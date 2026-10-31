# WS4a case definitions (design note Section 4). Each case states what it
# freezes and asserts its own precondition with ws_need(), on every rerun.

ws_cost_fx <- function(id, avail, aaa_open = c(100, 101.37, 103.11, 99.73, 102.29, 104.53, 101.07)) {
  bbb <- 50 + 0:6 / 3
  ws_fixture(id, list(AAA = aaa_open + 0.5, BBB = bbb), opens = list(AAA = aaa_open, BBB = bbb), avail = avail)
}
ws_days <- function(...) stats::setNames(list(...), ws_iso(seq_along(list(...))))
ws_c1_plan <- ws_days(list(AAA = 3, BBB = 2), list(AAA = 5), list(AAA = 1, BBB = 0), list(AAA = -2), list(AAA = 0))

# C1: chained spread 7 bps, fixed 1.25 and notional 3 bps on both producers.
# Availability refuses short exposure, so its sweep closes to zero on day 4
# where the dense run reverses; the fee split is a dense-path witness.
ws_case("C1", "3166", function() {
  dense <- ws_cost_fx("c1_dense", FALSE)
  avail <- ws_cost_fx("c1_avail", TRUE)
  avail_plan <- utils::modifyList(ws_c1_plan, ws_days(NULL, NULL, NULL, list(AAA = 0))[4L])
  out <- c(ws_durable(dense, ws_exp(dense), "c1-dense", ws_c1_plan),
    ws_memory(ws_exp(avail, universe = c("AAA", "BBB")), avail_plan))
  legs <- table(out[["run.fills"]]$event_seq)
  ws_need(any(legs == 2L), "a reversal fill with CLOSE and OPEN legs")
  ws_need(c("BUY", "SELL") %in% out[["run.fills"]]$side, "BUY and SELL fills on the durable run")
  ws_need(c("BUY", "SELL") %in% out[["sweep.memory_events"]]$side, "BUY and SELL fills on the sweep")
  list(tables = out, facts = list(reversal_fills = sum(legs == 2L)))
})

# C2: spread-adjusted prices with more than 8 decimals, near-half ties at
# digit 9 on both sides; the notional fee uses the unrounded price.
ws_case("C2", "3166", function() {
  m <- c(BUY = 1 + 7 / 20000, SELL = 1 - 7 / 20000)
  x <- c(BUY = 101.234567885, SELL = 99.876543215)
  open <- c(100, x[["BUY"]] / m[["BUY"]], 101, x[["SELL"]] / m[["SELL"]], 100)
  fx <- ws_fixture("c2", list(AAA = open + 0.25), opens = list(AAA = open), avail = FALSE)
  plan <- ws_days(list(AAA = 7), NULL, list(AAA = 0))
  out <- ws_durable(fx, ws_exp(fx), "c2", plan)
  raw <- c(open[[2L]] * m[["BUY"]], open[[4L]] * m[["SELL"]])
  ws_need(abs(raw * 1e8 - floor(raw * 1e8) - 0.5) < 1e-4, "near-half tie at digit 9 on both sides")
  ws_need(raw != round(raw, 8), "unrounded and rounded prices differ")
  out <- out[c("run.ledger_events", "run.fills", "run.conditions")]
  list(tables = out, facts = list(unrounded = raw, rounded = round(raw, 8)))
})

# C3: fractional fills that reach the dust tolerance in fold and replay, and
# one residual lot kept just above it (inside ten tolerances).
ws_case("C3", "3164", function() {
  fx <- ws_fixture("c3", list(AAA = 10 + 0:5 / 4, BBB = 20 + 0:5 / 3), avail = FALSE)
  plan <- ws_days(list(AAA = 0.1, BBB = 1), list(AAA = 0.3, BBB = 1e-15), list(AAA = 0.6), list(AAA = 0))
  seen <- data.frame(phase = character(), kind = character())
  phase <- "fold"
  patches <- list(ledgr_run_finalize = function(original) function(...) {
    phase <<- "replay"
    on.exit(phase <<- "fold")
    original(...)
  }, ledgr_lot_dust_tolerance_rows = function(original) function(...) {
    tol <- original(...) # one evaluation per row; arguments 3:4 are the remaining lot and fill
    r <- if (...length() >= 4L) abs(cbind(..3, ..4)) else matrix(NA_real_, 0L, 2L)
    kind <- ifelse(rowSums(r > 0 & r <= tol) > 0, "snap", ifelse(rowSums(r > tol & r <= 10 * tol) > 0, "near", ""))
    for (k in kind[nzchar(kind)]) seen[nrow(seen) + 1L, ] <<- c(phase, k)
    tol
  })
  out <- ws_patches(patches, ws_durable(fx, ws_exp(fx, ledgr_cost_fixed_fee(0.25)), "c3", plan))
  hits <- table(paste(seen$phase, seen$kind))
  out <- c(out[c("run.ledger_events", "run.equity_curve")], ws_replay_book(fx$db, "c3", c("AAA", "BBB")))
  ws_need(c("fold snap", "replay snap", "fold near", "replay near") %in% names(hits), "dust snaps and a near-dust lot in fold and replay", out)
  list(tables = out, facts = as.list(unclass(hits)))
})

