# One fixture for every LDG-2960 surface: AAA is frozen when its bankruptcy
# lifetime terminal arrives (frozen fallback write_off), BBB carries a
# delisted terminal that the declared map refuses, and CLK always trades.
selection_visibility_fixture <- function() {
  lifetime <- ledgr_facts_lifetime(data.frame(
    instrument_id = c("AAA", "BBB"),
    effective_from = terminal_outcome_day(c(5L, 4L)),
    knowledge_time = terminal_outcome_day(c(5L, 4L)) - 1,
    assertion = "known_inactive",
    terminal_event = c("bankruptcy", "delisted"),
    stringsAsFactors = FALSE
  ))
  snapshot <- terminal_outcome_snapshot(
    list(
      AAA = c(100, 102, rep(NA_real_, 8L)),
      BBB = c(50, 52, 51, rep(NA_real_, 7L)),
      CLK = c(10, 11, 10, 12, 11, 13, 12, 14, 13, 15)
    ),
    lifetime = lifetime
  )
  strategy <- function(ctx, params) {
    if (identical(params$mode, "fail") && identical(ctx$ts_utc, "2020-01-03T16:00:00Z")) {
      stop("candidate failed on purpose")
    }
    target <- ctx$hold()
    target[["CLK"]] <- params$clk
    if (identical(ctx$ts_utc, "2020-01-01T16:00:00Z")) {
      if (identical(params$mode, "frozen")) target[["AAA"]] <- 1
      if (identical(params$mode, "hold")) target[["BBB"]] <- 1
    }
    target
  }
  exp <- ledgr_experiment(
    snapshot,
    strategy,
    opening = ledgr_opening(cash = 1000),
    valuation_policy = ledgr_valuation_stale(1),
    corporate_action_policy = ledgr_corporate_actions(
      held_terminal_position = c(delisted = "refuse", default = "last_permissible")
    ),
    cost_model = ledgr_cost_zero()
  )
  list(snapshot = snapshot, exp = exp)
}

selection_visibility_params <- function() {
  list(
    clean = list(mode = "clean", clk = 10),
    frozen = list(mode = "frozen", clk = 5),
    hold = list(mode = "hold", clk = 5),
    fail = list(mode = "fail", clk = 5)
  )
}

selection_visibility_grid <- function(ids = names(selection_visibility_params())) {
  do.call(ledgr_param_grid, selection_visibility_params()[ids])
}

# The expected surface, derived from the fixture by hand: clean trades CLK
# only; frozen buys AAA at 102, which is frozen on day 4 and written off by
# the research frozen fallback on day 5; hold buys BBB, whose delisted
# terminal is refused on day 4; fail errors on day 3.
selection_visibility_expected <- function() {
  list(
    candidate_id = c("clean", "frozen", "hold", "fail"),
    status = c("DONE", "DONE", "INCOMPLETE", "FAILED"),
    stop_reason = c(NA, NA, "terminal_settlement_unsupported", NA),
    affected_instrument_ids = list(character(), character(), "BBB", NA_character_),
    valuation_state = c("current", "frozen", "current", NA),
    frozen_instrument_sessions = c(0L, 1L, 0L, NA),
    assumed_terminal_outcomes = c(0L, 1L, 0L, NA)
  )
}

selection_visibility_count_lines <- function(noun = "candidates") {
  c(
    sprintf("4 %s attempted: 2 done, 1 incomplete, 1 failed.", noun),
    sprintf(
      "Of the done %s, 1 froze a holding and 1 used an assumed terminal outcome; see valuation_state and assumed_terminal_outcomes.",
      noun
    )
  )
}

selection_visibility_expect_rows <- function(rows, expected = selection_visibility_expected()) {
  at <- match(expected$candidate_id, rows$candidate_id)
  testthat::expect_false(anyNA(at))
  column <- function(name) unname(rows[[name]][at])
  testthat::expect_identical(as.character(column("status")), expected$status)
  testthat::expect_identical(column("stop_reason"), expected$stop_reason)
  testthat::expect_identical(column("affected_instrument_ids"), expected$affected_instrument_ids)
  testthat::expect_identical(column("valuation_state"), expected$valuation_state)
  testthat::expect_identical(column("frozen_instrument_sessions"), expected$frozen_instrument_sessions)
  testthat::expect_identical(column("assumed_terminal_outcomes"), expected$assumed_terminal_outcomes)
}

