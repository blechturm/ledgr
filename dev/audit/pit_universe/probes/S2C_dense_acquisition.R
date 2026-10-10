# Stage 2 challenger probe (judged-consistent item PIT-10-002): can a dense
# run reach a held cash acquisition? Corporate-action facts alone do not
# activate availability, and dense needs full bar coverage, which a vendor
# that keeps printing after the deal (or a fact effective inside the bars)
# satisfies. CCC bars s1..s40 (49 then a flat 49.80 from s18), complete
# cash_acquisition fact effective s19 at $50, held 10 from s1; no other
# fact family. Research and strict presets: status, CCC events, final CCC
# position, corporate-action summary.
#
#   sh dev/audit/pit_universe/run_low.sh dev/audit/pit_universe/probes/S2C_dense_acquisition.R <log>
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all("C:/tmp/ws22-b", quiet = TRUE, compile = FALSE))
source("C:/Users/maxth/Documents/GitHub/ledgr/dev/audit/pit_universe/fixture.R")
options(width = 200, warn = 1)
iso <- function(x) format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
fx <- pit_audit_fixture("announcement")
close_at <- function(k) pit_audit_at(fx$sessions[k], if (k == 30L) "13:00:00" else "16:00:00")
ts <- do.call(c, lapply(1:40, close_at))
bars <- rbind(
  data.frame(instrument_id = "AAA", ts_utc = ts, open = 40, high = 40, low = 40, close = 40, volume = 1000),
  data.frame(instrument_id = "CCC", ts_utc = ts, open = c(rep(49, 17), rep(49.8, 23)), high = c(rep(49, 17), rep(49.8, 23)),
             low = c(rep(49, 17), rep(49.8, 23)), close = c(rep(49, 17), rep(49.8, 23)), volume = 1000)
)
ca <- ledgr_facts_equity_corporate_actions(data.frame(
  fact_id = "ccc-cash", subtype = "cash_acquisition", parent_instrument_id = "CCC",
  entitlement_time = close_at(18), effective_time = close_at(19), knowledge_time = close_at(1) - 3600,
  payment_time = close_at(20), complete = TRUE, provenance_tier = "snapshot_bound",
  gross_cash_per_parent_unit = 50, gross_cash_validated = TRUE,
  recipient_instrument_id = NA_character_, recipient_identity_validated = FALSE,
  recipient_quantity_per_parent_unit = NA_real_, recipient_quantity_validated = FALSE,
  source = "s2c", stringsAsFactors = FALSE))
snap <- ledgr_snapshot_from_df(bars, data.frame(instrument_id = c("AAA", "CCC")), db_path = tempfile(fileext = ".duckdb"),
                               facts = ledgr_facts(ca), price_basis = "split_adjusted")
hold <- function(ctx, params) { t <- ctx$hold(); if (ctx$ts_utc == params$t1) t[["CCC"]] <- 10; t }
for (preset in c("research", "strict")) {
  pol <- if (preset == "research") ledgr_corporate_actions_research() else ledgr_corporate_actions_strict()
  exp <- ledgr_experiment(snap, hold, universe = c("AAA", "CCC"), cost_model = ledgr_cost_zero(),
                          opening = ledgr_opening(cash = 1e4), corporate_action_policy = pol)
  bt <- tryCatch(ledgr_run(exp, params = list(t1 = iso(close_at(1))), run_id = preset), error = identity)
  if (inherits(bt, "error")) { cat(sprintf("[%s] run ERROR %s - %s\n", preset, class(bt)[[1]], conditionMessage(bt))); next }
  led <- ledgr_results(bt, "ledger"); led <- led[led$instrument_id == "CCC", ]
  eq <- ledgr_results(bt, "equity")
  cs <- ledgr_corporate_action_summary(bt)
  scal <- cs[vapply(cs, function(v) is.atomic(v) && length(v) == 1L, logical(1))]
  cat(sprintf("[%s] status %s; availability active %s; CCC events %s; final equity %s\n", preset, ledgr_run_info(snap, preset)$status,
              isTRUE(bt$config$availability$active), paste(iso(led$ts_utc), led$event_type, collapse = " | "),
              format(tail(eq$equity, 1), nsmall = 2)))
  cat(sprintf("[%s] summary: %s\n", preset, paste(names(scal), unlist(lapply(scal, format)), sep = "=", collapse = " ")))
  close(bt)
}
ledgr_snapshot_close(snap)
