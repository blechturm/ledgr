ledgr_compare_test_table_counts <- function(con) {
  tables <- c("runs", "run_provenance", "run_telemetry", "ledger_events", "equity_curve", "features")
  stats::setNames(
    vapply(tables, function(table) {
      if (!ledgr:::ledgr_experiment_store_table_exists(con, table)) return(NA_integer_)
      as.integer(DBI::dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM %s", table))$n[[1]])
    }, integer(1)),
    tables
  )
}

testthat::test_that("ledgr_compare_runs compares stored completed runs without recomputation", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)
  snapshot <- ledgr_snapshot_from_df(test_bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  strategy <- function(ctx, params) {
    calls$n <- calls$n + 1L
    targets <- ctx$flat()
    targets["TEST_A"] <- params$qty
    targets
  }

  bt_a <- ledgr_backtest(
    snapshot = snapshot,
    strategy = strategy,
    strategy_params = list(qty = 1),
    start = "2020-01-01",
    end = "2020-01-05",
    db_path = db_path,
    run_id = "compare-qty-1"
  )
  on.exit(close(bt_a), add = TRUE)
  bt_b <- ledgr_backtest(
    snapshot = snapshot,
    strategy = strategy,
    strategy_params = list(qty = 2),
    start = "2020-01-01",
    end = "2020-01-05",
    db_path = db_path,
    run_id = "compare-qty-2"
  )
  on.exit(close(bt_b), add = TRUE)
  snapshot <- ledgr_test_snapshot_for_run(db_path, bt_a)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  before_calls <- calls$n
  opened <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  before_counts <- ledgr_compare_test_table_counts(opened$con)

  cmp <- ledgr_compare_runs(snapshot, run_ids = c("compare-qty-2", "compare-qty-1"))

  after_counts <- ledgr_compare_test_table_counts(opened$con)
  testthat::expect_identical(calls$n, before_calls)
  testthat::expect_identical(after_counts, before_counts)
  testthat::expect_identical(cmp$run_id, c("compare-qty-2", "compare-qty-1"))
  testthat::expect_true(all(c(
    "final_equity", "total_return", "max_drawdown", "n_trades", "win_rate",
    "execution_mode", "elapsed_sec", "strategy_source_hash",
    "strategy_params_hash", "config_hash", "snapshot_hash"
  ) %in% names(cmp)))
  testthat::expect_true(all(cmp$status == "DONE"))
  testthat::expect_true(all(is.finite(cmp$final_equity)))
  testthat::expect_true(all(!is.na(cmp$strategy_params_hash)))
})

testthat::test_that("ledgr_compare_runs compares different stored strategies", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)
  snapshot <- ledgr_snapshot_from_df(test_bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  buy_one <- function(ctx, params) {
    targets <- ctx$flat()
    targets["TEST_A"] <- 1
    targets
  }
  buy_two <- function(ctx, params) {
    targets <- ctx$flat()
    targets["TEST_A"] <- 2
    targets
  }

  bt_a <- ledgr_backtest(
    snapshot = snapshot,
    strategy = buy_one,
    start = "2020-01-01",
    end = "2020-01-05",
    db_path = db_path,
    run_id = "compare-strategy-a"
  )
  on.exit(close(bt_a), add = TRUE)
  bt_b <- ledgr_backtest(
    snapshot = snapshot,
    strategy = buy_two,
    start = "2020-01-01",
    end = "2020-01-05",
    db_path = db_path,
    run_id = "compare-strategy-b"
  )
  on.exit(close(bt_b), add = TRUE)
  cmp <- ledgr_compare_runs(snapshot, run_ids = c("compare-strategy-a", "compare-strategy-b"))
  testthat::expect_identical(nrow(cmp), 2L)
  testthat::expect_false(identical(cmp$strategy_source_hash[[1]], cmp$strategy_source_hash[[2]]))
})

testthat::test_that("ledgr_compare_runs counts only closing trades for win rate", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  bars <- data.frame(
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:3,
    instrument_id = "AAA",
    open = c(100, 100, 110, 110),
    high = c(100, 100, 110, 110),
    low = c(100, 100, 110, 110),
    close = c(100, 100, 110, 110),
    volume = c(1, 1, 1, 1),
    stringsAsFactors = FALSE
  )
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    if (ctx$ts_utc == "2020-01-01T00:00:00Z") {
      targets["AAA"] <- 10
    }
    targets
  }

  bt <- ledgr_backtest(
    data = bars,
    strategy = strategy,
    initial_cash = 2000,
    db_path = db_path,
    run_id = "compare-roundtrip"
  )
  on.exit(close(bt), add = TRUE)
  snapshot <- ledgr_test_snapshot_for_run(db_path, bt)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  cmp <- ledgr_compare_runs(snapshot, run_ids = "compare-roundtrip")
  testthat::expect_identical(cmp$n_trades, 1L)
  testthat::expect_equal(cmp$win_rate, 1)
})

