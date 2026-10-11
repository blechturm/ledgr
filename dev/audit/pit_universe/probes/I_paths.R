# Stage 1 probe (integrator): one strategy through every public point-in-time
# path on the shared fixture. Description only: prints what each path did and
# whether paths agree; asserts nothing.
#
# Cases
#   P1 run         full status coverage, membership universe
#   P2 sweep       two candidates (qty 5, 10); candidate qty 10 vs P1
#   P3 promote     candidate qty 10 promoted; vs P1 (equity, config_hash)
#   P4 resume      same strategy interrupted at s15, s19, s23 and resumed
#   P5 reconstruct ledgr_state_reconstruct() on P1, then the readers
#   P6 readers     results tables, explain, completion, summaries, compare
#   P7 declared    P1 on the default fixture (status for FFF and EEE only)
#   P8 basket      P1 with a character-vector universe (fixed basket)
#   P9 dense       bars only (no facts) for five continuous instruments
#   P10 early      opening dated before the sealed start: run vs sweep start
#   P11 offbar     an extra AAA bar on a closed ad hoc weekday: ingest, run, evidence surfaces
#   P12 pulse      ledgr_pulse_snapshot() on the point-in-time snapshot
#   P13 backtest   ledgr_backtest() (lower-level wrapper) on the point-in-time
#                  snapshot; ledgr_indicator_dev() at a halted session
#
#   sh dev/audit/pit_universe/run_low.sh dev/audit/pit_universe/probes/I_paths.R <log>
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all("C:/tmp/ws22-b", quiet = TRUE, compile = FALSE))
source("C:/Users/maxth/Documents/GitHub/ledgr/dev/audit/pit_universe/fixture.R")
options(width = 200, warn = 1)

iso <- function(x) format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
say <- function(case, ...) cat(sprintf("[%s] %s\n", case, paste0(...)))
err <- function(e) paste("ERROR", class(e)[[1L]], "-", conditionMessage(e))

fx <- pit_audit_fixture("announcement", status_coverage = "full")
close_at <- function(k) pit_audit_at(fx$sessions[k], if (k == 30L) "13:00:00" else "16:00:00")
db <- file.path(tempdir(), "I_paths_full.duckdb")
snap <- pit_audit_snapshot(fx, db_path = db)

