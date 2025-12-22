#' ledgr: Event-Sourced Trading Framework Skeleton
#'
#' Correctness-first, event-sourced scaffolding for a trading lifecycle.
#' This package currently contains structure only; see
#' `inst/design/ledgr_design_document.md` for the binding specification.
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

