# Cut 11 real-data continuity II (LDG-2978 to LDG-2980, LDG-2991).

continuity_ii_utc <- function(x) as.POSIXct(paste(x, "21:00:00"), tz = "UTC")

continuity_ii_bars <- function(id, days, close) {
  data.frame(instrument_id = id, ts_utc = continuity_ii_utc(days), open = close, high = close,
             low = close, close = close, volume = 100)
}

# An availability-aware snapshot over `days` (open sessions) inside `calendar`
# (every calendar day, weekends closed), with one complete membership set and
# an optional terminal lifetime fact.
continuity_ii_snapshot <- function(bars, ids, days, calendar = days, lifetime = NULL) {
  open <- calendar %in% days
  membership <- data.frame(effective_from = continuity_ii_utc(calendar[[1]] - 1),
                           knowledge_time = continuity_ii_utc(calendar[[1]] - 1), source = "d")
  membership$members <- I(list(ids))
  families <- list(
    ledgr_facts_sessions(
      data.frame(session_date = calendar, status = ifelse(open, "open", "closed"),
                 session_open = ifelse(open, "14:30:00", NA), session_close = ifelse(open, "21:00:00", NA)),
      venue_id = "V", timezone = "UTC", knowledge = "assume_effective"),
    ledgr_facts_membership_snapshots(membership, universe_id = "u", complete = TRUE, knowledge = "assume_effective")
  )
  if (!is.null(lifetime)) families <- c(families, list(lifetime))
  ledgr_snapshot_from_df(bars, data.frame(instrument_id = ids), db_path = tempfile(fileext = ".duckdb"),
                         facts = do.call(ledgr_facts, families), price_basis = "split_adjusted")
}

continuity_ii_equal_weight <- function(ctx, params) {
  ctx |> ledgr_selection() |> ledgr_weight_equal() |> ledgr_target_rebalance(ctx, equity_fraction = 0.9)
}

continuity_ii_experiment <- function(snapshot, strategy, stale = 2L) {
  ledgr_experiment(snapshot, strategy, universe = ledgr_universe_members("u"),
                   valuation_policy = ledgr_valuation_stale(stale), cost_model = ledgr_cost_zero(),
                   opening = ledgr_opening(cash = 1000))
}

# Weekdays of the first half of 2020 (first session Wednesday 2020-01-01).
continuity_ii_calendar <- seq(as.Date("2020-01-01"), as.Date("2020-06-30"), by = "day")
continuity_ii_weekdays <- continuity_ii_calendar[as.integer(format(continuity_ii_calendar, "%u")) <= 5L]

continuity_ii_wf_snapshot <- function(ids, lifetime = NULL, drop_after = NULL) {
  set.seed(11)
  days <- continuity_ii_weekdays
  bars <- do.call(rbind, lapply(ids, function(id) {
    continuity_ii_bars(id, days, round(10 * exp(cumsum(stats::rnorm(length(days), 0, 0.01))), 4))
  }))
  if (!is.null(drop_after)) {
    bars <- bars[!(bars$instrument_id == drop_after$id & bars$ts_utc >= continuity_ii_utc(drop_after$day)), , drop = FALSE]
  }
  continuity_ii_snapshot(bars, ids, days, continuity_ii_calendar, lifetime)
}

