ledgr_lot_state <- function(instrument_ids = character()) {
  instrument_ids <- as.character(instrument_ids)
  instrument_ids <- instrument_ids[!is.na(instrument_ids) & nzchar(instrument_ids)]
  instrument_ids <- unique(instrument_ids)
  n_inst <- length(instrument_ids)
  list(
    instrument_ids = instrument_ids,
    instrument_index = stats::setNames(seq_len(n_inst), instrument_ids),
    lot_qty = rep(list(numeric()), n_inst),
    lot_price = rep(list(numeric()), n_inst),
    lot_head = stats::setNames(rep(1L, n_inst), instrument_ids),
    lot_tail = stats::setNames(rep(0L, n_inst), instrument_ids),
    net_by_inst = stats::setNames(rep(0, n_inst), instrument_ids),
    cost_basis_by_inst = stats::setNames(rep(0, n_inst), instrument_ids),
    total_cost_basis = 0,
    realized_pnl = 0,
    realized_comp = 0
  )
}

ledgr_lot_direction <- function(side) {
  side <- toupper(as.character(side))
  if (length(side) != 1L || is.na(side)) return(NA_integer_)
  if (identical(side, "BUY")) return(1L)
  if (identical(side, "SELL")) return(-1L)
  NA_integer_
}

ledgr_lot_ensure_instrument <- function(state, instrument_id) {
  idx <- unname(state$instrument_index[instrument_id])
  if (length(idx) == 1L && !is.na(idx)) {
    return(list(state = state, index = as.integer(idx)))
  }

  idx <- length(state$instrument_ids) + 1L
  state$instrument_ids[[idx]] <- instrument_id
  state$instrument_index[[instrument_id]] <- idx
  state$lot_qty[[idx]] <- numeric()
  state$lot_price[[idx]] <- numeric()
  state$lot_head[[instrument_id]] <- 1L
  state$lot_tail[[instrument_id]] <- 0L
  state$net_by_inst[[instrument_id]] <- 0
  state$cost_basis_by_inst[[instrument_id]] <- 0
  list(state = state, index = idx)
}

ledgr_lot_values <- function(state, instrument_id) {
  idx <- unname(state$instrument_index[instrument_id])
  if (length(idx) != 1L || is.na(idx)) {
    return(list(qty = numeric(), price = numeric()))
  }
  head <- as.integer(state$lot_head[[idx]])
  tail <- as.integer(state$lot_tail[[idx]])
  if (tail < head) {
    return(list(qty = numeric(), price = numeric()))
  }
  live <- seq.int(head, tail)
  list(
    qty = as.numeric(state$lot_qty[[idx]][live]),
    price = as.numeric(state$lot_price[[idx]][live])
  )
}

ledgr_lot_count <- function(state, instrument_id) {
  values <- ledgr_lot_values(state, instrument_id)
  length(values$qty)
}

ledgr_lot_compact <- function(qty, price, head, tail, force = FALSE) {
  live_n <- if (tail >= head) tail - head + 1L else 0L
  if (live_n == 0L) {
    return(list(qty = qty, price = price, head = 1L, tail = 0L))
  }
  dead_n <- head - 1L
  if (!isTRUE(force) && dead_n <= live_n) {
    return(list(qty = qty, price = price, head = head, tail = tail))
  }
  live <- seq.int(head, tail)
  qty[seq_len(live_n)] <- qty[live]
  price[seq_len(live_n)] <- price[live]
  if (live_n < length(qty)) {
    qty[seq.int(live_n + 1L, length(qty))] <- NA_real_
    price[seq.int(live_n + 1L, length(price))] <- NA_real_
  }
  list(qty = qty, price = price, head = 1L, tail = live_n)
}

ledgr_lot_append_vectors <- function(qty, price, head, tail, value_qty, value_price) {
  if (tail >= length(qty) && head > 1L) {
    compacted <- ledgr_lot_compact(qty, price, head, tail, force = TRUE)
    qty <- compacted$qty
    price <- compacted$price
    head <- compacted$head
    tail <- compacted$tail
  }
  if (tail >= length(qty)) {
    old_capacity <- length(qty)
    new_capacity <- max(4L, old_capacity * 2L)
    length(qty) <- new_capacity
    length(price) <- new_capacity
    if (new_capacity > old_capacity) {
      idx <- seq.int(old_capacity + 1L, new_capacity)
      qty[idx] <- NA_real_
      price[idx] <- NA_real_
    }
  }
  tail <- tail + 1L
  qty[[tail]] <- as.numeric(value_qty)
  price[[tail]] <- as.numeric(value_price)
  list(qty = qty, price = price, head = head, tail = tail)
}

