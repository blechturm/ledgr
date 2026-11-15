# Profile cells shared by cost_map.R (runs) and sweep_map.R (sweeps): the
# frame-to-cell map, the leaf-first attribution and its synthetic stack
# witnesses. Sourced after descriptors.R (required_cells reads descriptors).

# --- attribution --------------------------------------------------------------
wrapper_frames <- c("ledgr_call_strategy_fn", "tryCatch", "tryCatchList", "tryCatchOne", "doTryCatch", "withCallingHandlers")
callee <- function(f) grepl("^\\$\\.ledgr_|^ledgr_|\\$hold$|\\$flat$|^hold$|^flat$", f)
stage_cells <- c(
  lean_context = "P2 context", lean_p1_value = "P1", lean_p2_decide = "P2 other", lean_p3_plan = "P3",
  lean_lot_fill = "P4 FIFO", lean_p4_apply = "P4 other", lean_p5_commit = "P5", lean_e_advance = "E advance",
  ledgr_fold_stage_observe_settle = "P1", ledgr_fold_stage_decide = "P2 other", ledgr_fold_stage_plan = "P3",
  ledgr_fold_stage_apply = "P4 other", ledgr_fold_stage_commit = "P5",
  # Cut 16 (LDG-3229): the pin's risk and sizing-evidence calls in P2, and
  # the lean sizing record, own cells (a strategy's own helper calls stay
  # in the strategy cells, which are decided first)
  ledgr_apply_risk_plan = "P2 risk", ledgr_availability_validate_post_risk = "P2 risk",
  ledgr_availability_validate_short_exposure = "P2 risk", ledgr_validate_post_risk_quantities = "P2 risk",
  ledgr_validate_sizing_evidence = "P2 sizing", lean_loop_add_sizing = "P2 sizing",
  # Cut 18 (LDG-3235): the lean fast paths in checks.R that replaced those
  # calls keep their cells; the target check gets its own
  lean_risk_targets = "P2 risk", lean_risk_pin = "P2 risk", lean_sizing_evidence = "P2 sizing",
  lean_targets = "P2 targets", ledgr_validate_strategy_targets = "P2 targets")
loop_cells <- c("strategy: own work", "strategy: ledgr callees", "strategy: call wrapper", unique(stage_cells),
                "loop: residual")
is_loop_cell <- function(cell) cell %in% loop_cells | startsWith(cell, "loop: ")
# Cells every run of an arm has; a required cell without samples is
# reported as unresolved, never as zero. A descriptor with risk and sizing
# (slice2_10x7200) also requires P2 risk and P2 sizing.
required_cells_base <- list(
  lean = c("strategy: own work", "strategy: ledgr callees", "strategy: call wrapper", "P1", "P2 context", "P2 other",
           "P3", "P4 FIFO", "P4 other", "P5", "E advance", "loop: residual"),
  pin = c("strategy: own work", "strategy: ledgr callees", "strategy: call wrapper", "P1", "P2 other", "P3", "P4 other",
          "P5", "loop: residual"))
required_cells <- function(arm, shape) {
  c(required_cells_base[[arm]], if (identical(bench_descriptor(shape)$family, "slice2")) c("P2 risk", "P2 sizing"))
}
base_names <- ls(baseenv(), all.names = TRUE)
other_cells <- c(
  lean_loop_expand = "transfer: expand", lean_loop_layout = "transfer: expand", lean_loop_keep = "transfer: expand",
  lean_loop_positions_at = "transfer: expand", lean_loop_explicit_block = "transfer: expand",
  # the transfer runs as `fn` inside the publish hook
  lean_loop_publish = "transfer: write", "hooks$publish" = "transfer: write", envelope = "envelope: setup and commit",
  ledgr_fold_envelope = "envelope: setup and commit",
  ledgr_history_compute_feature_series = "pre: features", ledgr_projection_from_feature_matrix = "pre: feature projection",
  ledgr_history_substrate_bind_features = "pre: feature projection",
  ledgr_history_substrate_for_experiment = "pre: bars substrate", ledgr_history_substrate = "pre: bars substrate",
  ledgr_availability_provider_from_substrate = "pre: provider",
  ledgr_experiment_materialize_feature_result = "pre: feature declarations",
  ledgr_strategy_preflight = "pre: strategy preflight", ledgr_run_snapshot_guard = "pre: snapshot guard",
  ledgr_run_registration = "pre: store and registration", ledgr_run_registration_provenance = "pre: store and registration",
  ledgr_validate_schema_once = "pre: store and registration", ledgr_store_open = "pre: store and registration",
  ledgr_config = "pre: config", ledgr_run_finalize = "post: finalise", ledgr_finalize_fold_telemetry = "post: telemetry",
  new_ledgr_backtest = "post: result object")
