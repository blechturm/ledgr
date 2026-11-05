args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3L) {
  stop("Usage: build_availability_run.R <source-root> <output-dir> <label>")
}
source_root <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
output_dir <- normalizePath(args[[2L]], winslash = "/", mustWork = FALSE)
label <- args[[3L]]
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
pkgload::load_all(source_root, quiet = TRUE)

probe_size <- function(name, default) {
  value <- Sys.getenv(name, unset = "")
  if (!nzchar(value)) return(as.integer(default))
  value <- suppressWarnings(as.integer(value))
  if (is.na(value) || value < 1L) stop(name, " must be a positive integer.")
  value
}
n_instruments <- probe_size("LEDGR_PROBE_INSTRUMENTS", 500L)
n_sessions <- probe_size("LEDGR_PROBE_SESSIONS", 7200L)
n_sets <- min(probe_size("LEDGR_PROBE_MEMBERSHIP_SETS", 600L), n_sessions)
store <- file.path(output_dir, paste0(label, "-availability.duckdb"))
snapshot_id <- paste0("diagnostic-reader-availability-", label)
run_id <- paste0("diagnostic-reader-availability-", label)
started <- proc.time()[["elapsed"]]
bars <- as.data.frame(
  ledgr_sim_bars(n_instruments, n_sessions, seed = 20261105L)
)
bar_dates <- as.Date(bars$ts_utc, tz = "UTC")
bars$ts_utc <- as.POSIXct(
  paste(bar_dates, "21:00:00"),
  tz = "UTC"
)
instrument_ids <- sort(unique(as.character(bars$instrument_id)), method = "radix")
pulses <- sort(unique(as.POSIXct(bars$ts_utc, tz = "UTC")))
set_positions <- unique(as.integer(round(seq(1L, length(pulses), length.out = n_sets))))
n_sets <- length(set_positions)
membership <- data.frame(
  instrument_id = rep(instrument_ids, times = n_sets),
  effective_from = rep(pulses[set_positions], each = length(instrument_ids)),
  knowledge_time = rep(pulses[set_positions], each = length(instrument_ids)),
  source = "public-diagnostic-reader-probe",
  set_id = rep(sprintf("set-%04d", seq_len(n_sets)), each = length(instrument_ids)),
  stringsAsFactors = FALSE
)
calendar <- seq(min(bar_dates), max(bar_dates), by = "day")
is_open <- calendar %in% unique(bar_dates)
sessions <- data.frame(
  session_date = calendar,
  status = ifelse(is_open, "open", "closed"),
  session_open = ifelse(is_open, "14:30:00", NA_character_),
  session_close = ifelse(is_open, "21:00:00", NA_character_),
  source = "public-diagnostic-reader-probe",
  stringsAsFactors = FALSE
)
facts <- ledgr_facts(
  ledgr_facts_sessions(
    sessions,
    venue_id = "public-probe-venue",
    knowledge = "assume_effective"
  ),
  ledgr_facts_membership_snapshots(
    membership,
    universe_id = "public-probe",
    complete = TRUE,
    knowledge = "evidenced"
  )
)
instrument_id <- instrument_ids[[1L]]
ts_utc <- format(pulses[[1L]], "%Y-%m-%dT%H:%M:%OS6Z", tz = "UTC")
snapshot <- ledgr_snapshot_from_df(
  bars,
  db_path = store,
  snapshot_id = snapshot_id,
  facts = facts,
  price_basis = "split_adjusted"
)
fixture_sha256 <- ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]]
rm(bars, membership, facts)
gc()
experiment <- ledgr_experiment(
  snapshot,
  function(ctx, params) ctx$hold(),
  universe = ledgr_universe_members("public-probe"),
  valuation_policy = ledgr_valuation_stale(),
  opening = ledgr_opening(cash = 1e6),
  cost_model = ledgr_cost_zero()
)
bt <- ledgr_run(experiment, run_id = run_id)
close(bt)
ledgr_snapshot_close(snapshot)

con <- DBI::dbConnect(duckdb::duckdb(), dbdir = store, read_only = TRUE)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
implicit_n <- DBI::dbGetQuery(
  con,
  paste(
    "SELECT COUNT(*) AS n FROM run_diagnostic_implicit",
    "WHERE run_id = ?"
  ),
  params = list(run_id)
)$n[[1L]]
first_decision <- DBI::dbGetQuery(
  con,
  paste(
    "SELECT instrument_id, ts_utc FROM run_diagnostic_implicit",
    "WHERE run_id = ? ORDER BY decision_seq LIMIT 1"
  ),
  params = list(run_id)
)
instrument_id <- as.character(first_decision$instrument_id[[1L]])
ts_utc <- format(
  as.POSIXct(first_decision$ts_utc[[1L]], tz = "UTC"),
  "%Y-%m-%dT%H:%M:%OS6Z",
  tz = "UTC"
)
physical_n <- DBI::dbGetQuery(
  con,
  "SELECT COUNT(*) AS n FROM run_diagnostics WHERE run_id = ?",
  params = list(run_id)
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
  snapshot_id = snapshot_id,
  run_id = run_id,
  instrument_id = instrument_id,
  ts_utc = ts_utc,
  instruments = n_instruments,
  sessions = n_sessions,
  membership_sets = n_sets,
  decision_shape_rows = as.numeric(n_instruments) * n_sessions,
  fixture_sha256 = fixture_sha256,
  implicit_rows = as.numeric(implicit_n),
  physical_rows = as.numeric(physical_n),
  build_elapsed_sec = proc.time()[["elapsed"]] - started,
  peak_wset_mib = memory[["peak_wset"]] / 2^20,
  peak_private_mib = memory[["peak_pagefile"]] / 2^20,
  stringsAsFactors = FALSE
)
utils::write.csv(
  meta,
  file.path(output_dir, paste0(label, "-availability-build.csv")),
  row.names = FALSE
)
print(meta)
