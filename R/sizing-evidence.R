ledgr_sizing_evidence_rule_version <- 1L

.ledgr_sizing_reason_codes <- c(
  "sizing_rounded",
  "sizing_rounded_to_zero_addition",
  "sizing_rounded_to_zero_liquidation",
  "sizing_unavailable",
  "sizing_zero_target",
  "sizing_liquidation"
)

# Validate helper-owned sizing evidence at the strategy return boundary. The
# fold trusts no attribute supplied by user code merely because it carries the
# internal class: every column is checked against the current decision axis,
# normalized target, held quantity and accepted decision mark.
ledgr_validate_sizing_evidence <- function(x, targets, context_ids,
                                           position, mark) {
  if (is.null(x)) return(NULL)
  fields <- c(
    "instrument_id", "requested_quantity", "pre_floor_quantity",
    "rounded_quantity", "price", "position_before", "reason_code"
  )
  if (!inherits(x, "ledgr_sizing_evidence") || !is.list(x) ||
      !identical(names(x), fields)) {
    rlang::abort(
      "Strategy sizing evidence has an invalid shape.",
      class = "ledgr_invalid_strategy_result"
    )
  }
  n <- length(x$instrument_id)
  if (any(lengths(x) != n) || !is.character(x$instrument_id) ||
      anyNA(x$instrument_id) || any(!nzchar(x$instrument_id)) ||
      anyDuplicated(x$instrument_id)) {
    rlang::abort(
      "Strategy sizing evidence must have one uniquely named row per sized instrument.",
      class = "ledgr_invalid_strategy_result"
    )
  }
  k <- match(x$instrument_id, context_ids)
  if (anyNA(k)) {
    rlang::abort(
      "Strategy sizing evidence names an instrument outside the decision axis.",
      class = "ledgr_invalid_strategy_result"
    )
  }
  numeric_fields <- fields[2:6]
  if (any(!vapply(x[numeric_fields], is.numeric, logical(1)))) {
    rlang::abort(
      "Strategy sizing evidence quantity, price and position columns must be numeric.",
      class = "ledgr_invalid_strategy_result"
    )
  }
  if (!is.character(x$reason_code) || anyNA(x$reason_code) ||
      any(!x$reason_code %in% .ledgr_sizing_reason_codes)) {
    rlang::abort(
      "Strategy sizing evidence contains an invalid reason code.",
      class = "ledgr_invalid_strategy_result"
    )
  }
  unavailable <- x$reason_code == "sizing_unavailable"
  priced <- is.finite(x$price) & x$price > 0
  needs_price <- x$reason_code %in% c(
    "sizing_rounded",
    "sizing_rounded_to_zero_addition",
    "sizing_rounded_to_zero_liquidation"
  )
  if (any(!is.na(x$requested_quantity[unavailable])) ||
      any(!is.na(x$pre_floor_quantity[unavailable])) ||
      any(!is.na(x$price[unavailable])) ||
      any(!is.finite(x$rounded_quantity)) ||
      any(!is.finite(x$position_before)) ||
      any(!is.finite(x$requested_quantity[!unavailable])) ||
      any(!is.finite(x$pre_floor_quantity[!unavailable])) ||
      any(!priced[needs_price]) ||
      any(!is.na(x$price[!unavailable & !priced]))) {
    rlang::abort(
      "Strategy sizing evidence contains an invalid typed value.",
      class = "ledgr_invalid_strategy_result"
    )
  }
  same_number <- function(a, b) {
    identical(as.numeric(a), as.numeric(b))
  }
  unevidenced <- rep(TRUE, length(context_ids))
  unevidenced[k] <- FALSE
  if (!same_number(x$rounded_quantity, targets[k]) ||
      !same_number(x$position_before, position[k]) ||
      !same_number(x$price[priced], mark[k[priced]]) ||
      !same_number(targets[unevidenced], position[unevidenced])) {
    # Ordinary R transformations can preserve attributes while changing the
    # target values. The internal helper evidence is then stale, not an
    # invalid strategy result. Discard it and let the fold disclose that the
    # pulse's sizing intent is unavailable.
    return(NULL)
  }
  x
}

ledgr_sizing_summary_empty <- function() {
  list(
    available = FALSE,
    decision_clock = "accepted decision mark",
    currency = NA_character_,
    aggregation = "exposure-weighted across priced sizing rows",
    evidenced_decisions = 0L,
    unavailable_decisions = 0L,
    no_instruction_decisions = 0L,
    raw_intent_unavailable = FALSE,
    rounded_to_zero_instructions = 0L,
    pooled_coverage = NA_real_,
    minimum_decision_coverage = NA_real_,
    last_decision_coverage = NA_real_,
    requested_value_diagnostic = NA_real_,
    post_guard_value_diagnostic = NA_real_,
    rounded_value_diagnostic = NA_real_,
    rounding_difference_diagnostic = NA_real_,
    final_actual_invested_exposure = NA_real_,
    actual_exposure_clock = "final valued pulse"
  )
}

