# Slice-5 workloads (Cut 26, workstream 46; interface Section 19.14): the
# restart routes, the compiled selector and walk-forward (LDG-3272), built
# with public constructors and package helpers, the pin as oracle. Sourced by
# loop_parity.R after loop_workloads_slice4.R, whose s4_ helpers it uses
# (with lw_rebind from loop_workloads.R and the a0_ helpers).
#
# loop_reach gains, per workload, the route it is named for, asserted on the
# pin's own tables before parity is accepted. A route that leaves no trace in
# the tables (a fold count, a native dispatch) is counted during the pinned
# arm into s5_seen, which loop_parity.R evaluates the predicate right after.

s5_seen <- new.env(parent = emptyenv())
s5_cond <- function(e) {
  data.frame(class = paste(setdiff(class(e), c("rlang_error", "error", "condition")), collapse = "/"),
             message = conditionMessage(e), stringsAsFactors = FALSE)
}
s5_runs <- function(t) t$runs
s5_status <- function(t) as.character(t$runs$status)
s5_events <- function(t) if (is.data.frame(t$ledger_events)) t$ledger_events else data.frame()

# --- restart routes (decision 4) ------------------------------------------------
# A strategy whose day-5 call fails while the option is set; it buys on days
# 2 and 4 and draws once on day 3 (seeded runs), so a fresh attempt that does
# not reset the RNG sequence or state differs. Pulse dates are literals.
s5_strategy <- function(fail_option = "ledgr.s5_fail", replay_option = "ledgr.s5_replay_forbidden") {
  f <- function(ctx, params) NULL
  body(f) <- substitute({
    if (isTRUE(getOption(REPLAY))) stop("s5: the strategy was called on a replay")
    target <- ctx$hold()
    if (isTRUE(getOption(FAIL)) && identical(ctx$ts_utc, D5)) stop("s5 probe failure")
    if (identical(ctx$ts_utc, D2)) target[["A"]] <- 5
    if (identical(ctx$ts_utc, D3)) target[["C"]] <- if (stats::runif(1L) > 0.5) 3 else 2
    if (identical(ctx$ts_utc, D4)) target[["B"]] <- 2
    if (identical(ctx$ts_utc, D7)) target[["A"]] <- 1
    target
  }, list(FAIL = fail_option, REPLAY = replay_option,
          D2 = s4_iso(2L), D3 = s4_iso(3L), D4 = s4_iso(4L), D5 = s4_iso(5L), D7 = s4_iso(7L)))
  environment(f) <- ns
  f
}
s5_with_options <- function(values, expr) {
  old <- options(values)
  on.exit(options(old))
  expr
}
# Fresh replacement after FAILED without completion evidence.
s5_restart_failed <- function(name, positions = NULL, cost_basis = NULL) function() {
  db <- s4_snapshot(name, s4_closes(), NULL)
  snapshot <- ledgr::ledgr_snapshot_open(db, name, verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot))
  exp <- s4_exp(s5_strategy(), positions = positions, cost_basis = cost_basis)(snapshot)
  run_id <- paste0("s5-", name)
  first <- s5_with_options(list(ledgr.s5_fail = TRUE), collect_open(snapshot, db, run_id, exp, seed = 21L))
  second <- collect_open(snapshot, db, run_id, exp, seed = 21L)
  list(attempt1 = first$run, run = second$run)
}
# Fresh replacement after a RUNNING max_pulses attempt: the same config
# again (max_pulses is part of the config identity, so another control is
# refused as a config_hash mismatch); the second invocation enters a fresh
# fold and replaces the first attempt's output.
s5_restart_running <- function(name) function() {
  db <- s4_snapshot(name, s4_closes(), NULL)
  snapshot <- ledgr::ledgr_snapshot_open(db, name, verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot))
  exp <- s4_exp(s5_strategy(), positions = c(A = 3), cost_basis = c(A = 30))(snapshot)
  exp$control <- list(max_pulses = 5L)
  restore <- s5_count_folds()
  on.exit(restore(), add = TRUE)
  run_id <- paste0("s5-", name)
  first <- collect_open(snapshot, db, run_id, exp, seed = 21L)
  folds_first <- s5_seen$folds
  second <- collect_open(snapshot, db, run_id, exp, seed = 21L)
  s5_seen$fold_counts <- c(folds_first, s5_seen$folds)
  list(attempt1 = first$run, run = second$run)
}
# Counts fold entries in this arm (pin or lean: whichever envelope is bound).
s5_count_folds <- function() {
  s5_seen$folds <- 0L
  inner <- get("ledgr_fold_envelope", envir = ns)
  lw_rebind("ledgr_fold_envelope", function(execution, output_handler) {
    s5_seen$folds <- s5_seen$folds + 1L
    inner(execution, output_handler)
  })
}
s5_incomplete_exp <- function(snapshot) ledgr::ledgr_experiment(snapshot, s5_strategy(),
  opening = ledgr::ledgr_opening(cash = 5000, positions = c(A = 3), cost_basis = c(A = 28)),
  cost_model = ledgr::ledgr_cost_zero(), valuation_policy = ledgr::ledgr_valuation_stale(1L, exhausted = "refuse"))
