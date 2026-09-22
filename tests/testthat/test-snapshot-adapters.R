# ledgr-test-profile: review
test_that("ledgr_snapshot_from_df creates a sealed snapshot", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snap <- ledgr_snapshot_from_df(test_bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snap), add = TRUE)

  expect_s3_class(snap, "ledgr_snapshot")
  expect_true(file.exists(snap$db_path))
  expect_equal(snap$metadata$n_bars, 732L)
  expect_equal(snap$metadata$n_instruments, 2L)
  expect_equal(snap$metadata$start_date, "2020-01-01T00:00:00Z")
  expect_equal(snap$metadata$end_date, "2020-12-31T00:00:00Z")

  con <- ledgr_db_init(snap$db_path)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  info <- ledgr_snapshot_info(con, snap$snapshot_id)
  meta <- ledgr:::ledgr_json_read_config(info$meta_json[[1]])
  expect_false("data_hash" %in% names(meta))
  expect_false("data_hash" %in% names(snap$metadata))
})

test_that("ledgr_snapshot_from_df validates required columns", {
  bad <- test_bars
  bad$close <- NULL
  expect_error(ledgr_snapshot_from_df(bad), "bars_df missing required column")
})

test_that("ledgr_snapshot_from_df rejects sub-second POSIXct bars", {
  bad <- test_bars
  bad$ts_utc <- as.POSIXct(bad$ts_utc, tz = "UTC")
  bad$ts_utc[[1]] <- bad$ts_utc[[1]] + 0.25

  expect_error(
    ledgr_snapshot_from_df(bad),
    class = "LEDGR_SUBSECOND_TIMESTAMP"
  )
})

# ledgr-test-profile: review
test_that("ledgr_snapshot_from_df allows custom snapshot IDs and warns on malformed generated-style IDs", {
  expect_warning(
    snap <- ledgr_snapshot_from_df(test_bars, snapshot_id = "research_baseline"),
    NA
  )
  on.exit(ledgr_snapshot_close(snap), add = TRUE)

  expect_warning(
    snap_bad <- ledgr_snapshot_from_df(test_bars, snapshot_id = "snapshot_bad"),
    class = "ledgr_snapshot_id_noncanonical"
  )
  on.exit(ledgr_snapshot_close(snap_bad), add = TRUE)
})

test_that("ledgr_snapshot_from_df requires chronological bars per instrument", {
  bad <- test_bars
  idx <- which(bad$instrument_id == "TEST_A")
  bad[idx, ] <- bad[rev(idx), ]

  expect_error(
    ledgr_snapshot_from_df(bad),
    "chronological"
  )
})

make_manual_csv_bars <- function() {
  data.frame(
    instrument_id = rep(c("AAA", "BBB"), each = 4L),
    ts_utc = rep(
      c(
        "2020-04-01T00:00:00Z",
        "2020-04-02T00:00:00Z",
        "2020-04-03T00:00:00Z",
        "2020-04-04T00:00:00Z"
      ),
      2L
    ),
    open = c(100, 101, 102, 103, 50, 49, 48, 47),
    high = c(101, 102, 103, 104, 51, 50, 49, 48),
    low = c(99, 100, 101, 102, 49, 48, 47, 46),
    close = c(100, 102, 101, 104, 50, 48, 49, 47),
    volume = 1000,
    stringsAsFactors = FALSE
  )
}

