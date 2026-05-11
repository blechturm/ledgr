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
  testthat::expect_equal(n_eq, 3L)

  n_state <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM strategy_state WHERE run_id = ?", params = list(out$run_id))$n[[1]]
  testthat::expect_equal(n_state, 3L)
})

testthat::test_that("low-level runner rejects opening positions outside the universe", {
  db_path <- make_runner_fixture_db()
  cfg <- base_runner_config(db_path)
  cfg$opening <- list(
    cash = 1000,
    date = NULL,
    positions = c(BBB = 1),
    cost_basis = c(BBB = 10)
  )

  testthat::expect_error(
    ledgr_backtest_run(cfg),
    "opening.positions contains instruments outside universe.instrument_ids",
    fixed = TRUE,
    class = "ledgr_invalid_config"
  )
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

testthat::test_that("strategy_state is persisted and restored across resume", {
  path <- tempfile(fileext = ".duckdb")

  drv <- duckdb::duckdb()
  con <- DBI::dbConnect(drv, dbdir = path)
  ledgr_create_schema(con)

  DBI::dbExecute(con, "INSERT INTO instruments (instrument_id) VALUES ('AAA')")
  DBI::dbAppendTable(
    con,
    "bars",
    data.frame(
      instrument_id = rep("AAA", 4),
      ts_utc = as.POSIXct(c("2020-01-01 00:00:00", "2020-01-02 00:00:00", "2020-01-03 00:00:00", "2020-01-04 00:00:00"), tz = "UTC"),
      open = c(100, 101, 102, 103),
      high = c(100, 101, 102, 103),
      low = c(100, 101, 102, 103),
      close = c(100, 101, 102, 103),
      volume = c(1, 1, 1, 1),
      stringsAsFactors = FALSE
    )
  )

  DBI::dbDisconnect(con, shutdown = TRUE)
  duckdb::duckdb_shutdown(drv)

  cfg <- list(
    db_path = path,
    engine = list(seed = 1L, tz = "UTC"),
    universe = list(instrument_ids = c("AAA")),
    backtest = list(
      start_ts_utc = "2020-01-01T00:00:00Z",
      end_ts_utc = "2020-01-04T00:00:00Z",
      pulse = "EOD",
      initial_cash = 1000
    ),
    fill_model = list(type = "next_open", spread_bps = 0, commission_fixed = 0),
    features = list(enabled = FALSE, defs = list()),
    strategy = list(id = "state_prev", params = list())
  )

  run_id <- "run-state-prev"
  ledgr:::ledgr_backtest_run_internal(cfg, run_id = run_id, control = list(max_pulses = 2L))
  gc()
  Sys.sleep(0.05)

  drv <- duckdb::duckdb()
  con <- DBI::dbConnect(drv, dbdir = path)
  on.exit(duckdb::duckdb_shutdown(drv), add = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  testthat::expect_warning(ledgr_backtest_run(cfg, run_id = run_id), "LEDGR_LAST_BAR_NO_FILL", fixed = TRUE)

  states <- DBI::dbGetQuery(
    con,
    "SELECT ts_utc, state_json FROM strategy_state WHERE run_id = ? ORDER BY ts_utc",
    params = list(run_id)
  )
  steps <- vapply(states$state_json, function(x) jsonlite::fromJSON(x, simplifyVector = FALSE)$step, numeric(1))
  testthat::expect_identical(states$ts_utc, c("2020-01-01T00:00:00Z", "2020-01-02T00:00:00Z", "2020-01-03T00:00:00Z", "2020-01-04T00:00:00Z"))
  testthat::expect_identical(as.integer(steps), c(1L, 2L, 3L, 4L))
})

testthat::test_that("db_live writes strategy_state only after pulse fill writes", {
  db_path <- make_runner_fixture_db()
  cfg <- base_runner_config(db_path)
  cfg$engine$execution_mode <- "db_live"
  cfg$features <- list(enabled = FALSE, defs = list())

  ns <- asNamespace("ledgr")
  original <- get("ledgr_write_fill_events", envir = ns, inherits = FALSE)
  saw_state_before_fill <- FALSE
  unlockBinding("ledgr_write_fill_events", ns)
  assign(
    "ledgr_write_fill_events",
    function(con, run_id, fill_intent, event_seq_start = NULL, use_transaction = TRUE) {
      state_rows <- DBI::dbGetQuery(
        con,
        "SELECT COUNT(*) AS n FROM strategy_state WHERE run_id = ?",
        params = list(run_id)
      )$n[[1]]
      if (as.integer(state_rows) > 0L) saw_state_before_fill <<- TRUE
      original(con, run_id, fill_intent, event_seq_start = event_seq_start, use_transaction = use_transaction)
    },
    envir = ns
  )
  lockBinding("ledgr_write_fill_events", ns)
  on.exit(
    {
      unlockBinding("ledgr_write_fill_events", ns)
      assign("ledgr_write_fill_events", original, envir = ns)
      lockBinding("ledgr_write_fill_events", ns)
    },
    add = TRUE
  )

  run_id <- "run-db-live-state-order"
  ledgr:::ledgr_backtest_run_internal(cfg, run_id = run_id, control = list(max_pulses = 1L))
  testthat::expect_false(saw_state_before_fill)
  gc()
  Sys.sleep(0.05)

  drv <- duckdb::duckdb()
  con <- DBI::dbConnect(drv, dbdir = db_path)
  on.exit(duckdb::duckdb_shutdown(drv), add = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  state_rows <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM strategy_state WHERE run_id = ?", params = list(run_id))$n[[1]]
  fill_rows <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM ledger_events WHERE run_id = ?", params = list(run_id))$n[[1]]
  testthat::expect_equal(as.integer(state_rows), 1L)
  testthat::expect_equal(as.integer(fill_rows), 1L)
})
