ws42_integration_reader <- function(ctx) {
  list(
    close = ledgr_history_frame(ctx, bar = "close", instruments = "decision_axis"),
    fast = ledgr_history_frame(ctx, feature = "fast", lookback = 2L, na_action = "drop_instruments"),
    bbb_fast = ledgr_history_frame(ctx, feature = "fast", lookback = 2L, instruments = "BBB"),
    planes = ctx$vec[c("id", "member", "admissible", "target_restriction_reason", "close", "position")],
    cash = ctx$cash,
    equity = ctx$equity
  )
}

ws42_sweep_core <- function(x) {
  frame <- as.data.frame(x)
  frame[, c("candidate_id", "status", "stop_reason", "final_equity", "total_return", "n_trades")]
}

# ledgr-test-profile: review
testthat::test_that("[LTB-0300] run, sweep, window, precompute and inspection read one causal history", {
  seen <- new.env()
  opening <- ledgr_opening(cash = 1000, positions = c(AAA = 2), cost_basis = c(AAA = 10))
  fixture <- ws42_history_fixture(
    strategy = ws42_spy(seen, ws42_integration_reader),
    opening = opening,
    dividend = c(6L, 6L)
  )
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  exp <- fixture$exp
  axis <- fixture$axis
  at <- function(tag, session) seen[[paste(tag, ws42_iso(axis[[session]]))]]

  close(ledgr_run(exp, params = list(tag = "run"), run_id = "run"))
  ledgr_sweep(exp, ledgr_param_grid(list(tag = "sweep")))
  pre_grid <- ledgr_param_grid(list(tag = "precompute"))
  ledgr_sweep(exp, pre_grid, precomputed_features = ledgr_precompute_features(exp, pre_grid))
  window <- ledgr:::ledgr_experiment_window(exp, axis[[1L]], axis[[8L]])
  close(ledgr:::ledgr_run_window(exp, params = list(tag = "run_window"), window = window, run_id = "run_window"))
  ledgr:::ledgr_sweep_window(exp, ledgr_param_grid(list(tag = "sweep_window")), window)

  # Literal session-6 history: CCC's close is carried from session 5 because
  # its inactivity is not known until session 7; AAA's dividend posts at
  # session 6 on the two opening shares.
  run6 <- at("run", 6L)
  testthat::expect_identical(run6$close$AAA, c(11, 12, 13, 14, 15, 16))
  testthat::expect_identical(run6$close$BBB, c(21, 22, 22, 22, 25, 26))
  testthat::expect_identical(run6$close$CCC, c(31, 32, 33, 34, 35, 35))
  testthat::expect_identical(
    unname(attr(run6$close, "ledgr_history")$evidence$input_carried[, "CCC"]),
    c(FALSE, FALSE, FALSE, FALSE, FALSE, TRUE)
  )
  testthat::expect_identical(as.numeric(run6$close$ts_utc), as.numeric(axis[1:6]))
  testthat::expect_identical(names(run6$fast), c("ts_utc", "AAA"))
  testthat::expect_identical(run6$fast$AAA, c(14.5, 15.5))
  selection <- attr(run6$fast, "ledgr_history")$selection
  testthat::expect_identical(
    selection$exclusion_reason[match(c("BBB", "CCC"), selection$instrument_id)],
    c("missing_required_input", "missing_required_input")
  )
  # BBB's session-6 average needs only sessions 5-6, so nothing before the
  # two-session window was used.
  testthat::expect_identical(run6$bbb_fast$BBB, c(NA, 25.5))
  testthat::expect_false(attr(run6$bbb_fast, "ledgr_history")$used_before_window)
  testthat::expect_identical(run6$cash, 1001)
  testthat::expect_identical(run6$equity, 1033)
  run7 <- at("run", 7L)
  testthat::expect_identical(run7$close$CCC[6:7], c(NA_real_, NA_real_))
  testthat::expect_identical(run7$planes$admissible, c(TRUE, TRUE, FALSE))

  # Every entry point reads the same history, masks, treatment and exclusions.
  for (tag in c("sweep", "precompute", "run_window", "sweep_window")) {
    for (session in seq_along(axis)) {
      testthat::expect_identical(at(tag, session), at("run", session), info = paste(tag, session))
    }
  }

  # Experiment-derived inspection reproduces the first pulse of a run that
  # starts at the cutoff, including the dividend P1 posts at that pulse.
  inspected <- ledgr_pulse_snapshot(exp, ts_utc = axis[[6L]], params = list(tag = "inspect"))
  testthat::expect_s3_class(inspected, "ledgr_pulse_context")
  testthat::expect_identical(inspected$ts_utc, ws42_iso(axis[[6L]]))
  dated <- ledgr_experiment(
    fixture$snapshot, ws42_spy(seen, ws42_integration_reader),
    universe = ledgr_universe_members("u"),
    features = ledgr_feature_map(fast = ledgr_ind_sma(2)),
    valuation_policy = ledgr_valuation_stale(3), cost_model = ledgr_cost_zero(),
    opening = ledgr_opening(
      cash = 1000, date = fixture$days[[6L]], positions = c(AAA = 2), cost_basis = c(AAA = 10)
    )
  )
  close(ledgr_run(dated, params = list(tag = "dated"), run_id = "dated"))
  first <- at("dated", 6L)
  testthat::expect_identical(ws42_integration_reader(inspected), first)
  testthat::expect_identical(
    ws42_integration_reader(ledgr_pulse_snapshot(dated, ts_utc = as.Date(fixture$days[[6L]]))),
    first
  )
  testthat::expect_identical(first$cash, 1001)
  testthat::expect_identical(first$close, run6$close)

  # Changing the experiment's policy changes the inspected history without a
  # pulse-only policy or start argument.
  strict <- ledgr_experiment(
    fixture$snapshot, function(ctx, params) ctx$hold(),
    universe = ledgr_universe_members("u"),
    features = ledgr_feature_map(fast = ledgr_ind_sma(2)),
    valuation_policy = ledgr_valuation_stale(3), cost_model = ledgr_cost_zero(),
    opening = opening, history_policy = ledgr_history_policy(price_carry = NULL)
  )
  strict_close <- ledgr_history_frame(
    ledgr_pulse_snapshot(strict, ts_utc = axis[[6L]]), bar = "close", instruments = "decision_axis"
  )
  testthat::expect_identical(strict_close$BBB, c(21, 22, NA, NA, 25, 26))
  testthat::expect_identical(strict_close$CCC[[6L]], NA_real_)
  testthat::expect_identical(
    attr(strict_close, "ledgr_history")$policy_identity$price_carry,
    NULL
  )
  testthat::expect_false(any(
    c("history_policy", "policy", "data_start", "start", "experiment") %in%
      names(formals(ledgr_pulse_snapshot))
  ))
  testthat::expect_error(
    ledgr_pulse_snapshot(exp, ts_utc = axis[[6L]], universe = "AAA"),
    class = "ledgr_invalid_args"
  )
  testthat::expect_error(
    ledgr_pulse_snapshot(exp, ts_utc = axis[[6L]], cash = 5),
    class = "ledgr_invalid_args"
  )
  testthat::expect_error(
    ledgr_pulse_snapshot(exp, ts_utc = axis[[6L]] + 1),
    class = "ledgr_history_outside_axis"
  )
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0301] explicit precompute is reused only on its exact causal identity", {
  calls <- new.env()
  calls$n <- 0L
  counting <- function(ctx, params) {
    calls$n <- calls$n + 1L
    ctx$hold()
  }
  fixture <- ws42_history_fixture(strategy = counting)
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  exp <- fixture$exp
  axis <- fixture$axis
  grid <- ledgr_param_grid(list(tag = "a"), list(tag = "b"))

  # Backward and reordered requests are pure: a later cutoff, an earlier one
  # and the later one again give identical payloads, and the earlier payload
  # is the causal prefix of the later one.
  full <- ledgr_precompute_features(exp, grid)
  early <- ledgr_precompute_features(exp, grid, end = axis[[6L]])
  again <- ledgr_precompute_features(exp, grid)
  testthat::expect_identical(again$projection, full$projection)
  testthat::expect_identical(again$payload, full$payload)
  testthat::expect_identical(full$history_axis$cutoff_utc, ws42_iso(axis[[8L]]))
  testthat::expect_identical(early$history_axis$cutoff_utc, ws42_iso(axis[[6L]]))
  testthat::expect_identical(
    unname(early$projection$feature_values$sma_2),
    unname(full$projection$feature_values$sma_2[, 1:6])
  )
  testthat::expect_identical(
    unname(full$projection$feature_values$sma_2["AAA", ]),
    c(NA, 11.5, 12.5, 13.5, 14.5, 15.5, 16.5, 17.5)
  )

  # Exact reuse is deterministic.
  reused <- ledgr_sweep(exp, grid, precomputed_features = full)
  fresh <- ledgr_sweep(exp, grid)
  testthat::expect_identical(ws42_sweep_core(reused), ws42_sweep_core(fresh))

  # Stale payloads refuse before any candidate runs.
  refuses <- function(expr, class) {
    before <- calls$n
    testthat::expect_error(expr, class = class)
    testthat::expect_identical(calls$n, before)
  }
  refuses(ledgr_sweep(exp, grid, precomputed_features = early), "ledgr_precomputed_range_mismatch")
  forged <- full
  forged$history_axis$axis_hash <- "different"
  refuses(ledgr_sweep(exp, grid, precomputed_features = forged), "ledgr_precomputed_history_mismatch")
  carry2 <- ledgr_experiment(
    fixture$snapshot, counting, universe = ledgr_universe_members("u"),
    features = ledgr_feature_map(fast = ledgr_ind_sma(2)),
    valuation_policy = ledgr_valuation_stale(3), cost_model = ledgr_cost_zero(),
    opening = ledgr_opening(cash = 1000), history_policy = ledgr_history_policy(price_carry = 2L)
  )
  refuses(ledgr_sweep(carry2, grid, precomputed_features = full), "ledgr_precomputed_history_mismatch")
  sma3 <- ledgr_experiment(
    fixture$snapshot, counting, universe = ledgr_universe_members("u"),
    features = ledgr_feature_map(fast = ledgr_ind_sma(3)),
    valuation_policy = ledgr_valuation_stale(3), cost_model = ledgr_cost_zero(),
    opening = ledgr_opening(cash = 1000)
  )
  refuses(ledgr_sweep(sma3, grid, precomputed_features = full), "ledgr_precomputed_feature_mismatch")
  window <- ledgr:::ledgr_experiment_window(exp, axis[[1L]], axis[[6L]])
  refuses(
    ledgr:::ledgr_sweep_window(exp, grid, window, precomputed_features = full),
    "ledgr_precomputed_range_mismatch"
  )
  testthat::expect_identical(
    ws42_sweep_core(ledgr:::ledgr_sweep_window(exp, grid, window, precomputed_features = early)),
    ws42_sweep_core(ledgr:::ledgr_sweep_window(exp, grid, window))
  )
  # A different knowledge state (CCC's inactivity known one session later) is
  # a different snapshot and refuses; so does a dense experiment.
  shifted <- ws42_history_fixture(strategy = counting, ccc_known = 8L)
  on.exit(ledgr_snapshot_close(shifted$snapshot), add = TRUE)
  refuses(
    ledgr_sweep(shifted$exp, grid, precomputed_features = full),
    "ledgr_precomputed_snapshot_mismatch"
  )
  dense_snapshot <- ws42_dense_snapshot()
  on.exit(ledgr_snapshot_close(dense_snapshot), add = TRUE)
  dense <- ledgr_experiment(
    dense_snapshot, counting, cost_model = ledgr_cost_zero(),
    features = ledgr_feature_map(fast = ledgr_ind_sma(2)),
    opening = ledgr_opening(cash = 1000)
  )
  refuses(ledgr_sweep(dense, grid, precomputed_features = full), "ledgr_precomputed_feature_mismatch")
  refuses(
    ledgr_sweep(exp, grid, precomputed_features = ledgr_precompute_features(dense, grid)),
    "ledgr_precomputed_feature_mismatch"
  )

  # Returned results are fresh values: mutating them changes no later read,
  # pulse or candidate.
  seen <- new.env()
  mutating <- function(ctx, params) {
    first <- ledgr_history_frame(ctx, bar = "close", instruments = "decision_axis")
    m <- ledgr_history_matrix(first)
    seen[[paste(params$tag, ctx$ts_utc)]] <- first
    first$AAA[] <- -1
    m[] <- -1
    attr(first, "ledgr_history")$evidence$input_carried[] <- TRUE
    again <- ledgr_history_frame(ctx, bar = "close", instruments = "decision_axis")
    if (!identical(again, seen[[paste(params$tag, ctx$ts_utc)]])) stop("history read changed")
    ctx$hold()
  }
  mutation_exp <- ledgr_experiment(
    fixture$snapshot, mutating, universe = ledgr_universe_members("u"),
    features = ledgr_feature_map(fast = ledgr_ind_sma(2)),
    valuation_policy = ledgr_valuation_stale(3), cost_model = ledgr_cost_zero(),
    opening = ledgr_opening(cash = 1000)
  )
  result <- ledgr_sweep(mutation_exp, grid, precomputed_features = full, stop_on_error = TRUE)
  testthat::expect_identical(as.data.frame(result)$status, c("DONE", "DONE"))
  for (session in seq_along(axis)) {
    testthat::expect_identical(
      seen[[paste("a", ws42_iso(axis[[session]]))]],
      seen[[paste("b", ws42_iso(axis[[session]]))]]
    )
  }
  testthat::expect_identical(seen[[paste("b", ws42_iso(axis[[8L]]))]]$AAA, 11:18 + 0)
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0302] pulse inspection is external, P1/P2-only and gated to availability", {
  fixture <- ws42_history_fixture(
    opening = ledgr_opening(cash = 1000, positions = c(AAA = 2), cost_basis = c(AAA = 10)),
    dividend = c(6L, 6L)
  )
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  con <- ledgr:::get_connection(fixture$snapshot)
  run_tables <- c("runs", "ledger_events", "equity_curve", "strategy_state", "run_diagnostics", "run_completion")
  rows <- function() {
    vapply(run_tables, function(table) {
      DBI::dbGetQuery(con, sprintf("SELECT COUNT(*) AS n FROM %s", table))$n
    }, numeric(1))
  }
  before <- rows()
  # P3 to P5 never run: replacing them with failures leaves inspection intact.
  testthat::local_mocked_bindings(
    ledgr_fold_stage_plan = function(...) stop("P3 ran during inspection"),
    ledgr_fold_stage_apply = function(...) stop("P4 ran during inspection"),
    ledgr_fold_stage_commit = function(...) stop("P5 ran during inspection"),
    .package = "ledgr"
  )
  ctx <- ledgr_pulse_snapshot(fixture$exp, ts_utc = fixture$axis[[6L]])
  testthat::expect_identical(ctx$cash, 1001)
  testthat::expect_identical(rows(), before)
  testthat::expect_false(any(c("exp", "experiment", "history_policy", "snapshot") %in% names(ctx)))
  testthat::expect_s3_class(ctx$.history, "ledgr_history_view")
  testthat::expect_identical(
    names(formals(ledgr_history_frame)),
    c("ctx", "feature", "bar", "lookback", "instruments", "na_action", "layout")
  )

  # A strategy context is never built from an experiment by the strategy:
  # no package source calls the inspection outside ledgr_pulse_snapshot(),
  # and no documented strategy body calls ledgr_pulse_snapshot().
  repository <- ledgr_test_source_root()
  sources <- list.files(file.path(repository, "R"), pattern = "[.]R$", full.names = TRUE)
  callers <- sources[vapply(sources, function(path) {
    any(grepl("ledgr_pulse_inspection(", readLines(path, warn = FALSE), fixed = TRUE))
  }, logical(1))]
  testthat::expect_identical(basename(callers), "pulse-snapshot.R")
  docs <- c(
    list.files(file.path(repository, "vignettes"), pattern = "[.](Rmd|qmd)$", full.names = TRUE),
    list.files(file.path(repository, "man"), pattern = "[.]Rd$", full.names = TRUE)
  )
  strategy_bodies <- function(text) {
    starts <- gregexpr("function\\s*\\(\\s*ctx", text, perl = TRUE)[[1L]]
    if (starts[[1L]] == -1L) return(character())
    vapply(starts, function(start) {
      open <- regexpr("\\{", substring(text, start))
      if (open == -1L) return("")
      chars <- strsplit(substring(text, start + open - 1L), "")[[1L]]
      depth <- cumsum((chars == "{") - (chars == "}"))
      paste(chars[seq_len(which(depth == 0L)[[1L]])], collapse = "")
    }, character(1))
  }
  offending <- docs[vapply(docs, function(path) {
    bodies <- strategy_bodies(paste(readLines(path, warn = FALSE), collapse = "\n"))
    any(grepl("ledgr_pulse_snapshot(", bodies, fixed = TRUE))
  }, logical(1))]
  testthat::expect_identical(offending, character())

  # Gating: a dense experiment has no experiment-derived inspection, its
  # snapshot-and-universe form is unchanged, and malformed calls refuse.
  dense_snapshot <- ws42_dense_snapshot()
  on.exit(ledgr_snapshot_close(dense_snapshot), add = TRUE)
  dense <- ledgr_experiment(
    dense_snapshot, function(ctx, params) ctx$hold(), cost_model = ledgr_cost_zero(),
    opening = ledgr_opening(cash = 1000)
  )
  testthat::expect_error(
    ledgr_pulse_snapshot(dense, ts_utc = as.POSIXct("2021-01-06 21:00:00", tz = "UTC")),
    class = "ledgr_pulse_snapshot_availability_required"
  )
  pulse <- ledgr_pulse_snapshot(
    dense_snapshot, universe = c("AAA", "BBB"), ts_utc = "2021-01-06T21:00:00Z"
  )
  on.exit(close(pulse), add = TRUE)
  testthat::expect_identical(pulse$close("BBB"), 23)
  testthat::expect_null(pulse$.history)
  testthat::expect_error(ledgr_history_frame(pulse, bar = "close"), class = "ledgr_history_unavailable")
  testthat::expect_error(ledgr_pulse_snapshot("not a snapshot"), class = "ledgr_invalid_args")
  testthat::expect_error(
    ledgr_pulse_snapshot(dense_snapshot, universe = "AAA", ts_utc = "2021-01-06T21:00:00Z", params = list()),
    class = "ledgr_invalid_args"
  )
})
