ledgr_typed_event_metadata <- function(events, order_idx = NULL) {
  n_events <- if (is.null(events)) 0L else nrow(events)
  if (n_events == 0L) {
    return(NULL)
  }
  cash_delta <- attr(events, "ledgr_event_cash_delta", exact = TRUE)
  position_delta <- attr(events, "ledgr_event_position_delta", exact = TRUE)
  meta <- attr(events, "ledgr_event_meta", exact = TRUE)
  if (length(cash_delta) != n_events ||
      length(position_delta) != n_events ||
      length(meta) != n_events) {
    return(NULL)
  }
  if (!is.null(order_idx)) {
    cash_delta <- cash_delta[order_idx]
    position_delta <- position_delta[order_idx]
    meta <- meta[order_idx]
  }
  list(
    cash_delta = as.numeric(cash_delta),
    position_delta = as.numeric(position_delta),
    meta = meta
  )
}

ledgr_event_meta_at <- function(events, typed_meta, i) {
  if (!is.null(typed_meta)) {
    meta <- typed_meta$meta[[i]]
    if (!is.null(meta)) {
      return(meta)
    }
  }
  ledgr_json_read_nested(events$meta_json[[i]])
}

ledgr_equity_from_events <- function(events,
                                     pulses_posix,
                                     close_mat,
                                     initial_cash,
                                     instrument_ids,
                                     run_id) {
  n_pulses <- length(pulses_posix)
  typed_meta <- NULL
  events <- if (is.null(events) || nrow(events) == 0L) {
    data.frame()
  } else {
    order_idx <- order(events$event_seq)
    typed_meta <- ledgr_typed_event_metadata(events, order_idx = order_idx)
    events[order_idx, , drop = FALSE]
  }
  n_events <- nrow(events)

  if (n_pulses == 0L) {
    return(ledgr_empty_equity_curve())
  }

  event_ts <- if (n_events > 0L) {
    as.POSIXct(events$ts_utc, tz = "UTC")
  } else {
    as.POSIXct(character(0), tz = "UTC")
  }
  event_ts_num <- as.numeric(event_ts)
  pulse_ts_num <- as.numeric(pulses_posix)

  cash_delta <- numeric(n_events)
  position_delta <- numeric(n_events)
  event_meta <- vector("list", n_events)
  if (n_events > 0L) {
    if (!is.null(typed_meta)) {
      cash_delta <- typed_meta$cash_delta
      position_delta <- typed_meta$position_delta
    }
    for (i in seq_len(n_events)) {
      meta <- ledgr_event_meta_at(events, typed_meta, i)
      event_meta[[i]] <- meta
      if (is.null(typed_meta)) {
        cash_delta[[i]] <- as.numeric(meta$cash_delta %||% 0)
        position_delta[[i]] <- as.numeric(meta$position_delta %||% 0)
      }
    }
  }

  # Event streams are step functions over pulse time. `findInterval()` maps each
  # pulse to the most recent event at or before that timestamp, preserving
  # next-open fill timing without inspecting future events.
  idx <- findInterval(pulse_ts_num, event_ts_num)
  cash_cum <- if (n_events > 0L) cumsum(cash_delta) else numeric(0)
  cash_at <- rep(as.numeric(initial_cash), length(idx))
  has_event <- idx > 0L
  if (any(has_event)) {
    cash_at[has_event] <- as.numeric(initial_cash) + cash_cum[idx[has_event]]
  }

  n_inst <- length(instrument_ids)
  positions_mat <- matrix(0, nrow = n_inst, ncol = n_pulses)
  if (n_events > 0L) {
    for (j in seq_along(instrument_ids)) {
      id <- instrument_ids[[j]]
      ev_idx <- which(events$instrument_id == id)
      if (length(ev_idx) == 0L) next
      pos_cum <- cumsum(position_delta[ev_idx])
      idx_inst <- findInterval(pulse_ts_num, event_ts_num[ev_idx])
      has_inst_event <- idx_inst > 0L
      if (any(has_inst_event)) {
        positions_mat[j, has_inst_event] <- pos_cum[idx_inst[has_inst_event]]
      }
    }
  }

  positions_value <- if (n_pulses > 0L) colSums(positions_mat * close_mat) else numeric(0)

  reconstruction_lots <- ledgr_lot_state(instrument_ids)
  event_realized <- numeric(n_events)
  event_cost_basis <- numeric(n_events)
  if (n_events > 0L) {
    for (i in seq_len(n_events)) {
      lot_res <- ledgr_lot_apply_event(
        reconstruction_lots,
        event_type = events$event_type[[i]],
        instrument_id = events$instrument_id[[i]],
        side = events$side[[i]],
        qty = events$qty[[i]],
        price = events$price[[i]],
        fee = events$fee[[i]],
        meta = event_meta[[i]]
      )
      reconstruction_lots <- lot_res$state
      event_realized[[i]] <- reconstruction_lots$realized_pnl
      event_cost_basis[[i]] <- reconstruction_lots$total_cost_basis
    }
  }

  realized_at <- numeric(length(idx))
  cost_basis_at <- numeric(length(idx))
  if (any(has_event)) {
    realized_at[has_event] <- event_realized[idx[has_event]]
    cost_basis_at[has_event] <- event_cost_basis[idx[has_event]]
  }

  equity <- cash_at + positions_value
  unrealized <- positions_value - cost_basis_at

  data.frame(
    run_id = rep(run_id, length(pulses_posix)),
    ts_utc = pulses_posix,
    cash = cash_at,
    positions_value = positions_value,
    equity = equity,
    realized_pnl = realized_at,
    unrealized_pnl = unrealized,
    stringsAsFactors = FALSE
  )
}

