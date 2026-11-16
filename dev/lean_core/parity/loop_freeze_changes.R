# Writes loop_freeze_changes.csv: the recorded changes to the 4a3e08b8
# freeze (loop_freeze.csv, which stays as loop_freeze.R generated it).
# loop_parity.R --freeze applies them: an `update` must name an existing
# (mode, workload, debug) row, an `add` a new one; anything else stops.
#
#   Rscript dev/lean_core/parity/loop_freeze_changes.R

here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
row <- function(action, mode, workload, debug, lean_folds, refused, backstop, reason) {
  data.frame(action = action, mode = mode, workload = workload, debug = debug, lean_folds = lean_folds,
             refused = refused, backstop = backstop, reason = reason, stringsAsFactors = FALSE)
}
both <- function(...) rbind(row(..., debug = 0L), row(..., debug = 1L))
rows <- list()
add <- function(x) rows[[length(rows) + 1L]] <<- x

# Workstream 32: the five witnesses it added, from its committed gate
# records (evidence/loop_gate_debug0.csv, loop_gate_debug1.csv at 27747ab0).
for (w in c("witness_retained_context", "witness_error_cleanup", "witness_error_cleanup_error",
            "witness_error_custom", "witness_error_cleanup_seeded")) {
  add(both(action = "add", mode = "gate", workload = w, lean_folds = 1L, refused = "", backstop = "",
           reason = "Workstream 32 witness, path as its committed gate records"))
}

# Batch one and inert at debug 0: the 4a3e08b8 freeze holds them at debug 1
# only; a debug setting does not choose the execution path (the 106 frozen
# tuples match across debug settings, workstream 32 close review round 1),
# so each debug-0 row repeats its debug-1 row.
base <- utils::read.csv(file.path(here, "loop_freeze.csv"), stringsAsFactors = FALSE, na.strings = character(),
                        colClasses = c(refused = "character", backstop = "character"))
d1 <- base[base$mode %in% c("batch1", "inert") & base$debug == 1L, ]
for (i in seq_len(nrow(d1))) {
  add(row("add", d1$mode[[i]], d1$workload[[i]], 0L, d1$lean_folds[[i]], d1$refused[[i]], d1$backstop[[i]],
          "debug-0 row repeating the frozen debug-1 path (Cut 16 R4)"))
}

# Cut 16 decision 4: the two gate rows slice 2 moves, as the probe found.
add(both(action = "update", mode = "gate", workload = "dense_cost", lean_folds = 6L,
         refused = "sweep workers; compiled FIFO", backstop = "",
         reason = "Cut 16 decision 4: costs covered; its one-worker sweep candidates run lean"))
add(both(action = "update", mode = "gate", workload = "dense_risk_features", lean_folds = 0L,
         refused = "opening positions and imports; sweep workers", backstop = "",
         reason = "Cut 16 decision 4: costs and risk covered; next uncovered feature named"))

# Cut 16 slice-2 workloads: one lean fold, no refusal, no backstop
# (declared expected paths, LDG-3226 and LDG-3227).
slice2 <- c("s2_cost_fixed", "s2_cost_notional", "s2_cost_spread", "s2_cost_chain", "s2_risk_nonbinding",
            "s2_risk_bind", "s2_risk_long_only", "s2_risk_chain", "s2_risk_equity_refusal", "s2_risk_short_refusal",
            "s2_cost_insufficient", "s2_cost_sale_consumes", "s2_cost_nonpositive_price")
for (w in slice2) {
  add(both(action = "add", mode = "gate", workload = w, lean_folds = 1L, refused = "", backstop = "",
           reason = "Cut 16 slice-2 workload, declared path"))
}

sizing <- c("s2_sizing_rebalance", "s2_sizing_adjust", "s2_sizing_risk", "s2_sizing_combo", "s2_sizing_reasons",
            "s2_sizing_notice", "s2_sizing_stale", "s2_sizing_malformed", "s2_sizing_malformed_target",
            "s2_sizing_batch", "s2_sizing_growth", "s2_sizing_prefix")
for (w in sizing) {
  add(both(action = "add", mode = "gate", workload = w, lean_folds = 1L, refused = "", backstop = "",
           reason = "Cut 16 slice-2 workload, declared path"))
}
add(both(action = "add", mode = "gate", workload = "s2_sizing_sweep", lean_folds = 2L, refused = "", backstop = "",
         reason = "Cut 16 slice-2 one-worker sweep: two lean candidate folds, declared path"))
# R4: sizing across terminal batches (batch one) and with inert hooks, whose
# lean-fold count is 0 as for every inert row.
add(both(action = "add", mode = "batch1", workload = "s2_sizing_batch", lean_folds = 1L, refused = "", backstop = "",
         reason = "Cut 16 R4: sizing, intent, risk and costs across terminal batches, declared path"))