ledgr_lot_dust_tolerance <- function(...) {
  values <- abs(as.numeric(c(...)))
  values <- values[is.finite(values)]
  .Machine$double.eps * max(c(1, values))
}

ledgr_fill_leg_fees <- function(fee, close_qty, open_qty) {
  total_qty <- as.numeric(close_qty) + as.numeric(open_qty)
  if (!is.finite(total_qty) || total_qty <= 0) {
    return(c(close = 0, open = 0))
  }

  close_fee <- if (close_qty > 0) {
    as.numeric(fee) * as.numeric(close_qty) / total_qty
  } else {
    0
  }
  open_fee <- if (open_qty > 0) as.numeric(fee) - close_fee else 0
  c(close = close_fee, open = open_fee)
}

ledgr_lot_add_realized <- function(state, delta) {
  y <- as.numeric(delta) - as.numeric(state$realized_comp)
  t <- as.numeric(state$realized_pnl) + y
  state$realized_comp <- (t - as.numeric(state$realized_pnl)) - y
  state$realized_pnl <- t
  state
}

ledgr_lot_apply_opening <- function(state, instrument_id, qty, cost_basis) {
  if (!is.character(instrument_id) || length(instrument_id) != 1L ||
    is.na(instrument_id) || !nzchar(instrument_id)) {
    return(state)
  }
  qty <- suppressWarnings(as.numeric(qty))
  cost_basis <- suppressWarnings(as.numeric(cost_basis))
  if (length(qty) != 1L || is.na(qty) || !is.finite(qty) || qty == 0 ||
    length(cost_basis) != 1L || is.na(cost_basis) || !is.finite(cost_basis)) {
    return(state)
  }

  ensured <- ledgr_lot_ensure_instrument(state, instrument_id)
  state <- ensured$state
  idx <- ensured$index
  appended <- ledgr_lot_append_vectors(
    state$lot_qty[[idx]],
    state$lot_price[[idx]],
    as.integer(state$lot_head[[idx]]),
    as.integer(state$lot_tail[[idx]]),
    qty,
    cost_basis
  )
  state$lot_qty[[idx]] <- appended$qty
  state$lot_price[[idx]] <- appended$price
  state$lot_head[[idx]] <- appended$head
  state$lot_tail[[idx]] <- appended$tail
  old_basis <- as.numeric(state$cost_basis_by_inst[[idx]])
  new_basis <- old_basis + qty * cost_basis
  state$net_by_inst[[idx]] <- as.numeric(state$net_by_inst[[idx]]) + qty
  state$cost_basis_by_inst[[idx]] <- new_basis
  state$total_cost_basis <- as.numeric(state$total_cost_basis) - old_basis + new_basis
  state
}

ledgr_lot_state_from_opening <- function(instrument_ids,
                                         positions = numeric(0),
                                         cost_basis = numeric(0)) {
  state <- ledgr_lot_state(instrument_ids)
  if (is.null(positions) || length(positions) == 0L) {
    return(state)
  }
  position_names <- names(positions)
  positions <- as.numeric(positions)
  names(positions) <- position_names %||% character(length(positions))
  cost_basis_names <- names(cost_basis)
  cost_basis <- as.numeric(cost_basis)
  names(cost_basis) <- cost_basis_names %||% character(length(cost_basis))
  for (id in names(positions)) {
    if (!nzchar(id)) next
    qty <- positions[[id]]
    basis <- if (id %in% names(cost_basis)) cost_basis[[id]] else NA_real_
    state <- ledgr_lot_apply_opening(state, id, qty, basis)
  }
  state
}

ledgr_lot_state_from_events <- function(events, instrument_ids = character()) {
  if (is.null(events) || nrow(events) == 0L) {
    return(ledgr_lot_state(instrument_ids))
  }
  prepared <- ledgr_prepare_accounting_events(events, instrument_ids)
  ledgr_replay_accounting_events(prepared)$lot_state
}

