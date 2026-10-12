#!/usr/bin/env Rscript

check_stop <- function(message) stop(message, call. = FALSE)

script_path <- function() {
  value <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(value) != 1L) check_stop("Cannot identify checker path.")
  normalizePath(sub("^--file=", "", value), winslash = "/")
}

windows_to_wsl <- function(path) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  paste0("/mnt/", tolower(substr(path, 1L, 1L)), substring(path, 3L))
}

run_command <- function(command, args) {
  output <- system2(command, args, stdout = TRUE, stderr = TRUE)
  status <- attr(output, "status")
  if (!is.null(status) && status != 0L) {
    check_stop(paste(c("Command failed:", output), collapse = "\n"))
  }
  output
}

scope_state <- function(root) {
  old <- setwd(root)
  on.exit(setwd(old), add = TRUE)
  system2(
    "git",
    c(
      "status", "--porcelain=v1", "--",
      "R", "src", "tests", "NAMESPACE", "DESCRIPTION", "man", "inst/design"
    ),
    stdout = TRUE,
    stderr = TRUE
  )
}

same_lines <- function(left, right) {
  identical(readLines(left, warn = FALSE), readLines(right, warn = FALSE))
}

read_csv <- function(path) {
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

check_cases <- function(path) {
  cases <- read_csv(path)
  if (nrow(cases) != 10L || anyDuplicated(cases$case)) {
    check_stop("The deterministic corpus is not the frozen ten-case corpus.")
  }
  equal <- cases$relation == "equal"
  different <- cases$relation == "different"
  if (any(cases$root[equal] != cases$comparison_root[equal]) ||
      any(cases$root[different] == cases$comparison_root[different])) {
    check_stop("A deterministic relation failed.")
  }
  hostile <- cases[cases$case == "wrong_order_refused", , drop = FALSE]
  if (nrow(hostile) != 1L || !startsWith(hostile$root, "refused: ")) {
    check_stop("Hostile order was not refused.")
  }
  cases
}

cost_summary <- function(path) {
  cost <- read_csv(path)
  required <- c(500000, 1000000, 2000000, 5000000)
  if (!identical(sort(unique(cost$rows)), required) ||
      any(table(cost$rows) != 3L)) {
    check_stop("Cost evidence has the wrong shape.")
  }
  if (any(vapply(
    split(cost$checksum, cost$rows),
    function(x) length(unique(x)) != 1L,
    logical(1)
  ))) {
    check_stop("Repeated cost checksums moved.")
  }
  medians <- aggregate(
    elapsed_seconds ~ rows,
    cost,
    stats::median
  )
  medians <- medians[order(medians$rows), , drop = FALSE]
  largest_us <- tail(medians$elapsed_seconds / medians$rows * 1e6, 1L)
  exponent <- log(
    tail(medians$elapsed_seconds, 1L) / medians$elapsed_seconds[[1L]]
  ) / log(tail(medians$rows, 1L) / medians$rows[[1L]])
  if (largest_us > 1 || exponent > 1.10) {
    check_stop(sprintf(
      "Cost gate failed: %.4f us/bar; exponent %.4f.",
      largest_us,
      exponent
    ))
  }
  list(cost = cost, largest_us = largest_us, exponent = exponent)
}

check_memory <- function(path) {
  memory <- read_csv(path)
  if (!identical(memory$case, c("bars", "facts")) ||
      !identical(memory$rows, c(5000000, 300000)) ||
      any(memory$peak_rss_bytes <= 0) ||
      memory$output_bytes[[1L]] != 64 ||
      memory$output_bytes[[2L]] <= 0) {
    check_stop("Memory evidence is incomplete.")
  }
  memory
}

checker_path <- script_path()
spike_dir <- dirname(checker_path)
root <- normalizePath(file.path(spike_dir, "..", "..", ".."), winslash = "/")
runner <- file.path(spike_dir, "spike_runner.R")
expected <- file.path(spike_dir, "evidence")
scope_before <- scope_state(root)

scratch <- tempfile("rule3-check-")
dir.create(file.path(scratch, "windows"), recursive = TRUE)
dir.create(file.path(scratch, "ubuntu"), recursive = TRUE)
on.exit(unlink(scratch, recursive = TRUE, force = TRUE), add = TRUE)

rscript <- file.path(
  R.home("bin"),
  if (identical(.Platform$OS.type, "windows")) "Rscript.exe" else "Rscript"
)
run_command(
  rscript,
  c(runner, "--all", file.path(scratch, "windows"))
)
run_command(
  "wsl",
  c(
    "-d", "Ubuntu", "--", "/usr/bin/Rscript",
    windows_to_wsl(runner), "--all",
    windows_to_wsl(file.path(scratch, "ubuntu"))
  )
)

for (platform in c("windows", "ubuntu")) {
  recorded <- file.path(expected, platform, "cases.csv")
  rerun <- file.path(scratch, platform, "cases.csv")
  if (!same_lines(recorded, rerun)) {
    check_stop(sprintf("Deterministic evidence moved on %s.", platform))
  }
}
windows_cases <- check_cases(file.path(scratch, "windows", "cases.csv"))
ubuntu_cases <- check_cases(file.path(scratch, "ubuntu", "cases.csv"))
if (!identical(windows_cases, ubuntu_cases)) {
  check_stop("Windows and Ubuntu deterministic evidence differ.")
}

windows_cost <- cost_summary(file.path(scratch, "windows", "cost.csv"))
ubuntu_cost <- cost_summary(file.path(scratch, "ubuntu", "cost.csv"))
if (!identical(
  windows_cost$cost[c("rows", "replicate", "checksum")],
  ubuntu_cost$cost[c("rows", "replicate", "checksum")]
)) {
  check_stop("Windows and Ubuntu cost checksums differ.")
}
windows_memory <- check_memory(file.path(scratch, "windows", "memory.csv"))
ubuntu_memory <- check_memory(file.path(scratch, "ubuntu", "memory.csv"))

gut <- new.env(parent = baseenv())
sys.source(runner, envir = gut)
gut$r3_compare_order <- function(frame, keys, previous_last = NULL) {
  if (nrow(frame) == 0L) previous_last else
    frame[keys][nrow(frame), , drop = FALSE]
}
gutted <- gut$r3_conformance_cases()
if (!identical(
  gutted$root[gutted$case == "wrong_order_refused"],
  "accepted"
) || identical(gutted, windows_cases)) {
  check_stop("The hostile-order gut did not change deterministic evidence.")
}

if (!identical(scope_before, scope_state(root))) {
  check_stop("Package scope changed while the checker ran.")
}

cat(sprintf(
  paste0(
    "RULE3_SPIKE_OK windows_us=%.4f windows_exp=%.4f ",
    "ubuntu_us=%.4f ubuntu_exp=%.4f ",
    "windows_bar_rss=%s ubuntu_bar_rss=%s ",
    "windows_fact_rss=%s ubuntu_fact_rss=%s\n"
  ),
  windows_cost$largest_us,
  windows_cost$exponent,
  ubuntu_cost$largest_us,
  ubuntu_cost$exponent,
  windows_memory$peak_rss_bytes[[1L]],
  ubuntu_memory$peak_rss_bytes[[1L]],
  windows_memory$peak_rss_bytes[[2L]],
  ubuntu_memory$peak_rss_bytes[[2L]]
))
