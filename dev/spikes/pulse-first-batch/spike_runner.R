args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(flag, default = NULL) {
  at <- match(flag, args)
  if (is.na(at) || at >= length(args)) default else args[[at + 1L]]
}
preset <- arg_value("--preset", "smoke")
output <- normalizePath(arg_value("--output", file.path(tempdir(), "pulse-first-batch")),
  winslash = "/", mustWork = FALSE)
repo_root <- normalizePath(arg_value("--repo", "."), winslash = "/")
spike_root <- file.path(repo_root, "dev", "spikes", "pulse-first-batch")
dir.create(output, recursive = TRUE, showWarnings = FALSE)

source(file.path(spike_root, "R", "core.R"))
source(file.path(spike_root, "R", "loops.R"))
source(file.path(spike_root, "R", "parallel.R"))
source(file.path(spike_root, "tests", "run-correctness.R"))
source(file.path(spike_root, "benchmarks", "run-benchmarks.R"))

correctness <- pfb_run_correctness(spike_root, repo_root, gut = FALSE, run_parallel = TRUE)
gutted <- pfb_run_correctness(spike_root, repo_root, gut = TRUE, run_parallel = FALSE)
utils::write.csv(correctness, file.path(output, "correctness.csv"), row.names = FALSE)
utils::write.csv(gutted, file.path(output, "gutted_correctness.csv"), row.names = FALSE)
stopifnot(all(correctness$status == "pass"), any(gutted$status == "fail"))

if (identical(preset, "record")) {
  serial_cases <- list(
    list(case_id = "S01", n_sessions = 252L, n_instruments = 10L, n_configs = 10L, family = "signal", feature_mode = "common", fee_rate = 0, seed = 101L),
    list(case_id = "S02", n_sessions = 252L, n_instruments = 100L, n_configs = 100L, family = "signal", feature_mode = "common", fee_rate = 0, seed = 102L),
    list(case_id = "S03", n_sessions = 252L, n_instruments = 100L, n_configs = 500L, family = "signal", feature_mode = "common", fee_rate = 0.0001, seed = 103L),
    list(case_id = "S04", n_sessions = 252L, n_instruments = 100L, n_configs = 500L, family = "signal", feature_mode = "varying", fee_rate = 0.0001, seed = 104L),
    list(case_id = "S05", n_sessions = 252L, n_instruments = 100L, n_configs = 500L, family = "stateful", feature_mode = "varying", fee_rate = 0.0001, seed = 105L),
    list(case_id = "S06", n_sessions = 1260L, n_instruments = 100L, n_configs = 100L, family = "signal", feature_mode = "common", fee_rate = 0, seed = 106L),
    list(case_id = "S07", n_sessions = 252L, n_instruments = 500L, n_configs = 100L, family = "signal", feature_mode = "common", fee_rate = 0, seed = 107L),
    list(case_id = "S08", n_sessions = 252L, n_instruments = 100L, n_configs = 1000L, family = "signal", feature_mode = "common", fee_rate = 0, seed = 108L)
  )
  parallel_cases <- list(
    list(case_id = "P01", n_sessions = 252L, n_instruments = 100L, n_configs = 128L, family = "signal", feature_mode = "common", fee_rate = 0, seed = 201L, workers = c(1L, 2L, 4L), batch_sizes = c(1L, 16L, 64L, 128L)),
    list(case_id = "P02", n_sessions = 252L, n_instruments = 100L, n_configs = 512L, family = "stateful", feature_mode = "varying", fee_rate = 0.0001, seed = 202L, workers = c(1L, 2L, 4L), batch_sizes = c(64L, 256L, 512L))
  )
  ledgr_cases <- list(
    list(case_id = "L01", n_sessions = 252L, n_instruments = 10L, n_configs = 10L, workers = 1L, seed = 301L),
    list(case_id = "L02", n_sessions = 252L, n_instruments = 10L, n_configs = 32L, workers = 1L, seed = 302L),
    list(case_id = "L03", n_sessions = 252L, n_instruments = 10L, n_configs = 32L, workers = 2L, seed = 302L),
    list(case_id = "L04", n_sessions = 252L, n_instruments = 10L, n_configs = 32L, workers = 4L, seed = 302L)
  )
  repeats <- 2L
} else {
  serial_cases <- list(
    list(case_id = "S00", n_sessions = 60L, n_instruments = 10L, n_configs = 12L, family = "signal", feature_mode = "varying", fee_rate = 0.0001, seed = 1L)
  )
  parallel_cases <- list(
    list(case_id = "P00", n_sessions = 60L, n_instruments = 10L, n_configs = 12L, family = "stateful", feature_mode = "common", fee_rate = 0.0001, seed = 2L, workers = c(1L, 2L), batch_sizes = c(1L, 6L, 12L))
  )
  ledgr_cases <- list(
    list(case_id = "L00", n_sessions = 30L, n_instruments = 3L, n_configs = 3L, workers = 1L, seed = 3L)
  )
  repeats <- 1L
}

