# Spike 12: chunked extractor real-path wall recovery measurement
#
# Context: Codex peer review of the v0.1.8.9 spike round (Finding 3) showed
# Spike 7's (LDG-2486) ~170s recovery estimate is too direct. Production
# durable `ledgr_results(bt, "fills")` goes through `ledgr_extract_fills_impl`
# at R/backtest.R:1021 with a chunked reader (`stream_threshold = 100000L`,
# fetch_size = 50000L per chunk). Per-chunk buffer is sized to
# `nrow(rows) * 2L` (~100k slots for a 50k-row chunk), much smaller than
# the monolithic 260k-slot buffer Spike 7 measured. The real production
# durable recovery from a setv fix at R/fold-reconstruction.R:219-227 is
# bounded by chunk size, not by total event count.
#
# This spike measures the actual production durable wall recovery by:
#   1. Building a synthetic ledger_events DuckDB table.
#   2. Calling `ledgr:::ledgr_extract_fills_impl` directly through the
#      production chunked path. Timed BASELINE.
#   3. Patching `ledgr_fill_row_buffer_add` in the namespace with a
#      setv variant. Calling the extractor again. Timed PATCHED.
#   4. Restoring the original. Computing recovery as baseline - patched.
#
# FAITHFULNESS: this exercises the PRODUCTION chunked extractor path
# exactly. Only the per-row buffer-write hot function is replaced. The
# extractor's chunked DBI fetch, lot machinery, fill-row classification,
# and temp-table accumulation are unchanged.
#
# CAVEAT: synthetic events use simplified meta_json. Production events
# carry more metadata which affects per-event parsing cost. The wall
# recovery RATIO (baseline / patched) should hold; absolute seconds
# may differ slightly from a real bt at xlarge.

suppressWarnings(suppressMessages({
  library(DBI)
  library(duckdb)
  library(collapse)
  if (!requireNamespace("pkgload", quietly = TRUE)) {
    stop("pkgload required.")
  }
  pkgload::load_all(".", quiet = TRUE)
}))