testthat::test_that("ledgr_compare_runs respects archive and incomplete-run rules", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  strategy <- function(ctx, params) ctx$flat()
  bt <- ledgr_backtest(
    data = test_bars,
    strategy = strategy,
    start = "2020-01-01",
    end = "2020-01-05",
    db_path = db_path,
    run_id = "compare-archived"
  )
  on.exit(close(bt), add = TRUE)
  snapshot <- ledgr_test_snapshot_for_run(db_path, bt)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  ledgr_run_archive(snapshot, "compare-archived", reason = "test")

  testthat::expect_false("compare-archived" %in% ledgr_compare_runs(snapshot)$run_id)
  testthat::expect_true("compare-archived" %in% ledgr_compare_runs(snapshot, include_archived = TRUE)$run_id)
  testthat::expect_true("compare-archived" %in% ledgr_compare_runs(snapshot, run_ids = "compare-archived")$run_id)
  duplicate <- ledgr_compare_runs(snapshot, run_ids = c("compare-archived", "compare-archived"))
  testthat::expect_identical(duplicate$run_id, c("compare-archived", "compare-archived"))

  bad_strategy <- function(ctx, params) stop("compare failure")
  testthat::expect_error(
    ledgr_backtest(
      snapshot = snapshot,
      strategy = bad_strategy,
      start = "2020-01-01",
      end = "2020-01-05",
      db_path = db_path,
      run_id = "compare-failed"
    ),
    "compare failure",
    fixed = TRUE
  )

  testthat::expect_error(
    ledgr_compare_runs(snapshot, run_ids = "compare-failed"),
    "Use ledgr_run_info()",
    class = "ledgr_run_not_complete"
  )
  testthat::expect_error(
    ledgr_compare_runs(snapshot, run_ids = "missing-run"),
    class = "ledgr_run_not_found"
  )
  testthat::expect_error(
    ledgr_compare_runs(snapshot, metrics = "experimental"),
    class = "ledgr_invalid_args"
  )
})

testthat::test_that("ledgr_compare_runs tolerates legacy pre-provenance runs without mutation", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)
  opened <- ledgr_test_open_duckdb(db_path)
  con <- opened$con

  DBI::dbExecute(con, "
    CREATE TABLE snapshots (
      snapshot_id TEXT NOT NULL PRIMARY KEY,
      status TEXT NOT NULL,
      created_at_utc TIMESTAMP NOT NULL,
      sealed_at_utc TIMESTAMP,
      snapshot_hash TEXT,
      meta_json TEXT
    )
  ")
  DBI::dbExecute(con, "
    CREATE TABLE snapshot_instruments (
      snapshot_id TEXT NOT NULL,
      instrument_id TEXT NOT NULL,
      meta_json TEXT,
      PRIMARY KEY (snapshot_id, instrument_id)
    )
  ")
  DBI::dbExecute(con, "
    CREATE TABLE snapshot_bars (
      snapshot_id TEXT NOT NULL,
      instrument_id TEXT NOT NULL,
      ts_utc TIMESTAMP NOT NULL,
      open DOUBLE NOT NULL,
      high DOUBLE NOT NULL,
      low DOUBLE NOT NULL,
      close DOUBLE NOT NULL,
      volume DOUBLE,
      PRIMARY KEY (snapshot_id, instrument_id, ts_utc)
    )
  ")
  DBI::dbExecute(con, "
    INSERT INTO snapshots (
      snapshot_id, status, created_at_utc, sealed_at_utc, snapshot_hash, meta_json
    ) VALUES (
      'snap', 'SEALED', TIMESTAMP '2020-01-01 00:00:00',
      TIMESTAMP '2020-01-01 00:00:00', 'legacy-hash', '{}'
    )
  ")
  DBI::dbExecute(con, "
    INSERT INTO snapshot_instruments (snapshot_id, instrument_id, meta_json)
    VALUES ('snap', 'TEST_A', '{}')
  ")
  DBI::dbExecute(con, "
    CREATE TABLE runs (
      run_id TEXT NOT NULL PRIMARY KEY,
      created_at_utc TIMESTAMP,
      engine_version TEXT,
      config_json TEXT,
      config_hash TEXT,
      data_hash TEXT,
      snapshot_id TEXT,
      status TEXT,
      error_msg TEXT
    )
  ")
  DBI::dbExecute(con, "
    CREATE TABLE equity_curve (
      run_id TEXT NOT NULL,
      ts_utc TIMESTAMP NOT NULL,
      cash DOUBLE,
      positions_value DOUBLE,
      equity DOUBLE,
      realized_pnl DOUBLE,
      unrealized_pnl DOUBLE
    )
  ")
  DBI::dbExecute(
    con,
    "INSERT INTO runs (run_id, created_at_utc, engine_version, config_json, config_hash, data_hash, snapshot_id, status, error_msg)
     VALUES ('legacy-compare', '2020-01-01 00:00:00', 'legacy', '{}', 'cfg', 'data', 'snap', 'DONE', NULL)"
  )
  DBI::dbExecute(
    con,
    "INSERT INTO equity_curve (run_id, ts_utc, cash, positions_value, equity, realized_pnl, unrealized_pnl)
     VALUES ('legacy-compare', '2020-01-01 00:00:00', 1000, 0, 1000, 0, 0)"
  )

  before_tables <- DBI::dbGetQuery(con, "SELECT table_name FROM information_schema.tables WHERE table_schema = 'main' ORDER BY table_name")
  ledgr_test_close_duckdb(opened$con, opened$drv)
  snapshot <- new_ledgr_snapshot(db_path, "snap")
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  cmp <- ledgr_compare_runs(snapshot, run_ids = "legacy-compare")

  reopened <- ledgr_test_open_duckdb(db_path)
  after_tables <- DBI::dbGetQuery(reopened$con, "SELECT table_name FROM information_schema.tables WHERE table_schema = 'main' ORDER BY table_name")
  ledgr_test_close_duckdb(reopened$con, reopened$drv)

  testthat::expect_identical(after_tables, before_tables)
  testthat::expect_identical(cmp$run_id, "legacy-compare")
  testthat::expect_identical(cmp$reproducibility_level, "legacy")
  testthat::expect_true(is.na(cmp$strategy_source_hash))
  testthat::expect_true(is.na(cmp$strategy_params_hash))
})
