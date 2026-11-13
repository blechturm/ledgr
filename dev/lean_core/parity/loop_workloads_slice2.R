# Slice-2 workloads (Cut 16, LDG-3226 and LDG-3227; interface Section 19.9):
# costs, the risk chain and the sizing helpers, built with public
# constructors, the pin as oracle. Sourced by loop_parity.R after
# loop_workloads.R (whose helpers lw_bars, lw_snapshot, lw_schedule_strategy
# and lw_days it uses).
#
# loop_reach holds, per workload, the branch it is named for, asserted on the
# pin's own tables before parity is accepted (decision 4, cut review R2): a
# predicate that finds no matching row fails the workload.

# --- shared helpers -----------------------------------------------------------

s2_cross_exp <- function(cost, risk, cash = 1e7) function(snapshot) {
  strategy <- r_floor_transition
  environment(strategy) <- ns
  ledgr::ledgr_experiment(snapshot, strategy,
    features = ledgr::ledgr_feature_map(
      fast = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
      slow = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L)),
    opening = ledgr::ledgr_opening(cash = cash), cost_model = cost, risk_chain = risk,
    asset_state = list(above = FALSE, usable = FALSE))
}
s2_cross <- function(name, n_inst, n_days, cost, risk) function() {
  db <- build(name, function(db) ledgr::ledgr_snapshot_from_df(r_floor_fixture(n_inst, n_days)$bars, db_path = db,
                                                              snapshot_id = name, price_basis = "split_adjusted"))
  collect(db, name, paste0("s2-", name), s2_cross_exp(cost, risk), seed = 20260530L)
}
s2_sched <- function(name, bars, plan, cost, risk = ledgr::ledgr_risk_none(), cash = 5000) function() {
  db <- lw_snapshot(name, bars)
  exp <- function(snapshot) ledgr::ledgr_experiment(snapshot, lw_schedule_strategy(plan),
    opening = ledgr::ledgr_opening(cash = cash), cost_model = cost, risk_chain = risk)
  collect(db, name, paste0("s2-", name), exp, seed = 11L)
}
s2_plan <- function(n_days, ...) {
  steps <- list(...)
  stats::setNames(lapply(steps, `[[`, 2L), lw_days(n_days)[vapply(steps, `[[`, 1L, 1L)])
}
s2_chain <- function() ledgr::ledgr_cost_chain(ledgr::ledgr_cost_spread_bps(10), ledgr::ledgr_cost_fixed_fee(1),
                                                ledgr::ledgr_cost_notional_bps_fee(5))

# Pin tables of the committed run. The A0 extraction stores every column as
# canonical text (numbers as strings, times as ISO 8601), so the predicates
# convert the columns they read.
s2_num_cols <- function(d, cols) {
  for (col in intersect(cols, names(d))) d[[col]] <- as.numeric(d[[col]])
  d
}
s2_diag <- function(t) s2_num_cols(t$run$run_diagnostics, c("target", "quantity", "price", "target_before_risk",
  "target_after_risk", "position_before", "position_after"))
