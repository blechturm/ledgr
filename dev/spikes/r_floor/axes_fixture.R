# A changing-axis fixture: declared daily sessions, membership intervals in
# which instruments enter and leave, and missing bars, so the decision axis
# changes, former members are held at stale marks and positions change
# partially.
r_floor_axes_fixture <- function(n_inst, n_sess, seed = 20260530L,
                                 db_path = tempfile(fileext = ".duckdb")) {
  set.seed(seed)
  ids <- sprintf("I%03d", seq_len(n_inst))
  dates <- as.Date("2020-01-01") + seq_len(n_sess) - 1L
  sessions <- ledgr::ledgr_facts_sessions(data.frame(
    session_date = dates, status = "open", session_open = "14:30:00",
    session_close = "21:00:00", knowledge_time = as.POSIXct(dates, tz = "UTC") - 1,
    stringsAsFactors = FALSE), venue_id = "XNYS")
  # Each instrument joins at a random session and about half leave later.
  enter <- sample.int(max(2L, n_sess %/% 3L), n_inst, replace = TRUE)
  leave <- ifelse(stats::runif(n_inst) < 0.5,
                  pmin(n_sess, enter + sample.int(n_sess, n_inst, replace = TRUE)), NA)
  at <- function(k) as.POSIXct(paste(dates[k], "00:00:00"), tz = "UTC")
  # One membership interval per instrument; a leaver's interval ends at its
  # exit session (half-open, so it is not a member from then on).
  out <- !is.na(leave) & leave > enter
  effective_to <- as.POSIXct(rep(NA_real_, n_inst), tz = "UTC")
  effective_to[out] <- at(leave[out])
  rows <- data.frame(instrument_id = ids, effective_from = at(enter),
                     effective_to = effective_to, member = TRUE)
  membership <- ledgr::ledgr_facts_membership_intervals(rows, universe_id = "U",
    knowledge = "assume_effective")
  # Random walks with about 3 percent of bars missing (never the first).
  ts <- as.POSIXct(paste(dates, "21:00:00"), tz = "UTC")
  bars <- do.call(rbind, lapply(seq_len(n_inst), function(i) {
    close <- round(50 * exp(cumsum(stats::rnorm(n_sess, 0, 0.02))), 4)
    open <- round(close * exp(stats::rnorm(n_sess, 0, 0.005)), 4)
    keep <- c(TRUE, stats::runif(n_sess - 1L) > 0.03)
    data.frame(ts_utc = ts, instrument_id = ids[[i]], open = open,
               high = pmax(open, close) * 1.01, low = pmin(open, close) * 0.99,
               close = close, volume = 1000)[keep, ]
  }))
  snapshot <- ledgr::ledgr_snapshot_from_df(bars,
    instruments_df = data.frame(instrument_id = ids), db_path = db_path,
    snapshot_id = "r_floor_axes", facts = ledgr::ledgr_facts(sessions, membership),
    price_basis = "split_adjusted")
  list(snapshot = snapshot, bars = bars, ids = ids, dates = dates,
       enter = enter, leave = leave)
}
