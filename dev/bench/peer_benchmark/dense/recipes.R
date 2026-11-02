# Public fixtures only. No old harness is loaded.
# Historical strategy factory/body below retained verbatim from
# peer_benchmark.R::peer_strategy at 7879e8ba, with only the factory renamed.
dense_historical_strategy <- function(fast_id, slow_id) {
  force(fast_id); force(slow_id)
  function(ctx, params) {
    targets <- ctx$hold()
    instruments <- ctx$universe
    fast <- ctx[[fast_id]]
    slow <- ctx[[slow_id]]
    current_above <- is.finite(fast) & is.finite(slow) & fast > slow
    cross_up <- current_above & !ctx$state$above
    cross_down <- !current_above & ctx$state$above
    if (any(cross_up)) targets[instruments[cross_up]] <- 1
    if (any(cross_down)) targets[instruments[cross_down]] <- 0
    ledgr_strategy_result(targets, above = current_above)
  }
}


dense_transition <- function(ctx, params) {
  fast <- ctx$fast
  slow <- ctx$slow
  ids <- ctx$universe
  usable <- is.finite(fast) & is.finite(slow)
  above <- usable & fast > slow
  targets <- ctx$hold()
  enter <- ctx$state$usable & usable & above & !ctx$state$above
  exit <- ctx$state$usable & usable & !above & ctx$state$above
  targets[enter] <- 1
  targets[exit] <- 0
  ledgr_strategy_result(targets, above = above, usable = usable)
}

dense_positive_return <- function(ctx, params) {
  score <- ctx$return_10
  targets <- ctx$hold()
  usable <- is.finite(score)
  targets[usable] <- as.numeric(score[usable] > 0)
  targets
}

dense_mean_reversion <- function(ctx, params) {
  average <- ctx$average
  usable <- is.finite(average)
  targets <- ctx$hold()
  targets[usable & ctx$close < 0.99 * average] <- 1
  targets[usable & ctx$close >= average] <- 0
  targets
}

dense_ema_trend <- function(ctx, params) {
  average <- ctx$average
  usable <- is.finite(average)
  targets <- ctx$hold()
  targets[usable] <- as.numeric(ctx$close[usable] > average[usable])
  targets
}

dense_cost_final <- function(ctx, params) {
  targets <- ctx$hold()
  day <- substr(ctx$ts_utc, 1L, 10L)
  if (identical(day, "2020-01-01")) targets[c("AAA", "BBB")] <- c(1, 0)
  if (identical(day, "2020-01-08")) targets["AAA"] <- 3
  targets
}

dense_cases <- function() {
  list(
    historical_start_dense = list(recipe = "historical", facts = FALSE, late = FALSE),
    historical_start_facts = list(recipe = "historical", facts = TRUE, late = FALSE),
    transition = list(recipe = "transition", facts = FALSE, late = FALSE),
    positive_return = list(recipe = "positive_return", facts = FALSE, late = FALSE),
    mean_reversion = list(recipe = "mean_reversion", facts = FALSE, late = FALSE),
    ema_trend = list(recipe = "ema_trend", facts = FALSE, late = FALSE),
    historical_late_dense = list(recipe = "historical", facts = FALSE, late = TRUE),
    historical_late_facts = list(recipe = "historical", facts = TRUE, late = TRUE),
    cost_final = list(recipe = "cost_final", facts = FALSE, late = FALSE)
  )
}

dense_fixture <- function(case) {
  cost <- identical(case$recipe, "cost_final")
  if (cost) {
    # Input data retyped from A0 fixtures.R:12-51; no fixture code imported.
    stamp <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:7
    bars <- data.frame(
      instrument_id = rep(c("AAA", "BBB"), each = 8L), ts_utc = rep(stamp, 2L),
      open = c(100,101,103,102,104,107,106,108, 50,51,50,49,48,50,52,51),
      high = c(101,103,104,103,106,108,108,109, 51,52,51,50,49,51,53,52),
      low = c(99,100,101,101,103,106,105,107, 49,50,49,48,47,49,51,50),
      close = c(100,102,103,102,105,107,106,108, 50,51,50,49,48,50,52,51),
      volume = rep(c(1000, 2000), each = 8L)
    )
  } else {
    bars <- ledgr_sim_bars(12L, 90L, seed = 20260530L,
      start = "2020-01-01", instrument_prefix = "P")
    bars$ts_utc <- bars$ts_utc + 21 * 3600
  }
  days <- sort(unique(as.Date(bars$ts_utc)))
  facts <- NULL
  if (case$facts) {
    calendar <- seq(min(days), max(days), by = "day")
    open <- calendar %in% days
    sessions <- data.frame(session_date = calendar,
      status = ifelse(open, "open", "closed"),
      session_open = ifelse(open, "14:30:00", NA),
      session_close = ifelse(open, "21:00:00", NA))
    prior <- as.POSIXct(paste(days[1] - 1, "21:00:00"), tz = "UTC")
    members <- data.frame(effective_from = prior, knowledge_time = prior, source = "probe")
    members$members <- I(list(sort(unique(bars$instrument_id))))
    facts <- ledgr_facts(
      ledgr_facts_sessions(sessions, venue_id = "V", knowledge = "assume_effective"),
      ledgr_facts_membership_snapshots(members, universe_id = "u", complete = TRUE,
        knowledge = "assume_effective")
    )
  }
  features <- switch(case$recipe,
    historical = ledgr_feature_map(
      fast = ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
      slow = ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L)),
    transition = ledgr_feature_map(
      fast = ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
      slow = ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L)),
    positive_return = ledgr_feature_map(return_10 = ledgr_ind_returns(10L)),
    mean_reversion = ledgr_feature_map(average = ledgr_ind_ttr("SMA", input = "close", n = 10L)),
    ema_trend = ledgr_feature_map(average = ledgr_ind_ttr("EMA", input = "close", n = 5L)),
    cost_final = list()
  )
  strategy <- if (identical(case$recipe, "historical")) {
    dense_historical_strategy("fast", "slow")
  } else get(paste0("dense_", case$recipe), mode = "function")
  state <- if (case$recipe == "transition") {
    list(above = FALSE, usable = FALSE)
  } else if (case$recipe == "historical") {
    list(above = FALSE)
  } else {
    list()
  }
  list(bars = bars, facts = facts, features = features, strategy = strategy,
    asset_state = state,
    opening = ledgr_opening(cash = if (cost) 10000 else 1e7,
      date = if (case$late) days[30L] else NULL),
    cost = if (cost) ledgr_cost_chain(ledgr_cost_spread_bps(5), ledgr_cost_fixed_fee(1))
      else ledgr_cost_zero())
}
