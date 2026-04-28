testthat::test_that("ledgr_run_label updates labels without changing identity hashes", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["TEST_A"] <- 1
    targets
  }

  bt <- ledgr_backtest(
    data = test_bars,
    strategy = strategy,
    start = "2020-01-01",
    end = "2020-01-05",
    db_path = db_path,
    run_id = "label-run"
  )
  on.exit(close(bt), add = TRUE)

  before <- ledgr_run_info(db_path, "label-run")
  identity_cols <- c("run_id", "config_hash", "data_hash", "strategy_source_hash", "strategy_params_hash")

  labeled <- ledgr_run_label(db_path, "label-run", "baseline")
  testthat::expect_s3_class(labeled, "ledgr_run_info")
  testthat::expect_identical(labeled$label, "baseline")
  testthat::expect_identical(labeled[identity_cols], before[identity_cols])

  cleared <- ledgr_run_label(db_path, "label-run", "")
  testthat::expect_true(is.na(cleared$label))

  testthat::expect_error(
    ledgr_run_label(db_path, "missing-run", "label"),
    class = "ledgr_run_not_found"
  )
  testthat::expect_error(
    ledgr_run_label(db_path, "label-run", NA_character_),
    class = "ledgr_invalid_args"
  )
})

testthat::test_that("ledgr_run_label and ledgr_run_archive work on non-completed runs", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  strategy <- function(ctx, params) ctx$flat()
  bt <- ledgr_backtest(
    data = test_bars,
    strategy = strategy,
    start = "2020-01-01",
    end = "2020-01-05",
    db_path = db_path,
    run_id = "status-metadata-run"
  )
  close(bt)

  opened <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  DBI::dbExecute(
    opened$con,
    "UPDATE runs SET status = 'FAILED', error_msg = 'bad params' WHERE run_id = 'status-metadata-run'"
  )

  failed_label <- ledgr_run_label(db_path, "status-metadata-run", "failed bad params")
  testthat::expect_identical(failed_label$status, "FAILED")
  testthat::expect_identical(failed_label$label, "failed bad params")

  DBI::dbExecute(opened$con, "UPDATE runs SET status = 'RUNNING' WHERE run_id = 'status-metadata-run'")
  running_archive <- ledgr_run_archive(db_path, "status-metadata-run", reason = "stale running test")
  testthat::expect_identical(running_archive$status, "RUNNING")
  testthat::expect_true(running_archive$archived)
  testthat::expect_identical(running_archive$archive_reason, "stale running test")
})

testthat::test_that("ledgr_run_archive hides runs by default and is idempotent", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  strategy <- function(ctx, params) ctx$flat()
  bt <- ledgr_backtest(
    data = test_bars,
    strategy = strategy,
    start = "2020-01-01",
    end = "2020-01-05",
    db_path = db_path,
    run_id = "archive-run"
  )
  close(bt)

  before <- ledgr_run_info(db_path, "archive-run")
  identity_cols <- c("run_id", "config_hash", "data_hash", "strategy_source_hash", "strategy_params_hash")

  archived <- ledgr_run_archive(db_path, "archive-run", reason = "bad parameter test")
  testthat::expect_s3_class(archived, "ledgr_run_info")
  testthat::expect_true(archived$archived)
  testthat::expect_identical(archived$archive_reason, "bad parameter test")
  testthat::expect_false(is.na(archived$archived_at_utc))
  testthat::expect_identical(archived[identity_cols], before[identity_cols])

  visible <- ledgr_run_list(db_path)
  testthat::expect_false("archive-run" %in% visible$run_id)

  all_runs <- ledgr_run_list(db_path, include_archived = TRUE)
  testthat::expect_true("archive-run" %in% all_runs$run_id)
  testthat::expect_true(all_runs$archived[all_runs$run_id == "archive-run"])

  reopened <- ledgr_run_open(db_path, "archive-run")
  testthat::expect_s3_class(reopened, "ledgr_backtest")
  close(reopened)

  archived_again <- ledgr_run_archive(db_path, "archive-run", reason = "second reason")
  testthat::expect_identical(archived_again$archived_at_utc, archived$archived_at_utc)
  testthat::expect_identical(archived_again$archive_reason, archived$archive_reason)

  testthat::expect_error(
    ledgr_run_archive(db_path, "missing-run"),
    class = "ledgr_run_not_found"
  )
  testthat::expect_error(
    ledgr_run_archive(db_path, "archive-run", reason = NA_character_),
    class = "ledgr_invalid_args"
  )
})

testthat::test_that("metadata writes migrate legacy stores before updating", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  opened <- ledgr_test_open_duckdb(db_path)
  DBI::dbExecute(
    opened$con,
    "
    CREATE TABLE runs (
      run_id TEXT NOT NULL PRIMARY KEY,
      created_at_utc TIMESTAMP NOT NULL,
      engine_version TEXT,
      config_json TEXT,
      config_hash TEXT,
      data_hash TEXT,
      snapshot_id TEXT,
      status TEXT NOT NULL,
      error_msg TEXT
    )
    "
  )
  DBI::dbExecute(
    opened$con,
    "
    INSERT INTO runs (
      run_id, created_at_utc, engine_version, config_json, config_hash,
      data_hash, snapshot_id, status, error_msg
    ) VALUES (
      'legacy-metadata-run', TIMESTAMP '2020-01-01 00:00:00', '0.1.4',
      '{}', 'config-hash', 'window-hash', 'legacy-snapshot', 'FAILED', 'old failure'
    )
    "
  )
  ledgr_test_close_duckdb(opened$con, opened$drv)

  labeled <- NULL
  testthat::expect_message(
    labeled <- ledgr_run_label(db_path, "legacy-metadata-run", "legacy failed"),
    "Upgraded ledgr experiment-store schema",
    fixed = TRUE
  )
  testthat::expect_identical(labeled$label, "legacy failed")
  testthat::expect_identical(labeled$status, "FAILED")

  archived <- ledgr_run_archive(db_path, "legacy-metadata-run", reason = "legacy cleanup")
  testthat::expect_true(archived$archived)
  testthat::expect_identical(archived$archive_reason, "legacy cleanup")
})
