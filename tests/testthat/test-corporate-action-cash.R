corporate_action_cash_rows <- function(entitlement,
                                       knowledge = entitlement,
                                       effective = entitlement,
                                       amount = 1.25) {
  data.frame(
    fact_id = "dividend-1",
    subtype = "ordinary_cash_dividend",
    parent_instrument_id = "AAA",
    entitlement_time = as.POSIXct(entitlement, tz = "UTC"),
    effective_time = as.POSIXct(effective, tz = "UTC"),
    knowledge_time = as.POSIXct(knowledge, tz = "UTC"),
    complete = TRUE,
    provenance_tier = "snapshot_bound",
    gross_cash_per_parent_unit = amount,
    gross_cash_validated = TRUE,
    recipient_identity_validated = FALSE,
    recipient_quantity_validated = FALSE,
    source = "cash_fixture",
    stringsAsFactors = FALSE
  )
}

corporate_action_cash_bars <- function() {
  ts <- as.POSIXct("2020-01-01 16:00:00", tz = "UTC") + 86400 * 0:3
  data.frame(
    instrument_id = "AAA",
    ts_utc = ts,
    open = c(100, 90, 45, 46),
    high = c(100, 90, 45, 46),
    low = c(100, 90, 45, 46),
    close = c(100, 90, 45, 46),
    volume = 1000,
    stringsAsFactors = FALSE
  )
}

corporate_action_cash_plan_fixture <- function(posting = "effective_close",
                                                knowledge_day = 1L) {
  pulses <- corporate_action_cash_bars()$ts_utc
  rows <- corporate_action_cash_rows(
    entitlement = pulses[[2L]],
    effective = pulses[[4L]],
    knowledge = pulses[[knowledge_day]]
  )
  rows$snapshot_id <- "snapshot-test"
  policy <- ledgr_corporate_actions(cash_posting = posting)
  plan <- ledgr:::ledgr_corporate_action_plan(
    rows = rows,
    policy_identity = ledgr:::ledgr_corporate_action_policy_identity(policy),
    pulses_posix = pulses,
    instrument_ids = "AAA",
    start_idx = 1L
  )
  list(plan = plan, pulses = pulses)
}

