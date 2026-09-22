ledgr_equity_from_events <- function(events,
                                     pulses_posix,
                                     close_mat,
                                     initial_cash,
                                     instrument_ids,
                                     run_id) {
  if (length(pulses_posix) == 0L) {
    return(ledgr_empty_equity_curve())
  }
  if (is.null(events) || nrow(events) == 0L) events <- ledgr_empty_event_table()
  prepared <- ledgr_prepare_accounting_events(events, instrument_ids)
  replay <- ledgr_replay_accounting_events(prepared, initial_cash = initial_cash)
  ledgr_accounting_equity_from_replay(
    replay,
    pulses_posix,
    close_mat,
    initial_cash,
    instrument_ids,
    run_id
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

ledgr_fill_row_buffer_add_many <- function(buffer,
                                           event_seq,
                                           ts_utc,
                                           instrument_id,
                                           side,
                                           qty,
                                           price,
                                           fee,
                                           realized_pnl,
                                           action) {
  n <- length(event_seq)
  if (n == 0L) {
    return(invisible(buffer))
  }
  start <- buffer$n + 1L
  end <- buffer$n + n
  if (end > buffer$capacity) {
    ledgr_fill_row_buffer_grow(buffer, end)
  }
  idx <- start:end
  buffer$event_seq[idx] <- as.integer(event_seq)
  buffer$ts_utc[idx] <- as.POSIXct(as.numeric(ts_utc), origin = "1970-01-01", tz = "UTC")
  buffer$instrument_id[idx] <- as.character(instrument_id)
  buffer$side[idx] <- as.character(side)
  buffer$qty[idx] <- as.numeric(qty)
  buffer$price[idx] <- as.numeric(price)
  buffer$fee[idx] <- as.numeric(fee)
  buffer$realized_pnl[idx] <- as.numeric(realized_pnl)
  buffer$action[idx] <- as.character(action)
  buffer$n <- end
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

ledgr_fills_from_events <- function(events,
                                    pulses_posix,
                                    execution_opportunities_posix = NULL) {
  if (is.null(events) || nrow(events) == 0L) {
    return(ledgr_empty_fills_table())
  }
  instrument_ids <- unique(stats::na.omit(events$instrument_id))
  prepared <- ledgr_prepare_accounting_events(events, instrument_ids)
  replay <- ledgr_replay_accounting_events(prepared)
  ledgr_accounting_fills_from_replay(
    replay,
    pulses_posix,
    execution_opportunities_posix
  )
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
                                                    metric_kernel,
                                                    execution_opportunities_posix = NULL) {
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

  if (is.null(events) || nrow(events) == 0L) events <- ledgr_empty_event_table()
  ledgr_assert_events_in_fold_order(events)
  prepared <- ledgr_prepare_accounting_events(events, instrument_ids)
  replay <- ledgr_replay_accounting_events(prepared, initial_cash = initial_cash)
  equity <- ledgr_accounting_equity_from_replay(
    replay,
    pulses_posix,
    close_mat,
    initial_cash,
    instrument_ids,
    run_id
  )
  fills <- ledgr_accounting_fills_from_replay(
    replay,
    pulses_posix,
    execution_opportunities_posix
  )
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
