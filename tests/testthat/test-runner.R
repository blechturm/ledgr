make_runner_fixture_db <- function() {
  path <- tempfile(fileext = ".duckdb")

  drv <- duckdb::duckdb()
  con <- DBI::dbConnect(drv, dbdir = path)
  ledgr_create_schema(con)

  DBI::dbAppendTable(con, "instruments", data.frame(instrument_id = "AAA"))

  bars <- data.frame(
    instrument_id = "AAA",
    ts_utc = as.POSIXct(c("2020-01-01 00:00:00", "2020-01-02 00:00:00", "2020-01-03 00:00:00"), tz = "UTC"),
    open = c(100, 101, 102),
    high = c(100, 101, 102),
    low = c(100, 101, 102),
    close = c(100, 101, 102),
    volume = c(1, 1, 1),
    stringsAsFactors = FALSE
  )
  DBI::dbAppendTable(con, "bars", bars)

  DBI::dbDisconnect(con, shutdown = TRUE)
  duckdb::duckdb_shutdown(drv)
  path
}

base_runner_config <- function(db_path) {
  list(
    db_path = db_path,
    engine = list(seed = 1L, tz = "UTC"),
    universe = list(instrument_ids = c("AAA")),
    backtest = list(
      start_ts_utc = "2020-01-01T00:00:00Z",
      end_ts_utc = "2020-01-03T00:00:00Z",
      pulse = "EOD",
      initial_cash = 1000
    ),
    fill_model = list(type = "next_open", spread_bps = 0, commission_fixed = 0),
    features = list(enabled = TRUE, defs = list(list(id = "return_1"))),
    strategy = list(id = "echo", params = list(targets = c(AAA = 1)))
  )
}

testthat::test_that("runner executes a minimal end-to-end run and writes outputs", {
  db_path <- make_runner_fixture_db()
  cfg <- base_runner_config(db_path)

  out <- ledgr_backtest_run(cfg)
  testthat::expect_true(is.list(out))
  testthat::expect_true(nzchar(out$run_id))
  testthat::expect_identical(out$db_path, db_path)
  gc()
  Sys.sleep(0.05)

  drv <- duckdb::duckdb()
  con <- DBI::dbConnect(drv, dbdir = db_path)
  on.exit(duckdb::duckdb_shutdown(drv), add = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  run <- DBI::dbGetQuery(con, "SELECT status, error_msg FROM runs WHERE run_id = ?", params = list(out$run_id))
  testthat::expect_equal(nrow(run), 1L)
  testthat::expect_identical(run$status[[1]], "DONE")
  testthat::expect_true(is.na(run$error_msg[[1]]))

  n_features <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM features WHERE run_id = ?", params = list(out$run_id))$n[[1]]
  testthat::expect_true(n_features > 0)

  n_ledger <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM ledger_events WHERE run_id = ?", params = list(out$run_id))$n[[1]]
  testthat::expect_true(n_ledger >= 0)

  n_eq <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM equity_curve WHERE run_id = ?", params = list(out$run_id))$n[[1]]
  testthat::expect_true(n_eq > 0)
})

testthat::test_that("runner resume appends ledger events without duplicate event_seq and rebuilds tail", {
  db_path <- make_runner_fixture_db()

  cfg <- base_runner_config(db_path)
  cfg$features$defs <- list(list(id = "sma_2"))
  cfg$strategy <- list(
    id = "ts_rule",
    params = list(
      cutover_ts_utc = "2020-01-02T00:00:00Z",
      targets_before = c(AAA = 1),
      targets_after = c(AAA = 2)
    )
  )

  run_id <- "run-resume-1"
  ledgr:::ledgr_backtest_run_internal(cfg, run_id = run_id, control = list(max_pulses = 1L))
  gc()
  Sys.sleep(0.05)

  drv <- duckdb::duckdb()
  con <- DBI::dbConnect(drv, dbdir = db_path)
  on.exit(duckdb::duckdb_shutdown(drv), add = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  before <- DBI::dbGetQuery(con, "SELECT event_seq, ts_utc FROM ledger_events WHERE run_id = ? ORDER BY event_seq", params = list(run_id))
  testthat::expect_equal(nrow(before), 1L)

  ledgr_backtest_run(cfg, run_id = run_id)

  after <- DBI::dbGetQuery(con, "SELECT event_seq, ts_utc FROM ledger_events WHERE run_id = ? ORDER BY event_seq", params = list(run_id))
  testthat::expect_equal(nrow(after), 2L)
  testthat::expect_identical(as.integer(after$event_seq), c(1L, 2L))

  n_eq <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM equity_curve WHERE run_id = ?", params = list(run_id))$n[[1]]
  testthat::expect_true(n_eq > 0)
})

testthat::test_that("runner refuses to resume on config hash mismatch", {
  db_path <- make_runner_fixture_db()
  cfg <- base_runner_config(db_path)

  run_id <- "run-mismatch-1"
  ledgr_backtest_run(cfg, run_id = run_id)
  gc()
  Sys.sleep(0.05)

  cfg2 <- cfg
  cfg2$fill_model$spread_bps <- 1

  testthat::expect_error(
    ledgr_backtest_run(cfg2, run_id = run_id),
    class = "ledgr_run_hash_mismatch"
  )
})
