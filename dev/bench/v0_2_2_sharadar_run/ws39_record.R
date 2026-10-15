# LDG-3055: build one fresh schema-120 Sharadar snapshot and record only
# aggregate evidence. The private work directory holds the store, worker logs,
# and ephemeral cross-process state; no private path or source row is emitted.
#
# Rscript ws39_record.R <ledgr_repo> <adapter_repo> <fresh_work_dir> <out_dir>

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 4L) {
  stop(
    "Usage: ws39_record.R <ledgr_repo> <adapter_repo> <fresh_work_dir> <out_dir>",
    call. = FALSE
  )
}

ledgr_repo <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
adapter_repo <- normalizePath(args[[2L]], winslash = "/", mustWork = TRUE)
work_dir_input <- args[[3L]]
out_dir <- normalizePath(args[[4L]], winslash = "/", mustWork = FALSE)

root_value <- Sys.getenv("SHARADAR_DATA_ROOT", unset = "")
if (!nzchar(root_value)) {
  stop("SHARADAR_DATA_ROOT must name the guarded private root.", call. = FALSE)
}
root <- normalizePath(root_value, winslash = "/", mustWork = TRUE)
if (!file.exists(file.path(root, ".ledgr-sharadar-private-root"))) {
  stop("The configured private root has no sentinel.", call. = FALSE)
}
work_dir <- normalizePath(work_dir_input, winslash = "/", mustWork = FALSE)
root_prefix <- paste0(tolower(root), "/")
if (!startsWith(tolower(work_dir), root_prefix)) {
  stop("fresh_work_dir must be a child of the guarded private root.", call. = FALSE)
}
if (file.exists(work_dir)) {
  stop("fresh_work_dir must not already exist; WS39 never deletes a store.", call. = FALSE)
}
if (dir.exists(out_dir) && length(list.files(out_dir, all.files = TRUE, no.. = TRUE))) {
  stop("out_dir must be absent or empty.", call. = FALSE)
}

dir.create(work_dir, recursive = TRUE, showWarnings = FALSE)
result_dir <- file.path(work_dir, "aggregate-results")
log_dir <- file.path(work_dir, "logs")
dir.create(result_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)

script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script <- normalizePath(sub("^--file=", "", script_arg[[1L]]), winslash = "/")
worker <- file.path(dirname(script), "ws39_stage.R")
rscript <- file.path(R.home("bin"), "Rscript")
stages <- c("build", "cold_verify", "full_membership", "availability")
stage_rows <- vector("list", length(stages))

for (i in seq_along(stages)) {
  stage <- stages[[i]]
  started <- Sys.time()
  process <- processx::process$new(
    rscript,
    c(worker, stage, ledgr_repo, adapter_repo, work_dir, result_dir),
    stdout = file.path(log_dir, paste0(stage, ".log")),
    stderr = "2>&1"
  )
  peak_rss <- 0
  while (process$is_alive()) {
    rss <- tryCatch(
      ps::ps_memory_info(ps::ps_handle(process$get_pid()))[["rss"]],
      error = function(error) NA_real_
    )
    if (is.finite(rss)) peak_rss <- max(peak_rss, rss)
    Sys.sleep(0.5)
  }
  status <- process$get_exit_status()
  stage_rows[[i]] <- data.frame(
    stage = stage,
    exit_status = status,
    elapsed_s = round(as.numeric(difftime(Sys.time(), started, units = "secs")), 1),
    peak_rss_mib = round(peak_rss / 2^20),
    stringsAsFactors = FALSE
  )
  cat(sprintf(
    "%-16s exit %d  %7.1f s  peak %5d MiB\n",
    stage,
    status,
    stage_rows[[i]]$elapsed_s,
    stage_rows[[i]]$peak_rss_mib
  ))
  if (!identical(status, 0L)) {
    stop(
      "WS39 stage failed; the log remains under the private work directory: ",
      stage,
      call. = FALSE
    )
  }
}

stages_df <- do.call(rbind, stage_rows)
read_result <- function(name) {
  jsonlite::read_json(file.path(result_dir, paste0(name, ".json")), simplifyVector = TRUE)
}
build <- read_result("build")
cold <- read_result("cold_verify")
full <- read_result("full_membership")
availability <- read_result("availability")

if (!identical(build$snapshot_id, cold$snapshot_id) ||
    !identical(build$snapshot_hash, cold$snapshot_hash) ||
    !identical(build$snapshot_id, full$snapshot_id) ||
    !identical(build$snapshot_hash, full$snapshot_hash) ||
    !identical(build$snapshot_id, availability$snapshot_id) ||
    !identical(build$snapshot_hash, availability$snapshot_hash)) {
  stop("The build, cold-open and experiment stages did not retain one snapshot identity.", call. = FALSE)
}

