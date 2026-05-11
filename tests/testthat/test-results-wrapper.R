testthat::test_that("ledgr_results delegates to tibble::as_tibble for supported result tables", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["TEST_A"] <- 1
    targets
  }

  bt <- ledgr_backtest(
    data = test_bars,
    strategy = strategy,
    start = "2020-01-01",
    end = "2020-01-05",
    db_path = db_path,
    run_id = "results-wrapper-run"
  )
  on.exit(close(bt), add = TRUE)

  for (what in c("equity", "fills", "trades", "ledger")) {
    result <- ledgr_results(bt, what = what)
    testthat::expect_s3_class(result, "ledgr_result_table")
    testthat::expect_equal(
      tibble::as_tibble(result),
      tibble::as_tibble(bt, what = what),
      ignore_attr = TRUE
    )
    if ("ts_utc" %in% names(result)) {
      testthat::expect_s3_class(tibble::as_tibble(result)$ts_utc, "POSIXct")
    }
  }
  testthat::expect_error(
    ledgr_results(bt, what = "metrics"),
    "ledgr_compute_metrics\\(bt\\)",
    class = "ledgr_invalid_result_table"
  )
  testthat::expect_error(
    ledgr_results(bt, what = "positions"),
    "Unknown ledgr result table `positions`",
    class = "ledgr_invalid_result_table"
  )
})