s5_incomplete_db <- function(name) {
  closes <- s4_closes()
  closes$A[5:10] <- NA
  s4_snapshot(name, closes, ledgr::ledgr_facts(s4_sessions(10L)))
}
# Achieved INCOMPLETE reopen: the second invocation validates the completion
# evidence and enters no fold; a strategy call on the replay fails.
s5_reopen_incomplete <- function() {
  name <- "s5_reopen_incomplete"
  db <- s5_incomplete_db(name)
  snapshot <- ledgr::ledgr_snapshot_open(db, name, verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot))
  exp <- s5_incomplete_exp(snapshot)
  restore <- s5_count_folds()
  on.exit(restore(), add = TRUE)
  first <- collect_open(snapshot, db, "s5-reopen", exp, seed = 8L)
  folds_first <- s5_seen$folds
  second <- s5_with_options(list(ledgr.s5_replay_forbidden = TRUE), collect_open(snapshot, db, "s5-reopen", exp, seed = 8L))
  s5_seen$fold_counts <- c(folds_first, s5_seen$folds)
  list(attempt1 = first$run, run = second$run,
       route = list(folds = data.frame(first = folds_first, total = s5_seen$folds)))
}
# Completion recovery: a terminal-finalization fault leaves the run with its
# completion evidence; the second invocation finalizes it without a fold.
s5_recover_completion <- function() {
  name <- "s5_recover_completion"
  db <- s5_incomplete_db(name)
  snapshot <- ledgr::ledgr_snapshot_open(db, name, verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot))
  exp <- s5_incomplete_exp(snapshot)
  restore <- s5_count_folds()
  on.exit(restore(), add = TRUE)
  restore_final <- lw_rebind("ledgr_run_finalize", function(...) stop("s5: injected finalization failure"))
  first <- tryCatch(collect_open(snapshot, db, "s5-recover", exp, seed = 8L), finally = restore_final())
  folds_first <- s5_seen$folds
  second <- s5_with_options(list(ledgr.s5_replay_forbidden = TRUE), collect_open(snapshot, db, "s5-recover", exp, seed = 8L))
  s5_seen$fold_counts <- c(folds_first, s5_seen$folds)
  list(attempt1 = first$run, run = second$run,
       route = list(folds = data.frame(first = folds_first, total = s5_seen$folds)))
}

