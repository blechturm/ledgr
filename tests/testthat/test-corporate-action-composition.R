corporate_action_composition_fixture <- function(subtype) {
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
  security <- subtype %in% c("stock_acquisition", "mixed_acquisition", "spin_off")
  cash <- subtype %in% c("cash_acquisition", "mixed_acquisition")
  action <- ledgr_facts_equity_corporate_actions(data.frame(
    fact_id = paste0("fact-", subtype),
    subtype = subtype,
    parent_instrument_id = "AAA",
    entitlement_time = pulses[[2L]],
    effective_time = pulses[[2L]],
    knowledge_time = pulses[[1L]],
    complete = TRUE,
    provenance_tier = "snapshot_bound",
    gross_cash_per_parent_unit = if (cash) {
      if (identical(subtype, "cash_acquisition")) 120 else 65
    } else {
      NA_real_
    },
    gross_cash_validated = cash,
    recipient_instrument_id = if (security) "BBB" else NA_character_,
    recipient_identity_validated = security,
    recipient_quantity_per_parent_unit = if (security) 0.5 else NA_real_,
    recipient_quantity_validated = security,
    stringsAsFactors = FALSE
  ))
  sessions <- ledgr_facts_sessions(data.frame(
    session_date = dates,
    status = "open",
    session_open = "09:30:00",
    session_close = "16:00:00",
    knowledge_time = as.POSIXct(dates, tz = "UTC") - 1,
    stringsAsFactors = FALSE
  ), venue_id = "XNYS")
  fact_list <- list(sessions, action)
  if (!identical(subtype, "spin_off")) {
    fact_list <- append(fact_list, list(ledgr_facts_lifetime(data.frame(
      instrument_id = "AAA",
      effective_from = pulses[[2L]],
      knowledge_time = pulses[[2L]] - 1,
      assertion = "known_inactive",
      terminal_event = "acquired",
      stringsAsFactors = FALSE
    ))))
  }
  snapshot <- ledgr_snapshot_from_df(
    bars,
    instruments_df = data.frame(instrument_id = c("AAA", "BBB")),
    facts = do.call(ledgr_facts, fact_list),
    price_basis = "split_adjusted"
  )
  list(snapshot = snapshot, pulses = pulses)
}

corporate_action_composition_run <- function(subtype, policy, run_id) {
  fixture <- corporate_action_composition_fixture(subtype)
  strategy <- function(ctx, params) {
    forbidden <- grepl(
      "contractual|omitted|successor|corporate_action",
      names(ctx)
    )
    if (any(forbidden)) stop("A retrospective estimate entered the strategy context.")
    ctx$hold()
  }
  experiment <- ledgr_experiment(
    fixture$snapshot,
    strategy,
    opening = ledgr_opening(
      cash = 1000,
      positions = c(AAA = 2),
      cost_basis = c(AAA = 100)
    ),
    valuation_policy = ledgr_valuation_stale(1L),
    cost_model = ledgr_cost_zero(),
    corporate_action_policy = policy
  )
  list(
    snapshot = fixture$snapshot,
    run = ledgr_run(experiment, run_id = run_id)
  )
}

