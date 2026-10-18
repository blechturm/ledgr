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

# Two instruments on one axis; `close` is a named list of close vectors (NA
# marks a missing bar).
ws43_panel_substrate <- function(close) {
  n <- length(close[[1L]])
  axis <- ws43_history_axis(n)
  ids <- names(close)
  bars <- do.call(rbind, lapply(ids, function(id) {
    x <- close[[id]]
    keep <- is.finite(x)
    data.frame(
      instrument_id = id, ts_utc = axis[keep], open = x[keep], high = x[keep] + 1,
      low = x[keep] - 1, close = x[keep], volume = 1000, stringsAsFactors = FALSE
    )
  }))
  data <- list(
    families = data.frame(family = "sessions", stringsAsFactors = FALSE),
    lifetime = NULL,
    sessions = data.frame(
      venue_id = "V", session_date = as.Date(axis), status = "open",
      session_open = axis - 6 * 3600, session_close = axis,
      knowledge_time = axis - 6 * 3600, stringsAsFactors = FALSE
    )
  )
  config <- list(
    universe = list(instrument_ids = ids),
    availability = list(universe_rule = NULL, valuation_policy = unclass(ledgr_valuation_stale())),
    history_policy = ledgr_history_policy(price_carry = NULL)
  )
  ledgr:::ledgr_history_substrate(
    bars = bars, instrument_ids = ids, axis = axis, availability_data = data,
    availability_config = config, snapshot_hash = "ws43-panel"
  )
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

  # The refusal precedes every strategy call and every ledger, equity or
  # sweep/precompute artifact. Sweep and precompute write nothing; a durable
  # run registers before it prepares features, so it is recorded FAILED with
  # no ledger or equity row (Cut 16 decision 18).
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
  con <- get_connection(snapshot)
  store_rows <- function(table, run_id = NULL) {
    if (!DBI::dbExistsTable(con, table)) return(0)
    sql <- sprintf("SELECT COUNT(*) AS n FROM %s", table)
    if (!is.null(run_id)) sql <- paste0(sql, sprintf(" WHERE run_id = '%s'", run_id))
    DBI::dbGetQuery(con, sql)$n
  }
  grid <- ledgr_param_grid(one = list())
  testthat::expect_error(
    ledgr_precompute_features(experiment, grid),
    class = "ledgr_feature_lookahead_detected"
  )
  testthat::expect_error(
    ledgr_sweep(experiment, grid, stop_on_error = TRUE),
    class = "ledgr_feature_lookahead_detected"
  )
  for (table in c("runs", "ledger_events", "equity_curve")) {
    testthat::expect_identical(store_rows(table), 0, info = table)
  }
  testthat::expect_error(
    ledgr_run(experiment, run_id = "ws43-lookahead"),
    class = "ledgr_feature_lookahead_detected"
  )
  testthat::expect_identical(ran$n, 0L)
  testthat::expect_identical(store_rows("runs"), 1)
  testthat::expect_identical(ledgr_run_info(snapshot, "ws43-lookahead")$status, "FAILED")
  for (table in c("ledger_events", "equity_curve")) {
    testthat::expect_true(DBI::dbExistsTable(con, table), info = table)
    testthat::expect_identical(store_rows(table, "ws43-lookahead"), 0, info = table)
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

  # With several instruments the probe is still one instrument per
  # definition: the one with the most calculated cells (BBB here, although
  # AAA comes first), so the count does not grow with instruments and a
  # refusal names the probe.
  panel <- ws43_panel_substrate(list(
    AAA = c(rep(NA, 10L), 100 + 1:10),
    BBB = 50 + sin(1:20)
  ))
  testthat::expect_identical(
    ws43_count_calls(
      "ledgr_history_feature_inputs_prefix",
      ledgr:::ledgr_history_compute_feature_series(panel, list(calc))
    ),
    4L
  )
  demeaned <- ledgr_indicator(
    "demeaned_close",
    fn = function(window) 0,
    requires_bars = 1L,
    series_fn = function(bars, params) bars$close - mean(bars$close)
  )
  refusal <- tryCatch(
    ledgr:::ledgr_history_compute_feature_series(panel, list(demeaned)),
    error = identity
  )
  testthat::expect_s3_class(refusal, "ledgr_feature_lookahead_detected")
  testthat::expect_identical(refusal$instrument_id, "BBB")

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

testthat::test_that("[LTB-0318] history frames report the prepared feature carry planes", {
  # BBB has no print on sessions 3 and 4. Default price carry fills the SMA's
  # close there (input carry); the return never consumes a carried price, so
  # its value on sessions 3 and 4 is the session-2 return carried as output
  # (output_carry = 2) and session 5 is past that age.
  seen <- new.env()
  reader <- function(ctx) {
    list(
      level = attr(ledgr_history_frame(ctx, feature = "level"), "ledgr_history")$evidence,
      ret = attr(ledgr_history_frame(ctx, feature = "ret"), "ledgr_history")$evidence,
      values = ledgr_history_frame(ctx, feature = "ret")
    )
  }
  fixture <- ws42_history_fixture(
    strategy = ws42_spy(seen, reader),
    policy = ledgr_history_policy(output_carry = 2L),
    features = ledgr_feature_map(level = ledgr_ind_sma(2L), ret = ledgr_ind_returns(1L))
  )
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  axis <- fixture$axis
  close(ledgr_run(fixture$exp, params = list(tag = "run"), run_id = "planes"))
  ledgr_sweep(fixture$exp, ledgr_param_grid(list(tag = "sweep")))
  grid <- ledgr_param_grid(list(tag = "precompute"))
  ledgr_sweep(
    fixture$exp, grid,
    precomputed_features = ledgr_precompute_features(fixture$exp, grid)
  )
  at <- function(tag) seen[[paste(tag, ws42_iso(axis[[5L]]))]]
  run <- at("run")
  plane <- function(evidence, field, id = "BBB") unname(evidence[[field]][, id])

  testthat::expect_identical(plane(run$level, "input_carried"), c(FALSE, FALSE, TRUE, TRUE, FALSE))
  # Column meanings follow v12 Sections 5-6 (close review F2): `calculated`
  # is admission, `ready` is stable_after reached in the segment and
  # `calculation_valid` is a ready, finite calculated value.
  testthat::expect_identical(plane(run$level, "calculated"), rep(TRUE, 5L))
  testthat::expect_identical(plane(run$level, "ready"), c(FALSE, TRUE, TRUE, TRUE, TRUE))
  testthat::expect_identical(plane(run$level, "calculation_valid"), c(FALSE, TRUE, TRUE, TRUE, TRUE))
  testthat::expect_identical(plane(run$level, "output_carried"), rep(FALSE, 5L))
  testthat::expect_identical(plane(run$level, "input_carried", "AAA"), rep(FALSE, 5L))

  ret_2 <- (22 - 21) / 21
  testthat::expect_identical(run$values$BBB, c(NA, ret_2, ret_2, ret_2, NA))
  testthat::expect_identical(plane(run$ret, "input_carried"), rep(FALSE, 5L))
  testthat::expect_identical(plane(run$ret, "output_carried"), c(FALSE, FALSE, TRUE, TRUE, FALSE))
  # Sessions 1 and 5 are admitted but not ready (warm-up, then re-warming
  # after the gap); sessions 3 and 4 are not admitted and are output-carried.
  testthat::expect_identical(plane(run$ret, "calculated"), c(TRUE, TRUE, FALSE, FALSE, TRUE))
  testthat::expect_identical(plane(run$ret, "calculation_valid"), c(FALSE, TRUE, FALSE, FALSE, FALSE))
  testthat::expect_identical(plane(run$ret, "ready"), c(FALSE, TRUE, FALSE, FALSE, FALSE))
  testthat::expect_identical(
    plane(run$ret, "source_ts_utc"),
    c(NA, rep(as.numeric(axis[[2L]]), 3L), NA)
  )
  testthat::expect_identical(plane(run$ret, "carry_age_sessions"), c(NA, 0L, 1L, 2L, NA))
  testthat::expect_identical(
    plane(run$ret, "missing_reason"),
    c("not_ready", "", "output_carried", "output_carried", "not_ready")
  )
  testthat::expect_identical(plane(run$ret, "calculation_valid", "AAA"), c(FALSE, rep(TRUE, 4L)))

  # The sweep and explicit-precompute routes read the same retained planes.
  for (tag in c("sweep", "precompute")) {
    testthat::expect_identical(at(tag)$level, run$level, info = tag)
    testthat::expect_identical(at(tag)$ret, run$ret, info = tag)
  }
})
