# ledgr-test-file-profile: review

# Session 4 misses one bar (inside the five-session carry horizon); sessions
# 8 to 13 miss six bars, so the sixth is past the horizon and the input
# restarts at session 14.
ws43_gap_close <- function() {
  c(10, 11, 12, NA, 14, 15, 16, NA, NA, NA, NA, NA, NA, 24, 25, 26, 27, 28)
}

ws43_segment_oracle <- function(close, segments, fn) {
  out <- rep(NA_real_, length(close))
  for (segment in segments) {
    out[segment] <- fn(close[segment])
  }
  out
}

testthat::test_that("[LTB-0300] bounded and history-dependent indicators compute over treated segments", {
  testthat::skip_if_not_installed("TTR")
  close <- ws43_gap_close()
  carried_close <- c(10, 11, 12, 12, 14, 15, 16, 16, 16, 16, 16, 16, NA, 24, 25, 26, 27, 28)
  default <- ws43_history_substrate(close)
  strict <- ws43_history_substrate(close, policy = ledgr_history_policy(price_carry = NULL))

  # Built-in bounded SMA: default carry fills the one-session gap and five of
  # the six missing sessions; an explicit no-carry request keeps the strict
  # values, and the restart needs a complete new window.
  testthat::expect_identical(
    ws43_feature_values(default, ledgr_ind_sma(2L)),
    c(NA, 10.5, 11.5, 12, 13, 14.5, 15.5, 16, 16, 16, 16, 16, NA, NA, 24.5, 25.5, 26.5, 27.5)
  )
  testthat::expect_identical(
    ws43_feature_values(strict, ledgr_ind_sma(2L)),
    c(NA, 10.5, 11.5, NA, NA, 14.5, 15.5, NA, NA, NA, NA, NA, NA, NA, 24.5, 25.5, 26.5, 27.5)
  )

  # Returns never consume a carried price: identical with and without carry.
  strict_returns <- c(
    NA, (11 - 10) / 10, (12 - 11) / 11, NA, NA, (15 - 14) / 14, (16 - 15) / 15,
    rep(NA, 7), (25 - 24) / 24, (26 - 25) / 25, (27 - 26) / 26, (28 - 27) / 27
  )
  returns_values <- ws43_feature_values(default, ledgr_ind_returns(1L))
  testthat::expect_identical(returns_values, strict_returns)
  testthat::expect_identical(returns_values, ws43_feature_values(strict, ledgr_ind_returns(1L)))

  # History-dependent TTR EMA runs once per treated segment and restarts.
  ema <- ledgr_ind_ttr("EMA", input = "close", n = 3L)
  testthat::expect_identical(
    ws43_feature_values(default, ema),
    ws43_segment_oracle(carried_close, list(1:12, 14:18), function(x) TTR::EMA(x, n = 3L))
  )
  testthat::expect_identical(
    ws43_feature_values(strict, ema),
    ws43_segment_oracle(close, list(1:3, 5:7, 14:18), function(x) TTR::EMA(x, n = 3L))
  )

  # Multi-output TTR rows: MACD signal (history-dependent, consumes carry) and
  # Bollinger upper band (bounded, volatility family: raw input only).
  macd <- ledgr_ind_ttr("MACD", input = "close", output = "signal",
    nFast = 2L, nSlow = 3L, nSig = 2L)
  macd_oracle <- function(x) {
    value <- TTR::MACD(x, nFast = 2L, nSlow = 3L, nSig = 2L)[, "signal"]
    value[seq_len(min(3L, length(x)))] <- NA_real_
    value
  }
  testthat::expect_identical(
    ws43_feature_values(default, macd),
    ws43_segment_oracle(carried_close, list(1:12, 14:18), macd_oracle)
  )
  bbands <- ledgr_ind_ttr("BBands", input = "close", output = "up", n = 3L)
  bbands_oracle <- function(x) as.numeric(TTR::BBands(x, n = 3L)[, "up"])
  testthat::expect_identical(
    ws43_feature_values(default, bbands),
    ws43_segment_oracle(close, list(1:3, 5:7, 14:18), bbands_oracle)
  )

  # Algorithm variants: default RSI is history-dependent, maType = "SMA" is
  # bounded; both are return-family rows and use raw input.
  rsi_default <- ledgr_ind_ttr("RSI", input = "close", n = 2L)
  rsi_sma <- ledgr_ind_ttr("RSI", input = "close", n = 2L, maType = "SMA")
  long_close <- c(10, 12, 11, 13, 12, 14, NA, 15, 13, 16, 14, 17, 15)
  long <- ws43_history_substrate(long_close)
  testthat::expect_identical(
    ws43_feature_values(long, rsi_default),
    ws43_segment_oracle(long_close, list(1:6, 8:13), function(x) as.numeric(TTR::RSI(x, n = 2L)))
  )
  testthat::expect_identical(
    ws43_feature_values(long, rsi_sma),
    ws43_segment_oracle(long_close, list(1:6, 8:13), function(x) as.numeric(TTR::RSI(x, n = 2L, maType = "SMA")))
  )

  # A bounded fn receives exactly requires_bars rows; stable_after is the
  # first-valid boundary after each start or restart.
  width_probe <- ledgr_indicator(
    "width_probe",
    function(window) nrow(window) * 1000 + window$close[[nrow(window)]],
    requires_bars = 2L,
    stable_after = 4L,
    history_class = "bounded",
    required_fields = "close"
  )
  testthat::expect_identical(
    ws43_feature_values(default, width_probe),
    c(NA, NA, NA, 2012, 2014, 2015, 2016, 2016, 2016, 2016, 2016, 2016, NA, NA, NA, NA, 2027, 2028)
  )
  # An undeclared fn-only definition is history-dependent and also receives
  # exactly requires_bars rows.
  undeclared <- ledgr_indicator("undeclared_width", function(window) nrow(window), requires_bars = 3L)
  testthat::expect_identical(
    ws43_feature_values(default, undeclared),
    c(NA, NA, rep(3, 10), NA, NA, NA, 3, 3, 3)
  )

  # Custom bounded fn/series_fn pairs: an exact pair passes, a mismatch
  # refuses with the instrument and session, a declared tolerance admits a
  # small difference, and a history-dependent pair is not refuted.
  exact_pair <- ledgr_indicator(
    "exact_pair",
    fn = function(window) window$close[[2L]] - window$close[[1L]],
    series_fn = function(bars, params) c(NA, diff(bars$close)),
    requires_bars = 2L,
    history_class = "bounded",
    required_fields = "close"
  )
  testthat::expect_identical(
    ws43_feature_values(default, exact_pair),
    c(NA, 1, 1, 0, 2, 1, 1, 0, 0, 0, 0, 0, NA, NA, 1, 1, 1, 1)
  )
  offset_series <- function(bars, params) c(NA, diff(bars$close)) + 1e-12
  mismatch <- ledgr_indicator(
    "mismatch_pair",
    fn = function(window) window$close[[2L]] - window$close[[1L]],
    series_fn = offset_series,
    requires_bars = 2L,
    history_class = "bounded",
    required_fields = "close"
  )
  refusal <- tryCatch(ws43_feature_values(default, mismatch), error = identity)
  testthat::expect_s3_class(refusal, "ledgr_indicator_gap_parity")
  testthat::expect_identical(refusal$feature_id, "mismatch_pair")
  testthat::expect_identical(refusal$instrument_id, "AAA")
  testthat::expect_identical(refusal$ts_utc, ws43_history_axis(18L)[[2L]])
  tolerant <- ledgr_indicator(
    "tolerant_pair",
    fn = function(window) window$close[[2L]] - window$close[[1L]],
    series_fn = offset_series,
    requires_bars = 2L,
    history_class = "bounded",
    required_fields = "close",
    tolerance = 1e-9
  )
  testthat::expect_equal(
    ws43_feature_values(default, tolerant),
    c(NA, 1, 1, 0, 2, 1, 1, 0, 0, 0, 0, 0, NA, NA, 1, 1, 1, 1) + c(NA, rep(1e-12, 11), NA, NA, rep(1e-12, 4)),
    tolerance = 0
  )
  history_pair <- ledgr_indicator(
    "history_pair",
    fn = function(window) -1,
    series_fn = function(bars, params) cumsum(bars$close),
    requires_bars = 1L
  )
  testthat::expect_identical(
    ws43_feature_values(default, history_pair),
    ws43_segment_oracle(carried_close, list(1:12, 14:18), cumsum)
  )

  # Lifetime-inactive sessions are structural: their prints enter no
  # calculation, bounded windows count only expected sessions, and
  # history-dependent segments restart after the interval.
  axis <- ws43_history_axis(10L)
  inactive <- ledgr_facts_lifetime(data.frame(
    instrument_id = "AAA",
    effective_from = axis[[5L]],
    effective_to = axis[[7L]],
    knowledge_time = axis[[5L]] - 3600,
    assertion = "known_inactive",
    source = "ws43",
    stringsAsFactors = FALSE
  ))
  interval <- ws43_history_substrate(c(10, 11, 12, 13, 99, 99, 16, 17, 18, 19), lifetime = inactive)
  testthat::expect_identical(
    ws43_feature_values(interval, ledgr_ind_sma(2L)),
    c(NA, 10.5, 11.5, 12.5, NA, NA, 14.5, 16.5, 17.5, 18.5)
  )
  testthat::expect_identical(
    ws43_feature_values(interval, ledgr_ind_ttr("EMA", input = "close", n = 2L)),
    ws43_segment_oracle(c(10, 11, 12, 13, NA, NA, 16, 17, 18, 19), list(1:4, 7:10), function(x) TTR::EMA(x, n = 2L))
  )

  # Required-field admission ignores an unrelated missing field.
  high_gap <- ws43_history_substrate(
    c(10, 11, 12, 13, 14),
    fields = list(high = c(11, 12, NA, 14, 15))
  )
  testthat::expect_identical(
    ws43_feature_values(high_gap, ledgr_ind_sma(2L)),
    c(NA, 10.5, 11.5, 12.5, 13.5)
  )
  testthat::expect_identical(
    ws43_feature_values(
      high_gap,
      ledgr_indicator("hl_range", function(window) window$high[[2L]] - window$low[[2L]],
        requires_bars = 2L, history_class = "bounded",
        required_fields = c("high", "low")),
      calculation_start = NULL
    ),
    # Session 3 uses the high carried from session 2 (12) and its own low (11).
    c(NA, 2, 1, 2, 2)
  )
  strict_high <- ws43_history_substrate(
    c(10, 11, 12, 13, 14),
    fields = list(high = c(11, 12, NA, 14, 15)),
    policy = ledgr_history_policy(price_carry = NULL)
  )
  # Without carry the high gap stays missing, and close-only SMA ignores it.
  testthat::expect_identical(
    ws43_feature_values(strict_high, ledgr_ind_sma(2L)),
    c(NA, 10.5, 11.5, 12.5, 13.5)
  )
  testthat::expect_identical(
    ws43_feature_values(
      strict_high,
      ledgr_indicator("hl_range", function(window) window$high[[2L]] - window$low[[2L]],
        requires_bars = 2L, history_class = "bounded",
        required_fields = c("high", "low"))
    ),
    c(NA, 2, NA, NA, 2)
  )
})

