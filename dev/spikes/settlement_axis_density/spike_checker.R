args <- commandArgs(trailingOnly = TRUE)
repo_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)

arg_value <- function(flag, default = NULL) {
  at <- match(flag, args)
  if (is.na(at)) return(default)
  if (at == length(args)) stop(sprintf("%s needs a value", flag), call. = FALSE)
  args[[at + 1L]]
}

spike_root <- file.path(
  repo_root,
  "dev",
  "spikes",
  "settlement_axis_density"
)
runner <- arg_value("--runner", file.path(spike_root, "spike_runner.R"))
evidence_dir <- arg_value("--evidence", file.path(spike_root, "evidence"))

git_config <- tempfile("ledgr-density-checker-gitconfig-")
writeLines(
  c("[safe]", paste0("\tdirectory = ", repo_root)),
  con = git_config,
  useBytes = TRUE
)
Sys.setenv(GIT_CONFIG_GLOBAL = git_config)
on.exit(unlink(git_config, force = TRUE), add = TRUE)

scope_status <- function() {
  scope <- c(
    "R",
    "src",
    "tests",
    "NAMESPACE",
    "DESCRIPTION",
    "man",
    "inst/design"
  )
  out <- system2(
    "git",
    c(
      "-C",
      shQuote(repo_root),
      "status",
      "--porcelain=v1",
      "--untracked-files=all",
      "--",
      scope
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
  if (gut) command <- c(command, "--gut-injection")
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
  size <- file.info(path)$size
  readBin(path, what = "raw", n = size)
}

compare_dirs <- function(left, right) {
  left_files <- sort(list.files(left, pattern = "[.]csv$", full.names = FALSE))
  right_files <- sort(list.files(right, pattern = "[.]csv$", full.names = FALSE))
  if (!identical(left_files, right_files)) {
    stop("Evidence file inventories differ.", call. = FALSE)
  }
  differences <- vapply(left_files, function(name) {
    !identical(
      read_bytes(file.path(left, name)),
      read_bytes(file.path(right, name))
    )
  }, logical(1))
  list(files = left_files, differences = differences)
}

required <- c("cases.csv", "parity.csv")
if (!identical(
  sort(list.files(evidence_dir, pattern = "[.]csv$", full.names = FALSE)),
  required
)) {
  stop("Recorded evidence inventory is incomplete.", call. = FALSE)
}
if (!file.exists(runner)) stop("Spike runner is missing.", call. = FALSE)

before <- scope_status()
rerun_dir <- tempfile("ledgr-density-rerun-")
gut_dir <- tempfile("ledgr-density-gut-")
on.exit(unlink(c(rerun_dir, gut_dir), recursive = TRUE, force = TRUE), add = TRUE)

run_runner(rerun_dir)
exact <- compare_dirs(evidence_dir, rerun_dir)
if (any(exact$differences)) {
  stop(
    sprintf(
      "Deterministic rerun differs: %s",
      paste(exact$files[exact$differences], collapse = ", ")
    ),
    call. = FALSE
  )
}

run_runner(gut_dir, gut = TRUE)
gut <- compare_dirs(evidence_dir, gut_dir)
if (!any(gut$differences)) {
  stop("Gutted injection path did not change the evidence.", call. = FALSE)
}

recorded_cases <- utils::read.csv(
  file.path(evidence_dir, "cases.csv"),
  stringsAsFactors = FALSE
)
gutted_cases <- utils::read.csv(
  file.path(gut_dir, "cases.csv"),
  stringsAsFactors = FALSE
)
recorded_late <- recorded_cases[
  recorded_cases$case_id == "late_start_at_entitlement",
  ,
  drop = FALSE
]
gutted_late <- gutted_cases[
  gutted_cases$case_id == "late_start_at_entitlement",
  ,
  drop = FALSE
]
changed_fields <- c(
  "child_position",
  "child_view_rows",
  "child_ledger_rows",
  "final_positions_value",
  "final_equity"
)
if (nrow(recorded_late) != 1L || nrow(gutted_late) != 1L ||
    any(vapply(changed_fields, function(name) {
      identical(recorded_late[[name]], gutted_late[[name]])
    }, logical(1))) ||
    !isTRUE(recorded_late$child_held_at_entitlement[[1L]]) ||
    isTRUE(gutted_late$child_held_at_entitlement[[1L]]) ||
    !isTRUE(recorded_late$child_priced_at_entitlement[[1L]]) ||
    isTRUE(gutted_late$child_priced_at_entitlement[[1L]])) {
  stop(
    "Gutted injection did not change child position and visibility evidence.",
    call. = FALSE
  )
}

after <- scope_status()
if (!identical(before, after)) {
  stop("Package or design scope changed during checker execution.", call. = FALSE)
}

cases <- utils::read.csv(file.path(evidence_dir, "cases.csv"), stringsAsFactors = FALSE)
parity <- utils::read.csv(file.path(evidence_dir, "parity.csv"), stringsAsFactors = FALSE)
if (nrow(cases) != 3L || nrow(parity) != 3L) {
  stop("Recorded row counts changed.", call. = FALSE)
}

cat("SETTLEMENT_AXIS_DENSITY_CHECKS_OK: 9 checks\n")
cat(sprintf("RERUN_BYTE_EXACT: %s\n", paste(exact$files, collapse = ", ")))
cat(sprintf(
  "GUT_DETECTED: %s\n",
  paste(gut$files[gut$differences], collapse = ", ")
))
cat("PACKAGE_SCOPE_UNCHANGED\n")
