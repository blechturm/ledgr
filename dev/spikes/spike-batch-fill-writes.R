# Spike: per-row DuckDB INSERT vs batched/transactioned writes
#
# Context: R/ledger-writer.R:ledgr_write_fill_events uses DBI::dbExecute per
# fill plus an optional dbWithTransaction wrapper, called from
# R/fold-engine.R:336-340 inside the per-fill loop. LDG-2479 grid showed
# ledgr_results(bt, "fills") extraction is super-linear, BUT the WRITE side
# of the durable handler is also per-fill: 68k+ DBI::dbExecute calls. The
# v0.1.8.9 inventory's B1 lane is to batch these.
#
# FAITHFULNESS: replicates the ledger_events DuckDB schema (11 columns)
# from inst/schema/ and the per-row DBI::dbExecute pattern from
# R/ledger-writer.R. A fixed pre-built row payload is reused so the spike
# times the DB WRITE PATH only, not payload construction (canonical_json,
# ts conversion, validation are separate lanes). The "current" variant
# matches the production write call: per-row DBI::dbExecute with
# parameterized INSERT.
#
# Variants:
#   per_row        : DBI::dbExecute one INSERT per row, no explicit txn
#                    (DuckDB default: implicit per-row commit)
#   per_row_tx     : same as per_row but wrapped in ONE dbWithTransaction
#                    around the whole batch (no per-row commit)
#   batched_10     : dbAppendTable with chunks of 10 rows
#   batched_100    : ditto, chunks of 100
#   batched_1000   : ditto, chunks of 1000
#   batched_10000  : ditto, chunks of 10000
#
# CAVEAT: in-memory DuckDB (":memory:") is faster than disk-backed; absolute
# seconds underestimate production. The RELATIVE speedup between variants
# and the per-fill cost knee are the load-bearing claims.
#
# Usage:
#   Rscript dev/spikes/spike-batch-fill-writes.R

suppressWarnings(suppressMessages({
  library(DBI)
  library(duckdb)
}))

mk_con <- function() {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
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
  con
}

mk_row_payload <- function(i) {
  list(
    event_id = sprintf("run_x_%08d", i),
    run_id = "run_x",
    ts_utc = as.POSIXct("2026-01-01", tz = "UTC") + i,
    event_type = "FILL",
    instrument_id = sprintf("INST_%05d", (i %% 1000L) + 1L),
    side = if (i %% 2L == 0L) "BUY" else "SELL",
    qty = 1,
    price = 100,
    fee = 0,
    meta_json = '{"cash_delta":-100,"position_delta":1,"realized_pnl":null}',
    event_seq = i
  )
}

mk_row_df <- function(start_i, n) {
  i_seq <- seq.int(start_i, length.out = n)
  data.frame(
    event_id = sprintf("run_x_%08d", i_seq),
    run_id = rep("run_x", n),
    ts_utc = as.POSIXct("2026-01-01", tz = "UTC") + i_seq,
    event_type = rep("FILL", n),
    instrument_id = sprintf("INST_%05d", (i_seq %% 1000L) + 1L),
    side = ifelse(i_seq %% 2L == 0L, "BUY", "SELL"),
    qty = rep(1, n),
    price = rep(100, n),
    fee = rep(0, n),
    meta_json = rep('{"cash_delta":-100,"position_delta":1,"realized_pnl":null}', n),
    event_seq = as.integer(i_seq),
    stringsAsFactors = FALSE
  )
}

write_per_row <- function(con, n) {
  ins_sql <- "
    INSERT INTO ledger_events
    (event_id, run_id, ts_utc, event_type, instrument_id, side, qty, price, fee, meta_json, event_seq)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  "
  for (i in seq_len(n)) {
    row <- mk_row_payload(i)
    DBI::dbExecute(con, ins_sql, params = list(
      row$event_id, row$run_id, row$ts_utc, row$event_type, row$instrument_id,
      row$side, row$qty, row$price, row$fee, row$meta_json, row$event_seq
    ))
  }
}

