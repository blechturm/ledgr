args <- commandArgs(trailingOnly = TRUE)
here <- normalizePath(dirname(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))), winslash = "/")
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
recorded <- file.path(here, "evidence")
scratch <- tempfile("typed-accounting-check-")
dir.create(scratch, recursive = TRUE)
on.exit(unlink(scratch, recursive = TRUE, force = TRUE), add = TRUE)

status <- system2(
  file.path(R.home("bin"), "Rscript.exe"),
  c(file.path(here, "run_spike.R"), scratch)
)
if (!identical(status, 0L)) stop("runner failed")

expected_semantic <- utils::read.csv(file.path(recorded, "semantic.csv"), stringsAsFactors = FALSE)
actual_semantic <- utils::read.csv(file.path(scratch, "semantic.csv"), stringsAsFactors = FALSE)
if (!identical(expected_semantic, actual_semantic)) {
  stop("semantic evidence differs from the recorded CSV")
}
if (any(actual_semantic$mismatched_cells != 0L)) {
  stop("a typed layout failed exact roundtrip")
}

gut <- utils::read.csv(file.path(scratch, "gut.csv"), stringsAsFactors = FALSE)
if (nrow(gut) != 1L || !isTRUE(gut$expected_failure[[1L]]) || gut$mismatched_cells[[1L]] < 1L) {
  stop("gutted source_fact_id path was not detected")
}

timing <- utils::read.csv(file.path(scratch, "timing.csv"), stringsAsFactors = FALSE)
if (nrow(timing) != 6L || any(timing$mismatched_cells != 0L)) {
  stop("timing evidence is incomplete or inexact")
}
if (any(!is.finite(timing$write_seconds)) || any(!is.finite(timing$read_seconds))) {
  stop("timing evidence is non-finite")
}

root <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
scope <- c("R", "src", "tests", "NAMESPACE", "DESCRIPTION", "man", "inst/design")
Sys.setenv(GIT_CONFIG_GLOBAL = "C:/Users/maxth/.gitconfig")
git <- system2(
  "git",
  c("-C", root, "status", "--porcelain", "--", scope),
  stdout = TRUE, stderr = TRUE
)
if (length(git) > 0L) stop("package scope changed during the spike: ", paste(git, collapse = "; "))

cat("PASS: exact typed roundtrips reproduced, gut detected, package scope untouched\n")
