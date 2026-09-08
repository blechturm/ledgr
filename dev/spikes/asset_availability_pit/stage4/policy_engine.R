stage4_policy_target <- function(member,
                                 held_qty,
                                 requested_target,
                                 restriction_reason = "") {
  held <- is.finite(held_qty) && held_qty != 0
  restricted <- nzchar(restriction_reason)
  admissible <- if (restricted) {
    if (held) unique(c(held_qty, 0)) else 0
  } else {
    requested_target
  }
  accepted <- any(abs(requested_target - admissible) <= 1e-12)
  list(
    member = isTRUE(member),
    held = held,
    target_restricted = restricted,
    admissible_targets = admissible,
    accepted = accepted,
    target = if (accepted) requested_target else held_qty,
    reason_code = if (restricted) restriction_reason else ""
  )
}

stage4_policy_mark <- function(observation_state,
                               close,
                               prior_mark = NA_real_,
                               prior_age = NA_integer_,
                               held_qty = 0,
                               max_stale_age = 2L,
                               terminal_event = NA_character_) {
  if (!is.na(terminal_event) && nzchar(terminal_event)) {
    return(list(
      value = prior_mark, age = prior_age, source = "terminal_event",
      permissible = FALSE, stop_reason = "terminal_settlement_unsupported"
    ))
  }
  if (identical(observation_state, "accepted") && is.finite(close)) {
    return(list(
      value = close, age = 0L, source = "observed_close",
      permissible = TRUE, stop_reason = NA_character_
    ))
  }
  if (identical(observation_state, "expected_session_absence") &&
      is.finite(prior_mark) && held_qty != 0) {
    age <- as.integer(if (is.na(prior_age)) 1L else prior_age + 1L)
    permissible <- age <= max_stale_age
    return(list(
      value = prior_mark, age = age, source = "stale_mark",
      permissible = permissible,
      stop_reason = if (permissible) NA_character_ else
        "valuation_horizon_exhausted"
    ))
  }
  list(
    value = NA_real_, age = NA_integer_, source = "unavailable",
    permissible = held_qty == 0,
    stop_reason = if (held_qty == 0) NA_character_ else "valuation_unavailable"
  )
}

stage4_policy_fill <- function(intent_qty,
                               execution_price,
                               trading_status,
                               fixed_fee = 0) {
  if (intent_qty == 0) {
    return(list(
      status = "not_attempted", qty = 0L, price = NA_real_, fee = 0,
      cash_delta = 0, reason_code = ""
    ))
  }
  reasons <- character()
  status_reason <- stage3_status_fill_reason(trading_status)
  if (nzchar(status_reason)) reasons <- c(reasons, status_reason)
  if (!is.finite(execution_price)) reasons <- c(reasons, "execution_bar_missing")
  if (length(reasons) > 0L) {
    return(list(
      status = "no_fill", qty = 0L, price = NA_real_, fee = 0,
      cash_delta = 0, reason_code = paste(unique(reasons), collapse = "|")
    ))
  }
  qty <- abs(as.integer(intent_qty))
  side <- sign(intent_qty)
  list(
    status = "filled", qty = qty, price = execution_price, fee = fixed_fee,
    cash_delta = -side * qty * execution_price - fixed_fee,
    reason_code = ""
  )
}

stage4_policy_affordability <- function(opening_cash,
                                        proposals,
                                        tolerance = 1e-8) {
  stage3_affordability(opening_cash, proposals, tolerance)
}

stage4_policy_evidence_status <- function(stop_reason = NA_character_) {
  if (is.na(stop_reason) || !nzchar(stop_reason)) "complete" else "incomplete"
}

stage4_policy_stop_disposition <- function(stop_reason) {
  status <- stage4_policy_evidence_status(stop_reason)
  list(
    evidence_status = status,
    selection_eligible = identical(status, "complete"),
    strategy_invoked = identical(status, "complete"),
    risk_invoked = identical(status, "complete"),
    fill_proposals = if (identical(status, "complete")) NA_integer_ else 0L
  )
}

stage4_policy_max_weight <- function(targets, equity, marks, max_weight) {
  active <- abs(targets) > sqrt(.Machine$double.eps)
  missing <- names(targets)[active & !is.finite(marks)]
  if (length(missing) > 0L) {
    return(list(
      accepted = FALSE,
      targets = targets,
      stop_reason = "risk_mark_unavailable",
      stop_asset_id = missing[[1L]],
      stop_target = targets[[missing[[1L]]]],
      stop_risk_step = "max_weight"
    ))
  }
  list(
    accepted = TRUE,
    targets = stage3_apply_max_weight(targets, equity, marks, max_weight),
    stop_reason = NA_character_,
    stop_asset_id = NA_character_,
    stop_target = NA_real_,
    stop_risk_step = NA_character_
  )
}

stage4_policy_post_risk_valid <- function(strategy_targets, post_risk_targets) {
  zero <- abs(post_risk_targets) <= sqrt(.Machine$double.eps)
  same_sign <- sign(post_risk_targets) == sign(strategy_targets)
  no_larger <- abs(post_risk_targets) <=
    abs(strategy_targets) + sqrt(.Machine$double.eps)
  all(zero | (same_sign & no_larger))
}

stage4_provider_mark_series <- function(provider,
                                        case_id,
                                        asset_id,
                                        pulses,
                                        held_qty,
                                        max_stale_age = 2L) {
  rows <- stage4_provider_rows(provider)
  out <- vector("list", length(pulses))
  prior_mark <- NA_real_
  prior_age <- NA_integer_
  for (i in seq_along(pulses)) {
    time <- pulses[[i]]
    state_row <- stage4_latest_fact(
      rows, case_id, "observation_state", asset_id, time, time
    )
    close_row <- stage4_latest_fact(
      rows, case_id, "close", asset_id, time, time
    )
    terminal_row <- stage4_latest_fact(
      rows, case_id, "terminal_event", asset_id, time, time
    )
    state <- if (is.null(state_row)) "not_observed" else
      as.character(state_row$value[[1L]])
    close <- if (is.null(close_row) || close_row$event_time[[1L]] != time) {
      NA_real_
    } else {
      as.numeric(close_row$value[[1L]])
    }
    terminal <- if (is.null(terminal_row) ||
      terminal_row$event_time[[1L]] != time) NA_character_ else
      as.character(terminal_row$value[[1L]])
    mark <- stage4_policy_mark(
      state, close, prior_mark, prior_age, held_qty, max_stale_age, terminal
    )
    out[[i]] <- c(list(event_time = time, observation_state = state), mark)
    if (is.finite(mark$value)) prior_mark <- mark$value
    if (!is.na(mark$age)) prior_age <- mark$age
  }
  out
}
