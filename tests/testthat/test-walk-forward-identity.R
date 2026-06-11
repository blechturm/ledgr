testthat::test_that("walk-forward candidate keys use canonical identity fields", {
  fields <- list(
    params_hash = digest::digest("params", algo = "sha256"),
    feature_params_hash = digest::digest("feature-params", algo = "sha256"),
    strategy_hash = digest::digest("strategy", algo = "sha256"),
    feature_set_hash = digest::digest("feature-set", algo = "sha256"),
    alias_map_hash = digest::digest("alias-map", algo = "sha256"),
    metric_context_hash = digest::digest("metric-context", algo = "sha256"),
    cost_model_hash = digest::digest("cost-model", algo = "sha256"),
    risk_chain_hash = digest::digest("risk-chain", algo = "sha256")
  )

  payload <- do.call(ledgr:::ledgr_walk_forward_candidate_payload, fields)
  testthat::expect_identical(
    names(payload),
    c(
      "params_hash", "feature_params_hash", "strategy_hash",
      "feature_set_hash", "alias_map_hash", "metric_context_hash",
      "cost_model_hash", "risk_chain_hash", "execution_seed",
      "candidate_schema_version"
    )
  )
  testthat::expect_true(is.na(payload$execution_seed))
  testthat::expect_identical(payload$candidate_schema_version, "v1")

  key_a <- do.call(ledgr:::ledgr_walk_forward_candidate_key, fields)
  key_b <- do.call(ledgr:::ledgr_walk_forward_candidate_key, fields)
  changed_cost <- do.call(
    ledgr:::ledgr_walk_forward_candidate_key,
    utils::modifyList(fields, list(cost_model_hash = digest::digest("cost-model-b", algo = "sha256")))
  )
  changed_risk <- do.call(
    ledgr:::ledgr_walk_forward_candidate_key,
    utils::modifyList(fields, list(risk_chain_hash = digest::digest("risk-chain-b", algo = "sha256")))
  )

  testthat::expect_match(key_a, "^[0-9a-f]{64}$")
  testthat::expect_identical(key_a, key_b)
  testthat::expect_false(identical(key_a, changed_cost))
  testthat::expect_false(identical(key_a, changed_risk))
})

testthat::test_that("walk-forward candidate identity derives deterministic per-row seeds", {
  fields <- list(
    params_hash = digest::digest("params", algo = "sha256"),
    feature_params_hash = digest::digest("feature-params", algo = "sha256"),
    strategy_hash = digest::digest("strategy", algo = "sha256"),
    feature_set_hash = digest::digest("feature-set", algo = "sha256"),
    alias_map_hash = digest::digest("alias-map", algo = "sha256"),
    metric_context_hash = digest::digest("metric-context", algo = "sha256"),
    cost_model_hash = digest::digest("cost-model", algo = "sha256"),
    risk_chain_hash = digest::digest("risk-chain", algo = "sha256")
  )

  seeded <- do.call(
    ledgr:::ledgr_walk_forward_candidate_identity,
    c(fields, list(master_seed = 42L, fold_seq = 2L, window = "train"))
  )
  same <- do.call(
    ledgr:::ledgr_walk_forward_candidate_identity,
    c(fields, list(master_seed = 42L, fold_seq = 2L, window = "train"))
  )
  changed_window <- do.call(
    ledgr:::ledgr_walk_forward_candidate_identity,
    c(fields, list(master_seed = 42L, fold_seq = 2L, window = "test"))
  )
  changed_fold <- do.call(
    ledgr:::ledgr_walk_forward_candidate_identity,
    c(fields, list(master_seed = 42L, fold_seq = 3L, window = "train"))
  )
  unseeded <- do.call(
    ledgr:::ledgr_walk_forward_candidate_identity,
    c(fields, list(master_seed = NULL, fold_seq = 2L, window = "train"))
  )

  testthat::expect_match(seeded$unseeded_candidate_key, "^[0-9a-f]{64}$")
  testthat::expect_match(seeded$candidate_key, "^[0-9a-f]{64}$")
  testthat::expect_type(seeded$execution_seed, "integer")
  testthat::expect_identical(seeded, same)
  testthat::expect_false(identical(seeded$execution_seed, changed_window$execution_seed))
  testthat::expect_false(identical(seeded$execution_seed, changed_fold$execution_seed))
  testthat::expect_false(identical(seeded$candidate_key, changed_window$candidate_key))
  testthat::expect_true(is.na(unseeded$execution_seed))
})

testthat::test_that("walk-forward param grid hash excludes labels and row order", {
  grid_ab <- ledgr_param_grid(
    a = list(qty = 1, threshold = 2),
    b = list(qty = 2, threshold = 3)
  )
  grid_ba <- ledgr_param_grid(
    second = list(qty = 2, threshold = 3),
    first = list(qty = 1, threshold = 2)
  )
  grid_changed <- ledgr_param_grid(
    a = list(qty = 1, threshold = 2),
    b = list(qty = 3, threshold = 3)
  )

  hash_ab <- ledgr:::ledgr_walk_forward_param_grid_hash(grid_ab)
  testthat::expect_match(hash_ab, "^[0-9a-f]{64}$")
  testthat::expect_identical(hash_ab, ledgr:::ledgr_walk_forward_param_grid_hash(grid_ba))
  testthat::expect_false(identical(hash_ab, ledgr:::ledgr_walk_forward_param_grid_hash(grid_changed)))
})

