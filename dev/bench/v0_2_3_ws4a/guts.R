# WS4a guts: one product regression per design-note Section 4 gut, applied as
# an in-memory namespace patch (check.R --gut=<name>) in a fresh process.
# Every gut must make check.R fail for its case. Run as a script, it runs
# each gut and writes records/gut_results.csv.
#
# Usage: Rscript guts.R [--out=<scratch dir>] [--guts=<name,name>]

ws_ns <- function(name) get(name, envir = asNamespace("ledgr"))
ws_gut <- new.env()
ws_plain <- function(steps) Filter(function(s) !identical(s$type_id, "notional_bps_fee"), steps)
ws_swallow <- function(method) {
  swallow <- function(original) function(...) tryCatch(original(...), ws4a_injected = function(e) {
    if (!grepl(method, conditionMessage(e), fixed = TRUE)) stop(e)
    list(sample_start = NULL, t_event = 0, t_state = 0, continue = TRUE)
  })
  list(ledgr_fold_stage_apply = swallow, ledgr_fold_stage_commit = swallow)
}
ws_skip_gut <- function(stage) {
  out <- list(ledgr_fold_stage_observe_settle = function(original) function(fold_state, services, ...) {
    ws_gut$services <- services
    ws_gut$observation <- original(fold_state, services, ...)
  })
  if (stage == "plan") out$ledgr_fold_scheduled_skip_plan <- function(original) function(fold_state, decision) {
    ws_ns("ledgr_fold_stage_plan")(fold_state, ws_gut$services, ws_gut$observation, decision, FALSE, NULL)
    original(fold_state, decision)
  } else out$ledgr_fold_scheduled_skip_decision <- function(original) function(fold_state, observation) {
    ws_ns("ledgr_fold_stage_decide")(fold_state, ws_gut$services, observation, FALSE, NULL)
    original(fold_state, observation)
  }
  out
}
ws_flip <- function(state, id) {
  i <- match(id, state$instrument_ids)
  live <- if (is.na(i)) integer() else seq.int(state$lot_head[[i]], length.out = max(0L, state$lot_tail[[i]] - state$lot_head[[i]] + 1L))
  if (length(live) < 2L) return(state)
  state$lot_qty[[i]][live] <- rev(state$lot_qty[[i]][live])
  state$lot_price[[i]][live] <- rev(state$lot_price[[i]][live])
  state
}

