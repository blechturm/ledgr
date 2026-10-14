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
    snapshot, function(ctx, params) ctx$hold(),
    universe = ledgr_universe_members("u"),
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
  # LTB-0245 (review) covers the interrupted-and-resumed permutations.
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0245] interrupted availability runs resume to what the uninterrupted run stores", {
  snapshot <- scale_test_events_snapshot()
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  con <- ledgr:::get_connection(snapshot)
  days <- pit_consistency_days()


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
    snapshot, buy_then_stop,
    universe = ledgr_universe_members("u"),
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
    snapshot, hold_or_interrupt,
    universe = ledgr_universe_members("u"),
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
    snapshot, strategy,
    universe = ledgr_universe_members("u"),
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
  set_aaa <- function(field, value, day = days[[3]]) {
    function(bars) {
      k <- bars$instrument_id == "AAA" & bars$ts_utc == at(day)
      bars[k, field] <- value
      bars
    }
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
    zero_volume, buy,
    universe = ledgr_universe_members("u"),
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
      snapshot, hold,
      universe = ledgr_universe_members("u"),
      valuation_policy = ledgr_valuation_stale(2), cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1000)
    )
  }
  # The calendar ends before the last bar (K1): every entry point refuses and
  # a window the calendar covers runs.
  short_end <- scale_test_events_snapshot(sessions_to = days[[10]])
  on.exit(ledgr_snapshot_close(short_end), add = TRUE)
  exp <- experiment(short_end)
  testthat::expect_error(ledgr_run(exp, run_id = "short_calendar"), class = "ledgr_sessions_incomplete")
  testthat::expect_error(ledgr_sweep(exp, ledgr_param_grid(a = list())), class = "ledgr_sessions_incomplete")
  folds <- ledgr:::ledgr_fold_list(
    list(ledgr_fold(at(days[[2]]), at(days[[7]]), at(days[[8]]), at(days[[13]]), fold_seq = 1L)),
    constructor = list(type_id = "explicit")
  )
  testthat::expect_error(
    ledgr_walk_forward(exp, grid = ledgr_param_grid(a = list()), folds = folds, selection_rule = ledgr_rule_argmax("sharpe_ratio")),
    class = "ledgr_sessions_incomplete"
  )
  window <- ledgr_experiment_window(exp, at(days[[1]]), at(days[[10]]))
  close(ledgr_run_window(exp, window = window, run_id = "covered_window"))
  testthat::expect_identical(ledgr_run_info(short_end, "covered_window")$status, "DONE")

  # The calendar starts after the first bar (K2): the run refuses.
  late_start <- scale_test_events_snapshot(sessions_from = days[[4]])
  on.exit(ledgr_snapshot_close(late_start), add = TRUE)
  testthat::expect_error(ledgr_run(experiment(late_start), run_id = "short_calendar"), class = "ledgr_sessions_incomplete")

  # New York bars that start a day before the calendar: the full request and a
  # bare window over the uncovered day refuse. LTB-0240 holds the variants.
  ny_days <- as.Date("2021-03-01") + 0:4
  ny_close <- as.POSIXct(paste(ny_days, "16:00:00"), tz = "America/New_York")
  attr(ny_close, "tzone") <- "UTC"
  late <- ledgr_snapshot_from_df(
    data.frame(instrument_id = "AAA", ts_utc = ny_close, open = 10, high = 10, low = 10, close = 10, volume = 1),
    db_path = tempfile(fileext = ".duckdb"), price_basis = "split_adjusted",
    facts = ledgr_facts(ledgr_facts_sessions(
      data.frame(session_date = ny_days[-1], status = "open", session_open = "09:30:00", session_close = "16:00:00"),
      venue_id = "XNYS", timezone = "America/New_York", knowledge = "assume_effective"
    ))
  )
  on.exit(ledgr_snapshot_close(late), add = TRUE)
  late_exp <- ledgr_experiment(late, hold,
    universe = "AAA", valuation_policy = ledgr_valuation_stale(1),
    cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1000)
  )
  testthat::expect_error(ledgr_run(late_exp, run_id = "late_calendar_full"), class = "ledgr_sessions_incomplete")
  testthat::expect_error(ledgr_experiment_window(late_exp, ny_close[[1]], ny_close[[3]]),
    class = "ledgr_sessions_incomplete"
  )
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0240] calendar coverage holds on every entry point and on New York calendars", {
  days <- pit_consistency_days()
  at <- function(d) as.POSIXct(paste(d, "21:00:00"), tz = "UTC")
  hold <- function(ctx, params) ctx$hold()
  experiment <- function(snapshot) {
    ledgr_experiment(
      snapshot, hold,
      universe = ledgr_universe_members("u"),
      valuation_policy = ledgr_valuation_stale(2), cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1000)
    )
  }
  # K2 on the remaining entry points, and a window the calendar covers.
  snapshot <- scale_test_events_snapshot(sessions_from = days[[4]])
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- experiment(snapshot)
  testthat::expect_error(ledgr_sweep(exp, ledgr_param_grid(a = list())), class = "ledgr_sessions_incomplete")
  folds <- ledgr:::ledgr_fold_list(
    list(ledgr_fold(at(days[[2]]), at(days[[7]]), at(days[[8]]), at(days[[10]]), fold_seq = 1L)),
    constructor = list(type_id = "explicit")
  )
  testthat::expect_error(
    ledgr_walk_forward(exp, grid = ledgr_param_grid(a = list()), folds = folds, selection_rule = ledgr_rule_argmax("sharpe_ratio")),
    class = "ledgr_sessions_incomplete"
  )
  window <- ledgr_experiment_window(exp, at(days[[4]]), at(days[[15]]))
  close(ledgr_run_window(exp, window = window, run_id = "covered_window"))
  testthat::expect_identical(ledgr_run_info(snapshot, "covered_window")$status, "DONE")

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
    exp <- ledgr_experiment(ny, hold,
      universe = "AAA", valuation_policy = ledgr_valuation_stale(1),
      cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1000, date = opening_date)
    )
    run_id <- paste0("ny_opening_", as.character(opening_date))
    close(ledgr_run(exp, run_id = run_id))
    testthat::expect_identical(ledgr_run_info(ny, run_id)$status, "DONE")
    testthat::expect_identical(ledgr_sweep(exp, ledgr_param_grid(a = list()))$status[[1]], "DONE")
  }

  # Bars that start a day before the calendar: a request from the calendar's
  # first civil day covers every bar it asks for, so it runs.
  late <- ledgr_snapshot_from_df(
    data.frame(instrument_id = "AAA", ts_utc = ny_close, open = 10, high = 10, low = 10, close = 10, volume = 1),
    db_path = tempfile(fileext = ".duckdb"), price_basis = "split_adjusted",
    facts = ledgr_facts(ledgr_facts_sessions(
      data.frame(session_date = ny_days[-1], status = "open", session_open = "09:30:00", session_close = "16:00:00"),
      venue_id = "XNYS", timezone = "America/New_York", knowledge = "assume_effective"
    ))
  )
  on.exit(ledgr_snapshot_close(late), add = TRUE)
  late_exp <- function(...) {
    ledgr_experiment(late, hold,
      universe = "AAA", valuation_policy = ledgr_valuation_stale(1),
      cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1000, ...)
    )
  }
  close(ledgr_run(late_exp(date = ny_days[[2]]), run_id = "late_calendar_opening"))
  testthat::expect_identical(ledgr_run_info(late, "late_calendar_opening")$status, "DONE")
  testthat::expect_identical(ledgr_sweep(late_exp(date = ny_days[[2]]), ledgr_param_grid(a = list()))$status[[1]], "DONE")
  window <- ledgr_experiment_window(late_exp(), as.POSIXct(paste(ny_days[[2]], "00:00:00"), tz = "UTC"), ny_close[[5]])
  close(ledgr_run_window(late_exp(), window = window, run_id = "late_calendar_window"))
  testthat::expect_identical(ledgr_run_info(late, "late_calendar_window")$status, "DONE")
})

