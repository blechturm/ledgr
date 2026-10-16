ledgr_risk_fold_test_execution <- function(strategy,
                                           cost_resolver,
                                           risk_plan = NULL,
                                           run_id = "risk-fold-test",
                                           instrument_ids = c("AAA", "BBB"),
                                           cash = 1000,
                                           positions = stats::setNames(c(0, 0), c("AAA", "BBB")),
                                           price = NULL) {
  pulses_posix <- as.POSIXct(
    c("2024-01-01 00:00:00", "2024-01-02 00:00:00", "2024-01-03 00:00:00"),
    tz = "UTC"
  )
  pulses_iso <- vapply(pulses_posix, ledgr:::ledgr_normalize_ts_utc, character(1))
  if (is.null(price)) {
    price <- rbind(
      AAA = c(10, 11, 12),
      BBB = c(20, 21, 22)
    )
  }
  price <- price[instrument_ids, , drop = FALSE]
  dimnames(price) <- list(instrument_ids, pulses_iso)
  bars_mat <- list(
    open = price,
    high = price,
    low = price,
    close = price,
    volume = matrix(1000, nrow = length(instrument_ids), ncol = length(pulses_posix), dimnames = dimnames(price)),
    gap_type = matrix("", nrow = length(instrument_ids), ncol = length(pulses_posix), dimnames = dimnames(price)),
    is_synthetic = matrix(FALSE, nrow = length(instrument_ids), ncol = length(pulses_posix), dimnames = dimnames(price))
  )
  bars_by_id <- stats::setNames(lapply(instrument_ids, function(id) {
    data.frame(
      instrument_id = id,
      ts_utc = pulses_posix,
      open = as.numeric(bars_mat$open[id, ]),
      high = as.numeric(bars_mat$high[id, ]),
      low = as.numeric(bars_mat$low[id, ]),
      close = as.numeric(bars_mat$close[id, ]),
      volume = as.numeric(bars_mat$volume[id, ]),
      gap_type = "",
      is_synthetic = FALSE,
      stringsAsFactors = FALSE
    )
  }), instrument_ids)

  ledgr:::ledgr_execution_spec(
    run_id = run_id,
    instrument_ids = instrument_ids,
    strategy_fn = strategy,
    strategy_params = list(),
    strategy_call_signature = ledgr:::ledgr_strategy_signature(strategy),
    strategy_is_functional = TRUE,
    pulses_posix = pulses_posix,
    pulses_iso = pulses_iso,
    start_idx = 1L,
    max_pulses = Inf,
    checkpoint_every = 0L,
    telemetry_stride = 0L,
    state = list(cash = cash, positions = positions[instrument_ids]),
    state_prev = NULL,
    bars_by_id = bars_by_id,
    bars_mat = bars_mat,
    static_bars_views = NULL,
    static_feature_views = NULL,
    feature_defs = list(),
    runtime_projection = ledgr:::ledgr_projection_from_feature_matrix(
      feature_matrix = list(),
      universe = instrument_ids,
      pulses_posix = pulses_posix
    ),
    active_alias_map = NULL,
    risk_plan = risk_plan,
    cost_resolver = cost_resolver,
    event_seq_start = 1L,
    telemetry = ledgr:::ledgr_sweep_telemetry_env(),
    seed = 123L,
    event_mode = "buffered",
    use_fast_context = TRUE,
    compiled_accounting_model = NULL
  )
}

