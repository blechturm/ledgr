args <- commandArgs(trailingOnly = TRUE)
mode_arg <- grep("^--mode=", args, value = TRUE)
mode <- if (length(mode_arg) == 0L) "review" else sub("^--mode=", "", mode_arg[[1L]])
if (!mode %in% c("review", "gate")) {
  stop("`--mode` must be `review` or `gate`.", call. = FALSE)
}

root <- normalizePath(
  file.path("dev", "spikes", "asset_availability_pit"),
  winslash = "/",
  mustWork = TRUE
)
runner <- file.path(root, "run_stage3.R")
runner_args <- c(runner, "--no-write")
if (mode == "gate") runner_args <- c(runner_args, "--require-freeze-anchor")
output <- system2(
  file.path(R.home("bin"), "Rscript.exe"),
  runner_args,
  stdout = TRUE,
  stderr = TRUE
)
status <- attr(output, "status")
if (!is.null(status) && status != 0L) {
  stop(paste(output, collapse = "\n"), call. = FALSE)
}

required <- c(
  "dev/spikes/asset_availability_pit/check_stage3.R",
  "dev/spikes/asset_availability_pit/run_stage3.R",
  "dev/spikes/asset_availability_pit/stage3/common.R",
  "dev/spikes/asset_availability_pit/stage3/conformance.R",
  "dev/spikes/asset_availability_pit/stage3/mutations.R",
  "dev/spikes/asset_availability_pit/stage3/package_dense_control.R",
  "dev/spikes/asset_availability_pit/stage3/reference_provider.R",
  "dev/spikes/asset_availability_pit/stage3/reference_witnesses.R",
  "dev/spikes/asset_availability_pit/stage3/shared_fold.R",
  "dev/spikes/asset_availability_pit/stage3/w21_evidence.R"
)
missing <- required[!file.exists(required)]
if (length(missing) > 0L) stop("Missing Stage 3 code: ", paste(missing, collapse = ", "), call. = FALSE)
actual <- c(
  "dev/spikes/asset_availability_pit/check_stage3.R",
  "dev/spikes/asset_availability_pit/run_stage3.R",
  file.path(
    "dev/spikes/asset_availability_pit/stage3",
    list.files(file.path(root, "stage3"), pattern = "[.]R$")
  )
)
actual <- gsub("\\\\", "/", actual)
if (!setequal(actual, required)) {
  stop("The discovered Stage 3 executable set does not match the gate contract.", call. = FALSE)
}

old_home <- Sys.getenv("HOME")
on.exit(Sys.setenv(HOME = old_home), add = TRUE)
if (nzchar(Sys.getenv("USERPROFILE"))) Sys.setenv(HOME = Sys.getenv("USERPROFILE"))
git <- function(args, stdout = FALSE) {
  suppressWarnings(system2("git", args, stdout = stdout, stderr = FALSE))
}
base <- "1f42cf7"
runtime_paths <- c("R", "src", "tests/testthat", "NAMESPACE", "DESCRIPTION", "man", "inst/design")
if (git(c("diff", "--quiet", base, "HEAD", "--", runtime_paths)) != 0L ||
    git(c("diff", "--quiet", "--", runtime_paths)) != 0L) {
  stop("Stage 3 changed a forbidden package or design path.", call. = FALSE)
}

if (mode == "gate") {
  registry_path <- file.path(root, "evidence", "stage3_code.csv")
  if (!file.exists(registry_path)) stop("Stage 3 code registry is missing.", call. = FALSE)
  registry <- utils::read.csv(
    registry_path,
    stringsAsFactors = FALSE,
    colClasses = "character",
    na.strings = character()
  )
  if (!identical(names(registry), c("path", "role", "first_appearance_commit"))) {
    stop("Stage 3 code registry has the wrong columns.", call. = FALSE)
  }
  if (!setequal(registry$path, required)) {
    stop("Stage 3 code registry does not exactly cover the Stage 3 executable set.", call. = FALSE)
  }
  if (any(!grepl("^[0-9a-f]{40}$", registry$first_appearance_commit))) {
    stop("Stage 3 first-appearance commits must be full Git hashes.", call. = FALSE)
  }
  for (i in seq_len(nrow(registry))) {
    actual <- git(
      c("log", "--diff-filter=A", "--format=%H", "--", registry$path[[i]]),
      stdout = TRUE
    )
    if (length(actual) != 1L || actual[[1L]] != registry$first_appearance_commit[[i]]) {
      stop("Incorrect first-appearance commit for ", registry$path[[i]], call. = FALSE)
    }
    if (git(c("merge-base", "--is-ancestor", "c82c485", actual[[1L]])) != 0L) {
      stop("Stage 3 code predates the Stage 2 gate: ", registry$path[[i]], call. = FALSE)
    }
  }
  status_lines <- git(c("status", "--porcelain", "--", "dev/spikes/asset_availability_pit"), stdout = TRUE)
  if (length(status_lines) > 0L) stop("Stage 3 gate requires a clean spike workspace.", call. = FALSE)
}

cat(paste(output, collapse = "\n"), "\n", sep = "")
cat("Stage 3 ", mode, " check passed.\n", sep = "")
