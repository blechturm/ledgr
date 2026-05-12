fifo_opening_bars <- function(prices_by_instrument) {
  ids <- names(prices_by_instrument)
  n <- length(prices_by_instrument[[1L]])
  ts <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * (seq_len(n) - 1L)

  do.call(
    rbind,
    lapply(ids, function(id) {
      prices <- as.numeric(prices_by_instrument[[id]])
      data.frame(
        instrument_id = id,
        ts_utc = ts,
        open = prices,
        high = prices,
        low = prices,
        close = prices,
        volume = rep(1000, n),
        stringsAsFactors = FALSE
      )
    })
  )
}

fifo_opening_setup <- function(prices_by_instrument) {
  db_path <- tempfile(fileext = ".duckdb")
  snapshot <- ledgr_snapshot_from_df(fifo_opening_bars(prices_by_instrument), db_path = db_path)
  list(db_path = db_path, snapshot = snapshot)
}

fifo_opening_config <- function(snapshot,
                                strategy,
                                opening,
                                fill_model = list(type = "next_open", spread_bps = 0, commission_fixed = 0),
                                execution_mode = "audit_log") {
  universe <- ledgr:::ledgr_infer_universe_from_snapshot(snapshot)
  ledgr_config(
    snapshot = snapshot,
    universe = universe,
    strategy = strategy,
    strategy_params = list(),
    backtest = ledgr_backtest_config(
      start = snapshot$metadata$start_date,
      end = snapshot$metadata$end_date,
      initial_cash = opening$cash
    ),
    features = list(),
    persist_features = TRUE,
    execution_mode = execution_mode,
    fill_model = fill_model,
    db_path = snapshot$db_path,
    opening = opening,
    seed = NULL
  )
}

fifo_opening_run <- function(snapshot,
                             strategy,
                             opening,
                             run_id,
                             fill_model = list(type = "next_open", spread_bps = 0, commission_fixed = 0),
                             execution_mode = "audit_log") {
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    opening = opening,
    fill_model = fill_model,
    execution_mode = execution_mode
  )
  ledgr_run(exp, run_id = run_id)
}

fifo_opening_reconstruct <- function(db_path, run_id) {
  opened <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  ledgr_state_reconstruct(run_id, opened$con)
}

fifo_opening_equity_detail <- function(db_path, run_id) {
  opened <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  DBI::dbGetQuery(
    opened$con,
    "
    SELECT ts_utc, cash, positions_value, equity, realized_pnl, unrealized_pnl
    FROM equity_curve
    WHERE run_id = ?
    ORDER BY ts_utc
    ",
    params = list(run_id)
  )
}

testthat::test_that("resume after partial opening-position liquidation does not double-count cost basis", {
  setup <- fifo_opening_setup(list(AAA = c(60, 60, 60, 60)))
  on.exit(ledgr_snapshot_close(setup$snapshot), add = TRUE)
  on.exit(unlink(setup$db_path), add = TRUE)

  target_by_ts <- c(
    "2020-01-01T00:00:00Z" = 60,
    "2020-01-02T00:00:00Z" = 0
  )
  strategy <- function(ctx, params) {
    targets <- ctx$hold()
    if (ctx$ts_utc %in% names(target_by_ts)) {
      targets["AAA"] <- unname(target_by_ts[[ctx$ts_utc]])
    }
    targets
  }

  run_id <- "fifo-opening-resume"
  cfg <- fifo_opening_config(
    setup$snapshot,
    strategy = strategy,
    opening = ledgr_opening(cash = 10000, positions = c(AAA = 100), cost_basis = c(AAA = 50))
  )

  ledgr:::ledgr_backtest_run_internal(cfg, run_id = run_id, control = list(max_pulses = 1L))
  gc()
  Sys.sleep(0.05)
  ledgr_backtest_run(cfg, run_id = run_id)

  bt <- ledgr:::new_ledgr_backtest(run_id, setup$db_path, cfg)
  on.exit(close(bt), add = TRUE)

  fills <- ledgr_results(bt, what = "fills")
  closes <- fills[fills$action == "CLOSE", , drop = FALSE]
  testthat::expect_equal(nrow(closes), 2L)
  testthat::expect_equal(closes$qty, c(40, 60))
  testthat::expect_equal(closes$realized_pnl, c(400, 600))

  equity <- fifo_opening_equity_detail(setup$db_path, run_id)
  testthat::expect_equal(equity$realized_pnl[[nrow(equity)]], 1000)
  testthat::expect_equal(equity$unrealized_pnl[[nrow(equity)]], 0)

  rebuilt <- fifo_opening_reconstruct(setup$db_path, run_id)
  testthat::expect_equal(rebuilt$positions$qty[rebuilt$positions$instrument_id == "AAA"], 0)
  testthat::expect_equal(rebuilt$equity_curve$realized_pnl[[nrow(rebuilt$equity_curve)]], 1000)
  testthat::expect_equal(rebuilt$equity_curve$unrealized_pnl[[nrow(rebuilt$equity_curve)]], 0)
})

