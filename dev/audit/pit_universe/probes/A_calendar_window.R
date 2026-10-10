# Stage 1 probe (reader A): calendar coverage versus sealed bar range, run and
# window boundaries, and what run identity binds. Description only.
#   sh dev/audit/pit_universe/run_low.sh dev/audit/pit_universe/probes/A_calendar_window.R <log>
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all("C:/tmp/ws22-b", quiet = TRUE, compile = FALSE))
source("C:/Users/maxth/Documents/GitHub/ledgr/dev/audit/pit_universe/fixture.R")

say <- function(case, value) cat(sprintf("[%s] %s\n", case, paste(value, collapse = " | ")))
iso <- function(x) format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
hold <- function(ctx, params) ctx$hold()

fx <- pit_audit_fixture("announcement")
cal <- pit_audit_calendar()
ids <- c("AAA", "GGG")
bars <- fx$bars[fx$bars$instrument_id %in% ids, ]
inst <- data.frame(instrument_id = ids)

run_pulses <- function(sessions_df, bars_df, label, opening = ledgr_opening(cash = 1e4)) {
  facts <- ledgr_facts(ledgr_facts_sessions(sessions_df, venue_id = "XNYS", timezone = pit_audit_tz,
                                            knowledge = "assume_effective"))
  snap <- ledgr_snapshot_from_df(bars_df, inst, facts = facts, price_basis = "split_adjusted")
  on.exit(ledgr_snapshot_close(snap), add = TRUE)
  info <- ledgr_snapshot_info(snap)
  exp <- ledgr_experiment(snap, hold, universe = ids, valuation_policy = ledgr_valuation_stale(3),
                          cost_model = ledgr_cost_zero(), opening = opening)
  out <- tryCatch({
    bt <- ledgr_run(exp, run_id = label)
    eq <- ledgr_results(bt, "equity")
    res <- c(paste("pulses", nrow(eq)), paste("first", iso(min(eq$ts_utc))), paste("last", iso(max(eq$ts_utc))),
             paste("cfg start", bt$config$backtest$start_ts_utc), paste("cfg end", bt$config$backtest$end_ts_utc))
    close(bt)
    res
  }, error = function(e) paste("error", class(e)[[1L]], conditionMessage(e)))
  say(label, c(paste("sealed", info$start_date, "to", info$end_date), out))
}

# C1: calendar covers only s1..s30 while bars run to s40.
last30 <- cal$open_days[[30L]]
run_pulses(cal$sessions[cal$sessions$session_date <= last30, ], bars, "C1 calendar shorter than bars")
# C2: calendar runs past the last bar (bars cut at s30).
run_pulses(cal$sessions, bars[bars$ts_utc <= pit_audit_at(last30, "13:00:00"), ], "C2 calendar longer than bars")
# C3: calendar starts at s10 while bars start at s1.
s10 <- cal$open_days[[10L]]
run_pulses(cal$sessions[cal$sessions$session_date >= s10, ], bars, "C3 calendar starts after first bar")
# C4: opening dated before the sealed start.
run_pulses(cal$sessions, bars, "C4 opening before sealed start",
           opening = ledgr_opening(cash = 1e4, date = as.Date("2021-02-01")))

# C5: experiment windows given as civil dates inside and at the sealed edges.
facts <- ledgr_facts(fx$families$sessions)
snap <- ledgr_snapshot_from_df(bars, inst, facts = facts, price_basis = "split_adjusted")
exp <- ledgr_experiment(snap, hold, universe = ids, valuation_policy = ledgr_valuation_stale(3),
                        cost_model = ledgr_cost_zero())
w_in <- ledgr_experiment_window(exp, as.character(cal$open_days[[5L]]), as.character(cal$open_days[[10L]]))
say("C5 window inside range", c(iso(w_in$scoring_start_utc), iso(w_in$scoring_end_utc)))
bt <- ledgr_run_window(exp, window = w_in, run_id = "c5")
eq <- ledgr_results(bt, "equity")
say("C5 window pulses", c(nrow(eq), iso(min(eq$ts_utc)), iso(max(eq$ts_utc))))
close(bt)
w_edge <- ledgr_experiment_window(exp, as.character(cal$open_days[[1L]]), as.character(cal$open_days[[40L]]))
say("C5 window at sealed edges", c(iso(w_edge$scoring_start_utc), iso(w_edge$scoring_end_utc)))

# C6: identity. Same bars sealed twice under different snapshot IDs.
dense <- data.frame(instrument_id = "Z", ts_utc = as.POSIXct("2021-01-04 21:00:00", tz = "UTC") + 86400 * 0:3,
                    open = 1, high = 1, low = 1, close = 1)
db <- tempfile(fileext = ".duckdb")
s1 <- ledgr_snapshot_from_df(dense, db_path = db, snapshot_id = "snap_one")
s2 <- ledgr_snapshot_from_df(dense, db_path = db, snapshot_id = "snap_two")
h <- c(ledgr_snapshot_info(s1)$snapshot_hash, ledgr_snapshot_info(s2)$snapshot_hash)
say("C6 snapshot hashes equal", identical(h[[1]], h[[2]]))
cfg <- function(s) {
  e <- ledgr_experiment(s, function(ctx, params) ctx$flat(), cost_model = ledgr_cost_zero())
  bt <- ledgr_run(e, run_id = paste0("id_", s$snapshot_id))
  on.exit(close(bt))
  config_hash(bt$config)
}
ch <- c(cfg(s1), cfg(s2))
say("C6 config hashes equal", identical(ch[[1]], ch[[2]]))
