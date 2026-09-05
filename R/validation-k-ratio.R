#' K-Ratio diagnostic
#'
#' `ledgr_k_ratio()` computes the Kestner (2013) K-Ratio over each candidate
#' in a return panel. It uses compounded period returns, fits a linear trend to
#' cumulative log wealth, and applies the published observation-count and
#' periodicity adjustment. The result is evidence only: it does not select,
#' promote, filter, or change walk-forward identity.
#'
#' @param x A `ledgr_return_panel` object or a `ledgr_sweep_results` object with
#'   retained completed returns.
#' @param periods_per_year Finite positive numeric scalar giving the expected
#'   number of return observations in one calendar year. Supply this explicitly;
#'   ledgr does not infer annualization from optional panel labels.
#' @param candidates Optional character vector of candidate ids to include.
#' @param risk_free_return Finite scalar per-period risk-free return to subtract
#'   before compounding. It must be greater than -1. The default is zero.
#' @return A `ledgr_k_ratio` object with `summary` and `metadata`. Use
#'   `as_tibble(x)` for programmatic access.
#' @examples
#' returns <- data.frame(
#'   steady = c(0.010, 0.011, 0.009, 0.012),
#'   uneven = c(0.040, -0.030, 0.020, -0.015)
#' )
#' result <- ledgr_k_ratio(ledgr_return_panel(returns), periods_per_year = 12)
#' tibble::as_tibble(result)
#' @seealso `vignette("selection-integrity", package = "ledgr")` or
#'   `system.file("doc", "selection-integrity.html", package = "ledgr")`.
#' @export
ledgr_k_ratio <- function(x,
                          periods_per_year = NULL,
                          candidates = NULL,
                          risk_free_return = 0) {
  panel <- ledgr_return_panel_resolve(x, candidates = candidates)
  m <- panel$matrix
  ledgr_k_ratio_validate_matrix(m)
  periods_per_year <- ledgr_k_ratio_validate_periods_per_year(periods_per_year)
  risk_free_return <- ledgr_k_ratio_validate_risk_free(risk_free_return)

  rows <- lapply(seq_len(ncol(m)), function(j) {
    ledgr_k_ratio_candidate_row(
      returns = m[, j],
      candidate_id = colnames(m)[[j]],
      periods_per_year = periods_per_year,
      risk_free_return = risk_free_return
    )
  })
  summary <- tibble::as_tibble(do.call(rbind, rows))
  summary <- cbind(
    tibble::tibble(
      diagnostic = "k_ratio",
      schema_version = 1L,
      source = panel$source,
      panel_hash = panel$panel_hash,
      sweep_id = panel$sweep_id
    ),
    summary,
    tibble::tibble(
      value = panel$value,
      first_row_dropped = isTRUE(panel$first_row_dropped),
      complete_panel = isTRUE(panel$complete)
    )
  )

  out <- list(
    summary = summary,
    metadata = list(
      source = panel$source,
      diagnostic = "k_ratio",
      schema_version = 1L,
      native_version = "ledgr_k_ratio_kestner_2013_v1",
      variant = "kestner_2013_compounded",
      periods_per_year = periods_per_year,
      risk_free_return = risk_free_return,
      input_identity = panel$input_identity,
      panel = list(
        panel_hash = panel$panel_hash,
        value = panel$value,
        candidate_ids = panel$candidate_ids,
        completed_candidate_ids = panel$completed_candidate_ids,
        excluded_candidate_ids = panel$excluded_candidate_ids,
        labels = panel$labels,
        first_row_dropped = isTRUE(panel$first_row_dropped),
        complete = isTRUE(panel$complete)
      )
    )
  )
  class(out) <- c("ledgr_k_ratio", "list")
  out
}

#' @export
as_tibble.ledgr_k_ratio <- function(x, ...) {
  tibble::as_tibble(x$summary)
}

#' @export
print.ledgr_k_ratio <- function(x, ...) {
  if (!inherits(x, "ledgr_k_ratio")) {
    rlang::abort(
      "`x` must be a ledgr_k_ratio object.",
      class = "ledgr_invalid_args"
    )
  }
  summary <- tibble::as_tibble(x$summary)
  cat("# ledgr K-Ratio\n", sep = "")
  cat("# i variant: Kestner 2013, compounded returns\n", sep = "")
  cat(sprintf("# i candidates: %d\n", nrow(summary)), sep = "")
  cat(sprintf("# i periods per year: %s\n\n", format(summary$periods_per_year[[1L]])), sep = "")
  print(summary[, c(
    "candidate_id", "observations", "slope", "slope_std_error",
    "raw_k_ratio", "k_ratio"
  ), drop = FALSE], ...)
  invisible(x)
}

