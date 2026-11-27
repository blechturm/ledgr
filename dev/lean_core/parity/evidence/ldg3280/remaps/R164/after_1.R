  batch <- function(pos, qty, fee = c(0, 0)) {
    f <- list(k = 1:2, pos = pos, side = c(1L, 1L), qty = qty, price = c(10, 10), fee = fee)
    out <- tryCatch(lean_lot_fill(zero, f$pos, f$side, f$qty, f$price, f$fee), error = identity)
    out <- lean_lot_first_failure(zero, f, out)
    c(out$row, condition(stop(out$error)))
  }
