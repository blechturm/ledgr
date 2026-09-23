#!/usr/bin/env Rscript

repo_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
rscript <- "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe"
runner <- file.path(
  repo_root, "dev", "spikes", "settlement_class_b_atomic", "spike_runner.R"
)
recorded <- file.path(
  repo_root, "dev", "spikes", "settlement_class_b_atomic",
  "evidence", "cases.csv"
)

git_config <- tempfile("ledgr-class-b-check-gitconfig-")
writeLines(c("[safe]", paste0("\tdirectory = ", repo_root)), git_config)
Sys.setenv(GIT_CONFIG_GLOBAL = git_config)
on.exit(unlink(git_config, force = TRUE), add = TRUE)

package_scope_status <- function() {
  out <- system2(
    "git",
    c("status", "--porcelain=v1", "--untracked-files=all", "--",
      "R", "src", "tests", "NAMESPACE", "DESCRIPTION", "man", "inst/design"),
    stdout = TRUE,
    stderr = TRUE
  )
  if (!is.null(attr(out, "status")) && attr(out, "status") != 0L) {
    stop(paste(out, collapse = "\n"), call. = FALSE)
  }
  out
}

run_once <- function(output_dir, gut = FALSE) {
  call_args <- c(runner, "--output-dir", output_dir)
  if (gut) call_args <- c(call_args, "--gut-parent-consumption")
  out <- system2(
    rscript,
    vapply(call_args, shQuote, character(1)),
    stdout = TRUE,
    stderr = TRUE
  )
  if (!is.null(attr(out, "status")) && attr(out, "status") != 0L) {
    stop(paste(out, collapse = "\n"), call. = FALSE)
  }
}

bytes <- function(path) {
  size <- file.info(path)$size
  if (is.na(size)) stop("Missing evidence file: ", path, call. = FALSE)
  readBin(path, what = "raw", n = size)
}

before <- package_scope_status()
normal_dir <- tempfile("class-b-normal-")
gut_dir <- tempfile("class-b-gut-")
on.exit(unlink(normal_dir, recursive = TRUE, force = TRUE), add = TRUE)
on.exit(unlink(gut_dir, recursive = TRUE, force = TRUE), add = TRUE)

run_once(normal_dir)
rerun <- file.path(normal_dir, "cases.csv")
if (!identical(bytes(recorded), bytes(rerun))) {
  stop("Class B evidence did not reproduce byte-for-byte.", call. = FALSE)
}

run_once(gut_dir, gut = TRUE)
gut_file <- file.path(gut_dir, "cases.csv")
if (identical(bytes(recorded), bytes(gut_file))) {
  stop("Gutting parent-lot consumption did not change evidence.", call. = FALSE)
}
gutted <- utils::read.csv(gut_file, stringsAsFactors = FALSE)
if (nrow(gutted) != 1L || gutted$case_id[[1L]] != "case_1_stock" ||
    gutted$status[[1L]] != "ERROR" ||
    gutted$error_class[[1L]] != "ledgr_settlement_basis_invariant" ||
    gutted$event_count[[1L]] != 0L) {
  stop("The parent-consumption gut did not fail before append.", call. = FALSE)
}

after <- package_scope_status()
if (!identical(before, after)) {
  stop("Package-scope Git status changed during the checker.", call. = FALSE)
}
cat("CLASS_B_ATOMIC_CHECKER_OK: rerun matched; parent gut failed.\n")
