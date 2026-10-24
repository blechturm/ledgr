# ledgr-test-file-profile: review

history_foundation_sessions <- function(timezone = "America/New_York",
                                        venue_id = "XNYS") {
  dates <- as.Date("2020-01-02") + 0:5
  ledgr_facts_sessions(
    data.frame(
      session_date = dates,
      status = "open",
      session_open = "09:30:00",
      session_close = "16:00:00",
      knowledge_time = as.POSIXct("2019-12-31", tz = "UTC"),
      stringsAsFactors = FALSE
    ),
    venue_id = venue_id,
    timezone = timezone
  )
}

history_foundation_snapshot <- function(history_policy = ledgr_history_policy()) {
  sessions <- history_foundation_sessions()
  membership <- ledgr_facts_membership_intervals(
    data.frame(
      instrument_id = "AAA",
      effective_from = as.POSIXct("2020-01-02 14:30:00", tz = "UTC"),
      knowledge_time = as.POSIXct("2020-01-02 14:30:00", tz = "UTC"),
      member = TRUE,
      source = "fixture",
      stringsAsFactors = FALSE
    ),
    universe_id = "research"
  )
  facts <- ledgr_facts(sessions, membership)
  pulses <- sessions$rows$session_close
  bars <- data.frame(
    instrument_id = "AAA",
    ts_utc = pulses,
    open = 100 + seq_along(pulses),
    high = 101 + seq_along(pulses),
    low = 99 + seq_along(pulses),
    close = 100 + seq_along(pulses),
    volume = 1000,
    stringsAsFactors = FALSE
  )
  snapshot <- ledgr_snapshot_from_df(
    bars,
    instruments_df = data.frame(instrument_id = "AAA"),
    facts = facts,
    price_basis = "split_adjusted"
  )
  strategy <- function(ctx, params) ctx$hold()
  experiment <- ledgr_experiment(
    snapshot,
    strategy,
    universe = ledgr_universe_members("research"),
    cost_model = ledgr_cost_zero(),
    history_policy = history_policy
  )
  list(snapshot = snapshot, experiment = experiment, sessions = sessions)
}

