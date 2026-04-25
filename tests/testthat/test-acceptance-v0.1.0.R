# Acceptance suite for v0.1.0 (Given/When/Then style)

testthat::test_that("AT1: schema initialization creates required tables", {
  db_path <- tempfile(fileext = ".duckdb")
  con <- ledgr_db_init(db_path)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  testthat::expect_error(ledgr_validate_schema(con), NA)
})

testthat::test_that("AT2: run registration stores hashes and reaches DONE", {
  instrument_ids <- c("AAA", "BBB")
  ts_utc <- c("2020-01-01 00:00:00", "2020-01-02 00:00:00", "2020-01-03 00:00:00")
  bars <- ledgr_test_make_bars(instrument_ids, ts_utc)
  db_path <- ledgr_test_make_db(instrument_ids, ts_utc, bars_df = bars, shuffle = TRUE)

  cfg <- list(
    db_path = db_path,
    engine = list(seed = 1L, tz = "UTC"),
    universe = list(instrument_ids = instrument_ids),
    backtest = list(
      start_ts_utc = "2020-01-01T00:00:00Z",
      end_ts_utc = "2020-01-03T00:00:00Z",
      pulse = "EOD",
      initial_cash = 1000
    ),
    fill_model = list(type = "next_open", spread_bps = 0, commission_fixed = 0),
    features = list(enabled = TRUE, defs = list(list(id = "return_1"))),
    strategy = list(id = "hold_zero", params = list())
  )

  run_id <- "at2-run-1"
  out <- ledgr_backtest_run(cfg, run_id = run_id)
  testthat::expect_identical(out$run_id, run_id)

  gc()
  Sys.sleep(0.05)

  h <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(h$con, h$drv), add = TRUE)

  row <- DBI::dbGetQuery(
    h$con,
    "SELECT status, config_json, config_hash, data_hash, error_msg FROM runs WHERE run_id = ?",
    params = list(run_id)
  )
  testthat::expect_equal(nrow(row), 1L)
  testthat::expect_identical(row$status[[1]], "DONE")
  testthat::expect_true(nzchar(row$config_json[[1]]))
  testthat::expect_true(nzchar(row$config_hash[[1]]))
  testthat::expect_true(nzchar(row$data_hash[[1]]))
  testthat::expect_true(is.na(row$error_msg[[1]]))
})

testthat::test_that("AT3: deterministic replay produces identical outputs (excluding run_id/event_id)", {
  instrument_ids <- c("AAA", "BBB")
  ts_utc <- c("2020-01-01 00:00:00", "2020-01-02 00:00:00", "2020-01-03 00:00:00", "2020-01-04 00:00:00")
  bars <- ledgr_test_make_bars(instrument_ids, ts_utc)
  db_path <- ledgr_test_make_db(instrument_ids, ts_utc, bars_df = bars, shuffle = TRUE)

  cfg <- list(
    db_path = db_path,
    engine = list(seed = 1L, tz = "UTC"),
    universe = list(instrument_ids = instrument_ids),
    backtest = list(
      start_ts_utc = "2020-01-01T00:00:00Z",
      end_ts_utc = "2020-01-04T00:00:00Z",
      pulse = "EOD",
      initial_cash = 1000
    ),
    fill_model = list(type = "next_open", spread_bps = 5, commission_fixed = 1),
    features = list(enabled = TRUE, defs = list(list(id = "return_1"), list(id = "sma_2"))),
    strategy = list(id = "echo", params = list(targets = c(AAA = 1, BBB = 2)))
  )

  run_a <- "at3-a"
  run_b <- "at3-b"
  out_a <- ledgr_backtest_run(cfg, run_id = run_a)
  out_b <- ledgr_backtest_run(cfg, run_id = run_b)
  testthat::expect_identical(out_a$run_id, run_a)
  testthat::expect_identical(out_b$run_id, run_b)

  gc()
  Sys.sleep(0.05)

  h <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(h$con, h$drv), add = TRUE)

  run_rows <- DBI::dbGetQuery(
    h$con,
    "
    SELECT run_id, status, error_msg
    FROM runs
    WHERE run_id IN (?, ?)
    ORDER BY run_id
    ",
    params = list(run_a, run_b)
  )
  testthat::expect_equal(run_rows$run_id, c(run_a, run_b))
  testthat::expect_identical(run_rows$status, c("DONE", "DONE"))
  testthat::expect_true(all(is.na(run_rows$error_msg)))

  ledger_a <- ledgr_test_fetch_ledger_core(h$con, run_a)
  ledger_b <- ledgr_test_fetch_ledger_core(h$con, run_b)
  testthat::expect_gt(nrow(ledger_b), 0L)
  testthat::expect_equal(ledger_a, ledger_b)

  feat_a <- ledgr_test_fetch_features_core(h$con, run_a)
  feat_b <- ledgr_test_fetch_features_core(h$con, run_b)
  testthat::expect_gt(nrow(feat_b), 0L)
  testthat::expect_equal(feat_a, feat_b)

  eq_a <- ledgr_test_fetch_equity_curve_core(h$con, run_a)
  eq_b <- ledgr_test_fetch_equity_curve_core(h$con, run_b)
  testthat::expect_gt(nrow(eq_b), 0L)
  testthat::expect_equal(eq_a, eq_b)
})

