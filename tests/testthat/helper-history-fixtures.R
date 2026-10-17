# Shared Workstream 42 public-history fixtures (LDG-3062..3064).

# Eight venue sessions (closes at 21:00 UTC). AAA closes at 10 + k on session
# k, BBB at 20 + k but has no print on sessions 3 and 4, and CCC closes at
# 30 + k through session 5. A known_inactive lifetime fact for CCC is
# effective at session 6's open and only becomes known at session 7's open.
ws42_history_fixture <- function(strategy = function(ctx, params) ctx$hold(),
                                 policy = ledgr_history_policy(),
                                 opening = ledgr_opening(cash = 1000),
                                 features = ledgr_feature_map(fast = ledgr_ind_sma(2)),
                                 availability = TRUE,
                                 dividend = NULL,
                                 ccc_known = 7L) {
  days <- as.Date("2021-01-04") + c(0:4, 7:9)
  utc <- function(d) as.POSIXct(paste(d, "21:00:00"), tz = "UTC")
  k <- seq_along(days)
  bars <- rbind(
    data.frame(instrument_id = "AAA", ts_utc = utc(days), close = 10 + k),
    data.frame(instrument_id = "BBB", ts_utc = utc(days[-c(3, 4)]), close = 20 + k[-c(3, 4)]),
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
      features = features, valuation_policy = ledgr_valuation_stale(3),
      cost_model = ledgr_cost_zero(), opening = opening, history_policy = policy
    )
  } else {
    NULL
  }
  list(snapshot = snapshot, exp = exp, days = days, axis = utc(days))
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
