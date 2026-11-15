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

# --- LDG-3238: missing bars, stale and frozen marks, valuation policies ----------

s3_stale <- function(n, ex) ledgr::ledgr_valuation_stale(max_sessions = n, exhausted = ex)
# Holds, buys A and B (10 each) on session 2, then the case's own step.
s3_mode_strategy <- function(mode) {
  force(mode)
  function(ctx, params) {
    day <- as.integer(as.Date(substr(ctx$ts_utc, 1L, 10L)) - as.Date("2020-01-01")) + 1L
    t <- ctx$hold()
    if (day == 2L) t[c("A", "B")] <- 10
    if (mode == "increase" && day == 10L) t[["B"]] <- 20
    if (mode == "liquidate" && day >= 10L) t[["B"]] <- 0
    if (mode == "adjust_exit" && day == 10L) return(ledgr::ledgr_target_adjust(ctx, exit = c(A = FALSE, B = TRUE, C = FALSE)))
    if (mode == "rebalance" && day >= 3L) return(ledgr::ledgr_target_rebalance(ctx, c(A = 0.3, B = 0.3, C = 0.3)))
    if (mode == "reduce" && day == 8L) t[["B"]] <- 200
    if (mode == "buy_c" && day == 10L) t[["C"]] <- 5
    if (mode == "buy_c_early" && day == 3L) t[["C"]] <- 5
    if (mode == "buy_c_5" && day == 5L) t[["C"]] <- 10
    t
  }
}
s3_mode <- function(name, mode, drop, valuation = s3_stale(2L, "freeze"), risk = ledgr::ledgr_risk_none(),
                    max_pulses = NULL) function() {
  exp <- s3_exp(s3_mode_strategy(mode), valuation = valuation, risk = risk)
  e <- if (is.null(max_pulses)) exp else function(snapshot) {
    x <- exp(snapshot)
    x$control <- list(max_pulses = max_pulses)
    x
  }
  s3_run(name, s3_closes(drop), e)
}
# Closed calendar days: sessions only on the weekdays of 2020-01-01..20; bars
# on the open sessions only.
s3_closed_sessions <- function() {
  dates <- s3_dates()
  open <- !weekdays(dates, abbreviate = FALSE) %in% c("Saturday", "Sunday")
  closes <- s3_closes(list(B = 8:14))
  for (id in names(closes)) closes[[id]][!open] <- NA
  db <- build("s3_closed_sessions", function(db) {
    at <- function(k) as.POSIXct(paste(dates[k], "16:00:00"), tz = "UTC")
    rows <- data.frame(session_date = dates, status = ifelse(open, "open", "closed"),
      session_open = ifelse(open, "09:30:00", NA_character_), session_close = ifelse(open, "16:00:00", NA_character_),
      knowledge_time = as.POSIXct(dates, tz = "UTC") - 1, stringsAsFactors = FALSE)
    bars <- do.call(rbind, lapply(names(closes), function(id) {
      k <- which(!is.na(closes[[id]]))
      data.frame(ts_utc = at(k), instrument_id = id, open = closes[[id]][k], high = closes[[id]][k] + 1,
                 low = closes[[id]][k] - 1, close = closes[[id]][k], volume = 1000, stringsAsFactors = FALSE)
    }))
    ledgr::ledgr_snapshot_from_df(bars, instruments_df = data.frame(instrument_id = names(closes)),
      facts = ledgr::ledgr_facts(ledgr::ledgr_facts_sessions(rows, venue_id = "XNYS")), price_basis = "split_adjusted",
      db_path = db, snapshot_id = "s3_closed_sessions")
  })
  collect(db, "s3_closed_sessions", "s3-s3_closed_sessions",
          s3_exp(s3_mode_strategy("hold"), valuation = s3_stale(2L, "freeze")), seed = 11L)
}

# R2/R3 fixture: `n` instruments I001.. over 28 sessions, prices 20 + j +
# sin(k + j), the case's gaps; buys 2 of every instrument on the opening
# session, then holds.
s3_wide_dates <- s3_dates(28L)
s3_wide_gaps <- function(gaps, j) switch(gaps, none = integer(), first = if (j == 9L) 6:8 else integer(),
  before = if (j == 9L) 3:5 else integer(), tail = if (j == 9L) 21L else integer(),
  many = if (j %% 3L == 0L) 5:24 else if (j %% 3L == 1L) c(7:9, 15:18) else integer(),
  transition = if (j == 8L) 5:9 else if (j == 9L) 8:15 else integer(),
  multi = if (j %in% c(8L, 9L)) 8:28 else integer())
