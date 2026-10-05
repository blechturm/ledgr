# Rscript dev/spikes/terminal-outcomes/freeze_probe.R IMPLEMENTATION_REPO
#
# Probe for terminal-outcome seed v2: what does ledgr do today with a held
# instrument that has no bars for a few sessions inside the stale budget?
# AAA has no bars on sessions 4-6 and resumes on session 7; BBB trades daily.
# Valuation policy: ledgr_valuation_stale(5). Public API only; asserts nothing.
args <- commandArgs(trailingOnly = TRUE)
suppressMessages(pkgload::load_all(args[[1L]], quiet = TRUE, compile = FALSE))
days <- 10L
dates <- as.Date("2020-01-01") + seq_len(days) - 1L
pulses <- as.POSIXct(paste(dates, "16:00:00"), tz = "UTC")
iso <- format(pulses, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
aaa_close <- c(100, 101, 102, NA, NA, NA, 60, 61, 62, 63)
keep <- !is.na(aaa_close)
bar_rows <- function(id, close, keep) data.frame(ts_utc = pulses[keep], instrument_id = id,
  open = close[keep], high = close[keep], low = close[keep], close = close[keep], volume = 1000)
bars <- rbind(bar_rows("AAA", aaa_close, keep), bar_rows("BBB", 100 + 0:9, rep(TRUE, days)))
sessions <- ledgr_facts_sessions(data.frame(session_date = dates, status = "open",
  session_open = "09:30:00", session_close = "16:00:00",
  knowledge_time = as.POSIXct(dates, tz = "UTC") - 1), venue_id = "XNYS")
snap <- ledgr_snapshot_from_df(bars, instruments_df = data.frame(instrument_id = c("AAA", "BBB")),
  facts = ledgr_facts(sessions), db_path = tempfile(fileext = ".duckdb"))

make_strategy <- function(persistent) function(ctx, params) {
  if (identical(ctx$ts_utc, iso[[1L]])) return(c(AAA = 10, BBB = 10))
  t <- ctx$hold()
  if (ctx$ts_utc == iso[[4L]] || (persistent && ctx$ts_utc > iso[[4L]])) t[["AAA"]] <- 0
  t
}
for (case in c("persistent_exit", "one_shot_exit")) {
  exp <- ledgr_experiment(snap, make_strategy(case == "persistent_exit"),
    universe = c("AAA", "BBB"), valuation_policy = ledgr_valuation_stale(5L),
    cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 10000))
  bt <- ledgr_run(exp, run_id = case)
  cat("\n=====", case, "| status:", ledgr_run_info(snap, bt$run_id)$status, "\n")
  f <- ledgr_results(bt, "fills"); print(f[, intersect(c("ts_utc", "instrument_id", "side", "qty", "price"), names(f))])
  e <- ledgr_results(bt, "equity"); print(e[, intersect(c("ts_utc", "equity", "positions_value"), names(e))])
  d <- ledgr_results(bt, "diagnostics")
  d <- d[d$instrument_id == "AAA", intersect(c("ts_utc", "stage", "outcome", "reason_code", "mark_source", "mark_age", "target", "quantity"), names(d))]
  print(as.data.frame(d), row.names = FALSE)
  close(bt)
}
ledgr_snapshot_close(snap)
