testthat::test_that("current schema retains normalized availability tables", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  testthat::expect_identical(
    ledgr:::ledgr_experiment_store_version(con),
    ledgr:::ledgr_experiment_store_schema_version
  )
  testthat::expect_identical(ledgr:::ledgr_saved_sweep_schema_version, 4L)
  tables <- DBI::dbGetQuery(
    con,
    "SELECT table_name FROM information_schema.tables WHERE table_schema = 'main'"
  )$table_name
  testthat::expect_true(all(names(ledgr:::ledgr_snapshot_availability_tables()) %in% tables))
  testthat::expect_true("hash_rule_version" %in% ledgr:::ledgr_experiment_store_columns(con, "snapshots"))
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
  testthat::expect_false("hash_rule_version" %in% ledgr:::ledgr_experiment_store_columns(con, "snapshots"))
  testthat::expect_false(ledgr:::ledgr_experiment_store_table_exists(con, "snapshot_fact_families"))
})

# ledgr-test-profile: review
testthat::test_that("missing-marker snapshots stay readable but do not verify", {
  db_path <- tempfile(fileext = ".duckdb")
  bars <- data.frame(
    instrument_id = "AAA",
    ts_utc = as.POSIXct("2024-01-01", tz = "UTC"),
    open = 10, high = 11, low = 9, close = 10, volume = 100
  )
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  id <- snapshot$snapshot_id
  hash <- ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]]
  con <- ledgr:::get_connection(snapshot)
  DBI::dbExecute(
    con,
    "UPDATE snapshots SET hash_rule_version = NULL WHERE snapshot_id = ?",
    params = list(id)
  )
  ledgr_snapshot_close(snapshot)

  con <- ledgr_db_init(db_path)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  row <- DBI::dbGetQuery(
    con,
    "SELECT status, snapshot_hash, hash_rule_version FROM snapshots WHERE snapshot_id = ?",
    params = list(id)
  )
  testthat::expect_identical(row$status[[1L]], "SEALED")
  testthat::expect_identical(row$snapshot_hash[[1L]], hash)
  testthat::expect_true(is.na(row$hash_rule_version[[1L]]))
  testthat::expect_true(is.na(
    ledgr:::ledgr_snapshot_hash_rule_version(con, id)
  ))
  testthat::expect_error(
    ledgr:::ledgr_snapshot_hash(con, id),
    class = "ledgr_snapshot_rebuild_required"
  )
})
