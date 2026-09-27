# Shared by spike_runner.R and spike_checker.R: derives timing_summary.csv
# from the raw repetitions in timing.csv so the checker can recompute it.
summarise_timing <- function(timing) {
  keys <- unique(timing[c("case", "site", "op")])
  q <- function(x, p) unname(stats::quantile(x, p, type = 7))
  rows <- lapply(seq_len(nrow(keys)), function(i) {
    k <- keys[i, ]
    t <- timing[timing$case == k$case & timing$site == k$site & timing$op == k$op, ]
    b <- t[t$arm == "base", ]; r <- t[t$arm == "rsplit", ]
    b <- b[order(b$rep), ]; r <- r[order(r$rep), ]
    paired <- b$elapsed_s - r$elapsed_s
    data.frame(
      case = k$case, site = k$site, op = k$op, reps = nrow(b),
      base_median_ms = round(1000 * stats::median(b$elapsed_s), 2),
      base_rel_iqr = round(stats::IQR(b$elapsed_s) / stats::median(b$elapsed_s), 3),
      rsplit_median_ms = round(1000 * stats::median(r$elapsed_s), 2),
      rsplit_rel_iqr = round(stats::IQR(r$elapsed_s) / stats::median(r$elapsed_s), 3),
      ratio_rsplit_to_base = round(stats::median(r$elapsed_s) / stats::median(b$elapsed_s), 3),
      paired_saving_median_ms = round(1000 * stats::median(paired), 2),
      paired_saving_q25_ms = round(1000 * q(paired, 0.25), 2),
      paired_saving_q75_ms = round(1000 * q(paired, 0.75), 2),
      base_gc_median_ms = round(1000 * stats::median(b$gc_s), 2),
      rsplit_gc_median_ms = round(1000 * stats::median(r$gc_s), 2)
    )
  })
  do.call(rbind, rows)
}
