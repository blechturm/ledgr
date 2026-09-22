v011_close_con <- function(con) {
  if (!is.null(con) && DBI::dbIsValid(con)) {
    drv <- attr(con, "ledgr_duckdb_drv")
    suppressWarnings(try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE))
    if (!is.null(drv)) suppressWarnings(try(duckdb::duckdb_shutdown(drv), silent = TRUE))
  }
  invisible(TRUE)
}

v011_make_csv <- function(lines, bom = FALSE) {
  path <- tempfile(fileext = ".csv")
  if (isTRUE(bom)) lines[[1]] <- paste0("\ufeff", lines[[1]])
  writeLines(lines, path, useBytes = TRUE)
  path
}

v011_make_runner_cfg <- function(db_path, snapshot_id, universe_ids, start_ts_utc, end_ts_utc) {
  ledgr_test_modernize_config(list(
    db_path = db_path,
    engine = list(seed = 1L, tz = "UTC"),
    data = list(source = "snapshot", snapshot_id = snapshot_id),
    universe = list(instrument_ids = universe_ids),
    backtest = list(
      start_ts_utc = start_ts_utc,
      end_ts_utc = end_ts_utc,
      pulse = "EOD",
      initial_cash = 1000
    ),
    fill_model = list(type = "next_open", spread_bps = 0, commission_fixed = 0),
    features = list(enabled = FALSE, defs = list()),
    strategy = list(id = "hold_zero", params = list())
  ))
}

testthat::test_that("AT1: Snapshot create", {
  db_path <- tempfile(fileext = ".duckdb")
  con <- ledgr_db_init(db_path)
  on.exit(v011_close_con(con), add = TRUE)

  snapshot_id <- ledgr_snapshot_create(con)
  testthat::expect_true(is.character(snapshot_id) && length(snapshot_id) == 1 && nzchar(snapshot_id))

  row <- DBI::dbGetQuery(
    con,
    "SELECT status FROM snapshots WHERE snapshot_id = ?",
    params = list(snapshot_id)
  )
  testthat::expect_equal(nrow(row), 1L)
  testthat::expect_identical(row$status[[1]], "CREATED")
})

testthat::test_that("AT2: bars CSV format contract: rounding and missing column failure", {
  bars_csv <- v011_make_csv(c(
    "instrument_id,ts_utc,open,high,low,close,volume",
    "AAA,2020-01-01T00:00:00Z,1.000000001,1.000000009,1.000000001,1.000000005,10.000000009"
  ))

  snap <- ledgr_snapshot_from_csv(bars_csv)
  on.exit(ledgr_snapshot_close(snap), add = TRUE)

  con <- ledgr_db_init(snap$db_path)
  on.exit(v011_close_con(con), add = TRUE)
  row <- DBI::dbGetQuery(
    con,
    "SELECT open, high, close, volume FROM snapshot_bars WHERE snapshot_id = ?",
    params = list(snap$snapshot_id)
  )
  testthat::expect_equal(nrow(row), 1L)
  testthat::expect_equal(as.numeric(row$open[[1]]), round(1.000000001, 8), tolerance = 1e-12)
  testthat::expect_equal(as.numeric(row$high[[1]]), round(1.000000009, 8), tolerance = 1e-12)
  testthat::expect_equal(as.numeric(row$close[[1]]), round(1.000000005, 8), tolerance = 1e-12)
  testthat::expect_equal(as.numeric(row$volume[[1]]), round(10.000000009, 8), tolerance = 1e-12)

  bad_csv <- v011_make_csv(c(
    "instrument_id,ts_utc,open,high,low",
    "AAA,2020-01-01T00:00:00Z,1,1,1"
  ))
  testthat::expect_error(
    ledgr_snapshot_from_csv(bad_csv),
    class = "ledgr_invalid_args"
  )
})

