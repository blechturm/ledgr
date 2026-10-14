args <- commandArgs(trailingOnly = TRUE)
`%||%` <- function(x, y) if (is.null(x)) y else x
if (length(args) < 3L) {
  stop("Usage: Rscript spike_checker.R <repo> <recorded> <scratch> [normal|gut]")
}

repo <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
recorded <- normalizePath(args[[2L]], winslash = "/", mustWork = TRUE)
scratch <- normalizePath(args[[3L]], winslash = "/", mustWork = FALSE)
mode <- if (length(args) >= 4L) args[[4L]] else "normal"
dir.create(scratch, recursive = TRUE, showWarnings = FALSE)

fail <- function(...) stop(paste0(...), call. = FALSE)
assert <- function(ok, ...) if (!isTRUE(ok)) fail(...)
read_record <- function(dir, name) {
  path <- file.path(dir, name)
  assert(file.exists(path), "Missing evidence file: ", path)
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

# Scope guard: the spike may add only its own artifacts and the macro-plan route.
git_config <- file.path(scratch, "git-safe-config")
status <- system2(
  "git",
  c("config", "--file", git_config, "--add", "safe.directory", repo),
  stdout = TRUE,
  stderr = TRUE
)
assert(identical(attr(status, "status") %||% 0L, 0L), "Could not prepare git scope guard")
old_global <- Sys.getenv("GIT_CONFIG_GLOBAL", unset = NA_character_)
Sys.setenv(GIT_CONFIG_GLOBAL = git_config)
on.exit({
  if (is.na(old_global)) Sys.unsetenv("GIT_CONFIG_GLOBAL") else Sys.setenv(GIT_CONFIG_GLOBAL = old_global)
}, add = TRUE)
changed <- system2(
  "git",
  c("-C", repo, "diff", "--name-only", "--ignore-space-at-eol"),
  stdout = TRUE
)
untracked <- system2(
  "git",
  c("-C", repo, "ls-files", "--others", "--exclude-standard"),
  stdout = TRUE
)
allowed <- function(path) {
  startsWith(path, "dev/spikes/feature_keeping/") ||
    startsWith(path, "inst/design/spikes/feature_keeping_spike/") ||
    identical(path, "inst/design/ledgr_v0_2_2_spec_packet/macro_plan.md") ||
    identical(path, "inst/design/rfc/README.md")
}
outside <- c(changed[!vapply(changed, allowed, logical(1))],
             untracked[!vapply(untracked, allowed, logical(1))])
assert(!length(outside), "Spike scope guard found changes outside scope: ", paste(outside, collapse = ", "))

timings <- read_record(recorded, "timings.csv")
correctness <- read_record(recorded, "correctness.csv")
walk <- read_record(recorded, "walk_forward.csv")
memory <- read_record(recorded, "memory.csv")
decision <- read_record(recorded, "decision.csv")
metadata <- read_record(recorded, "metadata.csv")

assert(nrow(timings) == 18L && all(timings$status == "ok"), "Timing record is incomplete")
assert(identical(sort(unique(timings$case)), c("cold", "persist", "repeat")), "Timing cases drifted")
assert(length(unique(timings$result_hash_first[timings$case == "cold"])) == 1L,
       "Cold arms changed results")
assert(length(unique(timings$result_hash_first[timings$case == "persist"])) == 1L,
       "Persistence arms changed results")
assert(all(timings$feature_rows[timings$arm == "persist_on"] == 40000),
       "Persistence-on row count drifted")
assert(all(timings$feature_rows[timings$arm == "persist_off"] == 0),
       "Persistence-off row count drifted")

assert(isTRUE(correctness$capture_stale[[1L]]), "Recorded capture-state defect disappeared")
assert(correctness$capture_first_fills[[1L]] == 0L &&
         correctness$capture_warm_fills[[1L]] == 0L &&
         correctness$capture_fresh_fills[[1L]] == 3L,
       "Capture-state oracle drifted")
assert(correctness$capture_warm_hits[[1L]] > 0L, "Warm capture case did not hit the cache")
for (name in c("engine_version_isolated", "same_hash", "different_ids",
               "same_hash_reused", "same_hash_outputs_equal")) {
  assert(isTRUE(correctness[[name]][[1L]]), "Correctness witness failed: ", name)
}
assert(!isTRUE(correctness$public_feature_reader[[1L]]) &&
         identical(correctness$reader_result[[1L]], "ledgr_invalid_result_table"),
       "Persisted-feature reader boundary drifted")

assert(walk$folds_first[[1L]] == 5L && walk$folds_second[[1L]] == 5L,
       "Walk-forward fold count drifted")
assert(walk$feature_calls_first[[1L]] == walk$feature_calls_second[[1L]] &&
         walk$feature_calls_first[[1L]] > 0L,
       "Walk-forward recomputation witness drifted")
assert(all(unlist(walk[c("entries_first", "entries_second", "values_first", "values_second")])) == 0,
       "Walk-forward unexpectedly retained feature-cache values")

assert(identical(memory$scale[[1L]], "full") &&
         memory$n_instruments[[1L]] == 1166L && memory$n_sessions[[1L]] == 7213L,
       "Recorded memory shape is not the registered Sharadar shape")
assert(memory$cache_entries[[1L]] == memory$n_instruments[[1L]] &&
         memory$cache_values[[1L]] == memory$expected_values[[1L]],
       "Recorded cache population is incomplete")
assert(memory$cache_bytes[[1L]] > 0 && memory$rss_after_run_gc[[1L]] > 0,
       "Recorded memory evidence is missing")

assert(identical(decision$verdict[[1L]], "RED"), "Recorded verdict is not RED")
assert(isTRUE(decision$cache_benefit[[1L]]) && !isTRUE(decision$cache_correctness[[1L]]) &&
         !isTRUE(decision$cache_keep[[1L]]), "Cache decision does not follow the charter")
assert(!isTRUE(decision$persistence_public_consumer[[1L]]) &&
         isTRUE(decision$persistence_outputs_equal[[1L]]) &&
         !isTRUE(decision$persistence_keep[[1L]]),
       "Persistence decision does not follow the charter")
assert(identical(metadata$value[metadata$field == "tree"], "f262e77a"), "Base tree drifted")

file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
checker <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "dev/spikes/feature_keeping/spike_checker.R"
runner <- normalizePath(file.path(dirname(checker), "runner.R"),
                        winslash = "/", mustWork = TRUE)
rerun <- file.path(scratch, paste0("rerun-", mode))
work <- file.path(scratch, paste0("work-", mode))
if (dir.exists(rerun)) unlink(rerun, recursive = TRUE, force = TRUE)
if (dir.exists(work)) unlink(work, recursive = TRUE, force = TRUE)
result <- processx::run(
  file.path(R.home("bin"), "Rscript.exe"),
  c(runner, "run", repo, rerun, work, "quick", mode),
  timeout = 600000L,
  echo = FALSE,
  error_on_status = FALSE
)
assert(identical(result$status, 0L), "Rerun failed: ", paste(result$stderr, collapse = " "))

actual_correctness <- read_record(rerun, "correctness.csv")
actual_walk <- read_record(rerun, "walk_forward.csv")
actual_memory <- read_record(rerun, "memory.csv")
actual_decision <- read_record(rerun, "decision.csv")

correctness_fields <- c(
  "capture_first_fills", "capture_warm_fills", "capture_fresh_fills",
  "capture_stale", "engine_version_isolated", "same_hash", "different_ids",
  "same_hash_reused", "same_hash_outputs_equal", "public_feature_reader",
  "reader_result"
)
assert(identical(actual_correctness[correctness_fields], correctness[correctness_fields]),
       "Rerun correctness evidence differs from the registered record")
walk_fields <- c("folds_first", "folds_second", "feature_calls_first",
                 "feature_calls_second", "entries_first", "entries_second",
                 "values_first", "values_second")
assert(identical(actual_walk[walk_fields], walk[walk_fields]),
       "Rerun walk-forward evidence differs from the registered record")
assert(actual_memory$cache_entries[[1L]] == actual_memory$n_instruments[[1L]] &&
         actual_memory$cache_values[[1L]] == actual_memory$expected_values[[1L]],
       "Rerun cache population is incomplete")
decision_fields <- c("verdict", "cache_benefit", "cache_correctness", "cache_keep",
                     "persistence_public_consumer", "persistence_outputs_equal",
                     "persistence_keep")
assert(identical(actual_decision[decision_fields], decision[decision_fields]),
       "Rerun decision differs from the registered record")

cat("FEATURE_KEEPING_SPIKE_OK verdict=RED mode=", mode, "\n", sep = "")
