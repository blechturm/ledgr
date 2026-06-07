ledgr_sweep_retention_schema_version <- 1L

#' Sweep retention policy
#'
#' `ledgr_sweep_retention()` creates a classed retention policy for
#' [ledgr_sweep()]. Retention controls which optional sweep evidence is kept in
#' memory or later persisted. It is not part of execution identity.
#'
#' @param returns Character scalar. `"none"` keeps the current scalar-only sweep
#'   output. `"completed"` requests retained net equity/return series for
#'   completed candidates once retained-series capture is available.
#' @return A `ledgr_sweep_retention` object.
#' @export
ledgr_sweep_retention <- function(returns = c("none", "completed")) {
  if (missing(returns)) {
    returns <- "none"
  }
  if (!is.character(returns) ||
      length(returns) != 1L ||
      is.na(returns) ||
      !returns %in% c("none", "completed")) {
    rlang::abort(
      "`returns` must be one of \"none\" or \"completed\".",
      class = c("ledgr_invalid_sweep_retention", "ledgr_invalid_args")
    )
  }
  structure(
    list(
      retention_schema_version = ledgr_sweep_retention_schema_version,
      returns = unname(returns)
    ),
    class = c("ledgr_sweep_retention", "list")
  )
}

ledgr_sweep_retention_normalize <- function(retain) {
  if (!inherits(retain, "ledgr_sweep_retention")) {
    rlang::abort(
      "`retain` must be created with ledgr_sweep_retention().",
      class = c("ledgr_invalid_sweep_retention", "ledgr_invalid_args")
    )
  }
  if (!is.list(retain) ||
      !identical(retain$retention_schema_version, ledgr_sweep_retention_schema_version) ||
      !is.character(retain$returns) ||
      length(retain$returns) != 1L ||
      is.na(retain$returns) ||
      !retain$returns %in% c("none", "completed")) {
    rlang::abort(
      "`retain` has an invalid ledgr sweep retention shape.",
      class = c("ledgr_invalid_sweep_retention", "ledgr_invalid_args")
    )
  }
  ledgr_sweep_retention(retain$returns)
}
