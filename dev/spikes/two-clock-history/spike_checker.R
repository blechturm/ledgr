# Two-clock history spike checker.
#
# Rscript dev/spikes/two-clock-history/spike_checker.R <ledgr_repo>
#
# Reruns the runner (normal and --gut) into scratch directories, diffs against
# the recorded evidence, compares the bitemporal answers with the frozen
# expected answers, asserts the gut fails cases 1, 2 and 4 on named rows while
# case 8 passes, reports the size bound, and guards package scope.
args <- commandArgs(trailingOnly = TRUE)
repo <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
spike <- file.path(repo, "dev/spikes/two-clock-history")
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

scratch <- tempfile("tch-check-")
run(file.path(scratch, "normal"))
run(file.path(scratch, "gut"), "--gut")
for (pair in list(c("normal", ""), c("gut", "gut"))) {
  for (file in c("cases.csv", "shape.csv", "growth.csv")) {
    recorded <- file.path(evidence, pair[[2L]], file)
    fresh <- file.path(scratch, pair[[1L]], file)
    if (!file.exists(recorded) || !file.exists(fresh) || !same_file(recorded, fresh)) {
      fail("rerun differs from recorded evidence: ", pair[[1L]], "/", file)
    }
  }
}

expected <- utils::read.csv(file.path(spike, "expected.csv"), stringsAsFactors = FALSE)
key <- function(df) paste(df$case, df$s_day, df$t_day)
answers <- function(mode) {
  df <- utils::read.csv(file.path(scratch, mode, "cases.csv"), stringsAsFactors = FALSE)
  df$answer[match(key(expected), key(df))]
}
normal <- answers("normal")
gutted <- answers("gut")
expected$bitemporal <- normal
expected$gut <- gutted
print(expected[, c("case", "s_day", "t_day", "expected", "bitemporal", "gut")], row.names = FALSE)
if (!all(normal == expected$expected)) fail("bitemporal answers differ from expected on ",
                                              sum(normal != expected$expected), " rows")

named <- (expected$case == 1 & expected$t_day %in% c(8, 9)) | (expected$case == 2 & expected$t_day == 6) |
  (expected$case == 4 & expected$t_day == 8)
if (!all(gutted[named] != expected$expected[named])) fail("gut did not fail cases 1, 2 and 4 on their named rows")
diagonal <- function(mode) {
  df <- utils::read.csv(file.path(scratch, mode, "cases.csv"), stringsAsFactors = FALSE)
  df$answer[df$case == 8]
}
if (!all(diagonal("normal") == "10 of 10 days equal") || !all(diagonal("gut") == "10 of 10 days equal")) {
  fail("case 8: the diagonal does not equal the shipped provider")
}

shape <- utils::read.csv(file.path(scratch, "normal", "shape.csv"), stringsAsFactors = FALSE)
print(shape, row.names = FALSE)
cat(sprintf("size kill condition (segments > 2 x fact rows) fires on %d of %d fixtures; max segments per fact row %.2f\n",
            sum(!shape$bound_twice_fact_rows), nrow(shape), max(shape$segments_written / shape$fact_rows)))

growth <- utils::read.csv(file.path(scratch, "normal", "growth.csv"), stringsAsFactors = FALSE)
print(growth, row.names = FALSE)
cat(sprintf("case 9: append-only max %.2f segments per fact row; with restatements max %.2f\n",
            max(growth$segments_per_fact_row[growth$long_facts == 0]), max(growth$segments_per_fact_row)))

status_after <-git("status", "--porcelain", "--", c(package_paths, "inst/design"))
if (!identical(status_before, status_after)) fail("package or design scope changed during the rerun")
committed <- git("diff", "--name-only", "9452e9e", "HEAD", "--", package_paths)
if (length(committed)) fail("package files changed since spike start 9452e9e: ", paste(committed, collapse = ", "))

if (length(failures)) {
  cat("SPIKE CHECK FAILED\n", paste("-", failures, collapse = "\n"), "\n")
  quit(status = 1L)
}
cat("SPIKE CHECK OK: rerun identical, all expected answers match, gut fails cases 1, 2 and 4, diagonal equal, scope clean\n")
