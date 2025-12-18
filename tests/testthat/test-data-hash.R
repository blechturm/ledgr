testthat::test_that("ledgr_data_hash is deterministic and order-sensitive in instrument_ids", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  ledgr_create_schema(con)

  DBI::dbExecute(
    con,
    "
    INSERT INTO bars (instrument_id, ts_utc, open, high, low, close, volume)
    VALUES
      ('A', TIMESTAMP '2020-01-01 00:00:00', 1, 1, 1, 1, 100),
      ('A', TIMESTAMP '2020-01-02 00:00:00', 2, 2, 2, 2, 200),
      ('B', TIMESTAMP '2020-01-01 00:00:00', 10, 10, 10, 10, 1000)
    "
  )

  h1 <- ledgr_data_hash(con, c("A", "B"), "2020-01-01T00:00:00Z", "2020-01-02T00:00:00Z")
  h2 <- ledgr_data_hash(con, c("A", "B"), "2020-01-01T00:00:00Z", "2020-01-02T00:00:00Z")
  testthat::expect_identical(h1, h2)

  h3 <- ledgr_data_hash(con, c("B", "A"), "2020-01-01T00:00:00Z", "2020-01-02T00:00:00Z")
  testthat::expect_false(identical(h1, h3))
})

testthat::test_that("changing a single bar changes the hash", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  ledgr_create_schema(con)
  DBI::dbExecute(
    con,
    "
    INSERT INTO bars (instrument_id, ts_utc, open, high, low, close, volume)
    VALUES ('A', TIMESTAMP '2020-01-01 00:00:00', 1, 1, 1, 1, 100)
    "
  )

  h1 <- ledgr_data_hash(con, "A", "2020-01-01T00:00:00Z", "2020-01-01T00:00:00Z")
  DBI::dbExecute(
    con,
    "
    UPDATE bars
    SET open = open + 0.01
    WHERE instrument_id = 'A' AND ts_utc = TIMESTAMP '2020-01-01 00:00:00'
    "
  )
  h2 <- ledgr_data_hash(con, "A", "2020-01-01T00:00:00Z", "2020-01-01T00:00:00Z")
  testthat::expect_false(identical(h1, h2))
})

testthat::test_that("rounding to 8 decimals makes tiny differences beyond precision hash-equal", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  ledgr_create_schema(con)
  DBI::dbExecute(
    con,
    "
    INSERT INTO bars (instrument_id, ts_utc, open, high, low, close, volume)
    VALUES ('A', TIMESTAMP '2020-01-01 00:00:00', 1.000000001, 1, 1, 1, 100)
    "
  )

  h1 <- ledgr_data_hash(con, "A", "2020-01-01T00:00:00Z", "2020-01-01T00:00:00Z")
  DBI::dbExecute(
    con,
    "
    UPDATE bars
    SET open = 1.000000002
    WHERE instrument_id = 'A' AND ts_utc = TIMESTAMP '2020-01-01 00:00:00'
    "
  )
  h2 <- ledgr_data_hash(con, "A", "2020-01-01T00:00:00Z", "2020-01-01T00:00:00Z")
  testthat::expect_identical(h1, h2)
})

testthat::test_that("query ordering makes hash stable even if bars are inserted out of order", {
  make_db <- function(order) {
    con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
    ledgr_create_schema(con)

    rows <- list(
      a2 = "('A', TIMESTAMP '2020-01-02 00:00:00', 2, 2, 2, 2, 200)",
      b1 = "('B', TIMESTAMP '2020-01-01 00:00:00', 10, 10, 10, 10, 1000)",
      a1 = "('A', TIMESTAMP '2020-01-01 00:00:00', 1, 1, 1, 1, 100)"
    )
    values <- paste(unname(rows[order]), collapse = ",\n")
    DBI::dbExecute(
      con,
      paste0(
        "INSERT INTO bars (instrument_id, ts_utc, open, high, low, close, volume) VALUES\n",
        values
      )
    )
    con
  }

  con_x <- make_db(c("a2", "b1", "a1"))
  on.exit(DBI::dbDisconnect(con_x, shutdown = TRUE), add = TRUE)
  con_y <- make_db(c("a1", "a2", "b1"))
  on.exit(DBI::dbDisconnect(con_y, shutdown = TRUE), add = TRUE)

  hx <- ledgr_data_hash(con_x, c("A", "B"), "2020-01-01T00:00:00Z", "2020-01-02T00:00:00Z")
  hy <- ledgr_data_hash(con_y, c("A", "B"), "2020-01-01T00:00:00Z", "2020-01-02T00:00:00Z")
  testthat::expect_identical(hx, hy)
})
