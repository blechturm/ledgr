make_snapshot_with_data <- function(con, snapshot_id) {
  ledgr_create_schema(con)
  ledgr_snapshot_create(con, snapshot_id = snapshot_id, meta = list())

  instruments <- data.frame(
    instrument_id = c("AAA", "BBB"),
    symbol = c("AAA", "BBB"),
    currency = "USD",
    asset_class = "EQUITY",
    multiplier = 1,
    tick_size = 0.01,
    stringsAsFactors = FALSE
  )

  bars <- data.frame(
    instrument_id = c("BBB", "AAA", "BBB", "AAA"),
    ts_utc = rep(c("2020-01-01T00:00:00Z", "2020-01-02T00:00:00Z"), each = 2L),
    open = c(10, 1, 10.1, 1.01),
    high = c(11, 1.1, 11.1, 1.11),
    low = c(9, 0.9, 9.1, 0.91),
    close = c(10.5, 1.05, 10.6, 1.06),
    volume = c(100, 200, 101, 201),
    stringsAsFactors = FALSE
  )

  ledgr_test_fill_snapshot(con, snapshot_id, bars, instruments)

  invisible(TRUE)
}

testthat::test_that("snapshot hash is deterministic across repeated calls and chunk sizes", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  snapshot_id <- "snapshot_20250101_000000_abcd"
  make_snapshot_with_data(con, snapshot_id)

  h1 <- ledgr:::ledgr_snapshot_hash(con, snapshot_id, chunk_size = 1)
  h2 <- ledgr:::ledgr_snapshot_hash(con, snapshot_id, chunk_size = 2)
  h3 <- ledgr:::ledgr_snapshot_hash(con, snapshot_id, chunk_size = 10000)

  testthat::expect_type(h1, "character")
  testthat::expect_equal(length(h1), 1L)
  testthat::expect_true(nzchar(h1))
  testthat::expect_equal(h1, h2)
  testthat::expect_equal(h1, h3)
})

testthat::test_that("snapshot hash timestamp encoding fails closed on invalid input", {
  encoded <- ledgr:::ledgr_snapshot_hash_encode_time(
    as.POSIXct("2020-01-01", tz = "UTC")
  )
  testthat::expect_type(encoded, "raw")
  testthat::expect_identical(length(encoded), 9L)
  testthat::expect_error(
    ledgr:::ledgr_snapshot_hash_encode_time("2020-01-01T00:00:00Z"),
    class = "ledgr_snapshot_hash_invalid_timestamp"
  )
})

testthat::test_that("snapshot hash ignores snapshot_id and metadata", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  snapshot_id1 <- ledgr_snapshot_create(con, snapshot_id = "snapshot_20250101_000000_abcd", meta = list())
  snapshot_id2 <- ledgr_snapshot_create(con, snapshot_id = "snapshot_20250101_000000_abce", meta = list())

  instruments <- data.frame(
    snapshot_id = rep(snapshot_id1, 2L),
    instrument_id = c("AAA", "BBB"),
    symbol = c("AAA", "BBB"),
    currency = c("USD", "USD"),
    asset_class = c("EQUITY", "EQUITY"),
    multiplier = c(1.0, 1.0),
    tick_size = c(0.01, 0.01),
    meta_json = c(NA_character_, NA_character_),
    stringsAsFactors = FALSE
  )
  instruments2 <- instruments
  instruments2$snapshot_id <- rep(snapshot_id2, 2L)

  DBI::dbAppendTable(con, "snapshot_instruments", instruments)
  DBI::dbAppendTable(con, "snapshot_instruments", instruments2)

  ts <- as.POSIXct(c("2020-01-01 00:00:00", "2020-01-02 00:00:00"), tz = "UTC")
  bars_ordered <- data.frame(
    snapshot_id = rep(snapshot_id1, 4L),
    instrument_id = c("AAA", "AAA", "BBB", "BBB"),
    ts_utc = c(ts[[1]], ts[[2]], ts[[1]], ts[[2]]),
    open = c(1, 1.01, 10, 10.1),
    high = c(1.1, 1.11, 11, 11.1),
    low = c(0.9, 0.91, 9, 9.1),
    close = c(1.05, 1.06, 10.5, 10.6),
    volume = c(200, 201, 100, 101),
    stringsAsFactors = FALSE
  )
  bars_reversed <- bars_ordered[rev(seq_len(nrow(bars_ordered))), , drop = FALSE]
  bars_reversed$snapshot_id <- rep(snapshot_id2, nrow(bars_reversed))

  DBI::dbAppendTable(con, "snapshot_bars", bars_ordered)
  DBI::dbAppendTable(con, "snapshot_bars", bars_reversed)

  h1 <- ledgr:::ledgr_snapshot_hash(con, snapshot_id1, chunk_size = 2)
  h2 <- ledgr:::ledgr_snapshot_hash(con, snapshot_id2, chunk_size = 2)
  testthat::expect_identical(h1, h2)

  DBI::dbExecute(
    con,
    "UPDATE snapshots SET meta_json = ? WHERE snapshot_id = ?",
    params = list('{"changed":true}', snapshot_id2)
  )
  h3 <- ledgr:::ledgr_snapshot_hash(con, snapshot_id2, chunk_size = 2)
  testthat::expect_identical(h1, h3)
})

