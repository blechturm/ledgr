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
  sparse <- testthat::with_mocked_bindings(
    ledgr:::ledgr_history_lifetime_segments(
      list(lifetime = sparse_rows), sparse_ids, axis, NULL
    ),
    ledgr_history_segments_build = function(...) {
      stop("sparse facts must not enter the global epoch compiler")
    },
    .package = "ledgr"
  )
  testthat::expect_identical(sparse$segment_count, rep(2L, 128L))
  testthat::expect_identical(sparse$fact_count, rep(1L, 128L))
  sparse_rows <- rbind(
    sparse_rows,
    transform(
      sparse_rows[1L, , drop = FALSE],
      effective_from = axis[[4L]],
      knowledge_time = axis[[5L]],
      assertion = "known_inactive",
      fact_id = "lifetime-I001-correction"
    )
  )
  compiled <- testthat::with_mocked_bindings(
    ledgr:::ledgr_history_lifetime_segments(
      list(lifetime = sparse_rows), sparse_ids, axis, NULL
    ),
    ledgr_history_segments_build = function(...) {
      stop("one corrected instrument must not enter the global epoch compiler")
    },
    .package = "ledgr"
  )
  testthat::expect_identical(compiled$fact_count[[1L]], 2L)
  testthat::expect_identical(compiled$fact_count[-1L], rep(1L, 127L))

  lagged_intervals <- ledgr_facts_membership_intervals(
    data.frame(
      instrument_id = c("AAA", "AAA", "BBB"),
      effective_from = axis[c(1L, 4L, 2L)],
      effective_to = as.POSIXct(c(axis[[4L]], NA, axis[[6L]]),
        origin = "1970-01-01", tz = "UTC"
      ),
      knowledge_time = axis[c(2L, 6L, 3L)],
      member = c(TRUE, FALSE, TRUE),
      source = "test",
      stringsAsFactors = FALSE
    ),
    universe_id = "U"
  )
  lagged_data <- list(
    membership_sets = data.frame(
      universe_id = character(), set_id = character(),
      effective_from = as.POSIXct(character(), tz = "UTC"),
      knowledge_time = as.POSIXct(character(), tz = "UTC"),
      complete = logical(), stringsAsFactors = FALSE
    ),
    membership = lagged_intervals$rows
  )
  lagged_segments <- testthat::with_mocked_bindings(
    ledgr:::ledgr_history_membership_segments(
      lagged_data, "U", c("AAA", "BBB"), axis, NULL
    ),
    ledgr_history_segments_build = function(...) {
      stop("interval-only membership must compile per instrument")
    },
    .package = "ledgr"
  )
  for (observation_idx in seq_along(axis)) {
    for (knowledge_idx in seq_along(axis)) {
      expected_answer <- ledgr:::ledgr_membership_resolve_prepared(
        lagged_data, "U", axis[[observation_idx]],
        instruments = c("AAA", "BBB"),
        knowledge_cutoff = axis[[knowledge_idx]]
      )$rows
      actual_answer <- ledgr:::ledgr_history_segments_query(
        lagged_segments, observation_idx, axis[[knowledge_idx]], 1:2
      )
      testthat::expect_identical(
        actual_answer$state,
        ledgr:::ledgr_history_membership_state(
          expected_answer$member, expected_answer$reason
        )
      )
      testthat::expect_identical(
        actual_answer$winner, as.character(expected_answer$evidence_ids)
      )
    }
  }

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

  scaling_n <- 40L
  scaling_axis <- as.POSIXct("2021-01-01", tz = "UTC") +
    seq_len(scaling_n) * 86400
  scaling_ids <- sprintf("S%02d", seq_len(10L))
  scaling_sets <- ledgr_facts_membership_snapshots(
    data.frame(
      effective_from = scaling_axis,
      knowledge_time = scaling_axis,
      set_id = sprintf("set-%02d", seq_len(scaling_n)),
      members = I(lapply(seq_len(scaling_n), function(i) {
        scaling_ids[seq_len(1L + i %% length(scaling_ids))]
      })),
      source = "test",
      stringsAsFactors = FALSE
    ),
    universe_id = "SCALE",
    complete = TRUE
  )
  scaling_plan <- ledgr:::ledgr_availability_prepared_membership_plan(
    list(
      membership_sets = scaling_sets$headers,
      membership = scaling_sets$rows
    ),
    "SCALE",
    scaling_ids
  )
  membership_calls <- new.env(parent = emptyenv())
  membership_calls$n <- 0L
  original_advance_header <- ledgr:::ledgr_membership_advance_prepared_header
  testthat::with_mocked_bindings(
    {
      scaling_resolver <-
        ledgr:::ledgr_availability_prepared_membership_from_plan(scaling_plan)
      invisible(lapply(scaling_axis, scaling_resolver))
    },
    ledgr_membership_advance_prepared_header = function(...) {
      membership_calls$n <- membership_calls$n + 1L
      original_advance_header(...)
    },
    .package = "ledgr"
  )
  # One forward pass applies each complete header exactly once.
  testthat::expect_identical(membership_calls$n, scaling_n)

  # Lagged knowledge can make an earlier-effective complete set eligible after
  # a later one; the complete-set boundary must not move backwards, and one
  # resolver must agree with the canonical resolver forward, backward and
  # forward again.
  lagged_complete <- ledgr_facts_membership_snapshots(
    data.frame(
      effective_from = scaling_axis[c(2L, 6L)],
      knowledge_time = scaling_axis[c(9L, 7L)],
      set_id = c("early-late-known", "late-early-known"),
      members = I(list(scaling_ids[1:3], scaling_ids[4:6])),
      source = "test",
      stringsAsFactors = FALSE
    ),
    universe_id = "SCALE",
    complete = TRUE
  )
  lagged_partial <- ledgr_facts_membership_snapshots(
    data.frame(
      effective_from = scaling_axis[[8L]],
      knowledge_time = scaling_axis[[10L]],
      set_id = "partial-addition",
      members = I(list(scaling_ids[7:8])),
      source = "test",
      stringsAsFactors = FALSE
    ),
    universe_id = "SCALE",
    complete = FALSE
  )
  lagged_mixed <- list(
    membership_sets = rbind(lagged_complete$headers, lagged_partial$headers),
    membership = rbind(lagged_complete$rows, lagged_partial$rows)
  )
  lagged_resolver <- attr(
    ledgr:::ledgr_availability_prepared_membership(
      lagged_mixed, "SCALE", scaling_ids
    ),
    "resolve",
    exact = TRUE
  )
  lagged_cutoffs <- scaling_axis[c(1:12, 12:1, 1:12)]
  for (cutoff in lagged_cutoffs) {
    expected_members <- ledgr:::ledgr_membership_resolve_prepared(
      lagged_mixed, "SCALE", cutoff,
      instruments = scaling_ids, knowledge_cutoff = cutoff
    )$rows
    actual_members <- lagged_resolver(as.numeric(cutoff))
    testthat::expect_identical(
      ifelse(actual_members$known, actual_members$member, NA),
      expected_members$member
    )
    testthat::expect_identical(
      actual_members$winner, expected_members$evidence_ids
    )
  }

  incomplete_sets <- ledgr_facts_membership_snapshots(
    data.frame(
      effective_from = scaling_axis,
      knowledge_time = scaling_axis,
      set_id = sprintf("partial-%02d", seq_len(scaling_n)),
      members = I(lapply(seq_len(scaling_n), function(i) {
        scaling_ids[[1L + i %% length(scaling_ids)]]
      })),
      source = "test",
      stringsAsFactors = FALSE
    ),
    universe_id = "SCALE",
    complete = FALSE
  )
  incomplete_data <- list(
    membership_sets = incomplete_sets$headers,
    membership = incomplete_sets$rows
  )
  advances <- 0L
  original_advance <- ledgr:::ledgr_membership_advance_prepared_header
  testthat::with_mocked_bindings(
    {
      incomplete_resolver <- ledgr:::ledgr_availability_prepared_membership(
        incomplete_data, "SCALE", scaling_ids
      )
      for (cutoff in scaling_axis) {
        expected_members <- ledgr:::ledgr_membership_resolve_prepared(
          incomplete_data,
          "SCALE",
          cutoff,
          instruments = scaling_ids,
          knowledge_cutoff = cutoff
        )$rows
        actual_members <- attr(incomplete_resolver, "resolve", exact = TRUE)(
          as.numeric(cutoff)
        )
        testthat::expect_identical(
          ifelse(actual_members$known, actual_members$member, NA),
          expected_members$member
        )
        testthat::expect_identical(
          actual_members$winner,
          expected_members$evidence_ids
        )
      }
    },
    ledgr_membership_advance_prepared_header = function(...) {
      advances <<- advances + 1L
      original_advance(...)
    },
    .package = "ledgr"
  )
  testthat::expect_identical(advances, scaling_n)

  path_dates <- as.Date("2022-01-03") + 0:3
  path_sessions <- ledgr_facts_sessions(
    data.frame(
      session_date = path_dates,
      status = "open",
      session_open = "09:30:00",
      session_close = "16:00:00",
      knowledge_time = as.POSIXct(path_dates, tz = "UTC") - 1,
      stringsAsFactors = FALSE
    ),
    venue_id = "XNYS"
  )
  path_axis <- path_sessions$rows$session_close
  path_lifetime <- ledgr_facts_lifetime(data.frame(
    instrument_id = c("AAA", "AAA", "BBB"),
    effective_from = path_axis[c(1L, 4L, 1L)],
    effective_to = as.POSIXct(c(path_axis[[4L]], NA, NA),
      origin = "1970-01-01", tz = "UTC"
    ),
    knowledge_time = path_axis[c(1L, 4L, 1L)],
    assertion = c("known_active", "known_inactive", "known_active"),
    terminal_event = NA_character_,
    source = "test",
    stringsAsFactors = FALSE
  ))
  path_rows <- rbind(
    data.frame(instrument_id = "AAA", ts_utc = path_axis[c(1L, 3L)]),
    data.frame(instrument_id = "BBB", ts_utc = path_axis)
  )
  path_rows$open <- path_rows$high <- path_rows$low <- path_rows$close <-
    seq_len(nrow(path_rows)) + 100
  path_rows$volume <- 1000
  path_snapshot <- ledgr_snapshot_from_df(
    path_rows,
    instruments_df = data.frame(instrument_id = c("AAA", "BBB")),
    facts = ledgr_facts(path_sessions, path_lifetime),
    price_basis = "split_adjusted"
  )
  withr::defer(ledgr_snapshot_close(path_snapshot))
  path_experiment <- ledgr_experiment(
    path_snapshot,
    function(ctx, params) ctx$hold(),
    universe = c("AAA", "BBB"),
    cost_model = ledgr_cost_zero()
  )
  path_substrate <- testthat::with_mocked_bindings(
    ledgr:::ledgr_history_substrate_for_experiment(path_experiment),
    ledgr_precompute_fetch_bars = function(...) {
      stop("history construction must keep the bar query unsplit")
    },
    .package = "ledgr"
  )
  testthat::expect_identical(
    unname(path_substrate$bars$observed[1L, ]),
    c(TRUE, FALSE, TRUE, FALSE)
  )
  testthat::expect_identical(
    unname(path_substrate$expected[1L, ]),
    c(TRUE, TRUE, TRUE, FALSE)
  )
  testthat::expect_identical(
    unname(path_substrate$missing_expected_bar[1L, ]),
    c(FALSE, TRUE, FALSE, FALSE)
  )
  testthat::expect_false(any(path_substrate$inactive_print[1L, ]))
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
  boundary <- ledgr:::ledgr_history_input_carry_matrix(
    matrix(c(1, rep(NA_real_, 6L)), nrow = 1L),
    matrix(TRUE, nrow = 1L, ncol = 7L),
    axis,
    max_sessions = 5L
  )
  testthat::expect_equal(boundary$value[1L, ], c(rep(1, 6L), NA))
  testthat::expect_identical(
    boundary$missing_reason[1L, 7L], "carry_expired"
  )
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
  testthat::expect_identical(
    as.numeric(no_refresh$source_ts_utc[2:3]),
    rep(as.numeric(axis[[1L]]), 2L)
  )

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
  terminal_matrix <- ledgr:::ledgr_history_input_carry_matrix(
    matrix(c(1, NA, NA, 4), nrow = 1L),
    matrix(TRUE, nrow = 1L, ncol = 4L),
    axis[1:4],
    max_sessions = 5L,
    terminal_barrier = matrix(
      c(FALSE, TRUE, FALSE, FALSE), nrow = 1L
    )
  )
  testthat::expect_equal(terminal_matrix$value[1L, ], c(1, NA, NA, 4))
  testthat::expect_identical(
    terminal_matrix$barrier_reason[1L, 2L], "terminal"
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
  terminal_before_knowledge <- ledgr:::ledgr_history_substrate_terminal_at(
    fixture$substrate, fixture$axis[[4L]], observation_idx = 1:4
  )
  terminal_after_knowledge <- ledgr:::ledgr_history_substrate_terminal_at(
    fixture$substrate, fixture$axis[[5L]], observation_idx = 1:4
  )
  testthat::expect_false(terminal_before_knowledge[1L, 4L])
  testthat::expect_true(terminal_after_knowledge[1L, 4L])
  terminal_after_relisting <- ledgr:::ledgr_history_substrate_terminal_at(
    fixture$substrate, fixture$axis[[7L]], observation_idx = 7L
  )
  # The terminal state follows the shared lifetime resolver after relisting,
  # while the carry barrier it implies stays sticky (v12 Section 5).
  testthat::expect_true(terminal_after_relisting[1L, 1L])
  testthat::expect_identical(
    unname(ledgr:::ledgr_history_substrate_query_facts(
      fixture$substrate, "lifetime_terminal",
      fixture$axis[[7L]], fixture$axis[[7L]], "AAA"
    )$state),
    ""
  )

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
  expired_output <- ledgr:::ledgr_history_output_carry(
    value = c(1, NA, NA),
    eligible_gap = c(FALSE, TRUE, TRUE),
    expected = rep(TRUE, 3L),
    axis = axis[1:3],
    max_sessions = 1L
  )
  testthat::expect_equal(expired_output$value, c(1, 1, NA))
  testthat::expect_identical(
    expired_output$missing_reason,
    c("", "output_carried", "output_carry_expired")
  )
  testthat::expect_true(is.na(expired_output$source_ts_utc[[3L]]))
  testthat::expect_true(is.na(expired_output$carry_age_sessions[[3L]]))
  ineligible_output <- ledgr:::ledgr_history_output_carry(
    value = c(1, NA, NA),
    eligible_gap = c(FALSE, TRUE, FALSE),
    expected = rep(TRUE, 3L),
    axis = axis[1:3],
    max_sessions = 2L
  )
  testthat::expect_true(is.na(ineligible_output$source_ts_utc[[3L]]))
  testthat::expect_true(is.na(ineligible_output$carry_age_sessions[[3L]]))

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

  window_treatment <- ledgr:::ledgr_history_substrate_treated_field(
    fixture$substrate,
    "close",
    cutoff = fixture$axis[[4L]],
    observation_idx = 2:4
  )
  testthat::expect_true(window_treatment$input_carried[1L, 1L])
  testthat::expect_identical(
    as.numeric(window_treatment$source_ts_utc[1L, 1L]),
    as.numeric(fixture$axis[[1L]])
  )
  cutoff_treatment <- ledgr:::ledgr_history_substrate_treated_field(
    fixture$substrate,
    "close",
    cutoff = fixture$axis[[3L]]
  )
  testthat::expect_identical(ncol(cutoff_treatment$value), 3L)
  volume_treatment <- ledgr:::ledgr_history_substrate_treated_field(
    fixture$substrate,
    "volume",
    cutoff = fixture$axis[[3L]],
    carry_allowed = TRUE
  )
  testthat::expect_false(any(volume_treatment$input_carried))
  testthat::expect_true(is.na(volume_treatment$value[1L, 2L]))

  nondefault <- fixture
  nondefault$config$history_policy <- ledgr_history_policy(price_carry = 1L)
  nondefault$substrate <- ledgr:::ledgr_history_substrate(
    bars = fixture$bars,
    instrument_ids = c("AAA", "BBB"),
    axis = fixture$axis,
    availability_data = fixture$data,
    availability_config = nondefault$config,
    snapshot_hash = "nondefault"
  )
  nondefault_treatment <- ledgr:::ledgr_history_substrate_treated_field(
    nondefault$substrate,
    "close",
    cutoff = fixture$axis[[3L]]
  )
  testthat::expect_true(nondefault_treatment$input_carried[1L, 2L])
  testthat::expect_false(nondefault_treatment$input_carried[1L, 3L])

  bbb <- match("BBB", fixture$substrate$instrument_ids)
  bounded_feature <- ledgr:::ledgr_history_compute_feature_series(
    fixture$substrate,
    list(ledgr_ind_returns(2L)),
    calculation_start = fixture$axis[[2L]],
    calculation_end = fixture$axis[[4L]]
  )[[1L]][bbb, ]
  testthat::expect_true(all(is.na(bounded_feature[c(1L, 5:7)])))
  testthat::expect_true(any(is.finite(bounded_feature[2:4])))
  # Runs and sweeps pass ISO strings; the bound must keep its time of day.
  iso_bounded_feature <- ledgr:::ledgr_history_compute_feature_series(
    fixture$substrate,
    list(ledgr_ind_returns(2L)),
    calculation_start = ledgr_iso_utc(fixture$axis[[2L]]),
    calculation_end = ledgr_iso_utc(fixture$axis[[4L]])
  )[[1L]][bbb, ]
  testthat::expect_identical(iso_bounded_feature, bounded_feature)

  admission_reasons <- ledgr:::ledgr_history_estimator_admission(list(
    calculation_valid = rbind(c(FALSE, TRUE), c(FALSE, TRUE)),
    input_carried = matrix(FALSE, nrow = 2L, ncol = 2L),
    missing_reason = rbind(c("raw_missing", ""), c("carry_expired", "")),
    barrier_reason = rbind(c("terminal", ""), c("", ""))
  ))
  testthat::expect_identical(
    admission_reasons$exclusion_reason,
    c("structural_exclusion", "carry_expired")
  )

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
  original_candidate_eval <- ledgr:::ledgr_sweep_eval_candidate_task
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
  identity_mutations <- list(
    policy = function(x) {
      x$history_substrate$policy_identity <- "different-policy"
      x
    },
    source_start = function(x) {
      x$history_substrate$source_start_utc <-
        x$history_substrate$source_start_utc + 1
      x
    },
    data_start = function(x) {
      x$history_substrate$data_start_utc <-
        x$history_substrate$data_start_utc + 1
      x
    },
    instruments = function(x) {
      x$history_substrate$instrument_ids <-
        rev(x$history_substrate$instrument_ids)
      x
    },
    axis = function(x) {
      x$history_substrate$axis[[1L]] <- x$history_substrate$axis[[1L]] + 1
      x
    },
    feature_engine = function(x) {
      x$history_substrate$feature_projection$feature_engine_version <-
        "different-engine"
      x
    },
    feature_ids = function(x) {
      x$history_substrate$feature_projection$feature_values$extra <-
        matrix(NA_real_, nrow = 2L, ncol = length(x$history_substrate$axis))
      x
    }
  )
  for (name in names(identity_mutations)) {
    testthat::expect_error(
      ledgr:::ledgr_history_worker_stage(
        identity_mutations[[name]](invariant), identity
      ),
      class = "ledgr_staged_history_mismatch",
      info = name
    )
  }
  other_owner <- invariant
  other_owner$staged_owner_id <- "other-owner"
  testthat::expect_error(
    ledgr:::ledgr_history_worker_stage(other_owner, identity),
    class = "ledgr_staged_history_mismatch"
  )
  invalid_version <- invariant
  invalid_version$history_substrate$substrate_version <-
    invalid_version$history_substrate$substrate_version + 1L
  testthat::expect_error(
    ledgr:::ledgr_history_worker_stage(invalid_version, identity),
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

  snapshot <- availability_runtime_fixture(days = 4L)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  experiment <- ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$flat(),
    cost_model = ledgr_cost_zero()
  )
  grid <- ledgr_param_grid(one = list(n = 1L))
  stops <- new.env(parent = emptyenv())
  stops$n <- 0L
  dispatch_without_daemon <- function(tasks, workers) {
    lapply(
      tasks,
      original_candidate_eval,
      stop_on_error = FALSE
    )
  }
  stage_without_daemon <- function(tasks, owner_id) {
    list(
      tasks = tasks,
      invariant = NULL,
      identity = NULL,
      bytes = 0,
      census = ledgr:::ledgr_sweep_history_payload_census(tasks)
    )
  }
  stop_daemon <- function() {
    stops$n <- stops$n + 1L
    invisible(NULL)
  }
  testthat::with_mocked_bindings(
    testthat::expect_s3_class(
      ledgr_sweep(experiment, grid, seed = 1L, workers = 2L),
      "ledgr_sweep_results"
    ),
    ledgr_parallel_worker_setup = function(...) list(initialized = TRUE),
    ledgr_sweep_stage_history_tasks = stage_without_daemon,
    ledgr_parallel_mirai_stage_history = function(...) invisible(TRUE),
    ledgr_sweep_eval_candidate_tasks_parallel = dispatch_without_daemon,
    ledgr_parallel_mirai_stop = stop_daemon,
    .package = "ledgr"
  )
  testthat::expect_identical(stops$n, 1L)
  testthat::with_mocked_bindings(
    testthat::expect_error(
      ledgr_sweep(experiment, grid, seed = 1L, workers = 2L),
      class = "ledgr_parallel_worker_failed"
    ),
    ledgr_parallel_worker_setup = function(...) list(initialized = TRUE),
    ledgr_sweep_stage_history_tasks = stage_without_daemon,
    ledgr_parallel_mirai_stage_history = function(...) invisible(TRUE),
    ledgr_sweep_eval_candidate_tasks_parallel = function(...) {
      rlang::abort(
        "simulated worker failure",
        class = c("ledgr_parallel_worker_failed", "ledgr_parallel_error")
      )
    },
    ledgr_parallel_mirai_stop = stop_daemon,
    .package = "ledgr"
  )
  testthat::expect_identical(stops$n, 2L)
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
  strict_experiment <- ledgr_experiment(
    snapshot,
    strategy,
    cost_model = ledgr_cost_zero(),
    history_policy = ledgr_history_policy(price_carry = NULL)
  )
  strict_substrate <- ledgr:::ledgr_history_substrate_for_experiment(
    strict_experiment
  )
  strict_run <- ledgr:::ledgr_run_experiment(
    strict_experiment,
    params = list(qty = 1),
    run_id = "ws41-strict-policy-match",
    seed = 7L,
    history_substrate = strict_substrate
  )
  withr::defer(close(strict_run))
  testthat::expect_identical(strict_substrate$history_policy$price_carry, NULL)
  default_substrate <- ledgr:::ledgr_history_substrate_for_experiment(
    experiment
  )
  testthat::expect_error(
    ledgr:::ledgr_run_experiment(
      strict_experiment,
      params = list(qty = 1),
      run_id = "ws41-strict-policy-mismatch",
      seed = 7L,
      history_substrate = default_substrate
    ),
    class = "ledgr_invalid_history_substrate"
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
  compact_fields <- new.env(parent = emptyenv())
  compact_fields$sets <- list()
  original_prepare <- ledgr:::ledgr_availability_provider_prepare
  original_stage_tasks <- ledgr:::ledgr_sweep_stage_history_tasks
  testthat::local_mocked_bindings(
    ledgr_sweep_stage_history_tasks = function(tasks, owner_id) {
      staged <- original_stage_tasks(tasks, owner_id)
      compact_fields$sets[[length(compact_fields$sets) + 1L]] <-
        names(staged$tasks[[1L]])
      staged
    },
    .package = "ledgr"
  )
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
  expected_compact_fields <- c(
    "index", "run_id", "candidate_id", "candidate_row", "raw_params",
    "params", "feature_params", "execution_seed", "candidate",
    "candidate_feature_row", "staged_invariant_identity"
  )
  testthat::expect_true(length(compact_fields$sets) >= 2L)
  for (fields in compact_fields$sets) {
    testthat::expect_identical(fields, expected_compact_fields)
  }
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
  dated_experiment <- ledgr_experiment(
    snapshot,
    strategy,
    features = list(ledgr_ind_returns(2L)),
    opening = ledgr_opening(
      cash = 100000,
      date = "2020-01-05T16:00:00Z"
    ),
    cost_model = ledgr_cost_zero()
  )
  dated_run <- ledgr_run(dated_experiment, list(qty = 1), seed = 7L)
  withr::defer(close(dated_run))
  dated_fills <- ledgr_results(dated_run, "fills")
  testthat::expect_identical(nrow(dated_fills), 1L)
  testthat::expect_identical(
    as.numeric(dated_fills$ts_utc),
    as.numeric(as.POSIXct("2020-01-08 09:30:00", tz = "UTC"))
  )
  dated_equity <- ledgr_results(dated_run, "equity")
  testthat::expect_equal(
    dated_equity$equity[[nrow(dated_equity)]],
    100005
  )
  dated_sweep <- ledgr_sweep(
    dated_experiment,
    ledgr_param_grid(one = list(qty = 1)),
    seed = 7L,
    workers = 1L
  )
  testthat::expect_equal(dated_sweep$final_equity, 100005)
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
  stages <- new.env(parent = emptyenv())
  stages$n <- 0L
  feature_bounds <- new.env(parent = emptyenv())
  feature_bounds$end <- numeric()
  original_prepare <- ledgr:::ledgr_history_substrate_for_experiment
  original_stage_tasks <- ledgr:::ledgr_sweep_stage_history_tasks
  original_compute <- ledgr:::ledgr_history_compute_feature_series
  testthat::local_mocked_bindings(
    ledgr_history_substrate_for_experiment = function(...) {
      builds$n <- builds$n + 1L
      original_prepare(...)
    },
    ledgr_sweep_stage_history_tasks = function(...) {
      stages$n <- stages$n + 1L
      original_stage_tasks(...)
    },
    ledgr_history_compute_feature_series = function(...,
                                                     calculation_end = NULL) {
      feature_bounds$end <- c(
        feature_bounds$end,
        if (is.null(calculation_end)) {
          NA_real_
        } else {
          as.numeric(ledgr:::ledgr_history_utc(calculation_end))
        }
      )
      original_compute(..., calculation_end = calculation_end)
    },
    .package = "ledgr"
  )
  sequential <- ledgr_walk_forward(
    experiment, grid, folds, ledgr_rule_argmax("sharpe_ratio"),
    seed = 7L, workers = 1L
  )
  testthat::expect_false(anyNA(feature_bounds$end))
  # Every training sweep and test run calculates features only to its own
  # window end; none reaches the shared substrate's later end.
  window_ends <- as.numeric(unlist(lapply(folds, function(fold) {
    c(fold$train_end_utc, fold$test_end_utc)
  })))
  testthat::expect_true(all(feature_bounds$end %in% window_ends))
  # Fold 1 selects no candidate and so runs no test window; every training
  # sweep must still calculate to exactly its own training end.
  train_ends <- as.numeric(unlist(lapply(folds, `[[`, "train_end_utc")))
  testthat::expect_true(all(train_ends %in% feature_bounds$end))
  testthat::expect_identical(.Random.seed, caller_rng)
  sequential_test_has_fills <- vapply(
    sequential$test_runs,
    function(run) nrow(ledgr_results(run, "fills")) > 0L,
    logical(1)
  )
  sequential_fill_times <- lapply(
    sequential$test_runs,
    function(run) ledgr_results(run, "fills")$ts_utc
  )
  train_final_equity <- sequential$scores[
    sequential$scores$fold_seq == 2L &
      sequential$scores$window == "train" &
      sequential$scores$candidate_label == "one" &
      sequential$scores$metric_name == "final_equity",
    "metric_value",
    drop = TRUE
  ]
  testthat::expect_equal(train_final_equity, 100002)
  testthat::expect_identical(
    as.numeric(sequential_fill_times[[1L]]),
    as.numeric(as.POSIXct("2020-01-12 09:30:00", tz = "UTC"))
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
  testthat::expect_identical(stages$n, 4L)
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
