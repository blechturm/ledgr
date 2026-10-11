# Cut 12: point-in-time consistency (audit inst/design/audits/
# v0_2_2_pit_universe_audit). Each block pins one audit finding's fix.

pit_consistency_days <- function() as.Date("2021-01-04") + c(0:4, 7:11, 14:18)

pit_consistency_stored <- function(con, run_id) {
  list(
    equity = DBI::dbGetQuery(
      con,
      "SELECT ts_utc, cash, positions_value, equity FROM equity_curve WHERE run_id = ? ORDER BY ts_utc",
      params = list(run_id)
    ),
    completion = DBI::dbGetQuery(
      con,
      paste(
        "SELECT intended_terminal_status, achieved_start_utc, achieved_end_utc,",
        "last_fully_valued_ts_utc, last_executed_ts_utc, stop_reason FROM run_completion WHERE run_id = ?"
      ),
      params = list(run_id)
    ),
    ledger = DBI::dbGetQuery(
      con,
      paste(
        "SELECT event_seq, ts_utc, event_type, instrument_id, side, qty, price, fee, meta_json",
        "FROM ledger_events WHERE run_id = ? ORDER BY event_seq"
      ),
      params = list(run_id)
    ),
    diagnostics = DBI::dbGetQuery(
      con,
      paste(
        "SELECT diagnostic_seq, ts_utc, instrument_id, stage, outcome, reason_code, reasons,",
        "quantity, price, position_before, position_after, detail_json",
        "FROM run_diagnostics WHERE run_id = ? ORDER BY diagnostic_seq"
      ),
      params = list(run_id)
    )
  )
}

