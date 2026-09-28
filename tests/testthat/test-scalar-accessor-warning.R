ledgr_scalar_warning_fixture <- function() {
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
  list(
    ids = ids,
    bars = bars,
    snapshot = ledgr_snapshot_from_df(bars)
  )
}

ledgr_scalar_warning_loop_strategy <- function(ctx, params) {
  values <- vapply(ctx$universe, ctx$close, numeric(1))
  targets <- ctx$hold()
  if (all(is.finite(values))) targets[[1L]] <- 1
  targets
}

ledgr_scalar_warning_experiment <- function(snapshot) {
  ledgr_experiment(
    snapshot,
    ledgr_scalar_warning_loop_strategy,
    opening = ledgr_opening(cash = 10000),
    cost_model = ledgr_cost_zero()
  )
}

ledgr_scalar_warning_run <- function(experiment, run_id, params = list()) {
  observed <- list()
  run <- withCallingHandlers(
    ledgr_run(experiment, params = params, run_id = run_id),
    ledgr_scalar_accessor_loop = function(condition) {
      observed[[length(observed) + 1L]] <<- condition
      invokeRestart("muffleWarning")
    }
  )
  list(run = run, observed = observed)
}

ledgr_scalar_feature_warning_strategy <- function(ctx, params) {
  ids <- ctx$universe[seq_len(params$n_reads)]
  values <- vapply(ids, function(id) {
    ctx$feature(id, params$feature_id)
  }, numeric(1))
  targets <- ctx$flat()
  if (all(is.finite(values))) targets[[1L]] <- 1
  targets
}

ledgr_mapped_feature_loop_strategy <- function(ctx, params) {
  values <- lapply(ctx$universe, ctx$features)
  targets <- ctx$flat()
  if (all(vapply(values, function(value) {
    all(is.finite(value))
  }, logical(1)))) {
    targets[[1L]] <- 1
  }
  targets
}

testthat::test_that("[LTB-0067] universe-wide scalar access warns once without false positives", {
  fixture <- ledgr_scalar_warning_fixture()
  snapshot <- fixture$snapshot
  ids <- fixture$ids
  bars <- fixture$bars
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  warned <- ledgr_scalar_warning_run(
    ledgr_scalar_warning_experiment(snapshot),
    "scalar-warning"
  )
  on.exit(close(warned$run), add = TRUE)

  testthat::expect_length(warned$observed, 1L)
  testthat::expect_s3_class(warned$observed[[1L]], "ledgr_scalar_accessor_loop")
  testthat::expect_identical(warned$observed[[1L]]$accessor, "close")
  testthat::expect_identical(warned$observed[[1L]]$observed_call_count, 100L)
  testthat::expect_identical(warned$observed[[1L]]$vector_form, "ctx$vec$close")
  testthat::expect_match(
    conditionMessage(warned$observed[[1L]]),
    "100 times",
    fixed = TRUE
  )

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
  local({
    testthat::local_mocked_bindings(
      ledgr_pulse_context_record_scalar_access = function(...) {
        rlang::abort(
          "Vector planes must not enter scalar-access accounting.",
          class = "ledgr_test_plane_counted_as_scalar"
        )
      },
      .package = "ledgr"
    )
    no_warning(function(ctx, params) {
      invisible(ctx$vec$close)
      ctx$flat()
    }, "plane-only")
  })
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
    positions = small_ctx$.positions,
    universe = small_ctx$universe
  )
  testthat::expect_null(small_ctx$.pulse_lookup$scalar_access_state)
  testthat::expect_identical(small_ctx$close(ids[[1L]]), 100)
})

