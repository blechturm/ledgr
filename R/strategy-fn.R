# Internal registry for functional strategies (keyed by digest).
ledgr_strategy_registry <- new.env(parent = emptyenv())

ledgr_register_strategy_fn <- function(fn, include_captures = TRUE, key = NULL) {
  if (!is.function(fn)) {
    rlang::abort("`strategy` must be a function.", class = "ledgr_invalid_args")
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

