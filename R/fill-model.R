ledgr_fill_next_open <- function(desired_qty_delta, next_bar, spread_bps, commission_fixed, price_round_digits = 8L) {
  proposal <- ledgr_next_open_fill_proposal(
    desired_qty_delta = desired_qty_delta,
    next_bar = next_bar
  )
  if (inherits(proposal, "ledgr_fill_none")) {
    return(proposal)
  }

  cost_resolver <- ledgr_cost_spread_commission_internal(
    spread_bps = spread_bps,
    commission_fixed = commission_fixed,
    price_round_digits = price_round_digits
  )
  ledgr_resolve_fill_proposal(proposal, cost_resolver)
}

ledgr_next_open_fill_proposal <- function(desired_qty_delta, next_bar) {
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

  if (is.null(next_bar)) {
    return(structure(
      list(
        status = "NO_FILL",
        warn_code = "LEDGR_LAST_BAR_NO_FILL",
        reason = "No next bar available; fills cannot be simulated on the final pulse."
      ),
      class = "ledgr_fill_none"
    ))
  }

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

  if (!is.character(instrument_id) || length(instrument_id) != 1 || is.na(instrument_id) || !nzchar(instrument_id)) {
    rlang::abort("`next_bar$instrument_id` must be a non-empty character scalar.", class = "ledgr_invalid_fill_input")
  }
  if (is.null(ts_utc)) {
    rlang::abort("`next_bar$ts_utc` is required.", class = "ledgr_invalid_fill_input")
  }
  if (!is.numeric(open) || length(open) != 1 || is.na(open) || !is.finite(open) || open <= 0) {
    rlang::abort("`next_bar$open` must be a finite numeric scalar > 0.", class = "ledgr_invalid_fill_input")
  }

  side <- if (desired_qty_delta > 0) "BUY" else "SELL"
  qty <- abs(as.numeric(desired_qty_delta))
  ts_exec_utc <- ledgr_normalize_ts_utc(ts_utc)

  execution_bar <- list(
    instrument_id = instrument_id,
    ts_utc = ts_exec_utc,
    open = as.numeric(open),
    high = ledgr_fill_optional_bar_numeric(next_bar$high),
    low = ledgr_fill_optional_bar_numeric(next_bar$low),
    close = ledgr_fill_optional_bar_numeric(next_bar$close),
    volume = ledgr_fill_optional_bar_numeric(next_bar$volume)
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

ledgr_cost_spread_commission_internal <- function(spread_bps, commission_fixed, price_round_digits = 8L) {
  if (!is.numeric(spread_bps) || length(spread_bps) != 1 || is.na(spread_bps) || !is.finite(spread_bps) || spread_bps < 0) {
    rlang::abort("`spread_bps` must be a finite numeric scalar >= 0.", class = "ledgr_invalid_fill_input")
  }
  if (!is.numeric(commission_fixed) || length(commission_fixed) != 1 || is.na(commission_fixed) || !is.finite(commission_fixed) || commission_fixed < 0) {
    rlang::abort("`commission_fixed` must be a finite numeric scalar >= 0.", class = "ledgr_invalid_fill_input")
  }
  if (!is.numeric(price_round_digits) || length(price_round_digits) != 1 || is.na(price_round_digits) || !is.finite(price_round_digits) ||
      price_round_digits < 0 || (price_round_digits %% 1) != 0) {
    rlang::abort("`price_round_digits` must be an integer >= 0.", class = "ledgr_invalid_fill_input")
  }

  force(spread_bps)
  force(commission_fixed)
  force(price_round_digits)
  resolver <- function(proposal, fill_context) {
    ledgr_default_cost_resolve(
      proposal = proposal,
      fill_context = fill_context,
      spread_bps = spread_bps,
      commission_fixed = commission_fixed,
      price_round_digits = price_round_digits
    )
  }
  structure(
    resolver,
    class = c("ledgr_cost_resolver", "function")
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

ledgr_default_cost_resolve <- function(proposal,
                                       fill_context,
                                       spread_bps,
                                       commission_fixed,
                                       price_round_digits = 8L) {
  if (!inherits(proposal, "ledgr_fill_proposal")) {
    rlang::abort("`proposal` must be a ledgr_fill_proposal.", class = "ledgr_invalid_fill_proposal")
  }
  if (!inherits(fill_context, "ledgr_fill_context")) {
    rlang::abort("`fill_context` must be a ledgr_fill_context.", class = "ledgr_invalid_fill_context")
  }

  side <- proposal$side
  qty <- proposal$qty
  instrument_id <- proposal$instrument_id
  ts_exec_utc <- proposal$ts_exec_utc
  open <- fill_context$execution_bar$open

  # Spec v0.1.0: next-open fill uses full spread_bps adjustment.
  multiplier <- if (side == "BUY") (1 + spread_bps / 10000) else (1 - spread_bps / 10000)
  fill_price <- round(open * multiplier, digits = as.integer(price_round_digits))

  structure(
    list(
      instrument_id = instrument_id,
      side = side,
      qty = qty,
      fill_price = fill_price,
      commission_fixed = as.numeric(commission_fixed),
      ts_exec_utc = ts_exec_utc
    ),
    class = "ledgr_fill_intent"
  )
}
