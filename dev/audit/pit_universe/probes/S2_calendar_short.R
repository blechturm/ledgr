# Stage 2 probe (analyst): session calendar coverage against the bar range
# (Gate 1 carried item: valuation when the calendar is shorter than the bars)
# and the recorded run window.
#   K1 calendar s1..s30, bars s1..s40 (AAA bought at s1 and held)
#   K2 calendar s10..s40, bars s1..s40
#   K3 full calendar, opening dated 2021-02-01 (before the sealed start)
# For each: run status, completion row (intended and achieved bounds,
# complete_performance), stored config window, equity rows, summary heading,
# and the sweep's scoring_range for the same experiment.
#
#   sh dev/audit/pit_universe/run_low.sh dev/audit/pit_universe/probes/S2_calendar_short.R <log>
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all("C:/tmp/ws22-b", quiet = TRUE, compile = FALSE))
source("C:/Users/maxth/Documents/GitHub/ledgr/dev/audit/pit_universe/fixture.R")
options(width = 200, warn = 1)
iso <- function(x) format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
fx <- pit_audit_fixture("announcement")
cal <- pit_audit_calendar()
ids <- c("AAA", "GGG")
bars <- fx$bars[fx$bars$instrument_id %in% ids, ]
strategy <- function(ctx, params) { t <- ctx$hold(); if (ctx$ts_utc == params$buy_ts) t[["AAA"]] <- 10; t }
first_close <- function(sessions) iso(pit_audit_at(min(sessions$session_date[sessions$status == "open"]), "16:00:00"))

probe <- function(label, sessions, opening = ledgr_opening(cash = 1e4)) {
  db <- tempfile(fileext = ".duckdb")
  facts <- ledgr_facts(ledgr_facts_sessions(sessions, venue_id = "XNYS", timezone = pit_audit_tz, knowledge = "assume_effective"))
  snap <- ledgr_snapshot_from_df(bars, data.frame(instrument_id = ids), db_path = db, facts = facts, price_basis = "split_adjusted")
  on.exit(ledgr_snapshot_close(snap), add = TRUE)
  info <- ledgr_snapshot_info(snap)
  exp <- ledgr_experiment(snap, strategy, universe = ids, valuation_policy = ledgr_valuation_stale(3),
                          cost_model = ledgr_cost_zero(), opening = opening)
  p <- list(buy_ts = first_close(sessions))
  bt <- ledgr_run(exp, params = p, run_id = label)
  comp <- ledgr_run_completion(bt)
  eq <- ledgr_results(bt, "equity")
  cat(sprintf("[%s] sealed %s..%s; status %s; completion %s complete_performance %s; requested %s..%s; achieved %s..%s\n",
              label, info$start_date, info$end_date, ledgr_run_info(snap, label)$status, comp$completion_status,
              comp$complete_performance, iso(comp$requested_start_utc), iso(comp$requested_end_utc),
              iso(comp$achieved_start_utc), iso(comp$achieved_end_utc)))
  cat(sprintf("[%s] config window %s..%s; equity rows %d %s..%s; final equity %s\n", label,
              bt$config$backtest$start_ts_utc, bt$config$backtest$end_ts_utc, nrow(eq),
              iso(min(eq$ts_utc)), iso(max(eq$ts_utc)), format(tail(eq$equity, 1), nsmall = 2)))
  sm <- capture.output(summary(bt))
  cat(sprintf("[%s] summary: %s\n", label, paste(trimws(grep("Metric|Annualized Return|window|Window|prefix", sm, value = TRUE)), collapse = " / ")))
  close(bt)
  sw <- ledgr_sweep(exp, ledgr_param_grid(c1 = p))
  sr <- attr(sw, "scoring_range") %||% attr(sw, "sweep_meta")$scoring_range
  cat(sprintf("[%s] sweep status %s final equity %s; scoring_range %s\n", label, sw$status[[1]],
              format(sw$final_equity[[1]], nsmall = 2), if (is.null(sr)) "<not found>" else paste(unlist(sr), collapse = "..")))
}
s30 <- cal$open_days[[30L]]; s10 <- cal$open_days[[10L]]
probe("K1_cal_to_s30", cal$sessions[cal$sessions$session_date <= s30, ])
probe("K2_cal_from_s10", cal$sessions[cal$sessions$session_date >= s10, ])
probe("K3_opening_early", cal$sessions, opening = ledgr_opening(cash = 1e4, date = as.Date("2021-02-01")))
