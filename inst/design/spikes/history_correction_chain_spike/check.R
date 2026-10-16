#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
repo <- normalizePath(if (length(args)) args[[1L]] else ".", winslash = "/", mustWork = TRUE)
spike_rel <- "inst/design/spikes/history_correction_chain_spike"
spike <- file.path(repo, spike_rel)
runner <- file.path(spike, "run.R")
recorded <- file.path(spike, "evidence")
rscript <- file.path(R.home("bin"), "Rscript.exe")
if (!file.exists(rscript)) rscript <- file.path(R.home("bin"), "Rscript")

failures <- character()
fail <- function(...) failures <<- c(failures, paste0(...))

scope_state <- function() {
  scope <- file.path(repo, c(
    "R", "src", "tests", "NAMESPACE", "DESCRIPTION", "man", "inst/design"
  ))
  files <- unlist(lapply(scope, function(path) {
    if (dir.exists(path)) {
      list.files(path, recursive = TRUE, full.names = TRUE, all.files = TRUE)
    } else if (file.exists(path)) {
      path
    } else {
      character()
    }
  }), use.names = FALSE)
  files <- sort(files[file.info(files)$isdir %in% FALSE], method = "radix")
  stats::setNames(
    unname(tools::md5sum(files)),
    substring(normalizePath(files, winslash = "/"), nchar(repo) + 2L)
  )
}

run_spike <- function(output, gut = "none") {
  cmd <- c(
    shQuote(runner),
    paste0("--package-root=", shQuote(repo)),
    paste0("--output=", shQuote(output)),
    paste0("--gut=", gut)
  )
  result <- suppressWarnings(system2(rscript, cmd, stdout = TRUE, stderr = TRUE))
  status <- attr(result, "status")
  if (is.null(status)) status <- 0L
  if (status != 0L) {
    fail("runner exited ", status, ": ", paste(result, collapse = " | "))
  }
  invisible(result)
}

same_text <- function(left, right) {
  if (!file.exists(left) || !file.exists(right)) return(FALSE)
  normalize <- function(path) paste(readLines(path, warn = FALSE), collapse = "\n")
  identical(normalize(left), normalize(right))
}

before <- scope_state()
normal <- tempfile("history-chain-normal-")
gutted <- tempfile("history-chain-gut-")
dir.create(normal)
dir.create(gutted)
on.exit(unlink(c(normal, gutted), recursive = TRUE, force = TRUE), add = TRUE)

run_spike(normal)
run_spike(gutted, "drop_private_supersession")

evidence_files <- c(
  "case_results.csv", "timeline.csv", "classifier.csv", "derived_findings.csv"
)
for (name in evidence_files) {
  if (!same_text(file.path(recorded, name), file.path(normal, name))) {
    fail("normal rerun differs from recorded ", name)
  }
}

cases <- utils::read.csv(file.path(normal, "case_results.csv"), stringsAsFactors = FALSE)
expected_cases <- c(
  "direct_full", "linear_monotone", "linear_out_of_order",
  "competing_descendants", "partial_coverage", "overextended_coverage",
  "dangling_reference", "cycle", "ancestor_and_sibling"
)
if (!identical(cases$case_id, expected_cases)) {
  fail("case matrix is missing or reordered")
}
if (nrow(cases) > 10L) fail("case count exceeds the ten-case protocol cap")
accepted <- cases$constructor_outcome == "accepted"
if (!all(cases$public_seal_run_outcome[accepted] == "accepted")) {
  fail("a constructor-accepted case did not complete the public seal/run path")
}
if (!all(cases$public_seal_run_outcome[!accepted] == "not_reached")) {
  fail("a constructor-refused case was presented as a public runtime result")
}

timeline <- utils::read.csv(file.path(normal, "timeline.csv"), stringsAsFactors = FALSE)
private_counts <- table(timeline$case_id[timeline$observation_layer == "private_prepared_resolver"])
if (!identical(as.integer(private_counts[expected_cases]), rep(7L, length(expected_cases)))) {
  fail("each case must carry seven private resolver observations")
}
public_cases <- unique(timeline$case_id[timeline$observation_layer == "public_run_availability"])
if (!identical(public_cases, cases$case_id[accepted])) {
  fail("public runtime timelines do not match constructor-accepted cases")
}

derived <- utils::read.csv(file.path(normal, "derived_findings.csv"), stringsAsFactors = FALSE)
if (nrow(derived) != 11L || !all(derived$observed)) {
  fail("the normal run does not reproduce all eleven derived observations")
}

gut_timeline <- file.path(gutted, "timeline.csv")
if (same_text(file.path(normal, "timeline.csv"), gut_timeline)) {
  fail("the gutted supersession path did not change timeline evidence")
}
gut_derived <- utils::read.csv(file.path(gutted, "derived_findings.csv"), stringsAsFactors = FALSE)
if (all(gut_derived$observed)) {
  fail("the gutted supersession path did not falsify any derived observation")
}

after <- scope_state()
if (!identical(before, after)) fail("package or design scope changed during rerun")

r_files <- c(runner, file.path(spike, "check.R"), file.path(spike, "gut_demo.R"))
r_lines <- sum(vapply(r_files, function(path) length(readLines(path, warn = FALSE)), integer(1)))
if (r_lines > 1500L) fail("R harness exceeds 1,500 lines: ", r_lines)

cat("Cases:", paste(cases$case_id, collapse = ", "), "\n")
cat("Derived observations:", sum(derived$observed), "of", nrow(derived), "\n")
cat("Gut falsified:", paste(gut_derived$finding[!gut_derived$observed], collapse = ", "), "\n")
cat("R harness lines:", r_lines, "\n")
if (length(failures)) {
  cat("HISTORY_CORRECTION_CHAIN_CHECK_FAILED\n", paste("-", failures, collapse = "\n"), "\n")
  quit(status = 1L)
}
cat("HISTORY_CORRECTION_CHAIN_CHECK_OK\n")
