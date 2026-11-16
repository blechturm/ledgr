# Slice-4 workloads (Cut 21, workstreams 39-40; interface Section 19.13):
# opening positions and carried openings (LDG-3243), built with public
# constructors and package helpers, the pin as oracle. Sourced by
# loop_parity.R after loop_workloads_slice3.R (whose helpers build, collect,
# collect_open and s3_dates it uses; lw_prefix_reads is loop_workloads.R's).
#
# loop_reach gains, per workload, the branch it is named for, asserted on the
# pin's own tables before parity is accepted.

# --- shared fixtures ------------------------------------------------------------

s4_at <- function(k, time = "16:00:00") as.POSIXct(paste(s3_dates(max(k))[k], time), tz = "UTC")
s4_iso <- function(k) format(s4_at(k), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
# Targets from a per-day table (ISO pulse -> named quantities); other days hold.
s4_strategy <- function(plan) {
  force(plan)
  function(ctx, params) {
    target <- ctx$hold()
    step <- plan[[ctx$ts_utc]]
    if (!is.null(step)) for (id in intersect(names(step), names(target))) target[[id]] <- step[[id]]
    target
  }
}
s4_plan <- function(...) {
  steps <- list(...)
  stats::setNames(lapply(steps, `[[`, 2L), vapply(steps, function(p) s4_iso(p[[1L]]), ""))
}
s4_bars <- function(closes) {
  do.call(rbind, lapply(names(closes), function(id) {
    k <- which(!is.na(closes[[id]]))
    data.frame(ts_utc = s4_at(k), instrument_id = id, open = closes[[id]][k], high = closes[[id]][k] + 1,
               low = closes[[id]][k] - 1, close = closes[[id]][k], volume = 1000, stringsAsFactors = FALSE)
  }))
}
s4_sessions <- function(n_days) {
  d <- s3_dates(n_days)
  ledgr::ledgr_facts_sessions(data.frame(session_date = d, status = "open", session_open = "09:30:00",
    session_close = "16:00:00", knowledge_time = as.POSIXct(d, tz = "UTC") - 1, stringsAsFactors = FALSE),
    venue_id = "XNYS")
}
s4_snapshot <- function(name, closes, facts = NULL) build(name, function(db) {
  ledgr::ledgr_snapshot_from_df(s4_bars(closes), instruments_df = data.frame(instrument_id = names(closes)),
    facts = facts, price_basis = "split_adjusted", db_path = db, snapshot_id = name)
})
s4_closes <- function(n_days = 10L) list(A = 30 + seq_len(n_days) / 4, B = 45 - seq_len(n_days) / 5,
                                         C = 12 + (seq_len(n_days) %% 3))
s4_run <- function(name, closes, facts, exp, seed = 21L) {
  db <- s4_snapshot(name, closes, facts)
  collect(db, name, paste0("s4-", name), exp, seed = seed)
}
s4_exp <- function(strategy, positions = NULL, cost_basis = NULL, cash = 1e4, ...) function(snapshot) {
  ledgr::ledgr_experiment(snapshot, strategy, opening = ledgr::ledgr_opening(cash = cash, positions = positions,
    cost_basis = cost_basis), cost_model = ledgr::ledgr_cost_zero(), ...)
}
s4_dividend <- function(parent, entitle, effective, cash = 0.5, id = "div-1") {
  data.frame(fact_id = id, subtype = "ordinary_cash_dividend", parent_instrument_id = parent,
    entitlement_time = s4_at(entitle), effective_time = s4_at(effective), knowledge_time = s4_at(1L) - 3600,
    complete = TRUE, provenance_tier = "snapshot_bound", gross_cash_per_parent_unit = cash,
    gross_cash_validated = TRUE, recipient_identity_validated = FALSE, recipient_quantity_validated = FALSE,
    source = "s4", stringsAsFactors = FALSE)
}

# --- LDG-3243: opening positions and carried openings ---------------------------

# A carried test window (cut review R1): the package helper that builds a
# walk-forward test window's experiment (R/walk-forward.R:1142, not
# exported) gives the opening its carried part, run by ledgr_run() with no
# walk-forward orchestration. The window opens on day 5 holding A = 10 in
# two FIFO lots (4 at 20, 6 at 40; one average-price lot would be 10 at 32),
# entered on day 1, frozen (A has no bars on days 2-6 and the policy
# freezes an exhausted holding), sells 5 A on day 8, and records its entry
# price and bars since entry in each intent reason. With `pending`, a
# dividend fact of 0.5 per unit is carried as an entitlement bound for 7
# units, not the 10 held.
s4_carried <- function(name, pending) {
  closes <- s4_closes()
  closes$A[2:6] <- NA
  facts <- if (pending) {
    act <- s4_dividend("A", 3L, 7L)
    act$knowledge_time <- s4_at(6L)
    ledgr::ledgr_facts(s4_sessions(10L), ledgr::ledgr_facts_equity_corporate_actions(act))
  } else ledgr::ledgr_facts(s4_sessions(10L))
  db <- s4_snapshot(name, closes, facts)
  fact <- NULL
  if (pending) {
    con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db, read_only = TRUE)
    fact <- DBI::dbGetQuery(con, "SELECT fact_id FROM snapshot_equity_corporate_actions")$fact_id[[1L]]
    DBI::dbDisconnect(con, shutdown = TRUE)
  }
  snapshot <- ledgr::ledgr_snapshot_open(db, name, verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot))
  strat <- function(ctx, params) {
    t <- ctx$hold()
    if (ctx$ts_utc == "2020-01-08T16:00:00Z") t[["A"]] <- 5
    list(targets = t, intent_reason = paste(ctx$entry_price[["A"]], ctx$bars_since_entry[["A"]], sep = ":"))
  }
  exp <- s4_exp(strat, positions = c(A = 10), cost_basis = c(A = 32),
    valuation_policy = ledgr::ledgr_valuation_stale(1L, exhausted = "freeze"))(snapshot)
  opening <- ledgr::ledgr_opening(1e4, date = s4_at(5L), positions = c(A = 10), cost_basis = c(A = 32))
  opening$carried <- list(lots = list(instrument_id = c("A", "A"), qty = c(4, 6), price = c(20, 40)),
    frozen = "A", position_facts = list(instrument_id = "A", entry_at = s4_iso(1L), exit_at = ""))
  if (pending) opening$carried$pending <- data.frame(fact_id = fact, quantity = 7, posting_ts_utc = s4_iso(3L))
  exp <- get("ledgr_walk_forward_experiment_with_opening", envir = ns)(exp, opening)
  collect_open(snapshot, db, paste0("s4-", name), exp, seed = 21L)
}

