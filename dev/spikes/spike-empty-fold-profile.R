# Spike: line-level profile of the per-pulse "empty-fold" machinery bucket.
#
# spike-amdahl-floor.R showed the empty fold (no features, no trades) is a large
# slice of the loop at modest turnover, and attributed it loosely to "ctx-build".
# Codex review: "empty" is NOT pure ctx-build -- it also includes bars/current-
# pulse plumbing, positions/equity bookkeeping, target handling, and the output
# wrapper. This spike runs a real empty ledgr fold under Rprof and reports
# function self-time so the bucket can actually be split.
#
# Reuses the bench harness setup (ledgr_sim_bars + flat strategy + ledgr_run);
# does not reinvent the run path. Relates to: spike-amdahl-floor.md, the
# architecture synthesis L2. Usage: Rscript dev/spikes/spike-empty-fold-profile.R

suppressWarnings(suppressMessages(source(file.path("dev", "bench", "run_benchmarks.R"))))
bench_load_ledgr_source()

N_INST <- 500L; N_PULSES <- 1260L; REPS <- 3L
seed <- 20260529L

bars <- bench_make_bars(N_INST, N_PULSES, seed)
db_path <- tempfile(pattern = "ledgr_emptyfold_", fileext = ".duckdb")
snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
on.exit({ try(ledgr_snapshot_close(snapshot), silent = TRUE); unlink(db_path) }, add = TRUE)

flat_strategy <- function(ctx, params) ctx$flat()        # no features, no trades
exp <- ledgr_experiment(
  snapshot = snapshot, strategy = flat_strategy, features = list(),
  opening = ledgr_opening(cash = 1e7), persist_features = FALSE
)

cat(sprintf("empty fold: %d inst x %d pulses, %d reps under Rprof\n\n", N_INST, N_PULSES, REPS))

prof <- tempfile(fileext = ".out")
Rprof(prof, interval = 0.002, line.profiling = FALSE)
for (k in seq_len(REPS)) {
  rid <- sprintf("emptyfold_%02d_%s", k, paste(sample(c(0:9, letters), 6L, TRUE), collapse = ""))
  bt <- ledgr_run(exp, params = list(qty = 1), run_id = rid, seed = seed + k)
  try(close(bt), silent = TRUE)
}
Rprof(NULL)

sr <- summaryRprof(prof)
self <- sr$by.self
total_self <- sum(self$self.time)
cat(sprintf("total sampled self-time: %.2fs across %d reps (%.2fs/run)\n\n", total_self, REPS, total_self / REPS))
cat("Top 30 functions by self-time:\n")
top <- utils::head(self, 30L)
for (i in seq_len(nrow(top))) {
  cat(sprintf("  %6.2fs  %5.1f%%  %s\n", top$self.time[i], 100 * top$self.time[i] / total_self, rownames(top)[i]))
}

out <- "dev/bench/results/spike_empty_fold_profile.csv"
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(data.frame(fn = rownames(self), self_time = self$self.time,
                            self_pct = 100 * self$self.time / total_self),
                 out, row.names = FALSE)
cat("\nWROTE", out, "\n")
