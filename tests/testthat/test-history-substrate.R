ws41_history_fixture <- function(segment_limit = NULL) {
  axis <- as.POSIXct("2020-01-01 21:00:00", tz = "UTC") + 0:6 * 86400
  membership <- ledgr_facts_membership_snapshots(
    data.frame(
      effective_from = axis[c(1L, 4L)],
      knowledge_time = axis[c(3L, 6L)],
      set_id = c("members-1", "members-2"),
      members = I(list("AAA", "BBB")),
      source = "test",
      stringsAsFactors = FALSE
    ),
    universe_id = "U",
    complete = TRUE
  )
  lifetime <- ledgr_facts_lifetime(data.frame(
    instrument_id = c("AAA", "AAA", "AAA", "BBB"),
    effective_from = axis[c(1L, 4L, 7L, 1L)],
    effective_to = as.POSIXct(c(axis[[4L]], axis[[7L]], NA, NA),
      origin = "1970-01-01", tz = "UTC"
    ),
    knowledge_time = axis[c(1L, 5L, 7L, 1L)],
    assertion = c(
      "known_active", "known_inactive", "known_active", "known_active"
    ),
    terminal_event = c(NA, "delisting", NA, NA),
    source = "test",
    stringsAsFactors = FALSE
  ))
  status <- ledgr_facts_trading_status(data.frame(
    instrument_id = c("AAA", "AAA", "BBB"),
    effective_from = axis[c(1L, 3L, 1L)],
    effective_to = as.POSIXct(c(axis[[3L]], NA, NA),
      origin = "1970-01-01", tz = "UTC"
    ),
    knowledge_time = axis[c(1L, 4L, 1L)],
    status = c("active", "halted", "active"),
    source = "test",
    stringsAsFactors = FALSE
  ))
  bars <- expand.grid(
    instrument_id = c("AAA", "BBB"),
    ts_utc = axis,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  bars <- bars[order(bars$instrument_id, bars$ts_utc), , drop = FALSE]
  value <- seq_len(nrow(bars))
  bars$open <- bars$high <- bars$low <- bars$close <- as.numeric(100 + value)
  bars$volume <- as.numeric(1000 + value)
  bars <- bars[!(bars$instrument_id == "AAA" & bars$ts_utc %in% axis[c(2L, 3L, 7L)]), ]

  data <- list(
    families = data.frame(
      family = c("membership", "trading_status", "lifetime", "sessions"),
      stringsAsFactors = FALSE
    ),
    membership_sets = membership$headers,
    membership = membership$rows,
    status = status$rows,
    lifetime = lifetime$rows,
    sessions = data.frame(
      venue_id = "V",
      session_date = as.Date(axis),
      status = "open",
      session_open = axis - 6 * 3600,
      session_close = axis,
      knowledge_time = axis - 6 * 3600,
      stringsAsFactors = FALSE
    )
  )
  config <- list(
    universe = list(instrument_ids = c("AAA", "BBB")),
    availability = list(
      universe_rule = unclass(ledgr_universe_members("U")),
      valuation_policy = unclass(ledgr_valuation_stale())
    ),
    history_policy = ledgr_history_policy(segment_limit = segment_limit)
  )
  list(
    axis = axis,
    bars = bars,
    data = data,
    config = config,
    substrate = ledgr:::ledgr_history_substrate(
      bars = bars,
      instrument_ids = c("AAA", "BBB"),
      axis = axis,
      availability_data = data,
      availability_config = config,
      snapshot_hash = "ws41"
    )
  )
}

# ledgr-test-profile: review
testthat::test_that("[LTB-0291] causal history substrate preserves two-clock facts", {
  fixture <- ws41_history_fixture()
  substrate <- fixture$substrate
  axis <- fixture$axis

  before <- ledgr:::ledgr_history_substrate_query_facts(
    substrate, "membership", axis[[1L]], axis[[2L]], c("AAA", "BBB")
  )
  learned <- ledgr:::ledgr_history_substrate_query_facts(
    substrate, "membership", axis[[1L]], axis[[3L]], c("AAA", "BBB")
  )
  testthat::expect_identical(unname(before$state), c("unknown", "unknown"))
  testthat::expect_identical(unname(learned$state), c("active", "inactive"))
  testthat::expect_identical(
    ledgr:::ledgr_history_membership_state(
      c(TRUE, FALSE, NA, NA),
      c("member_asserted", "nonmember_asserted", "unknown", "conflicting")
    ),
    c("active", "inactive", "unknown", "conflicting")
  )
  testthat::expect_match(unname(learned$winner[[1L]]), "members-1", fixed = TRUE)
  testthat::expect_identical(
    unname(learned$reason),
    c("member_asserted", "omitted_from_complete_set")
  )

  late <- ledgr:::ledgr_history_substrate_query_facts(
    substrate, "lifetime", axis[[4L]], axis[[5L]], "AAA"
  )
  early_again <- ledgr:::ledgr_history_substrate_query_facts(
    substrate, "lifetime", axis[[4L]], axis[[4L]], "AAA"
  )
  testthat::expect_identical(unname(late$state), "known_inactive")
  testthat::expect_identical(unname(early_again$state), "unknown")

  status_late <- ledgr:::ledgr_history_substrate_query_facts(
    substrate, "trading_status", axis[[3L]], axis[[4L]], "AAA"
  )
  status_early <- ledgr:::ledgr_history_substrate_query_facts(
    substrate, "trading_status", axis[[3L]], axis[[3L]], "AAA"
  )
  testthat::expect_identical(unname(status_late$state), "halted")
  testthat::expect_identical(unname(status_early$state), "unknown")
  testthat::expect_true(substrate$halted[1L, 4L])
  testthat::expect_true(substrate$missing_expected_bar[1L, 2L])
  testthat::expect_true(substrate$inactive_print[1L, 5L])
  testthat::expect_true(substrate$bars$observed[1L, 5L])

  testthat::expect_identical(
    substrate$families$declared,
    c("lifetime", "membership", "sessions", "trading_status")
  )
  testthat::expect_true(all(substrate$families$membership_complete$complete))
  census <- ledgr:::ledgr_history_substrate_census(substrate)
  testthat::expect_setequal(
    census$family,
    c("membership", "trading_status", "lifetime", "lifetime_terminal")
  )
  testthat::expect_identical(
    names(census),
    c(
      "instrument_id", "family", "fact_count", "segment_count",
      "segment_ratio", "segment_limit"
    )
  )
  testthat::expect_true(all(census$segment_count <= census$segment_limit))
  provider <- ledgr:::ledgr_availability_provider_from_substrate(
    substrate,
    fixture$config,
    "ws41"
  )
  for (pulse_idx in c(6L, 3L, 7L)) {
    current <- provider$facts(axis[[pulse_idx]], c("AAA", "BBB"))
    status_now <- ledgr:::ledgr_history_substrate_query_facts(
      substrate,
      "trading_status",
      axis[[pulse_idx]],
      axis[[pulse_idx]],
      c("AAA", "BBB")
    )
    lifetime_now <- ledgr:::ledgr_history_substrate_query_facts(
      substrate,
      "lifetime",
      axis[[pulse_idx]],
      axis[[pulse_idx]],
      c("AAA", "BBB")
    )
    testthat::expect_identical(unname(status_now$state), unname(current$status))
    testthat::expect_identical(
      unname(lifetime_now$state), unname(current$lifetime)
    )
  }
  testthat::expect_error(
    ledgr:::ledgr_history_substrate_validate_owner(
      substrate,
      snapshot_hash = "different",
      history_policy = fixture$config$history_policy,
      instrument_ids = c("AAA", "BBB"),
      required_start = axis[[1L]],
      required_end = axis[[7L]]
    ),
    class = "ledgr_invalid_history_substrate"
  )
  truncated <- substrate
  truncated$source_start_utc <- axis[[2L]]
  truncated$axis <- axis[-1L]
  testthat::expect_error(
    ledgr:::ledgr_history_substrate_validate_owner(
      truncated,
      snapshot_hash = "ws41",
      history_policy = fixture$config$history_policy,
      instrument_ids = c("AAA", "BBB"),
      required_start = axis[[1L]],
      required_end = axis[[7L]]
    ),
    class = "ledgr_invalid_history_substrate"
  )
  testthat::expect_error(
    ws41_history_fixture(segment_limit = 1L),
    class = "ledgr_history_segment_limit_exceeded"
  )

  frozen <- learned
  ignored <- ledgr:::ledgr_history_substrate_query_facts(
    substrate, "membership", axis[[4L]], axis[[6L]], c("AAA", "BBB")
  )
  testthat::expect_identical(frozen, learned)
  testthat::expect_identical(unname(ignored$state), c("inactive", "active"))

  sparse_ids <- sprintf("I%03d", seq_len(128L))
  sparse_rows <- data.frame(
    instrument_id = sparse_ids,
    effective_from = rep(axis[[1L]], length(sparse_ids)),
    effective_to = as.POSIXct(NA, origin = "1970-01-01", tz = "UTC"),
    knowledge_time = rep(axis[[2L]], length(sparse_ids)),
    assertion = "known_active",
    terminal_event = NA_character_,
    fact_id = paste0("lifetime-", sparse_ids),
    stringsAsFactors = FALSE
  )
  testthat::local_mocked_bindings(
    ledgr_history_segments_build = function(...) {
      stop("sparse facts must not enter the global epoch compiler")
    },
    .package = "ledgr"
  )
  sparse <- ledgr:::ledgr_history_lifetime_segments(
    list(lifetime = sparse_rows), sparse_ids, axis, NULL
  )
  testthat::expect_identical(sparse$segment_count, rep(2L, 128L))
  testthat::expect_identical(sparse$fact_count, rep(1L, 128L))

  two_clock <- ledgr_facts_membership_snapshots(
    data.frame(
      effective_from = axis[c(2L, 4L, 6L)],
      knowledge_time = axis[c(5L, 4L, 7L)],
      set_id = c("late-first", "known-second", "last"),
      members = I(list(c("AAA"), c("BBB"), c("AAA", "BBB"))),
      source = "test",
      stringsAsFactors = FALSE
    ),
    universe_id = "U",
    complete = TRUE
  )
  two_clock_data <- list(
    membership_sets = two_clock$headers,
    membership = two_clock$rows
  )
  two_clock_segments <- ledgr:::ledgr_history_membership_segments(
    two_clock_data, "U", c("AAA", "BBB"), axis, NULL
  )
  for (observation_idx in seq_along(axis)) {
    for (knowledge_idx in seq_along(axis)) {
      expected_answer <- ledgr:::ledgr_membership_resolve_prepared(
        two_clock_data,
        "U",
        axis[[observation_idx]],
        instruments = c("AAA", "BBB"),
        knowledge_cutoff = axis[[knowledge_idx]]
      )$rows
      actual_answer <- ledgr:::ledgr_history_segments_query(
        two_clock_segments,
        observation_idx,
        axis[[knowledge_idx]],
        1:2
      )
      testthat::expect_identical(
        actual_answer$state,
        ledgr:::ledgr_history_membership_state(
          expected_answer$member, expected_answer$reason
        )
      )
      testthat::expect_identical(
        actual_answer$winner,
        as.character(expected_answer$evidence_ids)
      )
      testthat::expect_identical(
        actual_answer$reason,
        as.character(expected_answer$reason)
      )
    }
  }
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0292] history treatment is causal, bounded and disclosed", {
  axis <- as.POSIXct("2020-01-01", tz = "UTC") + 0:6 * 86400
  value <- c(NA, 10, NA, NA, 999, 20, NA)
  expected <- c(TRUE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE)
  treated <- ledgr:::ledgr_history_input_carry(
    value, expected, axis, max_sessions = 2L
  )
  testthat::expect_equal(treated$value, c(NA, 10, 10, 10, NA, 20, 20))
  testthat::expect_identical(
    treated$input_carried,
    c(FALSE, FALSE, TRUE, TRUE, FALSE, FALSE, TRUE)
  )
  testthat::expect_identical(
    treated$carry_age_sessions,
    c(NA_integer_, 0L, 1L, 2L, NA_integer_, 0L, 1L)
  )
  testthat::expect_true(treated$observed[[5L]])
  testthat::expect_false(treated$calculation_valid[[5L]])
  testthat::expect_identical(treated$missing_reason[[5L]], "inactive_interval_print")
  testthat::expect_identical(treated$barrier_reason[[5L]], "lifetime_inactive")

  short <- ledgr:::ledgr_history_input_carry(
    value, expected, axis, max_sessions = 1L
  )
  testthat::expect_true(is.na(short$value[[4L]]))
  testthat::expect_identical(short$missing_reason[[4L]], "carry_expired")
  strict <- ledgr:::ledgr_history_input_carry(
    value, expected, axis, max_sessions = NULL
  )
  volume <- ledgr:::ledgr_history_input_carry(
    value, expected, axis, max_sessions = 5L, carry_allowed = FALSE
  )
  testthat::expect_false(any(strict$input_carried))
  testthat::expect_false(any(volume$input_carried))
  testthat::expect_true(is.na(strict$value[[3L]]))
  testthat::expect_true(is.na(volume$value[[3L]]))

  no_refresh <- ledgr:::ledgr_history_input_carry(
    c(1, NA, NA, NA), rep(TRUE, 4L), axis[1:4], max_sessions = 2L
  )
  testthat::expect_equal(no_refresh$value, c(1, 1, 1, NA))
  testthat::expect_identical(no_refresh$carry_age_sessions, c(0L, 1L, 2L, NA_integer_))

  terminal <- ledgr:::ledgr_history_input_carry(
    c(1, NA, 2, NA),
    rep(TRUE, 4L),
    axis[1:4],
    max_sessions = 5L,
    terminal_barrier = c(FALSE, TRUE, TRUE, TRUE)
  )
  testthat::expect_equal(terminal$value, c(1, NA, 2, NA))
  testthat::expect_false(any(terminal$input_carried))
  testthat::expect_identical(
    terminal$barrier_reason,
    c("", "terminal", "terminal", "terminal")
  )
  matrix_treatment <- ledgr:::ledgr_history_input_carry_matrix(
    rbind(value, c(1, NA, NA, 4, NA, 6, NA)),
    rbind(expected, rep(TRUE, 7L)),
    axis,
    max_sessions = 2L,
    terminal_barrier = rbind(rep(FALSE, 7L), rep(FALSE, 7L))
  )
  testthat::expect_equal(matrix_treatment$value[1L, ], treated$value)
  for (field in c(
    "value", "expected", "observed", "is_missing", "input_carried",
    "calculated", "output_carried", "source_ts_utc",
    "carry_age_sessions", "ready", "calculation_valid", "missing_reason",
    "barrier_reason"
  )) {
    actual <- unname(matrix_treatment[[field]][1L, ])
    expected_value <- unname(treated[[field]])
    if (identical(field, "source_ts_utc")) {
      actual <- as.numeric(actual)
      expected_value <- as.numeric(expected_value)
    }
    testthat::expect_equal(
      actual,
      expected_value,
      info = field
    )
  }
  testthat::expect_equal(
    matrix_treatment$value[2L, ],
    c(1, 1, 1, 4, 4, 6, 6)
  )

  admission <- ledgr:::ledgr_history_estimator_admission(treated)
  testthat::expect_false(admission$included)
  fully_treated <- ledgr:::ledgr_history_input_carry(
    c(1, NA, 2), rep(TRUE, 3L), axis[1:3], max_sessions = 1L
  )
  admitted <- ledgr:::ledgr_history_estimator_admission(fully_treated)
  testthat::expect_true(admitted$included)
  testthat::expect_identical(admitted$carried_input_count, 1L)
  testthat::expect_equal(admitted$carried_input_share, 1 / 3)
  testthat::expect_identical(
    ledgr:::ledgr_history_evidence_fields(),
    c(
      "expected", "observed", "is_missing", "input_carried", "calculated",
      "output_carried", "source_ts_utc", "carry_age_sessions", "ready",
      "calculation_valid", "missing_reason", "barrier_reason", "requested",
      "included", "exclusion_reason", "required_input_count",
      "carried_input_count", "carried_input_share"
    )
  )

  fixture <- ws41_history_fixture()
  early <- ledgr:::ledgr_history_substrate_treated_field(
    fixture$substrate,
    "close",
    cutoff = fixture$axis[[4L]]
  )
  early_copy <- early
  late <- ledgr:::ledgr_history_substrate_treated_field(
    fixture$substrate,
    "close",
    cutoff = fixture$axis[[6L]]
  )
  no_carry <- ledgr:::ledgr_history_substrate_treated_field(
    fixture$substrate,
    "close",
    cutoff = fixture$axis[[4L]],
    carry_allowed = FALSE
  )
  testthat::expect_true(early$input_carried[1L, 2L])
  testthat::expect_true(is.na(no_carry$value[1L, 2L]))
  testthat::expect_false(late$expected[1L, 4L])
  testthat::expect_false(late$calculation_valid[1L, 5L])
  testthat::expect_identical(early, early_copy)
  revived <- ledgr:::ledgr_history_substrate_treated_field(
    fixture$substrate,
    "close",
    cutoff = fixture$axis[[7L]]
  )
  testthat::expect_true(revived$expected[1L, 7L])
  testthat::expect_true(is.na(revived$value[1L, 7L]))
  testthat::expect_false(revived$input_carried[1L, 7L])
  testthat::expect_identical(revived$barrier_reason[1L, 7L], "terminal")

  output <- ledgr:::ledgr_history_output_carry(
    value = c(NA, 1, NA, NA),
    eligible_gap = c(FALSE, FALSE, TRUE, FALSE),
    expected = rep(TRUE, 4L),
    axis = axis[1:4],
    max_sessions = 2L
  )
  testthat::expect_equal(output$value, c(NA, 1, 1, NA))
  testthat::expect_identical(
    output$output_carried,
    c(FALSE, FALSE, TRUE, FALSE)
  )
  warmup <- ledgr:::ledgr_history_output_carry(
    value = c(7, NA),
    eligible_gap = c(FALSE, TRUE),
    expected = c(TRUE, TRUE),
    axis = axis[1:2],
    max_sessions = 1L,
    source_eligible = c(FALSE, FALSE)
  )
  testthat::expect_true(is.na(warmup$value[[2L]]))
  testthat::expect_false(warmup$output_carried[[2L]])

  late_known_early <- ledgr:::ledgr_history_substrate_treated_field(
    fixture$substrate,
    "close",
    cutoff = fixture$axis[[4L]],
    observation_idx = 1:4,
    carry_allowed = FALSE
  )
  late_known_early_copy <- late_known_early
  late_known_after <- ledgr:::ledgr_history_substrate_treated_field(
    fixture$substrate,
    "close",
    cutoff = fixture$axis[[5L]],
    observation_idx = 1:4,
    carry_allowed = FALSE
  )
  early_output <- ledgr:::ledgr_history_output_carry(
    value = c(1, NA, 2, NA),
    eligible_gap = c(FALSE, TRUE, FALSE, TRUE),
    expected = unname(late_known_early$expected[1L, ]),
    axis = fixture$axis[1:4],
    max_sessions = 2L
  )
  after_output <- ledgr:::ledgr_history_output_carry(
    value = c(1, NA, 2, NA),
    eligible_gap = c(FALSE, TRUE, FALSE, TRUE),
    expected = unname(late_known_after$expected[1L, ]),
    axis = fixture$axis[1:4],
    max_sessions = 2L
  )
  testthat::expect_identical(
    unname(late_known_early$expected[1L, ]),
    rep(TRUE, 4L)
  )
  testthat::expect_identical(
    unname(late_known_after$expected[1L, ]),
    c(TRUE, TRUE, TRUE, FALSE)
  )
  testthat::expect_equal(early_output$value, c(1, 1, 2, 2))
  testthat::expect_equal(after_output$value, c(1, 1, 2, NA))
  testthat::expect_identical(
    early_output$output_carried,
    c(FALSE, TRUE, FALSE, TRUE)
  )
  testthat::expect_identical(
    after_output$output_carried,
    c(FALSE, TRUE, FALSE, FALSE)
  )
  testthat::expect_identical(
    after_output$missing_reason,
    c("", "output_carried", "", "not_expected")
  )
  testthat::expect_identical(late_known_early, late_known_early_copy)

  action_data <- fixture$data
  action_data$families <- rbind(
    action_data$families,
    data.frame(family = "equity_corporate_actions", stringsAsFactors = FALSE)
  )
  action_data$corporate_actions <- data.frame(
    fact_id = "cash-1",
    parent_instrument_id = "AAA",
    entitlement_time = fixture$axis[[2L]],
    effective_time = fixture$axis[[2L]],
    knowledge_time = fixture$axis[[1L]],
    stringsAsFactors = FALSE
  )
  assumed_config <- fixture$config
  assumed_config$data <- list(price_basis = NULL)
  declared_config <- fixture$config
  declared_config$data <- list(price_basis = "split_adjusted")
  assumed_substrate <- ledgr:::ledgr_history_substrate(
    bars = fixture$bars,
    instrument_ids = c("AAA", "BBB"),
    axis = fixture$axis,
    availability_data = action_data,
    availability_config = assumed_config,
    snapshot_hash = "assumed-basis"
  )
  declared_substrate <- ledgr:::ledgr_history_substrate(
    bars = fixture$bars,
    instrument_ids = c("AAA", "BBB"),
    axis = fixture$axis,
    availability_data = action_data,
    availability_config = declared_config,
    snapshot_hash = "declared-basis"
  )
  assumed_treatment <- ledgr:::ledgr_history_substrate_treated_field(
    assumed_substrate,
    "close",
    cutoff = fixture$axis[[3L]],
    observation_idx = 1:3
  )
  declared_treatment <- ledgr:::ledgr_history_substrate_treated_field(
    declared_substrate,
    "close",
    cutoff = fixture$axis[[3L]],
    observation_idx = 1:3
  )
  testthat::expect_identical(
    assumed_treatment$barrier_reason,
    declared_treatment$barrier_reason
  )
  testthat::expect_identical(
    assumed_treatment$input_carried,
    declared_treatment$input_carried
  )
  testthat::expect_true(assumed_treatment$input_carried[1L, 2L])

  action_dates <- as.Date("2020-02-03") + 0:3
  action_sessions <- ledgr_facts_sessions(
    data.frame(
      session_date = action_dates,
      status = "open",
      session_open = "14:30:00",
      session_close = "21:00:00",
      knowledge_time = as.POSIXct("2020-01-31", tz = "UTC"),
      stringsAsFactors = FALSE
    ),
    venue_id = "XNYS",
    timezone = "UTC"
  )
  dated_action <- ledgr_facts_equity_corporate_actions(data.frame(
    subtype = "ordinary_cash_dividend",
    parent_instrument_id = "AAA",
    entitlement_time = action_dates[[2L]],
    effective_time = action_dates[[2L]],
    complete = TRUE,
    provenance_tier = "snapshot_bound",
    gross_cash_per_parent_unit = 1,
    gross_cash_validated = TRUE,
    source = "ws41",
    stringsAsFactors = FALSE
  ))
  action_facts <- ledgr_facts(action_sessions, dated_action)
  normalized_action <- ledgr:::ledgr_facts_family(
    action_facts, "equity_corporate_actions"
  )[[1L]]$rows
  testthat::expect_identical(
    normalized_action$knowledge_time,
    action_sessions$rows$session_open[[2L]]
  )
  testthat::expect_identical(
    normalized_action$entitlement_time,
    action_sessions$rows$session_close[[2L]]
  )
  action_bars <- data.frame(
    instrument_id = "AAA",
    ts_utc = action_sessions$rows$session_close,
    open = 100,
    high = 101,
    low = 99,
    close = 100,
    volume = 1000,
    stringsAsFactors = FALSE
  )
  action_snapshot <- ledgr_snapshot_from_df(
    action_bars,
    facts = action_facts,
    price_basis = "split_adjusted"
  )
  withr::defer(ledgr_snapshot_close(action_snapshot))
  action_experiment <- ledgr_experiment(
    action_snapshot,
    function(ctx, params) ctx$hold(),
    opening = ledgr_opening(
      cash = 1000,
      positions = c(AAA = 2),
      cost_basis = c(AAA = 100)
    ),
    cost_model = ledgr_cost_zero()
  )
  action_run <- ledgr_run(action_experiment, run_id = "ws41-dated-action")
  withr::defer(close(action_run))
  action_summary <- ledgr:::ledgr_corporate_action_summary(action_run)
  testthat::expect_identical(action_summary$gross_cash_posted, 2)
  action_store <- ledgr:::ledgr_backtest_read_connection(action_run)
  withr::defer(action_store$close())
  action_post <- DBI::dbGetQuery(
    action_store$con,
    paste(
      "SELECT ts_utc FROM ledger_events",
      "WHERE run_id = ? AND event_type = 'CASHFLOW'",
      "AND meta_json LIKE '%corporate_action_cash%'"
    ),
    params = list(action_run$run_id)
  )
  testthat::expect_identical(nrow(action_post), 1L)
  testthat::expect_identical(
    as.numeric(action_post$ts_utc),
    as.numeric(action_sessions$rows$session_close[[2L]])
  )
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0293] availability fold ownership has one history reader", {
  repository <- ledgr_test_source_root()
  fold <- paste(readLines(file.path(repository, "R", "fold-engine.R")), collapse = "\n")
  runner <- paste(readLines(file.path(repository, "R", "backtest-runner.R")), collapse = "\n")
  sweep <- paste(readLines(file.path(repository, "R", "sweep.R")), collapse = "\n")

  testthat::expect_length(gregexpr(
    "services$history_reader$bars(pulse_idx)", fold, fixed = TRUE
  )[[1L]], 1L)
  testthat::expect_false(grepl(
    "ledgr_history_substrate_bar_frame", fold, fixed = TRUE
  ))
  testthat::expect_false(grepl(
    "history_substrate = history_substrate", paste(
      deparse(ledgr:::ledgr_fold_stage_plan),
      deparse(ledgr:::ledgr_fold_stage_apply),
      deparse(ledgr:::ledgr_fold_stage_commit),
      collapse = "\n"
    ), fixed = TRUE
  ))
  testthat::expect_true(grepl(
    paste0(
      "if \\(availability_active\\) \\{[\\s\\S]*?",
      "history_substrate <- ledgr_history_substrate\\([\\s\\S]*?",
      "bars_all <- NULL[\\s\\S]*?\\} else \\{[\\s\\S]*?",
      "raw_bars_by_id <- split\\(bars_all"
    ),
    runner,
    perl = TRUE
  ))
  testthat::expect_match(sweep, "ledgr_sweep_stage_history_tasks", fixed = TRUE)
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0294] staged history identity is exact and tasks are lean", {
  fixture <- ws41_history_fixture()
  fixture$substrate$feature_projection <- list(
    feature_engine_version = "test",
    feature_values = list()
  )
  invariant <- list(
    history_substrate = fixture$substrate,
    pulses_posix = fixture$substrate$axis,
    availability_config = fixture$config,
    snapshot_hash = fixture$substrate$snapshot_hash
  )
  identity <- ledgr:::ledgr_history_stage_identity(fixture$substrate, "owner")
  invariant$staged_owner_id <- "owner"
  invariant$staged_invariant_identity <- identity
  ledgr:::ledgr_history_worker_clear()
  on.exit(ledgr:::ledgr_history_worker_clear(), add = TRUE)

  testthat::expect_error(
    ledgr:::ledgr_history_worker_take(identity),
    class = "ledgr_staged_history_mismatch"
  )
  ledgr:::ledgr_history_worker_stage(invariant, identity)
  testthat::expect_identical(
    ledgr:::ledgr_history_worker_take(identity)$history_substrate$snapshot_hash,
    "ws41"
  )
  testthat::expect_identical(
    ledgr:::ledgr_history_worker_take(identity)$pulses_iso,
    format(
      fixture$substrate$axis,
      "%Y-%m-%dT%H:%M:%SZ",
      tz = "UTC"
    )
  )
  testthat::expect_s3_class(
    ledgr:::ledgr_history_worker_take(identity)$availability_provider,
    "ledgr_availability_provider"
  )
  testthat::with_mocked_bindings(
    testthat::expect_identical(
      ledgr:::ledgr_history_worker_take(identity)$history_substrate$snapshot_hash,
      "ws41"
    ),
    ledgr_history_stage_identity = function(...) {
      stop("candidate tasks must not rehash the staged invariant")
    },
    .package = "ledgr"
  )
  testthat::expect_error(
    ledgr:::ledgr_history_worker_take(paste0(identity, "x")),
    class = "ledgr_staged_history_mismatch"
  )
  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  testthat::local_mocked_bindings(
    ledgr_sweep_eval_candidate_task = function(...) {
      calls$n <- calls$n + 1L
      stop("candidate work must not start")
    },
    .package = "ledgr"
  )
  testthat::expect_error(
    ledgr:::ledgr_sweep_worker_eval_candidate_task(list(
      staged_invariant_identity = paste0(identity, "stale")
    )),
    class = "ledgr_staged_history_mismatch"
  )
  testthat::expect_identical(calls$n, 0L)
  altered <- invariant
  altered$history_substrate$snapshot_hash <- "altered"
  testthat::expect_error(
    ledgr:::ledgr_history_worker_stage(altered, identity),
    class = "ledgr_staged_history_mismatch"
  )

  tasks <- list(
    c(list(
      history_substrate = fixture$substrate,
      pulses_posix = fixture$substrate$axis,
      pulses_iso = format(
        fixture$substrate$axis, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"
      )
    ), list(
      candidate_id = "a", params = list(n = 1L)
    )),
    c(list(
      history_substrate = fixture$substrate,
      pulses_posix = fixture$substrate$axis,
      pulses_iso = format(
        fixture$substrate$axis, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"
      )
    ), list(
      candidate_id = "b", params = list(n = 2L)
    ))
  )
  staged <- ledgr:::ledgr_sweep_stage_history_tasks(tasks, "owner")
  testthat::expect_true(staged$bytes > 0)
  testthat::expect_identical(
    staged$census$payload_class[staged$census$field == "history_substrate"],
    "staged_invariant"
  )
  testthat::expect_identical(
    staged$census$payload_class[staged$census$field == "candidate_id"],
    "candidate_varying"
  )
  testthat::expect_identical(
    staged$census$payload_class[staged$census$field == "pulses_iso"],
    "worker_reconstructed"
  )
  testthat::expect_identical(
    staged$census$bytes[staged$census$field == "pulses_iso"],
    0
  )
  testthat::expect_null(staged$invariant$pulses_iso)
  testthat::expect_true(all(vapply(staged$tasks, function(task) {
    is.null(task$history_substrate) && is.character(task$staged_invariant_identity)
  }, logical(1))))
  testthat::expect_lt(
    as.numeric(object.size(staged$tasks)),
    as.numeric(object.size(tasks))
  )
  ledgr:::ledgr_history_worker_clear()
  testthat::expect_error(
    ledgr:::ledgr_history_worker_take(identity),
    class = "ledgr_staged_history_mismatch"
  )
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("[LTB-0295] availability sweeps stage history without semantic drift", {
  testthat::skip_if_not_installed("mirai")
  ledgr_test_skip_workers_in_coverage()
  snapshot <- availability_runtime_fixture(days = 4L)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    target <- ctx$hold()
    target[["AAA"]] <- params$qty
    target
  }
  experiment <- ledgr_experiment(
    snapshot,
    strategy,
    cost_model = ledgr_cost_zero()
  )
  grid <- ledgr_param_grid(
    one = list(qty = 1),
    two = list(qty = 2),
    three = list(qty = 3)
  )
  set.seed(8675309)
  caller_rng <- .Random.seed
  builds <- new.env(parent = emptyenv())
  builds$n <- 0L
  builds$result <- NULL
  original_prepare <- ledgr:::ledgr_availability_provider_prepare
  local({
    testthat::local_mocked_bindings(
      ledgr_availability_provider_prepare = function(...) {
        builds$n <- builds$n + 1L
        original_prepare(...)
      },
      .package = "ledgr"
    )
    builds$result <- ledgr_sweep(
      experiment, grid, seed = 42L, workers = 1L
    )
  })
  sequential <- builds$result
  testthat::expect_identical(builds$n, 1L)
  testthat::expect_identical(.Random.seed, caller_rng)
  current_dispatch <- testthat::with_mocked_bindings(
    ledgr_sweep(experiment, grid, seed = 42L, workers = 2L),
    ledgr_sweep_stage_history_tasks = function(tasks, owner_id) {
      list(
        tasks = tasks,
        invariant = NULL,
        identity = NULL,
        bytes = 0,
        census = ledgr:::ledgr_sweep_history_payload_census(tasks)
      )
    },
    ledgr_parallel_mirai_stage_history = function(...) invisible(TRUE),
    .package = "ledgr"
  )
  testthat::expect_identical(.Random.seed, caller_rng)
  parallel_two <- ledgr_sweep(experiment, grid, seed = 42L, workers = 2L)
  testthat::expect_identical(.Random.seed, caller_rng)
  parallel_three <- ledgr_sweep(experiment, grid, seed = 42L, workers = 3L)
  testthat::expect_identical(.Random.seed, caller_rng)

  comparable <- function(x) {
    out <- as.data.frame(x[, c(
      "candidate_id", "candidate_row", "status", "final_equity",
      "n_trades", "execution_seed", "risk_chain_hash", "error_class",
      "error_msg"
    ), drop = FALSE])
    attr(out, "sweep_id") <- NULL
    attr(out, "staged_invariant_bytes") <- NULL
    attr(out, "staged_payload_census") <- NULL
    attr(out, "history_worker_support") <- NULL
    out
  }
  testthat::expect_equal(comparable(current_dispatch), comparable(sequential))
  testthat::expect_equal(comparable(parallel_two), comparable(sequential))
  testthat::expect_equal(comparable(parallel_three), comparable(sequential))
  testthat::expect_identical(parallel_two$candidate_id, c("one", "two", "three"))
  testthat::expect_identical(parallel_three$candidate_id, c("one", "two", "three"))
  testthat::expect_gt(attr(parallel_two, "staged_invariant_bytes"), 0)
  testthat::expect_gt(attr(parallel_three, "staged_invariant_bytes"), 0)
  testthat::expect_identical(attr(sequential, "staged_invariant_bytes"), 0)
  testthat::expect_identical(
    attr(parallel_two, "history_worker_support"), "measured"
  )
  testthat::expect_identical(
    attr(parallel_three, "history_worker_support"), "unmeasured"
  )
  testthat::expect_false(
    "availability_data" %in% attr(parallel_two, "staged_payload_census")$field
  )
  testthat::expect_identical(
    attr(parallel_two, "staged_payload_census")$payload_class[
      attr(parallel_two, "staged_payload_census")$field == "history_substrate"
    ],
    "staged_invariant"
  )
  for (field in c(
    "snapshot_hash", "strategy_hash", "feature_union_hash",
    "metric_context_hash", "cost_model_hash", "risk_chain_hash"
  )) {
    testthat::expect_identical(
      attr(current_dispatch, field),
      attr(sequential, field),
      info = paste("current dispatch", field)
    )
    testthat::expect_identical(
      attr(parallel_two, field),
      attr(sequential, field),
      info = field
    )
    testthat::expect_identical(
      attr(parallel_three, field),
      attr(sequential, field),
      info = field
    )
  }
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("[LTB-0296] availability walk-forward accepts staged workers", {
  testthat::skip_if_not_installed("mirai")
  ledgr_test_skip_workers_in_coverage()
  snapshot <- availability_runtime_fixture(days = 13L)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    if (!any(is.finite(ctx$vec$feature("return_2")))) {
      return(ctx$hold())
    }
    target <- ctx$flat()
    target[["AAA"]] <- params$qty
    target
  }
  experiment <- ledgr_experiment(
    snapshot,
    strategy,
    features = list(ledgr_ind_returns(2L)),
    cost_model = ledgr_cost_zero()
  )
  grid <- ledgr_param_grid(one = list(qty = 1), two = list(qty = 2))
  folds <- ledgr:::ledgr_fold_list(
    list(
      ledgr:::ledgr_fold(
        "2020-01-01T16:00:00Z", "2020-01-04T16:00:00Z",
        "2020-01-05T16:00:00Z", "2020-01-08T16:00:00Z",
        fold_seq = 1L
      ),
      ledgr:::ledgr_fold(
        "2020-01-02T16:00:00Z", "2020-01-07T16:00:00Z",
        "2020-01-09T16:00:00Z", "2020-01-12T16:00:00Z",
        fold_seq = 2L
      )
    ),
    constructor = list(type_id = "explicit")
  )
  set.seed(2468)
  caller_rng <- .Random.seed
  builds <- new.env(parent = emptyenv())
  builds$n <- 0L
  original_prepare <- ledgr:::ledgr_history_substrate_for_experiment
  testthat::local_mocked_bindings(
    ledgr_history_substrate_for_experiment = function(...) {
      builds$n <- builds$n + 1L
      original_prepare(...)
    },
    .package = "ledgr"
  )
  sequential <- ledgr_walk_forward(
    experiment, grid, folds, ledgr_rule_argmax("sharpe_ratio"),
    seed = 7L, workers = 1L
  )
  testthat::expect_identical(.Random.seed, caller_rng)
  sequential_test_has_fills <- vapply(
    sequential$test_runs,
    function(run) nrow(ledgr_results(run, "fills")) > 0L,
    logical(1)
  )
  lapply(sequential$test_runs, close)
  parallel <- ledgr_walk_forward(
    experiment,
    grid,
    folds,
    ledgr_rule_argmax("sharpe_ratio"),
    seed = 7L,
    workers = 2L
  )
  on.exit(lapply(parallel$test_runs, close), add = TRUE)
  testthat::expect_identical(.Random.seed, caller_rng)
  parallel_three <- ledgr_walk_forward(
    experiment,
    grid,
    folds,
    ledgr_rule_argmax("sharpe_ratio"),
    seed = 7L,
    workers = 3L
  )
  on.exit(lapply(parallel_three$test_runs, close), add = TRUE)
  testthat::expect_identical(.Random.seed, caller_rng)
  testthat::expect_identical(builds$n, 3L)
  testthat::expect_true(all(sequential_test_has_fills))
  testthat::expect_identical(sequential$history_worker_support, "measured")
  testthat::expect_identical(parallel$history_worker_support, "measured")
  testthat::expect_identical(
    parallel_three$history_worker_support, "unmeasured"
  )
  testthat::expect_identical(parallel$session_id, sequential$session_id)
  testthat::expect_identical(parallel_three$session_id, sequential$session_id)
  testthat::expect_equal(parallel$folds, sequential$folds)
  testthat::expect_equal(parallel_three$folds, sequential$folds)
  testthat::expect_equal(parallel$scores, sequential$scores)
  testthat::expect_equal(parallel_three$scores, sequential$scores)
  testthat::expect_equal(parallel$selected, sequential$selected)
  testthat::expect_equal(parallel_three$selected, sequential$selected)
})
