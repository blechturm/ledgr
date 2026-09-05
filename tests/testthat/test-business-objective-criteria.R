ledgr_objective_test_trades <- function(timestamps,
                                        pnl,
                                        outcome = ifelse(pnl > 0, "WIN", ifelse(pnl < 0, "LOSS", "BREAKEVEN"))) {
  tibble::tibble(
    candidate_id = "candidate_01",
    candidate_row = 1L,
    trade_seq = seq_along(timestamps),
    close_ts_utc = as.POSIXct(timestamps, origin = "1970-01-01", tz = "UTC"),
    realized_pnl = as.numeric(pnl),
    win_loss = as.character(outcome)
  )
}

ledgr_objective_test_return_panel <- function() {
  index <- seq_len(64L)
  ledgr_return_panel(cbind(
    steady = 0.004 + 0.001 * sin(index / 4),
    moderate = 0.003 + 0.002 * cos(index / 5),
    uneven = 0.002 + 0.006 * sin(index / 2),
    flat = 0.001 + 0.003 * cos(index / 3)
  ))
}

testthat::test_that("summary and trajectory criteria have known directions", {
  max_drawdown <- ledgr_objective_max_drawdown(0.20)
  testthat::expect_true(ledgr:::ledgr_objective_step_evaluate(max_drawdown, 0.10)$passed)
  testthat::expect_false(ledgr:::ledgr_objective_step_evaluate(max_drawdown, 0.30)$passed)

  min_trades <- ledgr_objective_min_trades(30)
  testthat::expect_true(ledgr:::ledgr_objective_step_evaluate(min_trades, 30)$passed)
  testthat::expect_false(ledgr:::ledgr_objective_step_evaluate(min_trades, 29)$passed)

  trajectory <- ledgr_objective_positive_trajectory(slope_min = 0)
  rising <- exp(0.01 * 0:9)
  falling <- exp(-0.01 * 0:9)
  rising_result <- ledgr:::ledgr_objective_step_evaluate(trajectory, rising)
  falling_result <- ledgr:::ledgr_objective_step_evaluate(trajectory, falling)
  testthat::expect_equal(rising_result$value, 0.01, tolerance = 1e-12)
  testthat::expect_equal(falling_result$value, -0.01, tolerance = 1e-12)
  testthat::expect_true(rising_result$passed)
  testthat::expect_false(falling_result$passed)

  testthat::expect_error(
    ledgr:::ledgr_objective_step_evaluate(max_drawdown, NULL, candidate_id = "missing"),
    class = "ledgr_objective_missing_evidence"
  )
  testthat::expect_error(
    ledgr:::ledgr_objective_step_evaluate(max_drawdown, NA_real_, candidate_id = "bad"),
    class = "ledgr_objective_non_finite_evidence"
  )
  testthat::expect_error(
    ledgr:::ledgr_objective_step_evaluate(trajectory, c(100, 0, 101), candidate_id = "bad"),
    class = "ledgr_objective_non_finite_evidence"
  )
})

