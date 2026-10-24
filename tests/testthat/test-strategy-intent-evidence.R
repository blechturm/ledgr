intent_evidence_bars <- function(days = 8L, session_close = FALSE) {
  dates <- as.Date("2020-01-01") + seq_len(days) - 1L
  ts <- if (session_close) {
    as.POSIXct(paste(dates, "16:00:00"), tz = "UTC")
  } else {
    as.POSIXct(dates, tz = "UTC")
  }
  data.frame(
    ts_utc = ts,
    instrument_id = "AAA",
    open = 100 + seq_len(days),
    high = 101 + seq_len(days),
    low = 99 + seq_len(days),
    close = 100 + seq_len(days),
    volume = 1000,
    stringsAsFactors = FALSE
  )
}

intent_evidence_strategy <- function(ctx, params) {
  n <- if (is.null(ctx$state_prev$n)) 1L else ctx$state_prev$n + 1L
  targets <- if (n == 1L) {
    stats::setNames(rep(params$quantity, length(ctx$universe)), ctx$universe)
  } else {
    ctx$hold()
  }
  out <- list(targets = targets, state_update = list(n = n))
  if (isTRUE(params$record) && !n %in% params$omit_at) {
    out$intent_reason <- if (n == 1L) "minimum_variance_solution" else "hold_current_portfolio"
  }
  out
}

intent_evidence_availability_snapshot <- function(days = 4L) {
  dates <- as.Date("2020-01-01") + seq_len(days) - 1L
  sessions <- ledgr_facts_sessions(
    data.frame(
      session_date = dates,
      status = "open",
      session_open = "09:30:00",
      session_close = "16:00:00",
      knowledge_time = as.POSIXct(dates, tz = "UTC") - 1,
      stringsAsFactors = FALSE
    ),
    venue_id = "XNYS"
  )
  membership <- ledgr_facts_membership_snapshots(
    data.frame(
      effective_from = as.POSIXct("2020-01-01", tz = "UTC"),
      knowledge_time = as.POSIXct("2019-12-31", tz = "UTC"),
      set_id = "members",
      members = I(list("AAA")),
      source = "test",
      stringsAsFactors = FALSE
    ),
    universe_id = "U",
    complete = TRUE
  )
  ledgr_snapshot_from_df(
    intent_evidence_bars(days, session_close = TRUE),
    instruments_df = data.frame(instrument_id = "AAA"),
    facts = ledgr_facts(sessions, membership),
    price_basis = "split_adjusted"
  )
}

intent_evidence_rows <- function(bt) {
  diagnostics <- tibble::as_tibble(ledgr_results(bt, "diagnostics"))
  diagnostics[diagnostics$reason_code == "strategy_intent", , drop = FALSE]
}

