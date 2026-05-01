testthat::test_that("ledgr result table timestamp display is compact for EOD only", {
  eod <- ledgr_result_table(
    tibble::tibble(
      ts_utc = ledgr_utc(c("2020-01-01", "2020-01-02")),
      value = c(1, 2)
    ),
    what = "equity"
  )
  testthat::expect_s3_class(eod, "ledgr_result_table")
  testthat::expect_s3_class(eod$ts_utc, "POSIXct")

  printed <- utils::capture.output(print(eod))
  testthat::expect_true(any(grepl("2020-01-01", printed, fixed = TRUE)))
  testthat::expect_false(any(grepl("00:00:00", printed, fixed = TRUE)))

  raw <- tibble::as_tibble(eod)
  testthat::expect_s3_class(raw$ts_utc, "POSIXct")
  testthat::expect_false(inherits(raw, "ledgr_result_table"))

  intraday <- ledgr_result_table(
    tibble::tibble(
      ts_utc = ledgr_utc(c("2020-01-01 09:30:00", "2020-01-01 10:30:00")),
      value = c(1, 2)
    ),
    what = "fills"
  )
  printed_intraday <- utils::capture.output(print(intraday))
  testthat::expect_true(any(grepl("09:30:00", printed_intraday, fixed = TRUE)))
})

testthat::test_that("ledgr.print_ts_utc option controls result table display", {
  result <- ledgr_result_table(
    tibble::tibble(
      ts_utc = ledgr_utc(c("2020-01-01", "2020-01-02")),
      value = c(1, 2)
    ),
    what = "equity"
  )

  old <- getOption("ledgr.print_ts_utc")
  on.exit(options(ledgr.print_ts_utc = old), add = TRUE)

  options(ledgr.print_ts_utc = "datetime")
  printed <- utils::capture.output(print(result))
  testthat::expect_true(any(grepl("00:00:00", printed, fixed = TRUE)))

  options(ledgr.print_ts_utc = "auto")
  printed_auto <- utils::capture.output(print(result))
  testthat::expect_false(any(grepl("00:00:00", printed_auto, fixed = TRUE)))

  options(ledgr.print_ts_utc = "date")
  testthat::expect_error(print(result), class = "ledgr_invalid_option")
})
