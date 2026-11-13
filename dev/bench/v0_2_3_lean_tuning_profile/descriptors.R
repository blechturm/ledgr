# Workload descriptors for the lean-loop cost map, the paired comparisons
# (dev/lean_core/parity/loop_shortcuts.R) and the cut16-loop-1 timing
# protocol (Cut 16 decision 6, LDG-3229). One definition, sourced by all
# three. A descriptor's identity is its id, separate from its dimensions:
# the four crossover ids keep Cut 14's and Cut 15's names ("10x7200", ...)
# and their fixture; slice2_10x7200 is a different workload on the same
# 10 x 7,200 simulated bars.
#
# Needs r_floor_fixture() and r_floor_transition() from
# dev/spikes/r_floor/fixture.R (or an equivalent bars builder passed in).
#
#   bench_descriptor(id) -> list(id, instruments, pulses, family, bars(),
#                                experiment(snapshot), reach(bt))

bench_descriptor_ids <- c("10x7200", "20x23400", "500x1260", "1166x252", "slice2_10x7200")

# slice2_10x7200: cash 1e7; spread_bps(10), fixed_fee(1),
# notional_bps_fee(5); max_weight(0.05); ledgr_target_rebalance() with weight
# 0.08 per instrument and invest_fraction 0.9 on the first pulse and every
# third pulse after it, holding in between; the pulse counted in declared
# portfolio state.
bench_slice2_strategy <- function(weights) {
  s <- function(ctx, params) {
    k <- ctx$state$k + 1L
    targets <- if (k %% 3L == 1L) ledgr_target_rebalance(ctx, weights = weights, invest_fraction = 0.9) else ctx$hold()
    ledgr_strategy_result(targets, k = k)
  }
  environment(s) <- list2env(list(weights = weights), parent = asNamespace("ledgr"))
  s
}

bench_descriptor <- function(id, fixture = r_floor_fixture) {
  # any NxM id is the crossover on N instruments x M pulses (the four named
  # shapes, and small ones for self-tests)
  crossover <- c("10x7200" = "10x7200", "20x23400" = "20x23400", "500x1260" = "500x1260", "1166x252" = "1166x252",
                 slice2_10x7200 = "10x7200")
  if (grepl("^[0-9]+x[0-9]+$", id)) crossover[[id]] <- id
  if (!id %in% names(crossover)) stop("unknown workload descriptor: ", id, call. = FALSE)
  d <- as.integer(strsplit(crossover[[id]], "x")[[1L]])
  bars <- function() fixture(d[[1L]], d[[2L]])$bars
  if (id != "slice2_10x7200") {
    experiment <- function(snapshot) {
      strategy <- r_floor_transition
      environment(strategy) <- asNamespace("ledgr")
      ledgr::ledgr_experiment(snapshot, strategy,
        features = ledgr::ledgr_feature_map(
          fast = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
          slow = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L)),
        opening = ledgr::ledgr_opening(cash = 1e7), cost_model = ledgr::ledgr_cost_zero(),
        risk_chain = ledgr::ledgr_risk_none(), asset_state = list(above = FALSE, usable = FALSE))
    }
    return(list(id = id, instruments = d[[1L]], pulses = d[[2L]], family = "crossover", bars = bars,
                experiment = experiment, reach = NULL))
  }
  experiment <- function(snapshot) {
    ids <- sprintf("P%02d", seq_len(d[[1L]]))
    ledgr::ledgr_experiment(snapshot, bench_slice2_strategy(stats::setNames(rep(0.08, length(ids)), ids)),
      opening = ledgr::ledgr_opening(cash = 1e7),
      cost_model = ledgr::ledgr_cost_chain(ledgr::ledgr_cost_spread_bps(10), ledgr::ledgr_cost_fixed_fee(1),
                                           ledgr::ledgr_cost_notional_bps_fee(5)),
      risk_chain = ledgr::ledgr_risk_max_weight(0.05), portfolio_state = list(k = 0L))
  }
  # Reach, asserted on a pin run before profiling or timing: sizing rows
  # occur, max_weight strictly reduces targets, priced fills with fees occur.
  reach <- function(bt) {
    diag <- as.data.frame(ledgr::ledgr_results(bt, "diagnostics"))
    fills <- as.data.frame(ledgr::ledgr_results(bt, "fills"))
    dec <- diag[!is.na(diag$stage) & diag$stage == "decision" & !is.na(diag$target_before_risk) &
                !is.na(diag$target_after_risk), ]
    c(sizing_rows = sum(!is.na(diag$stage) & diag$stage == "sizing"),
      risk_reductions = sum(abs(dec$target_after_risk) < abs(dec$target_before_risk)),
      priced_fills_with_fees = sum(is.finite(fills$price) & fills$price > 0 & is.finite(fills$fee) & fills$fee > 0))
  }
  list(id = id, instruments = d[[1L]], pulses = d[[2L]], family = "slice2", bars = bars, experiment = experiment,
       reach = reach)
}

# Every reach count must be positive.
bench_reach_ok <- function(counts) length(counts) > 0L && all(counts > 0)
