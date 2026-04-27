testthat::test_that("ledgr_results delegates to tibble::as_tibble for supported result tables", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  strategy <- function(ctx) {
    targets <- ctx$targets()
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
    testthat::expect_equal(
      ledgr_results(bt, what = what),
      tibble::as_tibble(bt, what = what),
      ignore_attr = TRUE
    )
  }
  testthat::expect_error(ledgr_results(bt, what = "positions"))
})
