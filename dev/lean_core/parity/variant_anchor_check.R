# Every registered variant's edits still apply to the lean sources: each
# names an existing function and an anchor line found exactly once inside it
# (lean_apply_edits()). A static check, no workload runs; used after source
# edits that do not change behaviour (Cut 27's clarity pass, LDG-3277).
#   Rscript variant_anchor_check.R   exits 1 when an edit no longer applies
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
lean <- normalizePath(file.path(here, ".."), winslash = "/")
source(file.path(here, "loop_edits.R"))
# The variant definitions of loop_parity.R, evaluated without running it.
exprs <- parse(file.path(here, "loop_parity.R"), keep.source = FALSE)
want <- c("edit", "variant", "restored_variant", "store_variant", "loop_mutations")
env <- new.env()
for (e in exprs) {
  if (is.call(e) && identical(e[[1L]], as.name("<-")) && is.symbol(e[[2L]]) && as.character(e[[2L]]) %in% want) {
    eval(e, env)
  }
}
stopifnot(is.list(env$loop_mutations), length(env$loop_mutations) > 0L)
src <- list()
bad <- character()
for (m in names(env$loop_mutations)) {
  edits <- env$loop_mutations[[m]]$edits
  for (f in unique(vapply(edits, `[[`, "", "file"))) {
    if (is.null(src[[f]])) src[[f]] <- readLines(file.path(lean, f), warn = FALSE, encoding = "UTF-8")
    r <- tryCatch({ lean_apply_edits(src[[f]], Filter(function(e) identical(e$file, f), edits)); "" },
                  error = conditionMessage)
    if (nzchar(r)) bad <- c(bad, sprintf("%s (%s): %s", m, f, r))
  }
}
cat(length(env$loop_mutations), "variants checked\n")
if (length(bad)) cat(bad, sep = "\n")
cat(if (length(bad)) "VARIANT ANCHORS FAIL" else "VARIANT ANCHORS PASS", "\n")
quit(status = if (length(bad)) 1L else 0L)
