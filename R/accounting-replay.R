ledgr_accounting_event_error <- function(message, class = "ledgr_invalid_ledger_event") {
  rlang::abort(
    message,
    class = c("ledgr_invalid_accounting_event", class)
  )
}

ledgr_accounting_event_columns <- function() {
  c(
    "event_id", "run_id", "ts_utc", "event_type", "instrument_id",
    "side", "qty", "price", "fee", "meta_json", "event_seq"
  )
}

ledgr_prepare_accounting_events <- function(columns, instrument_ids = character()) {
  if (!is.list(columns)) {
    ledgr_accounting_event_error("Accounting events must be supplied as column vectors.")
  }
  required <- ledgr_accounting_event_columns()
  missing <- setdiff(required, names(columns))
  if (length(missing) > 0L) {
    ledgr_accounting_event_error(sprintf(
      "Accounting events are missing required columns: %s.",
      paste(missing, collapse = ", ")
    ))
  }

  n <- length(columns$event_seq)
  lengths <- vapply(columns[required], length, integer(1))
  if (any(lengths != n)) {
    ledgr_accounting_event_error("Accounting event columns must have equal lengths.")
  }
  if (n == 0L) {
    ids <- unique(as.character(instrument_ids))
    ids <- ids[!is.na(ids) & nzchar(ids)]
    return(structure(list(
      event_id = character(), run_id = character(),
      ts_utc = as.POSIXct(character(), tz = "UTC"), event_type = character(),
      instrument_id = character(), instrument_index = integer(), side = character(),
      qty = numeric(), price = numeric(), fee = numeric(), meta = list(),
      cash_delta = numeric(), position_delta = numeric(), event_seq = integer(),
      operation = integer(), lot_side = integer(), lot_qty = numeric(),
      lot_price = numeric(), position_before = numeric(),
      realized_model_pnl = numeric(), instrument_ids = ids
    ), class = "ledgr_prepared_accounting_events"))
  }

  event_seq <- suppressWarnings(as.integer(columns$event_seq))
  if (anyNA(event_seq) || anyDuplicated(event_seq)) {
    ledgr_accounting_event_error("Accounting event_seq values must be unique integers.")
  }
  order_idx <- order(event_seq)
  event_seq <- event_seq[order_idx]

  ts_utc <- as.POSIXct(columns$ts_utc[order_idx], tz = "UTC")
  if (anyNA(ts_utc)) {
    ledgr_accounting_event_error("Accounting event timestamps must be valid UTC timestamps.")
  }

  event_type <- as.character(columns$event_type[order_idx])
  instrument_id <- as.character(columns$instrument_id[order_idx])
  side <- toupper(as.character(columns$side[order_idx]))
  qty <- suppressWarnings(as.numeric(columns$qty[order_idx]))
  price <- suppressWarnings(as.numeric(columns$price[order_idx]))
  fee <- suppressWarnings(as.numeric(columns$fee[order_idx]))
  meta_json <- as.character(columns$meta_json[order_idx])
  source_cash <- attr(columns, "ledgr_event_cash_delta", exact = TRUE)
  source_position <- attr(columns, "ledgr_event_position_delta", exact = TRUE)
  has_cash <- length(source_cash) == n
  has_position <- length(source_position) == n
  if (!identical(has_cash, has_position)) {
    ledgr_accounting_event_error(
      "Accounting event cash and position auxiliaries must be supplied together.",
      "ledgr_invalid_ledger_meta"
    )
  }
  if (has_cash) {
    cash_delta <- as.numeric(source_cash[order_idx])
    position_delta <- as.numeric(source_position[order_idx])
  }
  meta <- lapply(seq_len(n), function(i) {
    value <- meta_json[[i]]
    if (length(value) == 1L && !is.na(value) && nzchar(value)) {
      parsed <- tryCatch(
        ledgr_json_read_nested(value),
        error = function(e) {
          ledgr_accounting_event_error(
            "Accounting event meta_json is malformed.",
            "ledgr_invalid_ledger_meta"
          )
        }
      )
      if (identical(event_type[[i]], "FILL") && side[[i]] %in% c("BUY", "SELL") &&
        is.finite(qty[[i]]) && is.finite(price[[i]]) && is.finite(fee[[i]])) {
        direction <- if (identical(side[[i]], "BUY")) 1 else -1
        if (is.null(parsed$cash_delta)) {
          parsed$cash_delta <- -direction * qty[[i]] * price[[i]] - fee[[i]]
        }
        if (is.null(parsed$position_delta)) {
          parsed$position_delta <- direction * qty[[i]]
        }
      }
      return(parsed)
    }
    if (identical(event_type[[i]], "FILL") && side[[i]] %in% c("BUY", "SELL") &&
      is.finite(qty[[i]]) && is.finite(price[[i]]) && is.finite(fee[[i]])) {
      direction <- if (identical(side[[i]], "BUY")) 1 else -1
      return(list(
        fee = fee[[i]],
        cash_delta = if (has_cash) {
          cash_delta[[i]]
        } else {
          -direction * qty[[i]] * price[[i]] - fee[[i]]
        },
        position_delta = if (has_cash) {
          position_delta[[i]]
        } else {
          direction * qty[[i]]
        },
        realized_pnl = NULL
      ))
    }
    ledgr_accounting_event_error(
      "Accounting events require non-empty meta_json.",
      "ledgr_invalid_ledger_meta"
    )
  })
  if (!has_cash) {
    scalar_delta <- function(value, name) {
      delta <- value[[name]]
      if (!is.numeric(delta) || length(delta) != 1L) {
        return(NA_real_)
      }
      as.numeric(delta)
    }
    cash_delta <- vapply(meta, scalar_delta, numeric(1), name = "cash_delta")
    position_delta <- vapply(meta, scalar_delta, numeric(1), name = "position_delta")
  }
  if (anyNA(cash_delta) || any(!is.finite(cash_delta)) ||
    anyNA(position_delta) || any(!is.finite(position_delta))) {
    ledgr_accounting_event_error(
      "Accounting event metadata must provide finite cash_delta and position_delta values.",
      "ledgr_invalid_ledger_meta"
    )
  }

  operation <- integer(n)
  # Typed lot inputs projected from the prepared rows (Synthesis 3.4): a FILL
  # carries its own side, quantity and price; an opening its signed
  # position_delta and cost basis; a DISPOSITION its quantity, mark, the
  # side that closes position_before, and its realized-P&L witness.
  lot_side <- ledgr_lot_side(side)
  lot_side[is.na(lot_side)] <- 0L
  lot_qty <- qty
  lot_price <- price
  position_before <- rep(NA_real_, n)
  realized_model_pnl <- rep(NA_real_, n)
  for (i in seq_len(n)) {
    type <- event_type[[i]]
    if (identical(type, "FILL")) {
      if (!(side[[i]] %in% c("BUY", "SELL"))) {
        ledgr_accounting_event_error("FILL side must be BUY or SELL.")
      }
      if (is.na(qty[[i]]) || !is.finite(qty[[i]]) || qty[[i]] <= 0 ||
        is.na(price[[i]]) || !is.finite(price[[i]]) || price[[i]] <= 0 ||
        is.na(fee[[i]]) || !is.finite(fee[[i]]) || fee[[i]] < 0) {
        ledgr_accounting_event_error(
          "FILL qty and price must be positive and fee must be non-negative."
        )
      }
      if (is.na(instrument_id[[i]]) || !nzchar(instrument_id[[i]])) {
        ledgr_accounting_event_error("FILL instrument_id must be non-empty.")
      }
      operation[[i]] <- 1L
    } else if (identical(type, "CASHFLOW")) {
      if (identical(meta[[i]]$source, "opening_position")) {
        if (!ledgr_lot_meta_is_opening(meta[[i]]) ||
          length(meta[[i]]$position_delta) != 1L ||
          !is.numeric(meta[[i]]$position_delta) ||
          !is.finite(meta[[i]]$position_delta) ||
          length(meta[[i]]$cost_basis) != 1L ||
          !is.numeric(meta[[i]]$cost_basis) ||
          !is.finite(meta[[i]]$cost_basis) ||
          is.na(instrument_id[[i]]) || !nzchar(instrument_id[[i]])) {
          ledgr_accounting_event_error(
            "Opening-position metadata is malformed.",
            "ledgr_invalid_ledger_meta"
          )
        }
        operation[[i]] <- 3L
        lot_side[[i]] <- 0L
        lot_qty[[i]] <- as.numeric(meta[[i]]$position_delta)
        lot_price[[i]] <- as.numeric(meta[[i]]$cost_basis)
      } else {
        operation[[i]] <- 2L
        lot_side[[i]] <- 0L
      }
    } else if (identical(type, "DISPOSITION")) {
      forbidden <- intersect(
        names(meta[[i]]),
        c("subtype", "equity_subtype", "vendor_subtype")
      )
      required_meta <- c(
        "source", "source_fact_id", "position_delta", "cash_delta",
        "quantity", "mark", "mark_source_ts_utc", "mark_age",
        "position_before", "position_after", "realized_model_pnl",
        "disposition_policy_id"
      )
      if (length(forbidden) > 0L ||
        !isTRUE(meta[[i]]$source %in% ledgr_disposition_sources()) ||
        any(!required_meta %in% names(meta[[i]])) ||
        is.na(instrument_id[[i]]) || !nzchar(instrument_id[[i]]) ||
        !is.numeric(meta[[i]]$quantity) || length(meta[[i]]$quantity) != 1L ||
        !is.finite(meta[[i]]$quantity) || meta[[i]]$quantity <= 0 ||
        !is.numeric(meta[[i]]$mark) || length(meta[[i]]$mark) != 1L ||
        !is.finite(meta[[i]]$mark) || meta[[i]]$mark < 0 ||
        !is.numeric(meta[[i]]$position_before) ||
        length(meta[[i]]$position_before) != 1L ||
        !is.finite(meta[[i]]$position_before) ||
        !is.numeric(meta[[i]]$position_after) ||
        length(meta[[i]]$position_after) != 1L ||
        !identical(as.numeric(meta[[i]]$position_after), 0) ||
        !is.numeric(meta[[i]]$realized_model_pnl) ||
        length(meta[[i]]$realized_model_pnl) != 1L ||
        !is.finite(meta[[i]]$realized_model_pnl) ||
        !is.character(meta[[i]]$source_fact_id) ||
        length(meta[[i]]$source_fact_id) != 1L ||
        is.na(meta[[i]]$source_fact_id) || !nzchar(meta[[i]]$source_fact_id) ||
        !is.character(meta[[i]]$disposition_policy_id) ||
        length(meta[[i]]$disposition_policy_id) != 1L ||
        is.na(meta[[i]]$disposition_policy_id) ||
        !nzchar(meta[[i]]$disposition_policy_id)) {
        ledgr_accounting_event_error(
          "DISPOSITION metadata is malformed or carries a forbidden subtype.",
          "ledgr_invalid_ledger_meta"
        )
      }
      expected_position <- -as.numeric(meta[[i]]$position_before)
      expected_cash <- -expected_position * as.numeric(meta[[i]]$mark)
      # The persisted event row must agree with its metadata, so an event
      # quantity or price cannot drift from the amount replay disposes.
      if (!isTRUE(all.equal(position_delta[[i]], expected_position, tolerance = 0)) ||
        !isTRUE(all.equal(cash_delta[[i]], expected_cash, tolerance = 0)) ||
        !isTRUE(all.equal(qty[[i]], as.numeric(meta[[i]]$quantity), tolerance = 0)) ||
        !isTRUE(all.equal(price[[i]], as.numeric(meta[[i]]$mark), tolerance = 0))) {
        ledgr_accounting_event_error(
          "DISPOSITION cash and position deltas do not reconcile to its position and mark.",
          "ledgr_invalid_ledger_meta"
        )
      }
      operation[[i]] <- 4L
      position_before[[i]] <- as.numeric(meta[[i]]$position_before)
      lot_side[[i]] <- -as.integer(sign(position_before[[i]]))
      lot_qty[[i]] <- as.numeric(meta[[i]]$quantity)
      lot_price[[i]] <- as.numeric(meta[[i]]$mark)
      realized_model_pnl[[i]] <- as.numeric(meta[[i]]$realized_model_pnl)
    } else {
      ledgr_accounting_event_error(sprintf(
        "Unsupported accounting event_type: %s.",
        if (is.na(type)) "NA" else type
      ))
    }
  }

  ids <- unique(c(
    as.character(instrument_ids),
    instrument_id[!is.na(instrument_id) & nzchar(instrument_id)]
  ))
  ids <- ids[!is.na(ids) & nzchar(ids)]
  instrument_index <- match(instrument_id, ids)

  structure(list(
    event_id = as.character(columns$event_id[order_idx]),
    run_id = as.character(columns$run_id[order_idx]),
    ts_utc = ts_utc,
    event_type = event_type,
    instrument_id = instrument_id,
    instrument_index = as.integer(instrument_index),
    side = side,
    qty = qty,
    price = price,
    fee = fee,
    meta = meta,
    cash_delta = cash_delta,
    position_delta = position_delta,
    event_seq = event_seq,
    operation = operation,
    lot_side = lot_side,
    lot_qty = lot_qty,
    lot_price = lot_price,
    position_before = position_before,
    realized_model_pnl = realized_model_pnl,
    instrument_ids = ids
  ), class = "ledgr_prepared_accounting_events")
}

