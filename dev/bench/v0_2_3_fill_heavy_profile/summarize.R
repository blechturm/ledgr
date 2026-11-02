S <- commandArgs(trailingOnly = TRUE)[[1]]
builds <- list(
  v0.2.2 = list(commit = "7539be45", timing = "out-v022", cls = "cls-v022"),
  cut6 = list(commit = "14252ffb", timing = c("alt-cut6-1", "alt-cut6-2"), cls = "cls-alt-cut6"),
  cut7 = list(commit = "e04786ef", timing = c("alt-cut7-1", "alt-cut7-2"), cls = "cls-alt-cut7"))
timings <- do.call(rbind, lapply(names(builds), function(b) {
  t <- do.call(rbind, lapply(builds[[b]]$timing, function(d) read.csv(file.path(S, d, "timings.csv"))))
  t$build <- b; t$commit <- builds[[b]]$commit; t
}))
timed <- timings[!timings$profiled, ]
stages <- do.call(rbind, lapply(names(builds), function(b) {
  r <- read.csv(file.path(S, builds[[b]]$cls, "regions.csv"))
  run_wall <- median(timed$run[timed$build == b])
  in_run <- r[!r$region %in% c("results read", "other"), ]
  data.frame(build = b, commit = builds[[b]]$commit, region = c(in_run$region, "results read (fills)"),
    seconds = round(c(in_run$seconds / sum(in_run$seconds) * run_wall,
      median(timed$fills_read[timed$build == b])), 2))
}))
stages$ms_per_pulse <- round(stages$seconds / 1260 * 1000, 2)
out <- file.path(S, "evidence"); dir.create(out, showWarnings = FALSE)
write.csv(timings[c("build", "commit", "rep", "profiled", "run", "fills_read", "equity_read", "n_fills", "final_equity")],
  file.path(out, "timings.csv"), row.names = FALSE)
write.csv(stages, file.path(out, "stages.csv"), row.names = FALSE)
print(reshape(stages[c("build", "region", "seconds")], idvar = "region", timevar = "build", direction = "wide"), row.names = FALSE)