testthat::test_that("[LTB-0102] exact-ID feature loops warn but mapped alias loops do not", {
  fixture <- ledgr_scalar_warning_fixture()
  snapshot <- fixture$snapshot
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  feature <- ledgr_ind_sma(1)
  feature_id <- ledgr_feature_id(feature)
  feature_map <- ledgr_feature_map(signal = feature)
  exact_experiment <- ledgr_experiment(
    snapshot,
    ledgr_scalar_feature_warning_strategy,
    features = feature_map,
    opening = ledgr_opening(cash = 10000),
    cost_model = ledgr_cost_zero()
  )

  warned <- ledgr_scalar_warning_run(
    exact_experiment,
    "feature-scalar-warning",
    params = list(n_reads = 100L, feature_id = feature_id)
  )
  on.exit(close(warned$run), add = TRUE)
  testthat::expect_length(warned$observed, 1L)
  testthat::expect_s3_class(
    warned$observed[[1L]],
    "ledgr_scalar_accessor_loop"
  )
  testthat::expect_identical(warned$observed[[1L]]$accessor, "feature")
  testthat::expect_identical(
    warned$observed[[1L]]$observed_call_count,
    100L
  )
  testthat::expect_identical(
    warned$observed[[1L]]$vector_form,
    "ctx$vec$feature(feature_id)"
  )

  quiet_conditions <- list()
  quiet <- withCallingHandlers(
    ledgr_run(
      exact_experiment,
      params = list(n_reads = 99L, feature_id = feature_id),
      run_id = "feature-below-threshold"
    ),
    ledgr_scalar_accessor_loop = function(condition) {
      quiet_conditions[[length(quiet_conditions) + 1L]] <<- condition
      invokeRestart("muffleWarning")
    }
  )
  on.exit(close(quiet), add = TRUE)
  testthat::expect_length(quiet_conditions, 0L)

  mapped_conditions <- list()
  mapped <- withCallingHandlers(
    ledgr_run(
      ledgr_experiment(
        snapshot,
        ledgr_mapped_feature_loop_strategy,
        features = feature_map,
        opening = ledgr_opening(cash = 10000),
        cost_model = ledgr_cost_zero()
      ),
      run_id = "mapped-feature-loop"
    ),
    ledgr_scalar_accessor_loop = function(condition) {
      mapped_conditions[[length(mapped_conditions) + 1L]] <<- condition
      invokeRestart("muffleWarning")
    }
  )
  on.exit(close(mapped), add = TRUE)
  testthat::expect_length(mapped_conditions, 0L)

  suppressed <- suppressWarnings(ledgr_run(
    exact_experiment,
    params = list(n_reads = 100L, feature_id = feature_id),
    run_id = "feature-warning-suppressed"
  ))
  on.exit(close(suppressed), add = TRUE)
  testthat::expect_identical(
    ledgr_results(warned$run, "fills"),
    ledgr_results(suppressed, "fills")
  )
  testthat::expect_identical(
    ledgr_results(warned$run, "equity"),
    ledgr_results(suppressed, "equity")
  )
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0071] scalar warning is durable-output neutral", {
  fixture <- ledgr_scalar_warning_fixture()
  snapshot <- fixture$snapshot
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  experiment <- ledgr_scalar_warning_experiment(snapshot)

  warned <- ledgr_scalar_warning_run(experiment, "scalar-warning-neutrality")
  on.exit(close(warned$run), add = TRUE)
  suppressed <- suppressWarnings(ledgr_run(
    experiment,
    run_id = "scalar-suppressed-neutrality"
  ))
  on.exit(close(suppressed), add = TRUE)
  plane <- ledgr_run(
    ledgr_experiment(
      snapshot,
      function(ctx, params) {
        targets <- ctx$hold()
        if (all(is.finite(ctx$vec$close))) targets[[1L]] <- 1
        targets
      },
      opening = ledgr_opening(cash = 10000),
      cost_model = ledgr_cost_zero()
    ),
    run_id = "scalar-plane-neutrality"
  )
  on.exit(close(plane), add = TRUE)

  testthat::expect_length(warned$observed, 1L)
  testthat::expect_identical(
    ledgr_results(warned$run, "fills"),
    ledgr_results(suppressed, "fills")
  )
  testthat::expect_identical(
    ledgr_results(warned$run, "equity"),
    ledgr_results(suppressed, "equity")
  )
  testthat::expect_identical(
    ledgr_results(warned$run, "fills"),
    ledgr_results(plane, "fills")
  )
  testthat::expect_identical(
    ledgr_results(warned$run, "equity"),
    ledgr_results(plane, "equity")
  )
  warned_info <- ledgr_run_info(snapshot, warned$run$run_id)
  suppressed_info <- ledgr_run_info(snapshot, suppressed$run_id)
  testthat::expect_identical(warned_info$config_hash, suppressed_info$config_hash)
  testthat::expect_identical(warned_info$strategy_hash, suppressed_info$strategy_hash)
})