testthat::test_that("[LTB-0301] input carry, calculation, readiness and output carry are separate planes", {
  close <- c(10, 11, NA, 13, NA, NA, 16, 17)
  default <- ws43_history_substrate(
    close,
    fields = list(high = c(11, 12, NA, NA, NA, NA, 17, 18))
  )
  sma <- ledgr_ind_sma(2L)
  evidence <- ledgr:::ledgr_history_feature_planes(default, "AAA", sma)
  testthat::expect_identical(evidence$value, c(NA, 10.5, 11, 12, 13, 13, 14.5, 16.5))
  testthat::expect_identical(evidence$observed, c(TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, TRUE, TRUE))
  testthat::expect_identical(evidence$is_missing, !evidence$observed)
  testthat::expect_identical(evidence$input_carried, c(FALSE, FALSE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE))
  testthat::expect_identical(evidence$calculated, rep(TRUE, 8L))
  testthat::expect_identical(evidence$ready, c(FALSE, rep(TRUE, 7L)))
  testthat::expect_identical(evidence$calculation_valid, evidence$ready)
  testthat::expect_identical(evidence$output_carried, rep(FALSE, 8L))
  testthat::expect_identical(evidence$missing_reason, c("not_ready", rep("", 7L)))
  testthat::expect_identical(evidence$required_input_count, c(NA, rep(2L, 7L)))
  testthat::expect_identical(evidence$carried_input_count, c(NA, 0L, 1L, 1L, 1L, 2L, 1L, 0L))
  testthat::expect_identical(evidence$carried_input_share, c(NA, 0, 0.5, 0.5, 0.5, 1, 0.5, 0))

  # A high-and-close definition names the exact blocking field; the high gap
  # at session 4 is carried while close is observed.
  high_close <- ledgr_indicator(
    "high_close",
    function(window) window$high[[2L]] + window$close[[2L]],
    requires_bars = 2L,
    history_class = "bounded",
    required_fields = c("high", "close")
  )
  strict <- ws43_history_substrate(
    close,
    fields = list(high = c(11, 12, NA, NA, NA, NA, 17, 18)),
    policy = ledgr_history_policy(price_carry = NULL)
  )
  strict_evidence <- ledgr:::ledgr_history_feature_planes(strict, "AAA", high_close)
  testthat::expect_identical(
    strict_evidence$blocking_field,
    c("", "", "high,close", "high", "high,close", "high,close", "", "")
  )
  testthat::expect_identical(strict_evidence$input_carried, rep(FALSE, 8L))
  testthat::expect_identical(strict_evidence$calculated, c(TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, TRUE))
  testthat::expect_identical(strict_evidence$ready, c(FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE))
  testthat::expect_identical(
    strict_evidence$missing_reason,
    c("not_ready", "", "required_input_missing", "required_input_missing",
      "required_input_missing", "required_input_missing", "not_ready", "")
  )

  # The return family keeps raw missingness: a carried session is missing
  # input, disclosed as an excluded carried input.
  returns_evidence <- ledgr:::ledgr_history_feature_planes(default, "AAA", ledgr_ind_returns(1L))
  testthat::expect_identical(returns_evidence$input_carried, rep(FALSE, 8L))
  testthat::expect_identical(
    returns_evidence$missing_reason,
    c("not_ready", "", "carried_input_excluded", "not_ready",
      "carried_input_excluded", "carried_input_excluded", "not_ready", "")
  )
  testthat::expect_identical(returns_evidence$value, c(NA, 0.1, NA, NA, NA, NA, NA, 17 / 16 - 1))

  # Output carry alone (input carry disabled) fills only sessions whose own
  # required input is unavailable, from the latest earlier valid output and
  # within its age; it never fills warm-up or re-warming sessions (4 and 7).
  output_only <- ws43_history_substrate(
    close,
    policy = ledgr_history_policy(price_carry = NULL, output_carry = 3L)
  )
  output_evidence <- ledgr:::ledgr_history_feature_planes(output_only, "AAA", sma)
  testthat::expect_identical(output_evidence$value, c(NA, 10.5, 10.5, NA, 10.5, NA, NA, 16.5))
  testthat::expect_identical(output_evidence$output_carried, c(FALSE, FALSE, TRUE, FALSE, TRUE, FALSE, FALSE, FALSE))
  testthat::expect_identical(output_evidence$input_carried, rep(FALSE, 8L))
  testthat::expect_identical(output_evidence$calculation_valid, c(FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE))
  testthat::expect_identical(output_evidence$carry_age_sessions, c(NA, 0L, 1L, NA, 3L, NA, NA, 0L))
  testthat::expect_identical(
    output_evidence$missing_reason,
    c("not_ready", "", "output_carried", "not_ready", "output_carried",
      "output_carry_expired", "not_ready", "")
  )
  # The same policy without output carry leaves every one of those sessions
  # missing: output carry is its own plane.
  no_output <- ledgr:::ledgr_history_feature_planes(
    ws43_history_substrate(close, policy = ledgr_history_policy(price_carry = NULL)),
    "AAA",
    sma
  )
  testthat::expect_identical(no_output$value, c(NA, 10.5, NA, NA, NA, NA, NA, 16.5))
  testthat::expect_identical(no_output$output_carried, rep(FALSE, 8L))
})

