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
