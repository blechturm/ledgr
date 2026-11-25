#' Simple Moving Average
#'
#' @param n Window size.
#' @return A `ledgr_indicator` object.
#' @examples
#' window <- data.frame(close = c(100, 101, 103))
#' ledgr_ind_sma(3)$fn(window)
#'
#' @section Articles:
#' Indicators, feature IDs, and warmup:
#' `vignette("indicators", package = "ledgr")`
#' `system.file("doc", "indicators.html", package = "ledgr")`
#' @export
ledgr_ind_sma <- function(n) {
  if (ledgr_contains_param_ref(n)) {
    return(ledgr_new_parameterized_indicator("ledgr_ind_sma", list(n = n), "n"))
  }
  if (!is.numeric(n) || length(n) != 1 || is.na(n) || n < 1 || n > .Machine$integer.max || n %% 1 != 0) {
    rlang::abort("`n` must be an integer >= 1.", class = "ledgr_invalid_args")
  }
  n <- as.integer(n)
  ledgr_indicator_builtin("sma", ledgr_indicator(
    id = sprintf("sma_%d", n),
    fn = function(window) {
      mean(window$close)
    },
    series_fn = function(bars, params) {
      ledgr_rolling_mean(bars$close, as.integer(params$n))
    },
    requires_bars = as.integer(n),
    stable_after = as.integer(n),
    params = list(n = n),
    source = "ledgr",
    gap_contract = "strict_window"
  ))
}

#' Exponential Moving Average
#'
#' @param n Window size.
#' @return A `ledgr_indicator` object.
#' @examples
#' window <- data.frame(close = c(100, 101, 103, 104))
#' ledgr_ind_ema(3)$fn(window)
#'
#' @section Articles:
#' Indicators, feature IDs, and warmup:
#' `vignette("indicators", package = "ledgr")`
#' `system.file("doc", "indicators.html", package = "ledgr")`
#' @export
ledgr_ind_ema <- function(n) {
  if (ledgr_contains_param_ref(n)) {
    return(ledgr_new_parameterized_indicator("ledgr_ind_ema", list(n = n), "n"))
  }
  if (!is.numeric(n) || length(n) != 1 || is.na(n) || n < 1 || n > .Machine$integer.max || n %% 1 != 0) {
    rlang::abort("`n` must be an integer >= 1.", class = "ledgr_invalid_args")
  }
  n <- as.integer(n)
  ledgr_indicator_builtin("ema", ledgr_indicator(
    id = sprintf("ema_%d", n),
    fn = function(window) {
      alpha <- 2 / (n + 1)
      ema <- window$close[1]

      for (i in 2:nrow(window)) {
        ema <- alpha * window$close[i] + (1 - alpha) * ema
      }

      ema
    },
    series_fn = function(bars, params) {
      n <- as.integer(params$n)
      ledgr_bounded_ema_series(bars$close, n)
    },
    requires_bars = as.integer(n + 1),
    stable_after = as.integer(n + 1),
    params = list(n = n),
    source = "ledgr",
    gap_contract = "strict_window"
  ))
}

#' Relative Strength Index
#'
#' @param n Window size (default 14).
#' @return A `ledgr_indicator` object.
#' @examples
#' window <- data.frame(close = c(100, 101, 102, 101))
#' ledgr_ind_rsi(3)$fn(window)
#'
#' @section Articles:
#' Indicators, feature IDs, and warmup:
#' `vignette("indicators", package = "ledgr")`
#' `system.file("doc", "indicators.html", package = "ledgr")`
#' @export
ledgr_ind_rsi <- function(n = 14L) {
  if (ledgr_contains_param_ref(n)) {
    return(ledgr_new_parameterized_indicator("ledgr_ind_rsi", list(n = n), "n"))
  }
  if (!is.numeric(n) || length(n) != 1 || is.na(n) || n < 1 || n > .Machine$integer.max || n %% 1 != 0) {
    rlang::abort("`n` must be an integer >= 1.", class = "ledgr_invalid_args")
  }
  n <- as.integer(n)
  ledgr_indicator_builtin("rsi", ledgr_indicator(
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
    series_fn = function(bars, params) {
      n <- as.integer(params$n)
      ledgr_simple_rsi_series(bars$close, n)
    },
    requires_bars = as.integer(n + 1),
    stable_after = as.integer(n + 1),
    params = list(n = n),
    source = "ledgr",
    gap_contract = "strict_window"
  ))
}

