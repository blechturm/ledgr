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

testthat::test_that("compiled spot FIFO path matches canonical R fold outputs", {
  r_path <- ledgr_compiled_spot_fifo_test_run(NULL)
  compiled_path <- ledgr_compiled_spot_fifo_test_run("spot_fifo")

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
    ledgr:::ledgr_fills_from_events(compiled_path$typed_events),
    ledgr:::ledgr_fills_from_events(r_path$typed_events)
  )
  testthat::expect_equal(compiled_path$inline_summary, r_path$inline_summary)
  testthat::expect_equal(compiled_path$reconstructed, r_path$reconstructed)
  testthat::expect_equal(compiled_path$fold$state$cash, r_path$fold$state$cash)
  testthat::expect_equal(compiled_path$fold$state$positions, r_path$fold$state$positions)
  testthat::expect_equal(compiled_path$fold$state$lot_state, r_path$fold$state$lot_state)
  testthat::expect_identical(compiled_path$fold$next_event_seq, r_path$fold$next_event_seq)
})

testthat::test_that("compiled spot FIFO batches preserve multi-instrument pulse parity", {
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
  testthat::expect_equal(compiled_path$fold$state$lot_state, r_path$fold$state$lot_state)
  testthat::expect_identical(compiled_path$fold$next_event_seq, r_path$fold$next_event_seq)
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

testthat::test_that("run and sweep route fold payloads through one constructor", {
  run_body <- paste(deparse(body(ledgr:::ledgr_run_fold)), collapse = "\n")
  sweep_body <- paste(deparse(body(ledgr:::ledgr_sweep_run_candidate)), collapse = "\n")

  testthat::expect_true(grepl("ledgr_execution_spec", run_body, fixed = TRUE))
  testthat::expect_true(grepl("ledgr_execution_spec", sweep_body, fixed = TRUE))
  testthat::expect_true(grepl("ledgr_validate_execution_spec", paste(deparse(body(ledgr:::ledgr_execute_fold)), collapse = "\n"), fixed = TRUE))
})
