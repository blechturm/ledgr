corporate_action_axis_snapshot <- function(closed) {
  dates <- as.Date("2020-01-01") + 0:4
  pulses <- as.POSIXct(paste(dates, "16:00:00"), tz = "UTC")
  parent <- data.frame(
    instrument_id = "AAA", ts_utc = pulses,
    open = 10:14, high = 10:14, low = 10:14, close = 10:14,
    volume = 1000
  )
  bars <- parent
  instruments <- "AAA"
  if (isTRUE(closed)) {
    bars <- rbind(parent, data.frame(
      instrument_id = "BBB", ts_utc = pulses,
      open = 20:24, high = 20:24, low = 20:24, close = 20:24,
      volume = 1000
    ))
    instruments <- c("AAA", "BBB")
  }
  sessions <- ledgr_facts_sessions(data.frame(
    session_date = dates,
    status = "open",
    session_open = "09:30:00",
    session_close = "16:00:00",
    knowledge_time = as.POSIXct(dates, tz = "UTC") - 1,
    stringsAsFactors = FALSE
  ), venue_id = "XNYS")
  membership <- ledgr_facts_membership_snapshots(data.frame(
    instrument_id = "AAA",
    effective_from = pulses[[1L]],
    knowledge_time = pulses[[1L]] - 1,
    stringsAsFactors = FALSE
  ), universe_id = "research", complete = TRUE)
  lifetime <- ledgr_facts_lifetime(data.frame(
    instrument_id = "AAA",
    effective_from = pulses[[4L]],
    knowledge_time = pulses[[1L]] - 1,
    assertion = "known_inactive",
    terminal_event = "acquired",
    stringsAsFactors = FALSE
  ))
  action <- ledgr_facts_equity_corporate_actions(data.frame(
    fact_id = "axis-cash",
    subtype = "cash_acquisition",
    parent_instrument_id = "AAA",
    entitlement_time = pulses[[4L]],
    effective_time = pulses[[4L]],
    knowledge_time = pulses[[1L]],
    complete = TRUE,
    provenance_tier = "snapshot_bound",
    gross_cash_per_parent_unit = 14,
    gross_cash_validated = TRUE,
    recipient_instrument_id = NA_character_,
    recipient_identity_validated = FALSE,
    recipient_quantity_per_parent_unit = NA_real_,
    recipient_quantity_validated = FALSE,
    stringsAsFactors = FALSE
  ))
  list(
    snapshot = ledgr_snapshot_from_df(
      bars,
      instruments_df = data.frame(instrument_id = instruments),
      facts = ledgr_facts(sessions, membership, lifetime, action),
      price_basis = "split_adjusted"
    ),
    pulses = pulses
  )
}

corporate_action_axis_state <- function(bt) {
  opened <- ledgr:::ledgr_backtest_read_connection(bt)
  on.exit(opened$close(), add = TRUE)
  rows <- DBI::dbGetQuery(
    opened$con,
    "SELECT ts_utc, state_json FROM strategy_state WHERE run_id = ? ORDER BY ts_utc",
    params = list(bt$run_id)
  )
  data.frame(
    ts_utc = as.POSIXct(rows$ts_utc, tz = "UTC"),
    axis = vapply(rows$state_json, function(value) {
      ledgr:::ledgr_json_read_nested(value)$axis
    }, character(1)),
    cross_mean = vapply(rows$state_json, function(value) {
      ledgr:::ledgr_json_read_nested(value)$cross_mean
    }, character(1)),
    stringsAsFactors = FALSE
  )
}

# ledgr-test-profile: review
testthat::test_that("[LTB-0056] physical recipient closure does not leak before settlement", {
  fixtures <- list(
    unclosed = corporate_action_axis_snapshot(FALSE),
    closed = corporate_action_axis_snapshot(TRUE)
  )
  withr::defer(lapply(fixtures, function(value) {
    ledgr_snapshot_close(value$snapshot)
  }))
  strategy <- function(ctx, params) {
    targets <- ctx$hold()
    if (identical(ctx$ts_utc, params$first_pulse)) targets[["AAA"]] <- 2
    values <- ctx$vec$feature("sma_2")
    list(
      targets = targets,
      state_update = list(
        axis = paste(ctx$vec$id, collapse = "|"),
        cross_mean = if (all(is.na(values))) {
          "unavailable"
        } else {
          format(mean(values, na.rm = TRUE), scientific = FALSE)
        }
      )
    )
  }
  runs <- lapply(names(fixtures), function(name) {
    value <- fixtures[[name]]
    exp <- ledgr_experiment(
      value$snapshot,
      strategy,
      features = list(ledgr_ind_sma(2)),
      opening = ledgr_opening(
        cash = 1000,
        positions = c(AAA = 1),
        cost_basis = c(AAA = 10)
      ),
      universe = ledgr_universe_members("research"),
      valuation_policy = ledgr_valuation_stale(0L),
      cost_model = ledgr_cost_zero(),
      corporate_action_policy = ledgr_corporate_actions_research()
    )
    ledgr_run(
      exp,
      params = list(
        first_pulse = ledgr:::ledgr_normalize_ts_utc(value$pulses[[1L]])
      ),
      run_id = paste0("axis-", name)
    )
  })
  names(runs) <- names(fixtures)
  withr::defer(lapply(runs, close))
  settlement <- fixtures$closed$pulses[[4L]]
  pre_settlement <- fixtures$closed$pulses[[3L]]
  availability <- lapply(runs, function(bt) {
    value <- as.data.frame(ledgr_results(bt, "availability"))
    value <- value[
      as.POSIXct(value$ts_utc, tz = "UTC") <= pre_settlement,
      ,
      drop = FALSE
    ]
    value$run_id <- NULL
    value
  })
  state <- lapply(runs, function(bt) {
    value <- corporate_action_axis_state(bt)
    value[value$ts_utc <= pre_settlement, , drop = FALSE]
  })
  fills <- lapply(runs, function(bt) {
    value <- as.data.frame(ledgr_results(bt, "fills"))
    value <- value[
      as.POSIXct(value$ts_utc, tz = "UTC") <= pre_settlement,
      ,
      drop = FALSE
    ]
    value[, setdiff(names(value), c("run_id", "event_id")), drop = FALSE]
  })
  testthat::expect_identical(availability$closed, availability$unclosed)
  testthat::expect_identical(state$closed, state$unclosed)
  testthat::expect_identical(fills$closed, fills$unclosed)
  testthat::expect_true(nrow(fills$closed) > 0L)
  testthat::expect_true(all(state$closed$axis == "AAA"))
  testthat::expect_identical(
    state$closed$cross_mean,
    c("unavailable", "10.5", "11.5")
  )
  closed_view <- ledgr_results(runs$closed, "availability")
  child_pre <- closed_view[
    closed_view$instrument_id == "BBB" &
      as.POSIXct(closed_view$ts_utc, tz = "UTC") < settlement,
    ,
    drop = FALSE
  ]
  testthat::expect_equal(nrow(child_pre), 0L)
})
