test_that("iso_utc normalizes supported inputs", {
  expect_equal(iso_utc(as.Date("2020-01-01")), "2020-01-01T00:00:00Z")

  ts <- as.POSIXct("2020-01-01 12:34:56", tz = "UTC")
  expect_equal(iso_utc(ts), "2020-01-01T12:34:56Z")

  expect_equal(iso_utc("2020-01-01"), "2020-01-01T00:00:00Z")
  expect_equal(iso_utc("2020-01-01T00:00:00Z"), "2020-01-01T00:00:00Z")
  expect_equal(iso_utc("2020-01-01T12:34:56"), "2020-01-01T12:34:56Z")
})

test_that("iso_utc rejects unsupported formats", {
  expect_error(iso_utc("01/02/2020"), "Unsupported timestamp format")
  expect_error(iso_utc("2020-01-01T12:34"), "Unsupported timestamp format")
  expect_error(iso_utc("2016-12-31T23:59:60Z"), "Unsupported timestamp format")
  expect_error(iso_utc(NA_character_), "non-empty")
})

test_that("ledgr_utc returns UTC POSIXct vectors", {
  x <- ledgr_utc(c("2020-01-01", "2020-01-01 09:30:00", "2020-01-01T10:30:00Z"))
  expect_s3_class(x, "POSIXct")
  expect_identical(attr(x, "tzone"), "UTC")
  expect_identical(
    format(x, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    c("2020-01-01T00:00:00Z", "2020-01-01T09:30:00Z", "2020-01-01T10:30:00Z")
  )

  d <- ledgr_utc(as.Date(c("2020-01-01", "2020-01-02")))
  expect_identical(
    format(d, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    c("2020-01-01T00:00:00Z", "2020-01-02T00:00:00Z")
  )
  expect_error(ledgr_utc("not-a-date"), class = "ledgr_invalid_timestamp")
  expect_error(ledgr_utc(NA_character_), class = "ledgr_invalid_timestamp")
})
