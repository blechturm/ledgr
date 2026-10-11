# LDG-2992 compiled availability-accounting spike checker.
#
# Rscript spike_checker.R <ledgr_repo>
#
# Builds a scratch tree from the spike branch, reruns normal and gutted arms,
# diffs deterministic case evidence, checks parity and the gut, and proves the
# rerun did not alter package or design scope.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) stop("usage: spike_checker.R <ledgr_repo>")
repo <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
spike <- file.path(repo, "dev/spikes/compiled_availability_accounting")
recorded <- file.path(spike, "evidence")
rscript <- file.path(R.home("bin"), "Rscript")
failures <- character()
fail <- function(...) failures <<- c(failures, paste0(...))

git <- function(...) {
  suppressWarnings(system2(
    "git", c("-C", shQuote(repo), ...), stdout = TRUE, stderr = TRUE
  ))
}
scope <- c("R", "src", "tests", "NAMESPACE", "DESCRIPTION", "man", "inst/design")
status_before <- git("status", "--porcelain", "--", scope)

scratch <- tempfile("ldg2992-check-")
dir.create(scratch, recursive = TRUE)
tree <- file.path(scratch, "tree")
dir.create(tree)
archive <- file.path(scratch, "tree.tar")
archive_status <- system2(
  "git",
  c("-C", shQuote(repo), "archive", "--format=tar", "-o", shQuote(archive), "HEAD"),
  stdout = FALSE,
  stderr = FALSE
)
if (!identical(archive_status, 0L)) stop("could not archive the spike branch")
utils::untar(archive, exdir = tree)

run <- function(name, gut = FALSE) {
  out <- file.path(scratch, name)
  cmd <- c(
    shQuote(file.path(tree, "dev/spikes/compiled_availability_accounting/spike_runner.R")),
    shQuote(tree), shQuote(out), if (gut) "--gut" else character()
  )
  code <- system2(rscript, cmd, stdout = FALSE, stderr = FALSE)
  if (!identical(code, 0L)) fail(name, " runner exited ", code)
  out
}
normal_dir <- run("normal")
gut_dir <- run("gut", gut = TRUE)

same_file <- function(a, b) {
  if (!file.exists(a) || !file.exists(b)) return(FALSE)
  identical(
    gsub("\r\n", "\n", paste(readLines(a, warn = FALSE), collapse = "\n")),
    gsub("\r\n", "\n", paste(readLines(b, warn = FALSE), collapse = "\n"))
  )
}
if (!same_file(file.path(recorded, "cases.csv"), file.path(normal_dir, "cases.csv"))) {
  fail("normal rerun differs from recorded cases.csv")
}

read_cases <- function(path) {
  utils::read.csv(file.path(path, "cases.csv"), stringsAsFactors = FALSE)
}
normal <- read_cases(normal_dir)
gutted <- read_cases(gut_dir)
evidence_cols <- setdiff(names(normal), c("case", "arm"))
case_names <- unique(normal$case)
for (case_name in case_names) {
  rows <- normal[normal$case == case_name, , drop = FALSE]
  if (!identical(rows$arm, c("canonical", "hybrid"))) {
    fail(case_name, ": missing or reordered canonical/hybrid arms")
    next
  }
  unequal <- evidence_cols[!vapply(
    evidence_cols,
    function(name) identical(rows[[name]][[1L]], rows[[name]][[2L]]),
    logical(1)
  )]
  if (length(unequal)) {
    fail(case_name, ": canonical and hybrid differ in ", paste(unequal, collapse = ", "))
  }
}

normal_key <- paste(normal$case, normal$arm)
gut_key <- paste(gutted$case, gutted$arm)
gutted <- gutted[match(normal_key, gut_key), , drop = FALSE]
canonical <- normal$arm == "canonical"
if (!identical(normal[canonical, evidence_cols], gutted[canonical, evidence_cols])) {
  fail("gut changed canonical evidence")
}
hybrid <- normal$arm == "hybrid"
gut_detected <- normal$events_json[hybrid] != gutted$events_json[hybrid]
if (!all(gut_detected)) {
  fail("gut did not change hybrid event evidence for: ", paste(normal$case[hybrid][!gut_detected], collapse = ", "))
}

