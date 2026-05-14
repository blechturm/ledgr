testthat::test_that("ledgr_derive_seed is stable and independent of ambient RNG", {
  set.seed(1)
  first <- ledgr:::ledgr_derive_seed(2026L, list(run_id = "grid_abc", params = list(n = 20L)))
  stats::runif(10)
  second <- ledgr:::ledgr_derive_seed(2026L, list(params = list(n = 20L), run_id = "grid_abc"))

  testthat::expect_identical(first, second)
  testthat::expect_type(first, "integer")
  testthat::expect_true(first >= 1L)
  testthat::expect_true(first <= 2147483647L)
  testthat::expect_identical(first, 350931654L)
})
