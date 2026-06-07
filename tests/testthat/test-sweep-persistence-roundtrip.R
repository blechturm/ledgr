ledgr_sweep_roundtrip_bars <- function() {
  data.frame(
    instrument_id = rep("AAA", 6L),
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:5,
    open = 100:105,
    high = 101:106,
    low = 99:104,
    close = c(100, 102, 101, 104, 103, 106),
    volume = 1000,
    stringsAsFactors = FALSE
  )
}

ledgr_sweep_roundtrip_experiment <- function(snapshot) {
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["AAA"] <- params$qty
    targets
  }
  ledgr_experiment(snapshot, strategy, cost_model = ledgr_cost_zero())
}

ledgr_sweep_roundtrip_sweep <- function(exp) {
  grid <- ledgr_param_grid(a = list(qty = 1), b = list(qty = 2))
  ledgr_sweep(
    exp,
    grid,
    seed = 123L,
    retain = ledgr_sweep_retention("completed")
  )
}

ledgr_sweep_roundtrip_json <- function(x) {
  vapply(x, function(value) as.character(canonical_json(value)), character(1))
}

testthat::test_that("reopened sweeps round-trip scalar rows, identity, and retained series", {
  snapshot <- ledgr_snapshot_from_df(
    ledgr_sweep_roundtrip_bars(),
    db_path = tempfile(fileext = ".duckdb"),
    snapshot_id = "roundtrip_snapshot"
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_sweep_roundtrip_experiment(snapshot)
  sweep <- ledgr_sweep_roundtrip_sweep(exp)

  ledgr_sweep_save(sweep, snapshot, sweep_id = "roundtrip_saved", note = "round trip")
  reopened <- ledgr_sweep_open(snapshot, "roundtrip_saved")

  scalar_cols <- c(
    "candidate_id", "candidate_row", "status", "final_equity",
    "total_return", "annualized_return", "volatility", "sharpe_ratio",
    "max_drawdown", "n_trades", "win_rate", "avg_trade",
    "time_in_market", "execution_seed", "error_class", "error_msg"
  )
  for (name in scalar_cols) {
    testthat::expect_equal(reopened[[name]], sweep[[name]], tolerance = 1e-12, info = name)
  }
  testthat::expect_identical(
    ledgr_sweep_roundtrip_json(reopened$params),
    ledgr_sweep_roundtrip_json(sweep$params)
  )
  testthat::expect_identical(
    ledgr_sweep_roundtrip_json(reopened$feature_params),
    ledgr_sweep_roundtrip_json(sweep$feature_params)
  )
  testthat::expect_identical(
    ledgr_sweep_roundtrip_json(reopened$feature_fingerprints),
    ledgr_sweep_roundtrip_json(sweep$feature_fingerprints)
  )
  testthat::expect_identical(
    ledgr_sweep_roundtrip_json(reopened$provenance),
    ledgr_sweep_roundtrip_json(sweep$provenance)
  )

  parity_attrs <- c(
    "snapshot_id", "snapshot_hash", "universe", "master_seed",
    "seed_contract", "evaluation_scope", "strategy_hash",
    "feature_union_hash", "feature_engine_version", "metric_context_hash",
    "metric_context_version", "cost_model_hash", "cost_plan_json",
    "sweep_retention"
  )
  for (name in parity_attrs) {
    testthat::expect_identical(
      attr(reopened, name, exact = TRUE),
      attr(sweep, name, exact = TRUE),
      info = name
    )
  }
  testthat::expect_identical(attr(reopened, "sweep_id", exact = TRUE), "roundtrip_saved")
  testthat::expect_true(isTRUE(attr(reopened, "saved_sweep", exact = TRUE)$saved))
  testthat::expect_type(attr(reopened, "execution_assumptions", exact = TRUE), "list")
  testthat::expect_identical(
    names(attr(reopened, "execution_assumptions", exact = TRUE)),
    names(ledgr_json_read_nested(canonical_json(attr(sweep, "execution_assumptions", exact = TRUE))))
  )
  testthat::expect_identical(
    attr(reopened, "scoring_range", exact = TRUE)$start,
    attr(sweep, "scoring_range", exact = TRUE)$start
  )
  testthat::expect_identical(
    attr(reopened, "scoring_range", exact = TRUE)$end,
    attr(sweep, "scoring_range", exact = TRUE)$end
  )

  original_returns <- ledgr_sweep_returns(sweep)
  original_returns$sweep_id <- "roundtrip_saved"
  reopened_returns <- ledgr_sweep_returns(reopened)
  testthat::expect_equal(reopened_returns, original_returns, tolerance = 1e-12)
  testthat::expect_true(is.na(reopened_returns$period_return[[1]]))

  testthat::expect_equal(
    ledgr_sweep_returns_wide(reopened, value = "equity"),
    ledgr_sweep_returns_wide(structure(sweep, sweep_id = "roundtrip_saved"), value = "equity"),
    tolerance = 1e-12
  )
})

testthat::test_that("reopened sweeps survive dplyr and base row operations", {
  testthat::skip_if_not_installed("dplyr")
  snapshot <- ledgr_snapshot_from_df(
    ledgr_sweep_roundtrip_bars(),
    db_path = tempfile(fileext = ".duckdb"),
    snapshot_id = "survivability_snapshot"
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_sweep_roundtrip_experiment(snapshot)
  sweep <- ledgr_sweep_roundtrip_sweep(exp)
  ledgr_sweep_save(sweep, snapshot, sweep_id = "survive_saved")
  reopened <- ledgr_sweep_open(snapshot, "survive_saved")

  filtered <- dplyr::filter(reopened, candidate_id == "b")
  testthat::expect_s3_class(filtered, "ledgr_sweep_results")
  testthat::expect_identical(attr(filtered, "sweep_id", exact = TRUE), "survive_saved")
  testthat::expect_identical(ledgr_sweep_info(filtered)$grid$candidate_rows, 2L)
  testthat::expect_identical(unique(ledgr_sweep_returns(filtered)$candidate_id), "b")
  candidate <- ledgr_candidate(filtered, "b")
  testthat::expect_identical(candidate$candidate_row, 2L)
  testthat::expect_identical(candidate$sweep_meta$sweep_id, "survive_saved")
  testthat::expect_identical(candidate$selection_view$candidate_id, "b")

  arranged <- dplyr::arrange(reopened, dplyr::desc(total_return))
  arranged_candidate <- ledgr_candidate(arranged, 1L)
  testthat::expect_identical(arranged$candidate_row, c(2L, 1L))
  testthat::expect_identical(arranged_candidate$candidate_id, "b")
  testthat::expect_identical(arranged_candidate$selection_view$candidate_row, c(2L, 1L))

  sliced <- dplyr::slice(reopened, 2L)
  testthat::expect_identical(ledgr_sweep_info(sliced)$grid$candidate_ids, "b")
  testthat::expect_identical(unique(ledgr_sweep_returns(sliced)$candidate_id), "b")

  base_subset <- reopened[2L, ]
  testthat::expect_s3_class(base_subset, "ledgr_sweep_results")
  testthat::expect_identical(attr(base_subset, "sweep_id", exact = TRUE), "survive_saved")
  testthat::expect_identical(ledgr_sweep_info(base_subset)$grid$candidate_rows, 2L)
  testthat::expect_identical(unique(ledgr_sweep_returns(base_subset)$candidate_id), "b")

  in_memory_subset <- sweep[2L, ]
  testthat::expect_s3_class(in_memory_subset, "ledgr_sweep_results")
  testthat::expect_identical(
    attr(in_memory_subset, "sweep_id", exact = TRUE),
    attr(sweep, "sweep_id", exact = TRUE)
  )
  testthat::expect_identical(ledgr_sweep_info(in_memory_subset)$grid$candidate_rows, 2L)
  testthat::expect_identical(unique(ledgr_sweep_returns(in_memory_subset)$candidate_id), "b")
})

testthat::test_that("promotion from reopened sweeps re-executes committed run artifacts", {
  testthat::skip_if_not_installed("dplyr")
  snapshot <- ledgr_snapshot_from_df(
    ledgr_sweep_roundtrip_bars(),
    db_path = tempfile(fileext = ".duckdb"),
    snapshot_id = "promotion_roundtrip_snapshot"
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_sweep_roundtrip_experiment(snapshot)
  sweep <- ledgr_sweep_roundtrip_sweep(exp)
  ledgr_sweep_save(sweep, snapshot, sweep_id = "promotion_saved")
  reopened <- ledgr_sweep_open(snapshot, "promotion_saved")

  candidate <- ledgr_candidate(dplyr::filter(reopened, candidate_id == "b"), "b")
  con <- ledgr:::get_connection(snapshot)
  before_runs <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM runs")$n[[1]]
  before_sweep_candidates <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM sweep_candidates")$n[[1]]
  bt <- ledgr_promote(exp, candidate, run_id = "reopened-promotion", note = "from reopened")
  on.exit(close(bt), add = TRUE)

  after_runs <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM runs")$n[[1]]
  after_sweep_candidates <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM sweep_candidates")$n[[1]]
  testthat::expect_identical(as.integer(after_runs), as.integer(before_runs + 1L))
  testthat::expect_identical(after_sweep_candidates, before_sweep_candidates)
  testthat::expect_gt(nrow(ledgr_results(bt, what = "ledger")), 0L)

  context <- ledgr_promotion_context(bt)
  testthat::expect_identical(context$source_sweep$sweep_id, "promotion_saved")
  testthat::expect_identical(context$selected_candidate$candidate_id, "b")
  testthat::expect_identical(context$selected_candidate$candidate_row, 2)
  testthat::expect_identical(context$candidate_summary[[1]]$candidate_id, "b")
})