# An opening holding of A whose basis the experiment's package payload field
# marks unknown (R/sweep.R:1402, 1746), in a one-worker sweep: the strategy
# buys one B when A's entry price is masked and two when it is known.
s4_basis_sweep <- function(name, unknown) {
  db <- s4_snapshot(name, s4_closes(), NULL)
  snapshot <- ledgr::ledgr_snapshot_open(db, name, verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot))
  strat <- function(ctx, params) {
    target <- ctx$hold()
    target[["B"]] <- if (is.na(ctx$entry_price[["A"]])) 1 else 2
    target
  }
  exp <- s4_exp(strat, positions = c(A = 10), cost_basis = c(A = 28))(snapshot)
  if (unknown) exp$position_fact_unknown_basis <- "A"
  obs <- a0_observe_memory(ledgr::ledgr_sweep(exp, ledgr::ledgr_grid_named(a = list(strategy = list(k = 1L))),
    seed = 17L, workers = 1L, retain = a0_retain()))
  list(sweep = c(a0_sweep_tables(obs$value), a0_memory_tables(obs$observed, obs$value)))
}

loop_slice4 <- list(
  # Opening positions with a cost basis, complete bars, no facts: held,
  # added to, partly sold (FIFO through the opening lot), liquidated.
  s4_opening = function() s4_run("s4_opening", s4_closes(), NULL,
    s4_exp(s4_strategy(s4_plan(list(3L, c(A = 14)), list(5L, c(B = 2)), list(8L, c(A = 0, C = 3)))),
           positions = c(A = 10, B = 5), cost_basis = c(A = 28, B = 47))),
  # Opening positions under a declared calendar (availability active).
  s4_opening_sessions = function() s4_run("s4_opening_sessions", s4_closes(), ledgr::ledgr_facts(s4_sessions(10L)),
    s4_exp(s4_strategy(s4_plan(list(4L, c(A = 3)), list(7L, c(B = 9)))), positions = c(A = 6), cost_basis = c(A = 29))),
  # The carried window with its pending entitlement (a corporate-action plan:
  # lean from LDG-3244), and without it (lean now).
  s4_carried = function() s4_carried("s4_carried", pending = TRUE),
  s4_carried_lots = function() s4_carried("s4_carried_lots", pending = FALSE),
  s4_basis_unknown = function() s4_basis_sweep("s4_basis_unknown", TRUE),
  s4_basis_known = function() s4_basis_sweep("s4_basis_known", FALSE),
  # Committed prefix (decision 4(b)): the sweep's opening row is in the
  # retaining handler before the first strategy call; a run's opening rows
  # are in the store, outside its pending count.
  s4_prefix_opening_sweep = function() lw_prefix_reads(memory = TRUE,
    workload = function() s4_basis_sweep("s4_prefix_opening_sweep", FALSE)),
  s4_prefix_opening_run = function() lw_prefix_reads(memory = FALSE, workload = loop_slice4_opening)
)
loop_slice4_opening <- loop_slice4$s4_opening

