workstream8_strict_bars <- function() {
  values <- c(10, 11, 9, 13, 12, 14, 17, 16, 19, 18, 21, 23)
  data.frame(
    ts_utc = as.POSIXct("2024-01-01", tz = "UTC") +
      86400 * seq_along(values),
    instrument_id = "AAA",
    open = values - 0.5,
    high = values + 1,
    low = values - 1,
    close = values,
    volume = 100,
    stringsAsFactors = FALSE
  )
}

workstream8_strict_def <- function(indicator, active = FALSE) {
  definition <- ledgr:::ledgr_precompute_feature_def_from_indicator(indicator)
  if (isTRUE(active)) {
    definition$fingerprint <- ledgr:::ledgr_active_feature_fingerprint(
      definition
    )
  }
  definition
}

testthat::test_that("[LTB-0142] strict built-ins preserve exact values and masks", {
  dense <- workstream8_strict_bars()
  cases <- list(
    dense = dense,
    open_gap = transform(dense, open = replace(open, 6L, NA_real_)),
    high_gap = transform(dense, high = replace(high, 6L, NA_real_)),
    low_gap = transform(dense, low = replace(low, 6L, NA_real_)),
    close_gap = transform(dense, close = replace(close, 6L, NA_real_)),
    consecutive = transform(
      dense,
      close = replace(close, 6:7, NA_real_)
    ),
    leading = transform(
      dense,
      open = replace(open, 1:4, NA_real_),
      high = replace(high, 1:4, NA_real_),
      low = replace(low, 1:4, NA_real_),
      close = replace(close, 1:4, NA_real_)
    ),
    short = dense[1:2, , drop = FALSE]
  )
  indicators <- list(
    sma = ledgr_ind_sma(3L),
    returns = ledgr_ind_returns(2L)
  )
  for (case_name in names(cases)) {
    for (feature in names(indicators)) {
      definition <- workstream8_strict_def(indicators[[feature]])
      expected <- ledgr:::ledgr_compute_feature_series_strict_scalar(
        cases[[case_name]],
        definition
      )
      actual <- ledgr:::ledgr_compute_feature_series_strict(
        cases[[case_name]],
        definition
      )
      testthat::expect_identical(actual, expected, info = paste(
        case_name,
        feature
      ))
      testthat::expect_identical(
        is.na(actual),
        is.na(expected),
        info = paste(case_name, feature, "NA mask")
      )
    }
  }

  expected_sma <- rep(NA_real_, nrow(dense))
  for (i in 3:nrow(dense)) {
    expected_sma[[i]] <- mean(dense$close[(i - 2L):i])
  }
  testthat::expect_identical(
    ledgr:::ledgr_compute_feature_series_strict(
      dense,
      workstream8_strict_def(ledgr_ind_sma(3L))
    ),
    expected_sma
  )

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
})

testthat::test_that("[LTB-0143] strict dispatch is canonical and bounded", {
  bars <- workstream8_strict_bars()
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
    workstream8_strict_def(ledgr_ind_sma(3L), active = TRUE),
    workstream8_strict_def(ledgr_ind_returns(2L), active = TRUE),
    workstream8_strict_def(custom, active = TRUE),
    workstream8_strict_def(external, active = TRUE),
    workstream8_strict_def(ttr_like, active = TRUE)
  )

  scalar_calls <- 0L
  builtin_calls <- 0L
  original_scalar <- ledgr:::ledgr_compute_feature_series_strict_scalar
  original_builtin <- ledgr:::ledgr_compute_feature_series_strict_builtin
  testthat::local_mocked_bindings(
    ledgr_compute_feature_series_strict_scalar = function(...) {
      scalar_calls <<- scalar_calls + 1L
      original_scalar(...)
    },
    ledgr_compute_feature_series_strict_builtin = function(...) {
      builtin_calls <<- builtin_calls + 1L
      original_builtin(...)
    },
    .package = "ledgr"
  )
  values <- lapply(definitions, function(definition) {
    ledgr:::ledgr_compute_feature_series_strict(bars, definition)
  })
  testthat::expect_identical(builtin_calls, 2L)
  testthat::expect_identical(scalar_calls, 3L)
  testthat::expect_identical(
    values[[3L]][[3L]],
    mean(bars$close[1:3]) + 1
  )
  testthat::expect_null(ledgr:::ledgr_strict_builtin_kind(definitions[[3L]]))
  testthat::expect_null(ledgr:::ledgr_strict_builtin_kind(definitions[[4L]]))
  testthat::expect_null(ledgr:::ledgr_strict_builtin_kind(definitions[[5L]]))
})

testthat::test_that("[LTB-0144] strict helper provenance is availability-only", {
  source <- paste(deparse(body(ledgr:::ledgr_feature_engine_version)), collapse = "\n")
  helpers <- c(
    "ledgr_compute_feature_series_strict_scalar",
    "ledgr_strict_builtin_kind",
    "ledgr_strict_ttr_template_match",
    "ledgr_strict_complete_window_mask",
    "ledgr_strict_sma_series",
    "ledgr_compute_feature_series_strict_builtin"
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
      "25d86252352ea2228c9b49cade9eb482e21adf41d01f1ec5ce4a8a7db5809281"
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
