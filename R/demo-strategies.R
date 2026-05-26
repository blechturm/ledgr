#' Demo SMA crossover strategy
#'
#' `ledgr_demo_sma_crossover_strategy()` returns a small deterministic strategy
#' function for examples, vignettes, and smoke tests. It is a teaching fixture,
#' not an investment recommendation and not a strategy library surface.
#'
#' The returned strategy expects an active alias map with numeric aliases named
#' `fast` and `slow`, typically from a feature map such as:
#'
#' ```
#' ledgr_feature_map(
#'   fast = ledgr_ind_sma(ledgr_param("fast_n")),
#'   slow = ledgr_ind_sma(ledgr_param("slow_n"))
#' )
#' ```
#'
#' The strategy reads only `params$qty` and `params$threshold`. It remains flat
#' until both aliases pass warmup, then targets `qty` when `(fast / slow) - 1`
#' is greater than `threshold`.
#'
#' @return A Tier-1-compatible strategy function with signature
#'   `function(ctx, params)`.
#' @section Articles:
#' Strategy development:
#' `vignette("strategy-development", package = "ledgr")`
#' `system.file("doc", "strategy-development.html", package = "ledgr")`
#'
#' Sweeps:
#' `vignette("sweeps", package = "ledgr")`
#' `system.file("doc", "sweeps.html", package = "ledgr")`
#' @examples
#' strategy <- ledgr_demo_sma_crossover_strategy()
#' ledgr_strategy_preflight(strategy)
#' @export
ledgr_demo_sma_crossover_strategy <- function() {
  function(ctx, params) {
    qty <- params$qty
    threshold <- params$threshold

    if (is.null(qty) || length(qty) != 1L || !is.numeric(qty) || is.na(qty) || !is.finite(qty)) {
      # Use base stop() with a structured condition; rlang::abort() would make
      # this demo strategy Tier 2 under the current preflight allowlist.
      stop(structure(
        list(message = "`params$qty` must be a finite numeric scalar."),
        class = c(
          "ledgr_invalid_demo_strategy_params",
          "ledgr_invalid_strategy_params",
          "simpleError",
          "error",
          "condition"
        )
      ))
    }
    if (is.null(threshold) || length(threshold) != 1L || !is.numeric(threshold) ||
      is.na(threshold) || !is.finite(threshold)) {
      stop(structure(
        list(message = "`params$threshold` must be a finite numeric scalar."),
        class = c(
          "ledgr_invalid_demo_strategy_params",
          "ledgr_invalid_strategy_params",
          "simpleError",
          "error",
          "condition"
        )
      ))
    }

    targets <- ctx$flat()
    required_aliases <- c("fast", "slow")

    for (id in ctx$universe) {
      values <- ctx$features(id)
      missing_aliases <- required_aliases[!(required_aliases %in% names(values))]
      if (length(missing_aliases) > 0L) {
        stop(structure(
          list(message = paste0(
            "The demo SMA crossover strategy requires active aliases `fast` and `slow`; missing: ",
            paste(missing_aliases, collapse = ", "),
            "."
          )),
          class = c(
            "ledgr_unknown_active_alias",
            "ledgr_invalid_pulse_context",
            "simpleError",
            "error",
            "condition"
          )
        ))
      }

      values <- values[required_aliases]
      if (passed_warmup(values) && ((values[["fast"]] / values[["slow"]]) - 1) > threshold) {
        targets[id] <- qty
      }
    }

    targets
  }
}
