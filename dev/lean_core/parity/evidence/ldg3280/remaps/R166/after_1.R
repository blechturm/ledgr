  canonical <- fills(c(1e308, 1), c(0, Inf))
  refused <- tryCatch(lean_lot_fill(state$lot_state, canonical$pos, canonical$side, canonical$qty, canonical$price, canonical$fee), error = identity)
  testthat::expect_s3_class(refused, "error")
  testthat::expect_identical(lean_lot_first_failure(state$lot_state, canonical, refused)$row, 1L)