testthat::test_that("[LTB-0303] features use the lifetime mask knowable at each pulse", {
  testthat::skip_if_not_installed("TTR")
  axis <- ws43_history_axis(8L)
  # Sessions 4 and 5 are later learned (at session 7) to be lifetime
  # inactive. Before that, they are expected sessions with missing bars.
  late <- ledgr_facts_lifetime(data.frame(
    instrument_id = "AAA",
    effective_from = axis[[4L]] - 3600,
    effective_to = axis[[6L]] - 3600,
    knowledge_time = axis[[7L]] - 3600,
    assertion = "known_inactive",
    source = "ws43",
    stringsAsFactors = FALSE
  ))
  close <- c(10, 11, 20, NA, NA, 15, 16, 17)
  substrate <- ws43_history_substrate(close, lifetime = late)
  ema <- ledgr_ind_ttr("EMA", input = "close", n = 2L)
  values <- ws43_feature_values(substrate, ema)
  before <- as.numeric(TTR::EMA(c(10, 11, 20, 20, 20, 15), n = 2L))
  after <- as.numeric(TTR::EMA(c(15, 16, 17), n = 2L))
  testthat::expect_identical(values[1:6], before)
  testthat::expect_identical(values[7:8], after[2:3])
  # The same facts known from the start make session 6 a restart.
  early <- late
  early$rows$knowledge_time <- axis[[1L]] - 7200
  known <- ws43_feature_values(ws43_history_substrate(close, lifetime = early), ema)
  testthat::expect_true(is.na(known[[6L]]))
  testthat::expect_identical(known[7:8], after[2:3])
})

