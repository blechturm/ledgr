ledgr_min_trl_test_sweep <- function(returns, statuses = NULL) {
  returns <- as.matrix(returns)
  if (is.null(colnames(returns))) {
    colnames(returns) <- paste0("c", seq_len(ncol(returns)))
  }
  candidate_ids <- colnames(returns)
  if (is.null(statuses)) {
    statuses <- rep("DONE", length(candidate_ids))
  }
  ts_utc <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * seq_len(nrow(returns) + 1L)
  rows <- lapply(seq_along(candidate_ids), function(j) {
    period_return <- c(NA_real_, as.numeric(returns[, j]))
    tibble::tibble(
      sweep_id = "min-trl-test-sweep",
      candidate_id = candidate_ids[[j]],
      ts_utc = ts_utc,
      equity = 100 * cumprod(c(1, 1 + as.numeric(returns[, j]))),
      period_return = period_return
    )
  })
  out <- tibble::tibble(
    candidate_id = candidate_ids,
    candidate_row = seq_along(candidate_ids),
    status = statuses
  )
  class(out) <- c("ledgr_sweep_results", class(out))
  attr(out, "sweep_id") <- "min-trl-test-sweep"
  attr(out, "sweep_retention") <- ledgr_sweep_retention("completed")
  attr(out, "sweep_returns") <- tibble::as_tibble(do.call(rbind, rows))
  out
}

ledgr_min_trl_reference_panel <- function() {
  cbind(
    strong = c(0.012, 0.016, 0.010, 0.018, 0.013, 0.017, 0.011, 0.015),
    noisy = c(0.040, -0.030, 0.035, -0.025, 0.030, -0.020, 0.025, -0.015),
    weak = c(0.004, -0.002, 0.003, -0.001, 0.002, -0.003, 0.005, -0.004)
  )
}

ledgr_min_trl_manual <- function(x,
                                 reference_sharpe = 0,
                                 confidence = 0.95,
                                 risk_free_return = 0) {
  excess <- as.numeric(x) - risk_free_return
  observed_sharpe <- mean(excess) / stats::sd(excess)
  centered <- excess - mean(excess)
  moment_2 <- mean(centered^2)
  skewness <- mean(centered^3) / moment_2^(3 / 2)
  kurtosis <- mean(centered^4) / moment_2^2
  min_trl <- if (observed_sharpe > reference_sharpe) {
    1 + (1 - skewness * observed_sharpe + ((kurtosis - 1) / 4) * observed_sharpe^2) *
      (stats::qnorm(confidence) / (observed_sharpe - reference_sharpe))^2
  } else {
    Inf
  }
  c(
    observed_sharpe = observed_sharpe,
    skewness = skewness,
    kurtosis = kurtosis,
    min_track_record_length = min_trl
  )
}

