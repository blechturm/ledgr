#' Sweep-level PBO/CSCV diagnostic
#'
#' `ledgr_sweep_pbo()` computes a native Probability of Backtest Overfitting
#' (PBO) diagnostic using Combinatorially Symmetric Cross Validation (CSCV) over
#' retained completed-candidate return panels. It is an evidence surface only:
#' it does not select, promote, filter, or change walk-forward identity.
#'
#' @param sweep A `ledgr_sweep_results` object with retained completed returns.
#' @param candidates Optional character vector of candidate ids to include.
#' @param S Even positive number of contiguous CSCV subsets. `S` must divide the
#'   post-first-row return count.
#' @param metric Optional function that receives a numeric returns matrix and
#'   returns one finite numeric score per candidate column. Higher scores are
#'   treated as better. When `NULL`, mean period return is used.
#' @param metric_name Optional character scalar naming the metric in result
#'   metadata.
#' @param threshold Numeric logit threshold. PBO is the fraction of CSCV cases
#'   with `lambda <= threshold`.
#' @return A `ledgr_sweep_pbo` object with `summary`, `cases`, `degradation`,
#'   and `metadata` tables/lists. Use `as_tibble(x)`,
#'   `as_tibble(x, what = "cases")`, or
#'   `as_tibble(x, what = "degradation")` for programmatic access.
#' @examples
#' \dontrun{
#' pbo <- ledgr_sweep_pbo(sweep, S = 4)
#' as_tibble(pbo)
#' as_tibble(pbo, what = "cases")
#' }
#' @seealso `vignette("selection-integrity", package = "ledgr")` or
#'   `system.file("doc", "selection-integrity.html", package = "ledgr")`.
#' @export
ledgr_sweep_pbo <- function(sweep,
                            candidates = NULL,
                            S = 4L,
                            metric = NULL,
                            metric_name = NULL,
                            threshold = 0) {
  panel <- ledgr_sweep_returns_panel(
    sweep,
    candidates = candidates,
    value = "returns",
    complete = TRUE
  )
  m <- panel$matrix
  ledgr_sweep_pbo_validate_matrix(m)
  S <- ledgr_sweep_pbo_validate_s(S, nrow(m))
  threshold <- ledgr_sweep_pbo_validate_threshold(threshold)
  metric_info <- ledgr_sweep_pbo_metric(metric, substitute(metric), metric_name)

  cases <- ledgr_sweep_pbo_cases(
    m = m,
    S = S,
    metric = metric_info$fn,
    threshold = threshold
  )
  pbo <- mean(cases$lambda <= threshold)
  probability_not_overfit <- mean(cases$lambda > threshold)
  summary <- tibble::tibble(
    diagnostic = "pbo_cscv",
    schema_version = 1L,
    sweep_id = ledgr_sweep_pbo_sweep_id(sweep),
    pbo = as.numeric(pbo),
    probability_not_overfit = as.numeric(probability_not_overfit),
    threshold = threshold,
    S = S,
    n_cases = nrow(cases),
    n_observations = nrow(m),
    n_candidates = ncol(m),
    metric_name = metric_info$name,
    value = panel$value,
    first_row_dropped = isTRUE(panel$first_row_dropped),
    complete_panel = isTRUE(panel$complete),
    candidate_ids = list(panel$candidate_ids),
    completed_candidate_ids = list(panel$completed_candidate_ids),
    excluded_candidate_ids = list(panel$excluded_candidate_ids)
  )
  degradation <- cases[, c(
    "case", "winner_candidate_id", "oos_best_candidate_id",
    "in_sample_metric", "out_of_sample_metric", "metric_degradation",
    "lambda", "below_threshold"
  ), drop = FALSE]

  out <- list(
    summary = summary,
    cases = cases,
    degradation = degradation,
    metadata = list(
      source = "retained_sweep_returns",
      diagnostic = "pbo_cscv",
      schema_version = 1L,
      native_version = "ledgr_pbo_cscv_v1",
      metric_name = metric_info$name,
      threshold = threshold,
      S = S,
      panel = list(
        value = panel$value,
        candidate_ids = panel$candidate_ids,
        completed_candidate_ids = panel$completed_candidate_ids,
        excluded_candidate_ids = panel$excluded_candidate_ids,
        first_row_dropped = isTRUE(panel$first_row_dropped),
        complete = isTRUE(panel$complete)
      )
    )
  )
  class(out) <- c("ledgr_sweep_pbo", "list")
  out
}

