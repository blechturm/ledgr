# Stage 2 probe (analyst): venue civil date against UTC date (Gate 1 carried
# item: a non-Americas venue). The same small dataset is sealed under three
# venues: America/New_York (control), Australia/Sydney (east of UTC; session
# opens on the previous UTC date) and Pacific/Honolulu (close after UTC
# midnight). Sessions 10:00-16:00 local, 8 weekdays from 2021-03-01. Bars
# are given as Date labels (mapped to the session close). BBB gets a
# known_inactive lifetime row whose effective_from is the Date of session d6
# (assume_effective, label "delisting"). The strategy buys BBB at the d5
# decision. Prints the pulses, where the BBB fill and terminal disposition
# land, and how a date-only window d3..d6 resolves.
#
#   sh dev/audit/pit_universe/run_low.sh dev/audit/pit_universe/probes/S2_venue.R <log>
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all("C:/tmp/ws22-b", quiet = TRUE, compile = FALSE))
options(width = 200, warn = 1)
iso <- function(x) format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
days <- seq(as.Date("2021-03-01"), by = "day", length.out = 10)
days <- days[as.integer(format(days, "%u")) <= 5L][1:8]
venue <- function(tz) {
  civil <- seq(min(days), max(days), by = "day")
  open <- civil %in% days
  sessions <- data.frame(session_date = civil, status = ifelse(open, "open", "closed"),
                         session_open = ifelse(open, "10:00:00", NA), session_close = ifelse(open, "16:00:00", NA),
                         stringsAsFactors = FALSE)
  bars <- rbind(
    data.frame(instrument_id = "AAA", ts_utc = days, open = 10, high = 10, low = 10, close = 10, volume = 1),
    data.frame(instrument_id = "BBB", ts_utc = days, open = 20, high = 20, low = 20, close = 20, volume = 1)
  )
  life <- data.frame(instrument_id = "BBB", effective_from = days[[6]], assertion = "known_inactive",
                     terminal_event = "delisting", stringsAsFactors = FALSE)
  facts <- ledgr_facts(
    ledgr_facts_sessions(sessions, venue_id = "V", timezone = tz, knowledge = "assume_effective"),
    ledgr_facts_lifetime(life, knowledge = "assume_effective"))
  snap <- ledgr_snapshot_from_df(bars, data.frame(instrument_id = c("AAA", "BBB")), db_path = tempfile(fileext = ".duckdb"),
                                 facts = facts, price_basis = "split_adjusted")
  on.exit(ledgr_snapshot_close(snap), add = TRUE)
  buy <- function(ctx, params) { t <- ctx$hold(); if (ctx$ts_utc == params$buy_ts) t[["BBB"]] <- 10; t }
  exp <- ledgr_experiment(snap, buy, universe = c("AAA", "BBB"), valuation_policy = ledgr_valuation_stale(3),
                          cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1e4))
  stored_bars <- ledgr_results(ledgr_run(exp, params = list(buy_ts = "1900-01-01T00:00:00Z"), run_id = "probe_pulses"), "equity")$ts_utc
  bt <- ledgr_run(exp, params = list(buy_ts = iso(stored_bars[[5]])), run_id = "buy")
  led <- ledgr_results(bt, "ledger")
  dg <- ledgr_results(bt, "diagnostics"); dg <- dg[dg$instrument_id == "BBB" & dg$stage != "decision", ]
  cat(sprintf("[%s] pulses (session closes, UTC): d1 %s, d5 %s, d6 %s\n", tz, iso(stored_bars[[1]]), iso(stored_bars[[5]]), iso(stored_bars[[6]])))
  cat(sprintf("[%s] lifetime effective_from (Date d6 = %s) as stored: %s\n", tz, days[[6]], iso(as.POSIXct(days[[6]]))))
  cat(sprintf("[%s] BBB events: %s\n", tz, paste(iso(led$ts_utc[led$instrument_id == "BBB"]), led$event_type[led$instrument_id == "BBB"], collapse = " | ")))
  cat(sprintf("[%s] BBB non-decision diagnostics: %s\n", tz, paste(iso(dg$ts_utc), dg$stage, dg$outcome, dg$reason_code, collapse = " | ")))
  close(bt)
  w <- tryCatch(ledgr_experiment_window(exp, as.character(days[[3]]), as.character(days[[6]])), error = identity)
  if (inherits(w, "error")) { cat(sprintf("[%s] window d3..d6 dates: %s\n", tz, conditionMessage(w))); return(invisible()) }
  wb <- ledgr_run_window(exp, params = list(buy_ts = "1900-01-01T00:00:00Z"), window = w, run_id = "win")
  we <- ledgr_results(wb, "equity")$ts_utc; close(wb)
  cat(sprintf("[%s] window '%s'..'%s' -> %s..%s; pulses %s\n", tz, days[[3]], days[[6]], iso(w$scoring_start_utc),
              iso(w$scoring_end_utc), paste(iso(we), collapse = ",")))
}
for (tz in c("America/New_York", "Australia/Sydney", "Pacific/Honolulu")) {
  r <- tryCatch(venue(tz), error = function(e) cat(sprintf("[%s] ERROR %s - %s\n", tz, class(e)[[1]], conditionMessage(e))))
}
