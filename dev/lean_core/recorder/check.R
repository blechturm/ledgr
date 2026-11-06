# LDG-3212 checker: reruns the runner and the omission demonstration into a
# scratch directory, diffs the regenerated manifests and evidence CSVs
# against the committed ones, requires every call to replay on the table's
# fields and every omission and witness to hold, and guards package scope.
#
#   Rscript dev/lean_core/recorder/check.R --lib=<pinned library> --src=<pinned source archive> --scratch=<empty dir>
#
# Exits with status 1 on any difference or failure.

here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
arg <- function(name) {
  hit <- grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)
  if (!length(hit)) stop("--", name, "= is required", call. = FALSE)
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
lib <- arg("lib")
src <- arg("src")
scratch <- arg("scratch")
dir.create(scratch, recursive = TRUE, showWarnings = FALSE)
if (length(list.files(scratch))) stop("--scratch= must be empty", call. = FALSE)
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
rscript <- file.path(R.home("bin"), "Rscript")
problems <- character()

for (script in c("run.R", "omissions.R")) {
  status <- system2(rscript, c(file.path(here, script), paste0("--lib=", lib), paste0("--src=", src),
                               paste0("--captures=", file.path(scratch, "captures")),
                               paste0("--out=", file.path(scratch, "evidence")),
                               paste0("--manifests=", file.path(scratch, "manifests"))))
  if (!identical(status, 0L)) problems <- c(problems, paste(script, "exited with status", status))
}

same_csv <- function(committed, fresh, label) {
  if (!file.exists(fresh)) return(paste(label, "was not regenerated"))
  a <- readLines(committed, warn = FALSE)
  b <- readLines(fresh, warn = FALSE)
  if (identical(a, b)) return(character())
  at <- which(c(a, rep("", max(0L, length(b) - length(a)))) != c(b, rep("", max(0L, length(a) - length(b)))))[[1L]]
  sprintf("%s differs at line %d:\n  committed: %s\n  rerun:     %s", label, at, a[at], b[at])
}
for (f in list.files(file.path(here, "manifests"), pattern = "[.]csv$")) {
  problems <- c(problems, same_csv(file.path(here, "manifests", f), file.path(scratch, "manifests", f), file.path("manifests", f)))
}
for (f in list.files(file.path(here, "evidence"), pattern = "[.]csv$")) {
  problems <- c(problems, same_csv(file.path(here, "evidence", f), file.path(scratch, "evidence", f), file.path("evidence", f)))
}

replay <- utils::read.csv(file.path(scratch, "evidence", "replay.csv"), stringsAsFactors = FALSE, na.strings = character())
if (!any(replay$boundary == "history_read" & replay$calls > 0L)) problems <- c(problems, "no history read was captured")
# Findings explain a failure; they never let a call pass.
short <- replay[replay$passed != replay$calls, ]
problems <- c(problems, sprintf("replay: %s %s passes %d of %d: %s", short$workload, short$boundary, short$passed,
                                short$calls, short$first_failure))
omissions <- utils::read.csv(file.path(scratch, "evidence", "omissions.csv"), stringsAsFactors = FALSE)
bad <- omissions[!omissions$outcome %in% c("fails as required", "control passes", "recorded correctly"), ]
problems <- c(problems, sprintf("omission %s: %s", bad$omission, bad$outcome))

# Content changes against HEAD (line endings normalized, so a file rewritten
# byte-identical with LF under core.autocrlf is not a change) and new files.
paths <- c("R", "src", "tests", "NAMESPACE", "DESCRIPTION", "man", "inst/design")
git <- function(...) {
  x <- system2("git", c("-C", repo, ...), stdout = TRUE, stderr = FALSE)
  if (!is.null(attr(x, "status"))) problems <<- c(problems, paste("cannot inspect package scope: git", ..1, "failed"))
  x
}
scope <- c(git("diff", "--name-only", "HEAD", "--", paths), git("ls-files", "--others", "--exclude-standard", "--", paths))
if (length(scope)) problems <- c(problems, paste("package scope changed:", scope))

if (length(problems)) {
  cat("CHECK FAILED\n", paste0("- ", problems, "\n"), sep = "")
  quit(status = 1L)
}
cat("CHECK PASSED: manifests and evidence reproduce, every call replays on the table's fields,",
    "every omission and witness holds, package scope clean\n")
