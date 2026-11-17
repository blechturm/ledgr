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
# Buys 2 A on day 1; a call on any later day fails (the capacity witnesses).
s4_cap_strategy <- function(ctx, params) {
  if (ctx$ts_utc != "2020-01-01T16:00:00Z") stop("lean witness: strategy reached after a refused append")
  t <- ctx$hold()
  t[["A"]] <- 12
  t
}
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
  # The retaining handler's room (close review round 1, F1): a one-candidate
  # sweep on A alone has room for its opening row and 3 more events (one
  # per pulse). Twelve dividends on day 1 exceed it at their append, before
  # the strategy (which fails if called); the prefix observer, with a
  # holding strategy, sees no call. After a day-1 fill (2 events held), four
  # dividends on day 2 exceed the 5. Three dividends on day 1 fill the room
  # exactly, and day 1's fill then exceeds it when committed (P5).
  s4_capacity_block = function() s4_ca_sweep("s4_capacity_block", list(A = 30 + 1:3),
    s4_ca_facts(do.call(rbind, lapply(1:12, function(k) s4_div(paste0("d", k), "A", 1L, 2L)))),
    s4_exp(function(ctx, params) stop("lean witness: strategy reached after a refused append"),
      positions = c(A = 10), cost_basis = c(A = 28))),
  s4_capacity_prefix = function() lw_prefix_reads(memory = TRUE, workload = function()
    s4_ca_sweep("s4_capacity_prefix", list(A = 30 + 1:3),
      s4_ca_facts(do.call(rbind, lapply(1:12, function(k) s4_div(paste0("d", k), "A", 1L, 2L)))),
      s4_exp(s4_strategy(list()), positions = c(A = 10), cost_basis = c(A = 28)))),
  s4_capacity_after_fill = function() lw_prefix_reads(memory = TRUE, workload = function()
    s4_ca_sweep("s4_capacity_after_fill", list(A = 30 + 1:4),
      s4_ca_facts(do.call(rbind, lapply(1:4, function(k) s4_div(paste0("d", k), "A", 2L, 3L)))),
      s4_exp(s4_strategy(s4_plan(list(1L, c(A = 12)))), positions = c(A = 10), cost_basis = c(A = 28)))),
  s4_capacity_fill = function() lw_prefix_reads(memory = TRUE, workload = function()
    s4_ca_sweep("s4_capacity_fill", list(A = 30 + 1:3),
      s4_ca_facts(do.call(rbind, lapply(1:3, function(k) s4_div(paste0("d", k), "A", 1L, 2L)))),
      s4_exp(s4_strategy(s4_plan(list(1L, c(A = 12)))), positions = c(A = 10), cost_basis = c(A = 28)))),
  # The same two refusals without the prefix observer (which needs the
  # harness hooks), for inert hooks: the strategy buys on day 1 and fails if
  # called on a later day.
  s4_capacity_after_fill_run = function() s4_ca_sweep("s4_capacity_after_fill_run", list(A = 30 + 1:4),
    s4_ca_facts(do.call(rbind, lapply(1:4, function(k) s4_div(paste0("d", k), "A", 2L, 3L)))),
    s4_exp(s4_cap_strategy, positions = c(A = 10), cost_basis = c(A = 28))),
  s4_capacity_fill_run = function() s4_ca_sweep("s4_capacity_fill_run", list(A = 30 + 1:3),
    s4_ca_facts(do.call(rbind, lapply(1:3, function(k) s4_div(paste0("d", k), "A", 1L, 2L)))),
    s4_exp(s4_cap_strategy, positions = c(A = 10), cost_basis = c(A = 28))),
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
s4_capacity_failed <- function(t) {
  s <- t$sweep$sweep
  NROW(s) == 1L && identical(as.character(s$status), "FAILED") &&
    identical(as.character(s$error_class), "ledgr_event_buffer_capacity_exceeded")
}
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
  # nothing), and A's day-4 spin-off leaves A unchanged, so the day-5 target
  # of 12 buys exactly 2 (cut review R7: unchanged positions).
  s4_quantity_reported = function(t) {
    f <- t$run$fills
    identical(s4_status(t), "DONE") && nrow(s4_cf(t)) == 0L && nrow(s4_stop_rows(t, "corporate_action_quantity_refused")) == 0L &&
      sum(f$instrument_id == "A") == 1L && s4_num(f$qty[f$instrument_id == "A"]) == 2
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
  s4_prefix_dividend_stop = function(t) isTRUE(s4_prefix_step(t, "sweep", "2020-01-04") == 1),
  # Close review round 1, F1: the candidate fails with the retaining
  # handler's capacity refusal, at the point each witness names.
  s4_capacity_block = function(t) s4_capacity_failed(t),
  s4_capacity_after_fill_run = function(t) s4_capacity_failed(t),
  s4_capacity_fill_run = function(t) s4_capacity_failed(t),
  # Refused at the day-1 append: no strategy or reconciliation observation.
  s4_capacity_prefix = function(t) s4_capacity_failed(t) && NROW(t$sweep$prefix_reads) == 0L,
  # Day 1 sees the opening row, its reconciliation the committed fill too;
  # refused at the day-2 append, before that day's strategy call.
  s4_capacity_after_fill = function(t) {
    p <- t$sweep$prefix_reads
    s4_capacity_failed(t) && NROW(p) == 2L && identical(p$ts_utc, c("2020-01-01T16:00:00Z", "reconciliation")) &&
      identical(s4_num(p$events), c(1, 2))
  },
  # Day 1 sees the opening row and three dividends (the room is full);
  # refused when its fill is committed, before reconciliation.
  s4_capacity_fill = function(t) {
    p <- t$sweep$prefix_reads
    s4_capacity_failed(t) && NROW(p) == 1L && p$ts_utc == "2020-01-01T16:00:00Z" && s4_num(p$events) == 4
  }
))

