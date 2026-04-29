testthat::test_that("run tags are mutable metadata and do not alter identity", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["TEST_A"] <- params$qty
    targets
  }
  bt <- ledgr_backtest(
    data = test_bars,
    strategy = strategy,
    strategy_params = list(qty = 1),
    start = "2020-01-01",
    end = "2020-01-05",
    db_path = db_path,
    run_id = "tagged-run"
  )
  on.exit(close(bt), add = TRUE)
  close(bt)
  snapshot <- ledgr_test_snapshot_for_run(db_path, bt)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  before <- ledgr_run_info(snapshot, "tagged-run")
  tagged <- ledgr_run_tag(snapshot, "tagged-run", c(" baseline ", "demo", "demo"))
  testthat::expect_s3_class(tagged, "ledgr_snapshot")
  tagged_info <- ledgr_run_info(snapshot, "tagged-run")
  testthat::expect_identical(tagged_info$tags, "baseline, demo")

  tags <- ledgr_run_tags(snapshot, "tagged-run")
  testthat::expect_s3_class(tags, "tbl_df")
  testthat::expect_identical(tags$tag, c("baseline", "demo"))
  testthat::expect_true(all(tags$run_id == "tagged-run"))

  all_tags <- ledgr_run_tags(snapshot)
  testthat::expect_identical(all_tags$tag, c("baseline", "demo"))

  runs <- ledgr_run_list(snapshot)
  testthat::expect_identical(runs$tags[runs$run_id == "tagged-run"], "baseline, demo")

  opened <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  testthat::expect_identical(
    DBI::dbGetQuery(opened$con, "SELECT COUNT(*) AS n FROM run_tags WHERE run_id = 'tagged-run'")$n[[1]],
    2
  )

  after <- ledgr_run_info(snapshot, "tagged-run")
  identity_cols <- c("config_hash", "data_hash", "snapshot_hash", "strategy_source_hash", "strategy_params_hash")
  for (col in identity_cols) {
    testthat::expect_identical(after[[col]], before[[col]])
  }

  ledgr_run_untag(snapshot, "tagged-run", "demo")
  untagged <- ledgr_run_info(snapshot, "tagged-run")
  testthat::expect_identical(untagged$tags, "baseline")
  testthat::expect_identical(ledgr_run_tags(snapshot, "tagged-run")$tag, "baseline")

  ledgr_run_untag(snapshot, "tagged-run")
  cleared <- ledgr_run_info(snapshot, "tagged-run")
  testthat::expect_true(is.na(cleared$tags))
  testthat::expect_identical(nrow(ledgr_run_tags(snapshot, "tagged-run")), 0L)
})

testthat::test_that("run tag validation and missing runs fail clearly", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  strategy <- function(ctx, params) ctx$flat()
  bt <- ledgr_backtest(
    data = test_bars,
    strategy = strategy,
    start = "2020-01-01",
    end = "2020-01-05",
    db_path = db_path,
    run_id = "tag-validation"
  )
  on.exit(close(bt), add = TRUE)
  snapshot <- ledgr_test_snapshot_for_run(db_path, bt)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  testthat::expect_error(
    ledgr_run_tag(snapshot, "tag-validation", c("ok", "")),
    class = "ledgr_invalid_args"
  )
  testthat::expect_error(
    ledgr_run_tag(snapshot, "tag-validation", "bad,tag"),
    class = "ledgr_invalid_args"
  )
  testthat::expect_error(
    ledgr_run_tag(snapshot, "missing-run", "baseline"),
    class = "ledgr_run_not_found"
  )
  testthat::expect_error(
    ledgr_run_untag(snapshot, "missing-run", "baseline"),
    class = "ledgr_run_not_found"
  )
  testthat::expect_error(
    ledgr_run_tags(snapshot, "missing-run"),
    class = "ledgr_run_not_found"
  )
  testthat::expect_error(
    ledgr_run_untag(snapshot, "tag-validation", character(0)),
    class = "ledgr_invalid_args"
  )
})

testthat::test_that("run tag reads do not mutate legacy stores but writes migrate additively", {
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
      'legacy-snapshot', 'SEALED', TIMESTAMP '2020-01-01 00:00:00',
      TIMESTAMP '2020-01-01 00:00:00', 'legacy-hash', '{}'
    )
  ")
  DBI::dbExecute(con, "
    INSERT INTO snapshot_instruments (snapshot_id, instrument_id, meta_json)
    VALUES ('legacy-snapshot', 'TEST_A', '{}')
  ")
  DBI::dbExecute(con, "
    CREATE TABLE runs (
      run_id TEXT NOT NULL PRIMARY KEY,
      created_at_utc TIMESTAMP NOT NULL,
      engine_version TEXT,
      config_json TEXT,
      config_hash TEXT,
      data_hash TEXT,
      snapshot_id TEXT,
      status TEXT NOT NULL,
      error_msg TEXT
    )
  ")
  DBI::dbExecute(
    con,
    "
    INSERT INTO runs (
      run_id, created_at_utc, engine_version, config_json, config_hash,
      data_hash, snapshot_id, status, error_msg
    ) VALUES (
      'legacy-tag', TIMESTAMP '2020-01-01 00:00:00', '0.1.4',
      '{}', 'config-hash', 'window-hash', 'legacy-snapshot', 'DONE', NULL
    )
    "
  )

  before_tables <- DBI::dbGetQuery(
    con,
    "SELECT table_name FROM information_schema.tables WHERE table_schema = 'main' ORDER BY table_name"
  )$table_name
  ledgr_test_close_duckdb(opened$con, opened$drv)
  snapshot <- new_ledgr_snapshot(db_path, "legacy-snapshot")
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  testthat::expect_identical(nrow(ledgr_run_tags(snapshot)), 0L)

  reopened_read <- ledgr_test_open_duckdb(db_path)
  after_read_tables <- DBI::dbGetQuery(
    reopened_read$con,
    "SELECT table_name FROM information_schema.tables WHERE table_schema = 'main' ORDER BY table_name"
  )$table_name
  ledgr_test_close_duckdb(reopened_read$con, reopened_read$drv)
  testthat::expect_identical(after_read_tables, before_tables)

  tagged <- ledgr_run_tag(snapshot, "legacy-tag", "legacy")
  testthat::expect_s3_class(tagged, "ledgr_snapshot")
  testthat::expect_identical(ledgr_run_info(snapshot, "legacy-tag")$tags, "legacy")
  reopened_write <- ledgr_test_open_duckdb(db_path)
  after_write_tables <- DBI::dbGetQuery(
    reopened_write$con,
    "SELECT table_name FROM information_schema.tables WHERE table_schema = 'main' ORDER BY table_name"
  )$table_name
  testthat::expect_true("run_tags" %in% after_write_tables)
  status_after_write <- DBI::dbGetQuery(
    reopened_write$con,
    "SELECT status FROM runs WHERE run_id = 'legacy-tag'"
  )$status[[1]]
  ledgr_test_close_duckdb(reopened_write$con, reopened_write$drv)
  testthat::expect_identical(ledgr_run_tags(snapshot, "legacy-tag")$tag, "legacy")
  testthat::expect_identical(status_after_write, "DONE")
})
