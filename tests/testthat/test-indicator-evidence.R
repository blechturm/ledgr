# ledgr-test-file-profile: review

# Frame feature evidence read through the retained planes of one
# preparation, at the last session of a one-instrument substrate.
ws43_frame_evidence <- function(substrate, definition, calculation_start) {
  values <- ledgr:::ledgr_history_compute_feature_series(
    substrate, list(feature = definition),
    calculation_start = calculation_start
  )
  projection <- ledgr:::ledgr_projection_from_feature_matrix(
    values,
    universe = substrate$instrument_ids,
    pulses_posix = substrate$axis,
    feature_engine_version = "test"
  )
  bound <- ledgr:::ledgr_history_substrate_bind_features(substrate, projection)
  n <- length(substrate$axis)
  ledgr:::ledgr_history_feature_evidence(bound, "feature", 1L, seq_len(n), n)
}

testthat::test_that("[LTB-0319] frame feature evidence separates every v12 feature state", {
  # Sessions 1-2 have no print, session 6 one missing print within the carry
  # horizon, and sessions 9-15 a seven-session gap (five carried, then two
  # beyond the horizon). The calculation starts at session 2, so session 1 is
  # outside the calculation.
  close <- c(NA, NA, 10, 11, 12, NA, 14, 15, rep(NA, 7L), 23, 24, 25)
  axis <- ws43_history_axis(length(close))
  output <- ws43_history_substrate(close, policy = ledgr_history_policy(output_carry = 1L))
  default <- ws43_history_substrate(close)
  start <- axis[[2L]]
  sma <- ledgr_ind_sma(2L)
  ret <- ledgr_ind_returns(1L)
  row <- function(evidence, field) as.vector(evidence[[field]])

  # SMA(2) with one session of output carry.
  ev <- ws43_frame_evidence(output, sma, start)
  testthat::expect_identical(row(ev, "missing_reason"), c(
    "outside_calculation", "required_input_missing", "not_ready", "", "", "",
    "", "", "", "", "", "", "", "output_carried", "output_carry_expired",
    "not_ready", "", ""
  ))
  testthat::expect_identical(row(ev, "calculated"), c(
    FALSE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE,
    TRUE, FALSE, FALSE, TRUE, TRUE, TRUE
  ))
  testthat::expect_identical(row(ev, "ready"), c(
    FALSE, FALSE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE,
    TRUE, FALSE, FALSE, FALSE, TRUE, TRUE
  ))
  testthat::expect_identical(row(ev, "calculation_valid"), row(ev, "ready"))
  testthat::expect_identical(row(ev, "input_carried"), c(
    rep(FALSE, 5L), TRUE, FALSE, FALSE, rep(TRUE, 5L), rep(FALSE, 5L)
  ))
  testthat::expect_identical(row(ev, "output_carried"), c(rep(FALSE, 13L), TRUE, rep(FALSE, 4L)))
  testthat::expect_identical(row(ev, "carry_age_sessions"), c(
    NA, NA, NA, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 1L, NA, NA, 0L, 0L
  ))
  testthat::expect_identical(row(ev, "source_ts_utc")[[14L]], as.numeric(axis[[13L]]))

  # Without output carry the gap beyond the horizon is a missing input.
  ev <- ws43_frame_evidence(default, sma, start)
  testthat::expect_identical(
    row(ev, "missing_reason")[14:16],
    c("required_input_missing", "required_input_missing", "not_ready")
  )

  # A return never consumes a carried price: a missing print inside the
  # horizon is carried_input_excluded, beyond it required_input_missing.
  ev <- ws43_frame_evidence(default, ret, start)
  testthat::expect_identical(row(ev, "missing_reason"), c(
    "outside_calculation", "required_input_missing", "not_ready", "", "",
    "carried_input_excluded", "not_ready", "", rep("carried_input_excluded", 5L),
    "required_input_missing", "required_input_missing", "not_ready", "", ""
  ))
  testthat::expect_identical(row(ev, "input_carried"), rep(FALSE, 18L))

  # The internal per-instrument reader uses the same column meanings.
  for (case in list(list(output, sma), list(default, sma), list(default, ret))) {
    frame <- ws43_frame_evidence(case[[1L]], case[[2L]], start)
    seam <- ledgr:::ledgr_history_feature_planes(
      case[[1L]], "AAA", case[[2L]],
      calculation_start = start
    )
    for (field in c(
      "calculated", "ready", "calculation_valid", "input_carried",
      "output_carried", "carry_age_sessions", "missing_reason"
    )) {
      testthat::expect_identical(row(frame, field), seam[[field]], info = field)
    }
    testthat::expect_identical(row(frame, "source_ts_utc"), as.numeric(seam$source_ts_utc))
  }

  # Cut 16 decision (21): a ready cell whose calculation is not finite reads
  # calculation_non_finite, so every cell that is not calculation_valid
  # carries a reason. Derived from the value; both readers agree.
  non_finite <- ledgr_indicator(
    "non_finite",
    fn = function(window) if (window$close[[nrow(window)]] > 12) NA_real_ else 1,
    requires_bars = 1L,
    history_class = "bounded",
    required_fields = "close"
  )
  levels <- ws43_history_substrate(c(10, 11, 12, 13, 14))
  ev <- ws43_frame_evidence(levels, non_finite, NULL)
  testthat::expect_identical(
    row(ev, "missing_reason"),
    c("", "", "", "calculation_non_finite", "calculation_non_finite")
  )
  testthat::expect_identical(row(ev, "ready"), rep(TRUE, 5L))
  testthat::expect_identical(row(ev, "calculation_valid"), c(TRUE, TRUE, TRUE, FALSE, FALSE))
  testthat::expect_identical(
    ledgr:::ledgr_history_feature_planes(levels, "AAA", non_finite)$missing_reason,
    row(ev, "missing_reason")
  )

  # Input carry is limited to the definition's own required fields: a gap
  # in `high` alone leaves a close-only SMA uncarried while a definition
  # requiring `high` reads a carried input.
  high_gap <- ws43_history_substrate(
    c(10, 11, 12, 13, 14),
    fields = list(high = c(11, 12, NA, 14, 15))
  )
  high_only <- ledgr_indicator(
    "high_level",
    fn = function(window) window$high[[nrow(window)]],
    requires_bars = 1L,
    history_class = "bounded",
    required_fields = "high"
  )
  testthat::expect_identical(
    row(ws43_frame_evidence(high_gap, sma, NULL), "input_carried"),
    rep(FALSE, 5L)
  )
  testthat::expect_identical(
    row(ws43_frame_evidence(high_gap, high_only, NULL), "input_carried"),
    c(FALSE, FALSE, TRUE, FALSE, FALSE)
  )
})

