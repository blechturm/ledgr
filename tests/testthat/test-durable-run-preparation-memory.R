testthat::test_that("[LTB-0155] durable preparation releases each dead copy at its boundary", {
  snapshot <- availability_runtime_fixture(days = 5L)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    invisible(ctx$vec$feature("sma_2"))
    ctx$flat()
  }
  experiment <- ledgr_experiment(
    snapshot,
    strategy,
    features = list(ledgr_ind_sma(2L)),
    valuation_policy = ledgr_valuation_stale(1L),
    cost_model = ledgr_cost_zero(),
    persist_features = TRUE
  )
  feature_boundary <- NULL
  fold_boundary <- NULL
  original_strict <- ledgr:::ledgr_compute_feature_series_strict
  original_fold <- ledgr:::ledgr_execute_fold
  ledgr_feature_cache_clear()
  testthat::local_mocked_bindings(
    ledgr_compute_feature_series_strict = function(...) {
      caller <- parent.frame()
      feature_boundary <<- list(
        bars_all = get0("bars_all", caller, inherits = FALSE),
        raw_bars_by_id = get0("raw_bars_by_id", caller, inherits = FALSE),
        bars_cols_by_id = get0("bars_cols_by_id", caller, inherits = FALSE),
        bars_by_id = get0("bars_by_id", caller, inherits = FALSE)
      )
      original_strict(...)
    },
    ledgr_execute_fold = function(execution, output_handler) {
      caller <- parent.frame()
      released <- c(
        "bars_all", "raw_bars_by_id", "bars_by_id", "bars_cols_by_id",
        "run_feature_series", "run_feature_matrix"
      )
      fold_boundary <<- list(
        released = vapply(released, function(name) {
          value <- get0(name, caller, inherits = FALSE)
          is.null(value)
        }, logical(1L)),
        execution_bars_by_id = execution$bars_by_id
      )
      original_fold(execution, output_handler)
    },
    .package = "ledgr"
  )

  bt <- ledgr_run(experiment, run_id = "durable-release-boundaries")
  on.exit(close(bt), add = TRUE)
  testthat::expect_null(feature_boundary$bars_all)
  testthat::expect_null(feature_boundary$raw_bars_by_id)
  testthat::expect_null(feature_boundary$bars_cols_by_id)
  testthat::expect_true(is.list(feature_boundary$bars_by_id))
  testthat::expect_gt(length(feature_boundary$bars_by_id), 0L)
  testthat::expect_true(all(fold_boundary$released))
  testthat::expect_identical(fold_boundary$execution_bars_by_id, list())
  testthat::expect_identical(ledgr_run_info(snapshot, bt$run_id)$status, "DONE")

  if (!(requireNamespace("covr", quietly = TRUE) && covr::in_covr())) {
    source <- paste(deparse(body(ledgr:::ledgr_run_fold_impl)), collapse = "\n")
    testthat::expect_no_match(source, "\\bgc\\s*\\(", perl = TRUE)
    testthat::expect_match(source, "bars_by_id = list()", fixed = TRUE)
  }
})

testthat::test_that("[LTB-0156] finalization skips only work its branch cannot use", {
  snapshot <- availability_runtime_fixture(days = 5L)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  experiment <- ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$flat(),
    features = list(ledgr_ind_sma(2L)),
    valuation_policy = ledgr_valuation_stale(1L),
    cost_model = ledgr_cost_zero(),
    persist_features = TRUE
  )
  slice_calls <- 0L
  event_reads <- 0L
  original_slice <- ledgr:::ledgr_projection_slice
  original_events <- ledgr:::ledgr_run_finalize_events
  testthat::local_mocked_bindings(
    ledgr_projection_slice = function(...) {
      slice_calls <<- slice_calls + 1L
      original_slice(...)
    },
    ledgr_run_finalize_events = function(...) {
      event_reads <<- event_reads + 1L
      original_events(...)
    },
    .package = "ledgr"
  )

  bt <- ledgr_run(experiment, run_id = "durable-finalization-branches")
  testthat::expect_identical(slice_calls, 0L)
  testthat::expect_identical(event_reads, 0L)
  testthat::expect_gt(nrow(ledgr_results(bt, "equity")), 0L)
  close(bt)

  pulses <- as.POSIXct("2024-01-01", tz = "UTC") + 86400 * 0:2
  projection <- ledgr:::ledgr_runtime_projection(
    feature_values = list(x = matrix(1:3, nrow = 1L)),
    universe = "AAA",
    pulses_posix = pulses
  )
  sliced <- ledgr:::ledgr_projection_slice(projection, pulses[1:2])
  testthat::expect_identical(slice_calls, 1L)
  testthat::expect_identical(dim(sliced$feature_values$x), c(1L, 2L))

  con <- DBI::dbConnect(duckdb::duckdb(), snapshot$db_path, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  events <- ledgr:::ledgr_run_finalize_events(con, "durable-finalization-branches")
  testthat::expect_identical(event_reads, 1L)
  testthat::expect_true(is.data.frame(events))

  if (!(requireNamespace("covr", quietly = TRUE) && covr::in_covr())) {
    source <- paste(deparse(body(ledgr:::ledgr_run_finalize)), collapse = "\n")
    testthat::expect_match(
      source,
      "else \\{\\s+events_df <- ledgr_run_finalize_events\\(con, run_id\\)",
      perl = TRUE
    )
    testthat::expect_match(
      source,
      "if \\(full_projection\\) \\{\\s+runtime_projection",
      perl = TRUE
    )
  }
})
