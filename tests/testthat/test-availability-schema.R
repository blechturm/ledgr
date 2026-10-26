testthat::test_that("current schema retains normalized availability tables", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  testthat::expect_identical(
    ledgr:::ledgr_experiment_store_version(con),
    ledgr:::ledgr_experiment_store_schema_version
  )
  testthat::expect_identical(ledgr:::ledgr_saved_sweep_schema_version, 6L)
  tables <- DBI::dbGetQuery(
    con,
    "SELECT table_name FROM information_schema.tables WHERE table_schema = 'main'"
  )$table_name
  testthat::expect_true(all(names(ledgr:::ledgr_snapshot_availability_tables()) %in% tables))
  snapshot_columns <- DBI::dbGetQuery(
    con,
    paste(
      "SELECT column_name FROM information_schema.columns",
      "WHERE table_schema = 'main' AND table_name = 'snapshots'"
    )
  )$column_name
  testthat::expect_true("hash_rule_version" %in% snapshot_columns)
  testthat::expect_invisible(ledgr_validate_schema(con))
})

testthat::test_that("an older availability store refuses without mutation", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  DBI::dbExecute(
    con,
    "CREATE TABLE ledgr_schema_metadata (
       key TEXT PRIMARY KEY, value TEXT NOT NULL, updated_at_utc TIMESTAMP NOT NULL
     )"
  )
  DBI::dbExecute(
    con,
    "INSERT INTO ledgr_schema_metadata VALUES
     ('experiment_store_schema_version', '112', TIMESTAMP '2026-09-01 00:00:00')"
  )
  DBI::dbExecute(
    con,
    "CREATE TABLE snapshots (
       snapshot_id TEXT PRIMARY KEY,
       status TEXT NOT NULL,
       created_at_utc TIMESTAMP NOT NULL,
       sealed_at_utc TIMESTAMP,
       snapshot_hash TEXT,
       meta_json TEXT,
       error_msg TEXT
     )"
  )

  error <- testthat::expect_error(
    ledgr_create_schema(con),
    class = "ledgr_store_rebuild_required"
  )
  testthat::expect_identical(error$cause, "older")
  recorded <- DBI::dbGetQuery(
    con,
    "SELECT value FROM ledgr_schema_metadata WHERE key = 'experiment_store_schema_version'"
  )$value[[1L]]
  testthat::expect_identical(recorded, "112")
  snapshot_columns <- DBI::dbGetQuery(
    con,
    paste(
      "SELECT column_name FROM information_schema.columns",
      "WHERE table_schema = 'main' AND table_name = 'snapshots'"
    )
  )$column_name
  tables <- DBI::dbGetQuery(
    con,
    "SELECT table_name FROM information_schema.tables WHERE table_schema = 'main'"
  )$table_name
  testthat::expect_false("hash_rule_version" %in% snapshot_columns)
  testthat::expect_false("snapshot_fact_families" %in% tables)
})
