ledgr_parity_bars <- function() {
  dates <- as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:7
  rbind(
    data.frame(
      ts_utc = dates,
      instrument_id = "AAA",
      open = c(100, 101, 103, 102, 104, 107, 106, 108),
      high = c(101, 103, 104, 103, 106, 108, 108, 109),
      low = c(99, 100, 101, 101, 103, 106, 105, 107),
      close = c(100, 102, 103, 102, 105, 107, 106, 108),
      volume = 1000,
      stringsAsFactors = FALSE
    ),
    data.frame(
      ts_utc = dates,
      instrument_id = "BBB",
      open = c(50, 51, 50, 49, 48, 50, 52, 51),
      high = c(51, 52, 51, 50, 49, 51, 53, 52),
      low = c(49, 50, 49, 48, 47, 49, 51, 50),
      close = c(50, 51, 50, 49, 48, 50, 52, 51),
      volume = 2000,
      stringsAsFactors = FALSE
    )
  )
}

ledgr_parity_metric_cols <- function() {
  c(
    "total_return", "annualized_return", "volatility", "sharpe_ratio",
    "max_drawdown", "n_trades", "win_rate", "avg_trade", "time_in_market"
  )
}

ledgr_parity_accounting_tolerance <- function() {
  # The current R memory and persistent paths are byte-identical. LDG-2403 uses
  # 1e-10 as forward protection so later typed-event or single-pass changes may
  # introduce harmless floating-point order noise, but not cent-level accounting
  # drift.
  1e-10
}

ledgr_parity_metric_tolerance <- function() {
  # Metrics are downstream of equity/fill tables. Use the same tight tolerance
  # so Sharpe/volatility changes caused by arithmetic order are allowed only at
  # numerical-noise scale.
  1e-10
}

ledgr_parity_normalize_table <- function(x, drop = character()) {
  out <- tibble::as_tibble(x)
  for (col in intersect(c("run_id", "event_id", drop), names(out))) {
    out[[col]] <- NULL
  }
  if ("ts_utc" %in% names(out)) {
    out$ts_utc <- vapply(out$ts_utc, ledgr:::ledgr_normalize_ts_utc, character(1))
  }
  out
}

ledgr_parity_close_matrix <- function(bars, universe) {
  pulses <- sort(unique(as.POSIXct(bars$ts_utc, tz = "UTC")))
  out <- matrix(
    NA_real_,
    nrow = length(universe),
    ncol = length(pulses),
    dimnames = list(universe, vapply(pulses, ledgr:::ledgr_normalize_ts_utc, character(1)))
  )
  for (j in seq_along(universe)) {
    rows <- bars[as.character(bars$instrument_id) == universe[[j]], , drop = FALSE]
    rows <- rows[order(rows$ts_utc), , drop = FALSE]
    out[j, ] <- as.numeric(rows$close)
  }
  out
}

ledgr_parity_final_positions <- function(fills) {
  fills <- tibble::as_tibble(fills)
  instruments <- sort(unique(as.character(fills$instrument_id)))
  stats::setNames(vapply(instruments, function(instrument_id) {
    rows <- fills[as.character(fills$instrument_id) == instrument_id, , drop = FALSE]
    side <- toupper(as.character(rows$side))
    direction <- ifelse(side %in% c("BUY", "COVER", "BUY_TO_COVER"), 1, -1)
    sum(direction * as.numeric(rows$qty), na.rm = TRUE)
  }, numeric(1)), instruments)
}

ledgr_parity_persistent_equity_detail <- function(bt) {
  opened <- ledgr:::ledgr_backtest_read_connection(bt)
  on.exit(opened$close(), add = TRUE)
  DBI::dbGetQuery(
    opened$con,
    "
    SELECT ts_utc, cash, positions_value, equity, realized_pnl, unrealized_pnl
    FROM equity_curve
    WHERE run_id = ?
    ORDER BY ts_utc
    ",
    params = list(bt$run_id)
  )
}

ledgr_expect_sweep_row_matches_run <- function(row, bt) {
  metrics <- ledgr_compute_metrics(bt)
  equity <- ledgr_results(bt, "equity")
  final_equity <- equity$equity[[nrow(equity)]]

  testthat::expect_equal(
    row$final_equity[[1]],
    final_equity,
    tolerance = ledgr_parity_accounting_tolerance()
  )
  for (col in ledgr_parity_metric_cols()) {
    if (identical(col, "n_trades")) {
      testthat::expect_identical(row[[col]][[1]], as.integer(metrics[[col]]))
    } else {
      testthat::expect_equal(
        row[[col]][[1]],
        metrics[[col]],
        tolerance = ledgr_parity_metric_tolerance(),
        info = sprintf("%s actual=%s expected=%s", col, deparse(row[[col]][[1]]), deparse(metrics[[col]]))
      )
    }
  }
}