s3_wide_snapshot <- function(name, n, gaps) build(name, function(db) {
  ids <- sprintf("I%03d", seq_len(n))
  bars <- do.call(rbind, lapply(seq_along(ids), function(j) {
    k <- setdiff(seq_along(s3_wide_dates), s3_wide_gaps(gaps, j))
    price <- 20 + j + sin(k + j)
    data.frame(ts_utc = as.POSIXct(paste(s3_wide_dates[k], "16:00:00"), tz = "UTC"), instrument_id = ids[[j]],
               open = price, high = price + 1, low = price - 1, close = price, volume = 1000, stringsAsFactors = FALSE)
  }))
  sessions <- ledgr::ledgr_facts_sessions(data.frame(session_date = s3_wide_dates, status = "open",
    session_open = "09:30:00", session_close = "16:00:00", knowledge_time = as.POSIXct(s3_wide_dates, tz = "UTC") - 1,
    stringsAsFactors = FALSE), venue_id = "XNYS")
  ledgr::ledgr_snapshot_from_df(bars, instruments_df = data.frame(instrument_id = ids), facts = ledgr::ledgr_facts(sessions),
    price_basis = "split_adjusted", db_path = db, snapshot_id = name)
})
s3_wide_strategy <- function(start, buy_last_at = NULL, skip_last = FALSE) {
  force(start); force(buy_last_at); force(skip_last)
  function(ctx, params) {
    day <- as.integer(as.Date(substr(ctx$ts_utc, 1L, 10L)) - as.Date("2020-01-01")) + 1L
    t <- ctx$hold()
    if (day == start) t[] <- 2
    if (skip_last && day == start) t[length(t)] <- 0
    if (!is.null(buy_last_at) && day == buy_last_at) t[length(t)] <- 4
    t
  }
}
s3_wide_exp <- function(strategy, start, exhausted = "freeze") function(snapshot) {
  ledgr::ledgr_experiment(snapshot, strategy, opening = ledgr::ledgr_opening(cash = 1e6, date = s3_wide_dates[[start]]),
    cost_model = ledgr::ledgr_cost_zero(), valuation_policy = s3_stale(2L, exhausted))
}
s3_wide <- function(name, n, gaps, start = 1L, exhausted = "freeze", skip_last = FALSE) function() {
  db <- s3_wide_snapshot(name, n, gaps)
  collect(db, name, paste0("s3-", name), s3_wide_exp(s3_wide_strategy(start, skip_last = skip_last), start, exhausted),
          seed = 19L)
}
# The execution-tail case: a window whose scoring ends at session 20 while
# the prepared planes continue to session 21, where only the last
# instrument has no bar; the final decision buys it (cut review R2). It runs
# through the pin's own window entry, as walk-forward and sweeps do.
s3_tail_gap <- function() {
  name <- "s3_tail_gap"
  db <- s3_wide_snapshot(name, 9L, "tail")
  snapshot <- ledgr::ledgr_snapshot_open(db, name, verify = TRUE)
  on.exit(ledgr::ledgr_snapshot_close(snapshot))
  exp <- s3_wide_exp(s3_wide_strategy(1L, buy_last_at = 20L), 1L)(snapshot)
  sink <- a0_new_sink()
  run_id <- "s3-s3_tail_gap"
  a0_run_or_record(close({
    w <- ns$ledgr_experiment_window(exp, s3_wide_dates[[1L]], s3_wide_dates[[20L]], opening_state_policy = "flat_test_state")
    w$final_execution_ts_utc <- paste0(s3_wide_dates[[21L]], "T09:30:00Z")
    hs <- ns$ledgr_history_substrate_for_experiment(exp, end = paste0(s3_wide_dates[[21L]], "T16:00:00Z"))
    ns$ledgr_run_window(exp, window = w, run_id = run_id, seed = 19L, history_substrate = hs)
  }), run_id, sink)
  list(run = c(a0_store_tables(db, run_id), list(run_conditions = a0_canon(sink$rows, "run_conditions", "seq"))))
}