testthat::test_that("[LTB-0284] civil fact dates retain venue resolution evidence", {
  cases <- list(
    Sydney = c("Australia/Sydney", "XASX"),
    Honolulu = c("Pacific/Honolulu", "XHNL"),
    New_York = c("America/New_York", "XNYS")
  )
  for (case in cases) {
    sessions <- history_foundation_sessions(case[[1L]], case[[2L]])
    membership <- ledgr_facts_membership_intervals(
      data.frame(
        instrument_id = "AAA",
        effective_from = as.Date("2020-01-02"),
        effective_to = as.Date("2020-01-06"),
        knowledge_time = as.Date("2020-01-02"),
        member = TRUE,
        source = "fixture"
      ),
      universe_id = "research"
    )
    bundle <- ledgr_facts(sessions, membership)
    row <- ledgr:::ledgr_facts_family(bundle, "membership")[[1L]]$rows
    evidence <- ledgr:::ledgr_json_read_nested(row$civil_time_json[[1L]])
    testthat::expect_identical(evidence$effective_from$civil_date, "2020-01-02")
    testthat::expect_identical(evidence$effective_from$timezone, case[[1L]])
    testthat::expect_identical(evidence$effective_from$venue_id, case[[2L]])
    testthat::expect_identical(evidence$effective_from$calendar_id, case[[2L]])
    testthat::expect_identical(
      evidence$effective_from$resolved_ts_utc,
      ledgr:::ledgr_fact_time_token(sessions$rows$session_open[[1L]])
    )
    testthat::expect_identical(
      as.numeric(row$effective_from[[1L]]),
      as.numeric(sessions$rows$session_open[[1L]])
    )
    testthat::expect_identical(
      as.numeric(row$effective_to[[1L]]),
      as.numeric(sessions$rows$session_open[[5L]])
    )
    testthat::expect_identical(
      as.numeric(row$knowledge_time[[1L]]),
      as.numeric(sessions$rows$session_open[[1L]])
    )
    testthat::expect_identical(
      evidence$effective_to$resolved_ts_utc,
      ledgr:::ledgr_fact_time_token(sessions$rows$session_open[[5L]])
    )
    testthat::expect_identical(
      evidence$knowledge_time$resolved_ts_utc,
      ledgr:::ledgr_fact_time_token(sessions$rows$session_open[[1L]])
    )
    testthat::expect_false(format(row$effective_from[[1L]], "%H:%M:%S", tz = "UTC") == "00:00:00")
  }

  membership <- ledgr_facts_membership_intervals(
    data.frame(
      instrument_id = "AAA", effective_from = as.Date("2020-01-02"),
      knowledge_time = as.Date("2020-01-02"), member = TRUE,
      source = "fixture"
    ),
    universe_id = "research"
  )
  testthat::expect_error(
    ledgr_facts(membership),
    class = "ledgr_fact_civil_date_unresolved"
  )
  testthat::expect_error(
    ledgr_facts(
      history_foundation_sessions("America/New_York", "A"),
      history_foundation_sessions("America/New_York", "B"),
      membership
    ),
    class = "ledgr_fact_civil_date_unresolved"
  )

  fixture <- history_foundation_snapshot()
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  dated <- ledgr_experiment(
    fixture$snapshot,
    function(ctx, params) ctx$hold(),
    opening = ledgr_opening(cash = 1000, date = as.Date("2020-01-03")),
    universe = ledgr_universe_members("research"),
    cost_model = ledgr_cost_zero()
  )
  testthat::expect_identical(
    dated$opening$date,
    ledgr_iso_utc(fixture$sessions$rows$session_open[[2L]])
  )
  dated_run <- ledgr_run(dated, run_id = "civil-date-run")
  on.exit(close(dated_run), add = TRUE)
  testthat::expect_identical(
    dated_run$config$backtest$start_ts_utc,
    ledgr_iso_utc(fixture$sessions$rows$session_open[[2L]])
  )
  dated_sweep <- ledgr_sweep(dated, ledgr_grid_named(candidate_1 = list(strategy = list())))
  testthat::expect_identical(
    attr(dated_sweep, "scoring_range")$start,
    ledgr_iso_utc(fixture$sessions$rows$session_close[[2L]])
  )
  window <- ledgr_experiment_window(
    dated,
    as.Date("2020-01-03"),
    as.Date("2020-01-06")
  )
  testthat::expect_identical(
    as.numeric(window$scoring_start_utc),
    as.numeric(fixture$sessions$rows$session_open[[2L]])
  )
  testthat::expect_identical(
    as.numeric(window$scoring_end_utc),
    as.numeric(fixture$sessions$rows$session_close[[5L]])
  )
  fold <- ledgr_fold(
    train_start = as.Date("2020-01-02"),
    train_end = as.Date("2020-01-03"),
    test_start = as.Date("2020-01-04"),
    test_end = as.Date("2020-01-05")
  )
  fold_window <- ledgr:::ledgr_experiment_window_from_fold(
    dated,
    fold,
    "test",
    "flat_test_state"
  )
  testthat::expect_identical(
    as.numeric(fold_window$scoring_start_utc),
    as.numeric(fixture$sessions$rows$session_open[[3L]])
  )
  testthat::expect_identical(
    as.numeric(fold_window$scoring_end_utc),
    as.numeric(fixture$sessions$rows$session_close[[4L]])
  )
  precomputed <- ledgr_precompute_features(
    dated,
    ledgr_grid_named(candidate_1 = list(strategy = list())),
    start = as.Date("2020-01-03"),
    end = as.Date("2020-01-06")
  )
  testthat::expect_identical(
    precomputed$scoring_range$start,
    ledgr_iso_utc(fixture$sessions$rows$session_open[[2L]])
  )
  testthat::expect_identical(
    precomputed$scoring_range$end,
    ledgr_iso_utc(fixture$sessions$rows$session_close[[5L]])
  )

  folds <- ledgr:::ledgr_fold_list(
    list(
      ledgr_fold(
        as.Date("2020-01-02"), as.Date("2020-01-03"),
        as.Date("2020-01-04"), as.Date("2020-01-05"),
        fold_seq = 1L
      ),
      ledgr_fold(
        as.Date("2020-01-03"), as.Date("2020-01-04"),
        as.Date("2020-01-06"), as.Date("2020-01-07"),
        fold_seq = 2L
      )
    ),
    constructor = list(type_id = "explicit")
  )
  walk_forward_experiment <- ledgr_experiment(
    fixture$snapshot,
    function(ctx, params) ctx$hold(),
    opening = ledgr_opening(
      cash = 1000,
      positions = c(AAA = 1),
      cost_basis = c(AAA = 101)
    ),
    universe = ledgr_universe_members("research"),
    cost_model = ledgr_cost_zero()
  )
  walk_forward <- ledgr_walk_forward(
    walk_forward_experiment,
    grid = ledgr_grid_named(candidate_1 = list(strategy = list())),
    folds = folds,
    selection_rule = ledgr_rule_argmax("annualized_return"),
    seed = 47L
  )
  on.exit(invisible(lapply(walk_forward$test_runs, close)), add = TRUE)
  expected_test_start <- fixture$sessions$rows$session_open[c(3L, 5L)]
  expected_test_end <- fixture$sessions$rows$session_close[c(4L, 6L)]
  testthat::expect_identical(
    as.numeric(walk_forward$folds$test_start_utc),
    as.numeric(expected_test_start)
  )
  testthat::expect_identical(
    as.numeric(walk_forward$folds$test_end_utc),
    as.numeric(expected_test_end)
  )
  reopened <- ledgr_walk_forward_open(fixture$snapshot, walk_forward$session_id)
  testthat::expect_identical(
    as.numeric(reopened$folds$test_start_utc),
    as.numeric(expected_test_start)
  )
  candidate <- ledgr_candidate(reopened, fold_seq = 1L)
  testthat::expect_identical(
    as.numeric(candidate$sweep_meta$scoring_range$start),
    as.numeric(fixture$sessions$rows$session_close[[1L]])
  )
  testthat::expect_identical(
    as.numeric(candidate$sweep_meta$scoring_range$end),
    as.numeric(fixture$sessions$rows$session_close[[2L]])
  )

  testthat::expect_error(
    ledgr:::ledgr_snapshot_resolve_civil_boundary(
      fixture$snapshot,
      as.Date("2020-01-12"),
      "open"
    ),
    class = "ledgr_session_boundary_unresolved"
  )

  con <- ledgr:::get_connection(fixture$snapshot)
  DBI::dbExecute(
    con,
    paste(
      "INSERT INTO snapshot_sessions (snapshot_id, venue_id, session_date,",
      "effective_from, effective_to, knowledge_time, status, session_open,",
      "session_close, provenance_json)",
      "SELECT snapshot_id, 'XNAS', session_date, effective_from, effective_to,",
      "knowledge_time, status, session_open, session_close, provenance_json",
      "FROM snapshot_sessions WHERE snapshot_id = ?",
      "AND session_date = DATE '2020-01-02'"
    ),
    params = list(fixture$snapshot$snapshot_id)
  )
  testthat::expect_error(
    ledgr:::ledgr_snapshot_resolve_civil_boundary(
      fixture$snapshot,
      as.Date("2020-01-02"),
      "open"
    ),
    class = "ledgr_session_boundary_unresolved"
  )
})

