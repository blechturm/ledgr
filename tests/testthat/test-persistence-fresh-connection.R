testthat::test_that("completed run artifacts are visible from a fresh connection after ledgr_run", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snapshot <- ledgr_snapshot_from_df(test_bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["TEST_A"] <- 1
    targets
  }
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    opening = ledgr_opening(cash = 10000),
    universe = c("TEST_A", "TEST_B")
  )

  bt <- ledgr_run(exp, params = list(), run_id = "fresh-run")
  on.exit(close(bt), add = TRUE)

  opened <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)

  run_row <- DBI::dbGetQuery(
    opened$con,
    "SELECT status, config_hash, data_hash FROM runs WHERE run_id = 'fresh-run'"
  )
  ledger_n <- DBI::dbGetQuery(
    opened$con,
    "SELECT COUNT(*) AS n FROM ledger_events WHERE run_id = 'fresh-run'"
  )$n[[1]]
  equity_n <- DBI::dbGetQuery(
    opened$con,
    "SELECT COUNT(*) AS n FROM equity_curve WHERE run_id = 'fresh-run'"
  )$n[[1]]

  testthat::expect_identical(nrow(run_row), 1L)
  testthat::expect_identical(run_row$status[[1]], "DONE")
  testthat::expect_true(nzchar(run_row$config_hash[[1]]))
  testthat::expect_true(nzchar(run_row$data_hash[[1]]))
  testthat::expect_gt(ledger_n, 0)
  testthat::expect_gt(equity_n, 0)
})

testthat::test_that("run metadata mutations are visible from fresh connections", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snapshot <- ledgr_snapshot_from_df(test_bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) ctx$flat()
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    opening = ledgr_opening(cash = 10000)
  )
  bt <- ledgr_run(exp, params = list(), run_id = "fresh-metadata")
  on.exit(close(bt), add = TRUE)

  ledgr_run_label(snapshot, "fresh-metadata", "baseline")
  ledgr_run_archive(snapshot, "fresh-metadata", reason = "fresh read")
  ledgr_run_tag(snapshot, "fresh-metadata", c("demo", "release-gate"))
  ledgr_run_untag(snapshot, "fresh-metadata", "demo")

  opened <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)

  run_row <- DBI::dbGetQuery(
    opened$con,
    "
    SELECT label, archived, archive_reason
    FROM runs
    WHERE run_id = 'fresh-metadata'
    "
  )
  tags <- DBI::dbGetQuery(
    opened$con,
    "
    SELECT tag
    FROM run_tags
    WHERE run_id = 'fresh-metadata'
    ORDER BY tag
    "
  )

  testthat::expect_identical(run_row$label[[1]], "baseline")
  testthat::expect_true(isTRUE(run_row$archived[[1]]))
  testthat::expect_identical(run_row$archive_reason[[1]], "fresh read")
  testthat::expect_identical(tags$tag, "release-gate")
})

testthat::test_that("low-level CSV snapshot workflow survives close, load, and run", {
  db_path <- tempfile(fileext = ".duckdb")
  bars_csv <- tempfile(fileext = ".csv")
  on.exit(unlink(c(db_path, bars_csv)), add = TRUE)

  bars <- data.frame(
    instrument_id = rep(c("AAA", "BBB"), each = 4L),
    ts_utc = rep(
      c(
        "2020-04-01T00:00:00Z",
        "2020-04-02T00:00:00Z",
        "2020-04-03T00:00:00Z",
        "2020-04-04T00:00:00Z"
      ),
      2L
    ),
    open = c(100, 101, 102, 103, 50, 49, 48, 47),
    high = c(101, 102, 103, 104, 51, 50, 49, 48),
    low = c(99, 100, 101, 102, 49, 48, 47, 46),
    close = c(100, 102, 101, 104, 50, 48, 49, 47),
    volume = 1000,
    stringsAsFactors = FALSE
  )
  utils::write.csv(bars, bars_csv, row.names = FALSE)

  con <- ledgr_db_init(db_path)
  on.exit({
    if (DBI::dbIsValid(con)) {
      DBI::dbDisconnect(con, shutdown = TRUE)
    }
  }, add = TRUE)
  snapshot_id <- "fresh_csv_snapshot"
  ledgr_snapshot_create(con, snapshot_id = snapshot_id, meta = list())
  ledgr_snapshot_import_bars_csv(
    con,
    snapshot_id,
    bars_csv_path = bars_csv,
    instruments_csv_path = NULL,
    auto_generate_instruments = TRUE
  )
  hash <- ledgr_snapshot_seal(con, snapshot_id)
  DBI::dbDisconnect(con, shutdown = TRUE)

  loaded <- ledgr_snapshot_load(db_path, snapshot_id = snapshot_id, verify = TRUE)
  on.exit(ledgr_snapshot_close(loaded), add = TRUE)
  loaded_info <- ledgr_snapshot_info(loaded)

  testthat::expect_identical(loaded_info$snapshot_hash[[1]], hash)
  testthat::expect_identical(loaded$metadata$start_date, "2020-04-01T00:00:00Z")
  testthat::expect_identical(loaded$metadata$end_date, "2020-04-04T00:00:00Z")

  strategy <- function(ctx, params) ctx$flat()
  exp <- ledgr_experiment(
    snapshot = loaded,
    strategy = strategy,
    opening = ledgr_opening(cash = 10000),
    universe = c("AAA", "BBB")
  )
  bt <- ledgr_run(exp, params = list(), run_id = "fresh-csv-run")
  on.exit(close(bt), add = TRUE)

  opened <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)

  run_status <- DBI::dbGetQuery(
    opened$con,
    "SELECT status FROM runs WHERE run_id = 'fresh-csv-run'"
  )$status[[1]]
  equity_n <- DBI::dbGetQuery(
    opened$con,
    "SELECT COUNT(*) AS n FROM equity_curve WHERE run_id = 'fresh-csv-run'"
  )$n[[1]]

  testthat::expect_identical(run_status, "DONE")
  testthat::expect_gt(equity_n, 0)
})
