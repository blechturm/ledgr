# profile-loop.R
#
# Rprof a single measured ledgr run to attribute fold cost by frame. It sources
# spike-feature-payload-dps.R, which loads SOURCE via pkgload::load_all and
# hard-fails on a stale install - so this harness profiles current source
# (v0.1.8.5+), never the installed build.
#
# CURRENT-SOURCE READING (v0.1.8.5): the fold LOOP is cheap (~5 ms/pulse). The
# dominant frames are pre-loop SETUP - feature-fingerprint cache-key
# construction (`t_pre`, ~50% at low/mid pulse counts) and pulse-view
# materialization (`gap`). The earlier "loop is the bottleneck / ~0.29 s/pulse"
# reading was an artifact of profiling the stale installed v0.1.8.0 build (which
# predates the v0.1.8.3 fast-context consolidation); it does NOT hold on source.
#
# Strategy: warm the feature cache with one run, then profile a single measured
# run; the by.self frames show where the time goes (fingerprinting vs view
# build vs the loop's fill/event/ctx work).
#
#   Rscript dev/spikes/profile-loop.R

source("dev/spikes/spike-feature-payload-dps.R")

cfg   <- list(n_inst = 100L, n_days = 126L, n_feat = 20L)
bars  <- make_panel(cfg$n_inst, cfg$n_days)
feats <- make_features(cfg$n_feat)
strat <- make_strategy(cfg$n_feat, trade = TRUE)

snap <- ledgr_snapshot_from_df(
  bars, snapshot_id = "prof_loop",
  db_path = file.path(tempdir(), "prof_loop.duckdb")
)
exp <- ledgr_experiment(
  snapshot = snap, strategy = strat,
  features = feats, opening = ledgr_opening(cash = 1e7)
)

# Warm the feature cache so the profiled run's t_pre is negligible.
invisible(close(ledgr_run(exp, params = list(qty = 1), run_id = "warm")))

prof <- tempfile(fileext = ".Rprof")
Rprof(prof, interval = 0.005, memory.profiling = FALSE)
bt <- ledgr_run(exp, params = list(qty = 1), run_id = "hot")
Rprof(NULL)
close(bt)

s <- summaryRprof(prof)
cat("== profiled config:", cfg$n_inst, "inst x", cfg$n_days, "pulses x",
    cfg$n_feat, "feat ==\n")
cat("total sampled seconds:", s$sampling.time, "\n\n")
cat("=== BY SELF TIME (top 30) ===\n")
print(utils::head(s$by.self, 30))
cat("\n=== BY TOTAL TIME (top 25) ===\n")
print(utils::head(s$by.total, 25))

ledgr_snapshot_close(snap)