testthat::test_that("AT4: no-lookahead holds for built-in features", {
  bars <- ledgr_test_make_bars(c("AAA"), c(
    "2020-01-01 00:00:00",
    "2020-01-02 00:00:00",
    "2020-01-03 00:00:00",
    "2020-01-04 00:00:00"
  ))
  bars <- bars[order(bars$ts_utc), , drop = FALSE]

  testthat::expect_error(
    ledgr:::ledgr_check_no_lookahead(ledgr:::ledgr_feature_sma_n(2L), bars, horizons = c(1L, 2L)),
    NA
  )
  testthat::expect_error(
    ledgr:::ledgr_check_no_lookahead(ledgr:::ledgr_feature_return_1(), bars, horizons = c(1L, 2L)),
    NA
  )
})

testthat::test_that("AT5/AT6/AT7: ledger-derived state satisfies accounting identities and monotone time", {
  instrument_ids <- c("AAA")
  ts_utc <- c("2020-01-01 00:00:00", "2020-01-02 00:00:00", "2020-01-03 00:00:00")
  bars <- ledgr_test_make_bars(instrument_ids, ts_utc)
  db_path <- ledgr_test_make_db(instrument_ids, ts_utc, bars_df = bars, shuffle = TRUE)

  cfg <- list(
    db_path = db_path,
    engine = list(seed = 1L, tz = "UTC"),
    universe = list(instrument_ids = instrument_ids),
    backtest = list(
      start_ts_utc = "2020-01-01T00:00:00Z",
      end_ts_utc = "2020-01-03T00:00:00Z",
      pulse = "EOD",
      initial_cash = 1000
    ),
    fill_model = list(type = "next_open", spread_bps = 0, commission_fixed = 0),
    features = list(enabled = FALSE, defs = list()),
    strategy = list(id = "echo", params = list(targets = c(AAA = 1)))
  )

  run_id <- "at6-run-1"
  ledgr_backtest_run(cfg, run_id = run_id)

  gc()
  Sys.sleep(0.05)

  h <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(h$con, h$drv), add = TRUE)

  eq <- ledgr_test_fetch_equity_curve_core(h$con, run_id)
  testthat::expect_equal(nrow(eq), length(ts_utc))
  testthat::expect_identical(eq$ts_utc, c("2020-01-01T00:00:00Z", "2020-01-02T00:00:00Z", "2020-01-03T00:00:00Z"))

  reconstructed <- ledgr_state_reconstruct(run_id, h$con)
  testthat::expect_true(is.list(reconstructed))
  testthat::expect_true(all(c("positions", "cash", "pnl", "equity_curve") %in% names(reconstructed)))
  testthat::expect_equal(reconstructed$equity_curve, eq)

  testthat::expect_true(all(diff(as.POSIXct(eq$ts_utc, tz = "UTC")) > 0))

  testthat::expect_true(all.equal(eq$equity, eq$cash + eq$positions_value, tolerance = 1e-10))

  meta <- DBI::dbGetQuery(
    h$con,
    "SELECT meta_json, instrument_id FROM ledger_events WHERE run_id = ? ORDER BY event_seq",
    params = list(run_id)
  )
  if (nrow(meta) > 0) {
    pos_by_id <- numeric(0)
    cash_delta_sum <- 0
    for (i in seq_len(nrow(meta))) {
      m <- jsonlite::fromJSON(meta$meta_json[[i]], simplifyVector = FALSE)
      cash_delta_sum <- cash_delta_sum + as.numeric(m$cash_delta)
      id <- meta$instrument_id[[i]]
      if (!is.na(id) && nzchar(id)) {
        if (is.null(names(pos_by_id)) || !(id %in% names(pos_by_id))) pos_by_id[id] <- 0
        pos_by_id[id] <- pos_by_id[id] + as.numeric(m$position_delta)
      }
    }
    testthat::expect_equal(eq$cash[[nrow(eq)]], 1000 + cash_delta_sum)
    testthat::expect_equal(pos_by_id[["AAA"]], 1)
  }
})