# --- LDG-3244: corporate actions without other facts ----------------------------

# One corporate-action fact (R/availability-facts.R:615). `entitle`,
# `effective` and `known` are day numbers, NA for no clock; known = 0 is an
# hour before the first session. An incomplete fact carries a refusal reason.
s4_action <- function(id, subtype, parent, entitle = NA, effective = NA, known = 0L, cash = NA_real_,
                      complete = TRUE) {
  at <- function(k) if (is.na(k)) as.POSIXct(NA, tz = "UTC") else if (k == 0L) s4_at(1L) - 3600 else s4_at(k)
  data.frame(fact_id = id, subtype = subtype, parent_instrument_id = parent, entitlement_time = at(entitle),
    effective_time = at(effective), knowledge_time = at(known), complete = complete,
    refusal_reason = if (complete) NA_character_ else "unverified", provenance_tier = "snapshot_bound",
    gross_cash_per_parent_unit = cash, gross_cash_validated = !is.na(cash), recipient_identity_validated = FALSE,
    recipient_quantity_validated = FALSE, source = "s4", stringsAsFactors = FALSE)
}
s4_ca_facts <- function(acts, sessions = NULL) {
  f <- ledgr::ledgr_facts_equity_corporate_actions(acts)
  if (is.null(sessions)) ledgr::ledgr_facts(f) else ledgr::ledgr_facts(s4_sessions(sessions), f)
}
s4_div <- function(id, parent, entitle, effective, cash = 0.5, known = 0L) {
  s4_action(id, "ordinary_cash_dividend", parent, entitle, effective, known, cash)
}
s4_policy <- function(...) ledgr::ledgr_corporate_actions(...)
# A one-worker sweep of one candidate over a snapshot with corporate actions.
s4_ca_sweep <- function(name, closes, facts, exp) {
  db <- s4_snapshot(name, closes, facts)
  snapshot <- ledgr::ledgr_snapshot_open(db, name, verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot))
  obs <- a0_observe_memory(ledgr::ledgr_sweep(exp(snapshot), ledgr::ledgr_grid_named(a = list(strategy = list(k = 1L))),
    seed = 17L, workers = 1L, retain = a0_retain()))
  list(sweep = c(a0_sweep_tables(obs$value), a0_memory_tables(obs$observed, obs$value)))
}
# The mixed case (decision 10, cut review R8): eight held instruments with a
# dividend each on day 3 (one block of eight rows, beside that pulse's
# fills), single dividends on days 4, 5, 7 and 8 (six blocks: the capture
# grows past its four slots after a nonempty prefix), fills decided on days
# 2, 3 and 6, and a dividend on day 9, after the last fill.
s4_mixed_ids <- sprintf("M%d", 1:8)
s4_mixed <- function(name) {
  closes <- stats::setNames(lapply(seq_along(s4_mixed_ids), function(k) 20 + k + seq_len(10L) / 5), s4_mixed_ids)
  acts <- rbind(do.call(rbind, lapply(seq_along(s4_mixed_ids), function(k)
    s4_div(paste0("d3-", k), s4_mixed_ids[[k]], 3L, 5L, cash = k / 10))),
    s4_div("d4", "M1", 4L, 6L), s4_div("d5", "M2", 5L, 6L), s4_div("d7", "M3", 7L, 8L), s4_div("d8", "M4", 8L, 9L),
    s4_div("d9", "M5", 9L, 10L))
  s4_run(name, closes, s4_ca_facts(acts),
    s4_exp(s4_strategy(s4_plan(list(2L, c(M6 = 4)), list(3L, c(M1 = 14, M7 = 2)), list(6L, c(M2 = 0, M8 = 15)))),
      positions = stats::setNames(rep(10, 8L), s4_mixed_ids), cost_basis = stats::setNames(rep(20, 8L), s4_mixed_ids),
      cash = 1e5))
}

