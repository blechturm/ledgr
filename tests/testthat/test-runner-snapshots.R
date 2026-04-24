make_snapshot_runner_db <- function(status = "SEALED") {
  path <- tempfile(fileext = ".duckdb")
  drv <- duckdb::duckdb()
  con <- DBI::dbConnect(drv, dbdir = path)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  on.exit(duckdb::duckdb_shutdown(drv), add = TRUE)

  ledgr_create_schema(con)

  snapshot_id <- ledgr_snapshot_create(con, snapshot_id = "snapshot_20250101_000000_abcd", meta = list())

  instruments_csv <- tempfile(fileext = ".csv")
  writeLines(
    c(
      "instrument_id,symbol,currency,asset_class,multiplier,tick_size",
      "AAA,AAA,USD,EQUITY,1,0.01",
      "BBB,BBB,USD,EQUITY,1,0.01"
    ),
    instruments_csv,
    useBytes = TRUE
  )
  bars_csv <- tempfile(fileext = ".csv")
  writeLines(
    c(
      "instrument_id,ts_utc,open,high,low,close,volume",
      "AAA,2020-01-01T00:00:00Z,100,100,100,100,1",
      "AAA,2020-01-02T00:00:00Z,101,101,101,101,1",
      "AAA,2020-01-03T00:00:00Z,102,102,102,102,1",
      "BBB,2020-01-01T00:00:00Z,200,200,200,200,1",
      "BBB,2020-01-02T00:00:00Z,201,201,201,201,1",
      "BBB,2020-01-03T00:00:00Z,202,202,202,202,1"
    ),
    bars_csv,
    useBytes = TRUE
  )

  ledgr_snapshot_import_bars_csv(
    con,
    snapshot_id,
    bars_csv_path = bars_csv,
    instruments_csv_path = instruments_csv,
    auto_generate_instruments = FALSE,
    validate = "fail_fast"
  )

  if (identical(status, "SEALED")) {
    ledgr_snapshot_seal(con, snapshot_id)
  } else if (identical(status, "FAILED")) {
    DBI::dbExecute(con, "UPDATE snapshots SET status = 'FAILED' WHERE snapshot_id = ?", params = list(snapshot_id))
  } else if (identical(status, "CREATED")) {
    # leave as-is
  } else {
    stop("test helper: unknown status")
  }

  list(path = path, snapshot_id = snapshot_id)
}

runner_snapshot_config <- function(db_path, snapshot_id, universe_ids, snapshot_db_path = NULL) {
  data <- list(source = "snapshot", snapshot_id = snapshot_id)
  if (!is.null(snapshot_db_path)) data$snapshot_db_path <- snapshot_db_path

  list(
    db_path = db_path,
    engine = list(seed = 1L, tz = "UTC"),
    data = data,
    universe = list(instrument_ids = universe_ids),
    backtest = list(
      start_ts_utc = "2020-01-01T00:00:00Z",
      end_ts_utc = "2020-01-03T00:00:00Z",
      pulse = "EOD",
      initial_cash = 1000
    ),
    fill_model = list(type = "next_open", spread_bps = 0, commission_fixed = 0),
    features = list(enabled = FALSE, defs = list()),
    strategy = list(id = "hold_zero", params = list())
  )
}

testthat::test_that("runner can use a SEALED snapshot and a subset universe; run stores runs.snapshot_id", {
  fx <- make_snapshot_runner_db(status = "SEALED")
  cfg <- runner_snapshot_config(fx$path, fx$snapshot_id, universe_ids = c("AAA"))

  out <- ledgr_backtest_run(cfg, run_id = "run-snapshot-1")
  testthat::expect_identical(out$run_id, "run-snapshot-1")
  gc()
  Sys.sleep(0.05)

  drv <- duckdb::duckdb()
  con <- DBI::dbConnect(drv, dbdir = fx$path)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  on.exit(duckdb::duckdb_shutdown(drv), add = TRUE)

  run <- DBI::dbGetQuery(con, "SELECT status, snapshot_id FROM runs WHERE run_id = ?", params = list("run-snapshot-1"))
  testthat::expect_equal(nrow(run), 1L)
  testthat::expect_identical(run$status[[1]], "DONE")
  testthat::expect_identical(run$snapshot_id[[1]], fx$snapshot_id)
})

testthat::test_that("runner can use separate snapshot artifact and run ledger databases", {
  fx <- make_snapshot_runner_db(status = "SEALED")
  run_path <- tempfile(fileext = ".duckdb")
  cfg <- runner_snapshot_config(
    run_path,
    fx$snapshot_id,
    universe_ids = c("AAA"),
    snapshot_db_path = fx$path
  )

  out <- ledgr_backtest_run(cfg, run_id = "run-snapshot-split-db")
  testthat::expect_identical(out$db_path, run_path)
  gc()
  Sys.sleep(0.05)

  drv <- duckdb::duckdb()
  con <- DBI::dbConnect(drv, dbdir = run_path)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  on.exit(duckdb::duckdb_shutdown(drv), add = TRUE)

  run <- DBI::dbGetQuery(con, "SELECT status, snapshot_id FROM runs WHERE run_id = ?", params = list("run-snapshot-split-db"))
  testthat::expect_equal(nrow(run), 1L)
  testthat::expect_identical(run$status[[1]], "DONE")
  testthat::expect_identical(run$snapshot_id[[1]], fx$snapshot_id)

  snapshot_rows <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM snapshots")$n[[1]]
  equity_rows <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM equity_curve WHERE run_id = ?", params = list("run-snapshot-split-db"))$n[[1]]
  testthat::expect_equal(as.integer(snapshot_rows), 0L)
  testthat::expect_gt(as.integer(equity_rows), 0L)
})