# C4: dense long -> short -> long with chained costs; every partial close
# meets at least two live lots of unequal basis.
ws_case("C4", "3164", function() {
  open <- c(100, 101.5, 103.25, 99.75, 98.5, 97.25, 99.5, 102.75, 104)
  fx <- ws_fixture("c4", list(AAA = open + 0.5), opens = list(AAA = open), avail = FALSE)
  plan <- ws_days(list(AAA = 2), list(AAA = 4), list(AAA = 3), list(AAA = -2), list(AAA = -4), list(AAA = -3),
    list(AAA = 2), list(AAA = 0))
  partial <- character()
  planned <- list()
  hooks <- list(ledgr_lot_fill = function(a, v) {
    net <- a$book$net_by_inst[a$pos]
    for (k in which(net * a$side < 0 & a$qty < abs(net))) {
      lots <- ledgr_lot_book_live(a$book, a$pos[[k]])
      partial <<- c(partial, sprintf("%s:%d:%d", if (a$side[[k]] > 0) "BUY" else "SELL", length(lots$qty), length(unique(lots$price))))
    }
  }, ledgr_fold_stage_apply = function(a, v) { # LDG-3166: the typed fill rows
    f <- a$plan$batch$fill
    if (length(f$k)) planned[[length(planned) + 1L]] <<- data.frame(pulse = a$observation$pulse_idx,
      instrument_id = unname(a$services$instrument_ids[f$pos]), planned = f$planned_position_after, actual = a$fold_state$positions[f$pos])
  })
  out <- ws_trace(hooks, ws_durable(fx, ws_exp(fx), "c4", plan))
  parts <- do.call(rbind, strsplit(unique(partial), ":"))
  ws_need(c("BUY", "SELL") %in% parts[, 1L] & all(as.integer(parts[, 2:3]) >= 2L), "partial closes on both sides with two unequal live lots")
  out <- c(out[c("run.ledger_events", "run.fills", "run.trades", "run.equity_curve")],
    list(positions = ws_frame(do.call(rbind, planned), "positions", c("pulse", "instrument_id"))))
  list(tables = out, facts = list(partial_closes = partial))
})

# Walk-forward chain shared by C5a and C17: three contiguous test windows,
# fractional lots at fractional prices, fees, decisions on window ends.
ws_wf_plan <- stats::setNames(list(list(AAA = 0.35), list(AAA = 0.95), list(AAA = 1.4), list(AAA = 1.85), list(AAA = 0.6)),
  ws_iso(c(5, 6, 7, 8, 10)))
ws_wf <- function(id, plan = ws_wf_plan) {
  fx <- ws_fixture(id, list(AAA = 100 + c(0, 1.37, 2.11, 0.73, 3.29, 1.53, 2.07, 4.41, 3.19, 2.6, 1.9, 2.2), BBB = 50 + (1:12) / 7))
  exp <- ws_exp(fx, ledgr_cost_chain(ledgr_cost_fixed_fee(0.5), ledgr_cost_notional_bps_fee(3)),
    opening = ledgr_opening(cash = 1000), universe = c("AAA", "BBB"))
  iso <- function(k) format(ws_day(k), "%Y-%m-%dT%H:%M:%SZ")
  folds <- ledgr:::ledgr_fold_list(lapply(1:3, function(f) {
    test <- list(c(5, 6), c(7, 8), c(9, 12))[[f]]
    ledgr_fold(iso(1), iso(test[[1]] - 1), iso(test[[1]]), iso(test[[2]]), fold_seq = f)
  }), constructor = list(type_id = "explicit"))
  sink <- a0_new_sink()
  wf <- a0_capture_warnings(ledgr_walk_forward(exp, grid = ws_grid(plan), folds = folds,
    selection_rule = ledgr_rule_argmax("annualized_return"), seed = 1L), "<walk_forward>", sink)
  ids <- vapply(wf$test_runs, function(bt) bt$run_id, character(1))
  lapply(wf$test_runs, close)
  list(fx = fx, exp = exp, ids = ids, sink = sink, status = wf$status)
}

# C5a: carried openings across two boundaries, then partly consumed.
ws_case("C5a", "3164", function() {
  wf <- ws_wf("c5a")
  out <- list()
  lots <- integer()
  for (k in seq_along(wf$ids)) {
    ledger <- ws_ledger(wf$fx$db, wf$ids[[k]])
    opening <- ledger[grepl("opening_position", ledger$meta_json, fixed = TRUE), c("event_seq", "instrument_id", "qty", "price", "meta_json")]
    out[[sprintf("w%d.openings", k)]] <- ws_frame(opening, "openings", "event_seq")
    book <- ws_book(ledgr_lot_book_from_events(ledger, c("AAA", "BBB")), c("AAA", "BBB"))
    out <- c(out, ws_prefix(c(book, a0_store_tables(wf$fx$db, wf$ids[[k]])["equity_curve"]), sprintf("w%d", k)))
    lots <- c(lots, sum(opening$instrument_id == "AAA"), sum(book$book_lots$instrument_id == "AAA"))
  }
  ws_need(identical(wf$status, "DONE") && length(wf$ids) == 3L, "three carried test windows")
  ws_need(lots[3] >= 2L && lots[5] > lots[3] && lots[6] >= 1L && lots[6] < lots[5], "lots carried twice, then partly consumed")
  list(tables = out, facts = list(aaa_lots_open_end = lots))
})