#' @export
as_tibble.ledgr_sweep_pbo <- function(x,
                                      what = c("summary", "cases", "degradation"),
                                      ...) {
  what <- match.arg(what)
  tibble::as_tibble(x[[what]])
}

#' @export
print.ledgr_sweep_pbo <- function(x, ...) {
  if (!inherits(x, "ledgr_sweep_pbo")) {
    rlang::abort("`x` must be a ledgr_sweep_pbo object.", class = "ledgr_invalid_args")
  }
  summary <- tibble::as_tibble(x$summary)
  cat("# ledgr sweep PBO/CSCV\n", sep = "")
  cat(sprintf("# i pbo: %.4f\n", summary$pbo[[1L]]), sep = "")
  cat(sprintf("# i cases: %d\n", summary$n_cases[[1L]]), sep = "")
  cat(sprintf("# i candidates: %d\n", summary$n_candidates[[1L]]), sep = "")
  cat(sprintf("# i S: %d\n\n", summary$S[[1L]]), sep = "")
  print(summary[, c(
    "diagnostic", "pbo", "probability_not_overfit", "threshold",
    "S", "n_cases", "n_observations", "n_candidates", "metric_name"
  ), drop = FALSE], ...)
  cat("\nUse as_tibble(x, what = \"cases\") for CSCV case evidence.\n", sep = "")
  invisible(x)
}

ledgr_sweep_pbo_validate_matrix <- function(m) {
  if (!is.matrix(m) || !is.numeric(m)) {
    rlang::abort(
      "PBO requires a numeric retained-return matrix.",
      class = c("ledgr_validation_pbo_invalid_panel", "ledgr_invalid_args")
    )
  }
  if (ncol(m) < 2L) {
    rlang::abort(
      "PBO requires at least two completed candidates with retained returns.",
      class = c("ledgr_validation_pbo_too_few_candidates", "ledgr_invalid_args"),
      n_candidates = ncol(m)
    )
  }
  if (nrow(m) < 4L) {
    rlang::abort(
      "PBO requires at least four post-first-row return observations.",
      class = c("ledgr_validation_pbo_too_few_observations", "ledgr_invalid_args"),
      n_observations = nrow(m)
    )
  }
  if (anyNA(m) || any(!is.finite(m))) {
    rlang::abort(
      "PBO requires a finite complete retained-return matrix.",
      class = c("ledgr_validation_pbo_invalid_panel", "ledgr_invalid_args")
    )
  }
  invisible(TRUE)
}

ledgr_sweep_pbo_validate_s <- function(S, n_observations) {
  if (!is.numeric(S) ||
      length(S) != 1L ||
      is.na(S) ||
      !is.finite(S) ||
      S != as.integer(S)) {
    rlang::abort(
      "`S` must be a whole even number.",
      class = c("ledgr_validation_pbo_invalid_s", "ledgr_invalid_args")
    )
  }
  S <- as.integer(S)
  if (S < 2L || S %% 2L != 0L) {
    rlang::abort(
      "`S` must be an even whole number >= 2.",
      class = c("ledgr_validation_pbo_invalid_s", "ledgr_invalid_args"),
      S = S
    )
  }
  if (n_observations < S) {
    rlang::abort(
      "`S` cannot exceed the number of post-first-row return observations.",
      class = c("ledgr_validation_pbo_too_few_observations", "ledgr_invalid_args"),
      S = S,
      n_observations = n_observations
    )
  }
  if (n_observations %% S != 0L) {
    rlang::abort(
      "`S` must evenly divide the number of post-first-row return observations.",
      class = c("ledgr_validation_pbo_invalid_s", "ledgr_invalid_args"),
      S = S,
      n_observations = n_observations
    )
  }
  S
}

ledgr_sweep_pbo_validate_threshold <- function(threshold) {
  if (!is.numeric(threshold) ||
      length(threshold) != 1L ||
      is.na(threshold) ||
      !is.finite(threshold)) {
    rlang::abort(
      "`threshold` must be a finite numeric scalar.",
      class = c("ledgr_validation_pbo_invalid_threshold", "ledgr_invalid_args")
    )
  }
  as.numeric(threshold)
}