testthat::test_that("pulse plan resolves same-pulse fills before emitting events", {
  events_written <- 0L
  resolver_seen_events <- integer()
  base_resolver <- ledgr_test_cost_resolver(spread_bps = 0, commission_fixed = 0)
  cost_resolver <- function(proposal, fill_context) {
    resolver_seen_events <<- c(resolver_seen_events, events_written)
    base_resolver(proposal, fill_context)
  }
  strategy <- function(ctx, params) {
    if (identical(ctx$ts_utc, "2024-01-01T00:00:00Z")) {
      targets <- ctx$flat()
      targets["AAA"] <- 1
      targets["BBB"] <- 1
      return(targets)
    }
    ctx$hold()
  }
  handler <- ledgr:::ledgr_memory_output_handler("risk-fold-plan-order")
  write_fill_events <- handler$write_fill_events
  handler$write_fill_events <- function(...) {
    events_written <<- events_written + 1L
    write_fill_events(...)
  }

  execution <- ledgr_risk_fold_test_execution(
    strategy = strategy,
    cost_resolver = cost_resolver,
    run_id = "risk-fold-plan-order"
  )
  ledgr:::ledgr_execute_fold(execution, handler)

  events <- handler$events()
  testthat::expect_identical(resolver_seen_events, c(0L, 0L))
  testthat::expect_identical(events_written, 2L)
  testthat::expect_identical(as.character(events$instrument_id), c("AAA", "BBB"))
  testthat::expect_identical(as.integer(events$event_seq), 1:2)
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0281] the envelope calls five typed stage packets in order", {
  stage_order <- character()
  stage_packets <- list()
  capture_stage <- function(name, fn) {
    force(name)
    force(fn)
    function(...) {
      value <- fn(...)
      stage_order <<- c(stage_order, name)
      stage_packets[[name]] <<- value
      value
    }
  }
  originals <- list(
    observe = ledgr:::ledgr_fold_stage_observe_settle,
    decide = ledgr:::ledgr_fold_stage_decide,
    plan = ledgr:::ledgr_fold_stage_plan,
    apply = ledgr:::ledgr_fold_stage_apply,
    commit = ledgr:::ledgr_fold_stage_commit
  )
  testthat::local_mocked_bindings(
    ledgr_fold_stage_observe_settle = capture_stage("observe", originals$observe),
    ledgr_fold_stage_decide = capture_stage("decide", originals$decide),
    ledgr_fold_stage_plan = capture_stage("plan", originals$plan),
    ledgr_fold_stage_apply = capture_stage("apply", originals$apply),
    ledgr_fold_stage_commit = capture_stage("commit", originals$commit),
    .package = "ledgr"
  )
  execution <- ledgr_risk_fold_test_execution(
    strategy = function(ctx, params) ctx$hold(),
    cost_resolver = ledgr_test_cost_resolver(0, 0),
    run_id = "phase-packet-contract"
  )
  ledgr:::ledgr_execute_fold(
    execution,
    ledgr:::ledgr_memory_output_handler("phase-packet-contract")
  )
  expected_names <- list(
    observe = c(
      "pulse_idx", "ts", "ts_iso", "context_ids", "context_position_idx",
      "positions_snapshot", "positions_value", "availability_view",
      "valuation", "members", "history_bars", "sample_start", "t_feats",
      "t_bars"
    ),
    decide = c(
      "strategy_targets", "targets", "state_update", "sample_start",
      "t_ctx", "t_strat", "t_target"
    ),
    plan = c(
      "pulse_plan", "accounting_events", "diagnostic_segments",
      "sample_start", "t_target", "t_fill"
    ),
    apply = c("sample_start", "t_event", "t_state"),
    commit = "continue"
  )
  has_data_frame <- function(x) {
    is.data.frame(x) ||
      (is.list(x) && any(vapply(x, has_data_frame, logical(1L))))
  }
  testthat::expect_identical(
    stage_order,
    rep(c("observe", "decide", "plan", "apply", "commit"), 3L)
  )
  for (name in names(expected_names)) {
    testthat::expect_true(is.list(stage_packets[[name]]), info = name)
    testthat::expect_identical(names(stage_packets[[name]]), expected_names[[name]])
    testthat::expect_false(has_data_frame(stage_packets[[name]]), info = name)
  }
})

