pit_constructor_args <- function(inputs, family) {
  args <- inputs$recipe$constructors[[family]]
  args[names(args) != "enabled"]
}

pit_families <- function(inputs) {
  out <- list(
    do.call(
      ledgr_facts_sessions,
      c(list(df = inputs$sessions), pit_constructor_args(inputs, "sessions"))
    ),
    do.call(
      ledgr_facts_membership_snapshots,
      c(
        list(df = inputs$membership),
        pit_constructor_args(inputs, "membership")
      )
    ),
    do.call(
      ledgr_facts_lifetime,
      c(list(df = inputs$lifetime), pit_constructor_args(inputs, "lifetime"))
    ),
    do.call(
      ledgr_facts_trading_status,
      c(
        list(df = inputs$trading_status),
        pit_constructor_args(inputs, "trading_status")
      )
    )
  )
  if (isTRUE(inputs$recipe$constructors$corporate_actions$enabled)) {
    out[[length(out) + 1L]] <- ledgr_facts_equity_corporate_actions(
      inputs$corporate_actions
    )
  }
  out
}

testthat::test_that("[LTB-0076] PIT inputs are calendar-first and case-locatable", {
  args <- list(
    instrument_ids = paste0("PIT", 1:4),
    from = "2020-01-01",
    to = "2020-01-31",
    seed = 17L,
    venue_id = "PIT_VENUE",
    universe_id = "PIT_UNIVERSE",
    timezone = "UTC",
    session_open = "09:30:00",
    session_close = "16:00:00"
  )
  inputs <- do.call(ledgr_sim_pit_inputs, args)
  repeated <- do.call(ledgr_sim_pit_inputs, args)
  changed_seed <- do.call(
    ledgr_sim_pit_inputs,
    utils::modifyList(args, list(seed = 18L))
  )

  testthat::expect_identical(inputs, repeated)
  testthat::expect_identical(class(inputs), "list")
  testthat::expect_identical(names(attributes(inputs)), "names")
  testthat::expect_identical(
    names(inputs),
    c(
      "bars", "instruments", "sessions", "membership", "lifetime",
      "trading_status", "corporate_actions", "recipe", "cases"
    )
  )
  frames <- c(
    "bars", "instruments", "sessions", "membership", "lifetime",
    "trading_status", "corporate_actions", "cases"
  )
  testthat::expect_true(all(vapply(inputs[frames], is.data.frame, logical(1))))
  testthat::expect_identical(names(inputs$bars), names(changed_seed$bars))
  testthat::expect_identical(
    inputs$bars[c("ts_utc", "instrument_id")],
    changed_seed$bars[c("ts_utc", "instrument_id")]
  )
  testthat::expect_false(identical(inputs$bars$close, changed_seed$bars$close))
  testthat::expect_identical(
    inputs[names(inputs) != "bars"],
    changed_seed[names(changed_seed) != "bars"]
  )

  families <- pit_families(inputs)
  facts <- do.call(ledgr_facts, families)
  testthat::expect_s3_class(facts, "ledgr_facts")
  testthat::expect_identical(length(facts$families), 5L)

  closure_row <- inputs$cases$type == "venue_closure"
  missing_row <- inputs$cases$type == "missing_observation"
  closure_date <- inputs$cases$date[closure_row][[1L]]
  missing_date <- inputs$cases$date[missing_row][[1L]]
  missing_id <- inputs$cases$instrument_id[missing_row][[1L]]
  bar_dates <- as.Date(inputs$bars$ts_utc, tz = "UTC")
  testthat::expect_false(closure_date %in% bar_dates)
  testthat::expect_identical(
    inputs$sessions$status[inputs$sessions$session_date == closure_date],
    "closed"
  )
  testthat::expect_identical(
    inputs$sessions$status[inputs$sessions$session_date == missing_date],
    "open"
  )
  testthat::expect_false(any(
    inputs$bars$instrument_id == missing_id & bar_dates == missing_date
  ))
  testthat::expect_true(all(
    setdiff(args$instrument_ids, missing_id) %in%
      inputs$bars$instrument_id[bar_dates == missing_date]
  ))

  normalized_sessions <- families[[1L]]$rows
  expected_close <- normalized_sessions$session_close[
    match(bar_dates, normalized_sessions$session_date)
  ]
  testthat::expect_identical(inputs$bars$ts_utc, expected_close)
  testthat::expect_true(any(
    inputs$trading_status$knowledge_time >
      inputs$trading_status$effective_from,
    na.rm = TRUE
  ))

  delisting <- inputs$lifetime[
    inputs$lifetime$instrument_id == args$instrument_ids[[1L]] &
      inputs$lifetime$assertion == "known_inactive", , drop = FALSE
  ]
  delisting_at <- delisting$effective_from[[1L]]
  delisted_bars <- inputs$bars$ts_utc[
    inputs$bars$instrument_id == args$instrument_ids[[1L]]
  ]
  testthat::expect_true(delisting_at %in% delisted_bars)
  testthat::expect_false(any(delisted_bars > delisting_at))
  delisted_status <- inputs$trading_status[
    inputs$trading_status$instrument_id == args$instrument_ids[[1L]],
    , drop = FALSE
  ]
  testthat::expect_identical(delisted_status$effective_to, delisting_at)

  halted <- inputs$trading_status[
    inputs$trading_status$status == "halted", , drop = FALSE
  ]
  halt_id <- halted$instrument_id[[1L]]
  halt_bars <- inputs$bars$ts_utc[inputs$bars$instrument_id == halt_id]
  testthat::expect_gt(halted$knowledge_time[[1L]], halted$effective_from[[1L]])
  testthat::expect_identical(halted$precedence[[1L]], 1L)
  testthat::expect_true(halted$effective_from[[1L]] %in% halt_bars)
  testthat::expect_false(any(
    halt_bars > halted$effective_from[[1L]] &
      halt_bars < halted$effective_to[[1L]]
  ))
  testthat::expect_true(halted$effective_to[[1L]] %in% halt_bars)

  all_cases <- inputs$cases$type
  for (disabled_case in all_cases) {
    disabled <- do.call(
      ledgr_sim_pit_inputs,
      c(args, list(cases = setdiff(all_cases, disabled_case)))
    )
    testthat::expect_false(disabled_case %in% disabled$cases$type)
    testthat::expect_s3_class(
      do.call(ledgr_facts, pit_families(disabled)),
      "ledgr_facts"
    )
  }
  no_cases <- do.call(
    ledgr_sim_pit_inputs,
    c(args, list(cases = character()))
  )
  testthat::expect_identical(nrow(no_cases$cases), 0L)
  testthat::expect_identical(nrow(no_cases$corporate_actions), 0L)
  testthat::expect_false(no_cases$recipe$constructors$corporate_actions$enabled)
  testthat::expect_s3_class(
    do.call(ledgr_facts, pit_families(no_cases)),
    "ledgr_facts"
  )
})