ledgr_fill_row_buffer <- function(capacity) {
  capacity <- max(1L, as.integer(capacity %||% 1L))
  buffer <- new.env(parent = emptyenv())
  buffer$capacity <- capacity
  buffer$n <- 0L
  buffer$event_seq <- integer(capacity)
  buffer$ts_utc <- rep(as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC"), capacity)
  buffer$instrument_id <- character(capacity)
  buffer$side <- character(capacity)
  buffer$qty <- numeric(capacity)
  buffer$price <- numeric(capacity)
  buffer$fee <- numeric(capacity)
  buffer$realized_pnl <- numeric(capacity)
  buffer$action <- character(capacity)
  buffer
}

ledgr_fill_row_buffer_grow <- function(buffer, required) {
  if (required <= buffer$capacity) {
    return(invisible(buffer))
  }
  old_capacity <- buffer$capacity
  new_capacity <- old_capacity
  while (new_capacity < required) {
    new_capacity <- max(required, new_capacity * 2L)
  }
  idx <- seq_len(buffer$n)
  grow_posix <- function(x) {
    out <- rep(as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC"), new_capacity)
    if (buffer$n > 0L) out[idx] <- x[idx]
    out
  }
  grow_vector <- function(x, prototype) {
    out <- rep(prototype, new_capacity)
    if (buffer$n > 0L) out[idx] <- x[idx]
    out
  }
  buffer$event_seq <- grow_vector(buffer$event_seq, integer(1))
  buffer$ts_utc <- grow_posix(buffer$ts_utc)
  buffer$instrument_id <- grow_vector(buffer$instrument_id, character(1))
  buffer$side <- grow_vector(buffer$side, character(1))
  buffer$qty <- grow_vector(buffer$qty, numeric(1))
  buffer$price <- grow_vector(buffer$price, numeric(1))
  buffer$fee <- grow_vector(buffer$fee, numeric(1))
  buffer$realized_pnl <- grow_vector(buffer$realized_pnl, numeric(1))
  buffer$action <- grow_vector(buffer$action, character(1))
  buffer$capacity <- as.integer(new_capacity)
  invisible(buffer)
}

ledgr_fill_row_buffer_add <- function(buffer,
                                      event_seq,
                                      ts_utc,
                                      instrument_id,
                                      side,
                                      qty,
                                      price,
                                      fee,
                                      realized_pnl,
                                      action) {
  i <- buffer$n + 1L
  if (i > buffer$capacity) {
    ledgr_fill_row_buffer_grow(buffer, i)
  }
  collapse::setv(buffer$event_seq, i, as.integer(event_seq), vind1 = TRUE)
  collapse::setv(buffer$ts_utc, i, as.POSIXct(ts_utc, tz = "UTC"), vind1 = TRUE)
  collapse::setv(buffer$instrument_id, i, as.character(instrument_id), vind1 = TRUE)
  collapse::setv(buffer$side, i, as.character(side), vind1 = TRUE)
  collapse::setv(buffer$qty, i, as.numeric(qty), vind1 = TRUE)
  collapse::setv(buffer$price, i, as.numeric(price), vind1 = TRUE)
  collapse::setv(buffer$fee, i, as.numeric(fee), vind1 = TRUE)
  collapse::setv(buffer$realized_pnl, i, as.numeric(realized_pnl), vind1 = TRUE)
  collapse::setv(buffer$action, i, as.character(action), vind1 = TRUE)
  buffer$n <- i
  invisible(buffer)
}

ledgr_fill_row_buffer_data_frame <- function(buffer) {
  if (buffer$n == 0L) {
    return(as.data.frame(ledgr_empty_fills_table()))
  }
  idx <- seq_len(buffer$n)
  data.frame(
    event_seq = buffer$event_seq[idx],
    ts_utc = buffer$ts_utc[idx],
    instrument_id = buffer$instrument_id[idx],
    side = buffer$side[idx],
    qty = buffer$qty[idx],
    price = buffer$price[idx],
    fee = buffer$fee[idx],
    realized_pnl = buffer$realized_pnl[idx],
    action = buffer$action[idx],
    stringsAsFactors = FALSE
  )
}

ledgr_fill_row_buffer_tibble <- function(buffer) {
  tibble::as_tibble(ledgr_fill_row_buffer_data_frame(buffer))
}

ledgr_fills_from_events <- function(events) {
  if (is.null(events) || nrow(events) == 0L) {
    return(ledgr_empty_fills_table())
  }

  order_idx <- order(events$event_seq)
  typed_meta <- ledgr_typed_event_metadata(events, order_idx = order_idx)
  events <- events[order_idx, , drop = FALSE]
  instrument_ids <- unique(stats::na.omit(events$instrument_id))
  lot_state <- ledgr_lot_state(instrument_ids)
  fill_rows <- ledgr_fill_row_buffer(nrow(events) * 2L)

  event_seq_col <- .subset2(events, "event_seq")
  ts_utc_col <- .subset2(events, "ts_utc")
  event_type_col <- .subset2(events, "event_type")
  instrument_col <- .subset2(events, "instrument_id")
  side_col <- .subset2(events, "side")
  qty_col <- .subset2(events, "qty")
  price_col <- .subset2(events, "price")
  fee_col <- .subset2(events, "fee")

  for (i in seq_len(nrow(events))) {
    event_type <- as.character(event_type_col[[i]])
    inst <- as.character(instrument_col[[i]])
    side <- as.character(side_col[[i]])
    qty <- suppressWarnings(as.numeric(qty_col[[i]]))
    price <- suppressWarnings(as.numeric(price_col[[i]]))
    fee <- suppressWarnings(as.numeric(fee_col[[i]]))
    if (identical(event_type, "CASHFLOW")) {
      meta <- ledgr_event_meta_at(events, typed_meta, i)
      lot_res <- ledgr_lot_apply_event(
        lot_state,
        event_type = event_type,
        instrument_id = inst,
        side = side,
        qty = qty,
        price = price,
        fee = fee,
        meta = meta
      )
      lot_state <- lot_res$state
      next
    }
    if (!identical(event_type, "FILL") &&
        !identical(event_type, "FILL_PARTIAL")) {
      next
    }

    meta <- ledgr_event_meta_at(events, typed_meta, i)
    if (is.na(qty) || qty <= 0 || is.na(price)) {
      ledgr_fill_row_buffer_add(
        fill_rows,
        event_seq_col[[i]], ts_utc_col[[i]], inst, side, qty, price, fee,
        NA_real_, NA_character_
      )
      next
    }

    side_norm <- toupper(side)
    if (!(side_norm %in% c("BUY", "COVER", "BUY_TO_COVER", "SELL", "SHORT", "SELL_SHORT"))) {
      ledgr_fill_row_buffer_add(
        fill_rows,
        event_seq_col[[i]], ts_utc_col[[i]], inst, side, qty, price, fee,
        NA_real_, NA_character_
      )
      next
    }

    lot_res <- ledgr_lot_apply_event(
      lot_state,
      event_type = event_type,
      instrument_id = inst,
      side = side,
      qty = qty,
      price = price,
      fee = fee,
      meta = meta
    )
    close_qty <- lot_res$close_qty
    open_qty <- lot_res$open_qty
    realized_close <- lot_res$realized_close
    lot_state <- lot_res$state

    # A single event can close an existing lot and open the opposite side. The
    # CLOSE row must remain before the OPEN row for FIFO/replay parity.
    if (close_qty > 0) {
      ledgr_fill_row_buffer_add(
        fill_rows,
        event_seq_col[[i]], ts_utc_col[[i]], inst, side, close_qty, price, fee,
        realized_close, "CLOSE"
      )
    }
    if (open_qty > 0) {
      ledgr_fill_row_buffer_add(
        fill_rows,
        event_seq_col[[i]], ts_utc_col[[i]], inst, side, open_qty, price, fee,
        0, "OPEN"
      )
    }
  }

  if (fill_rows$n == 0L) {
    return(ledgr_empty_fills_table())
  }
  ledgr_fill_row_buffer_tibble(fill_rows)
}

ledgr_assert_events_in_fold_order <- function(events) {
  if (is.null(events) || nrow(events) < 2L) {
    return(invisible(TRUE))
  }
  event_seq <- suppressWarnings(as.integer(events$event_seq))
  if (any(is.na(event_seq)) || any(diff(event_seq) <= 0L)) {
    rlang::abort(
      "Sweep memory events must be in strictly increasing fold-produced event sequence order.",
      class = "ledgr_invalid_event_order"
    )
  }
  invisible(TRUE)
}

ledgr_sweep_summary_from_ordered_events <- function(events,
                                                    pulses_posix,
                                                    close_mat,
                                                    initial_cash,
                                                    instrument_ids,
                                                    run_id,
                                                    metric_kernel) {
  n_pulses <- length(pulses_posix)
  if (n_pulses == 0L) {
    equity <- ledgr_empty_equity_curve()
    fills <- ledgr_empty_fills_table()
    return(list(
      equity = equity,
      fills = fills,
      metrics = ledgr_metrics_from_equity_fills(
        equity = equity,
        fills = fills,
        metric_kernel = metric_kernel
      ),
      final_equity = NA_real_
    ))
  }

  events <- if (is.null(events) || nrow(events) == 0L) {
    data.frame()
  } else {
    ledgr_assert_events_in_fold_order(events)
    events
  }
  n_events <- nrow(events)
  typed_meta <- ledgr_typed_event_metadata(events)

  event_ts <- if (n_events > 0L) {
    as.POSIXct(events$ts_utc, tz = "UTC")
  } else {
    as.POSIXct(character(0), tz = "UTC")
  }
  event_ts_num <- as.numeric(event_ts)
  pulse_ts_num <- as.numeric(pulses_posix)
  idx <- findInterval(pulse_ts_num, event_ts_num)
  has_event <- idx > 0L

  cash_delta <- numeric(n_events)
  position_delta <- numeric(n_events)
  event_realized <- numeric(n_events)
  event_cost_basis <- numeric(n_events)
  if (!is.null(typed_meta)) {
    cash_delta <- typed_meta$cash_delta
    position_delta <- typed_meta$position_delta
  }

  max_fill_rows <- max(1L, n_events * 2L)
  fill_event_seq <- integer(max_fill_rows)
  fill_ts_utc <- rep(as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC"), max_fill_rows)
  fill_instrument_id <- character(max_fill_rows)
  fill_side <- character(max_fill_rows)
  fill_qty <- numeric(max_fill_rows)
  fill_price <- numeric(max_fill_rows)
  fill_fee <- numeric(max_fill_rows)
  fill_realized_pnl <- numeric(max_fill_rows)
  fill_action <- character(max_fill_rows)
  fill_idx <- 0L

  add_fill_row <- function(i, inst, side, qty, price, fee, realized_pnl, action) {
    fill_idx <<- fill_idx + 1L
    collapse::setv(fill_event_seq, fill_idx, as.integer(events$event_seq[[i]]), vind1 = TRUE)
    collapse::setv(fill_ts_utc, fill_idx, as.POSIXct(event_ts[[i]], tz = "UTC"), vind1 = TRUE)
    fill_instrument_id[[fill_idx]] <<- inst
    fill_side[[fill_idx]] <<- side
    collapse::setv(fill_qty, fill_idx, as.numeric(qty), vind1 = TRUE)
    collapse::setv(fill_price, fill_idx, as.numeric(price), vind1 = TRUE)
    collapse::setv(fill_fee, fill_idx, as.numeric(fee), vind1 = TRUE)
    collapse::setv(fill_realized_pnl, fill_idx, as.numeric(realized_pnl), vind1 = TRUE)
    fill_action[[fill_idx]] <<- action
    invisible(TRUE)
  }

  reconstruction_lots <- ledgr_lot_state(instrument_ids)
  if (n_events > 0L) {
    for (i in seq_len(n_events)) {
      event_type <- as.character(events$event_type[[i]])
      inst <- as.character(events$instrument_id[[i]])
      side <- as.character(events$side[[i]])
      qty <- suppressWarnings(as.numeric(events$qty[[i]]))
      price <- suppressWarnings(as.numeric(events$price[[i]]))
      fee <- suppressWarnings(as.numeric(events$fee[[i]]))
      meta <- ledgr_event_meta_at(events, typed_meta, i)
      if (is.null(typed_meta)) {
        cash_delta[[i]] <- as.numeric(meta$cash_delta %||% 0)
        position_delta[[i]] <- as.numeric(meta$position_delta %||% 0)
      }

      lot_res <- ledgr_lot_apply_event(
        reconstruction_lots,
        event_type = event_type,
        instrument_id = inst,
        side = side,
        qty = qty,
        price = price,
        fee = fee,
        meta = meta
      )
      reconstruction_lots <- lot_res$state
      event_realized[[i]] <- reconstruction_lots$realized_pnl
      event_cost_basis[[i]] <- reconstruction_lots$total_cost_basis

      if (identical(event_type, "CASHFLOW")) {
        next
      }
      if (!identical(event_type, "FILL") && !identical(event_type, "FILL_PARTIAL")) {
        next
      }
      if (is.na(qty) || qty <= 0 || is.na(price)) {
        add_fill_row(i, inst, side, qty, price, fee, NA_real_, NA_character_)
        next
      }
      side_norm <- toupper(side)
      if (!(side_norm %in% c("BUY", "COVER", "BUY_TO_COVER", "SELL", "SHORT", "SELL_SHORT"))) {
        add_fill_row(i, inst, side, qty, price, fee, NA_real_, NA_character_)
        next
      }
      if (isTRUE(lot_res$close_qty > 0)) {
        add_fill_row(i, inst, side, lot_res$close_qty, price, fee, lot_res$realized_close, "CLOSE")
      }
      if (isTRUE(lot_res$open_qty > 0)) {
        add_fill_row(i, inst, side, lot_res$open_qty, price, fee, 0, "OPEN")
      }
    }
  }

  cash_cum <- if (n_events > 0L) cumsum(cash_delta) else numeric(0)
  cash_at <- rep(as.numeric(initial_cash), length(idx))
  if (any(has_event)) {
    cash_at[has_event] <- as.numeric(initial_cash) + cash_cum[idx[has_event]]
  }

  n_inst <- length(instrument_ids)
  positions_mat <- matrix(0, nrow = n_inst, ncol = n_pulses)
  if (n_events > 0L) {
    for (j in seq_along(instrument_ids)) {
      id <- instrument_ids[[j]]
      ev_idx <- which(events$instrument_id == id)
      if (length(ev_idx) == 0L) next
      pos_cum <- cumsum(position_delta[ev_idx])
      idx_inst <- findInterval(pulse_ts_num, event_ts_num[ev_idx])
      has_inst_event <- idx_inst > 0L
      if (any(has_inst_event)) {
        positions_mat[j, has_inst_event] <- pos_cum[idx_inst[has_inst_event]]
      }
    }
  }
  positions_value <- if (n_pulses > 0L) colSums(positions_mat * close_mat) else numeric(0)

  realized_at <- numeric(length(idx))
  cost_basis_at <- numeric(length(idx))
  if (any(has_event)) {
    realized_at[has_event] <- event_realized[idx[has_event]]
    cost_basis_at[has_event] <- event_cost_basis[idx[has_event]]
  }

  equity <- data.frame(
    run_id = rep(run_id, length(pulses_posix)),
    ts_utc = pulses_posix,
    cash = cash_at,
    positions_value = positions_value,
    equity = cash_at + positions_value,
    realized_pnl = realized_at,
    unrealized_pnl = positions_value - cost_basis_at,
    stringsAsFactors = FALSE
  )
  fills <- if (fill_idx == 0L) {
    ledgr_empty_fills_table()
  } else {
    tibble::tibble(
      event_seq = fill_event_seq[seq_len(fill_idx)],
      ts_utc = fill_ts_utc[seq_len(fill_idx)],
      instrument_id = fill_instrument_id[seq_len(fill_idx)],
      side = fill_side[seq_len(fill_idx)],
      qty = fill_qty[seq_len(fill_idx)],
      price = fill_price[seq_len(fill_idx)],
      fee = fill_fee[seq_len(fill_idx)],
      realized_pnl = fill_realized_pnl[seq_len(fill_idx)],
      action = fill_action[seq_len(fill_idx)]
    )
  }
  metrics <- ledgr_metrics_from_equity_fills(
    equity = equity,
    fills = fills,
    metric_kernel = metric_kernel
  )
  list(
    equity = equity,
    fills = fills,
    metrics = metrics,
    final_equity = equity$equity[[nrow(equity)]]
  )
}