# C5b: successive openings on a book with nonzero realized_comp: no Kahan step.
ws_case("C5b", "3164", function() {
  ids <- c("AAA", "BBB", "CCC")
  st <- ledgr:::ledgr_lot_book(3L)
  fills <- list(list("BUY", 2.97, 997.955, 0.32), list("BUY", 0.67, 994.875, 1.605), list("SELL", 1.35, 1009.441, 0.415),
    list("BUY", 1.65, 993.435, 0.54), list("BUY", 2.43, 991.926, 0.962))
  for (f in fills) st <- ledgr:::ledgr_lot_fill(st, 1L, ledgr_lot_side(f[[1]]), f[[2]], f[[3]], fee = f[[4]])$book
  comp_before <- st$realized_comp
  ws_need(comp_before != 0, "nonzero realized_comp before the openings", ws_book(st, ids))
  ops <- list(list("BBB", 2.5, -3.25), list("BBB", 1.25, 7.5), list("CCC", -1.75, 4.5), list("AAA", 0.4, 11.03))
  kahan <- ws_counter(ws4a_seams[["kahan"]])
  st <- ws_trace(kahan$hooks, {
    for (o in ops) st <- ledgr:::ledgr_lot_opening(st, match(o[[1]], ids), o[[2]], o[[3]])$book
    st
  })
  list(tables = ws_book(st, ids), facts = list(kahan_calls = kahan$get()[[1]], comp_before = ws_hex(comp_before),
    comp_after = ws_hex(st$realized_comp)))
})

# Dispositions shared by C6, C12 and C14b: AAA (three fractional lots) is
# acquired on day 4 at its last permissible mark; BBB is written off at zero
# on day 5; the day-4 CCC buy needs the acquisition cash.
ws_disp <- function(id, state = FALSE) {
  closes <- list(AAA = c(100, 101.5, 102.25, 90, NA, NA), BBB = c(50, NA, NA, NA, NA, NA), CCC = rep(50, 6), CLK = rep(10, 6))
  life <- ledgr_facts_lifetime(data.frame(instrument_id = c("AAA", "BBB"), effective_from = ws_day(4:5),
    knowledge_time = ws_day(4:5) - 1, assertion = "known_inactive", terminal_event = c("acquired", "bankruptcy")))
  deal <- ledgr_facts_equity_corporate_actions(data.frame(fact_id = "ws4a-acq", subtype = "cash_acquisition",
    parent_instrument_id = "AAA", entitlement_time = ws_day(4), effective_time = ws_day(4), knowledge_time = ws_day(1),
    complete = TRUE, provenance_tier = "snapshot_bound", gross_cash_per_parent_unit = 120, gross_cash_validated = TRUE,
    recipient_identity_validated = FALSE, recipient_quantity_validated = FALSE))
  fx <- ws_fixture(id, closes, facts = list(life, deal))
  exp <- ws_exp(fx, ledgr_cost_zero(), valuation_policy = ledgr_valuation_stale(1),
    opening = ledgr_opening(cash = 100, positions = c(AAA = 1.25, BBB = 4.5), cost_basis = c(AAA = 99.5, BBB = 100)))
  plan <- ws_days(list(AAA = 1.6), list(AAA = 2), NULL, list(CCC = 3))
  plan$state <- state
  list(fx = fx, exp = exp, plan = plan)
}

# C6: multi-lot fractional and zero-price dispositions; replay refuses a
# wrong realized_model_pnl witness.
ws_case("C6", "3164", function() {
  d <- ws_disp("c6")
  lots <- integer()
  hooks <- list(ledgr_disposition_post = function(a, v) {
    lots <<- c(lots, stats::setNames(ledgr_lot_book_live_count(a$state_value$lot_state, match(a$ids, a$instrument_ids)), a$ids))
  })
  out <- ws_trace(hooks, ws_durable(d$fx, d$exp, "c6", d$plan))
  ledger <- ws_ledger(d$fx$db, "c6")
  disp <- which(ledger$event_type == "DISPOSITION")
  ws_need(any(lots >= 2L) && any(ledger$price[disp] == 0 & ledger$fee[disp] == 0), "multi-lot and zero-price dispositions",
    out[c("run.runs", "run.conditions", "run.run_diagnostics")])
  bad <- ledger
  i <- disp[ledger$price[disp] > 0][[1L]]
  meta <- ledgr_lot_parse_meta(bad$meta_json[[i]])
  meta$realized_model_pnl <- meta$realized_model_pnl + 1
  bad$meta_json[[i]] <- canonical_json(meta)
  refusal <- tryCatch(ledgr_lot_book_from_events(bad, c("AAA", "BBB", "CCC", "CLK")), error = function(e) e)
  ws_need(inherits(refusal, "error"), "the wrong witness is refused")
  out <- c(out["run.ledger_events"], ws_replay_book(d$fx$db, "c6", c("AAA", "BBB", "CCC", "CLK")),
    list(refusal = ws_frame(data.frame(class = paste(class(refusal), collapse = "/"), message = conditionMessage(refusal)), "refusal", "class")))
  list(tables = out, facts = list(lots_at_disposition = lots))
})

