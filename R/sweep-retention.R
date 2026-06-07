ledgr_sweep_retention_schema_version <- 1L

#' Sweep retention policy
#'
#' `ledgr_sweep_retention()` creates a classed retention policy for
#' [ledgr_sweep()]. Retention controls which optional sweep evidence is kept in
#' memory or later persisted. It is not part of execution identity.
#'
#' @param returns Character scalar. `"none"` keeps the current scalar-only sweep
#'   output. `"completed"` requests retained net equity/return series for
#'   completed candidates once retained-series capture is available.
#' @return A `ledgr_sweep_retention` object.
#' @export
ledgr_sweep_retention <- function(returns = c("none", "completed")) {
  if (missing(returns)) {
    returns <- "none"
  }
  if (!is.character(returns) ||
      length(returns) != 1L ||
      is.na(returns) ||
      !returns %in% c("none", "completed")) {
    rlang::abort(
      "`returns` must be one of \"none\" or \"completed\".",
      class = c("ledgr_invalid_sweep_retention", "ledgr_invalid_args")
    )
  }
  structure(
    list(
      retention_schema_version = ledgr_sweep_retention_schema_version,
      returns = unname(returns)
    ),
    class = c("ledgr_sweep_retention", "list")
  )
}

ledgr_sweep_retention_normalize <- function(retain) {
  if (!inherits(retain, "ledgr_sweep_retention")) {
    rlang::abort(
      "`retain` must be created with ledgr_sweep_retention().",
      class = c("ledgr_invalid_sweep_retention", "ledgr_invalid_args")
    )
  }
  if (!is.list(retain) ||
      !identical(retain$retention_schema_version, ledgr_sweep_retention_schema_version) ||
      !is.character(retain$returns) ||
      length(retain$returns) != 1L ||
      is.na(retain$returns) ||
      !retain$returns %in% c("none", "completed")) {
    rlang::abort(
      "`retain` has an invalid ledgr sweep retention shape.",
      class = c("ledgr_invalid_sweep_retention", "ledgr_invalid_args")
    )
  }
  ledgr_sweep_retention(retain$returns)
}

ledgr_sweep_empty_returns <- function(include_sweep_id = TRUE) {
  out <- tibble::tibble(
    candidate_id = character(),
    candidate_row = integer(),
    ts_utc = as.POSIXct(character(), tz = "UTC"),
    equity = numeric(),
    period_return = numeric()
  )
  if (isTRUE(include_sweep_id)) {
    out <- tibble::tibble(sweep_id = character(), out)
  }
  out
}

ledgr_sweep_retained_returns_from_equity <- function(equity,
                                                     candidate_id,
                                                     candidate_row) {
  if (!is.data.frame(equity) || nrow(equity) == 0L) {
    return(ledgr_sweep_empty_returns(include_sweep_id = FALSE))
  }
  equity_values <- as.numeric(equity$equity)
  period_return <- c(NA_real_, compute_period_returns(equity_values))
  tibble::tibble(
    candidate_id = rep(as.character(candidate_id), nrow(equity)),
    candidate_row = rep(as.integer(candidate_row), nrow(equity)),
    ts_utc = as.POSIXct(equity$ts_utc, tz = "UTC"),
    equity = equity_values,
    period_return = period_return
  )
}

ledgr_sweep_collect_retained_returns <- function(results, sweep_id) {
  retained <- lapply(results, `[[`, "retained_returns")
  retained <- retained[!vapply(retained, is.null, logical(1))]
  retained <- retained[vapply(retained, nrow, integer(1)) > 0L]
  if (length(retained) == 0L) {
    return(ledgr_sweep_empty_returns(include_sweep_id = TRUE))
  }
  out <- tibble::as_tibble(do.call(rbind, retained))
  tibble::tibble(
    sweep_id = rep(as.character(sweep_id), nrow(out)),
    candidate_id = as.character(out$candidate_id),
    candidate_row = as.integer(out$candidate_row),
    ts_utc = as.POSIXct(out$ts_utc, tz = "UTC"),
    equity = as.numeric(out$equity),
    period_return = as.numeric(out$period_return)
  )
}

