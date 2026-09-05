ledgr_k_ratio_test_sweep <- function(returns) {
  returns <- as.matrix(returns)
  if (is.null(colnames(returns))) {
    colnames(returns) <- paste0("c", seq_len(ncol(returns)))
  }
  candidate_ids <- colnames(returns)
  ts_utc <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * seq_len(nrow(returns) + 1L)
  rows <- lapply(seq_along(candidate_ids), function(j) {
    tibble::tibble(
      sweep_id = "k-ratio-test-sweep",
      candidate_id = candidate_ids[[j]],
      ts_utc = ts_utc,
      equity = 100 * cumprod(c(1, 1 + as.numeric(returns[, j]))),
      period_return = c(NA_real_, as.numeric(returns[, j]))
    )
  })
  out <- tibble::tibble(
    candidate_id = candidate_ids,
    candidate_row = seq_along(candidate_ids),
    status = rep("DONE", length(candidate_ids))
  )
  class(out) <- c("ledgr_sweep_results", class(out))
  attr(out, "sweep_id") <- "k-ratio-test-sweep"
  attr(out, "sweep_retention") <- ledgr_sweep_retention("completed")
  attr(out, "sweep_returns") <- tibble::as_tibble(do.call(rbind, rows))
  out
}

ledgr_k_ratio_reference_panel <- function() {
  cbind(
    smooth_growth = c(
      0.015, -0.002, 0.012, 0.004, 0.011, 0.003,
      0.013, 0.005, 0.010, 0.004, 0.012, 0.006
    ),
    noisy_flat = c(
      0.080, -0.075, 0.060, -0.065, 0.050, -0.055,
      0.040, -0.045, 0.030, -0.035, 0.020, -0.025
    )
  )
}

ledgr_k_ratio_manual <- function(returns, periods_per_year, risk_free_return = 0) {
  excess <- as.numeric(returns) - risk_free_return
  cumulative_log_wealth <- cumsum(log1p(excess))
  fit <- stats::lm(cumulative_log_wealth ~ seq.int(0, length(excess) - 1L))
  coefficients <- summary(fit)$coefficients
  slope <- unname(coefficients[2L, "Estimate"])
  slope_std_error <- unname(coefficients[2L, "Std. Error"])
  raw_k_ratio <- slope / slope_std_error
  c(
    cumulative_log_return = cumulative_log_wealth[[length(cumulative_log_wealth)]],
    slope = slope,
    slope_std_error = slope_std_error,
    raw_k_ratio = raw_k_ratio,
    k_ratio = raw_k_ratio * sqrt(periods_per_year) / length(excess)
  )
}

