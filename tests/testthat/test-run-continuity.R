# Cut 10 real-data run continuity (LDG-2973 to LDG-2975).

continuity_bars <- function() {
  data.frame(
    instrument_id = rep(c("AAA", "BBB"), each = 5),
    ts_utc = rep(as.POSIXct("2020-01-06 21:00:00", tz = "UTC") + 86400 * 0:4, 2),
    open = rep(c(10, 20), each = 5), high = rep(c(10, 20), each = 5),
    low = rep(c(10, 20), each = 5), close = rep(c(10, 20), each = 5), volume = 100
  )
}

continuity_run_row <- function(snapshot, run_id) {
  DBI::dbGetQuery(
    ledgr:::get_connection(snapshot),
    "SELECT status, error_msg FROM runs WHERE run_id = ?",
    params = list(run_id)
  )
}

testthat::test_that("[LTB-0198] an early exit after registration records FAILED and still propagates", {
  snapshot <- ledgr_snapshot_from_df(continuity_bars(), db_path = tempfile(fileext = ".duckdb"))
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  hold <- function(ctx, params) ctx$hold()
  buy <- function(ctx, params) {
    target <- ctx$flat()
    target[["AAA"]] <- 1
    target
  }
  exp_with <- function(features, strategy = hold) {
    ledgr_experiment(snapshot, strategy, features = features, opening = ledgr_opening(cash = 1000),
                     cost_model = ledgr_cost_zero())
  }
  failing <- ledgr_indicator(id = "boom", requires_bars = 1L, fn = function(window) stop("feature exploded"))
  # One definition, so a rerun resumes the same row; the option picks the exit.
  interrupting <- ledgr_indicator(id = "halt", requires_bars = 1L, fn = function(window) {
    if (identical(getOption("ledgr.test.continuity_exit"), "error")) stop("second attempt failed")
    rlang::interrupt()
  })

  # An error during feature computation, before the pulse loop.
  testthat::expect_error(ledgr_run(exp_with(list(failing)), run_id = "early-error"), "feature exploded")
  row <- continuity_run_row(snapshot, "early-error")
  testthat::expect_identical(row$status, "FAILED")
  testthat::expect_match(row$error_msg, "feature exploded", fixed = TRUE)

  # An interrupt is observed, recorded and still reaches the caller.
  got <- tryCatch(ledgr_run(exp_with(list(interrupting)), run_id = "early-interrupt"),
                  interrupt = function(e) "interrupted")
  testthat::expect_identical(got, "interrupted")
  row <- continuity_run_row(snapshot, "early-interrupt")
  testthat::expect_identical(row$status, "FAILED")
  testthat::expect_identical(row$error_msg, "Run interrupted before completion.")

  # A resumed row that already says FAILED takes the new attempt's message.
  old <- options(ledgr.test.continuity_exit = "error")
  testthat::expect_error(ledgr_run(exp_with(list(interrupting)), run_id = "early-interrupt"), "second attempt failed")
  options(old)
  row <- continuity_run_row(snapshot, "early-interrupt")
  testthat::expect_identical(row$status, "FAILED")
  testthat::expect_match(row$error_msg, "second attempt failed", fixed = TRUE)

  # Normal endings and the soft stop are untouched.
  done <- ledgr_run(exp_with(list(), buy), run_id = "normal-done")
  close(done)
  row <- continuity_run_row(snapshot, "normal-done")
  testthat::expect_identical(row$status, "DONE")
  testthat::expect_true(is.na(row$error_msg))
  old <- options(ledgr.interrupt = TRUE)
  soft <- ledgr_run(exp_with(list(), buy), run_id = "soft-stop")
  options(old)
  close(soft)
  row <- continuity_run_row(snapshot, "soft-stop")
  testthat::expect_identical(row$status, "RUNNING")
  testthat::expect_true(is.na(row$error_msg))
})
