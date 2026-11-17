# Runner for the deterministic evidence of this probe (the timing scripts,
# steps_clean.R, probe_time.R and inputs_split.R, are run separately on the
# P-cores through dev/bench/v0_2_3_lean_tuning_profile/pcore.ps1 under the
# High performance plan, as in the commit message). Writes into --out:
#   census_walk.csv                 candidate 6 call graph (census_walk.R)
#   check_c23.csv, _counts, _unions candidates 2 and 3 against the pin (probe_check.R)
#
#   Rscript probe.R --lib=<pinned library> --out=<dir>
arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)[[1L]])
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
lib <- arg("lib")
out <- arg("out")
dir.create(out, showWarnings = FALSE, recursive = TRUE)
rscript <- file.path(R.home("bin"), "Rscript.exe")
run <- function(script, ...) {
  status <- system2(rscript, c(file.path(here, script), paste0("--lib=", lib), ...))
  if (!identical(as.integer(status), 0L)) stop(script, " failed with status ", status, call. = FALSE)
}
run("census_walk.R", paste0("--out=", file.path(out, "census_walk.csv")))
run("probe_check.R", paste0("--out=", file.path(out, "check_c23.csv")))
