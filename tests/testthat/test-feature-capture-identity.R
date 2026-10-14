# ledgr-test-file-profile: fast

capture_identity_indicator <- function(value) {
  ledgr_indicator(
    id = "captured_scale",
    fn = function(window) tail(window$close, 1L) * value,
    series_fn = function(bars, params) bars$close * value,
    requires_bars = 1L
  )
}

capture_identity_def <- function(indicator) {
  list(
    id = indicator$id,
    fn = indicator$fn,
    series_fn = indicator$series_fn,
    requires_bars = indicator$requires_bars,
    stable_after = indicator$stable_after,
    params = indicator$params
  )
}

testthat::test_that("direct deterministic captures bind every feature identity layer", {
  one_a <- capture_identity_indicator(1)
  one_b <- capture_identity_indicator(1)
  two <- capture_identity_indicator(2)

  indicator_fingerprints <- vapply(
    list(one_a, one_b, two),
    ledgr:::ledgr_indicator_fingerprint,
    character(1)
  )
  testthat::expect_identical(indicator_fingerprints[[1L]], indicator_fingerprints[[2L]])
  testthat::expect_false(identical(indicator_fingerprints[[1L]], indicator_fingerprints[[3L]]))

  defs <- lapply(list(one_a, one_b, two), capture_identity_def)
  def_fingerprints <- vapply(defs, ledgr:::ledgr_feature_def_fingerprint, character(1))
  testthat::expect_identical(def_fingerprints[[1L]], def_fingerprints[[2L]])
  testthat::expect_false(identical(def_fingerprints[[1L]], def_fingerprints[[3L]]))

  active_fingerprints <- vapply(defs, ledgr:::ledgr_active_feature_fingerprint, character(1))
  testthat::expect_identical(active_fingerprints[[1L]], active_fingerprints[[2L]])
  testthat::expect_false(identical(active_fingerprints[[1L]], active_fingerprints[[3L]]))
  testthat::expect_false(identical(
    ledgr:::ledgr_feature_set_hash(def_fingerprints[[1L]]),
    ledgr:::ledgr_feature_set_hash(def_fingerprints[[3L]])
  ))
})

testthat::test_that("atomic and list captures are accepted but unsupported captures refuse", {
  captured_list <- list(scale = 2, label = "stable")
  list_indicator <- ledgr_indicator(
    id = "captured_list",
    fn = function(window) tail(window$close, 1L) * captured_list$scale,
    requires_bars = 1L
  )
  testthat::expect_match(
    ledgr:::ledgr_indicator_fingerprint(list_indicator),
    "^[0-9a-f]{64}$"
  )

  captured_environment <- new.env(parent = emptyenv())
  captured_environment$scale <- 2
  environment_indicator <- ledgr_indicator(
    id = "captured_environment",
    fn = function(window) tail(window$close, 1L) * captured_environment$scale,
    requires_bars = 1L
  )
  testthat::expect_error(
    ledgr:::ledgr_indicator_fingerprint(environment_indicator),
    class = "ledgr_config_non_deterministic"
  )
  testthat::expect_error(
    ledgr:::ledgr_feature_def_fingerprint(capture_identity_def(environment_indicator)),
    class = "ledgr_config_non_deterministic"
  )
})

testthat::test_that("captured functions bind their signature but not their own captures", {
  make_indicator <- function(scale) {
    helper <- (function(value) function(x) x * value)(scale)
    ledgr_indicator(
      id = "captured_helper",
      fn = function(window) helper(tail(window$close, 1L)),
      requires_bars = 1L
    )
  }

  testthat::expect_identical(
    ledgr:::ledgr_indicator_fingerprint(make_indicator(1)),
    ledgr:::ledgr_indicator_fingerprint(make_indicator(2))
  )
})

testthat::test_that("package constructors and adapters fingerprint under capture-aware identity", {
  constructors <- list(
    ledgr_ind_sma(3),
    ledgr_ind_ema(3),
    ledgr_ind_rsi(3),
    ledgr_ind_returns(3),
    ledgr_adapter_r(stats::median, id = "median_close", requires_bars = 3)
  )
  if (requireNamespace("TTR", quietly = TRUE)) {
    constructors <- c(
      constructors,
      list(ledgr_ind_ttr("RSI", input = "close", n = 3)),
      unname(ledgr_ind_ttr_outputs("BBands", input = "close", n = 3)$indicators)
    )
  }
  fingerprints <- vapply(constructors, ledgr:::ledgr_indicator_fingerprint, character(1))
  testthat::expect_true(all(grepl("^[0-9a-f]{64}$", fingerprints)))
})

testthat::test_that("CSV capture identity uses params data_hash, including missing rows", {
  make_csv <- function(values) {
    path <- tempfile(fileext = ".csv")
    utils::write.csv(data.frame(
      ts_utc = c("2020-01-01T00:00:00Z", "2020-01-02T00:00:00Z"),
      instrument_id = "AAA",
      signal = values
    ), path, row.names = FALSE)
    path
  }
  plain_path <- make_csv(c(1.5, 2.25))
  missing_path <- make_csv(c(1.5, NA_real_))
  on.exit(unlink(c(plain_path, missing_path)), add = TRUE)

  plain <- ledgr_adapter_csv(plain_path, value_col = "signal", id = "csv_signal")
  missing <- ledgr_adapter_csv(missing_path, value_col = "signal", id = "csv_signal")
  plain_fingerprint <- ledgr:::ledgr_indicator_fingerprint(plain)
  missing_fingerprint <- ledgr:::ledgr_indicator_fingerprint(missing)
  testthat::expect_identical(plain_fingerprint, ledgr:::ledgr_indicator_fingerprint(plain))
  testthat::expect_false(identical(plain_fingerprint, missing_fingerprint))

  changed_capture <- ledgr_adapter_csv(missing_path, value_col = "signal", id = "csv_signal")
  captured_values <- environment(changed_capture$fn)$values
  captured_values[] <- c(99.75, -3.5)
  environment(changed_capture$fn)$values <- captured_values
  testthat::expect_identical(
    ledgr:::ledgr_indicator_fingerprint(changed_capture),
    missing_fingerprint
  )

  values <- c(1.5, NA_real_)
  labelled_only <- ledgr_indicator(
    id = "csv_signal",
    fn = function(window) values[[1L]],
    requires_bars = 1L,
    params = list(adapter = "csv", data_hash = missing$params$data_hash),
    source = "custom"
  )
  testthat::expect_error(
    ledgr:::ledgr_indicator_fingerprint(labelled_only),
    class = "ledgr_config_non_deterministic"
  )
})