testthat::test_that("[LTB-0136] the fold flushes its handler once per pulse", {
  strategy <- function(ctx, params) {
    if (identical(ctx$ts_utc, "2024-01-01T00:00:00Z")) {
      targets <- ctx$flat()
      targets[c("AAA", "BBB")] <- 1
      return(targets)
    }
    ctx$hold()
  }
  handler <- ledgr:::ledgr_memory_output_handler("pulse-flush-counter")
  writes <- 0L
  flushes <- 0L
  original_write <- handler$write_fill_events
  original_flush <- handler$flush_pulse_events
  handler$write_fill_events <- function(...) {
    writes <<- writes + 1L
    original_write(...)
  }
  handler$flush_pulse_events <- function() {
    flushes <<- flushes + 1L
    original_flush()
  }

  execution <- ledgr_risk_fold_test_execution(
    strategy = strategy,
    cost_resolver = ledgr_test_cost_resolver(
      spread_bps = 0,
      commission_fixed = 0
    ),
    run_id = "pulse-flush-counter"
  )
  ledgr:::ledgr_execute_fold(execution, handler)

  testthat::expect_identical(writes, 2L)
  testthat::expect_identical(flushes, 3L)
  testthat::expect_identical(handler$events()$instrument_id, c("AAA", "BBB"))

  final_strategy <- function(ctx, params) {
    if (identical(ctx$ts_utc, "2024-01-02T00:00:00Z")) {
      targets <- ctx$flat()
      targets[c("AAA", "BBB")] <- 1
      return(targets)
    }
    ctx$hold()
  }
  final_handler <- ledgr:::ledgr_memory_output_handler("pulse-final-flush")
  final_execution <- ledgr_risk_fold_test_execution(
    strategy = final_strategy,
    cost_resolver = ledgr_test_cost_resolver(
      spread_bps = 0,
      commission_fixed = 0
    ),
    run_id = "pulse-final-flush"
  )
  final_execution$max_pulses <- 2L
  ledgr:::ledgr_execute_fold(final_execution, final_handler)
  testthat::expect_identical(
    final_handler$events()$instrument_id,
    c("AAA", "BBB")
  )
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0137] a failed pulse publishes no partial fill rows", {
  pulses <- as.POSIXct("2024-01-01", tz = "UTC") + 86400 * 0:2
  bars <- do.call(rbind, lapply(c("AAA", "BBB"), function(instrument_id) {
    data.frame(
      ts_utc = pulses,
      instrument_id = instrument_id,
      open = c(10, 11, 12),
      high = c(10, 11, 12),
      low = c(10, 11, 12),
      close = c(10, 11, 12),
      volume = 1000,
      stringsAsFactors = FALSE
    )
  }))
  snapshot <- ledgr_snapshot_from_df(bars)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets[] <- params$qty
    targets
  }
  experiment <- ledgr_experiment(
    snapshot,
    strategy,
    cost_model = ledgr_cost_zero()
  )

  original_apply <- ledgr:::ledgr_lot_apply_fill
  calls <- 0L
  testthat::local_mocked_bindings(
    ledgr_lot_apply_fill = function(...) {
      calls <<- calls + 1L
      if (calls == 2L) {
        rlang::abort("injected second-fill failure", class = "ledgr_test_fill_failure")
      }
      original_apply(...)
    },
    .package = "ledgr"
  )

  testthat::expect_error(
    ledgr_run(
      experiment,
      params = list(qty = 1),
      run_id = "pulse-atomic-failure",
      seed = 1L
    ),
    class = "ledgr_test_fill_failure"
  )
  con <- get_connection(snapshot)
  run_row <- DBI::dbGetQuery(
    con,
    "SELECT status FROM runs WHERE run_id = 'pulse-atomic-failure'"
  )
  event_count <- DBI::dbGetQuery(
    con,
    "SELECT COUNT(*) AS n FROM ledger_events WHERE run_id = 'pulse-atomic-failure'"
  )$n[[1L]]
  testthat::expect_identical(run_row$status, "FAILED")
  testthat::expect_identical(as.integer(event_count), 0L)

  calls <- 0L
  mixed <- ledgr_sweep(
    experiment,
    ledgr_param_grid(failed = list(qty = 1), completed = list(qty = 2)),
    seed = 1L
  )
  reference <- ledgr_sweep(
    experiment,
    ledgr_param_grid(completed = list(qty = 2)),
    seed = 1L
  )
  testthat::expect_identical(mixed$status, c("FAILED", "DONE"))
  testthat::expect_identical(mixed$error_class[[1L]], "ledgr_test_fill_failure")
  stable_columns <- c(
    "status", "completion_json", "final_equity", "total_return",
    "annualized_return", "volatility", "sharpe_ratio", "max_drawdown",
    "n_trades", "win_rate", "avg_trade", "time_in_market", "params",
    "feature_params", "warnings", "feature_fingerprints", "risk_chain_hash"
  )
  for (name in stable_columns) {
    testthat::expect_identical(
      mixed[[name]][[2L]],
      reference[[name]][[1L]],
      info = name
    )
  }
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0280] handler faults preserve fold atomicity in both data modes", {
  pulses <- as.POSIXct("2024-01-01 16:00:00", tz = "UTC") + 86400 * 0:2
  bars <- ledgr_test_make_bars(c("AAA", "BBB"), pulses)
  sessions <- ledgr_facts_sessions(
    data.frame(
      session_date = as.Date(pulses),
      status = "open",
      session_open = "09:30:00",
      session_close = "16:00:00",
      knowledge_time = pulses - 86400,
      stringsAsFactors = FALSE
    ),
    venue_id = "XNYS"
  )
  snapshots <- list(
    dense = ledgr_snapshot_from_df(
      bars,
      db_path = tempfile(fileext = ".duckdb")
    ),
    availability = ledgr_snapshot_from_df(
      bars,
      instruments_df = data.frame(
        instrument_id = c("AAA", "BBB"),
        stringsAsFactors = FALSE
      ),
      facts = ledgr_facts(sessions),
      price_basis = "split_adjusted",
      db_path = tempfile(fileext = ".duckdb")
    )
  )
  on.exit(lapply(snapshots, ledgr_snapshot_close), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets[] <- 1
    targets
  }
  experiments <- lapply(snapshots, function(snapshot) {
    ledgr_experiment(
      snapshot,
      strategy,
      cost_model = ledgr_cost_zero(),
      execution_mode = "db_live"
    )
  })
  fault_factory <- function(original_factory, method, fail_at = 2L) {
    force(original_factory)
    force(method)
    force(fail_at)
    function(...) {
      handler <- original_factory(...)
      original_method <- handler[[method]]
      calls <- 0L
      handler[[method]] <- function(...) {
        calls <<- calls + 1L
        if (calls == fail_at) {
          rlang::abort(
            paste("injected", method, "failure"),
            class = "ledgr_test_handler_failure"
          )
        }
        original_method(...)
      }
      handler
    }
  }

  persistent_factory <- ledgr:::ledgr_persistent_output_handler
  for (mode in names(experiments)) {
    run_id <- paste0("handler-fault-", mode)
    testthat::expect_error(
      testthat::with_mocked_bindings(
        ledgr_run(experiments[[mode]], run_id = run_id, seed = 1L),
        ledgr_persistent_output_handler = fault_factory(
          persistent_factory,
          "write_fill_events"
        ),
        .package = "ledgr"
      ),
      class = "ledgr_test_handler_failure",
      info = mode
    )
    con <- get_connection(snapshots[[mode]])
    testthat::expect_identical(
      as.integer(DBI::dbGetQuery(
        con,
        "SELECT COUNT(*) AS n FROM ledger_events WHERE run_id = ?",
        params = list(run_id)
      )$n[[1L]]),
      0L,
      info = mode
    )
    if (identical(mode, "availability")) {
      testthat::expect_true(DBI::dbGetQuery(
        con,
        paste0(
          "SELECT COUNT(*) AS n FROM run_diagnostics ",
          "WHERE run_id = ? AND outcome = 'error'"
        ),
        params = list(run_id)
      )$n[[1L]] > 0)
    }
  }

  memory_factory <- ledgr:::ledgr_memory_output_handler
  for (method in c("write_fill_events", "record_accounting_fact")) {
    for (mode in names(experiments)) {
      sweep <- testthat::with_mocked_bindings(
        ledgr_sweep(
          experiments[[mode]],
          ledgr_param_grid(failed = list()),
          seed = 1L
        ),
        ledgr_memory_output_handler = fault_factory(memory_factory, method),
        .package = "ledgr"
      )
      testthat::expect_identical(sweep$status, "FAILED", info = paste(method, mode))
      testthat::expect_identical(
        sweep$error_class[[1L]],
        "ledgr_test_handler_failure",
        info = paste(method, mode)
      )
      testthat::expect_true(
        is.na(sweep$final_equity[[1L]]),
        info = paste(method, mode)
      )
    }
  }
})