s2_decisions <- function(t) {
  d <- s2_diag(t)
  d[!is.na(d$stage) & d$stage == "decision" & !is.na(d$target_before_risk) & !is.na(d$target_after_risk), ]
}
s2_fills <- function(t) s2_num_cols(t$run$fills, c("qty", "price", "fee", "realized_pnl"))
s2_messages <- function(t) unlist(lapply(t, function(p) unlist(lapply(p, function(d) {
  if (!is.data.frame(d)) return(character())
  unlist(d[intersect(names(d), c("message", "error_msg"))])
}))))
s2_time <- function(x) {
  if (inherits(x, "POSIXct")) return(as.numeric(x))
  as.numeric(as.POSIXct(x, format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC"))
}

# --- LDG-3226: costs and the risk chain --------------------------------------

s2_const <- function(px, n_days) lw_bars(px, n_days, drift = 0)

loop_slice2 <- list(
  # Each cost model, and their chain, on crossover 10 x 300.
  s2_cost_fixed = s2_cross("s2_cost_fixed", 10L, 300L, ledgr::ledgr_cost_fixed_fee(1), ledgr::ledgr_risk_none()),
  s2_cost_notional = s2_cross("s2_cost_notional", 10L, 300L, ledgr::ledgr_cost_notional_bps_fee(5),
                              ledgr::ledgr_risk_none()),
  s2_cost_spread = s2_cross("s2_cost_spread", 10L, 300L, ledgr::ledgr_cost_spread_bps(10), ledgr::ledgr_risk_none()),
  s2_cost_chain = s2_cross("s2_cost_chain", 10L, 300L, s2_chain(), ledgr::ledgr_risk_none()),
  # max_weight that never binds, and one that binds on held positions.
  s2_risk_nonbinding = s2_cross("s2_risk_nonbinding", 10L, 300L, ledgr::ledgr_cost_zero(),
                                ledgr::ledgr_risk_max_weight(0.05)),
  s2_risk_bind = s2_cross("s2_risk_bind", 10L, 300L, ledgr::ledgr_cost_zero(), ledgr::ledgr_risk_max_weight(1e-5)),
  # long_only on planned shorts; the chain of long_only and a binding cap.
  s2_risk_long_only = s2_sched("s2_risk_long_only", lw_bars(c(A = 30, B = 45, C = 12), 20L, drift = 0.05),
    s2_plan(20L, list(2L, c(A = 3, B = -2)), list(5L, c(B = 4, C = -5)), list(9L, c(A = 0, C = 6)),
            list(13L, c(A = -1, B = 0))),
    ledgr::ledgr_cost_zero(), ledgr::ledgr_risk_long_only()),
  s2_risk_chain = s2_sched("s2_risk_chain", lw_bars(c(A = 30, B = 45, C = 12), 20L, drift = 0.05),
    s2_plan(20L, list(2L, c(A = 3, B = -2)), list(5L, c(B = 60, C = -5)), list(9L, c(A = 0, C = 6)),
            list(13L, c(A = -1, B = 0))),
    ledgr::ledgr_cost_fixed_fee(0.5),
    ledgr::ledgr_risk_chain(ledgr::ledgr_risk_long_only(), ledgr::ledgr_risk_max_weight(0.3))),
  # The risk step's own refusal: a fee leaves equity a hair below zero after
  # an exit, and the next max_weight application refuses negative equity.
  s2_risk_equity_refusal = s2_sched("s2_risk_equity_refusal", s2_const(c(A = 1), 8L),
    s2_plan(8L, list(2L, c(A = 1)), list(4L, c(A = 0))),
    ledgr::ledgr_cost_fixed_fee(1.000000005), ledgr::ledgr_risk_max_weight(1), cash = 2.000000005),
  # A short target kept by max_weight is refused on the risked targets.
  s2_risk_short_refusal = s2_sched("s2_risk_short_refusal", s2_const(c(A = 30, B = 45), 6L),
    s2_plan(6L, list(2L, c(A = 2)), list(4L, c(A = -3))),
    ledgr::ledgr_cost_zero(), ledgr::ledgr_risk_max_weight(0.5)),
  # Fees that make a buy unaffordable.
  s2_cost_insufficient = s2_sched("s2_cost_insufficient", s2_const(c(A = 10, B = 20), 8L),
    s2_plan(8L, list(2L, c(A = 10)), list(4L, c(A = 5, B = 2))),
    ledgr::ledgr_cost_fixed_fee(1), cash = 100),
  # A fee larger than a sale's proceeds, beside a buy on the same pulse.
  s2_cost_sale_consumes = s2_sched("s2_cost_sale_consumes", s2_const(c(A = 1, B = 10), 8L),
    s2_plan(8L, list(2L, c(A = 1)), list(4L, c(A = 0, B = 2))),
    ledgr::ledgr_cost_fixed_fee(2), cash = 100),
  # A spread that takes the sell price to zero on complete positive bars.
  s2_cost_nonpositive_price = s2_sched("s2_cost_nonpositive_price", s2_const(c(A = 10), 6L),
    s2_plan(6L, list(1L, c(A = 2)), list(3L, c(A = 0))),
    ledgr::ledgr_cost_spread_bps(20000), cash = 1000)
)

loop_reach <- list(
  s2_cost_fixed = function(t) { f <- s2_fills(t); nrow(f) > 0L && all(f$fee == 1) },
  s2_cost_notional = function(t) { f <- s2_fills(t); nrow(f) > 0L && all(f$fee > 0) },
  s2_cost_spread = function(t) { f <- s2_fills(t); nrow(f) > 0L && all(f$fee == 0) },
  # Both price transforms and both fee adders: buys above and sells below
  # the execution bar's open, every fee the fixed 1 plus 5 bps of the
  # transformed (unrounded) notional.
  s2_cost_chain = function(t) {
    f <- s2_fills(t)
    bars <- r_floor_fixture(10L, 300L)$bars
    open <- bars$open[match(paste(f$instrument_id, s2_time(f$ts_utc)),
                            paste(bars$instrument_id, s2_time(bars$ts_utc)))]
    buy <- f$side == "BUY"; sell <- f$side == "SELL"
    any(buy) && any(sell) && !anyNA(open) && all(f$price[buy] > open[buy]) && all(f$price[sell] < open[sell]) &&
      all(abs(f$fee - (1 + 5e-4 * f$qty * f$price)) <= 1e-9 * (1 + f$fee))
  },
  s2_risk_nonbinding = function(t) {
    d <- s2_decisions(t)
    nrow(d) > 0L && any(d$target_before_risk != 0) && all(d$target_after_risk == d$target_before_risk)
  },
  # A strict cap reduction, and a held position the strategy asked to keep
  # strictly reduced, followed by a reducing fill.
  s2_risk_bind = function(t) {
    d <- s2_decisions(t)
    f <- s2_fills(t)
    cut <- d$target_before_risk != 0 & abs(d$target_after_risk) < abs(d$target_before_risk)
    held <- cut & d$position_before != 0 & d$target_before_risk == d$position_before
    any(cut) && any(vapply(which(held), function(r) {
      later <- f[f$instrument_id == d$instrument_id[[r]] & s2_time(f$ts_utc) > s2_time(d$ts_utc[[r]]), ]
      nrow(later) > 0L && later$side[[which.min(s2_time(later$ts_utc))]] == "SELL"
    }, logical(1L)))
  },
  s2_risk_long_only = function(t) {
    d <- s2_decisions(t); any(d$target_before_risk < 0 & d$target_after_risk == 0)
  },
  s2_risk_chain = function(t) {
    d <- s2_decisions(t)
    any(d$target_before_risk < 0 & d$target_after_risk == 0) &&
      any(d$target_before_risk > 0 & d$target_after_risk > 0 & d$target_after_risk < d$target_before_risk)
  },
  s2_risk_equity_refusal = function(t) any(grepl("ctx$equity", s2_messages(t), fixed = TRUE)),
  s2_risk_short_refusal = function(t) any(grepl("cannot open or enlarge short exposure", s2_messages(t), fixed = TRUE)),
  s2_cost_insufficient = function(t) {
    d <- s2_diag(t); any(d$stage == "execution" & d$reason_code == "insufficient_cash", na.rm = TRUE)
  },
  s2_cost_sale_consumes = function(t) {
    f <- s2_fills(t)
    s <- which(f$side == "SELL" & f$qty * f$price - f$fee < 0)
    d <- s2_diag(t)
    length(s) > 0L && any(vapply(s, function(r) {
      at <- s2_time(f$ts_utc[[r]])
      sum(s2_time(f$ts_utc) == at) > 1L ||
        any(d$stage == "execution" & s2_time(d$execution_ts_utc) == at & d$instrument_id != f$instrument_id[[r]],
            na.rm = TRUE)
    }, logical(1L)))
  },
  s2_cost_nonpositive_price = function(t) {
    d <- s2_diag(t); any(d$stage == "execution" & d$reason_code == "execution_bar_missing", na.rm = TRUE)
  }
)
