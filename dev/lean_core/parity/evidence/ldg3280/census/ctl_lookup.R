# Map file:line pairs to their test_that block (fork part_controls lookup).
#   Rscript ctl_lookup.R file:line [file:line ...]
b <- utils::read.csv("C:/Users/maxth/ledgr-wt/cut27-scratch/out/ldg3280/census_hits.csv", stringsAsFactors = FALSE)
for (a in commandArgs(TRUE)) {
  f <- sub(":.*$", "", a); l <- as.integer(sub("^.*:", "", a))
  i <- which(b$file == f & b$first <= l & b$last >= l)
  if (!length(i)) { cat(a, "-> (top level)\n"); next }
  i <- i[which.max(b$first[i])]
  st <- if (b$probe_failed[i] > 0 || isTRUE(b$probe_error[i])) "fail" else if (isTRUE(b$probe_skipped[i])) "skip" else "pass"
  cat(sprintf("%s -> %d-%d [%s seed=%s] %s\n", a, b$first[i], b$last[i], st, b$in_seed[i], b$test[i]))
}