# C7: scheduled skips with stale marks; fills on due pulses; the strategy and
# the planner run on due pulses only.
ws_case("C7", "3165", function() {
  fx <- ws_fixture("c7", list(AAA = 100 + 1:8, BBB = c(50, 51, NA, NA, 54, NA, 56, 57)))
  due <- ws_iso(c(1, 3, 5, 7))
  strategy <- ledgr_strategy_schedule(ws_plan_strategy, ledgr_schedule_dates(as.Date(due)))
  exp <- ledgr_experiment(fx$snap, strategy, cost_model = ledgr_cost_fixed_fee(0.5), valuation_policy = ledgr_valuation_stale(2),
    opening = ledgr_opening(cash = 1000, positions = c(BBB = 2), cost_basis = c(BBB = 50)))
  plan <- stats::setNames(list(list(AAA = 1), list(AAA = 3), list(BBB = 1), list(AAA = 0)), due)
  calls <- ws_counter(c("ledgr_call_strategy_fn", ws4a_seams[["planner_return"]]))
  out <- ws_trace(calls$hooks, ws_durable(fx, exp, "c7", plan))
  n <- calls$get()
  diag <- out[["run.run_diagnostics"]]
  skip_ts <- unique(diag$ts_utc[diag$reason_code %in% "scheduled_skip"])
  ws_need(length(skip_ts) == 4L && any(diag$outcome == "marked" & diag$ts_utc %in% skip_ts & diag$mark_source == "stale_close"),
    "skip pulses with stale-mark rows")
  ws_need(nrow(out[["run.fills"]]) > 0L && all(substr(out[["run.fills"]]$ts_utc, 1L, 10L) %in% ws_iso(c(2, 4, 6, 8))), "fills from due pulses")
  out <- c(out[c("run.run_diagnostics", "run.fills", "run.equity_curve")], ws_memory(exp, plan)["sweep.memory_diagnostics"])
  list(tables = out, facts = list(strategy_calls = n[[1]], planner_calls = n[[2]]))
})

# C8a/C8b: small-cash availability fixture with one perturbed plan.
ws_small_cash <- function(id) {
  fx <- ws_fixture(id, list(AAA = c(30, 30.5, 31, 31.5, 32)))
  list(fx = fx, exp = ws_exp(fx, ledgr_cost_zero(), opening = ledgr_opening(cash = 100)), plan = ws_days(NULL, list(AAA = 3)))
}
ws_perturb <- function(seam, injected) stats::setNames(list(function(original) function(...) {
  value <- original(...)
  plan <- if (is.null(value$batch)) value else value$batch # LDG-3166: the typed plan
  if (injected$n == 0L && length(plan$fill$k) > 0L) {
    injected$n <- 1L
    injected$recorded <- ws_args(original, ...)$cash %||% NA_real_
    plan$expected_final_cash <- plan$expected_final_cash + 1
    if (is.null(value$batch)) value <- plan else value$batch <- plan
  }
  value
}), seam)
ws_perturb_case <- function(id, seam) {
  s <- ws_small_cash(id)
  run_hit <- new.env()
  run_hit$n <- 0L
  out <- ws_patches(ws_perturb(seam, run_hit), ws_durable(s$fx, s$exp, id, s$plan))
  sweep_hit <- new.env()
  sweep_hit$n <- 0L
  out <- c(out, ws_patches(ws_perturb(seam, sweep_hit), ws_memory(s$exp, s$plan)))
  ws_need(run_hit$n == 1L && sweep_hit$n == 1L, "the injection ran once per path")
  list(out = out, run_hit = run_hit)
}
ws_case("C8a", "3166", function() {
  r <- ws_perturb_case("c8a", ws4a_seams[["planner_return"]])
  diag <- r$out[["run.run_diagnostics"]]
  stop_row <- diag[diag$reason_code %in% "affordability_reconciliation_failed", ]
  ws_need(nrow(stop_row) == 1L && r$out[["run.run_completion"]]$intended_terminal_status %in% "INCOMPLETE", "INCOMPLETE stop with its diagnostic")
  detail <- jsonlite::fromJSON(stop_row$detail_json)
  rel <- abs(detail$virtual_final_cash - detail$recorded_final_cash) / abs(detail$recorded_final_cash)
  ws_need(rel > ledgr:::ledgr_availability_cash_tolerance, "mismatch beyond the relative tolerance")
  list(tables = r$out, facts = list(injections = r$run_hit$n, relative_mismatch = rel))
})
ws_case("C8b", "3166", function() {
  r <- ws_perturb_case("c8b", ws4a_seams[["p3_return"]])
  ws_need(r$out[["run.runs"]]$status %in% "FAILED" && nrow(r$out[["run.ledger_events"]]) == 0L, "P5 abort with durable rollback")
  ws_need(r$out[["sweep.sweep"]]$status %in% "FAILED" && nrow(r$out[["sweep.memory_events"]]) == 0L, "no successful memory result")
  list(tables = r$out, facts = list(injections = r$run_hit$n))
})

# C9: compiled sweep with fractional quantities; nonzero realized_comp enters
# at least two pack/unpack cycles.
ws_case("C9", "3164", function() {
  open <- c(997.955, 994.875, 1009.441, 993.435, 991.926, 1001.213, 996.332, 1009.934)
  fx <- ws_fixture("c9", list(AAA = open + 0.5), opens = list(AAA = open), avail = FALSE)
  plan <- ws_days(list(AAA = 2.97), list(AAA = 3.64), list(AAA = 2.29), list(AAA = 3.94), list(AAA = 6.37), list(AAA = 5.66), list(AAA = 8.62))
  comps <- character()
  last <- NULL
  hooks <- stats::setNames(list(function(a, v) {
    comps <<- c(comps, ws_hex(a$state$lot_state$realized_comp))
    last <<- v$lot_state
  }), ws4a_seams[["compiled_batch"]])
  out <- ws_trace(hooks, ws_memory(ws_exp(fx, ledgr_cost_fixed_fee(0.37)), plan, compiled_accounting_model = "spot_fifo"))
  ws_need(sum(comps != "0x0p+0") >= 2L, "nonzero realized_comp entering two compiled batches")
  list(tables = c(out, ws_book(last, "AAA")), facts = list(comp_in = comps))
})

