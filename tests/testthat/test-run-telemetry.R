testthat::test_that("successful runs persist compact telemetry and print execution mode", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  strategy <- function(ctx, params) ctx$flat()

  bt <- ledgr_backtest(
    data = test_bars,
    strategy = strategy,
    start = "2020-01-01",
    end = "2020-01-05",
    db_path = db_path,
    run_id = "telemetry-success",
    persist_features = FALSE,
  cost_model = ledgr_cost_zero()
  )
  on.exit(close(bt), add = TRUE)
  snapshot <- ledgr_test_snapshot_for_run(db_path, bt)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  printed_bt <- utils::capture.output(print(bt))
  testthat::expect_true(any(grepl("Execution Mode:", printed_bt, fixed = TRUE)))
  testthat::expect_true(any(grepl("audit_log", printed_bt, fixed = TRUE)))

  info <- ledgr_run_info(snapshot, "telemetry-success")
  testthat::expect_identical(info$status, "DONE")
  testthat::expect_identical(info$execution_mode, "audit_log")
  testthat::expect_true(is.finite(info$elapsed_sec))
  testthat::expect_identical(as.integer(info$pulse_count), 5L)
  testthat::expect_identical(info$persist_features, FALSE)
  testthat::expect_identical(as.integer(info$feature_cache_hits), 0L)
  testthat::expect_identical(as.integer(info$feature_cache_misses), 0L)

  printed_info <- utils::capture.output(print(info))
  testthat::expect_true(any(grepl("Cache Hits:", printed_info, fixed = TRUE)))
  testthat::expect_true(any(grepl("Cache Misses:", printed_info, fixed = TRUE)))
  testthat::expect_true(any(grepl("Persist Features:", printed_info, fixed = TRUE)))
})

testthat::test_that("diagnostic fold-loop telemetry records sampled buckets", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets[[ctx$universe[[1L]]]] <- 1
    targets
  }

  bt <- ledgr_backtest(
    data = test_bars,
    strategy = strategy,
    start = "2020-01-01",
    end = "2020-01-05",
    db_path = db_path,
    run_id = "telemetry-buckets",
    persist_features = FALSE,
    control = list(telemetry_stride = 1L),
  cost_model = ledgr_cost_zero()
  )
  on.exit(close(bt), add = TRUE)

  bench <- ledgr_backtest_bench(bt)
  telemetry <- ledgr:::ledgr_get_run_telemetry(bt$run_id)
  expected <- c(
    "t_pulse",
    "t_bars",
    "t_ctx",
    "t_fill",
    "t_state",
    "t_feats",
    "t_strat",
    "t_target",
    "t_event",
    "t_exec"
  )
  testthat::expect_true(all(expected %in% bench$component))
  testthat::expect_gt(length(telemetry$t_pulse), 0L)
  testthat::expect_equal(
    telemetry$t_exec,
    telemetry$t_target + telemetry$t_fill + telemetry$t_event + telemetry$t_state
  )
  sampled <- bench[bench$component %in% expected, , drop = FALSE]
  testthat::expect_true(all(is.finite(sampled$mean)))
  testthat::expect_true(bench$mean[bench$component == "t_pulse"] >= 0)
})

testthat::test_that("failed runs persist minimum telemetry diagnostics", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  bad_strategy <- function(ctx, params) {
    stop("strategy boom")
  }

  testthat::expect_error(
    ledgr_backtest(
      data = test_bars,
      strategy = bad_strategy,
      start = "2020-01-01",
      end = "2020-01-05",
      db_path = db_path,
      run_id = "telemetry-failed",
    cost_model = ledgr_cost_zero()
    ),
    "strategy boom"
  )
  opened_snapshot <- ledgr_test_open_duckdb(db_path)
  snapshot_id <- DBI::dbGetQuery(
    opened_snapshot$con,
    "SELECT snapshot_id FROM runs WHERE run_id = 'telemetry-failed'"
  )$snapshot_id[[1]]
  ledgr_test_close_duckdb(opened_snapshot$con, opened_snapshot$drv)
  snapshot <- ledgr_snapshot_load(db_path, snapshot_id)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  info <- ledgr_run_info(snapshot, "telemetry-failed")
  testthat::expect_identical(info$status, "FAILED")
  testthat::expect_identical(info$telemetry_missing, FALSE)
  testthat::expect_identical(info$execution_mode, "audit_log")
  testthat::expect_true(is.finite(info$elapsed_sec))
  testthat::expect_identical(info$persist_features, TRUE)
  testthat::expect_true(is.na(info$feature_cache_hits) || is.integer(as.integer(info$feature_cache_hits)))
  testthat::expect_true(is.na(info$feature_cache_misses) || is.integer(as.integer(info$feature_cache_misses)))
  testthat::expect_match(info$error_msg, "strategy boom", fixed = TRUE)

  opened <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  row <- DBI::dbGetQuery(
    opened$con,
    "SELECT status, execution_mode, elapsed_sec FROM run_telemetry WHERE run_id = 'telemetry-failed'"
  )
  testthat::expect_identical(nrow(row), 1L)
  testthat::expect_identical(row$status[[1]], "FAILED")
  testthat::expect_identical(row$execution_mode[[1]], "audit_log")
  testthat::expect_true(is.finite(row$elapsed_sec[[1]]))
})