testthat::test_that("[LTB-0218] a run that values no pulse keeps its prefix, opens and reruns", {
  snapshot <- scale_test_events_snapshot()
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  con <- ledgr:::get_connection(snapshot)
  days <- pit_consistency_days()

  # An opening dated on the session where its holding has no bar stops on the
  # run's first pulse: no NA equity rows, and the run opens and reruns.
  first <- ledgr_experiment(
    snapshot, function(ctx, params) ctx$hold(), universe = ledgr_universe_members("u"),
    valuation_policy = ledgr_valuation_stale(2), cost_model = ledgr_cost_zero(),
    opening = ledgr_opening(cash = 1000, date = days[[6]], positions = c(BBB = 1), cost_basis = c(BBB = 20))
  )
  close(ledgr_run(first, run_id = "first_pulse_stop"))
  stored <- pit_consistency_stored(con, "first_pulse_stop")
  testthat::expect_identical(nrow(stored$equity), 0L)
  testthat::expect_identical(stored$completion$intended_terminal_status, "INCOMPLETE")
  testthat::expect_true(is.na(stored$completion$achieved_end_utc))
  reopened <- ledgr_run_open(snapshot, "first_pulse_stop")
  testthat::expect_true(any(grepl("no valued pulse", utils::capture.output(print(reopened)), fixed = TRUE)))
  close(reopened)
  close(ledgr_run(first, run_id = "first_pulse_stop"))

  # A run interrupted before the pulse that stops it, then resumed, stores what
  # the uninterrupted run stores.
  buy_day <- as.character(days[[4]])
  buy_then_stop <- function(ctx, params) {
    target <- ctx$hold()
    if (identical(substr(ctx$ts_utc, 1, 10), buy_day)) target[["BBB"]] <- 1
    if (identical(substr(ctx$ts_utc, 1, 10), getOption("ledgr.test.interrupt_on", ""))) {
      options(ledgr.interrupt = TRUE)
    }
    target
  }
  stopped <- ledgr_experiment(
    snapshot, buy_then_stop, universe = ledgr_universe_members("u"),
    valuation_policy = ledgr_valuation_stale(0, exhausted = "refuse"), cost_model = ledgr_cost_zero(),
    opening = ledgr_opening(cash = 1000)
  )
  old <- options(ledgr.interrupt = FALSE, ledgr.test.interrupt_on = "")
  on.exit(options(old), add = TRUE)
  close(ledgr_run(stopped, run_id = "fresh_stop"))
  fresh <- pit_consistency_stored(con, "fresh_stop")
  testthat::expect_identical(fresh$completion$intended_terminal_status, "INCOMPLETE")
  testthat::expect_gt(nrow(fresh$equity), 0L)

  options(ledgr.test.interrupt_on = as.character(days[[5]]))
  close(ledgr_run(stopped, run_id = "resumed_stop"))
  testthat::expect_identical(ledgr_run_info(snapshot, "resumed_stop")$status, "RUNNING")
  options(ledgr.interrupt = FALSE, ledgr.test.interrupt_on = "")
  close(ledgr_run(stopped, run_id = "resumed_stop"))
  resumed <- pit_consistency_stored(con, "resumed_stop")
  testthat::expect_identical(resumed$equity, fresh$equity)
  testthat::expect_identical(resumed$completion, fresh$completion)
  testthat::expect_identical(resumed$ledger, fresh$ledger)
  testthat::expect_identical(resumed$diagnostics, fresh$diagnostics)
  close(ledgr_run_open(snapshot, "resumed_stop"))

  # A run interrupted after its last pulse values nothing on resume and still
  # finishes as the uninterrupted run does.
  hold_or_interrupt <- function(ctx, params) {
    if (identical(substr(ctx$ts_utc, 1, 10), getOption("ledgr.test.interrupt_on", ""))) {
      options(ledgr.interrupt = TRUE)
    }
    ctx$hold()
  }
  held <- ledgr_experiment(
    snapshot, hold_or_interrupt, universe = ledgr_universe_members("u"),
    valuation_policy = ledgr_valuation_stale(2), cost_model = ledgr_cost_zero(),
    opening = ledgr_opening(cash = 1000)
  )
  close(ledgr_run(held, run_id = "fresh_done"))
  options(ledgr.test.interrupt_on = as.character(days[[length(days)]]))
  close(ledgr_run(held, run_id = "resumed_done"))
  testthat::expect_identical(ledgr_run_info(snapshot, "resumed_done")$status, "RUNNING")
  options(ledgr.interrupt = FALSE, ledgr.test.interrupt_on = "")
  close(ledgr_run(held, run_id = "resumed_done"))
  done <- pit_consistency_stored(con, "fresh_done")
  testthat::expect_identical(done$completion$intended_terminal_status, "DONE")
  testthat::expect_identical(pit_consistency_stored(con, "resumed_done"), done)
  close(ledgr_run_open(snapshot, "resumed_done"))
})

testthat::test_that("[LTB-0219] an INCOMPLETE run with a fill after its achieved end reconstructs", {
  snapshot <- scale_test_events_snapshot()
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  con <- ledgr:::get_connection(snapshot)
  days <- pit_consistency_days()
  # BBB bought for the day-5 open stops the run at day 6 (no bar, no stale
  # allowance); AAA decided on day 5 fills at day 6's open, after the achieved end.
  bbb_day <- as.character(days[[4]])
  aaa_day <- as.character(days[[5]])
  strategy <- function(ctx, params) {
    target <- ctx$hold()
    day <- substr(ctx$ts_utc, 1, 10)
    if (identical(day, bbb_day)) target[["BBB"]] <- 1
    if (identical(day, aaa_day)) target[["AAA"]] <- 1
    target
  }
  exp <- ledgr_experiment(
    snapshot, strategy, universe = ledgr_universe_members("u"),
    valuation_policy = ledgr_valuation_stale(0, exhausted = "refuse"), cost_model = ledgr_cost_zero(),
    opening = ledgr_opening(cash = 1000)
  )
  close(ledgr_run(exp, run_id = "post_prefix_fill"))
  stored <- pit_consistency_stored(con, "post_prefix_fill")
  testthat::expect_identical(stored$completion$intended_terminal_status, "INCOMPLETE")
  testthat::expect_true(stored$completion$last_executed_ts_utc > stored$completion$achieved_end_utc)
  fills <- DBI::dbGetQuery(con, "SELECT instrument_id FROM ledger_events WHERE run_id = 'post_prefix_fill' AND event_type = 'FILL' ORDER BY event_seq")
  testthat::expect_identical(fills$instrument_id, c("BBB", "AAA"))

  rebuilt <- ledgr_state_reconstruct("post_prefix_fill", con)
  after <- pit_consistency_stored(con, "post_prefix_fill")
  testthat::expect_equal(after$equity, stored$equity, tolerance = 0)
  qty <- stats::setNames(rebuilt$positions$qty, rebuilt$positions$instrument_id)
  testthat::expect_identical(unname(qty[["BBB"]]), 1)
  testthat::expect_identical(unname(qty[["AAA"]]), 0)
})

