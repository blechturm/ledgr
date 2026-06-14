ledgr_pbo_test_sweep <- function(returns, statuses = NULL) {
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
      sweep_id = "pbo-test-sweep",
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
  attr(out, "sweep_id") <- "pbo-test-sweep"
  attr(out, "sweep_retention") <- ledgr_sweep_retention("completed")
  attr(out, "sweep_returns") <- tibble::as_tibble(do.call(rbind, rows))
  out
}

ledgr_pbo_reference_panel <- function() {
  matrix(
    c(
      0.02, 0.01, -0.01, 0.00, 0.03, 0.01, -0.02, 0.00, 0.01, 0.02, -0.01, 0.00,
      0.00, 0.01, 0.02, 0.01, -0.01, 0.00, 0.03, 0.02, -0.02, -0.01, 0.00, 0.01,
      -0.01, 0.00, 0.01, 0.02, 0.00, -0.01, 0.01, 0.03, 0.02, 0.00, -0.02, -0.01,
      0.01, -0.02, 0.00, 0.01, 0.02, 0.03, 0.00, -0.01, 0.00, 0.01, 0.02, 0.03
    ),
    nrow = 12,
    ncol = 4,
    dimnames = list(NULL, paste0("c", 1:4))
  )
}

testthat::test_that("native PBO matches the spike reference fixture", {
  sweep <- ledgr_pbo_test_sweep(ledgr_pbo_reference_panel())

  pbo <- ledgr_sweep_pbo(sweep, S = 4L)
  summary <- tibble::as_tibble(pbo)
  cases <- tibble::as_tibble(pbo, what = "cases")
  degradation <- tibble::as_tibble(pbo, what = "degradation")

  testthat::expect_s3_class(pbo, "ledgr_sweep_pbo")
  testthat::expect_identical(
    names(summary),
    c(
      "diagnostic", "schema_version", "sweep_id", "pbo",
      "probability_not_overfit", "threshold", "S", "n_cases",
      "n_observations", "n_candidates", "metric_name", "value",
      "first_row_dropped", "complete_panel", "candidate_ids",
      "completed_candidate_ids", "excluded_candidate_ids"
    )
  )
  testthat::expect_equal(summary$pbo[[1]], 2 / 3, tolerance = 1e-12)
  testthat::expect_equal(summary$probability_not_overfit[[1]], 1 / 3, tolerance = 1e-12)
  testthat::expect_identical(summary$S[[1]], 4L)
  testthat::expect_identical(summary$n_cases[[1]], 6L)
  testthat::expect_identical(summary$n_observations[[1]], 12L)
  testthat::expect_identical(summary$n_candidates[[1]], 4L)
  testthat::expect_identical(summary$metric_name[[1]], "mean_return")
  testthat::expect_identical(summary$candidate_ids[[1]], paste0("c", 1:4))
  testthat::expect_true(summary$first_row_dropped[[1]])
  testthat::expect_true(summary$complete_panel[[1]])

  testthat::expect_identical(cases$winner_column, c(1L, 2L, 4L, 3L, 4L, 4L))
  testthat::expect_identical(cases$oos_best_column, c(4L, 4L, 3L, 4L, 2L, 1L))
  testthat::expect_equal(cases$oos_rank, c(1, 2, 3, 1, 1, 3), tolerance = 1e-12)
  testthat::expect_equal(cases$omega_bar, c(0.25, 0.50, 0.75, 0.25, 0.25, 0.75), tolerance = 1e-12)
  testthat::expect_equal(
    cases$lambda,
    c(-1.09861228866811, 0, 1.09861228866811, -1.09861228866811, -1.09861228866811, 1.09861228866811),
    tolerance = 1e-12
  )
  testthat::expect_identical(nrow(degradation), nrow(cases))
  testthat::expect_identical(pbo$metadata$native_version, "ledgr_pbo_cscv_v1")

  printed <- utils::capture.output(print(pbo, n = 1))
  testthat::expect_true(any(grepl("ledgr sweep PBO/CSCV", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("as_tibble(x, what = \"cases\")", printed, fixed = TRUE)))
})

testthat::test_that("native PBO can cross-check against pbo when it is installed", {
  testthat::skip_if_not_installed("pbo")

  panel <- ledgr_pbo_reference_panel()
  sweep <- ledgr_pbo_test_sweep(panel)
  pbo <- ledgr_sweep_pbo(sweep, S = 4L)
  reference <- pbo::pbo(
    as.data.frame(panel, check.names = FALSE),
    s = 4L,
    f = function(x) colMeans(as.data.frame(x), na.rm = FALSE),
    threshold = 0,
    allow_parallel = FALSE
  )

  testthat::expect_equal(tibble::as_tibble(pbo)$pbo[[1]], reference$phi, tolerance = 1e-12)
})

testthat::test_that("native PBO known-direction fixture distinguishes overfit families", {
  overfit <- matrix(-0.01, nrow = 12, ncol = 4, dimnames = list(NULL, paste0("c", 1:4)))
  subset_id <- rep(1:4, each = 3)
  for (j in 1:4) {
    overfit[subset_id == j, j] <- 0.05
  }
  robust <- cbind(
    robust = rep(0.02, 12),
    weaker = rep(0.01, 12),
    flat = rep(0, 12),
    drag = rep(-0.005, 12)
  )

  overfit_pbo <- ledgr_sweep_pbo(ledgr_pbo_test_sweep(overfit), S = 4L)
  robust_pbo <- ledgr_sweep_pbo(ledgr_pbo_test_sweep(robust), S = 4L)

  testthat::expect_gte(tibble::as_tibble(overfit_pbo)$pbo[[1]], 0.99)
  testthat::expect_lte(tibble::as_tibble(robust_pbo)$pbo[[1]], 0.01)
  testthat::expect_gt(
    tibble::as_tibble(overfit_pbo)$pbo[[1]],
    tibble::as_tibble(robust_pbo)$pbo[[1]]
  )
})

testthat::test_that("native PBO fails closed on invalid evidence and arguments", {
  sweep <- ledgr_pbo_test_sweep(ledgr_pbo_reference_panel())

  testthat::expect_error(
    ledgr_sweep_pbo(sweep, S = 3L),
    class = "ledgr_validation_pbo_invalid_s"
  )
  testthat::expect_error(
    ledgr_sweep_pbo(sweep, S = 5L),
    class = "ledgr_validation_pbo_invalid_s"
  )
  testthat::expect_error(
    ledgr_sweep_pbo(ledgr_pbo_test_sweep(ledgr_pbo_reference_panel()[, 1, drop = FALSE]), S = 4L),
    class = "ledgr_validation_pbo_too_few_candidates"
  )
  testthat::expect_error(
    ledgr_sweep_pbo(ledgr_pbo_test_sweep(matrix(0.01, nrow = 2, ncol = 2)), S = 2L),
    class = "ledgr_validation_pbo_too_few_observations"
  )
  testthat::expect_error(
    ledgr_sweep_pbo(sweep, metric = function(x) rep(Inf, ncol(x))),
    class = "ledgr_validation_pbo_invalid_metric"
  )
  testthat::expect_error(
    ledgr_sweep_pbo(sweep, threshold = NA_real_),
    class = "ledgr_validation_pbo_invalid_threshold"
  )

  ragged <- sweep
  retained <- attr(ragged, "sweep_returns", exact = TRUE)
  retained <- retained[!(retained$candidate_id == "c2" & retained$ts_utc == max(retained$ts_utc)), , drop = FALSE]
  attr(ragged, "sweep_returns") <- retained
  testthat::expect_error(
    ledgr_sweep_pbo(ragged, S = 4L),
    class = "ledgr_validation_pbo_incomplete_panel"
  )

  unretained <- sweep
  attr(unretained, "sweep_retention") <- ledgr_sweep_retention("none")
  attr(unretained, "sweep_returns") <- NULL
  testthat::expect_error(
    ledgr_sweep_pbo(unretained),
    class = "ledgr_sweep_returns_unretained"
  )
})

testthat::test_that("native PBO adds no pbo runtime dependency", {
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

  testthat::expect_false("pbo" %in% imports)
  testthat::expect_no_match(namespace, "import\\(pbo\\)")
  testthat::expect_no_match(namespace, "importFrom(pbo", fixed = TRUE)
})