testthat::test_that("tamper detection fails loud when SEALED snapshot is mutated after seal", {
  fx <- make_snapshot_runner_db(status = "SEALED")
  gc()
  Sys.sleep(0.05)

  drv <- duckdb::duckdb()
  con <- DBI::dbConnect(drv, dbdir = fx$path)
  DBI::dbExecute(
    con,
    "
    UPDATE snapshot_bars
    SET close = close + 1
    WHERE snapshot_id = ? AND instrument_id = 'BBB' AND ts_utc = CAST('2020-01-02 00:00:00' AS TIMESTAMP)
    ",
    params = list(fx$snapshot_id)
  )
  DBI::dbDisconnect(con, shutdown = TRUE)
  duckdb::duckdb_shutdown(drv)
  gc()
  Sys.sleep(0.05)

  cfg <- runner_snapshot_config(fx$path, fx$snapshot_id, universe_ids = c("AAA"))
  testthat::expect_error(
    ledgr_backtest_run(cfg, run_id = "run-snapshot-tamper"),
    class = "LEDGR_SNAPSHOT_CORRUPTED"
  )
  gc()
  Sys.sleep(0.05)

  drv <- duckdb::duckdb()
  con <- DBI::dbConnect(drv, dbdir = fx$path)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  on.exit(duckdb::duckdb_shutdown(drv), add = TRUE)
  run <- DBI::dbGetQuery(con, "SELECT status, error_msg FROM runs WHERE run_id = ?", params = list("run-snapshot-tamper"))
  testthat::expect_identical(run$status[[1]], "FAILED")
  testthat::expect_true(grepl("LEDGR_SNAPSHOT_CORRUPTED", run$error_msg[[1]], fixed = TRUE))
})

testthat::test_that("coverage validation fails loud for ragged per-instrument coverage", {
  path <- tempfile(fileext = ".duckdb")
  drv <- duckdb::duckdb()
  con <- DBI::dbConnect(drv, dbdir = path)
  ledgr_create_schema(con)

  snapshot_id <- ledgr_snapshot_create(con, snapshot_id = "snapshot_20250101_000000_abcd", meta = list())

  # AAA has 3 days; BBB starts late (missing 2020-01-01).
  DBI::dbAppendTable(
    con,
    "snapshot_instruments",
    data.frame(
      snapshot_id = rep(snapshot_id, 2L),
      instrument_id = c("AAA", "BBB"),
      symbol = c("AAA", "BBB"),
      currency = c("USD", "USD"),
      asset_class = c("EQUITY", "EQUITY"),
      multiplier = c(1, 1),
      tick_size = c(0.01, 0.01),
      meta_json = c(NA_character_, NA_character_),
      stringsAsFactors = FALSE
    )
  )
  DBI::dbAppendTable(
    con,
    "snapshot_bars",
    data.frame(
      snapshot_id = c(rep(snapshot_id, 3L), rep(snapshot_id, 2L)),
      instrument_id = c("AAA", "AAA", "AAA", "BBB", "BBB"),
      ts_utc = as.POSIXct(
        c("2020-01-01 00:00:00", "2020-01-02 00:00:00", "2020-01-03 00:00:00", "2020-01-02 00:00:00", "2020-01-03 00:00:00"),
        tz = "UTC"
      ),
      open = c(100, 101, 102, 201, 202),
      high = c(100, 101, 102, 201, 202),
      low = c(100, 101, 102, 201, 202),
      close = c(100, 101, 102, 201, 202),
      volume = c(1, 1, 1, 1, 1),
      stringsAsFactors = FALSE
    )
  )
  ledgr_snapshot_seal(con, snapshot_id)

  DBI::dbDisconnect(con, shutdown = TRUE)
  duckdb::duckdb_shutdown(drv)
  gc()
  Sys.sleep(0.05)

  cfg <- runner_snapshot_config(path, snapshot_id, universe_ids = c("AAA", "BBB"))
  testthat::expect_error(
    ledgr_backtest_run(cfg, run_id = "run-snapshot-coverage"),
    class = "LEDGR_SNAPSHOT_COVERAGE_ERROR"
  )
})

testthat::test_that("runner rejects non-SEALED snapshots", {
  fx <- make_snapshot_runner_db(status = "CREATED")
  cfg <- runner_snapshot_config(fx$path, fx$snapshot_id, universe_ids = c("AAA"))

  testthat::expect_error(
    ledgr_backtest_run(cfg, run_id = "run-snapshot-not-sealed"),
    class = "LEDGR_SNAPSHOT_NOT_SEALED"
  )
})