testthat::test_that("[LTB-0221] ingest refuses non-positive prices and keeps zero volume", {
  days <- pit_consistency_days()
  at <- function(d) as.POSIXct(paste(d, "21:00:00"), tz = "UTC")
  set_aaa <- function(field, value, day = days[[3]]) function(bars) {
    k <- bars$instrument_id == "AAA" & bars$ts_utc == at(day)
    bars[k, field] <- value
    bars
  }
  # A fact-bearing snapshot refuses a zero, a negative, or a price that rounds
  # to zero at the stored 8 digits, naming the reason.
  for (edit in list(set_aaa(c("low", "close"), 0), set_aaa(c("open", "low"), -1), set_aaa("low", 4e-9))) {
    err <- testthat::expect_error(scale_test_events_snapshot(edit_bars = edit), class = "ledgr_availability_validation_failed")
    testthat::expect_match(conditionMessage(err), "ohlc_non_positive", fixed = TRUE)
  }
  # Under quarantine the row is excluded and recorded with its reason.
  quarantined <- scale_test_events_snapshot(edit_bars = set_aaa(c("low", "close"), 0), invalid_observations = "quarantine")
  on.exit(ledgr_snapshot_close(quarantined), add = TRUE)
  testthat::expect_identical(ledgr_snapshot_quarantine(quarantined)$reason, "ohlc_non_positive")
  testthat::expect_identical(
    DBI::dbGetQuery(ledgr:::get_connection(quarantined), "SELECT COUNT(*) AS n FROM snapshot_bars WHERE close <= 0 OR low <= 0")$n,
    0
  )
  # Zero volume with positive prices seals and fills.
  zero_volume <- scale_test_events_snapshot(edit_bars = function(bars) {
    bars$volume[bars$instrument_id == "AAA"] <- 0
    bars
  })
  on.exit(ledgr_snapshot_close(zero_volume), add = TRUE)
  buy_day <- as.character(days[[2]])
  buy <- function(ctx, params) {
    target <- ctx$hold()
    if (identical(substr(ctx$ts_utc, 1, 10), buy_day)) target[["AAA"]] <- 1
    target
  }
  exp <- ledgr_experiment(
    zero_volume, buy, universe = ledgr_universe_members("u"),
    valuation_policy = ledgr_valuation_stale(2), cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1000)
  )
  close(ledgr_run(exp, run_id = "zero_volume_fill"))
  fills <- DBI::dbGetQuery(ledgr:::get_connection(zero_volume), "SELECT instrument_id FROM ledger_events WHERE run_id = 'zero_volume_fill' AND event_type = 'FILL'")
  testthat::expect_identical(fills$instrument_id, "AAA")

  # A dense snapshot refuses the same prices at its seal check (LTB-0222 covers
  # other writers).
  dense <- data.frame(
    instrument_id = "AAA", ts_utc = at(days[1:3]), open = c(10, 11, 12), high = c(10, 11, 12),
    low = c(10, 11, 12), close = c(10, 11, 12), volume = c(100, 0, 100)
  )
  for (edit in list(set_aaa(c("low", "close"), 0), set_aaa(c("open", "low"), -1), set_aaa("low", 4e-9))) {
    testthat::expect_error(
      ledgr_snapshot_from_df(edit(dense), db_path = tempfile(fileext = ".duckdb")),
      class = "ledgr_ohlc_non_positive"
    )
  }
  dense_ok <- ledgr_snapshot_from_df(dense, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(dense_ok), add = TRUE)
  testthat::expect_identical(ledgr_snapshot_info(dense_ok)$status, "SEALED")
})

