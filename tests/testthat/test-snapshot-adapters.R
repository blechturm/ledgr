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
  meta <- jsonlite::fromJSON(info$meta_json[[1]], simplifyVector = TRUE)
  expect_equal(meta$data_hash, snap$metadata$data_hash)
})

test_that("ledgr_snapshot_from_df validates required columns", {
  bad <- test_bars
  bad$close <- NULL
  expect_error(ledgr_snapshot_from_df(bad), "bars_df missing required column")
})

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

seal_manual_csv_snapshot <- function(bars, meta = list(), snapshot_id = "manual_csv_snapshot") {
  csv_path <- tempfile(fileext = ".csv")
  utils::write.csv(bars, csv_path, row.names = FALSE)

  db_path <- tempfile(fileext = ".duckdb")
  con <- ledgr_db_init(db_path)
  on.exit(if (DBI::dbIsValid(con)) DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  ledgr_snapshot_create(con, snapshot_id = snapshot_id, meta = meta)
  ledgr_snapshot_import_bars_csv(
    con,
    snapshot_id,
    bars_csv_path = csv_path,
    instruments_csv_path = NULL,
    auto_generate_instruments = TRUE
  )
  hash <- ledgr_snapshot_seal(con, snapshot_id)
  info <- ledgr_snapshot_info(con, snapshot_id)

  unlink(csv_path)
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

test_that("create/import/seal CSV snapshots infer runnable metadata", {
  snapshot <- seal_manual_csv_snapshot(make_manual_csv_bars())
  on.exit(unlink(snapshot$db_path), add = TRUE)

  meta <- jsonlite::fromJSON(snapshot$info$meta_json[[1]], simplifyVector = FALSE)
  expect_equal(meta$n_bars, 8L)
  expect_equal(meta$n_instruments, 2L)
  expect_equal(meta$start_date, "2020-04-01T00:00:00Z")
  expect_equal(meta$end_date, "2020-04-04T00:00:00Z")

  loaded <- ledgr_snapshot_load(snapshot$db_path, snapshot$snapshot_id, verify = TRUE)
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
    universe = c("AAA", "BBB")
  )
  bt <- ledgr_run(exp, params = list(), run_id = "manual-csv-run")
  on.exit(close(bt), add = TRUE)

  expect_s3_class(bt, "ledgr_backtest")
  expect_true(nrow(ledgr_results(bt, "equity")) > 0L)
})

test_that("CSV seal metadata derivation preserves existing user metadata", {
  snapshot <- seal_manual_csv_snapshot(
    make_manual_csv_bars(),
    meta = list(description = "manual research fixture", n_bars = 999L)
  )
  on.exit(unlink(snapshot$db_path), add = TRUE)

  meta <- jsonlite::fromJSON(snapshot$info$meta_json[[1]], simplifyVector = FALSE)
  expect_equal(meta$description, "manual research fixture")
  expect_equal(meta$n_bars, 999L)
  expect_equal(meta$n_instruments, 2L)
  expect_equal(meta$start_date, "2020-04-01T00:00:00Z")
  expect_equal(meta$end_date, "2020-04-04T00:00:00Z")
})

test_that("low-level CSV sealing preserves high-level snapshot hash identity", {
  bars <- make_manual_csv_bars()

  db_path_from_df <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path_from_df), add = TRUE)
  from_df <- ledgr_snapshot_from_df(bars, db_path = db_path_from_df, snapshot_id = "from_df_snapshot")
  on.exit(ledgr_snapshot_close(from_df), add = TRUE)
  con_from_df <- ledgr_db_init(from_df$db_path)
  on.exit(DBI::dbDisconnect(con_from_df, shutdown = TRUE), add = TRUE)
  from_df_info <- ledgr_snapshot_info(con_from_df, from_df$snapshot_id)

  low_level <- seal_manual_csv_snapshot(bars, snapshot_id = "manual_csv_snapshot")
  on.exit(unlink(low_level$db_path), add = TRUE)

  expect_equal(low_level$hash, from_df_info$snapshot_hash[[1]])
})

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

test_that("ledgr_snapshot_from_yahoo requires quantmod", {
  if (requireNamespace("quantmod", quietly = TRUE)) {
    skip("quantmod installed; missing-package path not exercised")
  }
  expect_error(
    ledgr_snapshot_from_yahoo(symbols = "AAPL", from = "2020-01-01", to = "2020-01-02"),
    "quantmod package required"
  )
})
