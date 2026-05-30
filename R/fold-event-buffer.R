ledgr_event_buffer_initial_capacity <- function(max_events, initial_capacity = 1024L) {
  max_events <- ledgr_event_buffer_checked_capacity(max_events, "`max_events`")
  initial_capacity <- ledgr_event_buffer_checked_capacity(initial_capacity, "`initial_capacity`")
  as.integer(max(1L, min(max_events, initial_capacity)))
}

ledgr_event_buffer_next_capacity <- function(current_capacity,
                                             required,
                                             max_events,
                                             initial_capacity = 1024L,
                                             growth_factor = 2) {
  current_capacity <- as.integer(max(0L, current_capacity %||% 0L))
  required <- ledgr_event_buffer_checked_capacity(required, "`required`")
  max_events <- ledgr_event_buffer_checked_capacity(max_events, "`max_events`")
  if (required > max_events) {
    rlang::abort(
      "Ledger event buffer exceeded the run's maximum event capacity.",
      class = "ledgr_event_buffer_capacity_exceeded"
    )
  }
  if (required <= current_capacity) {
    return(as.integer(current_capacity))
  }
  if (!is.numeric(growth_factor) || length(growth_factor) != 1L || is.na(growth_factor) ||
      !is.finite(growth_factor) || growth_factor <= 1) {
    rlang::abort("`growth_factor` must be a finite numeric scalar > 1.", class = "ledgr_invalid_args")
  }
  capacity <- max(current_capacity, ledgr_event_buffer_initial_capacity(max_events, initial_capacity))
  while (capacity < required) {
    grown <- ceiling(capacity * growth_factor)
    if (grown <= capacity) {
      grown <- capacity + 1L
    }
    capacity <- min(max_events, max(required, grown))
  }
  as.integer(capacity)
}

ledgr_event_buffer_checked_capacity <- function(x, label) {
  if (!is.numeric(x) || length(x) != 1L || is.na(x) || !is.finite(x) || x < 1 || x != floor(x)) {
    rlang::abort(sprintf("%s must be a positive integer-like scalar.", label), class = "ledgr_invalid_args")
  }
  if (x > .Machine$integer.max) {
    rlang::abort(sprintf("%s exceeds R's integer vector length limit.", label), class = "ledgr_invalid_args")
  }
  as.integer(x)
}

ledgr_opening_position_event_rows <- function(run_id,
                                              ts_utc,
                                              positions,
                                              cost_basis,
                                              event_seq_start) {
  if (length(positions) == 0L) {
    return(data.frame())
  }
  rows <- vector("list", length(positions))
  idx <- 0L
  event_seq <- event_seq_start
  for (instrument_id in names(positions)) {
    qty <- as.numeric(positions[[instrument_id]])
    if (!is.finite(qty) || qty == 0) {
      next
    }
    cb <- as.numeric(cost_basis[[instrument_id]] %||% NA_real_)
    if (!is.finite(cb)) {
      rlang::abort(
        paste0(
          "Opening position for instrument '", instrument_id,
          "' requires a finite cost basis."
        ),
        class = "ledgr_opening_cost_basis_missing"
      )
    }
    idx <- idx + 1L
    meta <- list(
      source = "opening_position",
      cash_delta = 0,
      position_delta = qty,
      cost_basis = cb,
      opening_position = TRUE
    )
    rows[[idx]] <- data.frame(
      event_id = paste0(run_id, "_", sprintf("%08d", event_seq)),
      run_id = run_id,
      ts_utc = as.POSIXct(ledgr_normalize_ts_utc(ts_utc), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"),
      event_type = "CASHFLOW",
      instrument_id = instrument_id,
      side = NA_character_,
      qty = qty,
      price = cb,
      fee = 0,
      meta_json = canonical_json(meta),
      event_seq = event_seq,
      stringsAsFactors = FALSE
    )
    event_seq <- event_seq + 1L
  }
  if (idx == 0L) {
    return(data.frame())
  }
  do.call(rbind, rows[seq_len(idx)])
}