ledgr_k_ratio_validate_matrix <- function(m) {
  if (!is.matrix(m) || !is.numeric(m)) {
    rlang::abort(
      "K-Ratio requires a numeric return matrix.",
      class = c("ledgr_validation_k_ratio_invalid_returns", "ledgr_invalid_args")
    )
  }
  if (nrow(m) < 3L) {
    rlang::abort(
      "K-Ratio requires at least three return observations.",
      class = c("ledgr_validation_k_ratio_too_few_observations", "ledgr_invalid_args"),
      n_observations = nrow(m)
    )
  }
  if (anyNA(m) || any(!is.finite(m))) {
    rlang::abort(
      "K-Ratio requires finite period returns.",
      class = c("ledgr_validation_k_ratio_invalid_returns", "ledgr_invalid_args")
    )
  }
  invisible(TRUE)
}

ledgr_k_ratio_validate_periods_per_year <- function(periods_per_year) {
  if (!is.numeric(periods_per_year) ||
      length(periods_per_year) != 1L ||
      is.na(periods_per_year) ||
      !is.finite(periods_per_year) ||
      periods_per_year <= 0) {
    rlang::abort(
      "`periods_per_year` must be a finite positive numeric scalar.",
      class = c("ledgr_validation_k_ratio_invalid_periods_per_year", "ledgr_invalid_args")
    )
  }
  as.numeric(periods_per_year)
}

ledgr_k_ratio_validate_risk_free <- function(risk_free_return) {
  if (!is.numeric(risk_free_return) ||
      length(risk_free_return) != 1L ||
      is.na(risk_free_return) ||
      !is.finite(risk_free_return) ||
      risk_free_return <= -1) {
    rlang::abort(
      "`risk_free_return` must be a finite per-period return greater than -1.",
      class = c("ledgr_validation_k_ratio_invalid_risk_free", "ledgr_invalid_args")
    )
  }
  as.numeric(risk_free_return)
}

ledgr_k_ratio_candidate_row <- function(returns,
                                        candidate_id,
                                        periods_per_year,
                                        risk_free_return) {
  excess <- as.numeric(returns) - risk_free_return
  if (any(excess <= -1)) {
    rlang::abort(
      "K-Ratio compounded returns require every excess return to be greater than -1.",
      class = c("ledgr_validation_k_ratio_invalid_returns", "ledgr_invalid_args"),
      candidate_id = candidate_id
    )
  }

  observations <- length(excess)
  period_index <- seq.int(0, observations - 1L)
  cumulative_log_wealth <- cumsum(log1p(excess))
  centered_index <- period_index - mean(period_index)
  centered_wealth <- cumulative_log_wealth - mean(cumulative_log_wealth)
  index_sum_squares <- sum(centered_index^2)
  slope <- sum(centered_index * centered_wealth) / index_sum_squares
  intercept <- mean(cumulative_log_wealth) - slope * mean(period_index)
  residuals <- cumulative_log_wealth - (intercept + slope * period_index)
  residual_standard_error <- sqrt(sum(residuals^2) / (observations - 2L))
  slope_std_error <- residual_standard_error / sqrt(index_sum_squares)

  if (any(!is.finite(c(slope, residual_standard_error, slope_std_error))) ||
      slope_std_error <= .Machine$double.eps) {
    rlang::abort(
      "K-Ratio requires a cumulative log-wealth path with a finite, non-zero slope standard error.",
      class = c("ledgr_validation_k_ratio_invalid_returns", "ledgr_invalid_args"),
      candidate_id = candidate_id
    )
  }

  raw_k_ratio <- slope / slope_std_error
  k_ratio <- raw_k_ratio * sqrt(periods_per_year) / observations
  if (any(!is.finite(c(raw_k_ratio, k_ratio)))) {
    rlang::abort(
      "K-Ratio produced a non-finite value.",
      class = c("ledgr_validation_k_ratio_invalid_returns", "ledgr_invalid_args"),
      candidate_id = candidate_id
    )
  }

  tibble::tibble(
    candidate_id = candidate_id,
    observations = observations,
    periods_per_year = periods_per_year,
    risk_free_return = risk_free_return,
    cumulative_log_return = as.numeric(cumulative_log_wealth[[observations]]),
    slope = as.numeric(slope),
    slope_std_error = as.numeric(slope_std_error),
    raw_k_ratio = as.numeric(raw_k_ratio),
    k_ratio = as.numeric(k_ratio)
  )
}