loop_slice3 <- c(loop_slice3, list(
  s3_gap_held = s3_mode("s3_gap_held", "hold", list(B = 8L), valuation = NULL),
  s3_freeze_held = s3_mode("s3_freeze_held", "hold", list(B = 12:20)),
  s3_stop_refuse = s3_mode("s3_stop_refuse", "hold", list(B = 12:20), valuation = s3_stale(2L, "refuse")),
  s3_freeze_exit = s3_mode("s3_freeze_exit", "hold", list(B = 8:14)),
  s3_stale_reduction = s3_mode("s3_stale_reduction", "reduce", list(B = 7:8), valuation = s3_stale(3L, "freeze"),
    risk = ledgr::ledgr_risk_max_weight(0.3)),
  s3_exec_bar_missing = s3_mode("s3_exec_bar_missing", "buy_c_5", list(C = 6L)),
  s3_sizing_unpriced = s3_mode("s3_sizing_unpriced", "rebalance", list(C = 5L), valuation = s3_stale(3L, "freeze")),
  s3_risk_mark_expired = s3_mode("s3_risk_mark_expired", "buy_c", list(C = 4:12)),
  s3_risk_mark_never = s3_mode("s3_risk_mark_never", "buy_c_early", list(C = 1:12)),
  s3_frozen_increase = s3_mode("s3_frozen_increase", "increase", list(B = 8:14)),
  s3_frozen_liquidate = s3_mode("s3_frozen_liquidate", "liquidate", list(B = 8:14)),
  s3_sizing_liquidate_stale = s3_mode("s3_sizing_liquidate_stale", "adjust_exit", list(B = 8:11),
    valuation = s3_stale(5L, "freeze")),
  s3_sizing_liquidate_frozen = s3_mode("s3_sizing_liquidate_frozen", "adjust_exit", list(B = 8:14)),
  s3_no_bar_session = s3_mode("s3_no_bar_session", "hold", list(A = 8L, B = 8L, C = 8L)),
  s3_closed_sessions = s3_closed_sessions,
  s3_prefix_declared = s3_mode("s3_prefix_declared", "hold", list(B = 8:14), max_pulses = 11L),
  s3_missing_sweep = function() {
    db <- s3_snapshot("s3_missing_sweep", s3_closes(list(B = 8:14)))
    snapshot <- ledgr::ledgr_snapshot_open(db, "s3_missing_sweep", verify = TRUE)
    on.exit(ledgr::ledgr_snapshot_close(snapshot))
    strategy <- function(ctx, params) {
      t <- ctx$hold()
      if (substr(ctx$ts_utc, 1L, 10L) == "2020-01-02") t[c("A", "B")] <- params$q
      t
    }
    exp <- ledgr::ledgr_experiment(snapshot, strategy, opening = ledgr::ledgr_opening(cash = 1e4),
      cost_model = ledgr::ledgr_cost_zero(), valuation_policy = s3_stale(2L, "freeze"))
    grid <- ledgr::ledgr_grid_named(a = list(strategy = list(q = 10)), b = list(strategy = list(q = 20)))
    set.seed(8L)
    obs <- a0_observe_memory(ledgr::ledgr_sweep(exp, grid, seed = 17L, retain = a0_retain()))
    list(sweep = c(a0_sweep_tables(obs$value), a0_memory_tables(obs$observed, obs$value)))
  },
  # Cut review R2: the prepared axis against the scoring axis.
  s3_offset_full = s3_wide("s3_offset_full", 9L, "none", start = 8L),
  s3_offset_first_stale = s3_wide("s3_offset_first_stale", 9L, "first", start = 8L, skip_last = TRUE),
  s3_prescoring_gap = s3_wide("s3_prescoring_gap", 9L, "before", start = 8L),
  s3_tail_gap = s3_tail_gap,
  # Cut review R3: group order, affected sets, many rows.
  s3_mixed_transition = s3_wide("s3_mixed_transition", 9L, "transition"),
  s3_multi_stop = s3_wide("s3_multi_stop", 9L, "multi", exhausted = "refuse"),
  s3_many_gaps = s3_wide("s3_many_gaps", 70L, "many")
))

