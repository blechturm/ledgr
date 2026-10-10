# Direct reader memory and time (Cut 11 LDG-2983 follow-up).
#
#   Rscript reader_check.R <tree> <out_csv>
#
# The paired phase clocks attribute resident memory to short phases poorly:
# a 1.5 s phase inherits whatever earlier phases left uncollected. This
# measures the two readers LDG-2983 rewrote on their own: R heap allocated at
# peak (gc max used, after a reset) and the median of repeated timings, for
# ledgr_run_explain() on the scale fixture's momentum run and for the dense
# availability reader on the dense fixture.

args <- commandArgs(trailingOnly = TRUE)
tree <- args[[1L]]
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all(tree, quiet = TRUE, compile = FALSE))
source(file.path(tree, "dev/bench/v0_2_2_real_data_scale/fixture.R"))
work <- tempfile("reader_check")
dir.create(work)

measure <- function(reader, expr_fn, reps) {
  invisible(gc(reset = TRUE))
  invisible(expr_fn())
  peak_mb <- sum(gc()[, 6L])
  times <- vapply(seq_len(reps), function(i) {
    t0 <- Sys.time(); invisible(expr_fn()); as.numeric(difftime(Sys.time(), t0, units = "secs"))
  }, numeric(1))
  data.frame(reader = reader, heap_peak_mb = round(peak_mb, 1), median_s = round(stats::median(times), 4), reps = reps)
}

snapshot <- scale_fixture_snapshot(file.path(work, "scale.duckdb"))
mom <- ledgr_run(ledgr_experiment(snapshot, scale_momentum, features = list(ledgr_ind_returns(60L)),
                                  universe = ledgr_universe_members("U"), valuation_policy = ledgr_valuation_stale(5),
                                  cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1e6)),
                 params = list(lookback = 60L, n = 20L), run_id = "check-momentum")
pick <- unique(ledgr_results(mom, "fills")$instrument_id)[[1L]]
dense <- scale_fixture_dense_snapshot(file.path(work, "dense.duckdb"))
dbt <- ledgr_run(ledgr_experiment(dense, function(ctx, params) {
  target <- ctx$flat(); target[ctx$universe[1:5]] <- 10; target
}, cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1e5)), run_id = "check-dense")

out <- rbind(
  measure("explain", function() ledgr_run_explain(mom, pick), reps = 3L),
  measure("dense_availability", function() ledgr_results(dbt, "availability"), reps = 20L)
)
close(mom); close(dbt)
ledgr_snapshot_close(snapshot); ledgr_snapshot_close(dense)
unlink(work, recursive = TRUE)
out$tree <- tree
utils::write.csv(out, args[[2L]], row.names = FALSE)
print(out, row.names = FALSE)
