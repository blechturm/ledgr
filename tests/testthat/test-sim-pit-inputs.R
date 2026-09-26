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
  without_one_session <- inputs$bars[bar_dates != missing_date, , drop = FALSE]
  testthat::expect_false(missing_date %in% as.Date(without_one_session$ts_utc))
  testthat::expect_identical(
    inputs$sessions$status[inputs$sessions$session_date == missing_date],
    "open"
  )

  disabled <- do.call(
    ledgr_sim_pit_inputs,
    c(args, list(cases = setdiff(inputs$cases$type, "missing_observation")))
  )
  testthat::expect_false("missing_observation" %in% disabled$cases$type)
  expected_cases <- inputs$cases[
    inputs$cases$type != "missing_observation", , drop = FALSE
  ]
  rownames(expected_cases) <- NULL
  testthat::expect_identical(disabled$cases, expected_cases)
  disabled_dates <- as.Date(disabled$bars$ts_utc, tz = "UTC")
  testthat::expect_true(all(args$instrument_ids %in%
    disabled$bars$instrument_id[disabled_dates == missing_date]))
  testthat::expect_s3_class(do.call(ledgr_facts, pit_families(disabled)), "ledgr_facts")

  no_dividend <- do.call(
    ledgr_sim_pit_inputs,
    c(args, list(cases = setdiff(inputs$cases$type, "cash_dividend")))
  )
  testthat::expect_identical(nrow(no_dividend$corporate_actions), 0L)
  testthat::expect_false(no_dividend$recipe$constructors$corporate_actions$enabled)
  testthat::expect_s3_class(
    do.call(ledgr_facts, pit_families(no_dividend)),
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
  facts <- do.call(ledgr_facts, pit_families(inputs))
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
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0078] committed PIT inputs regenerate and compose", {
  generated <- ledgr_sim_pit_inputs(
    instrument_ids = sprintf("DEMO_%02d", 1:5),
    from = "2020-01-01",
    to = "2020-01-31",
    seed = 1702L,
    venue_id = "DEMO_XNYS",
    universe_id = "demo_members",
    timezone = "America/New_York",
    session_open = "09:30:00",
    session_close = "16:00:00",
    cases = c(
      "venue_closure", "missing_observation", "delisting", "halt",
      "cash_dividend"
    )
  )
  testthat::expect_identical(generated, ledgr_demo_pit_inputs)

  regenerated_path <- tempfile(fileext = ".rda")
  on.exit(unlink(regenerated_path), add = TRUE)
  data_env <- new.env(parent = emptyenv())
  assign("ledgr_demo_pit_inputs", generated, envir = data_env)
  save(
    list = "ledgr_demo_pit_inputs",
    file = regenerated_path,
    envir = data_env,
    compress = "xz",
    version = 2
  )
  committed_path <- normalizePath(
    testthat::test_path("..", "..", "data", "ledgr_demo_pit_inputs.rda"),
    winslash = "/",
    mustWork = TRUE
  )
  testthat::expect_identical(
    unname(tools::md5sum(regenerated_path)),
    unname(tools::md5sum(committed_path))
  )

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
})