testthat::test_that("[LTB-0223] session instants must fall on their date and stay distinct", {
  days <- as.Date(c("2021-03-01", "2021-03-02", "2021-03-03", "2021-03-04", "2021-03-05"))
  at <- function(d, hms) as.POSIXct(paste(d, hms), tz = "America/New_York")
  calendar <- function(open, close) {
    data.frame(session_date = days, status = "open", session_open = open, session_close = close)
  }
  build <- function(sessions) {
    ledgr_facts_sessions(sessions, venue_id = "XNYS", timezone = "America/New_York", knowledge = "assume_effective")
  }
  open <- do.call(c, lapply(days, at, hms = "09:30:00"))
  close <- do.call(c, lapply(days, at, hms = "16:00:00"))
  testthat::expect_s3_class(build(calendar(open, close)), "ledgr_facts_sessions")

  # One session's instants on the next date, distinct from every other session.
  shifted_open <- open
  shifted_close <- close
  shifted_open[[2]] <- at(days[[3]], "07:00:00")
  shifted_close[[2]] <- at(days[[3]], "08:00:00")
  testthat::expect_error(build(calendar(shifted_open, shifted_close)), class = "ledgr_session_instant_off_date")
  # A vendor off-by-one: the 2021-03-02 row repeats the 2021-03-03 instants.
  dup_open <- open
  dup_close <- close
  dup_open[[2]] <- open[[3]]
  dup_close[[2]] <- close[[3]]
  testthat::expect_error(build(calendar(dup_open, dup_close)), class = "ledgr_session_instant_duplicate")
  # A close past local midnight is off its date even when the open is not.
  late_close <- close
  late_close[[4]] <- at(days[[5]], "00:30:00")
  testthat::expect_error(build(calendar(open, late_close)), class = "ledgr_session_instant_off_date")
})

testthat::test_that("[LTB-0224] a calendar that does not cover the requested range refuses", {
  days <- pit_consistency_days()
  at <- function(d) as.POSIXct(paste(d, "21:00:00"), tz = "UTC")
  hold <- function(ctx, params) ctx$hold()
  experiment <- function(snapshot) {
    ledgr_experiment(
      snapshot, hold, universe = ledgr_universe_members("u"),
      valuation_policy = ledgr_valuation_stale(2), cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1000)
    )
  }
  fold <- function(train_start, test_end) {
    ledgr:::ledgr_fold_list(
      list(ledgr_fold(at(train_start), at(days[[7]]), at(days[[8]]), at(test_end), fold_seq = 1L)),
      constructor = list(type_id = "explicit")
    )
  }
  # The calendar ends before the last bar (K1), or starts after the first (K2).
  for (case in list(list(to = days[[10]], wf = c(days[[2]], days[[13]]), inside = days[c(1, 10)]),
                    list(from = days[[4]], wf = c(days[[2]], days[[10]]), inside = days[c(4, 15)]))) {
    snapshot <- scale_test_events_snapshot(sessions_from = case$from, sessions_to = case$to)
    exp <- experiment(snapshot)
    testthat::expect_error(ledgr_run(exp, run_id = "short_calendar"), class = "ledgr_sessions_incomplete")
    testthat::expect_error(ledgr_sweep(exp, ledgr_param_grid(a = list())), class = "ledgr_sessions_incomplete")
    testthat::expect_error(
      ledgr_walk_forward(exp, grid = ledgr_param_grid(a = list()), folds = fold(case$wf[[1]], case$wf[[2]]),
                         selection_rule = ledgr_rule_argmax("sharpe_ratio")),
      class = "ledgr_sessions_incomplete"
    )
    # A window the calendar covers runs.
    window <- ledgr_experiment_window(exp, at(case$inside[[1]]), at(case$inside[[2]]))
    inside <- ledgr_run_window(exp, window = window, run_id = "covered_window")
    testthat::expect_identical(ledgr_run_info(snapshot, "covered_window")$status, "DONE")
    close(inside)
    ledgr_snapshot_close(snapshot)
  }

  # A New York calendar whose civil days start at 05:00Z: an opening dated on
  # the first session, or before the sealed bars, runs from the sealed start
  # (the scoring-start rule), and the run and the sweep agree.
  ny_days <- as.Date("2021-03-01") + 0:4
  ny_close <- as.POSIXct(paste(ny_days, "16:00:00"), tz = "America/New_York")
  attr(ny_close, "tzone") <- "UTC"
  ny <- ledgr_snapshot_from_df(
    data.frame(instrument_id = "AAA", ts_utc = ny_close, open = 10, high = 10, low = 10, close = 10, volume = 1),
    db_path = tempfile(fileext = ".duckdb"), price_basis = "split_adjusted",
    facts = ledgr_facts(ledgr_facts_sessions(
      data.frame(session_date = ny_days, status = "open", session_open = "09:30:00", session_close = "16:00:00"),
      venue_id = "XNYS", timezone = "America/New_York", knowledge = "assume_effective"
    ))
  )
  on.exit(ledgr_snapshot_close(ny), add = TRUE)
  for (opening_date in list(ny_days[[1]], ny_days[[1]] - 10)) {
    exp <- ledgr_experiment(ny, hold, universe = "AAA", valuation_policy = ledgr_valuation_stale(1),
                            cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1000, date = opening_date))
    run_id <- paste0("ny_opening_", as.character(opening_date))
    close(ledgr_run(exp, run_id = run_id))
    testthat::expect_identical(ledgr_run_info(ny, run_id)$status, "DONE")
    testthat::expect_identical(ledgr_sweep(exp, ledgr_param_grid(a = list()))$status[[1]], "DONE")
  }
})

