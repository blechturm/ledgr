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