testthat::test_that("[LTB-0225] availability-aware experiments disclose their price basis", {
  days <- pit_consistency_days()
  at <- function(d) as.POSIXct(paste(d, "21:00:00"), tz = "UTC")
  hold <- function(ctx, params) ctx$hold()
  experiment <- function(snapshot, ...) {
    ledgr_experiment(snapshot, hold, cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1000), ...)
  }
  # An undeclared basis runs as an assumed default since LDG-3013 (LTB-0232).
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
  testthat::expect_true(grepl("\"close\":999", evidence$original_row_json, fixed = TRUE))
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
    snapshot, spy,
    universe = ledgr_universe_members("u"),
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

  # LTB-0247 (review) covers quarantine beside the record and latin1/Inf rows end to end.
  cafe <- "caf\u00e9"
  # The record serializer never visits a row on its own, even when every row
  # holds an exceptional value: the whole frame is one NDJSON write, the bytes
  # match the per-row form, and that form is never called.
  exceptional <- data.frame(
    instrument_id = "AAA", ts_utc = saturday + 86400 * 0:2, open = 1, high = 1, low = 1,
    close = 1, volume = 1, score = c(Inf, -Inf, Inf), note = iconv(cafe, "UTF-8", "latin1")
  )
  testthat::expect_identical(Encoding(exceptional$note), rep("latin1", 3L))
  expected <- vapply(1:3, function(i) ledgr:::ledgr_availability_original_row_json(exceptional[i, , drop = FALSE]), character(1))
  writes <- 0L
  write_ndjson <- ledgr:::ledgr_json_write_canonical_ndjson
  testthat::local_mocked_bindings(
    ledgr_availability_original_row_json = function(...) stop("per-row serializer used"),
    ledgr_json_write_canonical_ndjson = function(frame) {
      writes <<- writes + 1L
      write_ndjson(frame)
    },
    .package = "ledgr"
  )
  testthat::expect_identical(ledgr:::ledgr_availability_original_rows_json(exceptional), expected)
  testthat::expect_identical(writes, 1L)

  clean <- scale_test_events_snapshot()
  on.exit(ledgr_snapshot_close(clean), add = TRUE)
  testthat::expect_identical(ledgr_snapshot_info(clean)$off_session_bar_count, 0L)
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0247] off-session records sit beside quarantine and keep latin1 and infinite values", {
  days <- pit_consistency_days()
  saturday <- as.POSIXct(paste(days[[5]] + 1, "21:00:00"), tz = "UTC")
  add_off_session <- function(bars) {
    extra <- bars[bars$instrument_id == "AAA", , drop = FALSE][1L, ]
    extra$ts_utc <- saturday
    extra[c("open", "high", "low", "close")] <- 999
    rbind(bars, extra)
  }

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

  # Records keep the supplied row: latin1 text is written as UTF-8 and an
  # infinite extra value as a string, both as canonical JSON.
  cafe <- "café"
  odd <- scale_test_events_snapshot(edit_bars = function(bars) {
    extra <- rbind(bars[bars$instrument_id == "AAA", , drop = FALSE][1L, ], bars[bars$instrument_id == "BBB", , drop = FALSE][1L, ])
    extra$ts_utc <- saturday
    bars <- rbind(bars, extra)
    bars$note <- "plain"
    bars$score <- 1
    off <- bars$ts_utc == saturday
    bars$note[off] <- iconv(cafe, "UTF-8", "latin1")
    bars$score[off & bars$instrument_id == "AAA"] <- Inf
    bars
  })
  on.exit(ledgr_snapshot_close(odd), add = TRUE)
  records <- ledgr_snapshot_quarantine(odd)
  records <- records[order(records$supplied_instrument_id), , drop = FALSE]
  testthat::expect_identical(records$supplied_instrument_id, c("AAA", "BBB"))
  testthat::expect_true(all(grepl(paste0("\"note\":\"", cafe, "\""), records$original_row_json, fixed = TRUE)))
  testthat::expect_true(grepl("\"score\":\"Inf\"", records$original_row_json[[1L]], fixed = TRUE))
  testthat::expect_true(grepl("\"score\":1", records$original_row_json[[2L]], fixed = TRUE))
  testthat::expect_true(all(vapply(records$original_row_json, ledgr:::ledgr_snapshot_valid_canonical_json, logical(1))))
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
    exp <- ledgr_experiment(snapshot, buy_aaa,
      cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1000),
      corporate_action_policy = policy, ...
    )
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
  dense_bars <- data.frame(
    instrument_id = rep(c("AAA", "CCC"), each = 5), ts_utc = rep(at(days[1:5]), 2),
    open = 10, high = 10, low = 10, close = 10, volume = 1
  )
  dense <- ledgr_snapshot_from_df(
    dense_bars,
    db_path = tempfile(fileext = ".duckdb"), price_basis = "split_adjusted",
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
    ledgr_experiment(dense, buy_aaa,
      universe = c("AAA", "CCC"), cost_model = ledgr_cost_zero(),
      opening = ledgr_opening(cash = 1000), corporate_action_policy = ledgr_corporate_actions_strict()
    ),
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
    snapshot, buy_aaa,
    universe = ledgr_universe_members("u"), valuation_policy = ledgr_valuation_stale(2),
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

testthat::test_that("[LTB-0229] top-n ties break in C-locale order under any collation", {
  ids <- c("b2", "B1", "a3", "A4")
  signal <- ledgr_signal(stats::setNames(rep(1, 4), ids), origin = "tie")
  old <- Sys.getlocale("LC_COLLATE")
  on.exit(suppressWarnings(Sys.setlocale("LC_COLLATE", old)), add = TRUE)
  picked <- list()
  for (locale in c("C", "English_United States.1252", "en_US.UTF-8")) {
    if (!nzchar(suppressWarnings(Sys.setlocale("LC_COLLATE", locale)))) next
    selection <- ledgr_select_top_n(signal, 2)
    picked[[locale]] <- names(selection)[selection]
  }
  testthat::expect_gte(length(picked), 2L)
  for (p in picked) testthat::expect_identical(sort(p, method = "radix"), c("A4", "B1"))
})

testthat::test_that("[LTB-0230] ledgr_compute_metrics() withholds annualized figures for incomplete performance", {
  days <- pit_consistency_days()
  snapshot <- scale_test_events_snapshot()
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  buy_day <- as.character(days[[4]])
  buy_bbb <- function(ctx, params) {
    target <- ctx$hold()
    if (identical(substr(ctx$ts_utc, 1, 10), buy_day)) target[["BBB"]] <- 1
    target
  }
  experiment <- function(policy) {
    ledgr_experiment(snapshot, buy_bbb,
      universe = ledgr_universe_members("u"), valuation_policy = policy,
      cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1000)
    )
  }
  # BBB has no bar on the sixth session: refuse stops there, freeze runs on.
  stopped <- ledgr_run(experiment(ledgr_valuation_stale(0, exhausted = "refuse")), run_id = "metrics_incomplete")
  on.exit(close(stopped), add = TRUE)
  done <- ledgr_run(experiment(ledgr_valuation_stale(2)), run_id = "metrics_done")
  on.exit(close(done), add = TRUE)
  testthat::expect_identical(ledgr_run_completion(stopped)$completion_status, "INCOMPLETE")

  incomplete <- ledgr_compute_metrics(stopped)
  testthat::expect_true(all(is.na(c(incomplete$annualized_return, incomplete$volatility, incomplete$sharpe_ratio))))
  testthat::expect_identical(attr(incomplete, "withheld"), c("annualized_return", "volatility", "sharpe_ratio"))
  testthat::expect_true(is.finite(incomplete$total_return))
  printed <- utils::capture.output(print(incomplete))
  testthat::expect_true(any(grepl("Annualized Return: +withheld", printed)))

  complete <- ledgr_compute_metrics(done)
  testthat::expect_null(attr(complete, "withheld"))
  testthat::expect_true(is.finite(complete$annualized_return))
})

