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
    "risk_chain_hash", "risk_plan_json", "sweep_retention"
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
  testthat::expect_equal(
    ledgr_sweep_returns_matrix(reopened),
    ledgr_sweep_returns_matrix(sweep),
    tolerance = 1e-12
  )
  testthat::expect_equal(
    ledgr_sweep_returns_data_frame(reopened, value = "equity"),
    ledgr_sweep_returns_data_frame(sweep, value = "equity"),
    tolerance = 1e-12
  )
})

testthat::test_that("schema-1 saved sweeps reopen with no-op risk identity", {
  snapshot <- ledgr_snapshot_from_df(
    ledgr_sweep_roundtrip_bars(),
    db_path = tempfile(fileext = ".duckdb"),
    snapshot_id = "schema1_risk_snapshot"
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_sweep_roundtrip_experiment(snapshot)
  sweep <- ledgr_sweep_roundtrip_sweep(exp)
  ledgr_sweep_save(sweep, snapshot, sweep_id = "schema1_saved")

  con <- ledgr:::get_connection(snapshot)
  DBI::dbExecute(con, "UPDATE sweeps SET sweep_schema_version = 1 WHERE sweep_id = 'schema1_saved'")
  for (sql in c(
    "ALTER TABLE sweeps DROP COLUMN risk_chain_hash",
    "ALTER TABLE sweeps DROP COLUMN risk_plan_json",
    "ALTER TABLE sweep_candidates DROP COLUMN risk_chain_hash",
    "ALTER TABLE sweep_candidates DROP COLUMN risk_plan_json"
  )) {
    try(DBI::dbExecute(con, sql), silent = TRUE)
  }

  reopened <- ledgr_sweep_open(snapshot, "schema1_saved")
  noop_hash <- ledgr:::ledgr_risk_chain_hash(ledgr_risk_none())
  noop_plan <- ledgr:::ledgr_risk_plan_json(ledgr_risk_none())

  testthat::expect_identical(attr(reopened, "risk_chain_hash", exact = TRUE), noop_hash)
  testthat::expect_identical(attr(reopened, "risk_plan_json", exact = TRUE), noop_plan)
  testthat::expect_identical(reopened$risk_chain_hash, rep(noop_hash, nrow(reopened)))
  testthat::expect_true(all(vapply(reopened$provenance, function(provenance) {
    identical(provenance$risk_chain_hash, noop_hash) &&
      identical(provenance$risk_plan_json, noop_plan)
  }, logical(1))))
})

testthat::test_that("schema-1 saved sweeps fail closed with non-noop risk identity", {
  snapshot <- ledgr_snapshot_from_df(
    ledgr_sweep_roundtrip_bars(),
    db_path = tempfile(fileext = ".duckdb"),
    snapshot_id = "schema1_ambiguous_risk_snapshot"
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["AAA"] <- 1000
    targets
  }
  exp <- ledgr_experiment(
    snapshot,
    strategy,
    risk_chain = ledgr_risk_max_weight(0.2),
    cost_model = ledgr_cost_zero()
  )
  sweep <- ledgr_sweep(exp, ledgr_param_grid(candidate = list()), seed = 123L)
  ledgr_sweep_save(sweep, snapshot, sweep_id = "schema1_ambiguous_saved")

  con <- ledgr:::get_connection(snapshot)
  DBI::dbExecute(con, "UPDATE sweeps SET sweep_schema_version = 1 WHERE sweep_id = 'schema1_ambiguous_saved'")

  testthat::expect_error(
    ledgr_sweep_open(snapshot, "schema1_ambiguous_saved"),
    class = "ledgr_sweep_schema_incompatible"
  )
})

testthat::test_that("schema-2 saved sweeps fail closed on provenance risk drift", {
  snapshot <- ledgr_snapshot_from_df(
    ledgr_sweep_roundtrip_bars(),
    db_path = tempfile(fileext = ".duckdb"),
    snapshot_id = "schema2_provenance_drift_snapshot"
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  exp <- ledgr_sweep_roundtrip_experiment(snapshot)
  sweep <- ledgr_sweep_roundtrip_sweep(exp)
  ledgr_sweep_save(sweep, snapshot, sweep_id = "schema2_provenance_drift")

  con <- ledgr:::get_connection(snapshot)
  stored <- DBI::dbGetQuery(
    con,
    "
    SELECT provenance_json
    FROM sweep_candidates
    WHERE sweep_id = 'schema2_provenance_drift'
      AND candidate_row = 1
    "
  )
  provenance <- ledgr:::ledgr_json_read_nested(stored$provenance_json[[1]])
  provenance$risk_chain_hash <- ledgr:::ledgr_risk_chain_hash(ledgr_risk_long_only())
  DBI::dbExecute(
    con,
    "
    UPDATE sweep_candidates
    SET provenance_json = ?
    WHERE sweep_id = 'schema2_provenance_drift'
      AND candidate_row = 1
    ",
    params = list(as.character(ledgr:::canonical_json(provenance)))
  )

  testthat::expect_error(
    ledgr_sweep_open(snapshot, "schema2_provenance_drift"),
    class = "ledgr_sweep_schema_incompatible"
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
  testthat::expect_identical(context$selected_candidate$risk_chain_hash, attr(sweep, "risk_chain_hash", exact = TRUE))
  testthat::expect_identical(context$source_sweep$risk_chain_hash, attr(sweep, "risk_chain_hash", exact = TRUE))
  testthat::expect_identical(context$candidate_summary[[1]]$candidate_id, "b")
})

testthat::test_that("promotion from reopened sweep replays selected candidate risk plan", {
  snapshot <- ledgr_snapshot_from_df(
    ledgr_sweep_roundtrip_bars(),
    db_path = tempfile(fileext = ".duckdb"),
    snapshot_id = "promotion_risk_snapshot"
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    if (identical(ctx$ts_utc, "2020-01-01T00:00:00Z")) {
      targets <- ctx$flat()
      targets["AAA"] <- 1000
      return(targets)
    }
    ctx$hold()
  }
  risk <- ledgr_risk_max_weight(ledgr_param("cap"))
  sweep_exp <- ledgr_experiment(
    snapshot,
    strategy,
    risk_chain = risk,
    cost_model = ledgr_cost_zero()
  )
  sweep <- ledgr_sweep(
    sweep_exp,
    ledgr_param_grid(low = list(cap = 0.10), high = list(cap = 0.20)),
    seed = 123L,
    retain = ledgr_sweep_retention("completed")
  )
  ledgr_sweep_save(sweep, snapshot, sweep_id = "promotion_risk_saved")
  reopened <- ledgr_sweep_open(snapshot, "promotion_risk_saved")
  candidate <- ledgr_candidate(reopened, "high")
  promote_exp <- ledgr_experiment(
    snapshot,
    strategy,
    risk_chain = ledgr_risk_none(),
    cost_model = ledgr_cost_zero()
  )

  bt <- suppressWarnings(
    ledgr_promote(promote_exp, candidate, run_id = "reopened-risk-promotion")
  )
  on.exit(close(bt), add = TRUE)

  testthat::expect_identical(bt$config$risk_chain$risk_chain_hash, ledgr:::ledgr_risk_chain_hash(risk))
  testthat::expect_identical(bt$config$risk_chain$risk_plan_json, ledgr:::ledgr_risk_plan_json(risk))
  testthat::expect_equal(
    ledgr_results(bt, "equity")$equity[[nrow(ledgr_results(bt, "equity"))]],
    candidate$row$final_equity[[1]],
    tolerance = 1e-12
  )
  context <- ledgr_promotion_context(bt)
  testthat::expect_identical(context$selected_candidate$risk_plan_json, ledgr:::ledgr_risk_plan_json(risk))
  testthat::expect_identical(context$source_sweep$risk_chain_hash, ledgr:::ledgr_risk_chain_hash(risk))
})