stage_value <- function(name, field) {
  stages_df[stages_df$stage == name, field][[1L]]
}
summary <- c(
  ledgr_commit = build$ledgr_commit,
  adapter_commit = build$adapter_commit,
  canonical_build_id = build$canonical_build_id,
  canonical_fingerprint = build$canonical_fingerprint,
  adapter_policy = build$adapter_policy,
  snapshot_id = build$snapshot_id,
  snapshot_hash = build$snapshot_hash,
  snapshot_status = build$snapshot_status,
  experiment_store_schema_version = build$experiment_store_schema_version,
  identity_rule_version = build$identity_rule_version,
  snapshot_hash_rule_version = build$snapshot_hash_rule_version,
  format_fingerprint = build$format_fingerprint,
  schema_validation = cold$schema_validation,
  cold_verification = cold$verification_result,
  cold_verified_in_process = cold$verified_in_process,
  snapshot_build_elapsed_s = build$snapshot_build_elapsed_s,
  build_worker_elapsed_s = build$worker_elapsed_s,
  build_stage_elapsed_s = stage_value("build", "elapsed_s"),
  build_stage_peak_rss_mib = stage_value("build", "peak_rss_mib"),
  rule3_verification_elapsed_s = cold$verification_elapsed_s,
  cold_verify_stage_elapsed_s = stage_value("cold_verify", "elapsed_s"),
  cold_verify_stage_peak_rss_mib = stage_value("cold_verify", "peak_rss_mib"),
  bars = build$bars,
  instruments = build$instruments,
  open_sessions = build$open_sessions,
  membership_rows = build$membership_rows,
  membership_sets = build$membership_sets,
  lifetime_rows = build$lifetime_rows,
  fact_families = build$fact_families,
  off_session_bars = build$off_session_bars,
  untraded_bars_dropped = build$untraded_bars_dropped,
  untraded_bar_instruments = build$untraded_bar_instruments,
  requested_start_utc = build$start_date,
  requested_end_utc = build$end_date,
  first_bar_date = build$source_start_date,
  last_bar_date = build$source_end_date,
  vendor_source_rows = build$vendor_source_rows,
  canonical_bar_rows = build$canonical_bar_rows,
  feature_table_present = build$feature_table_present,
  retired_telemetry_columns_present = build$retired_telemetry_columns_present,
  dividend_fact_mapping = "absent; retained for the later dividend-facts rebuild",
  host = build$host,
  r_version = build$r_version,
  duckdb_version = build$duckdb_version,
  duckdb_threads = build$duckdb_threads
)
summary_df <- data.frame(
  key = names(summary),
  value = unname(as.character(summary)),
  stringsAsFactors = FALSE
)

experiments <- rbind(
  data.frame(
    probe = "full_membership_availability_path",
    universe_mode = "all snapshot instruments (universe = NULL)",
    run_id = full$run_id,
    status = full$status,
    snapshot_id = full$snapshot_id,
    snapshot_hash = full$snapshot_hash,
    schema_version = full$schema_version,
    config_hash = full$config_hash,
    availability_active = full$availability_active,
    pulse_count = full$pulse_count,
    elapsed_sec = full$elapsed_sec,
    equity_rows = full$equity_rows,
    fill_rows = full$fill_rows,
    stringsAsFactors = FALSE
  ),
  data.frame(
    probe = "dynamic_membership_availability_path",
    universe_mode = "membership universe rule",
    run_id = availability$run_id,
    status = availability$status,
    snapshot_id = availability$snapshot_id,
    snapshot_hash = availability$snapshot_hash,
    schema_version = availability$schema_version,
    config_hash = availability$config_hash,
    availability_active = availability$availability_active,
    pulse_count = availability$pulse_count,
    elapsed_sec = availability$elapsed_sec,
    equity_rows = availability$equity_rows,
    fill_rows = availability$fill_rows,
    stringsAsFactors = FALSE
  )
)

reconciliation <- data.frame(
  metric = c(
    "bars", "instruments", "open_sessions", "membership_rows",
    "membership_sets", "lifetime_rows", "snapshot_hash",
    "experiment_store_schema_version", "features_table",
    "retired_run_telemetry_columns"
  ),
  current = as.character(c(
    build$bars, build$instruments, build$open_sessions, build$membership_rows,
    build$membership_sets, build$lifetime_rows, build$snapshot_hash,
    build$experiment_store_schema_version, build$feature_table_present,
    build$retired_telemetry_columns_present
  )),
  frozen_source_or_current_contract = as.character(c(
    build$source_bars, build$source_instruments, build$open_sessions,
    build$membership_rows, build$membership_sets, build$lifetime_rows,
    build$snapshot_hash, 120L, FALSE, 0L
  )),
  prior_schema119_record = as.character(c(
    build$prior_bars, build$prior_instruments, build$prior_open_sessions,
    build$prior_membership_rows, build$prior_membership_sets,
    build$prior_lifetime_rows, build$prior_snapshot_hash, 119L,
    "present", "3"
  )),
  outcome = c(
    rep("exact", 7L),
    "intended schema-120 change",
    "deleted by LDG-3050",
    "deleted by LDG-3049/3050"
  ),
  stringsAsFactors = FALSE
)

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(summary_df, file.path(out_dir, "build_summary.csv"), row.names = FALSE)
utils::write.csv(stages_df, file.path(out_dir, "stages.csv"), row.names = FALSE)
utils::write.csv(experiments, file.path(out_dir, "experiments.csv"), row.names = FALSE)
utils::write.csv(reconciliation, file.path(out_dir, "reconciliation.csv"), row.names = FALSE)

cat("WS39_RECORD_COMPLETE\n")
