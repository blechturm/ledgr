ledgr_validate_strategy_helper_ctx <- function(ctx, helper) {
  if (!is.list(ctx) && !is.environment(ctx)) {
    rlang::abort(sprintf("`ctx` must be a ledgr strategy context for `%s()`.", helper), class = "ledgr_invalid_strategy_helper")
  }
  universe <- ctx$universe
  if (!is.character(universe) || length(universe) < 1L || anyNA(universe) || any(!nzchar(universe)) || anyDuplicated(universe)) {
    rlang::abort(sprintf("`ctx$universe` must be a unique non-empty character vector for `%s()`.", helper), class = "ledgr_invalid_strategy_helper")
  }
  universe
}

ledgr_strategy_helper_validate_lookback <- function(lookback) {
  if (!is.numeric(lookback) || length(lookback) != 1L || is.na(lookback) || !is.finite(lookback) || lookback < 1L || lookback != as.integer(lookback)) {
    rlang::abort("`lookback` must be a positive integer scalar.", class = "ledgr_invalid_strategy_helper")
  }
  as.integer(lookback)
}

ledgr_strategy_helper_validate_n <- function(n) {
  if (!is.numeric(n) || length(n) != 1L || is.na(n) || !is.finite(n) || n < 1L || n != as.integer(n)) {
    rlang::abort("`n` must be a positive integer scalar.", class = "ledgr_invalid_strategy_helper")
  }
  as.integer(n)
}

ledgr_strategy_helper_validate_equity_fraction <- function(equity_fraction) {
  if (!is.numeric(equity_fraction) || length(equity_fraction) != 1L || is.na(equity_fraction) || !is.finite(equity_fraction) || equity_fraction < 0 || equity_fraction > 1) {
    rlang::abort("`equity_fraction` must be a finite numeric scalar between 0 and 1.", class = "ledgr_invalid_strategy_helper")
  }
  as.numeric(equity_fraction)
}

ledgr_strategy_helper_context_equity <- function(ctx) {
  equity <- ctx$equity
  if (!is.numeric(equity) || length(equity) != 1L || is.na(equity) || !is.finite(equity) || equity < 0) {
    rlang::abort("`ctx$equity` must be a finite non-negative numeric scalar.", class = "ledgr_invalid_strategy_helper")
  }
  as.numeric(equity)
}

#' Build a return signal from registered return features
#'
#' `signal_return()` reads the `return_<lookback>` feature for every instrument
#' in `ctx$universe` and returns a `ledgr_signal`. The required indicator must
#' already be registered on the experiment, for example with
#' `features = list(ledgr_ind_returns(20))`; this helper never auto-registers
#' indicators.
#'
#' @param ctx ledgr strategy context.
#' @param lookback Positive integer return lookback.
#' @return A `ledgr_signal` object.
#' @examples
#' ctx <- list(
#'   universe = c("AAA", "BBB"),
#'   feature = function(id, feature_id) c(AAA = 0.03, BBB = NA_real_)[[id]]
#' )
#' signal_return(ctx, lookback = 5)
#'
#' @section Articles:
#' Strategy helper pipelines:
#' `vignette("strategy-development", package = "ledgr")`
#' `system.file("doc", "strategy-development.html", package = "ledgr")`
#' @export
signal_return <- function(ctx, lookback = 20L) {
  universe <- ledgr_validate_strategy_helper_ctx(ctx, "signal_return")
  lookback <- ledgr_strategy_helper_validate_lookback(lookback)
  feature_id <- sprintf("return_%d", lookback)

  values <- vapply(
    universe,
    function(id) as.numeric(ctx$feature(id, feature_id)),
    numeric(1)
  )
  ledgr_signal(values, universe = universe, origin = feature_id)
}

#' Select the top instruments from a signal
#'
#' `select_top_n()` selects the highest finite/non-missing signal values.
#' Missing values are ignored. Ties are broken deterministically by instrument
#' ID in alphabetical order. If no values are usable, the warning includes the
#' signal origin and non-missing count so warmup can be distinguished from a
#' signal that never becomes usable.
#'
#' @param signal A `ledgr_signal` object.
#' @param n Number of instruments to select.
#' @return A `ledgr_selection` object.
#' @examples
#' signal <- ledgr_signal(c(AAA = 0.03, BBB = NA, CCC = 0.01), origin = "return_5")
#' select_top_n(signal, n = 1)
#'
#' @section Articles:
#' Strategy helper pipelines:
#' `vignette("strategy-development", package = "ledgr")`
#' `system.file("doc", "strategy-development.html", package = "ledgr")`
#' @export
select_top_n <- function(signal, n) {
  if (!inherits(signal, "ledgr_signal")) {
    rlang::abort("`signal` must be a ledgr_signal object.", class = "ledgr_invalid_strategy_helper")
  }
  n <- ledgr_strategy_helper_validate_n(n)

  values <- as.numeric(signal)
  ids <- names(signal)
  available <- !is.na(values)
  if (!any(available)) {
    origin <- attr(signal, "origin")
    if (is.null(origin) || is.na(origin) || !nzchar(origin)) {
      origin <- "<unknown>"
    }
    rlang::warn(
      sprintf(
        "No available signal values for origin `%s` (non-missing 0/%d); returning an empty selection.",
        origin,
        length(ids)
      ),
      class = "ledgr_empty_selection"
    )
    return(ledgr_selection(logical(), universe = ids, origin = attr(signal, "origin")))
  }

  available_ids <- ids[available]
  available_values <- values[available]
  ord <- order(-available_values, available_ids)
  selected_ids <- available_ids[ord][seq_len(min(n, length(ord)))]

  if (length(selected_ids) < n) {
    rlang::warn(
      sprintf("Only %d available signal value(s); selecting all available instruments.", length(selected_ids)),
      class = "ledgr_partial_selection"
    )
  }

  selection <- stats::setNames(rep(FALSE, length(ids)), ids)
  selection[selected_ids] <- TRUE
  ledgr_selection(selection, universe = ids, origin = attr(signal, "origin"))
}

