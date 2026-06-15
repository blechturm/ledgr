#' Sweep candidate clustering diagnostic
#'
#' `ledgr_sweep_cluster()` clusters retained completed-candidate return series
#' with one deterministic hierarchical method. The effective independent trial
#' count is the number of clusters at `distance_threshold`; it is evidence for
#' selection-integrity diagnostics, not a selection rule.
#'
#' @param sweep A `ledgr_sweep_results` object with retained completed returns.
#' @param candidates Optional character vector of candidate ids to include.
#' @param distance_threshold Numeric scalar in `[0, 2]`. Distances are
#'   `1 - correlation` over retained return columns.
#' @return A `ledgr_sweep_cluster` object with `summary`, `membership`,
#'   `distances`, and `metadata`.
#' @examples
#' \dontrun{
#' clusters <- ledgr_sweep_cluster(sweep)
#' as_tibble(clusters)
#' as_tibble(clusters, what = "membership")
#' }
#' @seealso `vignette("selection-integrity", package = "ledgr")` or
#'   `system.file("doc", "selection-integrity.html", package = "ledgr")`.
#' @export
ledgr_sweep_cluster <- function(sweep,
                                candidates = NULL,
                                distance_threshold = 0.5) {
  panel <- ledgr_sweep_returns_panel(
    sweep,
    candidates = candidates,
    value = "returns",
    complete = TRUE
  )
  m <- panel$matrix
  ledgr_sweep_cluster_validate_matrix(m)
  distance_threshold <- ledgr_sweep_cluster_validate_threshold(distance_threshold)

  correlation <- stats::cor(m)
  if (anyNA(correlation) || any(!is.finite(correlation))) {
    rlang::abort(
      "Clustering requires finite return correlations; constant return series cannot be clustered.",
      class = c("ledgr_validation_cluster_invalid_returns", "ledgr_invalid_args")
    )
  }
  correlation[] <- pmax(-1, pmin(1, correlation))
  distance_matrix <- 1 - correlation
  diag(distance_matrix) <- 0
  hc <- stats::hclust(stats::as.dist(distance_matrix), method = "complete")
  raw_cluster <- as.integer(stats::cutree(hc, h = distance_threshold))
  cluster_index <- match(raw_cluster, unique(raw_cluster))

  membership <- tibble::tibble(
    candidate_id = colnames(m),
    cluster_index = as.integer(cluster_index),
    cluster_id = sprintf("cluster_%03d", as.integer(cluster_index))
  )
  effective_trials <- length(unique(cluster_index))
  identity <- ledgr_validation_sweep_identity(sweep)
  summary <- tibble::tibble(
    diagnostic = "effective_trial_clustering",
    schema_version = 1L,
    sweep_id = identity$sweep_id,
    effective_trials = as.integer(effective_trials),
    raw_trials = ncol(m),
    method = "hierarchical_correlation_complete",
    distance = "1 - correlation",
    distance_threshold = distance_threshold,
    n_observations = nrow(m),
    value = panel$value,
    first_row_dropped = isTRUE(panel$first_row_dropped),
    complete_panel = isTRUE(panel$complete),
    candidate_ids = list(panel$candidate_ids),
    completed_candidate_ids = list(panel$completed_candidate_ids),
    excluded_candidate_ids = list(panel$excluded_candidate_ids),
    metric_context_hash = identity$metric_context_hash,
    cost_model_hash = identity$cost_model_hash,
    risk_chain_hash = identity$risk_chain_hash
  )

  out <- list(
    summary = summary,
    membership = membership,
    distances = ledgr_sweep_cluster_distances(correlation, distance_matrix),
    metadata = list(
      source = "retained_sweep_returns",
      diagnostic = "effective_trial_clustering",
      schema_version = 1L,
      native_version = "ledgr_effective_trial_cluster_v1",
      method = "hierarchical_correlation_complete",
      method_params = list(
        distance = "1 - correlation",
        linkage = "complete",
        distance_threshold = distance_threshold
      ),
      input_identity = identity,
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
  class(out) <- c("ledgr_sweep_cluster", "list")
  out
}

#' @export
as_tibble.ledgr_sweep_cluster <- function(x,
                                          what = c("summary", "membership", "distances"),
                                          ...) {
  what <- match.arg(what)
  tibble::as_tibble(x[[what]])
}

#' @export
print.ledgr_sweep_cluster <- function(x, ...) {
  if (!inherits(x, "ledgr_sweep_cluster")) {
    rlang::abort("`x` must be a ledgr_sweep_cluster object.", class = "ledgr_invalid_args")
  }
  summary <- tibble::as_tibble(x$summary)
  cat("# ledgr sweep effective-trial clustering\n", sep = "")
  cat(sprintf("# i effective trials: %d\n", summary$effective_trials[[1L]]), sep = "")
  cat(sprintf("# i raw trials: %d\n", summary$raw_trials[[1L]]), sep = "")
  cat(sprintf("# i distance threshold: %.4f\n\n", summary$distance_threshold[[1L]]), sep = "")
  print(tibble::as_tibble(x$membership), ...)
  invisible(x)
}

#' Sweep-level deflated Sharpe ratio diagnostic
#'
#' `ledgr_sweep_dsr()` computes a native Deflated Sharpe Ratio (DSR)
#' diagnostic over retained completed-candidate return panels. It is an
#' evidence surface only: it does not select, promote, filter, or change
#' walk-forward identity.
#'
#' @param sweep A `ledgr_sweep_results` object with retained completed returns.
#' @param candidates Optional character vector of candidate ids to include.
#' @param effective_trials Optional whole-number effective independent trial
#'   count. When `NULL`, ledgr derives it from [ledgr_sweep_cluster()].
#' @param distance_threshold Numeric scalar in `[0, 2]` passed to
#'   [ledgr_sweep_cluster()] when `effective_trials` is `NULL`.
#' @param confidence Numeric scalar in `(0, 1)` used for the `significant`
#'   status flag.
#' @param risk_free_return Numeric scalar per-period risk-free return to
#'   subtract before computing Sharpe.
#' @return A `ledgr_sweep_dsr` object with `summary` and `metadata`.
#' @examples
#' \dontrun{
#' dsr <- ledgr_sweep_dsr(sweep)
#' as_tibble(dsr)
#' }
#' @seealso `vignette("selection-integrity", package = "ledgr")` or
#'   `system.file("doc", "selection-integrity.html", package = "ledgr")`.
#' @export
ledgr_sweep_dsr <- function(sweep,
                            candidates = NULL,
                            effective_trials = NULL,
                            distance_threshold = 0.5,
                            confidence = 0.95,
                            risk_free_return = 0) {
  panel <- ledgr_sweep_returns_panel(
    sweep,
    candidates = candidates,
    value = "returns",
    complete = TRUE
  )
  m <- panel$matrix
  ledgr_sweep_dsr_validate_matrix(m)
  confidence <- ledgr_sweep_dsr_validate_confidence(confidence)
  risk_free_return <- ledgr_sweep_dsr_validate_risk_free(risk_free_return)

  cluster <- NULL
  effective_trials_source <- "explicit"
  if (is.null(effective_trials)) {
    cluster <- ledgr_sweep_cluster(
      sweep,
      candidates = candidates,
      distance_threshold = distance_threshold
    )
    effective_trials <- tibble::as_tibble(cluster)$effective_trials[[1L]]
    effective_trials_source <- "clustered"
  }
  effective_trials <- ledgr_sweep_dsr_validate_effective_trials(
    effective_trials,
    raw_trials = ncol(m)
  )

  candidate_sharpes <- vapply(seq_len(ncol(m)), function(k) {
    ledgr_sweep_dsr_sharpe(m[, k], risk_free_return = risk_free_return)
  }, numeric(1))
  if (anyNA(candidate_sharpes) || any(!is.finite(candidate_sharpes))) {
    rlang::abort(
      "DSR requires non-constant retained returns for every completed candidate.",
      class = c("ledgr_validation_dsr_invalid_returns", "ledgr_invalid_args")
    )
  }
  variance_sharpe <- stats::var(candidate_sharpes)

  rows <- lapply(seq_len(ncol(m)), function(j) {
    ledgr_sweep_dsr_candidate_row(
      returns = m[, j],
      candidate_id = colnames(m)[[j]],
      effective_trials = effective_trials,
      raw_trials = ncol(m),
      variance_sharpe = variance_sharpe,
      confidence = confidence,
      risk_free_return = risk_free_return
    )
  })
  summary <- tibble::as_tibble(do.call(rbind, rows))
  identity <- ledgr_validation_sweep_identity(sweep)
  summary <- cbind(
    tibble::tibble(
      diagnostic = "deflated_sharpe_ratio",
      schema_version = 1L,
      sweep_id = identity$sweep_id
    ),
    summary,
    tibble::tibble(
      effective_trials_source = effective_trials_source,
      value = panel$value,
      first_row_dropped = isTRUE(panel$first_row_dropped),
      complete_panel = isTRUE(panel$complete),
      metric_context_hash = identity$metric_context_hash,
      cost_model_hash = identity$cost_model_hash,
      risk_chain_hash = identity$risk_chain_hash
    )
  )

  out <- list(
    summary = summary,
    metadata = list(
      source = "retained_sweep_returns",
      diagnostic = "deflated_sharpe_ratio",
      schema_version = 1L,
      native_version = "ledgr_dsr_v1",
      confidence = confidence,
      risk_free_return = risk_free_return,
      effective_trials = effective_trials,
      effective_trials_source = effective_trials_source,
      cluster = if (is.null(cluster)) NULL else list(
        summary = cluster$summary,
        membership = cluster$membership
      ),
      input_identity = identity,
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
  class(out) <- c("ledgr_sweep_dsr", "list")
  out
}

#' @export
as_tibble.ledgr_sweep_dsr <- function(x, ...) {
  tibble::as_tibble(x$summary)
}

#' @export
print.ledgr_sweep_dsr <- function(x, ...) {
  if (!inherits(x, "ledgr_sweep_dsr")) {
    rlang::abort("`x` must be a ledgr_sweep_dsr object.", class = "ledgr_invalid_args")
  }
  summary <- tibble::as_tibble(x$summary)
  cat("# ledgr sweep deflated Sharpe ratio\n", sep = "")
  cat(sprintf("# i candidates: %d\n", nrow(summary)), sep = "")
  cat(sprintf("# i effective trials: %d\n", summary$effective_trials[[1L]]), sep = "")
  cat(sprintf("# i confidence: %.3f\n\n", summary$confidence[[1L]]), sep = "")
  print(summary[, c(
    "candidate_id", "observed_sharpe", "expected_max_sharpe",
    "dsr_probability", "p_value", "significant"
  ), drop = FALSE], ...)
  invisible(x)
}

ledgr_sweep_cluster_validate_matrix <- function(m) {
  if (!is.matrix(m) || !is.numeric(m)) {
    rlang::abort(
      "Clustering requires a numeric retained-return matrix.",
      class = c("ledgr_validation_cluster_invalid_returns", "ledgr_invalid_args")
    )
  }
  if (ncol(m) < 2L) {
    rlang::abort(
      "Clustering requires at least two completed candidates with retained returns.",
      class = c("ledgr_validation_cluster_too_few_candidates", "ledgr_invalid_args"),
      n_candidates = ncol(m)
    )
  }
  if (nrow(m) < 3L) {
    rlang::abort(
      "Clustering requires at least three post-first-row return observations.",
      class = c("ledgr_validation_cluster_too_few_observations", "ledgr_invalid_args"),
      n_observations = nrow(m)
    )
  }
  if (anyNA(m) || any(!is.finite(m))) {
    rlang::abort(
      "Clustering requires finite retained returns.",
      class = c("ledgr_validation_cluster_invalid_returns", "ledgr_invalid_args")
    )
  }
  constant <- vapply(seq_len(ncol(m)), function(j) {
    stats::sd(m[, j]) <= .Machine$double.eps
  }, logical(1))
  if (any(constant)) {
    rlang::abort(
      "Clustering requires non-constant retained returns.",
      class = c("ledgr_validation_cluster_invalid_returns", "ledgr_invalid_args"),
      candidate_ids = colnames(m)[constant]
    )
  }
  invisible(TRUE)
}

ledgr_sweep_cluster_validate_threshold <- function(distance_threshold) {
  if (!is.numeric(distance_threshold) ||
      length(distance_threshold) != 1L ||
      is.na(distance_threshold) ||
      !is.finite(distance_threshold) ||
      distance_threshold < 0 ||
      distance_threshold > 2) {
    rlang::abort(
      "`distance_threshold` must be a finite numeric scalar in [0, 2].",
      class = c("ledgr_validation_cluster_invalid_threshold", "ledgr_invalid_args")
    )
  }
  as.numeric(distance_threshold)
}

ledgr_sweep_cluster_distances <- function(correlation, distance_matrix) {
  ids <- colnames(correlation)
  pairs <- utils::combn(ids, 2L)
  rows <- lapply(seq_len(ncol(pairs)), function(i) {
    a <- pairs[1L, i]
    b <- pairs[2L, i]
    tibble::tibble(
      candidate_id_a = a,
      candidate_id_b = b,
      correlation = as.numeric(correlation[a, b]),
      distance = as.numeric(distance_matrix[a, b])
    )
  })
  tibble::as_tibble(do.call(rbind, rows))
}

ledgr_sweep_dsr_validate_matrix <- function(m) {
  if (!is.matrix(m) || !is.numeric(m)) {
    rlang::abort(
      "DSR requires a numeric retained-return matrix.",
      class = c("ledgr_validation_dsr_invalid_returns", "ledgr_invalid_args")
    )
  }
  if (ncol(m) < 2L) {
    rlang::abort(
      "DSR requires at least two completed candidates with retained returns.",
      class = c("ledgr_validation_dsr_too_few_candidates", "ledgr_invalid_args"),
      n_candidates = ncol(m)
    )
  }
  if (nrow(m) < 4L) {
    rlang::abort(
      "DSR requires at least four post-first-row return observations.",
      class = c("ledgr_validation_dsr_too_few_observations", "ledgr_invalid_args"),
      n_observations = nrow(m)
    )
  }
  if (anyNA(m) || any(!is.finite(m))) {
    rlang::abort(
      "DSR requires finite retained returns.",
      class = c("ledgr_validation_dsr_invalid_returns", "ledgr_invalid_args")
    )
  }
  constant <- vapply(seq_len(ncol(m)), function(j) {
    stats::sd(m[, j]) <= .Machine$double.eps
  }, logical(1))
  if (any(constant)) {
    rlang::abort(
      "DSR requires non-constant retained returns.",
      class = c("ledgr_validation_dsr_invalid_returns", "ledgr_invalid_args"),
      candidate_ids = colnames(m)[constant]
    )
  }
  invisible(TRUE)
}

ledgr_sweep_dsr_validate_confidence <- function(confidence) {
  if (!is.numeric(confidence) ||
      length(confidence) != 1L ||
      is.na(confidence) ||
      !is.finite(confidence) ||
      confidence <= 0 ||
      confidence >= 1) {
    rlang::abort(
      "`confidence` must be a finite numeric scalar in (0, 1).",
      class = c("ledgr_validation_dsr_invalid_confidence", "ledgr_invalid_args")
    )
  }
  as.numeric(confidence)
}

ledgr_sweep_dsr_validate_risk_free <- function(risk_free_return) {
  if (!is.numeric(risk_free_return) ||
      length(risk_free_return) != 1L ||
      is.na(risk_free_return) ||
      !is.finite(risk_free_return) ||
      risk_free_return <= -1) {
    rlang::abort(
      "`risk_free_return` must be a finite per-period return greater than -1.",
      class = c("ledgr_validation_dsr_invalid_risk_free", "ledgr_invalid_args")
    )
  }
  as.numeric(risk_free_return)
}

ledgr_sweep_dsr_validate_effective_trials <- function(effective_trials, raw_trials) {
  if (!is.numeric(effective_trials) ||
      length(effective_trials) != 1L ||
      is.na(effective_trials) ||
      !is.finite(effective_trials) ||
      effective_trials != as.integer(effective_trials)) {
    rlang::abort(
      "`effective_trials` must be a whole numeric scalar.",
      class = c("ledgr_validation_dsr_invalid_effective_trials", "ledgr_invalid_args")
    )
  }
  effective_trials <- as.integer(effective_trials)
  if (effective_trials < 2L || effective_trials > raw_trials) {
    rlang::abort(
      "`effective_trials` must be at least 2 and no larger than the number of completed candidates.",
      class = c("ledgr_validation_dsr_invalid_effective_trials", "ledgr_invalid_args"),
      effective_trials = effective_trials,
      raw_trials = raw_trials
    )
  }
  effective_trials
}

ledgr_sweep_dsr_sharpe <- function(returns, risk_free_return) {
  excess <- as.numeric(returns) - risk_free_return
  sd_excess <- stats::sd(excess)
  if (!is.finite(sd_excess) || sd_excess <= .Machine$double.eps) {
    return(NA_real_)
  }
  mean(excess) / sd_excess
}

ledgr_sweep_dsr_candidate_row <- function(returns,
                                          candidate_id,
                                          effective_trials,
                                          raw_trials,
                                          variance_sharpe,
                                          confidence,
                                          risk_free_return) {
  excess <- as.numeric(returns) - risk_free_return
  observations <- length(excess)
  sd_excess <- stats::sd(excess)
  centered <- excess - mean(excess)
  moment_2 <- mean(centered^2)
  if (!is.finite(sd_excess) ||
      sd_excess <= .Machine$double.eps ||
      !is.finite(moment_2) ||
      moment_2 <= .Machine$double.eps) {
    rlang::abort(
      "DSR requires non-constant retained returns.",
      class = c("ledgr_validation_dsr_invalid_returns", "ledgr_invalid_args"),
      candidate_id = candidate_id
    )
  }

  observed_sharpe <- mean(excess) / sd_excess
  skewness <- mean(centered^3) / moment_2^(3 / 2)
  kurtosis <- mean(centered^4) / moment_2^2
  if (any(!is.finite(c(observed_sharpe, skewness, kurtosis, variance_sharpe))) ||
      variance_sharpe < 0) {
    rlang::abort(
      "DSR could not compute finite return moments and trial variance.",
      class = c("ledgr_validation_dsr_invalid_returns", "ledgr_invalid_args"),
      candidate_id = candidate_id
    )
  }

  emc <- 0.5772156649
  expected_max_z <- (1 - emc) * stats::qnorm(1 - 1 / effective_trials) +
    emc * stats::qnorm(1 - 1 / (effective_trials * exp(1)))
  expected_max_sharpe <- sqrt(variance_sharpe) * expected_max_z
  denominator_term <- 1 - skewness * observed_sharpe +
    ((kurtosis - 1) / 4) * observed_sharpe^2
  if (!is.finite(denominator_term) || denominator_term <= 0) {
    rlang::abort(
      "DSR produced a non-positive denominator term.",
      class = c("ledgr_validation_dsr_invalid_returns", "ledgr_invalid_args"),
      candidate_id = candidate_id
    )
  }
  dsr_z <- (observed_sharpe - expected_max_sharpe) *
    sqrt(observations - 1) / sqrt(denominator_term)
  dsr_probability <- stats::pnorm(dsr_z)
  if (!is.finite(dsr_probability)) {
    rlang::abort(
      "DSR produced a non-finite probability.",
      class = c("ledgr_validation_dsr_invalid_returns", "ledgr_invalid_args"),
      candidate_id = candidate_id
    )
  }
  significant <- dsr_probability >= confidence
  tibble::tibble(
    candidate_id = candidate_id,
    observations = observations,
    observed_sharpe = as.numeric(observed_sharpe),
    skewness = as.numeric(skewness),
    kurtosis = as.numeric(kurtosis),
    variance_sharpe = as.numeric(variance_sharpe),
    expected_max_z = as.numeric(expected_max_z),
    expected_max_sharpe = as.numeric(expected_max_sharpe),
    effective_trials = as.integer(effective_trials),
    raw_trials = as.integer(raw_trials),
    confidence = confidence,
    risk_free_return = risk_free_return,
    dsr_z = as.numeric(dsr_z),
    dsr_probability = as.numeric(dsr_probability),
    p_value = as.numeric(1 - dsr_probability),
    deflated_sharpe = as.numeric(observed_sharpe * dsr_probability),
    significant = isTRUE(significant),
    status = if (isTRUE(significant)) "significant" else "not_significant"
  )
}

ledgr_validation_sweep_identity <- function(sweep) {
  list(
    sweep_id = ledgr_validation_scalar_attr(sweep, "sweep_id"),
    metric_context_hash = ledgr_validation_scalar_attr(sweep, "metric_context_hash"),
    cost_model_hash = ledgr_validation_scalar_attr(sweep, "cost_model_hash"),
    risk_chain_hash = ledgr_validation_scalar_attr(sweep, "risk_chain_hash")
  )
}

ledgr_validation_scalar_attr <- function(x, name) {
  value <- attr(x, name, exact = TRUE)
  if (is.character(value) && length(value) == 1L && !is.na(value) && nzchar(value)) {
    return(as.character(value))
  }
  NA_character_
}
