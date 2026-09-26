args <- commandArgs(trailingOnly = TRUE)

value_arg <- function(name, default = NULL) {
  prefix <- paste0("--", name, "=")
  hit <- args[startsWith(args, prefix)]
  if (length(hit) == 0L) return(default)
  sub(prefix, "", hit[[length(hit)]], fixed = TRUE)
}

script_arg <- grep("^--file=", commandArgs(), value = TRUE)
script <- normalizePath(sub("^--file=", "", script_arg[[1L]]), winslash = "/")
root <- value_arg("root", normalizePath(file.path(dirname(script), ".."), winslash = "/"))
profile <- value_arg("profile", "fast")
mode <- value_arg("mode", "ordinary")
census <- value_arg("census", tempfile(fileext = ".csv"))
summary_path <- value_arg("summary", tempfile(fileext = ".csv"))
records_dir <- value_arg("records", NULL)
run_index <- as.integer(value_arg("run-index", "1"))
library_path <- value_arg("library", NULL)
reporter <- value_arg("reporter", "summary")
initial_workdir <- getwd()

absolute_path <- function(path) {
  if (grepl("^(?:[A-Za-z]:[/\\\\]|/)", path, perl = TRUE)) {
    return(chartr("\\", "/", path))
  }
  normalizePath(file.path(initial_workdir, path), winslash = "/", mustWork = FALSE)
}
if (!is.null(records_dir)) {
  if (is.na(run_index) || !run_index %in% 1:3) stop("--run-index must be 1, 2, or 3.")
  records_dir <- absolute_path(records_dir)
  dir.create(records_dir, recursive = TRUE, showWarnings = FALSE)
  census <- file.path(records_dir, sprintf("run-%d-census.csv", run_index))
  summary_path <- file.path(records_dir, sprintf("run-%d-summary.csv", run_index))
} else {
  census <- absolute_path(census)
  summary_path <- absolute_path(summary_path)
}

if (!is.null(library_path)) {
  library_path <- normalizePath(library_path, winslash = "/", mustWork = TRUE)
  .libPaths(c(library_path, .Library))
}
if (identical(mode, "cran")) {
  workdir <- Sys.getenv("LEDGR_CRAN_WORKDIR", unset = "")
  if (!nzchar(workdir)) stop("LEDGR_CRAN_WORKDIR is required in CRAN mode.")
  setwd(workdir)
  Sys.setenv(
    `_R_CHECK_CRAN_INCOMING_` = "true",
    `_R_CHECK_FORCE_SUGGESTS_` = "false",
    NOT_CRAN = "false"
  )
}

source(file.path(root, "tests", "test-control-plane.R"), local = TRUE)
if (!requireNamespace("pkgload", quietly = TRUE)) stop("pkgload is required.")
pkgload::load_all(root, quiet = TRUE)
# Start the timing workload from a stable collector state. Without this,
# harmless runner allocations can move one full collection into a later block.
invisible(gc(full = TRUE))
run <- ledgr_test_run_profile(
  root = root,
  profile = profile,
  mode = mode,
  reporter = reporter,
  census_path = census,
  load_package = "none"
)
summary <- data.frame(
  profile = profile,
  mode = mode,
  elapsed_seconds = run$elapsed_seconds,
  expected_blocks = nrow(run$expected),
  executed_blocks = nrow(run$actual),
  skipped_blocks = sum(run$actual$status == "skipped"),
  failed_blocks = sum(run$actual$status %in% c("failed", "error", "warning")),
  r_version = as.character(getRversion()),
  testthat_version = as.character(utils::packageVersion("testthat")),
  stringsAsFactors = FALSE
)
dir.create(dirname(summary_path), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(summary, summary_path, row.names = FALSE)
if (identical(profile, "fast")) {
  gates <- yaml::read_yaml(file.path(root, "tests", "test-gates.yml"))
  bound <- if (identical(mode, "ordinary")) {
    gates$ordinary_fast_max_seconds
  } else if (identical(mode, "cran")) {
    gates$cran_fast_max_seconds
  } else {
    NA_real_
  }
  exceeded <- is.numeric(bound) && length(bound) == 1L &&
    !is.na(bound) && run$elapsed_seconds > bound
  github_output <- Sys.getenv("GITHUB_OUTPUT", unset = "")
  if (nzchar(github_output)) {
    cat(sprintf("elapsed_seconds=%.3f\n", run$elapsed_seconds),
        file = github_output, append = TRUE)
    cat(sprintf("exceeded=%s\n", tolower(as.character(exceeded))),
        file = github_output, append = TRUE)
  }
  cat(sprintf("LEDGR_TEST_PROFILE_GATE_HINT exceeded=%s bound=%.3f\n",
              tolower(as.character(exceeded)), bound))
}
failure_status <- c("failed", "error", "warning")
failed <- run$actual[run$actual$status %in% failure_status, , drop = FALSE]
if (nrow(failed) > 0L) {
  ledgr_test_abort(
    sprintf(
      "Test profile has %d non-passing block(s); first is %s with status %s.",
      nrow(failed), failed$key[[1L]], failed$status[[1L]]
    ),
    "ledgr_test_profile_failed"
  )
}
cat(sprintf(
  "LEDGR_TEST_PROFILE_OK profile=%s mode=%s blocks=%d seconds=%.3f\n",
  profile, mode, nrow(run$actual), run$elapsed_seconds
))