check_clocks <- function(path) {
  value <- utils::read.csv(file.path(path, "clocks.csv"), stringsAsFactors = FALSE)
  expected_keys <- paste(rep(case_names, each = 2L), rep(c("canonical", "hybrid"), length(case_names)))
  if (!identical(paste(value$case, value$arm), expected_keys)) fail("clock rows are missing or reordered")
  if (any(!is.finite(value$elapsed_seconds)) || any(value$elapsed_seconds < 0) ||
      any(!is.finite(value$engine_seconds)) || any(value$engine_seconds < 0)) {
    fail("clock values are not finite non-negative seconds")
  }
}
check_clocks(normal_dir)

sharadar_path <- file.path(recorded, "sharadar_clocks.csv")
if (!file.exists(sharadar_path)) {
  fail("recorded aggregate Sharadar clocks are missing")
} else {
  sharadar <- utils::read.csv(sharadar_path, stringsAsFactors = FALSE)
  expected_columns <- c(
    "workload", "repetition", "canonical_order", "hybrid_order",
    "canonical_elapsed_seconds", "hybrid_elapsed_seconds", "elapsed_ratio",
    "canonical_engine_seconds", "hybrid_engine_seconds", "engine_ratio",
    "economic_outputs_equal"
  )
  if (!identical(names(sharadar), expected_columns)) {
    fail("aggregate Sharadar clock columns differ from the declared schema")
  } else {
    expected_keys <- c(
      "momentum 1", "momentum 2", "equal_weight 1", "equal_weight 2"
    )
    if (!identical(paste(sharadar$workload, sharadar$repetition), expected_keys)) {
      fail("aggregate Sharadar clock rows are missing or reordered")
    }
    numeric_columns <- c(
      "canonical_elapsed_seconds", "hybrid_elapsed_seconds",
      "canonical_engine_seconds", "hybrid_engine_seconds"
    )
    if (any(!is.finite(as.matrix(sharadar[numeric_columns]))) ||
        any(as.matrix(sharadar[numeric_columns]) <= 0)) {
      fail("aggregate Sharadar clocks are not finite positive seconds")
    }
    expected_elapsed <- round(
      sharadar$hybrid_elapsed_seconds / sharadar$canonical_elapsed_seconds,
      4L
    )
    expected_engine <- round(
      sharadar$hybrid_engine_seconds / sharadar$canonical_engine_seconds,
      4L
    )
    if (!identical(sharadar$elapsed_ratio, expected_elapsed) ||
        !identical(sharadar$engine_ratio, expected_engine)) {
      fail("aggregate Sharadar ratios do not recompute from their clocks")
    }
    if (!identical(sharadar$canonical_order, c(1L, 2L, 1L, 2L)) ||
        !identical(sharadar$hybrid_order, c(2L, 1L, 2L, 1L))) {
      fail("aggregate Sharadar arms did not alternate order")
    }
    if (!all(sharadar$economic_outputs_equal)) {
      fail("aggregate Sharadar evidence records an economic divergence")
    }
  }
}

status_after <- git("status", "--porcelain", "--", scope)
if (!identical(status_before, status_after)) {
  fail("package or design scope changed during the rerun")
}
fork_files <- git("diff", "--name-only", "437b73d3", "HEAD", "--", scope)
expected_fork <- sort(c("R/compiled-spot-fifo.R", "R/fold-engine.R", "R/sweep.R"))
if (!identical(sort(fork_files), expected_fork)) {
  fail("fork package scope differs from the three declared seam files: ", paste(fork_files, collapse = ", "))
}

r_files <- c(
  file.path(spike, "probe.R"),
  file.path(spike, "spike_runner.R"),
  file.path(spike, "spike_checker.R")
)
r_lines <- sum(vapply(r_files, function(path) length(readLines(path, warn = FALSE)), integer(1)))
if (r_lines > 1500L) fail("R harness exceeds 1,500 lines: ", r_lines)
if (length(case_names) > 10L) fail("case count exceeds ten: ", length(case_names))

cat("Cases:", paste(case_names, collapse = ", "), "\n")
cat("Gut changed hybrid event evidence:", paste(normal$case[hybrid][gut_detected], collapse = ", "), "\n")
cat("R harness lines:", r_lines, "\n")
if (length(failures)) {
  cat("SPIKE CHECK FAILED\n", paste("-", failures, collapse = "\n"), "\n")
  quit(status = 1L)
}
cat("SPIKE CHECK OK: rerun exact, three parity cases equal, gut detected, scope clean\n")
