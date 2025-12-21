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