loop_slice4 <- c(loop_slice4, list(
  # A cash dividend on an opening holding, a buy between entitlement and pay date.
  s4_dividend = function() s4_run("s4_dividend", s4_closes(), s4_ca_facts(s4_div("d1", "A", 3L, 6L)),
    s4_exp(s4_strategy(s4_plan(list(4L, c(A = 15)))), positions = c(A = 10), cost_basis = c(A = 28))),
  # A dividend on a position bought in the run (no opening positions).
  s4_dividend_bought = function() s4_run("s4_dividend_bought", s4_closes(), s4_ca_facts(s4_div("d1", "B", 4L, 7L, 1.25)),
    s4_exp(s4_strategy(s4_plan(list(1L, c(B = 20)), list(8L, c(B = 0)))))),
  # Dividends under a declared calendar, entitled on day 1 (the run-start
  # boundary: 10 held at the opening) and on day 3 (bound in day 2's P4
  # before its fills: 10, not the 12 bought then).
  s4_dividend_sessions = function() s4_run("s4_dividend_sessions", s4_closes(),
    s4_ca_facts(rbind(s4_div("d0", "A", 1L, 2L, 0.25), s4_div("d1", "A", 3L, 5L)), sessions = 10L),
    s4_exp(s4_strategy(s4_plan(list(2L, c(A = 12)))), positions = c(A = 10), cost_basis = c(A = 28))),
  # A dividend posted on a pulse the schedule skips (decided on days 2 and 8).
  s4_dividend_skip = function() s4_run("s4_dividend_skip", s4_closes(), s4_ca_facts(s4_div("d1", "A", 5L, 6L), sessions = 10L),
    s4_exp(s4_strategy(s4_plan(list(2L, c(B = 4)), list(8L, c(A = 0)))), positions = c(A = 10), cost_basis = c(A = 28),
      schedule = ledgr::ledgr_schedule_dates(s3_dates(10L)[c(2L, 8L)]))),
  # Cash posted at the next open, a late-known dividend, and a dividend on
  # an instrument never held beside a held one.
  s4_dividend_next_open = function() s4_run("s4_dividend_next_open", s4_closes(), s4_ca_facts(s4_div("d1", "A", 3L, 6L)),
    s4_exp(s4_strategy(list()), positions = c(A = 10), cost_basis = c(A = 28),
      corporate_action_policy = s4_policy(cash_posting = "next_open"))),
  s4_dividend_late = function() s4_run("s4_dividend_late", s4_closes(), s4_ca_facts(s4_div("d1", "A", 3L, 6L, known = 5L)),
    s4_exp(s4_strategy(list()), positions = c(A = 10), cost_basis = c(A = 28))),
  s4_dividend_unheld = function() s4_run("s4_dividend_unheld", s4_closes(),
    s4_ca_facts(rbind(s4_div("d1", "A", 3L, 6L), s4_div("d2", "C", 3L, 6L, 2))),
    s4_exp(s4_strategy(list()), positions = c(A = 10), cost_basis = c(A = 28))),
  # Refusals (a typed stop at the valuation): a held dividend under
  # cash_amount = "refuse"; a held unmodeled effect under
  # unsupported_quantity = "refuse"; both due on one pulse, where the cash
  # refusal comes first (R/fold-engine.R:383).
  s4_cash_refused = function() s4_run("s4_cash_refused", s4_closes(), s4_ca_facts(s4_div("d1", "A", 3L, 6L)),
    s4_exp(s4_strategy(list()), positions = c(A = 10), cost_basis = c(A = 28),
      corporate_action_policy = s4_policy(cash_amount = "refuse"))),
  s4_quantity_refused = function() s4_run("s4_quantity_refused", s4_closes(),
    s4_ca_facts(s4_action("q1", "stock_split", "A", 3L, 4L)),
    s4_exp(s4_strategy(list()), positions = c(A = 10), cost_basis = c(A = 28),
      corporate_action_policy = s4_policy(unsupported_quantity = "refuse"))),
  s4_cash_quantity_refused = function() s4_run("s4_cash_quantity_refused", s4_closes(),
    s4_ca_facts(rbind(s4_div("d1", "A", 4L, 6L), s4_action("q1", "stock_split", "B", 3L, 4L))),
    s4_exp(s4_strategy(list()), positions = c(A = 10, B = 5), cost_basis = c(A = 28, B = 47),
      corporate_action_policy = ledgr::ledgr_corporate_actions_strict())),
  # Reported, not refused (the default unsupported_quantity = "report_only"):
  # a held spin-off, a held incomplete dividend, a held unmodeled effect, and
  # an unmodeled effect with no effective clock.
  s4_quantity_reported = function() s4_run("s4_quantity_reported", s4_closes(),
    s4_ca_facts(rbind(s4_action("s1", "spin_off", "A", 3L, 4L), s4_action("i1", "ordinary_cash_dividend", "B", 3L, 5L,
      cash = 1, complete = FALSE), s4_action("u1", "rights_issue", "C", 4L, 6L), s4_action("u2", "rights_issue", "A", 5L))),
    s4_exp(s4_strategy(s4_plan(list(5L, c(A = 12)))), positions = c(A = 10, B = 5, C = 8),
      cost_basis = c(A = 28, B = 47, C = 12))),
  # Clock refusals (conditions, R/corporate-action-settlement.R:369-411): a
  # knowable fact with no event clock, and a dividend with an effective but
  # no entitlement clock.
  s4_clock_missing = function() s4_run("s4_clock_missing", s4_closes(),
    s4_ca_facts(s4_action("c1", "ordinary_cash_dividend", "A", known = 4L, cash = 0.5)),
    s4_exp(s4_strategy(list()), positions = c(A = 10), cost_basis = c(A = 28))),
  s4_entitlement_missing = function() s4_run("s4_entitlement_missing", s4_closes(),
    s4_ca_facts(s4_div("e1", "A", NA, 5L)),
    s4_exp(s4_strategy(list()), positions = c(A = 10), cost_basis = c(A = 28))),
  s4_dividend_mixed = function() s4_mixed("s4_dividend_mixed"),
  # A finite gross dividend whose cash delta overflows (cut review R3): the
  # capture's acceptance refuses it in P1, as the pin's handler does.
  s4_cash_overflow = function() s4_run("s4_cash_overflow", s4_closes(), s4_ca_facts(s4_div("d1", "A", 3L, 6L, 1e308)),
    s4_exp(s4_strategy(list()), positions = c(A = 10), cost_basis = c(A = 28))),
  # Committed prefix (decision 4(b), cut review R4): a dividend accepted in
  # P1 is in the retaining handler before that pulse's strategy call, with
  # and without an opening, on a run (outside the draining count), and on a
  # pulse whose strategy then fails.
  s4_prefix_dividend_sweep = function() lw_prefix_reads(memory = TRUE, workload = function()
    s4_ca_sweep("s4_prefix_dividend_sweep", s4_closes(), s4_ca_facts(s4_div("d1", "A", 3L, 6L)),
      s4_exp(s4_strategy(s4_plan(list(1L, c(B = 2)))), positions = c(A = 10), cost_basis = c(A = 28)))),
  s4_prefix_dividend_bought = function() lw_prefix_reads(memory = TRUE, workload = function()
    s4_ca_sweep("s4_prefix_dividend_bought", s4_closes(), s4_ca_facts(s4_div("d1", "B", 4L, 7L)),
      s4_exp(s4_strategy(s4_plan(list(1L, c(B = 20)), list(8L, c(B = 0))))))),
  s4_prefix_dividend_run = function() lw_prefix_reads(memory = FALSE, workload = function() loop_slice4$s4_dividend()),
  s4_prefix_dividend_stop = function() lw_prefix_reads(memory = TRUE, workload = function()
    s4_ca_sweep("s4_prefix_dividend_stop", s4_closes(), s4_ca_facts(s4_div("d1", "A", 4L, 6L)),
      s4_exp(function(ctx, params) {
        t <- ctx$hold()
        if (ctx$ts_utc == "2020-01-04T16:00:00Z") t[["B"]] <- NA_real_
        t
      }, positions = c(A = 10), cost_basis = c(A = 28))))
))