# C10: an empty decision context on days 3-4 (empty membership set) while a
# dividend entitled on day 3 settles there; valuation continues.
ws_case("C10", "3165", function() {
  mem <- data.frame(effective_from = ws_day(c(1, 3, 5)) - 3600, knowledge_time = ws_day(c(1, 3, 5)) - 7200,
    set_id = c("a", "e", "b"), source = "t")
  mem$members <- I(list("AAA", character(0), "AAA"))
  div <- ledgr_facts_equity_corporate_actions(data.frame(fact_id = "ws4a-div", subtype = "ordinary_cash_dividend",
    parent_instrument_id = "AAA", entitlement_time = ws_day(3), effective_time = ws_day(4), knowledge_time = ws_day(1),
    complete = TRUE, provenance_tier = "snapshot_bound", gross_cash_per_parent_unit = 1.25, gross_cash_validated = TRUE,
    recipient_identity_validated = FALSE, recipient_quantity_validated = FALSE))
  fx <- ws_fixture("c10", list(AAA = 100 + 1:6), facts = list(ledgr_facts_membership_snapshots(mem, "U", complete = TRUE), div))
  exp <- ws_exp(fx, ledgr_cost_zero(), universe = ledgr_universe_members("U"),
    opening = ledgr_opening(cash = 1000, positions = c(AAA = 1), cost_basis = c(AAA = 100)))
  ctx <- character()
  hooks <- list(ledgr_fold_stage_observe_settle = function(a, v) ctx <<- c(ctx, paste(ws_context(a, v)$ids, collapse = "+")))
  out <- ws_trace(hooks, ws_durable(fx, exp, "c10", ws_days(NULL, list(AAA = 0), NULL, NULL, list(AAA = 2))))
  ledger <- out[["run.ledger_events"]]
  ws_need(sum(ctx == "") == 2L && nrow(out[["run.equity_curve"]]) == 6L, "valued pulses with an empty context")
  ws_need(any(ledger$event_type == "CASHFLOW" & substr(ledger$ts_utc, 1L, 10L) %in% ws_iso(3:4)), "settlement on an empty-context pulse")
  out <- out[c("run.ledger_events", "run.equity_curve", "run.run_diagnostics", "run.run_completion")]
  list(tables = out, facts = list(context = ctx))
})

# C11: a buy precedes its funding sell in decision order (ZZZ, AAA, MMM),
# which differs from stable-ID order; MMM is rejected for cash.
ws_case("C11", "3166", function() {
  fx <- ws_fixture("c11", list(ZZZ = rep(40, 4), AAA = rep(30, 4), MMM = rep(100, 4)))
  exp <- ws_exp(fx, ledgr_cost_zero(), universe = c("ZZZ", "AAA", "MMM"),
    opening = ledgr_opening(cash = 10, positions = c(AAA = 5), cost_basis = c(AAA = 30)))
  plan <- ws_days(NULL, list(ZZZ = 2, AAA = 0, MMM = 2))
  order <- character()
  hooks <- stats::setNames(list(function(a, v) if (length(v$fill$k)) order <<- unname(a$instrument_ids[v$fill$pos])),
    ws4a_seams[["planner_return"]])
  out <- ws_trace(hooks, c(ws_durable(fx, exp, "c11", plan), ws_memory(exp, plan)))
  ws_need(identical(order, c("ZZZ", "AAA")), "decision order ZZZ, AAA differs from stable-ID order")
  ws_need(any(out[["run.run_diagnostics"]]$reason_code %in% "insufficient_cash"), "an affordability rejection")
  list(tables = out[c("run.ledger_events", "run.run_diagnostics", "sweep.memory_events")], facts = list(fill_order = order))
})

# C12: AAA acquisition cash at the day-4 pulse funds the CCC buy decided there.
ws_case("C12", "3165", function() {
  d <- ws_disp("c12")
  cash <- list()
  patch <- list(ledgr_fold_stage_observe_settle = function(original) function(fold_state, ...) {
    before <- fold_state$cash
    value <- original(fold_state, ...)
    cash[[length(cash) + 1L]] <<- c(before, fold_state$cash)
    value
  })
  out <- ws_patches(patch, ws_durable(d$fx, d$exp, "c12", d$plan))
  ledger <- out[["run.ledger_events"]]
  ws_need(cash[[4]][[1]] < 150 && cash[[4]][[2]] >= 150 && any(ledger$instrument_id == "CCC" & ledger$side %in% "BUY"),
    "settled disposition cash funds the CCC buy")
  list(tables = out[c("run.ledger_events", "run.equity_curve")], facts = list(cash_day4 = cash[[4]]))
})

