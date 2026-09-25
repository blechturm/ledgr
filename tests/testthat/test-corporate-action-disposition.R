corporate_action_disposition_rows <- function(pulses,
                                               subtype = "cash_acquisition") {
  data.frame(
    fact_id = "acquisition-1",
    subtype = subtype,
    parent_instrument_id = "AAA",
    entitlement_time = pulses[[2L]],
    effective_time = pulses[[2L]],
    knowledge_time = pulses[[1L]],
    complete = TRUE,
    provenance_tier = "snapshot_bound",
    gross_cash_validated = FALSE,
    recipient_identity_validated = FALSE,
    recipient_quantity_validated = FALSE,
    source = "disposition_fixture",
    stringsAsFactors = FALSE
  )
}

corporate_action_disposition_valuation <- function(mark = 90,
                                                    reference = mark,
                                                    age = 0L,
                                                    source = "current_close") {
  list(
    mark = c(AAA = mark),
    reference = c(AAA = reference),
    age = c(AAA = as.integer(age)),
    source = c(AAA = source),
    source_ts = stats::setNames(
      as.POSIXct("2020-01-02 16:00:00", tz = "UTC"),
      "AAA"
    )
  )
}

corporate_action_disposition_plan <- function(policy = ledgr_corporate_actions()) {
  pulses <- as.POSIXct(
    paste(as.Date("2020-01-01") + 0:2, "16:00:00"),
    tz = "UTC"
  )
  plan <- ledgr:::ledgr_corporate_action_plan(
    rows = corporate_action_disposition_rows(pulses),
    policy_identity = ledgr:::ledgr_corporate_action_policy_identity(policy),
    pulses_posix = pulses,
    instrument_ids = "AAA"
  )
  plan$bind_boundary(2L, c(AAA = 2))
  list(plan = plan, pulses = pulses)
}

corporate_action_disposition_state <- function() {
  list(
    cash = 1000,
    positions = c(AAA = 2),
    lot_state = ledgr:::ledgr_lot_state_from_opening(
      "AAA",
      positions = c(AAA = 2),
      cost_basis = c(AAA = 100)
    )
  )
}

corporate_action_disposition_snapshot <- function() {
  dates <- as.Date("2020-01-01") + 0:2
  pulses <- as.POSIXct(paste(dates, "16:00:00"), tz = "UTC")
  bars <- data.frame(
    instrument_id = "AAA",
    ts_utc = pulses,
    open = c(100, 90, 91),
    high = c(100, 90, 91),
    low = c(100, 90, 91),
    close = c(100, 90, 91),
    volume = 1000,
    stringsAsFactors = FALSE
  )
  sessions <- ledgr_facts_sessions(
    data.frame(
      session_date = dates,
      status = "open",
      session_open = "09:30:00",
      session_close = "16:00:00",
      knowledge_time = as.POSIXct(dates, tz = "UTC") - 1,
      stringsAsFactors = FALSE
    ),
    venue_id = "XNYS"
  )
  lifetime <- ledgr_facts_lifetime(data.frame(
    instrument_id = "AAA",
    effective_from = pulses[[2L]],
    knowledge_time = pulses[[2L]] - 1,
    assertion = "known_inactive",
    terminal_event = "acquired",
    stringsAsFactors = FALSE
  ))
  action <- ledgr_facts_equity_corporate_actions(
    corporate_action_disposition_rows(pulses)
  )
  ledgr_snapshot_from_df(
    bars,
    instruments_df = data.frame(instrument_id = "AAA"),
    facts = ledgr_facts(sessions, lifetime, action),
    price_basis = "split_adjusted"
  )
}

