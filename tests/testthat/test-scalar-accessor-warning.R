testthat::test_that("[LTB-0067] universe-wide scalar access warns once without changing output", {
  ids <- sprintf("I%03d", seq_len(100L))
  pulses <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:1
  bars <- data.frame(
    instrument_id = rep(ids, times = length(pulses)),
    ts_utc = rep(pulses, each = length(ids)),
    open = 100,
    high = 101,
    low = 99,
    close = 100,
    volume = 1000,
    stringsAsFactors = FALSE
  )
  snapshot <- ledgr_snapshot_from_df(bars)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  loop_strategy <- function(ctx, params) {
    values <- vapply(ctx$universe, ctx$close, numeric(1))
    targets <- ctx$hold()
    if (all(is.finite(values))) targets[[1L]] <- 1
    targets
  }
  experiment <- ledgr_experiment(
    snapshot,
    loop_strategy,
    opening = ledgr_opening(cash = 10000),
    cost_model = ledgr_cost_zero()
  )
  observed <- list()
  warned <- withCallingHandlers(
    ledgr_run(experiment, run_id = "scalar-warning"),
    ledgr_scalar_accessor_loop = function(condition) {
      observed[[length(observed) + 1L]] <<- condition
      invokeRestart("muffleWarning")
    }
  )
  on.exit(close(warned), add = TRUE)
  suppressed <- suppressWarnings(ledgr_run(experiment, run_id = "scalar-suppressed"))
  on.exit(close(suppressed), add = TRUE)

  testthat::expect_length(observed, 1L)
  testthat::expect_s3_class(observed[[1L]], "ledgr_scalar_accessor_loop")
  testthat::expect_identical(observed[[1L]]$accessor, "close")
  testthat::expect_identical(observed[[1L]]$observed_call_count, 100L)
  testthat::expect_identical(observed[[1L]]$vector_form, "ctx$vec$close")
  testthat::expect_match(conditionMessage(observed[[1L]]), "100 times", fixed = TRUE)

  testthat::expect_identical(
    ledgr_results(warned, "fills"),
    ledgr_results(suppressed, "fills")
  )
  testthat::expect_identical(
    ledgr_results(warned, "equity"),
    ledgr_results(suppressed, "equity")
  )
  warned_info <- ledgr_run_info(snapshot, warned$run_id)
  suppressed_info <- ledgr_run_info(snapshot, suppressed$run_id)
  testthat::expect_identical(warned_info$config_hash, suppressed_info$config_hash)
  testthat::expect_identical(warned_info$strategy_hash, suppressed_info$strategy_hash)

  no_warning <- function(strategy, run_id) {
    conditions <- list()
    bt <- withCallingHandlers(
      ledgr_run(
        ledgr_experiment(
          snapshot,
          strategy,
          opening = ledgr_opening(cash = 10000),
          cost_model = ledgr_cost_zero()
        ),
        run_id = run_id
      ),
      ledgr_scalar_accessor_loop = function(condition) {
        conditions[[length(conditions) + 1L]] <<- condition
        invokeRestart("muffleWarning")
      }
    )
    on.exit(close(bt), add = TRUE)
    testthat::expect_length(conditions, 0L)
  }
  no_warning(function(ctx, params) {
    invisible(ctx$vec$close)
    ctx$flat()
  }, "plane-only")
  no_warning(function(ctx, params) {
    invisible(vapply(ctx$universe[seq_len(5L)], ctx$close, numeric(1)))
    ctx$flat()
  }, "small-scalar-set")
  testthat::local_mocked_bindings(
    ledgr_pulse_context_record_scalar_access = function(...) {
      rlang::abort(
        "Small universes must keep the untracked scalar closures.",
        class = "ledgr_test_unnecessary_scalar_tracking"
      )
    },
    .package = "ledgr"
  )
  testthat::expect_silent(ledgr_sweep(
    ledgr_experiment(
      snapshot,
      function(ctx, params) {
        invisible(ctx$close(ctx$universe[[1L]]))
        ctx$flat()
      },
      universe = ids[seq_len(5L)],
      opening = ledgr_opening(cash = 10000),
      cost_model = ledgr_cost_zero()
    ),
    ledgr_param_grid(small = list()),
    seed = 17L,
    stop_on_error = TRUE
  ))
  small_ctx <- list(
    universe = ids[seq_len(5L)],
    positions = stats::setNames(numeric(5L), ids[seq_len(5L)]),
    .pulse_lookup = new.env(parent = emptyenv()),
    .feature_vector = NULL
  )
  small_ctx <- ledgr:::ledgr_ensure_pulse_context_accessors(small_ctx)
  small_ctx <- ledgr:::ledgr_refresh_pulse_context_lookup(
    small_ctx,
    bars = bars[seq_len(5L), , drop = FALSE],
    positions = small_ctx$positions,
    universe = small_ctx$universe
  )
  testthat::expect_null(small_ctx$.pulse_lookup$scalar_access_state)
  testthat::expect_identical(small_ctx$close(ids[[1L]]), 100)
})
