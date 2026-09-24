#!/usr/bin/env Rscript

repo_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
rscript <- "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe"
runner <- file.path(
  repo_root, "dev", "spikes", "settlement_quantity_primitive",
  "spike_runner.R"
)
recorded <- file.path(
  repo_root, "dev", "spikes", "settlement_quantity_primitive",
  "evidence", "cases.csv"
)

git_config <- tempfile("ledgr-spike-gitconfig-")
writeLines(
  c("[safe]", paste0("\tdirectory = ", repo_root)),
  con = git_config,
  sep = "\n",
  useBytes = TRUE
)
Sys.setenv(GIT_CONFIG_GLOBAL = git_config)
on.exit(unlink(git_config, force = TRUE), add = TRUE)

package_scope_status <- function() {
  out <- system2(
    "git",
    c(
      "-C", shQuote(repo_root), "status", "--porcelain=v1",
      "--untracked-files=all", "--", "R", "src", "tests",
      "NAMESPACE", "DESCRIPTION", "man", "inst/design"
    ),
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(out, "status")
  if (!is.null(status) && status != 0L) {
    stop(paste(out, collapse = "\n"), call. = FALSE)
  }
  out
}

run_runner <- function(output_dir, gut = FALSE) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  run_args <- c(runner)
  if (gut) run_args <- c(run_args, "--gut-operation3")
  run_args <- c(run_args, "--output-dir", output_dir)
  out <- system2(
    rscript,
    vapply(run_args, shQuote, character(1)),
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(out, "status")
  if (is.null(status)) status <- 0L
  if (status != 0L) {
    stop(paste(out, collapse = "\n"), call. = FALSE)
  }
  invisible(out)
}

read_bytes <- function(path) {
  size <- file.info(path)$size
  if (is.na(size)) stop(sprintf("Missing evidence file: %s", path), call. = FALSE)
  readBin(path, what = "raw", n = size)
}

first_differing_line <- function(left, right) {
  left_lines <- readLines(left, warn = FALSE)
  right_lines <- readLines(right, warn = FALSE)
  n <- max(length(left_lines), length(right_lines))
  for (i in seq_len(n)) {
    lhs <- if (i <= length(left_lines)) left_lines[[i]] else "<missing>"
    rhs <- if (i <= length(right_lines)) right_lines[[i]] else "<missing>"
    if (!identical(lhs, rhs)) {
      return(sprintf("line %d\nrecorded: %s\nrerun:   %s", i, lhs, rhs))
    }
  }
  "no textual difference"
}

before <- package_scope_status()
scratch <- tempfile("ledgr-settlement-check-")
gut_scratch <- tempfile("ledgr-settlement-gut-check-")
dir.create(scratch, recursive = TRUE)
dir.create(gut_scratch, recursive = TRUE)
on.exit(unlink(scratch, recursive = TRUE, force = TRUE), add = TRUE)
on.exit(unlink(gut_scratch, recursive = TRUE, force = TRUE), add = TRUE)

run_runner(scratch)
rerun <- file.path(scratch, "cases.csv")
if (!identical(read_bytes(recorded), read_bytes(rerun))) {
  stop(
    paste("Recorded evidence differs from the rerun:",
          first_differing_line(recorded, rerun), sep = "\n"),
    call. = FALSE
  )
}

run_runner(gut_scratch, gut = TRUE)
gut_file <- file.path(gut_scratch, "cases.csv")
if (identical(read_bytes(recorded), read_bytes(gut_file))) {
  stop("Gutting the operation-3 classifier did not change evidence.", call. = FALSE)
}
normal <- utils::read.csv(recorded, stringsAsFactors = FALSE)
gutted <- utils::read.csv(gut_file, stringsAsFactors = FALSE)
normal_case_1 <- normal[normal$case_id == "case_1", , drop = FALSE]
gutted_case_1 <- gutted[gutted$case_id == "case_1", , drop = FALSE]
normal_case_7 <- normal[normal$case_id == "case_7", , drop = FALSE]
gutted_case_7 <- gutted[gutted$case_id == "case_7", , drop = FALSE]
if (nrow(normal_case_1) != 1L || nrow(gutted_case_1) != 1L ||
    normal_case_1$operation3_count != 1L ||
    gutted_case_1$operation3_count != 0L) {
  stop("The gut did not remove the baseline operation-3 classification.", call. = FALSE)
}
if (nrow(normal_case_7) != 1L || nrow(gutted_case_7) != 1L ||
    normal_case_7$fold_status != "ERROR" ||
    gutted_case_7$fold_status != "DONE") {
  stop("The gut did not disable malformed operation-3 rejection.", call. = FALSE)
}

after <- package_scope_status()
if (!identical(before, after)) {
  stop(
    paste(
      "Package-scope status changed during the checker.",
      "Before:", paste(before, collapse = "\n"),
      "After:", paste(after, collapse = "\n"),
      sep = "\n"
    ),
    call. = FALSE
  )
}

message("SETTLEMENT_QUANTITY_PRIMITIVE_CHECKER_OK")
message("Recorded CSV reproduced byte-for-byte; operation-3 gut failed loudly.")
