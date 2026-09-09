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
  exp <- ledgr_experiment(snapshot, strategy, cost_model = ledgr_cost_zero())
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
  testthat::expect_identical(context$selected_candidate$candidate_id, "b")
  testthat::expect_identical(context$selected_candidate$candidate_row, 2)
  testthat::expect_identical(context$selected_candidate$params_json, as.character(canonical_json(list(qty = 2))))
  testthat::expect_identical(context$source_sweep$sweep_id, attr(results, "sweep_id"))

  summary_ids <- vapply(context$candidate_summary, `[[`, character(1), "candidate_id")
  testthat::expect_identical(summary_ids, c("b", "a"))
  summary_rows <- vapply(context$candidate_summary, `[[`, numeric(1), "candidate_row")
  testthat::expect_identical(summary_rows, c(2, 1))
  testthat::expect_identical(context$candidate_summary[[1]]$params_json, as.character(canonical_json(list(qty = 2))))
  testthat::expect_identical(context$candidate_summary[[2]]$params_json, as.character(canonical_json(list(qty = 1))))

  by_store <- ledgr_run_promotion_context(exp, "promoted-context-run")
  testthat::expect_identical(by_store$selected_candidate$candidate_id, "b")

  bt_no_note <- ledgr_promote(exp, candidate, run_id = "promoted-context-no-note")
  on.exit(close(bt_no_note), add = TRUE)
  context_no_note <- ledgr_promotion_context(bt_no_note)
  testthat::expect_null(context_no_note$note)

  info <- ledgr_run_info(snapshot, "promoted-context-run")
  testthat::expect_identical(info$promotion_context$source_sweep$sweep_id, attr(results, "sweep_id"))
})

testthat::test_that("ranked reopened sweeps retain lineage through promotion", {
  snapshot <- ledgr_snapshot_from_df(ledgr_promotion_test_bars())
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)

  strategy <- function(ctx, params) {
    targets <- ctx$flat()
    targets["AAA"] <- params$qty
    targets
  }
  risk <- ledgr_risk_max_weight(0.20)
  sweep_exp <- ledgr_experiment(
    snapshot,
    strategy,
    risk_chain = risk,
    cost_model = ledgr_cost_zero()
  )
  results <- ledgr_sweep(
    sweep_exp,
    ledgr_param_grid(low = list(qty = 1), high = list(qty = 2)),
    seed = 123L
  )
  ledgr_sweep_save(results, snapshot, sweep_id = "review_lineage_saved")
  reopened <- ledgr_sweep_open(snapshot, "review_lineage_saved")
  before <- serialize(reopened, NULL)

  review <- ledgr_sweep_review(reopened, rank_by = -candidate_row, n = 1L)

  testthat::expect_s3_class(review$ranked, "ledgr_sweep_results")
  testthat::expect_false(inherits(review$top, "ledgr_sweep_results"))
  testthat::expect_null(attr(review$top, "sweep_id", exact = TRUE))
  testthat::expect_null(attr(review$top, "risk_chain_hash", exact = TRUE))
  testthat::expect_null(attr(review$top, "risk_plan_json", exact = TRUE))
  testthat::expect_identical(review$ranked$candidate_id, c("high", "low"))
  testthat::expect_identical(attr(review$ranked, "sweep_id", exact = TRUE), "review_lineage_saved")
  testthat::expect_identical(
    attr(review$ranked, "risk_chain_hash", exact = TRUE),
    ledgr:::ledgr_risk_chain_hash(risk)
  )
  testthat::expect_identical(serialize(reopened, NULL), before)
  testthat::expect_error(
    ledgr_candidate(review$top, 1L),
    class = "ledgr_invalid_sweep_candidate_input"
  )

  candidate <- ledgr_candidate(review$ranked, 1L)
  promote_exp <- ledgr_experiment(
    snapshot,
    strategy,
    risk_chain = ledgr_risk_none(),
    cost_model = ledgr_cost_zero()
  )
  bt <- ledgr_promote(promote_exp, candidate, run_id = "review-lineage-promotion")
  on.exit(close(bt), add = TRUE)

  context <- ledgr_promotion_context(bt)
  testthat::expect_identical(context$source_sweep$sweep_id, "review_lineage_saved")
  testthat::expect_identical(context$selected_candidate$candidate_id, "high")
  testthat::expect_identical(
    vapply(context$candidate_summary, `[[`, character(1), "candidate_id"),
    c("high", "low")
  )
  testthat::expect_identical(
    context$selected_candidate$risk_chain_hash,
    ledgr:::ledgr_risk_chain_hash(risk)
  )
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
  exp <- ledgr_experiment(snapshot, strategy, cost_model = ledgr_cost_zero())
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
  exp <- ledgr_experiment(snapshot, strategy, cost_model = ledgr_cost_zero())
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
  exp <- ledgr_experiment(snapshot, strategy, cost_model = ledgr_cost_zero())
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
