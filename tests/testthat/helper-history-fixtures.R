# Shared Workstream 42 public-history fixtures (LDG-3062..3064).

# Eight venue sessions (closes at 21:00 UTC). AAA closes at 10 + k on session
# k, BBB at 20 + k but has no print on sessions 3 and 4, and CCC closes at
# 30 + k through session 5. A known_inactive lifetime fact for CCC is
# effective at session 6's open and only becomes known at session 7's open.
ws42_history_fixture <- function(strategy = function(ctx, params) ctx$hold(),
                                 policy = ledgr_history_policy(),
                                 opening = ledgr_opening(cash = 1000),
                                 features = ledgr_feature_map(fast = ledgr_ind_sma(2)),
                                 schedule = NULL,
                                 availability = TRUE,
                                 dividend = NULL,
                                 ccc_known = 7L,
                                 bbb_gaps = c(3L, 4L),
                                 valuation_policy = ledgr_valuation_stale(3),
                                 corporate_action_policy = ledgr_corporate_actions_research()) {
  days <- as.Date("2021-01-04") + c(0:4, 7:9)
  utc <- function(d) as.POSIXct(paste(d, "21:00:00"), tz = "UTC")
  k <- seq_along(days)
  bars <- rbind(
    data.frame(instrument_id = "AAA", ts_utc = utc(days), close = 10 + k),
    data.frame(instrument_id = "BBB", ts_utc = utc(days[-bbb_gaps]), close = 20 + k[-bbb_gaps]),
    data.frame(instrument_id = "CCC", ts_utc = utc(days[1:5]), close = 30 + k[1:5])
  )
  bars$open <- bars$high <- bars$low <- bars$close
  bars$volume <- 100 + seq_len(nrow(bars))
  calendar <- seq(min(days), max(days), by = "day")
  open <- calendar %in% days
  sessions <- data.frame(
    session_date = calendar, status = ifelse(open, "open", "closed"),
    session_open = ifelse(open, "14:30:00", NA), session_close = ifelse(open, "21:00:00", NA)
  )
  membership <- data.frame(
    effective_from = utc(days[[1]] - 1), knowledge_time = utc(days[[1]] - 1), source = "t"
  )
  membership$members <- I(list(c("AAA", "BBB", "CCC")))
  # `dividend` names AAA's entitlement and effective sessions; the gross
  # amount is 0.5 per share and it is known from the first session's open.
  actions <- if (is.null(dividend)) {
    NULL
  } else {
    ledgr_facts_equity_corporate_actions(data.frame(
      fact_id = "dividend-1",
      subtype = "ordinary_cash_dividend",
      parent_instrument_id = "AAA",
      entitlement_time = utc(days[[dividend[[1L]]]]),
      effective_time = utc(days[[dividend[[2L]]]]),
      knowledge_time = utc(days[[1L]]) - 6.5 * 3600,
      complete = TRUE,
      provenance_tier = "snapshot_bound",
      gross_cash_per_parent_unit = 0.5,
      gross_cash_validated = TRUE,
      recipient_identity_validated = FALSE,
      recipient_quantity_validated = FALSE,
      source = "ws42",
      stringsAsFactors = FALSE
    ))
  }
  facts <- do.call(ledgr_facts, Filter(Negate(is.null), list(
    actions,
    ledgr_facts_sessions(sessions, venue_id = "V", knowledge = "assume_effective"),
    ledgr_facts_membership_snapshots(
      membership, universe_id = "u", complete = TRUE, knowledge = "assume_effective"
    ),
    ledgr_facts_lifetime(data.frame(
      instrument_id = "CCC",
      effective_from = utc(days[[6]]) - 6.5 * 3600,
      knowledge_time = utc(days[[ccc_known]]) - 6.5 * 3600,
      assertion = "known_inactive",
      terminal_event = NA_character_
    ))
  )))
  snapshot <- ledgr_snapshot_from_df(
    bars, data.frame(instrument_id = c("AAA", "BBB", "CCC")),
    db_path = tempfile(fileext = ".duckdb"), facts = facts, price_basis = "split_adjusted"
  )
  exp <- if (isTRUE(availability)) {
    ledgr_experiment(
      snapshot, strategy, universe = ledgr_universe_members("u"),
      features = features, valuation_policy = valuation_policy,
      cost_model = ledgr_cost_zero(), opening = opening, history_policy = policy,
      schedule = schedule,
      corporate_action_policy = corporate_action_policy
    )
  } else {
    NULL
  }
  list(snapshot = snapshot, exp = exp, days = days, axis = utc(days))
}