testthat::test_that("[LTB-0231] ledgr_backtest() refuses snapshots with point-in-time facts and writes no run", {
  hold <- function(ctx, params) ctx$hold()
  facts_snapshot <- scale_test_events_snapshot()
  on.exit(ledgr_snapshot_close(facts_snapshot), add = TRUE)
  err <- testthat::expect_error(
    ledgr_backtest(facts_snapshot, hold, cost_model = ledgr_cost_zero(), run_id = "refused"),
    class = "ledgr_backtest_availability_unsupported"
  )
  testthat::expect_s3_class(err, "ledgr_invalid_args")
  testthat::expect_match(conditionMessage(err), "membership, sessions, lifetime", fixed = TRUE)
  testthat::expect_match(conditionMessage(err), "ledgr_run()", fixed = TRUE)
  testthat::expect_identical(nrow(ledgr_run_list(facts_snapshot)), 0L)

  # Trading-status facts alone also refuse (each activating family counts).
  status_days <- as.POSIXct(paste(pit_consistency_days()[1:4], "21:00:00"), tz = "UTC")
  status_only <- ledgr_snapshot_from_df(
    data.frame(instrument_id = "AAA", ts_utc = status_days, open = 10, high = 10, low = 10, close = 10, volume = 1),
    data.frame(instrument_id = "AAA"),
    db_path = tempfile(fileext = ".duckdb"),
    facts = ledgr_facts(ledgr_facts_trading_status(data.frame(
      instrument_id = "AAA", effective_from = status_days[[2]], knowledge_time = status_days[[1]],
      status = "halted", source = "t"
    )))
  )
  on.exit(ledgr_snapshot_close(status_only), add = TRUE)
  status_err <- testthat::expect_error(
    ledgr_backtest(status_only, hold, cost_model = ledgr_cost_zero(), run_id = "refused_status"),
    class = "ledgr_backtest_availability_unsupported"
  )
  testthat::expect_match(conditionMessage(status_err), "point-in-time facts (trading_status)", fixed = TRUE)

  days <- pit_consistency_days()
  at <- function(d) as.POSIXct(paste(d, "21:00:00"), tz = "UTC")
  bars <- data.frame(
    instrument_id = "AAA", ts_utc = at(days),
    open = 10, high = 10, low = 10, close = 10, volume = 100
  )
  dense <- ledgr_snapshot_from_df(bars, data.frame(instrument_id = "AAA"), db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(dense), add = TRUE)
  ran <- ledgr_backtest(dense, hold, cost_model = ledgr_cost_zero(), run_id = "dense_ok")
  on.exit(close(ran), add = TRUE)
  testthat::expect_identical(ledgr_run_list(dense)$status, "DONE")

  ca_only <- ledgr_snapshot_from_df(
    bars, data.frame(instrument_id = "AAA"),
    db_path = tempfile(fileext = ".duckdb"), price_basis = "split_adjusted",
    facts = ledgr_facts(pit_consistency_ca("cash_dividend", "AAA", at(days[[3]]), at(days[[4]])))
  )
  on.exit(ledgr_snapshot_close(ca_only), add = TRUE)
  ran_ca <- ledgr_backtest(ca_only, hold, cost_model = ledgr_cost_zero(), run_id = "ca_only_ok")
  on.exit(close(ran_ca), add = TRUE)
  testthat::expect_identical(ledgr_run_list(ca_only)$status, "DONE")
})

