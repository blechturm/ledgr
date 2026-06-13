testthat::test_that("ledgr_sweep_review ranks completed rows and separates issues", {
  sweep <- tibble::tibble(
    candidate_id = c("low", "high", "failed"),
    candidate_row = 1:3,
    status = c("DONE", "DONE", "FAILED"),
    final_equity = c(100, 120, NA_real_),
    total_return = c(0, 0.2, NA_real_),
    sharpe_ratio = c(0.1, 0.4, NA_real_),
    max_drawdown = c(0.01, 0.02, NA_real_),
    n_trades = c(1L, 2L, NA_integer_),
    execution_seed = c(11L, 12L, NA_integer_),
    error_class = c(NA_character_, NA_character_, "ledgr_test_failure"),
    error_msg = c(NA_character_, NA_character_, "failed"),
    params = list(list(qty = 1), list(qty = 2), list(qty = 3)),
    feature_params = list(list(), list(), list()),
    warnings = list(list(), list(simpleWarning("review me")), list())
  )

  review <- ledgr_sweep_review(sweep, rank_by = desc(sharpe_ratio), n = 1L)

  testthat::expect_s3_class(review, "ledgr_sweep_review")
  testthat::expect_identical(review$rank_by, "desc(sharpe_ratio)")
  testthat::expect_identical(review$ranked$candidate_id, c("high", "low"))
  testthat::expect_identical(review$ranked$rank, 1:2)
  testthat::expect_identical(review$top$candidate_id, "high")
  testthat::expect_true("params" %in% names(review$top))
  testthat::expect_identical(review$issues$candidate_id, c("high", "failed"))
  testthat::expect_true("warnings" %in% names(review$issues))
  testthat::expect_false(inherits(review, "ledgr_sweep_candidate"))

  printed <- utils::capture.output(print(review, n = 1))
  testthat::expect_true(any(grepl("ledgr sweep review", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("Top candidates", printed, fixed = TRUE)))
  testthat::expect_true(any(grepl("Issue rows", printed, fixed = TRUE)))
})

testthat::test_that("ledgr_sweep_review top keeps the ranking column", {
  sweep <- tibble::tibble(
    candidate_id = c("a", "b"),
    candidate_row = 1:2,
    status = c("DONE", "DONE"),
    custom_metric = c(3, 7)
  )

  review <- ledgr_sweep_review(sweep, rank_by = desc(custom_metric), n = 1L)

  testthat::expect_identical(review$top$candidate_id, "b")
  testthat::expect_true("custom_metric" %in% names(review$top))
  testthat::expect_identical(review$top$custom_metric, 7)
})

testthat::test_that("ledgr_sweep_review validates ranking inputs", {
  sweep <- tibble::tibble(
    candidate_id = c("a", "b"),
    status = c("DONE", "DONE"),
    sharpe_ratio = c(0.1, 0.2)
  )

  testthat::expect_error(
    ledgr_sweep_review(sweep),
    class = "ledgr_invalid_args"
  )
  testthat::expect_error(
    ledgr_sweep_review(sweep, rank_by = 1),
    class = "ledgr_invalid_sweep_review_rank"
  )
  testthat::expect_error(
    ledgr_sweep_review(sweep, rank_by = sharpe_ratio, n = Inf),
    class = "ledgr_invalid_args"
  )
  testthat::expect_error(
    ledgr_sweep_review(tibble::tibble(candidate_id = "a"), rank_by = candidate_id),
    class = "ledgr_invalid_sweep_review_input"
  )
})

testthat::test_that("ledgr_temp_store returns a disposable path and clears stale files", {
  path <- ledgr_temp_store()
  testthat::expect_match(path, "[.]duckdb$")
  testthat::expect_false(file.exists(path))

  stale <- tempfile(fileext = ".duckdb")
  writeLines("stale", stale)
  writeLines("wal", paste0(stale, ".wal"))
  out <- ledgr_temp_store(path = stale)
  testthat::expect_identical(out, stale)
  testthat::expect_false(file.exists(stale))
  testthat::expect_false(file.exists(paste0(stale, ".wal")))

  testthat::expect_error(
    ledgr_temp_store(path = tempfile(fileext = ".txt")),
    class = "ledgr_invalid_args"
  )

  dir_path <- tempfile(fileext = ".duckdb")
  dir.create(dir_path)
  on.exit(unlink(dir_path, recursive = TRUE, force = TRUE), add = TRUE)
  testthat::expect_error(
    ledgr_temp_store(path = dir_path),
    class = "ledgr_invalid_args"
  )
})
