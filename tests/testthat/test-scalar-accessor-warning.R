# ledgr-test-profile: fast
testthat::test_that("[LTB-0067] retired scalar-loop warnings and readers stay absent", {
  bars <- ledgr_test_make_bars(c("AAA", "BBB"), as.Date("2020-01-01") + 0:2)
  snapshot <- ledgr_snapshot_from_df(bars)
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  seen <- new.env(parent = emptyenv())
  seen$warnings <- character()
  strategy <- function(ctx, params) {
    withCallingHandlers(
      {
        first <- ctx$close
        second <- ctx$close
        testthat::expect_identical(first, second)
      },
      warning = function(cnd) {
        seen$warnings <- c(seen$warnings, conditionMessage(cnd))
        invokeRestart("muffleWarning")
      }
    )
    testthat::expect_error(ctx$vec, class = "ledgr_unknown_context_field")
    testthat::expect_error(ctx$feature, class = "ledgr_unknown_context_field")
    testthat::expect_error(ctx$features, class = "ledgr_unknown_context_field")
    ctx$hold()
  }
  run <- ledgr_run(ledgr_experiment(
    snapshot, strategy,
    opening = ledgr_opening(cash = 1000),
    cost_model = ledgr_cost_zero()
  ))
  on.exit(close(run), add = TRUE)
  testthat::expect_identical(seen$warnings, character())
})
