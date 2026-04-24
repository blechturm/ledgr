#' ledgr: Deterministic Event-Sourced Backtesting
#'
#' Correctness-first, event-sourced backtesting with sealed data snapshots,
#' deterministic replay, no-lookahead strategy execution, and ledger-derived
#' results.
#'
#' @keywords internal
"_PACKAGE"

.onLoad <- function(libname, pkgname) {
  ledgr_register_indicator(ledgr_ind_sma(50), "sma_50")
  ledgr_register_indicator(ledgr_ind_sma(200), "sma_200")
  ledgr_register_indicator(ledgr_ind_ema(12), "ema_12")
  ledgr_register_indicator(ledgr_ind_ema(26), "ema_26")
  ledgr_register_indicator(ledgr_ind_rsi(14), "rsi_14")
  ledgr_register_indicator(ledgr_ind_returns(1), "return_1")
  invisible(NULL)
}

