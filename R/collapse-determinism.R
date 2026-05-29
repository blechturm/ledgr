ledgr_collapse_deterministic_state <- function() {
  list(
    nthreads = 1L,
    remove = NULL,
    stable.algo = TRUE,
    sort = TRUE,
    digits = 2L,
    stub = TRUE,
    verbose = 0L,
    mask = NULL,
    na.rm = FALSE
  )
}

ledgr_with_collapse_deterministic <- function(expr) {
  old <- collapse::set_collapse()
  on.exit(do.call(collapse::set_collapse, old), add = TRUE)
  do.call(collapse::set_collapse, ledgr_collapse_deterministic_state())
  eval.parent(substitute(expr))
}
