make_test_bars <- function(instrument_ids, start_ts_utc, n) {
  start <- as.POSIXct(start_ts_utc, tz = "UTC", format = "%Y-%m-%d %H:%M:%S")
  if (is.na(start)) start <- as.POSIXct(start_ts_utc, tz = "UTC")
  ts <- start + (seq_len(n) - 1L) * 86400
  ts <- as.POSIXct(ts, origin = "1970-01-01", tz = "UTC")
  out <- do.call(
    rbind,
    lapply(seq_along(instrument_ids), function(i) {
      instrument_id <- instrument_ids[[i]]
      base <- 100 + i * 10
      data.frame(
        instrument_id = instrument_id,
        ts_utc = ts,
        open = base + seq_len(n) * 0.1,
        high = base + seq_len(n) * 0.1 + 0.5,
        low = base + seq_len(n) * 0.1 - 0.5,
        close = base + seq_len(n) * 0.1 + 0.2,
        volume = 1000 + seq_len(n),
        stringsAsFactors = FALSE
      )
    })
  )
  out$ts_utc <- as.POSIXct(out$ts_utc, tz = "UTC")
  out
}

# Cut 22 decision 4 deleted the v0.1.4 frame engine
# (ledgr_compute_feature_series(), ledgr_check_no_lookahead()); its claims
# move to the live calculation. live_feature_series() runs one definition over
# a one-instrument frame through the live dispatch
# (ledgr_history_feature_segment(): series_fn, else bounded fn windows, then
# the shared output normalisation); live_no_lookahead() runs the preparation
# path, whose causality probe refuses a definition that reads later rows.
live_feature_series <- function(bars, def) {
  substrate <- ws43_history_substrate(
    as.numeric(bars$close),
    fields = as.list(bars)[c("open", "high", "low", "volume")]
  )
  n <- length(substrate$axis)
  cert <- ledgr:::ledgr_feature_certify(def)
  if (n < as.integer(cert$def$stable_after)) return(rep(NA_real_, n))
  inputs <- ledgr:::ledgr_history_feature_inputs(substrate, 1L, n, substrate$axis[[n]])
  ledgr:::ledgr_history_feature_segment(cert, inputs, inputs$treated, seq_len(n))
}

live_no_lookahead <- function(feature_def, bars_df, horizons = c(1L, 3L)) {
  ws43_bars_feature_values(bars_df, feature_def)
  invisible(TRUE)
}

testthat::test_that("feature definitions are validated fail-loud", {
  good <- list(
    id = "x",
    requires_bars = 1L,
    stable_after = 1L,
    fn = function(window_bars_df) 1.0,
    params = list()
  )
  testthat::expect_true(ledgr:::ledgr_validate_feature_def(good))

  testthat::expect_error(
    ledgr:::ledgr_validate_feature_def(list(requires_bars = 1L, stable_after = 1L, fn = function(w) 1.0)),
    "feature_def$id",
    fixed = TRUE
  )

  testthat::expect_error(
    ledgr:::ledgr_validate_feature_def(list(id = "x", requires_bars = 0L, stable_after = 0L, fn = function(w) 1.0)),
    "requires_bars",
    fixed = TRUE
  )

  testthat::expect_error(
    ledgr:::ledgr_validate_feature_def(list(id = "x", requires_bars = 2L, stable_after = 1L, fn = function(w) 1.0)),
    "stable_after",
    fixed = TRUE
  )

  testthat::expect_error(
    ledgr:::ledgr_validate_feature_def(list(id = "x", requires_bars = 1L, stable_after = 1L, fn = 1)),
    "feature_def$fn",
    fixed = TRUE
  )

  testthat::expect_error(
    ledgr:::ledgr_validate_feature_def(
      list(id = "x", requires_bars = 1L, stable_after = 1L, fn = function(w) 1.0, series_fn = 1)
    ),
    "feature_def$series_fn",
    fixed = TRUE
  )

  testthat::expect_error(
    ledgr:::ledgr_validate_feature_def(
      list(
        id = "x",
        requires_bars = 1L,
        stable_after = 1L,
        fn = function(w) 1.0,
        params = list(env = environment())
      )
    ),
    class = "ledgr_config_non_deterministic"
  )
})

