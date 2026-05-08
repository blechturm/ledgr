#' ledgr: Deterministic Event-Sourced Backtesting
#'
#' Correctness-first, event-sourced backtesting with sealed data snapshots,
#' deterministic replay, no-lookahead strategy execution, and ledger-derived
#' results.
#'
#' @section Start here:
#' Installed vignettes can be discovered interactively with:
#'
#' `vignette(package = "ledgr")`
#'
#' Noninteractive `Rscript` and agent workflows can locate installed article
#' files with:
#'
#' `system.file("doc", package = "ledgr")`
#'
#' Core installed articles:
#' - `vignette("getting-started", package = "ledgr")`
#' - `system.file("doc", "getting-started.html", package = "ledgr")`
#' - `vignette("strategy-development", package = "ledgr")`
#' - `system.file("doc", "strategy-development.html", package = "ledgr")`
#' - `vignette("metrics-and-accounting", package = "ledgr")`
#' - `system.file("doc", "metrics-and-accounting.html", package = "ledgr")`
#' - `vignette("experiment-store", package = "ledgr")`
#' - `system.file("doc", "experiment-store.html", package = "ledgr")`
#' - `vignette("indicators", package = "ledgr")`
#' - `system.file("doc", "indicators.html", package = "ledgr")`
#'
#' @section Ecosystem:
#' ledgr connects to the R finance ecosystem through adapters. The core owns
#' the deterministic path from data to pulse, decision, fill, ledger event, and
#' portfolio state. Data vendors, indicator libraries, visualization tools, and
#' downstream analytics can plug in at adapter boundaries while the canonical
#' execution path remains unchanged.
#'
#' ledgr is not intended to replace every finance package. It is for workflows
#' where sealed snapshots, no-lookahead pulse execution, event-sourced ledgers,
#' and reproducible run identity matter more than an all-in-one interface. For
#' positioning detail, see the pkgdown-only "Who ledgr is for" article:
#' `https://blechturm.github.io/ledgr/articles/who-ledgr-is-for.html`.
#'
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

