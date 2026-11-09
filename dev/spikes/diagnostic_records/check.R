# Checker (spike protocol section 6): reruns the spike into a scratch
# directory and diffs every correctness column against the recorded
# evidence (timings are not compared), then guards package scope.
#
#   Rscript dev/spikes/diagnostic_records/check.R <pinned lib> <scratch dir> [--small]
#
# --small reruns the small workloads only (minutes instead of about an hour).

args <- commandArgs(TRUE)
small <- "--small" %in% args
args <- setdiff(args, "--small")
lib <- args[[1L]]
scratch <- args[[2L]]
dir.create(scratch, recursive = TRUE, showWarnings = FALSE)
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
                              winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
rscript <- file.path(R.home("bin"), "Rscript")
run <- function(script, ...) {
  status <- system2(rscript, c(file.path(here, script), lib, scratch, ...), stdout = FALSE, stderr = FALSE)
  if (!identical(status, 0L) && !identical(status, 1L)) stop(script, " exited with ", status)
}
fixed <- "crossover_10x7200,crossover_500x1260,momentum_40x504,momentum_500x1260,dense_risk_features"
all <- paste(fixed, "prep_fixture", sep = ",")
pick <- function(full, few) if (small) few else full
run("rebuild.R", pick(all, "prep_fixture,dense_risk_features,momentum_40x504"))
run("rebuild.R", pick(all, "prep_fixture,dense_risk_features,momentum_40x504"), "--gut")
run("fork.R", "sweeps", pick(all, "prep_fixture,dense_risk_features,momentum_40x504"))
run("fork.R", "sweeps", "prep_fixture,crossover_500x1260,dense_risk_features", "--gut")
run("fork.R", "runs", pick(fixed, "momentum_40x504,dense_risk_features"))
run("fork.R", "runs", "momentum_40x504,dense_risk_features,momentum_500x1260", "--gut")
if (!small) run("fork.R", "a0")

columns <- list(
  rebuild.csv = c("workload", "rebuilt_holds", "hold_count_check", "trace_identical", "first_difference"),
  rebuild_gut.csv = c("workload", "hold_count_check", "first_difference"),
  fork_sweeps.csv = c("workload", "arm", "different", "kept_rows"),
  fork_sweeps_gut.csv = c("workload", "arm", "different"),
  fork_runs.csv = c("workload", "arm", "different", "implicit_is_pin_fills", "stored_implicit_rows"),
  fork_runs_gut.csv = c("workload", "refused"),
  fork_a0.csv = c("workload", "path", "different")
)
if (small) columns$fork_a0.csv <- NULL
problems <- character()
for (f in names(columns)) {
  want <- utils::read.csv(file.path(here, "evidence", f), colClasses = "character")
  got <- utils::read.csv(file.path(scratch, f), colClasses = "character")
  keys <- intersect(c("workload", "arm", "path"), columns[[f]])
  got <- got[, columns[[f]], drop = FALSE]
  want <- want[do.call(paste, want[keys]) %in% do.call(paste, got[keys]), columns[[f]], drop = FALSE]
  got <- got[order(do.call(paste, got[keys]), method = "radix"), , drop = FALSE]
  want <- want[order(do.call(paste, want[keys]), method = "radix"), , drop = FALSE]
  rownames(got) <- rownames(want) <- NULL
  if (!identical(got, want)) problems <- c(problems, f)
}
scope <- system2("git", c("-C", repo, "status", "--porcelain", "--", "R", "src", "tests", "NAMESPACE",
                          "DESCRIPTION", "man", "inst/design"), stdout = TRUE)
scope <- scope[!grepl("R/cpp11.R|src/cpp11.cpp", scope)]
if (length(scope)) problems <- c(problems, paste("package scope changed:", paste(scope, collapse = "; ")))
if (length(problems)) {
  cat("CHECK FAIL:", paste(problems, collapse = ", "), "\n")
  quit(status = 1L)
}
cat("CHECK PASS\n")
