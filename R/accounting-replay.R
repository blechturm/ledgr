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

ledgr_accounting_meta_frame <- function(meta_json) {
  payload <- as.character(meta_json)
  payload[is.na(payload) | !nzchar(payload)] <- "{}"
  parsed <- tryCatch(
    yyjsonr::read_ndjson_str(paste(payload, collapse = "\n")),
    error = function(e) {
      ledgr_accounting_event_error(
        "Accounting event meta_json is malformed.",
        "ledgr_invalid_ledger_meta"
      )
    }
  )
  if (!is.data.frame(parsed)) parsed <- as.data.frame(parsed, stringsAsFactors = FALSE)
  parsed
}

ledgr_accounting_meta_field <- function(meta, name, n, default, type) {
  if (!name %in% names(meta)) return(rep(default, n))
  value <- meta[[name]]
  if (is.list(value)) {
    return(vapply(value, function(x) {
      if (is.null(x) || length(x) != 1L) default else type(x)
    }, type(default)))
  }
  value <- rep_len(value, n)
  missing <- is.na(value)
  value <- type(value)
  value[missing] <- default
  value
}

ledgr_empty_prepared_accounting_events <- function(instrument_ids = character()) {
  ids <- unique(as.character(instrument_ids))
  ids <- ids[!is.na(ids) & nzchar(ids)]
  structure(list(
    event_id = character(), run_id = character(),
    ts_utc = as.POSIXct(character(), tz = "UTC"), event_type = character(),
    instrument_id = character(), instrument_index = integer(), side = character(),
    qty = numeric(), price = numeric(), fee = numeric(), cash_delta = numeric(),
    position_delta = numeric(), source = character(), source_fact_id = character(),
    entitled_quantity = numeric(), gross_cash_per_parent_unit = numeric(),
    amount_policy_id = character(), posting_policy_id = character(),
    late_arrival = logical(), affected_marked_exposure = numeric(),
    terminal_event = character(), matched_label = character(),
    disposition_policy_id = character(), disposition_choice = character(),
    disposition_basis = character(), mark_source = character(),
    mark_source_ts_utc = as.POSIXct(character(), tz = "UTC"),
    mark_age = integer(), haircut_fraction = numeric(),
    event_seq = integer(), operation = integer(), lot_side = integer(),
    lot_qty = numeric(), lot_price = numeric(), position_before = numeric(),
    realized_model_pnl = numeric(), instrument_ids = ids
  ), class = "ledgr_prepared_accounting_events")
}

ledgr_validate_accounting_append <- function(rows,
                                             instrument_ids = character(),
                                             cash_delta = NULL,
                                             position_delta = NULL,
                                             prior_event_seq = NULL,
                                             prior_ts_utc = NULL) {
  if (!is.null(cash_delta) || !is.null(position_delta)) {
    if (any(!is.finite(c(cash_delta, position_delta)))) {
      # Durable fill publication formerly reached canonical JSON first; keep
      # that public refusal precedence for every sink while schema 124 is live.
      rlang::abort(
        "canonical_json() does not allow non-finite numeric values in config (Inf/-Inf/NaN).",
        class = "ledgr_config_non_finite"
      )
    }
    attr(rows, "ledgr_event_cash_delta") <- cash_delta
    attr(rows, "ledgr_event_position_delta") <- position_delta
  }
  ledgr_prepare_accounting_events(
    rows,
    instrument_ids = instrument_ids,
    prior_event_seq = prior_event_seq,
    prior_ts_utc = prior_ts_utc
  )
}