seal_manual_snapshot <- function(bars, meta = list(), snapshot_id = "manual_snapshot") {
  db_path <- tempfile(fileext = ".duckdb")
  con <- ledgr_db_init(db_path)
  on.exit(if (DBI::dbIsValid(con)) DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  ledgr_snapshot_create(con, snapshot_id = snapshot_id, meta = meta)
  ledgr_test_fill_snapshot(con, snapshot_id, bars)
  hash <- ledgr_snapshot_seal(con, snapshot_id)
  info <- ledgr_snapshot_info(con, snapshot_id)

  list(db_path = db_path, snapshot_id = snapshot_id, hash = hash, info = info)
}

test_that("ledgr_snapshot_from_csv delegates to df adapter", {
  csv_path <- tempfile(fileext = ".csv")
  on.exit(unlink(csv_path), add = TRUE)
  utils::write.csv(test_bars, csv_path, row.names = FALSE)

  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snap <- ledgr_snapshot_from_csv(csv_path, db_path = db_path)
  on.exit(ledgr_snapshot_close(snap), add = TRUE)

  expect_s3_class(snap, "ledgr_snapshot")
  expect_true(file.exists(snap$db_path))
})

# ledgr-test-profile: review
test_that("a directly built snapshot infers runnable metadata", {
  snapshot <- seal_manual_snapshot(make_manual_csv_bars())
  on.exit(unlink(snapshot$db_path), add = TRUE)

  meta <- ledgr:::ledgr_json_read_nested(snapshot$info$meta_json[[1]])
  expect_equal(meta$n_bars, 8L)
  expect_equal(meta$n_instruments, 2L)
  expect_equal(meta$start_date, "2020-04-01T00:00:00Z")
  expect_equal(meta$end_date, "2020-04-04T00:00:00Z")

  loaded <- ledgr_snapshot_open(snapshot$db_path, snapshot$snapshot_id, verify = TRUE)
  on.exit(ledgr_snapshot_close(loaded), add = TRUE)
  expect_equal(loaded$metadata$start_date, "2020-04-01T00:00:00Z")
  expect_equal(loaded$metadata$end_date, "2020-04-04T00:00:00Z")

  strategy <- function(ctx, params) {
    ctx$flat()
  }
  exp <- ledgr_experiment(
    snapshot = loaded,
    strategy = strategy,
    opening = ledgr_opening(cash = 10000),
    universe = c("AAA", "BBB"),
  cost_model = ledgr_cost_zero()
  )
  bt <- ledgr_run(exp, params = list(), run_id = "manual-csv-run")
  on.exit(close(bt), add = TRUE)

  expect_s3_class(bt, "ledgr_backtest")
  expect_true(nrow(ledgr_results(bt, "equity")) > 0L)
})

test_that("seal metadata derivation preserves existing user metadata", {
  snapshot <- seal_manual_snapshot(
    make_manual_csv_bars(),
    meta = list(description = "manual research fixture", n_bars = 999L)
  )
  on.exit(unlink(snapshot$db_path), add = TRUE)

  meta <- ledgr:::ledgr_json_read_nested(snapshot$info$meta_json[[1]])
  expect_equal(meta$description, "manual research fixture")
  expect_equal(meta$n_bars, 999L)
  expect_equal(meta$n_instruments, 2L)
  expect_equal(meta$start_date, "2020-04-01T00:00:00Z")
  expect_equal(meta$end_date, "2020-04-04T00:00:00Z")
})

# ledgr-test-profile: review
test_that("direct snapshot writes preserve high-level snapshot hash identity", {
  bars <- make_manual_csv_bars()

  db_path_from_df <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path_from_df), add = TRUE)
  from_df <- ledgr_snapshot_from_df(bars, db_path = db_path_from_df, snapshot_id = "from_df_snapshot")
  on.exit(ledgr_snapshot_close(from_df), add = TRUE)
  con_from_df <- ledgr_db_init(from_df$db_path)
  on.exit(DBI::dbDisconnect(con_from_df, shutdown = TRUE), add = TRUE)
  from_df_info <- ledgr_snapshot_info(con_from_df, from_df$snapshot_id)

  low_level <- seal_manual_snapshot(bars, snapshot_id = "manual_snapshot")
  on.exit(unlink(low_level$db_path), add = TRUE)

  expect_equal(low_level$hash, from_df_info$snapshot_hash[[1]])
})

# ledgr-test-profile: review
test_that("ledgr_snapshot_from_yahoo works offline with CSV fixture", {
  skip_if_not_installed("quantmod")

  fixture_path <- system.file("testdata", "yahoo_mock.csv", package = "ledgr")
  if (!nzchar(fixture_path)) {
    skip("Yahoo mock fixture not found.")
  }

  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snap <- ledgr_snapshot_from_yahoo(
    symbols = "yahoo_mock",
    from = "2020-01-01",
    to = "2020-01-05",
    db_path = db_path,
    src = "csv",
    dir = dirname(fixture_path)
  )
  on.exit(ledgr_snapshot_close(snap), add = TRUE)

  expect_s3_class(snap, "ledgr_snapshot")
  expect_equal(snap$metadata$n_bars, 5L)
  expect_equal(snap$metadata$n_instruments, 1L)
})

# ledgr-test-profile: review
test_that("ledgr_yahoo_extract_bars uses named columns", {
  skip_if_not_installed("xts")

  dates <- as.Date(c("2020-01-01", "2020-01-02"))
  x <- xts::xts(
    x = cbind(
      AAPL.Open = c(100, 101),
      AAPL.High = c(102, 103),
      AAPL.Low = c(99, 100),
      AAPL.Close = c(101, 102),
      AAPL.Volume = c(1000, 1100),
      AAPL.Adjusted = c(101, 102)
    ),
    order.by = dates
  )

  out <- ledgr:::ledgr_yahoo_extract_bars(x, "AAPL")
  expect_equal(nrow(out), 2)
  expect_equal(out$instrument_id[[1]], "AAPL")
  expect_equal(out$ts_utc[[1]], "2020-01-01T00:00:00Z")
})

