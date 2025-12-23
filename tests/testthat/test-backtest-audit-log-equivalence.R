testthat::test_that("audit_log matches db_live results", {
  n_rows <- 50
  base <- 50000 + cumsum(rep(1, n_rows))
  open <- base
  close <- base + rep(c(-1, 1), length.out = n_rows)
  df <- tibble::tibble(
    instrument_id = "BTC",
    ts_utc = format(
      seq(as.POSIXct("2025-01-01", tz = "UTC"), by = "min", length.out = n_rows),
      "%Y-%m-%dT%H:%M:%SZ"
    ),
    open = open,
    close = close,
    high = pmax(open, close) + 0.1,
    low = pmin(open, close) - 0.1,
    volume = 1000
  )

  snap <- ledgr_snapshot_from_df(df)
  ledgr_snapshot_seal(snap)

  strategy <- function(ctx) {
    if (as.numeric(ctx$bars$close[[1]]) > as.numeric(ctx$bars$open[[1]])) {
      return(c(BTC = 1))
    }
    c(BTC = 0)
  }

  end_ts <- df$ts_utc[[n_rows - 1L]]
  bt_audit <- suppressWarnings(ledgr_backtest(
    snapshot = snap,
    strategy = strategy,
    universe = "BTC",
    end = end_ts,
    execution_mode = "audit_log",
    persist_features = FALSE
  ))
  bt_db <- suppressWarnings(ledgr_backtest(
    snapshot = snap,
    strategy = strategy,
    universe = "BTC",
    end = end_ts,
    execution_mode = "db_live",
    persist_features = FALSE
  ))

  fills_a <- ledgr_extract_fills(bt_audit)
  fills_b <- ledgr_extract_fills(bt_db)
  fills_a <- fills_a[order(fills_a$event_seq), , drop = FALSE]
  fills_b <- fills_b[order(fills_b$event_seq), , drop = FALSE]

  testthat::expect_equal(nrow(fills_a), nrow(fills_b))
  testthat::expect_equal(fills_a$instrument_id, fills_b$instrument_id)
  testthat::expect_equal(fills_a$side, fills_b$side)
  testthat::expect_equal(fills_a$qty, fills_b$qty)
  testthat::expect_equal(fills_a$price, fills_b$price, tolerance = 1e-8)
  testthat::expect_equal(fills_a$fee, fills_b$fee, tolerance = 1e-8)
  testthat::expect_equal(fills_a$ts_utc, fills_b$ts_utc)

  eq_a <- ledgr_compute_equity_curve(bt_audit)
  eq_b <- ledgr_compute_equity_curve(bt_db)
  testthat::expect_equal(eq_a$equity, eq_b$equity, tolerance = 1e-8)
  testthat::expect_equal(eq_a$cash, eq_b$cash, tolerance = 1e-8)
  testthat::expect_equal(eq_a$positions_value, eq_b$positions_value, tolerance = 1e-8)
})