testthat::test_that("[LTB-0035] cash plan fixes entitlement and posts before use", {
  fixture <- corporate_action_cash_plan_fixture()
  rows <- list()
  handler <- list(append_event_rows = function(value) rows[[length(rows) + 1L]] <<- value)
  state <- list(cash = 1000, positions = c(AAA = 2))
  fixture$plan$bind_boundary(1L, state$positions)
  fixture$plan$bind_boundary(2L, state$positions)
  state$positions[["AAA"]] <- 0
  result <- fixture$plan$post(
    2L, "plan-run", 1L, handler, state, marks = c(AAA = 90)
  )

  testthat::expect_identical(result$state$cash, 1002.5)
  testthat::expect_identical(result$next_event_seq, 2L)
  testthat::expect_length(rows, 1L)
  meta <- ledgr:::ledgr_json_read_nested(rows[[1L]]$meta_json[[1L]])
  testthat::expect_identical(meta$source_fact_id, "dividend-1")
  testthat::expect_identical(meta$entitled_quantity, 2)
  testthat::expect_identical(meta$cash_delta, 2.5)
  testthat::expect_identical(meta$affected_marked_exposure, 180)
  testthat::expect_false(meta$late_arrival)
  testthat::expect_identical(
    meta$amount_policy_id,
    "ledgr.corporate_action.cash_amount.gross.v001"
  )
  testthat::expect_identical(
    meta$posting_policy_id,
    "ledgr.corporate_action.cash_posting.effective_close.v001"
  )

  again <- fixture$plan$post(
    2L, "plan-run", result$next_event_seq, handler, result$state,
    marks = c(AAA = 90)
  )
  testthat::expect_identical(again$state$cash, 1002.5)
  testthat::expect_length(rows, 1L)

  delayed <- corporate_action_cash_plan_fixture(knowledge_day = 3L)
  delayed$plan$bind_boundary(2L, c(AAA = 2))
  no_post <- delayed$plan$post(2L, "late-run", 1L, handler, state)
  testthat::expect_identical(no_post$next_event_seq, 1L)
  late <- delayed$plan$post(3L, "late-run", 1L, handler, state)
  late_meta <- ledgr:::ledgr_json_read_nested(rows[[2L]]$meta_json[[1L]])
  testthat::expect_identical(late$state$cash, 1002.5)
  testthat::expect_true(late_meta$late_arrival)

  next_open <- corporate_action_cash_plan_fixture(posting = "next_open")
  next_open$plan$bind_boundary(2L, c(AAA = 2))
  held <- next_open$plan$post(2L, "next-run", 1L, handler, state)
  testthat::expect_identical(held$next_event_seq, 1L)
  posted <- next_open$plan$post(3L, "next-run", 1L, handler, state)
  testthat::expect_identical(posted$state$cash, 1002.5)

  buyer <- corporate_action_cash_plan_fixture()
  buyer$plan$bind_boundary(2L, c(AAA = 0))
  buyer_state <- list(cash = 1000, positions = c(AAA = 2))
  buyer_result <- buyer$plan$post(2L, "buyer-run", 1L, handler, buyer_state)
  testthat::expect_identical(buyer_result$state$cash, 1000)

  strict <- corporate_action_cash_plan_fixture()
  strict$plan$state$settings[["cash_amount"]] <- "refuse"
  strict$plan$bind_boundary(2L, c(AAA = 2))
  testthat::expect_error(
    strict$plan$post(2L, "strict-run", 1L, handler, state),
    class = "ledgr_corporate_action_unsupported"
  )

  duplicate_row <- rows[[1L]]
  duplicate_meta <- ledgr:::ledgr_json_read_nested(duplicate_row$meta_json[[1L]])
  duplicate_events <- rbind(duplicate_row, duplicate_row)
  duplicate_events$event_id <- c("duplicate-1", "duplicate-2")
  duplicate_events$event_seq <- 1:2
  duplicate_events$meta_json <- rep(
    ledgr:::canonical_json(duplicate_meta),
    2L
  )
  testthat::expect_error(
    ledgr:::ledgr_corporate_action_plan(
      rows = corporate_action_cash_plan_fixture()$plan$state$rows,
      policy_identity = corporate_action_cash_plan_fixture()$plan$state$identity,
      pulses_posix = fixture$pulses,
      instrument_ids = "AAA",
      existing_events = duplicate_events,
      start_idx = 3L
    ),
    class = "ledgr_duplicate_corporate_action_event"
  )

  straddling_times <- as.POSIXct(
    c(999999999, 1000000000, 1000000001),
    origin = "1970-01-01",
    tz = "UTC"
  )
  testthat::expect_identical(
    ledgr:::ledgr_corporate_action_cumulative_at(
      straddling_times,
      c(1, 2, 4),
      straddling_times,
      include_equal = TRUE
    ),
    c(1, 3, 7)
  )
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0036] public run posts one gross dividend and reports it", {
  bars <- corporate_action_cash_bars()
  fact_rows <- corporate_action_cash_rows(
    entitlement = bars$ts_utc[[2L]],
    knowledge = bars$ts_utc[[1L]],
    effective = bars$ts_utc[[4L]]
  )
  snapshot <- ledgr_snapshot_from_df(
    bars,
    facts = ledgr_facts(ledgr_facts_equity_corporate_actions(fact_rows)),
    price_basis = "split_adjusted"
  )
  withr::defer(ledgr_snapshot_close(snapshot))
  strategy <- function(ctx, params) {
    list(
      targets = ctx$positions,
      state_update = list(observed_cash = ctx$cash)
    )
  }
  experiment <- ledgr_experiment(
    snapshot,
    strategy,
    opening = ledgr_opening(
      cash = 1000,
      positions = c(AAA = 2),
      cost_basis = c(AAA = 100)
    ),
    cost_model = ledgr_cost_zero()
  )
  run <- ledgr_run(experiment, run_id = "corporate-action-cash")
  withr::defer(close(run))
  opened <- ledgr:::ledgr_backtest_read_connection(run)
  withr::defer(opened$close())
  cash_events <- DBI::dbGetQuery(
    opened$con,
    paste(
      "SELECT * FROM ledger_events",
      "WHERE run_id = ? AND event_type = 'CASHFLOW' ORDER BY event_seq"
    ),
    params = list(run$run_id)
  )
  event_meta <- lapply(cash_events$meta_json, ledgr:::ledgr_json_read_nested)
  corporate <- which(vapply(
    event_meta,
    function(value) identical(value$source, "corporate_action_cash"),
    logical(1)
  ))
  testthat::expect_length(corporate, 1L)
  state_rows <- DBI::dbGetQuery(
    opened$con,
    "SELECT state_json FROM strategy_state WHERE run_id = ? ORDER BY ts_utc",
    params = list(run$run_id)
  )
  observed_cash <- vapply(state_rows$state_json, function(value) {
    as.numeric(ledgr:::ledgr_json_read_nested(value)$observed_cash)
  }, numeric(1))
  testthat::expect_identical(
    unname(observed_cash),
    c(1000, 1002.5, 1002.5, 1002.5)
  )
  summary <- ledgr:::ledgr_corporate_action_summary(run)
  testthat::expect_identical(summary$corporate_action_fidelity, "modeled")
  testthat::expect_identical(summary$gross_cash_posted, 2.5)
  testthat::expect_identical(summary$late_arrival_count, 0L)
  testthat::expect_identical(summary$choice_counts[["cash_amount.gross"]], 1L)
  testthat::expect_identical(
    summary$choice_counts[["cash_posting.effective_close"]],
    1L
  )

  config <- ledgr_config(
    snapshot = snapshot,
    universe = "AAA",
    strategy = strategy,
    backtest = ledgr_backtest_config(
      start = snapshot$metadata$start_date,
      end = snapshot$metadata$end_date,
      initial_cash = 1000
    ),
    opening = ledgr_opening(
      cash = 1000,
      positions = c(AAA = 2),
      cost_basis = c(AAA = 100)
    ),
    cost_model_hash = ledgr:::ledgr_cost_model_hash(ledgr_cost_zero()),
    cost_plan_json = ledgr:::ledgr_cost_plan_json(ledgr_cost_zero()),
    db_path = snapshot$db_path
  )
  ledgr:::ledgr_run_fold(
    config,
    run_id = "corporate-action-cash-resume",
    control = list(max_pulses = 1L)
  )
  ledgr_run_config(config, run_id = "corporate-action-cash-resume")
  reopened <- ledgr_run_open(snapshot, "corporate-action-cash-resume")
  withr::defer(close(reopened))
  reopened_summary <- ledgr:::ledgr_corporate_action_summary(reopened)
  testthat::expect_identical(reopened_summary$gross_cash_posted, 2.5)
  reopened_con <- ledgr:::ledgr_backtest_read_connection(reopened)
  withr::defer(reopened_con$close())
  posted_count <- DBI::dbGetQuery(
    reopened_con$con,
    paste(
      "SELECT COUNT(*) AS n FROM ledger_events",
      "WHERE run_id = ? AND event_type = 'CASHFLOW'",
      "AND meta_json LIKE '%corporate_action_cash%'"
    ),
    params = list(reopened$run_id)
  )$n[[1L]]
  testthat::expect_identical(as.integer(posted_count), 1L)

  boundary_strategy <- function(ctx, params) {
    target <- ctx$hold()
    if (identical(ctx$ts_utc, params$decision_ts)) {
      target[["AAA"]] <- params$target
    }
    list(targets = target, state_update = list(observed_cash = ctx$cash))
  }
  boundary_experiment <- function(opening_quantity, snapshot_value = snapshot) {
    opening <- if (opening_quantity == 0) {
      ledgr_opening(cash = 1000)
    } else {
      ledgr_opening(
        cash = 1000,
        positions = c(AAA = opening_quantity),
        cost_basis = c(AAA = 100)
      )
    }
    ledgr_experiment(
      snapshot_value,
      boundary_strategy,
      opening = opening,
      cost_model = ledgr_cost_zero()
    )
  }
  decision_params <- function(target) list(
    decision_ts = ledgr:::ledgr_normalize_ts_utc(bars$ts_utc[[1L]]),
    target = target
  )

  seller <- ledgr_run(
    boundary_experiment(4),
    params = decision_params(0),
    run_id = "corporate-action-ex-date-seller"
  )
  withr::defer(close(seller))
  buyer <- ledgr_run(
    boundary_experiment(0),
    params = decision_params(4),
    run_id = "corporate-action-ex-date-buyer"
  )
  withr::defer(close(buyer))
  seller_fills <- ledgr_run_fills(seller)
  buyer_fills <- ledgr_run_fills(buyer)
  testthat::expect_identical(seller_fills$side, "SELL")
  testthat::expect_identical(buyer_fills$side, "BUY")
  testthat::expect_identical(seller_fills$ts_utc, bars$ts_utc[[2L]])
  testthat::expect_identical(buyer_fills$ts_utc, bars$ts_utc[[2L]])
  testthat::expect_identical(
    ledgr:::ledgr_corporate_action_summary(seller)$gross_cash_posted,
    5
  )
  testthat::expect_identical(
    ledgr:::ledgr_corporate_action_summary(buyer)$gross_cash_posted,
    0
  )

  late_rows <- corporate_action_cash_rows(
    entitlement = bars$ts_utc[[2L]],
    knowledge = bars$ts_utc[[3L]],
    effective = bars$ts_utc[[4L]]
  )
  late_snapshot <- ledgr_snapshot_from_df(
    bars,
    facts = ledgr_facts(ledgr_facts_equity_corporate_actions(late_rows)),
    price_basis = "split_adjusted"
  )
  withr::defer(ledgr_snapshot_close(late_snapshot))
  late_config <- ledgr_config(
    snapshot = late_snapshot,
    universe = "AAA",
    strategy = boundary_strategy,
    strategy_params = decision_params(0),
    backtest = ledgr_backtest_config(
      start = late_snapshot$metadata$start_date,
      end = late_snapshot$metadata$end_date,
      initial_cash = 1000
    ),
    opening = ledgr_opening(
      cash = 1000,
      positions = c(AAA = 4),
      cost_basis = c(AAA = 100)
    ),
    cost_model_hash = ledgr:::ledgr_cost_model_hash(ledgr_cost_zero()),
    cost_plan_json = ledgr:::ledgr_cost_plan_json(ledgr_cost_zero()),
    db_path = late_snapshot$db_path
  )
  partial <- ledgr:::ledgr_run_fold(
    late_config,
    run_id = "corporate-action-ex-date-resume",
    control = list(max_pulses = 2L)
  )
  if (inherits(partial, "ledgr_backtest")) close(partial)
  ledgr_run_config(
    late_config,
    run_id = "corporate-action-ex-date-resume"
  )
  resumed_boundary <- ledgr_run_open(
    late_snapshot,
    "corporate-action-ex-date-resume"
  )
  withr::defer(close(resumed_boundary))
  testthat::expect_identical(
    ledgr:::ledgr_corporate_action_summary(resumed_boundary)$gross_cash_posted,
    5
  )
  testthat::expect_identical(
    ledgr_run_fills(resumed_boundary)$ts_utc,
    bars$ts_utc[[2L]]
  )

  testthat::expect_error(
    ledgr_sweep(
      experiment,
      ledgr_param_grid(candidate = list()),
      stop_on_error = TRUE,
      compiled_accounting_model = "spot_fifo"
    ),
    class = "ledgr_compiled_spot_fifo_unavailable"
  )
})
