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

# --- LDG-3227: the sizing helpers ---------------------------------------------

# A strategy acting on a per-pulse plan (pulse index -> a function of ctx and
# params returning the strategy's result); other pulses hold. Pulses are
# counted in declared portfolio state.
s2_pulse_strategy <- function(plan) {
  force(plan)
  s <- function(ctx, params) {
    k <- ctx$state$k + 1L
    act <- plan[[as.character(k)]]
    out <- if (is.null(act)) ctx$hold() else act(ctx, params)
    if (is.list(out) && !is.null(out$targets)) {
      ledgr::ledgr_strategy_result(out$targets, k = k, intent_reason = out$intent_reason)
    } else {
      ledgr::ledgr_strategy_result(out, k = k)
    }
  }
  environment(s) <- list2env(list(plan = plan), parent = ns)
  s
}
s2_rebal <- function(weights, intent = NULL, fraction = 0.9) function(ctx, params) {
  f <- if (is.null(params$fraction)) fraction else params$fraction
  t <- ledgr::ledgr_target_rebalance(ctx, weights = weights, invest_fraction = f)
  if (is.null(intent)) t else list(targets = t, intent_reason = intent)
}
s2_sizing_exp <- function(plan, cost = ledgr::ledgr_cost_zero(), risk = ledgr::ledgr_risk_none(), cash = 5000,
                          max_pulses = NULL) function(snapshot) {
  e <- ledgr::ledgr_experiment(snapshot, s2_pulse_strategy(plan), opening = ledgr::ledgr_opening(cash = cash),
    cost_model = cost, risk_chain = risk, portfolio_state = list(k = 0L))
  if (!is.null(max_pulses)) e$control <- list(max_pulses = max_pulses)
  e
}
s2_sizing <- function(name, plan, bars = NULL, ...) function() {
  if (is.null(bars)) bars <- lw_bars(c(A = 30, B = 45, C = 12), 30L, drift = 0.05)
  db <- lw_snapshot(name, bars)
  collect(db, name, paste0("s2-", name), s2_sizing_exp(plan, ...), seed = 11L)
}
s2_every <- function(pulses, act) stats::setNames(rep(list(act), length(pulses)), as.character(pulses))
s2_w3 <- c(A = 0.3, B = 0.3, C = 0.2)
s2_sizing_rows <- function(t, reason = NULL) {
  d <- s2_diag(t)
  keep <- !is.na(d$stage) & d$stage == "sizing"
  if (!is.null(reason)) keep <- keep & d$reason_code %in% reason
  d[keep, ]
}
s2_notices <- function(t) s2_sizing_rows(t, "sizing_intent_unavailable")
s2_sized_codes <- c("sizing_rounded", "sizing_zero_target", "sizing_liquidation",
                    "sizing_rounded_to_zero_addition", "sizing_rounded_to_zero_liquidation")

loop_slice2 <- c(loop_slice2, list(
  # ledgr_target_rebalance() every third pulse.
  s2_sizing_rebalance = s2_sizing("s2_sizing_rebalance", s2_every(seq(3L, 30L, by = 3L), s2_rebal(s2_w3))),
  # ledgr_target_adjust(): buy, then exit a held instrument, then add value.
  s2_sizing_adjust = s2_sizing("s2_sizing_adjust", list(
    "3" = s2_rebal(s2_w3),
    "6" = function(ctx, params) ledgr::ledgr_target_adjust(ctx, exit = c(A = TRUE, B = FALSE, C = FALSE)),
    "9" = function(ctx, params) ledgr::ledgr_target_adjust(ctx, add_value = c(B = 300, C = 150)))),
  # Sizing under a binding cap, then with the cost chain too.
  s2_sizing_risk = s2_sizing("s2_sizing_risk", s2_every(seq(3L, 30L, by = 3L), s2_rebal(s2_w3)),
                             risk = ledgr::ledgr_risk_max_weight(0.25)),
  s2_sizing_combo = s2_sizing("s2_sizing_combo", s2_every(seq(3L, 30L, by = 3L), s2_rebal(s2_w3)),
                              cost = s2_chain(), risk = ledgr::ledgr_risk_max_weight(0.25)),
  # Every sizing reason code: rounded and zero target on pulse 1; on pulse 3
  # a tiny weight on a held instrument (rounded to zero, liquidation), weight
  # 0 on a held one (liquidation), a tiny weight on a flat one (rounded to
  # zero, addition).
  s2_sizing_reasons = s2_sizing("s2_sizing_reasons", list(
    "1" = s2_rebal(c(A = 0.3, B = 0.3, C = 0)),
    "3" = s2_rebal(c(A = 0.001, B = 0, C = 0.0001)))),
  # The raw-quantity notice: helper evidence with an intent reason on pulse 1
  # and without one on pulse 2, an empty helper on pulse 3, raw targets after.
  s2_sizing_notice = s2_sizing("s2_sizing_notice", list(
    "1" = s2_rebal(c(A = 0.3), intent = "first rebalance"),
    "2" = s2_rebal(c(B = 0.3)),
    "3" = function(ctx, params) ledgr::ledgr_target_adjust(ctx))),
  # A helper target changed by ordinary assignment on pulse 1: the evidence is
  # stale, so pulse 1 takes the raw path and carries the run's notice.
  s2_sizing_stale = s2_sizing("s2_sizing_stale", list(
    "1" = function(ctx, params) {
      t <- ledgr::ledgr_target_rebalance(ctx, weights = s2_w3, invest_fraction = 0.9)
      t[["A"]] <- t[["A"]] + 1
      t
    })),
  # Malformed evidence on valid targets, and beside an invalid target.
  s2_sizing_malformed = s2_sizing("s2_sizing_malformed", list(
    "2" = function(ctx, params) {
      t <- ctx$hold()
      attr(t, "sizing_evidence") <- structure(list(instrument_id = "A"), class = "ledgr_sizing_evidence")
      t
    })),
  s2_sizing_malformed_target = s2_sizing("s2_sizing_malformed_target", list(
    "2" = function(ctx, params) {
      t <- ctx$hold()[c("A", "B")]
      attr(t, "sizing_evidence") <- structure(list(instrument_id = "A"), class = "ledgr_sizing_evidence")
      t
    })),
  # Sizing, intent, a binding cap and costs on one pulse's rows; run at
  # batch_rows = 1 so they span terminal batches (batch one, R4).
  s2_sizing_batch = s2_sizing("s2_sizing_batch", s2_every(seq(2L, 30L, by = 4L),
    s2_rebal(s2_w3, intent = "periodic rebalance")), cost = s2_chain(), risk = ledgr::ledgr_risk_max_weight(0.25)),
  # More sizing rows than the record's first allocation (64): growth.
  s2_sizing_growth = s2_sizing("s2_sizing_growth", s2_every(seq_len(60L),
    s2_rebal(stats::setNames(rep(0.08, 10L), sprintf("P%02d", 1:10)))), bars = r_floor_fixture(10L, 60L)$bars,
    cash = 1e5),
  # A max_pulses prefix ending after sizing pulses.
  s2_sizing_prefix = s2_sizing("s2_sizing_prefix", s2_every(seq(2L, 30L, by = 3L), s2_rebal(s2_w3)), max_pulses = 9L),
  # A one-worker sweep over the invest fraction: the memory sink omits sizing rows.
  s2_sizing_sweep = function() {
    db <- lw_snapshot("s2_sizing_sweep", lw_bars(c(A = 30, B = 45, C = 12), 30L, drift = 0.05))
    snapshot <- ledgr::ledgr_snapshot_open(db, "s2_sizing_sweep", verify = TRUE)
    on.exit(ledgr::ledgr_snapshot_close(snapshot))
    exp <- s2_sizing_exp(s2_every(seq(3L, 30L, by = 3L), s2_rebal(s2_w3)))(snapshot)
    grid <- ledgr::ledgr_grid_named(a = list(strategy = list(fraction = 0.9)), b = list(strategy = list(fraction = 0.5)))
    set.seed(8L)
    obs <- a0_observe_memory(ledgr::ledgr_sweep(exp, grid, seed = 17L, retain = a0_retain()))
    list(sweep = c(a0_sweep_tables(obs$value), a0_memory_tables(obs$observed, obs$value)))
  }
))

