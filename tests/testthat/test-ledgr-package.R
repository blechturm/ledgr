testthat::test_that("ledgr loads", {
  testthat::expect_true(requireNamespace("ledgr", quietly = TRUE))
})