#' Convert a selection to equal long-only weights
#'
#' `weight_equal()` assigns equal positive weights to selected instruments.
#' Empty selections produce empty weights.
#'
#' @param selection A `ledgr_selection` object.
#' @return A `ledgr_weights` object.
#' @examples
#' selection <- ledgr_selection(c(AAA = TRUE, BBB = TRUE), universe = c("AAA", "BBB"))
#' weight_equal(selection)
#'
#' @section Articles:
#' Strategy helper pipelines:
#' `vignette("strategy-development", package = "ledgr")`
#' `system.file("doc", "strategy-development.html", package = "ledgr")`
#' @export
weight_equal <- function(selection) {
  if (!inherits(selection, "ledgr_selection")) {
    rlang::abort("`selection` must be a ledgr_selection object.", class = "ledgr_invalid_strategy_helper")
  }
  selected <- names(selection)[as.logical(selection)]
  if (length(selected) == 0L) {
    # Empty selections created from all-FALSE vectors keep their universe in
    # names(); selections created as logical() carry it in an attribute.
    return(ledgr_weights(numeric(), universe = ledgr_strategy_type_empty_universe(selection), origin = attr(selection, "origin")))
  }
  weights <- stats::setNames(rep(1 / length(selected), length(selected)), selected)
  ledgr_weights(weights, universe = names(selection), origin = attr(selection, "origin"))
}

#' Construct full target quantities from weights
#'
#' `target_rebalance()` converts long-only weights into a full-universe
#' `ledgr_target`. It uses current pulse equity and current close prices at
#' decision time; fills still occur at the next open, so small drift between
#' decision-time sizing and fill-time value is expected. Share quantities are
#' floored to whole numbers with `floor(weight * equity_fraction * equity /
#' close_price)`.
#'
#' @param weights A `ledgr_weights` object.
#' @param ctx ledgr strategy context.
#' @param equity_fraction Fraction of current equity to allocate, between 0 and
#'   1.
#' @return A full-universe `ledgr_target` object.
#' @examples
#' weights <- ledgr_weights(c(AAA = 0.5, BBB = 0.5), universe = c("AAA", "BBB"))
#' ctx <- list(
#'   universe = c("AAA", "BBB"),
#'   equity = 1000,
#'   close = function(id) c(AAA = 50, BBB = 100)[[id]]
#' )
#' target_rebalance(weights, ctx, equity_fraction = 0.5)
#'
#' @section Articles:
#' Strategy helper pipelines:
#' `vignette("strategy-development", package = "ledgr")`
#' `system.file("doc", "strategy-development.html", package = "ledgr")`
#' @export
target_rebalance <- function(weights, ctx, equity_fraction = 1.0) {
  if (!inherits(weights, "ledgr_weights")) {
    rlang::abort("`weights` must be a ledgr_weights object.", class = "ledgr_invalid_strategy_helper")
  }
  universe <- ledgr_validate_strategy_helper_ctx(ctx, "target_rebalance")
  equity <- ledgr_strategy_helper_context_equity(ctx)
  equity_fraction <- ledgr_strategy_helper_validate_equity_fraction(equity_fraction)

  extra <- setdiff(names(weights), universe)
  if (length(extra) > 0L) {
    rlang::abort(
      sprintf("`weights` contains instruments outside `ctx$universe`: %s.", paste(extra, collapse = ", ")),
      class = "ledgr_invalid_strategy_helper"
    )
  }
  if (any(as.numeric(weights) < 0)) {
    rlang::abort("Negative weights are not supported until short-selling semantics are defined.", class = "ledgr_negative_weights")
  }
  if (sum(abs(as.numeric(weights))) > 1 + sqrt(.Machine$double.eps)) {
    rlang::abort("Levered weights are not supported; `sum(abs(weights))` must be <= 1.", class = "ledgr_levered_weights")
  }

  target <- stats::setNames(rep(0, length(universe)), universe)
  if (length(weights) == 0L || equity_fraction == 0 || equity == 0) {
    return(ledgr_target(target, universe = universe, origin = attr(weights, "origin")))
  }

  for (id in names(weights)) {
    price <- as.numeric(ctx$close(id))
    if (length(price) != 1L || is.na(price) || !is.finite(price) || price <= 0) {
      rlang::warn(
        sprintf("Cannot size target for `%s`: close price is missing, non-finite, or non-positive. Targeting 0.", id),
        class = "ledgr_invalid_target_price"
      )
      target[[id]] <- 0
    } else {
      target[[id]] <- floor((as.numeric(weights[[id]]) * equity_fraction * equity) / price)
    }
  }

  ledgr_target(target, universe = universe, origin = attr(weights, "origin"))
}