testthat::test_that("[LTB-0050] DISPOSITION is prepared, migrated and replays through FIFO", {
  fixture <- corporate_action_disposition_plan()
  emitted <- list()
  handler <- list(
    append_event_rows = function(rows) emitted[[length(emitted) + 1L]] <<- rows
  )
  result <- fixture$plan$post_disposition(
    index = 2L,
    run_id = "disposition-core",
    event_seq = 1L,
    output_handler = handler,
    state_value = corporate_action_disposition_state(),
    valuation = corporate_action_disposition_valuation()
  )
  testthat::expect_identical(result$state$cash, 1180)
  testthat::expect_identical(unname(result$state$positions), 0)
  testthat::expect_identical(
    ledgr:::ledgr_lot_count(result$state$lot_state, "AAA"),
    0L
  )
  testthat::expect_identical(result$state$lot_state$realized_pnl, -20)
  testthat::expect_identical(emitted[[1L]]$event_type, "DISPOSITION")
  meta <- ledgr:::ledgr_json_read_nested(emitted[[1L]]$meta_json[[1L]])
  testthat::expect_identical(meta$source_fact_id, "acquisition-1")
  testthat::expect_identical(meta$quantity, 2)
  testthat::expect_identical(meta$mark, 90)
  testthat::expect_identical(meta$position_before, 2)
  testthat::expect_identical(meta$position_after, 0)
  testthat::expect_identical(meta$realized_model_pnl, -20)
  testthat::expect_false(any(c(
    "subtype", "equity_subtype", "vendor_subtype"
  ) %in% names(meta)))

  prepared <- ledgr:::ledgr_prepare_accounting_events(emitted[[1L]], "AAA")
  replay <- ledgr:::ledgr_replay_accounting_events(
    prepared,
    initial_cash = 1000,
    initial_positions = c(AAA = 2),
    lot_state = ledgr:::ledgr_lot_state_from_opening(
      "AAA",
      positions = c(AAA = 2),
      cost_basis = c(AAA = 100)
    )
  )
  testthat::expect_identical(replay$cash, 1180)
  testthat::expect_identical(unname(replay$positions), 0)
  testthat::expect_identical(replay$lot_state$realized_pnl, -20)

  forbidden <- emitted[[1L]]
  forbidden_meta <- meta
  forbidden_meta$vendor_subtype <- "MERGER"
  forbidden$meta_json <- ledgr:::canonical_json(forbidden_meta)
  testthat::expect_error(
    ledgr:::ledgr_prepare_accounting_events(forbidden, "AAA"),
    class = "ledgr_invalid_ledger_meta"
  )

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))
  ledgr_create_schema(con)
  DBI::dbExecute(con, "DROP TABLE ledger_events")
  DBI::dbExecute(con, paste(
    "CREATE TABLE ledger_events (",
    "event_id TEXT NOT NULL PRIMARY KEY, run_id TEXT NOT NULL,",
    "ts_utc TIMESTAMP NOT NULL, event_type TEXT NOT NULL",
    "CHECK (event_type IN ('FILL','CASHFLOW')), instrument_id TEXT,",
    "side TEXT CHECK (side IN ('BUY','SELL')), qty DOUBLE, price DOUBLE,",
    "fee DOUBLE, meta_json TEXT, event_seq INTEGER NOT NULL,",
    "UNIQUE(run_id, event_seq))"
  ))
  DBI::dbExecute(con, paste(
    "INSERT INTO ledger_events",
    "(event_id, run_id, ts_utc, event_type, meta_json, event_seq)",
    "VALUES ('old-event', 'old-run', TIMESTAMP '2020-01-01 00:00:00',",
    "'CASHFLOW', '{}', 1)"
  ))
  DBI::dbExecute(
    con,
    paste(
      "UPDATE ledgr_schema_metadata SET value = ?",
      "WHERE key = 'experiment_store_schema_version'"
    ),
    params = list(as.character(ledgr:::ledgr_experiment_store_schema_version - 1L))
  )
  ledgr_create_schema(con)
  testthat::expect_identical(
    DBI::dbGetQuery(con, "SELECT event_id FROM ledger_events")$event_id,
    "old-event"
  )
  testthat::expect_no_error(DBI::dbAppendTable(con, "ledger_events", emitted[[1L]]))
  unknown <- emitted[[1L]]
  unknown$event_id <- "unknown-event"
  unknown$event_seq <- 3L
  unknown$event_type <- "UNKNOWN"
  testthat::expect_error(DBI::dbAppendTable(con, "ledger_events", unknown))
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0051] terminal mark policy disposes or refuses without mutation", {
  emitted <- list()
  handler <- list(
    append_event_rows = function(rows) emitted[[length(emitted) + 1L]] <<- rows
  )
  expired <- corporate_action_disposition_plan(ledgr_corporate_actions(
    held_terminal_position = "last_mark"
  ))
  expired_result <- expired$plan$post_disposition(
    2L,
    "last-mark",
    1L,
    handler,
    corporate_action_disposition_state(),
    corporate_action_disposition_valuation(
      mark = NA_real_,
      reference = 80,
      age = 3L,
      source = "expired_close"
    )
  )
  testthat::expect_identical(expired_result$state$cash, 1160)
  expired_meta <- ledgr:::ledgr_json_read_nested(emitted[[1L]]$meta_json[[1L]])
  testthat::expect_identical(expired_meta$mark_age, 3L)
  testthat::expect_identical(expired_meta$mark_source, "expired_close")

  stale <- corporate_action_disposition_plan()
  stale_result <- stale$plan$post_disposition(
    2L,
    "permitted-stale",
    1L,
    handler,
    corporate_action_disposition_state(),
    corporate_action_disposition_valuation(
      mark = 85,
      reference = 85,
      age = 1L,
      source = "stale_close"
    )
  )
  testthat::expect_identical(stale_result$state$cash, 1170)
  stale_meta <- ledgr:::ledgr_json_read_nested(emitted[[2L]]$meta_json[[1L]])
  testthat::expect_identical(stale_meta$mark_age, 1L)
  testthat::expect_identical(stale_meta$mark_source, "stale_close")

  unavailable <- corporate_action_disposition_plan()
  untouched <- corporate_action_disposition_state()
  before <- unserialize(serialize(untouched, NULL))
  testthat::expect_error(
    unavailable$plan$post_disposition(
      2L,
      "no-mark",
      1L,
      handler,
      untouched,
      corporate_action_disposition_valuation(
        mark = NA_real_,
        reference = NA_real_,
        age = NA_integer_,
        source = "missing"
      )
    ),
    class = "ledgr_corporate_action_disposition_mark_unavailable"
  )
  testthat::expect_identical(untouched, before)
  testthat::expect_length(emitted, 2L)

  snapshot <- corporate_action_disposition_snapshot()
  withr::defer(ledgr_snapshot_close(snapshot))
  experiment <- function(policy) ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$hold(),
    opening = ledgr_opening(
      cash = 1000,
      positions = c(AAA = 2),
      cost_basis = c(AAA = 100)
    ),
    valuation_policy = ledgr_valuation_stale(1L),
    cost_model = ledgr_cost_zero(),
    corporate_action_policy = policy
  )
  modeled <- ledgr_run(
    experiment(ledgr_corporate_actions_research()),
    run_id = "disposition-public-modeled"
  )
  withr::defer(close(modeled))
  opened <- ledgr:::ledgr_backtest_read_connection(modeled)
  withr::defer(opened$close())
  run_row <- DBI::dbGetQuery(
    opened$con,
    "SELECT status FROM runs WHERE run_id = ?",
    params = list(modeled$run_id)
  )
  disposition <- DBI::dbGetQuery(
    opened$con,
    paste(
      "SELECT * FROM ledger_events WHERE run_id = ?",
      "AND event_type = 'DISPOSITION'"
    ),
    params = list(modeled$run_id)
  )
  testthat::expect_identical(run_row$status, "DONE")
  testthat::expect_equal(nrow(disposition), 1L)
  summary <- ledgr:::ledgr_corporate_action_summary(modeled)
  testthat::expect_identical(summary$modeled_terminal_proceeds, 180)
  testthat::expect_identical(summary$positions_disposed, 1L)
  testthat::expect_identical(summary$realized_model_pnl, -20)

  strict <- ledgr_run(
    experiment(ledgr_corporate_actions_strict()),
    run_id = "disposition-public-strict"
  )
  withr::defer(close(strict))
  strict_opened <- ledgr:::ledgr_backtest_read_connection(strict)
  withr::defer(strict_opened$close())
  strict_run <- DBI::dbGetQuery(
    strict_opened$con,
    "SELECT status FROM runs WHERE run_id = ?",
    params = list(strict$run_id)
  )
  strict_completion <- DBI::dbGetQuery(
    strict_opened$con,
    "SELECT stop_reason FROM run_completion WHERE run_id = ?",
    params = list(strict$run_id)
  )
  strict_dispositions <- DBI::dbGetQuery(
    strict_opened$con,
    paste(
      "SELECT COUNT(*) AS n FROM ledger_events WHERE run_id = ?",
      "AND event_type = 'DISPOSITION'"
    ),
    params = list(strict$run_id)
  )
  testthat::expect_identical(strict_run$status, "INCOMPLETE")
  testthat::expect_identical(
    strict_completion$stop_reason,
    "terminal_settlement_unsupported"
  )
  testthat::expect_identical(as.integer(strict_dispositions$n), 0L)
})
