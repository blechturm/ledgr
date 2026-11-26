# One internal debug flag (Cut 24 decision 6; feature-engine stages
# synthesis rule 8). With debug on, internal hand-offs are also checked
# against the general path and a disagreement fails closed; debug changes
# assertions only, never values, records or identity. Off by default. There
# is no option, environment variable or exported function: the flag is read
# through ledgr_debug() and set only through local_ledgr_debug(), which
# restores the prior value when the calling frame exits, normally or by
# error. The testthat suite turns it on (tests/testthat/setup-debug.R); the
# parity runner and the timing workloads set it explicitly. Feature
# preparation runs in the calling process for runs, sweeps, explicit
# precompute and pulse inspection (R/sweep.R prepares before any worker
# starts), so mirai workers never read it. The lean core reuses it after the
# switch.
.ledgr_debug_state <- new.env(parent = emptyenv())
.ledgr_debug_state$on <- FALSE

ledgr_debug <- function() .ledgr_debug_state$on

local_ledgr_debug <- function(on, frame = parent.frame()) {
  if (!is.logical(on) || length(on) != 1L || is.na(on)) {
    stop("`on` must be TRUE or FALSE.", call. = FALSE)
  }
  prior <- .ledgr_debug_state$on
  .ledgr_debug_state$on <- on
  restore <- function() .ledgr_debug_state$on <- prior
  # Last in, first out, so nested settings unwind to the outermost prior.
  do.call(base::on.exit, list(as.call(list(restore)), add = TRUE, after = FALSE), envir = frame)
  invisible(prior)
}
