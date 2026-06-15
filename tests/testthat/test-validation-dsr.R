ledgr_dsr_test_sweep <- function(returns, statuses = NULL) {
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
      sweep_id = "dsr-test-sweep",
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
  attr(out, "sweep_id") <- "dsr-test-sweep"
  attr(out, "metric_context_hash") <- paste(rep("a", 64), collapse = "")
  attr(out, "cost_model_hash") <- paste(rep("b", 64), collapse = "")
  attr(out, "risk_chain_hash") <- paste(rep("c", 64), collapse = "")
  attr(out, "sweep_retention") <- ledgr_sweep_retention("completed")
  attr(out, "sweep_returns") <- tibble::as_tibble(do.call(rbind, rows))
  out
}

ledgr_dsr_reference_panel <- function() {
  a <- c(-0.020, -0.010, 0.000, 0.010, 0.020, 0.030, 0.010, -0.020, 0.000, 0.020, 0.015, -0.005)
  b <- a + c(0.001, -0.001, 0.001, -0.001, 0.001, -0.001, 0.001, -0.001, 0.001, -0.001, 0.001, -0.001)
  c <- c(0.030, -0.020, 0.025, -0.015, 0.020, -0.010, 0.015, -0.005, 0.010, 0.000, 0.005, -0.005)
  d <- c + c(-0.001, 0.001, -0.001, 0.001, -0.001, 0.001, -0.001, 0.001, -0.001, 0.001, -0.001, 0.001)
  cbind(a = a, b = b, c = c, d = d)
}

ledgr_dsr_manual_row <- function(returns,
                                 candidate_id,
                                 effective_trials,
                                 variance_sharpe,
                                 confidence = 0.95,
                                 risk_free_return = 0) {
  excess <- as.numeric(returns) - risk_free_return
  observed_sharpe <- mean(excess) / stats::sd(excess)
  centered <- excess - mean(excess)
  moment_2 <- mean(centered^2)
  skewness <- mean(centered^3) / moment_2^(3 / 2)
  kurtosis <- mean(centered^4) / moment_2^2
  emc <- 0.5772156649
  expected_max_z <- (1 - emc) * stats::qnorm(1 - 1 / effective_trials) +
    emc * stats::qnorm(1 - 1 / (effective_trials * exp(1)))
  expected_max_sharpe <- sqrt(variance_sharpe) * expected_max_z
  denominator_term <- 1 - skewness * observed_sharpe +
    ((kurtosis - 1) / 4) * observed_sharpe^2
  dsr_z <- (observed_sharpe - expected_max_sharpe) *
    sqrt(length(excess) - 1) / sqrt(denominator_term)
  dsr_probability <- stats::pnorm(dsr_z)
  c(
    observed_sharpe = observed_sharpe,
    skewness = skewness,
    kurtosis = kurtosis,
    expected_max_z = expected_max_z,
    expected_max_sharpe = expected_max_sharpe,
    dsr_z = dsr_z,
    dsr_probability = dsr_probability,
    p_value = 1 - dsr_probability,
    deflated_sharpe = observed_sharpe * dsr_probability,
    significant = as.numeric(dsr_probability >= confidence)
  )
}

testthat::test_that("effective-trial clustering is deterministic and reports membership", {
  panel <- ledgr_dsr_reference_panel()
  sweep <- ledgr_dsr_test_sweep(panel)

  cluster_a <- ledgr_sweep_cluster(sweep)
  cluster_b <- ledgr_sweep_cluster(sweep)
  summary <- tibble::as_tibble(cluster_a)
  membership <- tibble::as_tibble(cluster_a, what = "membership")
  distances <- tibble::as_tibble(cluster_a, what = "distances")

  testthat::expect_s3_class(cluster_a, "ledgr_sweep_cluster")
  testthat::expect_identical(cluster_a$summary, cluster_b$summary)
  testthat::expect_identical(cluster_a$membership, cluster_b$membership)
  testthat::expect_identical(
    names(summary),
    c(
      "diagnostic", "schema_version", "sweep_id", "effective_trials",
      "raw_trials", "method", "distance", "distance_threshold",
      "n_observations", "value", "first_row_dropped", "complete_panel",
      "candidate_ids", "completed_candidate_ids", "excluded_candidate_ids",
      "metric_context_hash", "cost_model_hash", "risk_chain_hash"
    )
  )
  testthat::expect_identical(summary$effective_trials[[1]], 2L)
  testthat::expect_identical(membership$cluster_index, c(1L, 1L, 2L, 2L))
  testthat::expect_identical(membership$candidate_id, colnames(panel))
  testthat::expect_equal(
    distances$distance[distances$candidate_id_a == "a" & distances$candidate_id_b == "b"],
    1 - stats::cor(panel[, "a"], panel[, "b"]),
    tolerance = 1e-12
  )
  testthat::expect_false("seed" %in% names(formals(ledgr_sweep_cluster)))
  testthat::expect_false("method" %in% names(formals(ledgr_sweep_cluster)))
  testthat::expect_identical(cluster_a$metadata$native_version, "ledgr_effective_trial_cluster_v1")

  printed <- utils::capture.output(print(cluster_a, n = 2))
  testthat::expect_true(any(grepl("effective-trial clustering", printed, fixed = TRUE)))
})

