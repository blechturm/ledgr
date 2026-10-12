# R heap max-used per phase (Cut 12 LDG-3015 to LDG-3018 evidence).
#
#   Rscript r_heap_probe.R <repo>
#
# Builds the fixture snapshot, then for each public phase resets R's gc
# statistics, runs the phase and prints the max-used heap (Ncells plus Vcells,
# MB) and elapsed seconds. Max-used heap excludes DuckDB's native memory, so
# it shows R's share of a peak; it still moves with when collection runs (a
# preset heap changes it), so a difference between two trees is a coarse
# signal of R allocation change, not a bound on it.
args <- commandArgs(trailingOnly = TRUE)
repo <- args[[1]]
suppressMessages(pkgload::load_all(repo, quiet = TRUE, compile = FALSE))
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]])))
source(file.path(here, "fixture.R"))
work <- tempfile("heap"); dir.create(work)
snapshot <- scale_fixture_snapshot(file.path(work, "scale.duckdb"), 800L, 1260L, 300L)
experiment <- function(strategy, features = list()) {
  ledgr_experiment(snapshot, strategy, features = features, universe = ledgr_universe_members("U"),
                   valuation_policy = ledgr_valuation_stale(5), cost_model = ledgr_cost_zero(),
                   opening = ledgr_opening(cash = 1e6))
}
heap <- function(label, expr) {
  invisible(gc(reset = TRUE, full = TRUE))
  t0 <- proc.time()[["elapsed"]]
  value <- force(expr)
  g <- gc()
  cat(sprintf("RESULT %s %.1f %.3f\n", label, sum(g[, 6]), proc.time()[["elapsed"]] - t0))
  invisible(value)
}
mom <- heap("run_momentum", ledgr_run(experiment(scale_momentum, list(ledgr_ind_returns(60L))), params = list(lookback = 60L, n = 20L), run_id = "m"))
heap("readers_momentum", for (w in c("equity", "returns", "fills", "trades", "ledger", "diagnostics")) ledgr_results(mom, w))
heap("availability", ledgr_results(mom, "availability"))
pick <- unique(ledgr_results(mom, "fills")$instrument_id)[[1L]]
heap("explain", as.data.frame(ledgr_run_explain(mom, pick)))
ew <- heap("run_equal_weight", ledgr_run(experiment(scale_equal_weight), params = list(f = 0.95), run_id = "e"))
heap("readers_equal_weight", for (w in c("equity", "returns", "fills", "trades", "ledger", "diagnostics")) ledgr_results(ew, w))
