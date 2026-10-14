# ledgr-test-file-profile: fast

testthat::test_that("[LTB-0264] stored record readers are current-only", {
  root <- testthat::test_path("..", "..")
  source_files <- list.files(
    file.path(root, "R"),
    pattern = "[.]R$",
    full.names = TRUE
  )
  source <- paste(
    unlist(lapply(source_files, readLines, warn = FALSE), use.names = FALSE),
    collapse = "\n"
  )
  retired <- c(
    "availability_close_v1",
    "ledgr_config_identity_rule",
    "ledgr_snapshot_rebuild_required",
    "ledgr_identity_rule_retired",
    "ledgr_identity_rule_retired_abort"
  )
  for (token in retired) {
    testthat::expect_no_match(source, token, fixed = TRUE)
  }

  testthat::expect_identical(ledgr:::ledgr_identity_rule_version, 2L)
  testthat::expect_identical(
    ledgr:::ledgr_saved_sweep_schema_version,
    4L
  )
  testthat::expect_identical(
    ledgr:::ledgr_sweep_retention_schema_version,
    2L
  )
  testthat::expect_identical(
    ledgr:::ledgr_snapshot_content_hash_rule_version,
    3L
  )

  current <- list(
    identity_rule_version = 2L,
    data = list(snapshot_id = "local-id", snapshot_hash = "content-hash"),
    risk_chain = ledgr:::ledgr_config_risk_identity()
  )
  payload <- ledgr:::config_hash_payload(current)
  testthat::expect_null(payload$data$snapshot_id)
  testthat::expect_identical(payload$data$snapshot_hash, "content-hash")
  missing_rule <- current
  missing_rule$identity_rule_version <- NULL
  testthat::expect_error(
    ledgr:::config_hash_payload(missing_rule),
    class = "ledgr_invalid_config"
  )
  missing_hash <- current
  missing_hash$data$snapshot_hash <- NULL
  testthat::expect_error(
    ledgr:::config_hash_payload(missing_hash),
    class = "ledgr_invalid_config"
  )

  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)
  snapshot <- ledgr_snapshot_from_df(
    ledgr_test_make_bars("AAA", as.Date("2020-01-01") + 0:2),
    db_path = db_path
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  config <- ledgr:::ledgr_config(
    snapshot = snapshot,
    universe = "AAA",
    strategy = function(ctx, params) ctx$flat(),
    backtest = ledgr:::ledgr_backtest_config(
      start = snapshot$metadata$start_date,
      end = snapshot$metadata$end_date,
      initial_cash = 1000
    ),
    cost_model_hash = ledgr:::ledgr_cost_model_hash(ledgr_cost_zero()),
    cost_plan_json = ledgr:::ledgr_cost_plan_json(ledgr_cost_zero()),
    db_path = db_path
  )

  invalid_configs <- list(
    missing_identity_rule = function(x) {
      x$identity_rule_version <- NULL
      x
    },
    old_identity_rule = function(x) {
      x$identity_rule_version <- 1L
      x
    },
    missing_snapshot_hash = function(x) {
      x$data$snapshot_hash <- NULL
      x
    },
    missing_risk = function(x) {
      x$risk_chain <- NULL
      x
    },
    missing_corporate_actions = function(x) {
      x$corporate_actions <- NULL
      x
    }
  )
  for (mutate in invalid_configs) {
    testthat::expect_error(
      ledgr:::validate_ledgr_config(mutate(config)),
      class = "ledgr_invalid_config"
    )
  }
  old_policy <- config
  old_policy$corporate_actions$policy_schema_version <- 1L
  testthat::expect_error(
    ledgr:::validate_ledgr_config(old_policy),
    class = "ledgr_policy_schema_mismatch"
  )

  con <- ledgr:::get_connection(snapshot)
  resume_cases <- invalid_configs[c(
    "missing_identity_rule", "old_identity_rule", "missing_snapshot_hash"
  )]
  for (case_name in names(resume_cases)) {
    run_id <- paste0("current-only-", case_name)
    ledgr:::ledgr_run_fold(
      config,
      run_id = run_id,
      control = list(max_pulses = 1L)
    )
    stored <- DBI::dbGetQuery(
      con,
      "SELECT config_json FROM runs WHERE run_id = ?",
      params = list(run_id)
    )$config_json[[1L]]
    record <- resume_cases[[case_name]](
      ledgr:::ledgr_json_read_config(stored)
    )
    DBI::dbExecute(
      con,
      "UPDATE runs SET config_json = ? WHERE run_id = ?",
      params = list(as.character(ledgr:::canonical_json(record)), run_id)
    )
    testthat::expect_error(
      ledgr:::ledgr_run_config(config, run_id = run_id),
      class = "ledgr_invalid_config"
    )
  }

  ledgr_run_config(config, run_id = "current-only-open")
  original_json <- DBI::dbGetQuery(
    con,
    "SELECT config_json FROM runs WHERE run_id = 'current-only-open'"
  )$config_json[[1L]]
  for (case_name in c("missing_risk", "missing_corporate_actions")) {
    record <- invalid_configs[[case_name]](
      ledgr:::ledgr_json_read_config(original_json)
    )
    DBI::dbExecute(
      con,
      "UPDATE runs SET config_json = ? WHERE run_id = 'current-only-open'",
      params = list(as.character(ledgr:::canonical_json(record)))
    )
    testthat::expect_error(
      ledgr_run_open(snapshot, "current-only-open"),
      class = "ledgr_invalid_run"
    )
  }
  DBI::dbExecute(
    con,
    "UPDATE runs SET config_json = ? WHERE run_id = 'current-only-open'",
    params = list(original_json)
  )
  DBI::dbExecute(
    con,
    "DELETE FROM run_provenance WHERE run_id = 'current-only-open'"
  )
  testthat::expect_error(
    ledgr_run_strategy(snapshot, "current-only-open"),
    "has no strategy provenance record",
    class = "ledgr_strategy_provenance_missing",
    fixed = TRUE
  )

  checker <- file.path(root, "tools", "check-codebase-contracts.R")
  checked <- system2(
    file.path(R.home("bin"), "Rscript"),
    c("--vanilla", shQuote(checker), "--self-test-current-only"),
    stdout = TRUE,
    stderr = TRUE
  )
  status <- attr(checked, "status")
  if (is.null(status)) status <- 0L
  testthat::expect_identical(status, 0L)
  testthat::expect_true(any(grepl(
    "LEDGR_CURRENT_ONLY_SELF_TEST_OK",
    checked,
    fixed = TRUE
  )))
})

