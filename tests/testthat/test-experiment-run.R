testthat::test_that("ledgr_run executes an experiment with fixed features", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:4)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    if (ctx$close("AAA") > 0) {
      targets["AAA"] <- params$qty
    }
    targets
  }
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    features = list(ledgr_ind_sma(2)),
    opening = ledgr_opening(cash = 10000),
    universe = "AAA"
  )

  bt <- ledgr_run(exp, params = list(qty = 1), run_id = "experiment-run")
  on.exit(close(bt), add = TRUE)

  testthat::expect_s3_class(bt, "ledgr_backtest")
  testthat::expect_identical(bt$run_id, "experiment-run")
  fills <- ledgr_extract_fills(bt)
  testthat::expect_true(nrow(fills) > 0L)
})

testthat::test_that("ledgr_run evaluates feature functions once per run", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:4)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  features <- function(params) {
    calls$n <- calls$n + 1L
    list(ledgr_ind_sma(params$n))
  }
  strategy <- function(ctx, params) ctx$flat()
  exp <- ledgr_experiment(snapshot = snapshot, strategy = strategy, features = features)

  bt <- ledgr_run(exp, params = list(n = 2), run_id = "feature-fn-run")
  on.exit(close(bt), add = TRUE)

  testthat::expect_identical(calls$n, 1L)
  testthat::expect_s3_class(bt, "ledgr_backtest")
})

testthat::test_that("ledgr_run accepts execution seeds and stores them in config identity", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:4)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    if (stats::runif(1) > 0) {
      targets["AAA"] <- 1
    }
    targets
  }
  exp <- ledgr_experiment(snapshot = snapshot, strategy = strategy)

  bt_seeded <- ledgr_run(exp, seed = 123L, run_id = "seeded-run")
  on.exit(close(bt_seeded), add = TRUE)
  seeded_config_json <- ledgr_run_info(snapshot, "seeded-run")$config_json
  seeded_cfg <- jsonlite::fromJSON(seeded_config_json, simplifyVector = FALSE)
  testthat::expect_identical(seeded_cfg$engine$seed, 123L)

  bt <- ledgr_run(exp, run_id = "null-seed-run")
  on.exit(close(bt), add = TRUE)
  config_json <- ledgr_run_info(snapshot, "null-seed-run")$config_json
  cfg <- jsonlite::fromJSON(config_json, simplifyVector = FALSE)
  testthat::expect_null(cfg$engine$seed)
})

testthat::test_that("ledgr_run with seed NULL uses ambient strategy RNG without resetting it", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:4)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$hold()
    if (all(targets == 0)) {
      targets["AAA"] <- floor(stats::runif(1) * 10) + 1
    }
    targets
  }
  exp <- ledgr_experiment(snapshot = snapshot, strategy = strategy)

  set.seed(9876)
  expected_qty <- floor(stats::runif(1) * 10) + 1
  set.seed(9876)
  bt <- ledgr_run(exp, run_id = "null-seed-rng-state", seed = NULL)
  on.exit(close(bt), add = TRUE)
  fills <- ledgr_extract_fills(bt)
  testthat::expect_equal(fills$qty[[1]], expected_qty)
})

testthat::test_that("ledgr_run matches equivalent ledgr_backtest output", {
  db_path_exp <- tempfile(fileext = ".duckdb")
  db_path_legacy <- tempfile(fileext = ".duckdb")
  on.exit(unlink(c(db_path_exp, db_path_legacy)), add = TRUE)

  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:4)
  snapshot_exp <- ledgr_snapshot_from_df(bars, db_path = db_path_exp)
  snapshot_legacy <- ledgr_snapshot_from_df(bars, db_path = db_path_legacy)
  on.exit(ledgr_snapshot_close(snapshot_exp), add = TRUE)
  on.exit(ledgr_snapshot_close(snapshot_legacy), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["AAA"] <- params$qty
    targets
  }
  params <- list(qty = 1)
  exp <- ledgr_experiment(
    snapshot = snapshot_exp,
    strategy = strategy,
    opening = ledgr_opening(cash = 10000),
    universe = "AAA"
  )

  bt_exp <- ledgr_run(exp, params = params, run_id = "exp-parity")
  bt_legacy <- ledgr_backtest(
    snapshot = snapshot_legacy,
    strategy = strategy,
    strategy_params = params,
    universe = "AAA",
    start = snapshot_legacy$metadata$start_date,
    end = snapshot_legacy$metadata$end_date,
    initial_cash = 10000,
    db_path = db_path_legacy,
    run_id = "legacy-parity"
  )
  on.exit(close(bt_exp), add = TRUE)
  on.exit(close(bt_legacy), add = TRUE)

  equity_exp <- tibble::as_tibble(bt_exp, what = "equity")
  equity_legacy <- tibble::as_tibble(bt_legacy, what = "equity")
  testthat::expect_equal(equity_exp$equity, equity_legacy$equity)
  testthat::expect_equal(equity_exp$cash, equity_legacy$cash)
})

