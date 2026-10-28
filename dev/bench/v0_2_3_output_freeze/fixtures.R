# ---------------------------------------------------------------------------
# Fixtures (synthetic; adapted from the parity tests named in inventory.md)
# ---------------------------------------------------------------------------

a0_sessions <- function(dates) {
  ledgr_facts_sessions(data.frame(
    session_date = dates, status = "open", session_open = "09:30:00", session_close = "16:00:00",
    knowledge_time = as.POSIXct(dates, tz = "UTC") - 1, stringsAsFactors = FALSE
  ), venue_id = "XNYS")
}

a0_dense_bars <- function() {
  dates <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:7
  rbind(
    data.frame(instrument_id = "AAA", ts_utc = dates,
      open = c(100, 101, 103, 102, 104, 107, 106, 108), high = c(101, 103, 104, 103, 106, 108, 108, 109),
      low = c(99, 100, 101, 101, 103, 106, 105, 107), close = c(100, 102, 103, 102, 105, 107, 106, 108),
      volume = 1000, stringsAsFactors = FALSE),
    data.frame(instrument_id = "BBB", ts_utc = dates,
      open = c(50, 51, 50, 49, 48, 50, 52, 51), high = c(51, 52, 51, 50, 49, 51, 53, 52),
      low = c(49, 50, 49, 48, 47, 49, 51, 50), close = c(50, 51, 50, 49, 48, 50, 52, 51),
      volume = 2000, stringsAsFactors = FALSE)
  )
}

a0_fx_dense_cost <- function(db_path) {
  snapshot <- ledgr_snapshot_from_df(a0_dense_bars(), db_path = db_path, snapshot_id = "a0_dense_cost")
  strategy <- function(ctx, params) {
    targets <- ctx$hold()
    day <- substr(ctx$ts_utc, 1L, 10L)
    if (identical(day, "2020-01-01")) {
      targets["AAA"] <- params$aaa_qty
      targets["BBB"] <- params$bbb_qty
    } else if (identical(day, "2020-01-03")) {
      targets["AAA"] <- params$aaa_partial_qty
    } else if (identical(day, "2020-01-05") && isTRUE(params$close_day5)) {
      targets["AAA"] <- 0
      targets["BBB"] <- 0
    } else if (identical(day, "2020-01-08")) {
      targets["AAA"] <- params$last_bar_qty
    }
    targets
  }
  exp <- ledgr_experiment(snapshot, strategy, opening = ledgr_opening(cash = 10000),
    universe = c("AAA", "BBB"),
    cost_model = ledgr_cost_chain(ledgr_cost_spread_bps(5), ledgr_cost_fixed_fee(1)))
  grid <- ledgr_grid_named(
    flat = list(strategy = list(aaa_qty = 0, aaa_partial_qty = 0, bbb_qty = 0, close_day5 = TRUE, last_bar_qty = 0)),
    partial = list(strategy = list(aaa_qty = 4, aaa_partial_qty = 2, bbb_qty = 2, close_day5 = TRUE, last_bar_qty = 0)),
    open_end = list(strategy = list(aaa_qty = 1, aaa_partial_qty = 1, bbb_qty = 0, close_day5 = FALSE, last_bar_qty = 3))
  )
  # ledgr_backtest() arguments for the db_live persistent mode (live writes).
  backtest <- list(snapshot = snapshot, strategy = strategy, universe = c("AAA", "BBB"), initial_cash = 10000,
    cost_model = ledgr_cost_chain(ledgr_cost_spread_bps(5), ledgr_cost_fixed_fee(1)), execution_mode = "db_live")
  list(snapshot = snapshot, exp = exp, grid = grid, seed = 2591L, backtest = backtest)
}