testthat::test_that("[LTB-0288] effective and knowledge clocks remain distinct", {
  at <- function(day) as.POSIXct(as.Date("2020-01-01") + day - 1L, tz = "UTC")
  family <- ledgr_facts_trading_status(data.frame(
    instrument_id = "AAA",
    effective_from = at(2),
    effective_to = at(6),
    knowledge_time = at(4),
    status = "halted",
    source = "fixture",
    precedence = 1L,
    stringsAsFactors = FALSE
  ))
  row <- family$rows[1L, , drop = FALSE]
  testthat::expect_identical(row$effective_from[[1L]], at(2))
  testthat::expect_identical(row$knowledge_time[[1L]], at(4))
  data <- list(
    families = data.frame(family = "trading_status", scope_id = "instrument"),
    status = family$rows,
    lifetime = data.frame(), membership = data.frame(),
    membership_sets = data.frame(), sessions = NULL
  )
  provider <- ledgr:::ledgr_availability_provider_build_prepared(
    data,
    list(
      universe = list(instrument_ids = "AAA"),
      availability = list(universe_rule = NULL)
    ),
    "fixture"
  )
  testthat::expect_identical(unname(provider$facts(at(3), "AAA")$status), "unknown")
  testthat::expect_identical(unname(provider$facts(at(4), "AAA")$status), "halted")
  segments <- ledgr:::ledgr_availability_prepared_segments(
    family$rows,
    key = "AAA",
    n_planes = 1L,
    default_codes = 0L,
    resolve = function(index) 1L
  )
  testthat::expect_identical(segments$effective_start, as.numeric(at(2)))
  testthat::expect_identical(segments$knowledge_start, as.numeric(at(4)))
})

