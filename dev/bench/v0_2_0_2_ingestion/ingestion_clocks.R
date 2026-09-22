# Reproduce the ingestion clocks reported by v0.2.0.2 cuts 3 and 5.
#
# Evidence capture, not an optimization benchmark and not a release claim.
# Single cold clocks at the release shape; they are orientation for the
# closeouts and must not be quoted as a promoted performance record.
#
# Run from the repository root:
#   Rscript dev/bench/v0_2_0_2_ingestion/ingestion_clocks.R
#
# Added under close review W7-F4 and W9-F4, which found the closeouts
# reported clocks from a scratch probe with no reproduction command.

options(warn = 1)

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
if (!file.exists(file.path(repo_root, "DESCRIPTION"))) {
  stop("Run this script from the ledgr repository root.", call. = FALSE)
}
pkgload::load_all(repo_root, quiet = TRUE)

n_instruments <- 500L
n_sessions <- 1260L

set.seed(1)
sessions <- as.POSIXct("2019-01-01", tz = "UTC") + (seq_len(n_sessions) - 1L) * 86400
ids <- sprintf("I%04d", seq_len(n_instruments))

bars_posixct <- data.frame(
  instrument_id = rep(ids, each = n_sessions),
  ts_utc = rep(sessions, times = n_instruments),
  open = 100 + runif(n_instruments * n_sessions),
  stringsAsFactors = FALSE
)
bars_posixct$high <- bars_posixct$open + 1
bars_posixct$low <- bars_posixct$open - 1
bars_posixct$close <- bars_posixct$open + 0.5
bars_posixct$volume <- 1000

bars_character <- bars_posixct
bars_character$ts_utc <- format(bars_posixct$ts_utc, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

csv_path <- tempfile(fileext = ".csv")
utils::write.csv(bars_character, csv_path, row.names = FALSE)

clock <- function(expr) round(system.time(expr)[["elapsed"]], 2)

# Build every normalization input before the clocks, so a clock measures the
# call and not the construction of its argument.
ts_date_only <- format(bars_posixct$ts_utc, "%Y-%m-%d")
ts_no_z <- format(bars_posixct$ts_utc, "%Y-%m-%dT%H:%M:%S")
seal_and_close <- function(expr) {
  snapshot <- expr
  ledgr_snapshot_close(snapshot)
  invisible(NULL)
}

results <- list(
  reader = clock(invisible(ledgr:::ledgr_read_csv_strict(csv_path))),
  from_df_posixct = clock(seal_and_close(
    ledgr_snapshot_from_df(bars_posixct, db_path = tempfile(fileext = ".duckdb"))
  )),
  from_df_character = clock(seal_and_close(
    ledgr_snapshot_from_df(bars_character, db_path = tempfile(fileext = ".duckdb"))
  )),
  from_csv = clock(seal_and_close(
    ledgr_snapshot_from_csv(csv_path, db_path = tempfile(fileext = ".duckdb"))
  )),
  normalize_posixct = clock(invisible(
    ledgr:::ledgr_snapshot_normalize_ts_utc(bars_posixct$ts_utc)
  )),
  normalize_character_iso_z = clock(invisible(
    ledgr:::ledgr_snapshot_normalize_ts_utc(bars_character$ts_utc)
  )),
  normalize_date_only = clock(invisible(
    ledgr:::ledgr_snapshot_normalize_ts_utc(ts_date_only)
  )),
  normalize_no_z = clock(invisible(
    ledgr:::ledgr_snapshot_normalize_ts_utc(ts_no_z)
  ))
)

peer_fixture <- file.path(
  repo_root, "dev", "bench", "results", "peer_benchmark_shared_bars_record.csv"
)
if (file.exists(peer_fixture)) {
  results$peer_phase <- clock(seal_and_close(
    ledgr_snapshot_from_csv(peer_fixture, db_path = tempfile(fileext = ".duckdb"))
  ))
}

cat(sprintf("rows: %d\n", nrow(bars_posixct)))
cat(sprintf("R: %s\n", R.version.string))
cat(sprintf("duckdb: %s\n", as.character(utils::packageVersion("duckdb"))))
cat("\nseconds, single cold clock each:\n")
for (nm in names(results)) {
  cat(sprintf("  %-26s %8.2f\n", nm, results[[nm]]))
}
