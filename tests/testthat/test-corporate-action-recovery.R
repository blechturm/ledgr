corporate_action_recovery_fixture <- function() {
  dates <- as.Date("2020-01-01") + 0:2
  pulses <- as.POSIXct(paste(dates, "16:00:00"), tz = "UTC")
  bars <- rbind(
    data.frame(
      instrument_id = "AAA", ts_utc = pulses,
      open = c(100, 90, 91), high = c(100, 90, 91),
      low = c(100, 90, 91), close = c(100, 90, 91), volume = 1000
    ),
    data.frame(
      instrument_id = "BBB", ts_utc = pulses,
      open = c(49, 50, 51), high = c(49, 50, 51),
      low = c(49, 50, 51), close = c(49, 50, 51), volume = 1000
    )
  )
  sessions <- ledgr_facts_sessions(data.frame(
    session_date = dates,
    status = "open",
    session_open = "09:30:00",
    session_close = "16:00:00",
    knowledge_time = as.POSIXct(dates, tz = "UTC") - 1,
    stringsAsFactors = FALSE
  ), venue_id = "XNYS")
  lifetime <- ledgr_facts_lifetime(data.frame(
    instrument_id = "AAA",
    effective_from = pulses[[2L]],
    knowledge_time = pulses[[2L]] - 1,
    assertion = "known_inactive",
    terminal_event = "acquired",
    stringsAsFactors = FALSE
  ))
  action <- ledgr_facts_equity_corporate_actions(data.frame(
    fact_id = "recovery-acquisition",
    subtype = "cash_acquisition",
    parent_instrument_id = "AAA",
    entitlement_time = pulses[[2L]],
    effective_time = pulses[[2L]],
    knowledge_time = pulses[[1L]],
    complete = TRUE,
    provenance_tier = "snapshot_bound",
    gross_cash_per_parent_unit = 120,
    gross_cash_validated = TRUE,
    recipient_identity_validated = FALSE,
    recipient_quantity_validated = FALSE,
    stringsAsFactors = FALSE
  ))
  snapshot <- ledgr_snapshot_from_df(
    bars,
    instruments_df = data.frame(instrument_id = c("AAA", "BBB")),
    facts = ledgr_facts(sessions, lifetime, action),
    price_basis = "split_adjusted"
  )
  list(snapshot = snapshot, pulses = pulses)
}

corporate_action_recovery_experiment <- function(fixture, strategy) {
  ledgr_experiment(
    fixture$snapshot,
    strategy,
    opening = ledgr_opening(
      cash = 1000,
      positions = c(AAA = 2),
      cost_basis = c(AAA = 100)
    ),
    valuation_policy = ledgr_valuation_stale(1L),
    cost_model = ledgr_cost_zero(),
    corporate_action_policy = ledgr_corporate_actions_research()
  )
}

corporate_action_recovery_config <- function(exp) {
  ledgr_config(
    snapshot = exp$snapshot,
    universe = exp$universe,
    strategy = exp$strategy,
    backtest = ledgr_backtest_config(
      start = exp$snapshot$metadata$start_date,
      end = exp$snapshot$metadata$end_date,
      initial_cash = exp$opening$cash
    ),
    opening = exp$opening,
    timing_model = exp$timing_model,
    cost_model_hash = exp$cost_model_hash,
    cost_plan_json = exp$cost_plan_json,
    risk_chain_hash = exp$risk_chain_hash,
    risk_plan_json = exp$risk_plan_json,
    db_path = exp$snapshot$db_path,
    availability = exp$availability,
    universe_rule = exp$universe_rule,
    valuation_policy = exp$valuation_policy,
    corporate_action_policy = exp$corporate_action_policy
  )
}

corporate_action_recovery_surface <- function(bt, what, exclusions) {
  value <- as.data.frame(ledgr_results(bt, what))
  value[, setdiff(names(value), exclusions), drop = FALSE]
}