a0_fx_dense_risk_features <- function(db_path) {
  snapshot <- ledgr_snapshot_from_df(a0_dense_bars(), db_path = db_path, snapshot_id = "a0_dense_risk_features")
  strategy <- function(ctx, params) {
    targets <- ctx$hold()
    sma <- ctx$feature("AAA", "sma_3")
    targets["AAA"] <- if (!is.na(sma) && ctx$close("AAA") > sma) params$qty else 0
    if (!is.null(ctx$pulse_seed) && (ctx$pulse_seed %% 2L) == 0L) targets["BBB"] <- params$qty_b
    targets
  }
  exp <- ledgr_experiment(snapshot, strategy,
    features = list(ledgr_ind_sma(3)),
    opening = ledgr_opening(cash = 10000, positions = c(AAA = 5), cost_basis = c(AAA = 99)),
    universe = c("AAA", "BBB"),
    risk_chain = ledgr_risk_chain(ledgr_risk_long_only(), ledgr_risk_max_weight(ledgr_param("cap"))),
    cost_model = ledgr_cost_spread_bps(10),
    metric_context = ledgr_metric_context(risk_free_rate = ledgr_risk_free_rate(0.04, label = "a0 policy")))
  grid <- ledgr_grid_named(
    tight = list(strategy = list(qty = 30, qty_b = 40, cap = 0.3)),
    loose = list(strategy = list(qty = 30, qty_b = -5, cap = 0.6))
  )
  list(snapshot = snapshot, exp = exp, grid = grid, seed = 77L)
}

a0_fx_dense_dividend_state <- function(db_path) {
  ts <- as.POSIXct("2020-01-01 16:00:00", tz = "UTC") + 86400 * 0:3
  bars <- data.frame(instrument_id = "AAA", ts_utc = ts, open = c(100, 90, 45, 46),
    high = c(100, 90, 45, 46), low = c(100, 90, 45, 46), close = c(100, 90, 45, 46),
    volume = 1000, stringsAsFactors = FALSE)
  dividend <- data.frame(fact_id = "dividend-1", subtype = "ordinary_cash_dividend",
    parent_instrument_id = "AAA", entitlement_time = ts[[2L]], effective_time = ts[[4L]],
    knowledge_time = ts[[1L]], complete = TRUE, provenance_tier = "snapshot_bound",
    gross_cash_per_parent_unit = 1.25, gross_cash_validated = TRUE,
    recipient_identity_validated = FALSE, recipient_quantity_validated = FALSE,
    source = "a0_fixture", stringsAsFactors = FALSE)
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path, snapshot_id = "a0_dense_dividend_state",
    facts = ledgr_facts(ledgr_facts_equity_corporate_actions(dividend)), price_basis = "split_adjusted")
  strategy <- function(ctx, params) {
    targets <- ctx$hold()
    if (identical(substr(ctx$ts_utc, 1L, 10L), "2020-01-02")) targets["AAA"] <- params$qty
    list(targets = targets, state_update = list(observed_cash = ctx$cash))
  }
  exp <- ledgr_experiment(snapshot, strategy,
    opening = ledgr_opening(cash = 1000, positions = c(AAA = 2), cost_basis = c(AAA = 100)),
    cost_model = ledgr_cost_zero())
  grid <- ledgr_grid_named(hold = list(strategy = list(qty = 2)), add = list(strategy = list(qty = 5)))
  list(snapshot = snapshot, exp = exp, grid = grid, seed = 11L)
}

