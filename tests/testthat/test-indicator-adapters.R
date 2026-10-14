testthat::test_that("ledgr_adapter_r wraps R functions", {
  ind <- ledgr:::ledgr_adapter_r(base::mean, id = "mean_close", requires_bars = 3L)
  testthat::expect_s3_class(ind, "ledgr_indicator")

  window <- data.frame(
    ts_utc = sprintf("2020-01-%02dT00:00:00Z", 1:3),
    instrument_id = rep("TEST_A", 3),
    open = c(1, 2, 3),
    high = c(1, 2, 3),
    low = c(1, 2, 3),
    close = c(1, 2, 3),
    volume = c(1, 1, 1),
    stringsAsFactors = FALSE
  )
  testthat::expect_equal(ind$fn(window), 2)
})

testthat::test_that("ledgr_adapter_r errors when package is missing", {
  testthat::expect_error(
    ledgr:::ledgr_adapter_r("NotAPkg::Nope", id = "bad", requires_bars = 1L),
    class = "ledgr_invalid_args"
  )
})

testthat::test_that("ledgr_adapter_csv loads once and looks up by ts/instrument", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)

  csv_df <- data.frame(
    ts_utc = c("2020-01-01T00:00:00Z", "2020-01-02T00:00:00Z"),
    instrument_id = c("TEST_A", "TEST_A"),
    signal = c(0.1, 0.2),
    stringsAsFactors = FALSE
  )
  utils::write.csv(csv_df, tmp, row.names = FALSE)

  ind <- ledgr:::ledgr_adapter_csv(
    csv_path = tmp,
    value_col = "signal",
    id = "csv_signal"
  )

  window <- data.frame(
    ts_utc = "2020-01-02T00:00:00Z",
    instrument_id = "TEST_A",
    open = 1,
    high = 1,
    low = 1,
    close = 1,
    volume = 1,
    stringsAsFactors = FALSE
  )

  testthat::expect_equal(ind$fn(window), 0.2)
})

testthat::test_that("ledgr_adapter_csv returns typed NA with a warning for missing keys", {
  local({
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)

  csv_df <- data.frame(
    ts_utc = c("2020-01-01T00:00:00Z"),
    instrument_id = c("TEST_A"),
    signal = c(0.1),
    stringsAsFactors = FALSE
  )
  utils::write.csv(csv_df, tmp, row.names = FALSE)

  ind <- ledgr:::ledgr_adapter_csv(
    csv_path = tmp,
    value_col = "signal",
    id = "csv_signal"
  )

  window <- data.frame(
    ts_utc = "2020-01-02T00:00:00Z",
    instrument_id = "TEST_A",
    open = 1,
    high = 1,
    low = 1,
    close = 1,
    volume = 1,
    stringsAsFactors = FALSE
  )

  testthat::expect_warning(
    result <- ind$fn(window),
    "No CSV value"
  )
  testthat::expect_true(is.na(result))
  })

  # Also covers: ledgr_adapter_csv returns NA_real_ for missing keys
  local({
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)

  csv_df <- data.frame(
    ts_utc = c("2020-01-01T00:00:00Z"),
    instrument_id = c("TEST_A"),
    signal = c("alpha"),
    stringsAsFactors = FALSE
  )
  utils::write.csv(csv_df, tmp, row.names = FALSE)

  ind <- ledgr:::ledgr_adapter_csv(
    csv_path = tmp,
    value_col = "signal",
    id = "csv_signal"
  )

  window <- data.frame(
    ts_utc = "2020-01-02T00:00:00Z",
    instrument_id = "TEST_A",
    open = 1,
    high = 1,
    low = 1,
    close = 1,
    volume = 1,
    stringsAsFactors = FALSE
  )

  testthat::expect_warning(result <- ind$fn(window), "No CSV value")
  testthat::expect_true(is.double(result))
  testthat::expect_true(is.na(result))
  })
})


# ledgr-test-profile: heavy_protocol
testthat::test_that("ledgr_adapter_r integrates with TTR when available", {
  testthat::skip_if_not_installed("TTR")

  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)
  bars <- ledgr_test_compact_bars(n_pulses = 16L)

  snap <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snap), add = TRUE)

  ind <- ledgr_adapter_r("TTR::RSI", id = "test_ttr_rsi", requires_bars = 15L, n = 14L)
  capture_strategy <- function(ctx, params) {
    values <- vapply(ctx$universe, function(id) ctx$feature(id, params$feature), numeric(1))
    list(
      targets = ctx$flat(),
      state_update = list(finite = as.list(stats::setNames(is.finite(values), names(values))))
    )
  }

  bt <- ledgr_backtest(
    snapshot = snap,
    strategy = capture_strategy,
    strategy_params = list(feature = "test_ttr_rsi"),
    universe = c("TEST_A", "TEST_B"),
    start = "2020-01-01",
    end = "2020-01-31",
    features = list(ind),
    db_path = db_path,
  cost_model = ledgr_cost_zero()
  )

  state <- availability_last_state(bt)
  testthat::expect_setequal(names(state$finite), c("TEST_A", "TEST_B"))
  testthat::expect_true(all(unlist(state$finite, use.names = FALSE)))
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("ledgr_adapter_csv integrates with runtime features", {
  db_path <- tempfile(fileext = ".duckdb")
  csv_path <- tempfile(fileext = ".csv")
  on.exit(unlink(db_path), add = TRUE)
  on.exit(unlink(csv_path), add = TRUE)
  bars <- ledgr_test_compact_bars()

  csv_df <- data.frame(
    ts_utc = vapply(bars$ts_utc, ledgr_iso_utc, character(1)),
    instrument_id = bars$instrument_id,
    signal = seq_len(nrow(bars)) / 100,
    stringsAsFactors = FALSE
  )
  utils::write.csv(csv_df, csv_path, row.names = FALSE)

  snap <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snap), add = TRUE)

  ind <- ledgr_adapter_csv(csv_path = csv_path, value_col = "signal", id = "test_csv_signal")
  capture_strategy <- function(ctx, params) {
    values <- vapply(ctx$universe, function(id) ctx$feature(id, params$feature), numeric(1))
    list(targets = ctx$flat(), state_update = list(values = as.list(values)))
  }

  bt <- ledgr_backtest(
    snapshot = snap,
    strategy = capture_strategy,
    strategy_params = list(feature = "test_csv_signal"),
    universe = c("TEST_A", "TEST_B"),
    start = "2020-01-01",
    end = "2020-01-10",
    features = list(ind),
    db_path = db_path,
  cost_model = ledgr_cost_zero()
  )

  state <- availability_last_state(bt)
  testthat::expect_setequal(names(state$values), c("TEST_A", "TEST_B"))
  last_rows <- bars$ts_utc == max(bars$ts_utc)
  last_keys <- paste(vapply(bars$ts_utc[last_rows], ledgr_iso_utc, character(1)), bars$instrument_id[last_rows], sep = "||")
  expected_key <- paste(csv_df$ts_utc, csv_df$instrument_id, sep = "||")
  testthat::expect_equal(
    unlist(state$values[c("TEST_A", "TEST_B")], use.names = FALSE),
    csv_df$signal[match(last_keys, expected_key)]
  )
})
