testthat::test_that("[LTB-0155] durable preparation releases each dead copy at its boundary", {
  snapshot <- availability_runtime_fixture(days = 5L)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    invisible(ctx[["sma_2"]])
    ctx$flat()
  }
  experiment <- ledgr_experiment(opening = ledgr_opening(cash = 100000),
    snapshot,
    strategy,
    features = list(ledgr_ind_sma(2L)),
    valuation_policy = ledgr_valuation_stale(1L),
    cost_model = ledgr_cost_zero()
  )
  feature_boundary <- NULL
  fold_boundary <- NULL
  original_history_feature <- ledgr:::ledgr_history_compute_feature_series
  original_fold <- ledgr:::ledgr_execute_fold
  testthat::local_mocked_bindings(
    ledgr_history_compute_feature_series = function(...) {
      caller <- parent.frame()
      feature_boundary <<- list(
        bars_all = get0("bars_all", caller, inherits = FALSE),
        raw_bars_by_id = get0("raw_bars_by_id", caller, inherits = FALSE),
        bars_cols_by_id = get0("bars_cols_by_id", caller, inherits = FALSE),
        bars_by_id = get0("bars_by_id", caller, inherits = FALSE),
        history_substrate = get0(
          "history_substrate", caller, inherits = FALSE
        )
      )
      original_history_feature(...)
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
        history_substrate = execution$history_substrate,
        has_bars_by_id = "bars_by_id" %in% names(execution)
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
  testthat::expect_null(feature_boundary$bars_by_id)
  testthat::expect_s3_class(
    feature_boundary$history_substrate,
    "ledgr_history_substrate"
  )
  testthat::expect_true(all(fold_boundary$released))
  testthat::expect_s3_class(
    fold_boundary$history_substrate,
    "ledgr_history_substrate"
  )
  testthat::expect_false(fold_boundary$has_bars_by_id)
  testthat::expect_identical(ledgr_run_info(snapshot, bt$run_id)$status, "DONE")

  if (!(requireNamespace("covr", quietly = TRUE) && covr::in_covr())) {
    source <- paste(deparse(body(ledgr:::ledgr_run_fold_impl)), collapse = "\n")
    testthat::expect_no_match(source, "\\bgc\\s*\\(", perl = TRUE)
    testthat::expect_no_match(source, "bars_by_id", fixed = TRUE)
  }
})
