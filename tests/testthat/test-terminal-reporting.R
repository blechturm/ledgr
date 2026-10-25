# ledgr-test-profile: fast
testthat::test_that("[LTB-0172] terminal outcomes reconcile to events and name their assumption", {
  lifetime <- ledgr_facts_lifetime(data.frame(
    instrument_id = c("AAA", "BBB"),
    effective_from = terminal_outcome_day(4L),
    knowledge_time = terminal_outcome_day(4L) - 1,
    assertion = "known_inactive",
    terminal_event = c("bankruptcy", "merger"),
    stringsAsFactors = FALSE
  ))
  snapshot <- terminal_outcome_snapshot(
    list(AAA = c(100, NA, NA, NA, NA), BBB = rep(50, 5L)),
    lifetime = lifetime
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  policy <- ledgr_corporate_actions(
    held_terminal_position = c(merger = "last_mark", default = "last_permissible")
  )
  bt <- ledgr_run(
    terminal_outcome_experiment(snapshot, policy = policy, positions = c(AAA = 2, BBB = 4)),
    run_id = "terminal-reporting"
  )
  on.exit(close(bt), add = TRUE)

  summary <- ledgr_corporate_action_summary(bt)
  outcomes <- summary$terminal_outcomes
  testthat::expect_identical(summary$corporate_action_fidelity, "modeled")
  testthat::expect_identical(outcomes$instrument_id, c("AAA", "BBB"))
  testthat::expect_identical(outcomes$source, rep("lifetime_terminal", 2L))
  testthat::expect_identical(outcomes$terminal_event, c("bankruptcy", "merger"))
  testthat::expect_identical(outcomes$matched_label, c("default", "merger"))
  testthat::expect_identical(outcomes$choice, c("write_off", "last_mark"))
  testthat::expect_identical(outcomes$assumption, c("default", "declared"))
  testthat::expect_identical(
    outcomes$assumption_label,
    c("default: assumed worthless", "declared: last observed mark")
  )
  testthat::expect_equal(outcomes$proceeds, c(0, 200))
  testthat::expect_equal(outcomes$realized_model_pnl, c(-200, -200))
  testthat::expect_identical(summary$choice_counts[["frozen_terminal_position.write_off"]], 1L)
  testthat::expect_identical(summary$choice_counts[["held_terminal_position.last_mark"]], 1L)
  testthat::expect_identical(summary$positions_disposed, 2L)
  testthat::expect_equal(summary$modeled_terminal_proceeds, 200)

  # The summary reconciles exactly to the persisted DISPOSITION events.
  events <- terminal_outcome_tables(bt)$events
  events <- events[events$event_type == "DISPOSITION", , drop = FALSE]
  testthat::expect_identical(as.character(events$instrument_id), outcomes$instrument_id)
  testthat::expect_equal(as.numeric(events$price), outcomes$price)
  testthat::expect_equal(as.numeric(events$qty), outcomes$quantity)

  # One warning, before any metric, names each assumption and its argument.
  printed <- utils::capture.output(print(bt))
  warning_at <- which(printed == "WARNING: this result relies on declared valuation or terminal assumptions.")
  testthat::expect_length(warning_at, 1L)
  testthat::expect_lt(warning_at, grep("^Final Equity:", printed))
  testthat::expect_true(all(c(
    "  Assumed terminal outcomes: 2.",
    "    AAA 2020-01-04: default: assumed worthless (frozen_terminal_position = \"write_off\", the research default).",
    "    BBB 2020-01-04: declared: last observed mark (held_terminal_position[\"merger\"] = \"last_mark\")."
  ) %in% printed))
  detailed <- utils::capture.output(summary(bt))
  testthat::expect_lt(
    which(detailed == "WARNING: this result relies on declared valuation or terminal assumptions."),
    which(detailed == "Performance Metrics:")
  )
  testthat::expect_true(
    "    AAA 2020-01-04: default: assumed worthless, proceeds 0 (label bankruptcy)" %in% detailed
  )
})

# ledgr-test-profile: fast
testthat::test_that("[LTB-0173] valuation evidence matches a pulse-level oracle", {
  snapshot <- terminal_outcome_snapshot(list(
    AAA = c(100, NA, NA, NA, 90, 91, 92),
    BBB = c(50, 51, NA, NA, NA, NA, NA),
    CLK = rep(10, 7L)
  ))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  bt <- ledgr_run(
    terminal_outcome_experiment(snapshot, positions = c(AAA = 2, BBB = 4)),
    run_id = "valuation-oracle"
  )
  on.exit(close(bt), add = TRUE)

  # Independent oracle from the fixture with max_sessions = 1:
  # AAA is stale on day 2, frozen on days 3-4 and current from day 5;
  # BBB is stale on day 3 and frozen on days 4-7 at its day-2 close of 51.
  equity <- c(1400, 1404, 1404, 1404, 1384, 1386, 1388)
  frozen_gross <- c(0, 0, 200, 404, 204, 204, 204)
  observed <- ledgr_valuation_summary(bt)
  testthat::expect_equal(terminal_outcome_tables(bt)$equity$equity, equity)
  testthat::expect_identical(observed$valuation_state, "frozen")
  testthat::expect_identical(observed$stale_instrument_sessions, 2L)
  testthat::expect_identical(observed$stale_instruments, 2L)
  testthat::expect_identical(observed$longest_stale_age, 1L)
  testthat::expect_identical(observed$frozen_instrument_sessions, 6L)
  testthat::expect_identical(observed$frozen_instruments, 2L)
  testthat::expect_identical(observed$longest_freeze_sessions, 4L)
  testthat::expect_equal(observed$max_frozen_gross_value, max(frozen_gross))
  testthat::expect_equal(observed$max_frozen_equity_weight, max(frozen_gross / equity))
  testthat::expect_identical(observed$frozen_at_end_count, 1L)
  testthat::expect_equal(observed$frozen_at_end_value, 204)
  testthat::expect_equal(observed$frozen_at_end_weight, 204 / 1388)
  testthat::expect_equal(observed$total_return, 1388 / 1400 - 1)
  testthat::expect_equal(observed$total_return_if_frozen_worthless, (1388 - 204) / 1400 - 1)
  # The bound never alters the stored equity or the standard metrics.
  testthat::expect_equal(ledgr_compute_metrics(bt)$total_return, 1388 / 1400 - 1)

  # print() places these exact lines; LTB-0172 covers their position.
  testthat::expect_identical(
    ledgr:::ledgr_valuation_headline(observed),
    "Valuation: FROZEN - 2 holdings frozen (longest 4 sessions, max 404 or 28.77% of equity); 1 still frozen at end worth 204"
  )
  testthat::expect_identical(
    ledgr:::ledgr_result_assumption_warning(observed, ledgr_corporate_action_summary(bt)),
    c(
      "WARNING: this result relies on declared valuation or terminal assumptions.",
      "  Frozen valuation: 2 holdings carried at the last close beyond max_sessions = 1 for 6 instrument-sessions (exhausted = \"freeze\", the default).",
      "  Still frozen at end: 1 holding worth 204 (14.70% of final equity); total return if worthless: -15.43%."
    )
  )
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0174] warnings have no materiality threshold and stay off clean runs", {
  warning_line <- "WARNING: this result relies on declared valuation or terminal assumptions."
  run_lines <- function(experiment, run_id) {
    bt <- ledgr_run(experiment, run_id = run_id)
    on.exit(close(bt), add = TRUE)
    list(print = utils::capture.output(print(bt)), valuation = ledgr_valuation_summary(bt))
  }

  # A tiny frozen holding still warns.
  tiny <- terminal_outcome_snapshot(list(AAA = c(100, NA, NA, NA), CLK = rep(10, 4L)))
  on.exit(ledgr_snapshot_close(tiny), add = TRUE)
  tiny_run <- run_lines(
    ledgr_experiment(
      tiny,
      function(ctx, params) ctx$hold(),
      opening = ledgr_opening(cash = 1e7, positions = c(AAA = 1), cost_basis = c(AAA = 100)),
      valuation_policy = ledgr_valuation_stale(1),
      cost_model = ledgr_cost_zero()
    ),
    "tiny-freeze"
  )
  testthat::expect_lt(tiny_run$valuation$max_frozen_equity_weight, 1e-4)
  testthat::expect_true(warning_line %in% tiny_run$print)

  # Refusing exhaustion stops without frozen exposure and without the warning.
  refused <- run_lines(
    terminal_outcome_experiment(tiny, valuation = ledgr_valuation_stale(1, exhausted = "refuse")),
    "refused-exhaustion"
  )
  testthat::expect_identical(refused$valuation$frozen_instrument_sessions, 0L)
  testthat::expect_identical(refused$valuation$valuation_state, "stale")
  testthat::expect_false(warning_line %in% refused$print)

  # A clean availability run reports current valuation and no warning.
  clean <- terminal_outcome_snapshot(list(AAA = c(100, 101, 102)))
  on.exit(ledgr_snapshot_close(clean), add = TRUE)
  clean_run <- run_lines(terminal_outcome_experiment(clean), "clean-availability")
  testthat::expect_true("Valuation: CURRENT - every held mark was a current close" %in% clean_run$print)
  testthat::expect_false(warning_line %in% clean_run$print)

  # Settlement evidence is not an assumption and does not warn.
  evidence <- terminal_outcome_snapshot(
    list(AAA = c(100, 90, 91)),
    corporate = terminal_outcome_acquisition("AAA", 2L)
  )
  on.exit(ledgr_snapshot_close(evidence), add = TRUE)
  evidence_run <- run_lines(terminal_outcome_experiment(evidence), "evidence-only")
  testthat::expect_false(warning_line %in% evidence_run$print)

  # A dense run has no valuation policy, headline or warning.
  bars <- data.frame(
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:2,
    instrument_id = "AAA", open = 100:102, high = 101:103, low = 99:101,
    close = 100:102, volume = 1000
  )
  dense <- ledgr_backtest(
    data = bars,
    strategy = function(ctx, params) {
      target <- ctx$flat()
      target["AAA"] <- 1
      target
    },
    initial_cash = 1000,
    cost_model = ledgr_cost_zero()
  )
  on.exit(close(dense), add = TRUE)
  dense_print <- utils::capture.output(print(dense))
  testthat::expect_identical(ledgr_valuation_summary(dense)$valuation_state, "not_applicable")
  testthat::expect_false(any(grepl("^Valuation", dense_print)))
  testthat::expect_false(warning_line %in% dense_print)
  testthat::expect_false(any(grepl("^Valuation Evidence", utils::capture.output(summary(dense)))))
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0438] stopped valuation headlines replace ordinary mark headlines", {
  lines_of <- function(run, method) {
    gsub("[ \t]+$", "", utils::capture.output(method(run)))
  }
  assert_stopped <- function(run, reason, day, instrument = "AAA") {
    expected <- paste(
      sprintf(
        "Valuation: STOPPED - 1 holding without a permissible mark at %sT16:00:00Z (%s);",
        day,
        instrument
      ),
      sprintf("the run is INCOMPLETE (%s)", reason)
    )
    for (output in list(lines_of(run, print), lines_of(run, summary))) {
      testthat::expect_true(expected %in% output)
      testthat::expect_false(any(grepl("Valuation: (CURRENT|STALE|FROZEN)", output)))
    }
    valuation <- ledgr_valuation_summary(run)
    testthat::expect_identical(valuation$valuation_stop_reason, reason)
    testthat::expect_identical(valuation$valuation_stop_instruments, instrument)
  }

  never <- terminal_outcome_snapshot(list(
    AAA = rep(NA_real_, 3L),
    CLK = rep(10, 3L)
  ))
  on.exit(ledgr_snapshot_close(never), add = TRUE)
  unpriced <- ledgr_run(terminal_outcome_experiment(never), run_id = "headline-unpriced")
  on.exit(close(unpriced), add = TRUE, after = FALSE)
  assert_stopped(unpriced, "valuation_horizon_exhausted", "2020-01-01")

  stale <- terminal_outcome_snapshot(list(
    AAA = c(100, NA, NA, NA),
    CLK = rep(10, 4L)
  ))
  on.exit(ledgr_snapshot_close(stale), add = TRUE)
  refused <- ledgr_run(
    terminal_outcome_experiment(
      stale,
      valuation = ledgr_valuation_stale(1L, exhausted = "refuse")
    ),
    run_id = "headline-refused"
  )
  on.exit(close(refused), add = TRUE, after = FALSE)
  testthat::expect_identical(ledgr_valuation_summary(refused)$valuation_state, "stale")
  assert_stopped(refused, "valuation_horizon_exhausted", "2020-01-03")

  no_mark <- terminal_outcome_snapshot(
    list(AAA = c(100, NA, 103)),
    lifetime = terminal_outcome_lifetime("AAA", 2L, "bankruptcy")
  )
  on.exit(ledgr_snapshot_close(no_mark), add = TRUE)
  terminal <- ledgr_run(
    terminal_outcome_experiment(
      no_mark,
      valuation = ledgr_valuation_stale(0L, exhausted = "refuse")
    ),
    run_id = "headline-terminal"
  )
  on.exit(close(terminal), add = TRUE, after = FALSE)
  assert_stopped(terminal, "terminal_mark_unavailable", "2020-01-02")

  clean_snapshot <- terminal_outcome_snapshot(list(AAA = c(100, 101, 102)))
  on.exit(ledgr_snapshot_close(clean_snapshot), add = TRUE)
  clean <- ledgr_run(terminal_outcome_experiment(clean_snapshot), run_id = "headline-clean")
  on.exit(close(clean), add = TRUE, after = FALSE)
  clean_lines <- lines_of(clean, print)
  testthat::expect_true(
    "Valuation: CURRENT - every held mark was a current close" %in% clean_lines
  )
  testthat::expect_false(any(grepl("STOPPED", clean_lines)))
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0175] reporting is identical from memory, reopen and resume", {
  snapshot <- terminal_outcome_snapshot(
    list(
      AAA = c(100, NA, NA, NA, 90, 91),
      BBB = c(50, NA, NA, NA, NA, NA),
      CLK = rep(10, 6L)
    ),
    lifetime = terminal_outcome_lifetime("BBB", 5L, "bankruptcy")
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  prior <- getOption("ledgr.interrupt")
  on.exit(options(ledgr.interrupt = prior), add = TRUE)
  strategy <- function(ctx, params) {
    if (isTRUE(params$interrupt) && identical(ctx$ts_utc, "2020-01-03T16:00:00Z")) {
      options(ledgr.interrupt = TRUE)
    }
    ctx$hold()
  }
  exp <- terminal_outcome_experiment(snapshot, strategy = strategy, positions = c(AAA = 2, BBB = 4))
  reports <- function(bt) {
    corporate <- ledgr_corporate_action_summary(bt)
    valuation <- ledgr_valuation_summary(bt)
    outcomes <- corporate$terminal_outcomes
    outcomes$source_fact_id <- NULL
    list(
      valuation = valuation,
      outcomes = outcomes,
      warning = ledgr:::ledgr_result_assumption_warning(valuation, corporate)
    )
  }
  options(ledgr.interrupt = FALSE)
  straight <- ledgr_run(exp, params = list(interrupt = FALSE), run_id = "report-straight")
  memory <- reports(straight)
  close(straight)
  reopened_bt <- ledgr_run_open(snapshot, "report-straight")
  reopened <- reports(reopened_bt)
  close(reopened_bt)

  first <- ledgr_run(exp, params = list(interrupt = TRUE), run_id = "report-resumed")
  close(first)
  options(ledgr.interrupt = FALSE)
  resumed_bt <- ledgr_run(exp, params = list(interrupt = TRUE), run_id = "report-resumed")
  resumed <- reports(resumed_bt)
  close(resumed_bt)

  testthat::expect_identical(memory$valuation$valuation_state, "frozen")
  testthat::expect_identical(memory$outcomes$assumption_label, "default: assumed worthless")
  testthat::expect_true(length(memory$warning) > 0L)
  testthat::expect_identical(reopened, memory)
  testthat::expect_identical(resumed, memory)
})
