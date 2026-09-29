#' Wrap a signal-style strategy as numeric targets
#'
#' `ledgr_signal_strategy()` is a small convenience wrapper for tutorial-style
#' strategies that emit explicit signals. It does not change the runner
#' contract: the returned strategy maps signals to a full named numeric target
#' vector before the shared StrategyResult validator runs.
#'
#' Only eligible instruments (`ctx$vec$admissible`) are mapped from their
#' signals. Every ineligible instrument, a held nonmember or a target-restricted
#' member, keeps its current quantity, whatever signal it received. On an empty
#' decision axis the function is still called and the strategy returns a named
#' zero-length target; a zero-length signal is valid whenever no instrument is
#' eligible.
#'
#' @param fn Signal function called as `fn(ctx)`. It receives the ledgr pulse
#'   context, not `params`, and must return either a scalar signal for a
#'   single-instrument universe or a named character vector with a signal for
#'   every eligible instrument in `ctx$universe`. Signals for ineligible
#'   instruments may be included or left out.
#' @param long_qty Target quantity for `"LONG"`.
#' @param flat_qty Target quantity for `"FLAT"`.
#' @param short_qty Target quantity for `"SHORT"`.
#'
#' @return A `function(ctx, params)` strategy suitable for ledgr execution. The
#'   returned strategy follows the normal ledgr strategy convention and maps the
#'   inner signal function's `"LONG"`, `"FLAT"`, and `"SHORT"` values to a full
#'   named numeric target vector.
#' @examples
#' strategy <- ledgr_signal_strategy(
#'   function(ctx) c(AAA = "LONG"),
#'   long_qty = 10
#' )
#' strategy(list(universe = "AAA"), list())
#'
#' @section Articles:
#' Strategy helper pipelines:
#' `vignette("strategy-development", package = "ledgr")`
#' `system.file("doc", "strategy-development.html", package = "ledgr")`
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

  out <- function(ctx, params) {
    universe <- ctx$universe
    availability_active <- isTRUE(ctx$availability_active)
    if (!is.character(universe) || (!availability_active && length(universe) < 1L) ||
        anyNA(universe) || any(!nzchar(universe))) {
      rlang::abort("Signal strategy context must include a non-empty character `universe`.", class = "ledgr_invalid_strategy_result")
    }
    eligible <- ledgr_strategy_eligible(ctx, universe)
    current_targets <- function() {
      position <- ctx$vec$position
      if (is.null(position) || length(position) != length(universe)) {
        rlang::abort(
          "`ctx$vec$position` must provide one value per decision-axis instrument when an instrument is ineligible.",
          class = "ledgr_invalid_strategy_result"
        )
      }
      stats::setNames(as.numeric(position), universe)
    }
    must_cover <- function(missing_ids) {
      rlang::abort(
        sprintf("Signal strategy output must cover every eligible instrument: %s.", paste(missing_ids, collapse = ", ")),
        class = "ledgr_invalid_strategy_result"
      )
    }

    signals <- fn(ctx)
    if (!is.character(signals)) {
      rlang::abort("Signal strategy functions must return character signals.", class = "ledgr_invalid_strategy_result")
    }
    if (length(signals) == 0L) {
      # With no eligible instrument there is nothing to map: every instrument
      # on the axis, if any, keeps its current quantity.
      if (any(eligible)) must_cover(universe[eligible])
      targets <- if (length(universe) == 0L) stats::setNames(numeric(), character()) else current_targets()
      return(ledgr_validate_strategy_targets(targets, universe, allow_empty = availability_active))
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

    if (all(eligible)) {
      # Every instrument is eligible: map the signals and let the target
      # validator refuse missing or extra names, as it always has.
      targets <- as.numeric(signal_map[signals])
      names(targets) <- signal_names
      return(ledgr_validate_strategy_targets(targets, universe, allow_empty = availability_active))
    }

    # Some instruments are ineligible: they keep their current quantity, and
    # the signals must name axis instruments and cover every eligible one.
    targets <- current_targets()
    position_of_signal <- match(signal_names, universe)
    if (anyNA(position_of_signal)) {
      rlang::abort(
        sprintf("Signal strategy output names instruments outside the decision axis: %s.",
                paste(signal_names[is.na(position_of_signal)], collapse = ", ")),
        class = "ledgr_invalid_strategy_result"
      )
    }
    covered <- logical(length(universe))
    covered[position_of_signal] <- TRUE
    if (any(eligible & !covered)) must_cover(universe[eligible & !covered])
    mapped <- eligible[position_of_signal]
    targets[position_of_signal[mapped]] <- unname(signal_map)[match(signals[mapped], names(signal_map))]
    ledgr_validate_strategy_targets(targets, universe, allow_empty = availability_active)
  }
  attr(out, "ledgr_signal_strategy_wrapper") <- TRUE
  out
}
