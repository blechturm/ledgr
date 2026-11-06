# Write-mode probe runner.
#
#   Rscript run.R --pkg=<pinned tree at d5b3a151> --out=<dir> [--rounds=2] [--reps=2]
#
# Question: do the two durable write modes (`audit_log`, which buffers
# events and writes them later, and `db_live`, which inserts every fill
# during P4) produce identical stores, and what does each cost in time and
# memory? Builds both snapshots once, then runs worker.R per mode and
# workload, alternating modes, for `rounds` rounds. Writes parity.csv
# (ledger, equity and diagnostics of db_live against audit_log) and
# timing.csv (medians per mode and workload).

local({
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])))
  entry <- file.path(here, "..", "..", "bench", "v0_2_3_ws16_entry")
  source(file.path(entry, "common.R"))
  source(file.path(entry, "workloads.R"))
  assign("wm_here", here, envir = globalenv())
})
pkg <- normalizePath(ws16_need("pkg"), winslash = "/")
out <- ws16_out(ws16_need("out"))
rounds <- as.integer(ws16_arg("rounds", "2"))
reps <- as.integer(ws16_arg("reps", "2"))
commit <- ws16_load_source(pkg)
if (!identical(commit, "d5b3a151")) stop("source tree is not the d5b3a151 pin", call. = FALSE)

snaps <- file.path(out, "snapshots")
dir.create(snaps, showWarnings = FALSE)
m <- ws16_momentum_snapshot(40L, 504L, file.path(snaps, "momentum.duckdb"), "wm_momentum")
ledgr_snapshot_close(m)
f <- ledgr_snapshot_from_df(ws16_fill_heavy_bars(), db_path = file.path(snaps, "fill.duckdb"), snapshot_id = "wm_fill")
ledgr_snapshot_close(f)
snapshot <- list(momentum = c(file.path(snaps, "momentum.duckdb"), "wm_momentum"),
                 fill_heavy = c(file.path(snaps, "fill.duckdb"), "wm_fill"))

rscript <- file.path(R.home("bin"), "Rscript")
raw_dir <- file.path(out, "raw")
dir.create(raw_dir, showWarnings = FALSE)
for (r in seq_len(rounds)) for (w in names(snapshot)) for (mode in c("audit_log", "db_live")) {
  args <- c(file.path(wm_here, "worker.R"), paste0("--pkg=", pkg), paste0("--snapshot=", snapshot[[w]][[1L]]),
            paste0("--id=", snapshot[[w]][[2L]]), paste0("--workload=", w), paste0("--mode=", mode),
            paste0("--reps=", reps), paste0("--out=", raw_dir), if (r == 1L) "--parity")
  log <- file.path(raw_dir, sprintf("%s_%s_%d.log", mode, w, r))
  if (!identical(system2(rscript, args, stdout = log, stderr = log), 0L)) stop("worker failed: ", log, call. = FALSE)
}

parity <- do.call(rbind, lapply(names(snapshot), function(w) {
  a <- readRDS(file.path(raw_dir, paste0("audit_log_", w, "_results.rds")))
  b <- readRDS(file.path(raw_dir, paste0("db_live_", w, "_results.rds")))
  data.frame(workload = w, table = names(a), rows = vapply(a, nrow, 0L),
             identical = mapply(identical, a, b[names(a)]))
}))
ws16_write(parity, file.path(out, "parity.csv"))
raw <- do.call(rbind, lapply(list.files(raw_dir, "\\.csv$", full.names = TRUE), utils::read.csv))
ws16_write(raw, file.path(out, "timing_raw.csv"))
med <- aggregate(cbind(loop_us_per_pulse, run_wall_s, r_heap_peak_mb, process_peak_wset_mb) ~ mode + workload,
                 data = raw, FUN = stats::median)
med[-(1:2)] <- lapply(med[-(1:2)], round, 1)
med$run_wall_s <- round(aggregate(run_wall_s ~ mode + workload, data = raw, FUN = stats::median)$run_wall_s, 3)
ws16_write(med[order(med$workload, med$mode), ], file.path(out, "timing.csv"))
print(parity)
print(med)
