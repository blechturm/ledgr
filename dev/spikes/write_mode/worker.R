# One write mode, one workload, in its own R process.
#
#   Rscript worker.R --pkg=<tree> --snapshot=<duckdb file> --id=<snapshot id>
#                    --workload=momentum|fill_heavy --mode=audit_log|db_live
#                    --reps=<n> --out=<dir> [--parity]
#
# Copies the sealed snapshot file to a private path, so both modes can use
# the same run IDs, then times `reps` runs after one warm-up run. With
# --parity the first run uses the run ID `wm-<workload>` and its ledger,
# equity and diagnostics tables are saved for comparison across modes.
# Memory: the R heap's peak during each run (gc() max used, reset before the
# run) and the process's peak working set at exit (ps).

local({
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])))
  entry <- file.path(here, "..", "..", "bench", "v0_2_3_ws16_entry")
  source(file.path(entry, "common.R"))
  source(file.path(entry, "workloads.R"))
})
pkg <- normalizePath(ws16_need("pkg"), winslash = "/")
workload <- ws16_need("workload")
mode <- ws16_need("mode")
reps <- as.integer(ws16_need("reps"))
out <- ws16_out(ws16_need("out"))
parity <- "--parity" %in% commandArgs(TRUE)
commit <- ws16_load_source(pkg)
if (!identical(commit, "d5b3a151")) stop("source tree is not the d5b3a151 pin", call. = FALSE)

t_loop <- NA_real_
ws16_wrap("ledgr_fold_envelope", function(orig) {
  force(orig)
  function(execution, output_handler) {
    res <- orig(execution, output_handler)
    t_loop <<- res$telemetry$t_loop
    res
  }
})

db <- file.path(tempdir(), basename(ws16_need("snapshot")))
file.copy(ws16_need("snapshot"), db, overwrite = TRUE)
snapshot <- ledgr_snapshot_open(db, ws16_need("id"))
if (identical(workload, "momentum")) {
  exp <- ledgr_experiment(
    snapshot, ws16_momentum_strategy,
    features = list(ledgr_ind_returns(63L)), schedule = ledgr_schedule_month_start(),
    opening = ledgr_opening(cash = 1e6), cost_model = ledgr_cost_zero(), execution_mode = mode)
  run <- function(id) ledgr_run(exp, params = list(lookback = 63L, n = 10L), run_id = id, seed = 1L)
  pulses <- 504L
} else {
  features <- ledgr_feature_map(
    fast = ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
    slow = ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L))
  exp <- ledgr_experiment(
    snapshot, ws16_fill_heavy_strategy, features = features,
    opening = ledgr_opening(cash = 1e7), cost_model = ledgr_cost_zero(),
    risk_chain = ledgr_risk_none(), asset_state = list(above = FALSE, usable = FALSE),
    execution_mode = mode)
  run <- function(id) suppressWarnings(ledgr_run(exp, run_id = id, seed = 20260530L))
  pulses <- 1260L
}

close(run(paste0("wm-warm-", mode)))
rows <- list()
for (r in seq_len(reps)) {
  id <- if (parity && r == 1L) paste0("wm-", workload) else sprintf("wm-%s-%s-%d", workload, mode, r)
  invisible(gc(reset = TRUE))
  base <- sum(gc()[, 2L])
  t0 <- ledgr_time_now()
  bt <- run(id)
  wall <- ledgr_time_elapsed(t0, ledgr_time_now())
  heap_peak <- sum(gc()[, 6L]) - base
  if (parity && r == 1L) {
    saveRDS(lapply(c(ledger = "ledger", equity = "equity", diagnostics = "diagnostics"),
                   function(w) as.data.frame(ledgr_results(bt, w))),
            file.path(out, paste0(mode, "_", workload, "_results.rds")))
  }
  close(bt)
  rows[[r]] <- data.frame(mode = mode, workload = workload, rep = r,
                          loop_us_per_pulse = 1e6 * t_loop / pulses, run_wall_s = wall,
                          r_heap_peak_mb = heap_peak)
}
timing <- do.call(rbind, rows)
timing$process_peak_wset_mb <- ps::ps_memory_info()[["peak_wset"]] / 2^20
ws16_write(timing, file.path(out, paste0(mode, "_", workload, "_", format(Sys.time(), "%H%M%S"), ".csv")))
ledgr_snapshot_close(snapshot)
cat("worker", mode, workload, "done\n")