# LDG-3238 branch reach, on the pin's own tables (A0 canonical text: numbers
# and times converted where read).
s3_rows <- function(t, code) { d <- s2_diag(t); d[!is.na(d$reason_code) & d$reason_code == code, ] }
s3_completion <- function(t) t$run$run_completion
s3_status <- function(t, status, reason = NA_character_) {
  c <- s3_completion(t)
  nrow(c) == 1L && identical(c$intended_terminal_status, status) &&
    (if (is.na(reason)) is.na(c$stop_reason) || !nzchar(c$stop_reason) else identical(c$stop_reason, reason))
}
s3_day_txt <- function(ts) substr(ts, 1L, 10L)
s3_age_num <- function(x) suppressWarnings(as.integer(x))
loop_reach <- c(loop_reach, list(
  s3_gap_held = function(t) {
    r <- s3_rows(t, "stale_mark_pass_through")
    any(r$instrument_id == "B" & s3_day_txt(r$ts_utc) == "2020-01-08" & s3_age_num(r$mark_age) == 1L)
  },
  s3_freeze_held = function(t) nrow(s3_rows(t, "valuation_frozen")) > 0L && s3_status(t, "DONE") &&
    nrow(s3_rows(t, "valuation_horizon_exhausted")) == 0L,
  # The stop's pulse has no equity row and is not counted; its row carries
  # the held quantity and an affected exposure is recorded.
  s3_stop_refuse = function(t) {
    r <- s3_rows(t, "valuation_horizon_exhausted")
    e <- t$run$equity_curve
    nrow(r) == 1L && s3_status(t, "INCOMPLETE", "valuation_horizon_exhausted") &&
      max(s2_time(e$ts_utc)) < s2_time(r$ts_utc[[1L]]) && r$quantity[[1L]] == 10
  },
  s3_freeze_exit = function(t) {
    r <- s3_rows(t, "valuation_freeze_exited")
    nrow(r) == 1L && r$instrument_id[[1L]] == "B" && r$quantity[[1L]] == 10
  },
  s3_stale_reduction = function(t) {
    r <- s3_rows(t, "stale_mark_reduction")
    nrow(r) > 0L && all(r$target_after_risk < r$target_before_risk)
  },
  s3_exec_bar_missing = function(t) any(s3_rows(t, "execution_bar_missing")$instrument_id == "C"),
  s3_sizing_unpriced = function(t) nrow(s3_rows(t, "sizing_unavailable")) > 0L,
  s3_risk_mark_expired = function(t) {
    r <- s3_rows(t, "risk_mark_unavailable")
    nrow(r) == 1L && r$mark_source[[1L]] == "expired_close" && s3_status(t, "INCOMPLETE", "risk_mark_unavailable")
  },
  s3_risk_mark_never = function(t) {
    r <- s3_rows(t, "risk_mark_unavailable")
    nrow(r) == 1L && r$mark_source[[1L]] == "missing" && is.na(s3_age_num(r$mark_age[[1L]]))
  },
  s3_frozen_increase = function(t) any(grepl("^ledgr_restricted_target/", t$run$run_conditions$class)),
  # The frozen holding's sale is refused for a missing execution bar first,
  # then fills once bars return.
  s3_frozen_liquidate = function(t) {
    m <- s3_rows(t, "execution_bar_missing")
    f <- s2_fills(t)
    any(m$instrument_id == "B") && any(f$instrument_id == "B" & f$side == "SELL" &
      s2_time(f$ts_utc) > max(s2_time(m$ts_utc[m$instrument_id == "B"])))
  },
  s3_sizing_liquidate_stale = function(t) {
    r <- s3_rows(t, "sizing_liquidation")
    nrow(r) == 1L && is.na(r$price[[1L]]) && nrow(s3_rows(t, "execution_bar_missing")) > 0L &&
      nrow(s3_rows(t, "valuation_frozen")) == 0L
  },
  s3_sizing_liquidate_frozen = function(t) {
    r <- s3_rows(t, "sizing_liquidation")
    nrow(r) == 1L && is.na(r$price[[1L]]) && nrow(s3_rows(t, "valuation_frozen")) > 0L
  },
  s3_no_bar_session = function(t) {
    r <- s3_rows(t, "stale_mark_pass_through")
    setequal(r$instrument_id[s3_day_txt(r$ts_utc) == "2020-01-08"], c("A", "B"))
  },
  # Marks age by session: a stale or frozen row whose calendar gap to its
  # source is larger than its age (a weekend lies between them).
  s3_closed_sessions = function(t) {
    d <- s2_diag(t)
    d <- d[!is.na(d$mark_age) & d$mark_source %in% c("stale_close", "frozen_close"), ]
    nrow(d) > 0L && any(as.integer(as.Date(s3_day_txt(d$ts_utc)) - as.Date("2020-01-07")) > s3_age_num(d$mark_age))
  },
  s3_prefix_declared = function(t) nrow(s3_completion(t)) == 0L && nrow(t$run$equity_curve) == 11L,
  s3_missing_sweep = function(t) {
    d <- t$sweep$memory_diagnostics
    !is.null(d) && any(d$reason_code == "valuation_frozen") && all(as.character(t$sweep$sweep$status) == "DONE")
  },
  # R2: scoring starts at session 8 of 28; marks are the current closes.
  s3_offset_full = function(t) {
    e <- t$run$equity_curve
    s3_day_txt(e$ts_utc[[1L]]) == "2020-01-08" && nrow(s3_rows(t, "stale_mark_pass_through")) == 0L
  },
  # The first decision's I009 keeps a pre-scoring reference: expired, age 3.
  s3_offset_first_stale = function(t) {
    d <- s2_diag(t)
    r <- d[d$stage == "decision" & d$instrument_id == "I009" & s3_day_txt(d$ts_utc) == "2020-01-08", ]
    nrow(r) == 1L && r$mark_source[[1L]] == "expired_close" && s3_age_num(r$mark_age[[1L]]) == 3L
  },
  s3_prescoring_gap = function(t) {
    e <- t$run$equity_curve
    s3_day_txt(e$ts_utc[[1L]]) == "2020-01-08" && s3_status(t, "DONE") && nrow(s3_rows(t, "stale_mark_pass_through")) == 0L
  },
  s3_tail_gap = function(t) {
    r <- s3_rows(t, "execution_bar_missing")
    nrow(r) == 1L && r$instrument_id[[1L]] == "I009" && s3_day_txt(r$ts_utc[[1L]]) == "2020-01-20"
  },
  # R3: on one pulse a frozen entry (I009) precedes an exit (I008) although
  # I008 sorts first.
  s3_mixed_transition = function(t) {
    d <- s2_diag(t)
    d$seq <- as.integer(d$diagnostic_seq)
    fz <- d[d$reason_code == "valuation_frozen", ]
    ex <- d[d$reason_code == "valuation_freeze_exited", ]
    any(vapply(seq_len(nrow(ex)), function(k) {
      same <- fz[s3_day_txt(fz$ts_utc) == s3_day_txt(ex$ts_utc[[k]]), ]
      any(same$instrument_id > ex$instrument_id[[k]] & same$seq < ex$seq[[k]])
    }, logical(1L)))
  },
  s3_multi_stop = function(t) {
    r <- s3_rows(t, "valuation_horizon_exhausted")
    setequal(r$instrument_id, c("I008", "I009")) && s3_status(t, "INCOMPLETE", "valuation_horizon_exhausted")
  },
  s3_many_gaps = function(t) nrow(s3_rows(t, "stale_mark_pass_through")) > 64L &&
    nrow(s3_rows(t, "valuation_freeze_exited")) > 64L
))