#' Retained sweep return series
#'
#' `ledgr_sweep_returns()` returns the retained long net portfolio equity and
#' adjacent-period return series for completed sweep candidates.
#'
#' @param x A `ledgr_sweep_results` object.
#' @param candidates Optional character vector of `candidate_id` values.
#' @return A tibble with `sweep_id`, `candidate_id`, `ts_utc`, `equity`, and
#'   `period_return`.
#' @export
ledgr_sweep_returns <- function(x, candidates = NULL) {
  ledgr_sweep_returns_resolve(x, candidates = candidates)
}

#' Retained sweep return or equity matrix
#'
#' `ledgr_sweep_returns_wide()` returns one wide tibble per call using retained
#' sweep return series.
#'
#' @param x A `ledgr_sweep_results` object.
#' @param candidates Optional character vector of `candidate_id` values.
#' @param value Value to widen. `"returns"` uses `period_return`; `"equity"`
#'   uses `equity`.
#' @return A tibble with `ts_utc` followed by one column per candidate.
#' @export
ledgr_sweep_returns_wide <- function(x,
                                     candidates = NULL,
                                     value = c("returns", "equity")) {
  value <- match.arg(value)
  long <- ledgr_sweep_returns_resolve(x, candidates = candidates)
  ids <- if (is.null(candidates)) {
    unique(as.character(long$candidate_id))
  } else {
    as.character(candidates)
  }
  ts_utc <- unique(as.POSIXct(long$ts_utc, tz = "UTC"))
  out <- tibble::tibble(ts_utc = ts_utc)
  value_col <- if (identical(value, "returns")) "period_return" else "equity"
  for (id in ids) {
    rows <- long[as.character(long$candidate_id) == id, , drop = FALSE]
    values <- rep(NA_real_, length(ts_utc))
    idx <- match(as.POSIXct(rows$ts_utc, tz = "UTC"), ts_utc)
    values[idx] <- as.numeric(rows[[value_col]])
    out[[id]] <- values
  }
  out
}

ledgr_sweep_returns_resolve <- function(x, candidates = NULL) {
  if (!inherits(x, "ledgr_sweep_results")) {
    rlang::abort("`x` must be a ledgr_sweep_results object.", class = "ledgr_invalid_args")
  }
  retain <- attr(x, "sweep_retention", exact = TRUE)
  returns <- attr(x, "sweep_returns", exact = TRUE)
  if (!inherits(retain, "ledgr_sweep_retention") ||
      !identical(retain$returns, "completed") ||
      is.null(returns)) {
    rlang::abort(
      "Sweep returns were not retained. Run ledgr_sweep(..., retain = ledgr_sweep_retention(\"completed\")) first.",
      class = c("ledgr_sweep_returns_unretained", "ledgr_invalid_args")
    )
  }
  candidates <- ledgr_sweep_returns_normalize_candidates(candidates)
  if (is.null(candidates)) {
    candidates_scope <- unique(as.character(x$candidate_id))
    returns <- ledgr_sweep_returns_filter_and_order(returns, candidates_scope)
  } else {
    ledgr_sweep_returns_validate_candidates(x, returns, candidates)
    returns <- ledgr_sweep_returns_filter_and_order(returns, candidates)
  }
  ledgr_sweep_returns_public_columns(returns)
}

ledgr_sweep_returns_filter_and_order <- function(returns, candidates) {
  if (length(candidates) == 0L) {
    return(returns[FALSE, , drop = FALSE])
  }
  returns <- returns[as.character(returns$candidate_id) %in% candidates, , drop = FALSE]
  id_order <- match(as.character(returns$candidate_id), candidates)
  ts_order <- order(id_order, as.POSIXct(returns$ts_utc, tz = "UTC"))
  returns[ts_order, , drop = FALSE]
}