a0_fx_avail_terminal_resume <- function(db_path) {
  day <- function(d) as.POSIXct(paste(as.Date("2020-01-01") + d - 1L, "16:00:00"), tz = "UTC")
  closes <- list(AAA = c(100, NA, NA, NA, 90, 91), BBB = c(50, NA, NA, NA, NA, NA), CLK = rep(10, 6L))
  bars <- do.call(rbind, lapply(names(closes), function(id) {
    keep <- which(!is.na(closes[[id]])); cl <- closes[[id]][keep]
    data.frame(ts_utc = day(keep), instrument_id = id, open = cl, high = cl + 1, low = cl - 1,
      close = cl, volume = 1000, stringsAsFactors = FALSE)
  }))
  lifetime <- ledgr_facts_lifetime(data.frame(instrument_id = "BBB", effective_from = day(5L),
    knowledge_time = day(5L) - 1, assertion = "known_inactive", terminal_event = "bankruptcy",
    stringsAsFactors = FALSE))
  snapshot <- ledgr_snapshot_from_df(bars, instruments_df = data.frame(instrument_id = names(closes)),
    db_path = db_path, snapshot_id = "a0_avail_terminal_resume",
    facts = ledgr_facts(a0_sessions(as.Date("2020-01-01") + 0:5), lifetime), price_basis = "split_adjusted")
  strategy <- function(ctx, params) {
    if (isTRUE(params$interrupt) && identical(ctx$ts_utc, "2020-01-03T16:00:00Z")) {
      options(ledgr.interrupt = TRUE)
    }
    target <- ctx$hold()
    if (ctx$ts_utc >= "2020-01-03T16:00:00Z" && "AAA" %in% names(target)) target[["AAA"]] <- 0
    target
  }
  exp <- ledgr_experiment(snapshot, strategy,
    opening = ledgr_opening(cash = 1000, positions = c(AAA = 2, BBB = 4), cost_basis = c(AAA = 100, BBB = 100)),
    valuation_policy = ledgr_valuation_stale(1), corporate_action_policy = ledgr_corporate_actions_research(),
    cost_model = ledgr_cost_zero())
  grid <- ledgr_grid_named(straight = list(strategy = list(interrupt = FALSE)))
  list(snapshot = snapshot, exp = exp, grid = grid, seed = 169L)
}

a0_fx_avail_acquisition <- function(db_path) {
  dates <- as.Date("2020-01-01") + 0:2
  pulses <- as.POSIXct(paste(dates, "16:00:00"), tz = "UTC")
  bars <- rbind(
    data.frame(instrument_id = "AAA", ts_utc = pulses, open = c(100, 90, 91), high = c(100, 90, 91),
      low = c(100, 90, 91), close = c(100, 90, 91), volume = 1000),
    data.frame(instrument_id = "BBB", ts_utc = pulses, open = c(49, 50, 51), high = c(49, 50, 51),
      low = c(49, 50, 51), close = c(49, 50, 51), volume = 1000))
  lifetime <- ledgr_facts_lifetime(data.frame(instrument_id = "AAA", effective_from = pulses[[2L]],
    knowledge_time = pulses[[2L]] - 1, assertion = "known_inactive", terminal_event = "acquired",
    stringsAsFactors = FALSE))
  action <- ledgr_facts_equity_corporate_actions(data.frame(fact_id = "a0-acquisition",
    subtype = "cash_acquisition", parent_instrument_id = "AAA", entitlement_time = pulses[[2L]],
    effective_time = pulses[[2L]], knowledge_time = pulses[[1L]], complete = TRUE,
    provenance_tier = "snapshot_bound", gross_cash_per_parent_unit = 120, gross_cash_validated = TRUE,
    recipient_identity_validated = FALSE, recipient_quantity_validated = FALSE, stringsAsFactors = FALSE))
  snapshot <- ledgr_snapshot_from_df(bars, instruments_df = data.frame(instrument_id = c("AAA", "BBB")),
    db_path = db_path, snapshot_id = "a0_avail_acquisition",
    facts = ledgr_facts(a0_sessions(dates), lifetime, action), price_basis = "split_adjusted")
  strategy <- function(ctx, params) {
    target <- ctx$hold()
    if (identical(ctx$ts_utc, "2020-01-01T16:00:00Z")) target[["BBB"]] <- params$qty
    target
  }
  exp <- ledgr_experiment(snapshot, strategy,
    opening = ledgr_opening(cash = 1000, positions = c(AAA = 2), cost_basis = c(AAA = 100)),
    valuation_policy = ledgr_valuation_stale(1L), cost_model = ledgr_cost_zero(),
    corporate_action_policy = ledgr_corporate_actions_research())
  grid <- ledgr_grid_named(none = list(strategy = list(qty = 0)), some = list(strategy = list(qty = 3)))
  list(snapshot = snapshot, exp = exp, grid = grid, seed = 54L)
}

