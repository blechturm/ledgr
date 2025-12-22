ledgr_test_open_duckdb <- function(db_path, attempts = 50L, sleep_s = 0.05) {
  attempts <- as.integer(attempts)
  if (attempts < 1L) attempts <- 1L

  last_err <- NULL
  for (i in seq_len(attempts)) {
    drv <- duckdb::duckdb()
    out <- tryCatch(
      {
        con <- DBI::dbConnect(drv, dbdir = db_path)
        list(con = con, drv = drv)
      },
      error = function(e) {
        last_err <<- e
        try(duckdb::duckdb_shutdown(drv), silent = TRUE)
        NULL
      }
    )
    if (!is.null(out)) return(out)
    gc()
    Sys.sleep(sleep_s)
  }
  stop(last_err)
}

ledgr_test_close_duckdb <- function(con, drv) {
  suppressWarnings(try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE))
  suppressWarnings(try(duckdb::duckdb_shutdown(drv), silent = TRUE))
  invisible(TRUE)
}

fixture_path <- testthat::test_path("fixtures", "test_bars.R")
if (file.exists(fixture_path)) {
  source(fixture_path, local = TRUE)
}

test_strategy <- function(ctx) {
  c(TEST_A = 100, TEST_B = 50)
}

get_test_connection <- function(db_path = tempfile(fileext = ".duckdb")) {
  opened <- ledgr_test_open_duckdb(db_path)
  con <- opened$con
  drv <- opened$drv
  attr(con, "ledgr_duckdb_drv") <- drv

  ledgr_create_schema(con)
  ledgr_validate_schema(con)

  list(con = con, drv = drv, db_path = db_path)
}

close_test_connection <- function(test_con) {
  if (is.list(test_con) && !is.null(test_con$con) && !is.null(test_con$drv)) {
    ledgr_test_close_duckdb(test_con$con, test_con$drv)
  }
  invisible(TRUE)
}

get_ledger_events <- function(con, run_id) {
  DBI::dbGetQuery(
    con,
    "
    SELECT event_seq, ts_utc, event_type, instrument_id, side, qty, price, fee, meta_json
    FROM ledger_events
    WHERE run_id = ?
    ORDER BY event_seq
    ",
    params = list(run_id)
  )
}

get_final_equity <- function(con, run_id) {
  df <- DBI::dbGetQuery(
    con,
    "
    SELECT equity
    FROM equity_curve
    WHERE run_id = ?
    ORDER BY ts_utc DESC
    LIMIT 1
    ",
    params = list(run_id)
  )
  if (nrow(df) < 1) return(NA_real_)
  as.numeric(df$equity[[1]])
}

ledgr_test_make_db <- function(instrument_ids, ts_utc, bars_df, shuffle = FALSE) {
  db_path <- tempfile(fileext = ".duckdb")

  drv <- duckdb::duckdb()
  con <- DBI::dbConnect(drv, dbdir = db_path)
  on.exit(ledgr_test_close_duckdb(con, drv), add = TRUE)

  ledgr_create_schema(con)
  DBI::dbAppendTable(con, "instruments", data.frame(instrument_id = instrument_ids, stringsAsFactors = FALSE))

  if (isTRUE(shuffle)) {
    bars_df <- bars_df[sample.int(nrow(bars_df)), , drop = FALSE]
  }
  DBI::dbAppendTable(con, "bars", bars_df)

  db_path
}

ledgr_test_make_bars <- function(instrument_ids, ts_utc) {
  ts <- as.POSIXct(ts_utc, tz = "UTC")
  out <- do.call(
    rbind,
    lapply(seq_along(instrument_ids), function(i) {
      instrument_id <- instrument_ids[[i]]
      base <- 100 + i * 10
      n <- length(ts)
      data.frame(
        instrument_id = instrument_id,
        ts_utc = ts,
        open = base + seq_len(n) * 1,
        high = base + seq_len(n) * 1,
        low = base + seq_len(n) * 1,
        close = base + seq_len(n) * 1,
        volume = rep(1, n),
        stringsAsFactors = FALSE
      )
    })
  )
  out
}

ledgr_test_norm_ts <- function(x) {
  format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

ledgr_test_fetch_ledger_core <- function(con, run_id) {
  df <- DBI::dbGetQuery(
    con,
    "
    SELECT ts_utc, instrument_id, side, qty, price, fee, meta_json, event_seq
    FROM ledger_events
    WHERE run_id = ?
    ORDER BY ts_utc, instrument_id, side, qty, price, fee, meta_json, event_seq
    ",
    params = list(run_id)
  )
  if (nrow(df) == 0) return(df)
  df$ts_utc <- ledgr_test_norm_ts(df$ts_utc)
  df
}

ledgr_test_fetch_features_core <- function(con, run_id) {
  df <- DBI::dbGetQuery(
    con,
    "
    SELECT ts_utc, instrument_id, feature_name, feature_value
    FROM features
    WHERE run_id = ?
    ORDER BY ts_utc, instrument_id, feature_name
    ",
    params = list(run_id)
  )
  if (nrow(df) == 0) return(df)
  df$ts_utc <- ledgr_test_norm_ts(df$ts_utc)
  df$feature_value <- as.numeric(df$feature_value)
  df
}

ledgr_test_fetch_equity_curve_core <- function(con, run_id) {
  df <- DBI::dbGetQuery(
    con,
    "
    SELECT ts_utc, cash, positions_value, equity, realized_pnl, unrealized_pnl
    FROM equity_curve
    WHERE run_id = ?
    ORDER BY ts_utc
    ",
    params = list(run_id)
  )
  if (nrow(df) == 0) return(df)
  df$ts_utc <- ledgr_test_norm_ts(df$ts_utc)
  df
}

