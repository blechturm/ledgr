ledgr_expect_lot_states_equivalent <- function(actual, expected) {
  ids <- unique(c(actual$instrument_ids, expected$instrument_ids))
  for (id in ids) {
    testthat::expect_identical(
      ledgr:::ledgr_lot_values(actual, id),
      ledgr:::ledgr_lot_values(expected, id)
    )
  }
  testthat::expect_identical(actual$net_by_inst[ids], expected$net_by_inst[ids])
  testthat::expect_identical(
    actual$cost_basis_by_inst[ids],
    expected$cost_basis_by_inst[ids]
  )
  testthat::expect_identical(actual$total_cost_basis, expected$total_cost_basis)
  testthat::expect_identical(actual$realized_pnl, expected$realized_pnl)
  testthat::expect_identical(actual$realized_comp, expected$realized_comp)
}

ledgr_test_execution_spec <- function(...) {
  pulses_posix <- as.POSIXct(
    c("2024-01-01 00:00:00", "2024-01-02 00:00:00"),
    tz = "UTC"
  )
  pulses_iso <- vapply(pulses_posix, ledgr:::ledgr_normalize_ts_utc, character(1))
  instrument_ids <- c("AAA", "BBB")
  close <- matrix(
    c(100, 101, 200, 201),
    nrow = 2L,
    dimnames = list(instrument_ids, pulses_iso)
  )
  bars_mat <- list(
    open = close,
    high = close,
    low = close,
    close = close,
    volume = close * 0,
    gap_type = matrix("", nrow = 2L, ncol = 2L, dimnames = dimnames(close)),
    is_synthetic = matrix(FALSE, nrow = 2L, ncol = 2L, dimnames = dimnames(close))
  )
  bars_by_id <- stats::setNames(lapply(instrument_ids, function(id) {
    data.frame(
      instrument_id = id,
      ts_utc = pulses_posix,
      open = close[id, ],
      high = close[id, ],
      low = close[id, ],
      close = close[id, ],
      volume = 0,
      gap_type = "",
      is_synthetic = FALSE,
      stringsAsFactors = FALSE
    )
  }), instrument_ids)
  strategy <- function(ctx, params) ctx$flat()

  args <- modifyList(
    list(
      run_id = "execution-spec-test",
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
      state = list(cash = 1000, positions = stats::setNames(c(0, 0), instrument_ids)),
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
      risk_plan = NULL,
      cost_resolver = ledgr_test_cost_resolver(
        spread_bps = 0,
        commission_fixed = 0
      ),
      event_seq_start = 1L,
      telemetry = ledgr:::ledgr_sweep_telemetry_env(),
      seed = 123L,
      event_mode = "buffered",
      use_fast_context = TRUE,
      compiled_accounting_model = NULL
    ),
    list(...),
    keep.null = TRUE
  )
  do.call(ledgr:::ledgr_execution_spec, args)
}

