# LDG-3215: the cross-edge preparation fixture and the registered history-read
# request set. Sourced into the global environment by the recorder runner
# (recorder/run.R) and by prep_edges.R; uses public constructors only.
#
# The fixture is a declared-session calendar of 96 open weekdays and six
# instruments. Every event sits within one session of an edge shared by tile
# widths 8 and 12 (the edges after sessions 24, 48 and 72), so the same
# fixture puts each event on both sides of an edge at either width:
#   AAA  member throughout, a bar every session (the control)
#   BBB  held from the opening; leaves membership at s25 (exit while held,
#        so it moves to the end of the decision axis: changed column order)
#        and rejoins at s49 (re-entry)
#   CCC  bars s1-s43 and s73-s96 (carry expires at s49); known_inactive from
#        s48 to s73 (relisting); named explicitly by an off-axis request
#        while inactive
#   DDD  no bars s20-s27: price carry (5 sessions) covers s20-s24 and expires
#        at s25; a min_observations window spans carried and missing values
#   EEE  bars s1-s43 (carry expires at s49); known_inactive effective s49 but
#        known only at s50 (late-known fact)
#   FFF  first bar s24, joins membership at s25 (listing and entry)
# The request set adds a 30-session lookback (several tiles at either width)
# and lookback = Inf.

lc_prep_widths <- c(8L, 12L)

lc_prep_fixture_inputs <- function() {
  n <- 96L
  days <- seq(as.Date("2021-01-04"), by = "day", length.out = 140L)
  days <- days[!format(days, "%u") %in% c("6", "7")][seq_len(n)]
  utc <- function(d) as.POSIXct(paste(d, "21:00:00"), tz = "UTC")
  open_utc <- function(d) as.POSIXct(paste(d, "14:30:00"), tz = "UTC")
  s <- seq_len(n)
  have <- list(AAA = s, BBB = s, CCC = c(1:43, 73:96), DDD = setdiff(s, 20:27), EEE = 1:43, FFF = 24:96)
  base <- c(AAA = 10, BBB = 20, CCC = 30, DDD = 40, EEE = 50, FFF = 60)
  bars <- do.call(rbind, lapply(names(have), function(id) {
    k <- have[[id]]
    data.frame(instrument_id = id, ts_utc = utc(days[k]), close = base[[id]] + 0.25 * k + 0.5 * (k %% 3L))
  }))
  bars$open <- bars$close - 0.125
  bars$high <- bars$close + 0.5
  bars$low <- bars$close - 0.5
  bars$volume <- 1000 + seq_len(nrow(bars))
  calendar <- seq(min(days), max(days), by = "day")
  is_open <- calendar %in% days
  sessions <- data.frame(session_date = calendar, status = ifelse(is_open, "open", "closed"),
                         session_open = ifelse(is_open, "14:30:00", NA), session_close = ifelse(is_open, "21:00:00", NA))
  # Membership changes take effect at the session's open.
  membership <- data.frame(effective_from = c(utc(days[[1]] - 1), open_utc(days[c(25L, 49L)])))
  membership$knowledge_time <- membership$effective_from
  membership$source <- "lc"
  membership$members <- I(list(c("AAA", "BBB", "CCC", "DDD", "EEE"), c("AAA", "CCC", "DDD", "EEE", "FFF"),
                               c("AAA", "BBB", "CCC", "DDD", "EEE", "FFF")))
  lifetime <- data.frame(
    instrument_id = c("CCC", "EEE"),
    effective_from = open_utc(days[c(48L, 49L)]),
    effective_to = c(open_utc(days[[73L]]), as.POSIXct(NA)),
    knowledge_time = open_utc(days[c(48L, 50L)]),
    assertion = "known_inactive", terminal_event = NA_character_
  )
  list(days = days, axis = utc(days), bars = bars, sessions = sessions, membership = membership,
       lifetime = lifetime, price_carry = 5L, opening_positions = c(BBB = 10))
}