testthat::test_that("opening-position lot drains before accumulated lots", {
  setup <- fifo_opening_setup(list(AAA = c(60, 60, 70, 80)))
  on.exit(ledgr_snapshot_close(setup$snapshot), add = TRUE)
  on.exit(unlink(setup$db_path), add = TRUE)

  target_by_ts <- c(
    "2020-01-01T00:00:00Z" = 100,
    "2020-01-02T00:00:00Z" = 50,
    "2020-01-03T00:00:00Z" = 0
  )
  strategy <- function(ctx, params) {
    targets <- ctx$hold()
    if (ctx$ts_utc %in% names(target_by_ts)) {
      targets["AAA"] <- unname(target_by_ts[[ctx$ts_utc]])
    }
    targets
  }

  bt <- fifo_opening_run(
    setup$snapshot,
    strategy = strategy,
    opening = ledgr_opening(cash = 10000, positions = c(AAA = 50), cost_basis = c(AAA = 40)),
    run_id = "fifo-opening-accumulation"
  )
  on.exit(close(bt), add = TRUE)

  fills <- ledgr_results(bt, what = "fills")
  closes <- fills[fills$action == "CLOSE", , drop = FALSE]
  testthat::expect_equal(nrow(closes), 2L)
  testthat::expect_equal(closes$qty, c(50, 50))
  testthat::expect_equal(closes$price, c(70, 80))
  testthat::expect_equal(closes$realized_pnl, c(1500, 1000))

  rebuilt <- fifo_opening_reconstruct(setup$db_path, bt$run_id)
  testthat::expect_equal(rebuilt$positions$qty[rebuilt$positions$instrument_id == "AAA"], 0)
  testthat::expect_equal(rebuilt$equity_curve$realized_pnl[[nrow(rebuilt$equity_curve)]], 2500)
})

testthat::test_that("opening-position lots are isolated across instruments", {
  setup <- fifo_opening_setup(list(AAA = c(60, 60, 60), BBB = c(40, 40, 40)))
  on.exit(ledgr_snapshot_close(setup$snapshot), add = TRUE)
  on.exit(unlink(setup$db_path), add = TRUE)

  strategy <- function(ctx, params) ctx$flat()
  bt <- fifo_opening_run(
    setup$snapshot,
    strategy = strategy,
    opening = ledgr_opening(
      cash = 10000,
      positions = c(AAA = 100, BBB = 200),
      cost_basis = c(AAA = 50, BBB = 30)
    ),
    run_id = "fifo-opening-multi-instrument"
  )
  on.exit(close(bt), add = TRUE)

  closes <- ledgr_results(bt, what = "fills")
  closes <- closes[closes$action == "CLOSE", , drop = FALSE]
  closes <- closes[order(closes$instrument_id), , drop = FALSE]

  testthat::expect_identical(closes$instrument_id, c("AAA", "BBB"))
  testthat::expect_equal(closes$qty, c(100, 200))
  testthat::expect_equal(closes$realized_pnl, c(1000, 2000))

  rebuilt <- fifo_opening_reconstruct(setup$db_path, bt$run_id)
  testthat::expect_equal(rebuilt$equity_curve$realized_pnl[[nrow(rebuilt$equity_curve)]], 3000)
})