ledgr_expect_run_artifacts_identical <- function(left, right) {
  testthat::expect_equal(
    ledgr_parity_normalize_table(ledgr_results(left, "ledger")),
    ledgr_parity_normalize_table(ledgr_results(right, "ledger")),
    tolerance = ledgr_parity_accounting_tolerance()
  )
  testthat::expect_equal(
    ledgr_parity_normalize_table(ledgr_results(left, "fills")),
    ledgr_parity_normalize_table(ledgr_results(right, "fills")),
    tolerance = ledgr_parity_accounting_tolerance()
  )
  testthat::expect_equal(
    ledgr_parity_normalize_table(ledgr_results(left, "trades")),
    ledgr_parity_normalize_table(ledgr_results(right, "trades")),
    tolerance = ledgr_parity_accounting_tolerance()
  )
  testthat::expect_equal(
    ledgr_parity_normalize_table(ledgr_parity_persistent_equity_detail(left)),
    ledgr_parity_normalize_table(ledgr_parity_persistent_equity_detail(right)),
    tolerance = ledgr_parity_accounting_tolerance()
  )
  testthat::expect_equal(
    ledgr_parity_final_positions(ledgr_results(left, "fills")),
    ledgr_parity_final_positions(ledgr_results(right, "fills")),
    tolerance = ledgr_parity_accounting_tolerance()
  )
}

ledgr_expect_memory_reconstruction_matches_run <- function(bt, bars, initial_cash, universe) {
  pulses <- sort(unique(as.POSIXct(bars$ts_utc, tz = "UTC")))
  close_mat <- ledgr_parity_close_matrix(bars, universe)
  events <- ledgr_results(bt, "ledger")

  memory_equity <- ledgr:::ledgr_equity_from_events(
    events = events,
    pulses_posix = pulses,
    close_mat = close_mat,
    initial_cash = initial_cash,
    instrument_ids = universe,
    run_id = bt$run_id
  )
  testthat::expect_equal(
    ledgr_parity_normalize_table(memory_equity),
    ledgr_parity_normalize_table(ledgr_parity_persistent_equity_detail(bt)),
    tolerance = ledgr_parity_accounting_tolerance()
  )

  memory_fills <- ledgr:::ledgr_fills_from_events(events)
  persistent_fills <- ledgr_results(bt, "fills")
  testthat::expect_equal(
    ledgr_parity_normalize_table(memory_fills),
    ledgr_parity_normalize_table(persistent_fills),
    tolerance = ledgr_parity_accounting_tolerance()
  )

  kernel <- ledgr:::ledgr_metric_kernel(context = ledgr_metric_context(bt), pulses = pulses)
  memory_metrics <- ledgr:::ledgr_metrics_from_equity_fills(
    equity = memory_equity,
    fills = memory_fills,
    metric_kernel = kernel
  )
  persistent_metrics <- ledgr_compute_metrics(bt)
  for (col in ledgr_parity_metric_cols()) {
    if (identical(col, "n_trades")) {
      testthat::expect_identical(memory_metrics[[col]], as.integer(persistent_metrics[[col]]))
    } else {
      testthat::expect_equal(
        memory_metrics[[col]],
        persistent_metrics[[col]],
        tolerance = ledgr_parity_metric_tolerance(),
        info = sprintf("memory metric %s", col)
      )
    }
  }
}