testthat::test_that("AT3: instruments are generated from the bars when no instruments file is given", {
  bars_csv <- v011_make_csv(c(
    "instrument_id,ts_utc,open,high,low,close",
    "AAA,2020-01-01T00:00:00Z,1,1,1,1",
    "BBB,2020-01-01T00:00:00Z,2,2,2,2"
  ))

  snap <- ledgr_snapshot_from_csv(bars_csv)
  on.exit(ledgr_snapshot_close(snap), add = TRUE)
  testthat::expect_equal(snap$metadata$n_instruments, 2L)

  con <- ledgr_db_init(snap$db_path)
  on.exit(v011_close_con(con), add = TRUE)
  inst <- DBI::dbGetQuery(
    con,
    "SELECT instrument_id, symbol, currency, asset_class FROM snapshot_instruments
     WHERE snapshot_id = ? ORDER BY instrument_id",
    params = list(snap$snapshot_id)
  )
  testthat::expect_identical(inst$instrument_id, c("AAA", "BBB"))
  testthat::expect_identical(inst$symbol, c("AAA", "BBB"))
  testthat::expect_identical(inst$currency, c("USD", "USD"))
  testthat::expect_identical(inst$asset_class, c("EQUITY", "EQUITY"))
})

testthat::test_that("AT4: Seal computes/stores snapshot_hash; instrument metadata differences change hash", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  make_snapshot <- function(snapshot_id, multiplier) {
    ledgr_snapshot_create(con, snapshot_id = snapshot_id, meta = list())
    DBI::dbAppendTable(
      con,
      "snapshot_instruments",
      data.frame(
        snapshot_id = rep(snapshot_id, 1L),
        instrument_id = "AAA",
        symbol = "AAA",
        currency = "USD",
        asset_class = "EQUITY",
        multiplier = multiplier,
        tick_size = 0.01,
        meta_json = NA_character_,
        stringsAsFactors = FALSE
      )
    )
    DBI::dbAppendTable(
      con,
      "snapshot_bars",
      data.frame(
        snapshot_id = rep(snapshot_id, 1L),
        instrument_id = "AAA",
        ts_utc = as.POSIXct("2020-01-01 00:00:00", tz = "UTC"),
        open = 1, high = 1, low = 1, close = 1, volume = 1,
        stringsAsFactors = FALSE
      )
    )
    ledgr_snapshot_seal(con, snapshot_id)
  }

  h1 <- make_snapshot("snapshot_20250101_000000_abcd", multiplier = 1.0)
  h2 <- make_snapshot("snapshot_20250101_000000_abce", multiplier = 2.0)

  row1 <- DBI::dbGetQuery(con, "SELECT status, sealed_at_utc, snapshot_hash FROM snapshots WHERE snapshot_id = 'snapshot_20250101_000000_abcd'")
  testthat::expect_identical(row1$status[[1]], "SEALED")
  testthat::expect_false(is.na(row1$sealed_at_utc[[1]]))
  testthat::expect_true(nzchar(row1$snapshot_hash[[1]]))
  testthat::expect_true(!identical(h1, h2))
})

testthat::test_that("AT5: Seal is atomic (forced hash failure -> FAILED, no partial hash)", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  snapshot_id <- ledgr_snapshot_create(con, snapshot_id = "snapshot_20250101_000000_abcd", meta = list())
  DBI::dbAppendTable(
    con,
    "snapshot_instruments",
    data.frame(
      snapshot_id = snapshot_id,
      instrument_id = "AAA",
      symbol = "AAA",
      currency = "USD",
      asset_class = "EQUITY",
      multiplier = 1.0,
      tick_size = 0.01,
      meta_json = NA_character_,
      stringsAsFactors = FALSE
    )
  )
  DBI::dbAppendTable(
    con,
    "snapshot_bars",
    data.frame(
      snapshot_id = snapshot_id,
      instrument_id = "AAA",
      ts_utc = as.POSIXct("2020-01-01 00:00:00", tz = "UTC"),
      open = 1, high = 1, low = 1, close = 1, volume = 1,
      stringsAsFactors = FALSE
    )
  )

  ns <- asNamespace("ledgr")
  original <- get("ledgr_snapshot_hash", envir = ns, inherits = FALSE)
  unlockBinding("ledgr_snapshot_hash", ns)
  assign("ledgr_snapshot_hash", function(...) rlang::abort("forced", class = "ledgr_test_forced_error"), envir = ns)
  lockBinding("ledgr_snapshot_hash", ns)
  on.exit(
    {
      unlockBinding("ledgr_snapshot_hash", ns)
      assign("ledgr_snapshot_hash", original, envir = ns)
      lockBinding("ledgr_snapshot_hash", ns)
    },
    add = TRUE
  )

  testthat::expect_error(ledgr_snapshot_seal(con, snapshot_id), class = "LEDGR_SNAPSHOT_SEAL_FAILED")

  row <- DBI::dbGetQuery(con, "SELECT status, sealed_at_utc, snapshot_hash, error_msg FROM snapshots WHERE snapshot_id = ?", params = list(snapshot_id))
  testthat::expect_identical(row$status[[1]], "FAILED")
  testthat::expect_true(is.na(row$sealed_at_utc[[1]]))
  testthat::expect_true(is.na(row$snapshot_hash[[1]]))
  testthat::expect_true(is.character(row$error_msg[[1]]) && nzchar(row$error_msg[[1]]))
})