# ledgr-test-profile: review
testthat::test_that("[LTB-0052] acquisition composition reports four reconciled quantities", {
  cases <- data.frame(
    subtype = c(
      "cash_acquisition", "stock_acquisition", "mixed_acquisition", "spin_off"
    ),
    event_count = c(1L, 1L, 1L, 0L),
    final_cash = c(1180, 1180, 1180, 1000),
    fidelity = c("modeled", "unsupported", "unsupported", "unsupported"),
    modeled_cash = c(180, 180, 180, 0),
    contractual = c(240, 50, 180, 50),
    difference = c(60, -130, 0, 50),
    successor = c(0, 50, 50, 50),
    stringsAsFactors = FALSE
  )
  for (i in seq_len(nrow(cases))) {
    value <- corporate_action_composition_run(
      cases$subtype[[i]],
      ledgr_corporate_actions_research(),
      paste0("composition-", i)
    )
    opened <- ledgr:::ledgr_backtest_read_connection(value$run)
    event_count <- DBI::dbGetQuery(
      opened$con,
      paste(
        "SELECT COUNT(*) AS n FROM ledger_events",
        "WHERE run_id = ? AND event_type = 'DISPOSITION'"
      ),
      params = list(value$run$run_id)
    )$n[[1L]]
    final_cash <- DBI::dbGetQuery(
      opened$con,
      paste(
        "SELECT cash FROM equity_curve WHERE run_id = ?",
        "ORDER BY ts_utc DESC LIMIT 1"
      ),
      params = list(value$run$run_id)
    )$cash[[1L]]
    opened$close()
    summary <- ledgr:::ledgr_corporate_action_summary(value$run)
    report <- summary$omitted_value
    testthat::expect_identical(as.integer(event_count), cases$event_count[[i]])
    testthat::expect_identical(as.numeric(final_cash), cases$final_cash[[i]])
    testthat::expect_identical(
      summary$corporate_action_fidelity,
      cases$fidelity[[i]]
    )
    testthat::expect_equal(report$modeled_cash_credited, cases$modeled_cash[[i]])
    testthat::expect_equal(
      report$estimated_contractual_consideration,
      cases$contractual[[i]]
    )
    testthat::expect_equal(report$difference, cases$difference[[i]])
    testthat::expect_equal(
      report$successor_exposure_not_represented,
      cases$successor[[i]]
    )
    testthat::expect_identical(report$entitled_parent_quantity, 2)
    testthat::expect_identical(report$valuation_ts_utc, as.POSIXct(
      "2020-01-02 16:00:00",
      tz = "UTC"
    ))
    testthat::expect_identical(report$estimate_label, "effective-date estimate")
    testthat::expect_identical(summary$unsupported_facts, as.integer(i > 1L))
    testthat::expect_identical(summary$affected_marked_exposure, 180)
    close(value$run)
    ledgr_snapshot_close(value$snapshot)
  }
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0053] quantity refusal and transaction identity fail closed", {
  reported <- corporate_action_composition_run(
    "spin_off",
    ledgr_corporate_actions_research(),
    "composition-report-only"
  )
  withr::defer(close(reported$run))
  withr::defer(ledgr_snapshot_close(reported$snapshot))
  summary <- ledgr:::ledgr_corporate_action_summary(reported$run)
  testthat::expect_identical(summary$corporate_action_fidelity, "unsupported")
  testthat::expect_identical(summary$gross_cash_posted, 0)
  testthat::expect_identical(summary$modeled_terminal_proceeds, 0)

  strict_fixture <- corporate_action_composition_fixture("spin_off")
  withr::defer(ledgr_snapshot_close(strict_fixture$snapshot))
  strict_experiment <- ledgr_experiment(
    strict_fixture$snapshot,
    function(ctx, params) ctx$hold(),
    opening = ledgr_opening(
      cash = 1000,
      positions = c(AAA = 2),
      cost_basis = c(AAA = 100)
    ),
    valuation_policy = ledgr_valuation_stale(1L),
    cost_model = ledgr_cost_zero(),
    corporate_action_policy = ledgr_corporate_actions_strict()
  )
  testthat::expect_error(
    ledgr_run(strict_experiment, run_id = "composition-strict"),
    class = "ledgr_corporate_action_quantity_unsupported"
  )

  pulses <- strict_fixture$pulses
  rows <- data.frame(
    fact_id = "acquisition-1",
    subtype = "mixed_acquisition",
    parent_instrument_id = "AAA",
    entitlement_time = pulses[[2L]],
    effective_time = pulses[[2L]],
    knowledge_time = pulses[[1L]],
    complete = TRUE,
    gross_cash_per_parent_unit = 65,
    gross_cash_validated = TRUE,
    recipient_instrument_id = "BBB",
    recipient_identity_validated = TRUE,
    recipient_quantity_per_parent_unit = 0.5,
    recipient_quantity_validated = TRUE,
    stringsAsFactors = FALSE
  )
  events <- data.frame(meta_json = c(
    ledgr:::canonical_json(list(
      source = "corporate_action_cash",
      source_fact_id = "acquisition-1"
    )),
    ledgr:::canonical_json(list(
      source = "corporate_action_disposition",
      source_fact_id = "acquisition-1"
    ))
  ))
  testthat::expect_error(
    ledgr:::ledgr_corporate_action_plan(
      rows,
      ledgr:::ledgr_corporate_action_policy_identity(
        ledgr_corporate_actions_research()
      ),
      pulses,
      c("AAA", "BBB"),
      existing_events = events
    ),
    class = "ledgr_corporate_action_double_credit"
  )
})