serial <- do.call(rbind, lapply(serial_cases, pfb_benchmark_serial,
  spike_root = spike_root, repeats = repeats))
utils::write.csv(serial, file.path(output, "serial_benchmarks.csv"), row.names = FALSE)

parallel <- do.call(rbind, lapply(parallel_cases, pfb_benchmark_parallel,
  spike_root = spike_root))
utils::write.csv(parallel, file.path(output, "parallel_benchmarks.csv"), row.names = FALSE)

ledgr_rows <- list()
for (i in seq_along(ledgr_cases)) {
  profile_file <- if (identical(ledgr_cases[[i]]$case_id, "L02"))
    file.path(output, "ledgr_sweep_profile.out") else NULL
  ledgr_rows[[i]] <- pfb_ledgr_contextual_baseline(
    ledgr_cases[[i]], repo_root, profile_output = profile_file
  )
}
ledgr_baseline <- do.call(rbind, ledgr_rows)
utils::write.csv(ledgr_baseline, file.path(output, "ledgr_baseline.csv"), row.names = FALSE)
if (file.exists(file.path(output, "ledgr_sweep_profile.out"))) {
  profile <- summaryRprof(file.path(output, "ledgr_sweep_profile.out"))$by.self
  profile$function_name <- rownames(profile)
  rownames(profile) <- NULL
  utils::write.csv(profile, file.path(output, "ledgr_sweep_profile.csv"), row.names = FALSE)
  unlink(file.path(output, "ledgr_sweep_profile.out"))
}

profile_params <- pfb_make_params(if (identical(preset, "record")) 500L else 20L, "signal", "common")
profile_market <- pfb_generate_market(if (identical(preset, "record")) 252L else 60L,
  if (identical(preset, "record")) 100L else 10L, 401L)
profile_prepared <- pfb_prepare(profile_market, profile_params)
pfb_profile(
  function() pfb_run_strategy_first(profile_prepared, profile_params),
  file.path(output, "strategy_first_profile.csv")
)
pfb_profile(
  function() pfb_run_pulse_first(profile_prepared, profile_params, share_pulse = TRUE),
  file.path(output, "pulse_first_profile.csv")
)

environment <- data.frame(
  recorded_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  r_version = R.version.string, platform = R.version$platform,
  os = paste(Sys.info()[c("sysname", "release", "machine")], collapse = " "),
  cpu = Sys.getenv("PROCESSOR_IDENTIFIER"),
  mirai_version = if (requireNamespace("mirai", quietly = TRUE)) as.character(packageVersion("mirai")) else NA_character_,
  ps_version = if (requireNamespace("ps", quietly = TRUE)) as.character(packageVersion("ps")) else NA_character_,
  workers_tested = paste(sort(unique(unlist(lapply(parallel_cases, `[[`, "workers")))), collapse = ","),
  stringsAsFactors = FALSE
)
utils::write.csv(environment, file.path(output, "environment.csv"), row.names = FALSE)
cat(sprintf("PASS: %s evidence written to %s\n", preset, output))