testthat::test_that("no-op feasibility hook does not sequentially reject same-pulse rebalances", {
  cost_resolver <- ledgr_test_cost_resolver(
    spread_bps = 0,
    commission_fixed = 0
  )
  strategy <- function(ctx, params) {
    if (identical(ctx$ts_utc, "2024-01-01T00:00:00Z")) {
      targets <- ctx$flat()
      targets["AAA"] <- 2
      return(targets)
    }
    if (identical(ctx$ts_utc, "2024-01-02T00:00:00Z")) {
      targets <- ctx$flat()
      targets["BBB"] <- 1
      targets["AAA"] <- 0
      return(targets)
    }
    ctx$hold()
  }
  handler <- ledgr:::ledgr_memory_output_handler("risk-fold-rebalance")
  execution <- ledgr_risk_fold_test_execution(
    strategy = strategy,
    cost_resolver = cost_resolver,
    run_id = "risk-fold-rebalance",
    instrument_ids = c("BBB", "AAA"),
    cash = 0,
    positions = c(BBB = 0, AAA = 0)
  )

  ledgr:::ledgr_execute_fold(execution, handler)
  events <- handler$events()

  testthat::expect_identical(as.character(events$instrument_id), c("AAA", "BBB", "AAA"))
  testthat::expect_identical(as.character(events$side), c("BUY", "BUY", "SELL"))
  testthat::expect_equal(sum(attr(events, "ledgr_event_cash_delta")), -20)
  position_delta <- attr(events, "ledgr_event_position_delta")
  final_position <- tapply(position_delta, events$instrument_id, sum)
  testthat::expect_equal(as.numeric(final_position[c("BBB", "AAA")]), c(1, 0))
})

