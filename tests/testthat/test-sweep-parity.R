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

ledgr_parity_normalize_table <- function(x, drop = character()) {
  out <- tibble::as_tibble(x)
  for (col in intersect(c("run_id", "event_id", drop), names(out))) {
    out[[col]] <- NULL
  }
  if ("ts_utc" %in% names(out)) {
    out$ts_utc <- vapply(out$ts_utc, ledgr_normalize_ts_utc, character(1))
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

ledgr_expect_sweep_row_matches_run <- function(row, bt) {
  metrics <- ledgr_compute_metrics(bt)
  equity <- ledgr_results(bt, "equity")
  final_equity <- equity$equity[[nrow(equity)]]

  testthat::expect_equal(row$final_equity[[1]], final_equity, tolerance = 0)
  for (col in ledgr_parity_metric_cols()) {
    if (identical(col, "n_trades")) {
      testthat::expect_identical(row[[col]][[1]], as.integer(metrics[[col]]))
    } else {
      testthat::expect_equal(
        row[[col]][[1]],
        metrics[[col]],
        tolerance = 0,
        info = sprintf("%s actual=%s expected=%s", col, deparse(row[[col]][[1]]), deparse(metrics[[col]]))
      )
    }
  }
}

ledgr_expect_run_artifacts_identical <- function(left, right) {
  testthat::expect_equal(
    ledgr_parity_normalize_table(ledgr_results(left, "ledger")),
    ledgr_parity_normalize_table(ledgr_results(right, "ledger")),
    tolerance = 0
  )
  testthat::expect_equal(
    ledgr_parity_normalize_table(ledgr_results(left, "fills")),
    ledgr_parity_normalize_table(ledgr_results(right, "fills")),
    tolerance = 0
  )
  testthat::expect_equal(
    ledgr_parity_normalize_table(ledgr_results(left, "trades")),
    ledgr_parity_normalize_table(ledgr_results(right, "trades")),
    tolerance = 0
  )
  testthat::expect_equal(
    ledgr_parity_normalize_table(ledgr_results(left, "equity"), drop = "drawdown"),
    ledgr_parity_normalize_table(ledgr_results(right, "equity"), drop = "drawdown"),
    tolerance = 0
  )
  testthat::expect_equal(
    ledgr_parity_final_positions(ledgr_results(left, "fills")),
    ledgr_parity_final_positions(ledgr_results(right, "fills")),
    tolerance = 0
  )
}

testthat::test_that("sweep candidates match persistent run and promoted run artifacts", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)
  snapshot <- ledgr_snapshot_from_df(ledgr_parity_bars(), db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$hold()
    day <- substr(ctx$ts_utc, 1L, 10L)
    if (identical(day, "2020-01-01")) {
      targets["AAA"] <- params$aaa_qty
      targets["BBB"] <- params$bbb_qty
    } else if (identical(day, "2020-01-02")) {
      targets["AAA"] <- 0
      targets["BBB"] <- params$bbb_qty
    } else if (identical(day, "2020-01-03")) {
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
    fill_model = list(type = "next_open", spread_bps = 5, commission_fixed = 1),
    universe = c("AAA", "BBB")
  )
  grid <- ledgr_param_grid(
    conservative = list(aaa_qty = 2, bbb_qty = 1, last_bar_qty = 1),
    aggressive = list(aaa_qty = 4, bbb_qty = 2, last_bar_qty = 3)
  )

  results <- ledgr_sweep(exp, grid, seed = 2026L)
  candidate <- ledgr_candidate(results, "aggressive")
  promoted <- suppressWarnings(ledgr_promote(exp, candidate, run_id = "parity-promoted"))
  direct <- suppressWarnings(ledgr_run(
    exp,
    params = candidate$params,
    run_id = "parity-direct",
    seed = candidate$execution_seed
  ))
  on.exit(close(promoted), add = TRUE)
  on.exit(close(direct), add = TRUE)

  row <- results[results$run_id == "aggressive", , drop = FALSE]
  testthat::expect_identical(row$status[[1]], "DONE")
  testthat::expect_true(any(vapply(
    row$warnings[[1]],
    function(w) grepl("LEDGR_LAST_BAR_NO_FILL", conditionMessage(w), fixed = TRUE),
    logical(1)
  )))
  ledgr_expect_sweep_row_matches_run(row, promoted)
  ledgr_expect_run_artifacts_identical(promoted, direct)

  testthat::expect_identical(ledgr_run_info(snapshot, "parity-promoted")$status, "DONE")
  testthat::expect_identical(ledgr_run_info(snapshot, "parity-direct")$status, "DONE")
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
    universe = "AAA"
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
    universe = "AAA"
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
    fill_model = list(type = "next_open", spread_bps = 5, commission_fixed = 1.25),
    strategy = list(id = "x", params = list())
  )

  testthat::expect_identical(
    ledgr:::config_hash(cfg),
    "948146c214583b5bf2e200113d0bc5c065d834624b0701b1d099157b15833b3f"
  )
})
