testthat::test_that("schema validation is repeatable and does not persist test rows", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  ledgr_create_schema(con)

  before <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM runs")$n[[1]]
  testthat::expect_error(ledgr_validate_schema(con), NA)
  testthat::expect_error(ledgr_validate_schema(con), NA)
  after <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM runs")$n[[1]]

  testthat::expect_identical(before, after)
})