#' Simple Returns
#'
#' @param n Periods back (default 1).
#' @return A `ledgr_indicator` object.
#' @examples
#' window <- data.frame(close = c(100, 105))
#' ledgr_ind_returns(1)$fn(window)
#'
#' @section Articles:
#' Indicators, feature IDs, and warmup:
#' `vignette("indicators", package = "ledgr")`
#' `system.file("doc", "indicators.html", package = "ledgr")`
#' @export
ledgr_ind_returns <- function(n = 1L) {
  if (ledgr_contains_param_ref(n)) {
    return(ledgr_new_parameterized_indicator("ledgr_ind_returns", list(n = n), "n"))
  }
  if (!is.numeric(n) || length(n) != 1 || is.na(n) || n < 1 || n > .Machine$integer.max || n %% 1 != 0) {
    rlang::abort("`n` must be an integer >= 1.", class = "ledgr_invalid_args")
  }
  n <- as.integer(n)
  ledgr_indicator_builtin("returns", ledgr_indicator(
    id = sprintf("return_%d", n),
    fn = function(window) {
      current <- window$close[nrow(window)]
      previous <- window$close[nrow(window) - n]
      (current - previous) / previous
    },
    series_fn = function(bars, params) {
      n <- as.integer(params$n)
      closes <- as.numeric(bars$close)
      out <- rep(NA_real_, length(closes))
      if (length(closes) <= n) return(out)
      idx <- (n + 1L):length(closes)
      out[idx] <- (closes[idx] - closes[idx - n]) / closes[idx - n]
      out
    },
    requires_bars = as.integer(n + 1),
    stable_after = as.integer(n + 1),
    params = list(n = n),
    source = "ledgr",
    gap_contract = "strict_window"
  ))
}

ledgr_indicator_builtin <- function(family, indicator) {
  row <- ledgr_indicator_catalogue_row("ledgr", family)
  if (is.null(row)) {
    rlang::abort("Missing built-in indicator catalogue row.", class = "ledgr_internal_error")
  }
  ledgr_indicator_apply_catalogue(indicator, row)
}

# The ledgr adapter (R/feature-adapters.R): the built-in catalogue rows,
# constructors, certification candidates and segment calculation.
ledgr_feature_adapter_ledgr <- function() {
  list(
    name = "ledgr",
    package = "ledgr",
    catalogue_rows = ledgr_feature_adapter_ledgr_rows,
    constructors = list(
      ledgr_ind_sma = ledgr_ind_sma,
      ledgr_ind_ema = ledgr_ind_ema,
      ledgr_ind_rsi = ledgr_ind_rsi,
      ledgr_ind_returns = ledgr_ind_returns
    ),
    candidates = ledgr_feature_adapter_ledgr_candidates,
    certified = function(canonical, declarations) list(),
    segment = ledgr_feature_adapter_ledgr_segment,
    bind = c(
      "ledgr_feature_adapter_ledgr", "ledgr_feature_adapter_ledgr_rows",
      "ledgr_feature_adapter_ledgr_candidates", "ledgr_feature_adapter_ledgr_segment"
    )
  )
}

ledgr_feature_adapter_ledgr_rows <- function(row) {
  close <- "close"
  list(
    row("ledgr", "sma", "value", "default", "bounded", close, "eligible", "n"),
    row("ledgr", "ema", "value", "default", "bounded", close, "eligible", "n + 1"),
    row("ledgr", "rsi", "value", "default", "bounded", close, "excluded", "n + 1"),
    row("ledgr", "returns", "value", "default", "bounded", close, "excluded", "n + 1")
  )
}

# Every built-in at every width the definition's params or ID carry, widths
# in discovery order (params, then ID) and the four families in this order
# within each width; all are constructed before certification compares any.
ledgr_feature_adapter_ledgr_candidates <- function(def) {
  out <- list()
  widths <- integer()
  n <- if (is.list(def$params)) def$params$n else NULL
  if (is.numeric(n) && length(n) == 1L && !is.na(n) && is.finite(n) &&
      n >= 1 && n %% 1 == 0 && n <= .Machine$integer.max) {
    widths <- as.integer(n)
  }
  id_width <- regmatches(def$id, regexec("^(sma|ema|rsi|return)_([0-9]+)$", def$id))[[1L]]
  if (length(id_width) == 3L) {
    widths <- unique(c(widths, as.integer(id_width[[3L]])))
  }
  constructors <- list(
    sma = ledgr_ind_sma,
    ema = ledgr_ind_ema,
    rsi = ledgr_ind_rsi,
    returns = ledgr_ind_returns
  )
  for (width in widths[!is.na(widths)]) {
    for (kind in names(constructors)) {
      out[[length(out) + 1L]] <- list(
        adapter = "ledgr",
        certification = "builtin",
        kind = kind,
        indicator = constructors[[kind]](width)
      )
    }
  }
  out
}

ledgr_feature_adapter_ledgr_segment <- function(cert, inputs, fields, rows, cache = NULL) {
  if (identical(cert$kind, "sma")) {
    # Exact parity with the scalar mean(window$close) oracle.
    return(ledgr_strict_sma_series(fields$close[rows], as.integer(cert$def$requires_bars)))
  }
  ledgr_history_feature_segment_general(cert, inputs, fields, rows)
}
