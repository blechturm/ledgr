# Shared by spike_runner.R and spike_checker.R: summarises paired base versus
# prepared repetitions, keyed by instruments and workflow.
summarise_timing <- function(timing) {
  if ("kept" %in% names(timing)) timing <- timing[timing$kept %in% TRUE, ]   # discarded load attempts stay in the CSV only
  keys <- unique(timing[c("instruments", "workflow")])
  rows <- lapply(seq_len(nrow(keys)), function(i) {
    t <- timing[timing$instruments == keys$instruments[[i]] & timing$workflow == keys$workflow[[i]], ]
    b <- t[t$arm == "base", ]; k <- t[t$arm == "prepared", ]
    b <- b[order(b$rep), ]; k <- k[order(k$rep), ]
    paired <- b$elapsed_s - k$elapsed_s
    q <- function(x, p) unname(stats::quantile(x, p, type = 7))
    data.frame(
      instruments = keys$instruments[[i]], workflow = keys$workflow[[i]], reps = nrow(b),
      base_median_s = round(stats::median(b$elapsed_s), 3),
      base_rel_iqr = round(stats::IQR(b$elapsed_s) / stats::median(b$elapsed_s), 3),
      prepared_median_s = round(stats::median(k$elapsed_s), 3),
      prepared_rel_iqr = round(stats::IQR(k$elapsed_s) / stats::median(k$elapsed_s), 3),
      ratio_prepared_to_base = round(stats::median(k$elapsed_s) / stats::median(b$elapsed_s), 3),
      paired_saving_median_s = round(stats::median(paired), 3),
      paired_saving_q25_s = round(q(paired, 0.25), 3),
      paired_saving_q75_s = round(q(paired, 0.75), 3),
      paired_saving_median_pct = round(100 * stats::median(paired / b$elapsed_s), 2)
    )
  })
  do.call(rbind, rows)
}
