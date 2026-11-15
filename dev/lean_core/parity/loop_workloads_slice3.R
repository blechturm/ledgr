# Slice-3 workloads (Cut 19, workstream 37; interface Section 19.11):
# declared session calendars, history reads in the strategy, missing bars
# with stale and frozen marks and the valuation policies, and schedules,
# built with public constructors, the pin as oracle. Sourced by
# loop_parity.R after loop_workloads.R and loop_workloads_slice2.R (whose
# helpers build, collect, lw_bars, lw_snapshot and s2_* it uses).
#
# loop_reach gains, per workload, the branch it is named for, asserted on
# the pin's own tables before parity is accepted; slice3_reach_cross.R
# checks that every predicate holds on its own workload and fails on at
# least one other.

# --- shared fixtures ------------------------------------------------------------

# A declared calendar of `n_days` open sessions from 2020-01-01, bars at the
# 16:00 close. `closes` is a named list of close vectors; NA means no bar.
s3_dates <- function(n_days = 20L) as.Date("2020-01-01") + seq_len(n_days) - 1L
s3_day <- function(k) format(s3_dates(max(k))[[k]], "%Y-%m-%d")
s3_close_values <- function(n_days = 20L) list(A = 30 * (1 + 0.02 * sin(seq_len(n_days))),
  B = 45 * (1 + 0.02 * sin(seq_len(n_days) + 1)), C = 12 * (1 + 0.02 * sin(seq_len(n_days) + 2)))
s3_closes <- function(drop = list(), n_days = 20L) {
  x <- s3_close_values(n_days)
  for (id in names(drop)) x[[id]][drop[[id]]] <- NA
  x
}
s3_snapshot <- function(name, closes, sessions = NULL) build(name, function(db) {
  dates <- s3_dates(length(closes[[1L]]))
  at <- function(k) as.POSIXct(paste(dates[k], "16:00:00"), tz = "UTC")
  if (is.null(sessions)) sessions <- dates
  facts <- ledgr::ledgr_facts_sessions(data.frame(session_date = sessions, status = "open", session_open = "09:30:00",
    session_close = "16:00:00", knowledge_time = as.POSIXct(sessions, tz = "UTC") - 1, stringsAsFactors = FALSE),
    venue_id = "XNYS")
  bars <- do.call(rbind, lapply(names(closes), function(id) {
    k <- which(!is.na(closes[[id]]))
    data.frame(ts_utc = at(k), instrument_id = id, open = closes[[id]][k], high = closes[[id]][k] + 1,
               low = closes[[id]][k] - 1, close = closes[[id]][k], volume = 1000, stringsAsFactors = FALSE)
  }))
  ledgr::ledgr_snapshot_from_df(bars, instruments_df = data.frame(instrument_id = names(closes)),
    facts = ledgr::ledgr_facts(facts), price_basis = "split_adjusted", db_path = db, snapshot_id = name)
})
# Targets from a per-day table (ISO day -> named quantities); other days hold.
s3_plan <- function(...) {
  steps <- list(...)
  stats::setNames(lapply(steps, `[[`, 2L), vapply(steps, function(p) s3_day(p[[1L]]), ""))
}
s3_exp <- function(strategy, opening_day = 1L, valuation = NULL, risk = ledgr::ledgr_risk_none(), features = list(),
                   schedule = NULL, cash = 1e4) function(snapshot) {
  ledgr::ledgr_experiment(snapshot, strategy, features = features,
    opening = ledgr::ledgr_opening(cash = cash, date = s3_dates(opening_day)[[opening_day]]),
    cost_model = ledgr::ledgr_cost_zero(), risk_chain = risk, valuation_policy = valuation, schedule = schedule)
}
s3_run <- function(name, closes, exp, seed = 11L, ...) {
  db <- s3_snapshot(name, closes)
  collect(db, name, paste0("s3-", name), exp, seed = seed, ...)
}

# --- history reads ---------------------------------------------------------------

