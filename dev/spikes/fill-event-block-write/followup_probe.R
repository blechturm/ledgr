# Follow-up probe for the fill-event block-write spike: where the current code
# spends time, and how the block-write saving scales with universe width.
# Supplementary evidence; the checker validates its shape but does not rerun it.
#
# Usage, from the repository root:
#   Rscript dev/spikes/fill-event-block-write/followup_probe.R [--out <dir>] [--reps <n>]
# Writes hotspots.csv (one sampled profile each of a canonical run, a canonical
# one-candidate sweep and a compiled spot_fifo sweep at 500 x 1,260) and
# width_scaling.csv (base vs block at 10, 50 and 150 instruments).

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(flag, default) { i <- match(flag, args); if (is.na(i) || i == length(args)) default else args[[i + 1L]] }
spike_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo_root <- normalizePath(file.path(spike_dir, "..", "..", ".."), winslash = "/")
out_dir <- arg_value("--out", file.path(spike_dir, "evidence"))
reps <- as.integer(arg_value("--reps", "3"))
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
suppressMessages(pkgload::load_all(repo_root, quiet = TRUE, compile = FALSE))
ns <- asNamespace("ledgr")
source(file.path(spike_dir, "seam.R"))
block <- bw_block_functions(ns)
quiet <- function(expr) suppressWarnings(suppressMessages(expr))
log_line <- function(...) cat(sprintf("[%s] ", format(Sys.time(), "%H:%M:%S")), ..., "\n", sep = "")

seal <- function(n) {
  bars <- as.data.frame(ledgr_sim_bars(n_instruments = n, n_days = 1260L, seed = 20260530L))
  path <- tempfile(fileext = ".duckdb")
  s <- ledgr_snapshot_from_df(bars, db_path = path, snapshot_id = "s"); ledgr_snapshot_close(s)
  path
}
exp_of <- function(snapshot) ledgr_experiment(snapshot, ledgr_demo_sma_crossover_strategy(),
  features = ledgr_feature_map(fast = ledgr_ind_sma(ledgr_param("fast_n")), slow = ledgr_ind_sma(ledgr_param("slow_n"))),
  opening = ledgr_opening(cash = 1e7), cost_model = ledgr_cost_zero())
grid1 <- ledgr_grid_cross(features = ledgr_feature_grid(fast_n = 5L, slow_n = 10L), strategy = ledgr_strategy_grid(qty = 1, threshold = 0))
run_once <- function(pristine, fns, id) {
  path <- tempfile(fileext = ".duckdb"); file.copy(pristine, path)
  snapshot <- ledgr_snapshot_open(path, "s")
  run <- bw_with(ns, fns, quiet(ledgr_run(exp_of(snapshot), params = list(qty = 1, threshold = 0),
    feature_params = list(fast_n = 5L, slow_n = 10L), run_id = id, seed = 1L)))
  fills <- nrow(ledgr_results(run, what = "fills")); invisible(ledgr_results(run, what = "equity")); close(run)
  ledgr_snapshot_close(snapshot); unlink(path)
  fills
}
sweep_once <- function(path, fns, compiled = NULL) {
  snapshot <- ledgr_snapshot_open(path, "s"); on.exit(ledgr_snapshot_close(snapshot))
  invisible(bw_with(ns, fns, quiet(ledgr_sweep(exp_of(snapshot), grid1, seed = 1L, compiled_accounting_model = compiled))))
}

# 1. Hotspots of the current production code at release shape.
log_line("hotspot profiles")
p500 <- seal(500L)
focus <- c("ledgr_execute_fold", "ledgr_call_strategy_fn", "ctx$features", "ledgr_feature_lookup_map",
  "ledgr_normalize_alias_map", "output_handler$write_fill_events", "ledgr_fill_event_payload", "canonical_json",
  "ledgr_lot_apply_fill", "ledgr_run_finalize", "ledgr_snapshot_hash", "output_handler$append_compiled_spot_batch",
  "ledgr_fill_row_buffer_add_many", "ledgr_run_compiled_spot_fifo_batch")
workloads <- list(
  ledgr_run = function() run_once(p500, NULL, sprintf("hot-%d", sample.int(1e6, 1L))),
  ledgr_sweep = function() sweep_once(p500, NULL),
  ledgr_sweep_compiled_spot_fifo = function() sweep_once(p500, NULL, "spot_fifo"))
hotspots <- list()
for (w in names(workloads)) {
  invisible(workloads[[w]]())                                   # warm-up
  prof <- tempfile(fileext = ".Rprof")
  t0 <- Sys.time(); utils::Rprof(prof, interval = 0.01)
  invisible(workloads[[w]]())
  utils::Rprof(NULL); wall <- as.numeric(Sys.time() - t0, units = "secs")
  s <- utils::summaryRprof(prof); unlink(prof)
  tot <- s$by.total
  hotspots[[w]] <- data.frame(workload = w, fn = focus,
    total_seconds = vapply(focus, function(f) { v <- tot[sprintf("\"%s\"", f), "total.time"]; if (is.na(v)) 0 else v }, 1),
    sampled_seconds = s$sampling.time, wall_seconds = round(wall, 2))
}
utils::write.csv(do.call(rbind, hotspots), file.path(out_dir, "hotspots.csv"), row.names = FALSE)
unlink(p500)

# 2. Width scaling of the block-write saving.
rows <- list()
for (n in c(10L, 50L, 150L)) {
  log_line("width ", n)
  pristine <- seal(n)
  sweep_path <- tempfile(fileext = ".duckdb"); file.copy(pristine, sweep_path)
  k <- 0L
  go <- function(workflow, arm) {
    fns <- if (arm == "block") block else NULL
    invisible(gc()); t0 <- Sys.time()
    fills <- if (workflow == "ledgr_run") { k <<- k + 1L; run_once(pristine, fns, sprintf("w%03d", k)) } else { sweep_once(sweep_path, fns); NA_integer_ }
    c(as.numeric(Sys.time() - t0, units = "secs"), fills)
  }
  for (workflow in c("ledgr_run", "ledgr_sweep")) {
    invisible(go(workflow, "base")); invisible(go(workflow, "block"))
    for (r in seq_len(reps)) for (pos in 1:2) {
      arm <- (if (r %% 2L == 1L) c("base", "block") else c("block", "base"))[[pos]]
      v <- go(workflow, arm)
      rows[[length(rows) + 1L]] <- data.frame(instruments = n, workflow = workflow, rep = r, position = pos, arm = arm,
        elapsed_s = v[[1L]], fills = v[[2L]])
    }
  }
  unlink(c(pristine, sweep_path))
}
utils::write.csv(do.call(rbind, rows), file.path(out_dir, "width_scaling.csv"), row.names = FALSE)
log_line("follow-up evidence written")
