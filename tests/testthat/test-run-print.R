testthat::test_that("ledgr_run_list prints curated view while preserving tibble data", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snapshot <- ledgr_snapshot_from_df(test_bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["TEST_A"] <- 1
    targets
  }
  bt <- ledgr_backtest(
    snapshot = snapshot,
    strategy = strategy,
    start = "2020-01-01",
    end = "2020-01-05",
    db_path = db_path,
    run_id = "print-list"
  )
  on.exit(close(bt), add = TRUE)

  runs <- ledgr_run_list(snapshot)
  testthat::expect_s3_class(runs, "ledgr_run_list")
  testthat::expect_s3_class(runs, "tbl_df")
  testthat::expect_type(runs$total_return, "double")
  testthat::expect_type(runs$final_equity, "double")
  testthat::expect_true("strategy_source_hash" %in% names(runs))

  printed <- utils::capture.output(print(runs))
  testthat::expect_true(any(grepl("# ledgr run list", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("%", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("Full identity and telemetry columns", printed, fixed = TRUE)))
  testthat::expect_s3_class(tibble::as_tibble(runs), "tbl_df")
})

testthat::test_that("ledgr_compare_runs prints curated view while preserving numeric metrics", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snapshot <- ledgr_snapshot_from_df(test_bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["TEST_A"] <- params$qty
    targets
  }
  bt_a <- ledgr_backtest(
    snapshot = snapshot,
    strategy = strategy,
    strategy_params = list(qty = 1),
    start = "2020-01-01",
    end = "2020-01-05",
    db_path = db_path,
    run_id = "print-cmp-a"
  )
  on.exit(close(bt_a), add = TRUE)
  bt_b <- ledgr_backtest(
    snapshot = snapshot,
    strategy = strategy,
    strategy_params = list(qty = 2),
    start = "2020-01-01",
    end = "2020-01-05",
    db_path = db_path,
    run_id = "print-cmp-b"
  )
  on.exit(close(bt_b), add = TRUE)

  cmp <- ledgr_compare_runs(snapshot, run_ids = c("print-cmp-a", "print-cmp-b"))
  testthat::expect_s3_class(cmp, "ledgr_comparison")
  testthat::expect_s3_class(cmp, "tbl_df")
  testthat::expect_type(cmp$total_return, "double")
  testthat::expect_type(cmp$max_drawdown, "double")
  testthat::expect_type(cmp$win_rate, "double")
  testthat::expect_true("strategy_source_hash" %in% names(cmp))

  printed <- utils::capture.output(print(cmp))
  testthat::expect_true(any(grepl("# ledgr comparison", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("%", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("Full identity and telemetry columns", printed, fixed = TRUE)))
  testthat::expect_s3_class(tibble::as_tibble(cmp), "tbl_df")
})
