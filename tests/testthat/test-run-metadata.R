ledgr_test_run_identity_hashes <- function(db_path, run_id) {
  opened <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)

  run_identity <- provenance_identity <- NULL
  for (attempt in seq_len(20L)) {
    run_identity <- DBI::dbGetQuery(
      opened$con,
      "
      SELECT
        r.run_id,
        r.config_hash,
        r.data_hash
      FROM runs r
      WHERE r.run_id = ?
      ",
      params = list(run_id)
    )
    provenance_identity <- DBI::dbGetQuery(
      opened$con,
      "
      SELECT
        p.strategy_source_hash,
        p.strategy_params_hash
      FROM run_provenance p
      WHERE p.run_id = ?
      ",
      params = list(run_id)
    )
    if (nrow(run_identity) == 1L && nrow(provenance_identity) == 1L) break
    Sys.sleep(0.05)
  }
  testthat::expect_identical(nrow(run_identity), 1L)
  testthat::expect_identical(nrow(provenance_identity), 1L)
  run_identity <- as.list(run_identity[1, , drop = TRUE])
  provenance_identity <- as.list(provenance_identity[1, , drop = TRUE])

  c(run_identity, provenance_identity)
}

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
  close(bt)
  snapshot <- ledgr_test_snapshot_for_run(db_path, bt)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  before_identity <- ledgr_test_run_identity_hashes(db_path, "label-run")

  labeled <- ledgr_run_label(snapshot, "label-run", "baseline")
  testthat::expect_s3_class(labeled, "ledgr_snapshot")
  labeled_info <- ledgr_run_info(snapshot, "label-run")
  testthat::expect_identical(labeled_info$label, "baseline")
  testthat::expect_identical(ledgr_test_run_identity_hashes(db_path, "label-run"), before_identity)

  ledgr_run_label(snapshot, "label-run", "")
  cleared <- ledgr_run_info(snapshot, "label-run")
  testthat::expect_true(is.na(cleared$label))

  testthat::expect_error(
    ledgr_run_label(snapshot, "missing-run", "label"),
    class = "ledgr_run_not_found"
  )
  testthat::expect_error(
    ledgr_run_label(snapshot, "label-run", NA_character_),
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
  snapshot <- ledgr_test_snapshot_for_run(db_path, bt)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  opened <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  DBI::dbExecute(
    opened$con,
    "UPDATE runs SET status = 'FAILED', error_msg = 'bad params' WHERE run_id = 'status-metadata-run'"
  )

  ledgr_run_label(snapshot, "status-metadata-run", "failed bad params")
  failed_label <- ledgr_run_info(snapshot, "status-metadata-run")
  testthat::expect_identical(failed_label$status, "FAILED")
  testthat::expect_identical(failed_label$label, "failed bad params")

  DBI::dbExecute(opened$con, "UPDATE runs SET status = 'RUNNING' WHERE run_id = 'status-metadata-run'")
  ledgr_run_archive(snapshot, "status-metadata-run", reason = "stale running test")
  running_archive <- ledgr_run_info(snapshot, "status-metadata-run")
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
  snapshot <- ledgr_test_snapshot_for_run(db_path, bt)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  before_identity <- ledgr_test_run_identity_hashes(db_path, "archive-run")

  archived_snapshot <- ledgr_run_archive(snapshot, "archive-run", reason = "bad parameter test")
  testthat::expect_s3_class(archived_snapshot, "ledgr_snapshot")
  archived <- ledgr_run_info(snapshot, "archive-run")
  testthat::expect_true(archived$archived)
  testthat::expect_identical(archived$archive_reason, "bad parameter test")
  testthat::expect_false(is.na(archived$archived_at_utc))
  testthat::expect_identical(ledgr_test_run_identity_hashes(db_path, "archive-run"), before_identity)

  visible <- ledgr_run_list(snapshot)
  testthat::expect_false("archive-run" %in% visible$run_id)

  all_runs <- ledgr_run_list(snapshot, include_archived = TRUE)
  testthat::expect_true("archive-run" %in% all_runs$run_id)
  testthat::expect_true(all_runs$archived[all_runs$run_id == "archive-run"])

  reopened <- ledgr_run_open(snapshot, "archive-run")
  testthat::expect_s3_class(reopened, "ledgr_backtest")
  close(reopened)

  ledgr_run_archive(snapshot, "archive-run", reason = "second reason")
  archived_again <- ledgr_run_info(snapshot, "archive-run")
  testthat::expect_identical(archived_again$archived_at_utc, archived$archived_at_utc)
  testthat::expect_identical(archived_again$archive_reason, archived$archive_reason)

  testthat::expect_error(
    ledgr_run_archive(snapshot, "missing-run"),
    class = "ledgr_run_not_found"
  )
  testthat::expect_error(
    ledgr_run_archive(snapshot, "archive-run", reason = NA_character_),
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
    CREATE TABLE snapshots (
      snapshot_id TEXT NOT NULL PRIMARY KEY,
      status TEXT NOT NULL,
      created_at_utc TIMESTAMP NOT NULL,
      sealed_at_utc TIMESTAMP,
      snapshot_hash TEXT,
      meta_json TEXT
    )
    "
  )
  DBI::dbExecute(
    opened$con,
    "
    CREATE TABLE snapshot_instruments (
      snapshot_id TEXT NOT NULL,
      instrument_id TEXT NOT NULL,
      meta_json TEXT,
      PRIMARY KEY (snapshot_id, instrument_id)
    )
    "
  )
  DBI::dbExecute(
    opened$con,
    "
    CREATE TABLE snapshot_bars (
      snapshot_id TEXT NOT NULL,
      instrument_id TEXT NOT NULL,
      ts_utc TIMESTAMP NOT NULL,
      open DOUBLE NOT NULL,
      high DOUBLE NOT NULL,
      low DOUBLE NOT NULL,
      close DOUBLE NOT NULL,
      volume DOUBLE,
      PRIMARY KEY (snapshot_id, instrument_id, ts_utc)
    )
    "
  )
  DBI::dbExecute(
    opened$con,
    "
    INSERT INTO snapshots (
      snapshot_id, status, created_at_utc, sealed_at_utc, snapshot_hash, meta_json
    ) VALUES (
      'legacy-snapshot', 'SEALED', TIMESTAMP '2020-01-01 00:00:00',
      TIMESTAMP '2020-01-01 00:00:00', 'legacy-hash', '{}'
    )
    "
  )
  DBI::dbExecute(
    opened$con,
    "
    INSERT INTO snapshot_instruments (snapshot_id, instrument_id, meta_json)
    VALUES ('legacy-snapshot', 'TEST_A', '{}')
    "
  )
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
  snapshot <- new_ledgr_snapshot(db_path, "legacy-snapshot")
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  labeled <- NULL
  testthat::expect_message(
    labeled <- ledgr_run_label(snapshot, "legacy-metadata-run", "legacy failed"),
    "Upgraded ledgr experiment-store schema",
    fixed = TRUE
  )
  testthat::expect_s3_class(labeled, "ledgr_snapshot")
  labeled_info <- ledgr_run_info(snapshot, "legacy-metadata-run")
  testthat::expect_identical(labeled_info$label, "legacy failed")
  testthat::expect_identical(labeled_info$status, "FAILED")

  ledgr_run_archive(snapshot, "legacy-metadata-run", reason = "legacy cleanup")
  archived <- ledgr_run_info(snapshot, "legacy-metadata-run")
  testthat::expect_true(archived$archived)
  testthat::expect_identical(archived$archive_reason, "legacy cleanup")
})