ws43_parity_snapshot <- function() {
  dates <- as.Date("2020-01-01") + 0:13
  sessions <- ledgr_facts_sessions(
    data.frame(
      session_date = dates,
      status = "open",
      session_open = "09:30:00",
      session_close = "16:00:00",
      knowledge_time = as.POSIXct("2019-12-01", tz = "UTC"),
      stringsAsFactors = FALSE
    ),
    venue_id = "XNYS"
  )
  days <- list(AAA = c(1:5, 7:14), BBB = c(1:3, 10:14))
  bars <- do.call(rbind, lapply(names(days), function(id) {
    day <- days[[id]]
    close <- (if (identical(id, "AAA")) 100 else 50) + day + sin(day)
    data.frame(
      ts_utc = as.POSIXct(paste(dates[day], "16:00:00"), tz = "UTC"),
      instrument_id = id,
      open = close,
      high = close + 1,
      low = close - 1,
      close = close,
      volume = 1000,
      stringsAsFactors = FALSE
    )
  }))
  ledgr_snapshot_from_df(
    bars,
    instruments_df = data.frame(instrument_id = c("AAA", "BBB")),
    facts = ledgr_facts(sessions),
    price_basis = "split_adjusted"
  )
}

ws43_parity_strategy <- function(ctx, params) {
  ids <- c("sma_2", "ret", "ema", "macd_signal", "bb_up", "custom")
  values <- unlist(lapply(c("AAA", "BBB"), function(instrument) {
    vapply(ids, function(id) ctx$features(instrument)[[id]], numeric(1))
  }))
  warning(
    sprintf(
      "WS43|%s|%s",
      ctx$ts_utc,
      paste(ifelse(is.na(values), "NA", sprintf("%.17g", values)), collapse = ",")
    ),
    call. = FALSE
  )
  ctx$hold()
}

