# ledgr-test-file-profile: review

# Closes with an interior maximum, so a running maximum and a whole-history
# statistic differ at every sampled position.
ws43_causality_close <- function(n = 18L) {
  100 + seq_len(n) + 3 * sin(seq_len(n))
}

ws43_count_calls <- function(name, expr) {
  calls <- 0L
  original <- get(name, envir = asNamespace("ledgr"))
  counted <- function(...) {
    calls <<- calls + 1L
    original(...)
  }
  binding <- stats::setNames(list(counted), name)
  do.call(testthat::local_mocked_bindings, c(binding, list(.package = "ledgr")))
  force(expr)
  calls
}

testthat::test_that("[LTB-0315] sampled prefix invariance refuses look-ahead before side effects", {
  close <- ws43_causality_close()
  substrate <- ws43_history_substrate(close)
  axis <- ws43_history_axis(length(close))

  # Valid series_fn, fn-only and built-in definitions pass unchanged. A
  # bounded fn-only definition receives exactly its requires_bars window
  # (v12 Section 6), during preparation and during the check.
  last_close <- ledgr_indicator(
    "last_close",
    fn = function(window) window$close[[nrow(window)]],
    requires_bars = 2L,
    stable_after = 4L,
    history_class = "bounded",
    required_fields = "close"
  )
  windows <- local({
    rows <- integer()
    original <- ledgr:::ledgr_call_feature_fn
    testthat::local_mocked_bindings(
      ledgr_call_feature_fn = function(fn, window, params) {
        rows <<- c(rows, nrow(window))
        original(fn, window, params)
      },
      .package = "ledgr"
    )
    testthat::expect_identical(
      ws43_feature_values(substrate, last_close),
      c(NA, NA, NA, close[4:18])
    )
    rows
  })
  # 15 prepared windows, 15 for the probe's structure and 1 + 5 + 10 + 14
  # for the four sampled prefixes (sessions 4, 8, 13 and 17).
  testthat::expect_identical(length(windows), 15L + 15L + 1L + 5L + 10L + 14L)
  testthat::expect_true(all(windows == 2L))
  causal_series <- ledgr_indicator(
    "causal_mean",
    fn = function(window) mean(window$close),
    requires_bars = 1L,
    series_fn = function(bars, params) cumsum(bars$close) / seq_len(nrow(bars))
  )
  testthat::expect_identical(
    ws43_feature_values(substrate, causal_series),
    cumsum(close) / seq_along(close)
  )
  testthat::expect_identical(
    ws43_feature_values(substrate, ledgr_ind_sma(3L)),
    c(NA, NA, vapply(3:18, function(k) mean(close[(k - 2L):k]), numeric(1)))
  )

  # A series_fn that de-means over the whole history reads later rows; the
  # first sampled position is the first calculated session with later
  # history, and the prepared and prefix values are both finite.
  demeaned <- ledgr_indicator(
    "demeaned_close",
    fn = function(window) 0,
    requires_bars = 1L,
    series_fn = function(bars, params) bars$close - mean(bars$close)
  )
  refusal <- tryCatch(ws43_feature_values(substrate, demeaned), error = identity)
  testthat::expect_s3_class(refusal, "ledgr_feature_lookahead_detected")
  testthat::expect_s3_class(refusal, "ledgr_invalid_feature_output")
  testthat::expect_identical(refusal$feature_id, "demeaned_close")
  testthat::expect_identical(refusal$instrument_id, "AAA")
  testthat::expect_identical(refusal$ts_utc, axis[[1L]])
  testthat::expect_identical(refusal$full_value, close[[1L]] - mean(close))
  testthat::expect_identical(refusal$prefix_value, 0)

  # A fn-only definition that carries state between calls leaks later
  # history into earlier values once the history has been seen.
  seen <- new.env(parent = emptyenv())
  seen$max <- -Inf
  running_max <- ledgr_indicator(
    "running_max",
    fn = function(window) {
      seen$max <- max(seen$max, window$close)
      seen$max
    },
    requires_bars = 1L,
    history_class = "bounded",
    required_fields = "close"
  )
  refusal <- tryCatch(ws43_feature_values(substrate, running_max), error = identity)
  testthat::expect_s3_class(refusal, "ledgr_feature_lookahead_detected")
  testthat::expect_identical(refusal$feature_id, "running_max")
  testthat::expect_identical(refusal$ts_utc, axis[[1L]])
  testthat::expect_identical(refusal$full_value, close[[1L]])
  testthat::expect_identical(refusal$prefix_value, max(close))

  # The refusal precedes every run, sweep and precompute side effect: the
  # strategy never runs and no ledger, equity or payload is produced.
  snapshot <- availability_runtime_fixture(days = 8L)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  ran <- new.env(parent = emptyenv())
  ran$n <- 0L
  experiment <- ledgr_experiment(
    snapshot,
    function(ctx, params) {
      ran$n <- ran$n + 1L
      ctx$hold()
    },
    features = list(demeaned),
    valuation_policy = ledgr_valuation_stale(1L),
    cost_model = ledgr_cost_zero()
  )
  grid <- ledgr_param_grid(one = list())
  testthat::expect_error(
    ledgr_precompute_features(experiment, grid),
    class = "ledgr_feature_lookahead_detected"
  )
  testthat::expect_error(
    ledgr_sweep(experiment, grid, stop_on_error = TRUE),
    class = "ledgr_feature_lookahead_detected"
  )
  testthat::expect_error(
    ledgr_run(experiment, run_id = "ws43-lookahead"),
    class = "ledgr_feature_lookahead_detected"
  )
  testthat::expect_identical(ran$n, 0L)
  con <- get_connection(snapshot)
  for (table in c("ledger_events", "equity_curve")) {
    if (DBI::dbExistsTable(con, table)) {
      testthat::expect_identical(
        DBI::dbGetQuery(
          con,
          sprintf("SELECT COUNT(*) AS n FROM %s WHERE run_id = 'ws43-lookahead'", table)
        )$n,
        0
      )
    }
  }
})

