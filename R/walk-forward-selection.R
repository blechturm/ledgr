ledgr_selection_rule_schema_version <- "v1"

#' Walk-forward scalar selection rules
#'
#' `ledgr_select_argmax()` and `ledgr_select_argmin()` create deterministic
#' scalar selection-rule value objects for walk-forward train-window scores.
#' V1 supports one classified scalar metric at a time. Composite, override,
#' top-N, stability-region, and arbitrary-function selectors are deferred.
#'
#' @param metric A single metric name.
#' @return A `ledgr_selection_rule` object.
#' @examples
#' ledgr_select_argmax("sharpe_ratio")
#' @export
ledgr_select_argmax <- function(metric) {
  ledgr_selection_rule(type_id = "argmax", metric = metric, direction = "max")
}

#' @rdname ledgr_select_argmax
#' @export
ledgr_select_argmin <- function(metric) {
  ledgr_selection_rule(type_id = "argmin", metric = metric, direction = "min")
}

#' @export
print.ledgr_selection_rule <- function(x, ...) {
  x <- ledgr_validate_selection_rule(x)
  cat("ledgr selection rule\n")
  cat("====================\n")
  cat("Type:   ", x$type_id, "\n", sep = "")
  cat("Metric: ", x$metric, "\n", sep = "")
  cat("Hash:   ", substr(x$selection_rule_hash, 1L, 12L), "\n", sep = "")
  invisible(x)
}

ledgr_selection_rule <- function(type_id, metric, direction) {
  if (!is.character(metric) || length(metric) != 1L || is.na(metric) || !nzchar(metric)) {
    rlang::abort("`metric` must be a non-empty character scalar.", class = "ledgr_walk_forward_invalid_selection_rule")
  }
  out <- structure(
    list(
      type_id = type_id,
      schema_version = ledgr_selection_rule_schema_version,
      metric = metric,
      direction = direction,
      selection_rule_hash = NA_character_
    ),
    class = c("ledgr_selection_rule", "list")
  )
  out$selection_rule_hash <- ledgr_selection_rule_hash(out)
  out
}

ledgr_selection_rule_payload <- function(rule) {
  rule <- ledgr_validate_selection_rule_shape(rule, check_hash = FALSE)
  list(
    type_id = rule$type_id,
    schema_version = rule$schema_version,
    metric = rule$metric,
    direction = rule$direction
  )
}

ledgr_selection_rule_hash <- function(rule) {
  digest::digest(as.character(canonical_json(ledgr_selection_rule_payload(rule))), algo = "sha256")
}

ledgr_validate_selection_rule <- function(rule) {
  ledgr_validate_selection_rule_shape(rule, check_hash = TRUE)
}

ledgr_validate_selection_rule_shape <- function(rule, check_hash = TRUE) {
  if (!inherits(rule, "ledgr_selection_rule") || !is.list(rule)) {
    rlang::abort("`selection_rule` must be created by ledgr_select_argmax() or ledgr_select_argmin().", class = "ledgr_walk_forward_invalid_selection_rule")
  }
  required <- c("type_id", "schema_version", "metric", "direction", "selection_rule_hash")
  if (!all(required %in% names(rule))) {
    rlang::abort("`selection_rule` has an invalid shape.", class = "ledgr_walk_forward_invalid_selection_rule")
  }
  if (!identical(rule$type_id, "argmax") && !identical(rule$type_id, "argmin")) {
    rlang::abort("`selection_rule$type_id` must be `argmax` or `argmin`.", class = "ledgr_walk_forward_invalid_selection_rule")
  }
  expected_direction <- if (identical(rule$type_id, "argmax")) "max" else "min"
  if (!identical(rule$direction, expected_direction)) {
    rlang::abort("`selection_rule$direction` does not match `selection_rule$type_id`.", class = "ledgr_walk_forward_invalid_selection_rule")
  }
  if (!identical(rule$schema_version, ledgr_selection_rule_schema_version)) {
    rlang::abort("`selection_rule` has an unsupported schema version.", class = "ledgr_walk_forward_invalid_selection_rule")
  }
  if (!is.character(rule$metric) || length(rule$metric) != 1L || is.na(rule$metric) || !nzchar(rule$metric)) {
    rlang::abort("`selection_rule$metric` must be a non-empty character scalar.", class = "ledgr_walk_forward_invalid_selection_rule")
  }
  if (isTRUE(check_hash)) {
    expected_hash <- ledgr_selection_rule_hash(rule)
    if (!identical(rule$selection_rule_hash, expected_hash)) {
      rlang::abort("`selection_rule$selection_rule_hash` does not match the canonical selection-rule payload.", class = "ledgr_walk_forward_invalid_selection_rule")
    }
  }
  rule
}

ledgr_metric_class_registry <- function() {
  c(
    annualized_return = "annualized",
    volatility = "annualized",
    sharpe_ratio = "ratio",
    win_rate = "rate",
    avg_trade = "length_invariant",
    total_return = "cumulative",
    final_equity = "level",
    max_drawdown = "path_dependent",
    n_trades = "count"
  )
}

ledgr_metric_class <- function(metric) {
  registry <- ledgr_metric_class_registry()
  class <- unname(registry[[metric]])
  if (is.null(class)) {
    rlang::abort(
      sprintf("Metric `%s` is not classified for walk-forward selection.", metric),
      class = "ledgr_walk_forward_metric_class_invalid"
    )
  }
  class
}

ledgr_metric_class_is_selectable <- function(class) {
  class %in% c("rate", "annualized", "ratio", "length_invariant")
}

ledgr_selection_rule_select <- function(rule, scores) {
  rule <- ledgr_validate_selection_rule(rule)
  if (!is.data.frame(scores)) {
    rlang::abort("`scores` must be a data frame.", class = "ledgr_invalid_args")
  }
  metric <- rule$metric
  if (!metric %in% names(scores)) {
    rlang::abort(
      sprintf("Metric `%s` is missing from the train-window score rows.", metric),
      class = "ledgr_walk_forward_metric_missing"
    )
  }
  metric_class <- ledgr_metric_class(metric)
  if (!ledgr_metric_class_is_selectable(metric_class)) {
    rlang::abort(
      sprintf("Metric `%s` has class `%s` and is not valid for v1 walk-forward selection.", metric, metric_class),
      class = "ledgr_walk_forward_metric_class_invalid"
    )
  }
  if (!"candidate_key" %in% names(scores)) {
    rlang::abort("Train-window score rows must include `candidate_key` for deterministic tie-breaking.", class = "ledgr_walk_forward_candidate_key_missing")
  }
  values <- as.numeric(scores[[metric]])
  eligible <- is.finite(values)
  if (!any(eligible)) {
    rlang::abort(
      sprintf("No finite eligible value exists for metric `%s`.", metric),
      class = "ledgr_walk_forward_no_selection"
    )
  }
  eligible_rows <- scores[eligible, , drop = FALSE]
  eligible_values <- values[eligible]
  best_value <- if (identical(rule$direction, "max")) {
    max(eligible_values)
  } else {
    min(eligible_values)
  }
  tied <- eligible_rows[eligible_values == best_value, , drop = FALSE]
  tied <- tied[order(as.character(tied$candidate_key)), , drop = FALSE]
  tied[1L, , drop = FALSE]
}
