make_csv_file <- function(lines) {
  path <- tempfile(fileext = ".csv")
  writeLines(lines, path, useBytes = TRUE)
  path
}

make_snapshot_with_data <- function(con, snapshot_id) {
  ledgr_create_schema(con)
  ledgr_snapshot_create(con, snapshot_id = snapshot_id, meta = list())

  instruments_csv <- make_csv_file(c(
    "instrument_id,symbol,currency,asset_class,multiplier,tick_size",
    "AAA,AAA,USD,EQUITY,1,0.01",
    "BBB,BBB,USD,EQUITY,1,0.01"
  ))

  bars_csv <- make_csv_file(c(
    "instrument_id,ts_utc,open,high,low,close,volume",
    "BBB,2020-01-01T00:00:00Z,10,11,9,10.5,100",
    "AAA,2020-01-01T00:00:00Z,1,1.1,0.9,1.05,200",
    "BBB,2020-01-02T00:00:00Z,10.1,11.1,9.1,10.6,101",
    "AAA,2020-01-02T00:00:00Z,1.01,1.11,0.91,1.06,201"
  ))

  ledgr_snapshot_import_bars_csv(
    con,
    snapshot_id,
    bars_csv_path = bars_csv,
    instruments_csv_path = instruments_csv,
    auto_generate_instruments = FALSE,
    validate = "fail_fast"
  )

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

testthat::test_that("bars insertion order does not affect snapshot hash", {
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
  testthat::expect_equal(h1, h2)
})

testthat::test_that("instrument changes affect snapshot hash", {
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

testthat::test_that("bar changes affect snapshot hash", {
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

testthat::test_that("snapshot hashing uses 8-decimal numeric encoding (adversarial precision)", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  s1 <- ledgr_snapshot_create(con, snapshot_id = "snapshot_20250101_000000_p1", meta = list())
  s2 <- ledgr_snapshot_create(con, snapshot_id = "snapshot_20250101_000000_p2", meta = list())

  make_bars_csv <- function(close_val) {
    path <- tempfile(fileext = ".csv")
    writeLines(
      c(
        "instrument_id,ts_utc,open,high,low,close,volume",
        sprintf("AAA,2020-01-01T00:00:00Z,0.1,0.1,0.1,%s,0.1", close_val)
      ),
      path,
      useBytes = TRUE
    )
    path
  }

  ledgr_snapshot_import_bars_csv(
    con,
    s1,
    bars_csv_path = make_bars_csv("0.10000000000000001"),
    instruments_csv_path = NULL,
    auto_generate_instruments = TRUE,
    validate = "fail_fast"
  )
  ledgr_snapshot_import_bars_csv(
    con,
    s2,
    bars_csv_path = make_bars_csv("0.10000000000000002"),
    instruments_csv_path = NULL,
    auto_generate_instruments = TRUE,
    validate = "fail_fast"
  )

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

  token <- function(x) {
    if (is.null(x)) return("null")
    if (is.atomic(x) && length(x) == 1 && is.na(x)) return("NA")
    if (is.character(x)) return(x)
    as.character(x)
  }

  fmt_ts_utc <- function(x) {
    if (inherits(x, "POSIXt")) return(format(x, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
    as.character(x)
  }

  fmt_num8 <- function(x) {
    if (is.null(x) || (is.atomic(x) && length(x) == 1 && is.na(x))) return("NA")
    x <- as.numeric(x)
    if (is.na(x) || !is.finite(x)) stop("unexpected numeric in test")
    sprintf("%.8f", round(x, 8))
  }

  inst <- DBI::dbGetQuery(
    con,
    "
    SELECT instrument_id, symbol, currency, asset_class, multiplier, tick_size, meta_json
    FROM snapshot_instruments
    WHERE snapshot_id = ?
    ORDER BY instrument_id
    ",
    params = list(s1)
  )
  bar <- DBI::dbGetQuery(
    con,
    "
    SELECT instrument_id, ts_utc, open, high, low, close, volume
    FROM snapshot_bars
    WHERE snapshot_id = ?
    ORDER BY instrument_id, ts_utc
    ",
    params = list(s1)
  )

  inst_line <- paste(
    token(inst$instrument_id[[1]]),
    token(inst$symbol[[1]]),
    token(inst$currency[[1]]),
    token(inst$asset_class[[1]]),
    fmt_num8(inst$multiplier[[1]]),
    fmt_num8(inst$tick_size[[1]]),
    token(inst$meta_json[[1]]),
    sep = "|"
  )
  bars_line <- paste(
    token(bar$instrument_id[[1]]),
    token(fmt_ts_utc(bar$ts_utc[[1]])),
    fmt_num8(bar$open[[1]]),
    fmt_num8(bar$high[[1]]),
    fmt_num8(bar$low[[1]]),
    fmt_num8(bar$close[[1]]),
    fmt_num8(bar$volume[[1]]),
    sep = "|"
  )

  inst_block_hash <- digest::digest(paste0(inst_line, "\n"), algo = "sha256")
  bars_block_hash <- digest::digest(paste0(bars_line, "\n"), algo = "sha256")
  expected <- digest::digest(paste0(inst_block_hash, bars_block_hash), algo = "sha256")

  testthat::expect_identical(h1, expected)
})