# --- LDG-3246: facts, the per-pulse views, the context axis and strategy state ---

# Membership snapshots of universe "U" (R/availability-facts.R:167): `sets`
# maps a day number to its members (character(0): no member); each set is
# effective from that day's 00:00 and known at 17:00 the day before, after
# that day's decision and before the next session opens.
s4_universe <- function(sets) {
  eff <- s4_at(as.integer(names(sets)), "00:00:00")
  ledgr::ledgr_facts_membership_snapshots(data.frame(effective_from = eff, knowledge_time = eff - 7 * 3600,
    set_id = paste0("S", names(sets)), members = I(unname(sets)), source = "s4", stringsAsFactors = FALSE), "U")
}
s4_members_exp <- function(strategy, ...) s4_exp(strategy, universe = ledgr::ledgr_universe_members("U"), ...)
# One trading-status row from day `from` (00:00) to `to` (NA: open), known at
# 17:00 the day before; two sources tied on one interval conflict.
s4_trading <- function(id, status, from, to = NA, src = "s4") {
  eff <- s4_at(from, "00:00:00")
  data.frame(fact_id = paste(id, status, from, src, sep = "-"), instrument_id = id, effective_from = eff,
    effective_to = if (is.na(to)) as.POSIXct(NA, tz = "UTC") else s4_at(to, "00:00:00"), knowledge_time = eff - 7 * 3600,
    status = status, source = src, precedence = 0L, stringsAsFactors = FALSE)
}
# The v0.2.0.1 availability witness (tests/testthat): membership sets, halts,
# a stale mark and a delisting, defined in an environment whose parent is
# ledgr's namespace so the helper's unqualified calls resolve (the probe's).
s4_v201 <- new.env(parent = asNamespace("ledgr"))
sys.source(file.path(here, "..", "..", "..", "tests", "testthat", "helper-availability-v0-2-0-1-witnesses.R"),
           envir = s4_v201)