# The sweep's own frames (sweep_map.R); a candidate's fold falls in the loop,
# envelope and transfer cells above, its feature computation in pre: features.
other_cells <- c(other_cells,
  ledgr_sweep_candidate_tasks = "sweep: candidate tasks", ledgr_resolve_feature_candidates = "sweep: feature resolution",
  ledgr_sweep_candidate_execution = "sweep: candidate setup", ledgr_sweep_summary_from_ordered_events = "sweep: summary",
  ledgr_fill_recording_pulses_from_opportunities = "sweep: fill recording", ledgr_fills_add_recording_pulse = "sweep: fill recording",
  ledgr_sweep_success_row = "sweep: result rows", ledgr_sweep_provenance = "sweep: result rows")
cell_of <- function(s) {
  # the strategy frame: `fn` called by ledgr_call_strategy_fn
  js <- which(s == "fn" & c(s[-1L], "") == "ledgr_call_strategy_fn")
  if (length(js)) {
    below <- s[seq_len(js[[1L]] - 1L)]
    return(if (any(callee(below))) "strategy: ledgr callees" else "strategy: own work")
  }
  for (j in seq_along(s)) {
    f <- s[[j]]
    if (f %in% c("ledgr_call_strategy_fn")) return("strategy: call wrapper")
    if (f %in% c("lean_p2_decide", "ledgr_fold_stage_decide") && j > 1L && all(s[seq_len(j - 1L)] %in% wrapper_frames) &&
        any(s[seq_len(j - 1L)] == "tryCatch")) return("strategy: call wrapper")
    if (f %in% names(stage_cells)) return(stage_cells[[f]])
    if (f %in% names(other_cells)) return(other_cells[[f]])
    if (identical(f, "fn") && j < length(s) && identical(s[[j + 1L]], "withCallingHandlers") && "ledgr_fold_envelope" %in% s) {
      # the loop body itself: its direct named callee, else base code
      callee_name <- if (j > 1L) s[[j - 1L]] else ""
      if (nzchar(callee_name) && !callee_name %in% base_names && !startsWith(callee_name, "<")) {
        return(paste0("loop: ", callee_name))
      }
      return("loop: residual")
    }
  }
  if ("ledgr_run" %in% s) "run: other" else if ("ledgr_sweep" %in% s) "sweep: other" else "outside the run"
}
attribute <- function(lines) {
  lines <- lines[!grepl("^sample.interval|^#", lines)]
  cells <- vapply(strsplit(lines, " ", fixed = TRUE), function(s) cell_of(gsub('"', "", s)), character(1L))
  table(cells[cells != "outside the run"])
}

# Synthetic stack witnesses (Cut 15, LDG-3225, R6): the frames Cut 15 added
# fall in the cells their callers own. Leaf first, as Rprof writes them.
stack_witnesses <- list(
  "P4 FIFO" = c("lean_lot_simple", "lean_lot_apply", "lean_lot_fill", "lean_p4_apply", "run_loop"),
  "P4 FIFO" = c("lean_lot_tol", "lean_lot_general", "lean_lot_apply", "lean_lot_fill", "lean_p4_apply"),
  "P2 context" = c("lean_strategy_view", "lean_context", "lean_p2_decide", "run_loop"),
  "strategy: ledgr callees" = c("$.ledgr_pulse_context", "$", "fn", "ledgr_call_strategy_fn", "doTryCatch",
                                "tryCatchOne", "tryCatchList", "tryCatch", "lean_p2_decide"),
  "strategy: call wrapper" = c("tryCatchList", "tryCatch", "lean_p2_decide", "run_loop"),
  # Cut 16 (LDG-3229): the risk, sizing-validation and sizing-expansion calls
  "P2 risk" = c("vapply", "ledgr_apply_risk_plan", "lean_p2_decide", "run_loop"),
  "P2 risk" = c("ledgr_availability_validate_post_risk", "lean_p2_decide", "run_loop"),
  "P2 risk" = c("ledgr_availability_validate_short_exposure", "lean_p2_decide", "run_loop"),
  "P2 sizing" = c("is.finite", "ledgr_validate_sizing_evidence", "lean_p2_decide", "run_loop"),
  "P2 sizing" = c("lean_loop_add_sizing", "lean_p2_decide", "run_loop"),
  "transfer: expand" = c("lean_rows_in", "lean_loop_expand", "fn", "lean_loop_publish"),
  "strategy: ledgr callees" = c("ledgr_validate_sizing_evidence", "ledgr_target_rebalance", "fn",
                                "ledgr_call_strategy_fn", "doTryCatch", "tryCatchOne", "tryCatchList", "tryCatch",
                                "lean_p2_decide")
)
stack_fail <- names(stack_witnesses)[vapply(seq_along(stack_witnesses), function(i)
  !identical(cell_of(stack_witnesses[[i]]), names(stack_witnesses)[[i]]), logical(1L))]
if (length(stack_fail)) stop("attribution: synthetic stacks misattributed for ", paste(stack_fail, collapse = ", "), call. = FALSE)
