testthat::test_that("plot.ledgr_backtest dispatches and returns a plot object", {
  testthat::skip_if_not_installed("ggplot2")

  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  bt <- ledgr_backtest(
    data = test_bars,
    strategy = test_strategy,
    start = "2020-01-01",
    end = "2020-01-15",
    db_path = db_path
  )

  out <- testthat::expect_error(suppressMessages(plot(bt)), NA)
  testthat::expect_true(inherits(out, "ggplot") || inherits(out, "gtable"))
})

testthat::test_that("plot.ledgr_backtest has dependency fallbacks", {
  testthat::skip_if_not_installed("ggplot2")

  db_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db_path), add = TRUE)

  bt <- ledgr_backtest(
    data = test_bars,
    strategy = test_strategy,
    start = "2020-01-01",
    end = "2020-01-15",
    db_path = db_path
  )

  testthat::local_mocked_bindings(
    ledgr_has_namespace = function(pkg) {
      if (identical(pkg, "gridExtra")) return(FALSE)
      requireNamespace(pkg, quietly = TRUE)
    }
  )
  testthat::expect_message(
    out <- plot(bt),
    "gridExtra"
  )
  testthat::expect_s3_class(out, "ggplot")

  testthat::local_mocked_bindings(
    ledgr_has_namespace = function(pkg) FALSE
  )
  testthat::expect_error(
    plot(bt),
    "ggplot2",
    class = "ledgr_missing_package"
  )
})
