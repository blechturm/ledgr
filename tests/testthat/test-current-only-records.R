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
    data = list(snapshot_id = "local-id", snapshot_hash = "content-hash")
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
})
