testthat::test_that("ledgr_db_init() opens DB and ensures schema", {
  dir <- withr::local_tempdir()
  db_path <- file.path(dir, "ledgr.duckdb")

  con <- ledgr_db_init(db_path)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  tables <- DBI::dbGetQuery(
    con,
    "
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'main'
    "
  )$table_name

  testthat::expect_true("runs" %in% tables)
  testthat::expect_true("bars" %in% tables)
  testthat::expect_true("strategy_state" %in% tables)
})

testthat::test_that("ledgr_state_reconstruct() returns derived artifacts and rebuilds equity_curve", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  ledgr_create_schema(con)

  cfg <- list(
    db_path = ":memory:",
    engine = list(seed = 1L, tz = "UTC"),
    universe = list(instrument_ids = c("AAA", "BBB")),
    backtest = list(
      start_ts_utc = "2020-01-01T00:00:00Z",
      end_ts_utc = "2020-01-03T00:00:00Z",
      pulse = "EOD",
      initial_cash = 1000
    ),
    fill_model = list(type = "next_open", spread_bps = 0, commission_fixed = 0),
    strategy = list(id = "hold_zero")
  )

  DBI::dbExecute(
    con,
    "
    INSERT INTO runs (run_id, created_at_utc, engine_version, config_json, config_hash, data_hash, status, error_msg)
    VALUES ('run-1', TIMESTAMP '2020-01-01 00:00:00', '0.1.0', ?, 'x', 'y', 'CREATED', NULL)
    ",
    params = list(canonical_json(cfg))
  )

  DBI::dbExecute(con, "INSERT INTO instruments (instrument_id) VALUES ('AAA'), ('BBB')")
  DBI::dbExecute(
    con,
    "
    INSERT INTO bars (instrument_id, ts_utc, open, high, low, close, volume)
    VALUES
      ('AAA', TIMESTAMP '2020-01-01 00:00:00', 1, 1, 1, 1, 100),
      ('AAA', TIMESTAMP '2020-01-02 00:00:00', 1, 1, 1, 1, 100),
      ('AAA', TIMESTAMP '2020-01-03 00:00:00', 1, 1, 1, 1, 100),
      ('BBB', TIMESTAMP '2020-01-01 00:00:00', 2, 2, 2, 2, 100),
      ('BBB', TIMESTAMP '2020-01-02 00:00:00', 2, 2, 2, 2, 100),
      ('BBB', TIMESTAMP '2020-01-03 00:00:00', 2, 2, 2, 2, 100)
    "
  )

  out <- ledgr_state_reconstruct("run-1", con)
  testthat::expect_true(is.list(out))
  testthat::expect_true(all(c("positions", "cash", "pnl", "equity_curve") %in% names(out)))
  testthat::expect_equal(nrow(out$equity_curve), 3)
  testthat::expect_equal(nrow(out$positions), 2)

  eq_rows <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM equity_curve WHERE run_id = 'run-1'")$n[[1]]
  testthat::expect_equal(eq_rows, 3)
})

testthat::test_that("ledgr_state_reconstruct() fails clearly for unsupported object-style calls", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  bars <- data.frame(
    instrument_id = "AAA",
    ts_utc = as.POSIXct(c("2020-01-01 00:00:00", "2020-01-02 00:00:00"), tz = "UTC"),
    open = c(100, 101),
    high = c(100, 101),
    low = c(100, 101),
    close = c(100, 101),
    volume = c(1, 1),
    stringsAsFactors = FALSE
  )
  strategy <- function(ctx) ctx$targets()
  bt <- ledgr_backtest(data = bars, strategy = strategy, initial_cash = 1000, db_path = db_path)
  on.exit(close(bt), add = TRUE)

  testthat::expect_error(
    ledgr_state_reconstruct(bt),
    "ledgr_state_reconstruct\\(bt\\$run_id, con\\)",
    class = "ledgr_invalid_args"
  )
  testthat::expect_error(
    ledgr_state_reconstruct(bt$run_id),
    "Use ledgr_state_reconstruct\\(run_id, con\\)",
    class = "ledgr_invalid_con"
  )
})