# ledgr-test-profile: review
testthat::test_that("[LTB-0203] reconstruction rebuilds gap-bearing availability runs exactly", {
  days <- as.Date(c("2020-01-06", "2020-01-07", "2020-01-08", "2020-01-09", "2020-01-10"))
  cases <- list(
    # BBB has no bar on day 1 (unheld skip) and day 4 (held skip, stale mark 21).
    list(bars = rbind(continuity_ii_bars("AAA", days, 10), continuity_ii_bars("BBB", days[-c(1, 4)], c(20, 21, 23))),
         stale = 2L, positions_value = c(0, 450, 912, 912, 956), positions = c(AAA = 45, BBB = 22)),
    # BBB's last bar is day 2 at 22; with stale(1) the 22 held shares are frozen at 22 from day 4.
    list(bars = rbind(continuity_ii_bars("AAA", days, c(10, 11, 12, 13, 14)), continuity_ii_bars("BBB", days[1:2], c(20, 22))),
         stale = 1L, positions_value = c(0, 979, 964, 991, 1058), positions = c(AAA = 41, BBB = 22))
  )
  for (case in cases) {
    snapshot <- continuity_ii_snapshot(case$bars, c("AAA", "BBB"), days)
    bt <- ledgr_run(continuity_ii_experiment(snapshot, continuity_ii_equal_weight, case$stale), run_id = "gap-run")
    con <- ledgr:::get_connection(snapshot)
    stored <- DBI::dbGetQuery(con, "SELECT * FROM equity_curve WHERE run_id = 'gap-run' ORDER BY ts_utc")
    testthat::expect_identical(stored$positions_value, case$positions_value)

    rebuilt <- ledgr_state_reconstruct("gap-run", con)
    for (column in c("cash", "positions_value", "equity", "realized_pnl", "unrealized_pnl")) {
      testthat::expect_identical(rebuilt$equity_curve[[column]], stored[[column]], info = column)
    }
    testthat::expect_identical(stats::setNames(rebuilt$positions$qty, rebuilt$positions$instrument_id), case$positions)
    close(bt)
    ledgr_snapshot_close(snapshot)
  }

  # A run that stopped early is rebuilt only through its last fully valued
  # pulse: with stale(0) and the default refusal, the held BBB has no mark on
  # day 4, so the run is INCOMPLETE after three valued pulses.
  snapshot <- continuity_ii_snapshot(cases[[1]]$bars, c("AAA", "BBB"), days)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_experiment(snapshot, continuity_ii_equal_weight, universe = ledgr_universe_members("u"),
                          valuation_policy = ledgr_valuation_stale(0, exhausted = "refuse"),
                          cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1000))
  bt <- ledgr_run(exp, run_id = "stopped-run")
  on.exit(close(bt), add = TRUE)
  testthat::expect_identical(ledgr_run_info(snapshot, "stopped-run")$status, "INCOMPLETE")
  con <- ledgr:::get_connection(snapshot)
  stored <- DBI::dbGetQuery(con, "SELECT * FROM equity_curve WHERE run_id = 'stopped-run' ORDER BY ts_utc")
  rebuilt <- ledgr_state_reconstruct("stopped-run", con)
  testthat::expect_identical(nrow(rebuilt$equity_curve), 3L)
  testthat::expect_identical(rebuilt$equity_curve$equity, stored$equity)
})