testthat::test_that("[LTB-0289] civil metadata encoding is field-wise", {
  sessions <- history_foundation_sessions()
  dates <- as.Date("2020-01-02") + rep(0:5, length.out = 120L)
  membership <- ledgr_facts_membership_intervals(
    data.frame(
      instrument_id = sprintf("I%03d", seq_along(dates)),
      effective_from = dates,
      knowledge_time = dates,
      member = TRUE,
      source = "fixture"
    ),
    universe_id = "research"
  )
  writes <- 0L
  tokens <- 0L
  writer <- ledgr:::ledgr_json_write_canonical_ndjson
  token <- ledgr:::ledgr_fact_time_token
  testthat::local_mocked_bindings(
    ledgr_json_write_canonical_ndjson = function(frame) {
      writes <<- writes + 1L
      writer(frame)
    },
    ledgr_fact_time_token = function(value) {
      tokens <<- tokens + 1L
      token(value)
    },
    .package = "ledgr"
  )
  bundle <- ledgr_facts(sessions, membership)
  testthat::expect_s3_class(bundle, "ledgr_facts")
  testthat::expect_gt(writes, 0L)
  testthat::expect_lte(writes, 6L)
  testthat::expect_lte(tokens, 12L)

  posix_membership <- ledgr_facts_membership_intervals(
    data.frame(
      instrument_id = sprintf("I%03d", seq_along(dates)),
      effective_from = as.POSIXct(dates, tz = "UTC"),
      knowledge_time = as.POSIXct(dates, tz = "UTC"),
      member = TRUE,
      source = "fixture"
    ),
    universe_id = "research"
  )
  writes <- 0L
  tokens <- 0L
  posix_bundle <- ledgr_facts(sessions, posix_membership)
  testthat::expect_s3_class(posix_bundle, "ledgr_facts")
  testthat::expect_identical(writes, 0L)
  testthat::expect_identical(tokens, 0L)
})

