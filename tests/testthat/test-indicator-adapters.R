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

testthat::test_that("ledgr_adapter_csv warns and returns NA on missing key", {
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

testthat::test_that("ledgr_adapter_csv returns NA_real_ for missing keys", {
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

testthat::test_that("ledgr_adapter_r integrates with TTR when available", {
  testthat::skip_if_not_installed("TTR")

  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snap <- ledgr_snapshot_from_df(test_bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snap), add = TRUE)

  ind <- ledgr_adapter_r("TTR::RSI", id = "test_ttr_rsi", requires_bars = 15L, n = 14L)
  zero_strategy <- function(ctx, params) {
    stats::setNames(rep(0, length(ctx$universe)), ctx$universe)
  }

  bt <- ledgr_backtest(
    snapshot = snap,
    strategy = zero_strategy,
    universe = c("TEST_A", "TEST_B"),
    start = "2020-01-01",
    end = "2020-01-31",
    features = list(ind),
    db_path = db_path
  )

  features <- DBI::dbGetQuery(
    ledgr:::get_connection(bt),
    "SELECT feature_name FROM features WHERE run_id = ?",
    params = list(bt$run_id)
  )
  testthat::expect_true("test_ttr_rsi" %in% unique(features$feature_name))
})

testthat::test_that("ledgr_adapter_csv integrates with feature persistence", {
  db_path <- tempfile(fileext = ".duckdb")
  csv_path <- tempfile(fileext = ".csv")
  on.exit(unlink(db_path), add = TRUE)
  on.exit(unlink(csv_path), add = TRUE)

  csv_df <- data.frame(
    ts_utc = vapply(test_bars$ts_utc, iso_utc, character(1)),
    instrument_id = test_bars$instrument_id,
    signal = seq_len(nrow(test_bars)) / 100,
    stringsAsFactors = FALSE
  )
  utils::write.csv(csv_df, csv_path, row.names = FALSE)

  snap <- ledgr_snapshot_from_df(test_bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snap), add = TRUE)

  ind <- ledgr_adapter_csv(csv_path = csv_path, value_col = "signal", id = "test_csv_signal")
  zero_strategy <- function(ctx, params) {
    stats::setNames(rep(0, length(ctx$universe)), ctx$universe)
  }

  bt <- ledgr_backtest(
    snapshot = snap,
    strategy = zero_strategy,
    universe = c("TEST_A", "TEST_B"),
    start = "2020-01-01",
    end = "2020-01-10",
    features = list(ind),
    db_path = db_path
  )

  persisted <- DBI::dbGetQuery(
    ledgr:::get_connection(bt),
    "
    SELECT ts_utc, instrument_id, feature_value
    FROM features
    WHERE run_id = ? AND feature_name = 'test_csv_signal'
    ORDER BY ts_utc, instrument_id
    ",
    params = list(bt$run_id)
  )
  testthat::expect_gt(nrow(persisted), 0L)
  first_key <- paste(iso_utc(persisted$ts_utc[[1]]), persisted$instrument_id[[1]], sep = "||")
  expected_key <- paste(csv_df$ts_utc, csv_df$instrument_id, sep = "||")
  testthat::expect_equal(
    as.numeric(persisted$feature_value[[1]]),
    csv_df$signal[[match(first_key, expected_key)]]
  )
})
