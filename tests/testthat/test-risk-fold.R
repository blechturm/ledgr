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

testthat::test_that("public run applies long-only risk step", {
  bars <- ledgr_test_make_bars("AAA", as.Date("2024-01-01") + 0:3)
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
