testthat::test_that("ledgr_param_grid preserves named labels and params", {
  grid <- ledgr_param_grid(
    conservative = list(threshold = 0.01, qty = 1),
    aggressive = list(threshold = 0.03, qty = 3)
  )

  testthat::expect_s3_class(grid, "ledgr_param_grid")
  testthat::expect_identical(grid$labels, c("conservative", "aggressive"))
  testthat::expect_identical(grid$params[[1]]$threshold, 0.01)
  testthat::expect_identical(grid$params[[2]]$qty, 3)
})

testthat::test_that("ledgr_param_grid generates stable labels for unnamed params", {
  grid_a <- ledgr_param_grid(list(qty = 1, threshold = 0.01))
  grid_b <- ledgr_param_grid(list(threshold = 0.01, qty = 1))

  testthat::expect_match(grid_a$labels, "^grid_[0-9a-f]{12}$")
  testthat::expect_identical(grid_a$labels, grid_b$labels)
})

testthat::test_that("ledgr_param_grid rejects duplicate labels and invalid entries", {
  testthat::expect_error(
    ledgr_param_grid(a = list(qty = 1), a = list(qty = 2)),
    class = "ledgr_duplicate_param_grid_labels"
  )
  testthat::expect_error(
    ledgr_param_grid(list(qty = 1), list(qty = 1)),
    class = "ledgr_duplicate_param_grid_labels"
  )
  testthat::expect_error(
    ledgr_param_grid(bad = "not-a-list"),
    class = "ledgr_invalid_param_grid"
  )
  testthat::expect_error(
    ledgr_param_grid(bad = list(fn = function(x) x)),
    "unsupported",
    ignore.case = TRUE
  )
  testthat::expect_error(
    ledgr_param_grid(),
    class = "ledgr_invalid_args"
  )
})

testthat::test_that("ledgr_param_grid prints its non-executing contract", {
  grid <- ledgr_param_grid(a = list(qty = 1), list(qty = 2))
  out <- utils::capture.output(print(grid))

  testthat::expect_true(any(grepl("ledgr_param_grid", out, fixed = TRUE)))
  testthat::expect_true(any(grepl("Combinations: 2", out, fixed = TRUE)))
  testthat::expect_true(any(grepl("not run IDs", out, fixed = TRUE)))
  testthat::expect_true(any(grepl("sweep/tune execution is not exported", out, fixed = TRUE)))
})

testthat::test_that("v0.1.7 does not export sweep or tune execution APIs", {
  exports <- getNamespaceExports("ledgr")
  testthat::expect_false("ledgr_sweep" %in% exports)
  testthat::expect_false("ledgr_tune" %in% exports)
})