s4_v201_run <- function(name, ...) {
  fx <- s4_v201$availability_v201_fold_fixture()
  db <- build(name, function(db) ledgr::ledgr_snapshot_from_df(fx$bars, instruments_df = fx$instruments,
    db_path = db, snapshot_id = name, facts = fx$facts, price_basis = "split_adjusted"))
  collect(db, name, paste0("s4-", name), function(snapshot) ledgr::ledgr_experiment(snapshot,
    s4_v201$availability_v201_fold_strategy, universe = ledgr::ledgr_universe_members("U"),
    cost_model = ledgr::ledgr_cost_zero(), opening = ledgr::ledgr_opening(cash = 1e6), ...), seed = 7L)
}
s4_facts_closes <- function(n_days = 10L) list(A = 10 + seq_len(n_days) / 10, B = 20 + seq_len(n_days) / 5,
  C = 30 - seq_len(n_days) / 10, D = 40 + seq_len(n_days) / 4, E = 50 - seq_len(n_days) / 5)
# A run expected to fail: its store tables and the condition's class vector,
# message, reason and affected instrument ids (decision 10, cut review R7).
s4_cond_run <- function(name, closes, facts, exp) {
  db <- s4_snapshot(name, closes, facts)
  snapshot <- ledgr::ledgr_snapshot_open(db, name, verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot))
  run_id <- paste0("s4-", name)
  e <- tryCatch({ close(ledgr::ledgr_run(exp(snapshot), run_id = run_id, seed = 21L)); NULL }, error = identity)
  cond <- data.frame(class = paste(class(e), collapse = "/"), message = if (is.null(e)) "" else conditionMessage(e),
    reason = as.character(e$reason %||% ""), instrument_ids = paste(as.character(e$instrument_ids), collapse = ","),
    stringsAsFactors = FALSE)
  list(run = c(a0_store_tables(db, run_id), list(condition = cond)))
}
# Strategy reads recorded in the intent reason (cut review R5): the context,
# the portfolio state `n` and the asset state `cnt` as read; then it holds,
# n counts the pulse and cnt each context instrument.
s4_state_strategy <- function(ctx, params) {
  cnt <- ctx$state$cnt
  ledgr::ledgr_strategy_result(ctx$hold(), n = ctx$state$n + 1L, cnt = cnt + 1,
    intent_reason = sprintf("n=%d;%s", ctx$state$n, paste(names(cnt), cnt, sep = "=", collapse = ",")))
}
# The strict subset (cut review R5): the context is D and B of A..E, then B,
# C, E with D a held nonmember. The strategy records its bar, feature and
# history reads; it buys B and D on day 2, is refused 30 more B for cash on
# day 4, sells 6 B on day 8; a context kept on day 3 (its feature unread) is
# read on day 7, after the context changed.
s4_subset_strategy <- function() {
  kept <- new.env(parent = emptyenv())
  function(ctx, params) {
    day <- substr(ctx$ts_utc, 1L, 10L)
    t <- ctx$hold()
    read <- paste(ctx$universe, round(ctx$close, 4), sep = ":", collapse = ",")
    if (day != "2020-01-03") read <- paste(read, paste(round(ctx$sma, 4), collapse = ","))
    if (day >= "2020-01-03") read <- paste(read, paste(round(ledgr::ledgr_history_matrix(ctx, bar = "close",
      lookback = 2L)[1L, ], 4), collapse = ","))
    if (day == "2020-01-02") t[c("B", "D")] <- c(10, 5)
    if (day == "2020-01-03") kept$ctx <- ctx
    if (day == "2020-01-04") t[["B"]] <- 40
    if (day == "2020-01-07") read <- paste(read, "| kept", paste(kept$ctx$universe, collapse = ","),
      round(kept$ctx$close[["D"]], 4), paste(round(kept$ctx$sma, 4), collapse = ","))
    if (day == "2020-01-08") t[["B"]] <- 4
    list(targets = t, intent_reason = read)
  }
}