testthat::test_that("[LTB-0232] an undeclared price basis runs as a disclosed split_adjusted default", {
  hold <- function(ctx, params) ctx$hold()
  experiment <- function(snapshot) {
    ledgr_experiment(snapshot, hold,
      universe = ledgr_universe_members("u"), valuation_policy = ledgr_valuation_stale(2),
      cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1000)
    )
  }
  undeclared <- scale_test_events_snapshot(price_basis = NULL)
  on.exit(ledgr_snapshot_close(undeclared), add = TRUE)
  exp <- experiment(undeclared)
  # Identity keeps the basis undeclared; disclosure shows the assumed model.
  testthat::expect_null(exp$data_identity$price_basis)
  plan <- ledgr_experiment_plan(exp)
  testthat::expect_identical(plan$price_basis, "split_adjusted")
  testthat::expect_true(plan$price_basis_default)
  assumed <- "split_adjusted (assumed default; the snapshot declares none)"
  testthat::expect_true(paste0("Price basis:  ", assumed) %in% utils::capture.output(print(plan)))
  testthat::expect_true(paste0("Price basis: ", assumed) %in% utils::capture.output(print(exp)))
  bt <- ledgr_run(exp, run_id = "assumed_basis")
  on.exit(close(bt), add = TRUE)
  testthat::expect_null(bt$config$data$price_basis)
  summary_ca <- ledgr_corporate_action_summary(bt)
  testthat::expect_identical(summary_ca$price_basis, "split_adjusted")
  testthat::expect_true(summary_ca$price_basis_default)
  testthat::expect_true(paste0("Price basis: ", assumed) %in% utils::capture.output(print(bt)))

  declared <- scale_test_events_snapshot()
  on.exit(ledgr_snapshot_close(declared), add = TRUE)
  exp_declared <- experiment(declared)
  testthat::expect_identical(exp_declared$data_identity$price_basis, "split_adjusted")
  plan_declared <- ledgr_experiment_plan(exp_declared)
  testthat::expect_false(plan_declared$price_basis_default)
  testthat::expect_true("Price basis:  split_adjusted (declared)" %in% utils::capture.output(print(plan_declared)))
  bt_declared <- ledgr_run(exp_declared, run_id = "declared_basis_label")
  on.exit(close(bt_declared), add = TRUE)
  testthat::expect_identical(bt_declared$config$data$price_basis, "split_adjusted")
  testthat::expect_false(ledgr_corporate_action_summary(bt_declared)$price_basis_default)
  printed <- utils::capture.output(print(bt_declared))
  testthat::expect_true("Price basis: split_adjusted (declared)" %in% printed)
  testthat::expect_false(any(grepl("assumed default", printed, fixed = TRUE)))
})

