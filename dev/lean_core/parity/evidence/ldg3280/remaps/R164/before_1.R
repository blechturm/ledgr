  batch <- function(pos, qty, fee = c(0, 0)) {
    out <- ns$ledgr_fold_fill_candidate(zero, list(k = 1:2, pos = pos, side = c(1L, 1L), qty = qty, price = c(10, 10), fee = fee))
    c(out$failed, condition(stop(out$error)))
  }
