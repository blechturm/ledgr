testthat::test_that("ledgr_backtest S3 methods return tidy outputs", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snap <- ledgr_snapshot_from_df(test_bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snap), add = TRUE)

  one_leg <- function(ctx) c(TEST_A = 100)

  bt <- ledgr_backtest(
    snapshot = snap,
    strategy = one_leg,
    universe = "TEST_A",
    start = "2020-01-01",
    end = "2020-01-15",
    db_path = db_path
  )

  out_print <- capture.output(print(bt))
  testthat::expect_true(any(grepl("ledgr Backtest Results", out_print)))
  testthat::expect_true(any(grepl("Run ID", out_print)))

  out_summary <- capture.output(summary(bt))
  testthat::expect_true(any(grepl("ledgr Backtest Summary", out_summary)))
  testthat::expect_true(any(grepl("Total Return", out_summary)))

  eq <- as_tibble(bt, "equity")
  testthat::expect_s3_class(eq, "tbl_df")
  testthat::expect_true(all(c("running_max", "drawdown") %in% names(eq)))

  fills <- as_tibble(bt, "fills")
  testthat::expect_s3_class(fills, "tbl_df")
  testthat::expect_true("realized_pnl" %in% names(fills))

  trades <- as_tibble(bt, type = "trades")
  testthat::expect_s3_class(trades, "tbl_df")

  ledger <- as_tibble(bt, "ledger")
  testthat::expect_s3_class(ledger, "tbl_df")
  testthat::expect_true("event_seq" %in% names(ledger))
})