# --- branch reach (on the pin's tables) -----------------------------------------

s4_events <- function(t, path = "run") t[[path]]$ledger_events
s4_diag <- function(t) t$run$run_diagnostics
s4_intents <- function(t) {
  d <- s4_diag(t)
  d <- d[d$reason_code == "strategy_intent", ]
  stats::setNames(d$reasons, substr(d$ts_utc, 1L, 10L))
}
# The carried window (cut review R1): on its first pulse (day 5) no
# valuation/frozen transition, but a decision/recorded/valuation_frozen row
# with the pin's mark metadata; the day-8 sale of 5 A realises FIFO lots
# (4 at 20, then 1 at 40), not one lot at 32; entry price 32 and 4 bars since
# the day-1 entry on the first decision, 40 after the sale; with `pending`,
# a corporate_action_cash CASHFLOW of 7 x 0.5 = 3.5 for the entitlement bound
# at 7 units against 10 held.
s4_carried_reach <- function(pending) function(t) {
  d <- s4_diag(t)
  first <- substr(d$ts_utc, 1L, 10L) == "2020-01-05"
  no_transition <- !any(first & d$stage == "valuation" & d$outcome == "frozen" & d$reason_code == "valuation_frozen")
  kept <- d[first & d$stage == "decision" & d$outcome == "recorded" & d$reason_code == "valuation_frozen", ]
  kept_ok <- nrow(kept) == 1L && kept$instrument_id == "A" && !is.na(kept$mark_source) && nzchar(kept$mark_source)
  sale <- t$run$fills[t$run$fills$instrument_id == "A" & t$run$fills$side == "SELL", ]
  num <- function(x) as.numeric(x)
  fifo <- nrow(sale) == 1L && num(sale$qty) == 5 &&
    isTRUE(all.equal(num(sale$realized_pnl), 4 * (num(sale$price) - 20) + (num(sale$price) - 40) - num(sale$fee))) &&
    !isTRUE(all.equal(num(sale$realized_pnl), 5 * (num(sale$price) - 32) - num(sale$fee)))
  r <- s4_intents(t)
  anchor <- identical(unname(r[["2020-01-05"]]), "32:4") && startsWith(unname(r[["2020-01-09"]]), "40:")
  ev <- s4_events(t)
  cash <- ev[ev$event_type == "CASHFLOW" & ev$source %in% "corporate_action_cash", ]
  ent <- if (pending) {
    nrow(cash) == 1L && isTRUE(all.equal(num(cash$cash_delta), 3.5)) && num(cash$entitled_quantity) == 7
  } else nrow(cash) == 0L
  no_transition && kept_ok && fifo && anchor && ent
}
# B bought on the first pulse: one when A's basis is unknown, two when known.
s4_basis_reach <- function(qty) function(t) {
  f <- t$sweep$memory_fills
  b <- f[f$instrument_id == "B" & f$side == "BUY", ]
  nrow(b) >= 1L && as.numeric(b$qty[[1L]]) == qty
}
s4_opening_reach <- function(n_open) function(t) {
  ev <- s4_events(t)
  op <- ev[ev$source %in% "opening_position", ]
  nrow(op) == n_open && any(ev$event_type == "FILL")
}

