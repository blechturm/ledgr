#' Run a backtest (v0.1.2)
#'
#' Thin wrapper around the canonical engine entrypoint `ledgr_run()`.
#'
#' @param config A config list (or JSON string) matching the v0.1.0 config contract.
#' @param run_id Optional run identifier to resume or reuse.
#' @return A list with `run_id` and `db_path`.
#' @export
ledgr_backtest <- function(config, run_id = NULL) {
  ledgr_run(config = config, run_id = run_id)
}

ledgr_run <- function(config, run_id = NULL) {
  ledgr_backtest_run(config = config, run_id = run_id)
}