# Replays prepared events through the typed lot operations. Lot rows (fills,
# nonzero openings and dispositions) are applied in consecutive
# conflict-free blocks: one block per run of rows with one operation and one
# timestamp, split where an instrument repeats (decision 6). Cash is a
# separate event-order scan of the published effects, each added once.
# Plain cashflows and zero openings move no lot; their position and
# aggregate facts are the book's values at their place in the stream.
ledgr_replay_accounting_events <- function(prepared,
                                           initial_cash = 0,
                                           initial_positions = NULL,
                                           lot_state = NULL) {
  if (!inherits(prepared, "ledgr_prepared_accounting_events")) {
    rlang::abort("`prepared` must be prepared accounting events.", class = "ledgr_invalid_args")
  }
  ids <- prepared$instrument_ids
  book <- if (is.null(lot_state)) {
    ledgr_lot_book(length(ids))
  } else {
    ledgr_lot_book_extend(lot_state, length(ids))
  }
  start_book <- book
  positions <- stats::setNames(rep(0, length(ids)), ids)
  if (!is.null(initial_positions) && length(initial_positions) > 0L) {
    matched <- intersect(names(initial_positions), ids)
    positions[matched] <- as.numeric(initial_positions[matched])
  }
  n <- length(prepared$event_seq)
  cash_after <- ledgr_cash_scan(initial_cash, prepared$cash_delta)
  cash <- if (n > 0L) cash_after[[n]] else as.numeric(initial_cash)

  op <- prepared$operation
  idx <- prepared$instrument_index
  lot_row <- op %in% c(.ledgr_lot_fill, .ledgr_lot_disposition) |
    (op == .ledgr_lot_opening & prepared$lot_qty != 0)
  rows <- which(lot_row)
  disposition <- rows[op[rows] == .ledgr_lot_disposition]
  malformed <- integer()
  if (length(disposition) > 0L) {
    before <- prepared$position_before[disposition]
    quantity <- prepared$lot_qty[disposition]
    mark <- prepared$lot_price[disposition]
    malformed <- disposition[!is.finite(before) | before == 0 | !is.finite(quantity) |
      quantity <= 0 | abs(before) != quantity | !is.finite(mark) | mark < 0]
  }
  # Scalar event order: the lot rows before the first malformed disposition
  # are applied first and may refuse earlier; otherwise it refuses after them.
  if (length(malformed) > 0L) rows <- rows[rows < malformed[[1L]]]
  k <- length(rows)
  ts <- as.numeric(prepared$ts_utc)[rows]
  # A run of lot rows continues while rows are adjacent and share their
  # operation and timestamp.
  new_run <- c(TRUE, rows[-1L] != rows[-k] + 1L |
    op[rows][-1L] != op[rows][-k] | ts[-1L] != ts[-k])[seq_len(k)]
  applied <- ledgr_lot_apply_blocks(
    book,
    operation = op[rows],
    pos = idx[rows],
    side = prepared$lot_side[rows],
    qty = prepared$lot_qty[rows],
    price = prepared$lot_price[rows],
    fee = ifelse(op[rows] == .ledgr_lot_fill, prepared$fee[rows], 0),
    realized_model_pnl = prepared$realized_model_pnl[rows],
    new_run = new_run
  )
  if (length(malformed) > 0L) {
    ledgr_accounting_event_error(
      "DISPOSITION lot metadata is malformed.",
      "ledgr_invalid_ledger_meta"
    )
  }
  book <- applied$book
  applied <- applied$applied

  scatter <- function(values) {
    out <- numeric(n)
    out[rows] <- values
    out
  }
  close_qty <- scatter(applied$close_qty)
  open_qty <- scatter(applied$open_qty)
  realized_close <- scatter(applied$realized_close)
  realized_delta <- scatter(applied$realized_delta)

  # Aggregates after each event: a lot row's own values, otherwise those of
  # the latest earlier lot row (or the starting book).
  latest <- cummax(ifelse(lot_row, seq_len(n), 0L))
  event_realized <- rep(start_book$realized_pnl, n)
  event_cost_basis <- rep(start_book$total_cost_basis, n)
  event_realized[latest > 0L] <- scatter(applied$event_realized)[latest[latest > 0L]]
  event_cost_basis[latest > 0L] <- scatter(applied$event_cost_basis)[latest[latest > 0L]]

  # Position after each event with an instrument: a lot row's lot-derived
  # net, otherwise the net after that instrument's latest earlier lot row
  # (or the starting book's net). Rows are ordered by (instrument, event)
  # so a running maximum finds the latest earlier lot row of the same
  # instrument.
  position_after <- rep(NA_real_, n)
  has <- which(!is.na(idx))
  if (length(has) > 0L) {
    after <- scatter(applied$position_after)
    ord <- has[order(idx[has], has, method = "radix")]
    seen <- cummax(ifelse(lot_row[ord], seq_along(ord), 0L))
    same <- seen > 0L
    same[same] <- idx[ord[seen[same]]] == idx[ord[same]]
    value <- start_book$net_by_inst[idx[ord]]
    value[same] <- after[ord[seen[same]]]
    position_after[ord] <- value
    last <- has[!duplicated(idx[has], fromLast = TRUE)]
    positions[idx[last]] <- position_after[last]
  }

  list(
    prepared = prepared,
    lot_state = book,
    cash = cash,
    positions = positions,
    cash_after = cash_after,
    position_after = position_after,
    event_realized = event_realized,
    event_cost_basis = event_cost_basis,
    close_qty = close_qty,
    open_qty = open_qty,
    realized_close = realized_close,
    realized_delta = realized_delta,
    event_seq = prepared$event_seq
  )
}