loop_reach <- c(loop_reach, list(
  s4_opening = s4_opening_reach(2L),
  s4_opening_sessions = s4_opening_reach(1L),
  s4_carried = s4_carried_reach(TRUE),
  s4_carried_lots = s4_carried_reach(FALSE),
  s4_basis_unknown = s4_basis_reach(1),
  s4_basis_known = s4_basis_reach(2),
  # The first strategy call already sees the opening row (one event).
  s4_prefix_opening_sweep = function(t) {
    p <- t$sweep$prefix_reads
    !is.null(p) && nrow(p) > 1L && p$events[[1L]] == 1L
  },
  s4_prefix_opening_run = function(t) {
    p <- t$run$prefix_reads
    !is.null(p) && nrow(p) > 1L && s4_opening_reach(2L)(t)
  }
))

# LDG-3244 (decision 10, cut review R7): corporate-action CASHFLOW rows are
# selected by source corporate_action_cash (not opening_position); each
# predicate asserts the posting's day, quantity, cash and evidence fields.
s4_num <- function(x) as.numeric(x)
s4_cf <- function(t, path = "run") {
  ev <- t[[path]]$ledger_events
  if (is.null(ev)) ev <- t[[path]]$memory_events
  ev[ev$event_type == "CASHFLOW" & ev$source %in% "corporate_action_cash", , drop = FALSE]
}
s4_day <- function(x) substr(x, 1L, 10L)
s4_status <- function(t) as.character(t$run$runs$status)
s4_stop_rows <- function(t, reason) {
  d <- s4_diag(t)
  d[d$stage == "valuation" & d$outcome == "stopped" & d$reason_code == reason, , drop = FALSE]
}
s4_refusal_reach <- function(reason, ids, day) function(t) {
  s <- s4_stop_rows(t, reason)
  cmp <- t$run$run_completion
  identical(s4_status(t), "INCOMPLETE") && nrow(s) == length(ids) && setequal(s$instrument_id, ids) &&
    all(s4_day(s$ts_utc) == day) && identical(as.character(cmp$stop_reason), reason) &&
    s4_num(cmp$affected_exposure) > 0 && nrow(s4_cf(t)) == 0L
}
s4_condition_reach <- function(class) function(t) any(grepl(class, t$run$run_conditions$class, fixed = TRUE))
# Count of events visible to the strategy call on `day` minus the previous
# call's (prefix reads, decision 4(b)).
s4_prefix_step <- function(t, path, day) {
  p <- t[[path]]$prefix_reads
  p <- p[p$ts_utc != "reconciliation", , drop = FALSE]
  k <- which(s4_day(p$ts_utc) == day)
  if (length(k) != 1L || k < 2L) return(NA_real_)
  s4_num(p$events[[k]]) - s4_num(p$events[[k - 1L]])
}