ledgr_lot_state_asof <- function(con, run_id, instrument_ids, ts_utc) {
  rows <- DBI::dbGetQuery(
    con,
    "
    SELECT event_id, run_id, ts_utc, event_type, instrument_id, side, qty, price, fee, meta_json, event_seq
    FROM ledger_events
    WHERE run_id = ? AND ts_utc <= ?
      AND event_type IN ('CASHFLOW', 'FILL')
    ORDER BY event_seq
    ",
    params = list(run_id, ts_utc)
  )
  ledgr_lot_state_from_events(rows, instrument_ids = instrument_ids)
}

ledgr_lot_apply_fill <- function(state, instrument_id, side, qty, price, fee = 0) {
  direction <- ledgr_lot_direction(side)
  qty <- suppressWarnings(as.numeric(qty))
  price <- suppressWarnings(as.numeric(price))
  fee <- suppressWarnings(as.numeric(fee))
  if (is.na(direction) ||
    !is.character(instrument_id) || length(instrument_id) != 1L ||
    is.na(instrument_id) || !nzchar(instrument_id) ||
    length(qty) != 1L || is.na(qty) || !is.finite(qty) || qty <= 0 ||
    length(price) != 1L || is.na(price) || !is.finite(price) || price <= 0 ||
    length(fee) != 1L || is.na(fee) || !is.finite(fee) || fee < 0) {
    rlang::abort(
      "Invalid fill input for lot accounting.",
      class = "ledgr_invalid_lot_fill"
    )
  }

  ensured <- ledgr_lot_ensure_instrument(state, instrument_id)
  state <- ensured$state
  idx <- ensured$index
  lot_qty <- state$lot_qty[[idx]]
  lot_price <- state$lot_price[[idx]]
  lot_head <- as.integer(state$lot_head[[idx]])
  lot_tail <- as.integer(state$lot_tail[[idx]])
  net_pos <- as.numeric(state$net_by_inst[[idx]])
  old_basis <- as.numeric(state$cost_basis_by_inst[[idx]])
  basis_delta <- 0
  close_qty <- 0
  remaining_fill <- qty
  realized_close <- 0
  if (remaining_fill > 0 && lot_tail >= lot_head) {
    if (direction > 0L) {
      while (remaining_fill > 0 && lot_tail >= lot_head && lot_qty[[lot_head]] < 0) {
        current_qty <- abs(as.numeric(lot_qty[[lot_head]]))
        current_price <- as.numeric(lot_price[[lot_head]])
        take <- min(current_qty, remaining_fill)
        realized_close <- realized_close + (current_price - price) * take
        basis_delta <- basis_delta + take * current_price
        current_qty <- current_qty - take
        remaining_fill <- remaining_fill - take
        close_qty <- close_qty + take
        tol <- ledgr_lot_dust_tolerance(qty, take, current_qty, remaining_fill)
        if (abs(remaining_fill) <= tol) {
          remaining_fill <- 0
        }
        if (current_qty <= tol) {
          lot_qty[[lot_head]] <- NA_real_
          lot_price[[lot_head]] <- NA_real_
          lot_head <- lot_head + 1L
        } else {
          lot_qty[[lot_head]] <- -current_qty
        }
      }
    } else {
      while (remaining_fill > 0 && lot_tail >= lot_head && lot_qty[[lot_head]] > 0) {
        current_qty <- as.numeric(lot_qty[[lot_head]])
        current_price <- as.numeric(lot_price[[lot_head]])
        take <- min(current_qty, remaining_fill)
        realized_close <- realized_close + (price - current_price) * take
        basis_delta <- basis_delta - take * current_price
        current_qty <- current_qty - take
        remaining_fill <- remaining_fill - take
        close_qty <- close_qty + take
        tol <- ledgr_lot_dust_tolerance(qty, take, current_qty, remaining_fill)
        if (abs(remaining_fill) <= tol) {
          remaining_fill <- 0
        }
        if (current_qty <= tol) {
          lot_qty[[lot_head]] <- NA_real_
          lot_price[[lot_head]] <- NA_real_
          lot_head <- lot_head + 1L
        } else {
          lot_qty[[lot_head]] <- current_qty
        }
      }
    }
  }

  open_qty <- remaining_fill

  if (lot_head > lot_tail) {
    lot_head <- 1L
    lot_tail <- 0L
  } else {
    compacted <- ledgr_lot_compact(lot_qty, lot_price, lot_head, lot_tail)
    lot_qty <- compacted$qty
    lot_price <- compacted$price
    lot_head <- compacted$head
    lot_tail <- compacted$tail
  }

  book_empty_before_open <- lot_head > lot_tail
  if (open_qty > 0 && !book_empty_before_open &&
      sign(lot_qty[[lot_head]]) != direction) {
    rlang::abort(
      "Lot accounting cannot open through an unconsumed opposing lot.",
      class = c("ledgr_lot_state_invariant", "ledgr_invalid_state")
    )
  }
  if (open_qty > 0) {
    signed_open <- if (direction > 0L) open_qty else -open_qty
    appended <- ledgr_lot_append_vectors(
      lot_qty,
      lot_price,
      lot_head,
      lot_tail,
      signed_open,
      price
    )
    lot_qty <- appended$qty
    lot_price <- appended$price
    lot_head <- appended$head
    lot_tail <- appended$tail
    basis_delta <- basis_delta + signed_open * price
  }

  new_basis <- old_basis + basis_delta
  new_net <- if (book_empty_before_open) {
    direction * open_qty
  } else {
    net_pos + direction * qty
  }
  tol <- ledgr_lot_dust_tolerance(new_basis, new_net, qty, price)
  if (abs(new_basis) <= tol) new_basis <- 0
  if (abs(new_net) <= tol) new_net <- 0
  state$lot_qty[[idx]] <- lot_qty
  state$lot_price[[idx]] <- lot_price
  state$lot_head[[idx]] <- lot_head
  state$lot_tail[[idx]] <- lot_tail
  state$net_by_inst[[idx]] <- new_net
  state$cost_basis_by_inst[[idx]] <- new_basis
  state$total_cost_basis <- as.numeric(state$total_cost_basis) - old_basis + new_basis
  realized_delta <- realized_close - fee
  state <- ledgr_lot_add_realized(state, realized_delta)

  list(
    state = state,
    close_qty = close_qty,
    open_qty = open_qty,
    realized_close = realized_close,
    realized_delta = realized_delta,
    direction = direction
  )
}

