# Check the Workstream 53 aggregate record without reading private inputs.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) {
  stop("Usage: check_ws53.R <evidence_dir>", call. = FALSE)
}
root <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
fail <- function(...) stop(..., call. = FALSE)
expect <- function(ok, message) if (!isTRUE(ok)) fail(message)
read <- function(...) utils::read.csv(file.path(root, ...), stringsAsFactors = FALSE)

steps <- read("steps.csv")
expected_one <- as.vector(outer(
  c("attrib_v003_la", "attrib_v003_lib", "attrib_v004_la", "attrib_v004_lib"),
  paste0("r", 1:3), paste, sep = "_"
))
expected_two <- as.vector(outer(
  c(
    "attrib_sweep_base_la", "attrib_sweep_v003_la",
    "attrib_sweep_v004_la", "attrib_sweep_v004_lib"
  ),
  paste0("r", 1:3), paste, sep = "_"
))
expected <- c(expected_one, expected_two)
expect(setequal(steps$tag, expected), "The one- and two-worker arm set changed.")
expect(all(as.integer(steps$exit_status) == 0L), "A measured arm did not exit cleanly.")
expect(all(as.numeric(steps$effective_sample_interval_s) <= 0.25), "A repeated arm missed the sampler interval.")
expect(all(as.integer(steps$other_r_at_start) == 0L), "A repeated arm started with a foreign R process.")

arm_summary <- read("arm_summary.csv")
expect(all(arm_summary$repeats == 3L), "Every repeated contrast needs three arms.")
expected_arms <- sub("_r[123]$", "", expected)
expect(setequal(arm_summary$arm, unique(expected_arms)), "The summary arm set changed.")

read_keys <- function(path) {
  x <- utils::read.csv(path, stringsAsFactors = FALSE)
  stats::setNames(as.character(x$value), as.character(x$key))
}
attrib_files <- list.files(root, pattern = "__attrib[.]csv$", full.names = TRUE)
expect(length(attrib_files) == length(expected), "An attribution result file is missing.")
attrib <- lapply(attrib_files, read_keys)
names(attrib) <- sub("__attrib[.]csv$", "", basename(attrib_files))
for (tag in expected_one) {
  expect(identical(attrib[[tag]][["fill_rows"]], "8798"), paste("Unexpected fill count:", tag))
}
for (tag in expected_two) {
  expect(identical(attrib[[tag]][["candidates_done"]], "2"), paste("Unexpected candidate count:", tag))
}
groups <- list(
  v003_run = expected_one[grepl("v003", expected_one)],
  v004_run = expected_one[grepl("v004", expected_one)],
  v003_sweep = expected_two[grepl("base_la|v003_la", expected_two)],
  v004_sweep = expected_two[grepl("v004", expected_two)]
)
for (group in groups) {
  values <- vapply(group, function(tag) attrib[[tag]][["final_equity"]], "")
  expect(length(unique(values)) == 1L, paste("Economic output differs in", group[[1L]]))
}

profile <- read("current/profile_run.csv")
telemetry_run <- read("current/telemetry_run.csv")
for (x in list(profile, telemetry_run)) {
  expect(identical(x$status[[1L]], "DONE"), "The current H1 run is not DONE.")
  expect(as.integer(x$pulses[[1L]]) == 7213L, "The current H1 pulse count changed.")
  expect(as.integer(x$fills[[1L]]) == 8798L, "The current H1 fill count changed.")
}
hash_cols <- c("fills_hash", "equity_hash", "trades_hash")
expect(
  identical(as.character(profile[1L, hash_cols]), as.character(telemetry_run[1L, hash_cols])),
  "Profiling changed a native result hash."
)
phase_total <- sum(as.numeric(profile[1L, c("t_pre_s", "t_loop_s", "t_post_s")]))
expect(abs(phase_total - profile$elapsed_s[[1L]]) / profile$elapsed_s[[1L]] <= 0.10, "Public phases do not reconcile to the run wall.")
profile_total <- read("current/profile_total.csv")
canonical <- profile_total[profile_total$function_name == '"canonical_json"', , drop = FALSE]
expect(nrow(canonical) == 1L, "The canonical JSON profile row is missing.")
expect(canonical$total.time[[1L]] / profile$elapsed_s[[1L]] < 0.05, "Canonical JSON unexpectedly clears the five-percent gate.")
scheduler <- read("current/scheduler_lower_bound.csv")
expect(scheduler$wall_share[[1L]] >= 0.05, "The scheduler result no longer reaches Type 2 routing.")

workers <- read("workers/worker_scaling.csv")
expect(setequal(workers$tag, c("v003_workers2_census", "v004_workers4", "v004_workers8")), "The worker-arm set changed.")
expect(all(as.integer(workers$exit_status) == 0L), "A worker arm failed.")
expect(all(workers$effective_interval_s <= 0.25), "A worker arm missed the sampler interval.")
eight <- workers[workers$workers == 8L, , drop = FALSE]
expect(nrow(eight) == 1L, "The eight-worker trigger arm is missing.")
expect(eight$parent_plus_daemon_peak_private_mib[[1L]] <= 12 * 1024, "The eight-worker private peak exceeds 12 GiB.")
worker_results <- list.files(file.path(root, "workers"), pattern = "_result[.]csv$", full.names = TRUE)
result_rows <- lapply(worker_results, utils::read.csv, stringsAsFactors = FALSE)
v004 <- result_rows[vapply(result_rows, function(x) grepl("v004", x$tag[[1L]]), TRUE)]
expect(length(unique(vapply(v004, function(x) x$final_equity[[1L]], ""))) == 1L, "Worker count changed the v004 result.")
expect(length(unique(vapply(v004, function(x) x$execution_seed[[1L]], ""))) == 1L, "Worker count changed execution seeds.")

text_files <- list.files(root, pattern = "[.](csv|md|txt)$", recursive = TRUE, full.names = TRUE)
for (path in text_files) {
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")
  expect(!grepl("[A-Za-z]:[/\\\\]", text), paste("Private or local path leaked into", basename(path)))
}
cat("WS53_CHECK_OK\n")
