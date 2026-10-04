bench_lib <- Sys.getenv("LEDGR_BENCH_LIB", "")
if (nzchar(bench_lib)) .libPaths(c(bench_lib, .libPaths()))

args <- commandArgs(TRUE)
if (!length(args) %in% 4:5) {
  stop(paste(
    "Usage: run_suite.R <accepted_repo> <candidate_repo> <out_dir>",
    "<pairs> [memory|dispatch]"
  ))
}
accepted_repo <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
candidate_repo <- normalizePath(args[[2L]], winslash = "/", mustWork = TRUE)
out_dir <- normalizePath(args[[3L]], winslash = "/", mustWork = FALSE)
pairs <- as.integer(args[[4L]])
gate_profile <- if (length(args) == 5L) args[[5L]] else "memory"
if (is.na(pairs) || pairs < 5L) stop("At least five pairs are required")
if (!gate_profile %in% c("memory", "dispatch")) {
  stop("Gate profile must be memory or dispatch")
}
if (!requireNamespace("processx", quietly = TRUE) ||
    !requireNamespace("ps", quietly = TRUE)) {
  stop("processx and ps are required")
}
script <- dirname(normalizePath(sub("^--file=", "", grep(
  "^--file=", commandArgs(FALSE), value = TRUE
)[[1L]]), winslash = "/"))
source(file.path(script, "helpers.R"), local = TRUE)
if (nzchar(memory_product_status(accepted_repo)) ||
    nzchar(memory_product_status(candidate_repo))) {
  stop("Product trees must be clean")
}
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
raw_dir <- file.path(out_dir, "raw")
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
fixture_dir <- file.path(out_dir, "fixture")
dir.create(fixture_dir, recursive = TRUE, showWarnings = FALSE)

run_child <- function(repo, arm, pair, persistence, mode = "gate",
                      availability = TRUE) {
  tag <- sprintf("%s_%02d_%s_%s", arm, pair, persistence,
                 mode)
  out_json <- file.path(raw_dir, paste0(tag, ".json"))
  stdout <- file.path(raw_dir, paste0(tag, ".stdout"))
  stderr <- file.path(raw_dir, paste0(tag, ".stderr"))
  fixture_db <- file.path(
    fixture_dir,
    if (availability) "snapshot.duckdb" else "dense.duckdb"
  )
  child <- processx::process$new(
    file.path(R.home("bin"), "Rscript"),
    c(file.path(script, "run_case.R"), repo,
      fixture_db,
      if (availability) "true" else "false",
      if (identical(persistence, "on")) "true" else "false",
      mode, out_json),
    stdout = stdout, stderr = stderr, cleanup = TRUE
  )
  peak <- 0
  while (child$is_alive()) {
    rss <- tryCatch(ps::ps_memory_info(ps::ps_handle(child$get_pid()))[["rss"]],
                    error = function(e) NA_real_)
    if (is.finite(rss)) peak <- max(peak, rss)
    child$poll_io(100)
  }
  status <- child$get_exit_status()
  err <- paste(readLines(stderr, warn = FALSE), collapse = "\n")
  if (!identical(status, 0L)) stop("Child failed: ", tag, "\n", err)
  value <- jsonlite::read_json(out_json, simplifyVector = TRUE)
  data.frame(
    arm = arm, pair = pair, persistence = persistence, mode = mode,
    availability = availability, commit = value$commit,
    elapsed_s = value$elapsed_s, peak_rss_bytes = peak,
    output_file = basename(out_json), stringsAsFactors = FALSE
  )
}

fixture_status <- system2(
  file.path(R.home("bin"), "Rscript"),
  c(file.path(script, "build_fixture.R"), candidate_repo, fixture_dir)
)
if (!identical(fixture_status, 0L)) stop("Fixture build failed")

rows <- list()
for (persistence in c("off", "on")) {
  for (pair in seq_len(pairs)) {
    order <- if (pair %% 2L) c("accepted", "candidate") else {
      c("candidate", "accepted")
    }
    repos <- c(accepted = accepted_repo, candidate = candidate_repo)
    for (arm in order) {
      rows[[length(rows) + 1L]] <- run_child(
        repos[[arm]], arm, pair, persistence, "gate", TRUE
      )
    }
  }
  for (arm in c("accepted", "candidate")) {
    repos <- c(accepted = accepted_repo, candidate = candidate_repo)
    rows[[length(rows) + 1L]] <- run_child(
      repos[[arm]], arm, 0L, persistence, "phase", TRUE
    )
  }
}
measurements <- do.call(rbind, rows)
utils::write.csv(measurements, file.path(out_dir, "measurements.csv"),
                 row.names = FALSE)

oracles <- list()
for (persistence in c("off", "on")) {
  oracles[[length(oracles) + 1L]] <- run_child(
    accepted_repo, "accepted", 0L, persistence, "oracle", TRUE
  )
  oracles[[length(oracles) + 1L]] <- run_child(
    candidate_repo, "candidate", 0L, persistence, "oracle", TRUE
  )
}
utils::write.csv(do.call(rbind, oracles), file.path(out_dir, "oracles.csv"),
                 row.names = FALSE)
dense_a <- run_child(accepted_repo, "accepted_dense", 0L, "off", "oracle",
                     FALSE)
dense_c <- run_child(candidate_repo, "candidate_dense", 0L, "off", "oracle",
                     FALSE)
utils::write.csv(rbind(dense_a, dense_c), file.path(out_dir, "dense.csv"),
                 row.names = FALSE)
jsonlite::write_json(list(
  accepted_commit = memory_git_commit(accepted_repo),
  candidate_commit = memory_git_commit(candidate_repo), pairs = pairs,
  gate_profile = gate_profile,
  peak_ratio_limit = if (identical(gate_profile, "memory")) 0.90 else 1.00,
  elapsed_ratio_limit = if (identical(gate_profile, "memory")) 1.05 else 1.00,
  peak_gate_target = if (identical(gate_profile, "memory")) {
    "unmarked peak child RSS"
  } else {
    "marked feature-phase peak-so-far at start_setup"
  },
  feature_phase_end_marker = "start_setup",
  retry_rule = paste("one complete fresh retry of the same pair count;",
                     "a miss stands only when the retry also misses"),
  gate_runs = "unmarked", phase_runs = "separate paired marked runs"
), file.path(out_dir, "suite.json"), auto_unbox = TRUE, pretty = TRUE)
cat("DURABLE_MEMORY_SUITE_OK", nrow(measurements), "rows\n")
