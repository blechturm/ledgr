args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3L) stop("Usage: build_run.R <source-root> <output-dir> <label>")
source_root <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
output_dir <- normalizePath(args[[2L]], winslash = "/", mustWork = FALSE)
label <- args[[3L]]
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
pkgload::load_all(source_root, quiet = TRUE)

n_instruments <- 500L
n_sessions <- 7200L
store <- file.path(output_dir, paste0(label, ".duckdb"))
snapshot_id <- paste0("diagnostic-reader-reuse-", label)
run_id <- paste0("diagnostic-reader-reuse-", label)
started <- proc.time()[["elapsed"]]
bars <- as.data.frame(ledgr_sim_bars(n_instruments, n_sessions, seed = 20261105L))
instrument_id <- as.character(bars$instrument_id[[1L]])
ts_utc <- format(as.POSIXct(bars$ts_utc[[1L]], tz = "UTC"), "%Y-%m-%dT%H:%M:%OS6Z", tz = "UTC")
snapshot <- ledgr_snapshot_from_df(bars, db_path = store, snapshot_id = snapshot_id)
fixture_sha256 <- ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]]
rm(bars); gc()
experiment <- ledgr_experiment(
  snapshot,
  function(ctx, params) ctx$hold(),
  opening = ledgr_opening(cash = 1e6),
  cost_model = ledgr_cost_zero()
)
bt <- ledgr_run(experiment, run_id = run_id)
close(bt); ledgr_snapshot_close(snapshot)

con <- DBI::dbConnect(duckdb::duckdb(), dbdir = store, read_only = TRUE)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
tables <- DBI::dbListTables(con)
implicit_n <- if ("run_diagnostic_implicit" %in% tables) DBI::dbGetQuery(
  con, "SELECT COUNT(*) AS n FROM run_diagnostic_implicit WHERE run_id = ?", params = list(run_id)
)$n[[1L]] else NA_real_
physical_n <- DBI::dbGetQuery(
  con, "SELECT COUNT(*) AS n FROM run_diagnostics WHERE run_id = ?", params = list(run_id)
)$n[[1L]]
memory <- ps::ps_memory_info(ps::ps_handle())
source_commit_file <- file.path(source_root, "SOURCE_COMMIT")
source_commit_override <- Sys.getenv("LEDGR_SOURCE_COMMIT", unset = "")
source_commit <- if (nzchar(source_commit_override)) {
  source_commit_override
} else if (file.exists(source_commit_file)) {
  readLines(source_commit_file, n = 1L, warn = FALSE)
} else {
  system2(
    "git",
    c("-c", "safe.directory=*", "-C", shQuote(source_root),
      "rev-parse", "HEAD"),
    stdout = TRUE
  )[[1L]]
}
meta <- data.frame(
  label = label,
  source_root = source_root,
  source_commit = source_commit,
  store = normalizePath(store, winslash = "/", mustWork = TRUE),
  snapshot_id = snapshot_id, run_id = run_id, instrument_id = instrument_id, ts_utc = ts_utc,
  instruments = n_instruments, sessions = n_sessions,
  decision_shape_rows = as.numeric(n_instruments) * n_sessions,
  fixture_sha256 = fixture_sha256,
  implicit_rows = as.numeric(implicit_n), physical_rows = as.numeric(physical_n),
  build_elapsed_sec = proc.time()[["elapsed"]] - started,
  peak_wset_mib = memory[["peak_wset"]] / 2^20,
  peak_private_mib = memory[["peak_pagefile"]] / 2^20,
  stringsAsFactors = FALSE
)
utils::write.csv(meta, file.path(output_dir, paste0(label, "-build.csv")), row.names = FALSE)
print(meta)