testthat::test_that("trade-distribution criteria use retained closed-trade evidence", {
  start <- as.POSIXct("2020-01-01", tz = "UTC")
  end <- start + 8 * 86400
  evenly_spaced <- start + c(1, 3, 5, 7) * 86400
  concentrated <- start + c(0.1, 0.2, 0.3, 0.4) * 86400
  even_evidence <- list(
    trades = ledgr_objective_test_trades(evenly_spaced, rep(10, 4)),
    scoring_range = list(start = start, end = end)
  )
  concentrated_evidence <- list(
    trades = ledgr_objective_test_trades(concentrated, c(97, 1, 1, 1)),
    scoring_range = list(start = start, end = end)
  )

  even_trades <- ledgr_objective_even_trades(max_concentration = 0.30)
  testthat::expect_true(ledgr:::ledgr_objective_step_evaluate(even_trades, even_evidence)$passed)
  trade_fail <- ledgr:::ledgr_objective_step_evaluate(even_trades, concentrated_evidence)
  testthat::expect_false(trade_fail$passed)
  testthat::expect_equal(trade_fail$value, 1)
  testthat::expect_identical(trade_fail$details$time_bins, 4L)

  even_profit <- ledgr_objective_even_profit(max_concentration = 0.40)
  testthat::expect_true(ledgr:::ledgr_objective_step_evaluate(even_profit, even_evidence)$passed)
  profit_fail <- ledgr:::ledgr_objective_step_evaluate(even_profit, concentrated_evidence)
  testthat::expect_false(profit_fail$passed)
  testthat::expect_equal(profit_fail$value, 0.97)
  testthat::expect_identical(profit_fail$details$concentration_basis, "absolute_realized_pnl")

  alternating <- even_evidence
  alternating$trades$win_loss <- rep(c("WIN", "LOSS"), 2)
  streaked <- even_evidence
  streaked$trades$trade_seq <- c(4L, 1L, 3L, 2L)
  streaked$trades$win_loss <- c("WIN", "WIN", "WIN", "WIN")
  stable_runs <- ledgr_objective_stable_runs(max_streak = 2)
  testthat::expect_true(ledgr:::ledgr_objective_step_evaluate(stable_runs, alternating)$passed)
  streak_fail <- ledgr:::ledgr_objective_step_evaluate(stable_runs, streaked)
  testthat::expect_false(streak_fail$passed)
  testthat::expect_equal(streak_fail$value, 4)
  testthat::expect_identical(streak_fail$details$order_key, "trade_seq")

  breakeven <- even_evidence
  breakeven$trades$win_loss[] <- "BREAKEVEN"
  breakeven_result <- ledgr:::ledgr_objective_step_evaluate(stable_runs, breakeven)
  testthat::expect_identical(breakeven_result$value, 0)
  testthat::expect_true(breakeven_result$passed)

  testthat::expect_error(
    ledgr:::ledgr_objective_step_evaluate(even_trades, list(trades = even_evidence$trades)),
    class = "ledgr_objective_missing_evidence"
  )
  bad_profit <- even_evidence
  bad_profit$trades$realized_pnl[] <- 0
  testthat::expect_error(
    ledgr:::ledgr_objective_step_evaluate(even_profit, bad_profit),
    class = "ledgr_objective_non_finite_evidence"
  )
  bad_runs <- even_evidence
  bad_runs$trades$win_loss[[1L]] <- "UNKNOWN"
  testthat::expect_error(
    ledgr:::ledgr_objective_step_evaluate(stable_runs, bad_runs),
    class = "ledgr_objective_invalid_evidence"
  )
})

testthat::test_that("stable-region evidence distinguishes a plateau from a spike", {
  grid <- expand.grid(x = 1:3, y = 1:3, KEEP.OUT.ATTRS = FALSE)
  grid$candidate_id <- sprintf("candidate_%02d", seq_len(nrow(grid)))
  grid <- grid[, c("candidate_id", "x", "y")]
  center <- which(grid$x == 2 & grid$y == 2)
  plateau_metric <- 1 - 0.01 * (abs(grid$x - 2) + abs(grid$y - 2))
  spike_metric <- ifelse(grid$x == 2 & grid$y == 2, 1, 0)

  plateau <- ledgr:::ledgr_stable_region_detect(
    grid,
    plateau_metric,
    parameter_columns = c("x", "y"),
    min_neighbors = 4
  )
  spike <- ledgr:::ledgr_stable_region_detect(
    grid,
    spike_metric,
    parameter_columns = c("x", "y"),
    min_neighbors = 1
  )
  testthat::expect_s3_class(plateau, "ledgr_stable_region_evidence")
  testthat::expect_equal(plateau$summary$tau[[center]], 0.01, tolerance = 1e-15)
  testthat::expect_identical(plateau$summary$good_neighbors[[center]], 4L)
  testthat::expect_true(plateau$summary$eligible[[center]])
  testthat::expect_equal(spike$summary$tau[[center]], 0, tolerance = 1e-15)
  testthat::expect_identical(spike$summary$good_neighbors[[center]], 0L)
  testthat::expect_false(spike$summary$eligible[[center]])

  step <- ledgr_objective_stable_region(
    min_neighbors = 4,
    metric = "sharpe_ratio",
    parameter_columns = c("x", "y")
  )
  center_result <- ledgr:::ledgr_objective_step_evaluate(
    step,
    plateau,
    candidate_id = grid$candidate_id[[center]]
  )
  testthat::expect_true(center_result$passed)
  testthat::expect_identical(center_result$value, 4)
  testthat::expect_equal(center_result$details$tau, 0.01, tolerance = 1e-15)

  stricter_step <- ledgr_objective_stable_region(
    min_neighbors = 5,
    metric = "sharpe_ratio",
    parameter_columns = c("x", "y")
  )
  stricter_result <- ledgr:::ledgr_objective_step_evaluate(
    stricter_step,
    plateau,
    candidate_id = grid$candidate_id[[center]]
  )
  testthat::expect_identical(stricter_result$value, 4)
  testthat::expect_identical(stricter_result$threshold, 5L)
  testthat::expect_false(stricter_result$passed)
})