testthat::test_that("[LTB-0225] availability-aware experiments require and disclose a price basis", {
  days <- pit_consistency_days()
  at <- function(d) as.POSIXct(paste(d, "21:00:00"), tz = "UTC")
  hold <- function(ctx, params) ctx$hold()
  experiment <- function(snapshot, ...) {
    ledgr_experiment(snapshot, hold, cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1000), ...)
  }
  undeclared <- scale_test_events_snapshot(price_basis = NULL)
  on.exit(ledgr_snapshot_close(undeclared), add = TRUE)
  testthat::expect_error(
    experiment(undeclared, universe = ledgr_universe_members("u"), valuation_policy = ledgr_valuation_stale(2)),
    class = "ledgr_price_basis_required"
  )

  declared <- scale_test_events_snapshot()
  on.exit(ledgr_snapshot_close(declared), add = TRUE)
  exp <- experiment(declared, universe = ledgr_universe_members("u"), valuation_policy = ledgr_valuation_stale(2))
  plan <- ledgr_experiment_plan(exp)
  testthat::expect_identical(plan$price_basis, "split_adjusted")
  testthat::expect_true(any(grepl("Price basis:  split_adjusted", utils::capture.output(print(plan)), fixed = TRUE)))
  bt <- ledgr_run(exp, run_id = "declared_basis")
  on.exit(close(bt), add = TRUE)
  testthat::expect_identical(ledgr_corporate_action_summary(bt)$price_basis, "split_adjusted")
  testthat::expect_true(any(grepl("Price basis: split_adjusted", utils::capture.output(print(bt)), fixed = TRUE)))

  # A dense snapshot without a declared basis runs as before.
  dense <- ledgr_snapshot_from_df(
    data.frame(instrument_id = "AAA", ts_utc = at(days[1:3]), open = 10, high = 10, low = 10, close = 10, volume = 1),
    db_path = tempfile(fileext = ".duckdb")
  )
  on.exit(ledgr_snapshot_close(dense), add = TRUE)
  dense_exp <- experiment(dense, universe = "AAA")
  testthat::expect_identical(ledgr_experiment_plan(dense_exp)$price_basis, "undeclared")
  close(ledgr_run(dense_exp, run_id = "dense_undeclared"))
  testthat::expect_identical(ledgr_run_info(dense, "dense_undeclared")$status, "DONE")
})

