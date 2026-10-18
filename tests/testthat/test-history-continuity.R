# Buys one AAA share on session 5 (the first test window's last pulse) and
# sells two on session 7, which closes the two opening shares bought at 10
# under FIFO.
ws42_continuity_strategy <- function(ctx, params) {
  target <- ctx$hold()
  day <- substr(ctx$ts_utc, 1L, 10L)
  if (identical(day, "2021-01-08")) {
    target[["AAA"]] <- target[["AAA"]] + params$qty
  }
  if (identical(day, "2021-01-12")) {
    target[["AAA"]] <- target[["AAA"]] - 2
  }
  target
}

ws42_continuity_fixture <- function() {
  ws42_history_fixture(
    strategy = ws42_continuity_strategy,
    opening = ledgr_opening(cash = 1000, positions = c(AAA = 2, BBB = 1), cost_basis = c(AAA = 10, BBB = 21)),
    dividend = c(5L, 5L),
    bbb_gaps = c(4L, 5L, 6L),
    valuation_policy = ledgr_valuation_stale(1, exhausted = "freeze"),
    corporate_action_policy = ledgr_corporate_actions(cash_posting = "next_open")
  )
}

ws42_continuity_folds <- function(days) {
  ledgr:::ledgr_fold_list(
    list(
      ledgr_fold(days[[1L]], days[[2L]], days[[3L]], days[[5L]], fold_seq = 1L),
      ledgr_fold(days[[1L]], days[[5L]], days[[6L]], days[[8L]], fold_seq = 2L)
    ),
    constructor = list(type_id = "explicit")
  )
}

ws42_frame <- function(x, drop = character()) {
  x <- as.data.frame(x)
  x[, setdiff(names(x), drop), drop = FALSE]
}

ws42_rows <- function(runs, what, drop) {
  out <- do.call(rbind, lapply(runs, function(bt) ws42_frame(ledgr_results(bt, what), drop)))
  rownames(out) <- NULL
  out
}

# AAA and BBB close at 10 + k and 20 + k on the eight fixture sessions; the
# holdings open with AAA 2 and BBB 1. One BBB corporate action has its
# entitlement and effective clocks at session `effective` and becomes known
# at session `known`'s open (LDG-3064 close review F1).
ws42_late_action_fixture <- function(subtype, policy, effective = 4L, known = 7L, buy_bbb = 0) {
  days <- as.Date("2021-01-04") + c(0:4, 7:9)
  utc <- function(d) as.POSIXct(paste(d, "21:00:00"), tz = "UTC")
  k <- seq_along(days)
  bars <- rbind(
    data.frame(instrument_id = "AAA", ts_utc = utc(days), close = 10 + k),
    data.frame(instrument_id = "BBB", ts_utc = utc(days), close = 20 + k)
  )
  bars$open <- bars$high <- bars$low <- bars$close
  bars$volume <- 100
  calendar <- seq(min(days), max(days), by = "day")
  open <- calendar %in% days
  sessions <- data.frame(
    session_date = calendar, status = ifelse(open, "open", "closed"),
    session_open = ifelse(open, "14:30:00", NA), session_close = ifelse(open, "21:00:00", NA)
  )
  membership <- data.frame(
    effective_from = utc(days[[1]] - 1), knowledge_time = utc(days[[1]] - 1), source = "t"
  )
  membership$members <- I(list(c("AAA", "BBB")))
  action <- data.frame(
    fact_id = "ca-1", subtype = subtype, parent_instrument_id = "BBB",
    entitlement_time = utc(days[[effective]]), effective_time = utc(days[[effective]]),
    knowledge_time = utc(days[[known]]) - 6.5 * 3600,
    complete = TRUE, provenance_tier = "snapshot_bound",
    gross_cash_per_parent_unit = if (identical(subtype, "ordinary_cash_dividend")) 0.5 else NA_real_,
    gross_cash_validated = identical(subtype, "ordinary_cash_dividend"),
    recipient_identity_validated = FALSE, recipient_quantity_validated = FALSE,
    source = "ws42", stringsAsFactors = FALSE
  )
  facts <- ledgr_facts(
    ledgr_facts_equity_corporate_actions(action),
    ledgr_facts_sessions(sessions, venue_id = "V", knowledge = "assume_effective"),
    ledgr_facts_membership_snapshots(
      membership, universe_id = "u", complete = TRUE, knowledge = "assume_effective"
    )
  )
  snapshot <- ledgr_snapshot_from_df(
    bars, data.frame(instrument_id = c("AAA", "BBB")),
    db_path = tempfile(fileext = ".duckdb"), facts = facts, price_basis = "split_adjusted"
  )
  # Buys `params$bbb` BBB shares on session 5, the first window's last pulse.
  strategy <- function(ctx, params) {
    target <- ctx$hold()
    if (identical(substr(ctx$ts_utc, 1L, 10L), "2021-01-08")) {
      target[["BBB"]] <- target[["BBB"]] + params$bbb
    }
    target
  }
  exp <- ledgr_experiment(
    snapshot, strategy, universe = ledgr_universe_members("u"),
    valuation_policy = ledgr_valuation_stale(3), cost_model = ledgr_cost_zero(),
    opening = ledgr_opening(cash = 1000, positions = c(AAA = 2, BBB = 1), cost_basis = c(AAA = 10, BBB = 21)),
    corporate_action_policy = policy
  )
  list(snapshot = snapshot, exp = exp, days = days, params = list(bbb = buy_bbb))
}