a0_fx_avail_incomplete <- function(db_path) {
  dates <- as.Date("2020-01-01") + 0:3
  bar_days <- c(1L, 2L, 4L)
  bars <- data.frame(ts_utc = as.POSIXct(paste(dates[bar_days], "16:00:00"), tz = "UTC"),
    instrument_id = "AAA", open = 100 + bar_days, high = 101 + bar_days, low = 99 + bar_days,
    close = 100 + bar_days, volume = 1000, stringsAsFactors = FALSE)
  snapshot <- ledgr_snapshot_from_df(bars, instruments_df = data.frame(instrument_id = "AAA"),
    db_path = db_path, snapshot_id = "a0_avail_incomplete",
    facts = ledgr_facts(a0_sessions(dates)), price_basis = "split_adjusted")
  strategy <- function(ctx, params) {
    target <- ctx$hold()
    target[["AAA"]] <- params$qty
    target
  }
  exp <- ledgr_experiment(snapshot, strategy,
    valuation_policy = ledgr_valuation_stale(0, exhausted = "refuse"), cost_model = ledgr_cost_zero())
  grid <- ledgr_grid_named(one = list(strategy = list(qty = 1)), two = list(strategy = list(qty = 2)))
  list(snapshot = snapshot, exp = exp, grid = grid, seed = 31L)
}

a0_fx_walk_forward <- function(db_path) {
  dates <- as.Date("2020-01-01") + 0:9
  make_bars <- function(id, keep, offset) {
    data.frame(instrument_id = id, ts_utc = as.POSIXct(paste(dates[keep], "16:00:00"), tz = "UTC"),
      open = 100 + offset + keep, high = 101 + offset + keep, low = 99 + offset + keep,
      close = 100 + offset + keep, volume = 1000, stringsAsFactors = FALSE)
  }
  bars <- rbind(make_bars("AAA", setdiff(1:10, 5L), 0), make_bars("BBB", setdiff(1:10, 8L), 20))
  snapshot <- ledgr_snapshot_from_df(bars, instruments_df = data.frame(instrument_id = c("AAA", "BBB")),
    db_path = db_path, snapshot_id = "a0_walk_forward",
    facts = ledgr_facts(a0_sessions(dates)), price_basis = "split_adjusted")
  strategy <- function(ctx, params) {
    target <- ctx$hold()
    target[["BBB"]] <- params$qty
    target
  }
  exp <- ledgr_experiment(snapshot, strategy, universe = c("AAA", "BBB"),
    opening = ledgr_opening(cash = 10000, positions = c(AAA = 1, BBB = 1), cost_basis = c(AAA = 101, BBB = 121)),
    valuation_policy = ledgr_valuation_stale(3, exhausted = "refuse"), cost_model = ledgr_cost_fixed_fee(0.5))
  grid <- ledgr_grid_named(small = list(strategy = list(qty = 2)), large = list(strategy = list(qty = 4)))
  folds <- ledgr:::ledgr_fold_list(list(
    ledgr_fold("2020-01-01T16:00:00Z", "2020-01-03T16:00:00Z", "2020-01-04T16:00:00Z", "2020-01-06T16:00:00Z", fold_seq = 1L),
    ledgr_fold("2020-01-04T16:00:00Z", "2020-01-06T16:00:00Z", "2020-01-07T16:00:00Z", "2020-01-10T16:00:00Z", fold_seq = 2L)
  ), constructor = list(type_id = "explicit"))
  list(snapshot = snapshot, exp = exp, grid = grid, seed = 24L, folds = folds)
}