testthat::test_that("compiled risk plan transforms targets before timing cost and event writes", {
  resolver_calls <- 0L
  resolver_qty <- numeric()
  base_resolver <- ledgr_test_cost_resolver(spread_bps = 0, commission_fixed = 0)
  cost_resolver <- function(proposal, fill_context) {
    resolver_calls <<- resolver_calls + 1L
    resolver_qty <<- c(resolver_qty, proposal$qty)
    base_resolver(proposal, fill_context)
  }
  strategy <- function(ctx, params) {
    if (identical(ctx$ts_utc, "2024-01-01T00:00:00Z")) {
      targets <- ctx$flat()
      targets["AAA"] <- 50
      return(targets)
    }
    ctx$hold()
  }
  risk_plan <- ledgr:::ledgr_risk_plan_compile(
    ledgr_risk_max_weight(0.1),
    params = list()
  )
  handler <- ledgr:::ledgr_memory_output_handler("risk-fold-risk-before-cost")
  execution <- ledgr_risk_fold_test_execution(
    strategy = strategy,
    cost_resolver = cost_resolver,
    risk_plan = risk_plan,
    run_id = "risk-fold-risk-before-cost",
    price = rbind(
      AAA = c(10, 10, 10),
      BBB = c(20, 20, 20)
    )
  )

  ledgr:::ledgr_execute_fold(execution, handler)
  events <- handler$events()

  testthat::expect_identical(resolver_calls, 1L)
  testthat::expect_equal(resolver_qty, 10)
  testthat::expect_equal(events$qty, 10)
})

