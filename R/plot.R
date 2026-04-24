# Internal dependency probe; separated for tests.
ledgr_has_namespace <- function(pkg) {
  requireNamespace(pkg, quietly = TRUE)
}

#' Plot backtest results
#'
#' @param x A `ledgr_backtest` object.
#' @param y Unused.
#' @param ... Unused.
#' @param type Plot type. Only `"equity"` is supported in v0.1.2.
#' @return A ggplot object, or a grid object when `gridExtra` is installed.
#' @export
plot.ledgr_backtest <- function(x, y = NULL, ..., type = "equity") {
  if (!inherits(x, "ledgr_backtest")) {
    rlang::abort("`x` must be a ledgr_backtest object.", class = "ledgr_invalid_backtest")
  }
  type <- match.arg(type, c("equity"))
  if (!ledgr_has_namespace("ggplot2")) {
    rlang::abort(
      "plot.ledgr_backtest() requires the optional package 'ggplot2'. Install it with install.packages('ggplot2').",
      class = "ledgr_missing_package"
    )
  }

  equity <- ledgr_compute_equity_curve(x)
  if (nrow(equity) == 0) {
    rlang::abort("No equity_curve rows found for this backtest.", class = "ledgr_invalid_backtest")
  }
  equity$ts_utc <- as.POSIXct(equity$ts_utc, tz = "UTC")

  p_equity <- ggplot2::ggplot(equity, ggplot2::aes(x = .data$ts_utc, y = .data$equity)) +
    ggplot2::geom_line() +
    ggplot2::labs(x = NULL, y = "Equity", title = "Equity Curve") +
    ggplot2::theme_minimal()

  p_drawdown <- ggplot2::ggplot(equity, ggplot2::aes(x = .data$ts_utc, y = .data$drawdown)) +
    ggplot2::geom_area() +
    ggplot2::labs(x = NULL, y = "Drawdown", title = "Drawdown") +
    ggplot2::theme_minimal()

  if (ledgr_has_namespace("gridExtra")) {
    return(gridExtra::grid.arrange(p_equity, p_drawdown, ncol = 1))
  }

  message("Optional package 'gridExtra' is not installed; showing equity curve only.")
  p_equity
}