ledgr_sweep_returns_public_columns <- function(returns) {
  out <- tibble::as_tibble(returns)
  out <- out[, c("sweep_id", "candidate_id", "ts_utc", "equity", "period_return"), drop = FALSE]
  out$ts_utc <- as.POSIXct(out$ts_utc, tz = "UTC")
  out$equity <- as.numeric(out$equity)
  out$period_return <- as.numeric(out$period_return)
  out
}

ledgr_sweep_returns_normalize_candidates <- function(candidates) {
  if (is.null(candidates)) {
    return(NULL)
  }
  if (!is.character(candidates) ||
      length(candidates) < 1L ||
      anyNA(candidates) ||
      any(!nzchar(candidates))) {
    rlang::abort("`candidates` must be NULL or a non-empty character vector.", class = "ledgr_invalid_args")
  }
  as.character(candidates)
}

ledgr_sweep_returns_validate_candidates <- function(x, returns, candidates) {
  known <- as.character(x$candidate_id)
  missing <- setdiff(candidates, known)
  if (length(missing) > 0L) {
    rlang::abort(
      sprintf("Unknown sweep candidate_id: %s.", paste(missing, collapse = ", ")),
      class = c("ledgr_sweep_returns_candidate_not_found", "ledgr_invalid_args")
    )
  }
  status <- stats::setNames(as.character(x$status), known)
  not_completed <- candidates[status[candidates] != "DONE"]
  if (length(not_completed) > 0L) {
    rlang::abort(
      sprintf("Retained returns are available only for completed candidates: %s.", paste(not_completed, collapse = ", ")),
      class = c("ledgr_sweep_returns_candidate_not_completed", "ledgr_invalid_args")
    )
  }
  retained_ids <- unique(as.character(returns$candidate_id))
  missing_retained <- setdiff(candidates, retained_ids)
  if (length(missing_retained) > 0L) {
    rlang::abort(
      sprintf("Retained returns are missing for completed candidate_id: %s.", paste(missing_retained, collapse = ", ")),
      class = c("ledgr_sweep_returns_candidate_not_completed", "ledgr_invalid_args")
    )
  }
  invisible(TRUE)
}

#' @export
`[.ledgr_sweep_results` <- function(x, i, j, drop = FALSE) {
  out <- NextMethod("[")
  if (!is.data.frame(out) || isTRUE(drop)) {
    return(out)
  }
  ledgr_sweep_results_restore(out, x)
}

ledgr_sweep_results_restore <- function(out, template) {
  attr_names <- c(
    "sweep_id", "snapshot_id", "snapshot_hash", "scoring_range", "universe",
    "master_seed", "seed_contract", "evaluation_scope", "strategy_hash",
    "strategy_name", "strategy_source_capture_method", "strategy_preflight",
    "feature_union", "feature_union_hash", "feature_engine_version",
    "candidate_features", "metric_context", "metric_context_hash",
    "metric_context_version", "cost_model_hash", "cost_plan_json",
    "sweep_retention", "execution_assumptions", "saved_sweep"
  )
  for (name in attr_names) {
    attr(out, name) <- attr(template, name, exact = TRUE)
  }
  attr(out, "sweep_returns") <- ledgr_sweep_returns_filter_to_result(
    attr(template, "sweep_returns", exact = TRUE),
    out
  )
  class(out) <- unique(c(
    intersect(c("ledgr_saved_sweep_results", "ledgr_sweep_results"), class(template)),
    class(out)
  ))
  out
}

ledgr_sweep_returns_filter_to_result <- function(returns, out) {
  if (!is.data.frame(returns) || !"candidate_id" %in% names(out)) {
    return(returns)
  }
  ledgr_sweep_returns_filter_and_order(returns, unique(as.character(out$candidate_id)))
}