testthat::test_that("long-only risk step maps negative targets to zero", {
  cost_resolver <- ledgr_test_cost_resolver(
    spread_bps = 0,
    commission_fixed = 0
  )
  strategy <- function(ctx, params) {
    if (identical(ctx$ts_utc, "2024-01-01T00:00:00Z")) {
      targets <- ctx$flat()
      targets["AAA"] <- -5
      targets["BBB"] <- 1
      return(targets)
    }
    ctx$hold()
  }
  risk_plan <- ledgr:::ledgr_risk_plan_compile(
    ledgr_risk_long_only(),
    params = list()
  )
  handler <- ledgr:::ledgr_memory_output_handler("risk-fold-long-only")
  execution <- ledgr_risk_fold_test_execution(
    strategy = strategy,
    cost_resolver = cost_resolver,
    risk_plan = risk_plan,
    run_id = "risk-fold-long-only"
  )

  ledgr:::ledgr_execute_fold(execution, handler)
  events <- handler$events()

  testthat::expect_identical(as.character(events$instrument_id), "BBB")
  testthat::expect_equal(events$qty, 1)
})

testthat::test_that("long-only risk step leaves compliant targets unchanged", {
  out <- ledgr:::ledgr_apply_risk_step_long_only(
    c(AAA = 5, BBB = 0),
    list(),
    list()
  )

  testthat::expect_equal(out, c(AAA = 5, BBB = 0))
})

testthat::test_that("max-weight risk step caps absolute target exposure", {
  cost_resolver <- ledgr_test_cost_resolver(
    spread_bps = 0,
    commission_fixed = 0
  )
  strategy <- function(ctx, params) {
    if (identical(ctx$ts_utc, "2024-01-01T00:00:00Z")) {
      targets <- ctx$flat()
      targets["AAA"] <- 50
      targets["BBB"] <- 20
      return(targets)
    }
    ctx$hold()
  }
  risk_plan <- ledgr:::ledgr_risk_plan_compile(
    ledgr_risk_max_weight(0.1),
    params = list()
  )
  handler <- ledgr:::ledgr_memory_output_handler("risk-fold-max-weight")
  execution <- ledgr_risk_fold_test_execution(
    strategy = strategy,
    cost_resolver = cost_resolver,
    risk_plan = risk_plan,
    run_id = "risk-fold-max-weight",
    price = rbind(
      AAA = c(10, 10, 10),
      BBB = c(20, 20, 20)
    )
  )

  ledgr:::ledgr_execute_fold(execution, handler)
  events <- handler$events()

  testthat::expect_identical(as.character(events$instrument_id), c("AAA", "BBB"))
  testthat::expect_equal(events$qty, c(10, 5))
})

testthat::test_that("max-weight preserves negative target direction", {
  out <- ledgr:::ledgr_apply_risk_step_max_weight(
    c(AAA = -50),
    list(args = list(max_weight = 0.1)),
    list(equity = 1000, vec = list(close = c(AAA = 10)))
  )

  testthat::expect_equal(out, c(AAA = -10))
})

testthat::test_that("max-weight zeros nonzero targets when equity is zero", {
  out <- ledgr:::ledgr_apply_risk_step_max_weight(
    c(AAA = 50, BBB = 0),
    list(args = list(max_weight = 0.1)),
    list(equity = 0, vec = list(close = c(AAA = 10, BBB = NA_real_)))
  )

  testthat::expect_equal(out, c(AAA = 0, BBB = 0))
})