# Non-opening ledger rows, equity and diagnostics of one run, or of a chain's
# test runs concatenated.
ws42_chain_record <- function(runs) {
  events <- ws42_rows(runs, "ledger", c("event_id", "run_id", "event_seq"))
  events <- events[!grepl("opening", events$meta_json, fixed = TRUE), ]
  rownames(events) <- NULL
  list(
    events = events,
    equity = ws42_rows(runs, "equity", character())[, c("ts_utc", "cash", "positions_value", "equity")],
    diagnostics = ws42_rows(runs, "diagnostics", c("run_id", "diagnostic_seq"))
  )
}

# ledgr-test-profile: review
testthat::test_that("[LTB-0303] carry_test_state windows are one economic chain equal to one run", {
  fixture <- ws42_continuity_fixture()
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  exp <- fixture$exp
  days <- fixture$days
  grid <- ledgr_param_grid(list(qty = 1))
  folds <- ws42_continuity_folds(days)

  # One public run over the same decision pulses with the same parameters.
  single <- ledgr:::ledgr_run_window(
    exp, params = list(qty = 1),
    window = ledgr:::ledgr_experiment_window(exp, days[[3L]], days[[8L]]),
    run_id = "continuity-single"
  )
  on.exit(close(single), add = TRUE)
  chain <- ledgr_walk_forward(
    exp, grid, folds, selection_rule = ledgr_rule_argmax("annualized_return"), seed = 1L
  )
  on.exit(lapply(chain$test_runs, close), add = TRUE)
  testthat::expect_identical(chain$status, "DONE")
  testthat::expect_identical(length(chain$test_runs), 2L)

  # The window's last decision (session 5) is filled by the same run at the
  # next session's open: one AAA share at 16 on 2021-01-11 14:30 UTC.
  first_fills <- ledgr_results(chain$test_runs[[1L]], "fills")
  testthat::expect_identical(first_fills$instrument_id, "AAA")
  testthat::expect_identical(first_fills$side, "BUY")
  testthat::expect_identical(first_fills$qty, 1)
  testthat::expect_identical(first_fills$price, 16)
  testthat::expect_identical(
    as.numeric(first_fills$ts_utc),
    as.numeric(as.POSIXct("2021-01-11 14:30:00", tz = "UTC"))
  )
  second_fills <- ledgr_results(chain$test_runs[[2L]], "fills")
  testthat::expect_identical(second_fills$side, "SELL")
  testthat::expect_identical(second_fills$price, 18)

  fill_cols <- c("ts_utc", "instrument_id", "side", "qty", "price", "fee")
  testthat::expect_identical(
    ws42_rows(chain$test_runs, "fills", character())[, fill_cols],
    ws42_frame(ledgr_results(single, "fills"))[, fill_cols]
  )

  # The session-5 next_open dividend binds the two shares held before the
  # boundary fill and posts 1.0 at session 6 in the next window's run.
  dividend <- function(bt) {
    ledger <- ws42_frame(ledgr_results(bt, "ledger"))
    ledger <- ledger[ledger$event_type == "CASHFLOW" & grepl("corporate_action_cash", ledger$meta_json, fixed = TRUE), ]
    data.frame(ts_utc = as.numeric(ledger$ts_utc), meta = ledger$meta_json, stringsAsFactors = FALSE)
  }
  testthat::expect_identical(nrow(dividend(chain$test_runs[[1L]])), 0L)
  posted <- dividend(chain$test_runs[[2L]])
  testthat::expect_identical(posted$ts_utc, as.numeric(as.POSIXct("2021-01-11 21:00:00", tz = "UTC")))
  testthat::expect_true(grepl('"entitled_quantity":2', posted$meta, fixed = TRUE))
  testthat::expect_identical(posted, dividend(single))

  # Equity and marks: BBB's last print is session 3 (23), stale at session 4,
  # frozen from session 5 through 6 and observed again at session 7 (27).
  equity_cols <- c("ts_utc", "cash", "positions_value", "equity")
  chain_equity <- ws42_rows(chain$test_runs, "equity", character())[, equity_cols]
  testthat::expect_identical(chain_equity, ws42_frame(ledgr_results(single, "equity"))[, equity_cols])
  testthat::expect_identical(chain_equity$equity, c(1049, 1051, 1053, 1056, 1063, 1067))
  testthat::expect_identical(chain_equity$cash, c(1000, 1000, 1000, 985, 985, 1021))
  # Ledger reconstruction of each window, including its carried opening lots
  # and the boundary fill after the first window's last pulse, agrees.
  con <- ledgr:::get_connection(fixture$snapshot)
  for (bt in chain$test_runs) {
    rebuilt <- ledgr_state_reconstruct(bt$run_id, con)$equity_curve
    testthat::expect_identical(rebuilt$equity, ws42_frame(ledgr_results(bt, "equity"))$equity)
  }

  # FIFO lots cross the boundary: the session-8 sale closes the two opening
  # shares bought at 10, realizing 2 * (18 - 10) = 16, as in the single run.
  trade_cols <- c("instrument_id", "side", "qty", "price", "fee", "realized_pnl")
  chain_trades <- ws42_frame(ledgr_results(chain$test_runs[[2L]], "trades"))
  single_trades <- ws42_frame(ledgr_results(single, "trades"))
  testthat::expect_identical(chain_trades$realized_pnl, 16)
  testthat::expect_identical(
    chain_trades[, trade_cols],
    single_trades[, trade_cols]
  )

  # Decision traces, freeze state and the boundary execution agree too.
  diag_drop <- c("run_id", "diagnostic_seq")
  testthat::expect_identical(
    ws42_rows(chain$test_runs, "diagnostics", diag_drop),
    ws42_frame(ledgr_results(single, "diagnostics"), diag_drop)
  )
  availability_cols <- c("ts_utc", "instrument_id", "priced", "mark_source", "mark_age", "target_restricted")
  testthat::expect_identical(
    ws42_rows(chain$test_runs, "availability", character())[, availability_cols],
    ws42_frame(ledgr_results(single, "availability"))[, availability_cols]
  )
  bbb <- ws42_rows(chain$test_runs, "availability", character())
  bbb <- bbb[bbb$instrument_id == "BBB", ]
  testthat::expect_identical(bbb$mark_source, c("current_close", "stale_close", "frozen_close", "frozen_close", "current_close", "current_close"))

  # Standalone and flat windows keep their terminal rule: the last decision
  # is recorded but not executed, and nothing crosses.
  standalone <- ledgr:::ledgr_run_window(
    exp, params = list(qty = 1),
    window = ledgr:::ledgr_experiment_window(exp, days[[3L]], days[[5L]]),
    run_id = "continuity-standalone"
  )
  on.exit(close(standalone), add = TRUE)
  testthat::expect_identical(nrow(ledgr_results(standalone, "fills")), 0L)
  standalone_diag <- ws42_frame(ledgr_results(standalone, "diagnostics"))
  testthat::expect_true("final_pulse_no_execution" %in% standalone_diag$reason_code)
  flat <- suppressWarnings(ledgr_walk_forward(
    exp, grid, folds, selection_rule = ledgr_rule_argmax("annualized_return"), seed = 1L,
    opening_state_policy = "flat_test_state"
  ))
  on.exit(lapply(flat$test_runs, close), add = TRUE)
  testthat::expect_identical(nrow(ledgr_results(flat$test_runs[[1L]], "fills")), 0L)
  flat_second <- ws42_frame(ledgr_results(flat$test_runs[[2L]], "equity"))
  testthat::expect_identical(flat_second$cash[[1L]], 1000)
  testthat::expect_identical(flat_second$equity[[1L]], 1000 + 2 * 16 + 23)
  testthat::expect_identical(nrow(dividend(flat$test_runs[[2L]])), 0L)

  # Corporate actions that one run settles after the first window carry over
  # (close review F1): every row the first window bound but would settle
  # later, cash entitlement, disposition or quantity effect, becomes due in
  # the second window on the pulse one run uses. Folds as above; BBB closes
  # at 20 + k.
  cases <- list(
    # Effective at session 4, known at 7: one run posts 0.5 on one share at
    # session 7 as a late arrival.
    late_dividend = list(
      args = list("ordinary_cash_dividend", ledgr_corporate_actions_research()),
      event = "CASHFLOW", ts = "2021-01-12 21:00:00", final = 1064.5, status = "DONE"
    ),
    # Effective at session 4, known at 7: one run disposes of the BBB share at
    # session 7's close of 27.
    late_acquisition = list(
      args = list("cash_acquisition", ledgr_corporate_actions_research()),
      event = "DISPOSITION", ts = "2021-01-12 21:00:00", final = 1063, status = "DONE"
    ),
    # A refused spin-off and a refused disposition stop one run at session 7,
    # after valuing session 6; the chain stops there too.
    refused_spin_off = list(
      args = list("spin_off", ledgr_corporate_actions(unsupported_quantity = "refuse")),
      event = NULL, final = 1058, status = "PARTIAL",
      reason = "corporate_action_quantity_refused"
    ),
    strict_acquisition = list(
      args = list("cash_acquisition", ledgr_corporate_actions_strict()),
      event = NULL, final = 1058, status = "PARTIAL",
      reason = "terminal_settlement_unsupported"
    ),
    # Entitled at the second window's first pulse (session 6) and paid at the
    # next open: the entitlement binds the one share held before the boundary
    # fill of three more at 26, and posts 0.5 at session 7.
    next_pulse_dividend = list(
      args = list("ordinary_cash_dividend", ledgr_corporate_actions(cash_posting = "next_open"),
                  effective = 6L, known = 1L, buy_bbb = 3),
      event = "CASHFLOW", ts = "2021-01-12 21:00:00", final = 1070.5, status = "DONE"
    ),
    # Effective at session 6, known at 8: one run disposes of all four shares
    # at session 8's close of 28.
    next_pulse_acquisition = list(
      args = list("cash_acquisition", ledgr_corporate_actions_research(),
                  effective = 6L, known = 8L, buy_bbb = 3),
      event = "DISPOSITION", ts = "2021-01-13 21:00:00", final = 1070, status = "DONE"
    )
  )
  for (name in names(cases)) {
    case <- cases[[name]]
    late <- do.call(ws42_late_action_fixture, case$args)
    one <- ledgr:::ledgr_run_window(
      late$exp, params = late$params,
      window = ledgr:::ledgr_experiment_window(late$exp, late$days[[3L]], late$days[[8L]]),
      run_id = paste0("late-single-", name)
    )
    late_chain <- suppressWarnings(ledgr_walk_forward(
      late$exp, ledgr_param_grid(late$params), ws42_continuity_folds(late$days),
      selection_rule = ledgr_rule_argmax("annualized_return"), seed = 1L
    ))
    expected <- ws42_chain_record(list(one))
    testthat::expect_identical(late_chain$status, case$status, info = name)
    testthat::expect_identical(ws42_chain_record(late_chain$test_runs), expected, info = name)
    testthat::expect_identical(expected$equity$equity[[nrow(expected$equity)]], case$final, info = name)
    action <- expected$events[grepl("corporate_action", expected$events$meta_json, fixed = TRUE), ]
    if (is.null(case$event)) {
      testthat::expect_identical(nrow(action), 0L, info = name)
      testthat::expect_true(case$reason %in% expected$diagnostics$reason_code, info = name)
    } else {
      testthat::expect_identical(action$event_type, case$event, info = name)
      testthat::expect_identical(
        as.numeric(action$ts_utc), as.numeric(as.POSIXct(case$ts, tz = "UTC")), info = name
      )
    }
    close(one)
    lapply(late_chain$test_runs, close)
    ledgr_snapshot_close(late$snapshot)
  }
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0304] every entry point reads feature, mark and entitlement history from the data start", {
  seen <- new.env()
  reader <- function(ctx) {
    list(
      fast = ctx$feature("AAA", "fast"),
      bbb_mark = ctx$vec$risk_mark[ctx$universe == "BBB"],
      bbb_age = ctx$vec$mark_age[ctx$universe == "BBB"],
      equity = ctx$equity
    )
  }
  opening <- ledgr_opening(
    cash = 1000, positions = c(BBB = 1), cost_basis = c(BBB = 21)
  )
  fixture <- ws42_history_fixture(strategy = ws42_spy(seen, reader), opening = opening)
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  axis <- fixture$axis
  days <- fixture$days
  dated <- ledgr_experiment(
    fixture$snapshot, ws42_spy(seen, reader), universe = ledgr_universe_members("u"),
    features = ledgr_feature_map(fast = ledgr_ind_sma(2)),
    valuation_policy = ledgr_valuation_stale(3), cost_model = ledgr_cost_zero(),
    opening = ledgr_opening(cash = 1000, date = days[[4L]], positions = c(BBB = 1), cost_basis = c(BBB = 21))
  )
  # Scoring starts at session 4. SMA(2) there reads sessions 3-4 (13.5); BBB's
  # last print before session 4 is session 2 (22), a stale mark of age 2.
  close(ledgr_run(dated, params = list(tag = "run"), run_id = "start-run"))
  sweep <- ledgr_sweep(dated, ledgr_param_grid(list(tag = "sweep")))
  promoted <- ledgr_promote(dated, ledgr_candidate(sweep, 1L), run_id = "start-promote")
  on.exit(close(promoted), add = TRUE)
  window <- ledgr:::ledgr_experiment_window(fixture$exp, days[[4L]], days[[8L]])
  close(ledgr:::ledgr_run_window(
    fixture$exp, params = list(tag = "run_window"), window = window, run_id = "start-window"
  ))
  ledgr:::ledgr_sweep_window(fixture$exp, ledgr_param_grid(list(tag = "sweep_window")), window)
  pre_grid <- ledgr_param_grid(list(tag = "precompute"))
  precomputed <- ledgr_precompute_features(dated, pre_grid)
  ledgr_sweep(dated, pre_grid, precomputed_features = precomputed)
  testthat::expect_identical(precomputed$history_axis$calculation_start_utc, ws42_iso(axis[[1L]]))
  testthat::expect_null(precomputed$warmup_range)
  expected <- list(fast = 13.5, bbb_mark = 22, bbb_age = 2L, equity = 1022)
  for (tag in c("run", "sweep", "run_window", "sweep_window", "precompute")) {
    testthat::expect_identical(seen[[paste(tag, ws42_iso(axis[[4L]]))]], expected, info = tag)
  }
  promoted_equity <- ws42_frame(ledgr_results(promoted, "equity"))
  testthat::expect_identical(promoted_equity$equity[[1L]], 1022)
  inspected <- ledgr_pulse_snapshot(dated, ts_utc = axis[[4L]])
  testthat::expect_identical(reader(inspected), expected)
  marks <- ws42_frame(ledgr_results(promoted, "availability"))
  marks <- marks[marks$instrument_id == "BBB", ]
  testthat::expect_identical(marks$mark_age[[1L]], 2L)
  testthat::expect_identical(marks$mark_source[[1L]], "stale_close")
  # Ledger reconstruction values the same data-start mark.
  rebuilt <- ledgr_state_reconstruct("start-run", ledgr:::get_connection(fixture$snapshot))
  testthat::expect_identical(rebuilt$equity_curve$equity[[1L]], 1022)

  # One substrate serves a whole walk-forward session: the constructor that
  # every preparation path (training sweeps and test runs alike) calls runs
  # once.
  builds <- new.env()
  builds$n <- 0L
  original <- ledgr:::ledgr_history_substrate
  testthat::local_mocked_bindings(
    ledgr_history_substrate = function(...) {
      builds$n <- builds$n + 1L
      original(...)
    },
    .package = "ledgr"
  )
  folds <- ledgr:::ledgr_fold_list(
    list(
      ledgr_fold(days[[1L]], days[[2L]], days[[3L]], days[[5L]], fold_seq = 1L),
      ledgr_fold(days[[1L]], days[[5L]], days[[6L]], days[[8L]], fold_seq = 2L)
    ),
    constructor = list(type_id = "explicit")
  )
  session <- ledgr_walk_forward(
    fixture$exp, ledgr_param_grid(list(tag = "wf")), folds,
    selection_rule = ledgr_rule_argmax("annualized_return"), seed = 1L
  )
  on.exit(lapply(session$test_runs, close), add = TRUE)
  testthat::expect_identical(builds$n, 1L)
  # The first test pulse (session 3) of the walk-forward reads SMA(2) from
  # sessions 2-3 of the shared history: 12.5.
  testthat::expect_identical(seen[[paste("wf", ws42_iso(axis[[3L]]))]]$fast, 12.5)
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0305] calendar-month folds derive every boundary from the anchor", {
  expected_test_starts <- c(
    "2020-01-31", "2020-02-29", "2020-03-31", "2020-04-30", "2020-05-31",
    "2020-06-30", "2020-07-31", "2020-08-31", "2020-09-30", "2020-10-31",
    "2020-11-30", "2020-12-31"
  )
  days <- seq(as.Date("2019-12-31"), as.Date("2021-01-31"), by = "day")
  sessions <- as.POSIXct(paste(days, "21:00:00"), tz = "UTC")
  check <- function(folds, scheme) {
    testthat::expect_identical(length(folds), 12L, info = scheme)
    train_start <- vapply(folds, function(f) as.numeric(f$train_start_utc), numeric(1))
    testthat::expect_identical(
      format(as.POSIXct(train_start, origin = "1970-01-01", tz = "UTC"), "%Y-%m-%d"),
      if (identical(scheme, "rolling")) c("2019-12-31", expected_test_starts[-12L]) else rep("2019-12-31", 12L),
      info = scheme
    )
    test_start <- vapply(folds, function(f) as.numeric(f$test_start_utc), numeric(1))
    test_end <- vapply(folds, function(f) as.numeric(f$test_end_utc), numeric(1))
    testthat::expect_identical(
      format(as.POSIXct(test_start, origin = "1970-01-01", tz = "UTC"), "%Y-%m-%d"),
      expected_test_starts,
      info = scheme
    )
    # Contiguous and gap-free: each test window ends one second before the
    # next starts, and every daily session from the first test start to the
    # last test end lies in exactly one test window.
    testthat::expect_identical(test_start[-1L], test_end[-length(test_end)] + 1, info = scheme)
    covered <- sessions[as.numeric(sessions) >= test_start[[1L]] & as.numeric(sessions) <= test_end[[12L]]]
    hits <- vapply(as.numeric(covered), function(s) sum(s >= test_start & s <= test_end), integer(1))
    testthat::expect_true(all(hits == 1L), info = scheme)
  }
  check(
    ledgr_folds_rolling("2019-12-31", "2021-01-31", train_window = "1 month", test_window = "1 month"),
    "rolling"
  )
  check(
    ledgr_folds_anchored("2019-12-31", "2021-01-31", train_window_initial = "1 month", test_window = "1 month"),
    "anchored"
  )
})