loop_reach <- c(loop_reach, list(
  # 10 x 0.5 entitled at the day-3 boundary, before the day-4 buy.
  s4_dividend = function(t) {
    cf <- s4_cf(t)
    nrow(cf) == 1L && cf$instrument_id == "A" && s4_num(cf$entitled_quantity) == 10 && s4_num(cf$cash_delta) == 5 &&
      s4_day(cf$ts_utc) == "2020-01-03" && cf$source_fact_id != ""
  },
  # 20 bought on day 1, entitled at day 4: 20 x 1.25.
  s4_dividend_bought = function(t) {
    cf <- s4_cf(t)
    nrow(cf) == 1L && cf$instrument_id == "B" && s4_num(cf$entitled_quantity) == 20 && s4_num(cf$cash_delta) == 25
  },
  # Day 1: the opening's 10 bound at the run start; day 3: bound in day 2's
  # P4 before its fills, 10 and not the 12 held after them.
  s4_dividend_sessions = function(t) {
    cf <- s4_cf(t)
    nrow(cf) == 2L && all(s4_num(cf$entitled_quantity) == 10) && setequal(s4_day(cf$ts_utc), c("2020-01-01", "2020-01-03")) &&
      any(t$run$fills$instrument_id == "A" & t$run$fills$side == "BUY" & s4_num(t$run$fills$qty) == 2)
  },
  # Posted on day 5, a pulse the schedule skips.
  s4_dividend_skip = function(t) {
    cf <- s4_cf(t)
    d <- s4_diag(t)
    skipped <- s4_day(d$ts_utc[d$reason_code == "scheduled_skip"])
    nrow(cf) == 1L && s4_day(cf$ts_utc) == "2020-01-05" && "2020-01-05" %in% skipped
  },
  # Entitled on day 3, posted at the next open (day 4), under its policy.
  s4_dividend_next_open = function(t) {
    cf <- s4_cf(t)
    nrow(cf) == 1L && s4_day(cf$ts_utc) == "2020-01-04" && grepl("next_open", cf$posting_policy_id)
  },
  # Known on day 5 after its day-3 entitlement: posted on day 5, late.
  s4_dividend_late = function(t) {
    cf <- s4_cf(t)
    nrow(cf) == 1L && s4_day(cf$ts_utc) == "2020-01-05" && identical(as.character(cf$late_arrival), "TRUE")
  },
  # The unheld C row posts nothing; the held A row posts.
  s4_dividend_unheld = function(t) {
    cf <- s4_cf(t)
    nrow(cf) == 1L && cf$instrument_id == "A"
  },
  s4_cash_refused = s4_refusal_reach("corporate_action_cash_refused", "A", "2020-01-03"),
  s4_quantity_refused = s4_refusal_reach("corporate_action_quantity_refused", "A", "2020-01-04"),
  # Both due on day 4: the cash refusal stops first; B's quantity is not checked.
  s4_cash_quantity_refused = s4_refusal_reach("corporate_action_cash_refused", "A", "2020-01-04"),
  # Reported effects: no stop, no CASHFLOW (the incomplete dividend settles
  # nothing), and the day-5 trade still happens.
  s4_quantity_reported = function(t) {
    identical(s4_status(t), "DONE") && nrow(s4_cf(t)) == 0L && nrow(s4_stop_rows(t, "corporate_action_quantity_refused")) == 0L &&
      any(t$run$fills$instrument_id == "A")
  },
  s4_clock_missing = s4_condition_reach("ledgr_corporate_action_clock_missing"),
  s4_entitlement_missing = s4_condition_reach("ledgr_corporate_action_entitlement_missing"),
  # Eight rows on day 3 (one block, beside fills decided that day), six
  # posting pulses (capture growth), a CASHFLOW numbered right before a FILL,
  # and CASHFLOW rows after the last FILL.
  s4_dividend_mixed = function(t) {
    ev <- t$run$ledger_events
    ev <- ev[order(s4_num(ev$event_seq)), ]
    cf <- ev$event_type == "CASHFLOW" & ev$source %in% "corporate_action_cash"
    fill <- ev$event_type == "FILL"
    sum(cf & s4_day(ev$ts_utc) == "2020-01-03") == 8L && length(unique(s4_day(ev$ts_utc[cf]))) == 6L &&
      any(cf[-length(cf)] & fill[-1L]) && max(which(cf)) > max(which(fill))
  },
  s4_cash_overflow = s4_condition_reach("ledgr_invalid_accounting_event"),
  # The dividend accepted on day 3 is visible to that day's strategy call:
  # one more event than day 2's call, with no fill in between.
  s4_prefix_dividend_sweep = function(t) isTRUE(s4_prefix_step(t, "sweep", "2020-01-03") == 1) && nrow(s4_cf(t, "sweep")) == 1L,
  s4_prefix_dividend_bought = function(t) isTRUE(s4_prefix_step(t, "sweep", "2020-01-04") == 1) && nrow(s4_cf(t, "sweep")) == 1L,
  # A draining run's count leaves the dividend out (it is in the store).
  s4_prefix_dividend_run = function(t) isTRUE(s4_prefix_step(t, "run", "2020-01-03") == 0) && nrow(s4_cf(t)) == 1L,
  # The day-4 dividend is visible to the strategy call that then fails.
  s4_prefix_dividend_stop = function(t) isTRUE(s4_prefix_step(t, "sweep", "2020-01-04") == 1)
))