# A strategy that aborts from the third session in availability mode, and a
# dense experiment on the same bars whose BBB gap is refused at run start.
a0_fx_failures <- function(db_path) {
  dates <- as.Date("2020-01-01") + 0:3
  ts <- as.POSIXct(paste(dates, "16:00:00"), tz = "UTC")
  bars <- rbind(
    data.frame(instrument_id = "AAA", ts_utc = ts, open = 100:103, high = 101:104, low = 99:102,
      close = 100:103, volume = 1000, stringsAsFactors = FALSE),
    data.frame(instrument_id = "BBB", ts_utc = ts[-3], open = c(50, 51, 53), high = c(51, 52, 54),
      low = c(49, 50, 52), close = c(50, 51, 53), volume = 1000, stringsAsFactors = FALSE))
  snapshot <- ledgr_snapshot_from_df(bars, instruments_df = data.frame(instrument_id = c("AAA", "BBB")),
    db_path = db_path, snapshot_id = "a0_failures", facts = ledgr_facts(a0_sessions(dates)),
    price_basis = "split_adjusted")
  strategy <- function(ctx, params) {
    if (isTRUE(params$fail) && ctx$ts_utc >= "2020-01-03T16:00:00Z") {
      rlang::abort("a0 injected strategy failure", class = "a0_strategy_failure")
    }
    target <- ctx$hold()
    target[["AAA"]] <- params$qty
    target
  }
  exp <- ledgr_experiment(snapshot, strategy, universe = c("AAA", "BBB"),
    valuation_policy = ledgr_valuation_stale(2), cost_model = ledgr_cost_zero())
  grid <- ledgr_grid_named(ok = list(strategy = list(fail = FALSE, qty = 2)),
    bad = list(strategy = list(fail = TRUE, qty = 2)))
  dense <- ledgr_snapshot_from_df(bars, db_path = db_path, snapshot_id = "a0_failures_dense")
  abort_exp <- ledgr_experiment(dense, strategy, universe = c("AAA", "BBB"), cost_model = ledgr_cost_zero())
  list(snapshot = snapshot, exp = exp, grid = grid, seed = 404L, abort_exp = abort_exp,
    abort_params = list(fail = FALSE, qty = 2), close = list(dense))
}

# ---------------------------------------------------------------------------
# Workloads
# ---------------------------------------------------------------------------

a0_workloads <- list(
  dense_cost = list(fixture = a0_fx_dense_cost, paths = c("run", "run_db_live", "sweep_w1", "sweep_w2", "sweep_compiled"),
    why = "parity-suite base case: two instruments, cost chain (spread + fixed fee), flat/partial/open-end candidates, last-bar no-fill warning; one and two workers; compiled spot-FIFO memory path; db_live persistent mode via ledgr_backtest()"),
  dense_risk_features = list(fixture = a0_fx_dense_risk_features, paths = c("run", "sweep_w1", "sweep_w2"),
    why = "risk chain (long_only + max_weight with a grid parameter), SMA feature warmup, opening lot, pulse_seed-driven targets, non-default metric context"),
  dense_dividend_state = list(fixture = a0_fx_dense_dividend_state, paths = c("run", "sweep_w1"),
    why = "dense mode corporate action (ordinary cash dividend posting CASHFLOW) and strategy_state writes via state_update"),
  avail_terminal_resume = list(fixture = a0_fx_avail_terminal_resume, paths = c("run", "run_resumed", "sweep_w1", "sweep_w2"),
    why = "availability mode: stale-mark freeze, bankruptcy terminal write-off (DISPOSITION), diagnostics and completion; ledgr.interrupt soft stop then resume; one and two workers"),
  avail_acquisition = list(fixture = a0_fx_avail_acquisition, paths = c("run", "sweep_w1"),
    why = "availability mode cash acquisition: held terminal position disposed at the deal price"),
  avail_incomplete = list(fixture = a0_fx_avail_incomplete, paths = c("run", "sweep_w1", "sweep_w2"),
    why = "availability INCOMPLETE terminal outcome (valuation horizon exhausted): completion evidence and stopped diagnostics; one and two workers"),
  walk_forward = list(fixture = a0_fx_walk_forward, paths = c("run", "sweep_w1", "walk_forward"),
    why = "walk-forward: train sweeps (memory) and carried test runs (persistent) on a gapped session calendar with fees"),
  failures = list(fixture = a0_fx_failures, paths = c("run", "run_abort", "sweep_w1", "sweep_w2"), timing = FALSE,
    why = "failure output: a strategy error mid-run (FAILED run, error_msg, exception diagnostic, rolled-back pulses; FAILED sweep candidate beside a DONE sibling, one and two workers) and a dense coverage refusal through abort_run")
)
