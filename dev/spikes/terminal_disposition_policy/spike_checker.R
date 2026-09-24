args <- commandArgs(trailingOnly = TRUE)
repo_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)

arg_value <- function(flag, default = NULL) {
  at <- match(flag, args)
  if (is.na(at)) return(default)
  if (at == length(args)) stop(sprintf("%s needs a value", flag), call. = FALSE)
  args[[at + 1L]]
}

spike_root <- file.path(repo_root, "dev", "spikes", "terminal_disposition_policy")
runner <- arg_value("--runner", file.path(spike_root, "spike_runner.R"))
evidence_dir <- arg_value("--evidence", file.path(spike_root, "evidence"))

git_config <- tempfile("ledgr-terminal-policy-checker-gitconfig-")
writeLines(c("[safe]", paste0("\tdirectory = ", repo_root)), git_config)
Sys.setenv(GIT_CONFIG_GLOBAL = git_config)
on.exit(unlink(git_config, force = TRUE), add = TRUE)

scope_status <- function() {
  scope <- c("R", "src", "tests", "NAMESPACE", "DESCRIPTION", "man", "inst/design")
  out <- system2(
    "git",
    c(
      "-C", shQuote(repo_root), "status", "--porcelain=v1",
      "--untracked-files=all", "--", scope
    ),
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(out, "status")
  if (!is.null(status) && status != 0L) {
    stop(paste(out, collapse = "\n"), call. = FALSE)
  }
  sort(out)
}

run_runner <- function(destination, gut = FALSE) {
  dir.create(destination, recursive = TRUE, showWarnings = FALSE)
  command <- c(shQuote(runner), "--output-dir", shQuote(destination))
  if (gut) command <- c(command, "--gut-disposition")
  out <- system2(
    file.path(R.home("bin"), "Rscript.exe"),
    command,
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(out, "status")
  if (!is.null(status) && status != 0L) {
    stop(paste(out, collapse = "\n"), call. = FALSE)
  }
  out
}

read_bytes <- function(path) {
  readBin(path, what = "raw", n = file.info(path)$size)
}

compare_dirs <- function(left, right) {
  left_files <- sort(list.files(left, pattern = "[.]csv$", full.names = FALSE))
  right_files <- sort(list.files(right, pattern = "[.]csv$", full.names = FALSE))
  if (!identical(left_files, right_files)) {
    stop("Evidence file inventories differ.", call. = FALSE)
  }
  differs <- vapply(left_files, function(name) {
    !identical(read_bytes(file.path(left, name)), read_bytes(file.path(right, name)))
  }, logical(1))
  list(files = left_files, differs = differs)
}

assert <- function(value, message) {
  if (!isTRUE(value)) stop(message, call. = FALSE)
  invisible(TRUE)
}

required <- c("cases.csv", "resume_parity.csv")
assert(
  identical(
    sort(list.files(evidence_dir, pattern = "[.]csv$", full.names = FALSE)),
    required
  ),
  "Recorded evidence inventory is incomplete."
)
assert(file.exists(runner), "Spike runner is missing.")

before <- scope_status()
rerun_dir <- tempfile("ledgr-terminal-policy-rerun-")
gut_dir <- tempfile("ledgr-terminal-policy-gut-")
on.exit(unlink(c(rerun_dir, gut_dir), recursive = TRUE, force = TRUE), add = TRUE)

run_runner(rerun_dir)
rerun <- compare_dirs(evidence_dir, rerun_dir)
assert(!any(rerun$differs), sprintf(
  "Deterministic rerun differs: %s",
  paste(rerun$files[rerun$differs], collapse = ", ")
))

recorded <- utils::read.csv(
  file.path(evidence_dir, "cases.csv"),
  stringsAsFactors = FALSE,
  na.strings = ""
)
parity <- utils::read.csv(
  file.path(evidence_dir, "resume_parity.csv"),
  stringsAsFactors = FALSE
)
assert(nrow(recorded) == 5L, "The record must contain five cases.")
assert(nrow(parity) == 5L, "Resume parity must contain five surfaces.")

accepted_ids <- c("current_mark", "stale_mark", "resumed_current_mark")
accepted <- recorded[recorded$case_id %in% accepted_ids, , drop = FALSE]
assert(
  nrow(accepted) == 3L &&
    all(accepted$final_status == "DONE") &&
    all(accepted$disposition_fill_rows == 1L) &&
    all(accepted$settlement_diagnostic_rows == 1L) &&
    all(accepted$stopped_diagnostic_rows == 0L) &&
    all(accepted$quantity == 2) &&
    all(accepted$price == 100) &&
    all(accepted$position_before == 2) &&
    all(accepted$position_after == 0) &&
    all(accepted$policy_id_recorded) &&
    all(accepted$final_cash == 1200) &&
    all(accepted$final_equity == 1200),
  "A disposition case no longer carries the observed accounting result."
)
assert(
  identical(
    accepted$mark_source[match(c("current_mark", "stale_mark"), accepted$case_id)],
    c("current_close", "stale_close")
  ) && identical(
    accepted$mark_age[match(c("current_mark", "stale_mark"), accepted$case_id)],
    c(0L, 1L)
  ),
  "Current and stale provenance changed."
)
refused <- recorded[
  recorded$case_id %in% c("strict_control", "no_permissible_mark"),
  ,
  drop = FALSE
]
assert(
  nrow(refused) == 2L &&
    all(refused$final_status == "INCOMPLETE") &&
    all(refused$stop_reason == "terminal_settlement_unsupported") &&
    all(refused$disposition_fill_rows == 0L) &&
    all(refused$settlement_diagnostic_rows == 0L) &&
    all(refused$stopped_diagnostic_rows == 1L),
  "Strict or markless behavior no longer fails closed."
)
resume_row <- recorded[recorded$case_id == "resumed_current_mark", , drop = FALSE]
assert(
  nrow(resume_row) == 1L && resume_row$first_status == "RUNNING",
  "The resume case no longer interrupts before disposition."
)
assert(
  all(recorded$reopen_events_identical) &&
    all(recorded$reopen_equity_identical) &&
    all(recorded$reopen_diagnostics_identical),
  "A reopened public surface differs from its completed run."
)
assert(
  all(parity$identical_after_identity_exclusions) &&
    all(parity$max_abs_numeric_difference == 0),
  "Direct and resumed public surfaces differ."
)

run_runner(gut_dir, gut = TRUE)
gut <- compare_dirs(evidence_dir, gut_dir)
assert(any(gut$differs), "Gutted disposition did not change evidence bytes.")
gutted <- utils::read.csv(
  file.path(gut_dir, "cases.csv"),
  stringsAsFactors = FALSE,
  na.strings = ""
)
for (case_id in c("current_mark", "resumed_current_mark")) {
  observed <- recorded[recorded$case_id == case_id, , drop = FALSE]
  removed <- gutted[gutted$case_id == case_id, , drop = FALSE]
  assert(
    nrow(observed) == 1L && nrow(removed) == 1L &&
      observed$final_status == "DONE" &&
      removed$final_status == "INCOMPLETE" &&
      removed$stop_reason == "terminal_settlement_unsupported" &&
      observed$disposition_fill_rows == 1L &&
      removed$disposition_fill_rows == 0L &&
      observed$settlement_diagnostic_rows == 1L &&
      removed$settlement_diagnostic_rows == 0L &&
      observed$final_cash == 1200 && removed$final_cash == 1000 &&
      observed$final_equity == 1200 && removed$final_equity == 1200,
    sprintf("The gut did not remove the measured disposition in %s.", case_id)
  )
}

after <- scope_status()
assert(identical(before, after), "Package or design scope changed during checking.")

cat("TERMINAL_DISPOSITION_POLICY_CHECKS_OK: 15 checks\n")
cat(sprintf("RERUN_BYTE_EXACT: %s\n", paste(rerun$files, collapse = ", ")))
cat(sprintf(
  "GUT_DETECTED: %s\n",
  paste(gut$files[gut$differs], collapse = ", ")
))
cat("PACKAGE_SCOPE_UNCHANGED\n")
