#' Configure causal history treatment
#'
#' `ledgr_history_policy()` records the experiment-level treatment choices
#' shared by causal history, feature preparation, pulse inspection and explicit
#' precomputation. The policy is part of experiment identity; worker and other
#' resource controls are not.
#'
#' @param price_carry Maximum age, in expected venue sessions, for causal
#'   price-input carry. The default is `5L`; `NULL` disables input carry.
#' @param output_carry Maximum age, in expected venue sessions, for output
#'   carry. `NULL` disables output carry.
#' @param segment_limit Optional positive whole-number override for the causal
#'   segment guard. `NULL` uses the implementation default.
#' @details Supplied ages and limits must fit in an R integer.
#'
#' @return A `ledgr_history_policy` object.
#' @section Articles:
#' Reading causal history:
#' `vignette("causal-history", package = "ledgr")`
#' `system.file("doc", "causal-history.html", package = "ledgr")`
#' @export
ledgr_history_policy <- function(price_carry = 5L,
                                 output_carry = NULL,
                                 segment_limit = NULL) {
  normalize_age <- function(value, argument, nullable) {
    if (is.null(value) && isTRUE(nullable)) return(NULL)
    if (!is.numeric(value) || length(value) != 1L || is.na(value) ||
        !is.finite(value) || value <= 0 || value != floor(value) ||
        value > .Machine$integer.max) {
      rlang::abort(
        sprintf(
          "`%s` must be NULL or a positive whole number no greater than %s.",
          argument,
          .Machine$integer.max
        ),
        class = c("ledgr_invalid_history_policy", "ledgr_invalid_args")
      )
    }
    as.integer(value)
  }

  structure(
    list(
      schema_version = ledgr_history_policy_schema_version,
      price_carry = normalize_age(price_carry, "price_carry", TRUE),
      output_carry = normalize_age(output_carry, "output_carry", TRUE),
      segment_limit = normalize_age(segment_limit, "segment_limit", TRUE)
    ),
    class = "ledgr_history_policy"
  )
}

ledgr_history_policy_schema_version <- 1L
ledgr_history_axis_rule_version <- 1L
ledgr_history_cutoff_rule_version <- 1L
ledgr_history_treatment_rule_version <- 1L

ledgr_history_policy_normalize <- function(policy) {
  if (!inherits(policy, "ledgr_history_policy") || !is.list(policy) ||
      !identical(policy$schema_version, ledgr_history_policy_schema_version)) {
    rlang::abort(
      "`history_policy` must be a current ledgr_history_policy object.",
      class = c("ledgr_invalid_history_policy", "ledgr_invalid_experiment")
    )
  }
  # Reconstructing through the public constructor both validates and removes
  # any unbound fields from identity.
  ledgr_history_policy(
    price_carry = policy$price_carry,
    output_carry = policy$output_carry,
    segment_limit = policy$segment_limit
  )
}

ledgr_history_policy_identity <- function(policy) {
  policy <- ledgr_history_policy_normalize(policy)
  list(
    policy_schema_version = policy$schema_version,
    axis_rule_version = ledgr_history_axis_rule_version,
    cutoff_rule_version = ledgr_history_cutoff_rule_version,
    treatment_rule_version = ledgr_history_treatment_rule_version,
    price_carry = policy$price_carry,
    output_carry = policy$output_carry,
    segment_limit = policy$segment_limit
  )
}

ledgr_history_identity_require_current <- function(history) {
  if (!is.list(history) ||
      !identical(history$policy_schema_version, ledgr_history_policy_schema_version) ||
      !identical(history$axis_rule_version, ledgr_history_axis_rule_version) ||
      !identical(history$cutoff_rule_version, ledgr_history_cutoff_rule_version) ||
      !identical(history$treatment_rule_version, ledgr_history_treatment_rule_version)) {
    rlang::abort(
      "Config field history must contain the current causal-history identity.",
      class = c("ledgr_history_identity_mismatch", "ledgr_invalid_config")
    )
  }
  invisible(ledgr_history_policy(
    price_carry = history$price_carry,
    output_carry = history$output_carry,
    segment_limit = history$segment_limit
  ))
}

# Disclosure rows for the history policy (LDG-3081): one row per bound field
# with its shown value and a default flag that is TRUE when the value equals
# the ledgr_history_policy() constructor default. Omission and an explicit
# default policy share identity, so the flag compares values, as the plan
# does for the valuation horizon.
ledgr_history_policy_disclosure <- function(policy) {
  policy <- ledgr_history_policy_normalize(policy)
  defaults <- ledgr_history_policy()
  sessions <- function(value) {
    if (is.null(value)) "off" else sprintf("%d session%s", value, if (value == 1L) "" else "s")
  }
  tibble::tibble(
    setting = c("history.price_carry", "history.output_carry", "history.segment_limit"),
    label = c("price carry", "output carry", "segment limit"),
    value = c(
      sessions(policy$price_carry),
      sessions(policy$output_carry),
      if (is.null(policy$segment_limit)) {
        "4 per fact, at least 16"
      } else {
        as.character(policy$segment_limit)
      }
    ),
    default = c(
      identical(policy$price_carry, defaults$price_carry),
      identical(policy$output_carry, defaults$output_carry),
      identical(policy$segment_limit, defaults$segment_limit)
    )
  )
}

# One display string for disclosure rows, with a marker on every field.
ledgr_history_policy_rows_display <- function(rows) {
  paste(
    sprintf(
      "%s %s (%s)", rows$label, rows$value,
      ifelse(rows$default, "default", "declared")
    ),
    collapse = "; "
  )
}

# The valuation stale-mark horizon (LDG-3081): its value with a marker, and
# the display that names it as such.
ledgr_valuation_horizon_value <- function(max_sessions, default) {
  max_sessions <- as.integer(max_sessions)
  sprintf(
    "%d session%s (%s)",
    max_sessions, if (identical(max_sessions, 1L)) "" else "s",
    if (isTRUE(default)) "default" else "declared"
  )
}

ledgr_valuation_horizon_display <- function(max_sessions, default) {
  paste("stale-mark horizon", ledgr_valuation_horizon_value(max_sessions, default))
}

#' @export
print.ledgr_history_policy <- function(x, ...) {
  x <- ledgr_history_policy_normalize(x)
  shown <- function(value) if (is.null(value)) "disabled" else as.character(value)
  cat("ledgr_history_policy\n")
  cat("====================\n")
  cat("Price carry: ", shown(x$price_carry), " expected sessions\n", sep = "")
  cat("Output carry: ", shown(x$output_carry), " expected sessions\n", sep = "")
  cat("Segment limit: ", if (is.null(x$segment_limit)) "default" else x$segment_limit, "\n", sep = "")
  invisible(x)
}