# Reads `lookback` sessions of history (a bar or a feature) as a matrix and
# `lookback - 1` as a long frame, records every value read in the pulse's
# intent reason, and trades instrument A on the values, so the economic
# tables depend on the reads too.
s3_hist_strategy <- function(source = "bar", lookback = 3L) {
  force(source); force(lookback)
  function(ctx, params) {
    m <- if (identical(source, "bar")) ledgr::ledgr_history_matrix(ctx, bar = "close", lookback = lookback) else
      ledgr::ledgr_history_matrix(ctx, feature = "sma", lookback = lookback)
    f <- if (identical(source, "bar")) ledgr::ledgr_history_frame(ctx, bar = "close", lookback = lookback - 1L, layout = "long") else
      ledgr::ledgr_history_frame(ctx, feature = "sma", lookback = lookback - 1L, layout = "long")
    info <- ledgr::ledgr_history_info(m)
    targets <- ctx$hold()
    s <- sum(m, na.rm = TRUE) + sum(as.numeric(f$value), na.rm = TRUE) + nrow(info$selection)
    targets[["A"]] <- if (floor(s) %% 2 == 1) 10 else 0
    list(targets = targets, state_update = NULL,
         intent_reason = if (length(m) == 0L) "empty" else paste(format(as.numeric(m), digits = 17L), collapse = ","))
  }
}
# The values a strategy read, by pulse day, from the pin's intent rows.
s3_intent_values <- function(t) {
  d <- t$run$run_diagnostics
  d <- d[d$reason_code == "strategy_intent", ]
  stats::setNames(lapply(strsplit(d$reasons, ",", fixed = TRUE), function(s) suppressWarnings(as.numeric(s))),
                  substr(d$ts_utc, 1L, 10L))
}
# Predicate: on every decided pulse, the values read are the closes of the
# `lookback` sessions ending at the pulse (column-major, A then B then C),
# and the first pulse is session `first`.
s3_bar_reach <- function(lookback, first = 1L, closes = s3_close_values(),
                         days = format(s3_dates(length(closes[[1L]])), "%Y-%m-%d")) function(t) {
  v <- s3_intent_values(t)
  if (length(v) < 2L) return(FALSE)
  k <- match(names(v), days)
  if (anyNA(k) || k[[1L]] != first) return(FALSE)
  all(vapply(seq_along(v), function(j) {
    w <- seq.int(k[[j]] - lookback + 1L, k[[j]])
    if (w[[1L]] < 1L) return(TRUE)   # too little history: the read is empty or partial
    isTRUE(all.equal(v[[j]], unlist(lapply(closes, `[`, w), use.names = FALSE), tolerance = 1e-7))
  }, logical(1L)))
}

loop_slice3 <- list(
  # LDG-3237: a declared session calendar with complete bars; fills execute
  # at the next session's open.
  s3_sessions_full = function() s3_run("s3_sessions_full", s3_closes(),
    s3_exp(lw_schedule_strategy(s3_plan(list(2L, c(A = 10, B = 10)), list(9L, c(A = 0)))))),
  # History reads of bars on a bar-native and on a declared-session run.
  s3_hist_bar_native = function() {
    db <- lw_snapshot("s3_hist_bar_native", lw_bars(c(A = 30, B = 45, C = 12), 20L, drift = 0.05))
    exp <- function(snapshot) ledgr::ledgr_experiment(snapshot, s3_hist_strategy("bar", 3L),
      opening = ledgr::ledgr_opening(cash = 1e4), cost_model = ledgr::ledgr_cost_zero())
    collect(db, "s3_hist_bar_native", "s3-s3_hist_bar_native", exp, seed = 11L)
  },
  s3_hist_declared = function() s3_run("s3_hist_declared", s3_closes(), s3_exp(s3_hist_strategy("bar", 3L))),
  # R2: scoring starts at session 8 of the prepared data; the first pulse
  # reads history before it, and nothing after its cutoff.
  s3_hist_offset_bar = function() s3_run("s3_hist_offset_bar", s3_closes(),
    s3_exp(s3_hist_strategy("bar", 3L), opening_day = 8L)),
  s3_hist_offset_feature = function() s3_run("s3_hist_offset_feature", s3_closes(),
    s3_exp(s3_hist_strategy("feature", 3L), opening_day = 8L,
      features = ledgr::ledgr_feature_map(sma = ledgr::ledgr_ind_ttr("SMA", input = "close", n = 2L))))
)

# Feature reach: SMA(2) of the closes, read over three sessions ending at the
# pulse; the first pulse is session 8 and its oldest value (session 6) needs
# the close of session 5, before scoring.
s3_feature_reach <- function(t) {
  v <- s3_intent_values(t)
  if (length(v) == 0L) return(FALSE)
  cl <- s3_close_values()
  days <- format(s3_dates(), "%Y-%m-%d")
  k <- match(names(v), days)
  if (anyNA(k) || k[[1L]] != 8L) return(FALSE)
  all(vapply(seq_along(v), function(j) {
    w <- seq.int(k[[j]] - 2L, k[[j]])
    expect <- unlist(lapply(cl, function(x) (x[w - 1L] + x[w]) / 2), use.names = FALSE)
    isTRUE(all.equal(v[[j]], expect, tolerance = 1e-7))
  }, logical(1L)))
}

loop_reach <- c(loop_reach, list(
  # Fills execute at the declared opens: the session after the decision, 09:30.
  s3_sessions_full = function(t) {
    f <- t$run$fills
    nrow(f) > 0L && all(substr(f$ts_utc, 12L, 19L) == "09:30:00")
  },
  s3_hist_bar_native = local({
    b <- lw_bars(c(A = 30, B = 45, C = 12), 20L, drift = 0.05)
    s3_bar_reach(3L, 1L, lapply(c(A = "A", B = "B", C = "C"), function(id) b$close[b$instrument_id == id]),
                 days = format(unique(as.Date(b$ts_utc)), "%Y-%m-%d"))
  }),
  s3_hist_declared = s3_bar_reach(3L),
  s3_hist_offset_bar = s3_bar_reach(3L, first = 8L),
  s3_hist_offset_feature = s3_feature_reach
))
