  # LR-25: the public spot_fifo path runs the lean R FIFO, so the compiled
  # append count retires, with the handler mock that attached it.
  testthat::expect_identical(ws4a_public_ovf(FALSE, 10, cash, list(S = 5), compiled = TRUE)$sweep,
    c("DONE", "1000"))
