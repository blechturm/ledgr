  batched <- function(f) {
    out <- ns$ledgr_fold_fill_candidate(book, f)
    if (is.null(out$failed)) "none" else c(out$failed, condition(out$error))
  }
