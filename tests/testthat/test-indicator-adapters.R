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