testthat::test_that("sweep candidates match persistent run and promoted run artifacts", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)
  bars <- ledgr_parity_bars()
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$hold()
    day <- substr(ctx$ts_utc, 1L, 10L)
    if (identical(day, "2020-01-01")) {
      targets["AAA"] <- params$aaa_qty
      targets["BBB"] <- params$bbb_qty
    } else if (identical(day, "2020-01-02")) {
      targets["AAA"] <- params$aaa_partial_qty
      targets["BBB"] <- params$bbb_qty
    } else if (identical(day, "2020-01-03") && isTRUE(params$close_day3)) {
      targets["AAA"] <- 0
      targets["BBB"] <- 0
    } else if (identical(day, "2020-01-08")) {
      targets["AAA"] <- params$last_bar_qty
    }
    targets
  }
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    opening = ledgr_opening(cash = 10000),
    cost_model = ledgr_cost_chain(ledgr_cost_spread_bps(5), ledgr_cost_fixed_fee(1)),
    universe = c("AAA", "BBB")
  )
  grid <- ledgr_param_grid(
    zero = list(aaa_qty = 0, aaa_partial_qty = 0, bbb_qty = 0, close_day3 = TRUE, last_bar_qty = 0),
    partial = list(aaa_qty = 4, aaa_partial_qty = 2, bbb_qty = 2, close_day3 = TRUE, last_bar_qty = 3),
    open_end = list(aaa_qty = 1, aaa_partial_qty = 1, bbb_qty = 0, close_day3 = FALSE, last_bar_qty = 1)
  )

  results <- ledgr_sweep(exp, grid, seed = 2026L)
  testthat::expect_identical(
    names(results),
    c(
      "run_id", "status", "final_equity", "total_return", "annualized_return",
      "volatility", "sharpe_ratio", "max_drawdown", "n_trades", "win_rate",
      "avg_trade", "time_in_market", "execution_seed", "error_class",
      "error_msg", "params", "feature_params", "warnings", "feature_fingerprints",
      "provenance", "t_engine", "t_results", "t_fills_extract"
    )
  )
  testthat::expect_true(all(results$status == "DONE"))

  partial_row <- results[results$run_id == "partial", , drop = FALSE]
  testthat::expect_true(any(vapply(
    partial_row$warnings[[1]],
    function(w) grepl("LEDGR_LAST_BAR_NO_FILL", conditionMessage(w), fixed = TRUE),
    logical(1)
  )))
  testthat::expect_length(results$warnings[[which(results$run_id == "zero")]], 0L)

  for (label in results$run_id) {
    candidate <- ledgr_candidate(results, label)
    promoted <- suppressWarnings(ledgr_promote(exp, candidate, run_id = paste0("parity-", label, "-promoted")))
    direct <- suppressWarnings(ledgr_run(
      exp,
      params = candidate$params,
      run_id = paste0("parity-", label, "-direct"),
      seed = candidate$execution_seed
    ))

    row <- results[results$run_id == label, , drop = FALSE]
    ledgr_expect_sweep_row_matches_run(row, promoted)
    ledgr_expect_run_artifacts_identical(promoted, direct)
    ledgr_expect_memory_reconstruction_matches_run(direct, bars, initial_cash = 10000, universe = c("AAA", "BBB"))

    testthat::expect_identical(ledgr_run_info(snapshot, paste0("parity-", label, "-promoted"))$status, "DONE")
    testthat::expect_identical(ledgr_run_info(snapshot, paste0("parity-", label, "-direct"))$status, "DONE")
    close(promoted)
    close(direct)
  }

  zero_direct <- ledgr_run(exp, params = grid$params[[1]], run_id = "parity-zero-check", seed = 1L)
  on.exit(close(zero_direct), add = TRUE)
  testthat::expect_identical(nrow(ledgr_results(zero_direct, "fills")), 0L)
  testthat::expect_identical(ledgr_compute_metrics(zero_direct)$n_trades, 0L)

  open_end_direct <- ledgr_run(exp, params = grid$params[[3]], run_id = "parity-open-end-check", seed = 1L)
  on.exit(close(open_end_direct), add = TRUE)
  open_end_equity <- ledgr_parity_persistent_equity_detail(open_end_direct)
  testthat::expect_gt(abs(open_end_equity$unrealized_pnl[[nrow(open_end_equity)]]), 0)
  testthat::expect_identical(ledgr_compute_metrics(open_end_direct)$n_trades, 0L)
})