testthat::test_that("[LTB-0204] the carry-window checker distinguishes gaps, overlaps and contiguous windows", {
  at <- function(x) as.POSIXct(x, tz = "UTC")
  window <- function(start, end) list(test = list(
    scoring_start_utc = at(start), scoring_end_utc = at(end)
  ))
  pulses <- at(c(
    "2020-02-01 16:00:00", "2020-02-02 16:00:00",
    "2020-02-03 16:00:00", "2020-02-04 16:00:00",
    "2020-02-05 16:00:00"
  ))
  testthat::local_mocked_bindings(
    ledgr_walk_forward_pulse_calendar = function(...) pulses,
    .package = "ledgr"
  )
  exp <- list()

  gap <- list(
    window("2020-02-01 16:00:00", "2020-02-02 16:00:00"),
    window("2020-02-04 16:00:00", "2020-02-05 16:00:00")
  )
  error <- testthat::expect_error(
    ledgr:::ledgr_walk_forward_refuse_noncontiguous_carry(exp, gap),
    class = "ledgr_walk_forward_gapped_carry"
  )
  testthat::expect_s3_class(error, "ledgr_walk_forward_invalid_fold_window")
  testthat::expect_match(conditionMessage(error), "between test window 1", fixed = TRUE)

  overlap <- list(
    window("2020-02-01 16:00:00", "2020-02-04 16:00:00"),
    window("2020-02-03 16:00:00", "2020-02-05 16:00:00")
  )
  testthat::expect_error(
    ledgr:::ledgr_walk_forward_refuse_noncontiguous_carry(exp, overlap),
    class = "ledgr_walk_forward_overlapping_carry"
  )
  reverse <- rev(overlap)
  testthat::expect_error(
    ledgr:::ledgr_walk_forward_refuse_noncontiguous_carry(exp, reverse),
    class = "ledgr_walk_forward_overlapping_carry"
  )
  touching <- list(
    window("2020-02-01 16:00:00", "2020-02-03 16:00:00"),
    window("2020-02-03 16:00:00", "2020-02-05 16:00:00")
  )
  testthat::expect_error(
    ledgr:::ledgr_walk_forward_refuse_noncontiguous_carry(exp, touching),
    class = "ledgr_walk_forward_overlapping_carry"
  )
  contiguous <- list(
    window("2020-02-01 16:00:00", "2020-02-02 16:00:00"),
    window("2020-02-03 16:00:00", "2020-02-05 16:00:00")
  )
  testthat::expect_true(
    ledgr:::ledgr_walk_forward_refuse_noncontiguous_carry(exp, contiguous)
  )
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0481] public carry_test_state refuses invalid windows before work", {
  snapshot <- continuity_ii_wf_snapshot(c("AAA", "BBB"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- continuity_ii_experiment(snapshot, function(ctx, params) ctx$flat())
  grid <- ledgr_strategy_grid(f = 0.5)
  # One-month test windows stepped every two months: March is unobserved.
  gapped <- ledgr_folds_rolling("2020-01-02", "2020-06-30", train_window = "1 month",
                                test_window = "1 month", step = "2 months")
  err <- testthat::expect_error(
    ledgr_walk_forward(exp, grid, gapped, ledgr_rule_argmax("sharpe_ratio"), seed = 1L),
    class = "ledgr_walk_forward_gapped_carry"
  )
  testthat::expect_s3_class(err, "ledgr_walk_forward_invalid_fold_window")
  testthat::expect_match(conditionMessage(err), "between test window 1 (ends 2020-03-01T23:59:59Z) and test window 2",
                         fixed = TRUE)
  testthat::expect_match(conditionMessage(err), "`step` equal to `test_window`", fixed = TRUE)
  testthat::expect_match(conditionMessage(err), "flat_test_state", fixed = TRUE)
  # Nothing reached the store.
  tables <- DBI::dbListTables(ledgr:::get_connection(snapshot))
  if ("walk_forward_sessions" %in% tables) {
    testthat::expect_identical(
      DBI::dbGetQuery(ledgr:::get_connection(snapshot), "SELECT COUNT(*) AS n FROM walk_forward_sessions")$n, 0
    )
  }

  # Overlapping test windows (two months stepped monthly) and a reverse-ordered
  # list refuse with their own class: each would open from later state.
  overlapping <- ledgr_folds_rolling("2020-01-02", "2020-06-30", train_window = "1 month",
                                     test_window = "2 months", step = "1 month")
  err <- testthat::expect_error(
    ledgr_walk_forward(exp, grid, overlapping, ledgr_rule_argmax("sharpe_ratio"), seed = 1L),
    class = "ledgr_walk_forward_overlapping_carry"
  )
  testthat::expect_s3_class(err, "ledgr_walk_forward_invalid_fold_window")
  testthat::expect_false(inherits(err, "ledgr_walk_forward_gapped_carry"))
  testthat::expect_match(conditionMessage(err), "test window 2 (starts 2020-03-02T00:00:00Z) overlaps test window 1",
                         fixed = TRUE)
  reverse <- ledgr:::ledgr_fold_list(
    list(
      ledgr_fold("2020-03-02", "2020-03-31", "2020-04-01", "2020-04-30", fold_seq = 1L),
      ledgr_fold("2020-01-02", "2020-01-31", "2020-02-01", "2020-02-29", fold_seq = 2L)
    ),
    constructor = list(type_id = "explicit")
  )
  err <- testthat::expect_error(ledgr:::ledgr_walk_forward_refuse_noncontiguous_carry(exp, reverse),
                                class = "ledgr_walk_forward_overlapping_carry")
  testthat::expect_match(conditionMessage(err), "test window 2 (starts 2020-02-01T00:00:00Z) starts before test window 1",
                         fixed = TRUE)
  # A window that starts exactly where the previous one ends shares that
  # instant, so it is not after it and refuses as an overlap.
  touching <- ledgr:::ledgr_fold_list(
    list(
      ledgr_fold("2020-01-02", "2020-01-31", "2020-02-01", "2020-03-01T00:00:00Z", fold_seq = 1L),
      ledgr_fold("2020-01-02", "2020-02-29", "2020-03-01T00:00:00Z", "2020-03-31", fold_seq = 2L)
    ),
    constructor = list(type_id = "explicit")
  )
  err <- testthat::expect_error(ledgr:::ledgr_walk_forward_refuse_noncontiguous_carry(exp, touching),
                                class = "ledgr_walk_forward_overlapping_carry")
  testthat::expect_s3_class(err, "ledgr_walk_forward_invalid_fold_window")
  testthat::expect_match(
    conditionMessage(err),
    "test window 2 (starts 2020-03-01T00:00:00Z) overlaps test window 1 (2020-02-01T00:00:00Z to 2020-03-01T00:00:00Z)",
    fixed = TRUE
  )

  # Contiguous folds, and a single fold, pass the check.
  contiguous <- ledgr_folds_rolling("2020-01-02", "2020-06-30", train_window = "1 month",
                                    test_window = "1 month", step = "1 month")
  testthat::expect_true(ledgr:::ledgr_walk_forward_refuse_noncontiguous_carry(exp, contiguous))
  testthat::expect_true(ledgr:::ledgr_walk_forward_refuse_noncontiguous_carry(exp, gapped[1]))

  # A dense experiment pulses on its bar timestamps and refuses the same way.
  dense <- ledgr_snapshot_from_df(
    do.call(rbind, lapply(c("AAA", "BBB"), function(id) continuity_ii_bars(id, continuity_ii_weekdays, 10))),
    db_path = tempfile(fileext = ".duckdb")
  )
  on.exit(ledgr_snapshot_close(dense), add = TRUE)
  dense_exp <- ledgr_experiment(dense, function(ctx, params) ctx$flat(), cost_model = ledgr_cost_zero(),
                                opening = ledgr_opening(cash = 1000))
  dense_err <- testthat::expect_error(
    ledgr_walk_forward(
      dense_exp, grid, gapped, ledgr_rule_argmax("sharpe_ratio"), seed = 1L
    ),
    class = "ledgr_walk_forward_gapped_carry"
  )
  testthat::expect_s3_class(
    dense_err, "ledgr_walk_forward_invalid_fold_window"
  )
  dense_tables <- DBI::dbListTables(ledgr:::get_connection(dense))
  if ("walk_forward_sessions" %in% dense_tables) {
    testthat::expect_identical(
      DBI::dbGetQuery(
        ledgr:::get_connection(dense),
        "SELECT COUNT(*) AS n FROM walk_forward_sessions"
      )$n,
      0
    )
  }
  testthat::expect_true(ledgr:::ledgr_walk_forward_refuse_noncontiguous_carry(dense_exp, contiguous))
})

testthat::test_that("[LTB-0206] a boundary on the first or last sealed date resolves to that session", {
  snapshot <- continuity_ii_wf_snapshot(c("AAA", "BBB"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- continuity_ii_experiment(snapshot, function(ctx, params) ctx$flat())
  # Midnight of the first date starts at the first session; a time after the
  # last close on the last date ends at the last session.
  last_late <- as.POSIXct("2020-06-30 23:59:59", tz = "UTC")
  window <- ledgr:::ledgr_experiment_window(exp, "2020-01-01", last_late)
  testthat::expect_identical(ledgr:::ledgr_walk_forward_iso(window$scoring_start_utc), "2020-01-01T21:00:00Z")
  # LDG-3064: a window carries no second history start.
  testthat::expect_false("hydration_start_utc" %in% names(window))
  testthat::expect_identical(ledgr:::ledgr_walk_forward_iso(window$execution_start_utc), "2020-01-01T21:00:00Z")
  testthat::expect_identical(ledgr:::ledgr_walk_forward_iso(window$scoring_end_utc), "2020-06-30T21:00:00Z")
  # Boundaries already inside the sealed range are kept as given.
  inside <- ledgr:::ledgr_experiment_window(exp, "2020-01-02", "2020-06-30")
  testthat::expect_identical(ledgr:::ledgr_walk_forward_iso(inside$scoring_start_utc), "2020-01-02T00:00:00Z")
  testthat::expect_identical(ledgr:::ledgr_walk_forward_iso(inside$scoring_end_utc), "2020-06-30T00:00:00Z")

  before <- testthat::expect_error(ledgr:::ledgr_experiment_window(exp, "2019-12-31", "2020-03-01"),
                                   class = "ledgr_walk_forward_invalid_fold_window")
  testthat::expect_match(conditionMessage(before), "2019-12-31 to 2020-03-01 must lie inside the sealed snapshot range 2020-01-01 to 2020-06-30",
                         fixed = TRUE)
  after <- testthat::expect_error(ledgr:::ledgr_experiment_window(exp, "2020-05-01", "2020-07-01"),
                                  class = "ledgr_walk_forward_invalid_fold_window")
  testthat::expect_match(conditionMessage(after), "sealed snapshot range 2020-01-01 to 2020-06-30", fixed = TRUE)

  # Feature precompute applies the same rule.
  meta <- ledgr:::ledgr_precompute_snapshot_meta(snapshot)
  range <- ledgr:::ledgr_precompute_scoring_range(meta, start = "2020-01-01", end = last_late)
  testthat::expect_identical(range$scoring_start, meta$start)
  testthat::expect_identical(range$scoring_end, meta$end)
  testthat::expect_error(ledgr:::ledgr_precompute_scoring_range(meta, start = "2019-12-31"),
                         class = "ledgr_invalid_precompute_range")
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0207] an empty unfinished row resumes with its opening positions", {
  days <- as.Date(c("2020-01-06", "2020-01-07", "2020-01-08", "2020-01-09"))
  hold <- function(ctx, params) ctx$hold()
  # One definition, so the rerun matches the first attempt's configuration;
  # the option makes the first attempt fail.
  gate <- ledgr_indicator(id = "gate", requires_bars = 1L, fn = function(window) {
    if (isTRUE(getOption("ledgr.test.fail_early"))) stop("first attempt failed")
    window$close[[nrow(window)]]
  })
  statuses <- c("CREATED", "RUNNING", "FAILED")
  for (k in seq_along(statuses)) {
    status <- statuses[[k]]
    # A distinct BBB price per case keeps each gate case independent.
    bars <- rbind(continuity_ii_bars("AAA", days, c(10, 11, 12, 13)), continuity_ii_bars("BBB", days, 20 + k))
    snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
    exp <- ledgr_experiment(snapshot, hold, features = list(gate), cost_model = ledgr_cost_zero(),
                            opening = ledgr_opening(cash = 1000, positions = c(AAA = 5), cost_basis = c(AAA = 50)))
    con <- ledgr:::get_connection(snapshot)
    old <- options(ledgr.test.fail_early = TRUE)
    testthat::expect_error(ledgr_run(exp, run_id = "empty-row"), "first attempt failed")
    options(old)
    # Leave the registered row exactly as a process that stopped before the
    # opening append would: no ledger events, in the case's status.
    DBI::dbExecute(con, "DELETE FROM ledger_events WHERE run_id = 'empty-row'")
    DBI::dbExecute(con, "UPDATE runs SET status = ? WHERE run_id = 'empty-row'", params = list(status))

    bt <- ledgr_run(exp, run_id = "empty-row")
    events <- ledgr_results(bt, "ledger")
    testthat::expect_identical(sum(events$event_type == "CASHFLOW"), 1L, info = status)
    equity <- ledgr_results(bt, "equity")
    testthat::expect_identical(equity$positions_value, 5 * c(10, 11, 12, 13), info = status)
    testthat::expect_identical(ledgr_run_info(snapshot, "empty-row")$status, "DONE", info = status)
    close(bt)
    ledgr_snapshot_close(snapshot)
  }
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0208] flat_test_state still runs gapped, overlapping and reverse-ordered folds", {
  bars <- do.call(rbind, lapply(c("AAA", "BBB"), function(id) {
    continuity_ii_bars(id, continuity_ii_weekdays, 10 + seq_along(continuity_ii_weekdays) / 100)
  }))
  snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  buy <- function(ctx, params) {
    target <- ctx$flat()
    target[["AAA"]] <- params$qty
    target
  }
  exp <- ledgr_experiment(snapshot, buy, cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1000))
  grid <- ledgr_strategy_grid(qty = 1)
  layouts <- list(
    gapped = ledgr_folds_rolling("2020-01-02", "2020-06-30", train_window = "1 month",
                                 test_window = "1 month", step = "2 months"),
    overlapping = ledgr_folds_rolling("2020-01-02", "2020-06-30", train_window = "1 month",
                                      test_window = "2 months", step = "1 month"),
    reverse = ledgr:::ledgr_fold_list(
      list(
        ledgr_fold("2020-03-02", "2020-03-31", "2020-04-01", "2020-04-30", fold_seq = 1L),
        ledgr_fold("2020-01-02", "2020-01-31", "2020-02-01", "2020-02-29", fold_seq = 2L)
      ),
      constructor = list(type_id = "explicit")
    )
  )
  for (name in names(layouts)) {
    wf <- suppressWarnings(ledgr_walk_forward(exp, grid, layouts[[name]], ledgr_rule_argmax("sharpe_ratio"),
                                              seed = 1L, opening_state_policy = "flat_test_state"))
    testthat::expect_identical(wf$status, "DONE", info = name)
    testthat::expect_true(all(wf$folds$status == "DONE"), info = name)
    lapply(wf$test_runs, close)
  }
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0205] an interrupted walk-forward resumes its test run on rerun", {
  interrupt_march <- function(ctx, params) {
    if (identical(getOption("ledgr.test.wf_interrupt"), substr(ctx$ts_utc, 1, 10))) rlang::interrupt()
    ctx |> ledgr_selection() |> ledgr_weight_equal() |> ledgr_target_rebalance(ctx, equity_fraction = params$f)
  }
  grid <- ledgr_strategy_grid(f = c(0.5, 0.9))
  folds <- ledgr_folds_rolling("2020-01-02", "2020-06-30", train_window = "1 month",
                               test_window = "1 month", step = "1 month")
  run_wf <- function(snapshot) {
    ledgr_walk_forward(continuity_ii_experiment(snapshot, interrupt_march), grid, folds,
                       ledgr_rule_argmax("sharpe_ratio"), seed = 1L)
  }
  digest <- function(snapshot, wf) {
    stored <- ledgr_walk_forward_folds(snapshot, wf$session_id)
    equity <- vapply(stored$test_run_id, function(id) {
      run <- ledgr_run_open(snapshot, id)
      on.exit(close(run), add = TRUE)
      paste(format(ledgr_results(run, "equity")$equity, digits = 15), collapse = "/")
    }, character(1))
    paste(stored$fold_seq, stored$status, stored$selection_source, stored$selected_candidate_key, equity)
  }

  reference_snapshot <- continuity_ii_wf_snapshot(c("AAA", "BBB"))
  on.exit(ledgr_snapshot_close(reference_snapshot), add = TRUE)
  reference <- run_wf(reference_snapshot)
  testthat::expect_identical(reference$status, "DONE")
  reference_digest <- digest(reference_snapshot, reference)
  testthat::expect_gt(length(unique(unlist(strsplit(reference_digest, "/", fixed = TRUE)))), 2L)

  # A finished session reruns by opening its DONE test runs, not executing them.
  con <- ledgr:::get_connection(reference_snapshot)
  stamps <- function() DBI::dbGetQuery(con, "SELECT run_id, updated_at_utc FROM run_telemetry ORDER BY run_id")
  before <- stamps()
  testthat::expect_identical(digest(reference_snapshot, run_wf(reference_snapshot)), reference_digest)
  testthat::expect_identical(stamps(), before)

  # Interrupt fold 2's test run (March), then rerun with the same arguments.
  snapshot <- continuity_ii_wf_snapshot(c("AAA", "BBB"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  old <- options(ledgr.test.wf_interrupt = "2020-03-10")
  got <- tryCatch(run_wf(snapshot), interrupt = function(e) "interrupted")
  options(old)
  testthat::expect_identical(got, "interrupted")
  failed <- DBI::dbGetQuery(ledgr:::get_connection(snapshot), "SELECT run_id FROM runs WHERE status = 'FAILED'")
  testthat::expect_identical(nrow(failed), 1L)

  # A FAILED test run whose configuration no longer matches still refuses.
  window <- ledgr:::ledgr_experiment_window(continuity_ii_experiment(snapshot, interrupt_march), "2020-03-02", "2020-04-01")
  testthat::expect_error(
    ledgr:::ledgr_walk_forward_run_or_open(continuity_ii_experiment(snapshot, interrupt_march), params = list(f = 0.123),
                                           feature_params = list(), window = window,
                                           run_id = failed$run_id[[1]], seed = 1L),
    class = "ledgr_run_hash_mismatch"
  )

  resumed <- run_wf(snapshot)
  testthat::expect_identical(resumed$status, "DONE")
  testthat::expect_identical(digest(snapshot, resumed), reference_digest)
})
