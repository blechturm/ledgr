# Workstream 46 (LDG-3076): incomplete lagged membership set compilation
# time on one tree (BASE: the family-wide epoch compiler; after Cut 16
# decision 22: the segment counter). Each shape is 500 weekday sessions, sets
# effective at evenly spaced sessions and known five sessions later, each
# listing a random half of the instruments, all incomplete.
#   Rscript membership_lagged_counts.R <tree> <label> <out.csv> <sets,...> <instruments,...>
args <- commandArgs(TRUE)
tree <- args[[1]]; label <- args[[2]]; out <- args[[3]]
sets_grid <- as.integer(strsplit(args[[4]], ",")[[1]])
inst_grid <- as.integer(strsplit(args[[5]], ",")[[1]])
suppressMessages(pkgload::load_all(tree, quiet = TRUE, compile = FALSE))
fn <- if (exists("ledgr_history_membership_segment_counts", envir = asNamespace("ledgr"), inherits = FALSE)) {
  function(d, ids, axis) ledgr:::ledgr_history_membership_segment_counts(d, "U", ids, axis, NULL)$segment_count
} else {
  function(d, ids, axis) ledgr:::ledgr_history_membership_segments(d, "U", ids, axis, NULL)$segment_count
}
# 500 weekday sessions, or more when there are more than 450 sets, so every
# set takes effect on its own session.
n_sessions <- max(500L, max(sets_grid) + 50L)
days <- seq(as.Date("2020-01-01"), by = "day", length.out = ceiling(n_sessions * 7 / 5) + 14L)
days <- days[as.integer(format(days, "%u")) <= 5L][seq_len(n_sessions)]
axis <- as.POSIXct(paste(days, "21:00:00"), tz = "UTC")
for (n_inst in inst_grid) for (n_sets in sets_grid) {
  set.seed(n_sets * 1000L + n_inst)
  ids <- sprintf("I%04d", seq_len(n_inst))
  at <- as.integer(round(seq(1, n_sessions - 50L, length.out = n_sets)))
  sets <- ledgr_facts_membership_snapshots(
    data.frame(
      effective_from = axis[at],
      knowledge_time = axis[at + 5L],
      set_id = sprintf("set-%03d", seq_len(n_sets)),
      members = I(lapply(seq_len(n_sets), function(k) sample(ids, n_inst %/% 2L))),
      source = "timing", stringsAsFactors = FALSE
    ),
    universe_id = "U", complete = FALSE
  )
  data <- list(membership_sets = sets$headers, membership = sets$rows)
  gc()
  t0 <- proc.time()[["elapsed"]]
  counts <- fn(data, ids, axis)
  elapsed <- proc.time()[["elapsed"]] - t0
  row <- data.frame(arm = label, instruments = n_inst, sets = n_sets, sessions = length(axis),
                    elapsed = round(elapsed, 3), segments = sum(counts),
                    count_digest = digest::digest(counts), stringsAsFactors = FALSE)
  write.table(row, out, append = file.exists(out), col.names = !file.exists(out), row.names = FALSE, sep = ",")
  print(row)
}