testthat::test_that("ledgr_state_reconstruct() rebuilds split-DB snapshot-backed runs", {
  snapshot_path <- tempfile(fileext = ".duckdb")
  run_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(snapshot_path), add = TRUE)
  on.exit(unlink(run_path), add = TRUE)

  bars <- data.frame(
    instrument_id = "AAA",
    ts_utc = as.POSIXct(
      c("2020-01-01 00:00:00", "2020-01-02 00:00:00", "2020-01-03 00:00:00"),
      tz = "UTC"
    ),
    open = c(100, 101, 102),
    high = c(100, 101, 102),
    low = c(100, 101, 102),
    close = c(100, 101, 102),
    volume = c(1, 1, 1),
    stringsAsFactors = FALSE
  )
  snap <- ledgr_snapshot_from_df(bars, db_path = snapshot_path, snapshot_id = "snapshot_20200101_000000_abcd")
  on.exit(ledgr_snapshot_close(snap), add = TRUE)

  strat <- function(ctx) {
    c(AAA = 1)
  }
  bt <- suppressWarnings(ledgr_backtest(
    snapshot = snap,
    strategy = strat,
    universe = "AAA",
    start = "2020-01-01",
    end = "2020-01-03",
    initial_cash = 1000,
    db_path = run_path
  ))
  gc()
  Sys.sleep(0.05)

  drv <- duckdb::duckdb()
  con <- DBI::dbConnect(drv, dbdir = run_path)
  on.exit(duckdb::duckdb_shutdown(drv), add = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  run_bars <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM bars")$n[[1]]
  testthat::expect_equal(as.integer(run_bars), 0L)

  DBI::dbExecute(con, "DELETE FROM equity_curve WHERE run_id = ?", params = list(bt$run_id))
  out <- ledgr_state_reconstruct(bt$run_id, con)

  testthat::expect_equal(nrow(out$equity_curve), 3L)
  eq_rows <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM equity_curve WHERE run_id = ?", params = list(bt$run_id))$n[[1]]
  testthat::expect_equal(as.integer(eq_rows), 3L)
  testthat::expect_equal(out$positions$qty[[1]], 1)
})

testthat::test_that("ledgr_state_reconstruct() rejects tampered snapshot sources", {
  snapshot_path <- tempfile(fileext = ".duckdb")
  run_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(snapshot_path), add = TRUE)
  on.exit(unlink(run_path), add = TRUE)

  bars <- data.frame(
    instrument_id = "AAA",
    ts_utc = as.POSIXct(
      c("2020-01-01 00:00:00", "2020-01-02 00:00:00", "2020-01-03 00:00:00"),
      tz = "UTC"
    ),
    open = c(100, 101, 102),
    high = c(100, 101, 102),
    low = c(100, 101, 102),
    close = c(100, 101, 102),
    volume = c(1, 1, 1),
    stringsAsFactors = FALSE
  )
  snap <- ledgr_snapshot_from_df(bars, db_path = snapshot_path, snapshot_id = "snapshot_20200101_000000_abcd")
  on.exit(ledgr_snapshot_close(snap), add = TRUE)

  strat <- function(ctx) {
    c(AAA = 1)
  }
  bt <- suppressWarnings(ledgr_backtest(
    snapshot = snap,
    strategy = strat,
    universe = "AAA",
    start = "2020-01-01",
    end = "2020-01-03",
    initial_cash = 1000,
    db_path = run_path
  ))
  gc()
  Sys.sleep(0.05)

  snap_drv <- duckdb::duckdb()
  snap_con <- DBI::dbConnect(snap_drv, dbdir = snapshot_path)
  DBI::dbExecute(
    snap_con,
    "UPDATE snapshot_bars SET close = close + 1 WHERE snapshot_id = ? AND instrument_id = 'AAA'",
    params = list(snap$snapshot_id)
  )
  DBI::dbDisconnect(snap_con, shutdown = TRUE)
  duckdb::duckdb_shutdown(snap_drv)
  gc()
  Sys.sleep(0.05)

  drv <- duckdb::duckdb()
  con <- DBI::dbConnect(drv, dbdir = run_path)
  on.exit(duckdb::duckdb_shutdown(drv), add = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  testthat::expect_error(
    ledgr_state_reconstruct(bt$run_id, con),
    class = "LEDGR_SNAPSHOT_CORRUPTED"
  )
})