lc_prep_fixture <- function(db_path, strategy = lc_prep_strategy, snapshot_id = "lc_prep_fixture") {
  x <- lc_prep_fixture_inputs()
  facts <- ledgr::ledgr_facts(
    ledgr::ledgr_facts_sessions(x$sessions, venue_id = "V", knowledge = "assume_effective"),
    ledgr::ledgr_facts_membership_snapshots(x$membership, universe_id = "u", complete = TRUE,
                                            knowledge = "assume_effective"),
    ledgr::ledgr_facts_lifetime(x$lifetime)
  )
  snapshot <- ledgr::ledgr_snapshot_from_df(
    x$bars, data.frame(instrument_id = sort(unique(x$bars$instrument_id))),
    db_path = db_path, snapshot_id = snapshot_id, facts = facts, price_basis = "split_adjusted"
  )
  exp <- ledgr::ledgr_experiment(
    snapshot, strategy, universe = ledgr::ledgr_universe_members("u"),
    features = ledgr::ledgr_feature_map(fast = ledgr::ledgr_ind_sma(3L), ret = ledgr::ledgr_ind_returns(10L)),
    valuation_policy = ledgr::ledgr_valuation_stale(5L), cost_model = ledgr::ledgr_cost_zero(),
    opening = ledgr::ledgr_opening(cash = 10000, positions = x$opening_positions, cost_basis = c(BBB = 200)),
    history_policy = ledgr::ledgr_history_policy(price_carry = x$price_carry)
  )
  list(snapshot = snapshot, exp = exp, inputs = x)
}

lc_prep_fixture_params <- list(long = 30L, mid = 12L, short = 10L, min_obs = 8L, feature = "ret",
                               off_axis = "CCC", all_history = TRUE, trade = FALSE)

# The registered request set (LDG-3215), issued on every decided pulse:
#   R1 bar matrix, close, long lookback
#   R2 feature matrix, long lookback (on the portable shapes and H1: the
#      252-session x 500-instrument returns window)
#   R3 bar frame, close, mid lookback, decision axis, long layout
#   R4 feature frame, mid lookback, wide layout
#   R5 bar matrix, close, short lookback, min_observations
#   R6 bar frame, close, short lookback, one explicitly named instrument
#   R7, R8 (fixture only): bar frame and feature matrix, lookback = Inf
# With params$trade the strategy then trades monthly top-n momentum (the
# registered H1 strategy, as dev/bench/v0_2_3_ws16_entry/workloads.R).
lc_prep_strategy <- function(ctx, params) {
  ledgr::ledgr_history_matrix(ctx, bar = "close", lookback = params$long)
  ledgr::ledgr_history_matrix(ctx, feature = params$feature, lookback = params$long)
  ledgr::ledgr_history_frame(ctx, bar = "close", lookback = params$mid, instruments = "decision_axis",
                             layout = "long")
  ledgr::ledgr_history_frame(ctx, feature = params$feature, lookback = params$mid, layout = "wide")
  ledgr::ledgr_history_matrix(ctx, bar = "close", lookback = params$short, min_observations = params$min_obs)
  ledgr::ledgr_history_frame(ctx, bar = "close", lookback = params$short, instruments = params$off_axis,
                             layout = "long")
  if (isTRUE(params$all_history)) {
    ledgr::ledgr_history_frame(ctx, bar = "close", lookback = Inf, layout = "wide")
    ledgr::ledgr_history_matrix(ctx, feature = params$feature, lookback = Inf)
  }
  if (!isTRUE(params$trade)) return(ctx$hold())
  score <- ledgr::ledgr_signal_return(ctx, params$lookback)
  selected <- ledgr::ledgr_select_top(score, n = params$n, within = ctx$buyable)
  target <- ledgr::ledgr_target_rebalance(ctx, weights = ledgr::ledgr_weight_equal(selected), invest_fraction = 0.95,
                                          index_leavers = "keep", capital_base = "remaining_equity")
  list(targets = target)
}

# The portable shapes: the WS16 entry momentum snapshot (500 instruments,
# declared sessions) with the request set on each monthly decision.
lc_prep_shape_params <- function(off_axis) {
  list(long = 252L, mid = 63L, short = 21L, min_obs = 15L, feature = "ret", off_axis = off_axis,
       all_history = FALSE, trade = TRUE, lookback = 252L, n = 20L)
}

lc_prep_shape_experiment <- function(snapshot, universe = NULL) {
  args <- list(snapshot, lc_prep_strategy, features = ledgr::ledgr_feature_map(ret = ledgr::ledgr_ind_returns(252L)),
               schedule = ledgr::ledgr_schedule_month_start(), opening = ledgr::ledgr_opening(cash = 1e6),
               cost_model = ledgr::ledgr_cost_zero())
  if (!is.null(universe)) {
    args$universe <- ledgr::ledgr_universe_members(universe)
    args$valuation_policy <- ledgr::ledgr_valuation_stale(5L)
  }
  do.call(ledgr::ledgr_experiment, args)
}