ledgr_sweep_pbo_metric <- function(metric, metric_expr, metric_name) {
  if (is.null(metric)) {
    fn <- function(x) colMeans(x, na.rm = FALSE)
    name <- "mean_return"
  } else {
    if (!is.function(metric)) {
      rlang::abort(
        "`metric` must be NULL or a function.",
        class = c("ledgr_validation_pbo_invalid_metric", "ledgr_invalid_args")
      )
    }
    fn <- metric
    name <- paste(deparse(metric_expr), collapse = " ")
  }
  if (!is.null(metric_name)) {
    if (!is.character(metric_name) ||
        length(metric_name) != 1L ||
        is.na(metric_name) ||
        !nzchar(metric_name)) {
      rlang::abort(
        "`metric_name` must be NULL or a non-empty character scalar.",
        class = c("ledgr_validation_pbo_invalid_metric", "ledgr_invalid_args")
      )
    }
    name <- metric_name
  }
  list(fn = fn, name = name)
}

ledgr_sweep_pbo_cases <- function(m, S, metric, threshold) {
  n_observations <- nrow(m)
  n_candidates <- ncol(m)
  subset_n <- n_observations / S
  combos <- utils::combn(S, S / 2L)
  out <- vector("list", ncol(combos))

  for (case_idx in seq_len(ncol(combos))) {
    in_subsets <- combos[, case_idx]
    out_subsets <- setdiff(seq_len(S), in_subsets)
    in_rows <- ledgr_sweep_pbo_subset_rows(in_subsets, subset_n)
    out_rows <- ledgr_sweep_pbo_subset_rows(out_subsets, subset_n)
    in_metric <- ledgr_sweep_pbo_eval_metric(metric, m[in_rows, , drop = FALSE])
    out_metric <- ledgr_sweep_pbo_eval_metric(metric, m[out_rows, , drop = FALSE])
    winner <- which.max(in_metric)
    oos_best <- which.max(out_metric)
    oos_rank <- rank(out_metric)[[winner]]
    omega_bar <- as.numeric(oos_rank / n_candidates)
    lambda <- log(omega_bar / (1 - omega_bar))
    out[[case_idx]] <- tibble::tibble(
      case = case_idx,
      in_sample_subsets = list(as.integer(in_subsets)),
      out_of_sample_subsets = list(as.integer(out_subsets)),
      in_sample_rows = list(as.integer(in_rows)),
      out_of_sample_rows = list(as.integer(out_rows)),
      winner_column = as.integer(winner),
      winner_candidate_id = colnames(m)[[winner]],
      oos_best_column = as.integer(oos_best),
      oos_best_candidate_id = colnames(m)[[oos_best]],
      oos_rank = as.numeric(oos_rank),
      omega_bar = omega_bar,
      lambda = as.numeric(lambda),
      in_sample_metric = as.numeric(in_metric[[winner]]),
      out_of_sample_metric = as.numeric(out_metric[[winner]]),
      metric_degradation = as.numeric(out_metric[[winner]] - in_metric[[winner]]),
      below_threshold = isTRUE(lambda <= threshold)
    )
  }

  do.call(rbind, out)
}

ledgr_sweep_pbo_subset_rows <- function(subsets, subset_n) {
  unlist(lapply(subsets, function(i) {
    start <- subset_n * i - subset_n + 1L
    end <- start + subset_n - 1L
    start:end
  }), use.names = FALSE)
}

ledgr_sweep_pbo_eval_metric <- function(metric, m) {
  values <- tryCatch(
    metric(m),
    error = function(e) {
      rlang::abort(
        "`metric` failed while scoring a CSCV slice.",
        class = c("ledgr_validation_pbo_invalid_metric", "ledgr_invalid_args"),
        parent = e
      )
    }
  )
  if (!is.numeric(values) ||
      is.list(values) ||
      length(values) != ncol(m) ||
      anyNA(values) ||
      any(!is.finite(values))) {
    rlang::abort(
      "`metric` must return one finite numeric score per candidate column.",
      class = c("ledgr_validation_pbo_invalid_metric", "ledgr_invalid_args")
    )
  }
  as.numeric(values)
}

ledgr_sweep_pbo_sweep_id <- function(sweep) {
  sweep_id <- attr(sweep, "sweep_id", exact = TRUE)
  if (is.character(sweep_id) && length(sweep_id) == 1L && !is.na(sweep_id)) {
    return(sweep_id)
  }
  NA_character_
}