# ledgr-test-profile: review
testthat::test_that("[LTB-0054] durable resume after disposition is exactly once", {
  fixture <- corporate_action_recovery_fixture()
  withr::defer(ledgr_snapshot_close(fixture$snapshot))
  exp <- corporate_action_recovery_experiment(
    fixture,
    function(ctx, params) ctx$hold()
  )
  config <- corporate_action_recovery_config(exp)
  ledgr_run_config(config, run_id = "disposition-clean")
  partial <- ledgr:::ledgr_run_fold(
    config,
    run_id = "disposition-resumed",
    control = list(max_pulses = 2L)
  )
  if (inherits(partial, "ledgr_backtest")) close(partial)
  opened <- ledgr:::ledgr_snapshot_connection(fixture$snapshot)
  partial_count <- DBI::dbGetQuery(
    opened$con,
    paste(
      "SELECT COUNT(*) AS n FROM ledger_events",
      "WHERE run_id = 'disposition-resumed' AND event_type = 'DISPOSITION'"
    )
  )$n[[1L]]
  testthat::expect_identical(as.integer(partial_count), 1L)
  ledgr_run_config(config, run_id = "disposition-resumed")

  clean <- ledgr_run_open(fixture$snapshot, "disposition-clean")
  resumed <- ledgr_run_open(fixture$snapshot, "disposition-resumed")
  withr::defer(close(clean))
  withr::defer(close(resumed))
  identity <- c("run_id", "event_id", "created_at_utc")
  for (surface in c("ledger", "equity", "diagnostics", "availability")) {
    testthat::expect_equal(
      corporate_action_recovery_surface(resumed, surface, identity),
      corporate_action_recovery_surface(clean, surface, identity),
      info = surface
    )
  }
  disposition <- ledgr_results(resumed, "ledger")
  testthat::expect_identical(
    sum(disposition$event_type == "DISPOSITION"),
    1L
  )
  reopened <- ledgr_run_open(fixture$snapshot, "disposition-resumed")
  withr::defer(close(reopened))
  testthat::expect_equal(
    corporate_action_recovery_surface(reopened, "ledger", identity),
    corporate_action_recovery_surface(clean, "ledger", identity)
  )
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0055] memory failure discards disposition artifacts only for that candidate", {
  fixture <- corporate_action_recovery_fixture()
  withr::defer(ledgr_snapshot_close(fixture$snapshot))
  observed <- character()
  original_handler <- ledgr:::ledgr_memory_output_handler
  testthat::local_mocked_bindings(
    ledgr_memory_output_handler = function(...) {
      handler <- original_handler(...)
      append <- handler$append_event_rows
      handler$append_event_rows <- function(rows) {
        if (any(rows$event_type == "DISPOSITION")) {
          observed <<- c(observed, "DISPOSITION")
        }
        append(rows)
      }
      handler
    },
    .package = "ledgr"
  )
  strategy <- function(ctx, params) {
    if (isTRUE(params$fail) && identical(
      ctx$ts_utc,
      ledgr:::ledgr_normalize_ts_utc(fixture$pulses[[2L]])
    )) {
      rlang::abort("injected after disposition", class = "ledgr_test_after_disposition")
    }
    ctx$hold()
  }
  exp <- corporate_action_recovery_experiment(fixture, strategy)
  sweep <- ledgr_sweep(
    exp,
    ledgr_param_grid(
      sibling = list(fail = FALSE),
      failed = list(fail = TRUE)
    ),
    stop_on_error = FALSE,
    retain = ledgr_sweep_retention("completed")
  )
  testthat::expect_identical(sweep$status, c("DONE", "FAILED"))
  testthat::expect_true(is.finite(sweep$final_equity[[1L]]))
  testthat::expect_true(is.na(sweep$final_equity[[2L]]))
  testthat::expect_identical(observed, c("DISPOSITION", "DISPOSITION"))
  retained <- ledgr_sweep_returns(sweep)
  testthat::expect_identical(unique(retained$candidate_id), "sibling")
  testthat::expect_error(
    ledgr_sweep_returns(sweep, candidates = "failed"),
    class = "ledgr_sweep_returns_candidate_not_completed"
  )

  handler_source <- paste(deparse(ledgr:::ledgr_memory_output_handler), collapse = "\n")
  testthat::expect_no_match(
    handler_source,
    "begin_transaction|commit_transaction|rollback|reopen",
    perl = TRUE
  )
})
