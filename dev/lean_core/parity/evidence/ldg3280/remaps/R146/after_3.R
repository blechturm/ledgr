  testthat::expect_error(lean_plan_execution_view(provider, 1704292200, "A"), class = "ledgr_invalid_pulse_plan")
  provider$execution_view <- function(cutoff, ids) list(member = stats::setNames(TRUE, ids),
    restricted = stats::setNames(TRUE, ids), reasons = stats::setNames("lifetime_inactive|trading_halted|lifetime_inactive", ids))
  testthat::expect_identical(lean_plan_execution_view(provider, 1704292200, "A")$reason_code, c(9L, 5L))