loop_reach <- c(loop_reach, list(
  s2_sizing_rebalance = function(t) nrow(s2_sizing_rows(t, "sizing_rounded")) > 0L,
  s2_sizing_adjust = function(t) {
    l <- s2_sizing_rows(t, "sizing_liquidation")
    any(l$instrument_id == "A" & l$position_before != 0)
  },
  s2_sizing_risk = function(t) {
    d <- s2_decisions(t)
    nrow(s2_sizing_rows(t, "sizing_rounded")) > 0L && any(d$target_after_risk < d$target_before_risk)
  },
  s2_sizing_combo = function(t) {
    d <- s2_decisions(t)
    f <- s2_fills(t)
    nrow(s2_sizing_rows(t, "sizing_rounded")) > 0L && any(d$target_after_risk < d$target_before_risk) &&
      nrow(f) > 0L && all(f$fee > 1)
  },
  s2_sizing_reasons = function(t) all(s2_sized_codes %in% s2_sizing_rows(t)$reason_code),
  # Helper pulses 1-3 carry no notice; exactly one notice, on pulse 4 (the
  # first raw pulse); the intent reason rides on pulse 1's sizing rows.
  s2_sizing_notice = function(t) {
    pulses <- sort(unique(s2_time(s2_diag(t)$ts_utc)))
    sized <- s2_sizing_rows(t, s2_sized_codes)
    n <- s2_notices(t)
    on <- function(p) s2_time(sized$ts_utc) == pulses[[p]]
    nrow(n) == 1L && s2_time(n$ts_utc) == pulses[[4L]] && any(on(1L)) && any(on(2L)) &&
      all(sized$reasons[on(1L)] == "first rebalance") &&
      all(is.na(sized$reasons[on(2L)]) | sized$reasons[on(2L)] == "")   # "" is stored as NA by the A0 extraction
  },
  # Stale on pulse 1: no sizing row, and the run's one notice on that pulse.
  s2_sizing_stale = function(t) {
    pulses <- sort(unique(s2_time(s2_diag(t)$ts_utc)))
    n <- s2_notices(t)
    nrow(s2_sizing_rows(t, s2_sized_codes)) == 0L && nrow(n) == 1L && s2_time(n$ts_utc) == pulses[[1L]]
  },
  s2_sizing_malformed = function(t) any(grepl("sizing evidence has an invalid shape", s2_messages(t), fixed = TRUE)),
  # Target validation precedes the evidence: the target refusal, not the evidence's.
  s2_sizing_malformed_target = function(t) {
    m <- s2_messages(t)
    length(m) > 0L && !any(grepl("sizing evidence", m, fixed = TRUE))
  },
  s2_sizing_batch = function(t) {
    s <- s2_sizing_rows(t, "sizing_rounded")
    d <- s2_decisions(t)
    nrow(s) > 0L && all(s$reasons == "periodic rebalance") && any(d$target_after_risk < d$target_before_risk)
  },
  s2_sizing_growth = function(t) nrow(s2_sizing_rows(t, s2_sized_codes)) > 64L,
  s2_sizing_prefix = function(t) nrow(s2_sizing_rows(t, "sizing_rounded")) > 0L
))