# Hold everything; set every tradable ID (admissible and priced) to qty.
strategy <- function(ctx, params) {
  t <- ctx$hold()
  ids <- ctx$tradable()
  if (length(ids)) t[ids] <- params$qty
  t
}
# Same targets; raises the soft interrupt at the pulse named by an option.
strategy_int <- function(ctx, params) {
  t <- ctx$hold()
  ids <- ctx$tradable()
  if (length(ids)) t[ids] <- params$qty
  stop_at <- getOption("probe.stop_at", NA_character_)
  if (!is.na(stop_at) && identical(ctx$ts_utc, stop_at)) options(ledgr.interrupt = TRUE)
  t
}
make_exp <- function(s, fn = strategy, universe = ledgr_universe_members(fx$universe_id),
                     opening = ledgr_opening(cash = 1e5)) {
  ledgr_experiment(s, fn, universe = universe, valuation_policy = ledgr_valuation_stale(3),
                   cost_model = ledgr_cost_zero(), opening = opening)
}
runs_row <- function(path, run_id) {
  con <- DBI::dbConnect(duckdb::duckdb(), path, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  r <- DBI::dbGetQuery(con, "SELECT run_id, status, config_hash, config_json FROM runs WHERE run_id = ?", params = list(run_id))
  cfg <- jsonlite::fromJSON(r$config_json, simplifyVector = FALSE)
  list(status = r$status, config_hash = r$config_hash,
       start = cfg$backtest$start_ts_utc %||% NA, end = cfg$backtest$end_ts_utc %||% NA)
}
ledger <- function(path, run_id) {
  con <- DBI::dbConnect(duckdb::duckdb(), path, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  DBI::dbGetQuery(con, "SELECT event_seq, ts_utc, event_type, instrument_id, side, qty, price FROM ledger_events WHERE run_id = ? ORDER BY event_seq", params = list(run_id))
}
reasons <- function(bt) {
  d <- tibble::as_tibble(bt, what = "diagnostics")
  rc <- d$reason_code; rc[is.na(rc) | !nzchar(rc)] <- "<empty>"
  tab <- table(paste(d$stage, rc, sep = ":"))
  paste(names(tab), tab, sep = "=", collapse = " ")
}
eq_of <- function(bt) { e <- ledgr_results(bt, "equity"); as.data.frame(e[, c("ts_utc", "cash", "positions_value", "equity")]) }

# ---- P1 run ---------------------------------------------------------------
exp <- make_exp(snap)
bt1 <- ledgr_run(exp, params = list(qty = 10), run_id = "I-run")
eq1 <- eq_of(bt1); rr1 <- runs_row(db, "I-run"); led1 <- ledger(db, "I-run")
say("P1 run", "status ", rr1$status, "; pulses ", nrow(eq1), "; final equity ", format(tail(eq1$equity, 1), nsmall = 2),
    "; events ", paste(names(table(led1$event_type)), table(led1$event_type), sep = "=", collapse = " "),
    "; cfg start ", rr1$start, " end ", rr1$end)
say("P1 run", "diagnostics ", reasons(bt1))
plan <- ledgr_experiment_plan(exp)
say("P1 plan", "families: ", paste(capture.output(print(plan))[1:min(12, length(capture.output(print(plan))))], collapse = " / "))

# ---- P2 sweep -------------------------------------------------------------
grid <- ledgr_param_grid(q5 = list(qty = 5), q10 = list(qty = 10))
sw <- tryCatch(ledgr_sweep(exp, grid), error = function(e) e)
if (inherits(sw, "error")) say("P2 sweep", err(sw)) else {
  say("P2 sweep", "columns: ", paste(names(sw), collapse = ","))
  say("P2 sweep", "status ", paste(sw$status, collapse = ","), "; final equity ", paste(format(sw$final_equity, nsmall = 2), collapse = ","))
  say("P2 sweep", "q10 final equity equals P1: ", isTRUE(all.equal(sw$final_equity[[2]], tail(eq1$equity, 1), tolerance = 0)))
  # ---- P3 promote ---------------------------------------------------------
  cand <- ledgr_candidate(sw, which = 2L)
  bt3 <- tryCatch(ledgr_promote(exp, cand, run_id = "I-promote"), error = function(e) e)
  if (inherits(bt3, "error")) say("P3 promote", err(bt3)) else {
    eq3 <- eq_of(bt3); rr3 <- runs_row(db, "I-promote")
    say("P3 promote", "status ", rr3$status, "; equity identical to P1: ", identical(eq3, eq1),
        "; config_hash equal to P1: ", identical(rr3$config_hash, rr1$config_hash),
        "; cfg start ", rr3$start)
    cmp <- tryCatch(ledgr_run_compare(snap, c("I-run", "I-promote")), error = function(e) e)
    say("P6 compare", if (inherits(cmp, "error")) err(cmp) else paste(nrow(cmp), "rows; final equity", paste(format(cmp$final_equity, nsmall = 2), collapse = ",")))
    close(bt3)
  }
}

# ---- P4 interrupted then resumed -------------------------------------------
exp_int <- make_exp(snap, strategy_int)
options(probe.stop_at = NA_character_, ledgr.interrupt = FALSE)
bt4f <- ledgr_run(exp_int, params = list(qty = 10), run_id = "I-fresh")
eq4f <- eq_of(bt4f); close(bt4f)
for (k in c(15L, 19L, 23L, NA_integer_)) {
  options(probe.stop_at = if (is.na(k)) NA_character_ else iso(close_at(k)), ledgr.interrupt = FALSE)
  b <- tryCatch(ledgr_run(exp_int, params = list(qty = 10), run_id = "I-resumed"), error = function(e) e)
  if (inherits(b, "error")) { say("P4 resume", "attempt stop ", k, ": ", err(b)); break }
  say("P4 resume", "attempt stop at s", k, " -> status ", ledgr_run_info(snap, "I-resumed")$status,
      "; equity rows ", nrow(ledgr_results(b, "equity")))
  close(b)
}
options(probe.stop_at = NA_character_, ledgr.interrupt = FALSE)
bt4 <- ledgr_run_open(snap, "I-resumed")
eq4 <- eq_of(bt4)
led4f <- ledger(db, "I-fresh"); led4 <- ledger(db, "I-resumed")
say("P4 resume", "fresh equals P1 equity: ", identical(eq4f, eq1), "; resumed equals fresh equity: ", identical(eq4, eq4f),
    "; ledger rows fresh/resumed ", nrow(led4f), "/", nrow(led4), "; ledger content identical: ",
    identical(led4f[, -1], led4[, -1]))
close(bt4)

# ---- P5 reconstruct, then P6 readers -------------------------------------
before <- lapply(c("equity", "fills", "trades", "ledger", "diagnostics", "availability"),
                 function(w) tibble::as_tibble(bt1, what = w))
close(bt1)
con <- DBI::dbConnect(duckdb::duckdb(), db)
rec <- tryCatch(ledgr_state_reconstruct("I-run", con), error = function(e) e)
DBI::dbDisconnect(con, shutdown = TRUE)
if (inherits(rec, "error")) say("P5 reconstruct", err(rec)) else
  say("P5 reconstruct", "rows ", nrow(rec$equity_curve), "; equity identical to stored: ",
      identical(as.numeric(rec$equity_curve$equity), as.numeric(eq1$equity)),
      "; positions ", nrow(rec$positions))
bt1 <- ledgr_run_open(snap, "I-run")
after <- lapply(c("equity", "fills", "trades", "ledger", "diagnostics", "availability"),
                function(w) tibble::as_tibble(bt1, what = w))
say("P6 readers", "rows equity/fills/trades/ledger/diagnostics/availability: ",
    paste(vapply(after, nrow, 1L), collapse = "/"), "; unchanged by reconstruct: ",
    paste(mapply(identical, before, after), collapse = "/"))
fills <- ledgr_results(bt1, "fills")
say("P6 readers", "fill ts sample ", paste(utils::head(iso(fills$ts_utc), 2), collapse = " "),
    "; recording pulse sample ", paste(utils::head(iso(fills$recording_pulse_ts_utc), 2), collapse = " "),
    "; NA recording pulses ", sum(is.na(fills$recording_pulse_ts_utc)))
av <- ledgr_results(bt1, "availability")
say("P6 readers", "availability columns ", paste(names(av), collapse = ","))
nnn <- av[av$instrument_id == "NNN" & av$ts_utc %in% c(close_at(14), close_at(15), close_at(30)), c("ts_utc", "member", "held", "target_restricted")]
say("P6 readers", "NNN s14/s15/s30 member ", paste(nnn$member, collapse = ","), " held ", paste(nnn$held, collapse = ","))
ex <- tryCatch(ledgr_run_explain(bt1, "NNN", close_at(16)), error = function(e) e)
say("P6 explain", if (inherits(ex, "error")) err(ex) else paste(names(ex), unlist(lapply(ex, function(v) paste(format(v), collapse = ";"))), sep = "=", collapse = " "))
comp <- ledgr_run_completion(bt1)
say("P6 completion", "status ", comp$completion_status, "; complete ", comp$complete_performance,
    "; achieved end ", iso(comp$last_fully_valued_ts_utc), "; last executed ", iso(comp$last_executed_ts_utc))
vs <- ledgr_valuation_summary(bt1)
say("P6 valuation", "state ", vs$valuation_state)
cs <- ledgr_corporate_action_summary(bt1)
say("P6 corporate", "fidelity ", cs$corporate_action_fidelity, "; gross cash ", cs$gross_cash_posted,
    "; terminal outcomes ", nrow(cs$terminal_outcomes), " (", paste(cs$terminal_outcomes$instrument_id, cs$terminal_outcomes$choice, sep = ":", collapse = " "), ")")
out <- capture.output(summary(bt1))
say("P6 summary", "assumption/knowledge lines: ", paste(grep("assum|knowledge|effective", out, value = TRUE, ignore.case = TRUE), collapse = " / "))
close(bt1)

# ---- P7 declared status coverage (default fixture) -------------------------
fxd <- pit_audit_fixture("announcement")
dbd <- file.path(tempdir(), "I_paths_declared.duckdb")
snapd <- pit_audit_snapshot(fxd, db_path = dbd)
bt7 <- tryCatch(ledgr_run(make_exp(snapd), params = list(qty = 10), run_id = "I-declared"), error = function(e) e)
if (inherits(bt7, "error")) say("P7 declared", err(bt7)) else {
  led7 <- ledger(dbd, "I-declared")
  say("P7 declared", "status ", ledgr_run_info(snapd, "I-declared")$status, "; filled IDs ",
      paste(unique(led7$instrument_id[led7$event_type == "FILL"]), collapse = ","), "; final equity ",
      format(tail(eq_of(bt7)$equity, 1), nsmall = 2))
  say("P7 declared", "diagnostics ", reasons(bt7))
  close(bt7)
}
ledgr_snapshot_close(snapd)

# ---- P8 fixed basket -------------------------------------------------------
basket <- c("AAA", "BBB", "NNN", "FFF")
bt8 <- tryCatch(ledgr_run(make_exp(snap, universe = basket), params = list(qty = 10), run_id = "I-basket"), error = function(e) e)
if (inherits(bt8, "error")) say("P8 basket", err(bt8)) else {
  av8 <- ledgr_results(bt8, "availability")
  say("P8 basket", "status ", ledgr_run_info(snap, "I-basket")$status, "; member at every pulse ",
      paste(tapply(av8$member, av8$instrument_id, all), collapse = ","), " for ", paste(sort(unique(av8$instrument_id)), collapse = ","),
      "; restricted FFF pulses ", sum(av8$instrument_id == "FFF" & av8$target_restricted))
  close(bt8)
}

# ---- P9 dense (no facts) ---------------------------------------------------
dense_ids <- c("AAA", "BBB", "GGG", "HHH", "NNN")
snapn <- ledgr_snapshot_from_df(fx$bars[fx$bars$instrument_id %in% dense_ids, ], data.frame(instrument_id = dense_ids),
                                db_path = file.path(tempdir(), "I_paths_dense.duckdb"))
bt9 <- tryCatch(ledgr_run(ledgr_experiment(snapn, strategy, universe = dense_ids, cost_model = ledgr_cost_zero(),
                                           opening = ledgr_opening(cash = 1e5)),
                          params = list(qty = 10), run_id = "I-dense"), error = function(e) e)
if (inherits(bt9, "error")) say("P9 dense", err(bt9)) else {
  eq9 <- eq_of(bt9); f9 <- ledgr_results(bt9, "fills")
  say("P9 dense", "status ", ledgr_run_info(snapn, "I-dense")$status, "; pulses ", nrow(eq9),
      "; first fill ts ", iso(f9$ts_utc[1]), "; availability rows ", nrow(ledgr_results(bt9, "availability")),
      "; diagnostics rows ", nrow(ledgr_results(bt9, "diagnostics")), "; valuation ", ledgr_valuation_summary(bt9)$valuation_state)
  close(bt9)
}
ledgr_snapshot_close(snapn)

# ---- P10 opening dated before the sealed start ------------------------------
exp10 <- make_exp(snap, opening = ledgr_opening(cash = 1e5, date = "2021-02-01"))
bt10 <- tryCatch(ledgr_run(exp10, params = list(qty = 10), run_id = "I-early"), error = function(e) e)
if (inherits(bt10, "error")) say("P10 early", err(bt10)) else {
  rr10 <- runs_row(db, "I-early")
  say("P10 early", "run cfg start ", rr10$start, "; config_hash equal to P1: ", identical(rr10$config_hash, rr1$config_hash),
      "; equity identical to P1: ", identical(eq_of(bt10), eq1))
  close(bt10)
  sw10 <- tryCatch(ledgr_sweep(exp10, ledgr_param_grid(q10 = list(qty = 10))), error = function(e) e)
  if (inherits(sw10, "error")) say("P10 early", "sweep ", err(sw10)) else {
    say("P10 early", "sweep final equity equals P1: ", isTRUE(all.equal(sw10$final_equity[[1]], tail(eq1$equity, 1), tolerance = 0)))
    bt10p <- tryCatch(ledgr_promote(exp10, ledgr_candidate(sw10, 1L), run_id = "I-early-promote"), error = function(e) e)
    if (inherits(bt10p, "error")) say("P10 early", "promote ", err(bt10p)) else {
      rr10p <- runs_row(db, "I-early-promote")
      say("P10 early", "promoted cfg start ", rr10p$start, "; config_hash equal to I-early: ", identical(rr10p$config_hash, rr10$config_hash))
      close(bt10p)
    }
  }
}

# ---- P11 off-calendar bar --------------------------------------------------
fxo <- fx
extra <- fx$bars[fx$bars$instrument_id == "AAA", ][1, ]
extra$ts_utc <- pit_audit_at(fx$closed_adhoc[[1]], "16:00:00")
extra$open <- extra$high <- extra$low <- extra$close <- 999
fxo$bars <- rbind(fx$bars, extra)
rep11 <- tryCatch(ledgr_facts_validate(do.call(ledgr_facts, unname(fxo$families)), fxo$bars, fxo$instruments), error = function(e) e)
say("P11 offbar", "validate: ", if (inherits(rep11, "error")) err(rep11) else paste(capture.output(print(rep11))[1:min(8, length(capture.output(print(rep11))))], collapse = " / "))
snapo <- tryCatch(pit_audit_snapshot(fxo, db_path = file.path(tempdir(), "I_paths_off.duckdb")), error = function(e) e)
if (inherits(snapo, "error")) say("P11 offbar", "seal ", err(snapo)) else {
  seen <- new.env(); seen$ts <- character(); seen$aaa <- numeric()
  spy <- function(ctx, params) { seen$ts <- c(seen$ts, ctx$ts_utc); seen$aaa <- c(seen$aaa, ctx$close("AAA")); ctx$hold() }
  bt11 <- tryCatch(ledgr_run(make_exp(snapo, spy), run_id = "I-off"), error = function(e) e)
  if (inherits(bt11, "error")) say("P11 offbar", "run ", err(bt11)) else {
    say("P11 offbar", "sealed bars ", nrow(fxo$bars), "; pulses seen ", length(seen$ts), "; AAA close 999 seen: ", any(seen$aaa == 999, na.rm = TRUE),
        "; off-session ts seen: ", iso(extra$ts_utc) %in% seen$ts)
    # Cut 12 LDG-3011 evidence surfaces (absent on the pre-cut tree).
    q11 <- ledgr_snapshot_quarantine(snapo)
    say("P11 offbar", "snapshot info off_session_bar_count ", ledgr_snapshot_info(snapo)$off_session_bar_count %||% "absent",
        "; quarantine rows ", nrow(q11), " reasons ", paste(q11$reason, collapse = ","),
        "; dispositions ", paste(q11$disposition %||% "absent", collapse = ","))
    say("P11 offbar", "summary off-session line: ", paste(grep("Off-session", capture.output(summary(bt11)), value = TRUE), collapse = " "))
    close(bt11)
  }
  ledgr_snapshot_close(snapo)
}

# ---- P12 interactive pulse snapshot ---------------------------------------
pulse <- tryCatch(ledgr_pulse_snapshot(snap, universe = c("AAA", "BBB"), ts_utc = close_at(5)), error = function(e) e)
if (inherits(pulse, "error")) say("P12 pulse", err(pulse)) else {
  say("P12 pulse", "availability_active ", isTRUE(pulse$availability_active), "; members ", paste(pulse$members, collapse = ","),
      "; admissible ", paste(pulse$vec$admissible, collapse = ","))
  close(pulse)
}
pulse2 <- tryCatch(ledgr_pulse_snapshot(snap, universe = c("AAA", "FFF"), ts_utc = close_at(14)), error = function(e) e)
say("P12 pulse", "FFF at s14 (halted, no bar): ", if (inherits(pulse2, "error")) err(pulse2) else "built")
if (!inherits(pulse2, "error")) close(pulse2)

# ---- P13 lower-level wrapper and indicator dev ------------------------------
bt13 <- tryCatch(ledgr_backtest(snap, strategy, universe = c("AAA", "BBB", "GGG", "HHH", "NNN"),
                                strategy_params = list(qty = 10), cost_model = ledgr_cost_zero(),
                                run_id = "I-backtest"), error = function(e) e)
if (inherits(bt13, "error")) say("P13 backtest", err(bt13)) else {
  f13 <- ledgr_results(bt13, "fills"); av13 <- ledgr_results(bt13, "availability")
  say("P13 backtest", "status ", ledgr_run_info(snap, "I-backtest")$status, "; availability active in config: ",
      isTRUE(bt13$config$availability$active), "; pulses ", nrow(ledgr_results(bt13, "equity")),
      "; first fill ts ", iso(f13$ts_utc[1]), "; NNN member at every pulse: ", all(av13$member[av13$instrument_id == "NNN"]))
  close(bt13)
}
dev <- tryCatch(ledgr_indicator_dev(snap, "FFF", close_at(15), lookback = 5L), error = function(e) e)
say("P13 indicator_dev", if (inherits(dev, "error")) err(dev) else paste("built; class", class(dev)[[1]], "; bars rows", NROW(dev$bars)))
if (!inherits(dev, "error")) close(dev)

ledgr_snapshot_close(snap)
