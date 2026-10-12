# Cut 12 LDG-3009 probe (PIT-12-005): a fill's recording pulse is derived two
# ways, from sessions and diagnostics for durable runs
# (ledgr_run_fill_recording_pulses) and from the execution-opportunity index
# for sweep candidates (ledgr_fill_recording_pulses_from_opportunities). The
# probe runs one availability experiment both ways on the audit fixture (full
# status coverage, with halts, a lifetime end and an early close) and on a
# dense fixture, and compares the recording pulse of every fill.
#
#   Rscript dev/audit/pit_universe/probes/S2_recording_pulse.R [<tree>]
args <- commandArgs(trailingOnly = TRUE)
tree <- if (length(args)) args[[1L]] else "C:/Users/maxth/Documents/GitHub/ledgr"
suppressMessages(pkgload::load_all(tree, quiet = TRUE, compile = FALSE))
source("C:/Users/maxth/Documents/GitHub/ledgr/dev/audit/pit_universe/fixture.R")
options(width = 200, warn = 1)
iso <- function(x) format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

# Capture the sweep side: wrap the shared helper that attaches the recording
# pulse and keep what the sweep candidate passes it.
ns <- asNamespace("ledgr")
captured <- new.env()
original <- get("ledgr_fills_add_recording_pulse", ns)
unlockBinding("ledgr_fills_add_recording_pulse", ns)
assign("ledgr_fills_add_recording_pulse", function(fills, recording_pulse_ts_utc) {
  out <- original(fills, recording_pulse_ts_utc)
  captured$fills <- out
  out
}, envir = ns)

compare <- function(label, exp) {
  captured$fills <- NULL
  sw <- ledgr_sweep(exp, ledgr_param_grid(q = list(qty = 10)))
  swept <- captured$fills
  bt <- ledgr_run(exp, params = list(qty = 10), run_id = paste0("rp_", label))
  on.exit(close(bt))
  run <- ledgr_results(bt, "fills")
  key <- function(f) paste(f$instrument_id, iso(f$ts_utc), format(f$qty), sep = "|")
  if (is.null(swept)) swept <- run[0, ]
  m <- match(key(run), key(swept))
  same <- !is.na(m) & vapply(seq_along(m), function(i) {
    if (is.na(m[[i]])) return(FALSE)
    identical(iso(run$recording_pulse_ts_utc[[i]]), iso(swept$recording_pulse_ts_utc[[m[[i]]]]))
  }, logical(1))
  cat(sprintf("[%s] sweep status %s; run fills %d, sweep fills %d, matched %d, same recording pulse %d, NA in run %d, NA in sweep %d\n",
              label, sw$status[[1L]], nrow(run), nrow(swept), sum(!is.na(m)), sum(same),
              sum(is.na(run$recording_pulse_ts_utc)), sum(is.na(swept$recording_pulse_ts_utc))))
  if (any(!same)) {
    bad <- which(!same)
    for (i in head(bad, 5L)) {
      cat(sprintf("  diverge: %s fill %s run pulse %s sweep pulse %s\n", run$instrument_id[[i]], iso(run$ts_utc[[i]]),
                  iso(run$recording_pulse_ts_utc[[i]]),
                  if (is.na(m[[i]])) "<no matching sweep fill>" else iso(swept$recording_pulse_ts_utc[[m[[i]]]])))
    }
  }
}

# Alternate the target every session so fills land around halts, the lifetime
# end and the early close, not only at entry.
strategy <- function(ctx, params) {
  t <- ctx$hold()
  ids <- ctx$tradable()
  day <- as.integer(as.numeric(as.POSIXct(ctx$ts_utc, tz = "UTC")) %/% 86400)
  if (length(ids)) t[ids] <- params$qty + day %% 2L
  t
}
fx <- pit_audit_fixture("announcement", status_coverage = "full")
snap <- pit_audit_snapshot(fx, db_path = file.path(tempdir(), "S2_recording_pulse.duckdb"))
compare("availability", ledgr_experiment(snap, strategy, universe = ledgr_universe_members(fx$universe_id),
                                         valuation_policy = ledgr_valuation_stale(3), cost_model = ledgr_cost_zero(),
                                         opening = ledgr_opening(cash = 1e5)))
ledgr_snapshot_close(snap)

dense_bars <- fx$bars[fx$bars$instrument_id %in% c("AAA", "GGG"), ]
dense <- ledgr_snapshot_from_df(dense_bars, db_path = file.path(tempdir(), "S2_recording_pulse_dense.duckdb"),
                                price_basis = "split_adjusted")
compare("dense", ledgr_experiment(dense, function(ctx, params) {
  t <- ctx$hold()
  day <- as.integer(as.numeric(as.POSIXct(ctx$ts_utc, tz = "UTC")) %/% 86400)
  t[] <- params$qty + day %% 2L
  t
}, universe = c("AAA", "GGG"), cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1e5)))
ledgr_snapshot_close(dense)
