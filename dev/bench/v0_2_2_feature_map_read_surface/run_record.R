args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 4L) {
  stop("Usage: run_record.R <pre_cut_repo> <candidate_repo> <out_dir> <reps>")
}
pre_cut_repo <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
candidate_repo <- normalizePath(args[[2L]], winslash = "/", mustWork = TRUE)
out_dir <- normalizePath(args[[3L]], winslash = "/", mustWork = FALSE)
reps <- as.integer(args[[4L]])
if (is.na(reps) || reps < 3L) stop("At least three triplets are required.")
if (!requireNamespace("processx", quietly = TRUE) ||
    !requireNamespace("ps", quietly = TRUE)) {
  stop("processx and ps are required.")
}

script_dir <- dirname(normalizePath(sub(
  "^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]
), winslash = "/"))
case_script <- file.path(script_dir, "run_case.R")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
raw_dir <- file.path(out_dir, "raw")
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)

arms <- data.frame(
  arm = c("pre_cut_bundle", "candidate_bundle", "candidate_plane"),
  repo = c(pre_cut_repo, candidate_repo, candidate_repo),
  mode = c("bundle", "bundle", "plane"),
  stringsAsFactors = FALSE
)
orders <- list(
  c("pre_cut_bundle", "candidate_bundle", "candidate_plane"),
  c("candidate_plane", "candidate_bundle", "pre_cut_bundle"),
  c("candidate_bundle", "pre_cut_bundle", "candidate_plane")
)

run_child <- function(arm, rep, attempt) {
  row <- arms[arms$arm == arm, , drop = FALSE]
  output <- file.path(
    raw_dir, sprintf("%s_%s_%02d.json", attempt, arm, rep)
  )
  stdout <- sub("[.]json$", ".stdout", output)
  stderr <- sub("[.]json$", ".stderr", output)
  process <- processx::process$new(
    file.path(R.home("bin"), "Rscript"),
    c(case_script, row$repo, row$mode, output),
    stdout = stdout, stderr = stderr, cleanup = TRUE
  )
  peak_rss <- 0
  while (process$is_alive()) {
    memory <- tryCatch(
      ps::ps_memory_info(ps::ps_handle(process$get_pid()))[["rss"]],
      error = function(e) NA_real_
    )
    if (is.finite(memory)) peak_rss <- max(peak_rss, memory)
    process$poll_io(100)
  }
  status <- process$get_exit_status()
  message <- paste(readLines(stderr, warn = FALSE), collapse = "\n")
  if (!identical(status, 0L)) stop("Case failed: ", arm, "; ", message)
  value <- jsonlite::read_json(output, simplifyVector = TRUE)
  data.frame(
    attempt = attempt, rep = rep, arm = arm,
    position = match(arm, orders[[(rep - 1L) %% 3L + 1L]]),
    repo_commit = value$repo_commit, elapsed_s = value$elapsed_s,
    peak_rss_bytes = peak_rss,
    fills_rows = value$fills$rows, fills_hash = value$fills$hash,
    equity_rows = value$equity$rows, equity_hash = value$equity$hash,
    state_rows = value$strategy_state$rows,
    state_hash = value$strategy_state$hash,
    stringsAsFactors = FALSE
  )
}

run_attempt <- function(attempt) {
  rows <- list()
  for (rep in seq_len(reps)) {
    order <- orders[[(rep - 1L) %% 3L + 1L]]
    for (arm in order) {
      rows[[length(rows) + 1L]] <- run_child(arm, rep, attempt)
      utils::write.csv(
        do.call(rbind, rows), file.path(out_dir, "measurements.partial.csv"),
        row.names = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

summarize <- function(rows) {
  medians <- vapply(split(rows$elapsed_s, rows$arm), median, numeric(1))
  data.frame(
    attempt = rows$attempt[[1L]],
    pre_cut_bundle_median_s = medians[["pre_cut_bundle"]],
    candidate_bundle_median_s = medians[["candidate_bundle"]],
    candidate_plane_median_s = medians[["candidate_plane"]],
    plane_over_candidate_loop =
      medians[["candidate_plane"]] / medians[["candidate_bundle"]],
    candidate_loop_over_pre_cut_loop =
      medians[["candidate_bundle"]] / medians[["pre_cut_bundle"]],
    stringsAsFactors = FALSE
  )
}

measurements <- run_attempt("initial")
summary <- summarize(measurements)
failed <- summary$plane_over_candidate_loop > 0.90 ||
  summary$candidate_loop_over_pre_cut_loop > 1.05
if (failed) {
  retry <- run_attempt("retry")
  measurements <- rbind(measurements, retry)
  summary <- rbind(summary, summarize(retry))
}
selected <- summary[nrow(summary), , drop = FALSE]
semantic_columns <- c(
  "fills_rows", "fills_hash", "equity_rows", "equity_hash", "state_rows",
  "state_hash"
)
parity <- vapply(
  semantic_columns,
  function(name) length(unique(measurements[[name]])) == 1L,
  logical(1)
)
decision <- data.frame(
  parity = all(parity),
  plane_gate = selected$plane_over_candidate_loop <= 0.90,
  loop_gate = selected$candidate_loop_over_pre_cut_loop <= 1.05,
  retry = if (nrow(summary) == 1L) "not_triggered" else "completed",
  stringsAsFactors = FALSE
)

utils::write.csv(
  measurements, file.path(out_dir, "measurements.csv"), row.names = FALSE
)
utils::write.csv(summary, file.path(out_dir, "summary.csv"), row.names = FALSE)
utils::write.csv(
  data.frame(surface = names(parity), identical = unname(parity)),
  file.path(out_dir, "parity.csv"), row.names = FALSE
)
utils::write.csv(decision, file.path(out_dir, "decision.csv"), row.names = FALSE)
writeLines(c(
  paste("Rscript", shQuote(case_script), "<repo> <bundle|plane> <output.json>"),
  paste(
    "Rscript", shQuote(file.path(script_dir, "run_record.R")),
    shQuote(pre_cut_repo), shQuote(candidate_repo), shQuote(out_dir), reps
  )
), file.path(out_dir, "commands.txt"))
unlink(file.path(out_dir, "measurements.partial.csv"))
print(summary, row.names = FALSE)
print(decision, row.names = FALSE)
if (!all(unlist(decision[1L, c("parity", "plane_gate", "loop_gate")]))) {
  stop("WS16 performance or parity gate failed.")
}
