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

ledgr_strategy_hold_zero <- function(ctx, params) {
  targets <- stats::setNames(rep(0, length(ctx$universe)), ctx$universe)
  list(targets = targets, state_update = list())
}

ledgr_strategy_echo <- function(ctx, params) {
  targets <- params$targets
  state_update <- params$state_update
  if (is.null(state_update)) state_update <- list()
  ledgr_validate_strategy_targets(targets, ctx$universe)
  list(targets = targets, state_update = state_update)
}

ledgr_strategy_state_prev_targets <- function(ctx, params) {
  prev <- ctx$state_prev

  step <- 1L
  if (!is.null(prev)) {
    if (!is.list(prev) || is.null(prev$step) || !is.numeric(prev$step) || length(prev$step) != 1 || is.na(prev$step) || !is.finite(prev$step)) {
      rlang::abort("state_prev strategy requires ctx$state_prev$step as a finite numeric scalar.", class = "ledgr_invalid_strategy")
    }
    step <- as.integer(prev$step) + 1L
  }

  targets <- stats::setNames(rep(as.numeric(step), length(ctx$universe)), ctx$universe)
  list(targets = targets, state_update = list(step = as.integer(step)))
}
