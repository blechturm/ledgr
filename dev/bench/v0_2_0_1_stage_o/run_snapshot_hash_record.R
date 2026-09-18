#!/usr/bin/env Rscript

# Stage O wrapper around the reviewed Stage N paired hash harness. It changes
# no arm or fixture logic; it only writes a new immutable final-record bundle.

args_o <- commandArgs(trailingOnly = TRUE)
script_arg_o <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script_path_o <- normalizePath(
  sub("^--file=", "", script_arg_o[[1L]]),
  winslash = "/",
  mustWork = TRUE
)
repo_root_o <- normalizePath(
  file.path(dirname(script_path_o), "..", "..", ".."),
  winslash = "/",
  mustWork = TRUE
)
source(file.path(
  repo_root_o,
  "dev", "bench", "v0_2_0_1_stage_n",
  "run_snapshot_hash_deduplication.R"
))

stage_o_arg <- function(name, default = NULL) {
  at <- match(name, args_o)
  if (is.na(at) || at == length(args_o)) default else args_o[[at + 1L]]
}

stage_o_main <- function() {
  tracked <- system2(
    "git",
    c("-C", shQuote(repo_root_o), "status", "--porcelain", "--untracked-files=no"),
    stdout = TRUE
  )
  if (length(tracked)) {
    stop("Tracked worktree changes must be committed before recording.", call. = FALSE)
  }
  output_arg <- stage_o_arg("--out-dir", "")
  if (!nzchar(output_arg)) stop("`--out-dir` is required.", call. = FALSE)
  output_dir <- normalizePath(output_arg, winslash = "/", mustWork = FALSE)
  if (dir.exists(output_dir) && length(list.files(output_dir, all.files = TRUE))) {
    stop("Refusing to overwrite an existing Stage O record.", call. = FALSE)
  }
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  db_path <- tempfile("stage_o_hash_", fileext = ".duckdb")
  on.exit(unlink(c(db_path, paste0(db_path, ".wal")), force = TRUE), add = TRUE)
  bars <- as.data.frame(ledgr_sim_bars(
    n_instruments = 500L,
    n_days = 1260L,
    seed = 20260530L,
    instrument_prefix = "STAGE_L_"
  ))
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  snapshot_id <- snapshot$snapshot_id
  stored_hash <- ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]]
  ledgr_snapshot_close(snapshot)
  frozen <- utils::read.csv(
    file.path(
      repo_root_o,
      "inst", "design", "ledgr_v0_2_0_1_spec_packet",
      "batch11-current-arm-prefixes.csv"
    ),
    stringsAsFactors = FALSE
  )
  frozen_hash <- unique(frozen$semantic_fingerprint[
    frozen$mechanism == "snapshot_hash_rule_1"
  ])
  if (length(frozen_hash) != 1L || !identical(stored_hash, frozen_hash)) {
    stop("Stage O fixture does not match the frozen Stage L hash.", call. = FALSE)
  }
  rm(bars)
  invisible(gc(full = TRUE))

  repetitions <- c("warmup", "run1", "run2", "run3")
  rows <- list()
  row_number <- 0L
  for (repetition in repetitions) {
    arms <- if (repetition %in% c("warmup", "run1", "run3")) {
      c("current", "candidate")
    } else {
      c("candidate", "current")
    }
    for (arm in arms) {
      message("[Stage O hash] ", repetition, " / ", arm)
      result <- stage_n_launch(arm, repetition, db_path, snapshot_id)
      row_number <- row_number + 1L
      row <- as.data.frame(result, stringsAsFactors = FALSE)
      row$measured <- !identical(repetition, "warmup")
      rows[[row_number]] <- row
    }
  }
  runs <- do.call(rbind, rows)
  rownames(runs) <- NULL
  if (!all(runs$snapshot_hash == stored_hash)) {
    stop("Stage O changed the registered snapshot hash.", call. = FALSE)
  }
  gate <- stage_n_gate(runs, row_count = 630000L)
  if (!isTRUE(gate$passed)) stop("One or more Stage O hash gates failed.", call. = FALSE)

  source_commit <- system2(
    "git",
    c("-C", shQuote(repo_root_o), "rev-parse", "HEAD"),
    stdout = TRUE
  )
  environment <- data.frame(
    source_commit = source_commit,
    r = R.version.string,
    platform = R.version$platform,
    duckdb = as.character(utils::packageVersion("duckdb")),
    testthat = as.character(utils::packageVersion("testthat")),
    collapse = as.character(utils::packageVersion("collapse")),
    primary_library = normalizePath(.libPaths()[[1L]], winslash = "/"),
    stringsAsFactors = FALSE
  )
  fixture <- data.frame(
    instruments = 500L,
    sessions = 1260L,
    rows = 630000L,
    seed = 20260530L,
    instrument_prefix = "STAGE_L_",
    chunk_size = 10000L,
    frozen_hash = frozen_hash,
    stringsAsFactors = FALSE
  )
  utils::write.csv(runs, file.path(output_dir, "snapshot_hash_runs.csv"), row.names = FALSE)
  utils::write.csv(gate, file.path(output_dir, "snapshot_hash_gates.csv"), row.names = FALSE)
  utils::write.csv(environment, file.path(output_dir, "environment.csv"), row.names = FALSE)
  utils::write.csv(fixture, file.path(output_dir, "fixture.csv"), row.names = FALSE)
  writeLines(c(
    "# v0.2.0.1 Stage O Snapshot-Hash Record",
    "",
    sprintf("- Source commit: `%s`.", source_commit),
    sprintf("- Frozen hash: `%s`.", frozen_hash),
    sprintf("- Current median: %.2f seconds.", gate$current_median_sec),
    sprintf("- Candidate median: %.2f seconds.", gate$candidate_median_sec),
    sprintf("- Wall ratio: %.6f (gate at most 0.80).", gate$wall_ratio),
    sprintf("- Formatter ratio: %.6f (gate at most 0.20).", gate$formatter_ratio),
    sprintf("- Peak ratio: %.6f (gate at most 1.15).", gate$peak_ws_ratio),
    sprintf("- Exact hash identity: `%s`.", gate$exact_hash),
    "- Current arm rebinds only the distinct formatter helper to the original formatter.",
    "- One warm-up and three measured calls per arm; fixture creation is outside the clock."
  ), file.path(output_dir, "summary.md"), useBytes = TRUE)
  cat("STAGE_O_HASH_RECORD_PREFIX=", output_dir, "\n", sep = "")
  print(gate, row.names = FALSE)
}

if (!length(args_o) || !identical(args_o[[1L]], "--child")) {
  stage_o_main()
}