testthat::test_that("[LTB-0226] an off-session bar is sealed, recorded and reported, never a pulse", {
  days <- pit_consistency_days()
  saturday <- as.POSIXct(paste(days[[5]] + 1, "21:00:00"), tz = "UTC")
  add_off_session <- function(bars) {
    extra <- bars[bars$instrument_id == "AAA", , drop = FALSE][1L, ]
    extra$ts_utc <- saturday
    extra[c("open", "high", "low", "close")] <- 999
    rbind(bars, extra)
  }
  snapshot <- scale_test_events_snapshot(edit_bars = add_off_session)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  info <- ledgr_snapshot_info(snapshot)
  testthat::expect_identical(info$off_session_bar_count, 1L)
  evidence <- ledgr_snapshot_quarantine(snapshot)
  testthat::expect_identical(evidence$reason, "off_session_bar")
  testthat::expect_identical(evidence$disposition, "sealed_not_a_pulse")
  testthat::expect_identical(evidence$supplied_instrument_id, "AAA")
  testthat::expect_equal(evidence$supplied_ts_utc, saturday, ignore_attr = TRUE)
  # The bar stays sealed and the record stays outside the hash: the snapshot
  # reopens with verification.
  con <- ledgr:::get_connection(snapshot)
  testthat::expect_identical(
    DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM snapshot_bars WHERE close = 999")$n,
    1
  )
  db_path <- snapshot$db_path
  snapshot_id <- snapshot$snapshot_id
  ledgr_snapshot_close(snapshot)
  snapshot <- ledgr_snapshot_open(db_path, snapshot_id, verify = TRUE)

  seen <- new.env()
  seen$ts <- character()
  spy <- function(ctx, params) {
    seen$ts <- c(seen$ts, ctx$ts_utc)
    ctx$hold()
  }
  exp <- ledgr_experiment(
    snapshot, spy, universe = ledgr_universe_members("u"),
    valuation_policy = ledgr_valuation_stale(2), cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1000)
  )
  bt <- ledgr_run(exp, run_id = "off_session_run")
  testthat::expect_false(any(substr(seen$ts, 1, 10) == as.character(days[[5]] + 1)))
  testthat::expect_false(any(as.Date(ledgr_results(bt, "equity")$ts_utc) == days[[5]] + 1))
  testthat::expect_true(any(grepl("Off-session bars: 1 sealed bar in the snapshot", utils::capture.output(summary(bt)), fixed = TRUE)))
  # The record is derived evidence: it is not counted as quarantined, and
  # removing it leaves the snapshot hash verifying.
  meta <- ledgr:::ledgr_json_read_nested(ledgr_snapshot_info(snapshot)$meta_json)
  testthat::expect_identical(as.integer(meta$quarantined_observation_count), 0L)
  close(bt)
  DBI::dbExecute(ledgr:::get_connection(snapshot), "DELETE FROM snapshot_observation_quarantine WHERE reason = 'off_session_bar'")
  ledgr_snapshot_close(snapshot)
  snapshot <- ledgr_snapshot_open(db_path, snapshot_id, verify = TRUE)
  testthat::expect_identical(ledgr_snapshot_info(snapshot)$off_session_bar_count, 0L)

  # Under quarantine the record sits beside a quarantined row; the
  # acknowledgement counts only the quarantined one.
  both <- scale_test_events_snapshot(
    edit_bars = function(bars) {
      bars <- add_off_session(bars)
      k <- bars$instrument_id == "BBB" & bars$ts_utc == as.POSIXct(paste(days[[2]], "21:00:00"), tz = "UTC")
      bars$high[k] <- bars$low[k] - 1
      bars
    },
    invalid_observations = "quarantine"
  )
  on.exit(ledgr_snapshot_close(both), add = TRUE)
  testthat::expect_setequal(ledgr_snapshot_quarantine(both)$reason, c("off_session_bar", "ohlc_invalid"))
  testthat::expect_identical(ledgr_snapshot_info(both)$off_session_bar_count, 1L)

  clean <- scale_test_events_snapshot()
  on.exit(ledgr_snapshot_close(clean), add = TRUE)
  testthat::expect_identical(ledgr_snapshot_info(clean)$off_session_bar_count, 0L)
})