ledgr_compiled_spot_fifo_test_run <- function(compiled_accounting_model = NULL) {
  pulses_posix <- as.POSIXct(
    c("2024-01-01 00:00:00", "2024-01-02 00:00:00", "2024-01-03 00:00:00", "2024-01-04 00:00:00"),
    tz = "UTC"
  )
  pulses_iso <- vapply(pulses_posix, ledgr:::ledgr_normalize_ts_utc, character(1))
  instrument_ids <- "AAA"
  close <- matrix(
    c(10, 11, 12, 13),
    nrow = 1L,
    dimnames = list(instrument_ids, pulses_iso)
  )
  bars_mat <- list(
    open = close,
    high = close + 0.5,
    low = close - 0.5,
    close = close,
    volume = matrix(1000, nrow = 1L, ncol = length(pulses_posix), dimnames = dimnames(close)),
    gap_type = matrix("", nrow = 1L, ncol = length(pulses_posix), dimnames = dimnames(close)),
    is_synthetic = matrix(FALSE, nrow = 1L, ncol = length(pulses_posix), dimnames = dimnames(close))
  )
  bars_by_id <- list(
    AAA = data.frame(
      instrument_id = "AAA",
      ts_utc = pulses_posix,
      open = as.numeric(bars_mat$open["AAA", ]),
      high = as.numeric(bars_mat$high["AAA", ]),
      low = as.numeric(bars_mat$low["AAA", ]),
      close = as.numeric(bars_mat$close["AAA", ]),
      volume = as.numeric(bars_mat$volume["AAA", ]),
      gap_type = "",
      is_synthetic = FALSE,
      stringsAsFactors = FALSE
    )
  )
  target_path <- list(
    c(AAA = -1),
    c(AAA = 1),
    c(AAA = 1),
    c(AAA = 1)
  )
  opening_positions <- c(AAA = 2)
  opening_cost_basis <- c(AAA = 10)
  opening_rows <- ledgr:::ledgr_opening_position_event_rows(
    run_id = "compiled-spot-fifo-parity",
    ts_utc = pulses_posix[[1L]],
    positions = opening_positions,
    cost_basis = opening_cost_basis,
    event_seq_start = 1L
  )
  pulse_idx <- 0L
  strategy <- function(ctx, params) {
    pulse_idx <<- pulse_idx + 1L
    target_path[[pulse_idx]]
  }
  spec <- ledgr:::ledgr_execution_spec(
    run_id = "compiled-spot-fifo-parity",
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
    state = list(
      cash = 1000,
      positions = opening_positions,
      lot_state = ledgr:::ledgr_lot_state_from_opening(
        instrument_ids = instrument_ids,
        positions = opening_positions,
        cost_basis = opening_cost_basis
      )
    ),
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
    risk_plan = NULL,
    cost_resolver = ledgr_test_cost_resolver(
      spread_bps = 0,
      commission_fixed = 0.25
    ),
    event_seq_start = as.integer(nrow(opening_rows)) + 1L,
    telemetry = ledgr:::ledgr_sweep_telemetry_env(),
    seed = 123L,
    event_mode = "buffered",
    use_fast_context = TRUE,
    compiled_accounting_model = compiled_accounting_model
  )
  handler <- ledgr:::ledgr_memory_output_handler("compiled-spot-fifo-parity")
  handler$append_event_rows(opening_rows)
  fold <- ledgr:::ledgr_execute_fold(spec, handler)
  metric_kernel <- ledgr:::ledgr_metric_kernel(context = ledgr_metric_context(), pulses = pulses_posix)
  list(
    fold = fold,
    handler = handler,
    pulses_posix = pulses_posix,
    events = handler$events(),
    typed_events = handler$typed_events(),
    inline_summary = handler$inline_summary("compiled-spot-fifo-parity", metric_kernel),
    reconstructed = ledgr:::ledgr_sweep_summary_from_ordered_events(
      events = handler$typed_events(),
      pulses_posix = pulses_posix,
      close_mat = bars_mat$close,
      initial_cash = 1000,
      instrument_ids = instrument_ids,
      run_id = "compiled-spot-fifo-parity",
      metric_kernel = metric_kernel
    )
  )
}

