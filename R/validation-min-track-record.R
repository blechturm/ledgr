#' Sweep-level minimum track record length diagnostic
#'
#' `ledgr_sweep_min_track_record()` computes the minimum track record length
#' (MinTRL) diagnostic over retained completed-candidate return panels. It is an
#' evidence surface only: it does not select, promote, filter, or change
#' walk-forward identity.
#'
#' @param sweep A `ledgr_sweep_results` object with retained completed returns.
#' @param candidates Optional character vector of candidate ids to include.
#' @param reference_sharpe Numeric scalar reference Sharpe ratio in the same
#'   per-period units as the retained return series. The default asks whether
#'   the observed Sharpe is significantly above zero.
#' @param confidence Numeric scalar confidence level in `(0, 1)`.
#' @param risk_free_return Numeric scalar per-period risk-free return to
#'   subtract before computing Sharpe. The default is zero.
#' @return A `ledgr_sweep_min_track_record` object with `summary` and
#'   `metadata`. Use `as_tibble(x)` for programmatic access.
#' @examples
#' \dontrun{
#' min_trl <- ledgr_sweep_min_track_record(sweep, reference_sharpe = 0)
#' as_tibble(min_trl)
#' }
#' @seealso `vignette("selection-integrity", package = "ledgr")` or
#'   `system.file("doc", "selection-integrity.html", package = "ledgr")`.
#' @export
ledgr_sweep_min_track_record <- function(sweep,
                                         candidates = NULL,
                                         reference_sharpe = 0,
                                         confidence = 0.95,
                                         risk_free_return = 0) {
  panel <- ledgr_sweep_returns_panel(
    sweep,
    candidates = candidates,
    value = "returns",
    complete = TRUE
  )
  m <- panel$matrix
  ledgr_min_track_record_validate_matrix(m)
  reference_sharpe <- ledgr_min_track_record_validate_reference(reference_sharpe)
  confidence <- ledgr_min_track_record_validate_confidence(confidence)
  risk_free_return <- ledgr_min_track_record_validate_risk_free(risk_free_return)

  rows <- lapply(seq_len(ncol(m)), function(j) {
    ledgr_min_track_record_candidate_row(
      returns = m[, j],
      candidate_id = colnames(m)[[j]],
      reference_sharpe = reference_sharpe,
      confidence = confidence,
      risk_free_return = risk_free_return
    )
  })
  summary <- tibble::as_tibble(do.call(rbind, rows))
  summary <- cbind(
    tibble::tibble(
      diagnostic = "minimum_track_record_length",
      schema_version = 1L,
      sweep_id = ledgr_min_track_record_sweep_id(sweep)
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
      source = "retained_sweep_returns",
      diagnostic = "minimum_track_record_length",
      schema_version = 1L,
      native_version = "ledgr_min_track_record_v1",
      reference_sharpe = reference_sharpe,
      confidence = confidence,
      risk_free_return = risk_free_return,
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
  class(out) <- c("ledgr_sweep_min_track_record", "list")
  out
}

#' @export
as_tibble.ledgr_sweep_min_track_record <- function(x, ...) {
  tibble::as_tibble(x$summary)
}

#' @export
print.ledgr_sweep_min_track_record <- function(x, ...) {
  if (!inherits(x, "ledgr_sweep_min_track_record")) {
    rlang::abort(
      "`x` must be a ledgr_sweep_min_track_record object.",
      class = "ledgr_invalid_args"
    )
  }
  summary <- tibble::as_tibble(x$summary)
  cat("# ledgr sweep minimum track record length\n", sep = "")
  cat(sprintf("# i candidates: %d\n", nrow(summary)), sep = "")
  cat(sprintf("# i confidence: %.3f\n", summary$confidence[[1L]]), sep = "")
  cat(sprintf("# i reference Sharpe: %.4f\n\n", summary$reference_sharpe[[1L]]), sep = "")
  print(summary[, c(
    "candidate_id", "observed_sharpe", "reference_sharpe",
    "min_track_record_length", "observations", "extra_observations_needed",
    "track_record_significant"
  ), drop = FALSE], ...)
  invisible(x)
}

ledgr_min_track_record_validate_matrix <- function(m) {
  if (!is.matrix(m) || !is.numeric(m)) {
    rlang::abort(
      "Minimum track record length requires a numeric retained-return matrix.",
      class = c("ledgr_validation_min_trl_invalid_returns", "ledgr_invalid_args")
    )
  }
  if (nrow(m) < 4L) {
    rlang::abort(
      "Minimum track record length requires at least four post-first-row return observations.",
      class = c("ledgr_validation_min_trl_too_few_observations", "ledgr_invalid_args"),
      n_observations = nrow(m)
    )
  }
  if (anyNA(m) || any(!is.finite(m))) {
    rlang::abort(
      "Minimum track record length requires finite retained returns.",
      class = c("ledgr_validation_min_trl_invalid_returns", "ledgr_invalid_args")
    )
  }
  invisible(TRUE)
}

ledgr_min_track_record_validate_reference <- function(reference_sharpe) {
  if (!is.numeric(reference_sharpe) ||
      length(reference_sharpe) != 1L ||
      is.na(reference_sharpe) ||
      !is.finite(reference_sharpe)) {
    rlang::abort(
      "`reference_sharpe` must be a finite numeric scalar.",
      class = c("ledgr_validation_min_trl_invalid_reference", "ledgr_invalid_args")
    )
  }
  as.numeric(reference_sharpe)
}

ledgr_min_track_record_validate_confidence <- function(confidence) {
  if (!is.numeric(confidence) ||
      length(confidence) != 1L ||
      is.na(confidence) ||
      !is.finite(confidence) ||
      confidence <= 0 ||
      confidence >= 1) {
    rlang::abort(
      "`confidence` must be a finite numeric scalar in (0, 1).",
      class = c("ledgr_validation_min_trl_invalid_confidence", "ledgr_invalid_args")
    )
  }
  as.numeric(confidence)
}

ledgr_min_track_record_validate_risk_free <- function(risk_free_return) {
  if (!is.numeric(risk_free_return) ||
      length(risk_free_return) != 1L ||
      is.na(risk_free_return) ||
      !is.finite(risk_free_return) ||
      risk_free_return <= -1) {
    rlang::abort(
      "`risk_free_return` must be a finite per-period return greater than -1.",
      class = c("ledgr_validation_min_trl_invalid_risk_free", "ledgr_invalid_args")
    )
  }
  as.numeric(risk_free_return)
}

ledgr_min_track_record_candidate_row <- function(returns,
                                                candidate_id,
                                                reference_sharpe,
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
      "Minimum track record length requires non-constant retained returns.",
      class = c("ledgr_validation_min_trl_invalid_returns", "ledgr_invalid_args"),
      candidate_id = candidate_id
    )
  }

  observed_sharpe <- mean(excess) / sd_excess
  skewness <- mean(centered^3) / moment_2^(3 / 2)
  kurtosis <- mean(centered^4) / moment_2^2
  if (any(!is.finite(c(observed_sharpe, skewness, kurtosis)))) {
    rlang::abort(
      "Minimum track record length could not compute finite return moments.",
      class = c("ledgr_validation_min_trl_invalid_returns", "ledgr_invalid_args"),
      candidate_id = candidate_id
    )
  }

  passes_reference <- observed_sharpe > reference_sharpe
  min_track_record_length <- if (isTRUE(passes_reference)) {
    1 + (1 - skewness * observed_sharpe + ((kurtosis - 1) / 4) * observed_sharpe^2) *
      (stats::qnorm(confidence) / (observed_sharpe - reference_sharpe))^2
  } else {
    Inf
  }
  if (!is.finite(min_track_record_length) && isTRUE(passes_reference)) {
    rlang::abort(
      "Minimum track record length produced a non-finite value.",
      class = c("ledgr_validation_min_trl_invalid_returns", "ledgr_invalid_args"),
      candidate_id = candidate_id
    )
  }
  track_record_significant <- is.finite(min_track_record_length) &&
    observations > min_track_record_length
  extra_observations_needed <- if (is.finite(min_track_record_length)) {
    ceiling(max(min_track_record_length - observations, 0))
  } else {
    Inf
  }
  status <- if (isTRUE(track_record_significant)) {
    "significant"
  } else if (isTRUE(passes_reference)) {
    "needs_more_observations"
  } else {
    "observed_not_above_reference"
  }

  tibble::tibble(
    candidate_id = candidate_id,
    observations = observations,
    observed_sharpe = as.numeric(observed_sharpe),
    reference_sharpe = reference_sharpe,
    confidence = confidence,
    risk_free_return = risk_free_return,
    skewness = as.numeric(skewness),
    kurtosis = as.numeric(kurtosis),
    min_track_record_length = as.numeric(min_track_record_length),
    track_record_significant = isTRUE(track_record_significant),
    extra_observations_needed = as.numeric(extra_observations_needed),
    status = status
  )
}

ledgr_min_track_record_sweep_id <- function(sweep) {
  sweep_id <- attr(sweep, "sweep_id", exact = TRUE)
  if (is.character(sweep_id) && length(sweep_id) == 1L && !is.na(sweep_id)) {
    return(sweep_id)
  }
  NA_character_
}
