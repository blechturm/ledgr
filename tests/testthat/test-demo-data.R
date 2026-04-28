testthat::test_that("ledgr_sim_bars is deterministic and schema-compatible", {
  a <- ledgr_sim_bars(n_instruments = 3, n_days = 20, seed = 42)
  b <- ledgr_sim_bars(n_instruments = 3, n_days = 20, seed = 42)
  c <- ledgr_sim_bars(n_instruments = 3, n_days = 20, seed = 43)

  testthat::expect_identical(a, b)
  testthat::expect_false(identical(a, c))
  testthat::expect_identical(
    names(a),
    c("ts_utc", "instrument_id", "open", "high", "low", "close", "volume")
  )
  testthat::expect_s3_class(a$ts_utc, "POSIXct")
  testthat::expect_identical(attr(a$ts_utc, "tzone"), "UTC")
  testthat::expect_identical(nrow(a), 60L)
  testthat::expect_identical(length(unique(a$instrument_id)), 3L)
  testthat::expect_true(all(a$high >= pmax(a$open, a$close)))
  testthat::expect_true(all(a$low <= pmin(a$open, a$close)))
  testthat::expect_true(all(a$low > 0))
  testthat::expect_true(all(a$volume > 0))
})

testthat::test_that("ledgr_sim_bars validates arguments", {
  testthat::expect_error(ledgr_sim_bars(n_instruments = 0), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_sim_bars(n_days = 1.5), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_sim_bars(seed = NA), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_sim_bars(start = "not-a-date"), class = "ledgr_invalid_args")
})

testthat::test_that("ledgr_demo_bars is an offline multi-instrument demo dataset", {
  testthat::expect_true(exists("ledgr_demo_bars"))
  testthat::expect_identical(
    names(ledgr_demo_bars),
    c("ts_utc", "instrument_id", "open", "high", "low", "close", "volume")
  )
  testthat::expect_gte(length(unique(ledgr_demo_bars$instrument_id)), 10L)
  testthat::expect_gte(min(table(ledgr_demo_bars$instrument_id)), 252L * 5L)
  testthat::expect_true(all(ledgr_demo_bars$high >= pmax(ledgr_demo_bars$open, ledgr_demo_bars$close)))
  testthat::expect_true(all(ledgr_demo_bars$low <= pmin(ledgr_demo_bars$open, ledgr_demo_bars$close)))

  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)
  snapshot <- ledgr_snapshot_from_df(utils::head(ledgr_demo_bars, 200), db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  testthat::expect_s3_class(snapshot, "ledgr_snapshot")
})