pit_consistency_ca <- function(subtype, parent, entitlement, effective) {
  ledgr_facts_equity_corporate_actions(data.frame(
    fact_id = paste0(parent, "-", subtype), subtype = subtype, parent_instrument_id = parent,
    entitlement_time = entitlement, effective_time = effective, knowledge_time = entitlement - 86400 * 3,
    payment_time = effective, complete = TRUE, provenance_tier = "snapshot_bound",
    gross_cash_per_parent_unit = 1, gross_cash_validated = TRUE,
    recipient_instrument_id = NA_character_, recipient_identity_validated = FALSE,
    recipient_quantity_per_parent_unit = NA_real_, recipient_quantity_validated = FALSE,
    source = "t", stringsAsFactors = FALSE
  ))
}

testthat::test_that("[LTB-0227] a held corporate action ledgr does not model is reported or refused", {
  days <- pit_consistency_days()
  at <- function(d) as.POSIXct(paste(d, "21:00:00"), tz = "UTC")
  buy_day <- as.character(days[[1]])
  buy_aaa <- function(ctx, params) {
    target <- ctx$hold()
    if (identical(substr(ctx$ts_utc, 1, 10), buy_day)) target[["AAA"]] <- 1
    target
  }
  run_summary <- function(snapshot, run_id, policy, ...) {
    exp <- ledgr_experiment(snapshot, buy_aaa, cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1000),
                            corporate_action_policy = policy, ...)
    bt <- ledgr_run(exp, run_id = run_id)
    on.exit(close(bt))
    ledgr_corporate_action_summary(bt)
  }
  pit <- list(universe = ledgr_universe_members("u"), valuation_policy = ledgr_valuation_stale(2))

  # An unknown subtype on the held AAA: research reports it, strict refuses.
  unknown <- scale_test_events_snapshot(corporate_actions = pit_consistency_ca("cash_dividend", "AAA", at(days[[5]]), at(days[[6]])))
  on.exit(ledgr_snapshot_close(unknown), add = TRUE)
  research <- do.call(run_summary, c(list(unknown, "unknown_research", ledgr_corporate_actions_research()), pit))
  testthat::expect_identical(research$corporate_action_fidelity, "unsupported")
  testthat::expect_identical(research$unsupported_facts, 1L)
  testthat::expect_identical(research$gross_cash_posted, 0)
  # Strict refuses it as an unsupported quantity effect, a typed stop (LDG-2997).
  do.call(run_summary, c(list(unknown, "unknown_strict", ledgr_corporate_actions_strict()), pit))
  testthat::expect_identical(
    DBI::dbGetQuery(ledgr:::get_connection(unknown), "SELECT stop_reason FROM run_completion WHERE run_id = 'unknown_strict'")$stop_reason,
    "corporate_action_quantity_refused"
  )
  # Not held: nothing is reported.
  unheld <- scale_test_events_snapshot(corporate_actions = pit_consistency_ca("cash_dividend", "BBB", at(days[[5]]), at(days[[7]])))
  on.exit(ledgr_snapshot_close(unheld), add = TRUE)
  quiet <- do.call(run_summary, c(list(unheld, "unknown_unheld", ledgr_corporate_actions_research()), pit))
  testthat::expect_identical(quiet$corporate_action_fidelity, "none")
  testthat::expect_identical(quiet$unsupported_facts, 0L)

  # A held cash acquisition in a dense run: no disposition acts there.
  dense_bars <- data.frame(instrument_id = rep(c("AAA", "CCC"), each = 5), ts_utc = rep(at(days[1:5]), 2),
                           open = 10, high = 10, low = 10, close = 10, volume = 1)
  dense <- ledgr_snapshot_from_df(
    dense_bars, db_path = tempfile(fileext = ".duckdb"), price_basis = "split_adjusted",
    facts = ledgr_facts(pit_consistency_ca("cash_acquisition", "AAA", at(days[[3]]), at(days[[4]])))
  )
  on.exit(ledgr_snapshot_close(dense), add = TRUE)
  dense_research <- run_summary(dense, "dense_research", ledgr_corporate_actions_research(), universe = c("AAA", "CCC"))
  testthat::expect_identical(dense_research$corporate_action_fidelity, "unsupported")
  testthat::expect_identical(dense_research$unsupported_facts, 1L)
  # A dense run has no typed stop, so strict still aborts; a dense sweep
  # candidate fails the same way.
  testthat::expect_error(
    run_summary(dense, "dense_strict", ledgr_corporate_actions_strict(), universe = c("AAA", "CCC")),
    class = "ledgr_corporate_action_quantity_unsupported"
  )
  dense_sweep <- ledgr_sweep(
    ledgr_experiment(dense, buy_aaa, universe = c("AAA", "CCC"), cost_model = ledgr_cost_zero(),
                     opening = ledgr_opening(cash = 1000), corporate_action_policy = ledgr_corporate_actions_strict()),
    ledgr_param_grid(a = list())
  )
  testthat::expect_identical(dense_sweep$error_class[[1L]], "ledgr_corporate_action_quantity_unsupported")
})

