ledgr_risk_fold_test_execution <- function(strategy,
                                           cost_resolver,
                                           run_id = "risk-fold-test",
                                           instrument_ids = c("AAA", "BBB"),
                                           cash = 1000,
                                           positions = stats::setNames(c(0, 0), c("AAA", "BBB"))) {
  pulses_posix <- as.POSIXct(
    c("2024-01-01 00:00:00", "2024-01-02 00:00:00", "2024-01-03 00:00:00"),
    tz = "UTC"
  )
  pulses_iso <- vapply(pulses_posix, ledgr:::ledgr_normalize_ts_utc, character(1))
  price <- rbind(
    AAA = c(10, 11, 12),
    BBB = c(20, 21, 22)
  )
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
  cost_resolver <- function(proposal, fill_context) {
    resolver_seen_events <<- c(resolver_seen_events, events_written)
    ledgr:::ledgr_default_cost_resolve(
      proposal = proposal,
      fill_context = fill_context,
      spread_bps = 0,
      commission_fixed = 0
    )
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
  cost_resolver <- ledgr:::ledgr_cost_spread_commission_internal(
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

testthat::test_that("private pulse-plan helpers are not exported", {
  exports <- getNamespaceExports("ledgr")
  testthat::expect_false("ledgr_fold_warn_final_bar_no_fill" %in% exports)
  testthat::expect_false("ledgr_fold_build_pulse_plan" %in% exports)
  testthat::expect_false("ledgr_fold_apply_net_feasibility_noop" %in% exports)
  testthat::expect_false("ledgr_fold_pulse_plan_fill_intents" %in% exports)
})
