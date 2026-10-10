# Stage 1 probe (integrator, handoff from reader A, A-019): a corporate-action
# row without knowledge_time. The HHH dividend of the shared fixture (full
# status coverage) is rebuilt with knowledge_time = NA; the strategy buys HHH
# at s1 and holds. Prints the validation outcome, CASHFLOW events and the
# corporate-action summary. Description only.
#
#   sh dev/audit/pit_universe/run_low.sh dev/audit/pit_universe/probes/I_ca_knowledge.R <log>
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all("C:/tmp/ws22-b", quiet = TRUE, compile = FALSE))
source("C:/Users/maxth/Documents/GitHub/ledgr/dev/audit/pit_universe/fixture.R")
options(width = 200, warn = 1)
iso <- function(x) format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

fx <- pit_audit_fixture("announcement", status_coverage = "full")
close_at <- function(k) pit_audit_at(fx$sessions[k], if (k == 30L) "13:00:00" else "16:00:00")
ca <- data.frame(
  fact_id = "hhh-div", subtype = "ordinary_cash_dividend", parent_instrument_id = "HHH",
  entitlement_time = close_at(14), effective_time = close_at(15),
  knowledge_time = as.POSIXct(NA, tz = "UTC"), payment_time = close_at(25),
  complete = TRUE, provenance_tier = "snapshot_bound",
  gross_cash_per_parent_unit = 1, gross_cash_validated = TRUE,
  recipient_instrument_id = NA_character_, recipient_identity_validated = FALSE,
  recipient_quantity_per_parent_unit = NA_real_, recipient_quantity_validated = FALSE,
  source = "audit_fixture", stringsAsFactors = FALSE
)
fx$families$corporate_actions <- ledgr_facts_equity_corporate_actions(ca)
facts <- do.call(ledgr_facts, unname(fx$families))
rep <- ledgr_facts_validate(facts, fx$bars, fx$instruments)
cat("[K1 validate]", paste(utils::head(capture.output(print(rep)), 12), collapse = " / "), "\n")
db <- file.path(tempdir(), "I_ca_knowledge.duckdb")
snap <- pit_audit_snapshot(fx, db_path = db)
buy <- function(ctx, params) { t <- ctx$hold(); if (identical(ctx$ts_utc, params$t1)) t[["HHH"]] <- 10; t }
exp <- ledgr_experiment(snap, buy, universe = ledgr_universe_members(fx$universe_id),
                        valuation_policy = ledgr_valuation_stale(3), cost_model = ledgr_cost_zero(),
                        opening = ledgr_opening(cash = 1e5))
bt <- ledgr_run(exp, params = list(t1 = iso(close_at(1))), run_id = "K-na-knowledge")
led <- ledgr_results(bt, "ledger")
cat("[K1 run] status", ledgr_run_info(snap, bt$run_id)$status, "; events",
    paste(names(table(led$event_type)), table(led$event_type), sep = "=", collapse = " "), "\n")
cs <- ledgr_corporate_action_summary(bt)
cat("[K1 summary] fidelity", cs$corporate_action_fidelity, "; gross cash", cs$gross_cash_posted,
    "; unsupported facts", cs$unsupported_facts, "\n")
close(bt)
ledgr_snapshot_close(snap)
