ledgr_sweep_persistence_parity_bars <- function() {
  dates <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:7
  rbind(
    data.frame(
      instrument_id = "AAA",
      ts_utc = dates,
      open = c(100, 101, 103, 102, 104, 107, 106, 108),
      high = c(101, 103, 104, 103, 106, 108, 108, 109),
      low = c(99, 100, 101, 101, 103, 106, 105, 107),
      close = c(100, 102, 103, 102, 105, 107, 106, 108),
      volume = 1000,
      stringsAsFactors = FALSE
    ),
    data.frame(
      instrument_id = "BBB",
      ts_utc = dates,
      open = c(50, 51, 50, 49, 48, 50, 52, 51),
      high = c(51, 52, 51, 50, 49, 51, 53, 52),
      low = c(49, 50, 49, 48, 47, 49, 51, 50),
      close = c(50, 51, 50, 49, 48, 50, 52, 51),
      volume = 2000,
      stringsAsFactors = FALSE
    )
  )
}

ledgr_sweep_persistence_parity_exp <- function(snapshot) {
  strategy <- function(ctx, params) {
    targets <- ctx$hold()
    day <- substr(ctx$ts_utc, 1L, 10L)
    if (identical(day, "2020-01-01")) {
      targets["AAA"] <- params$aaa_qty
      targets["BBB"] <- params$bbb_qty
    } else if (identical(day, "2020-01-03")) {
      targets["AAA"] <- params$aaa_partial_qty
      targets["BBB"] <- params$bbb_qty
    } else if (identical(day, "2020-01-05") && isTRUE(params$close_day5)) {
      targets["AAA"] <- 0
      targets["BBB"] <- 0
    }
    targets
  }
  ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    opening = ledgr_opening(cash = 10000),
    universe = c("AAA", "BBB"),
    cost_model = ledgr_cost_chain(ledgr_cost_spread_bps(5), ledgr_cost_fixed_fee(1))
  )
}

ledgr_sweep_persistence_parity_grid <- function() {
  ledgr_param_grid(
    flat = list(aaa_qty = 0, aaa_partial_qty = 0, bbb_qty = 0, close_day5 = TRUE),
    partial = list(aaa_qty = 4, aaa_partial_qty = 2, bbb_qty = 2, close_day5 = TRUE),
    open_end = list(aaa_qty = 1, aaa_partial_qty = 1, bbb_qty = 0, close_day5 = FALSE)
  )
}

ledgr_sweep_persistence_parity_fixture <- function(compiled_accounting_model = NULL) {
  db_path <- tempfile(fileext = ".duckdb")
  bars <- ledgr_sweep_persistence_parity_bars()
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  exp <- ledgr_sweep_persistence_parity_exp(snapshot)
  sweep <- ledgr_sweep(
    exp,
    ledgr_sweep_persistence_parity_grid(),
    seed = 2591L,
    retain = ledgr_sweep_retention("completed"),
    compiled_accounting_model = compiled_accounting_model
  )
  list(db_path = db_path, bars = bars, snapshot = snapshot, exp = exp, sweep = sweep)
}

ledgr_sweep_persistence_with_compiled <- function(expr) {
  tryCatch(
    eval.parent(substitute(expr)),
    error = function(e) {
      if (inherits(e, "ledgr_compiled_spot_fifo_unavailable")) {
        testthat::skip(conditionMessage(e))
      }
      stop(e)
    }
  )
}

ledgr_sweep_persistence_close_matrix <- function(bars, universe) {
  pulses <- sort(unique(as.POSIXct(bars$ts_utc, tz = "UTC")))
  out <- matrix(
    NA_real_,
    nrow = length(universe),
    ncol = length(pulses),
    dimnames = list(universe, vapply(pulses, ledgr:::ledgr_normalize_ts_utc, character(1)))
  )
  for (j in seq_along(universe)) {
    rows <- bars[as.character(bars$instrument_id) == universe[[j]], , drop = FALSE]
    rows <- rows[order(as.POSIXct(rows$ts_utc, tz = "UTC")), , drop = FALSE]
    out[j, ] <- as.numeric(rows$close)
  }
  out
}

ledgr_sweep_persistence_expected_returns <- function(equity, sweep_id, candidate_id) {
  equity_values <- as.numeric(equity$equity)
  tibble::tibble(
    sweep_id = rep(as.character(sweep_id), length(equity_values)),
    candidate_id = rep(as.character(candidate_id), length(equity_values)),
    ts_utc = as.POSIXct(equity$ts_utc, tz = "UTC"),
    equity = equity_values,
    period_return = c(NA_real_, ledgr:::compute_period_returns(equity_values))
  )
}

ledgr_sweep_persistence_expect_summary_parity <- function(sweep) {
  returns <- ledgr_sweep_returns(sweep)
  testthat::expect_identical(unique(as.character(returns$candidate_id)), as.character(sweep$candidate_id))
  for (candidate_id in as.character(sweep$candidate_id)) {
    retained <- ledgr_sweep_returns(sweep, candidates = candidate_id)
    row <- sweep[as.character(sweep$candidate_id) == candidate_id, , drop = FALSE]
    testthat::expect_equal(
      retained$equity[[nrow(retained)]],
      row$final_equity[[1]],
      tolerance = 1e-12,
      info = candidate_id
    )
    testthat::expect_true(is.na(retained$period_return[[1]]), info = candidate_id)
    testthat::expect_equal(
      retained$period_return[-1],
      ledgr:::compute_period_returns(retained$equity),
      tolerance = 1e-12,
      info = candidate_id
    )
  }
}