testthat::test_that("walk-forward session IDs consume session-level identities", {
  fields <- list(
    snapshot_hash = digest::digest("snapshot", algo = "sha256"),
    experiment_hash = digest::digest("experiment", algo = "sha256"),
    param_grid_hash = digest::digest("grid", algo = "sha256"),
    fold_list_hash = digest::digest("folds", algo = "sha256"),
    selection_rule_hash = digest::digest("selection", algo = "sha256"),
    metric_context_hash = digest::digest("metric-context", algo = "sha256"),
    cost_model_hash = digest::digest("cost-model", algo = "sha256"),
    risk_chain_hash = digest::digest("risk-chain", algo = "sha256"),
    master_seed = 100L,
    opening_state_policy = "carry_test_state",
    ledgr_version = "0.1.9.4-test"
  )

  payload <- do.call(ledgr:::ledgr_walk_forward_session_payload, fields)
  testthat::expect_identical(
    names(payload),
    c(
      "snapshot_hash", "experiment_hash", "param_grid_hash",
      "fold_list_hash", "selection_rule_hash", "metric_context_hash",
      "cost_model_hash", "risk_chain_hash", "master_seed",
      "opening_state_policy", "walk_forward_schema_version",
      "ledgr_version"
    )
  )

  id <- do.call(ledgr:::ledgr_walk_forward_session_id, fields)
  same <- do.call(ledgr:::ledgr_walk_forward_session_id, fields)
  changed_selection <- do.call(
    ledgr:::ledgr_walk_forward_session_id,
    utils::modifyList(fields, list(selection_rule_hash = digest::digest("selection-b", algo = "sha256")))
  )
  changed_metric <- do.call(
    ledgr:::ledgr_walk_forward_session_id,
    utils::modifyList(fields, list(metric_context_hash = digest::digest("metric-b", algo = "sha256")))
  )
  changed_cost <- do.call(
    ledgr:::ledgr_walk_forward_session_id,
    utils::modifyList(fields, list(cost_model_hash = digest::digest("cost-b", algo = "sha256")))
  )
  changed_risk <- do.call(
    ledgr:::ledgr_walk_forward_session_id,
    utils::modifyList(fields, list(risk_chain_hash = digest::digest("risk-b", algo = "sha256")))
  )
  changed_seed <- do.call(
    ledgr:::ledgr_walk_forward_session_id,
    utils::modifyList(fields, list(master_seed = 101L))
  )
  flat_state <- do.call(
    ledgr:::ledgr_walk_forward_session_id,
    utils::modifyList(fields, list(opening_state_policy = "flat_test_state"))
  )

  testthat::expect_match(id, "^[0-9a-f]{64}$")
  testthat::expect_identical(id, same)
  testthat::expect_false(identical(id, changed_selection))
  testthat::expect_false(identical(id, changed_metric))
  testthat::expect_false(identical(id, changed_cost))
  testthat::expect_false(identical(id, changed_risk))
  testthat::expect_false(identical(id, changed_seed))
  testthat::expect_false(identical(id, flat_state))
  testthat::expect_error(
    ledgr:::ledgr_walk_forward_opening_state_policy("reset"),
    class = "ledgr_walk_forward_invalid_identity"
  )
})

testthat::test_that("walk-forward experiment hash excludes separately carried identities", {
  bars <- data.frame(
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:2,
    instrument_id = "AAA",
    open = 100:102,
    high = 101:103,
    low = 99:101,
    close = 100:102,
    volume = 1000,
    stringsAsFactors = FALSE
  )
  snapshot <- ledgr_snapshot_from_df(bars)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) ctx$flat()
  bt <- ledgr_backtest_config(start = "2020-01-01", end = "2020-01-03", initial_cash = 1000)
  cost_zero <- ledgr_cost_zero()
  cost_bps <- ledgr_cost_spread_bps(5)
  risk_none <- ledgr_risk_none()
  risk_long <- ledgr_risk_long_only()

  cfg_base <- ledgr:::ledgr_config(
    snapshot = snapshot,
    universe = "AAA",
    strategy = strategy,
    backtest = bt,
    cost_model_hash = ledgr_cost_model_hash(cost_zero),
    cost_plan_json = ledgr_cost_plan_json(cost_zero),
    risk_chain_hash = ledgr:::ledgr_risk_chain_hash(risk_none),
    risk_plan_json = ledgr:::ledgr_risk_plan_json(risk_none),
    seed = 1L,
    run_id = "run-a"
  )
  cfg_identity_changed <- ledgr:::ledgr_config(
    snapshot = snapshot,
    universe = "AAA",
    strategy = strategy,
    backtest = bt,
    cost_model_hash = ledgr_cost_model_hash(cost_bps),
    cost_plan_json = ledgr_cost_plan_json(cost_bps),
    risk_chain_hash = ledgr:::ledgr_risk_chain_hash(risk_long),
    risk_plan_json = ledgr:::ledgr_risk_plan_json(risk_long),
    seed = 2L,
    run_id = "run-b"
  )
  cfg_base_changed <- ledgr:::ledgr_config(
    snapshot = snapshot,
    universe = "AAA",
    strategy = strategy,
    backtest = ledgr_backtest_config(start = "2020-01-01", end = "2020-01-02", initial_cash = 1000),
    cost_model_hash = ledgr_cost_model_hash(cost_zero),
    cost_plan_json = ledgr_cost_plan_json(cost_zero),
    risk_chain_hash = ledgr:::ledgr_risk_chain_hash(risk_none),
    risk_plan_json = ledgr:::ledgr_risk_plan_json(risk_none),
    seed = 1L
  )

  base_hash <- ledgr:::ledgr_walk_forward_experiment_hash(cfg_base)
  testthat::expect_match(base_hash, "^[0-9a-f]{64}$")
  testthat::expect_identical(base_hash, ledgr:::ledgr_walk_forward_experiment_hash(cfg_identity_changed))
  testthat::expect_false(identical(base_hash, ledgr:::ledgr_walk_forward_experiment_hash(cfg_base_changed)))
})