# --- LDG-3239: strategy schedules ---------------------------------------------------

s3_buy_ab <- function(ctx, params) {
  t <- ctx$hold()
  t[c("A", "B")] <- 10
  t
}
s3_friday <- function(ctx, params) {
  t <- ctx$hold()
  t[["A"]] <- if (ledgr::ledgr_schedule_due(ctx, ledgr::ledgr_schedule_weekday("friday"))) 20 else 0
  t
}
s3_sched <- function(name, strategy, drop = list(), schedule = ledgr::ledgr_schedule_week_start(),
                     valuation = s3_stale(2L, "freeze"), max_pulses = NULL) function() {
  exp <- s3_exp(strategy, valuation = valuation, schedule = schedule)
  e <- if (is.null(max_pulses)) exp else function(snapshot) {
    x <- exp(snapshot)
    x$control <- list(max_pulses = max_pulses)
    x
  }
  s3_run(name, s3_closes(drop), e)
}
loop_slice3 <- c(loop_slice3, list(
  s3_sched_full = s3_sched("s3_sched_full", s3_buy_ab),
  s3_sched_stale = s3_sched("s3_sched_stale", s3_buy_ab, list(B = 8:14)),
  s3_sched_query = s3_sched("s3_sched_query", s3_friday, schedule = NULL),
  s3_sched_none = s3_sched("s3_sched_none", s3_buy_ab, schedule = ledgr::ledgr_schedule_month_start()),
  # A valuation stop on a pulse the schedule skips (cut review R3): decided
  # only on session 2, B's bars end after session 7.
  s3_skip_stop = s3_sched("s3_skip_stop", s3_mode_strategy("hold"), list(B = 8:20),
    schedule = ledgr::ledgr_schedule_dates(s3_dates()[2L]), valuation = s3_stale(2L, "refuse")),
  s3_skip_stop_first = s3_sched("s3_skip_stop_first", s3_mode_strategy("hold"), list(B = 8:20),
    schedule = ledgr::ledgr_schedule_dates(s3_dates()[2L]), valuation = s3_stale(0L, "refuse")),
  s3_sched_prefix = s3_sched("s3_sched_prefix", s3_mode_strategy("hold"), list(B = 8:14),
    schedule = ledgr::ledgr_schedule_dates(s3_dates()[2L]), max_pulses = 11L),
  # A sweep whose candidates resolve different schedules: one completes,
  # one has no decision pulse.
  s3_sched_sweep = function() {
    db <- s3_snapshot("s3_sched_sweep", s3_closes(list(B = 8:14)))
    snapshot <- ledgr::ledgr_snapshot_open(db, "s3_sched_sweep", verify = TRUE)
    on.exit(ledgr::ledgr_snapshot_close(snapshot))
    exp <- ledgr::ledgr_experiment(snapshot, s3_mode_strategy("hold"), opening = ledgr::ledgr_opening(cash = 1e4),
      cost_model = ledgr::ledgr_cost_zero(), valuation_policy = s3_stale(2L, "freeze"),
      schedule = ledgr::ledgr_schedule_from_param("cadence"))
    grid <- ledgr::ledgr_grid_named(a = list(strategy = list(cadence = "week_start")),
                                    b = list(strategy = list(cadence = "month_end")))
    set.seed(8L)
    obs <- a0_observe_memory(ledgr::ledgr_sweep(exp, grid, seed = 11L, retain = a0_retain()))
    list(sweep = c(a0_sweep_tables(obs$value), a0_memory_tables(obs$observed, obs$value)))
  }
))
s3_days_of <- function(t, code) unique(s3_day_txt(s3_rows(t, code)$ts_utc))
loop_reach <- c(loop_reach, list(
  # Decided and skipped pulses are disjoint, and both occur.
  s3_sched_full = function(t) {
    skip <- s3_days_of(t, "scheduled_skip")
    dec <- s3_days_of(t, "decision_recorded")
    length(skip) > 0L && length(dec) > 0L && length(intersect(skip, dec)) == 0L
  },
  s3_sched_stale = function(t) {
    d <- s2_diag(t)
    ev <- d[d$stage == "valuation" & d$outcome == "marked", ]
    nrow(ev) > 0L && all(s3_day_txt(ev$ts_utc) %in% s3_days_of(t, "scheduled_skip"))
  },
  s3_sched_query = function(t) {
    d <- s2_diag(t)
    a <- d[d$stage == "decision" & d$instrument_id == "A", ]
    any(a$target == 20 & s3_day_txt(a$ts_utc) == "2020-01-03") && any(a$target == 0 & s3_day_txt(a$ts_utc) == "2020-01-02")
  },
  s3_sched_none = function(t) any(grepl("ledgr_schedule_no_decision", t$run$run_conditions$class)),
  # The skip pulse that stops writes no skip row, no reconciliation and no
  # equity row; the stop is the run's last row.
  s3_skip_stop = function(t) {
    r <- s3_rows(t, "valuation_horizon_exhausted")
    if (nrow(r) != 1L || !s3_status(t, "INCOMPLETE", "valuation_horizon_exhausted")) return(FALSE)
    day <- s3_day_txt(r$ts_utc[[1L]])
    !day %in% s3_days_of(t, "scheduled_skip") && !day %in% s3_days_of(t, "affordability_reconciled") &&
      !day %in% s3_day_txt(t$run$equity_curve$ts_utc) && length(s3_days_of(t, "scheduled_skip")) > 0L
  },
  s3_skip_stop_first = function(t) {
    r <- s3_rows(t, "valuation_horizon_exhausted")
    nrow(r) == 1L && s3_day_txt(r$ts_utc[[1L]]) == "2020-01-08" && nrow(t$run$equity_curve) == 7L
  },
  s3_sched_prefix = function(t) nrow(s3_completion(t)) == 0L && nrow(t$run$equity_curve) == 11L &&
    length(s3_days_of(t, "scheduled_skip")) > 0L,
  s3_sched_sweep = function(t) {
    s <- t$sweep$sweep
    st <- as.character(s$status)
    setequal(st, c("DONE", "FAILED")) && any(grepl("no decision pulse", s$error_msg[st == "FAILED"]))
  }
))
