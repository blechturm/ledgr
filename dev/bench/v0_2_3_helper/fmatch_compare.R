# Cut 17 (LDG-3233): base match() against collapse::fmatch() on the operand
# shapes of the rewritten sites: a requested subset of about half the
# universe matched against the universe (S01b, S08, S12, S15/S16), and the
# universe matched against a subset (S08's universe-side membership). Each
# variant is timed in alternating 0.3 s batches, 7 rounds; the medians are
# compared. Run under the host policy (pcore.ps1, High performance).
#
#   Rscript dev/bench/v0_2_3_helper/fmatch_compare.R --out=<csv>

args <- commandArgs(trailingOnly = TRUE)
out <- sub("^--out=", "", grep("^--out=", args, value = TRUE)[[1L]])
elapsed <- function() as.numeric(Sys.time())
per_call <- function(f, budget = 0.3) {
  f(); m <- 0L; t0 <- elapsed()
  while (elapsed() - t0 < budget) { for (i in 1:100) f(); m <- m + 100L }
  1e6 * (elapsed() - t0) / m
}
rows <- list()
for (n in c(10L, 500L, 1166L)) {
  universe <- sprintf("P%04d", seq_len(n))
  subset_ids <- universe[rev(seq(1L, n, by = 2L))]
  shapes <- list(subset_in_universe = list(x = subset_ids, table = universe),
                 universe_in_subset = list(x = universe, table = subset_ids))
  for (s in names(shapes)) {
    x <- shapes[[s]]$x; tb <- shapes[[s]]$table
    stopifnot(identical(match(x, tb, 0L), collapse::fmatch(x, tb, nomatch = 0L)))
    base_f <- function() match(x, tb, 0L)
    coll_f <- function() collapse::fmatch(x, tb, nomatch = 0L)
    b <- numeric(); cc <- numeric()
    for (r in 1:7) {
      if (r %% 2L) { b <- c(b, per_call(base_f)); cc <- c(cc, per_call(coll_f)) }
      else { cc <- c(cc, per_call(coll_f)); b <- c(b, per_call(base_f)) }
    }
    rows[[length(rows) + 1L]] <- data.frame(instruments = n, shape = s, x_length = length(x), table_length = length(tb),
      match_us = stats::median(b), fmatch_us = stats::median(cc), ratio = stats::median(cc) / stats::median(b),
      stringsAsFactors = FALSE)
  }
}
res <- do.call(rbind, rows)
utils::write.csv(res, out, row.names = FALSE)
print(res, row.names = FALSE, digits = 3)
