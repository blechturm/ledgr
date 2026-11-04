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

ledgr_event_buffer_setv <- function(columns, name, index, value) {
  if (!is.environment(columns)) {
    rlang::abort(
      "Event-buffer columns must be owned by an environment.",
      class = "ledgr_invalid_state"
    )
  }
  column <- columns[[name]]
  index <- as.integer(index)
  if (length(index) < 1L || anyNA(index) || any(index < 1L) || any(index > length(column))) {
    rlang::abort("Event-buffer write index is outside allocated storage.", class = "ledgr_invalid_state")
  }

  if (is.list(column)) {
    if (!is.list(value) || length(value) != length(index)) {
      rlang::abort("List event-buffer writes require one list element per index.", class = "ledgr_invalid_state")
    }
    collapse::setv(column, index, value, vind1 = TRUE, xlist = TRUE)
    return(invisible(TRUE))
  }

  value <- if (inherits(column, "POSIXct")) {
    as.POSIXct(value, tz = "UTC")
  } else if (is.character(column)) {
    as.character(value)
  } else if (is.integer(column)) {
    as.integer(value)
  } else if (is.logical(column)) {
    as.logical(value)
  } else {
    as.numeric(value)
  }
  if (length(value) != length(index)) {
    rlang::abort("Event-buffer writes require one value per index.", class = "ledgr_invalid_state")
  }
  collapse::setv(column, index, value, vind1 = TRUE)
  invisible(TRUE)
}

ledgr_opening_position_event_rows <- function(run_id,
                                              ts_utc,
                                              positions,
                                              cost_basis,
                                              event_seq_start,
                                              lots = NULL) {
  # A carried test window opens with its predecessor's FIFO lots, one opening
  # row per lot in lot order, so a ledger replay rebuilds the same lots.
  if (!is.null(lots) && length(lots$instrument_id) > 0L) {
    positions <- stats::setNames(as.numeric(lots$qty), as.character(lots$instrument_id))
    cost_basis <- as.numeric(lots$price)
  } else {
    lots <- NULL
  }
  if (length(positions) == 0L) {
    return(data.frame())
  }
  qty <- as.numeric(positions)
  keep <- is.finite(qty) & qty != 0
  if (!any(keep)) {
    return(data.frame())
  }
  instrument_id <- names(positions)[keep]
  qty <- qty[keep]
  cb <- if (is.null(lots)) {
    as.numeric(cost_basis[instrument_id])
  } else {
    as.numeric(cost_basis[keep])
  }
  bad <- which(!is.finite(cb))
  if (length(bad) > 0L) {
    rlang::abort(
      paste0(
        "Opening position for instrument '", instrument_id[[bad[[1L]]]],
        "' requires a finite cost basis."
      ),
      class = "ledgr_opening_cost_basis_missing"
    )
  }
  event_seq <- as.integer(event_seq_start) + seq_along(qty) - 1L
  ledgr_accounting_rows(
    event_id = paste0(run_id, "_", sprintf("%08d", event_seq)),
    run_id = rep(run_id, length(qty)),
    ts_utc = rep(as.POSIXct(
      ledgr_normalize_ts_utc(ts_utc), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"
    ), length(qty)),
    event_type = rep("CASHFLOW", length(qty)),
    instrument_id = instrument_id,
    qty = qty,
    price = cb,
    fee = rep(0, length(qty)),
    event_seq = event_seq,
    cash_delta = rep(0, length(qty)),
    position_delta = qty,
    source = rep("opening_position", length(qty))
  )
}