testthat::test_that("minimum track record length matches the reference formula", {
  panel <- ledgr_min_trl_reference_panel()
  sweep <- ledgr_min_trl_test_sweep(panel)

  min_trl <- ledgr_sweep_min_track_record(sweep, reference_sharpe = 0, confidence = 0.95)
  summary <- tibble::as_tibble(min_trl)

  testthat::expect_s3_class(min_trl, "ledgr_sweep_min_track_record")
  testthat::expect_identical(
    names(summary),
    c(
      "diagnostic", "schema_version", "sweep_id", "candidate_id",
      "observations", "observed_sharpe", "reference_sharpe", "confidence",
      "risk_free_return", "skewness", "kurtosis", "min_track_record_length",
      "track_record_significant", "extra_observations_needed", "status",
      "value", "first_row_dropped", "complete_panel"
    )
  )
  testthat::expect_identical(summary$diagnostic, rep("minimum_track_record_length", 3L))
  testthat::expect_identical(summary$schema_version, rep(1L, 3L))
  testthat::expect_identical(summary$candidate_id, colnames(panel))
  testthat::expect_identical(summary$observations, rep(nrow(panel), 3L))
  testthat::expect_true(all(summary$first_row_dropped))
  testthat::expect_true(all(summary$complete_panel))
  testthat::expect_identical(min_trl$metadata$native_version, "ledgr_min_track_record_v1")

  expected_strong <- ledgr_min_trl_manual(panel[, "strong"])
  strong <- summary[summary$candidate_id == "strong", , drop = FALSE]
  testthat::expect_equal(strong$observed_sharpe, expected_strong[["observed_sharpe"]], tolerance = 1e-12)
  testthat::expect_equal(strong$skewness, expected_strong[["skewness"]], tolerance = 1e-12)
  testthat::expect_equal(strong$kurtosis, expected_strong[["kurtosis"]], tolerance = 1e-12)
  testthat::expect_equal(
    strong$min_track_record_length,
    expected_strong[["min_track_record_length"]],
    tolerance = 1e-12
  )
  testthat::expect_identical(
    strong$extra_observations_needed,
    ceiling(max(expected_strong[["min_track_record_length"]] - nrow(panel), 0))
  )

  printed <- utils::capture.output(print(min_trl, n = 1))
  testthat::expect_true(any(grepl("minimum track record length", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("reference Sharpe", printed, fixed = TRUE)))
})

testthat::test_that("minimum track record length cross-checks against PerformanceAnalytics", {
  testthat::skip_if_not_installed("PerformanceAnalytics")
  testthat::skip_if_not_installed("xts")
  suppressWarnings(suppressPackageStartupMessages(library(PerformanceAnalytics)))

  panel <- ledgr_min_trl_reference_panel()
  sweep <- ledgr_min_trl_test_sweep(panel[, "strong", drop = FALSE])
  min_trl <- ledgr_sweep_min_track_record(sweep, reference_sharpe = 0, confidence = 0.95)
  summary <- tibble::as_tibble(min_trl)
  xts_returns <- xts::xts(
    panel[, "strong", drop = FALSE],
    order.by = as.Date("2020-01-01") + seq_len(nrow(panel))
  )
  reference <- PerformanceAnalytics::MinTrackRecord(
    xts_returns,
    Rf = 0,
    refSR = 0,
    p = 0.95,
    ignore_kurtosis = FALSE
  )

  testthat::expect_equal(
    summary$min_track_record_length[[1]],
    as.numeric(reference$min_TRL),
    tolerance = 1e-12
  )
  testthat::expect_identical(
    summary$track_record_significant[[1]],
    reference$IS_SR_SIGNIFICANT[[1]]
  )
  testthat::expect_equal(
    summary$extra_observations_needed[[1]],
    as.numeric(reference$num_of_extra_obs_needed),
    tolerance = 1e-12
  )
})

testthat::test_that("minimum track record length preserves weak candidates as evidence", {
  panel <- ledgr_min_trl_reference_panel()
  sweep <- ledgr_min_trl_test_sweep(panel)

  min_trl <- ledgr_sweep_min_track_record(sweep, reference_sharpe = 0.20)
  summary <- tibble::as_tibble(min_trl)

  strong <- summary[summary$candidate_id == "strong", , drop = FALSE]
  weak <- summary[summary$candidate_id == "weak", , drop = FALSE]
  testthat::expect_true(strong$observed_sharpe[[1]] > weak$observed_sharpe[[1]])
  testthat::expect_true(strong$min_track_record_length[[1]] < weak$min_track_record_length[[1]])
  testthat::expect_identical(weak$status[[1]], "observed_not_above_reference")
  testthat::expect_false(weak$track_record_significant[[1]])
  testthat::expect_true(is.infinite(weak$extra_observations_needed[[1]]))
})

testthat::test_that("minimum track record length fails closed on invalid evidence and arguments", {
  panel <- ledgr_min_trl_reference_panel()
  sweep <- ledgr_min_trl_test_sweep(panel)

  testthat::expect_error(
    ledgr_sweep_min_track_record(sweep, reference_sharpe = NA_real_),
    class = "ledgr_validation_min_trl_invalid_reference"
  )
  testthat::expect_error(
    ledgr_sweep_min_track_record(sweep, confidence = 1),
    class = "ledgr_validation_min_trl_invalid_confidence"
  )
  testthat::expect_error(
    ledgr_sweep_min_track_record(sweep, risk_free_return = -1),
    class = "ledgr_validation_min_trl_invalid_risk_free"
  )
  testthat::expect_error(
    ledgr_sweep_min_track_record(ledgr_min_trl_test_sweep(matrix(c(0.01, 0.02, 0.03), ncol = 1))),
    class = "ledgr_validation_min_trl_too_few_observations"
  )
  testthat::expect_error(
    ledgr_sweep_min_track_record(ledgr_min_trl_test_sweep(matrix(rep(0.01, 6), ncol = 1))),
    class = "ledgr_validation_min_trl_invalid_returns"
  )

  ragged <- sweep
  retained <- attr(ragged, "sweep_returns", exact = TRUE)
  retained <- retained[!(retained$candidate_id == "strong" & retained$ts_utc == max(retained$ts_utc)), , drop = FALSE]
  attr(ragged, "sweep_returns") <- retained
  testthat::expect_error(
    ledgr_sweep_min_track_record(ragged),
    class = "ledgr_sweep_returns_incomplete_panel"
  )

  unretained <- sweep
  attr(unretained, "sweep_retention") <- ledgr_sweep_retention("none")
  attr(unretained, "sweep_returns") <- NULL
  testthat::expect_error(
    ledgr_sweep_min_track_record(unretained),
    class = "ledgr_sweep_returns_unretained"
  )
})

testthat::test_that("minimum track record length adds no PerformanceAnalytics runtime import", {
  root <- testthat::test_path("..", "..")
  description_path <- file.path(root, "DESCRIPTION")
  namespace_path <- file.path(root, "NAMESPACE")
  testthat::skip_if_not(
    file.exists(description_path) && file.exists(namespace_path),
    "source package metadata not available during installed-package tests"
  )
  description <- read.dcf(description_path)
  imports <- trimws(unlist(strsplit(description[, "Imports"], "[,\n]")))
  namespace <- paste(readLines(namespace_path, warn = FALSE), collapse = "\n")

  testthat::expect_false("PerformanceAnalytics" %in% imports)
  testthat::expect_no_match(namespace, "import\\(PerformanceAnalytics\\)")
  testthat::expect_no_match(namespace, "importFrom(PerformanceAnalytics", fixed = TRUE)
})
