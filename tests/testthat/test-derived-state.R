insert_test_run_ds <- function(con, run_id, initial_cash) {
  DBI::dbExecute(
    con,
    "
    INSERT INTO runs (
      run_id,
      created_at_utc,
      engine_version,
      config_json,
      config_hash,
      data_hash,
      status,
      error_msg
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ",
    params = list(
      run_id,
      as.POSIXct("2020-01-01 00:00:00", tz = "UTC"),
      "0.1.0",
      "{}",
      "config-hash",
      "data-hash",
      "CREATED",
      NA_character_
    )
  )
}

insert_bars_for_ts <- function(con, instrument_id, ts_utc, close, open = close, high = close, low = close, volume = 1) {
  DBI::dbExecute(
    con,
    "
    INSERT INTO bars (instrument_id, ts_utc, open, high, low, close, volume)
    VALUES (?, ?, ?, ?, ?, ?, ?)
    ",
    params = list(
      instrument_id,
      as.POSIXct(ts_utc, tz = "UTC"),
      as.numeric(open),
      as.numeric(high),
      as.numeric(low),
      as.numeric(close),
      as.numeric(volume)
    )
  )
}

read_equity_curve <- function(con, run_id) {
  df <- DBI::dbGetQuery(
    con,
    "
    SELECT *
    FROM equity_curve
    WHERE run_id = ?
    ORDER BY ts_utc
    ",
    params = list(run_id)
  )
  df$ts_utc <- format(as.POSIXct(df$ts_utc, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  df
}

testthat::test_that("derived state reconstructs positions, cash, and equity_curve deterministically", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  run_id <- "run-derived-1"
  initial_cash <- 1000
  insert_test_run_ds(con, run_id, initial_cash)

  DBI::dbAppendTable(con, "instruments", data.frame(instrument_id = "AAA"))
  insert_bars_for_ts(con, "AAA", "2020-01-02 00:00:00", close = 101)
  insert_bars_for_ts(con, "AAA", "2020-01-03 00:00:00", close = 102)

  fill_buy <- ledgr:::ledgr_fill_next_open(
    desired_qty_delta = 2,
    next_bar = list(instrument_id = "AAA", ts_utc = "2020-01-02T00:00:00Z", open = 100),
    spread_bps = 0,
    commission_fixed = 1
  )
  fill_sell <- ledgr:::ledgr_fill_next_open(
    desired_qty_delta = -1,
    next_bar = list(instrument_id = "AAA", ts_utc = "2020-01-03T00:00:00Z", open = 110),
    spread_bps = 0,
    commission_fixed = 1
  )

  ledgr:::ledgr_write_fill_events(con, run_id, fill_buy, event_seq_start = 1L)
  ledgr:::ledgr_write_fill_events(con, run_id, fill_sell, event_seq_start = 2L)

  before_ledger <- DBI::dbGetQuery(con, "SELECT * FROM ledger_events WHERE run_id = ? ORDER BY event_seq", params = list(run_id))

  ds1 <- ledgr:::ledgr_rebuild_derived_state(con, run_id, initial_cash = initial_cash)
  testthat::expect_true(is.list(ds1))
  testthat::expect_equal(ds1$positions[["AAA"]], 1)

  expected_cash <- initial_cash + (-(2 * 100 + 1)) + (+(1 * 110 - 1))
  testthat::expect_equal(ds1$cash, expected_cash)

  eq1 <- read_equity_curve(con, run_id)
  testthat::expect_equal(nrow(eq1), 2L)
  testthat::expect_identical(eq1$ts_utc, c("2020-01-02T00:00:00Z", "2020-01-03T00:00:00Z"))
  testthat::expect_equal(eq1$equity[[1]], eq1$cash[[1]] + eq1$positions_value[[1]])
  testthat::expect_equal(eq1$equity[[2]], eq1$cash[[2]] + eq1$positions_value[[2]])
  testthat::expect_equal(eq1$positions_value[[2]], 1 * 102)

  ds2 <- ledgr:::ledgr_rebuild_derived_state(con, run_id, initial_cash = initial_cash)
  eq2 <- read_equity_curve(con, run_id)
  testthat::expect_equal(eq2, eq1)
  testthat::expect_equal(ds2$positions[["AAA"]], ds1$positions[["AAA"]])
  testthat::expect_equal(ds2$cash, ds1$cash)

  after_ledger <- DBI::dbGetQuery(con, "SELECT * FROM ledger_events WHERE run_id = ? ORDER BY event_seq", params = list(run_id))
  testthat::expect_equal(after_ledger, before_ledger)
})

testthat::test_that("empty ledger produces empty equity_curve and preserves initial_cash", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  run_id <- "run-derived-empty"
  initial_cash <- 500
  insert_test_run_ds(con, run_id, initial_cash)

  ds <- ledgr:::ledgr_rebuild_derived_state(con, run_id, initial_cash = initial_cash)
  testthat::expect_equal(length(ds$positions), 0L)
  testthat::expect_equal(ds$cash, initial_cash)

  eq <- read_equity_curve(con, run_id)
  testthat::expect_equal(nrow(eq), 0L)
})

testthat::test_that("rebuild failure does not delete existing equity_curve rows", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  run_id <- "run-derived-err"
  initial_cash <- 100
  insert_test_run_ds(con, run_id, initial_cash)

  DBI::dbAppendTable(con, "instruments", data.frame(instrument_id = "AAA"))
  # Intentionally do NOT insert bars for the fill timestamp.

  fill_buy <- ledgr:::ledgr_fill_next_open(
    desired_qty_delta = 1,
    next_bar = list(instrument_id = "AAA", ts_utc = "2020-01-02T00:00:00Z", open = 10),
    spread_bps = 0,
    commission_fixed = 0
  )
  ledgr:::ledgr_write_fill_events(con, run_id, fill_buy, event_seq_start = 1L)

  # Seed an existing derived row to ensure we don't delete it on failure.
  DBI::dbExecute(
    con,
    "
    INSERT INTO equity_curve (run_id, ts_utc, cash, positions_value, equity, realized_pnl, unrealized_pnl)
    VALUES (?, ?, ?, ?, ?, ?, ?)
    ",
    params = list(
      run_id,
      as.POSIXct("2000-01-01 00:00:00", tz = "UTC"),
      1, 0, 1, 0, 0
    )
  )

  testthat::expect_error(
    ledgr:::ledgr_rebuild_derived_state(con, run_id, initial_cash = initial_cash),
    class = "ledgr_missing_bars"
  )

  eq <- read_equity_curve(con, run_id)
  testthat::expect_equal(nrow(eq), 1L)
  testthat::expect_identical(eq$ts_utc[[1]], "2000-01-01T00:00:00Z")
})
