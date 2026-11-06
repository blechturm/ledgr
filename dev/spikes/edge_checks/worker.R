# One tree, one workload, in its own R process (two trees cannot share a
# session: both are package ledgr).
#
#   Rscript worker.R --tree=<dir> --workload=momentum|fill_heavy --reps=<n> --out=<dir>
#
# Writes <out>/<label>_timing.csv (the fold's t_loop and the run's wall per
# repetition), <label>_results.rds (ledger, equity and diagnostics of the
# first repetition) and <label>_edge.csv (what a strategy returning a missing
# target raises).

local({
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])))
  entry <- file.path(here, "..", "..", "bench", "v0_2_3_ws16_entry")
  source(file.path(entry, "common.R"))
  source(file.path(entry, "workloads.R"))
})
tree <- normalizePath(ws16_need("tree"), winslash = "/")
workload <- ws16_need("workload")
reps <- as.integer(ws16_need("reps"))
out <- ws16_out(ws16_need("out"))
commit <- ws16_load_source(tree)
label <- paste0(sub("^d5b3a151\\+?", "", commit), if (identical(commit, "d5b3a151")) "pinned" else "", "_", workload)
if (!startsWith(commit, "d5b3a151")) stop("tree is not built from the d5b3a151 pin", call. = FALSE)

t_loop <- NA_real_
ws16_wrap("ledgr_fold_envelope", function(orig) {
  force(orig)
  function(execution, output_handler) {
    res <- orig(execution, output_handler)
    t_loop <<- res$telemetry$t_loop
    res
  }
})

work <- file.path(tempdir(), "edge_checks")
dir.create(work, showWarnings = FALSE)
if (identical(workload, "momentum")) {
  snapshot <- ws16_momentum_snapshot(40L, 504L, file.path(work, "m.duckdb"), "ec_momentum")
  exp <- ws16_momentum_experiment(snapshot, 63L)
  run <- function(id) ledgr_run(exp, params = list(lookback = 63L, n = 10L), run_id = id, seed = 1L)
  pulses <- 504L
} else {
  snapshot <- ledgr_snapshot_from_df(ws16_fill_heavy_bars(), db_path = file.path(work, "f.duckdb"),
                                     snapshot_id = "ec_fill")
  exp <- ws16_fill_heavy_experiment(snapshot)
  run <- function(id) suppressWarnings(ledgr_run(exp, run_id = id, seed = 20260530L))
  pulses <- 1260L
}

close(run("ec-warm"))
timing <- list()
for (r in seq_len(reps)) {
  t0 <- ledgr_time_now()
  bt <- run(sprintf("ec-%s-%d", workload, r))
  wall <- ledgr_time_elapsed(t0, ledgr_time_now())
  if (r == 1L) {
    saveRDS(lapply(c(ledger = "ledger", equity = "equity", diagnostics = "diagnostics"),
                   function(w) as.data.frame(ledgr_results(bt, w))),
            file.path(out, paste0(label, "_results.rds")))
  }
  close(bt)
  timing[[r]] <- data.frame(tree = sub("_.*$", "", label), workload = workload, rep = r,
                            loop_us_per_pulse = 1e6 * t_loop / pulses, run_wall_s = wall)
}
ws16_write(do.call(rbind, timing), file.path(out, paste0(label, "_timing.csv")))

# The strategy edge stays: a missing target is refused in every tree.
bad <- ledgr_experiment(snapshot, function(ctx, params) {
  x <- ctx$hold()
  x[[1L]] <- NA_real_
  x
}, opening = ledgr_opening(cash = 1e6), cost_model = ledgr_cost_zero())
e <- tryCatch({ close(ledgr_run(bad, run_id = "ec-edge", seed = 1L)); NULL }, error = function(e) e)
ws16_write(data.frame(tree = sub("_.*$", "", label), workload = workload,
                      refused = !is.null(e), class = if (is.null(e)) "" else class(e)[[1L]]),
           file.path(out, paste0(label, "_edge.csv")))
ledgr_snapshot_close(snapshot)
cat("worker", label, "done\n")