# ledgr-test-profile: review
test_that("ledgr_snapshot_from_yahoo requires quantmod", {
  if (requireNamespace("quantmod", quietly = TRUE)) {
    skip("quantmod installed; missing-package path not exercised")
  }
  expect_error(
    ledgr_snapshot_from_yahoo(symbols = "AAPL", from = "2020-01-01", to = "2020-01-02"),
    "quantmod package required"
  )
})

# ledgr-test-profile: review
test_that("ledgr_snapshot_from_csv accepts an instruments CSV", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  bars_path <- tempfile(fileext = ".csv")
  utils::write.csv(
    data.frame(
      instrument_id = rep(c("AAA", "BBB"), each = 2L),
      ts_utc = rep(c("2020-01-01T00:00:00Z", "2020-01-02T00:00:00Z"), 2L),
      open = c(100, 101, 200, 201),
      high = c(101, 102, 201, 202),
      low = c(99, 100, 199, 200),
      close = c(100, 101, 200, 201),
      volume = 1000,
      stringsAsFactors = FALSE
    ),
    bars_path,
    row.names = FALSE
  )

  inst_path <- tempfile(fileext = ".csv")
  utils::write.csv(
    data.frame(
      instrument_id = c("AAA", "BBB"),
      symbol = c("ALPHA", "BETA"),
      currency = c("EUR", "USD"),
      asset_class = c("EQUITY", "EQUITY"),
      multiplier = c(2, 1),
      tick_size = c(0.05, 0.01),
      stringsAsFactors = FALSE
    ),
    inst_path,
    row.names = FALSE
  )

  snap <- ledgr_snapshot_from_csv(
    bars_path,
    instruments_csv_path = inst_path,
    db_path = db_path
  )
  on.exit(ledgr_snapshot_close(snap), add = TRUE)

  expect_equal(snap$metadata$n_instruments, 2L)

  con <- ledgr_db_init(snap$db_path)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  inst <- DBI::dbGetQuery(
    con,
    "SELECT instrument_id, symbol, currency, asset_class, multiplier, tick_size
     FROM snapshot_instruments WHERE snapshot_id = ? ORDER BY instrument_id",
    params = list(snap$snapshot_id)
  )
  expect_identical(inst$instrument_id, c("AAA", "BBB"))
  expect_identical(inst$symbol, c("ALPHA", "BETA"))
  expect_identical(inst$currency, c("EUR", "USD"))
  expect_equal(inst$multiplier, c(2, 1))
  expect_equal(inst$tick_size, c(0.05, 0.01))
})

# ledgr-test-profile: review
test_that("ledgr_snapshot_from_csv quarantines exactly as ledgr_snapshot_from_df does", {
  sessions <- data.frame(
    session_date = as.Date("2024-01-01") + 0:4,
    status = c("closed", "open", "open", "open", "open"),
    session_open = c(NA_character_, rep("09:30:00", 4L)),
    session_close = c(NA_character_, rep("16:00:00", 4L)),
    knowledge_time = as.POSIXct("2023-12-01", tz = "UTC"),
    stringsAsFactors = FALSE
  )
  facts <- ledgr_facts(
    ledgr_facts_sessions(
      sessions,
      venue_id = "XNYS",
      timezone = "America/New_York"
    )
  )

  bars <- data.frame(
    instrument_id = "AAA",
    ts_utc = as.Date("2024-01-02") + 0:2,
    open = c(10, 11, 12),
    high = c(11, 8, 13),
    low = c(9, 10, 11),
    close = c(10, 11, 12),
    volume = 100,
    stringsAsFactors = FALSE
  )

  csv_path <- tempfile(fileext = ".csv")
  utils::write.csv(bars, csv_path, row.names = FALSE)

  db_df <- tempfile(fileext = ".duckdb")
  db_csv <- tempfile(fileext = ".duckdb")
  on.exit(unlink(c(db_df, db_csv)), add = TRUE)

  snap_df <- ledgr_snapshot_from_df(
    bars,
    db_path = db_df,
    facts = facts,
    invalid_observations = "quarantine"
  )
  on.exit(ledgr_snapshot_close(snap_df), add = TRUE)

  snap_csv <- ledgr_snapshot_from_csv(
    csv_path,
    db_path = db_csv,
    facts = facts,
    invalid_observations = "quarantine"
  )
  on.exit(ledgr_snapshot_close(snap_csv), add = TRUE)

  expect_equal(snap_df$metadata$quarantined_observation_count, 1L)
  expect_identical(
    snap_csv$metadata$quarantined_observation_count,
    snap_df$metadata$quarantined_observation_count
  )
  expect_identical(snap_csv$metadata$n_bars, snap_df$metadata$n_bars)

  hash_of <- function(snap) {
    con <- ledgr_db_init(snap$db_path)
    on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
    ledgr_snapshot_info(con, snap$snapshot_id)$snapshot_hash
  }
  expect_identical(hash_of(snap_csv), hash_of(snap_df))
})
