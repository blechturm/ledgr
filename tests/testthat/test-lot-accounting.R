# LDG-3164 (decision 10): the typed fill operation (category 4) and the
# typed book (category 2) carry the same inputs and witnesses.
testthat::test_that("lot accounting fails closed on invalid fill input", {
  state <- ledgr:::ledgr_lot_book(1L)

  testthat::expect_error(
    ledgr:::ledgr_lot_fill(state, 1L, ledgr:::ledgr_lot_side(NA_character_), 1, 100, 0),
    class = "ledgr_invalid_lot_fill"
  )
  testthat::expect_error(
    ledgr:::ledgr_lot_fill(state, 1L, 1L, 0, 100, 0),
    class = "ledgr_invalid_lot_fill"
  )
  testthat::expect_error(
    ledgr:::ledgr_lot_fill(state, 1L, 1L, 1, 0, 0),
    class = "ledgr_invalid_lot_fill"
  )
  testthat::expect_error(
    ledgr:::ledgr_lot_fill(state, 1L, 1L, 1, 100, -0.01),
    class = "ledgr_invalid_lot_fill"
  )
})

testthat::test_that("lot accounting pops fractional dust lots", {
  state <- ledgr:::ledgr_lot_book(1L)
  state <- ledgr:::ledgr_lot_fill(state, 1L, 1L, 0.1, 10, 0)$book
  state <- ledgr:::ledgr_lot_fill(state, 1L, 1L, 0.2, 10, 0)$book
  state <- ledgr:::ledgr_lot_fill(state, 1L, -1L, 0.3, 10, 0)$book
  testthat::expect_identical(ledgr:::ledgr_lot_book_live_count(state, 1L), 0L)
  testthat::expect_equal(state$total_cost_basis, 0)

  short_state <- ledgr:::ledgr_lot_book(1L)
  short_state <- ledgr:::ledgr_lot_fill(short_state, 1L, -1L, 0.1, 10, 0)$book
  short_state <- ledgr:::ledgr_lot_fill(short_state, 1L, -1L, 0.2, 10, 0)$book
  short_state <- ledgr:::ledgr_lot_fill(short_state, 1L, 1L, 0.3, 10, 0)$book
  testthat::expect_identical(ledgr:::ledgr_lot_book_live_count(short_state, 1L), 0L)
  testthat::expect_equal(short_state$total_cost_basis, 0)
})
