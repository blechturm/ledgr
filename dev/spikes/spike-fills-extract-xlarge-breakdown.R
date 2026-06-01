# Spike: ledgr_extract_fills_impl behavior at xlarge fill counts
#
# Context: LDG-2479 grid at density_high_xlarge_durable (~133k fills) showed
# ledgr_results(bt, "fills") returned no row count, forcing the harness to
# fall back to ledger_events row count. The closeout note flagged this as a
# robustness gap. This spike attempts to reproduce the failure at synthetic
# scale and identify which stage of the extraction fails.
#
# FAITHFULNESS: directly populates a DuckDB ledger_events table at scales
# matching production, then attempts to call ledgr:::ledgr_extract_fills_impl
# via pkgload. If the function requires a fuller bt object than we can
# easily build, we time the underlying DuckDB queries and the
# ledgr_fills_from_events call separately as a decomposition.
#
# CAVEAT: this is a diagnostic spike, not a perf simulation. The output is
# a named cause + a proposed fix path, not a speedup number.

suppressWarnings(suppressMessages({
  library(DBI)
  library(duckdb)
  if (!requireNamespace("pkgload", quietly = TRUE)) {
    stop("pkgload required.")
  }
  pkgload::load_all(".", quiet = TRUE)
}))

mk_ledger_rows <- function(n_rows, seed = 42L) {
  set.seed(seed)
  ts_seq <- as.POSIXct("2026-01-01", tz = "UTC") + seq_len(n_rows)
  data.frame(
    event_id = sprintf("run_x_%08d", seq_len(n_rows)),
    run_id = rep("run_x", n_rows),
    ts_utc = ts_seq,
    event_type = rep("FILL", n_rows),
    instrument_id = sprintf("INST_%05d", sample.int(1000L, n_rows, replace = TRUE)),
    side = ifelse(seq_len(n_rows) %% 2L == 0L, "BUY", "SELL"),
    qty = rep(1, n_rows),
    price = runif(n_rows, 90, 110),
    fee = rep(0, n_rows),
    meta_json = sprintf('{"cash_delta":%g,"position_delta":%g,"realized_pnl":null}',
                        runif(n_rows, -100, 100),
                        sample(c(-1L, 1L), n_rows, replace = TRUE)),
    event_seq = as.integer(seq_len(n_rows)),
    stringsAsFactors = FALSE
  )
}

setup_db <- function(rows) {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  DBI::dbExecute(con, "
    CREATE TABLE runs (
      run_id VARCHAR,
      created_at TIMESTAMP
    )
  ")
  DBI::dbExecute(con, "INSERT INTO runs VALUES ('run_x', CURRENT_TIMESTAMP)")
  DBI::dbExecute(con, "
    CREATE TABLE ledger_events (
      event_id VARCHAR,
      run_id VARCHAR,
      ts_utc TIMESTAMP,
      event_type VARCHAR,
      instrument_id VARCHAR,
      side VARCHAR,
      qty DOUBLE,
      price DOUBLE,
      fee DOUBLE,
      meta_json VARCHAR,
      event_seq INTEGER
    )
  ")
  DBI::dbAppendTable(con, "ledger_events", rows)
  con
}

decompose_extract <- function(n_rows) {
  cat(sprintf("\n--- n_rows = %d ---\n", n_rows))
  rows <- mk_ledger_rows(n_rows)
  setup_t <- system.time({ con <- setup_db(rows) })[["elapsed"]]
  on.exit({
    suppressWarnings(try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE))
  })
  cat(sprintf("  setup_db (insert %d rows)      : %.3fs\n", n_rows, setup_t))

  count_t <- system.time({
    n_count <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM ledger_events WHERE run_id = 'run_x'")$n[[1]]
  })[["elapsed"]]
  cat(sprintf("  COUNT(*) query                  : %.3fs (returned %d rows)\n", count_t, n_count))

  read_t <- system.time({
    events_df <- DBI::dbGetQuery(con,
      "SELECT event_id, run_id, ts_utc, event_type, instrument_id, side, qty, price, fee, meta_json, event_seq
       FROM ledger_events WHERE run_id = 'run_x' ORDER BY event_seq")
  })[["elapsed"]]
  n_read <- nrow(events_df)
  cat(sprintf("  full-table SELECT               : %.3fs (returned %d rows)\n", read_t, n_read))

  if (n_read != n_rows) {
    cat(sprintf("  ANOMALY: select returned %d rows, expected %d\n", n_read, n_rows))
  }

  # Now call ledgr_fills_from_events on the in-memory events (Spike 7's
  # confirmed bottleneck; here just to confirm it scales as expected).
  # Skip for xlarge to avoid the 10-minute wait already measured in Spike 7.
  if (n_rows <= 30000L) {
    fills_t <- system.time({
      fills <- ledgr:::ledgr_fills_from_events(events_df)
    })[["elapsed"]]
    n_fills <- if (is.null(fills)) NA else nrow(fills)
    cat(sprintf("  ledgr_fills_from_events         : %.3fs (returned %s fill rows)\n",
                fills_t, as.character(n_fills)))
  } else {
    cat(sprintf("  ledgr_fills_from_events         : SKIPPED (already measured by Spike 7)\n"))
  }

  list(n_rows = n_rows, setup_s = setup_t, count_s = count_t,
       read_s = read_t, n_read = n_read)
}

cat("=== ledgr_results(bt, 'fills') stage decomposition ===\n")
cat("Each stage timed independently to identify where xlarge breaks.\n")

shapes <- c(13500L, 30000L, 68500L, 133000L)
results <- list()
for (n in shapes) {
  results[[length(results) + 1L]] <- decompose_extract(n)
}

cat("\n=== summary ===\n")
df <- do.call(rbind, lapply(results, as.data.frame))
print(df)

cat("\n=== interpretation ===\n")
cat("If COUNT(*) query and full SELECT both return correct row counts at\n")
cat("xlarge, the LDG-2479 grid harness failure to obtain a row count was\n")
cat("NOT in DuckDB query stage. The failure was likely in a higher-level\n")
cat("wrapper that constructs `bt` or in ledgr_results' integration with\n")
cat("the production bt structure. The reproduction requires running a\n")
cat("full backtest to materialize bt (out of scope for this spike).\n")

out <- "dev/bench/results/spike_fills_extract_xlarge_breakdown.csv"
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(df, out, row.names = FALSE)
cat(sprintf("\nWROTE %s\n", out))