testthat::test_that("[LTB-0285] correction chains have one graph policy", {
  at <- function(day) as.POSIXct(as.Date("2020-01-01") + day - 1L, tz = "UTC")
  rows <- function(ids, from, to, known, status, supersedes, precedence = 1L) {
    data.frame(
      instrument_id = "AAA", effective_from = from, effective_to = to,
      knowledge_time = known, status = status, source = "fixture",
      precedence = precedence, fact_id = ids,
      supersedes_fact_id = supersedes, stringsAsFactors = FALSE
    )
  }
  monotone <- rows(
    c("a", "b", "c"), at(2), at(7), at(2:4),
    c("halted", "active", "quotation_only"), c(NA, "a", "b")
  )
  testthat::expect_s3_class(
    ledgr_facts_trading_status(monotone),
    "ledgr_facts_trading_status"
  )
  earlier <- rows(
    c("a", "b"), c(at(3), at(2)), at(7), at(2:3),
    c("halted", "active"), c(NA, "a"), c(5L, 1L)
  )
  family <- ledgr_facts_trading_status(earlier)
  data <- list(
    families = data.frame(family = "trading_status", scope_id = "instrument"),
    status = family$rows, lifetime = data.frame(), membership = data.frame(),
    membership_sets = data.frame(), sessions = NULL
  )
  provider <- ledgr:::ledgr_availability_provider_build_prepared(
    data,
    list(universe = list(instrument_ids = "AAA"), availability = list(universe_rule = NULL)),
    "fixture"
  )
  testthat::expect_identical(
    unname(provider$facts(at(4), "AAA")$status),
    "active"
  )

  nonmonotone <- monotone
  nonmonotone$knowledge_time <- at(c(2, 5, 3))
  testthat::expect_error(
    ledgr_facts_trading_status(nonmonotone),
    class = "ledgr_fact_invalid_supersession"
  )
  early_end <- rows(
    c("a", "b"), c(at(2), at(3)), c(at(7), at(5)), at(2:3),
    c("halted", "active"), c(NA, "a")
  )
  testthat::expect_error(
    ledgr_facts_trading_status(early_end),
    class = "ledgr_fact_invalid_supersession"
  )
  siblings <- rows(
    c("a", "b", "c"), at(2), at(7), at(2:4),
    c("halted", "active", "quotation_only"), c(NA, "a", "a")
  )
  testthat::expect_error(
    ledgr_facts_trading_status(siblings),
    class = "ledgr_fact_structural_conflict"
  )

  unrelated <- rows(
    c("a", "b", "c", "d"), at(2), at(7), at(2:5),
    c("halted", "active", "halted", "quotation_only"),
    c(NA, "a", NA, "c"), c(1L, 2L, 1L, 2L)
  )
  testthat::expect_error(
    ledgr_facts_trading_status(unrelated),
    class = "ledgr_fact_structural_conflict"
  )

  revival <- rows(
    c("a", "b", "c"), at(2), at(7), at(2:4),
    c("halted", "active", "halted"), c(NA, "a", "b")
  )
  revival_family <- ledgr_facts_trading_status(revival)
  revival_data <- data
  revival_data$status <- revival_family$rows
  revival_provider <- ledgr:::ledgr_availability_provider_build_prepared(
    revival_data,
    list(
      universe = list(instrument_ids = "AAA"),
      availability = list(universe_rule = NULL)
    ),
    "fixture"
  )
  testthat::expect_identical(
    unname(revival_provider$facts(at(4), "AAA")$status),
    "halted"
  )

  same_assertion <- rows(
    c("a", "b", "c"), at(2), at(7), at(2:4),
    rep("halted", 3L), c(NA, "a", "a")
  )
  testthat::expect_s3_class(
    ledgr_facts_trading_status(same_assertion),
    "ledgr_facts_trading_status"
  )

  cycle <- rows(
    c("a", "b"), at(2), at(7), at(2),
    c("halted", "active"), c("b", "a")
  )
  testthat::expect_error(
    ledgr_facts_trading_status(cycle),
    class = "ledgr_fact_invalid_supersession"
  )
  dangling <- rows(
    "a", at(2), at(7), at(2), "halted", "missing"
  )
  testthat::expect_error(
    ledgr_facts_trading_status(dangling),
    class = "ledgr_fact_invalid_supersession"
  )

  testthat::expect_setequal(
    ledgr:::ledgr_status_runtime_conflicts(siblings),
    c("b", "c")
  )
  conflict_data <- data
  conflict_data$status <- siblings
  conflict_provider <- ledgr:::ledgr_availability_provider_build_prepared(
    conflict_data,
    list(
      universe = list(instrument_ids = "AAA"),
      availability = list(universe_rule = NULL)
    ),
    "fixture"
  )
  testthat::expect_identical(
    unname(conflict_provider$facts(at(4), "AAA")$status),
    "conflicting"
  )
})