# --- the compiled selector (decision 3) ------------------------------------------
s5_hold_buy <- function(ctx, params) {
  target <- ctx$hold()
  target[["A"]] <- 2
  target
}
environment(s5_hold_buy) <- ns
s5_grid <- function() ledgr::ledgr_grid_named(a = list(strategy = list(k = 1L)))
# A sweep under the selector, by stop_on_error: a candidate row (FALSE) or the
# escaping condition (TRUE).
s5_selected_sweep <- function(exp, stop_on_error) {
  tryCatch(list(sweep = a0_sweep_tables(ledgr::ledgr_sweep(exp, s5_grid(), seed = 5L, retain = a0_retain(),
                                                         compiled_accounting_model = "spot_fifo",
                                                         stop_on_error = stop_on_error))),
           error = function(e) list(escaped = list(condition = s5_cond(e))))
}
s5_both_forms <- function(exp) {
  a <- s5_selected_sweep(exp, FALSE)
  b <- s5_selected_sweep(exp, TRUE)
  stats::setNames(c(a, b), c(paste0(names(a), "_row"), paste0(names(b), "_escape")))
}
# The pin's native dispatch, counted in the pinned arm (the lean arm never
# calls it): ledgr_run_compiled_spot_fifo_batch() calls.
s5_count_native <- function() {
  s5_seen$native <- 0L
  inner <- get("ledgr_run_compiled_spot_fifo_batch", envir = ns)
  lw_rebind("ledgr_run_compiled_spot_fifo_batch", function(...) {
    s5_seen$native <- s5_seen$native + 1L
    inner(...)
  })
}
# The public durable refusal at ledgr_run entry (not an E-stage witness).
s5_compiled_durable <- function() {
  name <- "s5_compiled_durable"
  db <- s4_snapshot(name, s4_closes(), NULL)
  snapshot <- ledgr::ledgr_snapshot_open(db, name, verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot))
  exp <- s4_exp(s5_hold_buy)(snapshot)
  out <- tryCatch({
    close(ledgr::ledgr_run(exp, run_id = "s5-durable", compiled_accounting_model = "spot_fifo"))
    data.frame(class = "", message = "completed", stringsAsFactors = FALSE)
  }, error = s5_cond)
  list(entry = list(condition = out, runs = a0_store_tables(db, "s5-durable")$runs))
}
# The E event-kind refusal: a corporate-facts-only selected sweep.
s5_compiled_event_kinds <- function() {
  name <- "s5_compiled_event_kinds"
  db <- s4_snapshot(name, s4_closes(), s4_ca_facts(s4_div("s5-div", "A", 3L, 6L)))
  snapshot <- ledgr::ledgr_snapshot_open(db, name, verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot))
  s5_both_forms(s4_exp(s5_hold_buy, positions = c(A = 3), cost_basis = c(A = 28))(snapshot))
}
# The upstream availability refusal: a selected sweep on declared sessions.
s5_compiled_availability <- function() {
  name <- "s5_compiled_availability"
  db <- s4_snapshot(name, s4_closes(), ledgr::ledgr_facts(s4_sessions(10L)))
  snapshot <- ledgr::ledgr_snapshot_open(db, name, verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot))
  exp <- s4_exp(s5_hold_buy, valuation_policy = ledgr::ledgr_valuation_stale(1L))(snapshot)
  s5_both_forms(exp)
}
# The E dispatch refusal: the native routine missing (a test-only seam).
s5_compiled_missing_native <- function() {
  name <- "s5_compiled_missing_native"
  db <- s4_snapshot(name, s4_closes(), NULL)
  snapshot <- ledgr::ledgr_snapshot_open(db, name, verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot))
  restore <- lw_rebind("ledgr_cpp_spot_fifo_batch", NULL)
  on.exit(restore(), add = TRUE)
  s5_both_forms(s4_exp(s5_hold_buy)(snapshot))
}
# Successful selected sweeps: a fill-heavy multi-lot shape with partial
# closes, and a slice-2 cost shape. The pin's native dispatch is counted.
s5_lots_strategy <- function() {
  f <- function(ctx, params) NULL
  body(f) <- substitute({
    target <- ctx$hold()
    day <- match(ctx$ts_utc, DAYS)
    plan <- list(c(A = 4, B = 3), c(A = 9, C = 2), c(A = 6, B = 7), c(A = 12, C = 5), c(A = 3, B = 2),
                 c(A = 8, C = 1), c(A = 2, B = 6), c(A = 10, C = 4), c(A = 5, B = 1), c(A = 0, C = 0))
    if (!is.na(day)) for (id in names(plan[[day]])) target[[id]] <- plan[[day]][[id]]
    target
  }, list(DAYS = vapply(1:10, s4_iso, "")))
  environment(f) <- ns
  f
}
s5_compiled_success <- function(name, cost) function() {
  db <- s4_snapshot(name, s4_closes(), NULL)
  snapshot <- ledgr::ledgr_snapshot_open(db, name, verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot))
  exp <- ledgr::ledgr_experiment(snapshot, s5_lots_strategy(), opening = ledgr::ledgr_opening(cash = 1e4),
    cost_model = if (cost) s2_chain() else ledgr::ledgr_cost_zero())
  restore <- s5_count_native()
  on.exit(restore(), add = TRUE)
  s5_selected_sweep(exp, TRUE)
}
# A selected overflow: an opening holding with a basis near the double range
# (1e298 shares at 1e10, valued at the close, so equity stays finite) and a
# large buy: the pin's compiled arm runs its native batch and refuses with
# the canonical lot refusal, which the lean FIFO also raises.
s5_compiled_overflow <- function() {
  name <- "s5_compiled_overflow"
  db <- s4_snapshot(name, s4_closes(), NULL)
  snapshot <- ledgr::ledgr_snapshot_open(db, name, verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot))
  strategy <- function(ctx, params) {
    target <- ctx$hold()
    if (identical(ctx$ts_utc, "2020-01-02T16:00:00Z")) target[["B"]] <- 2e306
    target
  }
  environment(strategy) <- ns
  exp <- ledgr::ledgr_experiment(snapshot, strategy,
    opening = ledgr::ledgr_opening(cash = 1e308, positions = c(A = 1e298), cost_basis = c(A = 1e10)),
    cost_model = ledgr::ledgr_cost_zero())
  restore <- s5_count_native()
  on.exit(restore(), add = TRUE)
  s5_both_forms(exp)
}
# The selected-sweep capacity boundary (LR-19, D3-B): a lowered fill-event
# limit in both arms (the pin's output-handler buffers, the lean seam), at
# the limit (9 fill events: the run completes) and one below it (8: the last
# fill pulse refuses), each with the committed prefix read before every
# strategy call (lw_prefix_reads).
s5_compiled_capacity <- function(name, cap) function() {
  db <- s4_snapshot(name, s4_closes(), NULL)
  snapshot <- ledgr::ledgr_snapshot_open(db, name, verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot))
  strategy <- function(ctx, params) {
    t <- ctx$hold()
    t[["A"]] <- if (as.integer(substr(ctx$ts_utc, 9L, 10L)) %% 2L) 2 else 1
    t
  }
  environment(strategy) <- ns
  exp <- s4_exp(strategy)(snapshot)
  # The pin's limit lives in its output handler's buffers; the lean loop's
  # cumulative fill-only limit (LR-19) is its own seam.
  if (lw_lean_installed()) {
    old <- lean$lean_entry$capacity
    lean$lean_entry$capacity <- cap
    on.exit(lean$lean_entry$capacity <- old, add = TRUE)
  } else {
    inner <- get("ledgr_fold_envelope", envir = ns)
    restore <- lw_rebind("ledgr_fold_envelope", function(execution, output_handler) {
      init <- output_handler$init_buffers
      output_handler$init_buffers <- function(max_events) init(cap)
      inner(execution, output_handler)
    })
    on.exit(restore(), add = TRUE)
  }
  out <- s5_both_forms(exp)
  stats::setNames(out, sub("^sweep_row$", "sweep", names(out)))
}
s5_compiled_capacity_prefix <- function(name, cap) function() {
  lw_prefix_reads(memory = TRUE, workload = s5_compiled_capacity(name, cap))
}