testthat::test_that("[LTB-0320] a terminal interval ends feature carry and bounded windows", {
  # A delisting makes sessions 4-6 terminal-inactive (its print at 4 is
  # structural), a relisting print arrives at session 7 and session 8 is
  # missing. The terminal carry barrier stays sticky after relisting (WS41),
  # so session 7's close is never carried; and a terminal interval ends
  # bounded windows as well as carry (Cut 16 decision 20), so SMA(2) is not
  # ready until two treated rows after the relisting, never mean(12, 17).
  axis <- ws43_history_axis(10L)
  delisting <- ledgr_facts_lifetime(data.frame(
    instrument_id = "AAA",
    effective_from = axis[[4L]],
    effective_to = axis[[7L]],
    knowledge_time = axis[[1L]] - 3600,
    assertion = "known_inactive",
    terminal_event = "delisted",
    source = "ws43",
    stringsAsFactors = FALSE
  ))
  close <- c(10, 11, 12, 99, NA, NA, 17, NA, 19, 20)
  substrate <- ws43_history_substrate(close, lifetime = delisting)
  sma <- ledgr_ind_sma(2L)
  testthat::expect_identical(
    ws43_feature_values(substrate, sma),
    c(NA, 10.5, 11.5, NA, NA, NA, NA, NA, NA, 19.5)
  )
  ev <- ws43_frame_evidence(substrate, sma, NULL)
  testthat::expect_identical(as.vector(ev$input_carried), rep(FALSE, 10L))
  testthat::expect_identical(
    as.vector(ev$missing_reason)[7:10],
    c("not_ready", "required_input_missing", "not_ready", "")
  )
  testthat::expect_identical(as.vector(ev$barrier_reason)[3:4], c("", "terminal"))
  # The internal reader applies the same window rule to its carried-input
  # counts: no window spans the terminal interval.
  seam <- ledgr:::ledgr_history_feature_planes(substrate, "AAA", sma)
  testthat::expect_identical(
    seam$required_input_count[c(3L, 7L, 10L)],
    c(2L, NA, 2L)
  )

  # Every relisting restarts, not only the first (re-review R1): two
  # delisting cycles at sessions 5-6 and 12-13 with relistings at 7 and 14.
  # SMA(3) at session 14 is not ready, never mean(20, 21, 24); the carry
  # barrier stays sticky, so nothing is carried after either relisting.
  axis20 <- ws43_history_axis(20L)
  cycles <- ledgr_facts_lifetime(data.frame(
    instrument_id = "AAA",
    effective_from = c(axis20[[1L]] - 7200, axis20[c(5L, 7L, 12L, 14L)] - 3600),
    effective_to = as.POSIXct(
      c(axis20[c(5L, 7L, 12L, 14L)] - 3600, NA),
      origin = "1970-01-01", tz = "UTC"
    ),
    knowledge_time = axis20[[1L]] - 7200,
    assertion = c("known_active", "known_inactive", "known_active", "known_inactive", "known_active"),
    terminal_event = c(NA, "delisting", NA, "delisting", NA),
    source = "ws43",
    stringsAsFactors = FALSE
  ))
  two <- ws43_history_substrate(
    c(10, 11, 12, 13, 99, 99, 17, 18, 19, 20, 21, 99, 99, 24, 25, 26, 27, 28, 29, 30),
    lifetime = cycles
  )
  sma3 <- ledgr_ind_sma(3L)
  testthat::expect_identical(
    ws43_feature_values(two, sma3),
    c(NA, NA, 11, 12, NA, NA, NA, NA, 18, 19, 20, NA, NA, NA, NA, 25, 26, 27, 28, 29)
  )
  two_seam <- ledgr:::ledgr_history_feature_planes(two, "AAA", sma3)
  testthat::expect_identical(two_seam$missing_reason[14:16], c("not_ready", "not_ready", ""))
  testthat::expect_identical(is.na(two_seam$required_input_count[14:16]), c(TRUE, TRUE, FALSE))
  testthat::expect_identical(
    as.vector(ws43_frame_evidence(two, sma3, NULL)$ready)[14:16],
    c(FALSE, FALSE, TRUE)
  )
  testthat::skip_if_not_installed("TTR")
  testthat::expect_identical(
    ws43_feature_values(substrate, ledgr_ind_ttr("EMA", input = "close", n = 2L)),
    c(NA, 10.5, 11.5, NA, NA, NA, NA, NA, NA, 19.5)
  )
})

