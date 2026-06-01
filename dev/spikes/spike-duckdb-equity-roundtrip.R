# Spike: DuckDB DOUBLE round-trip byte-identity check
#
# Context: LDG-2476 three-phase decomposition showed durable vs ephemeral
# ledgr equity differ by ~8e-9 per bar, forcing the parity gate to relax
# from byte-identical to tolerance = 1e-8. DuckDB stores DOUBLE which is
# the same 8-byte IEEE 754 as R numeric. A pure round-trip SHOULD be
# byte-identical. Hypothesis candidates:
#
#   (a) DuckDB internally promotes DOUBLE through DECIMAL/NUMERIC at some
#       boundary in the chunked reader.
#   (b) Accumulation order differs between durable read-back (which reads
#       pre-aggregated equity from a table) and ephemeral reconstruction
#       (which walks the event stream and re-accumulates).
#   (c) A cast through different precision in the chunked reader path.
#
# This spike isolates: byte-comparison of a write/read cycle on a
# 100-element double vector. If identical, the mechanism is (b)
# accumulation order. If different, instrument to find the cast/promotion.

suppressWarnings(suppressMessages({
  library(DBI)
  library(duckdb)
}))

set.seed(42L)
n_test <- 100L

# Generate non-trivial doubles that exercise the IEEE 754 mantissa
test_vec <- c(
  # Tiny values
  1e-12, 1e-10, 8.456e-9, 1e-8,
  # Small mantissa-exercising values
  1.123456789012345, 2.718281828459045, 3.141592653589793,
  # Mid-range
  100.123456789, 1234.5678901234567, 9999.9999999999999,
  # Powers of 2 boundaries
  2^53 - 1, 2^53, 2^53 + 1,
  # Negative
  -1.234567890123456, -1e-9, -1e9,
  # Sums/differences of similar magnitudes (cancellation candidates)
  10000000.000000001 - 10000000.000000002,
  10000.123456789 + 0.000000001,
  # Random non-trivial doubles
  runif(n_test - 19, -1e6, 1e6) * (runif(n_test - 19) - 0.5) * 7.3
)
test_vec <- test_vec[seq_len(n_test)]

cat("=== test vector preview ===\n")
print(head(test_vec, 10))
cat(sprintf("Length: %d\n\n", length(test_vec)))

# Round-trip via in-memory DuckDB
con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
on.exit({
  suppressWarnings(try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE))
})

DBI::dbExecute(con, "CREATE TABLE t (idx INTEGER, val DOUBLE)")
df_in <- data.frame(idx = seq_len(n_test), val = test_vec)
DBI::dbAppendTable(con, "t", df_in)

df_out <- DBI::dbGetQuery(con, "SELECT idx, val FROM t ORDER BY idx")

cat("=== byte-identity check (direct round-trip) ===\n")
identical_full <- identical(test_vec, df_out$val)
byte_identical <- isTRUE(all.equal(test_vec, df_out$val, tolerance = 0))
cat(sprintf("identical()        : %s\n", as.character(identical_full)))
cat(sprintf("all.equal(tol=0)   : %s\n", as.character(byte_identical)))

diffs <- test_vec - df_out$val
diffs_finite <- diffs[is.finite(diffs)]
max_abs_diff <- if (length(diffs_finite)) max(abs(diffs_finite)) else 0
n_diff <- sum(!is.na(diffs) & diffs != 0)
cat(sprintf("Max abs diff       : %.6e\n", max_abs_diff))
cat(sprintf("Non-zero diffs     : %d / %d\n", n_diff, length(diffs)))

if (n_diff > 0L) {
  cat("\nDiffering rows (top 10):\n")
  ord <- order(-abs(diffs))[seq_len(min(10L, n_diff))]
  for (k in ord) {
    cat(sprintf("  idx %d: in=%.17g  out=%.17g  diff=%.6e\n",
                k, test_vec[k], df_out$val[k], diffs[k]))
  }
}

