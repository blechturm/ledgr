# Shared by spike_runner.R and spike_checker.R: derives timing_summary.csv
# from the raw repetitions in timing.csv so the checker can recompute it.
summarise_timing <- function(timing) {
  rows <- lapply(unique(timing$workflow), function(w) {
    t <- timing[timing$workflow == w, ]
    b <- t[t$arm == "base", ]; k <- t[t$arm == "block", ]
    b <- b[order(b$rep), ]; k <- k[order(k$rep), ]
    paired <- b$elapsed_s - k$elapsed_s
    q <- function(x, p) unname(stats::quantile(x, p, type = 7))
    data.frame(
      workflow = w, reps = nrow(b),
      base_median_s = round(stats::median(b$elapsed_s), 3),
      base_rel_iqr = round(stats::IQR(b$elapsed_s) / stats::median(b$elapsed_s), 3),
      block_median_s = round(stats::median(k$elapsed_s), 3),
      block_rel_iqr = round(stats::IQR(k$elapsed_s) / stats::median(k$elapsed_s), 3),
      ratio_block_to_base = round(stats::median(k$elapsed_s) / stats::median(b$elapsed_s), 3),
      paired_saving_median_s = round(stats::median(paired), 3),
      paired_saving_q25_s = round(q(paired, 0.25), 3),
      paired_saving_q75_s = round(q(paired, 0.75), 3),
      paired_saving_median_pct = round(100 * stats::median(paired / b$elapsed_s), 2),
      base_gc_median_s = round(stats::median(b$gc_s), 2),
      block_gc_median_s = round(stats::median(k$gc_s), 2)
    )
  })
  do.call(rbind, rows)
}
