testthat::test_that("collapse deterministic wrapper pins and restores caller settings", {
  testthat::skip_if_not_installed("collapse")
  original <- collapse::set_collapse()
  on.exit(do.call(collapse::set_collapse, original), add = TRUE)

  hostile <- original
  hostile$nthreads <- 2L
  hostile$na.rm <- TRUE
  hostile$sort <- FALSE
  hostile$stable.algo <- FALSE
  hostile$verbose <- 0L
  do.call(collapse::set_collapse, hostile)

  observed <- ledgr:::ledgr_with_collapse_deterministic({
    collapse::set_collapse()
  })

  testthat::expect_identical(observed, ledgr:::ledgr_collapse_deterministic_state())
  testthat::expect_identical(collapse::set_collapse(), hostile)
})

testthat::test_that("collapse deterministic wrapper restores settings after errors", {
  testthat::skip_if_not_installed("collapse")
  original <- collapse::set_collapse()
  on.exit(do.call(collapse::set_collapse, original), add = TRUE)

  hostile <- original
  hostile$nthreads <- 2L
  hostile$na.rm <- TRUE
  hostile$sort <- FALSE
  hostile$stable.algo <- FALSE
  hostile$verbose <- 0L
  do.call(collapse::set_collapse, hostile)

  testthat::expect_error(
    ledgr:::ledgr_with_collapse_deterministic({
      rlang::abort("boom", class = "ledgr_test_error")
    }),
    class = "ledgr_test_error"
  )
  testthat::expect_identical(collapse::set_collapse(), hostile)
})

testthat::test_that("hostile caller settings cannot alter wrapper-scoped value-bearing collapse output", {
  testthat::skip_if_not_installed("collapse")
  original <- collapse::set_collapse()
  on.exit(do.call(collapse::set_collapse, original), add = TRUE)

  x <- c(1, NA_real_, 3)
  deterministic <- ledgr:::ledgr_with_collapse_deterministic({
    collapse::fmean(x)
  })

  hostile <- original
  hostile$nthreads <- 2L
  hostile$na.rm <- TRUE
  hostile$sort <- FALSE
  hostile$stable.algo <- FALSE
  hostile$verbose <- 0L
  do.call(collapse::set_collapse, hostile)

  unwrapped_hostile <- collapse::fmean(x)
  wrapped_hostile <- ledgr:::ledgr_with_collapse_deterministic({
    collapse::fmean(x)
  })

  testthat::expect_false(identical(unwrapped_hostile, deterministic))
  testthat::expect_identical(wrapped_hostile, deterministic)
  testthat::expect_true(is.na(wrapped_hostile))
})
