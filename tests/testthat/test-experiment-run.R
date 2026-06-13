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
    universe = "AAA",
    cost_model = ledgr_cost_zero()
  )

  bt <- ledgr_run(exp, params = list(qty = 1), run_id = "experiment-run")
  on.exit(close(bt), add = TRUE)

  testthat::expect_s3_class(bt, "ledgr_backtest")
  testthat::expect_identical(bt$run_id, "experiment-run")
  fills <- ledgr_run_fills(bt)
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
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    features = features,
    cost_model = ledgr_cost_zero()
  )

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
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    cost_model = ledgr_cost_zero()
  )

  bt_seeded <- ledgr_run(exp, seed = 123L, run_id = "seeded-run")
  on.exit(close(bt_seeded), add = TRUE)
  seeded_config_json <- ledgr_run_info(snapshot, "seeded-run")$config_json
  seeded_cfg <- ledgr:::ledgr_json_read_nested(seeded_config_json)
  testthat::expect_identical(seeded_cfg$engine$seed, 123L)

  bt <- ledgr_run(exp, run_id = "null-seed-run")
  on.exit(close(bt), add = TRUE)
  config_json <- ledgr_run_info(snapshot, "null-seed-run")$config_json
  cfg <- ledgr:::ledgr_json_read_nested(config_json)
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
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    cost_model = ledgr_cost_zero()
  )

  set.seed(9876)
  expected_qty <- floor(stats::runif(1) * 10) + 1
  set.seed(9876)
  bt <- ledgr_run(exp, run_id = "null-seed-rng-state", seed = NULL)
  on.exit(close(bt), add = TRUE)
  fills <- ledgr_run_fills(bt)
  testthat::expect_equal(fills$qty[[1]], expected_qty)
})

testthat::test_that("pulse_seed is exposed as a stable per-pulse strategy input", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:4)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  observed <- new.env(parent = emptyenv())
  observed$seed <- integer()
  observed$pulse_seed <- integer()
  strategy <- function(ctx, params) {
    observed$seed <- c(observed$seed, ctx$seed)
    observed$pulse_seed <- c(observed$pulse_seed, ctx$pulse_seed)
    ctx$flat()
  }
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    cost_model = ledgr_cost_zero()
  )

  bt <- ledgr_run(exp, run_id = "pulse-seed-context", seed = 2026L)
  on.exit(close(bt), add = TRUE)

  expected <- vapply(
    seq_along(observed$pulse_seed),
    function(i) ledgr:::ledgr_derive_pulse_seed(2026L, i),
    integer(1)
  )
  testthat::expect_identical(observed$seed, rep(2026L, length(expected)))
  testthat::expect_identical(observed$pulse_seed, expected)
})

testthat::test_that("pulse_seed strategies reproduce across continuous and resumed runs", {
  db_clean <- tempfile(fileext = ".duckdb")
  db_resume <- tempfile(fileext = ".duckdb")
  on.exit(unlink(c(db_clean, db_resume)), add = TRUE)

  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:6)
  snap_clean <- ledgr_snapshot_from_df(bars, db_path = db_clean)
  snap_resume <- ledgr_snapshot_from_df(bars, db_path = db_resume)
  on.exit(ledgr_snapshot_close(snap_clean), add = TRUE)
  on.exit(ledgr_snapshot_close(snap_resume), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    if (!is.null(ctx$pulse_seed) && (ctx$pulse_seed %% 3L) == 0L) {
      targets["AAA"] <- params$qty
    }
    targets
  }
  cfg_clean <- ledgr_config(
    snapshot = snap_clean,
    universe = "AAA",
    strategy = strategy,
    strategy_params = list(qty = 1),
    backtest = ledgr_backtest_config(
      start = snap_clean$metadata$start_date,
      end = snap_clean$metadata$end_date,
      initial_cash = 10000
    ),
    db_path = db_clean,
    seed = 2026L,
    cost_model_hash = ledgr:::ledgr_cost_model_hash(ledgr_cost_zero()),
    cost_plan_json = ledgr:::ledgr_cost_plan_json(ledgr_cost_zero())
  )
  cfg_resume <- ledgr_config(
    snapshot = snap_resume,
    universe = "AAA",
    strategy = strategy,
    strategy_params = list(qty = 1),
    backtest = ledgr_backtest_config(
      start = snap_resume$metadata$start_date,
      end = snap_resume$metadata$end_date,
      initial_cash = 10000
    ),
    db_path = db_resume,
    seed = 2026L,
    cost_model_hash = ledgr:::ledgr_cost_model_hash(ledgr_cost_zero()),
    cost_plan_json = ledgr:::ledgr_cost_plan_json(ledgr_cost_zero())
  )

  suppressWarnings(ledgr_backtest_run(cfg_clean, run_id = "pulse-seed-clean"))
  ledgr:::ledgr_backtest_run_internal(
    cfg_resume,
    run_id = "pulse-seed-resume",
    control = list(max_pulses = 2L)
  )
  suppressWarnings(ledgr_backtest_run(cfg_resume, run_id = "pulse-seed-resume"))

  clean <- ledgr:::new_ledgr_backtest("pulse-seed-clean", db_clean, cfg_clean)
  resumed <- ledgr:::new_ledgr_backtest("pulse-seed-resume", db_resume, cfg_resume)
  on.exit(close(clean), add = TRUE)
  on.exit(close(resumed), add = TRUE)

  testthat::expect_equal(
    ledgr_results(clean, "equity"),
    ledgr_results(resumed, "equity")
  )
  clean_ledger <- ledgr_results(clean, "ledger")
  resumed_ledger <- ledgr_results(resumed, "ledger")
  identity_cols <- c("event_id", "run_id")
  testthat::expect_equal(
    clean_ledger[setdiff(names(clean_ledger), identity_cols)],
    resumed_ledger[setdiff(names(resumed_ledger), identity_cols)]
  )
})