ledgr_lot_meta_is_opening <- function(meta) {
  is.list(meta) &&
    identical(meta$source, "opening_position") &&
    !is.null(meta$position_delta) &&
    !is.null(meta$cost_basis)
}

ledgr_lot_parse_meta <- function(meta_json) {
  if (is.null(meta_json) ||
    (is.atomic(meta_json) && length(meta_json) == 1L && is.na(meta_json)) ||
    (is.character(meta_json) && length(meta_json) == 1L && !nzchar(meta_json))) {
    return(NULL)
  }
  tryCatch(ledgr_json_read_nested(meta_json), error = function(e) NULL)
}

ledgr_lot_apply_event <- function(state,
                                  event_type,
                                  instrument_id,
                                  side = NA_character_,
                                  qty = NA_real_,
                                  price = NA_real_,
                                  fee = 0,
                                  meta = NULL) {
  event_type <- as.character(event_type)
  if (length(event_type) != 1L || is.na(event_type)) {
    ledgr_accounting_event_error("Accounting event_type must be a non-missing scalar.")
  }

  if (identical(event_type, "CASHFLOW") && ledgr_lot_meta_is_opening(meta)) {
    state <- ledgr_lot_apply_opening(
      state,
      instrument_id = instrument_id,
      qty = meta$position_delta,
      cost_basis = meta$cost_basis
    )
    return(list(state = state, kind = "opening"))
  }

  if (identical(event_type, "CASHFLOW")) {
    return(list(state = state, kind = "cashflow"))
  }

  if (identical(event_type, "FILL")) {
    out <- ledgr_lot_apply_fill(
      state,
      instrument_id = instrument_id,
      side = side,
      qty = qty,
      price = price,
      fee = fee
    )
    out$kind <- "fill"
    return(out)
  }

  ledgr_accounting_event_error(sprintf(
    "Unsupported accounting event_type: %s.",
    event_type
  ))
}
