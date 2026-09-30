testthat::test_that("[LTB-0131] public calls open the store once, plus once per committed run, and leave no connection open", {
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

  # Composite calls open the store once for their own reads and writes, plus
  # once for each run they commit; the readers of what they wrote open once.
  wf_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(c(wf_path, paste0(wf_path, ".wal")), force = TRUE), add = TRUE)
  wf_bars <- data.frame(
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:11,
    instrument_id = "AAA",
    open = 100 + 1:12, high = 101 + 1:12, low = 99 + 1:12, close = 100 + 1:12, volume = 1000
  )
  wf_snapshot <- ledgr_snapshot_from_df(wf_bars, db_path = wf_path)
  wf_strategy <- function(ctx, params) {
    targets <- ctx$flat()
    if (ctx$close("AAA") >= params$threshold) targets["AAA"] <- params$qty
    targets
  }
  wf_exp <- ledgr_experiment(
    wf_snapshot, wf_strategy, opening = ledgr_opening(cash = 10000), cost_model = ledgr_cost_zero()
  )
  folds <- ledgr:::ledgr_fold_list(
    list(
      ledgr_fold("2020-01-01", "2020-01-04", "2020-01-05", "2020-01-07", fold_seq = 1L),
      ledgr_fold("2020-01-04", "2020-01-07", "2020-01-08", "2020-01-10", fold_seq = 2L)
    ),
    constructor = list(type_id = "explicit")
  )
  testthat::expect_identical(opens(wf <- ledgr_walk_forward(
    wf_exp,
    grid = ledgr_param_grid(trade = list(qty = 1, threshold = 101)),
    folds = folds,
    selection_rule = ledgr_rule_argmax("sharpe_ratio"),
    seed = 101L
  )), 3L)
  testthat::expect_identical(opens(invisible(lapply(wf$test_runs, close))), 2L)
  testthat::expect_identical(opens(ledgr_walk_forward_open(wf_snapshot, wf$session_id)), 1L)
  testthat::expect_identical(opens(ledgr_walk_forward_scores(wf_snapshot, wf$session_id)), 1L)
  testthat::expect_identical(opens(ledgr_walk_forward_folds(wf_snapshot, wf$session_id)), 1L)
  testthat::expect_identical(opens(candidate <- ledgr_candidate(wf, fold_seq = 1L)), 1L)
  testthat::expect_identical(opens(ledgr_candidate(wf, fold_seq = 1L, snapshot = wf_snapshot)), 1L)
  testthat::expect_identical(opens(
    promoted <- ledgr_promote(wf_exp, candidate, run_id = "lifecycle_promoted")
  ), 2L)
  testthat::expect_identical(opens(close(promoted)), 1L)

  # Interactive contexts read what they need when built and keep no connection.
  testthat::expect_identical(opens(
    pulse <- ledgr_pulse_snapshot(wf_snapshot, "AAA", "2020-01-05T00:00:00Z")
  ), 1L)
  testthat::expect_identical(opens(close(pulse)), 0L)
  testthat::expect_identical(opens(
    dev <- ledgr_indicator_dev(wf_snapshot, "AAA", "2020-01-06T00:00:00Z", lookback = 3)
  ), 1L)
  testthat::expect_identical(opens(dev$test_dates(
    function(window) mean(window$close),
    c("2020-01-05T00:00:00Z", "2020-01-06T00:00:00Z")
  )), 1L)
  testthat::expect_identical(opens(close(dev)), 0L)

  # A snapshot that borrowed a call's held connection does not close it.
  release <- ledgr:::ledgr_store_hold(wf_path)
  borrower <- ledgr_snapshot_open(wf_path)
  held_store <- ledgr:::get_connection(borrower)
  ledgr_snapshot_close(borrower)
  testthat::expect_true(DBI::dbIsValid(held_store))
  release()
  testthat::expect_false(DBI::dbIsValid(held_store))
  ledgr_snapshot_close(wf_snapshot)
})

testthat::test_that("[LTB-0132] ledgr opens a store the user holds open with their own DuckDB connection", {
  bars <- data.frame(
    ts_utc = rep(as.POSIXct(paste(as.Date("2026-02-02") + 0:3, "16:00:00"), tz = "UTC"), each = 2L),
    instrument_id = rep(c("AAA", "BBB"), 4L),
    open = 10, high = 10, low = 10, close = 10, volume = 1000
  )
  path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(c(path, paste0(path, ".wal")), force = TRUE), add = TRUE)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = path, snapshot_id = "user_held")
  ledgr_snapshot_close(snapshot)

  # A connection with DuckDB's default instance settings, not ledgr's.
  drv <- duckdb::duckdb()
  con <- DBI::dbConnect(drv, dbdir = path)
  on.exit(duckdb::duckdb_shutdown(drv), add = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  exp <- ledgr_experiment(
    snapshot, function(ctx, params) ctx$flat(),
    opening = ledgr_opening(cash = 1000), cost_model = ledgr_cost_zero()
  )
  bt <- ledgr_run(exp, run_id = "user_held_run")
  testthat::expect_identical(nrow(ledgr_results(bt, "equity")), 4L)
  close(bt)
  testthat::expect_true(DBI::dbIsValid(con))
  testthat::expect_identical(
    DBI::dbGetQuery(con, "SELECT run_id FROM runs")$run_id,
    "user_held_run"
  )
})