testthat::test_that("opening-position fills keep gross fill P&L separate from net equity P&L", {
  setup <- fifo_opening_setup(list(AAA = c(60, 60, 60)))
  on.exit(ledgr_snapshot_close(setup$snapshot), add = TRUE)
  on.exit(unlink(setup$db_path), add = TRUE)

  strategy <- function(ctx, params) ctx$flat()
  bt <- fifo_opening_run(
    setup$snapshot,
    strategy = strategy,
    opening = ledgr_opening(cash = 10000, positions = c(AAA = 100), cost_basis = c(AAA = 50)),
    fill_model = list(type = "next_open", spread_bps = 0, commission_fixed = 5),
    run_id = "fifo-opening-fee"
  )
  on.exit(close(bt), add = TRUE)

  fills <- ledgr_results(bt, what = "fills")
  testthat::expect_equal(fills$fee[[1]], 5)
  testthat::expect_equal(fills$realized_pnl[[1]], 1000)

  equity <- fifo_opening_equity_detail(setup$db_path, bt$run_id)
  testthat::expect_equal(equity$realized_pnl[[nrow(equity)]], 995)
  testthat::expect_equal(equity$unrealized_pnl[[nrow(equity)]], 0)

  metrics <- ledgr_compute_metrics(bt)
  testthat::expect_equal(metrics$avg_trade, 1000)
  testthat::expect_equal(metrics$n_trades, 1L)
})

testthat::test_that("opening-position liquidation can flip into a short lot", {
  setup <- fifo_opening_setup(list(AAA = c(60, 60, 55)))
  on.exit(ledgr_snapshot_close(setup$snapshot), add = TRUE)
  on.exit(unlink(setup$db_path), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["AAA"] <- -150
    targets
  }

  bt <- fifo_opening_run(
    setup$snapshot,
    strategy = strategy,
    opening = ledgr_opening(cash = 10000, positions = c(AAA = 100), cost_basis = c(AAA = 50)),
    run_id = "fifo-opening-flip"
  )
  on.exit(close(bt), add = TRUE)

  fills <- ledgr_results(bt, what = "fills")
  testthat::expect_equal(nrow(fills), 2L)
  testthat::expect_identical(fills$action, c("CLOSE", "OPEN"))
  testthat::expect_equal(fills$qty, c(100, 150))
  testthat::expect_equal(fills$realized_pnl, c(1000, 0))

  rebuilt <- fifo_opening_reconstruct(setup$db_path, bt$run_id)
  testthat::expect_equal(rebuilt$positions$qty[rebuilt$positions$instrument_id == "AAA"], -150)
  testthat::expect_equal(rebuilt$equity_curve$realized_pnl[[nrow(rebuilt$equity_curve)]], 1000)
  testthat::expect_equal(rebuilt$equity_curve$unrealized_pnl[[nrow(rebuilt$equity_curve)]], 750)
})

testthat::test_that("db_live and audit_log opening-position accounting agree", {
  run_mode <- function(mode) {
    setup <- fifo_opening_setup(list(AAA = c(60, 60, 60)))
    on.exit(ledgr_snapshot_close(setup$snapshot), add = TRUE)
    on.exit(unlink(setup$db_path), add = TRUE)

    strategy <- function(ctx, params) ctx$flat()
    bt <- fifo_opening_run(
      setup$snapshot,
      strategy = strategy,
      opening = ledgr_opening(cash = 10000, positions = c(AAA = 100), cost_basis = c(AAA = 50)),
      execution_mode = mode,
      run_id = paste0("fifo-opening-", mode)
    )
    on.exit(close(bt), add = TRUE)

    list(
      fills = ledgr_results(bt, what = "fills")[, c("instrument_id", "side", "qty", "price", "fee", "realized_pnl", "action")],
      equity = fifo_opening_equity_detail(setup$db_path, bt$run_id)[, c("cash", "positions_value", "equity", "realized_pnl", "unrealized_pnl")],
      rebuilt = fifo_opening_reconstruct(setup$db_path, bt$run_id)
    )
  }

  audit_log <- run_mode("audit_log")
  db_live <- run_mode("db_live")

  testthat::expect_equal(db_live$fills, audit_log$fills)
  testthat::expect_equal(db_live$equity, audit_log$equity)
  testthat::expect_equal(db_live$rebuilt$positions, audit_log$rebuilt$positions)
  testthat::expect_equal(
    db_live$rebuilt$equity_curve[, c("cash", "positions_value", "equity", "realized_pnl", "unrealized_pnl")],
    audit_log$rebuilt$equity_curve[, c("cash", "positions_value", "equity", "realized_pnl", "unrealized_pnl")]
  )
})