testthat::test_that("[LTB-0322] used_before_window reports every returned value that used earlier history", {
  # Re-review R2: a one-session read of a width-1 bounded level reaches
  # before its window when BBB's value is output-carried (no price carry,
  # output_carry = 2) or computed from a carried input (default carry) at
  # session 3, where BBB has no print; session 2 uses nothing earlier.
  level <- ledgr_indicator(
    "level",
    fn = function(window) window$close[[nrow(window)]],
    requires_bars = 1L,
    history_class = "bounded"
  )
  reader <- function(ctx) {
    attr(
      ledgr_history_frame(ctx, feature = "level", lookback = 1L, instruments = "decision_axis"),
      "ledgr_history"
    )$used_before_window
  }
  used <- function(policy) {
    seen <- new.env()
    fixture <- ws42_history_fixture(
      strategy = ws42_spy(seen, reader),
      policy = policy,
      features = ledgr_feature_map(level = level)
    )
    on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
    ledgr_sweep(fixture$exp, ledgr_grid_named(candidate_1 = list(strategy = list(tag = "s"))), stop_on_error = TRUE)
    vapply(2:3, function(k) seen[[paste("s", ws42_iso(fixture$axis[[k]]))]], logical(1))
  }
  testthat::expect_identical(
    used(ledgr_history_policy(price_carry = NULL, output_carry = 2L)),
    c(FALSE, TRUE)
  )
  testthat::expect_identical(used(ledgr_history_policy()), c(FALSE, TRUE))

  # A bounded SMA(2) window that spans a lifetime-inactive interval (sessions
  # 5-6) reaches back further than its width: read over sessions 6-7, the
  # session-7 value averages sessions 4 and 7.
  axis <- ws43_history_axis(8L)
  inactive <- ledgr_facts_lifetime(data.frame(
    instrument_id = "AAA",
    effective_from = axis[[5L]],
    effective_to = axis[[7L]],
    knowledge_time = axis[[1L]] - 3600,
    assertion = "known_inactive",
    source = "ws43",
    stringsAsFactors = FALSE
  ))
  substrate <- ws43_history_substrate(c(10, 11, 12, 13, 99, 99, 16, 17), lifetime = inactive)
  sma <- ledgr_ind_sma(2L)
  values <- ledgr:::ledgr_history_compute_feature_series(substrate, list(feature = sma))
  projection <- ledgr:::ledgr_projection_from_feature_matrix(
    values,
    universe = "AAA", pulses_posix = axis, feature_engine_version = "test"
  )
  bound <- ledgr:::ledgr_history_substrate_bind_features(substrate, projection)
  window <- function(columns) {
    ev <- ledgr:::ledgr_history_feature_evidence(bound, "feature", 1L, columns, max(columns))
    ledgr:::ledgr_history_used_before_window(
      "feature", ev, 1L, columns, ledgr:::ledgr_precompute_feature_def_from_indicator(sma),
      as.numeric(axis[[columns[[1L]]]])
    )
  }
  testthat::expect_identical(as.numeric(values$feature[1L, 7L]), mean(c(13, 16)))
  testthat::expect_true(window(6:7))
  testthat::expect_false(window(1:2))

  # A bounded definition with stable_after > requires_bars reaches back to
  # its segment's readiness (close review S1): with data from session 9, the
  # session-12 value of a requires_bars = 2, stable_after = 4 mean is valid
  # only because session 9 was available, so a read of sessions 10-14 used
  # history before its window and a read of sessions 9-14 did not.
  late <- ws43_history_substrate(c(rep(NA, 8L), 19:30))
  slow <- ledgr_indicator(
    "slow",
    fn = function(window) mean(window$close), requires_bars = 2L,
    stable_after = 4L, gap_contract = "strict_window"
  )
  slow_values <- ledgr:::ledgr_history_compute_feature_series(late, list(feature = slow))
  slow_bound <- ledgr:::ledgr_history_substrate_bind_features(
    late,
    ledgr:::ledgr_projection_from_feature_matrix(
      slow_values,
      universe = "AAA", pulses_posix = late$axis, feature_engine_version = "test"
    )
  )
  slow_window <- function(columns) {
    ev <- ledgr:::ledgr_history_feature_evidence(slow_bound, "feature", 1L, columns, max(columns))
    ledgr:::ledgr_history_used_before_window(
      "feature", ev, 1L, columns, ledgr:::ledgr_precompute_feature_def_from_indicator(slow),
      as.numeric(late$axis[[columns[[1L]]]])
    )
  }
  testthat::expect_identical(as.numeric(slow_values$feature[1L, 12L]), mean(c(21, 22)))
  testthat::expect_true(slow_window(10:14))
  testthat::expect_false(slow_window(9:14))
})
