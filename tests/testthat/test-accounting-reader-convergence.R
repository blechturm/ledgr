# ledgr-test-file-profile: review

testthat::test_that("[LTB-0551] accounting readers converge on one typed replay", {
  source_text <- function(fn) paste(deparse(body(fn)), collapse = "\n")

  recovery <- source_text(ledgr:::ledgr_run_terminal_recovery_equity)
  testthat::expect_length(
    gregexpr("ledgr_replay_accounting_events", recovery, fixed = TRUE)[[1L]],
    1L
  )
  testthat::expect_match(recovery, "ledgr_accounting_positions_at_pulses", fixed = TRUE)
  testthat::expect_false(grepl("ledgr_state_asof", recovery, fixed = TRUE))

  headline <- source_text(ledgr:::ledgr_headline_closed_trade_count)
  testthat::expect_match(headline, "ledgr_prepare_accounting_events", fixed = TRUE)
  testthat::expect_match(headline, "ledgr_replay_accounting_events", fixed = TRUE)
  testthat::expect_false(grepl("for (", headline, fixed = TRUE))

  for (fn in list(
    ledgr:::ledgr_corporate_action_held_unsupported,
    ledgr:::ledgr_corporate_action_composition_report,
    ledgr:::ledgr_corporate_action_summary
  )) {
    text <- source_text(fn)
    testthat::expect_match(text, "ledgr_prepare_accounting_events", fixed = TRUE)
  }
  testthat::expect_false(exists(
    "ledgr_corporate_action_event_meta",
    envir = asNamespace("ledgr"),
    inherits = FALSE
  ))

  sweep <- source_text(ledgr:::ledgr_sweep_run_candidate)
  testthat::expect_match(sweep, "output_handler$inline_summary", fixed = TRUE)
  testthat::expect_match(sweep, "ledgr_sweep_summary_from_ordered_events", fixed = TRUE)

  # The forward projection is exact on an event/pulse ladder; increasing the
  # ladder adds rows, not replay calls or prefix replays.
  rows <- ledgr_test_complete_fill_rows(data.frame(
    event_id = paste0("linear-", 1:200), run_id = "linear",
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 1:200,
    event_type = "FILL", instrument_id = "AAA",
    side = rep(c("BUY", "SELL"), 100), qty = 1, price = 10, fee = 0,
    event_seq = 1:200,
    stringsAsFactors = FALSE
  ))
  replay <- ledgr:::ledgr_replay_accounting_events(
    ledgr:::ledgr_prepare_accounting_events(rows, "AAA"),
    initial_cash = 1000
  )
  at <- as.POSIXct("2020-01-01", tz = "UTC") + 1:200
  projected <- ledgr:::ledgr_accounting_positions_at_pulses(replay, at, "AAA")
  testthat::expect_identical(as.numeric(projected), rep(c(1, 0), 100))
})
