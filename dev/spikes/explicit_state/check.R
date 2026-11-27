# Checker (LDG-3278): reruns one runner phase (default the prerequisite)
# into a scratch evidence directory, diffs every CSV it writes against the
# recorded evidence, and fails if any package-scope path (R, src, tests,
# NAMESPACE, DESCRIPTION, man, inst/design) or dev/lean_core differs from
# git HEAD.
#   Rscript check.R --lib=<pinned library> [--phase=prereq] [--scratch=<dir>]
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)
  if (!length(hit)) { if (is.null(default)) stop("--", name, "= is required", call. = FALSE); return(default) }
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
phase <- arg("phase", "prereq")
scratch <- normalizePath(arg("scratch", "C:/Users/maxth/ledgr-wt/cut27-scratch/spike/check"), winslash = "/", mustWork = FALSE)
recorded <- file.path(here, "evidence")
fresh <- file.path(scratch, "evidence")
dir.create(fresh, recursive = TRUE, showWarnings = FALSE)
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
fail <- character()

# 1. package scope against HEAD (tracked changes and untracked files)
scope <- c("R", "src", "tests", "NAMESPACE", "DESCRIPTION", "man", "inst/design", "dev/lean_core")
st <- system2("git", c("-C", repo, "status", "--porcelain", "--", scope), stdout = TRUE)
if (length(st)) fail <- c(fail, paste("scope differs from HEAD:", st))
cat(sprintf("scope (%s): %s\n", paste(scope, collapse = " "), if (length(st)) "CHANGED" else "unchanged"))

# 2. rerun and diff
status <- system2(file.path(R.home("bin"), "Rscript.exe"), c(file.path(here, "run.R"), paste0("--lib=", arg("lib")),
  paste0("--phase=", phase), paste0("--evidence=", fresh), paste0("--scratch=", scratch)))
files <- list.files(recorded, pattern = paste0("^", phase, "_.*[.]csv$"))
if (!length(files)) fail <- c(fail, paste("no recorded evidence for phase", phase))
for (f in files) {
  a <- utils::read.csv(file.path(recorded, f), stringsAsFactors = FALSE)
  b <- if (file.exists(file.path(fresh, f))) utils::read.csv(file.path(fresh, f), stringsAsFactors = FALSE) else NULL
  same <- !is.null(b) && identical(a, b)
  cat(sprintf("%-32s %s\n", f, if (same) "same" else "DIFFERS"))
  if (!same) {
    fail <- c(fail, paste(f, "differs from the recorded evidence"))
    if (!is.null(b) && identical(dim(a), dim(b))) {
      d <- which(a != b, arr.ind = TRUE)
      if (length(d)) print(utils::head(cbind(row = d[, 1L], column = names(a)[d[, 2L]], recorded = a[d], rerun = b[d]), 10L))
    }
  }
}
if (length(fail)) {
  cat("CHECK FAILED:\n", paste0("  ", fail, collapse = "\n"), "\n")
  quit(status = 1L)
}
cat("CHECK PASS:", phase, "reproduces the recorded evidence; scope unchanged\n")
