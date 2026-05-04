testthat::test_that("ledgr_feature_contracts supports maps, named lists, unnamed lists, and indicators", {
  features <- ledgr_feature_map(
    ret = ledgr_ind_returns(5),
    sma = ledgr_ind_sma(10)
  )

  contracts <- ledgr_feature_contracts(features)
  testthat::expect_s3_class(contracts, "tbl_df")
  testthat::expect_equal(names(contracts), c("alias", "feature_id", "source", "requires_bars", "stable_after"))
  testthat::expect_equal(contracts$alias, c("ret", "sma"))
  testthat::expect_equal(contracts$feature_id, c("return_5", "sma_10"))
  testthat::expect_equal(contracts$source, c("ledgr", "ledgr"))

  named <- ledgr_feature_contracts(list(signal = ledgr_ind_returns(2)))
  testthat::expect_equal(named$alias, "signal")
  testthat::expect_equal(named$feature_id, "return_2")

  unnamed <- ledgr_feature_contracts(list(ledgr_ind_returns(2)))
  testthat::expect_true(is.na(unnamed$alias[[1]]))
  testthat::expect_equal(unnamed$feature_id, "return_2")

  single <- ledgr_feature_contracts(ledgr_ind_sma(3))
  testthat::expect_true(is.na(single$alias[[1]]))
  testthat::expect_equal(single$feature_id, "sma_3")

  custom <- ledgr_indicator(
    id = "custom_close",
    fn = function(window) tail(window$close, 1),
    requires_bars = 1
  )
  testthat::expect_equal(ledgr_feature_contracts(custom)$source, "custom")

  custom_matching_builtin_shape <- ledgr_indicator(
    id = "sma_10",
    fn = function(window) tail(window$close, 1),
    requires_bars = 10,
    params = list(n = 10)
  )
  testthat::expect_equal(ledgr_feature_contracts(custom_matching_builtin_shape)$source, "custom")

  testthat::expect_error(
    ledgr_feature_contracts(list(bad = "not an indicator")),
    class = "ledgr_invalid_args"
  )
})

testthat::test_that("ledgr_feature_contracts identifies TTR-backed indicators when TTR is installed", {
  testthat::skip_if_not_installed("TTR")

  contracts <- ledgr_feature_contracts(
    ledgr_feature_map(rsi = ledgr_ind_ttr("RSI", input = "close", n = 14))
  )

  testthat::expect_equal(contracts$source, "TTR")
  testthat::expect_equal(contracts$feature_id, "ttr_rsi_14")
})

testthat::test_that("pulse feature views expose long and wide pulse-known data", {
  bars <- ledgr_test_make_bars(c("AAA", "BBB"), as.Date("2020-01-01") + 0:5)
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  features <- ledgr_feature_map(
    ret = ledgr_ind_returns(2),
    sma = ledgr_ind_sma(3)
  )
  pulse <- ledgr_pulse_snapshot(
    snapshot,
    universe = c("AAA", "BBB"),
    ts_utc = ledgr_utc("2020-01-06"),
    features = features,
    initial_cash = 1000
  )
  on.exit(close(pulse), add = TRUE)

  long_all <- ledgr_pulse_features(pulse)
  testthat::expect_s3_class(long_all, "tbl_df")
  testthat::expect_equal(names(long_all), c("ts_utc", "instrument_id", "feature_id", "feature_value", "alias"))
  testthat::expect_s3_class(long_all$ts_utc, "POSIXct")
  testthat::expect_equal(long_all$instrument_id, rep(c("AAA", "BBB"), each = 2))
  testthat::expect_equal(long_all$feature_id, rep(c("return_2", "sma_3"), times = 2))
  testthat::expect_true(all(is.na(long_all$alias)))
  testthat::expect_true(all(c("return_2", "sma_3") %in% long_all$feature_id))

  long_mapped <- ledgr_pulse_features(pulse, features)
  testthat::expect_s3_class(long_mapped, "tbl_df")
  testthat::expect_equal(long_mapped$instrument_id, rep(c("AAA", "BBB"), each = 2))
  testthat::expect_equal(long_mapped$alias, rep(c("ret", "sma"), times = 2))
  testthat::expect_equal(long_mapped$feature_id, rep(c("return_2", "sma_3"), times = 2))

  wide <- ledgr_pulse_wide(pulse, features)
  testthat::expect_s3_class(wide, "tbl_df")
  testthat::expect_equal(nrow(wide), 1L)
  testthat::expect_true(all(c("ts_utc", "cash", "equity") %in% names(wide)))
  testthat::expect_s3_class(wide$ts_utc, "POSIXct")
  testthat::expect_equal(
    names(wide),
    c(
      "ts_utc", "cash", "equity",
      "AAA__ohlcv_open", "AAA__ohlcv_high", "AAA__ohlcv_low", "AAA__ohlcv_close", "AAA__ohlcv_volume",
      "AAA__feature_return_2", "AAA__feature_sma_3",
      "BBB__ohlcv_open", "BBB__ohlcv_high", "BBB__ohlcv_low", "BBB__ohlcv_close", "BBB__ohlcv_volume",
      "BBB__feature_return_2", "BBB__feature_sma_3"
    )
  )
  testthat::expect_false(any(grepl("__ret$|__sma$", names(wide))))

  testthat::expect_equal(wide[["AAA__ohlcv_close"]], pulse$close("AAA"))
  testthat::expect_equal(wide[["BBB__ohlcv_volume"]], pulse$volume("BBB"))
  testthat::expect_equal(wide[["AAA__feature_return_2"]], pulse$feature("AAA", "return_2"))
  testthat::expect_equal(wide[["BBB__feature_sma_3"]], pulse$feature("BBB", "sma_3"))

  wide_all <- ledgr_pulse_wide(pulse)
  testthat::expect_s3_class(wide_all, "tbl_df")
  testthat::expect_equal(
    names(wide_all),
    c(
      "ts_utc", "cash", "equity",
      "AAA__ohlcv_open", "AAA__ohlcv_high", "AAA__ohlcv_low", "AAA__ohlcv_close", "AAA__ohlcv_volume",
      "AAA__feature_return_2", "AAA__feature_sma_3",
      "BBB__ohlcv_open", "BBB__ohlcv_high", "BBB__ohlcv_low", "BBB__ohlcv_close", "BBB__ohlcv_volume",
      "BBB__feature_return_2", "BBB__feature_sma_3"
    )
  )

  testthat::expect_error(
    ledgr_validate_pulse_wide_names(instruments = "AA__A", feature_ids = "return_2"),
    class = "ledgr_invalid_pulse_wide_names"
  )
  testthat::expect_error(
    ledgr_validate_pulse_wide_names(instruments = "AAA", feature_ids = "bad__feature"),
    class = "ledgr_invalid_pulse_wide_names"
  )
})