testthat::test_that("native DSR matches the reference formula", {
  panel <- ledgr_dsr_reference_panel()
  sweep <- ledgr_dsr_test_sweep(panel)

  dsr <- ledgr_sweep_dsr(sweep)
  summary <- tibble::as_tibble(dsr)
  sharpes <- apply(panel, 2, function(x) mean(x) / stats::sd(x))
  variance_sharpe <- stats::var(sharpes)
  expected_a <- ledgr_dsr_manual_row(
    panel[, "a"],
    candidate_id = "a",
    effective_trials = 2L,
    variance_sharpe = variance_sharpe
  )
  row_a <- summary[summary$candidate_id == "a", , drop = FALSE]

  testthat::expect_s3_class(dsr, "ledgr_sweep_dsr")
  testthat::expect_identical(
    names(summary),
    c(
      "diagnostic", "schema_version", "sweep_id", "candidate_id",
      "observations", "observed_sharpe", "skewness", "kurtosis",
      "variance_sharpe", "expected_max_z", "expected_max_sharpe",
      "effective_trials", "raw_trials", "confidence", "risk_free_return",
      "dsr_z", "dsr_probability", "p_value", "deflated_sharpe",
      "significant", "status", "effective_trials_source", "value",
      "first_row_dropped", "complete_panel", "metric_context_hash",
      "cost_model_hash", "risk_chain_hash"
    )
  )
  testthat::expect_identical(summary$effective_trials, rep(2L, 4L))
  testthat::expect_identical(summary$raw_trials, rep(4L, 4L))
  testthat::expect_identical(summary$effective_trials_source, rep("clustered", 4L))
  testthat::expect_true(all(summary$first_row_dropped))
  testthat::expect_true(all(summary$complete_panel))
  testthat::expect_identical(dsr$metadata$native_version, "ledgr_dsr_v1")
  testthat::expect_identical(dsr$metadata$cluster$membership$cluster_index, c(1L, 1L, 2L, 2L))

  for (field in names(expected_a)[names(expected_a) != "significant"]) {
    testthat::expect_equal(row_a[[field]], expected_a[[field]], tolerance = 1e-12)
  }
  testthat::expect_identical(row_a$significant[[1]], as.logical(expected_a[["significant"]]))

  printed <- utils::capture.output(print(dsr, n = 1))
  testthat::expect_true(any(grepl("deflated Sharpe ratio", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("effective trials", printed, fixed = TRUE)))
})

testthat::test_that("native DSR can cross-check against quantstrat when it is installed", {
  testthat::skip_if_not_installed("quantstrat")

  panel <- ledgr_dsr_reference_panel()
  sweep <- ledgr_dsr_test_sweep(panel)
  dsr <- ledgr_sweep_dsr(sweep, effective_trials = 2L)
  summary <- tibble::as_tibble(dsr)
  row_a <- summary[summary$candidate_id == "a", , drop = FALSE]
  helper <- getFromNamespace(".deflatedSharpe", "quantstrat")
  reference <- helper(
    sharpe = row_a$observed_sharpe[[1]],
    nTrials = row_a$effective_trials[[1]],
    varTrials = row_a$variance_sharpe[[1]],
    skew = row_a$skewness[[1]],
    kurt = row_a$kurtosis[[1]],
    numPeriods = row_a$observations[[1]],
    periodsInYear = 1
  )

  testthat::expect_equal(row_a$p_value[[1]], reference$p.value[[1]], tolerance = 1e-12)
  testthat::expect_equal(row_a$deflated_sharpe[[1]], reference$deflated.Sharpe[[1]], tolerance = 1e-12)
})

testthat::test_that("DSR decreases as effective trial count increases", {
  panel <- ledgr_dsr_reference_panel()
  sweep <- ledgr_dsr_test_sweep(panel)

  dsr_two <- tibble::as_tibble(ledgr_sweep_dsr(sweep, effective_trials = 2L))
  dsr_four <- tibble::as_tibble(ledgr_sweep_dsr(sweep, effective_trials = 4L))

  testthat::expect_true(all(dsr_four$dsr_probability < dsr_two$dsr_probability))
  testthat::expect_true(all(dsr_four$p_value > dsr_two$p_value))
})

testthat::test_that("DSR and clustering fail closed on invalid evidence and arguments", {
  panel <- ledgr_dsr_reference_panel()
  sweep <- ledgr_dsr_test_sweep(panel)

  testthat::expect_error(
    ledgr_sweep_cluster(sweep, distance_threshold = NA_real_),
    class = "ledgr_validation_cluster_invalid_threshold"
  )
  testthat::expect_error(
    ledgr_sweep_cluster(ledgr_dsr_test_sweep(panel[, "a", drop = FALSE])),
    class = "ledgr_validation_cluster_too_few_candidates"
  )
  testthat::expect_error(
    ledgr_sweep_cluster(ledgr_dsr_test_sweep(matrix(0.01, nrow = 4, ncol = 2))),
    class = "ledgr_validation_cluster_invalid_returns"
  )
  testthat::expect_error(
    ledgr_sweep_dsr(sweep, effective_trials = 1L),
    class = "ledgr_validation_dsr_invalid_effective_trials"
  )
  testthat::expect_error(
    ledgr_sweep_dsr(sweep, effective_trials = 5L),
    class = "ledgr_validation_dsr_invalid_effective_trials"
  )
  one_cluster <- cbind(
    a = panel[, "a"],
    b = panel[, "a"] + 0.0001,
    c = panel[, "a"] - 0.0001
  )
  testthat::expect_error(
    ledgr_sweep_dsr(ledgr_dsr_test_sweep(one_cluster)),
    class = "ledgr_validation_dsr_invalid_effective_trials"
  )
  testthat::expect_error(
    ledgr_sweep_dsr(sweep, confidence = 1),
    class = "ledgr_validation_dsr_invalid_confidence"
  )
  testthat::expect_error(
    ledgr_sweep_dsr(sweep, risk_free_return = -1),
    class = "ledgr_validation_dsr_invalid_risk_free"
  )
  testthat::expect_error(
    ledgr_sweep_dsr(ledgr_dsr_test_sweep(matrix(c(0.01, 0.02, 0.03), ncol = 1))),
    class = "ledgr_validation_dsr_too_few_candidates"
  )
  testthat::expect_error(
    ledgr_sweep_dsr(ledgr_dsr_test_sweep(cbind(a = c(0.01, 0.02, 0.03), b = c(0.03, 0.02, 0.01))), effective_trials = 2L),
    class = "ledgr_validation_dsr_too_few_observations"
  )
  testthat::expect_error(
    ledgr_sweep_dsr(ledgr_dsr_test_sweep(matrix(rep(0.01, 8), nrow = 4, ncol = 2)), effective_trials = 2L),
    class = "ledgr_validation_dsr_invalid_returns"
  )

  ragged <- sweep
  retained <- attr(ragged, "sweep_returns", exact = TRUE)
  retained <- retained[!(retained$candidate_id == "a" & retained$ts_utc == max(retained$ts_utc)), , drop = FALSE]
  attr(ragged, "sweep_returns") <- retained
  testthat::expect_error(
    ledgr_sweep_dsr(ragged),
    class = "ledgr_sweep_returns_incomplete_panel"
  )

  unretained <- sweep
  attr(unretained, "sweep_retention") <- ledgr_sweep_retention("none")
  attr(unretained, "sweep_returns") <- NULL
  testthat::expect_error(
    ledgr_sweep_dsr(unretained),
    class = "ledgr_sweep_returns_unretained"
  )
})

testthat::test_that("native DSR adds no quantstrat runtime dependency", {
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

  testthat::expect_false("quantstrat" %in% imports)
  testthat::expect_no_match(namespace, "import\\(quantstrat\\)")
  testthat::expect_no_match(namespace, "importFrom(quantstrat", fixed = TRUE)
})