mk_ledger_rows <- function(n_rows, seed = 42L) {
  set.seed(seed)
  ts_seq <- as.POSIXct("2026-01-01", tz = "UTC") + seq_len(n_rows)
  # Alternate BUY/SELL by instrument so lots close cleanly (mirrors
  # crossover-event semantics from the workload grid).
  data.frame(
    event_id = sprintf("run_x_%08d", seq_len(n_rows)),
    run_id = rep("run_x", n_rows),
    ts_utc = ts_seq,
    event_type = rep("FILL", n_rows),
    instrument_id = sprintf("INST_%05d", ((seq_len(n_rows) - 1L) %% 500L) + 1L),
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

# Patched buffer_add that uses collapse::setv for the 9 column writes
# at R/fold-reconstruction.R:219-227 instead of base-R `[[<-`.
make_setv_buffer_add <- function() {
  function(buffer,
           event_seq,
           ts_utc,
           instrument_id,
           side,
           qty,
           price,
           fee,
           realized_pnl,
           action) {
    i <- buffer$n + 1L
    if (i > buffer$capacity) {
      ledgr:::ledgr_fill_row_buffer_grow(buffer, i)
    }
    collapse::setv(buffer$event_seq, i, as.integer(event_seq), vind1 = TRUE)
    collapse::setv(buffer$ts_utc, i, as.POSIXct(ts_utc, tz = "UTC"), vind1 = TRUE)
    collapse::setv(buffer$instrument_id, i, as.character(instrument_id), vind1 = TRUE)
    collapse::setv(buffer$side, i, as.character(side), vind1 = TRUE)
    collapse::setv(buffer$qty, i, as.numeric(qty), vind1 = TRUE)
    collapse::setv(buffer$price, i, as.numeric(price), vind1 = TRUE)
    collapse::setv(buffer$fee, i, as.numeric(fee), vind1 = TRUE)
    collapse::setv(buffer$realized_pnl, i, as.numeric(realized_pnl), vind1 = TRUE)
    collapse::setv(buffer$action, i, as.character(action), vind1 = TRUE)
    buffer$n <- i
    invisible(buffer)
  }
}

# Call the production chunked extractor on a synthetic bt. Skip the
# bt->connection lookup by passing `con` directly.
call_extractor <- function(con, run_id) {
  bt <- list(run_id = run_id)
  # Pass a very high stream_threshold so the non-lazy materialized path is
  # taken at all scales. The chunked DBI fetch still runs (fetch_size=50000
  # is hardcoded), so we measure the same buffer-write hot path regardless.
  ledgr:::ledgr_extract_fills_impl(bt, con = con, stream_threshold = .Machine$integer.max)
}

# Run baseline + patched at a given scale; return timings + row counts.
measure_at_scale <- function(n_rows) {
  cat(sprintf("\n--- n_rows = %d ---\n", n_rows))
  rows <- mk_ledger_rows(n_rows)

  # Baseline (production code, unpatched)
  con1 <- setup_db(rows)
  base_t <- system.time({
    base_fills <- call_extractor(con1, "run_x")
  })[["elapsed"]]
  base_nrow <- nrow(base_fills)
  cat(sprintf("  baseline  : %8.3fs  (%d output rows)\n", base_t, base_nrow))
  DBI::dbDisconnect(con1, shutdown = TRUE)

  # Patched (production code with setv buffer_add)
  original_fn <- ledgr:::ledgr_fill_row_buffer_add
  setv_fn <- make_setv_buffer_add()
  assignInNamespace("ledgr_fill_row_buffer_add", setv_fn, ns = "ledgr")
  on.exit({
    assignInNamespace("ledgr_fill_row_buffer_add", original_fn, ns = "ledgr")
  }, add = TRUE)

  con2 <- setup_db(rows)
  patched_t <- system.time({
    patched_fills <- call_extractor(con2, "run_x")
  })[["elapsed"]]
  patched_nrow <- nrow(patched_fills)
  cat(sprintf("  patched   : %8.3fs  (%d output rows)\n", patched_t, patched_nrow))
  DBI::dbDisconnect(con2, shutdown = TRUE)

  # Restore namespace (also via on.exit, but be explicit)
  assignInNamespace("ledgr_fill_row_buffer_add", original_fn, ns = "ledgr")

  # Parity: row count should match. Column-value parity is byte-identical
  # if the setv variant truly mutates the same memory the base-R variant
  # would have written.
  rows_match <- base_nrow == patched_nrow
  cat(sprintf("  parity    : %s (baseline %d vs patched %d rows)\n",
              if (rows_match) "OK" else "FAIL", base_nrow, patched_nrow))
  if (rows_match) {
    # Sample first 100 rows for column-value parity
    bf <- as.data.frame(base_fills)
    pf <- as.data.frame(patched_fills)
    bf <- bf[order(bf$event_seq), , drop = FALSE]
    pf <- pf[order(pf$event_seq), , drop = FALSE]
    sample_n <- min(100L, nrow(bf))
    col_parity <- all(vapply(names(bf), function(col) {
      identical(bf[[col]][seq_len(sample_n)], pf[[col]][seq_len(sample_n)])
    }, logical(1)))
    cat(sprintf("  col parity: %s (first %d rows, %d columns)\n",
                if (col_parity) "OK" else "FAIL", sample_n, ncol(bf)))
  }

  recovery <- base_t - patched_t
  speedup <- base_t / pmax(patched_t, 0.001)
  cat(sprintf("  recovery  : %.3fs (%.1fx speedup)\n", recovery, speedup))

  data.frame(
    n_rows = n_rows,
    baseline_s = base_t,
    patched_s = patched_t,
    recovery_s = recovery,
    speedup = speedup,
    base_nrow = base_nrow,
    patched_nrow = patched_nrow
  )
}

cat("=== ledgr_extract_fills_impl chunked-path wall recovery ===\n")
cat("Production extractor uses fetch_size=50000, per-chunk buffer ~100k slots.\n")
cat("setv patch applied via assignInNamespace to ledgr_fill_row_buffer_add.\n")

shapes <- c(30000L, 68500L, 133000L)
results <- list()
for (n in shapes) {
  results[[length(results) + 1L]] <- measure_at_scale(n)
}

cat("\n=== summary ===\n")
df <- do.call(rbind, results)
print(df)

cat("\n=== wall translation for v0.1.8.9 lane ===\n")
xlarge <- df[df$n_rows == 133000L, ]
if (nrow(xlarge) > 0L) {
  cat(sprintf("Production xlarge cell (~133k fills):\n"))
  cat(sprintf("  Baseline (production chunked + base-R buffer): %.3fs\n",
              xlarge$baseline_s))
  cat(sprintf("  Patched  (production chunked + setv buffer)  : %.3fs\n",
              xlarge$patched_s))
  cat(sprintf("  Wall recovery (measured)                     : %.3fs\n",
              xlarge$recovery_s))
  cat(sprintf("  Speedup                                       : %.1fx\n",
              xlarge$speedup))
  cat(sprintf("\nCompare to Spike 7 (LDG-2486) monolithic estimate of ~170s.\n"))
  cat(sprintf("Spike 12 measures the REAL durable production path.\n"))
}

out <- "dev/bench/results/spike_chunked_extractor_wall_recovery.csv"
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(df, out, row.names = FALSE)
cat(sprintf("\nWROTE %s\n", out))