testthat::test_that("[LTB-0286] corporate-action clocks distinguish three cases", {
  base <- data.frame(
    subtype = "ordinary_cash_dividend", parent_instrument_id = "AAA",
    complete = TRUE, provenance_tier = "snapshot_bound",
    gross_cash_per_parent_unit = 1, gross_cash_validated = TRUE,
    source = "fixture", stringsAsFactors = FALSE
  )
  event <- base
  event$entitlement_time <- as.POSIXct("2020-01-03 16:00:00", tz = "UTC")
  event_family <- ledgr_facts_equity_corporate_actions(event)
  testthat::expect_identical(
    event_family$rows$knowledge_time,
    event_family$rows$entitlement_time
  )
  civil_event <- base
  civil_event$entitlement_time <- as.Date("2020-01-03")
  civil_bundle <- ledgr_facts(
    history_foundation_sessions(),
    ledgr_facts_equity_corporate_actions(civil_event)
  )
  civil_row <- ledgr:::ledgr_facts_family(
    civil_bundle,
    "equity_corporate_actions"
  )[[1L]]$rows
  civil_sessions <- ledgr:::ledgr_facts_family(
    civil_bundle,
    "sessions"
  )[[1L]]$rows
  session_index <- match(as.Date("2020-01-03"), civil_sessions$session_date)
  testthat::expect_identical(
    as.numeric(civil_row$knowledge_time),
    as.numeric(civil_sessions$session_open[[session_index]])
  )
  testthat::expect_identical(
    as.numeric(civil_row$entitlement_time),
    as.numeric(civil_sessions$session_close[[session_index]])
  )
  civil_evidence <- ledgr:::ledgr_json_read_nested(
    civil_row$civil_time_json[[1L]]
  )
  testthat::expect_false(identical(
    civil_evidence$knowledge_time$resolved_ts_utc,
    civil_evidence$entitlement_time$resolved_ts_utc
  ))
  rebundled <- do.call(ledgr_facts, civil_bundle$families)
  testthat::expect_identical(rebundled, civil_bundle)
  testthat::expect_identical(
    ledgr:::ledgr_facts_family(
      rebundled, "equity_corporate_actions"
    )[[1L]]$rows$civil_time_json,
    civil_row$civil_time_json
  )
  audit <- ledgr_facts_equity_corporate_actions(base)
  testthat::expect_true(is.na(audit$rows$knowledge_time[[1L]]))

  malformed <- base
  malformed$knowledge_time <- as.POSIXct("2020-01-03 16:00:00", tz = "UTC")
  malformed <- ledgr_facts_equity_corporate_actions(malformed)$rows
  pulses <- as.POSIXct(c("2020-01-02 16:00:00", "2020-01-03 16:00:00"), tz = "UTC")
  plan <- ledgr:::ledgr_corporate_action_plan(
    malformed,
    ledgr:::ledgr_corporate_action_policy_identity(ledgr_corporate_actions_research()),
    pulses,
    "AAA"
  )
  testthat::expect_no_error(plan$check_clocks(1L))
  error <- testthat::expect_error(
    plan$check_clocks(2L),
    class = "ledgr_corporate_action_clock_missing"
  )
  testthat::expect_s3_class(error, "ledgr_invalid_corporate_action_event")
  testthat::expect_identical(error$fact_id, malformed$fact_id[[1L]])
  testthat::expect_identical(error$parent_instrument_id, "AAA")
  testthat::expect_identical(error$knowledge_time, malformed$knowledge_time[[1L]])
  testthat::expect_true(is.na(error$entitlement_time))
  testthat::expect_true(is.na(error$effective_time))

  bars <- data.frame(
    instrument_id = "AAA",
    ts_utc = as.POSIXct("2020-01-01 16:00:00", tz = "UTC") + 86400 * 0:2,
    open = 100, high = 101, low = 99, close = 100, volume = 1000
  )
  clockless <- base
  clockless$knowledge_time <- bars$ts_utc[[2L]]
  snapshot <- ledgr_snapshot_from_df(
    bars,
    facts = ledgr_facts(ledgr_facts_equity_corporate_actions(clockless)),
    price_basis = "split_adjusted"
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  experiment <- ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$hold(),
    cost_model = ledgr_cost_zero()
  )
  testthat::expect_error(
    ledgr_run(experiment, run_id = "clockless-corporate-action"),
    class = "ledgr_corporate_action_clock_missing"
  )
  sweep <- ledgr_sweep(experiment, ledgr_grid_named(candidate_1 = list(strategy = list())))
  testthat::expect_identical(sweep$status, "FAILED")
  testthat::expect_identical(
    sweep$error_class,
    "ledgr_corporate_action_clock_missing"
  )

  dense_snapshot <- ledgr_snapshot_from_df(
    bars,
    facts = ledgr_facts(event_family),
    price_basis = "split_adjusted"
  )
  on.exit(ledgr_snapshot_close(dense_snapshot), add = TRUE)
  dense_experiment <- ledgr_experiment(
    dense_snapshot,
    function(ctx, params) ctx$hold(),
    opening = ledgr_opening(
      cash = 1000,
      positions = c(AAA = 2),
      cost_basis = c(AAA = 100)
    ),
    cost_model = ledgr_cost_zero()
  )
  dense_run <- ledgr_run(dense_experiment, run_id = "assumed-knowledge-dense")
  on.exit(close(dense_run), add = TRUE)
  dense_summary <- ledgr:::ledgr_corporate_action_summary(dense_run)
  testthat::expect_identical(dense_summary$gross_cash_posted, 2)
  testthat::expect_identical(dense_summary$choice_counts[["cash_amount.gross"]], 1L)
})