ws42_with_schedule <- function(exp, schedule) {
  schedule <- ledgr:::ledgr_schedule_validate(schedule)
  exp$schedule <- schedule
  strategy <- exp$strategy
  attr(strategy, "ledgr_schedule") <- unclass(schedule)
  exp$strategy <- strategy
  exp
}

ws16_attach_schedule_to_strategy_for_legacy_path_test <- function(strategy, schedule) {
  stopifnot(is.function(strategy))
  if (!is.null(attr(strategy, "ledgr_schedule", exact = TRUE))) {
    ledgr:::ledgr_schedule_abort("The test strategy already carries a schedule.")
  }
  attr(strategy, "ledgr_schedule") <- unclass(ledgr:::ledgr_schedule_validate(schedule))
  strategy
}

ws16_weight_equal_from_legacy_selection <- function(selection, ...) {
  if (inherits(selection, "ledgr_selection")) {
    selection <- names(selection)[!is.na(selection) & as.logical(selection)]
  }
  ledgr_weight_equal(selection, ...)
}

ws16_select_top_for_legacy_test <- function(score, n, ...) {
  within <- attr(score, "eligible", exact = TRUE)
  ids <- ledgr_select_top(score, n = n, within = within)
  universe <- names(score)
  out <- ledgr_selection(stats::setNames(universe %in% ids, universe), universe = universe)
  if (length(ids) == 0L) class(out) <- c("ledgr_empty_selection", class(out))
  out
}

ws16_target_from_legacy_call <- function(ctx,
                                         weights = NULL,
                                         equity_fraction = NULL,
                                         ...) {
  if ((!is.list(ctx) && !is.environment(ctx)) &&
      (is.list(weights) || is.environment(weights))) {
    swap <- ctx
    ctx <- weights
    weights <- swap
  }
  if (inherits(weights, "ledgr_weights")) weights <- unclass(weights)
  if (is.null(ctx$member)) ctx$member <- stats::setNames(rep(TRUE, length(ctx$universe)), ctx$universe)
  if (is.null(ctx$position)) ctx$position <- stats::setNames(numeric(length(ctx$universe)), ctx$universe)
  if (is.null(ctx$holding_value)) ctx$holding_value <- stats::setNames(numeric(length(ctx$universe)), ctx$universe)
  args <- list(ctx = ctx, weights = weights, ...)
  if (!is.null(equity_fraction)) args$invest_fraction <- equity_fraction
  held_leavers <- ctx$universe[as.numeric(ctx$position) != 0 & !as.logical(ctx$member)]
  if (length(held_leavers) > 0L && is.null(args$index_leavers) && is.null(args$keep)) {
    args$index_leavers <- "keep"
  }
  if (is.null(args$capital_base) && length(weights) > 0L &&
      (any(as.numeric(ctx$position) != 0) || !is.null(args$keep))) {
    args$capital_base <- "remaining_equity"
  }
  out <- do.call(ledgr_target_rebalance, args)
  attr(out, "origin") <- NULL
  attr(out, "sizing") <- NULL
  out
}

ws42_iso <- function(x) format(x, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

ws42_capture_run <- function(fixture_args = list(), reader, run_id = "history") {
  seen <- new.env()
  # The strategy preflight refuses free function symbols, so the reader's body
  # is spliced into the spy rather than called through a captured closure.
  spy <- function(ctx, params) {
    seen[[ctx$ts_utc]] <- NULL
    ctx$hold()
  }
  body(spy)[[2L]][[3L]] <- body(reader)
  fixture <- do.call(ws42_history_fixture, c(list(strategy = spy), fixture_args))
  bt <- ledgr_run(fixture$exp, run_id = run_id)
  list(fixture = fixture, bt = bt, seen = seen)
}


# A strategy that records `reader(ctx)` under "<params$tag> <ctx$ts_utc>" and
# holds. The strategy preflight refuses free function symbols, so the reader's
# body is spliced into the spy rather than called through a captured closure.
ws42_spy <- function(seen, reader) {
  spy <- function(ctx, params) {
    seen[[paste(params$tag, ctx$ts_utc)]] <- NULL
    ctx$hold()
  }
  body(spy)[[2L]][[3L]] <- body(reader)
  spy
}

ws42_dense_snapshot <- function() {
  ts <- as.POSIXct("2021-01-04 21:00:00", tz = "UTC") + 86400 * 0:5
  bars <- data.frame(
    ts_utc = rep(ts, 2L), instrument_id = rep(c("AAA", "BBB"), each = 6L),
    close = c(11:16, 21:26)
  )
  bars$open <- bars$high <- bars$low <- bars$close
  bars$volume <- 100
  ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
}
