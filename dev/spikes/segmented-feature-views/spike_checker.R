# Checker for the segmented-feature-views spike.
#
# Spike protocol section 6. Three jobs:
#   1. rerun the runner into a scratch directory;
#   2. diff the fresh evidence against the committed CSV;
#   3. guard package scope, so the spike changed no package file.
#
# Exit status is non-zero on any failure, so this is usable as a gate.
#
#   Rscript dev/spikes/segmented-feature-views/spike_checker.R

OUT <- "dev/spikes/segmented-feature-views"
RECORDED <- file.path(OUT, "spike_evidence.csv")
GUARDED <- c("R", "src", "tests", "NAMESPACE", "DESCRIPTION", "man", "inst/design")

fail <- character()
note <- function(...) cat(..., "\n", sep = "")

# ------------------------------------------------------- 3. package scope
# Checked first: a spike that edited the package invalidates its own evidence.
dirty <- system2("git", c("status", "--porcelain", "--", GUARDED), stdout = TRUE)
dirty <- dirty[nzchar(dirty)]
if (length(dirty) > 0L) {
  fail <- c(fail, "package scope is dirty")
  note("FAIL  package scope touched:")
  for (d in dirty) note("        ", d)
} else {
  note("ok    package scope clean (", paste(GUARDED, collapse = ", "), ")")
}

# --------------------------------------------------------- 1. rerun fresh
if (!file.exists(RECORDED)) stop("No recorded evidence to diff against.")
recorded <- utils::read.csv(RECORDED, stringsAsFactors = FALSE)

scratch <- file.path(tempdir(), paste0("spike-scratch-", Sys.getpid()))
dir.create(scratch, recursive = TRUE, showWarnings = FALSE)
on.exit(unlink(scratch, recursive = TRUE), add = TRUE)

keep <- tempfile(fileext = ".csv")
invisible(file.copy(RECORDED, keep, overwrite = TRUE))
status <- system2(
  file.path(R.home("bin"), "Rscript"),
  file.path(OUT, "spike_runner.R"),
  stdout = file.path(scratch, "runner.log"), stderr = file.path(scratch, "runner.err")
)
fresh <- utils::read.csv(RECORDED, stringsAsFactors = FALSE)
invisible(file.copy(keep, RECORDED, overwrite = TRUE))  # restore the committed evidence
# pkgload::load_all() regenerates the cpp11 registration on every load, so the
# runner leaves R/cpp11.R and src/cpp11.cpp modified by line endings alone. That
# is a load artifact and not a spike edit, so it is reverted here; without this a
# second consecutive check would fail its own scope guard.
invisible(system2("git", c("checkout", "--", "R/cpp11.R", "src/cpp11.cpp")))
if (!identical(as.integer(status), 0L)) {
  fail <- c(fail, "runner exited non-zero")
  note("FAIL  runner exit status ", status)
} else {
  note("ok    runner reran to completion")
}

# ------------------------------------------------------------- 2. diff
key <- function(d) paste(d$case, d$key, sep = "\u001f")
r <- recorded[order(key(recorded)), , drop = FALSE]
f <- fresh[order(key(fresh)), , drop = FALSE]

missing <- setdiff(key(r), key(f))
added <- setdiff(key(f), key(r))
if (length(missing) > 0L || length(added) > 0L) {
  fail <- c(fail, "evidence row set changed")
  for (m in missing) note("FAIL  row missing on rerun: ", sub("\u001f", " / ", m))
  for (a in added) note("FAIL  row new on rerun:     ", sub("\u001f", " / ", a))
} else {
  note("ok    evidence row set identical (", nrow(r), " rows)")
}

both <- intersect(key(r), key(f))
rv <- setNames(r$value, key(r))[both]
fv <- setNames(f$value, key(f))[both]
drift <- both[rv != fv]
if (length(drift) > 0L) {
  fail <- c(fail, "evidence values drifted")
  for (d in drift) {
    note("FAIL  ", sub("\u001f", " / ", d), ": recorded ", rv[[d]], " -> fresh ", fv[[d]])
  }
} else {
  note("ok    all ", length(both), " values reproduce")
}

# ------------------------------------------------------------------ verdict
if (length(fail) > 0L) {
  note("\nCHECKER FAILED: ", paste(unique(fail), collapse = "; "))
  quit(status = 1L)
}
note("\nCHECKER PASSED")
