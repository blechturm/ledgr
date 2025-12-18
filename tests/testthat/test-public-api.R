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