testthat::test_that("feature inspection views fail loudly for unregistered mapped feature IDs", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:5)
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  pulse <- ledgr_pulse_snapshot(
    snapshot,
    universe = "AAA",
    ts_utc = ledgr_utc("2020-01-06"),
    features = list(ledgr_ind_sma(3))
  )
  on.exit(close(pulse), add = TRUE)

  testthat::expect_error(
    ledgr_pulse_features(pulse, ledgr_feature_map(ret = ledgr_ind_returns(2))),
    class = "ledgr_unknown_feature_id"
  )
})

testthat::test_that("feature inspection views match across execution modes", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:8)
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  features <- ledgr_feature_map(ret = ledgr_ind_returns(2), sma = ledgr_ind_sma(3))
  observed <- list()
  strategy <- function(ctx, params) {
    # Overwrite on each pulse and retain the terminal pulse for parity checks.
    long <- ledgr_pulse_features(ctx, features)
    wide <- ledgr_pulse_wide(ctx, features)
    long_all <- ledgr_pulse_features(ctx)
    wide_all <- ledgr_pulse_wide(ctx)
    long$ts_utc <- format(long$ts_utc, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    wide$ts_utc <- format(wide$ts_utc, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    long_all$ts_utc <- format(long_all$ts_utc, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    wide_all$ts_utc <- format(wide_all$ts_utc, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    observed[[ctx$run_id]] <<- list(
      long = long,
      wide = wide,
      long_all = long_all,
      wide_all = wide_all
    )
    targets <- ctx$flat()
    x <- ctx$features("AAA", features)
    if (passed_warmup(x) && x[["ret"]] > 0) {
      targets["AAA"] <- 1
    }
    targets
  }

  for (mode in c("audit_log", "db_live")) {
    local({
      exp <- ledgr_experiment(
        snapshot = snapshot,
        strategy = strategy,
        features = features,
        opening = ledgr_opening(cash = 1000),
        execution_mode = mode
      )
      bt <- ledgr_run(exp, params = list(), run_id = paste0("inspection-", mode))
      on.exit(close(bt), add = TRUE)
    })
  }

  audit <- observed[["inspection-audit_log"]]
  live <- observed[["inspection-db_live"]]
  testthat::expect_equal(audit$long$feature_id, live$long$feature_id)
  testthat::expect_equal(audit$long$alias, live$long$alias)
  testthat::expect_equal(audit$long$feature_value, live$long$feature_value, tolerance = 1e-8)
  testthat::expect_equal(names(audit$wide), names(live$wide))
  testthat::expect_equal(audit$wide, live$wide, tolerance = 1e-8)
  testthat::expect_equal(audit$long_all$feature_id, live$long_all$feature_id)
  testthat::expect_equal(audit$long_all$alias, live$long_all$alias)
  testthat::expect_equal(audit$long_all$feature_value, live$long_all$feature_value, tolerance = 1e-8)
  testthat::expect_equal(names(audit$wide_all), names(live$wide_all))
  testthat::expect_equal(audit$wide_all, live$wide_all, tolerance = 1e-8)
})
