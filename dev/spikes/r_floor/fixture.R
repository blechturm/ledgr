# Shared fixture and the ledgr oracle run for the R-floor spike.
# The workload is the published peer-benchmark rule: SMA5/SMA10 transition,
# quantities 0 or 1, cash 1e7, zero cost, no risk, fixed basket.

r_floor_fixture <- function(n_inst, n_pulse) {
  bars <- ledgr::ledgr_sim_bars(n_inst, n_pulse, seed = 20260530L,
    start = "2020-01-01", instrument_prefix = "P")
  bars$ts_utc <- bars$ts_utc + 21 * 3600
  for (name in c("open", "high", "low", "close", "volume")) bars[[name]] <- round(bars[[name]], 8L)
  bars <- bars[order(bars$instrument_id, bars$ts_utc, method = "radix"), ]
  rownames(bars) <- NULL
  list(bars = bars, n_inst = n_inst, n_pulse = n_pulse)
}

r_floor_transition <- function(ctx, params) {
  fast <- ctx$fast
  slow <- ctx$slow
  usable <- is.finite(fast) & is.finite(slow)
  above <- usable & fast > slow
  targets <- ctx$hold()
  enter <- ctx$state$usable & usable & above & !ctx$state$above
  exit <- ctx$state$usable & usable & !above & ctx$state$above
  targets[enter] <- 1
  targets[exit] <- 0
  ledgr_strategy_result(targets, above = above, usable = usable)
}

r_floor_ledgr_run <- function(fx, run_id, db_path = tempfile(fileext = ".duckdb")) {
  snap <- ledgr::ledgr_snapshot_from_df(fx$bars, db_path = db_path,
    snapshot_id = paste0("r_floor_", run_id), price_basis = "split_adjusted")
  features <- ledgr::ledgr_feature_map(
    fast = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
    slow = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L))
  strategy <- r_floor_transition
  environment(strategy) <- asNamespace("ledgr")
  exp <- ledgr::ledgr_experiment(snap, strategy, features = features,
    opening = ledgr::ledgr_opening(cash = 1e7), cost_model = ledgr::ledgr_cost_zero(),
    risk_chain = ledgr::ledgr_risk_none(), asset_state = list(above = FALSE, usable = FALSE))
  suppressWarnings(ledgr::ledgr_run(exp, run_id = run_id, seed = 20260530L))
}
