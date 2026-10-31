# WS4a guts: one product regression per design-note Section 4 gut, applied as
# an in-memory namespace patch (check.R --gut=<name>) in a fresh process.
# Every gut must make check.R fail for its case, with its `expect` evidence in
# the log where given. Run as a script, it runs each gut and the invalid-ref
# control; a full run writes records/gut_results.csv and records/mutations.csv.
#
# Usage: Rscript guts.R [--out=<scratch dir>] [--guts=<name,name>] [--base=<ref>]

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
# LDG-3165: P1 returns the observation and the execution packet; P3 takes both.
ws_skip_gut <- function(stage) {
  out <- list(ledgr_fold_stage_observe_settle = function(original) function(fold_state, services, ...) {
    ws_gut$services <- services
    ws_gut$observed <- original(fold_state, services, ...)
  })
  if (stage == "plan") out$ledgr_fold_scheduled_skip_plan <- function(original) function(fold_state, decision) {
    o <- ws_gut$observed
    ws_ns("ledgr_fold_stage_plan")(fold_state, ws_gut$services, o$observation, decision, o$execution, FALSE, NULL)
    original(fold_state, decision)
  } else out$ledgr_fold_scheduled_skip_decision <- function(original) function(fold_state, services, observation) {
    ws_ns("ledgr_fold_stage_decide")(fold_state, services, observation, FALSE, NULL)
    original(fold_state, services, observation)
  }
  out
}
# Reverses the live lots of each book position in `pos` (LIFO through FIFO).
ws_flip <- function(book, pos) {
  live <- ws_ns("ledgr_lot_book_live")(book, pos)
  mirror <- live$slot[stats::ave(seq_along(live$slot), live$pos, FUN = rev)]
  book$lot_qty[live$slot] <- book$lot_qty[mirror]
  book$lot_price[live$slot] <- book$lot_price[mirror]
  book
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
  C3_tolerance_x10 = list(case = "C3", expect = "C3/(book_|run[.])", patch = list(ledgr_lot_dust_tolerance_rows = function(original) function(...) 10 * original(...))),
  C4_lifo = list(case = "C4", patch = list(ledgr_lot_fill = function(original) function(book, pos, side, ...) {
    closing <- pos[book$net_by_inst[pos] * side < 0]
    out <- original(ws_flip(book, closing), pos, side, ...)
    out$book <- ws_flip(out$book, closing)
    out
  })),
  C5a_reorder_carried_openings = list(case = "C5a", patch = list(ledgr_walk_forward_carried_opening = function(original) function(...) {
    opening <- original(...)
    if (!is.null(opening$carried$lots)) opening$carried$lots <- lapply(opening$carried$lots, rev)
    opening
  })),
  C5b_kahan_on_openings = list(case = "C5b", patch = list(ledgr_lot_opening = function(original) function(...) {
    out <- original(...)
    step <- ws_ns("ledgr_lot_add_realized")(out$book$realized_pnl, out$book$realized_comp, 0)
    out$book$realized_pnl <- step[[1L]]
    out$book$realized_comp <- step[[2L]]
    out
  })),
  C6_leave_one_live_lot = list(case = "C6", expect = "ledgr_lot_state_invariant.*Disposition left live lots", patch = list(ledgr_lot_disposition = function(original) function(book, pos, side, qty, ...) {
    original(book, pos, side, qty / 2, ...)
  })),
  C7_plan_on_skip = list(case = "C7", patch = ws_skip_gut("plan")),
  C7_strategy_on_skip = list(case = "C7", patch = ws_skip_gut("decision")),
  C8a_suppress_stop = list(case = "C8a", patch = list(ledgr_availability_cash_tolerance = function(original) Inf)),
  C8b_suppress_exception = list(case = "C8b", patch = list(ledgr_fold_stage_commit = function(original) function(...) {
    tryCatch(original(...), ledgr_affordability_reconciliation_failed = function(e) list(continue = TRUE))
  })),
  C9_drop_comp_in_unpack = list(case = "C9", patch = list(ledgr_carrier_compiled_unpack = function(original) function(...) {
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
  C14a_book_by_reference = list(case = "C14a", patch = list(ledgr_lot_fill = function(original) function(book, ...) {
    out <- original(book, ...)
    new <- out$book$lot_qty
    if (length(new) > 0L && length(book$lot_qty) == length(new)) collapse::setv(book$lot_qty, seq_along(new), new, vind1 = TRUE)
    out
  })),
  # Invisible to the base-shaped view: names a retained typed column by reference.
  C14a_rename_by_reference = list(case = "C14a", expect = "retained native book", patch = list(ledgr_lot_fill = function(original) function(book, ...) {
    out <- original(book, ...)
    collapse::setattrib(book$net_by_inst, list(names = rep("renamed", length(book$net_by_inst))))
    out
  })),
  C14b_write_retained_view = list(case = "C14b", patch = list(ledgr_call_strategy_fn = function(original) function(fn, ctx, ...) {
    if (!is.null(ws_gut$prev)) collapse::setv(ws_gut$prev, 1L, -999, vind1 = TRUE)
    ws_gut$prev <- ctx$vec$position
    original(fn, ctx, ...)
  })),
  # On the base an OPEN leg's qty is the event row's qty vector (as.numeric does
  # not copy), so a by-reference qty write reaches both witnesses; the leg-only
  # gut writes the leg's own fee (a fresh per-leg vector) and must leave the
  # event witness equal.
  C14c_reuse_staging = list(case = "C14c", expect = "changed: event_block", patch = list(ledgr_fill_event_payload = function(original) function(...) {
    value <- original(...)
    if (is.null(ws_gut$first)) ws_gut$first <- value else collapse::setv(ws_gut$first$row$qty, 1L, value$row$qty, vind1 = TRUE)
    value
  })),
  C14c_reuse_leg_staging = list(case = "C14c", expect = "changed: leg_block[)]", patch = list(ledgr_output_sink_memory = function(original) {
    ws4a_c14c_legs(function(legs) if (is.null(ws_gut$legs)) ws_gut$legs <- legs else
      collapse::setv(ws_gut$legs[[1L]]$fee, 1L, legs[[1L]]$fee + 1, vind1 = TRUE))(original)
  })),
  # M8 through the typed path (LDG-3165): the decision packet's bridge is
  # reversed; its context columns stay as P1 built them.
  C15_wrong_context_pos = list(case = "C15", patch = list(ledgr_fold_stage_observe_settle = function(original) function(...) {
    obs <- original(...)
    if (ws_ns("ledgr_is_fold_stop_result")(obs)) return(obs)
    obs$observation$packet$context_pos <- rev(obs$observation$packet$context_pos)
    obs
  })),
  C16_force_fold_equity = list(case = "C16", patch = list(ledgr_run_finalize = function(original) function(con, output_handler, run, ...) {
    run$availability_active <- TRUE
    original(con, output_handler, run, ...)
  })),
  C17_drop_continuation = list(case = "C17", patch = list(ledgr_walk_forward_continue_windows = function(original) function(fold_windows, ...) fold_windows)),
  C18_drop_split_tail = list(case = "C18", expect = "C18/(run|sweep)[.]", patch = list(ledgr_columnar_diagnostic_writer = function(original) function(run_id, output_handler, chunk_rows) {
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
  })),
  # Section 6 mutations without a Section 4 gut that already implements them.
  M2_reorder_pulse_fills = list(case = "C1", patch = list(ledgr_fold_stage_apply = function(original) function(fold_state, services, observation, plan, ...) {
    if (length(plan$accounting_events$fills) > 1L) plan$accounting_events$fills <- rev(plan$accounting_events$fills)
    original(fold_state, services, observation, plan, ...)
  })),
  M3_drop_lot_fee = list(case = "C4", patch = list(ledgr_lot_fill = function(original) function(book, pos, side, qty, price, fee = 0, ...) {
    original(book, pos, side, qty, price, fee = 0 * fee, ...)
  })),
  # The position read after a fill becomes the position before plus the signed quantity.
  M5_positions_plus_delta = list(case = "C5a", patch = list(ledgr_lot_fill = function(original) function(book, pos, side, qty, ...) {
    out <- original(book, pos, side, qty, ...)
    out$book$net_by_inst[pos] <- book$net_by_inst[pos] + side * qty
    out
  })),
  M7_drop_partial_remainder = list(case = "C4", patch = list(ledgr_lot_dust_tolerance_rows = function(original) function(...) {
    v <- list(...) # in-loop rows (qty, take, remaining lot qty, remaining fill): a partial close drops the lot's remainder
    tol <- original(...)
    if (length(v) == 4L) tol[v[[2L]] > 0 & v[[3L]] > 0 & v[[4L]] == 0] <- Inf
    tol
  })),
  M11_uncompensated_totals = list(case = "C5b", patch = list(ledgr_lot_add_realized = function(original) function(realized, comp, delta) {
    c(realized + delta, comp)
  })),
  # M11: the total basis as one cumsum() over the rows' basis changes instead of the ordered scalar scan.
  M11_cumsum_total_basis = list(case = "C3", expect = "C3/book_totals", patch = list(ledgr_lot_apply = function(original) function(book, input) {
    out <- original(book, input)
    d <- out$book$cost_basis_by_inst[input$pos] - book$cost_basis_by_inst[input$pos]
    out$applied$event_cost_basis <- cumsum(c(book$total_cost_basis, d))[-1L]
    if (length(d)) out$book$total_cost_basis <- out$applied$event_cost_basis[[length(d)]]
    out
  }))
)

# Section 6 mutation register: each M-id runs as the named gut on its case.
ws4a_mutations <- data.frame(id = paste0("M", 1:12), description = c("LIFO consumption", "reordered fills within a pulse",
  "dropped fee", "affordability-order publication", "positions as positions plus delta", "Kahan step on openings",
  "skip a partial close's remainder", "wrong context_pos", "notional fee from the rounded price", "drop the notional step",
  "cumsum totals", "drop realized_comp in unpack"), gut = c("C4_lifo", "M2_reorder_pulse_fills", "M3_drop_lot_fee",
  "C11_affordability_order", "M5_positions_plus_delta", "C5b_kahan_on_openings", "M7_drop_partial_remainder",
  "C15_wrong_context_pos", "C2_notional_from_rounded", "C1_drop_notional", "M11_cumsum_total_basis", "C9_drop_comp_in_unpack"))
stopifnot(ws4a_mutations$gut %in% names(ws4a_guts), !anyDuplicated(ws4a_mutations$gut))

if (sys.nframe() == 0L) {
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
  arg <- function(name, default) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), c(commandArgs(TRUE), paste0("--", name, "=", default)), value = TRUE)[[1L]])
  out <- arg("out", file.path(tempdir(), "ws4a_guts"))
  names <- strsplit(arg("guts", paste(names(ws4a_guts), collapse = ",")), ",", fixed = TRUE)[[1L]]
  check <- function(args) {
    log <- suppressWarnings(system2("Rscript", c(file.path(here, "check.R"), args), stdout = TRUE, stderr = TRUE))
    list(log = log, status = attr(log, "status") %||% 0L, evidence = function(re) grepl(re, paste(log, collapse = "\n")))
  }
  rows <- lapply(names, function(g) {
    # --base reaches check.R's product guard, so a candidate run uses --base=HEAD.
    r <- check(c(paste0("--gut=", g), paste0("--out=", file.path(out, g)), paste0("--base=", arg("base", "953338df"))))
    ok <- r$status == 1L && r$evidence(ws4a_guts[[g]]$expect %||% "")
    cat(sprintf("%-32s %-5s %s\n", g, ws4a_guts[[g]]$case, if (ok) "FAIL (expected)" else "NOT CAUGHT"))
    first <- paste(trimws(grep("^  ", r$log, value = TRUE)[1:3]), collapse = " | ")
    data.frame(gut = g, case = ws4a_guts[[g]]$case, check_exit = r$status, outcome = if (r$status == 1L) "FAIL" else "PASS",
      expected_evidence = ok, first_difference = first)
  })
  # Control: an unresolvable --base is a refusal (exit 2), not a case difference (exit 1).
  r <- check(c("--cases=C5b", "--base=LDG3163_NONEXISTENT_REF", paste0("--out=", file.path(out, "invalid_base_ref"))))
  cat(sprintf("%-32s %-5s %s\n", "control_invalid_base_ref", "C5b", if (r$status == 2L) "REFUSED (expected)" else "NOT REFUSED"))
  res <- rbind(do.call(rbind, rows), data.frame(gut = "control_invalid_base_ref", case = "C5b", check_exit = r$status,
    outcome = if (r$status == 2L) "REFUSED" else "NOT REFUSED", expected_evidence = r$status == 2L, first_difference = r$log[[1L]]))
  mutations <- merge(ws4a_mutations, res[c("gut", "case", "check_exit", "outcome")], by = "gut", sort = FALSE)
  names(mutations)[names(mutations) == "outcome"] <- "base_outcome"
  if (!any(grepl("^--guts=", commandArgs(TRUE)))) { # records are written only by a full run
    utils::write.csv(res, file.path(here, "records", "gut_results.csv"), row.names = FALSE)
    utils::write.csv(mutations[order(as.integer(sub("M", "", mutations$id))), c("id", "description", "gut", "case", "check_exit", "base_outcome")],
      file.path(here, "records", "mutations.csv"), row.names = FALSE)
  }
  quit(status = if (all(res$expected_evidence)) 0L else 1L)
}
