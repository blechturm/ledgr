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

# ledgr-test-profile: review
testthat::test_that("[LTB-0202] a mid-loop interrupt is re-raised and an INCOMPLETE row is never rewritten", {
  hold <- function(ctx, params) ctx$hold()
  # An interrupt inside the pulse loop is not swallowed by the fold
  # transaction: the row is FAILED, the caller sees it, and a rerun resumes to
  # the uninterrupted result.
  moving <- continuity_bars()
  moving$close <- moving$open <- moving$high <- moving$low <- c(10:14, 20:24)
  moving_snapshot <- ledgr_snapshot_from_df(moving, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(moving_snapshot), add = TRUE)
  midloop <- function(ctx, params) {
    if (identical(getOption("ledgr.test.continuity_midloop"), substr(ctx$ts_utc, 1, 10))) rlang::interrupt()
    target <- ctx$flat()
    target[["AAA"]] <- if (substr(ctx$ts_utc, 9, 10) %in% c("06", "08")) 10 else 5
    target
  }
  midloop_exp <- ledgr_experiment(moving_snapshot, midloop, opening = ledgr_opening(cash = 1000),
                                  cost_model = ledgr_cost_zero())
  reference <- ledgr_run(midloop_exp, run_id = "midloop-reference")
  on.exit(close(reference), add = TRUE)
  old <- options(ledgr.test.continuity_midloop = "2020-01-09")
  got <- tryCatch(ledgr_run(midloop_exp, run_id = "midloop"), interrupt = function(e) "interrupted")
  options(old)
  testthat::expect_identical(got, "interrupted")
  row <- continuity_run_row(moving_snapshot, "midloop")
  testthat::expect_identical(row$status, "FAILED")
  testthat::expect_identical(row$error_msg, "Run interrupted before completion.")
  resumed <- ledgr_run(midloop_exp, run_id = "midloop")
  on.exit(close(resumed), add = TRUE)
  testthat::expect_gt(nrow(ledgr_results(reference, "fills")), 1L)
  testthat::expect_identical(ledgr_results(resumed, "fills")$qty, ledgr_results(reference, "fills")$qty)
  testthat::expect_identical(ledgr_results(resumed, "equity")$equity, ledgr_results(reference, "equity")$equity)

  # The guard never touches an INCOMPLETE row: corrupt its completion evidence
  # so the resume path fails after registration, and the status must stay.
  days <- as.Date(c("2020-01-06", "2020-01-07", "2020-01-08"))
  utc <- function(d) as.POSIXct(paste(d, "21:00:00"), tz = "UTC")
  gap_bars <- data.frame(instrument_id = "AAA", ts_utc = utc(days[c(1, 3)]), open = 10, high = 10,
                         low = 10, close = 10, volume = 100)
  membership <- data.frame(effective_from = utc(days[[1]] - 1), knowledge_time = utc(days[[1]] - 1), source = "d")
  membership$members <- I(list("AAA"))
  gap_snapshot <- ledgr_snapshot_from_df(
    gap_bars, data.frame(instrument_id = "AAA"), db_path = tempfile(fileext = ".duckdb"),
    facts = ledgr_facts(
      ledgr_facts_sessions(
        data.frame(session_date = days, status = "open", session_open = "14:30:00", session_close = "21:00:00"),
        venue_id = "V", timezone = "UTC", knowledge = "assume_effective"),
      ledgr_facts_membership_snapshots(membership, universe_id = "u", complete = TRUE, knowledge = "assume_effective")
    ), price_basis = "split_adjusted"
  )
  on.exit(ledgr_snapshot_close(gap_snapshot), add = TRUE)
  incomplete_exp <- ledgr_experiment(
    gap_snapshot, hold, universe = ledgr_universe_members("u"),
    opening = ledgr_opening(cash = 1000, positions = c(AAA = 1), cost_basis = c(AAA = 10)),
    valuation_policy = ledgr_valuation_stale(0, exhausted = "refuse"), cost_model = ledgr_cost_zero()
  )
  incomplete <- ledgr_run(incomplete_exp, run_id = "kept-incomplete")
  close(incomplete)
  testthat::expect_identical(continuity_run_row(gap_snapshot, "kept-incomplete")$status, "INCOMPLETE")
  DBI::dbExecute(ledgr:::get_connection(gap_snapshot), "DELETE FROM run_completion WHERE run_id = 'kept-incomplete'")
  testthat::expect_error(ledgr_run(incomplete_exp, run_id = "kept-incomplete"))
  testthat::expect_identical(continuity_run_row(gap_snapshot, "kept-incomplete")$status, "INCOMPLETE")

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
                                     db_path = tempfile(fileext = ".duckdb"), facts = facts, price_basis = "split_adjusted")
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

testthat::test_that("[LTB-0200] the walk-forward no-selection policy and current record", {
  # Inspection: a previous fold reports no train selection score even when its
  # candidate's train row is INCOMPLETE with a finite value; a none fold has no
  # selected row.
  folds <- tibble::tibble(
    fold_seq = 1:3, fold_id = c("f1", "f2", "f3"),
    train_start_utc = as.POSIXct(c("2020-01-01", "2020-02-01", "2020-03-01"), tz = "UTC"),
    train_end_utc = as.POSIXct(c("2020-01-31", "2020-02-29", "2020-03-31"), tz = "UTC"),
    test_start_utc = as.POSIXct(c("2020-02-01", "2020-03-01", "2020-04-01"), tz = "UTC"),
    test_end_utc = as.POSIXct(c("2020-02-29", "2020-03-31", "2020-04-30"), tz = "UTC"),
    selected_candidate_key = c(NA, "k2", "k3"),
    test_run_id = c(NA, "r2", "r3"),
    status = "DONE",
    selection_source = c("none", "train", "previous")
  )
  scores <- tibble::tibble(
    fold_seq = c(2L, 2L, 3L, 3L), window = c("train", "test", "train", "test"),
    candidate_key = c("k2", "t2", "k3", "t3"), candidate_label = "cand",
    metric_name = "sharpe_ratio", metric_value = c(1.5, 0.5, 2.5, 0.25),
    status = c("DONE", "DONE", "INCOMPLETE", "DONE")
  )
  degradation <- ledgr:::ledgr_walk_forward_degradation_table(folds, scores, "sharpe_ratio")
  testthat::expect_identical(degradation$selection_source, c("none", "train", "previous"))
  testthat::expect_identical(degradation$train_metric_value[2:3], c(1.5, NA_real_))
  testthat::expect_identical(degradation$test_metric_value[2:3], c(0.5, 0.25))
  # The in-memory selected row for a previous fold blanks the metric too.
  train_wide <- tibble::tibble(candidate_key = c("k3", "other"), candidate_id = "cand",
                               sharpe_ratio = c(2.5, 1), status = c("INCOMPLETE", "DONE"))
  previous_row <- ledgr:::ledgr_walk_forward_previous_selection(train_wide, "k3", "sharpe_ratio")
  testthat::expect_identical(previous_row$candidate_key, "k3")
  testthat::expect_identical(previous_row$sharpe_ratio, NA_real_)
  selected <- ledgr:::ledgr_walk_forward_selected_from_rows(folds, scores, "sharpe_ratio")
  testthat::expect_identical(selected$fold_seq, 2:3)
  testthat::expect_identical(selected$selection_source, c("train", "previous"))
  testthat::expect_identical(selected$sharpe_ratio, c(1.5, NA_real_))

  # Identity: "fail" keeps the pre-Cut-10 payload; "previous" changes the ID.
  id_args <- list(snapshot_hash = "s", experiment_hash = "e", param_grid_hash = "g", fold_list_hash = "f",
                  selection_rule_hash = "r", metric_context_hash = "m", cost_model_hash = "c",
                  risk_chain_hash = "k", master_seed = 1L, ledgr_version = "0")
  fail_payload <- do.call(ledgr:::ledgr_walk_forward_session_payload, c(id_args, list(no_selection = "fail")))
  testthat::expect_false("no_selection" %in% names(fail_payload))
  testthat::expect_false(identical(
    do.call(ledgr:::ledgr_walk_forward_session_id, c(id_args, list(no_selection = "fail"))),
    do.call(ledgr:::ledgr_walk_forward_session_id, c(id_args, list(no_selection = "previous")))
  ))

  # The current schema owns selection_source directly; no migration path
  # remains in the package.
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)
  columns <- ledgr_test_store_columns(con, "walk_forward_folds")
  testthat::expect_true("selection_source" %in% columns)
  DBI::dbExecute(con, "
    INSERT INTO walk_forward_folds (
      session_id, fold_id, fold_seq, scheme, train_start_utc, train_end_utc,
      test_start_utc, test_end_utc,
      train_scoring_start_utc, test_scoring_start_utc, opening_state_policy,
      selection_source, status
    ) VALUES (
      's', 'f1', 1, 'rolling', '2020-01-01', '2020-01-31',
      '2020-02-01', '2020-02-29', '2020-01-01',
      '2020-02-01', 'carry_test_state', 'train', 'DONE'
    )")
  testthat::expect_error(DBI::dbExecute(con, "UPDATE walk_forward_folds SET selection_source = 'guess'"))
  testthat::expect_error(DBI::dbExecute(con, "UPDATE walk_forward_folds SET status = 'MAYBE'"))
  testthat::expect_error(DBI::dbExecute(con, "INSERT INTO walk_forward_folds SELECT * FROM walk_forward_folds"))
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0201] walk-forward reuses the previous selection or runs no test window", {
  utc <- function(d) as.POSIXct(paste(d, "21:00:00"), tz = "UTC")
  all_days <- seq(as.Date("2020-01-01"), as.Date("2020-06-30"), by = "day")
  weekday <- as.integer(format(all_days, "%u")) <= 5L
  days <- all_days[weekday]
  # AAA rises through January and falls through February; BBB does the
  # opposite. A one-month training window therefore selects AAA in fold 1
  # and BBB in fold 2, so "most recent" and "first" selections differ.
  month <- format(days, "%m")
  wiggle <- rep(c(0.02, 0.06), length.out = length(days))
  step_aaa <- ifelse(month == "01", wiggle, ifelse(month == "02", -wiggle, 0))
  aaa <- 10 + cumsum(step_aaa)
  bbb <- 10 + cumsum(-step_aaa)
  bars <- rbind(
    data.frame(instrument_id = "AAA", ts_utc = utc(days), open = aaa, high = aaa, low = aaa, close = aaa, volume = 100),
    data.frame(instrument_id = "BBB", ts_utc = utc(days), open = bbb, high = bbb, low = bbb, close = bbb, volume = 100)
  )
  membership <- data.frame(effective_from = utc(days[[1]]), knowledge_time = utc(days[[1]]), source = "d")
  membership$members <- I(list(c("AAA", "BBB")))
  facts <- ledgr_facts(
    ledgr_facts_sessions(
      data.frame(session_date = all_days, status = ifelse(weekday, "open", "closed"),
                 session_open = ifelse(weekday, "14:30:00", NA), session_close = ifelse(weekday, "21:00:00", NA)),
      venue_id = "V", timezone = "UTC", knowledge = "assume_effective"),
    ledgr_facts_membership_snapshots(membership, universe_id = "u", complete = TRUE, knowledge = "assume_effective")
  )
  snapshot <- ledgr_snapshot_from_df(bars, data.frame(instrument_id = c("AAA", "BBB")),
                                     db_path = tempfile(fileext = ".duckdb"), facts = facts, price_basis = "split_adjusted")
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  # Trade through February, then hold cash: training windows starting in
  # March or later have constant equity and no finite Sharpe ratio.
  strategy <- function(ctx, params) {
    target <- ctx$flat()
    if (substr(ctx$ts_utc, 1, 10) <= "2020-02-29") target[[params$asset]] <- 50
    target
  }
  exp <- ledgr_experiment(snapshot, strategy, universe = ledgr_universe_members("u"),
                          valuation_policy = ledgr_valuation_stale(2), cost_model = ledgr_cost_zero(),
                          opening = ledgr_opening(cash = 1000))
  folds <- ledgr_folds_rolling("2020-01-02", "2020-06-30", train_window = "1 month",
                               test_window = "1 month", step = "1 month")
  wf <- ledgr_walk_forward(exp, ledgr_strategy_grid(asset = c("AAA", "BBB")), folds,
                           ledgr_rule_argmax("sharpe_ratio"), seed = 1L)
  testthat::expect_identical(wf$status, "DONE")
  testthat::expect_identical(wf$no_selection, "previous")
  starts <- as.Date(wf$folds$train_start_utc)
  testthat::expect_identical(wf$folds$selection_source, ifelse(starts >= as.Date("2020-03-01"), "previous", "train"))
  testthat::expect_true(all(wf$folds$status == "DONE") && all(!is.na(wf$folds$test_run_id)))
  reopened <- ledgr_walk_forward_open(snapshot, wf$session_id)
  testthat::expect_identical(reopened$no_selection, "previous")
  testthat::expect_identical(reopened$folds$selection_source, wf$folds$selection_source)
  previous_seq <- wf$folds$fold_seq[wf$folds$selection_source == "previous"][[1]]
  candidate <- ledgr_candidate(wf, previous_seq)
  testthat::expect_identical(candidate$provenance$walk_forward$selection_source, "previous")
  testthat::expect_true(is.na(candidate$provenance$walk_forward$selected_train_metric_value))
  # Previous folds reuse the latest training selection (BBB, fold 2), not the
  # first (AAA, fold 1), and report no selection score in memory either.
  testthat::expect_identical(ledgr_candidate(wf, 1L)$params$asset, "AAA")
  testthat::expect_identical(ledgr_candidate(wf, 2L)$params$asset, "BBB")
  testthat::expect_identical(candidate$params$asset, "BBB")
  testthat::expect_identical(candidate$provenance$walk_forward$selection_source_fold_seq, 2L)
  previous_rows <- wf$selected$selection_source == "previous"
  testthat::expect_true(any(previous_rows))
  testthat::expect_true(all(is.na(wf$selected$sharpe_ratio[previous_rows])))

  cash <- function(ctx, params) ctx$flat()
  cash_exp <- ledgr_experiment(snapshot, cash, universe = ledgr_universe_members("u"),
                               valuation_policy = ledgr_valuation_stale(2), cost_model = ledgr_cost_zero(),
                               opening = ledgr_opening(cash = 1000))
  none <- ledgr_walk_forward(cash_exp, ledgr_strategy_grid(f = c(0.5, 0.9)), folds,
                             ledgr_rule_argmax("sharpe_ratio"), seed = 1L)
  testthat::expect_identical(none$status, "DONE")
  testthat::expect_true(all(none$folds$selection_source == "none") && all(is.na(none$folds$test_run_id)))
  testthat::expect_match(paste(utils::capture.output(print(none)), collapse = "\n"), "ran no test window", fixed = TRUE)
  testthat::expect_error(ledgr_candidate(none, 1L), class = "ledgr_walk_forward_candidate_not_found")
  testthat::expect_error(
    ledgr_walk_forward(cash_exp, ledgr_strategy_grid(f = c(0.5, 0.9)), folds,
                       ledgr_rule_argmax("sharpe_ratio"), seed = 1L, no_selection = "fail"),
    class = "ledgr_walk_forward_no_selection"
  )
})