testthat::test_that("AT8: resume deletes tails and final outputs match a clean run", {
  instrument_ids <- c("AAA")
  ts_utc <- c("2020-01-01 00:00:00", "2020-01-02 00:00:00", "2020-01-03 00:00:00", "2020-01-04 00:00:00")
  bars <- ledgr_test_make_bars(instrument_ids, ts_utc)

  db_resume <- ledgr_test_make_db(instrument_ids, ts_utc, bars_df = bars, shuffle = TRUE)
  cfg <- list(
    db_path = db_resume,
    engine = list(seed = 1L, tz = "UTC"),
    universe = list(instrument_ids = instrument_ids),
    backtest = list(
      start_ts_utc = "2020-01-01T00:00:00Z",
      end_ts_utc = "2020-01-04T00:00:00Z",
      pulse = "EOD",
      initial_cash = 1000
    ),
    fill_model = list(type = "next_open", spread_bps = 0, commission_fixed = 0),
    features = list(enabled = TRUE, defs = list(list(id = "sma_2"))),
    strategy = list(id = "state_prev", params = list())
  )

  run_id <- "at8-run-1"
  ledgr:::ledgr_backtest_run_internal(cfg, run_id = run_id, control = list(max_pulses = 1L))
  gc()
  Sys.sleep(0.05)
  testthat::expect_warning(ledgr_backtest_run(cfg, run_id = run_id), "LEDGR_LAST_BAR_NO_FILL", fixed = TRUE)

  gc()
  Sys.sleep(0.05)

  h1 <- ledgr_test_open_duckdb(db_resume)
  on.exit(ledgr_test_close_duckdb(h1$con, h1$drv), add = TRUE)

  seqs <- DBI::dbGetQuery(h1$con, "SELECT event_seq FROM ledger_events WHERE run_id = ? ORDER BY event_seq", params = list(run_id))$event_seq
  testthat::expect_identical(as.integer(seqs), seq_along(seqs))

  ledger_resume <- ledgr_test_fetch_ledger_core(h1$con, run_id)
  feat_resume <- ledgr_test_fetch_features_core(h1$con, run_id)
  eq_resume <- ledgr_test_fetch_equity_curve_core(h1$con, run_id)
  st_resume <- DBI::dbGetQuery(
    h1$con,
    "SELECT ts_utc, state_json FROM strategy_state WHERE run_id = ? ORDER BY ts_utc",
    params = list(run_id)
  )

  db_clean <- ledgr_test_make_db(instrument_ids, ts_utc, bars_df = bars, shuffle = TRUE)
  cfg_clean <- cfg
  cfg_clean$db_path <- db_clean
  testthat::expect_warning(ledgr_backtest_run(cfg_clean, run_id = run_id), "LEDGR_LAST_BAR_NO_FILL", fixed = TRUE)

  gc()
  Sys.sleep(0.05)

  h2 <- ledgr_test_open_duckdb(db_clean)
  on.exit(ledgr_test_close_duckdb(h2$con, h2$drv), add = TRUE)

  ledger_clean <- ledgr_test_fetch_ledger_core(h2$con, run_id)
  feat_clean <- ledgr_test_fetch_features_core(h2$con, run_id)
  eq_clean <- ledgr_test_fetch_equity_curve_core(h2$con, run_id)
  st_clean <- DBI::dbGetQuery(
    h2$con,
    "SELECT ts_utc, state_json FROM strategy_state WHERE run_id = ? ORDER BY ts_utc",
    params = list(run_id)
  )

  testthat::expect_equal(ledger_resume, ledger_clean)
  testthat::expect_equal(feat_resume, feat_clean)
  testthat::expect_equal(eq_resume, eq_clean)
  testthat::expect_equal(st_resume, st_clean)
})

