testthat::test_that("ledgr_run_list discovers multiple runs and hides archived rows", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snapshot <- ledgr_snapshot_from_df(test_bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy_one <- function(ctx) {
    targets <- ctx$targets()
    targets["TEST_A"] <- 1
    targets
  }
  strategy_two <- function(ctx) {
    targets <- ctx$targets()
    targets["TEST_B"] <- 2
    targets
  }

  bt_a <- ledgr_backtest(
    snapshot = snapshot,
    strategy = strategy_one,
    start = "2020-01-01",
    end = "2020-01-05",
    db_path = db_path,
    run_id = "list-a"
  )
  on.exit(close(bt_a), add = TRUE)

  bt_b <- ledgr_backtest(
    snapshot = snapshot,
    strategy = strategy_two,
    start = "2020-01-01",
    end = "2020-01-05",
    db_path = db_path,
    run_id = "list-b"
  )
  on.exit(close(bt_b), add = TRUE)

  runs <- ledgr_run_list(db_path)
  testthat::expect_s3_class(runs, "tbl_df")
  testthat::expect_true(all(c("list-a", "list-b") %in% runs$run_id))
  testthat::expect_true(all(c(
    "run_id", "snapshot_hash", "status", "reproducibility_level",
    "strategy_source_hash", "strategy_params_hash", "config_hash",
    "final_equity", "total_return", "max_drawdown", "n_trades"
  ) %in% names(runs)))
  testthat::expect_false("config_json" %in% names(runs))
  testthat::expect_false("dependency_versions_json" %in% names(runs))
  testthat::expect_false("strategy_params_json" %in% names(runs))

  opened <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  DBI::dbExecute(opened$con, "UPDATE runs SET archived = TRUE WHERE run_id = 'list-b'")

  visible <- ledgr_run_list(db_path)
  testthat::expect_true("list-a" %in% visible$run_id)
  testthat::expect_false("list-b" %in% visible$run_id)

  all_runs <- ledgr_run_list(db_path, include_archived = TRUE)
  testthat::expect_true("list-b" %in% all_runs$run_id)
  testthat::expect_true(all_runs$archived[all_runs$run_id == "list-b"])
})

testthat::test_that("ledgr_run_info returns printable diagnostics and tolerates missing telemetry", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$targets()
    targets["TEST_A"] <- params$qty
    targets
  }

  bt <- ledgr_backtest(
    data = test_bars,
    strategy = strategy,
    strategy_params = list(qty = 1),
    start = "2020-01-01",
    end = "2020-01-05",
    db_path = db_path,
    run_id = "info-run"
  )
  on.exit(close(bt), add = TRUE)

  info <- ledgr_run_info(db_path, "info-run")
  testthat::expect_s3_class(info, "ledgr_run_info")
  testthat::expect_identical(info$run_id, "info-run")
  testthat::expect_identical(info$status, "DONE")
  testthat::expect_identical(info$telemetry_missing, TRUE)
  testthat::expect_match(info$strategy_source_hash, "^[0-9a-f]{64}$")
  testthat::expect_true("config_json" %in% names(info))
  testthat::expect_true("dependency_versions_json" %in% names(info))

  printed <- utils::capture.output(print(info))
  testthat::expect_true(any(grepl("ledgr Run Info", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("Reproducibility:", printed, fixed = TRUE)))

  opened <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  DBI::dbExecute(
    opened$con,
    "UPDATE runs SET status = 'FAILED', error_msg = 'simulated failure' WHERE run_id = 'info-run'"
  )

  failed_info <- ledgr_run_info(db_path, "info-run")
  testthat::expect_identical(failed_info$status, "FAILED")
  failed_print <- utils::capture.output(print(failed_info))
  testthat::expect_true(any(grepl("simulated failure", failed_print, fixed = TRUE)))
})