# C13: two fills in one pulse; a fault is injected after calculation.
ws_two_fills <- function(id) {
  fx <- ws_fixture(id, list(AAA = c(100, 101, 102, 103), BBB = c(50, 51, 52, 53)))
  list(fx = fx, exp = ws_exp(fx, ledgr_cost_fixed_fee(0.5), opening = ledgr_opening(cash = 1000)),
    plan = ws_days(list(AAA = 2, BBB = 3), list(AAA = 1), list(BBB = 4)))
}
ws_fault <- function(what) rlang::abort(paste("ws4a injected failure:", what), class = "ws4a_injected")
ws_assert_abort <- function(out, durable = TRUE) {
  sweep_failed <- out[["sweep.sweep"]]$status %in% "FAILED" && nrow(out[["sweep.memory_events"]]) == 0L
  if (!durable) return(sweep_failed)
  diag <- out[["run.run_diagnostics"]]
  sweep_failed && out[["run.runs"]]$status %in% "FAILED" && nrow(out[["run.ledger_events"]]) == 0L &&
    grepl("ws4a_injected", out[["run.conditions"]]$class) && any(diag$outcome == "error" & diag$stage == "accounting")
}
ws_case("C13a", "3167", function() {
  t <- ws_two_fills("c13a")
  seen <- new.env()
  snap <- function(fs) list(book = fs$lot_state, cash = fs$cash, positions = fs$positions, event_seq = fs$event_seq)
  inject <- function() {
    n <- 0L
    # The second lot operation overall: the base's second one-row call, or
    # (LDG-3167) the second row of the pulse's one batch call; later calls,
    # such as a refusal's prefix bisection, fail too.
    list(ledgr_lot_fill = function(original) function(book, pos, ...) {
      n <<- n + length(pos)
      if (n >= 2L) ws_fault("lot operation")
      original(book, pos, ...)
    }, ledgr_fold_stage_apply = function(original) function(fold_state, ...) {
      before <- snap(fold_state)
      withCallingHandlers(original(fold_state, ...),
        ws4a_injected = function(e) seen$prefix <- list(before = before, after = snap(fold_state)))
    })
  }
  out <- c(ws_patches(inject(), ws_durable(t$fx, t$exp, "c13a", t$plan)), ws_patches(inject(), ws_memory(t$exp, t$plan)))
  ws_need(ws_assert_abort(out), "abort, rollback, condition, stage and failed memory result")
  list(tables = out, observed = as.list(seen))
})

# Typed-side assertions for LDG-3167/3168: not base identity claims. On the
# base, C13a's observed prefix shows the first fill installed before the fault.
ws4a_typed_c13b <- function(before, after) {
  fields <- c("book", "cash", "positions", "event_seq", "buffers")
  for (s in list(before, after)) if (!is.list(s) || !all(fields %in% names(s))) stop("ws4a C13b: a snapshot lacks a field", call. = FALSE)
  identical(before[fields], after[fields])
}
local({ # C13b controls, run on every source: equal, one field changed, missing fields refused.
  s <- list(book = 1, cash = 2, positions = 3, event_seq = 4L, buffers = 5)
  stopifnot(ws4a_typed_c13b(s, s), !ws4a_typed_c13b(s, replace(s, "cash", list(2.5))),
    inherits(tryCatch(ws4a_typed_c13b(list(), list()), error = identity), "error"))
})
ws4a_typed_c13c <- function(out, durable = TRUE) ws_assert_abort(out, durable)
ws4a_typed_c14c <- function(retained, frozen_fingerprint) identical(ws_fingerprint(retained), frozen_fingerprint)
ws4a_typed_c16 <- function(dense_fold_equity_rows, counts) {
  dense_fold_equity_rows > 0L && counts[["replay"]] == 1L && counts[["prefix_commit"]] == 0L
}

# C13c (base half): append, accounting-fact/leg and flush faults after a
# successful calculation, each at a named handler method. The durable sink has
# no separate fact/leg method on the base, so that injection is memory-only.
ws4a_c13c_attach <- c(append = "write_fill_events", fact = "record_accounting_fact", flush = "flush_pulse_events")
ws_case("C13c", "3167", function() {
  out <- list()
  for (k in names(ws4a_c13c_attach)) {
    t <- ws_two_fills(paste0("c13c_", k))
    patch <- list(ledgr_output_handler = function(original) function(sink, ...) {
      h <- original(sink, ...)
      if (is.function(h[[ws4a_c13c_attach[[k]]]])) h[[ws4a_c13c_attach[[k]]]] <- function(...) ws_fault(ws4a_c13c_attach[[k]])
      h
    })
    res <- ws_patches(patch, c(ws_durable(t$fx, t$exp, paste0("c13c-", k), t$plan), ws_memory(t$exp, t$plan)))
    ws_need(ws4a_typed_c13c(res, durable = k != "fact"), paste("abort and rollback for", k))
    out <- c(out, ws_prefix(res, k))
  }
  list(tables = out)
})