ledgr_run_sizing_summary <- function(bt, con = NULL) {
  if (!inherits(bt, "ledgr_backtest")) {
    rlang::abort("`bt` must be a ledgr_backtest object.", class = "ledgr_invalid_backtest")
  }
  opened <- if (is.null(con)) ledgr_backtest_read_connection(bt) else list(
    con = con, close = function() invisible(FALSE)
  )
  on.exit(opened$close(), add = TRUE)
  stored <- ledgr_diagnostic_summary_read(opened$con, bt$run_id)
  out <- ledgr_sizing_summary_empty()
  out$available <- isTRUE(stored$sizing_available[[1L]])
  out$raw_intent_unavailable <- isTRUE(stored$raw_intent_unavailable[[1L]])
  out$evidenced_decisions <- as.integer(stored$evidenced_decisions[[1L]])
  out$unavailable_decisions <- as.integer(stored$unavailable_decisions[[1L]])
  out$no_instruction_decisions <- as.integer(stored$no_instruction_decisions[[1L]])
  out$rounded_to_zero_instructions <- as.integer(stored$rounded_to_zero_instructions[[1L]])
  denominator <- stored$pooled_denominator[[1L]]
  out$pooled_coverage <- if (is.finite(denominator) && denominator > 0) {
    stored$pooled_numerator[[1L]] / denominator
  } else {
    NA_real_
  }
  out$minimum_decision_coverage <- stored$minimum_decision_coverage[[1L]]
  out$last_decision_coverage <- stored$last_decision_coverage[[1L]]
  out$requested_value_diagnostic <- stored$requested_value_diagnostic[[1L]]
  out$post_guard_value_diagnostic <- stored$post_guard_value_diagnostic[[1L]]
  out$rounded_value_diagnostic <- stored$rounded_value_diagnostic[[1L]]
  out$rounding_difference_diagnostic <-
    out$post_guard_value_diagnostic - out$rounded_value_diagnostic
  snapshot_id <- bt$config$data$snapshot_id
  currencies <- DBI::dbGetQuery(
    opened$con,
    "SELECT DISTINCT currency FROM snapshot_instruments WHERE snapshot_id = ? ORDER BY currency",
    params = list(snapshot_id)
  )$currency
  currencies <- currencies[!is.na(currencies) & nzchar(currencies)]
  out$currency <- if (length(currencies) == 1L) currencies else if (length(currencies) > 1L) {
    paste0("mixed (", paste(currencies, collapse = ", "), ")")
  } else {
    "not recorded"
  }
  final <- DBI::dbGetQuery(
    opened$con,
    paste(
      "SELECT positions_value, equity FROM equity_curve WHERE run_id = ?",
      "ORDER BY ts_utc DESC LIMIT 1"
    ),
    params = list(bt$run_id)
  )
  if (nrow(final) == 1L && is.finite(final$equity[[1L]]) && final$equity[[1L]] != 0) {
    out$final_actual_invested_exposure <- abs(final$positions_value[[1L]]) / abs(final$equity[[1L]])
  }
  out
}

ledgr_sizing_percent <- function(value) {
  if (length(value) != 1L || is.na(value) || !is.finite(value)) "N/A" else sprintf("%.2f%%", 100 * value)
}

ledgr_print_sizing_summary <- function(x, compact = FALSE) {
  if (isTRUE(compact)) {
    cat(sprintf("%-34s %s\n", "Sizing coverage (pooled):", ledgr_sizing_percent(x$pooled_coverage)))
    cat(sprintf("%-34s %s\n", "Final actual invested exposure:", ledgr_sizing_percent(x$final_actual_invested_exposure)))
    if (isTRUE(x$raw_intent_unavailable)) {
      cat(sprintf("%-34s %s\n", "Sizing intent coverage:", "unavailable (raw quantity targets)"))
    }
    return(invisible(x))
  }
  cat("\nSizing Evidence:\n")
  cat(sprintf("  Decision clock:                    %s\n", x$decision_clock))
  cat(sprintf("  Currency:                          %s\n", x$currency))
  cat(sprintf("  Aggregation:                       %s\n", x$aggregation))
  cat(sprintf("  Evidenced decisions (may overlap): %d\n", x$evidenced_decisions))
  cat(sprintf("  Decisions with unavailable intent: %d\n", x$unavailable_decisions))
  cat(sprintf("  Decisions with no sizing instruction: %d\n", x$no_instruction_decisions))
  cat(sprintf("  Rounded-to-zero instructions:      %d\n", x$rounded_to_zero_instructions))
  cat(sprintf("  Coverage (pooled):                 %s\n", ledgr_sizing_percent(x$pooled_coverage)))
  cat(sprintf("  Coverage (minimum decision):       %s\n", ledgr_sizing_percent(x$minimum_decision_coverage)))
  cat(sprintf("  Coverage (last decision):          %s\n", ledgr_sizing_percent(x$last_decision_coverage)))
  cat(sprintf("  Final actual invested exposure:    %s (%s)\n",
    ledgr_sizing_percent(x$final_actual_invested_exposure), x$actual_exposure_clock))
  cat("  Decision-exposure diagnostics (cross-decision sums; not portfolio exposure or P&L):\n")
  cat(sprintf("    Requested value:                 %s\n", format(x$requested_value_diagnostic, trim = TRUE)))
  cat(sprintf("    Post-guard pre-floor value:       %s\n", format(x$post_guard_value_diagnostic, trim = TRUE)))
  cat(sprintf("    Rounded value:                   %s\n", format(x$rounded_value_diagnostic, trim = TRUE)))
  cat(sprintf("    Rounding difference:             %s\n", format(x$rounding_difference_diagnostic, trim = TRUE)))
  invisible(x)
}
