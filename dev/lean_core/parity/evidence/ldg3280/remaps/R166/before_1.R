  testthat::expect_identical(ns$ledgr_fold_fill_candidate(state$lot_state, fills(c(1e308, 1), c(0, Inf)))$failed, 1L)
