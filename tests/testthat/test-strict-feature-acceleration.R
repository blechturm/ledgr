workstream8_strict_values <- function() {
  c(10, 11, 9, 13, 12, 14, 17, 16, 19, 18, 21, 23)
}

workstream8_window_means <- function(close, width) {
  out <- rep(NA_real_, length(close))
  for (i in seq.int(width, length(close))) {
    window <- close[seq.int(i - width + 1L, i)]
    if (all(is.finite(window))) out[[i]] <- mean(window)
  }
  out
}

workstream8_window_returns <- function(close, lag) {
  out <- rep(NA_real_, length(close))
  for (i in seq.int(lag + 1L, length(close))) {
    # The bounded window is every session from i - lag to i.
    if (all(is.finite(close[seq.int(i - lag, i)]))) {
      out[[i]] <- (close[[i]] - close[[i - lag]]) / close[[i - lag]]
    }
  }
  out
}

testthat::test_that("[LTB-0142] strict built-ins preserve exact values and masks", {
  # V12 Sections 5-6: built-in SMA and returns require only `close`, so a
  # missing open, high or low no longer blanks a window; default price carry
  # fills an SMA input but never a returns input; and an explicit no-carry
  # policy keeps the exact strict-window values.
  close <- workstream8_strict_values()
  strict <- ledgr_history_policy(price_carry = NULL)
  sma_oracle <- function(x) workstream8_window_means(x, 3L)
  returns_oracle <- function(x) workstream8_window_returns(x, 2L)
  no_close <- close
  cases <- list(
    dense = list(close = close, fields = list()),
    open_gap = list(close = close, fields = list(open = replace(close, 6L, NA_real_))),
    high_gap = list(close = close, fields = list(high = replace(close + 1, 6L, NA_real_))),
    low_gap = list(close = close, fields = list(low = replace(close - 1, 6L, NA_real_))),
    close_gap = list(close = replace(close, 6L, NA_real_), fields = list()),
    consecutive = list(close = replace(close, 6:7, NA_real_), fields = list()),
    leading = list(close = replace(close, 1:4, NA_real_), fields = list())
  )
  for (case_name in names(cases)) {
    case <- cases[[case_name]]
    strict_substrate <- ws43_history_substrate(case$close, fields = case$fields, policy = strict)
    testthat::expect_identical(
      ws43_feature_values(strict_substrate, ledgr_ind_sma(3L)),
      sma_oracle(case$close),
      info = paste(case_name, "strict SMA")
    )
    testthat::expect_identical(
      ws43_feature_values(strict_substrate, ledgr_ind_returns(2L)),
      returns_oracle(case$close),
      info = paste(case_name, "strict returns")
    )
    carried_substrate <- ws43_history_substrate(case$close, fields = case$fields)
    carried_close <- as.numeric(collapse::na_locf(case$close))
    testthat::expect_identical(
      ws43_feature_values(carried_substrate, ledgr_ind_sma(3L)),
      sma_oracle(carried_close),
      info = paste(case_name, "carried SMA")
    )
    testthat::expect_identical(
      ws43_feature_values(carried_substrate, ledgr_ind_returns(2L)),
      returns_oracle(case$close),
      info = paste(case_name, "returns never consume a carried price")
    )
  }
  short <- ws43_history_substrate(close[1:2], policy = strict)
  testthat::expect_identical(ws43_feature_values(short, ledgr_ind_sma(3L)), c(NA_real_, NA_real_))

  set.seed(17L)
  floating <- stats::rnorm(40L)
  testthat::expect_false(identical(
    ledgr:::ledgr_strict_sma_series(floating, 5L),
    ledgr:::ledgr_rolling_mean(floating, 5L)
  ))

  set.seed(7L)
  volatile <- 100 * exp(cumsum(stats::rnorm(1200L, 0, 0.20)))
  width <- 500L
  ends <- seq.int(width, length(volatile))
  scalar_mean <- c(
    rep(NA_real_, width - 1L),
    vapply(ends, function(i) {
      mean(volatile[seq.int(i - width + 1L, i)])
    }, numeric(1))
  )
  row_mean <- c(
    rep(NA_real_, width - 1L),
    rowMeans(embed(volatile, width))
  )
  testthat::expect_false(identical(row_mean, scalar_mean))
  testthat::expect_identical(
    ledgr:::ledgr_strict_sma_series(volatile, width),
    scalar_mean
  )
  testthat::expect_identical(
    ws43_feature_values(ws43_history_substrate(volatile), ledgr_ind_sma(width)),
    scalar_mean
  )
})