ws43_parity_lines <- function(messages) {
  sort(messages[startsWith(messages, "WS43|")], method = "radix")
}

testthat::test_that("[LTB-0302] feature bytes and failure classes match across run, sweep and workers", {
  testthat::skip_if_not_installed("TTR")
  snapshot <- ws43_parity_snapshot()
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  features <- ledgr_feature_map(
    sma_2 = ledgr_ind_sma(2L),
    ret = ledgr_ind_returns(1L),
    ema = ledgr_ind_ttr("EMA", input = "close", n = 3L),
    macd_signal = ledgr_ind_ttr("MACD", input = "close", output = "signal",
      nFast = 2L, nSlow = 3L, nSig = 2L),
    bb_up = ledgr_ind_ttr("BBands", input = "close", output = "up", n = 3L),
    custom = ledgr_indicator("custom_last", function(window) window$close[[nrow(window)]], requires_bars = 2L)
  )
  experiment <- ledgr_experiment(
    snapshot,
    ws43_parity_strategy,
    features = features,
    valuation_policy = ledgr_valuation_stale(1L),
    cost_model = ledgr_cost_zero()
  )
  run_messages <- character()
  bt <- withCallingHandlers(
    ledgr_run(experiment, run_id = "ws43-parity"),
    warning = function(w) {
      run_messages <<- c(run_messages, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  on.exit(close(bt), add = TRUE)
  run_lines <- ws43_parity_lines(run_messages)
  testthat::expect_length(run_lines, 14L)

  grid <- ledgr_param_grid(one = list())
  sweep_lines <- function(sweep) {
    ws43_parity_lines(unlist(lapply(
      sweep$warnings,
      function(conditions) vapply(conditions, conditionMessage, character(1))
    ), use.names = FALSE))
  }
  sequential <- ledgr_sweep(experiment, grid, stop_on_error = TRUE)
  testthat::expect_identical(sweep_lines(sequential), run_lines)

  # A mismatched custom bounded pair refuses with the same class on every
  # route and before any candidate runs.
  mismatch <- ledgr_indicator(
    "mismatch_pair",
    fn = function(window) window$close[[2L]] - window$close[[1L]],
    series_fn = function(bars, params) c(NA, diff(bars$close)) + 1e-9,
    requires_bars = 2L,
    history_class = "bounded",
    required_fields = "close"
  )
  refusing <- ledgr_experiment(
    snapshot,
    function(ctx, params) stop("strategy must not run"),
    features = list(mismatch),
    valuation_policy = ledgr_valuation_stale(1L),
    cost_model = ledgr_cost_zero()
  )
  testthat::expect_error(
    ledgr_run(refusing, run_id = "ws43-refusal"),
    class = "ledgr_indicator_gap_parity"
  )
  testthat::expect_error(
    ledgr_sweep(refusing, grid, stop_on_error = TRUE),
    class = "ledgr_indicator_gap_parity"
  )

  if (requireNamespace("mirai", quietly = TRUE) && !ledgr_test_in_coverage()) {
    parallel <- ledgr_sweep(
      experiment,
      ledgr_param_grid(one = list(), two = list()),
      workers = 2L,
      stop_on_error = TRUE
    )
    testthat::expect_identical(parallel$status, c("DONE", "DONE"))
    lines <- sweep_lines(parallel)
    testthat::expect_identical(lines[seq(1L, length(lines), by = 2L)], run_lines)
    testthat::expect_identical(lines[seq(2L, length(lines), by = 2L)], run_lines)
    testthat::expect_error(
      ledgr_sweep(refusing, ledgr_param_grid(one = list(), two = list()),
        workers = 2L, stop_on_error = TRUE),
      class = "ledgr_indicator_gap_parity"
    )
  }
})

testthat::test_that("[LTB-0304] a custom input_carry declaration excludes carried prices", {
  # Cut 16 decision (13): a custom definition may declare itself a return or
  # volatility definition with input_carry = "excluded".
  ratio <- function(window) window$close[[2L]] / window$close[[1L]] - 1
  make <- function(...) {
    ledgr_indicator(
      "custom_ratio", ratio, requires_bars = 2L,
      history_class = "bounded", required_fields = "close", ...
    )
  }
  undeclared <- make()
  declared <- make(input_carry = "excluded")
  testthat::expect_identical(undeclared$input_carry, "eligible")
  testthat::expect_identical(undeclared$input_carry_source, "default")
  testthat::expect_true(any(grepl(
    "Input carry:   eligible (default for an undeclared definition)",
    utils::capture.output(print(undeclared)),
    fixed = TRUE
  )))
  testthat::expect_identical(declared$input_carry_source, "declared")

  substrate <- ws43_history_substrate(c(10, 11, 12, NA, 14, 15))
  testthat::expect_identical(
    ws43_feature_values(substrate, undeclared),
    c(NA, 11 / 10 - 1, 12 / 11 - 1, 12 / 12 - 1, 14 / 12 - 1, 15 / 14 - 1)
  )
  testthat::expect_identical(
    ws43_feature_values(substrate, declared),
    c(NA, 11 / 10 - 1, 12 / 11 - 1, NA, NA, 15 / 14 - 1)
  )
  evidence <- ledgr:::ledgr_history_feature_planes(substrate, "AAA", declared)
  testthat::expect_identical(evidence$missing_reason[[4L]], "carried_input_excluded")
  testthat::expect_false(evidence$input_carried[[4L]])

  # The declaration is calculation-affecting identity; spelling out the
  # default is not.
  active <- function(indicator) {
    ledgr:::ledgr_active_feature_fingerprint(
      ledgr:::ledgr_precompute_feature_def_from_indicator(indicator)
    )
  }
  testthat::expect_false(identical(active(declared), active(undeclared)))
  testthat::expect_identical(active(make(input_carry = "eligible")), active(undeclared))
  testthat::expect_identical(
    ledgr:::ledgr_indicator_fingerprint(declared),
    ledgr:::ledgr_indicator_fingerprint(undeclared)
  )

  # Built-ins and registered TTR rows take the family from the catalogue.
  testthat::expect_error(
    make(input_carry = "sometimes"),
    class = "ledgr_invalid_indicator_declaration"
  )
  testthat::skip_if_not_installed("TTR")
  testthat::expect_error(
    ledgr_ind_ttr("ROC", input = "close", n = 2L, input_carry = "excluded"),
    class = "ledgr_indicator_history_contradiction"
  )
  testthat::expect_identical(
    ledgr_ind_ttr("ROC", input = "close", n = 2L, na.pad = TRUE,
      input_carry = "excluded")$input_carry_source,
    "declared"
  )
  relabelled <- ledgr_ind_sma(2L)
  relabelled$input_carry <- "excluded"
  relabelled$input_carry_source <- "declared"
  testthat::expect_error(
    ws43_feature_values(substrate, relabelled),
    class = "ledgr_indicator_history_contradiction"
  )
  snapshot <- availability_runtime_fixture(days = 4L)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  testthat::expect_error(
    ledgr_experiment(
      snapshot,
      function(ctx, params) stop("strategy must not run"),
      features = list(relabelled),
      cost_model = ledgr_cost_zero()
    ),
    class = "ledgr_indicator_history_contradiction"
  )
})
