ledgr_validate_strategy_targets <- function(targets, universe) {
  if (!is.character(universe) || length(universe) < 1 || anyNA(universe) || any(!nzchar(universe))) {
    rlang::abort("`universe` must be a non-empty character vector.", class = "ledgr_invalid_strategy_result")
  }
  if (anyDuplicated(universe)) {
    rlang::abort("`universe` must not contain duplicates.", class = "ledgr_invalid_strategy_result")
  }

  if (!is.numeric(targets) || length(targets) < 1) {
    rlang::abort(
      "`targets` must be a non-empty named numeric vector (quantities).",
      class = "ledgr_invalid_strategy_result"
    )
  }

  target_names <- names(targets)
  if (is.null(target_names) ||
      length(target_names) != length(targets) ||
      anyNA(target_names) ||
      any(!nzchar(target_names)) ||
      anyDuplicated(target_names)) {
    rlang::abort(
      "`targets` must be a named numeric vector with unique, non-empty names.",
      class = "ledgr_invalid_strategy_result"
    )
  }
  if (any(!is.finite(targets))) {
    rlang::abort("`targets` must contain only finite numeric values.", class = "ledgr_invalid_strategy_result")
  }

  missing <- setdiff(universe, target_names)
  extra <- setdiff(target_names, universe)
  if (length(extra) > 0) {
    rlang::abort(
      sprintf("`targets` contains instruments outside universe: %s", paste(extra, collapse = ", ")),
      class = "ledgr_invalid_strategy_result"
    )
  }
  if (length(missing) > 0) {
    rlang::abort(
      sprintf("`targets` must include all instruments in universe; missing: %s", paste(missing, collapse = ", ")),
      class = "ledgr_invalid_strategy_result"
    )
  }

  targets[universe]
}

LedgrStrategy <- R6::R6Class(
  "LedgrStrategy",
  public = list(
    params = NULL,

    initialize = function(params = list()) {
      if (!is.list(params)) {
        rlang::abort("`params` must be a list.", class = "ledgr_invalid_strategy")
      }
      self$params <- params
      invisible(self)
    },

    reset = function() {
      invisible(self)
    },

    on_pulse = function(ctx) {
      ledgr_validate_pulse_context(ctx)

      before <- private$fingerprint()
      result <- private$on_pulse_impl(ctx)
      private$validate_result(result, ctx)
      after <- private$fingerprint()

      if (!identical(before, after)) {
        rlang::abort(
          paste0(
            "Strategy mutated internal state during on_pulse(). Persistent state must be emitted via `state_update` only."
          ),
          class = "ledgr_strategy_mutation_detected"
        )
      }

      result
    }
  ),
  private = list(
    on_pulse_impl = function(ctx) {
      rlang::abort(
        "LedgrStrategy is abstract: subclasses must implement `private$on_pulse_impl(ctx)`.",
        class = "ledgr_invalid_strategy"
      )
    },

    snapshot = function() {
      collect_fields <- function(env) {
        out <- list()
        for (nm in ls(envir = env, all.names = TRUE)) {
          val <- tryCatch(get(nm, envir = env), error = function(e) NULL)
          if (is.function(val)) next
          if (is.environment(val)) next
          if (inherits(val, "R6")) next
          out[[nm]] <- val
        }
        out
      }

      list(
        public = collect_fields(self),
        private = collect_fields(private)
      )
    },

    fingerprint = function() {
      digest::digest(private$snapshot(), algo = "sha256")
    },

    validate_result = function(result, ctx) {
      if (!is.list(result) || is.null(result$targets)) {
        rlang::abort(
          "Strategy on_pulse() must return a list with at least `targets`.",
          class = "ledgr_invalid_strategy_result"
        )
      }

      ledgr_validate_strategy_targets(result$targets, ctx$universe)
      state_update <- result$state_update
      if (!is.null(state_update)) {
        if (!(is.list(state_update) || (is.character(state_update) && length(state_update) == 1))) {
          rlang::abort("`state_update` must be a JSON-safe list (or JSON string).", class = "ledgr_invalid_strategy_result")
        }
        invisible(canonical_json(state_update))
      }

      invisible(TRUE)
    }
  )
)

HoldZeroStrategy <- R6::R6Class(
  "HoldZeroStrategy",
  inherit = LedgrStrategy,
  private = list(
    on_pulse_impl = function(ctx) {
      targets <- stats::setNames(rep(0, length(ctx$universe)), ctx$universe)
      list(targets = targets, state_update = list())
    }
  )
)

EchoStrategy <- R6::R6Class(
  "EchoStrategy",
  inherit = LedgrStrategy,
  private = list(
    on_pulse_impl = function(ctx) {
      targets <- self$params$targets
      state_update <- self$params$state_update
      if (is.null(state_update)) state_update <- list()
      list(targets = targets, state_update = state_update)
    }
  )
)

BadMutatingStrategy <- R6::R6Class(
  "BadMutatingStrategy",
  inherit = LedgrStrategy,
  public = list(
    counter = 0L
  ),
  private = list(
    on_pulse_impl = function(ctx) {
      self$counter <- self$counter + 1L
      targets <- stats::setNames(rep(0, length(ctx$universe)), ctx$universe)
      list(targets = targets, state_update = list())
    }
  )
)

StatePrevStrategy <- R6::R6Class(
  "StatePrevStrategy",
  inherit = LedgrStrategy,
  private = list(
    on_pulse_impl = function(ctx) {
      prev <- ctx$state_prev

      step <- 1L
      if (!is.null(prev)) {
        if (!is.list(prev) || is.null(prev$step) || !is.numeric(prev$step) || length(prev$step) != 1 || is.na(prev$step) || !is.finite(prev$step)) {
          rlang::abort("StatePrevStrategy requires ctx$state_prev$step as a finite numeric scalar.", class = "ledgr_invalid_strategy")
        }
        step <- as.integer(prev$step) + 1L
      }

      targets <- stats::setNames(rep(as.numeric(step), length(ctx$universe)), ctx$universe)
      list(targets = targets, state_update = list(step = as.integer(step)))
    }
  )
)
