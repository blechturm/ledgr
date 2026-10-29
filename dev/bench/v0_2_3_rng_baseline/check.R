# RNG baseline checker: guards package scope, reruns probe.R into a scratch
# directory and compares every record table with records/ byte for byte.
# Exits non-zero on any difference and prints one "FAIL <table>: ..." line per
# differing table (first differing line and the text around the change).
#
# Usage: Rscript check.R [--records=<dir>] [--out=<scratch dir>] [--gut=<name>]

local({
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  here <- if (length(file_arg)) dirname(sub("^--file=", "", file_arg[[1L]])) else getwd()
  assign("ck_here", normalizePath(here, winslash = "/"), envir = globalenv())
})
ck_root <- normalizePath(file.path(ck_here, "..", "..", ".."), winslash = "/")
ck_arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), commandArgs(trailingOnly = TRUE), value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
}
records <- ck_arg("records", file.path(ck_here, "records"))
out <- ck_arg("out", file.path(tempdir(), "rng_probe_check"))
gut <- ck_arg("gut")
fails <- character()

# 1. Package scope: no product change (line-ending-only churn is ignored).
git <- function(...) suppressWarnings(system2("git", c("-C", shQuote(ck_root), ...), stdout = TRUE, stderr = FALSE))
scope <- c("R", "src", "tests", "man", "vignettes", "NAMESPACE", "DESCRIPTION")
numstat <- git("diff", "--ignore-cr-at-eol", "--numstat", "HEAD", "--", scope)
changed <- numstat[!grepl("^0\t0\t", numstat) & nzchar(numstat)]
untracked <- git("ls-files", "--others", "--exclude-standard", "--", scope)
for (x in c(changed, untracked)) fails <- c(fails, sprintf("FAIL scope: product path changed: %s", x))

# 2. Rerun.
if (dir.exists(out)) unlink(out, recursive = TRUE)
args <- c(shQuote(file.path(ck_here, "probe.R"), type = "cmd"), paste0("--out=", shQuote(out, type = "cmd")))
if (!is.null(gut)) args <- c(args, paste0("--gut=", gut))
log <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"), args, stdout = TRUE, stderr = TRUE))
status <- attr(log, "status") %||% 0L
if (!identical(as.integer(status), 0L)) {
  fails <- c(fails, sprintf("FAIL probe: probe.R exited %s: %s", status, paste(tail(log, 5L), collapse = " | ")))
}

# 3. Byte comparison through the manifests.
read_manifest <- function(d) {
  f <- file.path(d, "manifest.csv")
  if (!file.exists(f)) return(data.frame(file = character(), sha256 = character()))
  utils::read.csv(f, colClasses = "character")
}
sha <- function(f) digest::digest(file = f, algo = "sha256")
exp_m <- read_manifest(records); act_m <- read_manifest(out)
if (nrow(exp_m) == 0L) fails <- c(fails, "FAIL records: no manifest.csv in the records directory")
for (f in setdiff(exp_m$file, act_m$file)) fails <- c(fails, sprintf("FAIL %s: missing from rerun", sub("[.]csv$", "", f)))
for (f in setdiff(act_m$file, exp_m$file)) fails <- c(fails, sprintf("FAIL %s: new table in rerun", sub("[.]csv$", "", f)))
for (f in intersect(exp_m$file, act_m$file)) {
  table <- sub("[.]csv$", "", f)
  recorded <- sha(file.path(records, f))
  if (!identical(recorded, exp_m$sha256[exp_m$file == f])) {
    fails <- c(fails, sprintf("FAIL %s: record file no longer matches its manifest (edited or line endings changed)", table))
    next
  }
  if (identical(recorded, sha(file.path(out, f)))) next
  e <- readLines(file.path(records, f), encoding = "UTF-8", warn = FALSE)
  a <- readLines(file.path(out, f), encoding = "UTF-8", warn = FALSE)
  n <- min(length(e), length(a))
  i <- which(e[seq_len(n)] != a[seq_len(n)])
  if (!length(i)) {
    fails <- c(fails, sprintf("FAIL %s: row count %d recorded, %d now", table, length(e) - 1L, length(a) - 1L))
    next
  }
  i <- i[[1L]]
  ec <- strsplit(e[[i]], "")[[1L]]; ac <- strsplit(a[[i]], "")[[1L]]
  at <- which(ec[seq_len(min(length(ec), length(ac)))] != ac[seq_len(min(length(ec), length(ac)))])
  at <- max(1L, (if (length(at)) at[[1L]] else min(length(ec), length(ac))) - 30L)
  fails <- c(fails, sprintf("FAIL %s: line %d differs; recorded ...%s | now ...%s", table, i,
    substr(e[[i]], at, at + 90L), substr(a[[i]], at, at + 90L)))
}

if (length(fails)) {
  writeLines(fails)
  cat(sprintf("rng check: FAIL (%d)\n", length(fails)))
  quit(status = 1L)
}
cat(sprintf("rng check: PASS (%d tables identical, product scope clean)\n", nrow(exp_m)))
