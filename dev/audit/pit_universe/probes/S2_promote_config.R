# Stage 2 probe (analyst): promotion from a differently configured experiment
# (Gate 1 carried open item). A sweep runs under experiment A (membership
# universe, stale(3), research corporate-action preset, cash 1e5, strategy
# fA). Its qty-10 candidate is promoted into experiments that differ from A
# in exactly one input. Prints whether promotion refuses, the promoted run's
# final equity against the candidate's, and the stored promotion context.
#
#   sh dev/audit/pit_universe/run_low.sh dev/audit/pit_universe/probes/S2_promote_config.R <log>
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all("C:/tmp/ws22-b", quiet = TRUE, compile = FALSE))
source("C:/Users/maxth/Documents/GitHub/ledgr/dev/audit/pit_universe/fixture.R")
options(width = 200, warn = 1)
fx <- pit_audit_fixture("announcement", status_coverage = "full")
db <- file.path(tempdir(), "S2_promote.duckdb")
snap <- pit_audit_snapshot(fx, db_path = db)
fA <- function(ctx, params) { t <- ctx$hold(); ids <- ctx$tradable(); if (length(ids)) t[ids] <- params$qty; t }
fB <- function(ctx, params) { t <- ctx$hold(); ids <- ctx$tradable(); if (length(ids)) t[ids] <- 2 * params$qty; t }
mk <- function(strategy = fA, universe = ledgr_universe_members(fx$universe_id), valuation = ledgr_valuation_stale(3),
               ca = ledgr_corporate_actions_research(), cash = 1e5) {
  ledgr_experiment(snap, strategy, universe = universe, valuation_policy = valuation,
                   cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = cash), corporate_action_policy = ca)
}
expA <- mk()
sw <- ledgr_sweep(expA, ledgr_param_grid(q10 = list(qty = 10)))
cand <- ledgr_candidate(sw, which = 1L)
cat(sprintf("[A] sweep candidate status %s final equity %s; provenance fields: %s\n", sw$status[[1]],
            format(sw$final_equity[[1]], nsmall = 2), paste(names(cand$provenance), collapse = ",")))
variants <- list(
  same = mk(),
  basket_universe = mk(universe = c("AAA", "BBB", "NNN", "FFF", "HHH")),
  stale0_refuse = mk(valuation = ledgr_valuation_stale(0, exhausted = "refuse")),
  strict_ca = mk(ca = ledgr_corporate_actions_strict()),
  cash_5e4 = mk(cash = 5e4),
  other_strategy = mk(strategy = fB)
)
for (nm in names(variants)) {
  bt <- tryCatch(ledgr_promote(variants[[nm]], cand, run_id = paste0("promote_", nm)), error = identity)
  if (inherits(bt, "error")) { cat(sprintf("[%s] promote refused/failed: %s - %s\n", nm, class(bt)[[1]], conditionMessage(bt))); next }
  eq <- ledgr_results(bt, "equity")
  ctx <- tryCatch(ledgr_run_info(snap, paste0("promote_", nm)), error = identity)
  cat(sprintf("[%s] promoted: status %s final equity %s (candidate %s); equal: %s\n", nm,
              ctx$status, format(tail(eq$equity, 1), nsmall = 2), format(sw$final_equity[[1]], nsmall = 2),
              isTRUE(all.equal(tail(eq$equity, 1), sw$final_equity[[1]], tolerance = 0))))
  close(bt)
}
con <- DBI::dbConnect(duckdb::duckdb(), db, read_only = TRUE)
pc <- DBI::dbGetQuery(con, "SELECT run_id FROM run_promotion_context ORDER BY run_id")
DBI::dbDisconnect(con, shutdown = TRUE)
cat("[context] promotion context rows:", paste(pc$run_id, collapse = ","), "\n")
ledgr_snapshot_close(snap)