testthat::test_that("[LTB-0316] the causality checker samples a fixed bounded set of positions", {
  # At most four prefix recomputations of one probe instrument per
  # definition, whatever the history length; never all prefixes.
  calc <- ledgr_indicator(
    "causal_mean",
    fn = function(window) mean(window$close),
    requires_bars = 1L,
    series_fn = function(bars, params) cumsum(bars$close) / seq_len(nrow(bars))
  )
  fn_only <- ledgr_indicator(
    "last_close",
    fn = function(window) window$close[[nrow(window)]],
    requires_bars = 2L,
    history_class = "bounded",
    required_fields = "close"
  )
  prefixes <- function(n, definitions) {
    substrate <- ws43_history_substrate(ws43_causality_close(n))
    ws43_count_calls(
      "ledgr_history_feature_inputs_prefix",
      ledgr:::ledgr_history_compute_feature_series(substrate, definitions)
    )
  }
  testthat::expect_identical(prefixes(12L, list(calc)), 4L)
  testthat::expect_identical(prefixes(400L, list(calc)), 4L)
  testthat::expect_identical(prefixes(400L, list(calc, fn_only)), 8L)
  testthat::expect_identical(
    ledgr:::ledgr_history_feature_causality_positions(400L),
    c(1L, 134L, 267L, 400L)
  )
  testthat::expect_identical(ledgr:::ledgr_history_feature_causality_positions(2L), 1:2)
  testthat::expect_identical(ledgr:::ledgr_history_feature_causality_positions(0L), integer())

  # Every concrete definition is probed, including catalogue rows; a
  # definition with no calculated cell has nothing to probe.
  substrate <- ws43_history_substrate(ws43_causality_close(30L))
  testthat::expect_identical(
    ws43_count_calls(
      "ledgr_history_feature_inputs_prefix",
      ledgr:::ledgr_history_compute_feature_series(
        substrate,
        list(ledgr_ind_sma(3L), ledgr_ind_ema(3L), ledgr_ind_returns(1L))
      )
    ),
    12L
  )
  testthat::expect_identical(
    ws43_count_calls(
      "ledgr_history_feature_inputs_prefix",
      ledgr:::ledgr_history_compute_feature_series(substrate, list(ledgr_ind_sma(40L)))
    ),
    0L
  )
})

