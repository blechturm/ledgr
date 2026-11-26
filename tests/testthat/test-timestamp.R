test_that("ledgr_iso_utc normalizes supported inputs", {
  expect_equal(ledgr_iso_utc(as.Date("2020-01-01")), "2020-01-01T00:00:00Z")

  ts <- as.POSIXct("2020-01-01 12:34:56", tz = "UTC")
  expect_equal(ledgr_iso_utc(ts), "2020-01-01T12:34:56Z")

  expect_equal(ledgr_iso_utc("2020-01-01"), "2020-01-01T00:00:00Z")
  expect_equal(ledgr_iso_utc("2020-01-01T00:00:00Z"), "2020-01-01T00:00:00Z")
  expect_equal(ledgr_iso_utc("2020-01-01T12:34:56"), "2020-01-01T12:34:56Z")
})

test_that("ledgr_iso_utc rejects unsupported formats", {
  expect_error(ledgr_iso_utc("01/02/2020"), "trailing `Z`")
  expect_error(ledgr_iso_utc("2020-01-01T12:34"), "2020-01-01T00:00:00Z", fixed = TRUE)
  expect_error(ledgr_iso_utc("2016-12-31T23:59:60Z"), "UTC timestamp")
  expect_error(ledgr_iso_utc(NA_character_), "non-empty")
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

testthat::test_that("[LTB-0566] ledgr_utc parses character vectors exactly as one value at a time", {
  # The fixture holds the per-element results of the parser before Cut 25
  # (dev/bench/v0_2_3_cut25_chores/utc_probe.R on ca635540): 500 accepted
  # strings over the four accepted forms, then 32 edge values.
  oracle <- utils::read.csv(
    testthat::test_path("fixtures", "ledgr-utc-oracle.csv"),
    stringsAsFactors = FALSE, na.strings = "NA", encoding = "UTF-8"
  )
  valid <- oracle[oracle$set == "valid500", ]
  edge <- oracle[oracle$set == "edge", ]
  testthat::expect_identical(nrow(valid), 500L)
  testthat::expect_identical(nrow(edge), 32L)

  whole <- ledgr_utc(valid$input)
  testthat::expect_s3_class(whole, "POSIXct")
  testthat::expect_identical(attr(whole, "tzone"), "UTC")
  testthat::expect_identical(as.numeric(whole), valid$seconds)

  refused <- nzchar(edge$class)
  testthat::expect_identical(sum(refused), 21L)
  for (i in which(!refused)) {
    testthat::expect_identical(as.numeric(ledgr_utc(edge$input[[i]])), edge$seconds[[i]], info = edge$input[[i]])
  }
  for (i in which(refused)) {
    alone <- tryCatch(ledgr_utc(edge$input[[i]]), error = identity)
    testthat::expect_s3_class(alone, edge$class[[i]])
    testthat::expect_identical(conditionMessage(alone), edge$message[[i]], info = edge$input[[i]])
    for (at in c(0L, 2L, 5L)) {
      mixed <- append(valid$input[1:5], edge$input[[i]], after = at)
      err <- tryCatch(ledgr_utc(mixed), error = identity)
      testthat::expect_s3_class(err, edge$class[[i]])
      testthat::expect_identical(conditionMessage(err), edge$message[[i]], info = paste(edge$input[[i]], at))
    }
  }

  # Arabic-Indic digits match no accepted form after parsing.
  testthat::expect_error(ledgr_utc("\u0662\u0660\u0662\u0660-01-01"), class = "ledgr_invalid_timestamp")
  named <- ledgr_utc(c(a = "2020-01-01", b = "2020-01-02T00:00:00Z"))
  testthat::expect_null(names(named))
  # Classed character input (AsIs) parses as plain character, in every form
  # (close review F1).
  for (x in list(c("2020-01-01", "2020-01-02"),
                 c("2020-01-01T00:00:00", "2020-01-02T00:00:00Z"),
                 c("2020-01-01", "2020-01-02 09:30:00", "2020-01-03T10:30:00Z"))) {
    testthat::expect_identical(ledgr_utc(I(x)), ledgr_utc(x))
    testthat::expect_identical(ledgr_utc(I(stats::setNames(x, seq_along(x)))), ledgr_utc(x))
  }
  testthat::expect_error(ledgr_utc(I(c("2020-01-01", "2020-02-30"))), class = "ledgr_invalid_timestamp")
  testthat::expect_identical(
    ledgr_utc(character()),
    structure(numeric(0), class = c("POSIXct", "POSIXt"), tzone = "UTC")
  )
})