testthat::test_that("K-Ratio matches the pinned Kestner 2013 formula", {
  returns <- ledgr_k_ratio_reference_panel()
  panel <- ledgr_return_panel(returns)
  result <- ledgr_k_ratio(panel, periods_per_year = 252)
  summary <- tibble::as_tibble(result)

  testthat::expect_s3_class(result, "ledgr_k_ratio")
  testthat::expect_identical(
    names(summary),
    c(
      "diagnostic", "schema_version", "source", "panel_hash", "sweep_id",
      "candidate_id", "observations", "periods_per_year", "risk_free_return",
      "cumulative_log_return", "slope", "slope_std_error", "raw_k_ratio",
      "k_ratio", "value", "first_row_dropped", "complete_panel"
    )
  )
  testthat::expect_identical(summary$diagnostic, rep("k_ratio", 2L))
  testthat::expect_identical(summary$schema_version, rep(1L, 2L))
  testthat::expect_identical(summary$source, rep("user_return_panel", 2L))
  testthat::expect_identical(summary$panel_hash, rep(panel$panel_hash, 2L))
  testthat::expect_true(all(is.na(summary$sweep_id)))
  testthat::expect_identical(summary$candidate_id, colnames(returns))
  testthat::expect_identical(summary$observations, rep(nrow(returns), 2L))
  testthat::expect_identical(result$metadata$native_version, "ledgr_k_ratio_kestner_2013_v1")
  testthat::expect_identical(result$metadata$variant, "kestner_2013_compounded")
  testthat::expect_null(result$metadata$input_identity)

  expected <- ledgr_k_ratio_manual(returns[, "smooth_growth"], periods_per_year = 252)
  observed <- summary[summary$candidate_id == "smooth_growth", , drop = FALSE]
  for (field in names(expected)) {
    testthat::expect_equal(observed[[field]], expected[[field]], tolerance = 1e-12)
  }

  printed <- utils::capture.output(print(result, n = 1))
  testthat::expect_true(any(grepl("K-Ratio", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("Kestner 2013", printed, fixed = TRUE)))
})

testthat::test_that("K-Ratio ranks smooth growth above a noisy flat path", {
  summary <- tibble::as_tibble(
    ledgr_k_ratio(
      ledgr_return_panel(ledgr_k_ratio_reference_panel()),
      periods_per_year = 252
    )
  )

  smooth <- summary$k_ratio[summary$candidate_id == "smooth_growth"]
  noisy <- summary$k_ratio[summary$candidate_id == "noisy_flat"]
  testthat::expect_gt(smooth, 1)
  testthat::expect_lt(noisy, 0.5)
  testthat::expect_gt(smooth, noisy)
})

testthat::test_that("K-Ratio preserves panel evidence across direct and sweep inputs", {
  returns <- ledgr_k_ratio_reference_panel()
  sweep <- ledgr_k_ratio_test_sweep(returns)
  sweep_panel <- ledgr_sweep_returns_panel(sweep)
  direct_panel <- ledgr_return_panel(returns, ts = sweep_panel$ts_utc)

  testthat::expect_identical(sweep_panel$panel_hash, direct_panel$panel_hash)

  from_sweep <- ledgr_k_ratio(sweep, periods_per_year = 252)
  from_panel <- ledgr_k_ratio(direct_panel, periods_per_year = 252)
  sweep_summary <- tibble::as_tibble(from_sweep)
  panel_summary <- tibble::as_tibble(from_panel)
  comparable <- setdiff(names(sweep_summary), c("source", "sweep_id", "first_row_dropped"))

  testthat::expect_equal(panel_summary[, comparable], sweep_summary[, comparable], tolerance = 1e-12)
  testthat::expect_identical(unique(sweep_summary$panel_hash), unique(panel_summary$panel_hash))
  testthat::expect_identical(unique(sweep_summary$source), "retained_sweep_returns")
  testthat::expect_identical(unique(panel_summary$source), "user_return_panel")
  testthat::expect_true(all(is.na(panel_summary$sweep_id)))
  testthat::expect_null(from_panel$metadata$input_identity)
  testthat::expect_identical(from_sweep$metadata$input_identity$sweep_id, "k-ratio-test-sweep")
})

testthat::test_that("K-Ratio fails closed on invalid arguments and degenerate evidence", {
  panel <- ledgr_return_panel(ledgr_k_ratio_reference_panel())

  testthat::expect_error(
    ledgr_k_ratio(panel),
    class = "ledgr_validation_k_ratio_invalid_periods_per_year"
  )
  testthat::expect_error(
    ledgr_k_ratio(panel, periods_per_year = 0),
    class = "ledgr_validation_k_ratio_invalid_periods_per_year"
  )
  testthat::expect_error(
    ledgr_k_ratio(panel, periods_per_year = 252, risk_free_return = NA_real_),
    class = "ledgr_validation_k_ratio_invalid_risk_free"
  )
  testthat::expect_error(
    ledgr_k_ratio(panel, periods_per_year = 252, risk_free_return = -1),
    class = "ledgr_validation_k_ratio_invalid_risk_free"
  )
  testthat::expect_error(
    ledgr_k_ratio(ledgr_return_panel(data.frame(a = c(0.01, 0.02))), periods_per_year = 252),
    class = "ledgr_validation_k_ratio_too_few_observations"
  )
  testthat::expect_error(
    ledgr_k_ratio(ledgr_return_panel(data.frame(a = rep(0.01, 6))), periods_per_year = 252),
    class = "ledgr_validation_k_ratio_invalid_returns"
  )
  testthat::expect_error(
    ledgr_k_ratio(ledgr_return_panel(data.frame(a = c(0.01, -1, 0.02))), periods_per_year = 252),
    class = "ledgr_validation_k_ratio_invalid_returns"
  )
  testthat::expect_error(
    ledgr_k_ratio(ledgr_k_ratio_reference_panel(), periods_per_year = 252),
    class = "ledgr_invalid_args"
  )
})

testthat::test_that("K-Ratio inherits retained-panel failures", {
  sweep <- ledgr_k_ratio_test_sweep(ledgr_k_ratio_reference_panel())

  ragged <- sweep
  retained <- attr(ragged, "sweep_returns", exact = TRUE)
  retained <- retained[!(retained$candidate_id == "smooth_growth" & retained$ts_utc == max(retained$ts_utc)), , drop = FALSE]
  attr(ragged, "sweep_returns") <- retained
  testthat::expect_error(
    ledgr_k_ratio(ragged, periods_per_year = 252),
    class = "ledgr_sweep_returns_incomplete_panel"
  )

  unretained <- sweep
  attr(unretained, "sweep_retention") <- ledgr_sweep_retention("none")
  attr(unretained, "sweep_returns") <- NULL
  testthat::expect_error(
    ledgr_k_ratio(unretained, periods_per_year = 252),
    class = "ledgr_sweep_returns_unretained"
  )
})
