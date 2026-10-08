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

testthat::test_that("[LTB-0200] the walk-forward no-selection policy, its record and the schema 118 migration", {
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

  # Migration: a schema 117 fold table gains selection_source, selected folds
  # backfill to train, unselected folds stay NULL, and every CHECK survives.
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  DBI::dbExecute(con, "
    CREATE TABLE walk_forward_folds (
      session_id TEXT NOT NULL, fold_id TEXT NOT NULL, fold_seq INTEGER NOT NULL, scheme TEXT NOT NULL,
      train_start_utc TIMESTAMP NOT NULL, train_end_utc TIMESTAMP NOT NULL,
      test_start_utc TIMESTAMP NOT NULL, test_end_utc TIMESTAMP NOT NULL,
      hydration_start_utc TIMESTAMP NOT NULL, train_scoring_start_utc TIMESTAMP NOT NULL,
      test_scoring_start_utc TIMESTAMP NOT NULL,
      opening_state_policy TEXT NOT NULL CHECK (opening_state_policy IN ('carry_test_state','flat_test_state')),
      selected_candidate_key TEXT, selected_at_utc TIMESTAMP, test_run_id TEXT,
      status TEXT NOT NULL CHECK (status IN ('DONE','FAILED','INTERRUPTED','PARTIAL')),
      PRIMARY KEY (session_id, fold_seq), UNIQUE (session_id, fold_id))")
  DBI::dbExecute(con, "
    INSERT INTO walk_forward_folds VALUES
      ('s', 'f1', 1, 'rolling', '2020-01-01', '2020-01-31', '2020-02-01', '2020-02-29', '2020-01-01',
       '2020-01-01', '2020-02-01', 'carry_test_state', 'k1', '2020-02-01', 'r1', 'DONE'),
      ('s', 'f2', 2, 'rolling', '2020-02-01', '2020-02-29', '2020-03-01', '2020-03-31', '2020-02-01',
       '2020-02-01', '2020-03-01', 'carry_test_state', NULL, NULL, NULL, 'FAILED')")
  testthat::expect_true(ledgr:::ledgr_experiment_store_upgrade_walk_forward_folds(con))
  migrated <- DBI::dbGetQuery(con, "SELECT fold_seq, status, selection_source FROM walk_forward_folds ORDER BY fold_seq")
  testthat::expect_identical(migrated$status, c("DONE", "FAILED"))
  testthat::expect_identical(migrated$selection_source, c("train", NA))
  testthat::expect_false(ledgr:::ledgr_experiment_store_upgrade_walk_forward_folds(con))
  testthat::expect_error(DBI::dbExecute(con, "UPDATE walk_forward_folds SET selection_source = 'guess'"))
  testthat::expect_error(DBI::dbExecute(con, "UPDATE walk_forward_folds SET status = 'MAYBE'"))
  testthat::expect_error(DBI::dbExecute(con, "INSERT INTO walk_forward_folds SELECT * FROM walk_forward_folds WHERE fold_seq = 1"))
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0201] walk-forward reuses the previous selection or runs no test window", {
  utc <- function(d) as.POSIXct(paste(d, "21:00:00"), tz = "UTC")
  all_days <- seq(as.Date("2020-01-01"), as.Date("2020-06-30"), by = "day")
  weekday <- as.integer(format(all_days, "%u")) <= 5L
  days <- all_days[weekday]
  close <- 10 + seq_along(days) %% 7 / 10
  bars <- rbind(
    data.frame(instrument_id = "AAA", ts_utc = utc(days), open = close, high = close, low = close, close = close, volume = 100),
    data.frame(instrument_id = "BBB", ts_utc = utc(days), open = rev(close), high = rev(close), low = rev(close),
               close = rev(close), volume = 100)
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
                                     db_path = tempfile(fileext = ".duckdb"), facts = facts)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  # Trade through February, then hold cash: training windows starting in
  # March or later have constant equity and no finite Sharpe ratio.
  strategy <- function(ctx, params) {
    if (substr(ctx$ts_utc, 1, 10) > "2020-02-29") return(ctx$flat())
    ctx |> ledgr_selection() |> ledgr_weight_equal() |> ledgr_target_rebalance(ctx, equity_fraction = params$f)
  }
  exp <- ledgr_experiment(snapshot, strategy, universe = ledgr_universe_members("u"),
                          valuation_policy = ledgr_valuation_stale(2), cost_model = ledgr_cost_zero(),
                          opening = ledgr_opening(cash = 1000))
  folds <- ledgr_folds_rolling("2020-01-02", "2020-06-30", train_window = "1 month",
                               test_window = "1 month", step = "1 month")
  wf <- ledgr_walk_forward(exp, ledgr_strategy_grid(f = c(0.5, 0.9)), folds,
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