testthat::test_that("[LTB-0233] availability-aware experiments default to a disclosed 5-session horizon", {
  hold <- function(ctx, params) ctx$hold()
  testthat::expect_identical(ledgr_valuation_stale(), ledgr_valuation_stale(5, exhausted = "freeze"))
  snapshot <- scale_test_events_snapshot()
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  experiment <- function(...) {
    ledgr_experiment(snapshot, hold,
      universe = ledgr_universe_members("u"), cost_model = ledgr_cost_zero(),
      opening = ledgr_opening(cash = 1000), ...
    )
  }
  omitted <- experiment()
  testthat::expect_identical(omitted$valuation_policy, ledgr_valuation_stale())
  assumptions <- ledgr_experiment_plan(omitted)$assumptions
  testthat::expect_identical(assumptions$value[assumptions$setting == "valuation.max_sessions"], "5")
  testthat::expect_true(assumptions$default[assumptions$setting == "valuation.max_sessions"])
  testthat::expect_true(any(grepl("valuation.max_sessions +5 \\(default\\)$", utils::capture.output(print(ledgr_experiment_plan(omitted))))))

  bt_omitted <- ledgr_run(omitted, run_id = "horizon_omitted")
  on.exit(close(bt_omitted), add = TRUE)
  bt_five <- ledgr_run(experiment(valuation_policy = ledgr_valuation_stale(5)), run_id = "horizon_five")
  on.exit(close(bt_five), add = TRUE)
  # The defaulted policy is the same record and identity as declaring it.
  testthat::expect_identical(ledgr:::config_hash(bt_omitted$config), ledgr:::config_hash(bt_five$config))
  valuation <- ledgr_valuation_summary(bt_omitted)
  testthat::expect_identical(valuation$max_sessions, 5L)
  testthat::expect_true(valuation$max_sessions_default)
  testthat::expect_true(any(grepl("^  Max sessions: +5 \\(default\\)$", utils::capture.output(summary(bt_omitted)))))
  testthat::expect_true(any(grepl("max sessions 5 (default)", utils::capture.output(print(bt_omitted)), fixed = TRUE)))
  # LTB-0246 (review) covers a declared horizon and the dense default.
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0246] a declared horizon carries no default marker and the default never activates availability", {
  hold <- function(ctx, params) ctx$hold()
  testthat::expect_identical(ledgr_valuation_stale(), ledgr_valuation_stale(5, exhausted = "freeze"))
  snapshot <- scale_test_events_snapshot()
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  experiment <- function(...) {
    ledgr_experiment(snapshot, hold,
      universe = ledgr_universe_members("u"), cost_model = ledgr_cost_zero(),
      opening = ledgr_opening(cash = 1000), ...
    )
  }

  # A declared horizon other than the default carries no marker.
  bt_two <- ledgr_run(experiment(valuation_policy = ledgr_valuation_stale(2)), run_id = "horizon_two")
  on.exit(close(bt_two), add = TRUE)
  testthat::expect_false(ledgr_valuation_summary(bt_two)$max_sessions_default)
  testthat::expect_true(any(grepl("^  Max sessions: +2$", utils::capture.output(summary(bt_two)))))
  testthat::expect_true(any(grepl("max sessions 2;", utils::capture.output(print(bt_two)), fixed = TRUE)))

  # The default never activates availability: a snapshot without availability
  # facts stays dense and its config carries no valuation policy.
  days <- pit_consistency_days()
  dense <- ledgr_snapshot_from_df(
    data.frame(
      instrument_id = "AAA", ts_utc = as.POSIXct(paste(days, "21:00:00"), tz = "UTC"),
      open = 10, high = 10, low = 10, close = 10, volume = 1
    ),
    db_path = tempfile(fileext = ".duckdb")
  )
  on.exit(ledgr_snapshot_close(dense), add = TRUE)
  dense_exp <- ledgr_experiment(dense, hold, cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1000))
  testthat::expect_null(dense_exp$availability)
  testthat::expect_null(dense_exp$valuation_policy)
  bt_dense <- ledgr_run(dense_exp, run_id = "dense_no_default")
  on.exit(close(bt_dense), add = TRUE)
  testthat::expect_null(bt_dense$config$availability)
  testthat::expect_identical(ledgr_valuation_summary(bt_dense)$valuation_state, "not_applicable")
})

