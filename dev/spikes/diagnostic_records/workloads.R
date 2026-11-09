# The spike's workloads, shared by probe.R and rebuild.R. Expects `repo`
# (the repository root) and `work` (a scratch directory) and the pinned ledgr
# loaded. Each builder returns the store path, the open snapshot, the
# experiment, its params and seed.

source(file.path(repo, "dev/bench/v0_2_3_ws16_entry/workloads.R"))
source(file.path(repo, "dev/bench/v0_2_3_output_freeze/lib.R"))
source(file.path(repo, "dev/spikes/r_floor/fixture.R"))
source(file.path(repo, "dev/lean_core/parity/prep_fixture.R"))

dr_fresh <- function(name) {
  db <- file.path(work, paste0(name, ".duckdb"))
  if (file.exists(db)) unlink(db)
  db
}
dr_crossover <- function(n_inst, n_days) function() {
  db <- dr_fresh(sprintf("crossover_%dx%d", n_inst, n_days))
  snapshot <- ledgr::ledgr_snapshot_from_df(r_floor_fixture(n_inst, n_days)$bars, db_path = db,
                                            snapshot_id = "probe", price_basis = "split_adjusted")
  strategy <- r_floor_transition
  environment(strategy) <- asNamespace("ledgr")
  exp <- ledgr::ledgr_experiment(snapshot, strategy,
    features = ledgr::ledgr_feature_map(
      fast = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
      slow = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L)),
    opening = ledgr::ledgr_opening(cash = 1e7), cost_model = ledgr::ledgr_cost_zero(),
    risk_chain = ledgr::ledgr_risk_none(), asset_state = list(above = FALSE, usable = FALSE))
  list(db = db, snapshot = snapshot, exp = exp, params = list(), seed = 20260530L)
}
dr_momentum <- function(n_inst, n_days) function() {
  db <- dr_fresh(sprintf("momentum_%dx%d", n_inst, n_days))
  snapshot <- ws16_momentum_snapshot(n_inst, n_days, db, "probe")
  list(db = db, snapshot = snapshot, exp = ws16_momentum_experiment(snapshot, 63L),
       params = list(lookback = 63L, n = 10L), seed = 1L)
}
dr_workloads <- list(
  crossover_10x7200 = dr_crossover(10L, 7200L),
  crossover_500x1260 = dr_crossover(500L, 1260L),
  momentum_40x504 = dr_momentum(40L, 504L),
  momentum_500x1260 = dr_momentum(500L, 1260L),
  # membership exits, relisting, late-known inactivity, missing bars
  prep_fixture = function() {
    db <- dr_fresh("prep_fixture")
    fx <- lc_prep_fixture(db)
    list(db = db, snapshot = fx$snapshot, exp = fx$exp, seed = 1L,
         params = utils::modifyList(lc_prep_fixture_params, list(trade = TRUE, lookback = 10L, n = 3L)))
  },
  # risk cuts, spread costs, an opening position
  dense_risk_features = function() {
    db <- dr_fresh("dense_risk_features")
    fx <- a0_fx_dense_risk_features(db)
    list(db = db, snapshot = fx$snapshot, exp = fx$exp, seed = fx$seed,
         params = list(qty = 30, qty_b = 40, cap = 0.3))
  }
)
