testthat::test_that("walk-forward tables are created and validated with the experiment store schema", {
  path <- tempfile(fileext = ".duckdb")
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = path)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  testthat::expect_true(ledgr_create_schema(con))
  testthat::expect_true(ledgr_validate_schema(con))

  tables <- DBI::dbListTables(con)
  testthat::expect_true(all(c(
    "walk_forward_sessions",
    "walk_forward_folds",
    "walk_forward_scores"
  ) %in% tables))

  version <- DBI::dbGetQuery(
    con,
    "
    SELECT value
    FROM ledgr_schema_metadata
    WHERE key = 'experiment_store_schema_version'
    "
  )$value[[1]]
  testthat::expect_identical(as.integer(version), ledgr:::ledgr_experiment_store_schema_version)
})

testthat::test_that("walk-forward schema stores compact identity rows without plan JSON duplication", {
  path <- tempfile(fileext = ".duckdb")
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = path)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  ledgr_create_schema(con)

  session_id <- digest::digest("session", algo = "sha256")
  fold_id <- digest::digest("fold", algo = "sha256")
  candidate_key <- digest::digest("candidate", algo = "sha256")
  now <- as.POSIXct("2020-01-01 00:00:00", tz = "UTC")

  DBI::dbAppendTable(
    con,
    "walk_forward_sessions",
    data.frame(
      session_id = session_id,
      snapshot_hash = digest::digest("snapshot", algo = "sha256"),
      experiment_hash = digest::digest("experiment", algo = "sha256"),
      param_grid_hash = digest::digest("grid", algo = "sha256"),
      fold_list_hash = digest::digest("fold-list", algo = "sha256"),
      selection_rule_hash = digest::digest("selection", algo = "sha256"),
      metric_context_hash = digest::digest("metric", algo = "sha256"),
      cost_model_hash = digest::digest("cost", algo = "sha256"),
      risk_chain_hash = digest::digest("risk", algo = "sha256"),
      master_seed = 12L,
      opening_state_policy = "carry_test_state",
      created_at_utc = now,
      ledgr_version = "0.1.9.4-test",
      meta_json = "{}",
      stringsAsFactors = FALSE
    )
  )
  DBI::dbAppendTable(
    con,
    "walk_forward_folds",
    data.frame(
      session_id = session_id,
      fold_id = fold_id,
      fold_seq = 1L,
      scheme = "rolling",
      train_start_utc = now,
      train_end_utc = now + 86400,
      test_start_utc = now + 2 * 86400,
      test_end_utc = now + 3 * 86400,
      hydration_start_utc = now,
      train_scoring_start_utc = now,
      test_scoring_start_utc = now + 2 * 86400,
      opening_state_policy = "carry_test_state",
      selected_candidate_key = candidate_key,
      selected_at_utc = now + 4 * 86400,
      test_run_id = "wf-test-run",
      status = "DONE",
      stringsAsFactors = FALSE
    )
  )
  DBI::dbAppendTable(
    con,
    "walk_forward_scores",
    data.frame(
      session_id = session_id,
      fold_id = fold_id,
      fold_seq = 1L,
      candidate_key = candidate_key,
      candidate_label = "candidate-a",
      params_hash = digest::digest("params", algo = "sha256"),
      feature_params_hash = digest::digest("feature-params", algo = "sha256"),
      feature_set_hash = digest::digest("feature-set", algo = "sha256"),
      alias_map_hash = digest::digest("alias-map", algo = "sha256"),
      metric_context_hash = digest::digest("metric", algo = "sha256"),
      cost_model_hash = digest::digest("cost", algo = "sha256"),
      risk_chain_hash = digest::digest("risk", algo = "sha256"),
      window = "train",
      metric_name = "sharpe_ratio",
      metric_value = 1.25,
      n_trades = 2L,
      status = "DONE",
      error_class = NA_character_,
      error_msg = NA_character_,
      execution_seed = 456L,
      stringsAsFactors = FALSE
    )
  )

  fold_row <- DBI::dbGetQuery(
    con,
    "SELECT selected_candidate_key, test_run_id, status FROM walk_forward_folds WHERE session_id = ?",
    params = list(session_id)
  )
  score_row <- DBI::dbGetQuery(
    con,
    "SELECT candidate_key, cost_model_hash, risk_chain_hash, execution_seed FROM walk_forward_scores WHERE session_id = ?",
    params = list(session_id)
  )
  table_columns <- lapply(
    c("walk_forward_sessions", "walk_forward_folds", "walk_forward_scores"),
    function(table_name) ledgr:::ledgr_experiment_store_columns(con, table_name)
  )
  names(table_columns) <- c("walk_forward_sessions", "walk_forward_folds", "walk_forward_scores")
  all_columns <- unlist(table_columns, use.names = FALSE)

  testthat::expect_identical(fold_row$selected_candidate_key[[1]], candidate_key)
  testthat::expect_identical(fold_row$test_run_id[[1]], "wf-test-run")
  testthat::expect_identical(score_row$candidate_key[[1]], candidate_key)
  testthat::expect_identical(as.integer(score_row$execution_seed[[1]]), 456L)
  testthat::expect_false(any(all_columns %in% c("cost_plan_json", "risk_plan_json")))
  testthat::expect_true(ledgr_validate_schema(con))
})