add(both(action = "add", mode = "inert", workload = "s2_sizing_rebalance", lean_folds = 0L, refused = "", backstop = "",
         reason = "Cut 16 R4: sizing with inert hooks, inert-mode count"))

# Cut 19 decision 7: the existing gate rows slice 3 moves, before -> after,
# at both debug settings (listed in LDG-3240's evidence). The history
# witnesses run lean since LDG-3237 (history reads covered); the other rows'
# refusal moves past declared sessions to the next uncovered feature.
slice3_moves <- list(
  list("avail_terminal_resume", 0L, "opening positions and imports; sweep workers"),
  list("avail_acquisition", 0L, "corporate actions"),
  list("avail_incomplete", 4L, "sweep workers"),
  list("walk_forward", 0L, "opening positions and imports; walk-forward"),
  list("failures", 4L, "sweep workers"),
  list("prep_fixture", 0L, "opening positions and imports"))
for (m in slice3_moves) {
  add(both(action = "update", mode = "gate", workload = m[[1L]], lean_folds = m[[2L]], refused = m[[3L]],
           backstop = "", reason = "Cut 19 decision 7: declared sessions covered; next uncovered feature named"))
}
for (w in c("witness_backstop", "witness_backstop_kind", "witness_caught_backstop", "witness_caught_rethrow",
            "witness_outer_handler")) {
  add(both(action = "update", mode = "gate", workload = w, lean_folds = 1L, refused = "", backstop = "",
           reason = "Cut 19 decision 6: history reads covered; the witness runs lean, no backstop"))
}
for (w in c("witness_backstop_sweep", "witness_caught_backstop_sweep", "witness_caught_rethrow_sweep")) {
  add(both(action = "update", mode = "gate", workload = w, lean_folds = 2L, refused = "", backstop = "",
           reason = "Cut 19 decision 6: history reads covered; both candidates run lean, no backstop"))
}
add(both(action = "update", mode = "gate", workload = "momentum_40x504", lean_folds = 1L, refused = "", backstop = "",
         reason = "Cut 19 decision 7: schedules covered (LDG-3239); the workload runs lean"))
# Cut 19 slice-3 workloads: declared paths.
slice3 <- c(s3_sessions_full = 1L, s3_hist_bar_native = 1L, s3_hist_declared = 1L, s3_hist_offset_bar = 1L,
            s3_hist_offset_feature = 1L,
            # LDG-3238
            s3_gap_held = 1L, s3_freeze_held = 1L, s3_stop_refuse = 1L, s3_freeze_exit = 1L, s3_stale_reduction = 1L,
            s3_exec_bar_missing = 1L, s3_sizing_unpriced = 1L, s3_risk_mark_expired = 1L, s3_risk_mark_never = 1L,
            s3_frozen_increase = 1L, s3_frozen_liquidate = 1L, s3_sizing_liquidate_stale = 1L,
            s3_sizing_liquidate_frozen = 1L, s3_no_bar_session = 1L, s3_closed_sessions = 1L, s3_prefix_declared = 1L,
            s3_missing_sweep = 2L, s3_offset_full = 1L, s3_offset_first_stale = 1L, s3_prescoring_gap = 1L,
            s3_tail_gap = 1L, s3_mixed_transition = 1L, s3_multi_stop = 1L, s3_many_gaps = 1L,
            # LDG-3239 (s3_sched_none: the pin's no-decision refusal precedes any fold; the sweep's
            # second candidate fails at entry)
            s3_sched_full = 1L, s3_sched_stale = 1L, s3_sched_query = 1L, s3_sched_none = 0L, s3_skip_stop = 1L,
            s3_skip_stop_first = 1L, s3_sched_prefix = 1L, s3_sched_sweep = 1L)
for (w in names(slice3)) {
  add(both(action = "add", mode = "gate", workload = w, lean_folds = slice3[[w]], refused = "", backstop = "",
           reason = "Cut 19 slice-3 workload, declared path"))
}
# LDG-3238: valuation, risk and stop rows across terminal batches (batch
# one), and a marked run with inert hooks (inert-mode count 0).
for (w in c("s3_mixed_transition", "s3_multi_stop")) {
  add(both(action = "add", mode = "batch1", workload = w, lean_folds = 1L, refused = "", backstop = "",
           reason = "Cut 19 LDG-3238: slice-3 rows across terminal batches, declared path"))
}
add(both(action = "add", mode = "inert", workload = "s3_freeze_exit", lean_folds = 0L, refused = "", backstop = "",
         reason = "Cut 19 LDG-3238: a marked run with inert hooks, inert-mode count"))

