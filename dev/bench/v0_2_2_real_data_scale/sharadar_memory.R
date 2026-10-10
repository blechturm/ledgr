# Direct memory of one Sharadar workload (Cut 11 Workstream 22).
#
#   Rscript sharadar_memory.R <tree> <work_dir> <snapshot> <universe> <workload> <out_csv>
#
# workload: momentum | equal_weight | explain (a momentum run, then explain
# one instrument; only the explain call is measured). Reports the R heap at
# peak since a gc reset (gc max used, MB) and the process peak working set
# (ps peak_wset, MiB), which includes everything before the workload. The
# snapshot is copied into <work_dir> and removed afterwards; the output holds
# aggregates only.

args <- commandArgs(trailingOnly = TRUE)
tree <- args[[1L]]; work <- args[[2L]]; source_snapshot <- args[[3L]]; universe <- args[[4L]]
workload <- args[[5L]]; out_csv <- args[[6L]]
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all(tree, quiet = TRUE, compile = FALSE))
source(file.path(tree, "dev/bench/v0_2_2_real_data_scale/fixture.R"))
# Append-size variants are measured as committed trees, never by namespace
# overrides: an override wrapper inflated the heap by about 550 MB on its own.
dir.create(work, recursive = TRUE, showWarnings = FALSE)
snap_path <- file.path(work, "sharadar.duckdb")
stopifnot(file.copy(source_snapshot, snap_path, overwrite = TRUE))
snapshot <- ledgr_snapshot_open(snap_path)
experiment <- function(strategy, features = list()) {
  ledgr_experiment(snapshot, strategy, features = features, universe = ledgr_universe_members(universe),
                   valuation_policy = ledgr_valuation_stale(5), cost_model = ledgr_cost_zero(),
                   opening = ledgr_opening(cash = 1e6))
}
momentum <- function() ledgr_run(experiment(scale_momentum, list(ledgr_ind_returns(252L))),
                                 params = list(lookback = 252L, n = 20L), run_id = "mem-momentum")
rss_peak <- function() ps::ps_memory_info(ps::ps_handle())[["peak_wset"]] / 2^20

if (identical(workload, "explain")) {
  bt <- momentum()
  pick <- unique(ledgr_results(bt, "fills")$instrument_id)[[1L]]
  invisible(gc(reset = TRUE))
  t0 <- Sys.time(); invisible(ledgr_run_explain(bt, pick)); elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
} else {
  invisible(gc(reset = TRUE))
  t0 <- Sys.time()
  bt <- if (identical(workload, "momentum")) momentum() else
    ledgr_run(experiment(scale_equal_weight), params = list(f = 0.95), run_id = "mem-ew")
  elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
}
heap <- sum(gc()[, 6L])
out <- data.frame(tree = tree, workload = workload, heap_peak_mb = round(heap, 1),
                  process_peak_mib = round(rss_peak()), elapsed_s = round(elapsed, 2))
close(bt)
ledgr_snapshot_close(snapshot)
unlink(work, recursive = TRUE)
utils::write.csv(out, out_csv, row.names = FALSE)
print(out, row.names = FALSE)
