testthat::test_that("schema validation is repeatable and does not persist test rows", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  ledgr_create_schema(con)

  count <- function(table) DBI::dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM %s", table))$n[[1]]

  before_runs     <- count("runs")
  before_snaps    <- count("snapshots")
  before_features <- count("features")
  before_ledger   <- count("ledger_events")

  testthat::expect_error(ledgr_validate_schema(con), NA)
  testthat::expect_error(ledgr_validate_schema(con), NA)

  testthat::expect_identical(count("runs"),          before_runs)
  testthat::expect_identical(count("snapshots"),     before_snaps)
  testthat::expect_identical(count("features"),      before_features)
  testthat::expect_identical(count("ledger_events"), before_ledger)
})
