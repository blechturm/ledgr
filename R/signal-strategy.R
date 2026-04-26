#' Wrap a signal-style strategy as numeric targets
#'
#' `ledgr_signal_strategy()` is a small convenience wrapper for tutorial-style
#' strategies that emit explicit signals. It does not change the runner
#' contract: the returned strategy maps signals to a full named numeric target
#' vector before the shared StrategyResult validator runs.
#'
#' @param fn Function called as `fn(ctx)`. It must return either a scalar signal
#'   for a single-instrument universe or a named character vector with one
#'   signal per instrument in `ctx$universe`.
#' @param long_qty Target quantity for `"LONG"`.
#' @param flat_qty Target quantity for `"FLAT"`.
#' @param short_qty Target quantity for `"SHORT"`.
#'
#' @return A strategy function suitable for `ledgr_backtest()`.
#' @examples
#' strategy <- ledgr_signal_strategy(
#'   function(ctx) c(AAA = "LONG"),
#'   long_qty = 10
#' )
#' strategy(list(universe = "AAA"))
#' @export
ledgr_signal_strategy <- function(fn, long_qty = 1, flat_qty = 0, short_qty = -1) {
  if (!is.function(fn)) {
    rlang::abort("`fn` must be a function.", class = "ledgr_invalid_args")
  }

  validate_qty <- function(x, arg) {
    if (!is.numeric(x) || length(x) != 1L || is.na(x) || !is.finite(x)) {
      rlang::abort(sprintf("`%s` must be a finite numeric scalar.", arg), class = "ledgr_invalid_args")
    }
    as.numeric(x)
  }

  long_qty <- validate_qty(long_qty, "long_qty")
  flat_qty <- validate_qty(flat_qty, "flat_qty")
  short_qty <- validate_qty(short_qty, "short_qty")

  force(fn)
  force(long_qty)
  force(flat_qty)
  force(short_qty)

  function(ctx) {
    universe <- ctx$universe
    if (!is.character(universe) || length(universe) < 1L || anyNA(universe) || any(!nzchar(universe))) {
      rlang::abort("Signal strategy context must include a non-empty character `universe`.", class = "ledgr_invalid_strategy_result")
    }

    signals <- fn(ctx)
    if (!is.character(signals) || length(signals) < 1L) {
      rlang::abort("Signal strategy functions must return character signals.", class = "ledgr_invalid_strategy_result")
    }

    signal_names <- names(signals)
    if (is.null(signal_names) && length(signals) == 1L) {
      if (length(universe) != 1L) {
        rlang::abort(
          "Scalar signal returns are only valid for single-instrument universes. Return a named signal vector for multi-instrument strategies.",
          class = "ledgr_invalid_strategy_result"
        )
      }
      signal_names <- universe
    }

    if (is.null(signal_names) ||
      length(signal_names) != length(signals) ||
      anyNA(signal_names) ||
      any(!nzchar(signal_names)) ||
      anyDuplicated(signal_names)) {
      rlang::abort(
        "Signal strategy functions must return a named character vector with unique, non-empty instrument names.",
        class = "ledgr_invalid_strategy_result"
      )
    }

    signals <- toupper(trimws(signals))
    if (anyNA(signals) || any(!nzchar(signals))) {
      rlang::abort("Signal strategy output contains missing or empty signals.", class = "ledgr_invalid_strategy_result")
    }

    signal_map <- c(LONG = long_qty, FLAT = flat_qty, SHORT = short_qty)
    unknown <- setdiff(unique(signals), names(signal_map))
    if (length(unknown) > 0L) {
      rlang::abort(
        sprintf("Unknown signal(s): %s. Supported signals are LONG, FLAT, and SHORT.", paste(unknown, collapse = ", ")),
        class = "ledgr_invalid_strategy_result"
      )
    }

    targets <- as.numeric(signal_map[signals])
    names(targets) <- signal_names
    ledgr_validate_strategy_targets(targets, universe)
  }
}
