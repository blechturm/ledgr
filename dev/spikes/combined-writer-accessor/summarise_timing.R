# Shared by spike_runner.R and spike_checker.R: summarises paired base versus
# combined repetitions, keyed by instruments and workflow, and the four-arm
# additivity blocks.
summarise_timing <- function(timing) {
  if ("kept" %in% names(timing)) timing <- timing[timing$kept %in% TRUE, ]   # discarded load attempts stay in the CSV only
  keys <- unique(timing[c("instruments", "workflow")])
  rows <- lapply(seq_len(nrow(keys)), function(i) {
    t <- timing[timing$instruments == keys$instruments[[i]] & timing$workflow == keys$workflow[[i]], ]
    b <- t[t$arm == "base", ]; k <- t[t$arm == "combined", ]
    b <- b[order(b$rep), ]; k <- k[order(k$rep), ]
    paired <- b$elapsed_s - k$elapsed_s
    q <- function(x, p) unname(stats::quantile(x, p, type = 7))
    data.frame(
      instruments = keys$instruments[[i]], workflow = keys$workflow[[i]], reps = nrow(b),
      base_median_s = round(stats::median(b$elapsed_s), 3),
      base_rel_iqr = round(stats::IQR(b$elapsed_s) / stats::median(b$elapsed_s), 3),
      combined_median_s = round(stats::median(k$elapsed_s), 3),
      combined_rel_iqr = round(stats::IQR(k$elapsed_s) / stats::median(k$elapsed_s), 3),
      ratio_combined_to_base = round(stats::median(k$elapsed_s) / stats::median(b$elapsed_s), 3),
      paired_saving_median_s = round(stats::median(paired), 3),
      paired_saving_q25_s = round(q(paired, 0.25), 3),
      paired_saving_q75_s = round(q(paired, 0.75), 3),
      paired_saving_median_pct = round(100 * stats::median(paired / b$elapsed_s), 2)
    )
  })
  do.call(rbind, rows)
}

# Per workflow and arm: median time, and the within-repetition saving against base. The
# interaction is, per repetition, the combined saving minus the sum of the two single
# savings; zero means the changes add, negative means they overlap.
summarise_additivity <- function(d) {
  d <- d[d$kept %in% TRUE, ]
  rows <- lapply(split(d, d$workflow), function(t) {
    wide <- stats::reshape(t[c("rep", "arm", "elapsed_s")], idvar = "rep", timevar = "arm", direction = "wide")
    wide <- wide[order(wide$rep), ]
    saving <- function(arm) wide$elapsed_s.base - wide[[paste0("elapsed_s.", arm)]]
    interaction <- saving("combined") - saving("block") - saving("prepared")
    data.frame(workflow = t$workflow[[1L]], arm = c("base", "block", "prepared", "combined", "interaction"), reps = nrow(wide),
      median_s = c(vapply(c("base", "block", "prepared", "combined"), function(a) round(stats::median(wide[[paste0("elapsed_s.", a)]]), 3), 1), NA),
      saving_median_s = c(NA, vapply(c("block", "prepared", "combined"), function(a) round(stats::median(saving(a)), 3), 1),
        round(stats::median(interaction), 3)),
      saving_min_s = c(NA, vapply(c("block", "prepared", "combined"), function(a) round(min(saving(a)), 3), 1), round(min(interaction), 3)),
      saving_max_s = c(NA, vapply(c("block", "prepared", "combined"), function(a) round(max(saving(a)), 3), 1), round(max(interaction), 3)),
      saving_median_pct = c(NA, vapply(c("block", "prepared", "combined"), function(a) round(100 * stats::median(saving(a) / wide$elapsed_s.base), 2), 1), NA))
  })
  out <- do.call(rbind, rows); rownames(out) <- NULL; out
}
