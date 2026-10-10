# Stage 2 probe (analyst): sealed corporate-action rows that never act, and
# what the result surfaces say about them; plus ledgr_backtest() on the same
# point-in-time snapshot.
#   D0 control: HHH ordinary_cash_dividend with knowledge_time
#   D1 subtype "cash_dividend" (any lower-snake-case subtype seals)
#   D2 ordinary_cash_dividend with knowledge_time NA
# Each holds 10 HHH from s1 under the research and the strict preset and
# prints run status, HHH CASHFLOW events and the corporate-action summary.
#   B1 ledgr_backtest() vs ledgr_run() (membership universe) on the full
#      fixture snapshot for AAA, BBB (member from s10), NNN (removed s15).
#
#   sh dev/audit/pit_universe/run_low.sh dev/audit/pit_universe/probes/S2_ca_inert.R <log>
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all("C:/tmp/ws22-b", quiet = TRUE, compile = FALSE))
source("C:/Users/maxth/Documents/GitHub/ledgr/dev/audit/pit_universe/fixture.R")
options(width = 200, warn = 1)
iso <- function(x) format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
base <- pit_audit_fixture("announcement", status_coverage = "full")
close_at <- function(k) pit_audit_at(base$sessions[k], if (k == 30L) "13:00:00" else "16:00:00")
div <- function(subtype, knowledge) ledgr_facts_equity_corporate_actions(data.frame(
  fact_id = "hhh-div", subtype = subtype, parent_instrument_id = "HHH",
  entitlement_time = close_at(14), effective_time = close_at(15), knowledge_time = knowledge,
  payment_time = close_at(25), complete = TRUE, provenance_tier = "snapshot_bound",
  gross_cash_per_parent_unit = 1, gross_cash_validated = TRUE,
  recipient_instrument_id = NA_character_, recipient_identity_validated = FALSE,
  recipient_quantity_per_parent_unit = NA_real_, recipient_quantity_validated = FALSE,
  source = "s2", stringsAsFactors = FALSE))
hold_hhh <- function(ctx, params) { t <- ctx$hold(); if (ctx$ts_utc == params$t1) t[["HHH"]] <- 10; t }
k0 <- pit_audit_at(base$sessions[1], "09:30:00") - 1
variants <- list(D0_control = div("ordinary_cash_dividend", k0), D1_cash_dividend = div("cash_dividend", k0),
                 D2_no_knowledge = div("ordinary_cash_dividend", as.POSIXct(NA, tz = "UTC")))
for (nm in names(variants)) {
  fx <- base; fx$families$corporate_actions <- variants[[nm]]
  rep <- ledgr_facts_validate(do.call(ledgr_facts, unname(fx$families)), fx$bars, fx$instruments)
  ca_out <- tryCatch({ f <- rep$facts; paste(f$outcome[f$family == "equity_corporate_actions"], collapse = ",") }, error = function(e) "<n/a>")
  snap <- pit_audit_snapshot(fx, db_path = tempfile(fileext = ".duckdb"))
  for (preset in c("research", "strict")) {
    pol <- if (preset == "research") ledgr_corporate_actions_research() else ledgr_corporate_actions_strict()
    exp <- ledgr_experiment(snap, hold_hhh, universe = ledgr_universe_members(base$universe_id),
                            valuation_policy = ledgr_valuation_stale(3), cost_model = ledgr_cost_zero(),
                            opening = ledgr_opening(cash = 1e5), corporate_action_policy = pol)
    bt <- tryCatch(ledgr_run(exp, params = list(t1 = iso(close_at(1))), run_id = paste(nm, preset)), error = identity)
    if (inherits(bt, "error")) { cat(sprintf("[%s %s] run ERROR %s - %s\n", nm, preset, class(bt)[[1]], conditionMessage(bt))); next }
    led <- ledgr_results(bt, "ledger")
    cs <- ledgr_corporate_action_summary(bt)
    scal <- cs[vapply(cs, function(v) is.atomic(v) && length(v) == 1L, logical(1))]
    cat(sprintf("[%s %s] validate CA outcome %s; status %s; HHH CASHFLOW rows %d; summary: %s\n", nm, preset, ca_out,
                ledgr_run_info(snap, paste(nm, preset))$status, sum(led$event_type == "CASHFLOW" & led$instrument_id == "HHH"),
                paste(names(scal), unlist(lapply(scal, format)), sep = "=", collapse = " ")))
    close(bt)
  }
  ledgr_snapshot_close(snap)
}

# ---- B1: ledgr_backtest() on the point-in-time snapshot -------------------------
snap <- pit_audit_snapshot(base, db_path = tempfile(fileext = ".duckdb"))
all3 <- function(ctx, params) { t <- ctx$hold(); ids <- if (is.function(ctx$tradable)) ctx$tradable() else ctx$universe; t[intersect(ids, names(t))] <- 10; t }
exp <- ledgr_experiment(snap, all3, universe = ledgr_universe_members(base$universe_id), valuation_policy = ledgr_valuation_stale(3),
                        cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1e5))
br <- ledgr_run(exp, run_id = "B1_run"); lr <- ledgr_results(br, "ledger"); close(br)
bb <- tryCatch(ledgr_backtest(snapshot = snap, strategy = all3, universe = c("AAA", "BBB", "NNN"), initial_cash = 1e5,
                              cost_model = ledgr_cost_zero(), run_id = "B1_backtest"), error = identity)
if (inherits(bb, "error")) cat("[B1] ledgr_backtest ERROR", conditionMessage(bb), "\n") else {
  lb <- ledgr_results(bb, "ledger")
  first <- function(l, id) { x <- l[l$instrument_id == id & l$event_type == "FILL", ]; if (nrow(x)) paste(iso(min(x$ts_utc)), "..", iso(max(x$ts_utc)), nrow(x), "fills") else "none" }
  for (id in c("BBB", "NNN")) cat(sprintf("[B1] %s fills: ledgr_run %s | ledgr_backtest %s\n", id, first(lr, id), first(lb, id)))
  cat(sprintf("[B1] ledgr_backtest availability active: %s; diagnostics rows %d\n", isTRUE(bb$config$availability$active),
              nrow(ledgr_results(bb, "diagnostics"))))
  close(bb)
}
ledgr_snapshot_close(snap)