testthat::test_that("[LTB-0317] custom bounded fn/series_fn pairs are refuted at the sampled positions", {
  close <- ws43_causality_close()
  substrate <- ws43_history_substrate(close)
  axis <- ws43_history_axis(length(close))
  pair <- function(id, series_fn, ...) {
    ledgr_indicator(
      id,
      fn = function(window) window$close[[2L]] - window$close[[1L]],
      series_fn = series_fn,
      requires_bars = 2L,
      required_fields = "close",
      ...
    )
  }
  differences <- function(bars, params) c(NA, diff(bars$close))
  testthat::expect_identical(
    ws43_feature_values(substrate, pair("exact", differences, history_class = "bounded")),
    c(NA, diff(close))
  )

  # The pair disagrees only on session 17, the last sampled position (the
  # final calculated session with later history). The disagreement depends
  # on that row alone, so the pair stays prefix invariant.
  late_ts <- format(axis[[17L]], "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  late <- function(bars, params) {
    out <- c(NA, diff(bars$close))
    hit <- format(bars$ts_utc, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC") == late_ts
    out[hit] <- out[hit] + 1e-9
    out
  }
  refusal <- tryCatch(
    ws43_feature_values(substrate, pair("late_mismatch", late, history_class = "bounded")),
    error = identity
  )
  testthat::expect_s3_class(refusal, "ledgr_indicator_gap_parity")
  testthat::expect_identical(refusal$feature_id, "late_mismatch")
  testthat::expect_identical(refusal$instrument_id, "AAA")
  testthat::expect_identical(refusal$ts_utc, axis[[17L]])
  testthat::expect_identical(refusal$fn_value, close[[17L]] - close[[16L]])
  testthat::expect_identical(refusal$series_value, close[[17L]] - close[[16L]] + 1e-9)
  testthat::expect_identical(refusal$tolerance, 0)

  # A declared tolerance admits the difference and enters identity.
  tolerant <- pair("late_mismatch", late, history_class = "bounded", tolerance = 1e-6)
  testthat::expect_identical(
    ws43_feature_values(substrate, tolerant)[[17L]],
    close[[17L]] - close[[16L]] + 1e-9
  )
  testthat::expect_false(identical(
    ledgr:::ledgr_active_feature_fingerprint(
      ledgr:::ledgr_precompute_feature_def_from_indicator(tolerant)
    ),
    ledgr:::ledgr_active_feature_fingerprint(
      ledgr:::ledgr_precompute_feature_def_from_indicator(
        pair("late_mismatch", late, history_class = "bounded")
      )
    )
  ))

  # A history-dependent pair is not refuted: its series_fn values stand.
  constant <- function(bars, params) rep(1, nrow(bars))
  testthat::expect_identical(
    ws43_feature_values(substrate, pair("dependent_pair", constant)),
    c(NA, rep(1, 17L))
  )

  # Built-ins and catalogue rows never call fn for refutation at runtime.
  catalogue <- list(ledgr_ind_sma(3L), ledgr_ind_ema(3L), ledgr_ind_rsi(3L), ledgr_ind_returns(2L))
  if (requireNamespace("TTR", quietly = TRUE)) {
    catalogue <- c(catalogue, list(ledgr_ind_ttr("SMA", input = "close", n = 3L)))
  }
  testthat::expect_identical(
    ws43_count_calls(
      "ledgr_call_feature_fn",
      ledgr:::ledgr_history_compute_feature_series(substrate, catalogue)
    ),
    0L
  )
})
