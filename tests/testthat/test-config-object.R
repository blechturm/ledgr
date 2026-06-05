testthat::test_that("ledgr_config is a validated internal S3 object", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snapshot <- ledgr_snapshot_from_df(test_bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) ctx$flat()
  config <- ledgr:::ledgr_config(
    snapshot = snapshot,
    universe = c("TEST_A", "TEST_B"),
    strategy = strategy,
    backtest = ledgr:::ledgr_backtest_config(
      start = "2020-01-01",
      end = "2020-01-05",
      initial_cash = 1000
    ),
    cost_model_hash = ledgr:::ledgr_cost_model_hash(ledgr_cost_zero()),
    cost_plan_json = ledgr:::ledgr_cost_plan_json(ledgr_cost_zero()),
    db_path = db_path
  )

  testthat::expect_s3_class(config, "ledgr_config")
  testthat::expect_error(ledgr:::validate_ledgr_config(config), NA)

  printed <- utils::capture.output(print(config))
  testthat::expect_true(any(grepl("ledgr_config", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("Timing Model:", printed, fixed = TRUE)))
})