# Each (instrument, time) pair's position after that instrument's last ledger
# event at or before the time, from one sequential replay. Event timestamps
# never decrease in event order, so the events at or before a time are a
# prefix of the ledger and the replay's sequential `position_after` is exactly
# what replaying that prefix produces (cumsum() over deltas accumulates in
# long double and can differ in the last bit). One findInterval() over sorted
# (instrument, event position) keys resolves every pair. A pair whose
# instrument has no event by then, or whose time is NA, is 0. Returns NULL
# when timestamps decrease in event order; callers then replay per prefix.
ledgr_accounting_positions_at_pairs <- function(replay, query_ids, query_times) {
  prepared <- replay$prepared
  event_num <- as.numeric(prepared$ts_utc)
  if (is.unsorted(event_num)) {
    return(NULL)
  }
  inst <- prepared$instrument_index
  has <- !is.na(inst)
  big <- length(event_num) + 1
  key <- as.numeric(inst[has]) * big + which(has)
  ord <- order(key)
  key <- key[ord]
  key_inst <- inst[has][ord]
  after <- replay$position_after[has][ord]
  q_inst <- match(as.character(query_ids), prepared$instrument_ids)
  prefix <- findInterval(as.numeric(as.POSIXct(query_times, tz = "UTC")), event_num)
  out <- numeric(length(q_inst))
  ok <- which(!is.na(q_inst) & !is.na(prefix))
  if (length(ok) == 0L) {
    return(out)
  }
  hit <- findInterval(q_inst[ok] * big + prefix[ok], key)
  found <- hit > 0L
  found[found] <- key_inst[hit[found]] == q_inst[ok][found]
  out[ok[found]] <- after[hit[found]]
  out
}