ws4a_guts <- list(
  C1_drop_notional = list(case = "C1", patch = list(ledgr_cost_model_resolve = function(original) function(proposal, fill_context, steps, ...) {
    original(proposal, fill_context, ws_plain(steps), ...)
  })),
  C2_notional_from_rounded = list(case = "C2", patch = list(ledgr_cost_model_resolve = function(original) function(proposal, fill_context, steps, ...) {
    fill <- original(proposal, fill_context, ws_plain(steps), ...)
    for (s in setdiff(steps, ws_plain(steps))) fill$fee <- fill$fee + abs(fill$qty * fill$fill_price) * s$args$bps / 10000
    fill
  })),
  C3_tolerance_x10 = list(case = "C3", patch = list(ledgr_lot_dust_tolerance = function(original) function(...) 10 * original(...))),
  C4_lifo = list(case = "C4", patch = list(ledgr_lot_apply_fill = function(original) function(state, instrument_id, side, ...) {
    net <- sum(state$net_by_inst[names(state$net_by_inst) == instrument_id])
    if (net * (if (identical(side, "BUY")) 1 else -1) >= 0) return(original(state, instrument_id, side, ...))
    out <- original(ws_flip(state, instrument_id), instrument_id, side, ...)
    out$state <- ws_flip(out$state, instrument_id)
    out
  })),
  C5a_reorder_carried_openings = list(case = "C5a", patch = list(ledgr_walk_forward_carried_opening = function(original) function(...) {
    opening <- original(...)
    if (!is.null(opening$carried$lots)) opening$carried$lots <- lapply(opening$carried$lots, rev)
    opening
  })),
  C5b_kahan_on_openings = list(case = "C5b", patch = list(ledgr_lot_apply_opening = function(original) function(...) {
    ws_ns("ledgr_lot_add_realized")(original(...), 0)
  })),
  C6_leave_one_live_lot = list(case = "C6", patch = list(ledgr_lot_apply_fill = function(original) function(state, instrument_id, side, qty, ...,
                                                                                                             allow_zero_price = FALSE) {
    original(state, instrument_id, side, if (allow_zero_price) qty / 2 else qty, ..., allow_zero_price = allow_zero_price)
  })),
  C7_plan_on_skip = list(case = "C7", patch = ws_skip_gut("plan")),
  C7_strategy_on_skip = list(case = "C7", patch = ws_skip_gut("decision")),
  C8a_suppress_stop = list(case = "C8a", patch = list(ledgr_availability_cash_tolerance = function(original) Inf)),
  C8b_suppress_exception = list(case = "C8b", patch = list(ledgr_fold_stage_commit = function(original) function(...) {
    tryCatch(original(...), ledgr_affordability_reconciliation_failed = function(e) list(continue = TRUE))
  })),
  C9_drop_comp_in_unpack = list(case = "C9", patch = list(ledgr_compiled_spot_fifo_unpack_lots = function(original) function(...) {
    state <- original(...)
    state$realized_comp <- 0
    state
  })),
  C10_skip_valuation_on_empty = list(case = "C10", patch = list(ledgr_fold_stage_observe_settle = function(original) function(fold_state, services, ...) {
    advance <- services$valuation_state$advance
    append <- services$equity_fact_accumulator$append
    empty <- FALSE
    services$valuation_state$advance <- function(pulse_idx, axis, ...) {
      empty <<- length(axis) == 0L
      advance(pulse_idx, axis, ...)
    }
    services$equity_fact_accumulator$append <- function(value) if (!empty) append(value)
    original(fold_state, services, ...)
  })),
  C11_affordability_order = list(case = "C11", patch = list(ledgr_fold_build_availability_pulse_plan = function(original) function(...) {
    plan <- original(...)
    key <- vapply(plan$fills, function(e) paste(e$fill$side != "SELL", e$instrument_id), "")
    plan$fills <- plan$fills[order(key, method = "radix")]
    plan
  })),
  C12_fill_before_settlement = list(case = "C12", patch = list(ledgr_fold_stage_observe_settle = function(original) function(fold_state, ...) {
    ws_gut$cash <- fold_state$cash
    original(fold_state, ...)
  }, ledgr_fold_build_availability_pulse_plan = function(original) function(..., cash) original(..., cash = ws_gut$cash))),
  C13a_swallow = list(case = "C13a", patch = ws_swallow("lot")),
  C13c_swallow_append = list(case = "C13c", patch = ws_swallow("write_fill_events")),
  C13c_swallow_fact = list(case = "C13c", patch = ws_swallow("record_accounting_fact")),
  C13c_swallow_flush = list(case = "C13c", patch = ws_swallow("flush_pulse_events")),
  C14a_book_by_reference = list(case = "C14a", patch = list(ledgr_lot_apply_fill = function(original) function(state, instrument_id, ...) {
    out <- original(state, instrument_id, ...)
    i <- match(instrument_id, state$instrument_ids)
    new <- out$state$lot_qty[[i]]
    if (length(new) > 0L && length(state$lot_qty[[i]]) == length(new)) collapse::setv(state$lot_qty[[i]], seq_along(new), new, vind1 = TRUE)
    out
  })),
  C14b_write_retained_view = list(case = "C14b", patch = list(ledgr_call_strategy_fn = function(original) function(fn, ctx, ...) {
    if (!is.null(ws_gut$prev)) collapse::setv(ws_gut$prev, 1L, -999, vind1 = TRUE)
    ws_gut$prev <- ctx$vec$position
    original(fn, ctx, ...)
  })),
  C14c_reuse_staging = list(case = "C14c", patch = list(ledgr_fill_event_payload = function(original) function(...) {
    value <- original(...)
    if (is.null(ws_gut$first)) ws_gut$first <- value else collapse::setv(ws_gut$first$row$qty, 1L, value$row$qty, vind1 = TRUE)
    value
  })),
  C15_wrong_context_pos = list(case = "C15", patch = list(ledgr_fold_stage_observe_settle = function(original) function(...) {
    obs <- original(...)
    if (ws_ns("ledgr_is_fold_stop_result")(obs)) return(obs)
    obs$context_position_idx <- rev(obs$context_position_idx)
    obs$positions_snapshot[] <- rev(unname(obs$positions_snapshot))
    obs
  })),
  C16_force_fold_equity = list(case = "C16", patch = list(ledgr_run_finalize = function(original) function(con, output_handler, run, ...) {
    run$availability_active <- TRUE
    original(con, output_handler, run, ...)
  })),
  C17_drop_continuation = list(case = "C17", patch = list(ledgr_walk_forward_continue_windows = function(original) function(fold_windows, ...) fold_windows)),
  C18_drop_split_tail = list(case = "C18", patch = list(ledgr_columnar_diagnostic_writer = function(original) function(run_id, output_handler, chunk_rows) {
    writer <- original(run_id, output_handler, chunk_rows)
    append <- writer$append_block
    writer$append_block <- function(fields) append(lapply(fields, function(x) x[seq_len(min(length(x), chunk_rows))]))
    writer
  })),
  C18_retain_staging = list(case = "C18", patch = list(ledgr_fold_flush_pulse_block = function(original) function(fold_state, ...) {
    kept <- fold_state$pending_segments
    original(fold_state, ...)
    fold_state$pending_segments <- kept[seq_len(min(1L, length(kept)))]
    invisible(NULL)
  })),
  C18_drain_unused_equity = list(case = "C18", patch = list(ledgr_fold_equity_fact_accumulator = function(original) function(capacity) {
    acc <- original(capacity)
    collect <- acc$collect
    acc$collect <- function() {
      used <- collect()
      unused <- list(ts_utc = 0, cash = 0, positions_value = 0, realized_pnl = 0, cost_basis = 0)
      c(used, rep(list(unused), capacity - length(used)))
    }
    acc
  }))
)

