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
    2L, "plan-run", 1L, handler, state,
    marks = c(AAA = 90)
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
  # A declared refusal returns a typed stop and posts nothing (Cut 12 LDG-2997).
  refused <- strict$plan$post(2L, "strict-run", 1L, handler, state)
  testthat::expect_identical(refused$stopped$reason_code, "corporate_action_cash_refused")
  testthat::expect_identical(refused$stopped$ids, "AAA")
  testthat::expect_identical(refused$state$cash, state$cash)
  testthat::expect_identical(refused$next_event_seq, 1L)

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
  straddling <- data.frame(
    event_id = paste0("s", 1:3), run_id = "s", ts_utc = straddling_times,
    event_type = "FILL", instrument_id = "AAA", side = "BUY", qty = c(1, 2, 4),
    price = 10, fee = 0, meta_json = "{}", event_seq = 1:3, stringsAsFactors = FALSE
  )
  straddling_replay <- ledgr:::ledgr_replay_accounting_events(
    ledgr:::ledgr_prepare_accounting_events(straddling)
  )
  testthat::expect_identical(
    ledgr:::ledgr_accounting_positions_at_pairs(
      straddling_replay,
      rep("AAA", 3L),
      straddling_times
    ),
    c(1, 3, 7)
  )
})

# A resumed plan recounts past entitlements from the ledger. The fresh fold
# binds pulse e while processing pulse e - 1, before the fills decided there,
# which execute at pulse e's session open; expected quantities below are that
# rule written out by hand.
testthat::test_that("[LTB-0217] a resumed plan binds past entitlements like the fresh fold", {
  day <- as.POSIXct("2021-03-01", tz = "UTC") + 86400 * 0:4
  close <- day + 21 * 3600
  open <- day + 14.5 * 3600
  fill <- function(seq, ts, side, qty) {
    data.frame(
      event_id = paste0("r_", seq), run_id = "r", ts_utc = ts, event_type = "FILL",
      instrument_id = "AAA", side = side, qty = qty, price = 50, fee = 0,
      meta_json = "{}", event_seq = seq, stringsAsFactors = FALSE
    )
  }
  bound <- function(events, entitlement_pulse) {
    rows <- corporate_action_cash_rows(entitlement = close[[entitlement_pulse]], knowledge = close[[1L]])
    rows$snapshot_id <- "snapshot-test"
    plan <- ledgr:::ledgr_corporate_action_plan(
      rows = rows,
      policy_identity = ledgr:::ledgr_corporate_action_policy_identity(ledgr_corporate_actions()),
      pulses_posix = close,
      instrument_ids = "AAA",
      existing_events = events,
      start_idx = 4L
    )
    testthat::expect_true(plan$state$bound[[1L]])
    plan$state$quantity[[1L]]
  }
  # Buyer: decided at pulse 2, filled at pulse 3's open; not entitled at pulse 3.
  testthat::expect_identical(bound(fill(1L, open[[3L]], "BUY", 10), 3L), 0)
  # Seller: bought for pulse 2's open, sold at pulse 3's open; still entitled.
  testthat::expect_identical(
    bound(rbind(fill(1L, open[[2L]], "BUY", 10), fill(2L, open[[3L]], "SELL", 10)), 3L),
    10
  )
  # Fractional quantities: the sequential position, not a long-double sum.
  tenths <- do.call(rbind, lapply(1:10, function(k) fill(k, open[[2L]] + k, "BUY", 0.1)))
  testthat::expect_identical(bound(tenths, 3L), Reduce(`+`, rep(0.1, 10)))
  # First-pulse entitlement: the opening positions only.
  opening <- ledgr:::ledgr_opening_position_event_rows("r", close[[1L]], c(AAA = 5), c(AAA = 40), 1L)
  testthat::expect_identical(bound(rbind(opening, fill(2L, open[[2L]], "BUY", 3)), 1L), 5)
  # Dense stamping (fills at the bar time): a fill decided at pulse 2 is
  # stamped at pulse 3 and stays excluded.
  testthat::expect_identical(bound(fill(1L, close[[3L]], "BUY", 10), 3L), 0)
  # A ledger whose timestamps decrease in event order (never written by ledgr)
  # counts its events at or before the boundary, in event order.
  testthat::expect_identical(
    bound(rbind(fill(1L, open[[3L]], "BUY", 10), fill(2L, open[[2L]], "BUY", 0.1), fill(3L, open[[2L]], "BUY", 0.2)), 3L),
    0.1 + 0.2
  )
  # A fill whose meta records its position delta, as the fold writes it, and a
  # disposition that closes the holding before the boundary.
  bought <- fill(1L, open[[2L]], "BUY", 10)
  bought$meta_json <- '{"position_delta":10,"cash_delta":-500}'
  disposed <- fill(2L, close[[2L]], "SELL", 10)
  disposed$event_type <- "DISPOSITION"
  disposed$meta_json <- '{"position_delta":-10,"cash_delta":500,"source":"delisting"}'
  testthat::expect_identical(bound(bought, 3L), 10)
  testthat::expect_identical(bound(rbind(bought, disposed), 3L), 0)
  # The position-only pass behind the recount equals the full replay's
  # positions on interleaved instruments, whole and fractional.
  mixed <- function(qty) {
    out <- rbind(
      fill(1L, open[[2L]], "BUY", qty[[1L]]), fill(2L, open[[2L]] + 1, "BUY", qty[[2L]]),
      fill(3L, open[[3L]], "SELL", qty[[3L]]), fill(4L, open[[3L]] + 1, "BUY", qty[[4L]])
    )
    out$instrument_id <- c("AAA", "BBB", "AAA", "BBB")
    ledgr:::ledgr_prepare_accounting_events(out)
  }
  for (qty in list(c(3, 2, 1, 4), c(0.3, 0.2, 0.1, 0.7))) {
    prepared <- mixed(qty)
    testthat::expect_identical(
      ledgr:::ledgr_accounting_position_after(prepared),
      ledgr:::ledgr_replay_accounting_events(prepared)$position_after
    )
  }
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
      targets = ctx$hold(),
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

  next_open_experiment <- ledgr_experiment(
    snapshot,
    strategy,
    opening = ledgr_opening(
      cash = 1000,
      positions = c(AAA = 2),
      cost_basis = c(AAA = 100)
    ),
    cost_model = ledgr_cost_zero(),
    corporate_action_policy = ledgr_corporate_actions(
      cash_posting = "next_open"
    )
  )
  next_open_run <- ledgr_run(
    next_open_experiment,
    run_id = "corporate-action-cash-next-open"
  )
  withr::defer(close(next_open_run))
  next_open_con <- ledgr:::ledgr_backtest_read_connection(next_open_run)
  withr::defer(next_open_con$close())
  next_open_equity <- DBI::dbGetQuery(
    next_open_con$con,
    paste(
      "SELECT cash, equity FROM equity_curve",
      "WHERE run_id = ? ORDER BY ts_utc"
    ),
    params = list(next_open_run$run_id)
  )
  next_open_state <- DBI::dbGetQuery(
    next_open_con$con,
    "SELECT state_json FROM strategy_state WHERE run_id = ? ORDER BY ts_utc",
    params = list(next_open_run$run_id)
  )
  next_open_context_cash <- vapply(
    next_open_state$state_json,
    function(value) {
      as.numeric(ledgr:::ledgr_json_read_nested(value)$observed_cash)
    },
    numeric(1)
  )
  testthat::expect_identical(
    unname(next_open_equity$cash),
    c(1000, 1000, 1002.5, 1002.5)
  )
  testthat::expect_identical(
    unname(next_open_equity$equity),
    c(1200, 1180, 1092.5, 1094.5)
  )
  testthat::expect_identical(
    unname(next_open_context_cash),
    c(1000, 1000, 1002.5, 1002.5)
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
  decision_params <- function(target) {
    list(
      decision_ts = ledgr:::ledgr_normalize_ts_utc(bars$ts_utc[[1L]]),
      target = target
    )
  }

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
