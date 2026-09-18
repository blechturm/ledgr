#!/usr/bin/env Rscript

script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script_path <- normalizePath(
  sub("^--file=", "", script_arg[[1L]]),
  winslash = "/",
  mustWork = TRUE
)
root <- normalizePath(
  file.path(dirname(script_path), "..", "..", ".."),
  winslash = "/",
  mustWork = TRUE
)
source_commit <- "bcced9457de58f10f9c862c2890576a7370b1140"
availability_prefix <- file.path(
  root, "dev", "bench", "results",
  "v0_2_0_1_stage_o_availability_bcced94_20260918T123618Z"
)
hash_prefix <- file.path(
  root, "dev", "bench", "results",
  "v0_2_0_1_stage_o_hash_bcced94_20260918T124304Z"
)
peer_prefix <- file.path(
  root, "dev", "bench", "results",
  "peer_benchmark_record_20260918T140507Z"
)

checks <- 0L
assert <- function(ok, message) {
  checks <<- checks + 1L
  if (!isTRUE(ok)) stop(message, call. = FALSE)
  invisible(TRUE)
}
read_csv <- function(path) {
  assert(file.exists(path), paste("Missing record artifact:", path))
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}
read_text <- function(path) {
  assert(file.exists(path), paste("Missing tracked artifact:", path))
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

environment <- read_csv(file.path(availability_prefix, "environment.csv"))
assert(identical(environment$source_commit, source_commit), "Availability source mismatch.")
cold <- read_csv(file.path(availability_prefix, "cold_seal.csv"))
warm <- read_csv(file.path(availability_prefix, "warm_runs.csv"))
lanes <- read_csv(file.path(availability_prefix, "warm_lanes.csv"))
measured <- warm[warm$measured, , drop = FALSE]
assert(nrow(measured) == 3L, "Availability record does not have three measured runs.")
assert(all(warm$status == "DONE"), "An availability run did not finish DONE.")
assert(stats::median(measured$wall_seconds) <= 60, "Availability wall gate failed.")
assert(all(measured$peak_ws_mib <= 1024), "Availability peak gate failed.")
assert(!isTRUE(cold$pairwise_reference_exported), "Pairwise validator was exported.")
assert(cold$cold_end_to_end_seconds[[1L]] == 119.11, "Cold clock drifted.")
leading <- lanes$lane[[which.max(lanes$share_in_loop)]]
assert(identical(leading, "residual_fold"), "Profile leading lane drifted.")

hash_environment <- read_csv(file.path(hash_prefix, "environment.csv"))
hash_runs <- read_csv(file.path(hash_prefix, "snapshot_hash_runs.csv"))
hash_gate <- read_csv(file.path(hash_prefix, "snapshot_hash_gates.csv"))
assert(identical(hash_environment$source_commit, source_commit), "Hash source mismatch.")
assert(nrow(hash_runs) == 8L && all(hash_runs$status == "DONE"), "Hash runs incomplete.")
assert(length(unique(hash_runs$snapshot_hash)) == 1L, "Computed hashes differ.")
assert(identical(hash_runs$snapshot_hash, hash_runs$stored_hash), "Stored hashes differ.")
assert(isTRUE(hash_gate$exact_hash) && isTRUE(hash_gate$passed), "Hash identity gate failed.")
assert(hash_gate$formatter_ratio <= 0.20, "Hash formatter gate failed.")
assert(hash_gate$wall_ratio <= 0.80, "Hash wall gate failed.")
assert(hash_gate$peak_ws_ratio <= 1.15, "Hash peak gate failed.")

peer_environment_path <- paste0(peer_prefix, "_environment.json")
assert(file.exists(peer_environment_path), "Peer environment is missing.")
peer_environment <- jsonlite::read_json(peer_environment_path, simplifyVector = TRUE)
assert(identical(peer_environment$git_sha, source_commit), "Peer source mismatch.")
assert(
  identical(peer_environment$benchmark_method, "public_one_candidate_ledgr_sweep_v002"),
  "Peer benchmark method mismatch."
)
status <- read_csv(paste0(peer_prefix, "_status.csv"))
required_done <- c(
  "ledgr_ttr_canonical", "ledgr_ttr_canonical_sweep",
  "ledgr_ttr_compiled_spot_fifo_sweep", "ledgr_builtin_sma",
  "quantstrat", "backtrader", "zipline-reloaded-full"
)
assert(all(status$status[match(required_done, status$engine)] == "DONE"), "Required peer row failed.")
lean <- status[status$engine == "LEAN", , drop = FALSE]
assert(nrow(lean) == 1L && lean$status == "UNAVAILABLE", "LEAN status is dishonest.")
clock_columns <- c(
  "snapshot_prepare_sec", "experiment_setup_sec", "engine_sec", "results_sec",
  "cold_end_to_end", "warm_research_iteration"
)
assert(all(is.na(lean[clock_columns])), "Unavailable LEAN clocks are not missing.")

performance <- read_csv(paste0(peer_prefix, "_performance.csv"))
done <- performance$status == "DONE"
phase_sum <- rowSums(performance[done, c(
  "snapshot_prepare_sec", "experiment_setup_sec", "engine_sec", "results_sec"
)])
assert(
  max(abs(phase_sum - performance$reported_core_sec[done])) < 1e-8,
  "Peer phase totals do not reconcile."
)

peak <- read_csv(paste0(peer_prefix, "_working_set_peak.csv"))
samples <- read_csv(paste0(peer_prefix, "_working_set_samples.csv"))
assert(nrow(samples) == peak$sample_count[[1L]], "Peer peak sample count differs.")
assert(
  identical(max(samples$working_set_mib), peak$peak_working_set_mib[[1L]]),
  "Peer peak does not reproduce from raw samples."
)
assert(max(samples$process_count) > 1L, "Peer sampler did not observe descendants.")

quantstrat_path <- paste0(peer_prefix, "_quantstrat_environment.json")
assert(file.exists(quantstrat_path), "Quantstrat environment sidecar is missing.")
quantstrat <- jsonlite::read_json(quantstrat_path, simplifyVector = FALSE)
assert(identical(quantstrat$packages$quantstrat$version, "0.25"), "Quantstrat version mismatch.")
assert(
  identical(
    quantstrat$packages$quantstrat$remote_sha,
    "1114e4a1a8a3b68d2fb7a62b52d743cbc5e4b39f"
  ),
  "Quantstrat SHA mismatch."
)

source_paths <- c(
  "R", "src", "DESCRIPTION", "NAMESPACE",
  "dev/bench/peer_benchmark/peer_benchmark.R"
)
source_diff <- system2(
  "git",
  c(
    paste0("--git-dir=", root, "/.git"),
    paste0("--work-tree=", root),
    "diff", "--quiet", source_commit, "--", source_paths
  ),
  stdout = FALSE,
  stderr = FALSE
)
assert(identical(source_diff, 0L), "Execution source differs from the freeze.")

report_qmd <- read_text(file.path(root, "dev", "bench", "peer_benchmark", "peer_benchmark.qmd"))
report_md <- read_text(file.path(root, "dev", "bench", "peer_benchmark", "peer_benchmark.md"))
for (text in list(report_qmd, report_md)) {
  assert(grepl("peer_benchmark_record_20260918T140507Z", text, fixed = TRUE), "Report prefix drifted.")
  assert(grepl("not a public", text, ignore.case = TRUE), "Non-ranking language is missing.")
}
assert(!grepl("LEAN[^\n]*0[.]000", report_md), "Unavailable LEAN time rendered as zero.")

cat(sprintf("STAGE_O_RECORD_CHECKS_OK: %d checks\n", checks))