if (sys.nframe() == 0L) {
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
  arg <- function(name, default) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), c(commandArgs(TRUE), paste0("--", name, "=", default)), value = TRUE)[[1L]])
  out <- arg("out", file.path(tempdir(), "ws4a_guts"))
  names <- strsplit(arg("guts", paste(names(ws4a_guts), collapse = ",")), ",", fixed = TRUE)[[1L]]
  rows <- lapply(names, function(g) {
    log <- system2("Rscript", c(file.path(here, "check.R"), paste0("--gut=", g), paste0("--out=", file.path(out, g))), stdout = TRUE, stderr = TRUE)
    status <- attr(log, "status") %||% 0L
    cat(sprintf("%-32s %-5s %s\n", g, ws4a_guts[[g]]$case, if (status == 1L) "FAIL (expected)" else "NOT CAUGHT"))
    first <- paste(trimws(grep("^  ", log, value = TRUE)[1:3]), collapse = " | ")
    data.frame(gut = g, case = ws4a_guts[[g]]$case, check_exit = status, outcome = if (status == 1L) "FAIL" else "PASS", first_difference = first)
  })
  res <- do.call(rbind, rows)
  utils::write.csv(res, file.path(here, "records", "gut_results.csv"), row.names = FALSE)
  quit(status = if (all(res$outcome == "FAIL")) 0L else 1L)
}
