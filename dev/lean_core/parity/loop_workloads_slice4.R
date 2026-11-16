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

# The pin refuses no slice-4 input here; the lean loop refuses what later
# tickets cover (loop_expect_refused, loop_workloads.R).
loop_expect_refused <- c(loop_expect_refused, list(s4_carried = "corporate actions"))

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
