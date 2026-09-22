testthat::test_that("timing helpers handle numeric and difftime paths", {
  testthat::expect_true(length(ledgr:::ledgr_time_now()) == 1L)
  testthat::expect_equal(ledgr:::ledgr_time_elapsed(1, 3), 2)
  testthat::expect_equal(ledgr:::ledgr_time_elapsed(0, 1500), 1500)
  testthat::expect_true(is.na(ledgr:::ledgr_time_elapsed(numeric(), 1)))

  start <- as.POSIXct("2020-01-01 00:00:00", tz = "UTC")
  end <- as.POSIXct("2020-01-01 00:00:02", tz = "UTC")
  testthat::expect_equal(ledgr:::ledgr_time_elapsed(start, end), 2)
})

ledgr_test_coverage_script <- function() {
  candidates <- c(
    file.path("tools", "check-coverage.R"),
    file.path(Sys.getenv("GITHUB_WORKSPACE", ""), "tools", "check-coverage.R"),
    file.path("..", "..", "tools", "check-coverage.R")
  )
  for (candidate in candidates) {
    if (nzchar(candidate) && file.exists(candidate)) return(candidate)
  }
  testthat::skip("coverage helper source unavailable in installed-package test context")
}

testthat::test_that("coverage helper defaults to one attempt and retries transient failures", {
  local({
  source(ledgr_test_coverage_script())

  attempts <- 0L
  coverage <- ledgr_collect_coverage(
    package_coverage = function() {
      attempts <<- attempts + 1L
      if (attempts < 3L) stop("temporary coverage shard failure")
      list(ok = TRUE)
    },
    attempts = 3L
  )

  testthat::expect_equal(attempts, 3L)
  testthat::expect_equal(coverage, list(ok = TRUE))
  })

  # Also covers: coverage helper defaults to one collection attempt
  local({
  source(ledgr_test_coverage_script())

  old <- Sys.getenv("LEDGR_COVERAGE_ATTEMPTS", unset = NA_character_)
  on.exit({
    if (is.na(old)) {
      Sys.unsetenv("LEDGR_COVERAGE_ATTEMPTS")
    } else {
      Sys.setenv(LEDGR_COVERAGE_ATTEMPTS = old)
    }
  }, add = TRUE)

  Sys.unsetenv("LEDGR_COVERAGE_ATTEMPTS")

  testthat::expect_identical(ledgr_coverage_attempts(), 1L)
  })
})


testthat::test_that("coverage helper fails after retry budget is exhausted", {
  source(ledgr_test_coverage_script())

  testthat::expect_error(
    ledgr_collect_coverage(
      package_coverage = function() stop("permanent coverage failure"),
      attempts = 2L
    ),
    "permanent coverage failure"
  )
})

testthat::test_that("fill event row helper covers no-op and validation branches", {
  none <- structure(list(status = "NO_FILL"), class = "ledgr_fill_none")
  out <- ledgr:::ledgr_fill_event_row("run-1", none, 1L)
  testthat::expect_s3_class(out, "ledgr_ledger_write_result")
  testthat::expect_identical(out$status, "NO_OP")

  testthat::expect_error(
    ledgr:::ledgr_fill_event_row("run-1", list(), 1L),
    class = "ledgr_invalid_fill_intent"
  )
  fill <- structure(
    list(
      instrument_id = "AAA",
      side = "BUY",
      qty = 2,
      fill_price = 10,
      fee = 1,
      ts_exec_utc = "2020-01-02T00:00:00Z"
    ),
    class = "ledgr_fill_intent"
  )
  testthat::expect_error(
    ledgr:::ledgr_fill_event_row("run-1", fill, 0L),
    class = "ledgr_invalid_args"
  )

  row <- ledgr:::ledgr_fill_event_row("run-1", fill, 3L)
  testthat::expect_identical(row$status, "WROTE")
  testthat::expect_equal(row$cash_delta, -21)
  testthat::expect_equal(row$position_delta, 2)

  fill$side <- "SELL"
  row <- ledgr:::ledgr_fill_event_row("run-1", fill, 4L)
  testthat::expect_equal(row$cash_delta, 19)
  testthat::expect_equal(row$position_delta, -2)
})

testthat::test_that("indicator validation and fingerprint helpers fail loud on invalid inputs", {
  good_fn <- function(window) 1

  testthat::expect_error(ledgr_indicator("", good_fn, 1), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_indicator("x", 1, 1), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_indicator("x", good_fn, NA_real_), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_indicator("x", good_fn, 0), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_indicator("x", good_fn, 2, stable_after = 1), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_indicator("x", good_fn, 1, params = 1), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_indicator("x", good_fn, 1, params = list(1)), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_indicator("x", good_fn, 1, params = list(ts = Sys.Date())), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_indicator("x", function(window) { x <<- 1; 1 }, 1), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_indicator("x", function(window) runif(1), 1), class = "ledgr_purity_violation")

  testthat::expect_error(ledgr:::ledgr_static_function_signature(1), class = "ledgr_invalid_args")
  sig <- ledgr:::ledgr_static_function_signature(function(x) x + 1)
  testthat::expect_true(all(c("body", "formals", "environment_name") %in% names(sig)))

  testthat::expect_identical(ledgr:::ledgr_stable_payload(factor("a")), "a")
  payload <- ledgr:::ledgr_stable_payload(data.frame(a = 1, b = "x"))
  testthat::expect_identical(names(payload), c("a", "b"))
  testthat::expect_error(ledgr:::ledgr_stable_payload(as.Date("2020-01-01")), class = "ledgr_config_non_deterministic")
  testthat::expect_error(ledgr:::ledgr_stable_payload(new.env()), class = "ledgr_config_non_deterministic")
  testthat::expect_error(ledgr:::ledgr_stable_payload(Inf), class = "ledgr_config_non_deterministic")
  testthat::expect_error(ledgr:::ledgr_stable_payload(quote(runif(1))), class = "ledgr_config_non_deterministic")

  testthat::expect_error(ledgr:::ledgr_function_fingerprint(1), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr:::ledgr_function_fingerprint(function() Sys.time()), class = "ledgr_config_non_deterministic")
  testthat::expect_error(ledgr:::ledgr_indicator_fingerprint(list()), class = "ledgr_invalid_args")

  testthat::expect_error(ledgr_indicator_register(1), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_indicator_register(ledgr_ind_sma(2), name = ""), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_indicator_register(ledgr_ind_sma(2), name = "coverage_sma_2", overwrite = NA), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_indicator_get(""), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_indicator_get("missing_coverage_indicator"), class = "ledgr_invalid_args")
  testthat::expect_error(ledgr_indicator_list(""), class = "ledgr_invalid_args")
})
