store_marker_connection <- function(version, fingerprint = NULL) {
  con <- DBI::dbConnect(
    duckdb::duckdb(shared_home = FALSE), dbdir = ":memory:"
  )
  DBI::dbExecute(
    con,
    paste0(
      "CREATE TABLE ledgr_schema_metadata(",
      "key VARCHAR PRIMARY KEY, value VARCHAR NOT NULL, ",
      "updated_at_utc TIMESTAMP NOT NULL)"
    )
  )
  DBI::dbExecute(
    con,
    paste0(
      "INSERT INTO ledgr_schema_metadata VALUES ",
      "('experiment_store_schema_version', ?, CURRENT_TIMESTAMP)"
    ),
    params = list(as.character(version))
  )
  if (!is.null(fingerprint)) {
    DBI::dbExecute(
      con,
      paste0(
        "INSERT INTO ledgr_schema_metadata VALUES ",
        "('format_fingerprint', ?, CURRENT_TIMESTAMP)"
      ),
      params = list(fingerprint)
    )
  }
  con
}

testthat::test_that("non-current experiment stores refuse without mutation", {
  for (case in list(
    list(version = 118L, cause = "older"),
    list(version = 999L, cause = "newer")
  )) {
    con <- store_marker_connection(case$version)
    DBI::dbExecute(con, "CREATE TABLE sentinel(value INTEGER)")
    DBI::dbExecute(con, "INSERT INTO sentinel VALUES (7)")
    error <- testthat::expect_error(
      ledgr_create_schema(con),
      class = "ledgr_store_rebuild_required"
    )
    testthat::expect_identical(error$cause, case$cause)
    testthat::expect_identical(
      DBI::dbGetQuery(con, "SELECT value FROM sentinel")$value,
      7L
    )
    DBI::dbDisconnect(con, shutdown = TRUE)
  }
})

testthat::test_that("runs.execution_mode rejects values outside current modes", {
  con <- DBI::dbConnect(
    duckdb::duckdb(shared_home = FALSE), dbdir = ":memory:"
  )
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  DBI::dbExecute(
    con,
    paste0(
      "INSERT INTO runs (run_id, created_at_utc, engine_version, ",
      "config_json, config_hash, status, error_msg) VALUES ",
      "('run-mode-check', CURRENT_TIMESTAMP, 'current', '{}', ",
      "'config-hash', 'DONE', NULL)"
    )
  )
  testthat::expect_error(DBI::dbExecute(
    con,
    "UPDATE runs SET execution_mode = 'other' WHERE run_id = 'run-mode-check'"
  ))
  testthat::expect_no_error(DBI::dbExecute(
    con,
    "UPDATE runs SET execution_mode = 'db_live' WHERE run_id = 'run-mode-check'"
  ))
})

testthat::test_that("run telemetry constrains execution_mode to current values", {
  con <- DBI::dbConnect(
    duckdb::duckdb(shared_home = FALSE), dbdir = ":memory:"
  )
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  testthat::expect_error(DBI::dbExecute(
    con,
    paste0(
      "INSERT INTO run_telemetry (run_id, status, execution_mode) ",
      "VALUES ('run-bad-mode', 'DONE', 'other')"
    )
  ))
  testthat::expect_no_error(DBI::dbExecute(
    con,
    paste0(
      "INSERT INTO run_telemetry (run_id, status, execution_mode) ",
      "VALUES ('run-good-mode', 'DONE', 'audit_log')"
    )
  ))
})