testthat::test_that("risk chains apply built-in steps in order", {
  cost_resolver <- ledgr_test_cost_resolver(
    spread_bps = 0,
    commission_fixed = 0
  )
  strategy <- function(ctx, params) {
    if (identical(ctx$ts_utc, "2024-01-01T00:00:00Z")) {
      targets <- ctx$flat()
      targets["AAA"] <- -50
      targets["BBB"] <- 20
      return(targets)
    }
    ctx$hold()
  }
  risk_plan <- ledgr:::ledgr_risk_plan_compile(
    ledgr_risk_chain(
      ledgr_risk_long_only(),
      ledgr_risk_max_weight(0.1)
    ),
    params = list()
  )
  handler <- ledgr:::ledgr_memory_output_handler("risk-fold-chain")
  execution <- ledgr_risk_fold_test_execution(
    strategy = strategy,
    cost_resolver = cost_resolver,
    risk_plan = risk_plan,
    run_id = "risk-fold-chain",
    price = rbind(
      AAA = c(10, 10, 10),
      BBB = c(20, 20, 20)
    )
  )

  ledgr:::ledgr_execute_fold(execution, handler)
  events <- handler$events()

  testthat::expect_identical(as.character(events$instrument_id), "BBB")
  testthat::expect_equal(events$qty, 5)
})

testthat::test_that("max-weight fails closed when nonzero targets need invalid decision prices", {
  targets <- c(AAA = 1, BBB = 0)
  ctx <- list(
    universe = c("AAA", "BBB"),
    equity = 1000,
    vec = list(close = c(NA_real_, NA_real_))
  )
  risk_plan <- ledgr:::ledgr_risk_plan_compile(
    ledgr_risk_max_weight(0.1),
    params = list()
  )

  testthat::expect_error(
    ledgr:::ledgr_apply_risk_plan(targets, risk_plan, ctx),
    class = "ledgr_invalid_risk_context"
  )
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("public run applies long-only risk step", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2024-01-01") + 0:1)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    if (identical(ctx$ts_utc, "2024-01-01T00:00:00Z")) {
      targets <- ctx$flat()
      targets["AAA"] <- -10
      return(targets)
    }
    ctx$hold()
  }
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    risk_chain = ledgr_risk_long_only(),
    cost_model = ledgr_cost_zero()
  )

  bt <- ledgr_run(exp, run_id = "risk-long-only-run")
  on.exit(close(bt), add = TRUE)
  ledger <- ledgr_results(bt, "ledger")

  testthat::expect_identical(nrow(ledger), 0L)
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("public sweep applies parameterized max-weight risk step", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2024-01-01") + 0:3)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    if (identical(ctx$ts_utc, "2024-01-01T00:00:00Z")) {
      targets <- ctx$flat()
      targets["AAA"] <- 1000
      return(targets)
    }
    ctx$hold()
  }
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    risk_chain = ledgr_risk_max_weight(ledgr_param("cap")),
    cost_model = ledgr_cost_zero()
  )
  expected_risk <- ledgr_risk_max_weight(ledgr_param("cap"))
  grid <- ledgr_param_grid(
    low = list(cap = 0.1),
    high = list(cap = 0.2)
  )

  out <- ledgr_sweep(exp, grid, seed = 123L)

  testthat::expect_identical(as.character(out$status), c("DONE", "DONE"))
  testthat::expect_gt(out$final_equity[[2]], out$final_equity[[1]])
  testthat::expect_false("failure_type" %in% names(out))
  testthat::expect_identical(
    out$risk_chain_hash,
    rep(ledgr:::ledgr_risk_chain_hash(expected_risk), 2L)
  )
  risk_plan_json <- ledgr:::ledgr_risk_plan_json(expected_risk)
  testthat::expect_true(all(vapply(out$provenance, function(provenance) {
    identical(provenance$risk_chain_hash, ledgr:::ledgr_risk_chain_hash(expected_risk)) &&
      identical(provenance$risk_plan_json, risk_plan_json)
  }, logical(1))))
})

