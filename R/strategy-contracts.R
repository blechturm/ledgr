ledgr_strategy_targets_contract <- function() {
  "a named numeric target vector, or ledgr_target, with names matching ctx$universe"
}

ledgr_strategy_intermediate_classes <- function() {
  c("ledgr_signal", "ledgr_selection", "ledgr_weights")
}

ledgr_is_strategy_intermediate <- function(x) {
  any(vapply(ledgr_strategy_intermediate_classes(), inherits, logical(1), x = x))
}

ledgr_abort_intermediate_strategy_result <- function(x) {
  cls <- intersect(class(x), ledgr_strategy_intermediate_classes())[[1]]
  rlang::abort(
    sprintf(
      "Strategies must not return `%s` directly. Helper pipelines must terminate in `ledgr_target` or a full named numeric target vector.",
      cls
    ),
    class = "ledgr_invalid_strategy_result"
  )
}

ledgr_unwrap_strategy_target <- function(targets) {
  if (ledgr_is_strategy_intermediate(targets)) {
    ledgr_abort_intermediate_strategy_result(targets)
  }
  if (inherits(targets, "ledgr_target")) {
    targets <- unclass(targets)
  }
  targets
}

ledgr_validate_strategy_targets <- function(targets, universe) {
  if (!is.character(universe) || length(universe) < 1 || anyNA(universe) || any(!nzchar(universe))) {
    rlang::abort("`universe` must be a non-empty character vector.", class = "ledgr_invalid_strategy_result")
  }
  if (anyDuplicated(universe)) {
    rlang::abort("`universe` must not contain duplicates.", class = "ledgr_invalid_strategy_result")
  }

  targets <- ledgr_unwrap_strategy_target(targets)
  if (!is.numeric(targets) || length(targets) < 1) {
    rlang::abort(
      sprintf(
        "`targets` must be %s; got %s.",
        ledgr_strategy_targets_contract(),
        paste(class(targets), collapse = "/")
      ),
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
      sprintf(
        "`targets` must be %s. Names must be unique, non-empty instrument IDs.",
        ledgr_strategy_targets_contract()
      ),
      class = "ledgr_invalid_strategy_result"
    )
  }
  if (any(!is.finite(targets))) {
    rlang::abort(
      sprintf(
        "`targets` must be %s. Target quantities must be finite numeric values.",
        ledgr_strategy_targets_contract()
      ),
      class = "ledgr_invalid_strategy_result"
    )
  }

  missing <- setdiff(universe, target_names)
  extra <- setdiff(target_names, universe)
  if (length(missing) > 0 || length(extra) > 0) {
    details <- c(
      if (length(missing) > 0) sprintf("missing instruments: %s", paste(missing, collapse = ", ")),
      if (length(extra) > 0) sprintf("extra instruments: %s", paste(extra, collapse = ", "))
    )
    rlang::abort(
      sprintf(
        "`targets` must be %s; %s.",
        ledgr_strategy_targets_contract(),
        paste(details, collapse = "; ")
      ),
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

    on_pulse = function(ctx, params) {
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
    on_pulse_impl = function(ctx, params) {
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
    on_pulse_impl = function(ctx, params) {
      targets <- stats::setNames(rep(0, length(ctx$universe)), ctx$universe)
      list(targets = targets, state_update = list())
    }
  )
)

EchoStrategy <- R6::R6Class(
  "EchoStrategy",
  inherit = LedgrStrategy,
  private = list(
    on_pulse_impl = function(ctx, params) {
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
    on_pulse_impl = function(ctx, params) {
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
    on_pulse_impl = function(ctx, params) {
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
