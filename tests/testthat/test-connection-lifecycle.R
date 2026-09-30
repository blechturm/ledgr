testthat::test_that("[LTB-0131] public calls open the store once and leave no connection open", {
  connections <- new.env(parent = emptyenv())
  connections$all <- list()
  real_connect <- DBI::dbConnect
  testthat::local_mocked_bindings(
    dbConnect = function(drv, ...) {
      con <- real_connect(drv, ...)
      connections$all[[length(connections$all) + 1L]] <- con
      con
    },
    .package = "DBI"
  )
  # Opens made by one public call, after checking that no connection opened
  # so far, by this call or an earlier one, is still live.
  opens <- function(expr) {
    before <- length(connections$all)
    force(expr)
    live <- vapply(connections$all, DBI::dbIsValid, logical(1))
    testthat::expect_false(any(live))
    length(connections$all) - before
  }

  bars <- data.frame(
    ts_utc = rep(as.POSIXct(paste(as.Date("2026-02-02") + 0:3, "16:00:00"), tz = "UTC"), each = 2L),
    instrument_id = rep(c("AAA", "BBB"), 4L),
    open = 10, high = 10, low = 10, close = 10, volume = 1000
  )
  path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(c(path, paste0(path, ".wal")), force = TRUE), add = TRUE)
  strategy <- function(ctx, params) ctx$flat()
  grid <- ledgr_param_grid(a = list(), b = list())

  testthat::expect_identical(opens(
    snapshot <- ledgr_snapshot_from_df(bars, db_path = path, snapshot_id = "lifecycle")
  ), 1L)
  testthat::expect_identical(opens(
    exp <- ledgr_experiment(snapshot, strategy, opening = ledgr_opening(cash = 1000), cost_model = ledgr_cost_zero())
  ), 1L)
  testthat::expect_identical(opens(bt <- ledgr_run(exp, run_id = "lifecycle_run")), 1L)
  testthat::expect_identical(opens(utils::capture.output(summary(bt))), 1L)
  testthat::expect_identical(opens(ledgr_results(bt, "fills")), 1L)
  testthat::expect_identical(opens(close(bt)), 1L)
  testthat::expect_identical(opens(ledgr_snapshot_info(snapshot)), 1L)
  testthat::expect_identical(opens(ledgr_feature_contract_check(snapshot, list(ledgr_ind_returns(1)))), 1L)
  testthat::expect_identical(opens(precomputed <- ledgr_precompute_features(exp, grid)), 1L)
  testthat::expect_identical(opens(ledgr_sweep(exp, grid)), 1L)
  testthat::expect_identical(opens(ledgr_sweep(exp, grid, precomputed_features = precomputed)), 1L)
  # The data-first wrapper reads the snapshot and commits a run; close() checkpoints.
  testthat::expect_identical(opens(close(ledgr_backtest(
    snapshot = snapshot, strategy = strategy, initial_cash = 1000, cost_model = ledgr_cost_zero()
  ))), 3L)

  # A connection the caller opened stays open and is reused, not reopened.
  held <- ledgr:::get_connection(snapshot)
  testthat::expect_identical(length(connections$all), 15L)
  ledgr_snapshot_info(snapshot)
  ledgr_experiment(snapshot, strategy, opening = ledgr_opening(cash = 1000), cost_model = ledgr_cost_zero())
  testthat::expect_true(DBI::dbIsValid(held))
  testthat::expect_identical(length(connections$all), 15L)
  ledgr_snapshot_close(snapshot)
  testthat::expect_false(DBI::dbIsValid(held))
})
