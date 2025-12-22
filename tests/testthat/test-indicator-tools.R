testthat::test_that("ledgr_indicator_dev returns a read-only window", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snap <- ledgr_snapshot_from_df(test_bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snap), add = TRUE)

  ts_utc <- iso_utc(test_bars$ts_utc[[10]])
  dev <- ledgr:::ledgr_indicator_dev(snap, "TEST_A", ts_utc, lookback = 5L)
  on.exit(ledgr:::close.ledgr_indicator_dev(dev), add = TRUE)

  testthat::expect_s3_class(dev, "ledgr_indicator_dev")
  testthat::expect_true(is.data.frame(dev$window))
  testthat::expect_equal(nrow(dev$window), 5L)
  testthat::expect_true(is.function(dev$test))
  testthat::expect_true(is.function(dev$plot))
})

testthat::test_that("ledgr_pulse_snapshot computes features in-memory", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snap <- ledgr_snapshot_from_df(test_bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snap), add = TRUE)

  ts_utc <- iso_utc(test_bars$ts_utc[[10]])
  universe <- c("TEST_A", "TEST_B")
  features <- list(ledgr:::ledgr_ind_sma(3))

  ctx <- ledgr:::ledgr_pulse_snapshot(
    snapshot = snap,
    universe = universe,
    ts_utc = ts_utc,
    features = features,
    initial_cash = 1000
  )
  on.exit(ledgr:::close.ledgr_pulse_context(ctx), add = TRUE)

  testthat::expect_s3_class(ctx, "ledgr_pulse_context")
  testthat::expect_true(is.data.frame(ctx$bars))
  testthat::expect_equal(nrow(ctx$bars), length(universe))
  testthat::expect_true(is.data.frame(ctx$features))
  testthat::expect_true(all(c("ts_utc", "instrument_id", "feature_name", "feature_value") %in% names(ctx$features)))
})