testthat::test_that("stable-region topology failures are classed and fail closed", {
  grid <- expand.grid(x = 1:3, y = 1:3, KEEP.OUT.ATTRS = FALSE)
  grid$candidate_id <- sprintf("candidate_%02d", seq_len(nrow(grid)))
  grid <- grid[, c("candidate_id", "x", "y")]
  metric <- seq_len(nrow(grid))

  testthat::expect_error(
    ledgr:::ledgr_stable_region_detect(grid, metric, c("x", "y"), min_neighbors = 0),
    class = "ledgr_stable_region_invalid_min_neighbors"
  )
  testthat::expect_error(
    ledgr:::ledgr_stable_region_detect(grid, replace(metric, 1L, NA_real_), c("x", "y")),
    class = "ledgr_stable_region_invalid_metric"
  )
  unordered <- data.frame(
    candidate_id = paste0("u", 1:4),
    x = factor(rep(c("low", "high"), each = 2)),
    y = rep(1:2, 2)
  )
  testthat::expect_error(
    ledgr:::ledgr_stable_region_detect(unordered, 1:4, c("x", "y")),
    class = "ledgr_stable_region_unordered_axis"
  )
  unsupported <- transform(unordered, x = as.character(x))
  testthat::expect_error(
    ledgr:::ledgr_stable_region_detect(unsupported, 1:4, c("x", "y")),
    class = "ledgr_stable_region_unsupported_axis"
  )
  collapsed <- data.frame(candidate_id = paste0("c", 1:3), x = 1, y = 1:3)
  testthat::expect_error(
    ledgr:::ledgr_stable_region_detect(collapsed, 1:3, c("x", "y")),
    class = "ledgr_stable_region_collapsed_axis"
  )
  duplicate <- rbind(grid, transform(grid[1L, ], candidate_id = "duplicate"))
  testthat::expect_error(
    ledgr:::ledgr_stable_region_detect(duplicate, c(metric, metric[[1L]]), c("x", "y")),
    class = "ledgr_stable_region_duplicate_tuple"
  )
  testthat::expect_error(
    ledgr:::ledgr_stable_region_detect(grid[-1L, ], metric[-1L], c("x", "y")),
    class = "ledgr_stable_region_incomplete_grid"
  )

  ordered_grid <- unordered
  ordered_grid$x <- ordered(ordered_grid$x, levels = c("low", "high"))
  ordered_result <- ledgr:::ledgr_stable_region_detect(ordered_grid, 1:4, c("x", "y"), min_neighbors = 1)
  testthat::expect_s3_class(ordered_result, "ledgr_stable_region_evidence")

  minimizing <- ledgr:::ledgr_stable_region_detect(
    grid,
    abs(grid$x - 2) + abs(grid$y - 2),
    c("x", "y"),
    direction = "minimize",
    min_neighbors = 4
  )
  center <- which(grid$x == 2 & grid$y == 2)
  testthat::expect_true(minimizing$summary$eligible[[center]])
  testthat::expect_identical(minimizing$summary$good_neighbors[[center]], 4L)
})