testthat::test_that("feature series uses and validates vectorized series functions", {
  local({
  bars <- make_test_bars(c("AAA"), "2020-01-01 00:00:00", n = 6)
  calls <- new.env(parent = emptyenv())
  calls$fn <- 0L
  calls$series_fn <- 0L

  def <- list(
    id = "series_path",
    requires_bars = 2L,
    stable_after = 2L,
    fn = function(window) {
      calls$fn <- calls$fn + 1L
      tail(window$close, 1)
    },
    series_fn = function(bars, params = list()) {
      calls$series_fn <- calls$series_fn + 1L
      bars$close
    },
    params = list()
  )

  values <- live_feature_series(bars, def)

  testthat::expect_identical(calls$series_fn, 1L)
  testthat::expect_identical(calls$fn, 0L)
  testthat::expect_true(is.na(values[[1]]))
  testthat::expect_equal(values[-1], bars$close[-1])
  })

  # Also covers: feature series validates vectorized output
  local({
  bars <- make_test_bars(c("AAA"), "2020-01-01 00:00:00", n = 4)
  base_def <- list(
    id = "bad_series",
    requires_bars = 2L,
    stable_after = 2L,
    fn = function(window) tail(window$close, 1),
    params = list()
  )

  len_def <- base_def
  len_def$series_fn <- function(bars, params = list()) bars$close[-1]
  testthat::expect_error(
    live_feature_series(bars, len_def),
    "expected 4",
    fixed = TRUE
  )

  type_def <- base_def
  type_def$series_fn <- function(bars, params = list()) as.character(bars$close)
  testthat::expect_error(
    live_feature_series(bars, type_def),
    "non-numeric",
    fixed = TRUE
  )

  inf_def <- base_def
  inf_def$series_fn <- function(bars, params = list()) c(NA_real_, 1, Inf, 2)
  testthat::expect_error(
    live_feature_series(bars, inf_def),
    "infinite",
    fixed = TRUE
  )

  inf_warmup_def <- base_def
  inf_warmup_def$series_fn <- function(bars, params = list()) c(Inf, 1, 2, 3)
  values <- live_feature_series(bars, inf_warmup_def)
  testthat::expect_true(is.na(values[[1]]))
  testthat::expect_equal(values[-1], c(1, 2, 3))

  nan_def <- base_def
  nan_def$series_fn <- function(bars, params = list()) c(NaN, 1, 2, 3)
  values <- live_feature_series(bars, nan_def)
  testthat::expect_true(is.na(values[[1]]))
  testthat::expect_false(is.nan(values[[1]]))

  nan_late_def <- base_def
  nan_late_def$series_fn <- function(bars, params = list()) c(NA_real_, 1, NaN, 3)
  testthat::expect_error(
    live_feature_series(bars, nan_late_def),
    "NaN outside",
    fixed = TRUE
  )

  na_late_def <- base_def
  na_late_def$series_fn <- function(bars, params = list()) c(NA_real_, 1, NA_real_, 3)
  testthat::expect_error(
    live_feature_series(bars, na_late_def),
    "NA outside",
    fixed = TRUE
  )
  })
})


testthat::test_that("fn-only feature fallback uses bounded windows", {
  bars <- make_test_bars(c("AAA"), "2020-01-01 00:00:00", n = 8)
  seen <- new.env(parent = emptyenv())
  seen$max_rows <- 0L

  def <- list(
    id = "bounded_fn",
    requires_bars = 3L,
    stable_after = 3L,
    fn = function(window) {
      seen$max_rows <- max(seen$max_rows, nrow(window))
      mean(window$close)
    },
    params = list()
  )

  values <- live_feature_series(bars, def)

  testthat::expect_true(all(is.na(values[1:2])))
  testthat::expect_identical(seen$max_rows, 3L)
  testthat::expect_false(anyNA(values[3:length(values)]))
})

testthat::test_that("[LTB-0003] no-lookahead checker detects a leaking series function", {
  bars <- make_test_bars("AAA", "2020-01-01", 8L)
  causal <- list(
    id = "causal_close",
    requires_bars = 1L,
    stable_after = 1L,
    fn = function(window) tail(window$close, 1L),
    series_fn = function(x, params = list()) as.numeric(x$close),
    params = list()
  )
  leaking <- causal
  leaking$id <- "leaking_final_close"
  leaking$series_fn <- function(x, params = list()) {
    rep(as.numeric(tail(x$close, 1L)), nrow(x))
  }

  detects_leak <- function(checker) {
    error <- tryCatch(
      checker(leaking, bars, horizons = c(1L, 3L)),
      error = identity
    )
    if (!inherits(error, "ledgr_feature_lookahead_detected")) {
      stop("The leaking feature was not detected.", call. = FALSE)
    }
    invisible(TRUE)
  }

  testthat::expect_silent(
    live_no_lookahead(causal, bars, horizons = c(1L, 3L))
  )
  testthat::expect_silent(detects_leak(live_no_lookahead))
  testthat::expect_error(
    detects_leak(function(...) invisible(TRUE)),
    "The leaking feature was not detected.",
    fixed = TRUE
  )
})