testthat::test_that("[LTB-0234] results name the universe kind and the assumption-backed fact families", {
  hold <- function(ctx, params) ctx$hold()
  run <- function(snapshot, universe, run_id) {
    exp <- ledgr_experiment(snapshot, hold,
      universe = universe, valuation_policy = ledgr_valuation_stale(2),
      cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1000)
    )
    ledgr_run(exp, run_id = run_id)
  }
  assumed <- scale_test_events_snapshot()
  on.exit(ledgr_snapshot_close(assumed), add = TRUE)

  # Membership rule over assume_effective sessions and membership (I_paths P6).
  rule <- run(assumed, ledgr_universe_members("u"), "kind_membership")
  on.exit(close(rule), add = TRUE)
  valuation <- ledgr_valuation_summary(rule)
  testthat::expect_identical(valuation$universe_kind, "membership")
  testthat::expect_identical(valuation$universe_id, "u")
  testthat::expect_identical(valuation$assumption_backed_families, c("membership", "sessions"))
  testthat::expect_identical(valuation$assumption_reasons, c("knowledge_assume_effective", "knowledge_assume_effective"))
  testthat::expect_true(paste(
    "Point in time: membership rule 'u'; max sessions 2;",
    "assumption-backed facts: membership (knowledge assumed effective); sessions (knowledge assumed effective)"
  ) %in% utils::capture.output(print(rule)))
  summary_lines <- utils::capture.output(summary(rule))
  testthat::expect_true("  Universe:                    membership rule 'u'" %in% summary_lines)
  testthat::expect_true(paste0(
    "  Assumption-backed facts:     membership (knowledge assumed effective); sessions (knowledge assumed effective)"
  ) %in% summary_lines)

  # A fixed basket on the same snapshot does not apply membership (I_paths P8).
  basket <- run(assumed, c("AAA", "BBB"), "kind_basket")
  on.exit(close(basket), add = TRUE)
  valuation_basket <- ledgr_valuation_summary(basket)
  testthat::expect_identical(valuation_basket$universe_kind, "fixed")
  testthat::expect_true(is.na(valuation_basket$universe_id))
  testthat::expect_true(valuation_basket$membership_declared)
  testthat::expect_identical(valuation_basket$assumption_backed_families, "sessions")
  testthat::expect_true(paste(
    "Point in time: fixed basket (the snapshot's membership facts are not applied); max sessions 2;",
    "assumption-backed facts: sessions (knowledge assumed effective)"
  ) %in% utils::capture.output(print(basket)))
  testthat::expect_true(
    "  Universe:                    fixed basket (the snapshot's membership facts are not applied)" %in%
      utils::capture.output(summary(basket))
  )

  # Evidenced facts carry no assumption label on any surface.
  evidenced <- scale_test_events_snapshot(knowledge = "evidenced")
  on.exit(ledgr_snapshot_close(evidenced), add = TRUE)
  clean <- run(evidenced, ledgr_universe_members("u"), "kind_evidenced")
  on.exit(close(clean), add = TRUE)
  testthat::expect_identical(ledgr_valuation_summary(clean)$assumption_backed_families, character())
  testthat::expect_true("Point in time: membership rule 'u'; max sessions 2" %in% utils::capture.output(print(clean)))
  testthat::expect_false(any(grepl("Assumption-backed", utils::capture.output(summary(clean)), fixed = TRUE)))
  # LTB-0243 (review) covers two universes of different knowledge.
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0243] a membership rule rests only on its own universe's assumptions", {
  hold <- function(ctx, params) ctx$hold()
  run <- function(snapshot, universe, run_id) {
    exp <- ledgr_experiment(snapshot, hold,
      universe = universe, valuation_policy = ledgr_valuation_stale(2),
      cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1000)
    )
    ledgr_run(exp, run_id = run_id)
  }
  # A membership rule rests only on its own universe: an assumed second
  # universe in the same snapshot does not label an evidenced one.
  second <- data.frame(
    effective_from = as.POSIXct("2021-01-03 21:00:00", tz = "UTC"),
    knowledge_time = as.POSIXct("2021-01-03 21:00:00", tz = "UTC"), source = "t"
  )
  second$members <- I(list(c("AAA", "BBB")))
  mixed <- scale_test_events_snapshot(knowledge = "evidenced", extra_facts = ledgr_facts_membership_snapshots(
    second,
    universe_id = "v", complete = TRUE, knowledge = "assume_effective"
  ))
  on.exit(ledgr_snapshot_close(mixed), add = TRUE)
  evidenced_rule <- run(mixed, ledgr_universe_members("u"), "kind_mixed_u")
  on.exit(close(evidenced_rule), add = TRUE)
  testthat::expect_identical(ledgr_valuation_summary(evidenced_rule)$assumption_backed_families, character())
  assumed_rule <- run(mixed, ledgr_universe_members("v"), "kind_mixed_v")
  on.exit(close(assumed_rule), add = TRUE)
  testthat::expect_identical(ledgr_valuation_summary(assumed_rule)$assumption_backed_families, "membership")
})

