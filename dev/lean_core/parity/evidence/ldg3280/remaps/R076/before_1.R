  # The accessor returns NULL for an unseeded fold and one element otherwise.
  testthat::expect_null(ledgr:::ledgr_pulse_seed_at(list(pulse_seeds = NULL), 3L))
  five <- ledgr:::ledgr_pulse_seeds(7L, 1:5)
  testthat::expect_identical(ledgr:::ledgr_pulse_seed_at(list(pulse_seeds = five), 3L), five[[3L]])
})