ledgr_compiled_spot_fifo_multi_test_run <- function(compiled_accounting_model = NULL) {
  pulses_posix <- as.POSIXct(
    c("2024-02-01 00:00:00", "2024-02-02 00:00:00", "2024-02-03 00:00:00", "2024-02-04 00:00:00"),
    tz = "UTC"
  )
  pulses_iso <- vapply(pulses_posix, ledgr:::ledgr_normalize_ts_utc, character(1))
  instrument_ids <- c("AAA", "BBB", "CCC")
  close <- matrix(
    c(
      10, 11, 12, 13,
      20, 19, 18, 17,
      30, 31, 32, 33
    ),
    nrow = 3L,
    byrow = TRUE,
    dimnames = list(instrument_ids, pulses_iso)
  )
  bars_mat <- list(
    open = close,
    high = close + 0.5,
    low = close - 0.5,
    close = close,
    volume = matrix(1000, nrow = 3L, ncol = length(pulses_posix), dimnames = dimnames(close)),
    gap_type = matrix("", nrow = 3L, ncol = length(pulses_posix), dimnames = dimnames(close)),
    is_synthetic = matrix(FALSE, nrow = 3L, ncol = length(pulses_posix), dimnames = dimnames(close))
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
  opening_positions <- c(AAA = 2, BBB = 0, CCC = -1)
  opening_cost_basis <- c(AAA = 10, CCC = 30)
  opening_rows <- ledgr:::ledgr_opening_position_event_rows(
    run_id = "compiled-spot-fifo-multi-parity",
    ts_utc = pulses_posix[[1L]],
    positions = opening_positions,
    cost_basis = opening_cost_basis,
    event_seq_start = 1L
  )
  target_path <- list(
    c(AAA = -1, BBB = 2, CCC = 0),
    c(AAA = 1, BBB = -1, CCC = 2),
    c(AAA = 1, BBB = -1, CCC = 2),
    c(AAA = 1, BBB = -1, CCC = 2)
  )
  pulse_idx <- 0L
  strategy <- function(ctx, params) {
    pulse_idx <<- pulse_idx + 1L
    target_path[[pulse_idx]]
  }
  spec <- ledgr:::ledgr_execution_spec(
    run_id = "compiled-spot-fifo-multi-parity",
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
    state = list(
      cash = 1000,
      positions = opening_positions,
      lot_state = ledgr:::ledgr_lot_state_from_opening(
        instrument_ids = instrument_ids,
        positions = opening_positions,
        cost_basis = opening_cost_basis
      )
    ),
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
    risk_plan = NULL,
    cost_resolver = ledgr_test_cost_resolver(
      spread_bps = 0,
      commission_fixed = 0.25
    ),
    event_seq_start = as.integer(nrow(opening_rows)) + 1L,
    telemetry = ledgr:::ledgr_sweep_telemetry_env(),
    seed = 123L,
    event_mode = "buffered",
    use_fast_context = TRUE,
    compiled_accounting_model = compiled_accounting_model
  )
  handler <- ledgr:::ledgr_memory_output_handler("compiled-spot-fifo-multi-parity")
  handler$append_event_rows(opening_rows)
  fold <- ledgr:::ledgr_execute_fold(spec, handler)
  metric_kernel <- ledgr:::ledgr_metric_kernel(context = ledgr_metric_context(), pulses = pulses_posix)
  list(
    fold = fold,
    events = handler$events(),
    typed_events = handler$typed_events(),
    inline_summary = handler$inline_summary("compiled-spot-fifo-multi-parity", metric_kernel),
    reconstructed = ledgr:::ledgr_sweep_summary_from_ordered_events(
      events = handler$typed_events(),
      pulses_posix = pulses_posix,
      close_mat = bars_mat$close,
      initial_cash = 1000,
      instrument_ids = instrument_ids,
      run_id = "compiled-spot-fifo-multi-parity",
      metric_kernel = metric_kernel
    )
  )
}

testthat::test_that("execution spec constructor preserves the former list payload shape", {
  spec <- ledgr_test_execution_spec()

  testthat::expect_s3_class(spec, "ledgr_execution_spec")
  testthat::expect_identical(spec$spec_version, "ledgr_execution_spec_v1")
  legacy_equivalent <- unclass(spec)
  legacy_equivalent$spec_version <- NULL
  testthat::expect_identical(
    names(legacy_equivalent),
    c(
      "run_id",
      "instrument_ids",
      "id_to_idx",
      "strategy_fn",
      "strategy_params",
      "strategy_call_signature",
      "strategy_is_functional",
      "pulses_posix",
      "pulses_iso",
      "start_idx",
      "max_pulses",
      "checkpoint_every",
      "telemetry_stride",
      "state",
      "state_prev",
      "bars_by_id",
      "bars_mat",
      "static_bars_views",
      "static_feature_views",
      "feature_defs",
      "runtime_projection",
      "active_alias_map",
      "risk_plan",
      "cost_resolver",
      "event_seq_start",
      "telemetry",
      "seed",
      "event_mode",
      "use_fast_context",
      "compiled_accounting_model"
    )
  )
  testthat::expect_identical(spec$id_to_idx, stats::setNames(as.integer(1:2), c("AAA", "BBB")))
  testthat::expect_s3_class(spec$risk_plan, "ledgr_compiled_risk_plan")
  testthat::expect_identical(length(spec$risk_plan$steps), 0L)
  testthat::expect_null(spec$compiled_accounting_model)
})

testthat::test_that("execution specs validate before fold entry", {
  testthat::expect_error(
    ledgr:::ledgr_execute_fold(list(runtime_projection = NULL), output_handler = list()),
    class = "ledgr_invalid_execution_spec"
  )
  testthat::expect_error(
    ledgr_test_execution_spec(strategy_fn = 1),
    class = "ledgr_invalid_execution_spec"
  )
  bad_projection <- ledgr_test_execution_spec()
  bad_projection$runtime_projection <- list()
  testthat::expect_error(
    ledgr:::ledgr_validate_execution_spec(bad_projection),
    class = "ledgr_invalid_execution_spec"
  )
  testthat::expect_error(
    ledgr_test_execution_spec(risk_plan = list()),
    class = "ledgr_invalid_risk_plan"
  )
  malformed_step_plan <- structure(
    list(
      risk_schema_version = ledgr:::ledgr_risk_schema_version,
      steps = list(list(type_id = "long_only", schema_version = ledgr:::ledgr_risk_schema_version, args = list()))
    ),
    class = c("ledgr_compiled_risk_plan", "list")
  )
  testthat::expect_error(
    ledgr_test_execution_spec(risk_plan = malformed_step_plan),
    class = "ledgr_invalid_risk_plan"
  )
})

testthat::test_that("availability execution specs require aligned opening opportunities", {
  provider <- structure(
    list(valuation_policy = list(max_sessions = 1L)),
    class = c("ledgr_availability_provider", "list")
  )
  opening <- as.POSIXct("2024-01-01 12:00:00", tz = "UTC")
  spec <- ledgr_test_execution_spec(
    availability_provider = provider,
    execution_opportunities_posix = opening
  )

  testthat::expect_identical(spec$execution_opportunities_posix, opening)
  testthat::expect_error(
    ledgr_test_execution_spec(availability_provider = provider),
    class = "ledgr_invalid_execution_spec"
  )
  testthat::expect_error(
    ledgr_test_execution_spec(
      availability_provider = provider,
      execution_opportunities_posix = c(opening, opening + 1)
    ),
    class = "ledgr_invalid_execution_spec"
  )
  testthat::expect_error(
    ledgr_test_execution_spec(
      availability_provider = provider,
      execution_opportunities_posix = as.POSIXct(NA_character_, tz = "UTC")
    ),
    class = "ledgr_invalid_execution_spec"
  )
  testthat::expect_error(
    ledgr_test_execution_spec(
      availability_provider = provider,
      execution_opportunities_posix = "2024-01-01T12:00:00Z"
    ),
    class = "ledgr_invalid_execution_spec"
  )
  testthat::expect_error(
    ledgr_test_execution_spec(execution_opportunities_posix = opening),
    class = "ledgr_invalid_execution_spec"
  )
  testthat::expect_false("execution_opportunities_posix" %in% names(ledgr_test_execution_spec()))
})

testthat::test_that("compiled accounting model enum fails closed", {
  testthat::expect_null(ledgr_test_execution_spec()$compiled_accounting_model)
  testthat::expect_null(ledgr_test_execution_spec(compiled_accounting_model = NULL)$compiled_accounting_model)
  testthat::expect_identical(
    ledgr_test_execution_spec(compiled_accounting_model = "spot_fifo")$compiled_accounting_model,
    "spot_fifo"
  )
  testthat::expect_error(
    ledgr_test_execution_spec(compiled_accounting_model = "futures_margin"),
    class = "ledgr_unsupported_accounting_model"
  )

  spec <- ledgr_test_execution_spec(
    event_mode = "live",
    compiled_accounting_model = "spot_fifo"
  )
  handler <- ledgr:::ledgr_memory_output_handler("compiled-spot-fifo-live")
  testthat::expect_error(
    ledgr:::ledgr_execute_fold(spec, handler),
    class = "ledgr_compiled_spot_fifo_unavailable"
  )

  unavailable_handler <- list()
  testthat::expect_error(
    ledgr:::ledgr_execute_fold(
      ledgr_test_execution_spec(compiled_accounting_model = "spot_fifo"),
      unavailable_handler
    ),
    class = "ledgr_compiled_spot_fifo_unavailable"
  )
})

testthat::test_that("[LTB-0026] accounting refuses every unhandled pulse event kind", {
  event_kinds <- c("CASHFLOW", "DISPOSITION", "SYNTHETIC_UNKNOWN")
  original_builder <- ledgr:::ledgr_fold_build_pulse_plan

  run_with_kind <- function(event_kind, compiled_accounting_model) {
    testthat::local_mocked_bindings(
      ledgr_fold_build_pulse_plan = function(...) {
        plan <- original_builder(...)
        plan$fills <- list()
        plan$economic_event_kinds <- event_kind
        plan
      },
      .package = "ledgr"
    )
    ledgr_compiled_spot_fifo_test_run(compiled_accounting_model)
  }

  for (event_kind in event_kinds) {
    if (identical(event_kind, "CASHFLOW")) {
      testthat::expect_no_error(suppressWarnings(run_with_kind(event_kind, NULL)))
    } else {
      testthat::expect_error(
        run_with_kind(event_kind, NULL),
        class = "ledgr_invalid_pulse_plan",
        info = paste("canonical R envelope must reject", event_kind)
      )
    }
    testthat::expect_error(
      run_with_kind(event_kind, "spot_fifo"),
      class = "ledgr_compiled_spot_fifo_unavailable",
      info = paste("compiled envelope must reject", event_kind)
    )
  }

  fold_source <- paste(deparse(body(ledgr:::ledgr_execute_fold)), collapse = "\n")
  testthat::expect_match(
    fold_source,
    "ledgr_fold_pulse_plan_fill_intents(accounting_events)",
    fixed = TRUE
  )
  testthat::expect_match(
    fold_source,
    "for (entry in accounting_events$fills)",
    fixed = TRUE
  )
})

testthat::test_that("[LTB-0006] compiled spot FIFO path matches canonical R fold outputs", {
  r_path <- ledgr_compiled_spot_fifo_test_run(NULL)
  compiled_path <- ledgr_compiled_spot_fifo_test_run("spot_fifo")

  expect_reversal_fees <- function(path) {
    for (fills in list(path$inline_summary$fills, path$reconstructed$fills)) {
      testthat::expect_identical(fills$event_seq, c(2L, 2L, 3L, 3L))
      testthat::expect_identical(fills$action, c("CLOSE", "OPEN", "CLOSE", "OPEN"))
      testthat::expect_equal(fills$qty, c(2, 1, 1, 1))
      testthat::expect_equal(
        fills$fee,
        c(1 / 6, 1 / 12, 1 / 8, 1 / 8),
        tolerance = 1e-12
      )
      testthat::expect_equal(
        unname(vapply(split(fills$fee, fills$event_seq), sum, numeric(1))),
        c(0.25, 0.25),
        tolerance = 1e-12
      )
    }
  }
  expect_reversal_fees(r_path)
  expect_reversal_fees(compiled_path)

  testthat::expect_equal(
    as.data.frame(compiled_path$events),
    as.data.frame(r_path$events),
    ignore_attr = TRUE
  )
  for (attr_name in c(
    "ledgr_event_cash_delta",
    "ledgr_event_position_delta",
    "ledgr_event_realized",
    "ledgr_event_cost_basis"
  )) {
    testthat::expect_equal(
      attr(compiled_path$events, attr_name),
      attr(r_path$events, attr_name)
    )
  }
  testthat::expect_equal(
    ledgr:::ledgr_fills_from_events(compiled_path$typed_events, compiled_path$pulses_posix),
    ledgr:::ledgr_fills_from_events(r_path$typed_events, r_path$pulses_posix)
  )
  testthat::expect_equal(compiled_path$inline_summary, r_path$inline_summary)
  testthat::expect_equal(compiled_path$reconstructed, r_path$reconstructed)
  testthat::expect_equal(compiled_path$fold$state$cash, r_path$fold$state$cash)
  testthat::expect_equal(compiled_path$fold$state$positions, r_path$fold$state$positions)
  ledgr_expect_lot_states_equivalent(
    compiled_path$fold$state$lot_state,
    r_path$fold$state$lot_state
  )
  testthat::expect_identical(compiled_path$fold$next_event_seq, r_path$fold$next_event_seq)

  side <- c(rep("SELL", 4), rep("BUY", 2), "SELL")
  qty <- c(2.117, 0.129, 0.520, 2.254, 4.151, 1.016, 0.500)
  price <- c(54.45, 28.01, 29.28, 47.48, 40.96, 16.13, 20)
  r_fractional <- ledgr:::ledgr_lot_state("AAA")
  r_realized <- numeric(length(qty))
  r_basis <- numeric(length(qty))
  for (i in seq_along(qty)) {
    applied <- ledgr:::ledgr_lot_apply_fill(
      r_fractional, "AAA", side[[i]], qty[[i]], price[[i]], 0
    )
    r_fractional <- applied$state
    r_realized[[i]] <- r_fractional$realized_pnl
    r_basis[[i]] <- r_fractional$total_cost_basis
  }
  compiled_fractional <- ledgr:::ledgr_cpp_spot_fifo_batch(
    "fractional-reversal",
    rep.int(1L, length(qty)),
    rep("AAA", length(qty)),
    side,
    qty,
    price,
    rep(0, length(qty)),
    as.numeric(as.POSIXct("2020-01-01", tz = "UTC")) + seq_along(qty),
    1L,
    0,
    1000,
    integer(),
    numeric(),
    numeric(),
    0,
    0,
    0,
    0
  )
  testthat::expect_identical(
    compiled_fractional$lot_qty,
    ledgr:::ledgr_lot_values(r_fractional, "AAA")$qty
  )
  testthat::expect_identical(compiled_fractional$event_realized, r_realized)
  testthat::expect_identical(compiled_fractional$event_cost_basis, r_basis)

  # The full fill magnitude belongs in both compiled consumption-loop dust
  # scales. Without it these cases retain an opposing-sign residual and append
  # a new lot behind it. Numerical comparisons allow the legitimate final-bit
  # difference between successive R subtraction and C++ qty - close_qty; the
  # single-sign assertion is the mutation-sensitive detector.
  dust_cases <- list(
    list(side = "BUY", lot_qty = -c(1.078, 1.437, 0.536, 1.704), sign = 1),
    list(side = "SELL", lot_qty = c(1.078, 1.437, 0.536, 1.704), sign = -1)
  )
  dust_price <- c(52.71, 38.22, 36.88, 47.48)
  for (dust_case in dust_cases) {
    dust_qty <- dust_case$lot_qty
    dust_basis <- sum(dust_qty * dust_price)
    r_dust <- ledgr:::ledgr_lot_state("AAA")
    r_dust$lot_qty[[1L]] <- dust_qty
    r_dust$lot_price[[1L]] <- dust_price
    r_dust$lot_head[[1L]] <- 1L
    r_dust$lot_tail[[1L]] <- length(dust_qty)
    r_dust$net_by_inst[[1L]] <- sum(dust_qty)
    r_dust$cost_basis_by_inst[[1L]] <- dust_basis
    r_dust$total_cost_basis <- dust_basis
    r_dust <- ledgr:::ledgr_lot_apply_fill(
      r_dust, "AAA", dust_case$side, 6.136, 69.29, 0
    )$state
    compiled_dust <- ledgr:::ledgr_cpp_spot_fifo_batch(
      paste0("fractional-dust-scale-", tolower(dust_case$side)),
      1L,
      "AAA",
      dust_case$side,
      6.136,
      69.29,
      0,
      as.numeric(as.POSIXct("2020-01-01", tz = "UTC")),
      1L,
      sum(dust_qty),
      1000,
      rep.int(1L, length(dust_qty)),
      dust_qty,
      dust_price,
      dust_basis,
      dust_basis,
      0,
      0
    )
    r_dust_lots <- ledgr:::ledgr_lot_values(r_dust, "AAA")
    testthat::expect_equal(
      compiled_dust$lot_qty,
      r_dust_lots$qty,
      tolerance = 1e-12
    )
    testthat::expect_equal(
      compiled_dust$lot_price,
      r_dust_lots$price,
      tolerance = 1e-12
    )
    testthat::expect_equal(
      compiled_dust$event_realized,
      r_dust$realized_pnl,
      tolerance = 1e-12
    )
    testthat::expect_equal(
      compiled_dust$event_cost_basis,
      r_dust$total_cost_basis,
      tolerance = 1e-12
    )
    testthat::expect_identical(
      length(unique(sign(compiled_dust$lot_qty))),
      1L
    )
    testthat::expect_identical(
      sign(compiled_dust$lot_qty[[1L]]),
      dust_case$sign
    )
  }
})

testthat::test_that("[LTB-0013] compiled spot FIFO batches preserve multi-instrument pulse parity", {
  r_path <- ledgr_compiled_spot_fifo_multi_test_run(NULL)
  compiled_path <- ledgr_compiled_spot_fifo_multi_test_run("spot_fifo")

  testthat::expect_equal(
    as.data.frame(compiled_path$events),
    as.data.frame(r_path$events),
    ignore_attr = TRUE
  )
  for (attr_name in c(
    "ledgr_event_cash_delta",
    "ledgr_event_position_delta",
    "ledgr_event_realized",
    "ledgr_event_cost_basis"
  )) {
    testthat::expect_equal(
      attr(compiled_path$events, attr_name),
      attr(r_path$events, attr_name)
    )
  }
  testthat::expect_equal(compiled_path$inline_summary, r_path$inline_summary)
  testthat::expect_equal(compiled_path$reconstructed, r_path$reconstructed)
  testthat::expect_equal(compiled_path$fold$state$cash, r_path$fold$state$cash)
  testthat::expect_equal(compiled_path$fold$state$positions, r_path$fold$state$positions)
  ledgr_expect_lot_states_equivalent(
    compiled_path$fold$state$lot_state,
    r_path$fold$state$lot_state
  )
  testthat::expect_identical(compiled_path$fold$next_event_seq, r_path$fold$next_event_seq)
})

testthat::test_that("compiled spot FIFO pops fractional dust lots", {
  out <- ledgr:::ledgr_cpp_spot_fifo_batch(
    "compiled-fractional-dust",
    as.integer(c(1, 1, 1)),
    c("AAA", "AAA", "AAA"),
    c("BUY", "BUY", "SELL"),
    as.numeric(c(0.1, 0.2, 0.3)),
    as.numeric(c(10, 10, 10)),
    as.numeric(c(0, 0, 0)),
    as.numeric(as.POSIXct("2020-01-02T00:00:00Z", tz = "UTC")) + 0:2,
    as.integer(1),
    as.numeric(0),
    as.numeric(1000),
    integer(),
    numeric(),
    numeric(),
    as.numeric(0),
    as.numeric(0),
    as.numeric(0),
    as.numeric(0)
  )
  testthat::expect_length(out$lot_qty, 0L)
  testthat::expect_equal(out$total_cost_basis, 0)
})

testthat::test_that("compiled spot FIFO validates scalar state argument types", {
  call_batch <- function(cash = 1000, event_seq_start = 1L) {
    ledgr:::ledgr_cpp_spot_fifo_batch(
      "compiled-scalar-check",
      as.integer(1),
      "AAA",
      "BUY",
      as.numeric(1),
      as.numeric(100),
      as.numeric(0),
      as.numeric(as.POSIXct("2020-01-02T00:00:00Z", tz = "UTC")),
      event_seq_start,
      as.numeric(0),
      cash,
      integer(),
      numeric(),
      numeric(),
      as.numeric(0),
      as.numeric(0),
      as.numeric(0),
      as.numeric(0)
    )
  }

  testthat::expect_error(
    call_batch(cash = 1000L),
    "`cash` must be a numeric scalar.",
    fixed = TRUE
  )
  testthat::expect_error(
    call_batch(event_seq_start = as.numeric(1)),
    "`event_seq_start` must be an integer scalar.",
    fixed = TRUE
  )
})

testthat::test_that("execution specs are serializable worker payloads", {
  spec <- ledgr_test_execution_spec()
  round_trip <- unserialize(serialize(spec, NULL))

  testthat::expect_s3_class(round_trip, "ledgr_execution_spec")
  testthat::expect_identical(round_trip$spec_version, spec$spec_version)
  testthat::expect_identical(round_trip$run_id, spec$run_id)
  testthat::expect_identical(round_trip$instrument_ids, spec$instrument_ids)
  testthat::expect_true(is.function(round_trip$strategy_fn))
  testthat::expect_silent(ledgr:::ledgr_validate_execution_spec(round_trip))
})

testthat::test_that("fold position valuation aligns shuffled positions by instrument id", {
  observed_equity <- numeric()
  observed_positions <- list()
  strategy <- function(ctx, params) {
    observed_equity <<- c(observed_equity, ctx$equity)
    observed_positions[[length(observed_positions) + 1L]] <<- ctx$positions
    stats::setNames(as.numeric(ctx$positions[ctx$universe]), ctx$universe)
  }
  spec <- ledgr_test_execution_spec(
    strategy_fn = strategy,
    strategy_call_signature = ledgr:::ledgr_strategy_signature(strategy),
    state = list(cash = 1000, positions = c(BBB = 2, AAA = 1))
  )
  handler <- ledgr:::ledgr_memory_output_handler("position-valuation-alignment")

  ledgr:::ledgr_execute_fold(spec, handler)

  testthat::expect_equal(observed_equity, c(1302, 1602))
  testthat::expect_identical(names(observed_positions[[1L]]), c("AAA", "BBB"))
  testthat::expect_equal(as.numeric(observed_positions[[1L]][c("AAA", "BBB")]), c(1, 2))
})

testthat::test_that("fold target deltas align shuffled targets by instrument id", {
  observed_positions <- list()
  strategy <- function(ctx, params) {
    observed_positions[[length(observed_positions) + 1L]] <<- ctx$positions
    stats::setNames(c(2, 1), c("BBB", "AAA"))
  }
  spec <- ledgr_test_execution_spec(
    strategy_fn = strategy,
    strategy_call_signature = ledgr:::ledgr_strategy_signature(strategy)
  )
  handler <- ledgr:::ledgr_memory_output_handler("target-delta-alignment")

  ledgr:::ledgr_execute_fold(spec, handler)
  events <- handler$events()

  testthat::expect_equal(as.numeric(observed_positions[[2L]][c("AAA", "BBB")]), c(1, 2))
  testthat::expect_identical(events$instrument_id, c("AAA", "BBB"))
  testthat::expect_equal(events$qty, c(1, 2))
})

testthat::test_that("fold primitive positions preserve public named ctx snapshot", {
  observed <- list()
  strategy <- function(ctx, params) {
    observed[[length(observed) + 1L]] <<- list(
      positions = ctx$positions,
      vec_positions = ctx$vec$positions,
      idx_aaa = ctx$idx("AAA"),
      idx_bad = ctx$idx("ZZZ", missing = "na"),
      idx_error = testthat::capture_error(ctx$idx("ZZZ"))
    )
    stats::setNames(c(1, 0), c("AAA", "BBB"))
  }
  spec <- ledgr_test_execution_spec(
    strategy_fn = strategy,
    strategy_call_signature = ledgr:::ledgr_strategy_signature(strategy),
    state = list(cash = 1000, positions = c(0, 0))
  )
  handler <- ledgr:::ledgr_memory_output_handler("primitive-position-snapshot")

  ledgr:::ledgr_execute_fold(spec, handler)

  testthat::expect_identical(names(observed[[1L]]$positions), c("AAA", "BBB"))
  testthat::expect_equal(as.numeric(observed[[1L]]$positions), c(0, 0))
  testthat::expect_null(names(observed[[1L]]$vec_positions))
  testthat::expect_equal(observed[[2L]]$vec_positions, c(1, 0))
  testthat::expect_identical(observed[[1L]]$idx_aaa, 1L)
  testthat::expect_identical(observed[[1L]]$idx_bad, NA_integer_)
  testthat::expect_s3_class(observed[[1L]]$idx_error, "ledgr_invalid_pulse_context")
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0015] run and sweep share execution construction and fold core", {
  bars <- data.frame(
    instrument_id = "AAA",
    ts_utc = as.POSIXct("2024-01-01", tz = "UTC") + 86400 * 0:2,
    open = 100:102,
    high = 101:103,
    low = 99:101,
    close = 100:102,
    volume = 1000,
    stringsAsFactors = FALSE
  )
  snapshot <- ledgr_snapshot_from_df(bars)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) ctx$flat()
  experiment <- ledgr_experiment(
    snapshot,
    strategy,
    cost_model = ledgr_cost_zero()
  )
  calls <- 0L
  fold_calls <- 0L
  original <- ledgr:::ledgr_execution_spec
  original_fold <- ledgr:::ledgr_execute_fold
  testthat::local_mocked_bindings(
    ledgr_execution_spec = function(...) {
      calls <<- calls + 1L
      original(...)
    },
    ledgr_execute_fold = function(...) {
      fold_calls <<- fold_calls + 1L
      original_fold(...)
    },
    .package = "ledgr"
  )

  run <- ledgr_run(experiment, run_id = "execution-spec-route")
  on.exit(close(run), add = TRUE)
  sweep <- ledgr_sweep(
    experiment,
    ledgr_param_grid(single = list()),
    seed = 1L
  )
  testthat::expect_s3_class(run, "ledgr_backtest")
  testthat::expect_s3_class(sweep, "ledgr_sweep_results")
  testthat::expect_identical(calls, 2L)
  testthat::expect_identical(fold_calls, 2L)
})