# --- walk-forward (decision 4) ------------------------------------------------------
# Walk-forward with a cost model and a risk chain over two folds.
s5_walk_forward_costs <- function() {
  db <- lw_witness_db()
  snapshot <- ledgr::ledgr_snapshot_open(db, "lw_witness", verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot))
  strategy <- function(ctx, params) {
    targets <- ctx$hold()
    targets[["A"]] <- params$qty
    targets[["B"]] <- params$qty / 2
    targets
  }
  environment(strategy) <- ns
  exp <- ledgr::ledgr_experiment(snapshot, strategy, opening = ledgr::ledgr_opening(cash = 5000),
    cost_model = s2_chain(),
    risk_chain = ledgr::ledgr_risk_max_weight(0.4))
  grid <- ledgr::ledgr_grid_named(small = list(strategy = list(qty = 2)), large = list(strategy = list(qty = 6)))
  folds <- ns$ledgr_fold_list(list(
    ledgr::ledgr_fold("2021-01-04T00:00:00Z", "2021-01-07T00:00:00Z", "2021-01-08T00:00:00Z", "2021-01-11T00:00:00Z", fold_seq = 1L),
    ledgr::ledgr_fold("2021-01-08T00:00:00Z", "2021-01-11T00:00:00Z", "2021-01-12T00:00:00Z", "2021-01-17T00:00:00Z", fold_seq = 2L)
  ), constructor = list(type_id = "explicit"))
  wf <- ledgr::ledgr_walk_forward(exp, grid = grid, folds = folds,
                                  selection_rule = ledgr::ledgr_rule_argmax("sharpe_ratio"), seed = 3L)
  ids <- vapply(wf$test_runs, function(bt) bt$run_id, character(1L))
  lapply(wf$test_runs, close)
  list(walk_forward = c(list(
    wf_folds = a0_canon(as.data.frame(wf$folds), "wf_folds", "fold_seq"),
    wf_scores = a0_canon(as.data.frame(wf$scores), "wf_scores", c("fold_seq", "window", "candidate_key", "metric_name")),
    wf_status = a0_canon(data.frame(status = wf$status, test_run_ids = paste(ids, collapse = ","), stringsAsFactors = FALSE),
                         "wf_status", "status")), a0_store_tables(db, ids)))
}

