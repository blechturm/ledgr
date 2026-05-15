ledgr_promotion_test_bars <- function(offset = 0) {
  data.frame(
    ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:5,
    instrument_id = "AAA",
    open = 100:105 + offset,
    high = 101:106 + offset,
    low = 99:104 + offset,
    close = 100:105 + offset,
    volume = 1000,
    stringsAsFactors = FALSE
  )
}

testthat::test_that("promoted runs write and read durable promotion context", {
  snapshot <- ledgr_snapshot_from_df(ledgr_promotion_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["AAA"] <- params$qty
    targets
  }
  exp <- ledgr_experiment(snapshot, strategy)
  grid <- ledgr_param_grid(a = list(qty = 1), b = list(qty = 2))
  results <- ledgr_sweep(exp, grid, seed = 123L)
  selection <- results[c(2, 1), ]
  candidate <- ledgr_candidate(selection, 1)

  bt <- ledgr_promote(
    exp,
    candidate,
    run_id = "promoted-context-run",
    note = "selected from reordered view"
  )
  on.exit(close(bt), add = TRUE)

  context <- ledgr_promotion_context(bt)
  testthat::expect_type(context, "list")
  testthat::expect_identical(context$promotion_context_version, "ledgr_promotion_v1")
  testthat::expect_identical(context$source, "ledgr_promote")
  testthat::expect_identical(context$note, "selected from reordered view")
  testthat::expect_identical(context$selected_candidate$run_id, "b")
  testthat::expect_identical(context$selected_candidate$params_json, as.character(canonical_json(list(qty = 2))))
  testthat::expect_identical(context$source_sweep$sweep_id, attr(results, "sweep_id"))

  summary_ids <- vapply(context$candidate_summary, `[[`, character(1), "run_id")
  testthat::expect_identical(summary_ids, c("b", "a"))
  testthat::expect_identical(context$candidate_summary[[1]]$params_json, as.character(canonical_json(list(qty = 2))))
  testthat::expect_identical(context$candidate_summary[[2]]$params_json, as.character(canonical_json(list(qty = 1))))

  by_store <- ledgr_run_promotion_context(exp, "promoted-context-run")
  testthat::expect_identical(by_store$selected_candidate$run_id, "b")

  bt_no_note <- ledgr_promote(exp, candidate, run_id = "promoted-context-no-note")
  on.exit(close(bt_no_note), add = TRUE)
  context_no_note <- ledgr_promotion_context(bt_no_note)
  testthat::expect_null(context_no_note$note)

  info <- ledgr_run_info(snapshot, "promoted-context-run")
  testthat::expect_identical(info$promotion_context$source_sweep$sweep_id, attr(results, "sweep_id"))
})

testthat::test_that("direct runs return NULL promotion context without executing strategy", {
  snapshot <- ledgr_snapshot_from_df(ledgr_promotion_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  strategy <- function(ctx, params) {
    calls$n <- calls$n + 1L
    ctx$flat()
  }
  exp <- ledgr_experiment(snapshot, strategy)
  bt <- ledgr_run(exp, params = list(), run_id = "direct-run")
  on.exit(close(bt), add = TRUE)

  calls$n <- 0L
  testthat::expect_null(ledgr_promotion_context(bt))
  testthat::expect_identical(calls$n, 0L)
  testthat::expect_null(ledgr_run_promotion_context(exp, "direct-run"))
  testthat::expect_identical(calls$n, 0L)
  info <- ledgr_run_info(snapshot, "direct-run")
  testthat::expect_null(info$promotion_context)
  testthat::expect_identical(calls$n, 0L)
})

testthat::test_that("promotion context stores warning summaries only", {
  snapshot <- ledgr_snapshot_from_df(ledgr_promotion_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    rlang::warn("candidate warning", class = "ledgr_test_promotion_warning")
    ctx$flat()
  }
  exp <- ledgr_experiment(snapshot, strategy)
  grid <- ledgr_param_grid(candidate = list())
  results <- ledgr_sweep(exp, grid)
  candidate <- ledgr_candidate(results, "candidate")

  bt <- suppressWarnings(ledgr_promote(exp, candidate, run_id = "warning-context-run"))
  on.exit(close(bt), add = TRUE)
  context <- ledgr_promotion_context(bt)

  testthat::expect_identical(context$candidate_summary[[1]]$n_warnings, 6L)
  testthat::expect_true(is.character(context$candidate_summary[[1]]$warning_classes))
  testthat::expect_true("ledgr_test_promotion_warning" %in% context$candidate_summary[[1]]$warning_classes)
})

testthat::test_that("promotion context write failures warn without rolling back the run", {
  snapshot <- ledgr_snapshot_from_df(ledgr_promotion_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) ctx$flat()
  exp <- ledgr_experiment(snapshot, strategy)
  candidate <- ledgr_candidate(ledgr_sweep(exp, ledgr_param_grid(candidate = list())), "candidate")
  candidate$selection_view$params[[1]] <- list(non_serializable = new.env(parent = emptyenv()))

  bt <- NULL
  testthat::expect_warning(
    bt <- ledgr_promote(exp, candidate, run_id = "context-write-failed"),
    class = "ledgr_promotion_context_write_failed"
  )
  on.exit(close(bt), add = TRUE)
  testthat::expect_s3_class(bt, "ledgr_backtest")
  con <- get_connection(snapshot)
  row <- DBI::dbGetQuery(con, "SELECT status FROM runs WHERE run_id = 'context-write-failed'")
  testthat::expect_identical(row$status[[1]], "DONE")
})
