ledgr_sweep_filter_fixture <- function() {
  candidate_ids <- c("c11", "c12", "c21", "c22")
  candidate_rows <- seq_along(candidate_ids)
  params <- list(
    list(x = 1L, y = 1L),
    list(x = 1L, y = 2L),
    list(x = 2L, y = 1L),
    list(x = 2L, y = 2L)
  )
  sweep <- tibble::tibble(
    candidate_id = candidate_ids,
    candidate_row = candidate_rows,
    status = "DONE",
    max_drawdown = c(-0.10, -0.30, -0.12, -0.08),
    n_trades = 4L,
    sharpe_ratio = c(100, 99, 99, 98),
    params = params,
    feature_params = rep(list(list()), 4L)
  )
  class(sweep) <- c("ledgr_sweep_results", class(sweep))

  returns <- cbind(
    c11 = c(0.010, 0.012, 0.009, 0.011, 0.010, 0.013, 0.008, 0.012),
    c12 = c(-0.010, -0.008, -0.011, -0.009, -0.012, -0.007, -0.013, -0.009),
    c21 = c(0.006, 0.009, 0.005, 0.008, 0.007, 0.010, 0.004, 0.009),
    c22 = c(0.004, 0.007, 0.003, 0.006, 0.005, 0.008, 0.002, 0.007)
  )
  timestamps <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:8
  return_rows <- lapply(seq_along(candidate_ids), function(i) {
    equity <- c(100, 100 * cumprod(1 + returns[, i]))
    tibble::tibble(
      sweep_id = "sweep_filter_fixture",
      candidate_id = candidate_ids[[i]],
      ts_utc = timestamps,
      equity = equity,
      period_return = c(NA_real_, returns[, i])
    )
  })
  trade_rows <- lapply(seq_along(candidate_ids), function(i) {
    pnl <- if (identical(candidate_ids[[i]], "c12")) c(10, 1, 1, 1) else rep(1, 4)
    outcomes <- if (identical(candidate_ids[[i]], "c12")) {
      rep("WIN", 4)
    } else {
      rep(c("WIN", "LOSS"), 2)
    }
    tibble::tibble(
      sweep_id = "sweep_filter_fixture",
      candidate_id = candidate_ids[[i]],
      candidate_row = candidate_rows[[i]],
      trade_seq = 1:4,
      close_ts_utc = timestamps[c(2, 4, 6, 8)],
      realized_pnl = pnl,
      win_loss = outcomes
    )
  })

  attr(sweep, "sweep_id") <- "sweep_filter_fixture"
  attr(sweep, "snapshot_hash") <- paste(rep("1", 64L), collapse = "")
  attr(sweep, "metric_context_hash") <- paste(rep("2", 64L), collapse = "")
  attr(sweep, "cost_model_hash") <- paste(rep("3", 64L), collapse = "")
  attr(sweep, "risk_chain_hash") <- paste(rep("4", 64L), collapse = "")
  attr(sweep, "scoring_range") <- list(start = timestamps[[1L]], end = timestamps[[9L]])
  attr(sweep, "sweep_retention") <- ledgr_sweep_retention(
    returns = "completed",
    trades = "closed"
  )
  attr(sweep, "sweep_returns") <- do.call(rbind, return_rows)
  attr(sweep, "sweep_trades") <- do.call(rbind, trade_rows)
  sweep
}