testthat::test_that("last-bar policy warns and produces no fill event", {
  instrument_ids <- c("AAA")
  ts_utc <- c("2020-01-01 00:00:00", "2020-01-02 00:00:00")
  bars <- ledgr_test_make_bars(instrument_ids, ts_utc)
  db_path <- ledgr_test_make_db(instrument_ids, ts_utc, bars_df = bars, shuffle = TRUE)

  cfg <- list(
    db_path = db_path,
    engine = list(seed = 1L, tz = "UTC"),
    universe = list(instrument_ids = instrument_ids),
    backtest = list(
      start_ts_utc = "2020-01-01T00:00:00Z",
      end_ts_utc = "2020-01-02T00:00:00Z",
      pulse = "EOD",
      initial_cash = 1000
    ),
    fill_model = list(type = "next_open", spread_bps = 0, commission_fixed = 0),
    features = list(enabled = FALSE, defs = list()),
    strategy = list(
      id = "ts_rule",
      params = list(
        cutover_ts_utc = "2020-01-02T00:00:00Z",
        targets_before = c(AAA = 0),
        targets_after = c(AAA = 1)
      )
    )
  )

  run_id <- "lastbar-1"
  testthat::expect_warning(
    ledgr_backtest_run(cfg, run_id = run_id),
    "LEDGR_LAST_BAR_NO_FILL",
    fixed = TRUE
  )

  gc()
  Sys.sleep(0.05)

  h <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(h$con, h$drv), add = TRUE)

  n <- DBI::dbGetQuery(h$con, "SELECT COUNT(*) AS n FROM ledger_events WHERE run_id = ?", params = list(run_id))$n[[1]]
  testthat::expect_identical(n, 0)
})

testthat::test_that("AT12: OHLC violation fails loud and run is marked FAILED", {
  instrument_ids <- c("AAA")
  ts_utc <- c("2020-01-01 00:00:00", "2020-01-02 00:00:00", "2020-01-03 00:00:00")
  bars <- ledgr_test_make_bars(instrument_ids, ts_utc)
  bars$high[[2]] <- bars$low[[2]] - 1

  db_path <- ledgr_test_make_db(instrument_ids, ts_utc, bars_df = bars, shuffle = TRUE)
  cfg <- list(
    db_path = db_path,
    engine = list(seed = 1L, tz = "UTC"),
    universe = list(instrument_ids = instrument_ids),
    backtest = list(
      start_ts_utc = "2020-01-01T00:00:00Z",
      end_ts_utc = "2020-01-03T00:00:00Z",
      pulse = "EOD",
      initial_cash = 1000
    ),
    fill_model = list(type = "next_open", spread_bps = 0, commission_fixed = 0),
    features = list(enabled = FALSE, defs = list()),
    strategy = list(id = "hold_zero", params = list())
  )

  run_id <- "at12-bad-bars"
  testthat::expect_error(ledgr_backtest_run(cfg, run_id = run_id))

  gc()
  Sys.sleep(0.05)
  h <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(h$con, h$drv), add = TRUE)

  row <- DBI::dbGetQuery(h$con, "SELECT status, error_msg FROM runs WHERE run_id = ?", params = list(run_id))
  testthat::expect_equal(nrow(row), 1L)
  testthat::expect_identical(row$status[[1]], "FAILED")
  testthat::expect_true(nzchar(row$error_msg[[1]]))
})