loop_slice4 <- c(loop_slice4, list(
  # Trading status only (the probe's): B halted on days 4-6, learned after
  # the day-3 decision, so its day-3 buy meets the halt at execution.
  s4_halt = function() {
    status <- ledgr::ledgr_facts_trading_status(data.frame(fact_id = c("a", "b", "c", "b-halt"),
      instrument_id = c("A", "B", "C", "B"), effective_from = c(rep(s4_at(1L, "00:00:00"), 3L), s4_at(4L, "00:00:00")),
      effective_to = c(rep(as.POSIXct(NA, tz = "UTC"), 3L), s4_at(7L, "00:00:00")),
      knowledge_time = c(rep(s4_at(1L, "00:00:00") - 3600, 3L), s4_at(3L) + 3600), status = c(rep("active", 3L), "halted"),
      source = "s4", precedence = c(0L, 0L, 0L, 5L), stringsAsFactors = FALSE))
    s4_run("s4_halt", s4_closes(), ledgr::ledgr_facts(s4_sessions(10L), status),
      s4_exp(s4_strategy(s4_plan(list(2L, c(B = 5)), list(3L, c(B = 9)), list(8L, c(B = 0))))))
  },
  # The v0.2.0.1 availability witness with the default policies (the
  # probe's): membership changes, halts, a stale mark and a delisting.
  s4_v201_default = function() s4_v201_run("s4_v201_default",
    valuation_policy = ledgr::ledgr_valuation_stale(max_sessions = 2L)),
  # Membership entry and exit: A, bought on day 3, leaves the universe on
  # day 4 (known after the decision), so its fill reports
  # membership_changed_before_execution; it stays as a held nonmember at
  # context ordinal 4 (run position 1), is reduced on day 6; D enters.
  s4_membership = function() s4_run("s4_membership", s4_facts_closes(),
    ledgr::ledgr_facts(s4_sessions(10L), s4_universe(list("1" = c("A", "B", "C"), "4" = c("B", "C", "D")))),
    s4_members_exp(s4_strategy(s4_plan(list(1L, c(B = 3)), list(3L, c(A = 4)), list(5L, c(D = 2)), list(6L, c(A = 1)))))),
  # A held nonmember's exposure increased on day 5: refused.
  s4_nonmember_increase = function() s4_cond_run("s4_nonmember_increase", s4_facts_closes(),
    ledgr::ledgr_facts(s4_sessions(10L), s4_universe(list("1" = c("A", "B", "C"), "4" = c("B", "C", "D")))),
    s4_members_exp(s4_strategy(s4_plan(list(1L, c(B = 3)), list(3L, c(A = 4)), list(5L, c(A = 6)))))),
  # A target change on a halted instrument: refused.
  s4_restricted_target = function() s4_cond_run("s4_restricted_target", s4_facts_closes(),
    ledgr::ledgr_facts(s4_sessions(10L), ledgr::ledgr_facts_trading_status(rbind(s4_trading("A", "active", 1L),
      s4_trading("B", "active", 1L, 3L), s4_trading("B", "halted", 3L), s4_trading("C", "active", 1L)))),
    s4_exp(s4_strategy(s4_plan(list(1L, c(A = 2)), list(4L, c(B = 5)))))),
  # The quotation_only, status_unknown and status_unknown_or_conflicting
  # restrictions: A quotation_only from day 4 (its day-3 sale meets it at
  # execution), B with no status fact, C conflicting from day 5 (two tied
  # sources; its day-4 buy meets it at execution).
  s4_restrictions = function() s4_run("s4_restrictions", s4_facts_closes(),
    ledgr::ledgr_facts(s4_sessions(10L), ledgr::ledgr_facts_trading_status(rbind(s4_trading("A", "active", 1L, 4L),
      s4_trading("A", "quotation_only", 4L), s4_trading("C", "active", 1L), s4_trading("C", "halted", 5L, NA, "s4-alt"),
      s4_trading("D", "active", 1L), s4_trading("E", "active", 1L)))),
    s4_exp(s4_strategy(s4_plan(list(1L, c(A = 4, C = 3, D = 2)), list(3L, c(A = 0)), list(4L, c(C = 6)))))),
  # Asset-scoped state across context changes (cut review R5): the context
  # shrinks from A, B to B, through zero (days 4-5: the strategy is called
  # with an empty axis and one empty_public_domain row each), and grows to
  # A (re-entering with its default) and C (an entrant); n continues.
  s4_state_context = function() s4_run("s4_state_context", s4_facts_closes(),
    ledgr::ledgr_facts(s4_sessions(10L), s4_universe(list("1" = c("A", "B"), "3" = "B", "4" = character(), "6" = c("A", "C")))),
    s4_members_exp(s4_state_strategy, portfolio_state = list(n = 0L), asset_state = list(cnt = 0))),
  # No members but a held nonmember (cut review R5): A, bought on day 1,
  # stays on the context alone from day 3 under the ordinary rules and is
  # reduced on day 4; no empty_public_domain row.
  s4_no_members_held = function() s4_run("s4_no_members_held", s4_facts_closes(),
    ledgr::ledgr_facts(s4_sessions(10L), s4_universe(list("1" = c("A", "B"), "3" = character()))),
    s4_members_exp(s4_strategy(s4_plan(list(1L, c(A = 4)), list(4L, c(A = 2)))))),
  # A noncontiguous strict subset of the run axis, with features and history.
  s4_subset = function() s4_run("s4_subset", s4_facts_closes(),
    ledgr::ledgr_facts(s4_sessions(10L), s4_universe(list("1" = c("D", "B"), "6" = c("B", "C", "E")))),
    s4_members_exp(s4_subset_strategy(), cash = 1000,
      features = ledgr::ledgr_feature_map(sma = ledgr::ledgr_ind_ttr("SMA", input = "close", n = 2L)))),
  # Stale marks with facts: B has no bars on days 4-5 (a stale mark under
  # ledgr_valuation_stale(2)) while C is halted on days 6-7.
  s4_stale_facts = function() {
    closes <- s4_facts_closes()
    closes$B[4:5] <- NA
    s4_run("s4_stale_facts", closes, ledgr::ledgr_facts(s4_sessions(10L), ledgr::ledgr_facts_trading_status(rbind(
      s4_trading("A", "active", 1L), s4_trading("B", "active", 1L), s4_trading("C", "active", 1L, 6L),
      s4_trading("C", "halted", 6L, 8L), s4_trading("C", "active", 8L, NA, "s4-lift")))),
      s4_exp(s4_strategy(s4_plan(list(2L, c(B = 5, C = 2)))), valuation_policy = ledgr::ledgr_valuation_stale(2L)))
  },
  # A one-worker sweep over membership facts.
  s4_facts_sweep = function() s4_ca_sweep("s4_facts_sweep", s4_facts_closes(),
    ledgr::ledgr_facts(s4_sessions(10L), s4_universe(list("1" = c("A", "B", "C"), "4" = c("B", "C", "D")))),
    s4_members_exp(s4_strategy(s4_plan(list(1L, c(B = 3)), list(3L, c(A = 4)), list(5L, c(D = 2))))))
))