testthat::test_that("[LTB-0287] history policy is canonical identity input", {
  testthat::expect_error(
    ledgr:::ledgr_history_policy_identity(NULL),
    class = "ledgr_invalid_history_policy"
  )
  testthat::expect_null(ledgr_history_policy(price_carry = NULL)$price_carry)
  testthat::expect_null(ledgr_history_policy()$output_carry)
  testthat::expect_error(
    ledgr_history_policy(output_carry = 0),
    class = "ledgr_invalid_history_policy"
  )
  testthat::expect_error(
    ledgr_history_policy(segment_limit = 1e10),
    class = "ledgr_invalid_history_policy"
  )

  fixture <- history_foundation_snapshot()
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  default <- ledgr_run(fixture$experiment, run_id = "history-default")
  on.exit(close(default), add = TRUE)
  disabled_exp <- ledgr_experiment(
    fixture$snapshot,
    fixture$experiment$strategy,
    universe = ledgr_universe_members("research"),
    cost_model = ledgr_cost_zero(),
    history_policy = ledgr_history_policy(price_carry = NULL)
  )
  disabled <- ledgr_run(disabled_exp, run_id = "history-disabled")
  on.exit(close(disabled), add = TRUE)
  testthat::expect_identical(default$config$identity_rule_version, 4L)
  testthat::expect_false(identical(config_hash(default$config), config_hash(disabled$config)))
  repeated <- ledgr_run(fixture$experiment, run_id = "history-default-2")
  on.exit(close(repeated), add = TRUE)
  testthat::expect_identical(config_hash(default$config), config_hash(repeated$config))
  # Public omission uses the documented default; only an internal NULL refuses.
  omitted_exp <- ledgr_experiment(
    fixture$snapshot,
    fixture$experiment$strategy,
    universe = ledgr_universe_members("research"),
    cost_model = ledgr_cost_zero()
  )
  omitted <- ledgr_run(omitted_exp, run_id = "history-omitted")
  on.exit(close(omitted), add = TRUE)
  testthat::expect_identical(config_hash(default$config), config_hash(omitted$config))

  for (field in c(
    "axis_rule_version", "cutoff_rule_version", "treatment_rule_version"
  )) {
    changed <- default$config
    changed$history[[field]] <- changed$history[[field]] + 1L
    testthat::expect_false(
      identical(config_hash(default$config), config_hash(changed)),
      info = field
    )
    testthat::expect_error(
      ledgr:::validate_ledgr_config(changed),
      class = "ledgr_history_identity_mismatch",
      info = field
    )
  }

  assumed <- default$config
  declared <- default$config
  assumed$data$price_basis <- NULL
  declared$data$price_basis <- "split_adjusted"
  testthat::expect_false(identical(config_hash(assumed), config_hash(declared)))

  output <- ledgr_history_policy(output_carry = 2L)
  testthat::expect_identical(output$price_carry, 5L)
  testthat::expect_identical(output$output_carry, 2L)
  strict <- ledgr_history_policy(price_carry = NULL, output_carry = NULL)
  testthat::expect_false(identical(
    ledgr:::ledgr_history_policy_identity(strict),
    ledgr:::ledgr_history_policy_identity(output)
  ))
  testthat::expect_false("workers" %in% names(default$config))
  testthat::expect_false("resources" %in% names(default$config))
  for (policy in list(
    ledgr_history_policy(output_carry = 2L),
    ledgr_history_policy(segment_limit = 100L)
  )) {
    changed <- default$config
    changed$history <- ledgr:::ledgr_history_policy_identity(policy)
    testthat::expect_false(
      identical(config_hash(default$config), config_hash(changed))
    )
  }
})

