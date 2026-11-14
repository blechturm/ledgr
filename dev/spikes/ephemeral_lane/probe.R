# Spike ephemeral_lane, probe (spike protocol section 1): what a one-
# candidate, one-worker ledgr_sweep() returns on the lean loop, and which of
# its values the durable run's results can reproduce.
#
#   Rscript dev/spikes/ephemeral_lane/probe.R --lib=<pin library> [--shape=10x300]

args <- commandArgs(trailingOnly = TRUE)
opt <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
}
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
source(file.path(repo, "dev/spikes/lean_fifo_cpp/lean_env.R"))
env <- spike_lean_env(normalizePath(opt("lib"), winslash = "/"), repo)
shape <- opt("shape", "10x300")
desc <- env$defs$bench_descriptor(shape)
store <- tempfile(fileext = ".duckdb")
ledgr::ledgr_snapshot_close(ledgr::ledgr_snapshot_from_df(desc$bars(), db_path = store, snapshot_id = "eph", price_basis = "split_adjusted"))
snapshot <- ledgr::ledgr_snapshot_open(store, "eph", verify = TRUE)
exp <- desc$experiment(snapshot)
restore <- env$lean$lean_loop_install()
folds0 <- env$lean$lean_entry$lean_folds %||% 0L
grid <- ledgr::ledgr_grid_named(a = list(strategy = list()))
sw <- suppressWarnings(ledgr::ledgr_sweep(exp, grid, seed = 20260530L))
cat("lean folds in the sweep:", env$lean$lean_entry$lean_folds - folds0, "\n")
cat("sweep result class:", paste(class(sw), collapse = "/"), "\n")
str(as.data.frame(sw), max.level = 1, give.attr = FALSE)
bt <- suppressWarnings(ledgr::ledgr_run(exp, run_id = "eph", seed = 20260530L))
cat("lean folds after the run:", env$lean$lean_entry$lean_folds - folds0, "\n")
eq <- ledgr::ledgr_results(bt, "equity")
fills <- ledgr::ledgr_results(bt, "fills")
cat(sprintf("durable: final equity %.17g, fills %d\n", eq$equity[nrow(eq)], nrow(fills)))
m <- ledgr::ledgr_compute_metrics(bt); s <- as.data.frame(sw)
for (k in intersect(names(m), names(s))) cat(sprintf("  %-18s durable %-22s sweep %-22s identical %s\n", k, format(m[[k]], digits = 17), format(s[[k]], digits = 17), identical(unname(m[[k]]), unname(s[[k]]))))
close(bt); restore(); ledgr::ledgr_snapshot_close(snapshot)