ledgr_accounting_positions_at_pulses <- function(replay, pulses_posix, instrument_ids) {
  prepared <- replay$prepared
  pulse_num <- as.numeric(as.POSIXct(pulses_posix, tz = "UTC"))
  event_num <- as.numeric(prepared$ts_utc)
  event_rows_by_instrument <- split(
    seq_along(prepared$instrument_index),
    factor(
      prepared$instrument_index,
      levels = seq_along(prepared$instrument_ids)
    ),
    drop = FALSE
  )
  requested_index <- match(instrument_ids, prepared$instrument_ids)
  out <- matrix(
    0,
    nrow = length(instrument_ids),
    ncol = length(pulses_posix),
    dimnames = list(instrument_ids, NULL)
  )
  for (j in seq_along(instrument_ids)) {
    idx <- requested_index[[j]]
    rows <- if (is.na(idx)) integer() else event_rows_by_instrument[[idx]]
    if (length(rows) == 0L) next
    at <- findInterval(pulse_num, event_num[rows])
    present <- at > 0L
    out[j, present] <- replay$position_after[rows][at[present]]
  }
  out
}

ledgr_accounting_equity_from_replay <- function(replay,
                                                pulses_posix,
                                                close_mat,
                                                initial_cash,
                                                instrument_ids,
                                                run_id) {
  prepared <- replay$prepared
  event_at <- findInterval(
    as.numeric(as.POSIXct(pulses_posix, tz = "UTC")),
    as.numeric(prepared$ts_utc)
  )
  present <- event_at > 0L
  cash <- rep(as.numeric(initial_cash), length(pulses_posix))
  realized <- numeric(length(pulses_posix))
  basis <- numeric(length(pulses_posix))
  cash[present] <- replay$cash_after[event_at[present]]
  realized[present] <- replay$event_realized[event_at[present]]
  basis[present] <- replay$event_cost_basis[event_at[present]]
  positions <- ledgr_accounting_positions_at_pulses(
    replay,
    pulses_posix,
    instrument_ids
  )
  positions_value <- colSums(positions * close_mat)
  data.frame(
    run_id = rep(run_id, length(pulses_posix)),
    ts_utc = as.POSIXct(pulses_posix, tz = "UTC"),
    cash = cash,
    positions_value = positions_value,
    equity = cash + positions_value,
    realized_pnl = realized,
    unrealized_pnl = positions_value - basis,
    stringsAsFactors = FALSE
  )
}