# ledgr-test-profile: review
testthat::test_that("[LTB-0176] a mixed sweep shows counts, reasons and flags on every sweep surface", {
  fx <- selection_visibility_fixture()
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  sweep <- ledgr_sweep(
    fx$exp,
    selection_visibility_grid(),
    retain = ledgr_sweep_retention(returns = "completed")
  )

  # The live table, its print and the reopened table carry the same rows.
  selection_visibility_expect_rows(sweep)
  frozen <- sweep[sweep$candidate_id == "frozen", , drop = FALSE]
  testthat::expect_equal(frozen$max_frozen_equity_weight, 102 / 1005)
  testthat::expect_equal(frozen$frozen_at_end_value, 0)
  printed <- utils::capture.output(print(sweep))
  testthat::expect_true(all(paste("# i", selection_visibility_count_lines()) %in% printed))
  saved_id <- ledgr_sweep_save(sweep, fx$snapshot, sweep_id = "selection-visibility")
  reopened <- ledgr_sweep_open(fx$snapshot, saved_id)
  selection_visibility_expect_rows(reopened)
  for (name in c("max_frozen_equity_weight", "frozen_at_end_value")) {
    testthat::expect_identical(reopened[[name]], sweep[[name]])
  }

  # Review ranks the frozen DONE candidate beside its exposure fields and
  # lists the incomplete and failed candidates as issues with their reasons.
  review <- ledgr_sweep_review(sweep, rank_by = total_return)
  testthat::expect_identical(review$ranked$candidate_id, c("frozen", "clean"))
  testthat::expect_true(all(c(
    "valuation_state", "max_frozen_equity_weight", "frozen_at_end_value",
    "assumed_terminal_outcomes"
  ) %in% names(review$top)))
  testthat::expect_identical(review$issues$candidate_id, c("hold", "fail"))
  testthat::expect_identical(review$issues$stop_reason, c("terminal_settlement_unsupported", NA))
  testthat::expect_identical(unname(review$issues$affected_instrument_ids), list("BBB", NA_character_))
  testthat::expect_identical(
    review$counts[c("attempted", "done", "incomplete", "failed", "frozen_done", "assumed_done")],
    list(attempted = 4L, done = 2L, incomplete = 1L, failed = 1L, frozen_done = 1L, assumed_done = 1L)
  )
  review_print <- utils::capture.output(print(review))
  testthat::expect_true(all(paste("# i", selection_visibility_count_lines()) %in% review_print))

  # Incomplete and failed candidates never reach filtering or promotion.
  filtered <- ledgr_sweep_filter(
    sweep,
    ledgr_business_objective(ledgr_objective_max_drawdown(1))
  )
  testthat::expect_setequal(unique(filtered$tear_down$candidate_id), c("clean", "frozen"))
  testthat::expect_error(
    ledgr_candidate(sweep, "hold", allow_failed = TRUE),
    class = "ledgr_incomplete_sweep_candidate"
  )
  testthat::expect_s3_class(ledgr_candidate(sweep, "frozen"), "ledgr_sweep_candidate")
  # A failed candidate stays extractable for diagnosis only on request, and
  # is never promotable (Cut 6 decision 10).
  testthat::expect_error(ledgr_candidate(sweep, "fail"), class = "ledgr_failed_sweep_candidate")
  failed_candidate <- ledgr_candidate(sweep, "fail", allow_failed = TRUE)
  testthat::expect_s3_class(failed_candidate, "ledgr_sweep_candidate")
  testthat::expect_error(
    ledgr_promote(fx$exp, failed_candidate, run_id = "promote-failed"),
    class = "ledgr_promote_failed_candidate"
  )
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0177] attempted and incomplete candidates never enter validation math", {
  fx <- selection_visibility_fixture()
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  retain <- ledgr_sweep_retention(returns = "completed")
  mixed <- ledgr_sweep(fx$exp, selection_visibility_grid(), retain = retain)
  # Oracle: the completed-only panel, swept on its own.
  oracle <- ledgr_sweep(fx$exp, selection_visibility_grid(c("clean", "frozen")), retain = retain)

  mixed_panel <- ledgr_sweep_returns_panel(mixed)
  oracle_panel <- ledgr_sweep_returns_panel(oracle)
  testthat::expect_identical(mixed_panel$candidate_ids, c("clean", "frozen"))
  testthat::expect_identical(mixed_panel$excluded_candidate_ids, c("hold", "fail"))
  testthat::expect_identical(mixed_panel$matrix, oracle_panel$matrix)
  testthat::expect_identical(mixed_panel$panel_hash, oracle_panel$panel_hash)

  # Only the sweep identity and the excluded-ID disclosure may differ.
  trials_mixed <- ledgr_effective_trials(mixed)
  trials_oracle <- ledgr_effective_trials(oracle)
  testthat::expect_identical(trials_mixed$membership, trials_oracle$membership)
  testthat::expect_identical(trials_mixed$distances, trials_oracle$distances)
  maths <- c("panel_hash", "effective_trials", "raw_trials", "n_observations", "candidate_ids")
  testthat::expect_identical(trials_mixed$summary[maths], trials_oracle$summary[maths])
  dsr_mixed <- ledgr_dsr(mixed, effective_trials = 2)
  dsr_oracle <- ledgr_dsr(oracle, effective_trials = 2)
  dsr_mixed$summary$sweep_id <- NULL
  dsr_oracle$summary$sweep_id <- NULL
  testthat::expect_identical(dsr_mixed$summary, dsr_oracle$summary)

  # Structural detectors: an incomplete or failed prefix cannot be added.
  for (id in c("hold", "fail")) {
    testthat::expect_error(
      ledgr_sweep_returns_panel(mixed, candidates = c("clean", "frozen", id)),
      class = "ledgr_sweep_returns_candidate_not_completed"
    )
    testthat::expect_error(
      ledgr_dsr(mixed, candidates = c("clean", "frozen", id), effective_trials = 2),
      class = "ledgr_sweep_returns_candidate_not_completed"
    )
    testthat::expect_error(
      ledgr_effective_trials(mixed, candidates = c("clean", "frozen", id)),
      class = "ledgr_sweep_returns_candidate_not_completed"
    )
  }
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0178] run lists and comparison disclose incomplete runs and carry flags", {
  fx <- selection_visibility_fixture()
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  params <- selection_visibility_params()
  for (id in names(params)) {
    run_id <- paste0("run-", id)
    bt <- tryCatch(ledgr_run(fx$exp, params = params[[id]], run_id = run_id), error = function(e) NULL)
    if (!is.null(bt)) close(bt)
  }

  runs <- ledgr_run_list(fx$snapshot)
  runs$candidate_id <- sub("^run-", "", runs$run_id)
  selection_visibility_expect_rows(runs)
  printed <- utils::capture.output(print(runs))
  testthat::expect_true(all(selection_visibility_count_lines("runs") %in% sub("^# i ", "", printed)))

  # The stored flags agree with the run's own valuation evidence.
  frozen_bt <- ledgr_run_open(fx$snapshot, "run-frozen")
  valuation <- ledgr_valuation_summary(frozen_bt)
  close(frozen_bt)
  frozen_row <- runs[runs$run_id == "run-frozen", , drop = FALSE]
  testthat::expect_identical(frozen_row$frozen_instrument_sessions, valuation$frozen_instrument_sessions)
  testthat::expect_equal(frozen_row$max_frozen_equity_weight, valuation$max_frozen_equity_weight)
  testthat::expect_equal(frozen_row$frozen_at_end_value, valuation$frozen_at_end_value)

  # Comparison keeps only DONE runs and says how many it left out.
  compared <- ledgr_run_compare(fx$snapshot)
  testthat::expect_setequal(compared$run_id, c("run-clean", "run-frozen"))
  testthat::expect_identical(
    compared$valuation_state[match(c("run-clean", "run-frozen"), compared$run_id)],
    c("current", "frozen")
  )
  counts <- attr(compared, "selection_counts", exact = TRUE)
  testthat::expect_identical(
    counts[c("attempted", "done", "incomplete", "failed")],
    list(attempted = 4L, done = 2L, incomplete = 1L, failed = 1L)
  )
  compare_print <- utils::capture.output(print(compared))
  testthat::expect_true(any(grepl("4 runs attempted: 2 done, 1 incomplete, 1 failed.", compare_print, fixed = TRUE)))
  testthat::expect_true(any(grepl("Only DONE runs are compared", compare_print, fixed = TRUE)))
  # The flag columns keep the curated view: the full-table footer still prints.
  testthat::expect_true(
    "# i Full identity and telemetry columns remain available on this tibble." %in% compare_print
  )

  # A run named twice keeps its flags on both rows.
  repeated <- ledgr_run_compare(fx$snapshot, run_ids = c("run-frozen", "run-frozen"))
  testthat::expect_identical(repeated$valuation_state, c("frozen", "frozen"))
  testthat::expect_identical(repeated$frozen_instrument_sessions, c(1L, 1L))
  testthat::expect_identical(repeated$assumed_terminal_outcomes, c(1L, 1L))
  testthat::expect_identical(repeated$max_frozen_equity_weight[[1L]], repeated$max_frozen_equity_weight[[2L]])
  testthat::expect_gt(repeated$max_frozen_equity_weight[[2L]], 0)

  # A named incomplete run keeps its typed refusal.
  testthat::expect_error(
    ledgr_run_compare(fx$snapshot, run_ids = c("run-clean", "run-hold")),
    class = "ledgr_run_not_complete"
  )
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0190] frozen flags use a constant number of grouped store reads", {
  fx <- selection_visibility_fixture()
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  frozen_ids <- c("batch-frozen-a", "batch-frozen-b")
  for (run_id in frozen_ids) {
    bt <- ledgr_run(
      fx$exp,
      params = selection_visibility_params()$frozen,
      run_id = run_id
    )
    close(bt)
  }

  dense_bars <- ledgr_test_make_bars("DENSE", as.Date("2020-02-01") + 0:2)
  dense_snapshot <- ledgr_snapshot_from_df(
    dense_bars,
    db_path = fx$snapshot$db_path
  )
  on.exit(ledgr_snapshot_close(dense_snapshot), add = TRUE)
  dense <- ledgr_run(
    ledgr_experiment(
      dense_snapshot,
      function(ctx, params) ctx$flat(),
      cost_model = ledgr_cost_zero()
    ),
    run_id = "batch-dense"
  )
  close(dense)

  individual <- lapply(frozen_ids, function(run_id) {
    bt <- ledgr_run_open(fx$snapshot, run_id)
    on.exit(close(bt), add = TRUE)
    ledgr_valuation_summary(bt)
  })
  names(individual) <- frozen_ids
  con <- ledgr:::get_connection(fx$snapshot)
  query_count <- 0L
  original_query <- DBI::dbGetQuery
  testthat::local_mocked_bindings(
    dbGetQuery = function(conn, statement, ...) {
      query_count <<- query_count + 1L
      original_query(conn, statement, ...)
    },
    .package = "DBI"
  )
  ledgr:::ledgr_run_assumption_flags_many(con, frozen_ids[[1L]])
  one_run_queries <- query_count
  query_count <- 0L
  ids <- c(frozen_ids, frozen_ids[[1L]], "batch-dense")
  flags <- ledgr:::ledgr_run_assumption_flags_many(con, ids)
  testthat::expect_identical(query_count, one_run_queries)
  testthat::expect_identical(query_count, 4L)
  testthat::expect_identical(flags$run_id, ids)
  testthat::expect_identical(
    flags$valuation_state,
    c("frozen", "frozen", "frozen", NA_character_)
  )
  for (run_id in frozen_ids) {
    at <- which(flags$run_id == run_id)
    testthat::expect_true(all(
      flags$max_frozen_equity_weight[at] ==
        individual[[run_id]]$max_frozen_equity_weight
    ))
    testthat::expect_true(all(
      flags$frozen_at_end_value[at] ==
        individual[[run_id]]$frozen_at_end_value
    ))
  }

  listed <- ledgr_run_list(fx$snapshot)
  compared <- ledgr_run_compare(
    fx$snapshot,
    run_ids = c(frozen_ids, frozen_ids[[1L]])
  )
  for (surface in list(listed, compared)) {
    for (run_id in frozen_ids) {
      at <- which(surface$run_id == run_id)
      testthat::expect_true(all(
        surface$max_frozen_equity_weight[at] ==
          individual[[run_id]]$max_frozen_equity_weight
      ))
      testthat::expect_true(all(
        surface$frozen_at_end_value[at] ==
          individual[[run_id]]$frozen_at_end_value
      ))
    }
  }
  dense_listed <- ledgr_run_list(dense_snapshot)
  dense_compared <- ledgr_run_compare(dense_snapshot, run_ids = "batch-dense")
  testthat::expect_true(is.na(dense_listed$valuation_state[[1L]]))
  testthat::expect_true(is.na(dense_compared$valuation_state[[1L]]))
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0179] walk-forward scores and print carry counts, reasons and flags", {
  fx <- selection_visibility_fixture()
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  folds <- ledgr:::ledgr_fold_list(
    list(ledgr_fold(
      terminal_outcome_day(1L), terminal_outcome_day(6L),
      terminal_outcome_day(7L), terminal_outcome_day(10L),
      fold_seq = 1L
    )),
    constructor = list(type_id = "explicit")
  )
  wf <- ledgr_walk_forward(
    fx$exp,
    grid = selection_visibility_grid(),
    folds = folds,
    selection_rule = ledgr_rule_argmax("sharpe_ratio"),
    seed = 11L
  )
  on.exit(lapply(wf$test_runs, function(run) try(close(run), silent = TRUE)), add = TRUE)

  train <- wf$scores[wf$scores$window == "train" & wf$scores$metric_name == "sharpe_ratio", , drop = FALSE]
  train$candidate_id <- train$candidate_label
  selection_visibility_expect_rows(train)
  testthat::expect_identical(wf$selected$candidate_id, "clean")

  printed <- utils::capture.output(print(wf))
  testthat::expect_true(all(selection_visibility_count_lines("train evaluations") %in% printed))
  testthat::expect_true("1 test runs attempted: 1 done, 0 incomplete, 0 failed." %in% printed)

  reopened <- ledgr_walk_forward_scores(fx$snapshot, wf$session_id)
  testthat::expect_identical(
    reopened[names(wf$scores)],
    wf$scores[order(wf$scores$fold_seq, wf$scores$window, wf$scores$candidate_key, wf$scores$metric_name), ]
  )
})

# ledgr-test-profile: fast
testthat::test_that("[LTB-0180] the experiment plan lists declared assumptions with default markers", {
  fx <- selection_visibility_fixture()
  on.exit(ledgr_snapshot_close(fx$snapshot), add = TRUE)
  plan <- ledgr_experiment_plan(fx$exp)
  testthat::expect_identical(
    as.data.frame(plan$assumptions),
    data.frame(
      setting = c(
        "valuation.max_sessions", "valuation.exhausted",
        "held_terminal_position.delisted", "held_terminal_position.default",
        "frozen_terminal_position"
      ),
      value = c("1", "freeze", "refuse", "last_permissible", "write_off"),
      default = c(FALSE, TRUE, FALSE, TRUE, TRUE),
      stringsAsFactors = FALSE
    )
  )
  printed <- utils::capture.output(print(plan))
  testthat::expect_true("Declared assumptions:" %in% printed)
  testthat::expect_true(any(grepl("^  held_terminal_position\\.delisted +refuse$", printed)))
  testthat::expect_true(any(grepl("^  frozen_terminal_position +write_off \\(default\\)$", printed)))
})