testthat::test_that("[LTB-0228] a declared corporate-action refusal stops the run typed", {
  days <- pit_consistency_days()
  at <- function(d) as.POSIXct(paste(d, "21:00:00"), tz = "UTC")
  dividend <- pit_consistency_ca("ordinary_cash_dividend", "AAA", at(days[[5]]), at(days[[5]]))
  snapshot <- scale_test_events_snapshot(corporate_actions = dividend)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  con <- ledgr:::get_connection(snapshot)
  buy_day <- as.character(days[[1]])
  buy_aaa <- function(ctx, params) {
    target <- ctx$hold()
    if (identical(substr(ctx$ts_utc, 1, 10), buy_day)) target[["AAA"]] <- 1
    target
  }
  exp <- ledgr_experiment(
    snapshot, buy_aaa, universe = ledgr_universe_members("u"), valuation_policy = ledgr_valuation_stale(2),
    cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1000),
    corporate_action_policy = ledgr_corporate_actions_strict()
  )
  bt <- ledgr_run(exp, run_id = "strict_cash")
  close(bt)
  stored <- pit_consistency_stored(con, "strict_cash")
  # The held dividend is refused at its entitlement pulse (the fifth): the
  # prefix through the fourth stays, with the fill and no cash posting.
  testthat::expect_identical(ledgr_run_info(snapshot, "strict_cash")$status, "INCOMPLETE")
  testthat::expect_identical(stored$completion$intended_terminal_status, "INCOMPLETE")
  testthat::expect_identical(stored$completion$stop_reason, "corporate_action_cash_refused")
  testthat::expect_identical(nrow(stored$equity), 4L)
  testthat::expect_equal(as.POSIXct(stored$completion$achieved_end_utc, tz = "UTC"), at(days[[4]]), ignore_attr = TRUE)
  testthat::expect_identical(stored$ledger$event_type, "FILL")
  stop_row <- stored$diagnostics[stored$diagnostics$outcome == "stopped", , drop = FALSE]
  testthat::expect_identical(stop_row$reason_code, "corporate_action_cash_refused")
  testthat::expect_identical(stop_row$instrument_id, "AAA")
  reopened <- ledgr_run_open(snapshot, "strict_cash")
  testthat::expect_identical(ledgr_run_completion(reopened)$stop_reason, "corporate_action_cash_refused")
  testthat::expect_identical(ledgr_corporate_action_summary(reopened)$corporate_action_fidelity, "unsupported")
  close(reopened)
  # Rerunning returns the same stored run.
  close(ledgr_run(exp, run_id = "strict_cash"))
  testthat::expect_identical(pit_consistency_stored(con, "strict_cash"), stored)
})