# ledgr-test-profile: review
testthat::test_that("AT7: Tamper detection on load (runner)", {
  db_path <- tempfile(fileext = ".duckdb")
  con <- ledgr_db_init(db_path)

  snapshot_id <- ledgr_snapshot_create(con, snapshot_id = "snapshot_20250101_000000_abcd", meta = list())
  ledgr_test_fill_snapshot(
    con,
    snapshot_id,
    data.frame(
      instrument_id = "AAA",
      ts_utc = c("2020-01-01T00:00:00Z", "2020-01-02T00:00:00Z"),
      open = 1, high = 1, low = 1, close = 1, volume = 1,
      stringsAsFactors = FALSE
    )
  )
  ledgr_snapshot_seal(con, snapshot_id)

  v011_close_con(con)
  gc()
  Sys.sleep(0.05)

  opened <- ledgr_test_open_duckdb(db_path)
  con2 <- opened$con
  drv2 <- opened$drv
  DBI::dbExecute(
    con2,
    "UPDATE snapshot_bars SET close = close + 1 WHERE snapshot_id = ?",
    params = list(snapshot_id)
  )
  ledgr_test_close_duckdb(con2, drv2)
  gc()
  Sys.sleep(0.05)

  cfg <- v011_make_runner_cfg(db_path, snapshot_id, universe_ids = c("AAA"), start_ts_utc = "2020-01-01T00:00:00Z", end_ts_utc = "2020-01-02T00:00:00Z")
  testthat::expect_error(ledgr_run_config(cfg, run_id = "run-v011-tamper"), class = "LEDGR_SNAPSHOT_CORRUPTED")
})

# ledgr-test-profile: review
testthat::test_that("AT8: Subset universe allowed", {
  db_path <- tempfile(fileext = ".duckdb")
  con <- ledgr_db_init(db_path)

  snapshot_id <- ledgr_snapshot_create(con, snapshot_id = "snapshot_20250101_000000_abcd", meta = list())
  ledgr_test_fill_snapshot(
    con,
    snapshot_id,
    data.frame(
      instrument_id = rep(c("AAA", "CCC"), each = 2L),
      ts_utc = rep(c("2020-01-01T00:00:00Z", "2020-01-02T00:00:00Z"), times = 2L),
      open = 1, high = 1, low = 1, close = 1, volume = 1,
      stringsAsFactors = FALSE
    ),
    instruments = data.frame(
      instrument_id = c("AAA", "BBB", "CCC"),
      symbol = c("AAA", "BBB", "CCC"),
      currency = "USD",
      asset_class = "EQUITY",
      multiplier = 1,
      tick_size = 0.01,
      stringsAsFactors = FALSE
    )
  )
  ledgr_snapshot_seal(con, snapshot_id)

  v011_close_con(con)
  gc()
  Sys.sleep(0.05)

  cfg <- v011_make_runner_cfg(db_path, snapshot_id, universe_ids = c("AAA", "CCC"), start_ts_utc = "2020-01-01T00:00:00Z", end_ts_utc = "2020-01-02T00:00:00Z")
  out <- ledgr_run_config(cfg, run_id = "run-v011-subset")
  testthat::expect_identical(out$run_id, "run-v011-subset")
})

