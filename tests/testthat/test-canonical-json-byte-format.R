testthat::test_that("canonical_json byte-format v2 is pinned", {
  fixtures <- list(
    scalar_int = list(value = 42L, expected = "42"),
    numeric_integer_lookalike = list(value = list(x = 1.0), expected = "{\"x\":1.0}"),
    numeric_irrational = list(value = list(x = pi), expected = "{\"x\":3.141592653589793}"),
    numeric_exponent = list(
      value = list(x = .Machine$double.xmax / 1e10),
      expected = "{\"x\":1.7976931348623157e298}"
    ),
    meta_fill = list(
      value = list(cash_delta = -100, position_delta = 1, realized_pnl = NULL),
      expected = "{\"cash_delta\":-100.0,\"position_delta\":1.0,\"realized_pnl\":null}"
    ),
    string_escape = list(
      value = list(x = "line1\n\"quote\""),
      expected = "{\"x\":\"line1\\n\\\"quote\\\"\"}"
    ),
    posixt = list(
      value = list(ts = as.POSIXct("2026-01-01 12:34:56", tz = "UTC")),
      expected = "{\"ts\":\"2026-01-01T12:34:56Z\"}"
    ),
    nested_sorted = list(
      value = list(z = 1, a = list(b = 2, a = 1)),
      expected = "{\"a\":{\"a\":1.0,\"b\":2.0},\"z\":1.0}"
    )
  )

  for (fixture in fixtures) {
    testthat::expect_identical(
      as.character(ledgr:::canonical_json(fixture$value)),
      fixture$expected
    )
  }
})

testthat::test_that("yyjsonr read helpers cover nested and config shapes", {
  nested_json <- "{\"cash_delta\":-100.0,\"position_delta\":1.0,\"fills\":[{\"qty\":1.0}],\"singleton\":[\"x\"]}"
  nested <- ledgr:::ledgr_json_read_nested(nested_json)
  testthat::expect_type(nested, "list")
  testthat::expect_type(nested$fills, "list")
  testthat::expect_s3_class(nested$singleton, "AsIs")

  config <- ledgr:::ledgr_json_read_config(nested_json)
  testthat::expect_type(config, "list")
  testthat::expect_type(config$fills, "list")
  testthat::expect_false(inherits(config$singleton, "AsIs"))
  testthat::expect_identical(config$singleton, "x")
})
