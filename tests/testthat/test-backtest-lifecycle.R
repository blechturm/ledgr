testthat::test_that("close.ledgr_backtest checkpoints and is idempotent", {
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
    run_id = "close-idempotent"
  )

  testthat::expect_error(close(bt), NA)
  testthat::expect_error(close(bt), NA)

  info <- ledgr_run_info(snapshot, "close-idempotent")
  testthat::expect_identical(info$status, "DONE")
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
    run_id = "gc-checkpoint"
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

testthat::test_that("in-memory backtest handles do not require close", {
  bt <- ledgr:::new_ledgr_backtest("memory-no-close", ":memory:", config = list())
  testthat::expect_error(close(bt), NA)

  bt <- ledgr:::new_ledgr_backtest("memory-no-close-2", ":memory:", config = list())

  testthat::expect_silent(ledgr:::ledgr_backtest_auto_checkpoint_state(bt$.state))
  testthat::expect_true(isTRUE(bt$.state$auto_checkpointed))
})