# ledgr-test-profile: review
testthat::test_that("AT9: Per-instrument coverage validation fails on ragged coverage", {
  db_path <- tempfile(fileext = ".duckdb")
  con <- ledgr_db_init(db_path)

  snapshot_id <- ledgr_snapshot_create(con, snapshot_id = "snapshot_20250101_000000_abcd", meta = list())
  DBI::dbAppendTable(
    con,
    "snapshot_instruments",
    data.frame(
      snapshot_id = rep(snapshot_id, 2L),
      instrument_id = c("AAA", "BBB"),
      symbol = c("AAA", "BBB"),
      currency = c("USD", "USD"),
      asset_class = c("EQUITY", "EQUITY"),
      multiplier = c(1.0, 1.0),
      tick_size = c(0.01, 0.01),
      meta_json = c(NA_character_, NA_character_),
      stringsAsFactors = FALSE
    )
  )
  DBI::dbAppendTable(
    con,
    "snapshot_bars",
    data.frame(
      snapshot_id = c(rep(snapshot_id, 3L), rep(snapshot_id, 3L)),
      instrument_id = c("AAA", "AAA", "AAA", "BBB", "BBB", "BBB"),
      ts_utc = as.POSIXct(
        c("2020-01-01 00:00:00", "2021-01-01 00:00:00", "2022-01-01 00:00:00", "2021-01-01 00:00:00", "2022-01-01 00:00:00", "2023-01-01 00:00:00"),
        tz = "UTC"
      ),
      open = 1, high = 1, low = 1, close = 1, volume = 1,
      stringsAsFactors = FALSE
    )
  )
  ledgr_snapshot_seal(con, snapshot_id)

  v011_close_con(con)
  gc()
  Sys.sleep(0.05)

  cfg <- v011_make_runner_cfg(db_path, snapshot_id, universe_ids = c("AAA", "BBB"), start_ts_utc = "2020-01-01T00:00:00Z", end_ts_utc = "2023-01-01T00:00:00Z")
  testthat::expect_error(ledgr_run_config(cfg, run_id = "run-v011-coverage"), class = "LEDGR_SNAPSHOT_COVERAGE_ERROR")
})

testthat::test_that("AT10: Snapshot discovery APIs (list + info)", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  s1 <- ledgr_snapshot_create(con, snapshot_id = "snapshot_20250101_000000_abcd", meta = list())
  s2 <- ledgr_snapshot_create(con, snapshot_id = "snapshot_20250101_000000_abce", meta = list())
  DBI::dbExecute(con, "UPDATE snapshots SET status = 'FAILED' WHERE snapshot_id = ?", params = list(s2))

  lst <- ledgr_snapshot_list(con)
  testthat::expect_true(all(c("snapshot_id", "status", "created_at_utc", "instrument_count", "bar_count") %in% names(lst)))

  info <- ledgr_snapshot_info(con, s1)
  testthat::expect_equal(
    names(info),
    c(
      "snapshot_id",
      "status",
      "created_at_utc",
      "sealed_at_utc",
      "snapshot_hash",
      "bar_count",
      "instrument_count",
      "start_date",
      "end_date",
      "meta_json",
      "error_msg"
    )
  )
})

testthat::test_that("AT11: Empty snapshot seal fails", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  snapshot_id <- ledgr_snapshot_create(con, snapshot_id = "snapshot_20250101_000000_abcd", meta = list())
  testthat::expect_error(ledgr_snapshot_seal(con, snapshot_id), class = "LEDGR_SNAPSHOT_EMPTY")

  row <- DBI::dbGetQuery(con, "SELECT status, snapshot_hash FROM snapshots WHERE snapshot_id = ?", params = list(snapshot_id))
  testthat::expect_identical(row$status[[1]], "CREATED")
  testthat::expect_true(is.na(row$snapshot_hash[[1]]))
})

testthat::test_that("AT12: UTF-8 BOM tolerated", {
  bars_csv <- v011_make_csv(
    c(
      "instrument_id,ts_utc,open,high,low,close",
      "AAA,2020-01-01T00:00:00Z,1,1,1,1"
    ),
    bom = TRUE
  )

  snap <- ledgr_snapshot_from_csv(bars_csv)
  on.exit(ledgr_snapshot_close(snap), add = TRUE)

  con <- ledgr_db_init(snap$db_path)
  on.exit(v011_close_con(con), add = TRUE)
  ids <- DBI::dbGetQuery(
    con,
    "SELECT instrument_id FROM snapshot_bars WHERE snapshot_id = ?",
    params = list(snap$snapshot_id)
  )$instrument_id
  testthat::expect_identical(as.character(ids), "AAA")
})
