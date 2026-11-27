# Probe: load the lean core from the pinned library, transform the envelope
# for one set, and print the findings, counts and one transformed stage.
#   Rscript probe.R --lib=<pinned library> --set=commit|all [--show=lean_p5_commit] [--out=<file>]
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
arg <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)
  if (!length(hit)) return(default)
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
source(file.path(here, "..", "..", "lean_core", "load.R"))
lean <- lean_core_load(arg("lib"), debug = FALSE)
sys.source(file.path(here, "transform.R"), envir = lean, keep.source = FALSE)
set <- arg("set", "commit")
fork <- lean$es_transform(lean$lean_fold_envelope_plain, lean$es_sets[[set]])
info <- attr(fork, "es")
cat("set:", set, "\nreads rewritten:", info$reads, "\nwrites rewritten (<<-):", info$writes,
    "\nenvelope assignments rewritten:", info$top_assignments,
    "\nresidual envelope references:", paste(lean$es_residual(fork, info$map), collapse = ", "),
    "\nfindings:\n", paste0("  ", info$findings, collapse = "\n"), "\n")
show <- arg("show", "")
if (nzchar(show)) {
  pick <- function(f) Filter(function(x) is.call(x) && identical(x[[1L]], as.name("<-")) && identical(x[[2L]], as.name(show)), as.list(body(f)))[[1L]]
  cat("\n--- before ---\n"); cat(deparse(pick(lean$lean_fold_envelope_plain), width.cutoff = 100L), sep = "\n")
  cat("\n--- after ---\n"); cat(deparse(pick(fork), width.cutoff = 100L), sep = "\n")
}
out <- arg("out", "")
if (nzchar(out)) {
  d0 <- deparse(lean$lean_fold_envelope_plain, width.cutoff = 100L)
  d1 <- deparse(fork, width.cutoff = 100L)
  writeLines(d1, out)
  cat(sprintf("deparsed lines: plain %d, fork %d; characters: plain %d, fork %d\n", length(d0), length(d1),
              sum(nchar(d0)), sum(nchar(d1))))
}