testthat::test_that("[LTB-0143] strict dispatch is canonical and bounded", {
  close <- workstream8_strict_values()
  substrate <- ws43_history_substrate(close)
  custom <- ledgr_indicator(
    id = "sma_3",
    fn = function(window) mean(window$close) + 1,
    requires_bars = 3L,
    params = list(n = 3L),
    source = "ledgr",
    gap_contract = "strict_window"
  )
  external <- ledgr_indicator(
    id = "external_mean_3",
    fn = function(window) mean(window$close),
    requires_bars = 3L,
    params = list(n = 3L),
    source = "custom",
    gap_contract = "strict_window"
  )
  ttr_like <- ledgr_indicator(
    id = "ttr_sma_3",
    fn = function(window) mean(window$close),
    requires_bars = 3L,
    params = list(n = 3L),
    source = "TTR",
    gap_contract = "strict_window"
  )
  definitions <- list(
    ledgr_ind_sma(3L), ledgr_ind_returns(2L), custom, external, ttr_like
  )
  certified <- lapply(definitions, ledgr:::ledgr_feature_certify)
  testthat::expect_identical(
    vapply(certified, `[[`, character(1), "certification"),
    c("builtin", "builtin", "custom", "custom", "custom")
  )
  testthat::expect_identical(certified[[1L]]$kind, "sma")
  testthat::expect_identical(certified[[2L]]$kind, "returns")

  # A definition that claims a built-in identity is computed with the
  # package constructor's own functions, never with a replaced function.
  tampered <- ledgr:::ledgr_precompute_feature_def_from_indicator(ledgr_ind_sma(3L))
  tampered$fn <- function(window) stop("tampered fn must not run")
  tampered$series_fn <- function(bars, params) stop("tampered series_fn must not run")
  segment_calls <- 0L
  original_segment <- ledgr:::ledgr_history_feature_segment
  testthat::local_mocked_bindings(
    ledgr_history_feature_segment = function(...) {
      segment_calls <<- segment_calls + 1L
      original_segment(...)
    },
    .package = "ledgr"
  )
  tampered_returns <- ledgr:::ledgr_precompute_feature_def_from_indicator(ledgr_ind_returns(2L))
  tampered_returns$fn <- function(window) stop("tampered fn must not run")
  tampered_returns$series_fn <- function(bars, params) stop("tampered series_fn must not run")
  values <- lapply(c(definitions, list(tampered, tampered_returns)), function(definition) {
    ws43_feature_values(substrate, definition)
  })
  # One segment covers the complete series for every definition. The sampled
  # causality check (LDG-3067) adds a fixed five per definition: the probe's
  # own segment and four sampled prefixes, independent of history length.
  testthat::expect_identical(segment_calls, 7L * (1L + 1L + 4L))
  testthat::expect_identical(values[[7L]], values[[2L]])
  testthat::expect_identical(values[[3L]][[3L]], mean(close[1:3]) + 1)
  testthat::expect_identical(values[[6L]], values[[1L]])
  testthat::expect_identical(values[[4L]][[3L]], mean(close[1:3]))
})

testthat::test_that("[LTB-0144] strict helper provenance is availability-only", {
  source <- paste(deparse(body(ledgr:::ledgr_feature_engine_version)), collapse = "\n")
  helpers <- c(
    "ledgr_history_compute_feature_series",
    "ledgr_feature_certify",
    "ledgr_feature_catalogue_candidates",
    "ledgr_indicator_history_catalogue",
    "ledgr_indicator_declare",
    "ledgr_history_required_field_admission",
    "ledgr_history_feature_inputs",
    "ledgr_history_input_carry",
    "ledgr_history_output_carry",
    "ledgr_history_feature_ranges",
    "ledgr_history_feature_runs",
    "ledgr_history_feature_calculate",
    "ledgr_history_feature_segment",
    "ledgr_history_feature_frame",
    "ledgr_history_feature_window",
    "ledgr_strict_sma_series",
    "ledgr_active_feature_fingerprint"
  )
  for (helper in helpers) {
    testthat::expect_match(source, helper, fixed = TRUE)
  }
  under_covr <- requireNamespace("covr", quietly = TRUE) && covr::in_covr()
  if (!under_covr) {
    testthat::expect_identical(
      ledgr:::ledgr_feature_engine_version(FALSE),
      "80d1ae6d2165196044db3f0d1944d69f21b76e264d2df16df49e23f448a7c681"
    )
    testthat::expect_identical(
      ledgr:::ledgr_feature_engine_version(TRUE),
      "50b8f7830f4a57d30a557a8356a0be3d2ed0d8612664cf3f86af53dbdd322f9a"
    )
    testthat::expect_identical(
      ledgr:::ledgr_indicator_fingerprint(ledgr_ind_sma(20L)),
      "722be865c97f7cc5d2aa85b95d7ceef74959da6c754d643cde2063ed5d0366a0"
    )
    testthat::expect_identical(
      ledgr:::ledgr_indicator_fingerprint(ledgr_ind_returns(5L)),
      "d3feff6aeb660729888928583c4cf36150a66dba0053ab944783e064f090d9cb"
    )
  }
})
