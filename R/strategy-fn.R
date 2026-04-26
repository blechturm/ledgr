# Internal registry for functional strategies (keyed by digest).
ledgr_strategy_registry <- new.env(parent = emptyenv())

ledgr_register_strategy_fn <- function(fn) {
  if (!is.function(fn)) {
    rlang::abort("`strategy` must be a function or object with $on_pulse().", class = "ledgr_invalid_args")
  }
  key <- ledgr_function_fingerprint(fn, include_captures = TRUE, label = "`strategy`")
  assign(key, fn, envir = ledgr_strategy_registry)
  key
}

ledgr_get_strategy_fn <- function(key) {
  if (!is.character(key) || length(key) != 1 || is.na(key) || !nzchar(key)) {
    rlang::abort("Functional strategy key must be a non-empty string.", class = "ledgr_invalid_args")
  }
  if (!exists(key, envir = ledgr_strategy_registry, inherits = FALSE)) {
    rlang::abort(
      sprintf("Functional strategy not registered for key: %s", key),
      class = "ledgr_invalid_strategy"
    )
  }
  get(key, envir = ledgr_strategy_registry, inherits = FALSE)
}

ledgr_strategy_fn_from_key <- function(key) {
  fn <- ledgr_get_strategy_fn(key)

  R6::R6Class(
    "FunctionalStrategy",
    inherit = LedgrStrategy,
    private = list(
      on_pulse_impl = function(ctx) {
        out <- fn(ctx)
        if (is.list(out) && !is.null(out$targets)) return(out)
        if (is.numeric(out)) return(list(targets = out, state_update = list()))
        rlang::abort(
          sprintf(
            "Functional strategies must return %s or a list with `targets`.",
            ledgr_strategy_targets_contract()
          ),
          class = "ledgr_invalid_strategy_result"
        )
      }
    )
  )$new()
}
