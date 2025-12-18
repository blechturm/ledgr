testthat::test_that("fill model is deterministic and rounds fill_price", {
  bar <- list(
    instrument_id = "AAA",
    ts_utc = as.POSIXct("2020-01-02 00:00:00", tz = "UTC"),
    open = 100.123456789
  )

  a <- ledgr:::ledgr_fill_next_open(
    desired_qty_delta = 10,
    next_bar = bar,
    spread_bps = 7,
    commission_fixed = 1.25
  )
  b <- ledgr:::ledgr_fill_next_open(
    desired_qty_delta = 10,
    next_bar = bar,
    spread_bps = 7,
    commission_fixed = 1.25
  )

  testthat::expect_identical(a, b)
  testthat::expect_identical(a$side, "BUY")
  testthat::expect_equal(a$qty, 10)
  testthat::expect_equal(a$fill_price, round(100.123456789 * (1 + 7 / 10000), 8))
})

testthat::test_that("BUY/SELL spread adjustment is symmetric and spread=0 yields open", {
  bar <- list(
    instrument_id = "AAA",
    ts_utc = "2020-01-02T00:00:00Z",
    open = 100
  )

  buy <- ledgr:::ledgr_fill_next_open(
    desired_qty_delta = 1,
    next_bar = bar,
    spread_bps = 10,
    commission_fixed = 0
  )
  sell <- ledgr:::ledgr_fill_next_open(
    desired_qty_delta = -1,
    next_bar = bar,
    spread_bps = 10,
    commission_fixed = 0
  )

  testthat::expect_equal(buy$fill_price, 100 * (1 + 10 / 10000))
  testthat::expect_equal(sell$fill_price, 100 * (1 - 10 / 10000))

  buy0 <- ledgr:::ledgr_fill_next_open(
    desired_qty_delta = 1,
    next_bar = bar,
    spread_bps = 0,
    commission_fixed = 0
  )
  sell0 <- ledgr:::ledgr_fill_next_open(
    desired_qty_delta = -1,
    next_bar = bar,
    spread_bps = 0,
    commission_fixed = 0
  )

  testthat::expect_equal(buy0$fill_price, 100)
  testthat::expect_equal(sell0$fill_price, 100)
})

testthat::test_that("commission is included and must be non-negative", {
  bar <- list(
    instrument_id = "AAA",
    ts_utc = "2020-01-02T00:00:00Z",
    open = 100
  )

  fill <- ledgr:::ledgr_fill_next_open(
    desired_qty_delta = 1,
    next_bar = bar,
    spread_bps = 0,
    commission_fixed = 2.5
  )
  testthat::expect_equal(fill$commission_fixed, 2.5)

  testthat::expect_error(
    ledgr:::ledgr_fill_next_open(
      desired_qty_delta = 1,
      next_bar = bar,
      spread_bps = 0,
      commission_fixed = -0.1
    ),
    "commission_fixed",
    fixed = TRUE
  )
})

testthat::test_that("last-bar policy returns a structured NO_FILL with WARN code", {
  out <- ledgr:::ledgr_fill_next_open(
    desired_qty_delta = 1,
    next_bar = NULL,
    spread_bps = 0,
    commission_fixed = 0
  )

  testthat::expect_s3_class(out, "ledgr_fill_none")
  testthat::expect_identical(out$status, "NO_FILL")
  testthat::expect_identical(out$warn_code, "LEDGR_LAST_BAR_NO_FILL")
})

testthat::test_that("invalid inputs fail loud", {
  bar <- list(instrument_id = "AAA", ts_utc = "2020-01-02T00:00:00Z", open = 100)

  testthat::expect_error(
    ledgr:::ledgr_fill_next_open(desired_qty_delta = Inf, next_bar = bar, spread_bps = 0, commission_fixed = 0),
    "desired_qty_delta",
    fixed = TRUE
  )

  testthat::expect_error(
    ledgr:::ledgr_fill_next_open(desired_qty_delta = 1, next_bar = list(instrument_id = "AAA", ts_utc = "2020-01-02T00:00:00Z", open = NaN), spread_bps = 0, commission_fixed = 0),
    "next_bar$open",
    fixed = TRUE
  )

  testthat::expect_error(
    ledgr:::ledgr_fill_next_open(desired_qty_delta = 1, next_bar = bar, spread_bps = -1, commission_fixed = 0),
    "spread_bps",
    fixed = TRUE
  )
})