ledgr_prepare_accounting_events <- function(columns,
                                             instrument_ids = character(),
                                             prior_event_seq = NULL,
                                             prior_ts_utc = NULL) {
  if (!is.list(columns)) {
    ledgr_accounting_event_error("Accounting events must be supplied as column vectors.")
  }
  if (length(columns) == 0L) {
    return(ledgr_empty_prepared_accounting_events(instrument_ids))
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
    return(ledgr_empty_prepared_accounting_events(instrument_ids))
  }

  event_seq <- suppressWarnings(as.integer(columns$event_seq))
  if (anyNA(event_seq) || any(diff(event_seq) <= 0L) ||
    (!is.null(prior_event_seq) && event_seq[[1L]] <= as.integer(prior_event_seq))) {
    ledgr_accounting_event_error(
      "Accounting event_seq values must be strictly increasing across blocks."
    )
  }

  ts_utc <- as.POSIXct(columns$ts_utc, tz = "UTC")
  ts_num <- as.numeric(ts_utc)
  prior_num <- if (is.null(prior_ts_utc)) NA_real_ else as.numeric(as.POSIXct(prior_ts_utc, tz = "UTC"))
  if (anyNA(ts_utc) || is.unsorted(ts_num) ||
    (!is.na(prior_num) && ts_num[[1L]] < prior_num)) {
    ledgr_accounting_event_error(
      "Accounting event timestamps must be valid and nondecreasing across blocks."
    )
  }

  event_type <- as.character(columns$event_type)
  event_id <- as.character(columns$event_id)
  run_id <- as.character(columns$run_id)
  instrument_id <- as.character(columns$instrument_id)
  side <- toupper(as.character(columns$side))
  qty <- suppressWarnings(as.numeric(columns$qty))
  price <- suppressWarnings(as.numeric(columns$price))
  fee <- suppressWarnings(as.numeric(columns$fee))
  if (anyNA(event_id) || any(!nzchar(event_id)) || anyNA(run_id) || any(!nzchar(run_id)) ||
    anyNA(instrument_id) || any(!nzchar(instrument_id)) || anyNA(fee) || any(!is.finite(fee))) {
    ledgr_accounting_event_error("Accounting events require non-empty identities and finite fees.")
  }
  meta_json <- as.character(columns$meta_json)
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
    cash_delta <- as.numeric(source_cash)
    position_delta <- as.numeric(source_position)
  }

  meta <- ledgr_accounting_meta_frame(meta_json)
  field_chr <- function(name) ledgr_accounting_meta_field(meta, name, n, NA_character_, as.character)
  field_num <- function(name) ledgr_accounting_meta_field(meta, name, n, NA_real_, as.numeric)
  field_int <- function(name) ledgr_accounting_meta_field(meta, name, n, NA_integer_, as.integer)
  field_lgl <- function(name) ledgr_accounting_meta_field(meta, name, n, NA, as.logical)

  source <- field_chr("source")
  if (!has_cash) {
    cash_delta <- field_num("cash_delta")
    position_delta <- field_num("position_delta")
  }
  fill <- event_type == "FILL"
  direction <- ifelse(side == "BUY", 1, ifelse(side == "SELL", -1, NA_real_))
  if (anyNA(cash_delta) || any(!is.finite(cash_delta)) ||
    anyNA(position_delta) || any(!is.finite(position_delta))) {
    ledgr_accounting_event_error(
      "Accounting event metadata must provide finite cash_delta and position_delta values.",
      "ledgr_invalid_ledger_meta"
    )
  }

  opening <- event_type == "CASHFLOW" & !is.na(source) & source == "opening_position"
  cashflow <- event_type == "CASHFLOW" & !is.na(source) & source == "corporate_action_cash"
  disposition <- event_type == "DISPOSITION"
  unsupported <- !(fill | opening | cashflow | disposition)
  if (any(unsupported)) {
    ledgr_accounting_event_error(sprintf(
      "Unsupported accounting event_type: %s.",
      event_type[which(unsupported)[[1L]]]
    ))
  }

  invalid_fill <- fill & (
    !(side %in% c("BUY", "SELL")) | !is.finite(qty) | qty <= 0 |
      !is.finite(price) | price <= 0 | !is.finite(fee) | fee < 0 |
      is.na(instrument_id) | !nzchar(instrument_id)
  )
  if (any(invalid_fill)) {
    ledgr_accounting_event_error(
      "FILL requires BUY or SELL, a non-empty instrument, positive qty and price, and non-negative fee."
    )
  }
  expected_fill_cash <- rep(NA_real_, n)
  expected_fill_position <- rep(NA_real_, n)
  buy_fill <- fill & side == "BUY"
  sell_fill <- fill & side == "SELL"
  expected_fill_cash[buy_fill] <-
    -(qty[buy_fill] * price[buy_fill] + fee[buy_fill])
  expected_fill_cash[sell_fill] <-
    +(qty[sell_fill] * price[sell_fill] - fee[sell_fill])
  expected_fill_position[buy_fill] <- qty[buy_fill]
  expected_fill_position[sell_fill] <- -qty[sell_fill]
  invalid_fill_effect <- fill & (
    cash_delta != expected_fill_cash |
      position_delta != expected_fill_position
  )
  if (any(invalid_fill_effect, na.rm = TRUE)) {
    ledgr_accounting_event_error(
      "FILL cash and position deltas do not reconcile to side, quantity, price and fee.",
      "ledgr_invalid_ledger_meta"
    )
  }

  cost_basis <- field_num("cost_basis")
  invalid_opening <- opening & (
    is.na(instrument_id) | !nzchar(instrument_id) |
      !is.na(side) | !is.finite(qty) | qty == 0 | !is.finite(price) |
      !is.finite(position_delta) | !is.finite(cost_basis) | fee != 0 |
      cash_delta != 0 | position_delta != qty | price != cost_basis
  )
  if (any(invalid_opening)) {
    ledgr_accounting_event_error(
      "Opening-position metadata is malformed.",
      "ledgr_invalid_ledger_meta"
    )
  }

  source_fact_id <- field_chr("source_fact_id")
  entitled_quantity <- field_num("entitled_quantity")
  gross_cash_per_parent_unit <- field_num("gross_cash_per_parent_unit")
  amount_policy_id <- field_chr("amount_policy_id")
  posting_policy_id <- field_chr("posting_policy_id")
  late_arrival <- field_lgl("late_arrival")
  affected_marked_exposure <- field_num("affected_marked_exposure")
  terminal_event <- field_chr("terminal_event")
  matched_label <- field_chr("matched_label")
  disposition_policy_id <- field_chr("disposition_policy_id")
  disposition_choice <- field_chr("disposition_choice")
  disposition_basis <- field_chr("disposition_basis")
  mark_source <- field_chr("mark_source")
  mark_source_raw <- field_chr("mark_source_ts_utc")
  mark_source_ts_utc <- suppressWarnings(as.POSIXct(mark_source_raw, tz = "UTC"))
  mark_age <- field_int("mark_age")
  haircut_fraction <- field_num("haircut_fraction")
  position_before <- field_num("position_before")
  position_after <- field_num("position_after")
  realized_model_pnl <- field_num("realized_model_pnl")
  quantity <- field_num("quantity")
  mark <- field_num("mark")
  invalid_cashflow <- cashflow & (
    !is.na(side) | !is.na(qty) | !is.na(price) | fee != 0 |
      is.na(source_fact_id) | !nzchar(source_fact_id) |
      !is.finite(entitled_quantity) | !is.finite(gross_cash_per_parent_unit) |
      is.na(amount_policy_id) | !nzchar(amount_policy_id) |
      is.na(posting_policy_id) | !nzchar(posting_policy_id) |
      is.na(late_arrival) | !is.finite(affected_marked_exposure) |
      affected_marked_exposure < 0 | position_delta != 0 |
      cash_delta != entitled_quantity * gross_cash_per_parent_unit
  )
  if (any(invalid_cashflow)) {
    ledgr_accounting_event_error(
      "Corporate-action cash metadata is malformed or does not reconcile.",
      "ledgr_invalid_ledger_meta"
    )
  }
  cash_only <- !is.na(entitled_quantity) | !is.na(gross_cash_per_parent_unit) |
    !is.na(amount_policy_id) | !is.na(posting_policy_id) | !is.na(late_arrival)
  disposition_only <- !is.na(disposition_policy_id) | !is.na(disposition_choice) |
    !is.na(disposition_basis) | !is.na(mark_source) | !is.na(mark_source_raw) |
    !is.na(mark_age) | !is.na(position_before) | !is.na(realized_model_pnl) |
    !is.na(quantity) | !is.na(mark)
  lifetime_only <- !is.na(terminal_event) | !is.na(matched_label) | !is.na(haircut_fraction)
  irrelevant <- (fill & (!is.na(source) | !is.na(source_fact_id) | cash_only |
    disposition_only | lifetime_only | !is.na(affected_marked_exposure) | !is.na(cost_basis))) |
    (opening & (!is.na(source_fact_id) | cash_only | disposition_only |
      lifetime_only | !is.na(affected_marked_exposure))) |
    (cashflow & (disposition_only | lifetime_only | !is.na(cost_basis)))
  if (any(irrelevant)) {
    ledgr_accounting_event_error(
      "Accounting event metadata contains fields forbidden for its event kind.",
      "ledgr_invalid_ledger_meta"
    )
  }
  forbidden <- intersect(names(meta), c("subtype", "equity_subtype", "vendor_subtype"))
  scheduled <- disposition & !is.na(source) & source == "corporate_action_disposition"
  lifetime <- disposition & !is.na(source) & source == "lifetime_terminal_disposition"
  scheduled_zero <- scheduled & mark <= 0
  lifetime_zero <- lifetime &
    mark == 0 & disposition_choice == "write_off"
  invalid_disposition <- disposition & (
    length(forbidden) > 0L | !(source %in% ledgr_disposition_sources()) |
      is.na(instrument_id) | !nzchar(instrument_id) |
      !is.na(side) | fee != 0 |
      !is.finite(quantity) | quantity <= 0 | !is.finite(mark) | mark < 0 |
      scheduled_zero | (mark == 0 & !lifetime_zero) |
      !is.finite(position_before) | !is.finite(position_after) | position_after != 0 |
      !is.finite(realized_model_pnl) | is.na(source_fact_id) | !nzchar(source_fact_id) |
      is.na(disposition_policy_id) | !nzchar(disposition_policy_id)
  )
  if (any(invalid_disposition)) {
    ledgr_accounting_event_error(
      "DISPOSITION metadata is malformed or carries a forbidden subtype.",
      "ledgr_invalid_ledger_meta"
    )
  }
  invalid_disposition_evidence <- disposition & (
    is.na(disposition_choice) | is.na(disposition_basis) |
      is.na(mark_source) | !nzchar(mark_source) |
      is.na(mark_source_raw) | !nzchar(mark_source_raw) | is.na(mark_source_ts_utc) |
      is.na(mark_age) | mark_age < 0L |
      !is.finite(affected_marked_exposure) | affected_marked_exposure < 0 |
      (scheduled & !(disposition_choice %in% c("last_permissible", "last_mark"))) |
      (scheduled & disposition_basis != "evidence") |
      (scheduled & (!is.na(terminal_event) | !is.na(matched_label) | !is.na(haircut_fraction))) |
      (lifetime & !(disposition_choice %in% c("last_permissible", "last_mark", "haircut", "write_off"))) |
      (lifetime & !(disposition_basis %in% c("label", "default", "frozen_fallback"))) |
      (lifetime & (is.na(terminal_event) | !nzchar(terminal_event) |
        is.na(matched_label) | !nzchar(matched_label))) |
      (lifetime & disposition_choice == "haircut" & !is.finite(haircut_fraction)) |
      (lifetime & disposition_choice != "haircut" & !is.na(haircut_fraction))
  )
  if (any(invalid_disposition_evidence, na.rm = TRUE)) {
    ledgr_accounting_event_error(
      "DISPOSITION evidence fields are malformed.",
      "ledgr_invalid_ledger_meta"
    )
  }
  expected_position <- -position_before
  expected_cash <- -expected_position * mark
  unreconciled <- disposition & (
    position_delta != expected_position | cash_delta != expected_cash |
      qty != quantity | price != mark
  )
  if (any(unreconciled, na.rm = TRUE)) {
    ledgr_accounting_event_error(
      "DISPOSITION cash and position deltas do not reconcile to its position and mark.",
      "ledgr_invalid_ledger_meta"
    )
  }

  operation <- integer(n)
  operation[fill] <- .ledgr_lot_fill
  operation[cashflow] <- 2L
  operation[opening] <- .ledgr_lot_opening
  operation[disposition] <- .ledgr_lot_disposition
  lot_side <- ledgr_lot_side(side)
  lot_side[is.na(lot_side)] <- 0L
  lot_qty <- qty
  lot_price <- price
  lot_side[opening] <- 0L
  lot_qty[opening] <- position_delta[opening]
  lot_price[opening] <- cost_basis[opening]
  lot_side[disposition] <- -as.integer(sign(position_before[disposition]))
  lot_qty[disposition] <- quantity[disposition]
  lot_price[disposition] <- mark[disposition]

  ids <- unique(c(
    as.character(instrument_ids),
    instrument_id[!is.na(instrument_id) & nzchar(instrument_id)]
  ))
  ids <- ids[!is.na(ids) & nzchar(ids)]
  instrument_index <- match(instrument_id, ids)

  structure(list(
    event_id = event_id,
    run_id = run_id,
    ts_utc = ts_utc,
    event_type = event_type,
    instrument_id = instrument_id,
    instrument_index = as.integer(instrument_index),
    side = side,
    qty = qty,
    price = price,
    fee = fee,
    cash_delta = cash_delta,
    position_delta = position_delta,
    source = source,
    source_fact_id = source_fact_id,
    entitled_quantity = entitled_quantity,
    gross_cash_per_parent_unit = gross_cash_per_parent_unit,
    amount_policy_id = amount_policy_id,
    posting_policy_id = posting_policy_id,
    late_arrival = late_arrival,
    affected_marked_exposure = affected_marked_exposure,
    terminal_event = terminal_event,
    matched_label = matched_label,
    disposition_policy_id = disposition_policy_id,
    disposition_choice = disposition_choice,
    disposition_basis = disposition_basis,
    mark_source = mark_source,
    mark_source_ts_utc = mark_source_ts_utc,
    mark_age = mark_age,
    haircut_fraction = haircut_fraction,
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
# instrument has no event by then, or whose time is NA, is 0. Preparation
# already refuses decreasing event timestamps, so every query is a prefix.
ledgr_accounting_positions_at_pairs <- function(replay, query_ids, query_times) {
  prepared <- replay$prepared
  event_num <- as.numeric(prepared$ts_utc)
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