# Cut 21, LDG-3243 (workstream 39's intermediate paths, decision 10 and cut
# review R9): opening positions and carried openings covered, so the four
# workloads that stopped at "opening positions and imports" move to their
# next uncovered feature; their final slice-4 paths are LDG-3248's.
for (u in list(list("dense_risk_features", 4L, "sweep workers"),
               list("avail_terminal_resume", 0L, "membership, status or lifetime facts; sweep workers"),
               list("walk_forward", 4L, "walk-forward"),
               list("prep_fixture", 0L, "membership, status or lifetime facts"))) {
  add(both(action = "update", mode = "gate", workload = u[[1L]], lean_folds = u[[2L]], refused = u[[3L]],
           backstop = "", reason = "Cut 21 LDG-3243: opening positions covered; next uncovered feature named"))
}
slice4_3243 <- c(s4_opening = 1L, s4_opening_sessions = 1L, s4_carried = 0L, s4_carried_lots = 1L,
                 s4_basis_unknown = 1L, s4_basis_known = 1L, s4_prefix_opening_sweep = 1L, s4_prefix_opening_run = 1L)
for (w in names(slice4_3243)) {
  add(both(action = "add", mode = "gate", workload = w, lean_folds = slice4_3243[[w]],
           refused = if (w == "s4_carried") "corporate actions" else "", backstop = "",
           reason = if (w == "s4_carried") "Cut 21 LDG-3243 workload; its pending entitlement needs the corporate-action plan (LDG-3244)" else
             "Cut 21 LDG-3243 slice-4 workload, declared path"))
}
# Opening and carried rows across terminal batches (batch one), and a carried
# window and a sweep with an opening under inert hooks (inert-mode count 0).
for (w in c("s4_opening", "s4_carried_lots", "s4_prefix_opening_sweep")) {
  add(both(action = "add", mode = "batch1", workload = w, lean_folds = 1L, refused = "", backstop = "",
           reason = "Cut 21 LDG-3243: opening and carried rows across terminal batches, declared path"))
}
for (w in c("s4_carried_lots", "s4_basis_unknown")) {
  add(both(action = "add", mode = "inert", workload = w, lean_folds = 0L, refused = "", backstop = "",
           reason = "Cut 21 LDG-3243: an opening under inert hooks, inert-mode count"))
}

# Cut 21, LDG-3244 (workstream 39's intermediate paths, decision 10 and cut
# review R9): corporate actions covered but for scheduled dispositions, so
# the carried window with its pending entitlement and the dense dividend run
# go lean, and the acquisition run moves to its next uncovered feature; its
# final path is LDG-3248's.
for (u in list(list("s4_carried", 1L, ""), list("dense_dividend_state", 4L, ""),
               list("avail_acquisition", 0L, "corporate-action dispositions"))) {
  add(both(action = "update", mode = "gate", workload = u[[1L]], lean_folds = u[[2L]], refused = u[[3L]],
           backstop = "", reason = "Cut 21 LDG-3244: corporate actions covered but for scheduled dispositions"))
}
slice4_3244 <- c("s4_dividend", "s4_dividend_bought", "s4_dividend_sessions", "s4_dividend_skip", "s4_dividend_next_open",
  "s4_dividend_late", "s4_dividend_unheld", "s4_cash_refused", "s4_quantity_refused", "s4_cash_quantity_refused",
  "s4_quantity_reported", "s4_clock_missing", "s4_entitlement_missing", "s4_dividend_mixed", "s4_cash_overflow",
  "s4_prefix_dividend_sweep", "s4_prefix_dividend_bought", "s4_prefix_dividend_run", "s4_prefix_dividend_stop")
for (w in slice4_3244) {
  add(both(action = "add", mode = "gate", workload = w, lean_folds = 1L, refused = "", backstop = "",
           reason = "Cut 21 LDG-3244 slice-4 workload, declared path"))
}
# Corporate-action and fill rows across terminal batches (batch one), and
# corporate actions under inert hooks (inert-mode count 0).
for (w in c("s4_dividend", "s4_dividend_mixed", "s4_dividend_skip", "s4_cash_refused", "s4_prefix_dividend_sweep",
            "s4_carried")) {
  add(both(action = "add", mode = "batch1", workload = w, lean_folds = 1L, refused = "", backstop = "",
           reason = "Cut 21 LDG-3244: corporate-action rows across terminal batches, declared path"))
}
for (w in c("s4_dividend", "s4_dividend_mixed")) {
  add(both(action = "add", mode = "inert", workload = w, lean_folds = 0L, refused = "", backstop = "",
           reason = "Cut 21 LDG-3244: corporate actions under inert hooks, inert-mode count"))
}

out <- do.call(rbind, rows)
utils::write.csv(out, file.path(here, "loop_freeze_changes.csv"), row.names = FALSE)
cat(nrow(out), "changes:", paste(names(table(out$action)), table(out$action), collapse = ", "), "\n")