# Now test accumulation: write events, read back as table vs reconstruct
# via cumulative sum, compare
cat("\n=== accumulation order test ===\n")
cat("Test (b): does walking events in DuckDB-stored order produce the\n")
cat("same equity as cumsum(deltas) in memory?\n")

cash_deltas <- runif(1000L, -1000, 1000)
initial_cash <- 1e6

# In-memory accumulation
in_mem_eq <- initial_cash + cumsum(cash_deltas)

# Via DuckDB store and read
DBI::dbExecute(con, "CREATE TABLE deltas (event_seq INTEGER, cash_delta DOUBLE)")
DBI::dbAppendTable(con, "deltas",
                   data.frame(event_seq = seq_along(cash_deltas), cash_delta = cash_deltas))
read_deltas <- DBI::dbGetQuery(con, "SELECT cash_delta FROM deltas ORDER BY event_seq")$cash_delta
db_eq <- initial_cash + cumsum(read_deltas)

eq_identical <- identical(in_mem_eq, db_eq)
eq_max_diff <- max(abs(in_mem_eq - db_eq))
cat(sprintf("Equity from cumsum(in-memory deltas) vs cumsum(read-back deltas):\n"))
cat(sprintf("  identical()      : %s\n", as.character(eq_identical)))
cat(sprintf("  max abs diff     : %.6e\n", eq_max_diff))

if (eq_identical) {
  cat("  -> Accumulation order is preserved through round-trip.\n")
} else {
  cat("  -> DIFFERENCE detected. Investigate the read order or cast path.\n")
}

# Also test SUM/window aggregation done by DuckDB directly (no R loop)
duckdb_cumsum <- DBI::dbGetQuery(con,
  "SELECT event_seq, SUM(cash_delta) OVER (ORDER BY event_seq) AS cum_delta FROM deltas ORDER BY event_seq")$cum_delta
duckdb_eq <- initial_cash + duckdb_cumsum

duckdb_identical <- identical(in_mem_eq, duckdb_eq)
duckdb_max_diff <- max(abs(in_mem_eq - duckdb_eq))
cat(sprintf("\nDuckDB SUM() OVER vs in-memory cumsum:\n"))
cat(sprintf("  identical()      : %s\n", as.character(duckdb_identical)))
cat(sprintf("  max abs diff     : %.6e\n", duckdb_max_diff))

# Diagnosis
cat("\n=== diagnosis ===\n")
if (identical_full && eq_identical && duckdb_identical) {
  cat("Round-trip is BYTE-IDENTICAL. The LDG-2476 8e-9 noise must come\n")
  cat("from a different code path -- possibly a cast in the production\n")
  cat("reconstruction or chunked reader that the spike's direct DBI\n")
  cat("round-trip doesn't exercise.\n")
} else if (identical_full && !duckdb_identical) {
  cat("R round-trip is byte-identical, but DuckDB SUM() OVER differs from\n")
  cat("R cumsum. This points to mechanism (a) or (c): DuckDB's internal\n")
  cat("aggregation reorders or casts. If the durable equity is computed\n")
  cat("via SUM() OVER and ephemeral via R cumsum, that explains 8e-9 noise.\n")
} else if (!identical_full) {
  cat("Direct round-trip is NOT byte-identical. DuckDB DBI driver does a\n")
  cat("cast or promotion on writeback. Investigate the dbAppendTable path.\n")
}

# Save results
res <- data.frame(
  test = c("direct_roundtrip_identical",
           "direct_max_abs_diff",
           "cumsum_accumulation_identical",
           "cumsum_max_abs_diff",
           "duckdb_sumover_identical",
           "duckdb_sumover_max_diff"),
  value = c(as.character(identical_full),
            sprintf("%.6e", max_abs_diff),
            as.character(eq_identical),
            sprintf("%.6e", eq_max_diff),
            as.character(duckdb_identical),
            sprintf("%.6e", duckdb_max_diff))
)
out <- "dev/bench/results/spike_duckdb_equity_roundtrip.csv"
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(res, out, row.names = FALSE)
cat(sprintf("\nWROTE %s\n", out))
