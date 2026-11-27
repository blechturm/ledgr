  batched <- function(f) {
    out <- tryCatch(lean_lot_fill(book, f$pos, f$side, f$qty, f$price, f$fee), error = identity)
    if (!inherits(out, "error")) return("none")
    out <- lean_lot_first_failure(book, f, out)
    c(out$row, condition(out$error))
  }