ledgr_accounting_fills_from_replay <- function(replay,
                                               pulses_posix,
                                               execution_opportunities_posix = NULL) {
  prepared <- replay$prepared
  fill <- which(prepared$operation == 1L)
  if (length(fill) == 0L) {
    return(ledgr_empty_fills_table())
  }

  source <- rep(fill, each = 2L)
  close_leg <- rep(c(TRUE, FALSE), times = length(fill))
  quantity <- ifelse(close_leg, replay$close_qty[source], replay$open_qty[source])
  keep <- quantity > 0
  source <- source[keep]
  close_leg <- close_leg[keep]
  quantity <- quantity[keep]
  if (length(source) == 0L) {
    return(ledgr_empty_fills_table())
  }

  close_total <- replay$close_qty[source]
  open_total <- replay$open_qty[source]
  total <- close_total + open_total
  close_fee <- ifelse(
    open_total <= 0,
    prepared$fee[source],
    ifelse(close_total <= 0, 0, prepared$fee[source] * (close_total / total))
  )
  fee <- ifelse(close_leg, close_fee, prepared$fee[source] - close_fee)
  out <- tibble::tibble(
    event_seq = as.integer(prepared$event_seq[source]),
    ts_utc = as.POSIXct(prepared$ts_utc[source], tz = "UTC"),
    instrument_id = prepared$instrument_id[source],
    side = prepared$side[source],
    qty = as.numeric(quantity),
    price = as.numeric(prepared$price[source]),
    fee = as.numeric(fee),
    realized_pnl = ifelse(close_leg, replay$realized_close[source], 0),
    action = ifelse(close_leg, "CLOSE", "OPEN")
  )
  ledgr_fills_add_recording_pulse(
    out,
    ledgr_fill_recording_pulses_from_opportunities(
      out,
      pulses_posix,
      execution_opportunities_posix
    )
  )
}
