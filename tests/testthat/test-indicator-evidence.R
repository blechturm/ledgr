# ledgr-test-file-profile: review

# Frame feature evidence read through the retained planes of one
# preparation, at the last session of a one-instrument substrate.
ws43_frame_evidence <- function(substrate, definition, calculation_start) {
  values <- ledgr:::ledgr_history_compute_feature_series(
    substrate, list(feature = definition), calculation_start = calculation_start
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
      case[[1L]], "AAA", case[[2L]], calculation_start = start
    )
    for (field in c(
      "calculated", "ready", "calculation_valid", "input_carried",
      "output_carried", "carry_age_sessions", "missing_reason"
    )) {
      testthat::expect_identical(row(frame, field), seam[[field]], info = field)
    }
    testthat::expect_identical(row(frame, "source_ts_utc"), as.numeric(seam$source_ts_utc))
  }

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
  testthat::skip_if_not_installed("TTR")
  testthat::expect_identical(
    ws43_feature_values(substrate, ledgr_ind_ttr("EMA", input = "close", n = 2L)),
    c(NA, 10.5, 11.5, NA, NA, NA, NA, NA, NA, 19.5)
  )
})
