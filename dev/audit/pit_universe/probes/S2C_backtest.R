# Stage 2 challenger probe (S2-004): is ledgr_backtest() wrong because it
# ignores membership, or because it ignores availability activation?
# ledgr_backtest() takes a character universe, which the Availability
# Contract calls a fixed basket. Compare, on the full fixture snapshot:
#   K  ledgr_run() with the same character basket c("AAA","BBB","NNN")
#   M  ledgr_run() with ledgr_universe_members() (the analyst's comparison)
#   B  ledgr_backtest() with the character basket
# and a second basket with FFF (halted s14-s15, no bars) to see whether the
# dense path refuses or silently trades.
#
#   sh dev/audit/pit_universe/run_low.sh dev/audit/pit_universe/probes/S2C_backtest.R <log>
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all("C:/tmp/ws22-b", quiet = TRUE, compile = FALSE))
source("C:/Users/maxth/Documents/GitHub/ledgr/dev/audit/pit_universe/fixture.R")
options(width = 200, warn = 1)
iso <- function(x) format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
err <- function(e) paste(class(e)[[1L]], "-", conditionMessage(e))
base <- pit_audit_fixture("announcement", status_coverage = "full")
snap <- pit_audit_snapshot(base, db_path = tempfile(fileext = ".duckdb"))
all3 <- function(ctx, params) { t <- ctx$hold(); ids <- if (is.function(ctx$tradable)) ctx$tradable() else ctx$universe; t[intersect(ids, names(t))] <- 10; t }
first <- function(l, id) { x <- l[l$instrument_id == id & l$event_type == "FILL", ]; if (nrow(x)) paste(iso(min(x$ts_utc)), nrow(x), "fills") else "none" }
basket <- c("AAA", "BBB", "NNN")
expK <- ledgr_experiment(snap, all3, universe = basket, valuation_policy = ledgr_valuation_stale(3),
                         cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1e5))
k <- ledgr_run(expK, run_id = "K_basket"); lk <- ledgr_results(k, "ledger")
cat(sprintf("[K ledgr_run basket] availability active %s; BBB %s; NNN %s; NNN last FILL qty sign %s\n",
            isTRUE(k$config$availability$active), first(lk, "BBB"), first(lk, "NNN"),
            paste(sign(lk$qty[lk$instrument_id == "NNN" & lk$event_type == "FILL"]), collapse = ",")))
close(k)
noval <- tryCatch(ledgr_experiment(snap, all3, universe = basket, cost_model = ledgr_cost_zero(),
                                   opening = ledgr_opening(cash = 1e5)), error = identity)
cat("[K2 experiment basket without valuation policy]:", if (inherits(noval, "error")) err(noval) else "accepted", "\n")
if (!inherits(noval, "error")) {
  r <- tryCatch(ledgr_run(noval, run_id = "K2"), error = identity)
  cat("[K2 run]:", if (inherits(r, "error")) err(r) else "returned", "\n")
}
# Since Cut 12 LDG-3001 ledgr_backtest() refuses this snapshot; record that.
b <- tryCatch(ledgr_backtest(snapshot = snap, strategy = all3, universe = basket, initial_cash = 1e5,
                             cost_model = ledgr_cost_zero(), run_id = "B_basket"), error = identity)
if (inherits(b, "error")) cat("[B ledgr_backtest basket]:", err(b), "\n") else {
  lb <- ledgr_results(b, "ledger")
  cat(sprintf("[B ledgr_backtest basket] availability active %s; BBB %s; NNN %s\n",
              isTRUE(b$config$availability$active), first(lb, "BBB"), first(lb, "NNN")))
  close(b)
}
# Basket with an instrument that is halted with no bars s14-s15 and one whose
# lifetime ends (KKK, bars s1-s12).
for (bk in list(c("AAA", "FFF"), c("AAA", "KKK"), c("AAA", "EEE"))) {
  bb <- tryCatch(ledgr_backtest(snapshot = snap, strategy = all3, universe = bk, initial_cash = 1e5,
                                cost_model = ledgr_cost_zero(), run_id = paste0("B_", paste(bk, collapse = ""))), error = identity)
  cat(sprintf("[B ledgr_backtest %s]: %s\n", paste(bk, collapse = ","), if (inherits(bb, "error")) err(bb) else {
    l <- ledgr_results(bb, "ledger"); s <- paste("returned; fills", sum(l$event_type == "FILL")); close(bb); s }))
}
ledgr_snapshot_close(snap)