# C14: retained hand-outs keep their values across later pulses.
# `view` maps the retained value to its fingerprinted form at capture and at
# the end (C14a: the base-shaped container of a typed book).
ws_keep <- function(env, name, value, view = identity) if (is.null(env$print[[name]])) {
  env$value[[name]] <- value
  # The native typed value is also witnessed whole: the base-shaped view hides
  # names and empty segments (LDG-3164 close review F5).
  if (name %in% c("book_handout", "compiled_input", "corporate_action_view", "event_block", "leg_block")) {
    env$raw[[name]] <- serialize(value, NULL)
  }
  env$view[[name]] <- view
  env$print[[name]] <- ws_fingerprint(view(value))
}
ws_retained <- function(env, n) {
  raw <- vapply(names(env$raw), function(k) identical(env$raw[[k]], serialize(env$value[[k]], NULL)), logical(1))
  ws_need(all(raw), paste0("retained native book representation unchanged (changed: ",
    paste(names(env$raw)[!raw], collapse = ","), ")"))
  tab <- data.frame(object = names(env$print), at_capture = unlist(env$print),
    at_end = vapply(names(env$print), function(k) ws_fingerprint(env$view[[k]](env$value[[k]])), ""))
  ws_need(nrow(tab) == n && all(tab$at_capture == tab$at_end),
    paste0("every retained value unchanged (changed: ", paste(tab$object[tab$at_capture != tab$at_end], collapse = ","), ")"))
  list(tables = list(retained = ws_frame(tab, "retained", "object")))
}
ws_case("C14a", "3164", function() {
  fx <- ws_fixture("c14a", list(AAA = 100 + 0:5), avail = FALSE)
  plan <- ws_days(list(AAA = 1), list(AAA = 2), list(AAA = 3))
  keep <- new.env()
  hooks <- list(ledgr_lot_fill = function(a, v) ws_keep(keep, "book_handout", v$book, function(b) ws_legacy(b, "AAA")))
  hooks[[ws4a_seams[["compiled_batch"]]]] <- function(a, v) ws_keep(keep, "compiled_input", a$state, function(s)
    list(cash = s$cash, positions = stats::setNames(s$positions, "AAA"), lot_state = ws_legacy(s$lot_state, "AAA")))
  ws_trace(hooks, c(ws_durable(fx, ws_exp(fx), "c14a", plan), ws_memory(ws_exp(fx), plan, compiled_accounting_model = "spot_fifo")))
  ws_retained(keep, 2L)
})
ws_case("C14b", "3165", function() {
  d <- ws_disp("c14b", state = TRUE)
  keep <- new.env()
  calls <- 0L
  hooks <- list(ledgr_call_strategy_fn = function(a, v) if ((calls <<- calls + 1L) == 2L) {
    ws_keep(keep, "ctx_vec", a$ctx$vec)
    ws_keep(keep, "state_prev", a$ctx$state_prev)
    ws_keep(keep, "context", list(a$ctx$universe, a$ctx$members, a$ctx$.positions))
  }, ledgr_disposition_post = function(a, v) ws_keep(keep, "corporate_action_view", a$state_value, function(s) {
    s$lot_state <- ws_legacy(s$lot_state, a$instrument_ids) # typed book in its base-shaped container (LDG-3164)
    s
  }))
  ws_trace(hooks, ws_durable(d$fx, d$exp, "c14b", d$plan))
  ws_need(!is.null(keep$value$state_prev), "a retained state_prev")
  ws_retained(keep, 4L)
})
# C14c: the published event block and the memory sink's leg block, retained
# across later pulses. Base: the first fill's payload and the first pulse's
# staged legs. LDG-3167 attaches the typed handouts instead, the first event
# block (ledgr_fill_event_payload) and leg block (ledgr_fill_leg_block),
# fingerprinted in the base shape of the block's first event and of its legs,
# and witnessed whole (raw) as well.
ws4a_c14c_event_view <- function(b) {
  if (!is.null(b$row)) return(b)
  row <- list(event_id = b$event_id[[1L]], run_id = b$run_id[[1L]], ts_utc = .POSIXct(b$ts_utc[[1L]], tz = "UTC"),
    event_type = b$event_type[[1L]], instrument_id = b$instrument_id[[1L]], side = b$side[[1L]], qty = b$qty[[1L]],
    price = b$price[[1L]], fee = b$fee[[1L]], meta_json = b$meta_json[[1L]], event_seq = b$event_seq[[1L]])
  structure(list(status = "WROTE", event_id = row$event_id, event_seq = row$event_seq, next_event_seq = row$event_seq + 1L,
    cash_delta = b$cash_delta[[1L]], position_delta = b$position_delta[[1L]], meta = b$meta[[1L]], row = row),
    class = "ledgr_ledger_write_result")
}
ws4a_c14c_leg_view <- function(l) {
  if (is.null(names(l))) return(l)
  lapply(seq_along(l$event_seq), function(k) list(event_seq = l$event_seq[[k]], ts_utc = .POSIXct(l$ts_utc[[k]], tz = "UTC"),
    instrument_id = l$instrument_id[[k]], side = l$side[[k]], qty = l$qty[[k]], price = l$price[[k]], fee = l$fee[[k]],
    realized_pnl = l$realized_pnl[[k]], action = l$action[[k]]))
}
ws_case("C14c", "3167", function() {
  t <- ws_two_fills("c14c")
  keep <- new.env()
  flushes <- 0L
  ws_trace(list(ledgr_fill_event_payload = function(a, v) ws_keep(keep, "event_block", v, ws4a_c14c_event_view),
    ledgr_fill_leg_block = function(a, v) {
      flushes <<- flushes + 1L
      ws_keep(keep, "leg_block", v, ws4a_c14c_leg_view)
    }), ws_memory(t$exp, t$plan))
  ws_need(flushes >= 2L, "a later pulse flushes legs after the leg block is retained")
  c(ws_retained(keep, 2L), list(facts = list(leg_flushes = flushes)))
})

