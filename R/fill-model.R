ledgr_next_open_fill_proposal <- function(desired_qty_delta,
                                          next_bar = NULL,
                                          next_open_price = NULL,
                                          instrument_id = NULL,
                                          ts_utc = NULL,
                                          high = NA_real_,
                                          low = NA_real_,
                                          close = NA_real_,
                                          volume = NA_real_) {
  if (!is.numeric(desired_qty_delta) || length(desired_qty_delta) != 1 || is.na(desired_qty_delta) || !is.finite(desired_qty_delta)) {
    rlang::abort("`desired_qty_delta` must be a finite numeric scalar.", class = "ledgr_invalid_fill_input")
  }

  if (desired_qty_delta == 0) {
    return(structure(
      list(
        status = "NO_FILL",
        reason = "Zero delta quantity."
      ),
      class = "ledgr_fill_none"
    ))
  }

  if (is.null(next_bar) && is.null(next_open_price)) {
    return(structure(
      list(
        status = "NO_FILL",
        warn_code = "LEDGR_LAST_BAR_NO_FILL",
        reason = "No next bar available; fills cannot be simulated on the final pulse."
      ),
      class = "ledgr_fill_none"
    ))
  }

  open_label <- "`next_open_price`"
  if (!is.null(next_bar)) {
    if (!is.list(next_bar) && !is.data.frame(next_bar)) {
      rlang::abort("`next_bar` must be a one-row list or data.frame.", class = "ledgr_invalid_fill_input")
    }
    if (is.data.frame(next_bar)) {
      if (nrow(next_bar) != 1) {
        rlang::abort("`next_bar` must be a one-row data.frame.", class = "ledgr_invalid_fill_input")
      }
      next_bar <- as.list(next_bar)
    }
    instrument_id <- next_bar$instrument_id
    ts_utc <- next_bar$ts_utc
    open <- next_bar$open
    high <- next_bar$high
    low <- next_bar$low
    close <- next_bar$close
    volume <- next_bar$volume
    open_label <- "`next_bar$open`"
  } else {
    if (!is.numeric(next_open_price) || length(next_open_price) != 1 || is.na(next_open_price) || !is.finite(next_open_price) || next_open_price <= 0) {
      rlang::abort("`next_open_price` must be a finite numeric scalar > 0.", class = "ledgr_invalid_fill_input")
    }
    open <- next_open_price
  }

  if (!is.character(instrument_id) || length(instrument_id) != 1 || is.na(instrument_id) || !nzchar(instrument_id)) {
    rlang::abort("`instrument_id` must be a non-empty character scalar.", class = "ledgr_invalid_fill_input")
  }
  if (is.null(ts_utc)) {
    rlang::abort("`ts_utc` is required.", class = "ledgr_invalid_fill_input")
  }
  if (!is.numeric(open) || length(open) != 1 || is.na(open) || !is.finite(open) || open <= 0) {
    rlang::abort(sprintf("%s must be a finite numeric scalar > 0.", open_label), class = "ledgr_invalid_fill_input")
  }

  side <- if (desired_qty_delta > 0) "BUY" else "SELL"
  qty <- abs(as.numeric(desired_qty_delta))
  ts_exec_utc <- if (inherits(ts_utc, "POSIXt")) {
    ledgr_ts_utc_posix(ts_utc, label = "`next_bar$ts_utc`", class = "ledgr_invalid_fill_input")
  } else {
    ledgr_normalize_ts_utc(ts_utc)
  }

  execution_bar <- list(
    instrument_id = instrument_id,
    ts_utc = ts_exec_utc,
    open = as.numeric(open),
    high = ledgr_fill_optional_bar_numeric(high),
    low = ledgr_fill_optional_bar_numeric(low),
    close = ledgr_fill_optional_bar_numeric(close),
    volume = ledgr_fill_optional_bar_numeric(volume)
  )

  structure(
    list(
      instrument_id = instrument_id,
      side = side,
      qty = qty,
      ts_exec_utc = ts_exec_utc,
      execution_bar = execution_bar
    ),
    class = "ledgr_fill_proposal"
  )
}

ledgr_fill_optional_bar_numeric <- function(x) {
  if (is.null(x) || length(x) != 1 || is.na(x)) {
    return(NA_real_)
  }
  as.numeric(x)
}

ledgr_fill_context <- function(execution_bar) {
  if (!is.list(execution_bar) || is.null(execution_bar$instrument_id) ||
      is.null(execution_bar$ts_utc) || is.null(execution_bar$open)) {
    rlang::abort("`execution_bar` must include instrument_id, ts_utc, and open.", class = "ledgr_invalid_fill_context")
  }
  structure(
    list(
      execution_bar = execution_bar
    ),
    class = "ledgr_fill_context"
  )
}

ledgr_resolve_fill_proposal <- function(proposal, cost_resolver) {
  if (inherits(proposal, "ledgr_fill_none")) {
    return(proposal)
  }
  if (!inherits(proposal, "ledgr_fill_proposal")) {
    rlang::abort("`proposal` must be a ledgr_fill_proposal.", class = "ledgr_invalid_fill_proposal")
  }
  if (!is.function(cost_resolver)) {
    rlang::abort("`cost_resolver` must be a function.", class = "ledgr_invalid_fill_input")
  }
  context <- ledgr_fill_context(proposal$execution_bar)
  cost_resolver(proposal, context)
}