testthat::test_that("[LTB-0235] promotion records both identities and warns on a mismatch", {
  snapshot <- scale_test_events_snapshot()
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  buy <- function(ctx, params) {
    target <- ctx$hold()
    ids <- ctx$tradable()
    if (length(ids)) target[ids] <- params$qty
    target
  }
  buy_twice <- function(ctx, params) {
    target <- ctx$hold()
    ids <- ctx$tradable()
    if (length(ids)) target[ids] <- 2 * params$qty
    target
  }
  experiment <- function(strategy = buy, universe = ledgr_universe_members("u"), valuation = ledgr_valuation_stale(2),
                         policy = ledgr_corporate_actions_research(), cash = 1000, features = list()) {
    ledgr_experiment(snapshot, strategy,
      universe = universe, valuation_policy = valuation, cost_model = ledgr_cost_zero(),
      opening = ledgr_opening(cash = cash), corporate_action_policy = policy, features = features
    )
  }
  sweep <- ledgr_sweep(experiment(), ledgr_param_grid(q1 = list(qty = 1)))
  candidate <- ledgr_candidate(sweep, which = 1L)

  same <- testthat::expect_no_warning(ledgr_promote(experiment(), candidate, run_id = "promote_same"))
  on.exit(close(same), add = TRUE)
  check <- ledgr_promotion_context(same)$identity_check
  testthat::expect_identical(ledgr_promotion_context(same)$promotion_context_version, "ledgr_promotion_v2")
  testthat::expect_identical(check$mismatched, character())
  testthat::expect_identical(check$not_recorded, character())
  testthat::expect_identical(check$candidate, check$promoting)
  testthat::expect_setequal(names(check$promoting), c(
    "strategy_hash", "universe_hash", "valuation_policy_hash", "corporate_action_policy_hash", "opening_hash",
    "feature_set_hash"
  ))

  # One policy variant and the feature-set variant stay here; LTB-0242
  # (review) covers the universe, valuation, corporate-action and opening ones.
  variants <- list(
    strategy_hash = experiment(strategy = buy_twice),
    feature_set_hash = experiment(features = ledgr_feature_map(signal = ledgr_ind_sma(2L)))
  )
  for (field in names(variants)) {
    run_id <- paste0("promote_", field)
    testthat::expect_warning(
      bt <- ledgr_promote(variants[[field]], candidate, run_id = run_id),
      class = "ledgr_promote_identity_mismatch"
    )
    check <- ledgr_promotion_context(bt)$identity_check
    testthat::expect_identical(check$mismatched, field, info = field)
    testthat::expect_false(identical(check$candidate[[field]], check$promoting[[field]]), info = field)
    close(bt)
  }

  # A non-current promotion record refuses instead of losing its identity check.
  con <- ledgr:::get_connection(snapshot)
  stored <- DBI::dbGetQuery(con, "SELECT source_sweep_json FROM run_promotion_context WHERE run_id = 'promote_same'")
  v1_sweep <- ledgr:::ledgr_json_read_nested(stored$source_sweep_json[[1]])
  v1_sweep$identity_check <- NULL
  DBI::dbExecute(
    con,
    "UPDATE run_promotion_context SET promotion_context_version = 'ledgr_promotion_v1', source_sweep_json = ? WHERE run_id = 'promote_same'",
    params = list(as.character(ledgr:::canonical_json(v1_sweep)))
  )
  testthat::expect_error(
    ledgr_promotion_context(same),
    "Stored promotion context does not use ledgr_promotion_v2.",
    class = "ledgr_invalid_store",
    fixed = TRUE
  )
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0242] promotion warns on each policy, universe and opening identity", {
  snapshot <- scale_test_events_snapshot()
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  buy <- function(ctx, params) {
    target <- ctx$hold()
    ids <- ctx$tradable()
    if (length(ids)) target[ids] <- params$qty
    target
  }
  buy_twice <- function(ctx, params) {
    target <- ctx$hold()
    ids <- ctx$tradable()
    if (length(ids)) target[ids] <- 2 * params$qty
    target
  }
  experiment <- function(strategy = buy, universe = ledgr_universe_members("u"), valuation = ledgr_valuation_stale(2),
                         policy = ledgr_corporate_actions_research(), cash = 1000, features = list()) {
    ledgr_experiment(snapshot, strategy,
      universe = universe, valuation_policy = valuation, cost_model = ledgr_cost_zero(),
      opening = ledgr_opening(cash = cash), corporate_action_policy = policy, features = features
    )
  }
  sweep <- ledgr_sweep(experiment(), ledgr_param_grid(q1 = list(qty = 1)))
  candidate <- ledgr_candidate(sweep, which = 1L)

  variants <- list(
    universe_hash = experiment(universe = c("AAA", "BBB")),
    valuation_policy_hash = experiment(valuation = ledgr_valuation_stale(0, exhausted = "refuse")),
    corporate_action_policy_hash = experiment(policy = ledgr_corporate_actions_strict()),
    opening_hash = experiment(cash = 500)
  )
  for (field in names(variants)) {
    run_id <- paste0("promote_", field)
    testthat::expect_warning(
      bt <- ledgr_promote(variants[[field]], candidate, run_id = run_id),
      class = "ledgr_promote_identity_mismatch"
    )
    check <- ledgr_promotion_context(bt)$identity_check
    testthat::expect_identical(check$mismatched, field, info = field)
    testthat::expect_false(identical(check$candidate[[field]], check$promoting[[field]]), info = field)
    close(bt)
  }
})