testthat::test_that("ledgr_sim_pit_inputs rejects invalid and insufficient shapes", {
  testthat::expect_error(
    ledgr_sim_pit_inputs("ONE", "2020-01-01", "2020-01-31"),
    class = "ledgr_sim_pit_insufficient_shape"
  )
  testthat::expect_error(
    ledgr_sim_pit_inputs(paste0("X", 1:4), "2020-01-01", "2020-01-07"),
    class = "ledgr_sim_pit_insufficient_shape"
  )
  testthat::expect_error(
    ledgr_sim_pit_inputs(
      paste0("X", 1:4), "2020-01-01", "2020-01-31",
      cases = "invented"
    ),
    class = "ledgr_sim_pit_invalid"
  )
  testthat::expect_error(
    ledgr_sim_pit_inputs(
      paste0("X", 1:4), "2020-01-01", "2020-01-31",
      knowledge = c(sessions = "evidenced")
    ),
    class = "ledgr_sim_pit_invalid"
  )
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0077] PIT inputs seal, reopen, and run publicly", {
  inputs <- ledgr_sim_pit_inputs(
    instrument_ids = paste0("FLOW", 1:4),
    from = "2020-01-01",
    to = "2020-01-31",
    seed = 23L,
    venue_id = "FLOW_VENUE",
    universe_id = "FLOW_UNIVERSE"
  )
  families <- pit_families(inputs)
  facts <- do.call(ledgr_facts, families)
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)
  snapshot <- ledgr_snapshot_from_df(
    inputs$bars,
    instruments_df = inputs$instruments,
    facts = facts,
    db_path = db_path,
    price_basis = inputs$recipe$price_basis
  )
  snapshot_id <- snapshot$snapshot_id
  testthat::expect_true(ledgr_experiment_plan(ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$flat(),
    universe = ledgr_universe_members(inputs$recipe$scopes$universe_id),
    valuation_policy = ledgr_valuation_stale(2),
    cost_model = ledgr_cost_zero()
  ))$availability_active)
  ledgr_snapshot_close(snapshot)

  reopened <- ledgr_snapshot_open(db_path, snapshot_id, verify = TRUE)
  on.exit(ledgr_snapshot_close(reopened), add = TRUE)
  experiment <- ledgr_experiment(
    reopened,
    function(ctx, params) ctx$flat(),
    universe = ledgr_universe_members(inputs$recipe$scopes$universe_id),
    valuation_policy = ledgr_valuation_stale(2),
    cost_model = ledgr_cost_zero()
  )
  run <- ledgr_run(experiment, run_id = "pit-input-workflow")
  on.exit(close(run), add = TRUE)
  completion <- ledgr_run_completion(run)
  testthat::expect_identical(completion$completion_status, "DONE")
  testthat::expect_true(completion$complete_performance)

  session_rows <- families[[1L]]$rows
  halted <- inputs$trading_status[
    inputs$trading_status$status == "halted", , drop = FALSE
  ]
  before_known <- ledgr_run_explain(
    run, halted$instrument_id[[1L]], halted$effective_from[[1L]]
  )
  when_known <- ledgr_run_explain(
    run, halted$instrument_id[[1L]], halted$knowledge_time[[1L]]
  )
  after_halt <- ledgr_run_explain(
    run, halted$instrument_id[[1L]], halted$effective_to[[1L]]
  )
  testthat::expect_false(before_known$target_restricted[[1L]])
  testthat::expect_true(when_known$target_restricted[[1L]])
  testthat::expect_identical(
    when_known$target_restriction_reason[[1L]],
    "trading_halted"
  )
  testthat::expect_false(after_halt$target_restricted[[1L]])

  delisting_at <- inputs$lifetime$effective_from[
    inputs$lifetime$assertion == "known_inactive"
  ][[1L]]
  after_delisting <- session_rows$session_close[
    session_rows$status == "open" &
      session_rows$session_close > delisting_at
  ]
  first_stale <- ledgr_run_explain(
    run, inputs$instruments$instrument_id[[1L]], after_delisting[[1L]]
  )
  first_expired <- ledgr_run_explain(
    run, inputs$instruments$instrument_id[[1L]], after_delisting[[3L]]
  )
  testthat::expect_true(first_stale$target_restricted[[1L]])
  testthat::expect_identical(first_stale$mark_source[[1L]], "stale_close")
  testthat::expect_identical(first_stale$mark_age[[1L]], 1L)
  testthat::expect_identical(first_expired$mark_source[[1L]], "expired_close")
  testthat::expect_identical(first_expired$mark_age[[1L]], 3L)

  gap_date <- inputs$cases$date[
    inputs$cases$type == "missing_observation"
  ][[1L]]
  gap_close <- session_rows$session_close[
    session_rows$session_date == gap_date
  ][[1L]]
  gap_inputs <- inputs
  gap_inputs$bars <- gap_inputs$bars[
    as.Date(gap_inputs$bars$ts_utc, tz = "UTC") != gap_date,
    , drop = FALSE
  ]
  gap_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(gap_path), add = TRUE)
  gap_snapshot <- ledgr_snapshot_from_df(
    gap_inputs$bars,
    instruments_df = gap_inputs$instruments,
    facts = facts,
    db_path = gap_path,
    price_basis = gap_inputs$recipe$price_basis
  )
  gap_experiment <- ledgr_experiment(
    gap_snapshot,
    function(ctx, params) ctx$flat(),
    universe = ledgr_universe_members(
      gap_inputs$recipe$scopes$universe_id
    ),
    valuation_policy = ledgr_valuation_stale(2),
    cost_model = ledgr_cost_zero()
  )
  gap_run <- ledgr_run(gap_experiment, run_id = "pit-empty-session")
  on.exit(close(gap_run), add = TRUE)
  gap_equity <- tibble::as_tibble(gap_run, what = "equity")
  testthat::expect_true(gap_close %in% gap_equity$ts_utc)
  gap_explain <- ledgr_run_explain(
    gap_run, inputs$instruments$instrument_id[[3L]], gap_close
  )
  testthat::expect_identical(gap_explain$mark_source[[1L]], "stale_close")
  testthat::expect_identical(gap_explain$mark_age[[1L]], 1L)
  testthat::expect_identical(
    ledgr_run_completion(gap_run)$completion_status,
    "DONE"
  )
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0078] committed PIT inputs regenerate and compose", {
  script_path <- normalizePath(
    testthat::test_path("..", "..", "data-raw", "make_demo_pit_inputs.R"),
    winslash = "/",
    mustWork = TRUE
  )
  package_root <- normalizePath(
    testthat::test_path("..", ".."),
    winslash = "/",
    mustWork = TRUE
  )
  regenerated_path <- tempfile(fileext = ".rda")
  on.exit(unlink(regenerated_path), add = TRUE)
  script_env <- new.env(parent = globalenv())
  sys.source(script_path, envir = script_env)
  testthat::expect_true(is.function(script_env$make_ledgr_demo_pit_inputs))
  generated <- script_env$make_ledgr_demo_pit_inputs(
    output_path = regenerated_path,
    package_root = package_root
  )
  testthat::expect_identical(generated, ledgr_demo_pit_inputs)

  committed_path <- normalizePath(
    testthat::test_path("..", "..", "data", "ledgr_demo_pit_inputs.rda"),
    winslash = "/",
    mustWork = TRUE
  )
  testthat::expect_identical(
    unname(tools::md5sum(regenerated_path)),
    unname(tools::md5sum(committed_path))
  )

  data_help_path <- normalizePath(
    testthat::test_path("..", "..", "man", "ledgr_demo_pit_inputs.Rd"),
    winslash = "/",
    mustWork = TRUE
  )
  data_help <- paste(readLines(data_help_path, warn = FALSE), collapse = "\n")
  for (label in c(
    "DEMO_01", "DEMO_05", "DEMO_VENUE", "demo_members"
  )) {
    testthat::expect_match(data_help, label, fixed = TRUE)
  }
  for (constructor in c(
    "ledgr_facts_sessions", "ledgr_facts_membership_snapshots",
    "ledgr_facts_lifetime", "ledgr_facts_trading_status",
    "ledgr_facts_equity_corporate_actions"
  )) {
    testthat::expect_match(
      data_help,
      paste0("\\link[=", constructor, "]"),
      fixed = TRUE
    )
  }

  closure <- ledgr_demo_pit_inputs$cases$date[
    ledgr_demo_pit_inputs$cases$type == "venue_closure"
  ][[1L]]
  gap <- ledgr_demo_pit_inputs$cases[
    ledgr_demo_pit_inputs$cases$type == "missing_observation", , drop = FALSE
  ]
  bar_dates <- as.Date(ledgr_demo_pit_inputs$bars$ts_utc,
    tz = "America/New_York"
  )
  testthat::expect_false(closure %in% bar_dates)
  testthat::expect_identical(
    ledgr_demo_pit_inputs$sessions$status[
      ledgr_demo_pit_inputs$sessions$session_date == gap$date[[1L]]
    ],
    "open"
  )
  testthat::expect_false(any(
    ledgr_demo_pit_inputs$bars$instrument_id == gap$instrument_id[[1L]] &
      bar_dates == gap$date[[1L]]
  ))

  facts <- do.call(ledgr_facts, pit_families(ledgr_demo_pit_inputs))
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)
  snapshot <- ledgr_snapshot_from_df(
    ledgr_demo_pit_inputs$bars,
    instruments_df = ledgr_demo_pit_inputs$instruments,
    facts = facts,
    db_path = db_path,
    price_basis = ledgr_demo_pit_inputs$recipe$price_basis
  )
  snapshot_id <- snapshot$snapshot_id
  ledgr_snapshot_close(snapshot)
  reopened <- ledgr_snapshot_open(db_path, snapshot_id, verify = TRUE)
  on.exit(ledgr_snapshot_close(reopened), add = TRUE)
  experiment <- ledgr_experiment(
    reopened,
    function(ctx, params) ctx$flat(),
    universe = ledgr_universe_members(
      ledgr_demo_pit_inputs$recipe$scopes$universe_id
    ),
    valuation_policy = ledgr_valuation_stale(2),
    cost_model = ledgr_cost_zero()
  )
  testthat::expect_true(ledgr_experiment_plan(experiment)$availability_active)
  run <- ledgr_run(experiment, run_id = "committed-pit-input-workflow")
  on.exit(close(run), add = TRUE)
  testthat::expect_identical(
    ledgr_run_completion(run)$completion_status,
    "DONE"
  )

  cash_row <- ledgr_demo_pit_inputs$corporate_actions[
    ledgr_demo_pit_inputs$corporate_actions$parent_instrument_id ==
      "DEMO_03", , drop = FALSE
  ]
  testthat::expect_identical(
    cash_row$subtype,
    "ordinary_cash_dividend"
  )
  hold_strategy <- function(ctx, params) ctx$hold()
  held_opening <- ledgr_opening(
    cash = 1000,
    positions = c(DEMO_03 = 2),
    cost_basis = c(DEMO_03 = 100)
  )
  research_experiment <- ledgr_experiment(
    reopened,
    hold_strategy,
    universe = ledgr_universe_members(
      ledgr_demo_pit_inputs$recipe$scopes$universe_id
    ),
    opening = held_opening,
    valuation_policy = ledgr_valuation_stale(2),
    cost_model = ledgr_cost_zero()
  )
  research_run <- ledgr_run(
    research_experiment,
    run_id = "committed-pit-cash-research"
  )
  on.exit(close(research_run), add = TRUE)
  testthat::expect_identical(
    ledgr:::ledgr_corporate_action_summary(research_run)$gross_cash_posted,
    1.5
  )

  strict_experiment <- ledgr_experiment(
    reopened,
    hold_strategy,
    universe = ledgr_universe_members(
      ledgr_demo_pit_inputs$recipe$scopes$universe_id
    ),
    opening = held_opening,
    valuation_policy = ledgr_valuation_stale(2),
    cost_model = ledgr_cost_zero(),
    corporate_action_policy = ledgr_corporate_actions_strict()
  )
  testthat::expect_error(
    ledgr_run(strict_experiment, run_id = "committed-pit-cash-strict"),
    class = "ledgr_corporate_action_unsupported"
  )
})
