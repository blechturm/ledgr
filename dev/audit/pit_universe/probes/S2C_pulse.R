# Stage 2 challenger probe (S2-012): does ledgr_pulse_snapshot() differ from
# a run only in membership (which a character universe never consumes, being
# a fixed basket), or also in the facts a fixed basket still consumes
# (status, lifetime)? Fixed basket c("AAA","EEE") on the full fixture; EEE is
# quotation_only from s23 and known_inactive (regulatory_delisting) from s23,
# with OTC bars s23-s26. Compares the s24 planes of a ledgr_run() context
# with ledgr_pulse_snapshot() at the same timestamp.
#
#   sh dev/audit/pit_universe/run_low.sh dev/audit/pit_universe/probes/S2C_pulse.R <log>
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all("C:/tmp/ws22-b", quiet = TRUE, compile = FALSE))
source("C:/Users/maxth/Documents/GitHub/ledgr/dev/audit/pit_universe/fixture.R")
options(width = 200, warn = 1)
iso <- function(x) format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
fx <- pit_audit_fixture("announcement", status_coverage = "full")
close_at <- function(k) pit_audit_at(fx$sessions[k], if (k == 30L) "13:00:00" else "16:00:00")
snap <- pit_audit_snapshot(fx, db_path = tempfile(fileext = ".duckdb"))
t24 <- iso(close_at(24))
planes <- function(ctx) {
  i <- match("EEE", ctx$universe)
  sprintf("members %s; EEE member %s target_restricted %s reason '%s' admissible %s; tradable %s",
          paste(ctx$members, collapse = ","), ctx$vec$member[[i]], ctx$vec$target_restricted[[i]],
          ctx$vec$target_restriction_reason[[i]], ctx$vec$admissible[[i]], paste(ctx$tradable(), collapse = ","))
}
strategy <- function(ctx, params) {
  if (identical(ctx$ts_utc, params$t)) {
    i <- match("EEE", ctx$universe)
    options(probe.seen = sprintf("members %s; EEE member %s target_restricted %s reason '%s' admissible %s; tradable %s",
      paste(ctx$members, collapse = ","), ctx$vec$member[[i]], ctx$vec$target_restricted[[i]],
      ctx$vec$target_restriction_reason[[i]], ctx$vec$admissible[[i]], paste(ctx$tradable(), collapse = ",")))
  }
  ctx$hold()
}
exp <- ledgr_experiment(snap, strategy, universe = c("AAA", "EEE"), valuation_policy = ledgr_valuation_stale(3),
                        cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1e5))
bt <- ledgr_run(exp, params = list(t = t24), run_id = "basket"); close(bt)
cat("[run basket s24]", getOption("probe.seen"), "\n")
p <- tryCatch(ledgr_pulse_snapshot(snap, universe = c("AAA", "EEE"), ts_utc = t24), error = identity)
if (inherits(p, "error")) cat("[pulse s24] ERROR", class(p)[[1]], conditionMessage(p), "\n") else {
  cat("[pulse s24]", planes(p), "\n"); close(p)
}
ledgr_snapshot_close(snap)
