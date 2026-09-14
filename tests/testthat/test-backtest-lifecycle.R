testthat::test_that("closed durable handles remain read-only locators across sessions", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snapshot <- ledgr_snapshot_from_df(test_bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  snapshot_id <- snapshot$snapshot_id
  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  strategy <- function(ctx, params) {
    calls$n <- calls$n + 1L
    targets <- ctx$flat()
    targets["TEST_A"] <- 1
    targets
  }

  bt <- ledgr_backtest(
    snapshot = snapshot,
    strategy = strategy,
    start = "2020-01-01",
    end = "2020-01-05",
    db_path = db_path,
    run_id = "close-idempotent",
    cost_model = ledgr_cost_zero()
  )
  calls_after_run <- calls$n
  locator <- bt[c("run_id", "db_path")]
  expected_equity <- ledgr_results(bt, what = "equity")
  expected_fills <- ledgr_results(bt, what = "fills")

  store_contents <- function() {
    opened <- ledgr:::ledgr_run_store_open(db_path)
    on.exit(ledgr:::ledgr_run_store_close(opened), add = TRUE)
    tables <- DBI::dbGetQuery(
      opened$con,
      paste(
        "SELECT table_name FROM information_schema.tables",
        "WHERE table_schema = 'main' AND table_type = 'BASE TABLE'",
        "ORDER BY table_name"
      )
    )$table_name
    stats::setNames(
      lapply(
        tables,
        function(table) {
          sql <- paste(
            "SELECT * FROM",
            DBI::dbQuoteIdentifier(opened$con, table),
            "ORDER BY ALL"
          )
          DBI::dbGetQuery(opened$con, sql)
        }
      ),
      tables
    )
  }

  before <- store_contents()
  ledgr:::ledgr_backtest_open(bt)
  testthat::expect_true(DBI::dbIsValid(bt$.state$con))

  testthat::expect_error(close(bt), NA)
  testthat::expect_error(close(bt), NA)
  testthat::expect_true(is.null(bt$.state$con))
  testthat::expect_true(is.null(bt$.state$drv))
  testthat::expect_identical(bt[c("run_id", "db_path")], locator)
  testthat::expect_identical(ledgr_results(bt, what = "equity"), expected_equity)
  testthat::expect_identical(ledgr_results(bt, what = "fills"), expected_fills)
  testthat::expect_true(is.null(bt$.state$con))

  info <- ledgr_run_info(snapshot, "close-idempotent")
  testthat::expect_identical(info$status, "DONE")
  testthat::expect_identical(calls$n, calls_after_run)
  testthat::expect_identical(store_contents(), before)

  ledgr_snapshot_close(snapshot)
  reopened_snapshot <- ledgr_snapshot_open(db_path, snapshot_id, verify = TRUE)
  on.exit(ledgr_snapshot_close(reopened_snapshot), add = TRUE)
  reopened <- ledgr_run_open(reopened_snapshot, "close-idempotent")
  on.exit(close(reopened), add = TRUE)

  testthat::expect_identical(reopened[c("run_id", "db_path")], locator)
  testthat::expect_identical(
    ledgr_results(reopened, what = "equity"),
    expected_equity
  )
  testthat::expect_identical(
    ledgr_results(reopened, what = "fills"),
    expected_fills
  )
  testthat::expect_identical(calls$n, calls_after_run)
  testthat::expect_identical(store_contents(), before)
})

testthat::test_that("durable backtest safety net checkpoints and messages", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snapshot <- ledgr_snapshot_from_df(test_bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["TEST_A"] <- 1
    targets
  }

  bt <- ledgr_backtest(
    snapshot = snapshot,
    strategy = strategy,
    start = "2020-01-01",
    end = "2020-01-05",
    db_path = db_path,
    run_id = "gc-checkpoint",
  cost_model = ledgr_cost_zero()
  )
  ledgr:::ledgr_backtest_open(bt)
  state <- bt$.state
  assign("auto_checkpoint_message_emitted", FALSE, envir = ledgr:::.ledgr_backtest_lifecycle_registry)

  testthat::expect_message(
    ledgr:::ledgr_backtest_auto_checkpoint_state(state),
    "ledgr auto-checkpointed durable run 'gc-checkpoint'",
    fixed = TRUE
  )
  testthat::expect_true(isTRUE(state$auto_checkpointed))
  testthat::expect_true(is.null(state$con))
  testthat::expect_true(is.null(state$drv))

  info <- ledgr_run_info(snapshot, "gc-checkpoint")
  testthat::expect_identical(info$status, "DONE")
})

testthat::test_that("ordinary result access does not keep durable run files locked", {
  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  snapshot <- ledgr_snapshot_from_df(test_bars, db_path = db_path)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["TEST_A"] <- params$qty
    targets
  }
  exp <- ledgr_experiment(
    snapshot = snapshot,
    strategy = strategy,
    opening = ledgr_opening(cash = 10000),
  cost_model = ledgr_cost_zero()
  )
  ledgr_snapshot_close(snapshot)

  bt_first <- ledgr_run(exp, params = list(qty = 1), run_id = "result-access-first")
  on.exit(close(bt_first), add = TRUE)

  testthat::expect_s3_class(ledgr_results(bt_first, what = "equity"), "ledgr_result_table")
  testthat::expect_output(summary(bt_first), "ledgr Backtest Summary")
  testthat::expect_true(is.null(bt_first$.state$con))

  bt_second <- ledgr_run(exp, params = list(qty = 2), run_id = "result-access-second")
  on.exit(close(bt_second), add = TRUE)

  info <- ledgr_run_info(snapshot, "result-access-second")
  testthat::expect_identical(info$status, "DONE")
})

testthat::test_that("in-memory backtest handles do not require close", {
  bt <- ledgr:::new_ledgr_backtest("memory-no-close", ":memory:", config = list())
  testthat::expect_error(close(bt), NA)

  bt <- ledgr:::new_ledgr_backtest("memory-no-close-2", ":memory:", config = list())

  testthat::expect_silent(ledgr:::ledgr_backtest_auto_checkpoint_state(bt$.state))
  testthat::expect_true(isTRUE(bt$.state$auto_checkpointed))
})
