# Switch probe (Cut 27 drafting): the release's own test suite with the lean
# fold installed as the production engine would be (inert hooks: the
# envelope, the context read method and the worker channel; no harness
# fallback), against the same suite without it.
#
#   Rscript suite_probe.R --tree=<release source tree with LEDGR_SOURCE_COMMIT> --mode=baseline|lean --out=<dir>
#
# The tree's DLL must already be built by one process (parallel builds of a
# fresh tree corrupt it; dev/lean_core/parity/evidence/ldg3274/capture_crash).
# Writes <out>/<mode>_tests.csv (one row per test: file, test, counts and
# the first failure or error message) and <mode>_summary.txt.
local({
  arg <- function(n) sub(paste0("^--", n, "="), "", grep(paste0("^--", n, "="), commandArgs(TRUE), value = TRUE)[[1L]])
  assign("tree", normalizePath(arg("tree"), winslash = "/", mustWork = TRUE), globalenv())
  assign("mode", arg("mode"), globalenv())
  assign("out", arg("out"), globalenv())
})
stopifnot(mode %in% c("baseline", "lean"))
dir.create(out, recursive = TRUE, showWarnings = FALSE)
source(file.path(tree, "dev", "lean_core", "load.R"))
lean <- lean_core_load(tree)
if (identical(mode, "lean")) {
  lean$lean_loop_install(hooks = FALSE)
  stopifnot(identical(get("ledgr_fold_envelope", envir = asNamespace("ledgr")), lean$lean_fold_envelope))
}
cat("mode", mode, "ledgr from", getNamespaceInfo("ledgr", "path"), "\n")
t0 <- proc.time()[["elapsed"]]
res <- testthat::test_dir(file.path(tree, "tests", "testthat"), load_package = "none",
                          reporter = testthat::SummaryReporter$new(), stop_on_failure = FALSE, stop_on_warning = FALSE)
first_problem <- function(r) {
  for (e in r$results) {
    if (inherits(e, c("expectation_failure", "expectation_error"))) {
      return(substr(gsub("[\r\n]+", " ", conditionMessage(e)), 1L, 400L))
    }
  }
  ""
}
df <- data.frame(file = vapply(res, function(r) basename(r$file), ""), test = vapply(res, function(r) r$test, ""),
                 stringsAsFactors = FALSE)
s <- as.data.frame(res)
df$failed <- s$failed; df$error <- s$error; df$skipped <- s$skipped; df$passed <- s$passed
df$problem <- vapply(res, first_problem, "")
utils::write.csv(df, file.path(out, paste0(mode, "_tests.csv")), row.names = FALSE)
writeLines(c(sprintf("mode %s: %d files, %d tests, %d failed, %d errors, %d skipped, %.0f s",
                     mode, length(unique(df$file)), nrow(df), sum(df$failed > 0), sum(df$error), sum(df$skipped),
                     proc.time()[["elapsed"]] - t0)),
           file.path(out, paste0(mode, "_summary.txt")))
cat(readLines(file.path(out, paste0(mode, "_summary.txt"))), sep = "\n")
