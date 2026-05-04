testthat::test_that("snapshot_create with explicit id creates a CREATED snapshot row", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  snapshot_id <- "snapshot_20250101_000000_abcd"
  out <- ledgr_snapshot_create(con, snapshot_id = snapshot_id, meta = list(a = 1, b = "x"))
  testthat::expect_identical(out, snapshot_id)

  row <- DBI::dbGetQuery(con, "SELECT snapshot_id, status, meta_json FROM snapshots WHERE snapshot_id = ?", params = list(snapshot_id))
  testthat::expect_equal(nrow(row), 1L)
  testthat::expect_identical(row$status[[1]], "CREATED")
  testthat::expect_identical(row$meta_json[[1]], as.character(canonical_json(list(a = 1, b = "x"))))
})

testthat::test_that("snapshot_create with NULL id auto-generates per spec pattern", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  id <- ledgr_snapshot_create(con, snapshot_id = NULL, meta = list())
  testthat::expect_true(is.character(id) && length(id) == 1 && nzchar(id))
  testthat::expect_true(grepl("^snapshot_\\d{8}_\\d{6}_[0-9a-f]{4}$", id))
})

testthat::test_that("duplicate snapshot_id fails loud", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  snapshot_id <- "snapshot_20250101_000000_abcd"
  ledgr_snapshot_create(con, snapshot_id = snapshot_id, meta = list())
  testthat::expect_error(
    ledgr_snapshot_create(con, snapshot_id = snapshot_id, meta = list()),
    class = "ledgr_snapshot_exists"
  )
})

testthat::test_that("snapshot_list returns required columns and counts are zero for fresh snapshots", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  snapshot_id <- "snapshot_20250101_000000_abcd"
  ledgr_snapshot_create(con, snapshot_id = snapshot_id, meta = list())

  df <- ledgr_snapshot_list(con)
  testthat::expect_true(is.data.frame(df))
  testthat::expect_s3_class(df, "tbl_df")
  required <- c(
    "snapshot_id",
    "status",
    "created_at_utc",
    "sealed_at_utc",
    "snapshot_hash",
    "bar_count",
    "instrument_count",
    "meta_json",
    "error_msg"
  )
  testthat::expect_true(all(required %in% names(df)))

  one <- df[df$snapshot_id == snapshot_id, , drop = FALSE]
  testthat::expect_equal(nrow(one), 1L)
  testthat::expect_identical(one$status[[1]], "CREATED")
  testthat::expect_true(grepl("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$", one$created_at_utc[[1]]))
  testthat::expect_true(is.na(one$sealed_at_utc[[1]]))
  testthat::expect_true(is.na(one$snapshot_hash[[1]]) || !nzchar(one$snapshot_hash[[1]]))
  testthat::expect_equal(one$bar_count[[1]], 0L)
  testthat::expect_equal(one$instrument_count[[1]], 0L)
})

testthat::test_that("snapshot_list(status=...) filters and validates status enum", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  ledgr_snapshot_create(con, snapshot_id = "snapshot_20250101_000000_abcd", meta = list())
  ledgr_snapshot_create(con, snapshot_id = "snapshot_20250101_000001_abce", meta = list())

  df <- ledgr_snapshot_list(con, status = "CREATED")
  testthat::expect_s3_class(df, "tbl_df")
  testthat::expect_true(all(df$status == "CREATED"))

  empty <- ledgr_snapshot_list(con, status = "SEALED")
  testthat::expect_s3_class(empty, "tbl_df")
  testthat::expect_equal(nrow(empty), 0L)

  testthat::expect_error(ledgr_snapshot_list(con, status = "NOPE"), class = "ledgr_invalid_args")
})

testthat::test_that("snapshot_list accepts a DuckDB path", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  con <- ledgr_db_init(db_path)
  on.exit(if (DBI::dbIsValid(con)) DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  snapshot_id <- "snapshot_20250101_000000_abcd"
  ledgr_snapshot_create(con, snapshot_id = snapshot_id, meta = list())
  DBI::dbDisconnect(con, shutdown = TRUE)

  df <- ledgr_snapshot_list(db_path)
  testthat::expect_s3_class(df, "tbl_df")
  testthat::expect_equal(nrow(df), 1L)
  testthat::expect_identical(df$snapshot_id[[1]], snapshot_id)
})
