# Rerun only into scratch; the immutable freeze is read-only.
file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
source(file.path(dirname(normalizePath(file)), "native.R"))
pkg <- normalizePath(dense_arg("pkg", file.path(dense_home(), "../../../..")), winslash = "/")
records <- normalizePath(dense_arg("records", file.path(dense_home(), "oracles/20261030-pre-ws4")), winslash = "/")
out <- normalizePath(dense_arg("out", tempfile("dense-check-")), winslash = "/", mustWork = FALSE)
if (identical(out, records) || startsWith(out, paste0(records, "/"))) {
  stop("scratch must be outside the immutable record directory")
}
dense_load(pkg)
before <- dense_scope(pkg)
dense_record(out, pkg)
diffs <- dense_compare(records, out)
refs <- utils::read.csv(file.path(records, "a0_references.csv"))
stopifnot(identical(refs, dense_references(pkg)), identical(before, dense_scope(pkg)))
utils::write.csv(diffs, file.path(out, "differences.csv"), row.names = FALSE)
utils::write.csv(dense_history_difference(records), file.path(out, "first_divergences.csv"), row.names = FALSE)
if (nrow(diffs)) {
  print(diffs, row.names = FALSE)
  stop("dense native check: FAIL; expected files were not changed")
}
cat("dense native check: PASS; nine native arms identical, A0 pointers resolve, scope unchanged\n")