# ledgr-test-profile: review
testthat::test_that("[LTB-0490] structured intent reasons use one durable portfolio row", {
  snapshot <- ledgr_snapshot_from_df(intent_evidence_bars(3L))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  old_option <- options(ledgr.test.intent.record = TRUE)
  on.exit(options(old_option), add = TRUE)
  strategy <- function(ctx, params) {
    n <- if (is.null(ctx$state_prev$n)) 1L else ctx$state_prev$n + 1L
    targets <- if (n == 1L) {
      stats::setNames(rep(params$quantity, length(ctx$universe)), ctx$universe)
    } else {
      ctx$hold()
    }
    out <- list(targets = targets, state_update = list(n = n))
    if (isTRUE(getOption("ledgr.test.intent.record", FALSE)) &&
        !n %in% params$omit_at) {
      out$intent_reason <- if (n == 1L) {
        "minimum_variance_solution"
      } else {
        "hold_current_portfolio"
      }
    }
    out
  }
  exp <- ledgr_experiment(
    snapshot,
    strategy,
    cost_model = ledgr_cost_zero(),
    opening = ledgr_opening(cash = 1000)
  )
  with_reason <- ledgr_run(
    exp,
    params = list(quantity = 1, omit_at = 2L),
    run_id = "intent-dense-recorded"
  )
  on.exit(close(with_reason), add = TRUE)
  rows <- intent_evidence_rows(with_reason)

  testthat::expect_identical(nrow(rows), 2L)
  testthat::expect_identical(rows$instrument_id, c("", ""))
  testthat::expect_identical(rows$stage, rep("decision", 2L))
  testthat::expect_identical(rows$outcome, rep("recorded", 2L))
  testthat::expect_identical(rows$reason_code, rep("strategy_intent", 2L))
  testthat::expect_identical(rows$reasons, rep("strategy_intent", 2L))
  parsed <- lapply(rows$detail_json, ledgr:::ledgr_json_read_nested)
  testthat::expect_identical(
    lapply(parsed, names),
    rep(list("intent_reason"), 2L)
  )
  testthat::expect_identical(
    vapply(parsed, `[[`, character(1L), "intent_reason"),
    c("minimum_variance_solution", "hold_current_portfolio")
  )
  dense_intent_query <- NULL
  diagnostics_filtered <- ledgr:::ledgr_backtest_diagnostics_filtered
  dense_explanation <- testthat::with_mocked_bindings(
    ledgr_run_explain(with_reason, "AAA"),
    ledgr_backtest_diagnostics_filtered = function(...,
                                                    include_strategy_intent = FALSE) {
      dense_intent_query <<- include_strategy_intent
      diagnostics_filtered(
        ...,
        include_strategy_intent = include_strategy_intent
      )
    },
    .package = "ledgr"
  )
  testthat::expect_identical(dense_intent_query, FALSE)
  testthat::expect_identical(nrow(dense_explanation), 0L)
  testthat::expect_identical(
    names(dense_explanation),
    c(
      "run_id", "ts_utc", "instrument_id", "member", "held",
      "target_restricted", "target_restriction_reason",
      "target_restriction_reasons", "feature_identity_json", "quantity",
      "target_before_risk", "target_after_risk", "execution_outcome",
      "execution_reason", "execution_reasons", "resulting_position",
      "mark_source", "mark_age", "completion_status", "complete_performance"
    )
  )
  fills <- ledgr_results(with_reason, "fills")
  equity <- ledgr_results(with_reason, "equity")
  metrics <- ledgr_compute_metrics(with_reason)
  con <- ledgr:::get_connection(snapshot)
  state_with_reason <- DBI::dbGetQuery(
    con,
    paste(
      "SELECT ts_utc, state_json FROM strategy_state",
      "WHERE run_id = 'intent-dense-recorded' ORDER BY ts_utc"
    )
  )

  close(with_reason)
  reopened <- ledgr_run_open(snapshot, "intent-dense-recorded")
  on.exit(close(reopened), add = TRUE)
  testthat::expect_identical(intent_evidence_rows(reopened), rows)
  testthat::expect_identical(ledgr_results(reopened, "fills"), fills)
  testthat::expect_identical(ledgr_results(reopened, "equity"), equity)

  options(ledgr.test.intent.record = FALSE)
  omitted <- ledgr_run(
    exp,
    params = list(quantity = 1, omit_at = 2L),
    run_id = "intent-dense-omitted"
  )
  on.exit(close(omitted), add = TRUE)
  testthat::expect_identical(nrow(ledgr_results(omitted, "diagnostics")), 0L)
  testthat::expect_identical(ledgr_results(omitted, "fills"), fills)
  testthat::expect_identical(ledgr_results(omitted, "equity"), equity)
  testthat::expect_identical(ledgr_compute_metrics(omitted), metrics)
  state_omitted <- DBI::dbGetQuery(
    con,
    paste(
      "SELECT ts_utc, state_json FROM strategy_state",
      "WHERE run_id = 'intent-dense-omitted' ORDER BY ts_utc"
    )
  )
  testthat::expect_identical(state_omitted, state_with_reason)
  identity <- DBI::dbGetQuery(
    con,
    paste(
      "SELECT run_id, config_hash FROM runs",
      "WHERE run_id IN ('intent-dense-recorded', 'intent-dense-omitted')",
      "ORDER BY run_id"
    )
  )
  testthat::expect_identical(length(unique(identity$config_hash)), 1L)
  derived_id <- paste0(
    "run_",
    substr(digest::digest(paste0(identity$config_hash, ":NULL"), algo = "sha256"), 1L, 16L)
  )
  testthat::expect_identical(length(unique(derived_id)), 1L)
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0491] availability explanations join intent by decision pulse", {
  snapshot <- intent_evidence_availability_snapshot(3L)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(
    snapshot,
    intent_evidence_strategy,
    universe = ledgr_universe_members("U"),
    valuation_policy = ledgr_valuation_stale(1L),
    cost_model = ledgr_cost_zero(),
    opening = ledgr_opening(cash = 1000)
  )
  bt <- ledgr_run(
    exp,
    params = list(quantity = 1, record = TRUE, omit_at = 2L),
    run_id = "intent-availability"
  )
  on.exit(close(bt), add = TRUE)
  rows <- intent_evidence_rows(bt)
  intent_parser_calls <- 0L
  read_nested <- ledgr:::ledgr_json_read_nested
  testthat::local_mocked_bindings(
    ledgr_json_read_nested = function(x) {
      if (any(grepl("intent_reason", x, fixed = TRUE))) {
        intent_parser_calls <<- intent_parser_calls + 1L
      }
      read_nested(x)
    },
    .package = "ledgr"
  )
  explanation <- ledgr_run_explain(bt, "AAA")

  testthat::expect_identical(nrow(rows), 2L)
  testthat::expect_identical(intent_parser_calls, 1L)
  testthat::expect_type(explanation$intent_reason, "character")
  testthat::expect_identical(
    explanation$intent_reason,
    c("minimum_variance_solution", NA_character_, "hold_current_portfolio")
  )
  testthat::expect_identical(
    as.numeric(rows$ts_utc),
    as.numeric(explanation$ts_utc[c(1L, 3L)])
  )
  scalar_explanation <- ledgr_run_explain(bt, "AAA", explanation$ts_utc[[1L]])
  testthat::expect_identical(scalar_explanation$intent_reason, "minimum_variance_solution")
  testthat::expect_identical(intent_parser_calls, 2L)

  close(bt)
  reopened <- ledgr_run_open(snapshot, "intent-availability")
  on.exit(close(reopened), add = TRUE)
  testthat::expect_identical(intent_evidence_rows(reopened), rows)
  testthat::expect_identical(ledgr_run_explain(reopened, "AAA"), explanation)
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0492] malformed intent reasons refuse before economic commit", {
  bad_values <- list(character(2L), NA_character_, "", 1)
  for (value in bad_values) {
    testthat::expect_error(
      ledgr:::ledgr_validate_strategy_intent_reason(value),
      "`intent_reason` must be NULL or one non-empty character scalar.",
      fixed = TRUE,
      class = "ledgr_invalid_strategy_result"
    )
  }
  testthat::expect_null(ledgr:::ledgr_validate_strategy_intent_reason(NULL))
  testthat::expect_identical(
    ledgr:::ledgr_validate_strategy_intent_reason("rebalance_due"),
    "rebalance_due"
  )

  snapshot <- ledgr_snapshot_from_df(intent_evidence_bars(2L))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(
    snapshot,
    function(ctx, params) {
      list(targets = stats::setNames(1, ctx$universe), intent_reason = params$reason)
    },
    cost_model = ledgr_cost_zero()
  )
  testthat::expect_error(
    ledgr_run(exp, params = list(reason = ""), run_id = "intent-invalid"),
    class = "ledgr_invalid_strategy_result"
  )
  con <- ledgr:::get_connection(snapshot)
  testthat::expect_identical(
    DBI::dbGetQuery(
      con,
      paste(
        "SELECT COUNT(*) AS n FROM ledger_events",
        "WHERE run_id = 'intent-invalid'"
      )
    )$n[[1L]],
    0
  )
  testthat::expect_identical(
    DBI::dbGetQuery(
      con,
      paste(
        "SELECT COUNT(*) AS n FROM run_diagnostics",
        "WHERE run_id = 'intent-invalid' AND reason_code = 'strategy_intent'"
      )
    )$n[[1L]],
    0
  )
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0493] resume and committed walk-forward runs retain each invoked reason once", {
  snapshot <- ledgr_snapshot_from_df(intent_evidence_bars(8L))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  prior_interrupt <- getOption("ledgr.interrupt")
  on.exit(options(ledgr.interrupt = prior_interrupt), add = TRUE)
  interrupting <- function(ctx, params) {
    n <- if (is.null(ctx$state_prev$n)) 1L else ctx$state_prev$n + 1L
    if (n == 2L && isTRUE(params$interrupt)) options(ledgr.interrupt = TRUE)
    list(
      targets = ctx$hold(),
      state_update = list(n = n),
      intent_reason = paste0("pulse_", n)
    )
  }
  exp <- ledgr_experiment(snapshot, interrupting, cost_model = ledgr_cost_zero())
  options(ledgr.interrupt = FALSE)
  first <- ledgr_run(
    exp,
    params = list(interrupt = TRUE),
    run_id = "intent-resume"
  )
  first_rows <- intent_evidence_rows(first)
  close(first)
  testthat::expect_identical(nrow(first_rows), 2L)

  options(ledgr.interrupt = FALSE)
  resumed <- ledgr_run(
    exp,
    params = list(interrupt = TRUE),
    run_id = "intent-resume"
  )
  on.exit(close(resumed), add = TRUE)
  resumed_rows <- intent_evidence_rows(resumed)
  testthat::expect_identical(nrow(resumed_rows), 8L)
  testthat::expect_identical(
    unname(vapply(resumed_rows$detail_json, function(x) {
      ledgr:::ledgr_json_read_nested(x)$intent_reason
    }, character(1L))),
    paste0("pulse_", seq_len(8L))
  )
  testthat::expect_identical(anyDuplicated(resumed_rows$ts_utc), 0L)

  wf_exp <- ledgr_experiment(
    snapshot,
    function(ctx, params) {
      list(
        targets = ctx$flat(),
        intent_reason = paste0("candidate_", params$label)
      )
    },
    cost_model = ledgr_cost_zero()
  )
  folds <- ledgr:::ledgr_fold_list(
    list(ledgr_fold("2020-01-01", "2020-01-04", "2020-01-05", "2020-01-07")),
    constructor = list(type_id = "explicit")
  )
  wf <- ledgr_walk_forward(
    wf_exp,
    grid = ledgr_strategy_grid(label = "only"),
    folds = folds,
    selection_rule = ledgr_rule_argmax("annualized_return"),
    seed = 1L
  )
  on.exit(invisible(lapply(wf$test_runs, close)), add = TRUE)
  testthat::expect_identical(length(wf$test_runs), 1L)
  test_rows <- intent_evidence_rows(wf$test_runs[[1L]])
  testthat::expect_identical(nrow(test_rows), 3L)
  testthat::expect_true(all(vapply(test_rows$detail_json, function(x) {
    identical(ledgr:::ledgr_json_read_nested(x)$intent_reason, "candidate_only")
  }, logical(1L))))
})