testthat::test_that("ledgr_run records opening positions as ledger events", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:2)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) ctx$hold()
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    opening = ledgr_opening(cash = 1000, positions = c(AAA = 1), cost_basis = c(AAA = 100))
  )

  bt <- ledgr_run(exp, run_id = "opening-position-run")
  on.exit(close(bt), add = TRUE)

  ledger <- tibble::as_tibble(bt, what = "ledger")
  opening <- ledger[ledger$event_type == "CASHFLOW" & ledger$instrument_id == "AAA", , drop = FALSE]
  testthat::expect_equal(nrow(opening), 1L)
  testthat::expect_identical(as.character(opening$instrument_id[[1]]), "AAA")
  testthat::expect_equal(as.numeric(opening$qty[[1]]), 1)
  meta <- jsonlite::fromJSON(opening$meta_json[[1]], simplifyVector = FALSE)
  testthat::expect_identical(meta$source, "opening_position")

  opened <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  state <- ledgr_state_reconstruct("opening-position-run", opened$con)
  testthat::expect_equal(state$positions$qty[state$positions$instrument_id == "AAA"], 1)
  testthat::expect_equal(state$cash$cash[[nrow(state$cash)]], 1000)
})

testthat::test_that("opening position cost basis seeds FIFO accounting", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  bars <- data.frame(
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:2,
    instrument_id = "AAA",
    open = c(60, 60, 60),
    high = c(60, 60, 60),
    low = c(60, 60, 60),
    close = c(60, 60, 60),
    volume = c(1000, 1000, 1000),
    stringsAsFactors = FALSE
  )
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) ctx$flat()
  run_id <- "opening-position-cost-basis-run"
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    opening = ledgr_opening(cash = 1000, positions = c(AAA = 1), cost_basis = c(AAA = 50))
  )

  bt <- ledgr_run(exp, run_id = run_id)
  on.exit(close(bt), add = TRUE)

  fills <- ledgr_results(bt, what = "fills")
  testthat::expect_equal(nrow(fills), 1L)
  testthat::expect_identical(fills$side[[1]], "SELL")
  testthat::expect_identical(fills$action[[1]], "CLOSE")
  testthat::expect_equal(fills$realized_pnl[[1]], 10)

  trades <- ledgr_results(bt, what = "trades")
  testthat::expect_equal(nrow(trades), 1L)
  testthat::expect_equal(trades$realized_pnl[[1]], 10)

  equity <- ledgr_results(bt, what = "equity")
  testthat::expect_equal(equity$cash[[nrow(equity)]], 1060)
  testthat::expect_equal(equity$equity[[nrow(equity)]], 1060)

  metrics <- ledgr_compute_metrics(bt)
  testthat::expect_identical(metrics$n_trades, 1L)
  testthat::expect_equal(metrics$win_rate, 1)
  testthat::expect_equal(metrics$avg_trade, 10)

  cmp <- ledgr_compare_runs(snapshot, run_ids = run_id)
  testthat::expect_identical(cmp$n_trades, 1L)
  testthat::expect_equal(cmp$win_rate, 1)
  testthat::expect_equal(cmp$avg_trade, 10)

  opened <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  persisted_equity <- DBI::dbGetQuery(
    opened$con,
    "SELECT realized_pnl, unrealized_pnl FROM equity_curve WHERE run_id = ? ORDER BY ts_utc",
    params = list(run_id)
  )
  testthat::expect_equal(persisted_equity$unrealized_pnl[[1]], 10)
  testthat::expect_equal(persisted_equity$realized_pnl[[nrow(persisted_equity)]], 10)
  testthat::expect_equal(persisted_equity$unrealized_pnl[[nrow(persisted_equity)]], 0)

  rebuilt <- ledgr_state_reconstruct(run_id, opened$con)
  testthat::expect_equal(rebuilt$equity_curve$realized_pnl[[nrow(rebuilt$equity_curve)]], 10)
  testthat::expect_equal(rebuilt$equity_curve$unrealized_pnl[[nrow(rebuilt$equity_curve)]], 0)
})

testthat::test_that("ledgr_run accepts params = list()", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:2)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    testthat::expect_identical(params, list())
    ctx$flat()
  }
  exp <- ledgr_experiment(snapshot = snapshot, strategy = strategy)

  bt <- ledgr_run(exp, run_id = "empty-params-experiment")
  on.exit(close(bt), add = TRUE)
  testthat::expect_s3_class(bt, "ledgr_backtest")
})

testthat::test_that("ledgr_run validates run_id", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:2)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(snapshot = snapshot, strategy = function(ctx, params) ctx$flat())

  testthat::expect_error(
    ledgr_run(exp, run_id = ""),
    class = "ledgr_invalid_args"
  )
})

testthat::test_that("ledgr_run validates params before execution", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:2)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(snapshot = snapshot, strategy = function(ctx, params) ctx$flat())

  testthat::expect_error(
    ledgr_run(exp, params = "bad", run_id = "bad-params-run"),
    class = "ledgr_invalid_args"
  )
  testthat::expect_error(
    ledgr_run(exp, params = "bad", run_id = "bad-params-run"),
    "`params` must be a list",
    fixed = TRUE
  )
})