testthat::test_that("ambient RNG strategies fail loudly on resume", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  bars <- ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:6)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    if (stats::runif(1) > 0.25) {
      targets["AAA"] <- 1
    }
    targets
  }
  cfg <- ledgr_config(
    snapshot = snapshot,
    universe = "AAA",
    strategy = strategy,
    backtest = ledgr_backtest_config(
      start = snapshot$metadata$start_date,
      end = snapshot$metadata$end_date,
      initial_cash = 10000
    ),
    db_path = db_path,
    seed = 2026L,
    cost_model_hash = ledgr:::ledgr_cost_model_hash(ledgr_cost_zero()),
    cost_plan_json = ledgr:::ledgr_cost_plan_json(ledgr_cost_zero())
  )

  ledgr:::ledgr_backtest_run_internal(
    cfg,
    run_id = "ambient-rng-resume",
    control = list(max_pulses = 2L)
  )

  err <- testthat::capture_error(
    ledgr_backtest_run(cfg, run_id = "ambient-rng-resume")
  )
  testthat::expect_s3_class(err, "ledgr_strategy_ambient_rng_resume")
  testthat::expect_match(conditionMessage(err), "runif", fixed = TRUE)
  testthat::expect_match(conditionMessage(err), "ctx$pulse_seed", fixed = TRUE)
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
    universe = "AAA",
    cost_model = ledgr_cost_zero()
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
    run_id = "legacy-parity",
    cost_model = ledgr_cost_zero()
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
    opening = ledgr_opening(cash = 1000, positions = c(AAA = 1), cost_basis = c(AAA = 100)),
    cost_model = ledgr_cost_zero()
  )

  bt <- ledgr_run(exp, run_id = "opening-position-run")
  on.exit(close(bt), add = TRUE)

  ledger <- tibble::as_tibble(bt, what = "ledger")
  opening <- ledger[ledger$event_type == "CASHFLOW" & ledger$instrument_id == "AAA", , drop = FALSE]
  testthat::expect_equal(nrow(opening), 1L)
  testthat::expect_identical(as.character(opening$instrument_id[[1]]), "AAA")
  testthat::expect_equal(as.numeric(opening$qty[[1]]), 1)
  meta <- ledgr:::ledgr_json_read_nested(opening$meta_json[[1]])
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
    opening = ledgr_opening(cash = 1000, positions = c(AAA = 1), cost_basis = c(AAA = 50)),
    cost_model = ledgr_cost_zero()
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

  cmp <- ledgr_run_compare(snapshot, run_ids = run_id)
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
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    cost_model = ledgr_cost_zero()
  )

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
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = function(ctx, params) ctx$flat(),
    cost_model = ledgr_cost_zero()
  )

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
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = function(ctx, params) ctx$flat(),
    cost_model = ledgr_cost_zero()
  )

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