testthat::test_that("ledgr_run_open returns a handle without recomputation or mutation", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  strategy <- function(ctx) {
    calls$n <- calls$n + 1L
    targets <- ctx$targets()
    targets["TEST_A"] <- 1
    targets
  }

  bt <- ledgr_backtest(
    data = test_bars,
    strategy = strategy,
    start = "2020-01-01",
    end = "2020-01-05",
    db_path = db_path,
    run_id = "open-run"
  )
  original_calls <- calls$n
  close(bt)

  opened <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)
  before <- DBI::dbGetQuery(opened$con, "SELECT * FROM runs WHERE run_id = 'open-run'")
  before_ledger_count <- DBI::dbGetQuery(
    opened$con,
    "SELECT COUNT(*) AS n FROM ledger_events WHERE run_id = 'open-run'"
  )$n[[1]]

  calls$n <- 0L
  reopened <- ledgr_run_open(db_path, "open-run")
  on.exit(close(reopened), add = TRUE)
  testthat::expect_s3_class(reopened, "ledgr_backtest")
  testthat::expect_s3_class(reopened$config, "ledgr_config")
  testthat::expect_identical(calls$n, 0L)

  out_summary <- utils::capture.output(summary(reopened))
  testthat::expect_true(any(grepl("ledgr Backtest Summary", out_summary, fixed = TRUE)))
  equity <- tibble::as_tibble(reopened, what = "equity")
  ledger <- tibble::as_tibble(reopened, what = "ledger")
  fills <- tibble::as_tibble(reopened, what = "fills")
  trades <- ledgr_results(reopened, what = "trades")
  testthat::expect_s3_class(equity, "tbl_df")
  testthat::expect_s3_class(ledger, "tbl_df")
  testthat::expect_s3_class(fills, "tbl_df")
  testthat::expect_s3_class(trades, "tbl_df")
  if (requireNamespace("ggplot2", quietly = TRUE)) {
    testthat::expect_error(plot_obj <- plot(reopened), NA)
    testthat::expect_true(
      inherits(plot_obj, "ggplot") || inherits(plot_obj, "gtable") || inherits(plot_obj, "grob")
    )
  }

  after <- DBI::dbGetQuery(opened$con, "SELECT * FROM runs WHERE run_id = 'open-run'")
  after_ledger_count <- DBI::dbGetQuery(
    opened$con,
    "SELECT COUNT(*) AS n FROM ledger_events WHERE run_id = 'open-run'"
  )$n[[1]]
  testthat::expect_identical(before, after)
  testthat::expect_identical(before_ledger_count, after_ledger_count)
  testthat::expect_gt(original_calls, 0L)
})

testthat::test_that("ledgr_run_open rejects incomplete runs and archived completed runs still open", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  strategy <- function(ctx) ctx$targets()
  bt <- ledgr_backtest(
    data = test_bars,
    strategy = strategy,
    start = "2020-01-01",
    end = "2020-01-05",
    db_path = db_path,
    run_id = "status-run"
  )
  close(bt)

  opened <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(opened$con, opened$drv), add = TRUE)

  DBI::dbExecute(opened$con, "UPDATE runs SET archived = TRUE WHERE run_id = 'status-run'")
  archived <- ledgr_run_open(db_path, "status-run")
  testthat::expect_s3_class(archived, "ledgr_backtest")
  close(archived)

  DBI::dbExecute(
    opened$con,
    "UPDATE runs SET status = 'FAILED', error_msg = 'bad params' WHERE run_id = 'status-run'"
  )
  testthat::expect_error(
    ledgr_run_open(db_path, "status-run"),
    class = "ledgr_run_not_complete"
  )
  info <- ledgr_run_info(db_path, "status-run")
  testthat::expect_identical(info$error_msg, "bad params")
})

testthat::test_that("ledgr_run_list reads legacy stores without mutating them", {
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
      'legacy-run', TIMESTAMP '2020-01-01 00:00:00', '0.1.4',
      '{}', 'config-hash', 'window-hash', 'legacy-snapshot', 'DONE', NULL
    )
    "
  )
  ledgr_test_close_duckdb(opened$con, opened$drv)

  runs <- ledgr_run_list(db_path)
  testthat::expect_true("legacy-run" %in% runs$run_id)
  testthat::expect_identical(runs$reproducibility_level[runs$run_id == "legacy-run"], "legacy")
  testthat::expect_error(
    ledgr_run_open(db_path, "legacy-run"),
    class = "ledgr_invalid_run"
  )

  reopened <- ledgr_test_open_duckdb(db_path)
  on.exit(ledgr_test_close_duckdb(reopened$con, reopened$drv), add = TRUE)
  tables <- DBI::dbGetQuery(
    reopened$con,
    "
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'main'
    "
  )$table_name
  testthat::expect_false("run_provenance" %in% tables)
  testthat::expect_false("run_telemetry" %in% tables)
})
