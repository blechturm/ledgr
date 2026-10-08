# Recursive-indicator history spike checker.
#
# Rscript dev/spikes/recursive-indicator-history/spike_checker.R <ledgr_repo>
#
# Reruns the runner (normal and --gut) into scratch directories, diffs against
# the recorded evidence, asserts the gut fails on its named rows, reports
# agreement with the frozen expected answers, and guards package scope.
args <- commandArgs(trailingOnly = TRUE)
repo <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
spike <- file.path(repo, "dev/spikes/recursive-indicator-history")
evidence <- file.path(spike, "evidence")
rscript <- file.path(R.home("bin"), "Rscript")
failures <- character()
fail <- function(...) failures <<- c(failures, paste0(...))

git <- function(...) suppressWarnings(system2("git", c("-C", shQuote(repo), ...), stdout = TRUE, stderr = TRUE))
package_paths <- c("R", "src", "tests", "NAMESPACE", "DESCRIPTION", "man")
status_before <- git("status", "--porcelain", "--", c(package_paths, "inst/design"))

run <- function(out, extra = character()) {
  code <- system2(rscript, c(shQuote(file.path(spike, "spike_runner.R")), shQuote(repo), shQuote(out), extra),
                  stdout = FALSE, stderr = FALSE)
  if (!identical(code, 0L)) fail("runner exited ", code, " for ", out)
}
same_file <- function(a, b) {
  identical(gsub("\r\n", "\n", paste(readLines(a, warn = FALSE), collapse = "\n")),
            gsub("\r\n", "\n", paste(readLines(b, warn = FALSE), collapse = "\n")))
}

scratch <- tempfile("rih-check-")
run(file.path(scratch, "normal"))
run(file.path(scratch, "gut"), "--gut")
for (pair in list(c("normal", ""), c("gut", "gut"))) {
  for (file in c("prerequisite.csv", "classification.csv", if (pair[[1L]] == "normal") "fragility.csv")) {
    recorded <- file.path(evidence, pair[[2L]], file)
    fresh <- file.path(scratch, pair[[1L]], file)
    if (!file.exists(recorded) || !file.exists(fresh) || !same_file(recorded, fresh)) {
      fail("rerun differs from recorded evidence: ", pair[[1L]], "/", file)
    }
  }
}

normal <- utils::read.csv(file.path(scratch, "normal", "classification.csv"), stringsAsFactors = FALSE)
gutted <- utils::read.csv(file.path(scratch, "gut", "classification.csv"), stringsAsFactors = FALSE)
prerequisite <- utils::read.csv(file.path(scratch, "normal", "prerequisite.csv"), stringsAsFactors = FALSE)
if (!all(prerequisite$values_identical & prerequisite$na_pattern_equal)) fail("prerequisite: engine differs from public run")

# The gut must fail on named rows: the declared-strict running max loses its
# flag and TTR EMA(5) is misclassified as bounded, on every path.
row <- function(df, indicator) df[df$indicator == indicator, , drop = FALSE]
if (!all(row(normal, "running_max_strict")$p3b_flag) || any(row(gutted, "running_max_strict")$p3b_flag)) {
  fail("gut: running_max_strict flag did not go from TRUE to FALSE")
}
if (!all(row(normal, "ttr_ema5")$class == "decaying") || !all(row(gutted, "ttr_ema5")$class == "bounded")) {
  fail("gut: ttr_ema5 did not go from decaying to bounded")
}

# Frozen expected answers: report agreement; disagreements are findings for the
# closeout, not checker failures.
expected <- utils::read.csv(file.path(spike, "expected.csv"), stringsAsFactors = FALSE)
compared <- merge(normal[, c("path", "indicator", "class", "p3b_flag")], expected,
                  by = "indicator", suffixes = c("", "_expected"))
compared$class_agrees <- compared$class == compared$class_expected
compared$flag_agrees <- compared$p3b_flag == compared$p3b_flag_expected
print(compared[, c("path", "indicator", "class", "class_expected", "class_agrees", "flag_agrees")], row.names = FALSE)

fragility <- utils::read.csv(file.path(scratch, "normal", "fragility.csv"), stringsAsFactors = FALSE)
cat(sprintf("fragility: %d of %d probe classes differ from expected\n",
            sum(fragility$class != expected$class_expected[match(fragility$indicator, expected$indicator)]),
            nrow(fragility)))

status_after <- git("status", "--porcelain", "--", c(package_paths, "inst/design"))
if (!identical(status_before, status_after)) fail("package or design scope changed during the rerun")
committed <- git("diff", "--name-only", "9452e9e", "HEAD", "--", package_paths)
if (length(committed)) fail("package files changed since spike start 9452e9e: ", paste(committed, collapse = ", "))

if (length(failures)) {
  cat("SPIKE CHECK FAILED\n", paste("-", failures, collapse = "\n"), "\n")
  quit(status = 1L)
}
cat(sprintf("SPIKE CHECK OK: rerun identical, gut fails on named rows, scope clean; %d of %d class answers agree with expected\n",
            sum(compared$class_agrees), nrow(compared)))