# v201 availability witness (tests/testthat helper, unchanged).
source(file.path(ws_root, "tests", "testthat", "helper-availability-v0-2-0-1-witnesses.R"), local = TRUE)
ws_v201 <- function(id) {
  f <- availability_v201_fold_fixture()
  db <- file.path(ws_env$work, paste0(id, ".duckdb"))
  assign(normalizePath(db, winslash = "/", mustWork = FALSE), "<DB_PATH>", envir = a0_path_tokens)
  snap <- ledgr_snapshot_from_df(f$bars, instruments_df = f$instruments, db_path = db, snapshot_id = "witness",
    facts = f$facts, price_basis = "split_adjusted")
  ws_env$snaps <- c(ws_env$snaps, list(snap))
  options(ledgr.v201.interrupt_at = "", ledgr.v201.fail_at = "", ledgr.v201.increase_nonmember_at = "", ledgr.v201.exit_eee_from = "")
  exp <- ledgr_experiment(snap, availability_v201_fold_strategy, universe = ledgr_universe_members("U"),
    valuation_policy = ledgr_valuation_stale(max_sessions = 2L, exhausted = "refuse"),
    corporate_action_policy = ledgr_corporate_actions(held_terminal_position = "refuse"),
    cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1e6))
  list(fx = list(snap = snap, db = db), exp = exp)
}
ws_case("C15", "3165", function() {
  v <- ws_v201("c15")
  axis <- list()
  hooks <- list(ledgr_fold_stage_observe_settle = function(a, v) if (!ledgr_is_fold_stop_result(v)) {
    x <- ws_context(a, v)
    axis[[length(axis) + 1L]] <<- data.frame(pulse = v$observation$pulse_idx, context = paste(x$ids, collapse = "+"),
      members = paste(x$members, collapse = "+"), rows = paste(x$pos, collapse = "+"))
  })
  out <- ws_trace(hooks, ws_durable(v$fx, v$exp, "c15"))
  axis <- do.call(rbind, axis)
  ws_need(any(axis$context != axis$members) && length(unique(axis$context)) > 1L, "a changing context with held nonmembers")
  list(tables = c(out, list(context_axis = ws_frame(axis, "context_axis", "pulse"))))
})

# C16: a dense durable run finalizes equity through replay, not the prefix.
# LDG-3168: both producers now fill the fold's equity record, so the fact
# counts the fold rows finalization consumes (the frame built from the
# record; 0 on dense, as the empty base accumulator gave); the record's own
# rows are the typed precondition (observed, not compared).
ws_case("C16", "3168", function() {
  fx <- ws_cost_fx("c16", FALSE)
  n <- c(replay = 0L, prefix_commit = 0L, fold_equity_rows = 0L)
  inside <- FALSE
  record_rows <- NA
  count <- function(k) function(original) function(...) {
    if (inside) n[[k]] <<- n[[k]] + 1L
    original(...)
  }
  patch <- list(ledgr_run_finalize = function(original) function(...) {
    inside <<- TRUE
    on.exit(inside <<- FALSE)
    record_rows <<- ws_args(original, ...)$fold$equity_facts$n
    original(...)
  }, ledgr_run_fold_equity_frame = function(original) function(run_id, fold_equity) {
    if (inside) n[["fold_equity_rows"]] <<- n[["fold_equity_rows"]] + fold_equity$n
    original(run_id, fold_equity)
  })
  patch[[ws4a_seams[["replay"]]]] <- count("replay")
  patch[[ws4a_seams[["prefix_commit"]]]] <- count("prefix_commit")
  out <- ws_patches(patch, ws_durable(fx, ws_exp(fx), "c16", ws_c1_plan))
  ws_need(n[["replay"]] == 1L && n[["prefix_commit"]] == 0L, "replay used and prefix commit unused in finalization")
  ws_need(ws4a_typed_c16(record_rows, n), "the dense run filled its fold equity record")
  list(tables = out["run.equity_curve"], facts = as.list(n), observed = list(dense_record_rows = record_rows))
})

# C17: the window-1 final decision executes at window 2's first open in the
# chain; a standalone run of the same window is the control.
ws_case("C17", "3165", function() {
  wf <- ws_wf("c17")
  window <- ledgr:::ledgr_experiment_window(wf$exp, ws_day(5), ws_day(6))
  sink <- a0_new_sink()
  a0_run_or_record(ledgr:::ledgr_run_window(wf$exp, params = list(plan = ws_wf_plan), window = window,
    run_id = "c17-standalone", seed = 1L), "c17-standalone", sink)
  keep <- c("ledger_events", "run_diagnostics")
  out <- list()
  for (k in seq_along(wf$ids)) out <- c(out, ws_prefix(a0_store_tables(wf$fx$db, wf$ids[[k]])[keep], sprintf("w%d", k)))
  out <- c(out, ws_prefix(c(a0_store_tables(wf$fx$db, "c17-standalone")[keep],
    list(conditions = a0_canon(sink$rows, "run_conditions", "seq"))), "standalone"))
  boundary <- "2020-01-07T09:30:00Z"
  ws_need(any(out[["w1.ledger_events"]]$ts_utc == boundary) && !any(out[["standalone.ledger_events"]]$ts_utc == boundary),
    "continued execution at the next window's first open, absent standalone")
  list(tables = out)
})

# C18: the v201 witness with a writer chunk of 7, a pulse larger than the
# chunk and the witness's early stop (terminal refusal on day 10).
ws_case("C18", "3168", function() {
  v <- ws_v201("c18")
  patch <- stats::setNames(list(function(original) function(run_id, output_handler, chunk_rows = 65536L) {
    original(run_id, output_handler, chunk_rows = 7L)
  }), ws4a_seams[["diagnostic_writer"]])
  out <- ws_patches(patch, c(ws_durable(v$fx, v$exp, "c18"), ws_memory(v$exp, NULL)))
  diag <- out[["run.run_diagnostics"]]
  keep <- c("run.run_diagnostics", "sweep.memory_diagnostics", "run.equity_curve", "run.run_telemetry", "run.run_completion",
    "sweep.memory_completion", "sweep.memory_equity")
  ws_need(max(table(diag$ts_utc)) > 7L && out[["run.run_completion"]]$intended_terminal_status %in% "INCOMPLETE" &&
    as.integer(out[["run.run_telemetry"]]$pulse_count) < 12L, "a pulse above the chunk and an early stop", out[keep])
  list(tables = out[keep], facts = list(max_pulse_rows = max(table(diag$ts_utc))))
})
