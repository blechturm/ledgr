# Cut 10 real-data run continuity (LDG-2973 to LDG-2975).

continuity_bars <- function() {
  data.frame(
    instrument_id = rep(c("AAA", "BBB"), each = 5),
    ts_utc = rep(as.POSIXct("2020-01-06 21:00:00", tz = "UTC") + 86400 * 0:4, 2),
    open = rep(c(10, 20), each = 5), high = rep(c(10, 20), each = 5),
    low = rep(c(10, 20), each = 5), close = rep(c(10, 20), each = 5), volume = 100
  )
}

continuity_run_row <- function(snapshot, run_id) {
  DBI::dbGetQuery(
    ledgr:::get_connection(snapshot),
    "SELECT status, error_msg FROM runs WHERE run_id = ?",
    params = list(run_id)
  )
}

testthat::test_that("[LTB-0198] an early exit after registration records FAILED and still propagates", {
  snapshot <- ledgr_snapshot_from_df(continuity_bars(), db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  hold <- function(ctx, params) ctx$hold()
  buy <- function(ctx, params) {
    target <- ctx$flat()
    target[["AAA"]] <- 1
    target
  }
  exp_with <- function(features, strategy = hold) {
    ledgr_experiment(snapshot, strategy, features = features, opening = ledgr_opening(cash = 1000),
                     cost_model = ledgr_cost_zero())
  }
  failing <- ledgr_indicator(id = "boom", requires_bars = 1L, fn = function(window) stop("feature exploded"))
  # One definition, so a rerun resumes the same row; the option picks the exit.
  interrupting <- ledgr_indicator(id = "halt", requires_bars = 1L, fn = function(window) {
    if (identical(getOption("ledgr.test.continuity_exit"), "error")) stop("second attempt failed")
    rlang::interrupt()
  })

  # An error during feature computation, before the pulse loop.
  testthat::expect_error(ledgr_run(exp_with(list(failing)), run_id = "early-error"), "feature exploded")
  row <- continuity_run_row(snapshot, "early-error")
  testthat::expect_identical(row$status, "FAILED")
  testthat::expect_match(row$error_msg, "feature exploded", fixed = TRUE)

  # An interrupt is observed, recorded and still reaches the caller.
  got <- tryCatch(ledgr_run(exp_with(list(interrupting)), run_id = "early-interrupt"),
                  interrupt = function(e) "interrupted")
  testthat::expect_identical(got, "interrupted")
  row <- continuity_run_row(snapshot, "early-interrupt")
  testthat::expect_identical(row$status, "FAILED")
  testthat::expect_identical(row$error_msg, "Run interrupted before completion.")

  # A resumed row that already says FAILED takes the new attempt's message.
  old <- options(ledgr.test.continuity_exit = "error")
  testthat::expect_error(ledgr_run(exp_with(list(interrupting)), run_id = "early-interrupt"), "second attempt failed")
  options(old)
  row <- continuity_run_row(snapshot, "early-interrupt")
  testthat::expect_identical(row$status, "FAILED")
  testthat::expect_match(row$error_msg, "second attempt failed", fixed = TRUE)

  # Normal endings and the soft stop are untouched.
  done <- ledgr_run(exp_with(list(), buy), run_id = "normal-done")
  close(done)
  row <- continuity_run_row(snapshot, "normal-done")
  testthat::expect_identical(row$status, "DONE")
  testthat::expect_true(is.na(row$error_msg))
  old <- options(ledgr.interrupt = TRUE)
  soft <- ledgr_run(exp_with(list(), buy), run_id = "soft-stop")
  options(old)
  close(soft)
  row <- continuity_run_row(snapshot, "soft-stop")
  testthat::expect_identical(row$status, "RUNNING")
  testthat::expect_true(is.na(row$error_msg))
})

testthat::test_that("[LTB-0199] an unpriced eligible member is skipped, capped and recorded, not fatal", {
  ctx_with <- function(close, position, risk_mark, equity = 1000) {
    ctx <- list(
      universe = c("AAA", "BBB"), equity = equity, availability_active = TRUE,
      members = c("AAA", "BBB"),
      vec = list(close = close, position = position, risk_mark = risk_mark,
                 admissible = c(TRUE, TRUE)),
      .notes = new.env(parent = emptyenv())
    )
    ctx$.notes$sizing_skipped <- character()
    ctx
  }
  weights <- ledgr_weights(c(AAA = 0.5, BBB = 0.5), universe = c("AAA", "BBB"))

  # Unheld skip: AAA keeps its fully priced size, BBB stays flat, weight unspent.
  ctx <- ctx_with(close = c(10, NA), position = c(0, 0), risk_mark = c(10, NA))
  target <- ledgr_target_rebalance(weights, ctx, equity_fraction = 0.9)
  testthat::expect_identical(unclass(target)[c("AAA", "BBB")], c(AAA = 45, BBB = 0))
  testthat::expect_identical(attr(target, "sizing_skipped"), "BBB")
  testthat::expect_identical(ctx$.notes$sizing_skipped, "BBB")

  # Held skip below the cap: AAA unchanged at 45, BBB keeps 22 (E = 440).
  ctx <- ctx_with(close = c(10, NA), position = c(45, 22), risk_mark = c(10, 20))
  target <- ledgr_target_rebalance(weights, ctx, equity_fraction = 0.9)
  testthat::expect_identical(unclass(target)[c("AAA", "BBB")], c(AAA = 45, BBB = 22))

  # Cap binds: E = 900, V = 500, s = 0.2, AAA = floor(0.2 * 500 / 10) = 10.
  ctx <- ctx_with(close = c(10, NA), position = c(10, 45), risk_mark = c(10, 20))
  target <- ledgr_target_rebalance(weights, ctx, equity_fraction = 1)
  testthat::expect_identical(unclass(target)[c("AAA", "BBB")], c(AAA = 10, BBB = 45))

  # A held skipped member without any permissible mark still fails closed.
  ctx <- ctx_with(close = c(10, NA), position = c(10, 45), risk_mark = c(10, NA))
  testthat::expect_error(ledgr_target_rebalance(weights, ctx, equity_fraction = 1),
                         class = "ledgr_target_sizing_unavailable")

  # End to end: the canonical pipeline completes and records each skip even
  # when the strategy flattens the target to a plain vector.
  days <- as.Date(c("2020-01-06", "2020-01-07", "2020-01-08", "2020-01-09", "2020-01-10"))
  utc <- function(d) as.POSIXct(paste(d, "21:00:00"), tz = "UTC")
  bars <- continuity_bars()
  bars <- bars[!(bars$instrument_id == "BBB" & as.Date(bars$ts_utc) %in% days[c(1, 4)]), , drop = FALSE]
  membership <- data.frame(effective_from = utc(days[[1]] - 1), knowledge_time = utc(days[[1]] - 1), source = "d")
  membership$members <- I(list(c("AAA", "BBB")))
  facts <- ledgr_facts(
    ledgr_facts_sessions(
      data.frame(session_date = days, status = "open", session_open = "14:30:00", session_close = "21:00:00"),
      venue_id = "V", timezone = "UTC", knowledge = "assume_effective"),
    ledgr_facts_membership_snapshots(membership, universe_id = "u", complete = TRUE, knowledge = "assume_effective")
  )
  snapshot <- ledgr_snapshot_from_df(bars, data.frame(instrument_id = c("AAA", "BBB")),
                                     db_path = tempfile(fileext = ".duckdb"), facts = facts)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    c(ctx |> ledgr_selection() |> ledgr_weight_equal() |> ledgr_target_rebalance(ctx, equity_fraction = 0.9))
  }
  bt <- ledgr_run(
    ledgr_experiment(snapshot, strategy, universe = ledgr_universe_members("u"),
                     valuation_policy = ledgr_valuation_stale(2), cost_model = ledgr_cost_zero(),
                     opening = ledgr_opening(cash = 1000)),
    run_id = "skip-and-record"
  )
  on.exit(close(bt), add = TRUE)
  fills <- ledgr_results(bt, "fills")
  testthat::expect_identical(paste(fills$instrument_id, fills$side, fills$qty), c("AAA BUY 45", "BBB BUY 22"))
  diag <- ledgr_results(bt, "diagnostics")
  skips <- diag[diag$stage == "decision" & diag$reason_code == "sizing_unavailable", , drop = FALSE]
  testthat::expect_identical(skips$instrument_id, c("BBB", "BBB"))
  testthat::expect_identical(as.Date(skips$ts_utc), days[c(1, 4)])
  testthat::expect_identical(skips$target, c(0, 22))
})