# Branch reach for LDG-3246, on the pin's tables.
s4_rows <- function(t, stage, outcome, reason, path = "run") {
  d <- t[[path]]$run_diagnostics
  d[d$stage == stage & d$outcome == outcome & d$reason_code == reason, , drop = FALSE]
}
s4_implicit <- function(t) t$run$run_diagnostic_implicit
s4_cond_reach <- function(class, reason, ids) function(t) {
  c <- t$run$condition
  NROW(c) == 1L && startsWith(c$class, paste0(class, "/")) && c$reason == reason && c$instrument_ids == ids &&
    grepl(ids, c$message, fixed = TRUE)
}

loop_reach <- c(loop_reach, list(
  # B's day-3 buy meets the halt at execution; B's decision cells while halted.
  s4_halt = function(t) {
    nf <- s4_rows(t, "execution", "no_fill", "trading_halted")
    nrow(nf) >= 1L && all(nf$instrument_id == "B") &&
      nrow(s4_rows(t, "decision", "recorded", "trading_halted")) >= 1L
  },
  s4_v201_default = function(t) {
    d <- t$run$run_diagnostics
    all(c("membership_changed_before_execution", "final_pulse_no_execution", "execution_bar_missing",
          "stale_mark_pass_through") %in% d$reason_code)
  },
  # A's fill reports the membership change; A's day-4 hold is a held
  # nonmember at context ordinal 4: decision_order (4 - 1) x 5 + 1 = 16.
  s4_membership = function(t) {
    f <- s4_rows(t, "execution", "filled", "membership_changed_before_execution")
    im <- s4_implicit(t)
    a4 <- im[im$instrument_id == "A" & s4_day(im$ts_utc) == "2020-01-04", , drop = FALSE]
    nrow(f) == 1L && f$instrument_id == "A" && nrow(a4) == 1L && s4_num(a4$decision_order) == 16
  },
  s4_nonmember_increase = s4_cond_reach("ledgr_nonmember_exposure_increase", "nonmember_exposure_increase", "A"),
  s4_restricted_target = s4_cond_reach("ledgr_restricted_target", "restricted_target", "B"),
  s4_restrictions = function(t) {
    nf <- function(r) s4_rows(t, "execution", "no_fill", r)$instrument_id
    identical(nf("quotation_only"), "A") && identical(nf("status_unknown_or_conflicting"), "C") &&
      all(s4_rows(t, "decision", "recorded", "status_unknown")$instrument_id == "B") &&
      nrow(s4_rows(t, "decision", "recorded", "status_unknown")) >= 1L
  },
  # The recorded reads: B keeps its count when A leaves, the empty axis
  # keeps n, A re-enters with its default and C enters with it; one
  # empty_public_domain row on each empty day.
  s4_state_context = function(t) {
    r <- s4_intents(t)
    e <- s4_rows(t, "decision", "recorded", "empty_public_domain")
    identical(unname(r[c("2020-01-03", "2020-01-04", "2020-01-05", "2020-01-06")]), c("n=2;B=2", "n=3;", "n=4;", "n=5;A=0,C=0")) &&
      identical(s4_day(e$ts_utc), c("2020-01-04", "2020-01-05")) && identical(s4_status(t), "DONE")
  },
  # From day 3 only A is decided (held nonmember), no empty row; A reduced.
  s4_no_members_held = function(t) {
    d <- t$run$run_diagnostics
    im <- s4_implicit(t)
    late <- function(x) x$instrument_id[s4_day(x$ts_utc) >= "2020-01-03" & x$stage %in% c("decision", NA)]
    nrow(s4_rows(t, "decision", "recorded", "empty_public_domain")) == 0L &&
      all(im$instrument_id[s4_day(im$ts_utc) >= "2020-01-03"] == "A") && any(s4_day(im$ts_utc) >= "2020-01-03") &&
      any(t$run$fills$instrument_id == "A" & t$run$fills$side == "SELL")
  },
  # No row for A (never on the context); D's day-7 hold at ordinal 4 has
  # decision_order 19, B's at ordinal 1 has 2; the day-4 refusal maps to B.
  s4_subset = function(t) {
    d <- t$run$run_diagnostics
    im <- s4_implicit(t)
    d7 <- im[s4_day(im$ts_utc) == "2020-01-07", , drop = FALSE]
    rej <- s4_rows(t, "execution", "no_fill", "insufficient_cash")
    !any(d$instrument_id %in% "A") && !any(im$instrument_id %in% "A") && !any(t$run$fills$instrument_id %in% "A") &&
      identical(s4_num(d7$decision_order[d7$instrument_id == "D"]), 19) &&
      identical(s4_num(d7$decision_order[d7$instrument_id == "B"]), 2) &&
      identical(rej$instrument_id, "B") && sum(t$run$fills$side == "BUY") == 2L
  },
  s4_stale_facts = function(t) {
    nrow(s4_rows(t, "risk", "passed", "stale_mark_pass_through")) >= 1L &&
      nrow(s4_rows(t, "decision", "recorded", "trading_halted")) >= 1L
  },
  s4_facts_sweep = function(t) {
    s <- t$sweep$sweep
    f <- t$sweep$memory_fills
    NROW(s) == 1L && identical(as.character(s$status), "DONE") && any(f$instrument_id == "D")
  }
))
