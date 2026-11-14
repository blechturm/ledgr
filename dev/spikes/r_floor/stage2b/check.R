# R-floor stage 2b checker (spike protocol section 6).
#
#   Rscript dev/spikes/r_floor/stage2b/check.R --lib=<pin library> --scratch=<empty dir>
#
# 1. Reruns run.R with one round into <scratch>/rerun and diffs its
#    parity.csv and contract.csv against the recorded ones, and the timing
#    tables' rows (shape, configuration) against the recorded rows.
# 2. Gutted path: the full reference with the affordability stop forced
#    (gut = "reconciliation") must fail economic parity on both workloads.
# 3. Package scope: the commits that touch stage2b change nothing outside
#    dev/spikes/r_floor, and the package directories carry no uncommitted
#    content change (line endings ignored).

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), args, value = TRUE)[[1L]])
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", "..", ".."), winslash = "/")
lib <- normalizePath(opt("lib"), winslash = "/", mustWork = TRUE)
scratch <- opt("scratch"); dir.create(scratch, recursive = TRUE, showWarnings = FALSE)
recorded <- file.path(here, "evidence")
rscript <- file.path(R.home("bin"), "Rscript.exe")
fail <- character()

rerun <- file.path(scratch, "rerun")
st <- system2(rscript, c(file.path(here, "run.R"), paste0("--lib=", lib), paste0("--out=", rerun), "--rounds=1"), stdout = FALSE, stderr = FALSE)
if (st != 0L) fail <- c(fail, "rerun exited nonzero")
for (f in c("parity.csv", "contract.csv")) {
  a <- utils::read.csv(file.path(recorded, f), stringsAsFactors = FALSE); b <- utils::read.csv(file.path(rerun, f), stringsAsFactors = FALSE)
  if (!identical(a, b)) fail <- c(fail, paste(f, "differs from the recorded one"))
}
for (f in c("summary.csv", "attribution.csv")) {
  key <- if (f == "summary.csv") c("shape", "config") else c("shape", "part")
  a <- utils::read.csv(file.path(recorded, f), stringsAsFactors = FALSE)[key]; b <- utils::read.csv(file.path(rerun, f), stringsAsFactors = FALSE)[key]
  if (!identical(a, b)) fail <- c(fail, paste(f, "rows differ from the recorded rows"))
}

gut <- file.path(scratch, "gut")
for (s in c("10x7200", "slice2_10x7200")) {
  dir.create(gut, showWarnings = FALSE)
  file.copy(file.path(rerun, sprintf("records_%s_lean.rds", s)), gut, overwrite = TRUE)
  row <- tempfile(fileext = ".csv")
  st <- system2(rscript, c(file.path(here, "run.R"), paste0("--lib=", lib), "--mode=arm", "--arm=ref", paste0("--shape=", s),
                           paste0("--row=", row), paste0("--records=", file.path(gut, sprintf("records_%s_ref.rds", s))),
                           "--gut=reconciliation"), stdout = FALSE, stderr = FALSE)
  a <- readRDS(file.path(gut, sprintf("records_%s_ref.rds", s))); b <- readRDS(file.path(gut, sprintf("records_%s_lean.rds", s)))
  economic <- identical(unname(a$fills$qty), unname(b$fills$qty)) && identical(a$equity, b$equity[names(a$equity)]) && identical(a$status, b$status)
  cat(sprintf("gutted %s: status %s, fills %d (lean %d), economic parity %s\n", s, a$status, length(a$fills$qty), length(b$fills$qty), economic))
  if (st != 0L || economic) fail <- c(fail, paste("gutted path did not fail parity on", s))
}

git <- function(...) system2("git", c("-C", repo, ...), stdout = TRUE)
commits <- git("log", "--format=%H", "--", "dev/spikes/r_floor/stage2b")
outside <- unique(unlist(lapply(commits, function(h) {
  files <- git("show", "--name-only", "--format=", h)
  files[nzchar(files) & !startsWith(files, "dev/spikes/r_floor/")]
})))
if (length(outside)) fail <- c(fail, paste("stage 2b commits touch:", paste(outside, collapse = ", ")))
dirty <- suppressWarnings(git("diff", "--ignore-cr-at-eol", "--name-only", "--", "R", "src", "tests", "NAMESPACE", "DESCRIPTION", "man", "inst/design"))
if (length(dirty)) fail <- c(fail, paste("package scope changed:", paste(dirty, collapse = ", ")))

if (length(fail)) { cat("CHECK FAILED\n", paste0("- ", fail, "\n"), sep = ""); quit(status = 1L) }
cat("CHECK PASSED\n")
