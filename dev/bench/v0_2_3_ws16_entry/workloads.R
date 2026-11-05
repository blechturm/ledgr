# Portable workloads shared by the probes. Each builds its snapshot through
# public constructors only.

# Monthly top-n momentum on one returns feature: the registered H1 strategy
# (history-wave-h1) without its private membership universe.
ws16_momentum_strategy <- function(ctx, params) {
  score <- ledgr::ledgr_signal_return(ctx, params$lookback)
  selected <- ledgr::ledgr_select_top(score, n = params$n, within = ctx$buyable)
  weights <- ledgr::ledgr_weight_equal(selected)
  target <- ledgr::ledgr_target_rebalance(
    ctx, weights = weights, invest_fraction = 0.95,
    index_leavers = "keep", capital_base = "remaining_equity"
  )
  list(targets = target)
}

# Simulated bars on a declared session calendar (schedules need one), in the
# A0 fixtures' convention: bars at 16:00 UTC, sessions known the second before.
ws16_momentum_snapshot <- function(n_inst, n_days, db_path, snapshot_id, seed = 20260530L) {
  bars <- ledgr::ledgr_sim_bars(n_inst, n_days, seed = seed, start = "2000-01-03",
                                instrument_prefix = "P")
  dates <- as.Date(bars$ts_utc)
  bars$ts_utc <- as.POSIXct(paste(dates, "16:00:00"), tz = "UTC")
  for (name in c("open", "high", "low", "close", "volume")) bars[[name]] <- round(bars[[name]], 8L)
  # The calendar lists every civil date; days without bars are closed.
  days <- seq(min(dates), max(dates), by = "day")
  open <- days %in% dates
  sessions <- ledgr::ledgr_facts_sessions(data.frame(
    session_date = days, status = ifelse(open, "open", "closed"),
    session_open = ifelse(open, "09:30:00", NA_character_),
    session_close = ifelse(open, "16:00:00", NA_character_),
    knowledge_time = as.POSIXct(days, tz = "UTC") - 1, stringsAsFactors = FALSE
  ), venue_id = "XNYS")
  ledgr::ledgr_snapshot_from_df(bars, db_path = db_path, snapshot_id = snapshot_id,
                                facts = ledgr::ledgr_facts(sessions), price_basis = "split_adjusted")
}

ws16_momentum_experiment <- function(snapshot, lookback) {
  ledgr::ledgr_experiment(
    snapshot, ws16_momentum_strategy,
    features = list(ledgr::ledgr_ind_returns(as.integer(lookback))),
    schedule = ledgr::ledgr_schedule_month_start(),
    opening = ledgr::ledgr_opening(cash = 1e6),
    cost_model = ledgr::ledgr_cost_zero()
  )
}

# The registered fill-heavy workload (dev/bench/v0_2_3_fill_heavy_profile):
# SMA 5/10 transitions on 500 x 1,260 simulated sessions, about 54 fills
# per pulse.
ws16_fill_heavy_strategy <- function(ctx, params) {
  fast <- ctx$fast
  slow <- ctx$slow
  usable <- is.finite(fast) & is.finite(slow)
  above <- usable & fast > slow
  targets <- ctx$hold()
  enter <- ctx$state$usable & usable & above & !ctx$state$above
  exit <- ctx$state$usable & usable & !above & ctx$state$above
  targets[enter] <- 1
  targets[exit] <- 0
  ledgr::ledgr_strategy_result(targets, above = above, usable = usable)
}

ws16_fill_heavy_experiment <- function(snapshot) {
  features <- ledgr::ledgr_feature_map(
    fast = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
    slow = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L))
  ledgr::ledgr_experiment(snapshot, ws16_fill_heavy_strategy, features = features,
    opening = ledgr::ledgr_opening(cash = 1e7), cost_model = ledgr::ledgr_cost_zero(),
    risk_chain = ledgr::ledgr_risk_none(), asset_state = list(above = FALSE, usable = FALSE))
}

ws16_fill_heavy_bars <- function() {
  bars <- ledgr::ledgr_sim_bars(500L, 1260L, seed = 20260530L, start = "2020-01-01",
                                instrument_prefix = "P")
  bars$ts_utc <- bars$ts_utc + 21 * 3600
  for (name in c("open", "high", "low", "close", "volume")) bars[[name]] <- round(bars[[name]], 8L)
  bars
}
