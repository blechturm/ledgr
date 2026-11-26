# Cut 24 decision 6 (LDG-3262): ledgr's internal debug flag.

testthat::test_that("[Cut 24 debug] the flag defaults off and the suite turns it on", {
  testthat::expect_false(ledgr_test_debug_prior)
  testthat::expect_true(ledgr:::ledgr_debug())
})

testthat::test_that("[Cut 24 debug] the local setter restores the prior value on every exit", {
  outer <- ledgr:::ledgr_debug()
  normal <- function() {
    ledgr:::local_ledgr_debug(!outer)
    ledgr:::ledgr_debug()
  }
  testthat::expect_identical(normal(), !outer)
  testthat::expect_identical(ledgr:::ledgr_debug(), outer)

  failing <- function() {
    ledgr:::local_ledgr_debug(!outer)
    stop("inside")
  }
  testthat::expect_error(failing(), "inside")
  testthat::expect_identical(ledgr:::ledgr_debug(), outer)

  nested <- function() {
    ledgr:::local_ledgr_debug(FALSE)
    ledgr:::local_ledgr_debug(TRUE)
    inner <- ledgr:::ledgr_debug()
    c(inner, (function() {
      ledgr:::local_ledgr_debug(FALSE)
      ledgr:::ledgr_debug()
    })(), ledgr:::ledgr_debug())
  }
  testthat::expect_identical(nested(), c(TRUE, FALSE, TRUE))
  testthat::expect_identical(ledgr:::ledgr_debug(), outer)

  testthat::expect_identical(
    (function() ledgr:::local_ledgr_debug(FALSE))(),
    outer
  )
  for (bad in list(NA, 1L, c(TRUE, FALSE), "TRUE", NULL)) {
    testthat::expect_error(ledgr:::local_ledgr_debug(bad), "TRUE or FALSE")
  }
  testthat::expect_identical(ledgr:::ledgr_debug(), outer)
})

testthat::test_that("[Cut 24 debug] the flag has no public surface", {
  exports <- getNamespaceExports("ledgr")
  testthat::expect_false(any(c("ledgr_debug", "local_ledgr_debug") %in% exports))
  testthat::expect_false(any(grepl("debug", names(options()), fixed = TRUE) & grepl("ledgr", names(options()), fixed = TRUE)))
  # The flag reads no option or environment variable.
  source <- deparse(ledgr:::ledgr_debug)
  testthat::expect_false(any(grepl("getOption|Sys.getenv", source)))
  testthat::expect_false(any(grepl("getOption|Sys.getenv", deparse(ledgr:::local_ledgr_debug))))
})