testthat::test_that("[LTB-0265] removed public call forms have no compatibility path", {
  testthat::expect_false("fill_model" %in% names(formals(ledgr_backtest)))
  testthat::expect_false("fill_model" %in% names(formals(ledgr_experiment)))
  testthat::expect_false(
    "type" %in% names(formals(ledgr:::as_tibble.ledgr_backtest))
  )
  testthat::expect_identical(
    names(formals(ledgr:::ledgr_metrics_from_equity_fills)),
    c("equity", "fills", "metric_kernel")
  )
  testthat::expect_identical(
    names(formals(ledgr:::ledgr_metric_kernel)),
    c("context", "pulses")
  )
  sparse_pulses <- as.POSIXct(
    c("2020-01-01", "2021-01-01"),
    tz = "UTC"
  )
  testthat::expect_identical(
    suppressWarnings(ledgr:::ledgr_metric_kernel(pulses = sparse_pulses))$bars_per_year,
    ledgr:::ledgr_metric_kernel()$bars_per_year
  )

  root <- testthat::test_path("..", "..")
  condition_source <- paste(
    readLines(file.path(root, "R", "condition-reference.R"), warn = FALSE),
    collapse = "\n"
  )
  retired <- c(
    "ledgr_legacy_fill_model_shape",
    "ledgr_legacy_config_shape",
    "ledgr_execution_timing_version_mismatch"
  )
  for (class in retired) {
    testthat::expect_no_match(condition_source, class, fixed = TRUE)
  }

  retention_body <- paste(
    deparse(body(ledgr:::ledgr_sweep_retention_normalize)),
    collapse = "\n"
  )
  testthat::expect_match(
    retention_body,
    "ledgr_sweep_retention_schema_version",
    fixed = TRUE
  )
  testthat::expect_no_match(retention_body, "%||%", fixed = TRUE)
  legacy_retention <- ledgr:::canonical_json(list(
    retention_schema_version = 1L,
    returns = "completed",
    trades = "none"
  ))
  testthat::expect_error(
    ledgr:::ledgr_sweep_retention_from_json(legacy_retention),
    class = "ledgr_sweep_schema_incompatible"
  )
})
