# Internal registry for functional strategies (keyed by digest).
ledgr_strategy_registry <- new.env(parent = emptyenv())

ledgr_register_strategy_fn <- function(fn, include_captures = TRUE, key = NULL) {
  if (!is.function(fn)) {
    rlang::abort("`strategy` must be a function or object with $on_pulse().", class = "ledgr_invalid_args")
  }
  ledgr_strategy_signature(fn)
  if (is.null(key)) {
    key <- ledgr_function_fingerprint(fn, include_captures = include_captures, label = "`strategy`", allow_rng = TRUE)
  }
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

ledgr_strategy_fn_from_key <- function(key, signature = NULL, strategy_params = list()) {
  fn <- ledgr_get_strategy_fn(key)
  if (is.null(signature)) signature <- ledgr_strategy_signature(fn)

  R6::R6Class(
    "FunctionalStrategy",
    inherit = LedgrStrategy,
    private = list(
      on_pulse_impl = function(ctx, params) {
        out <- ledgr_call_strategy_fn(fn, ctx, strategy_params, signature)
        if (ledgr_is_strategy_intermediate(out)) {
          ledgr_abort_intermediate_strategy_result(out)
        }
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
