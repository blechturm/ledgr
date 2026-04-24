testthat::test_that("ledgr_backtest is equivalent to ledgr_run for functional strategies", {
  db_path_direct <- tempfile(fileext = ".duckdb")
  db_path_wrapper <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path_direct), add = TRUE)
  on.exit(unlink(db_path_wrapper), add = TRUE)

  snapshot_id <- "snapshot_20200101_000000_abcd"

  snap_direct <- ledgr_snapshot_from_df(test_bars, db_path = db_path_direct, snapshot_id = snapshot_id)
  on.exit(ledgr_snapshot_close(snap_direct), add = TRUE)

  snap_wrapper <- ledgr_snapshot_from_df(test_bars, db_path = db_path_wrapper, snapshot_id = snapshot_id)
  on.exit(ledgr_snapshot_close(snap_wrapper), add = TRUE)

  universe <- c("TEST_A", "TEST_B")
  config <- ledgr:::ledgr_config(
    snapshot = snap_direct,
    universe = universe,
    strategy = test_strategy,
    backtest = ledgr:::ledgr_backtest_config(start = "2020-01-01", end = "2020-12-31", initial_cash = 100000),
    db_path = db_path_direct
  )
  result_direct <- ledgr:::ledgr_run(config)

  result_wrapper <- ledgr_backtest(
    snapshot = snap_wrapper,
    strategy = test_strategy,
    universe = universe,
    start = "2020-01-01",
    end = "2020-12-31",
    initial_cash = 100000,
    db_path = db_path_wrapper
  )

  con_direct <- ledgr:::get_connection(snap_direct)
  con_wrapper <- ledgr:::get_connection(snap_wrapper)

  cfg_json_direct <- DBI::dbGetQuery(
    con_direct,
    "SELECT config_json FROM runs WHERE run_id = ?",
    params = list(result_direct$run_id)
  )$config_json[[1]]
  cfg_json_wrapper <- DBI::dbGetQuery(
    con_wrapper,
    "SELECT config_json FROM runs WHERE run_id = ?",
    params = list(result_wrapper$run_id)
  )$config_json[[1]]

  cfg_direct <- jsonlite::fromJSON(cfg_json_direct, simplifyVector = FALSE)
  cfg_wrapper <- jsonlite::fromJSON(cfg_json_wrapper, simplifyVector = FALSE)
  cfg_direct$db_path <- NULL
  cfg_wrapper$db_path <- NULL
  cfg_direct$data$snapshot_db_path <- NULL
  cfg_wrapper$data$snapshot_db_path <- NULL
  testthat::expect_identical(
    ledgr:::canonical_json(cfg_direct),
    ledgr:::canonical_json(cfg_wrapper)
  )

  events1 <- get_ledger_events(con_direct, result_direct$run_id)
  events2 <- get_ledger_events(con_wrapper, result_wrapper$run_id)

  compare_cols <- c("event_seq", "ts_utc", "event_type", "instrument_id", "side", "qty", "price", "fee", "meta_json")
  testthat::expect_equal(nrow(events1), nrow(events2))
  testthat::expect_identical(events1[, compare_cols], events2[, compare_cols])

  eq1 <- get_final_equity(con_direct, result_direct$run_id)
  eq2 <- get_final_equity(con_wrapper, result_wrapper$run_id)
  testthat::expect_equal(eq1, eq2, tolerance = 1e-10)
})

testthat::test_that("functional strategies must return targets for the full universe", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snap <- ledgr_snapshot_from_df(test_bars, db_path = db_path, snapshot_id = "snapshot_20200101_000000_abcd")
  on.exit(ledgr_snapshot_close(snap), add = TRUE)

  missing_target_strategy <- function(ctx) {
    c(TEST_A = 0)
  }

  testthat::expect_error(
    ledgr_backtest(
      snapshot = snap,
      strategy = missing_target_strategy,
      universe = c("TEST_A", "TEST_B"),
      start = "2020-01-01",
      end = "2020-12-31",
      initial_cash = 100000,
      db_path = db_path
    ),
    class = "ledgr_invalid_strategy_result"
  )
})