ledgr_sweep_persistence_expect_ordered_event_parity <- function(fixture, candidate_id, run_prefix) {
  sweep <- fixture$sweep
  exp <- fixture$exp
  candidate <- ledgr_candidate(sweep, candidate_id)
  run_id <- paste(run_prefix, candidate_id, sep = "-")
  # This helper compares retained series against ordered-event reconstruction;
  # final-bar warnings are asserted directly in the edge-case test below.
  bt <- suppressWarnings(ledgr_run(
    exp,
    params = candidate$params,
    feature_params = candidate$feature_params,
    run_id = run_id,
    seed = candidate$execution_seed
  ))
  on.exit(close(bt), add = TRUE)

  retained <- ledgr_sweep_returns(sweep, candidates = candidate_id)
  persistent_equity <- ledgr_results(bt, "equity")
  testthat::expect_equal(
    retained,
    ledgr_sweep_persistence_expected_returns(persistent_equity, attr(sweep, "sweep_id"), candidate_id),
    tolerance = 1e-12
  )

  pulses <- sort(unique(as.POSIXct(fixture$bars$ts_utc, tz = "UTC")))
  reconstructed <- ledgr:::ledgr_equity_from_events(
    events = ledgr_results(bt, "ledger"),
    pulses_posix = pulses,
    close_mat = ledgr_sweep_persistence_close_matrix(fixture$bars, exp$universe),
    initial_cash = exp$opening$cash,
    instrument_ids = exp$universe,
    run_id = run_id
  )
  testthat::expect_equal(
    retained,
    ledgr_sweep_persistence_expected_returns(reconstructed, attr(sweep, "sweep_id"), candidate_id),
    tolerance = 1e-12
  )
}

testthat::test_that("retained series match inline-memory summary on R accounting", {
  fixture <- ledgr_sweep_persistence_parity_fixture()
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  on.exit(unlink(fixture$db_path), add = TRUE)

  ledgr_sweep_persistence_expect_summary_parity(fixture$sweep)
})

testthat::test_that("retained series match inline-memory summary on compiled spot FIFO", {
  fixture <- ledgr_sweep_persistence_with_compiled(
    ledgr_sweep_persistence_parity_fixture(compiled_accounting_model = "spot_fifo")
  )
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  on.exit(unlink(fixture$db_path), add = TRUE)

  ledgr_sweep_persistence_expect_summary_parity(fixture$sweep)
  testthat::expect_identical(
    attr(fixture$sweep, "execution_assumptions")$compiled_accounting_model,
    "spot_fifo"
  )
})

testthat::test_that("retained series match ordered-event reconstruction on R accounting", {
  fixture <- ledgr_sweep_persistence_parity_fixture()
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  on.exit(unlink(fixture$db_path), add = TRUE)

  for (candidate_id in as.character(fixture$sweep$candidate_id)) {
    ledgr_sweep_persistence_expect_ordered_event_parity(fixture, candidate_id, "r-reconstructed")
  }
})

testthat::test_that("retained series match ordered-event reconstruction on compiled spot FIFO", {
  fixture <- ledgr_sweep_persistence_with_compiled(
    ledgr_sweep_persistence_parity_fixture(compiled_accounting_model = "spot_fifo")
  )
  on.exit(ledgr_snapshot_close(fixture$snapshot), add = TRUE)
  on.exit(unlink(fixture$db_path), add = TRUE)

  # Durable compiled ledgr_run() is not available in v0.1.9.2. This compares
  # compiled sweep retained series with the canonical R ordered-event
  # reconstruction for the same candidate reproduction key.
  for (candidate_id in as.character(fixture$sweep$candidate_id)) {
    ledgr_sweep_persistence_expect_ordered_event_parity(fixture, candidate_id, "compiled-reconstructed")
  }
})

testthat::test_that("retained-series parity matrix covers final-bar and failed-candidate edges", {
  snapshot <- ledgr_snapshot_from_df(
    ledgr_sweep_persistence_parity_bars(),
    db_path = tempfile(fileext = ".duckdb")
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    if (isTRUE(params$fail)) {
      stop("candidate failed")
    }
    targets <- ctx$flat()
    if (identical(substr(ctx$ts_utc, 1L, 10L), "2020-01-08")) {
      targets["AAA"] <- params$qty
    }
    targets
  }
  exp <- ledgr_experiment(snapshot, strategy, universe = c("AAA", "BBB"), cost_model = ledgr_cost_zero())
  grid <- ledgr_param_grid(
    final_bar = list(qty = 1, fail = FALSE),
    failed = list(qty = 1, fail = TRUE)
  )
  sweep <- ledgr_sweep(exp, grid, seed = 2591L, retain = ledgr_sweep_retention("completed"))

  testthat::expect_identical(as.character(sweep$status), c("DONE", "FAILED"))
  retained <- ledgr_sweep_returns(sweep)
  testthat::expect_identical(unique(as.character(retained$candidate_id)), "final_bar")
  testthat::expect_identical(nrow(retained), length(unique(as.POSIXct(ledgr_sweep_persistence_parity_bars()$ts_utc, tz = "UTC"))))
  testthat::expect_equal(retained$equity[[nrow(retained)]], sweep$final_equity[[1]], tolerance = 1e-12)
  testthat::expect_true(any(vapply(
    sweep$warnings[[1]],
    function(w) grepl("LEDGR_LAST_BAR_NO_FILL", conditionMessage(w), fixed = TRUE),
    logical(1)
  )))
  testthat::expect_error(
    ledgr_sweep_returns(sweep, candidates = "failed"),
    class = "ledgr_sweep_returns_candidate_not_completed"
  )
})