write_per_row_tx <- function(con, n) {
  ins_sql <- "
    INSERT INTO ledger_events
    (event_id, run_id, ts_utc, event_type, instrument_id, side, qty, price, fee, meta_json, event_seq)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  "
  DBI::dbWithTransaction(con, {
    for (i in seq_len(n)) {
      row <- mk_row_payload(i)
      DBI::dbExecute(con, ins_sql, params = list(
        row$event_id, row$run_id, row$ts_utc, row$event_type, row$instrument_id,
        row$side, row$qty, row$price, row$fee, row$meta_json, row$event_seq
      ))
    }
  })
}

write_batched <- function(con, n, batch_size) {
  n_full <- n %/% batch_size
  remainder <- n %% batch_size
  i_start <- 1L
  for (b in seq_len(n_full)) {
    df <- mk_row_df(i_start, batch_size)
    DBI::dbAppendTable(con, "ledger_events", df)
    i_start <- i_start + batch_size
  }
  if (remainder > 0L) {
    df <- mk_row_df(i_start, remainder)
    DBI::dbAppendTable(con, "ledger_events", df)
  }
}

time_variant <- function(variant_fn, n, ...) {
  con <- mk_con()
  on.exit({
    suppressWarnings(try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE))
  })
  t <- system.time(variant_fn(con, n, ...))[["elapsed"]]
  count <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM ledger_events")$n[[1]]
  list(elapsed = as.numeric(t), count = count)
}

n_fills_set <- c(13355L, 68324L)
batch_sizes <- c(10L, 100L, 1000L, 10000L)

cat("=== parity check ===\n")
parity <- time_variant(function(con, n) write_batched(con, n, 100L), 250L)
cat(sprintf("Wrote 250 rows in batches of 100; row count = %d  [%s]\n\n",
            parity$count, if (parity$count == 250L) "OK" else "FAIL"))
if (parity$count != 250L) stop("Parity check failed.")

cat("=== timing ===\n")
cat(sprintf("%-7s %-15s | %9s %9s | %9s\n",
            "n_fills", "variant", "wall_s", "us_per_row", "rows_ok"))

res <- list()
for (n_fills in n_fills_set) {
  cat(sprintf("--- n_fills = %d ---\n", n_fills))

  # per_row (current pattern, default txn)
  r <- time_variant(write_per_row, n_fills)
  cat(sprintf("%-7d %-15s | %8.3fs %9.1f | %9s\n",
              n_fills, "per_row", r$elapsed, r$elapsed / n_fills * 1e6,
              if (r$count == n_fills) "OK" else "FAIL"))
  res[[length(res) + 1L]] <- data.frame(
    n_fills = n_fills, variant = "per_row", batch_size = 1L,
    wall_s = r$elapsed, us_per_row = r$elapsed / n_fills * 1e6,
    rows_ok = r$count == n_fills
  )

  # per_row_tx (per-row INSERTs, one big transaction)
  r <- time_variant(write_per_row_tx, n_fills)
  cat(sprintf("%-7d %-15s | %8.3fs %9.1f | %9s\n",
              n_fills, "per_row_tx", r$elapsed, r$elapsed / n_fills * 1e6,
              if (r$count == n_fills) "OK" else "FAIL"))
  res[[length(res) + 1L]] <- data.frame(
    n_fills = n_fills, variant = "per_row_tx", batch_size = 1L,
    wall_s = r$elapsed, us_per_row = r$elapsed / n_fills * 1e6,
    rows_ok = r$count == n_fills
  )

  # batched variants
  for (bs in batch_sizes) {
    r <- time_variant(function(con, n) write_batched(con, n, bs), n_fills)
    cat(sprintf("%-7d %-15s | %8.3fs %9.1f | %9s\n",
                n_fills, sprintf("batched_%d", bs), r$elapsed, r$elapsed / n_fills * 1e6,
                if (r$count == n_fills) "OK" else "FAIL"))
    res[[length(res) + 1L]] <- data.frame(
      n_fills = n_fills, variant = sprintf("batched_%d", bs), batch_size = bs,
      wall_s = r$elapsed, us_per_row = r$elapsed / n_fills * 1e6,
      rows_ok = r$count == n_fills
    )
  }
  cat("\n")
}

out <- "dev/bench/results/spike_batch_fill_writes.csv"
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(do.call(rbind, res), out, row.names = FALSE)
cat(sprintf("WROTE %s\n", out))
