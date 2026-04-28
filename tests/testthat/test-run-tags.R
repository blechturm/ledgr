testthat::test_that("run tags are mutable metadata and do not alter identity", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$targets()
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

  before <- ledgr_run_info(db_path, "tagged-run")
  tagged <- ledgr_run_tag(db_path, "tagged-run", c(" baseline ", "demo", "demo"))
  testthat::expect_s3_class(tagged, "ledgr_run_info")
  testthat::expect_identical(tagged$tags, "baseline, demo")

  tags <- ledgr_run_tags(db_path, "tagged-run")
  testthat::expect_s3_class(tags, "tbl_df")
  testthat::expect_identical(tags$tag, c("baseline", "demo"))
  testthat::expect_true(all(tags$run_id == "tagged-run"))

  all_tags <- ledgr_run_tags(db_path)
  testthat::expect_identical(all_tags$tag, c("baseline", "demo"))

  runs <- ledgr_run_list(db_path)
  testthat::expect_identical(runs$tags[runs$run_id == "tagged-run"], "baseline, demo")

  opened <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  testthat::expect_identical(
    DBI::dbGetQuery(opened$con, "SELECT COUNT(*) AS n FROM run_tags WHERE run_id = 'tagged-run'")$n[[1]],
    2
  )

  after <- ledgr_run_info(db_path, "tagged-run")
  identity_cols <- c("config_hash", "data_hash", "snapshot_hash", "strategy_source_hash", "strategy_params_hash")
  for (col in identity_cols) {
    testthat::expect_identical(after[[col]], before[[col]])
  }

  untagged <- ledgr_run_untag(db_path, "tagged-run", "demo")
  testthat::expect_identical(untagged$tags, "baseline")
  testthat::expect_identical(ledgr_run_tags(db_path, "tagged-run")$tag, "baseline")

  cleared <- ledgr_run_untag(db_path, "tagged-run")
  testthat::expect_true(is.na(cleared$tags))
  testthat::expect_identical(nrow(ledgr_run_tags(db_path, "tagged-run")), 0L)
})

testthat::test_that("run tag validation and missing runs fail clearly", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  strategy <- function(ctx) ctx$targets()
  bt <- ledgr_backtest(
    data = test_bars,
    strategy = strategy,
    start = "2020-01-01",
    end = "2020-01-05",
    db_path = db_path,
    run_id = "tag-validation"
  )
  on.exit(close(bt), add = TRUE)

  testthat::expect_error(
    ledgr_run_tag(db_path, "tag-validation", c("ok", "")),
    class = "ledgr_invalid_args"
  )
  testthat::expect_error(
    ledgr_run_tag(db_path, "tag-validation", "bad,tag"),
    class = "ledgr_invalid_args"
  )
  testthat::expect_error(
    ledgr_run_tag(db_path, "missing-run", "baseline"),
    class = "ledgr_run_not_found"
  )
  testthat::expect_error(
    ledgr_run_untag(db_path, "missing-run", "baseline"),
    class = "ledgr_run_not_found"
  )
  testthat::expect_error(
    ledgr_run_tags(db_path, "missing-run"),
    class = "ledgr_run_not_found"
  )
  testthat::expect_error(
    ledgr_run_untag(db_path, "tag-validation", character(0)),
    class = "ledgr_invalid_args"
  )
})

testthat::test_that("run tag reads do not mutate legacy stores but writes migrate additively", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)
  opened <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  con <- opened$con

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
  testthat::expect_identical(nrow(ledgr_run_tags(db_path)), 0L)
  after_read_tables <- DBI::dbGetQuery(
    con,
    "SELECT table_name FROM information_schema.tables WHERE table_schema = 'main' ORDER BY table_name"
  )$table_name
  testthat::expect_identical(after_read_tables, before_tables)

  tagged <- ledgr_run_tag(db_path, "legacy-tag", "legacy")
  testthat::expect_identical(tagged$tags, "legacy")
  after_write_tables <- DBI::dbGetQuery(
    con,
    "SELECT table_name FROM information_schema.tables WHERE table_schema = 'main' ORDER BY table_name"
  )$table_name
  testthat::expect_true("run_tags" %in% after_write_tables)
  testthat::expect_identical(ledgr_run_tags(db_path, "legacy-tag")$tag, "legacy")
  testthat::expect_identical(
    DBI::dbGetQuery(con, "SELECT status FROM runs WHERE run_id = 'legacy-tag'")$status[[1]],
    "DONE"
  )
})