loop_slice5 <- list(
  s5_restart_plain = s5_restart_failed("s5_restart_plain"),
  s5_restart_opening = s5_restart_failed("s5_restart_opening", positions = c(A = 3, B = 1), cost_basis = c(A = 30, B = 44)),
  s5_restart_running = s5_restart_running("s5_restart_running"),
  s5_reopen_incomplete = s5_reopen_incomplete,
  s5_recover_completion = s5_recover_completion,
  s5_compiled_durable = s5_compiled_durable,
  s5_compiled_event_kinds = s5_compiled_event_kinds,
  s5_compiled_availability = s5_compiled_availability,
  s5_compiled_missing_native = s5_compiled_missing_native,
  s5_compiled_lots = s5_compiled_success("s5_compiled_lots", FALSE),
  s5_compiled_costs = s5_compiled_success("s5_compiled_costs", TRUE),
  s5_compiled_overflow = s5_compiled_overflow,
  s5_compiled_capacity_at = s5_compiled_capacity_prefix("s5_compiled_capacity_at", 9L),
  s5_compiled_capacity_over = s5_compiled_capacity_prefix("s5_compiled_capacity_over", 8L),
  s5_walk_forward_costs = s5_walk_forward_costs
)

# The route each workload is named for, on the pin's own tables.
s5_failed_then_done <- function(t, events) {
  identical(s5_status(t$attempt1), "FAILED") && identical(s5_status(t$run), "DONE") &&
    nrow(s5_events(t$run)) == events && !anyDuplicated(s5_events(t$run)$event_seq)
}
loop_reach <- c(loop_reach, list(
  s5_restart_plain = function(t) s5_failed_then_done(t, 4L),
  s5_restart_opening = function(t) s5_failed_then_done(t, 6L),
  s5_restart_running = function(t) {
    identical(s5_status(t$attempt1), "RUNNING") && identical(s5_status(t$run), "RUNNING") &&
      nrow(s5_events(t$run)) == nrow(s5_events(t$attempt1)) && !anyDuplicated(s5_events(t$run)$event_seq) &&
      NROW(t$run$run_conditions) == 0L && identical(s5_seen$fold_counts, c(1L, 2L))
  },
  s5_reopen_incomplete = function(t) {
    identical(s5_status(t$attempt1), "INCOMPLETE") && identical(s5_status(t$run), "INCOMPLETE") &&
      identical(s5_seen$fold_counts, c(1L, 1L))
  },
  s5_recover_completion = function(t) {
    s5_status(t$attempt1) %in% c("RUNNING", "FAILED") && identical(s5_status(t$run), "INCOMPLETE") &&
      identical(s5_seen$fold_counts, c(1L, 1L))
  },
  s5_compiled_durable = function(t) nzchar(t$entry$condition$class) && nrow(t$entry$runs) == 0L,
  s5_compiled_event_kinds = function(t) {
    identical(as.character(t$sweep_row$sweep$status), "FAILED") && !is.null(t$escaped_escape)
  },
  s5_compiled_availability = function(t) !is.null(t$escaped_row) && !is.null(t$escaped_escape),
  s5_compiled_missing_native = function(t) {
    identical(as.character(t$sweep_row$sweep$status), "FAILED") && !is.null(t$escaped_escape)
  },
  s5_compiled_lots = function(t) isTRUE(s5_seen$native > 0L) && !is.null(t$sweep),
  s5_compiled_costs = function(t) isTRUE(s5_seen$native > 0L) && !is.null(t$sweep),
  s5_walk_forward_costs = function(t) {
    le <- t$walk_forward$ledger_events
    identical(as.character(t$walk_forward$wf_status$status), "DONE") &&
      any(le$event_type == "FILL" & as.numeric(le$fee) > 0)
  },
  s5_compiled_overflow = function(t) {
    isTRUE(s5_seen$native > 0L) && identical(as.character(t$sweep_row$sweep$error_class), "ledgr_invalid_lot_fill")
  },
  s5_compiled_capacity_at = function(t) {
    identical(as.character(t$sweep$sweep$status), "DONE") && !is.null(t$sweep_escape) && !is.null(t$sweep$prefix_reads)
  },
  s5_compiled_capacity_over = function(t) {
    identical(as.character(t$sweep$sweep$error_class), "ledgr_event_buffer_capacity_exceeded") &&
      !is.null(t$escaped_escape) && !is.null(t$sweep$prefix_reads)
  }
))
