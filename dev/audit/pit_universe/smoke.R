# Smoke check for the audit fixture: both knowledge variants build, seal and
# run one holding strategy on the point-in-time universe. It records only
# whether each step completed; observations belong to Stage 1.
#
#   Rscript dev/audit/pit_universe/smoke.R <repo>
args <- commandArgs(trailingOnly = TRUE)
repo <- normalizePath(if (length(args)) args[[1L]] else ".", winslash = "/")
suppressMessages(pkgload::load_all(repo, quiet = TRUE))
source(file.path(repo, "dev/audit/pit_universe/fixture.R"))
for (variant in c("announcement", "effective_only")) {
  step <- "build"
  result <- tryCatch({
    fx <- pit_audit_fixture(variant)
    step <- "seal"
    snapshot <- pit_audit_snapshot(fx)
    on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
    step <- "run"
    exp <- ledgr_experiment(snapshot, function(ctx, params) ctx$hold(),
                            universe = ledgr_universe_members(fx$universe_id),
                            valuation_policy = ledgr_valuation_stale(3), cost_model = ledgr_cost_zero(),
                            opening = ledgr_opening(cash = 1e5))
    bt <- ledgr_run(exp, run_id = paste0("smoke-", variant))
    status <- ledgr_run_info(snapshot, bt$run_id)$status
    close(bt)
    sprintf("ok (run %s, %d bars, %d sessions)", status, nrow(fx$bars), length(fx$sessions))
  }, error = function(e) sprintf("FAILED at %s: %s: %s", step, class(e)[[1L]], conditionMessage(e)))
  cat(variant, ":", result, "\n")
}