testthat::test_that("instrument and bar changes affect the snapshot hash", {
  local({
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  snapshot_id <- "snapshot_20250101_000000_abcd"
  make_snapshot_with_data(con, snapshot_id)

  h1 <- ledgr:::ledgr_snapshot_hash(con, snapshot_id)
  DBI::dbExecute(
    con,
    "UPDATE snapshot_instruments SET multiplier = 2.0 WHERE snapshot_id = ? AND instrument_id = 'AAA'",
    params = list(snapshot_id)
  )
  h2 <- ledgr:::ledgr_snapshot_hash(con, snapshot_id)

  testthat::expect_true(!identical(h1, h2))
  })

  # Also covers: bar changes affect snapshot hash
  local({
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  snapshot_id <- "snapshot_20250101_000000_abcd"
  make_snapshot_with_data(con, snapshot_id)

  h1 <- ledgr:::ledgr_snapshot_hash(con, snapshot_id)
  DBI::dbExecute(
    con,
    "
    UPDATE snapshot_bars
    SET close = close + 0.01
    WHERE snapshot_id = ? AND instrument_id = 'AAA'
    ",
    params = list(snapshot_id)
  )
  h2 <- ledgr:::ledgr_snapshot_hash(con, snapshot_id)

  testthat::expect_true(!identical(h1, h2))
  })
})


testthat::test_that("snapshot hashing uses 8-decimal numeric encoding (adversarial precision)", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  s1 <- ledgr_snapshot_create(con, snapshot_id = "snapshot_20250101_000000_p1", meta = list())
  s2 <- ledgr_snapshot_create(con, snapshot_id = "snapshot_20250101_000000_p2", meta = list())

  make_bars <- function(close_val) {
    data.frame(
      instrument_id = "AAA",
      ts_utc = "2020-01-01T00:00:00Z",
      open = 0.1,
      high = 0.1,
      low = 0.1,
      close = as.numeric(close_val),
      volume = 0.1,
      stringsAsFactors = FALSE
    )
  }

  ledgr_test_fill_snapshot(con, s1, make_bars("0.10000000000000001"))
  ledgr_test_fill_snapshot(con, s2, make_bars("0.10000000000000002"))

  b1 <- DBI::dbGetQuery(
    con,
    "SELECT close, volume FROM snapshot_bars WHERE snapshot_id = ?",
    params = list(s1)
  )
  b2 <- DBI::dbGetQuery(
    con,
    "SELECT close, volume FROM snapshot_bars WHERE snapshot_id = ?",
    params = list(s2)
  )
  testthat::expect_identical(sprintf("%.8f", b1$close[[1]]), sprintf("%.8f", b2$close[[1]]))
  testthat::expect_identical(sprintf("%.8f", b1$volume[[1]]), sprintf("%.8f", b2$volume[[1]]))

  h1 <- ledgr:::ledgr_snapshot_hash(con, s1, chunk_size = 1)
  h2 <- ledgr:::ledgr_snapshot_hash(con, s2, chunk_size = 1)
  testthat::expect_identical(h1, h2)

  DBI::dbExecute(
    con,
    "UPDATE snapshot_bars SET close = close + 0.00000002 WHERE snapshot_id = ?",
    params = list(s2)
  )
  h3 <- ledgr:::ledgr_snapshot_hash(con, s2, chunk_size = 1)
  testthat::expect_false(identical(h1, h3))
})
