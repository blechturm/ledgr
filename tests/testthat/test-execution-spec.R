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
      cost_resolver = ledgr:::ledgr_cost_spread_commission_internal(
        spread_bps = 0,
        commission_fixed = 0
      ),
      event_seq_start = 1L,
      telemetry = ledgr:::ledgr_sweep_telemetry_env(),
      seed = 123L,
      event_mode = "buffered",
      use_fast_context = TRUE
    ),
    list(...),
    keep.null = TRUE
  )
  do.call(ledgr:::ledgr_execution_spec, args)
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
      "cost_resolver",
      "event_seq_start",
      "telemetry",
      "seed",
      "event_mode",
      "use_fast_context"
    )
  )
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
  testthat::expect_identical(names(observed_positions[[1L]]), c("BBB", "AAA"))
  testthat::expect_equal(as.numeric(observed_positions[[1L]][c("AAA", "BBB")]), c(1, 2))
})

testthat::test_that("run and sweep route fold payloads through one constructor", {
  run_body <- paste(deparse(body(ledgr:::ledgr_run_fold)), collapse = "\n")
  sweep_body <- paste(deparse(body(ledgr:::ledgr_sweep_run_candidate)), collapse = "\n")

  testthat::expect_true(grepl("ledgr_execution_spec", run_body, fixed = TRUE))
  testthat::expect_true(grepl("ledgr_execution_spec", sweep_body, fixed = TRUE))
  testthat::expect_true(grepl("ledgr_validate_execution_spec", paste(deparse(body(ledgr:::ledgr_execute_fold)), collapse = "\n"), fixed = TRUE))
})
