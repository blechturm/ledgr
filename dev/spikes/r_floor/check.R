# Checker: rerun both stages into a scratch directory, diff parity against
# the recorded evidence, check the timing tables' rows, and guard package
# scope. Usage: Rscript dev/spikes/r_floor/check.R <ledgr lib> <scratch dir>
args <- commandArgs(TRUE)
lib <- args[[1]]; scratch <- args[[2]]
here <- file.path("dev", "spikes", "r_floor")
evidence <- file.path(here, "evidence")
scope <- c("R", "src", "tests", "NAMESPACE", "DESCRIPTION", "man", "inst/design")
status <- function() system2("git", c("status", "--porcelain", "--", scope), stdout = TRUE)
read <- function(dir, f) utils::read.csv(file.path(dir, f), stringsAsFactors = FALSE)

before <- status()
problems <- character()
stages <- list(
  list(script = "run.R", parity = "parity.csv", timings = "timings.csv",
       ok = c("fills_identical", "equity_identical", "cash_identical")),
  list(script = "run2.R", parity = "parity_layers.csv", timings = "timings_layers.csv",
       ok = c("fills_identical", "equity_identical", "cash_identical"))
)
for (st in stages) {
  recorded <- read(evidence, st$parity)
  shapes <- paste(unique(recorded$shape), collapse = ",")
  rc <- system2(file.path(R.home("bin"), "Rscript"),
                c(file.path(here, st$script), lib, scratch, shapes), stdout = FALSE, stderr = FALSE)
  if (rc != 0L) { problems <- c(problems, sprintf("%s exited %d", st$script, rc)); next }
  fresh <- read(scratch, st$parity)
  if (!identical(fresh, recorded)) problems <- c(problems, sprintf("%s differs from the recorded evidence", st$parity))
  if (!all(as.matrix(fresh[st$ok]))) problems <- c(problems, sprintf("%s: the floor no longer reproduces ledgr", st$parity))
  if ("trace" %in% names(fresh)) {
    traced <- fresh$layer %in% c("trace_full", "trace_diff")
    if (!all(fresh$trace[traced] == "identical")) problems <- c(problems, "a rebuilt or in-loop trace differs from ledgr's")
  }
  keys <- intersect(c("shape", "variant", "layer"), names(fresh))
  if (!identical(read(scratch, st$timings)[keys], read(evidence, st$timings)[keys])) {
    problems <- c(problems, sprintf("%s rows differ from the recorded evidence", st$timings))
  }
}
if (!identical(status(), before)) problems <- c(problems, "package scope changed during the run")

if (length(problems)) {
  cat("R_FLOOR_CHECK_FAILED\n", paste0("  ", problems, "\n"), sep = "")
  quit(status = 1L)
}
cat("R_FLOOR_CHECK_OK\n")
