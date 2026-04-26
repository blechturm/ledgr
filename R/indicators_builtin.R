#' Simple Moving Average
#'
#' @param n Window size.
#' @return A `ledgr_indicator` object.
#' @examples
#' window <- data.frame(close = c(100, 101, 103))
#' ledgr_ind_sma(3)$fn(window)
#' @export
ledgr_ind_sma <- function(n) {
  if (!is.numeric(n) || length(n) != 1 || is.na(n) || n < 1 || n %% 1 != 0) {
    rlang::abort("`n` must be an integer >= 1.", class = "ledgr_invalid_args")
  }
  ledgr_indicator(
    id = sprintf("sma_%d", n),
    fn = function(window) {
      mean(window$close)
    },
    requires_bars = as.integer(n),
    stable_after = as.integer(n),
    params = list(n = n)
  )
}

#' Exponential Moving Average
#'
#' @param n Window size.
#' @return A `ledgr_indicator` object.
#' @examples
#' window <- data.frame(close = c(100, 101, 103, 104))
#' ledgr_ind_ema(3)$fn(window)
#' @export
ledgr_ind_ema <- function(n) {
  if (!is.numeric(n) || length(n) != 1 || is.na(n) || n < 1 || n %% 1 != 0) {
    rlang::abort("`n` must be an integer >= 1.", class = "ledgr_invalid_args")
  }
  ledgr_indicator(
    id = sprintf("ema_%d", n),
    fn = function(window) {
      alpha <- 2 / (n + 1)
      ema <- window$close[1]

      for (i in 2:nrow(window)) {
        ema <- alpha * window$close[i] + (1 - alpha) * ema
      }

      ema
    },
    requires_bars = as.integer(n + 1),
    stable_after = as.integer(n + 1),
    params = list(n = n)
  )
}

#' Relative Strength Index
#'
#' @param n Window size (default 14).
#' @return A `ledgr_indicator` object.
#' @examples
#' window <- data.frame(close = c(100, 101, 102, 101))
#' ledgr_ind_rsi(3)$fn(window)
#' @export
ledgr_ind_rsi <- function(n = 14L) {
  if (!is.numeric(n) || length(n) != 1 || is.na(n) || n < 1 || n %% 1 != 0) {
    rlang::abort("`n` must be an integer >= 1.", class = "ledgr_invalid_args")
  }
  ledgr_indicator(
    id = sprintf("rsi_%d", n),
    fn = function(window) {
      changes <- diff(window$close)
      gains <- pmax(changes, 0)
      losses <- abs(pmin(changes, 0))

      avg_gain <- mean(utils::tail(gains, n))
      avg_loss <- mean(utils::tail(losses, n))

      if (avg_loss == 0) return(100)

      rs <- avg_gain / avg_loss
      100 - (100 / (1 + rs))
    },
    requires_bars = as.integer(n + 1),
    stable_after = as.integer(n + 1),
    params = list(n = n)
  )
}

#' Simple Returns
#'
#' @param n Periods back (default 1).
#' @return A `ledgr_indicator` object.
#' @examples
#' window <- data.frame(close = c(100, 105))
#' ledgr_ind_returns(1)$fn(window)
#' @export
ledgr_ind_returns <- function(n = 1L) {
  if (!is.numeric(n) || length(n) != 1 || is.na(n) || n < 1 || n %% 1 != 0) {
    rlang::abort("`n` must be an integer >= 1.", class = "ledgr_invalid_args")
  }
  ledgr_indicator(
    id = sprintf("return_%d", n),
    fn = function(window) {
      current <- window$close[nrow(window)]
      previous <- window$close[nrow(window) - n]
      (current - previous) / previous
    },
    requires_bars = as.integer(n + 1),
    stable_after = as.integer(n + 1),
    params = list(n = n)
  )
}