testthat::test_that("sweep parity covers opening-position lots and non-default metric context", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)
  bars <- ledgr_parity_bars()
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$hold()
    day <- substr(ctx$ts_utc, 1L, 10L)
    if (identical(day, "2020-01-01")) {
      targets["AAA"] <- 3
    } else if (identical(day, "2020-01-02")) {
      targets["AAA"] <- 0
    }
    targets
  }
  context <- ledgr_metric_context(
    risk_free_rate = ledgr_risk_free_rate(0.04, label = "parity policy")
  )
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    opening = ledgr_opening(cash = 10000, positions = c(AAA = 5), cost_basis = c(AAA = 99)),
    cost_model = ledgr_cost_zero(),
    universe = c("AAA", "BBB"),
    metric_context = context
  )
  grid <- ledgr_param_grid(opening_partial = list())

  results <- ledgr_sweep(exp, grid, seed = 90210L)
  testthat::expect_s3_class(results, "ledgr_sweep_results")
  testthat::expect_identical(attr(results, "metric_context_hash"), ledgr_metric_context_hash(context))
  testthat::expect_equal(ledgr_metric_context(results)$risk_free_rate$annual_rate, 0.04)
  testthat::expect_identical(results$status[[1]], "DONE")

  candidate <- ledgr_candidate(results, "opening_partial")
  promoted <- suppressWarnings(ledgr_promote(exp, candidate, run_id = "opening-parity-promoted"))
  direct <- suppressWarnings(ledgr_run(
    exp,
    params = candidate$params,
    run_id = "opening-parity-direct",
    seed = candidate$execution_seed
  ))
  on.exit(close(promoted), add = TRUE)
  on.exit(close(direct), add = TRUE)

  ledgr_expect_sweep_row_matches_run(results[1, , drop = FALSE], promoted)
  ledgr_expect_run_artifacts_identical(promoted, direct)
  ledgr_expect_memory_reconstruction_matches_run(direct, bars, initial_cash = 10000, universe = c("AAA", "BBB"))

  direct_equity <- ledgr_parity_persistent_equity_detail(direct)
  # Opening lot: 5 shares at cost 99. Day 1 closes 2 at 101; day 2 closes
  # 3 at 103, so realized = (101 - 99) * 2 + (103 - 99) * 3 = 16.
  testthat::expect_equal(direct_equity$realized_pnl[[nrow(direct_equity)]], 16, tolerance = ledgr_parity_accounting_tolerance())
  testthat::expect_equal(direct_equity$unrealized_pnl[[nrow(direct_equity)]], 0, tolerance = ledgr_parity_accounting_tolerance())
  testthat::expect_false(isTRUE(all.equal(
    results$sharpe_ratio[[1]],
    ledgr_compute_metrics(direct, risk_free_rate = 0)$sharpe_ratio,
    tolerance = 1e-12
  )))
})

testthat::test_that("seeded stochastic sweep promotion reproduces the selected candidate", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)
  snapshot <- ledgr_snapshot_from_df(ledgr_parity_bars(), db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    if (stats::runif(1) > params$threshold) {
      targets["AAA"] <- params$qty
    }
    targets
  }
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    opening = ledgr_opening(cash = 10000),
    universe = "AAA",
    cost_model = ledgr_cost_zero()
  )
  grid <- ledgr_param_grid(candidate = list(qty = 3, threshold = 0.35))

  results <- ledgr_sweep(exp, grid, seed = 123L)
  candidate <- ledgr_candidate(results, "candidate")
  promoted <- suppressWarnings(ledgr_promote(exp, candidate, run_id = "seeded-promoted"))
  direct <- suppressWarnings(ledgr_run(
    exp,
    params = candidate$params,
    run_id = "seeded-direct",
    seed = candidate$execution_seed
  ))
  on.exit(close(promoted), add = TRUE)
  on.exit(close(direct), add = TRUE)

  ledgr_expect_sweep_row_matches_run(results[1, , drop = FALSE], promoted)
  ledgr_expect_run_artifacts_identical(promoted, direct)

  context <- ledgr_promotion_context(promoted)
  testthat::expect_identical(context$selected_candidate$run_id, "candidate")
  testthat::expect_identical(context$selected_candidate$execution_seed, candidate$execution_seed)
  testthat::expect_identical(context$source_sweep$sweep_id, attr(results, "sweep_id"))
  testthat::expect_identical(context$source_sweep$master_seed, 123L)
  testthat::expect_equal(context$candidate_summary[[1]]$final_equity, results$final_equity[[1]], tolerance = 0)
})

