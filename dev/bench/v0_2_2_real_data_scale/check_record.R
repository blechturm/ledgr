# Real-data scale checker (Cut 11 LDG-2982).
#
#   Rscript check_record.R <accepted_dir> <candidate_dir>
#   Rscript check_record.R <record_dir> --self-test
#
# Compares every comparison family byte for byte. A family missing on either
# side fails. The `identity` family is informational: ledgr fingerprints
# implementation bodies, so a behavior-preserving change may move a hash; it is
# reported, never silently accepted, and its acceptance is a review decision.
# --self-test perturbs one cell of each family in a copy of the record and
# requires that exactly that family fails.

args <- commandArgs(trailingOnly = TRUE)
families_of <- function(dir) sort(list.files(file.path(dir, "families"), pattern = "\\.csv$"))
compare <- function(a, b) {
  fa <- families_of(a)
  fb <- families_of(b)
  all <- union(fa, fb)
  status <- vapply(all, function(f) {
    pa <- file.path(a, "families", f)
    pb <- file.path(b, "families", f)
    if (!file.exists(pa) || !file.exists(pb)) return("missing")
    if (identical(unname(tools::md5sum(pa)), unname(tools::md5sum(pb)))) "identical" else "different"
  }, character(1))
  data.frame(family = sub("\\.csv$", "", all), status = status, row.names = NULL, stringsAsFactors = FALSE)
}

if (length(args) >= 2L && identical(args[[2L]], "--self-test")) {
  base <- args[[1L]]
  results <- character()
  for (f in families_of(base)) {
    copy <- tempfile("selftest")
    dir.create(file.path(copy, "families"), recursive = TRUE)
    file.copy(file.path(base, "families", families_of(base)), file.path(copy, "families"))
    lines <- readLines(file.path(copy, "families", f))
    # Perturb the first data cell (or the header when the family is empty).
    k <- if (length(lines) >= 2L) 2L else 1L
    lines[[k]] <- paste0(lines[[k]], "x")
    writeLines(lines, file.path(copy, "families", f))
    cmp <- compare(base, copy)
    failing <- cmp$family[cmp$status != "identical"]
    ok <- identical(failing, sub("\\.csv$", "", f))
    results[[f]] <- if (ok) "detected" else paste("NOT ISOLATED:", paste(failing, collapse = ","))
    unlink(copy, recursive = TRUE)
  }
  bad <- results[results != "detected"]
  cat(sprintf("self-test: %d families, %d detected alone\n", length(results), sum(results == "detected")))
  if (length(bad)) print(bad)
  quit(status = if (length(bad)) 1L else 0L)
}

cmp <- compare(args[[1L]], args[[2L]])
gate <- cmp[cmp$family != "identity", , drop = FALSE]
for (i in which(cmp$status != "identical")) cat(sprintf("%-9s %s\n", toupper(cmp$status[[i]]), cmp$family[[i]]))
ident <- cmp$status[cmp$family == "identity"]
cat(sprintf("%d families compared, %d identical; identity family %s\n",
            nrow(gate), sum(gate$status == "identical"), if (length(ident)) ident else "absent"))
ok <- all(gate$status == "identical")
cat(if (ok) "SCALE_CHECK_OK\n" else "SCALE_CHECK_MISMATCH\n")
quit(status = if (ok) 0L else 1L)