# ledgr-test-profile: heavy_protocol
testthat::test_that("risk failures are captured as sweep candidate failures", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2024-01-01") + 0:3)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    if (identical(ctx$ts_utc, "2024-01-01T00:00:00Z")) {
      targets <- ctx$flat()
      targets["AAA"] <- 1
      return(targets)
    }
    ctx$hold()
  }
  risk <- ledgr_risk_max_weight(ledgr_param("cap"))
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    risk_chain = risk,
    cost_model = ledgr_cost_zero()
  )
  grid <- ledgr_param_grid(
    ok = list(cap = 0.1),
    bad = list(cap = 2)
  )

  out <- ledgr_sweep(exp, grid, seed = 123L, stop_on_error = FALSE)

  testthat::expect_identical(as.character(out$candidate_id), c("ok", "bad"))
  testthat::expect_identical(as.character(out$status), c("DONE", "FAILED"))
  testthat::expect_identical(out$error_class[[2]], "ledgr_invalid_risk_model")
  testthat::expect_match(out$error_msg[[2]], "`max_weight`", fixed = TRUE)
  testthat::expect_false("failure_type" %in% names(out))
  testthat::expect_identical(
    out$risk_chain_hash,
    rep(ledgr:::ledgr_risk_chain_hash(risk), 2L)
  )
  testthat::expect_true(all(vapply(out$provenance, function(provenance) {
    identical(provenance$risk_plan_json, ledgr:::ledgr_risk_plan_json(risk))
  }, logical(1))))
  testthat::expect_error(
    ledgr_sweep(exp, grid, seed = 123L, stop_on_error = TRUE),
    class = "ledgr_invalid_risk_model"
  )
})

testthat::test_that("post-risk target validation has a distinct condition class", {
  testthat::expect_error(
    ledgr:::ledgr_validate_strategy_targets(c(AAA = 1), c("AAA", "BBB")),
    class = "ledgr_invalid_strategy_result"
  )
  testthat::expect_error(
    ledgr:::ledgr_validate_post_risk_targets(c(AAA = 1), c("AAA", "BBB")),
    class = "ledgr_invalid_post_risk_targets"
  )
  error <- testthat::capture_error(
    ledgr:::ledgr_validate_post_risk_targets(c(AAA = 1), c("AAA", "BBB"))
  )
  testthat::expect_s3_class(error$parent, "ledgr_invalid_strategy_result")
})

testthat::test_that("risk plan parameter references resolve once before fold execution", {
  risk_plan <- ledgr:::ledgr_risk_plan_compile(
    ledgr_risk_max_weight(ledgr_param("cap")),
    params = list(cap = 0.4)
  )

  testthat::expect_s3_class(risk_plan, "ledgr_compiled_risk_plan")
  testthat::expect_identical(length(risk_plan$steps), 1L)
  testthat::expect_identical(risk_plan$steps[[1L]]$args$max_weight, 0.4)
  testthat::expect_error(
    ledgr:::ledgr_risk_plan_compile(
      ledgr_risk_max_weight(ledgr_param("missing_cap")),
      params = list()
    ),
    class = "ledgr_risk_plan_parameter_missing"
  )
})

testthat::test_that("private pulse-plan helpers are not exported", {
  exports <- getNamespaceExports("ledgr")
  testthat::expect_false("ledgr_fold_warn_final_bar_no_fill" %in% exports)
  testthat::expect_false("ledgr_fold_build_pulse_plan" %in% exports)
  testthat::expect_false("ledgr_fold_apply_net_feasibility_noop" %in% exports)
  testthat::expect_false("ledgr_fold_pulse_plan_fill_intents" %in% exports)
})
