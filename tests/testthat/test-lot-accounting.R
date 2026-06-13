testthat::test_that("lot accounting fails closed on invalid fill input", {
  state <- ledgr:::ledgr_lot_state("AAA")

  testthat::expect_error(
    ledgr:::ledgr_lot_apply_fill(state, "AAA", NA_character_, 1, 100, 0),
    class = "ledgr_invalid_lot_fill"
  )
  testthat::expect_error(
    ledgr:::ledgr_lot_apply_fill(state, "AAA", "BUY", 0, 100, 0),
    class = "ledgr_invalid_lot_fill"
  )
  testthat::expect_error(
    ledgr:::ledgr_lot_apply_fill(state, "AAA", "BUY", 1, 0, 0),
    class = "ledgr_invalid_lot_fill"
  )
  testthat::expect_error(
    ledgr:::ledgr_lot_apply_fill(state, "AAA", "BUY", 1, 100, -0.01),
    class = "ledgr_invalid_lot_fill"
  )
})

testthat::test_that("lot accounting pops fractional dust lots", {
  state <- ledgr:::ledgr_lot_state("AAA")
  state <- ledgr:::ledgr_lot_apply_fill(state, "AAA", "BUY", 0.1, 10, 0)$state
  state <- ledgr:::ledgr_lot_apply_fill(state, "AAA", "BUY", 0.2, 10, 0)$state
  state <- ledgr:::ledgr_lot_apply_fill(state, "AAA", "SELL", 0.3, 10, 0)$state
  testthat::expect_length(ledgr:::ledgr_lot_get(state, "AAA"), 0L)
  testthat::expect_equal(state$total_cost_basis, 0)

  short_state <- ledgr:::ledgr_lot_state("AAA")
  short_state <- ledgr:::ledgr_lot_apply_fill(short_state, "AAA", "SELL", 0.1, 10, 0)$state
  short_state <- ledgr:::ledgr_lot_apply_fill(short_state, "AAA", "SELL", 0.2, 10, 0)$state
  short_state <- ledgr:::ledgr_lot_apply_fill(short_state, "AAA", "BUY", 0.3, 10, 0)$state
  testthat::expect_length(ledgr:::ledgr_lot_get(short_state, "AAA"), 0L)
  testthat::expect_equal(short_state$total_cost_basis, 0)
})