testthat::test_that("[LTB-0290] precomputed features bind causal history identity", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:3)
  snapshot <- ledgr_snapshot_from_df(bars, price_basis = "split_adjusted")
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) ctx$flat()
  features <- list(ledgr_ind_sma(2L))
  default <- ledgr_experiment(
    snapshot,
    strategy,
    features = features,
    cost_model = ledgr_cost_zero()
  )
  strict <- ledgr_experiment(
    snapshot,
    strategy,
    features = features,
    cost_model = ledgr_cost_zero(),
    history_policy = ledgr_history_policy(price_carry = NULL)
  )
  output <- ledgr_experiment(
    snapshot,
    strategy,
    features = features,
    cost_model = ledgr_cost_zero(),
    history_policy = ledgr_history_policy(output_carry = 2L)
  )
  grid <- ledgr_grid_named(candidate_1 = list(strategy = list()))
  precomputed <- ledgr_precompute_features(default, grid)
  candidate_calls <- 0L
  testthat::local_mocked_bindings(
    ledgr_sweep_eval_candidate_task = function(...) {
      candidate_calls <<- candidate_calls + 1L
      rlang::abort(
        "A candidate ran before causal-history identity validation.",
        class = "ledgr_test_candidate_ran"
      )
    },
    .package = "ledgr"
  )
  testthat::expect_error(
    ledgr_sweep(strict, grid, precomputed_features = precomputed),
    class = "ledgr_precomputed_history_mismatch"
  )
  testthat::expect_identical(candidate_calls, 0L)
  testthat::expect_error(
    ledgr_sweep(output, grid, precomputed_features = precomputed),
    class = "ledgr_precomputed_history_mismatch"
  )
  testthat::expect_identical(candidate_calls, 0L)
  for (field in c("axis_rule_version", "cutoff_rule_version")) {
    altered <- precomputed
    altered$history_identity[[field]] <-
      altered$history_identity[[field]] + 1L
    testthat::expect_error(
      ledgr_sweep(default, grid, precomputed_features = altered),
      class = "ledgr_precomputed_history_mismatch",
      info = field
    )
  }
  missing <- precomputed
  missing$history_identity <- NULL
  testthat::expect_error(
    ledgr_sweep(default, grid, precomputed_features = missing),
    class = "ledgr_precomputed_history_mismatch"
  )
  testthat::expect_identical(candidate_calls, 0L)
})