testthat::test_that("diagnostic thresholds snapshot ledgr-owned evidence without recomputation", {
  panel <- ledgr_objective_test_return_panel()
  dsr <- ledgr_dsr(panel, effective_trials = 2)
  min_trl <- ledgr_min_track_record(panel)
  dsr_step <- ledgr_objective_diagnostic_threshold(
    dsr,
    column = "dsr_probability",
    threshold = 0.50
  )
  min_trl_step <- ledgr_objective_diagnostic_threshold(
    min_trl,
    column = "min_track_record_length",
    threshold = 100
  )
  dsr_status <- ledgr_objective_diagnostic_threshold(
    dsr,
    column = "status",
    threshold = tibble::as_tibble(dsr)$status[[1L]]
  )

  testthat::expect_identical(dsr_step$params$comparison, "at_least")
  testthat::expect_identical(min_trl_step$params$comparison, "at_most")
  testthat::expect_identical(dsr_status$params$comparison, "equals")
  testthat::expect_match(dsr_step$params$source_hash, "^[0-9a-f]{64}$")
  testthat::expect_identical(dsr_step$params$source_hash, dsr_step$evidence_snapshot$source_hash)
  testthat::expect_identical(dsr_step$evidence_snapshot$source_metadata$panel_hash, panel$panel_hash)

  candidate_id <- tibble::as_tibble(dsr)$candidate_id[[1L]]
  expected_dsr <- tibble::as_tibble(dsr)$dsr_probability[[1L]]
  dsr_result <- ledgr:::ledgr_objective_step_evaluate(dsr_step, candidate_id = candidate_id)
  status_result <- ledgr:::ledgr_objective_step_evaluate(dsr_status, candidate_id = candidate_id)
  testthat::expect_equal(dsr_result$value, expected_dsr, tolerance = 1e-15)
  testthat::expect_identical(dsr_result$details$source_hash, dsr_step$params$source_hash)
  testthat::expect_true(status_result$passed)
  testthat::expect_identical(status_result$details$observed_status, dsr_status$params$threshold)

  weak_index <- seq_len(64L)
  weak_panel <- ledgr_return_panel(cbind(
    weak = -0.002 + 0.0005 * sin(weak_index / 4),
    stronger = 0.004 + 0.001 * cos(weak_index / 5)
  ))
  weak_min_trl <- ledgr_min_track_record(weak_panel)
  weak_step <- ledgr_objective_diagnostic_threshold(
    weak_min_trl,
    column = "min_track_record_length",
    threshold = 60
  )
  weak_result <- ledgr:::ledgr_objective_step_evaluate(
    weak_step,
    candidate_id = "weak"
  )
  testthat::expect_identical(weak_result$value, Inf)
  testthat::expect_false(weak_result$passed)

  for (indeterminate in list(NA_real_, NaN)) {
    indeterminate_min_trl <- weak_min_trl
    row <- match("weak", indeterminate_min_trl$summary$candidate_id)
    indeterminate_min_trl$summary$min_track_record_length[[row]] <- indeterminate
    indeterminate_step <- ledgr_objective_diagnostic_threshold(
      indeterminate_min_trl,
      column = "min_track_record_length",
      threshold = 60
    )
    testthat::expect_error(
      ledgr:::ledgr_objective_step_evaluate(
        indeterminate_step,
        candidate_id = "weak"
      ),
      class = "ledgr_objective_non_finite_evidence"
    )
  }

  changed_threshold <- ledgr_objective_diagnostic_threshold(
    dsr,
    column = "dsr_probability",
    threshold = 0.60
  )
  testthat::expect_false(identical(dsr_step$criterion_hash, changed_threshold$criterion_hash))

  changed_panel <- ledgr_objective_test_return_panel()
  changed_panel$matrix[[1L, 1L]] <- changed_panel$matrix[[1L, 1L]] + 0.001
  changed_panel$panel_hash <- ledgr:::ledgr_return_panel_hash(
    changed_panel$matrix,
    changed_panel$labels,
    changed_panel$value
  )
  changed_dsr <- ledgr_dsr(changed_panel, effective_trials = 2)
  changed_source <- ledgr_objective_diagnostic_threshold(
    changed_dsr,
    column = "dsr_probability",
    threshold = 0.50
  )
  testthat::expect_false(identical(dsr_step$params$source_hash, changed_source$params$source_hash))
  testthat::expect_false(identical(dsr_step$criterion_hash, changed_source$criterion_hash))

  objective <- ledgr_business_objective(dsr_step, min_trl_step)
  rebuilt <- ledgr:::ledgr_business_objective_from_plan_json(objective$plan_json)
  rebuilt_result <- ledgr:::ledgr_objective_step_evaluate(rebuilt$criteria[[1L]], candidate_id = candidate_id)
  testthat::expect_equal(rebuilt_result$value, dsr_result$value, tolerance = 1e-15)
  testthat::expect_identical(rebuilt$criteria[[1L]]$params$source_hash, dsr_step$params$source_hash)

  testthat::expect_error(
    ledgr_objective_diagnostic_threshold(dsr, "p_value", 0.05),
    class = "ledgr_invalid_diagnostic_threshold"
  )
  testthat::expect_error(
    ledgr_objective_diagnostic_threshold(min_trl, "min_TRL", 30),
    class = "ledgr_invalid_diagnostic_threshold"
  )
  testthat::expect_error(
    ledgr_objective_diagnostic_threshold(ledgr_pbo(panel, S = 4), "pbo", 0.5),
    class = "ledgr_invalid_diagnostic_threshold"
  )
  testthat::expect_error(
    ledgr:::ledgr_objective_step_evaluate(dsr_step, candidate_id = "missing"),
    class = "ledgr_objective_missing_evidence"
  )

  tampered <- dsr_step
  tampered$evidence_snapshot$records[[1L]]$value$value <- 0
  testthat::expect_error(
    ledgr:::ledgr_objective_step_evaluate(tampered, candidate_id = candidate_id),
    class = "ledgr_diagnostic_source_hash_mismatch"
  )
})
