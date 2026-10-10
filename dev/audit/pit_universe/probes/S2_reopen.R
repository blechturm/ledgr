# Stage 2 probe (analyst): the facts reopen path in ledgr_snapshot_open()
# (Gate 1 carried open item). Seals the full-status fixture, runs the probe
# strategy on the handle returned by ledgr_snapshot_from_df(), closes it,
# reopens the store with ledgr_snapshot_open(verify = TRUE) and with
# verify = FALSE, and compares: handle metadata, experiment data identity,
# the experiment plan, fact inspection, config_hash and the run's equity,
# ledger and diagnostics.
#
#   sh dev/audit/pit_universe/run_low.sh dev/audit/pit_universe/probes/S2_reopen.R <log>
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all("C:/tmp/ws22-b", quiet = TRUE, compile = FALSE))
source("C:/Users/maxth/Documents/GitHub/ledgr/dev/audit/pit_universe/fixture.R")
options(width = 200, warn = 1)
fx <- pit_audit_fixture("announcement", status_coverage = "full")
db <- file.path(tempdir(), "S2_reopen.duckdb")
strategy <- function(ctx, params) { t <- ctx$hold(); ids <- ctx$tradable(); if (length(ids)) t[ids] <- params$qty; t }
mk <- function(s) ledgr_experiment(s, strategy, universe = ledgr_universe_members(fx$universe_id),
                                   valuation_policy = ledgr_valuation_stale(3), cost_model = ledgr_cost_zero(),
                                   opening = ledgr_opening(cash = 1e5))
grab <- function(s, rid) {
  exp <- mk(s)
  bt <- ledgr_run(exp, params = list(qty = 10), run_id = rid)
  on.exit(close(bt))
  list(meta = s$metadata, data_identity = exp$data_identity, availability = exp$availability[c("active", "declared_families")],
       plan = capture.output(print(ledgr_experiment_plan(exp))),
       hist = ledgr_facts_history(s, "membership", scope_id = fx$universe_id)$rows,
       config_hash = config_hash(bt$config),
       equity = as.data.frame(ledgr_results(bt, "equity"))[, c("ts_utc", "cash", "positions_value", "equity")],
       ledger = as.data.frame(ledgr_results(bt, "ledger"))[, c("ts_utc", "event_type", "instrument_id", "qty", "price")],
       diag = as.data.frame(ledgr_results(bt, "diagnostics"))[, c("ts_utc", "instrument_id", "stage", "reason_code")],
       info = ledgr_snapshot_info(s)[, c("snapshot_hash", "start_date", "end_date")])
}
s0 <- pit_audit_snapshot(fx, db_path = db)
sid <- s0$snapshot_id
a <- grab(s0, "orig")
ledgr_snapshot_close(s0)
for (verify in c(TRUE, FALSE)) {
  s1 <- tryCatch(ledgr_snapshot_open(db, sid, verify = verify), error = identity)
  if (inherits(s1, "error")) { cat("[verify=", verify, "] open ERROR ", conditionMessage(s1), "\n", sep = ""); next }
  b <- grab(s1, paste0("reopened_", verify))
  ledgr_snapshot_close(s1)
  same <- vapply(names(a), function(n) identical(a[[n]], b[[n]]), logical(1))
  cat(sprintf("[verify=%s] identical: %s\n", verify, paste(names(same), same, sep = "=", collapse = " ")))
  if (!same[["meta"]]) {
    cat("   metadata names orig:", paste(sort(names(a$meta)), collapse = ","), "\n")
    cat("   metadata names reopened:", paste(sort(names(b$meta)), collapse = ","), "\n")
    common <- intersect(names(a$meta), names(b$meta))
    cat("   differing common fields:", paste(common[!vapply(common, function(n) identical(a$meta[[n]], b$meta[[n]]), logical(1))], collapse = ","), "\n")
  }
  if (!same[["data_identity"]]) cat("   data_identity orig:", format(unlist(a$data_identity)), " reopened:", format(unlist(b$data_identity)), "\n")
}
