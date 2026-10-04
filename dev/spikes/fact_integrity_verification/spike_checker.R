args <- commandArgs(trailingOnly = TRUE)
repo <- if (length(args) >= 1L) normalizePath(args[[1L]], winslash = "/") else "."
recorded <- if (length(args) >= 2L) args[[2L]] else file.path(
  repo,
  "dev/spikes/fact_integrity_verification/evidence"
)
runner <- file.path(repo, "dev/spikes/fact_integrity_verification/spike_runner.R")
rscript <- file.path(R.home("bin"), "Rscript.exe")
if (!file.exists(rscript)) rscript <- file.path(R.home("bin"), "Rscript")

scope_status <- function() {
  original_home <- Sys.getenv("HOME", unset = NA_character_)
  user_home <- Sys.getenv("USERPROFILE", unset = "")
  if (nzchar(user_home)) Sys.setenv(HOME = user_home)
  on.exit({
    if (is.na(original_home)) {
      Sys.unsetenv("HOME")
    } else {
      Sys.setenv(HOME = original_home)
    }
  }, add = TRUE)
  result <- system2(
    "git",
    c(
      "-C", shQuote(repo), "status", "--porcelain", "--",
      "R", "src", "tests", "NAMESPACE", "DESCRIPTION", "man"
    ),
    stdout = TRUE,
    stderr = TRUE
  )
  exit <- attr(result, "status")
  if (!is.null(exit) && exit != 0L) {
    stop(paste("Git scope guard failed:", paste(result, collapse = "\n")))
  }
  result
}

run <- function(out, gut = FALSE) {
  call_args <- c(runner, repo, out)
  if (gut) call_args <- c(call_args, "--gut")
  status <- system2(rscript, call_args, stdout = TRUE, stderr = TRUE)
  exit <- attr(status, "status")
  if (is.null(exit)) exit <- 0L
  if (exit != 0L) stop(paste(status, collapse = "\n"))
  invisible(status)
}

before <- scope_status()
scratch <- tempfile("fact-integrity-check-")
gut_dir <- tempfile("fact-integrity-gut-")
dir.create(scratch)
dir.create(gut_dir)
on.exit(unlink(c(scratch, gut_dir), recursive = TRUE, force = TRUE), add = TRUE)

run(scratch)
if (!identical(
  readLines(file.path(recorded, "cases.csv"), warn = FALSE),
  readLines(file.path(scratch, "cases.csv"), warn = FALSE)
)) {
  stop("Deterministic case evidence differs from the recorded CSV.")
}
summary <- utils::read.csv(file.path(scratch, "summary.csv"))
if (!isTRUE(summary$gate_passed[[1L]])) stop("The rerun did not clear the gate.")

run(gut_dir, gut = TRUE)
if (identical(
  readLines(file.path(recorded, "cases.csv"), warn = FALSE),
  readLines(file.path(gut_dir, "cases.csv"), warn = FALSE)
)) {
  stop("The gutted timestamp path did not change deterministic evidence.")
}
gut_cases <- utils::read.csv(file.path(gut_dir, "cases.csv"))
if (!any(gut_cases$candidate_status == "error")) {
  stop("The gutted timestamp path did not fail exact verification.")
}

after <- scope_status()
if (!identical(before, after)) stop("The spike changed guarded package scope.")
cat("FACT_INTEGRITY_SPIKE_CHECKS_OK\n")