testthat::test_that("pulse_seed sweep promotion reproduces the selected candidate", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)
  snapshot <- ledgr_snapshot_from_df(ledgr_parity_bars(), db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    if (!is.null(ctx$pulse_seed) && (ctx$pulse_seed %% params$modulus) == 0L) {
      targets["AAA"] <- params$qty
    }
    targets
  }
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    opening = ledgr_opening(cash = 10000),
    universe = "AAA",
  cost_model = ledgr_cost_zero()
  )
  grid <- ledgr_param_grid(candidate = list(qty = 3, modulus = 3L))

  results <- ledgr_sweep(exp, grid, seed = 123L)
  candidate <- ledgr_candidate(results, "candidate")
  promoted <- suppressWarnings(ledgr_promote(exp, candidate, run_id = "pulse-seed-promoted"))
  direct <- suppressWarnings(ledgr_run(
    exp,
    params = candidate$params,
    run_id = "pulse-seed-direct",
    seed = candidate$execution_seed
  ))
  on.exit(close(promoted), add = TRUE)
  on.exit(close(direct), add = TRUE)

  ledgr_expect_sweep_row_matches_run(results[1, , drop = FALSE], promoted)
  ledgr_expect_run_artifacts_identical(promoted, direct)
})

testthat::test_that("feature-factory sweep parity covers candidate-varying feature sets and warmup", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)
  snapshot <- ledgr_snapshot_from_df(ledgr_parity_bars(), db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  observed <- new.env(parent = emptyenv())
  features <- function(params) {
    list(ledgr_ind_sma(params$n))
  }
  strategy <- function(ctx, params) {
    feature_id <- paste0("sma_", params$n)
    value <- ctx$feature("AAA", feature_id)
    observed[[ctx$run_id]] <- c(observed[[ctx$run_id]] %||% numeric(), value)
    targets <- ctx$flat()
    if (!is.na(value) && ctx$close("AAA") > value) {
      targets["AAA"] <- params$qty
    }
    targets
  }
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    features = features,
    opening = ledgr_opening(cash = 10000),
    universe = "AAA",
    cost_model = ledgr_cost_zero()
  )
  grid <- ledgr_param_grid(short = list(n = 2, qty = 1), longer = list(n = 3, qty = 2))

  results <- ledgr_sweep(exp, grid, seed = 77L)
  feature_hashes <- vapply(results$provenance, `[[`, character(1), "feature_set_hash")
  testthat::expect_false(identical(feature_hashes[[1]], feature_hashes[[2]]))
  testthat::expect_true(all(results$status == "DONE"))

  for (label in results$run_id) {
    candidate <- ledgr_candidate(results, label)
    promoted <- suppressWarnings(ledgr_promote(exp, candidate, run_id = paste0("factory-", label, "-promoted")))
    direct <- suppressWarnings(ledgr_run(
      exp,
      params = candidate$params,
      run_id = paste0("factory-", label, "-direct"),
      seed = candidate$execution_seed
    ))
    on.exit(close(promoted), add = TRUE)
    on.exit(close(direct), add = TRUE)

    ledgr_expect_sweep_row_matches_run(results[results$run_id == label, , drop = FALSE], promoted)
    ledgr_expect_run_artifacts_identical(promoted, direct)
    testthat::expect_equal(
      observed[[label]],
      observed[[paste0("factory-", label, "-direct")]],
      tolerance = 0
    )
  }

  testthat::expect_true(is.na(observed$longer[[1]]))
  testthat::expect_true(is.na(observed$longer[[2]]))
  testthat::expect_true(is.finite(observed$longer[[3]]))
})

testthat::test_that("scalar execution config hash remains pinned across sweep parity work", {
  cfg <- list(
    db_path = "db.duckdb",
    engine = list(seed = 1L, tz = "UTC"),
    universe = list(instrument_ids = c("A")),
    backtest = list(
      start_ts_utc = "2020-01-01T00:00:00Z",
      end_ts_utc = "2020-01-02T00:00:00Z",
      pulse = "EOD",
      initial_cash = 1000
    ),
    timing_model = ledgr_timing_next_open(),
    cost_model = list(
      cost_model_hash = ledgr:::ledgr_cost_model_hash(
        ledgr_cost_chain(ledgr_cost_spread_bps(5), ledgr_cost_fixed_fee(1.25))
      ),
      cost_plan_json = ledgr:::ledgr_cost_plan_json(
        ledgr_cost_chain(ledgr_cost_spread_bps(5), ledgr_cost_fixed_fee(1.25))
      )
    ),
    strategy = list(id = "x", params = list())
  )

  testthat::expect_identical(
    ledgr:::config_hash(cfg),
    "23838c7297b9ec8a09b422f9f4a29933fb61b7cdbd8b030789ff4b2f441ae57b"
  )
})