testthat::test_that("[LTB-0236] run and session identity bind snapshot content under identity rule 2", {
  days <- pit_consistency_days()
  at <- function(d) as.POSIXct(paste(d, "21:00:00"), tz = "UTC")
  flat <- function(ctx, params) ctx$flat()
  bars <- data.frame(instrument_id = "Z", ts_utc = at(days[1:4]), open = 1, high = 1, low = 1, close = 1)
  run_hash <- function(snapshot, run_id) {
    exp <- ledgr_experiment(snapshot, flat, cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1000))
    bt <- ledgr_run(exp, run_id = run_id)
    on.exit(close(bt))
    testthat::expect_identical(bt$config$identity_rule_version, 2L)
    testthat::expect_identical(bt$config$data$snapshot_hash, ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]])
    ledgr_run_info(snapshot, run_id)$config_hash
  }
  # Identical content under two snapshot IDs (A_calendar_window C6).
  db <- tempfile(fileext = ".duckdb")
  one <- ledgr_snapshot_from_df(bars, db_path = db, snapshot_id = "snap_one")
  on.exit(ledgr_snapshot_close(one), add = TRUE)
  two <- ledgr_snapshot_from_df(bars, db_path = db, snapshot_id = "snap_two")
  on.exit(ledgr_snapshot_close(two), add = TRUE)
  testthat::expect_identical(run_hash(one, "id_one"), run_hash(two, "id_two"))
  # Different content under one reused snapshot ID.
  changed <- bars
  changed$close[[4]] <- 2
  changed$high[[4]] <- 2
  other <- ledgr_snapshot_from_df(changed, db_path = tempfile(fileext = ".duckdb"), snapshot_id = "snap_one")
  on.exit(ledgr_snapshot_close(other), add = TRUE)
  testthat::expect_false(identical(run_hash(one, "reuse_a"), run_hash(other, "reuse_b")))

  current <- ledgr_run_open(one, "id_one")
  testthat::expect_identical(nrow(ledgr_results(current, "equity")), 4L)
  close(current)

  # The recorded start is the clamped scoring start (S2_calendar_short K3, I_paths P10).
  early <- ledgr_experiment(one, flat, cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1000, date = days[[1]] - 30))
  bt_early <- ledgr_run(early, run_id = "early_opening")
  on.exit(close(bt_early), add = TRUE)
  plain <- ledgr_run(ledgr_experiment(one, flat, cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1000)),
    run_id = "plain_opening"
  )
  on.exit(close(plain), add = TRUE)
  testthat::expect_identical(bt_early$config$backtest$start_ts_utc, plain$config$backtest$start_ts_utc)
  testthat::expect_identical(bt_early$config$backtest$start_ts_utc, one$metadata$start_date)

  # LTB-0244 (review) covers walk-forward session identity.
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0244] walk-forward sessions use current content identity", {
  days <- pit_consistency_days()
  at <- function(d) as.POSIXct(paste(d, "21:00:00"), tz = "UTC")
  # A walk-forward session records rule 2 and reuses the same current identity.
  snapshot <- scale_test_events_snapshot()
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(snapshot, function(ctx, params) ctx$hold(),
    universe = ledgr_universe_members("u"),
    valuation_policy = ledgr_valuation_stale(2), cost_model = ledgr_cost_zero(),
    opening = ledgr_opening(cash = 1000)
  )
  folds <- ledgr:::ledgr_fold_list(
    list(ledgr_fold(at(days[[2]]), at(days[[7]]), at(days[[8]]), at(days[[13]]), fold_seq = 1L)),
    constructor = list(type_id = "explicit")
  )
  wf_args <- list(exp, grid = ledgr_param_grid(a = list()), folds = folds, selection_rule = ledgr_rule_argmax("sharpe_ratio"))
  wf <- do.call(ledgr_walk_forward, wf_args)
  wf_con <- ledgr:::get_connection(snapshot)
  session <- DBI::dbGetQuery(wf_con, "SELECT session_id, meta_json FROM walk_forward_sessions")
  testthat::expect_identical(nrow(session), 1L)
  testthat::expect_identical(as.integer(ledgr:::ledgr_json_read_nested(session$meta_json[[1]])$identity_rule_version), 2L)

  identity <- ledgr:::ledgr_walk_forward_session_identity(
    exp, wf_args$grid, folds, wf_args$selection_rule, NULL, "carry_test_state", "previous"
  )
  testthat::expect_identical(identity$session_id, session$session_id[[1]])
  do.call(ledgr_walk_forward, wf_args)
  sessions <- DBI::dbGetQuery(
    wf_con,
    "SELECT session_id, meta_json FROM walk_forward_sessions"
  )
  testthat::expect_identical(nrow(sessions), 1L)
  testthat::expect_identical(sessions$session_id[[1]], identity$session_id)
  testthat::expect_identical(
    ledgr_walk_forward_open(snapshot, identity$session_id)$session_id,
    identity$session_id
  )
})