testthat::test_that("ledgr_sweep_filter preserves all candidates and criterion rows", {
  sweep <- ledgr_sweep_filter_fixture()
  objective <- ledgr_business_objective(
    ledgr_objective_max_drawdown(0.20),
    ledgr_objective_min_trades(4),
    ledgr_objective_positive_trajectory(0)
  )
  identity_before <- ledgr:::ledgr_return_panel_sweep_identity(sweep)

  result <- ledgr_sweep_filter(sweep, objective)
  table <- tibble::as_tibble(result)

  testthat::expect_s3_class(result, "ledgr_sweep_filter_result")
  testthat::expect_identical(table, result$tear_down)
  testthat::expect_identical(
    table$candidate_id,
    rep(c("c11", "c12", "c21", "c22"), each = 3L)
  )
  testthat::expect_identical(
    table$criterion_id,
    rep(c("max_drawdown", "min_trades", "positive_trajectory"), 4L)
  )
  testthat::expect_identical(unique(table$eligible[table$candidate_id == "c11"]), TRUE)
  testthat::expect_identical(unique(table$eligible[table$candidate_id == "c12"]), FALSE)
  c11_drawdown <- table[
    table$candidate_id == "c11" & table$criterion_id == "max_drawdown",
  ]
  testthat::expect_identical(c11_drawdown$observed_value, 0.10)
  testthat::expect_identical(c11_drawdown$details[[1L]]$source_sign, "signed_drawdown")
  testthat::expect_true(all(c("criterion_params", "details") %in% names(table)))
  testthat::expect_false(any(c(
    "chosen_candidate", "selected_candidate", "rank", "selection"
  ) %in% names(table)))
  testthat::expect_identical(result$metadata$business_objective_hash, objective$business_objective_hash)
  testthat::expect_identical(result$metadata$sweep_id, "sweep_filter_fixture")
  testthat::expect_identical(ledgr:::ledgr_return_panel_sweep_identity(sweep), identity_before)

  tampered <- result
  tampered$tear_down <- tampered$tear_down[nrow(tampered$tear_down):1L, ]
  testthat::expect_error(
    tibble::as_tibble(tampered),
    class = "ledgr_invalid_sweep_filter_result"
  )

  printed <- capture.output(print(result))
  testthat::expect_false(any(grepl("more rows", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("all criteria must pass", printed, fixed = TRUE)))
})

testthat::test_that("ledgr_sweep_filter adapts all owned criterion evidence", {
  sweep <- ledgr_sweep_filter_fixture()
  dsr <- ledgr_dsr(sweep, effective_trials = 2)
  objective <- ledgr_business_objective(
    ledgr_objective_even_trades(0.30),
    ledgr_objective_even_profit(0.40),
    ledgr_objective_stable_region(
      min_neighbors = 1,
      metric = "sharpe_ratio",
      parameter_columns = c("x", "y")
    ),
    ledgr_objective_max_drawdown(0.20),
    ledgr_objective_stable_runs(2),
    ledgr_objective_min_trades(4),
    ledgr_objective_positive_trajectory(0),
    ledgr_objective_diagnostic_threshold(dsr, "dsr_probability", 0)
  )

  table <- tibble::as_tibble(ledgr_sweep_filter(sweep, objective))

  testthat::expect_identical(nrow(table), 32L)
  testthat::expect_setequal(
    unique(table$evidence_source),
    c(
      "closed_trades.close_ts_utc", "closed_trades.realized_pnl",
      "candidate_metric_lattice", "summary.max_drawdown",
      "closed_trades.win_loss", "summary.n_trades", "retained_equity",
      "diagnostic.dsr.dsr_probability"
    )
  )
  c12 <- table[table$candidate_id == "c12", ]
  testthat::expect_false(unique(c12$eligible))
  testthat::expect_true(any(!c12$passed))
  testthat::expect_identical(
    table$observed_value[table$candidate_id == "c12" & table$criterion_id == "stable_runs"],
    4
  )
  testthat::expect_true(all(table$business_objective_hash == objective$business_objective_hash))

  with_failed <- sweep
  with_failed$status[[2L]] <- "FAILED"
  reduced <- ledgr_sweep_filter(
    with_failed,
    ledgr_business_objective(ledgr_objective_max_drawdown(0.20))
  )
  testthat::expect_false("c12" %in% tibble::as_tibble(reduced)$candidate_id)
  testthat::expect_identical(reduced$metadata$excluded_candidate_ids, "c12")
})

testthat::test_that("ledgr_sweep_filter fails closed on missing or mismatched evidence", {
  sweep <- ledgr_sweep_filter_fixture()
  no_returns <- sweep
  attr(no_returns, "sweep_retention") <- ledgr_sweep_retention(trades = "closed")
  attr(no_returns, "sweep_returns") <- NULL
  testthat::expect_error(
    ledgr_sweep_filter(
      no_returns,
      ledgr_business_objective(ledgr_objective_positive_trajectory())
    ),
    class = "ledgr_sweep_returns_unretained"
  )

  no_trades <- sweep
  attr(no_trades, "sweep_retention") <- ledgr_sweep_retention("completed")
  attr(no_trades, "sweep_trades") <- NULL
  testthat::expect_error(
    ledgr_sweep_filter(
      no_trades,
      ledgr_business_objective(ledgr_objective_even_profit())
    ),
    class = "ledgr_sweep_trades_unretained"
  )

  panel <- ledgr_sweep_returns_panel(sweep)
  changed <- ledgr_return_panel(panel$matrix + 0.0001, ts = panel$ts_utc)
  diagnostic <- ledgr_dsr(changed, effective_trials = 2)
  objective <- ledgr_business_objective(
    ledgr_objective_diagnostic_threshold(diagnostic, "dsr_probability", 0.5)
  )
  testthat::expect_error(
    ledgr_sweep_filter(sweep, objective),
    class = "ledgr_sweep_filter_diagnostic_source_mismatch"
  )

  no_varying_axis <- sweep
  no_varying_axis$params <- rep(list(list(x = 1L, y = 1L)), nrow(no_varying_axis))
  stable_region <- ledgr_business_objective(
    ledgr_objective_stable_region(min_neighbors = 1, metric = "sharpe_ratio")
  )
  testthat::expect_error(
    ledgr_sweep_filter(no_varying_axis, stable_region),
    class = "ledgr_stable_region_invalid_grid"
  )
})

testthat::test_that("sweep-filter evidence is rejected by selection surfaces", {
  result <- ledgr_sweep_filter(
    ledgr_sweep_filter_fixture(),
    ledgr_business_objective(ledgr_objective_max_drawdown(0.20))
  )

  testthat::expect_error(
    ledgr_candidate(result),
    class = "ledgr_sweep_filter_not_candidate"
  )
  testthat::expect_error(
    ledgr_promote(NULL, result, run_id = "forbidden"),
    class = "ledgr_sweep_filter_promotion_forbidden"
  )
  testthat::expect_error(
    ledgr:::ledgr_selection_rule_select(ledgr_select_argmax("sharpe_ratio"), result),
    class = "ledgr_sweep_filter_walk_forward_forbidden"
  )
})

testthat::test_that("ledgr_sweep_filter evaluates reopened retained evidence", {
  bars <- data.frame(
    instrument_id = "AAA",
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:5,
    open = 100:105,
    high = 101:106,
    low = 99:104,
    close = c(100, 102, 101, 104, 103, 106),
    volume = 1000,
    stringsAsFactors = FALSE
  )
  snapshot <- ledgr_snapshot_from_df(
    bars,
    db_path = tempfile(fileext = ".duckdb"),
    snapshot_id = "filter_reopen_snapshot"
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["AAA"] <- params$qty
    targets
  }
  sweep <- ledgr_sweep(
    ledgr_experiment(snapshot, strategy, cost_model = ledgr_cost_zero()),
    ledgr_param_grid(a = list(qty = 1), b = list(qty = 2)),
    seed = 123L,
    retain = ledgr_sweep_retention("completed")
  )
  ledgr_sweep_save(sweep, snapshot, sweep_id = "filter_reopen_saved")
  reopened <- ledgr_sweep_open(snapshot, "filter_reopen_saved")
  objective <- ledgr_business_objective(
    ledgr_objective_max_drawdown(1),
    ledgr_objective_min_trades(0),
    ledgr_objective_positive_trajectory(-1)
  )

  result <- ledgr_sweep_filter(reopened, objective)
  table <- tibble::as_tibble(result)

  testthat::expect_identical(unique(table$candidate_id), c("a", "b"))
  testthat::expect_identical(nrow(table), 6L)
  testthat::expect_identical(result$metadata$sweep_id, "filter_reopen_saved")
  testthat::expect_identical(
    result$metadata$input_identity$snapshot_hash,
    attr(reopened, "snapshot_hash", exact = TRUE)
  )
})
