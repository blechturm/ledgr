ledgr_risk_schema_version <- 1L

#' Target-risk constructors
#'
#' These constructors create deterministic, classed target-risk objects for
#' ledgr execution. Risk steps transform complete strategy target vectors before
#' fill timing and cost resolution. They do not perform execution, persistence,
#' ranking, cost estimation, liquidity checks, OMS behavior, or data access.
#'
#' Target risk is not target construction. Strategies still return full named
#' numeric target quantities. A risk chain receives those validated targets and
#' may transform the requested quantities before ledgr builds fill proposals.
#' `ledgr_risk_long_only()` clips negative target quantities to zero.
#' `ledgr_risk_max_weight()` caps absolute target exposure per instrument using
#' decision-time equity and prices:
#' `abs(target_quantity * decision_price) <= max_weight * decision_equity`.
#'
#' Risk chains are execution identity. Equivalent no-op inputs, including an
#' omitted risk chain, `NULL`, and `ledgr_risk_none()`, normalize to the same
#' `risk_chain_hash` and `risk_plan_json`. Parameterized risk arguments use
#' `ledgr_param()` and are resolved from ordinary candidate parameters during
#' sweep execution.
#'
#' Target risk does not implement cash affordability, margin, shorting or borrow
#' policy, liquidity or capacity checks, order lifecycle behavior, broker-grade
#' risk controls, portfolio optimization, or automatic candidate selection.
#'
#' @param ... Risk step objects to compose in order.
#' @param max_weight Finite scalar in `(0, 1]`, or `ledgr_param("name")`.
#' @return A `ledgr_risk_model` object.
#' @examples
#' risk <- ledgr_risk_chain(
#'   ledgr_risk_long_only(),
#'   ledgr_risk_max_weight(0.20)
#' )
#' risk
#'
#' ledgr_risk_max_weight(ledgr_param("max_weight"))
#' ledgr_risk_none()
#' @export
ledgr_risk_chain <- function(...) {
  children <- list(...)
  if (length(children) == 0L) {
    return(ledgr_risk_none())
  }
  children <- ledgr_risk_flatten_children(children)
  if (length(children) == 0L) {
    return(ledgr_risk_none())
  }
  ledgr_risk_model(
    type_id = "chain",
    args = list(),
    children = children
  )
}

#' @rdname ledgr_risk_chain
#' @export
ledgr_risk_none <- function() {
  ledgr_risk_model(
    type_id = "none",
    args = list()
  )
}

#' @rdname ledgr_risk_chain
#' @export
ledgr_risk_long_only <- function() {
  ledgr_risk_model(
    type_id = "long_only",
    args = list()
  )
}

#' @rdname ledgr_risk_chain
#' @export
ledgr_risk_max_weight <- function(max_weight) {
  ledgr_risk_model(
    type_id = "max_weight",
    args = list(max_weight = ledgr_risk_validate_max_weight(max_weight))
  )
}

#' @export
print.ledgr_risk_model <- function(x, ...) {
  x <- ledgr_risk_validate_model(x)
  steps <- ledgr_risk_flat_steps(x)
  cat("ledgr risk chain\n")
  cat("================\n")
  if (length(steps) == 0L) {
    cat("Steps: none\n")
    cat("Hash:  ", substr(ledgr_risk_chain_hash(x), 1L, 12L), "\n", sep = "")
    return(invisible(x))
  }
  cat("Steps: ", length(steps), "\n", sep = "")
  for (i in seq_along(steps)) {
    step <- steps[[i]]
    arg_text <- ledgr_risk_arg_text(step$args)
    cat(i, ". ", step$type_id, arg_text, "\n", sep = "")
  }
  cat("Hash:  ", substr(ledgr_risk_chain_hash(x), 1L, 12L), "\n", sep = "")
  invisible(x)
}

ledgr_risk_model <- function(type_id, args = list(), children = list(), version = 1L) {
  structure(
    list(
      risk_schema_version = ledgr_risk_schema_version,
      type_id = type_id,
      version = as.integer(version),
      args = args,
      children = children
    ),
    class = c(paste0("ledgr_risk_", type_id), "ledgr_risk_model")
  )
}

ledgr_risk_validate_max_weight <- function(max_weight) {
  if (ledgr_is_param_ref(max_weight)) {
    return(max_weight)
  }
  if (!is.numeric(max_weight) || length(max_weight) != 1L ||
      is.na(max_weight) || !is.finite(max_weight) ||
      max_weight <= 0 || max_weight > 1) {
    rlang::abort(
      "`max_weight` must be a finite numeric scalar in (0, 1], or `ledgr_param(\"name\")`.",
      class = c("ledgr_invalid_risk_model", "ledgr_invalid_args")
    )
  }
  as.numeric(max_weight)
}

ledgr_risk_validate_model <- function(risk_chain) {
  if (!inherits(risk_chain, "ledgr_risk_model")) {
    rlang::abort(
      "`risk_chain` must be a ledgr risk object.",
      class = c("ledgr_invalid_risk_model", "ledgr_invalid_args")
    )
  }
  version <- suppressWarnings(as.integer(risk_chain$version))
  if (!is.list(risk_chain) ||
      !identical(as.integer(risk_chain$risk_schema_version), ledgr_risk_schema_version) ||
      !is.character(risk_chain$type_id) || length(risk_chain$type_id) != 1L ||
      !(as.character(risk_chain$type_id) %in% c("none", "long_only", "max_weight", "chain")) ||
      length(version) != 1L || is.na(version) ||
      !is.list(risk_chain$args) ||
      !is.list(risk_chain$children)) {
    rlang::abort(
      "`risk_chain` has an invalid ledgr risk object shape.",
      class = c("ledgr_invalid_risk_model", "ledgr_invalid_args")
    )
  }
  if (identical(risk_chain$type_id, "max_weight")) {
    if (!identical(names(risk_chain$args), "max_weight")) {
      rlang::abort(
        "`risk_chain` has an invalid max-weight risk argument shape.",
        class = c("ledgr_invalid_risk_model", "ledgr_invalid_args")
      )
    }
    risk_chain$args$max_weight <- ledgr_risk_validate_max_weight(risk_chain$args$max_weight)
  }
  risk_chain
}

ledgr_risk_normalize <- function(risk_chain = NULL) {
  if (is.null(risk_chain)) {
    return(ledgr_risk_none())
  }
  ledgr_risk_validate_model(risk_chain)
}

ledgr_experiment_normalize_risk_chain <- function(risk_chain = NULL) {
  ledgr_risk_normalize(risk_chain)
}

ledgr_risk_flatten_children <- function(children) {
  out <- list()
  for (child in children) {
    child <- ledgr_risk_validate_model(child)
    if (identical(child$type_id, "none")) {
      next
    }
    if (identical(child$type_id, "chain")) {
      out <- c(out, ledgr_risk_flatten_children(child$children))
    } else {
      out[[length(out) + 1L]] <- child
    }
  }
  out
}

ledgr_risk_flat_steps <- function(risk_chain = NULL) {
  risk_chain <- ledgr_risk_normalize(risk_chain)
  if (identical(risk_chain$type_id, "none")) {
    return(list())
  }
  if (identical(risk_chain$type_id, "chain")) {
    return(ledgr_risk_flatten_children(risk_chain$children))
  }
  list(risk_chain)
}

ledgr_risk_plan_payload <- function(risk_chain = NULL) {
  steps <- ledgr_risk_flat_steps(risk_chain)
  list(
    risk_schema_version = ledgr_risk_schema_version,
    type_id = if (length(steps) == 0L) "none" else "chain",
    steps = lapply(steps, ledgr_risk_step_payload)
  )
}

ledgr_risk_step_payload <- function(step) {
  step <- ledgr_risk_validate_model(step)
  list(
    type_id = step$type_id,
    schema_version = step$risk_schema_version,
    args = ledgr_risk_args_payload(step$args)
  )
}

ledgr_risk_args_payload <- function(args) {
  if (length(args) == 0L) {
    return(list())
  }
  stats::setNames(
    lapply(names(args), function(arg) ledgr_risk_arg_payload(args[[arg]], arg)),
    names(args)
  )
}

ledgr_risk_arg_payload <- function(value, arg) {
  if (ledgr_is_param_ref(value)) {
    return(list(kind = "param_ref", name = ledgr_param_name(value)))
  }
  if (is.null(value) || is.list(value) || length(value) != 1L) {
    rlang::abort(
      sprintf("Risk argument `%s` must be a scalar or `ledgr_param()` reference.", arg),
      class = c("ledgr_invalid_risk_model", "ledgr_invalid_args")
    )
  }
  list(kind = "value", value = value)
}

ledgr_risk_plan_json <- function(risk_chain = NULL) {
  as.character(canonical_json(ledgr_risk_plan_payload(risk_chain)))
}

ledgr_risk_chain_hash <- function(risk_chain = NULL) {
  digest::digest(ledgr_risk_plan_json(risk_chain), algo = "sha256")
}

ledgr_risk_plan_reconstruct <- function(risk_plan_json) {
  if (!is.character(risk_plan_json) || length(risk_plan_json) != 1L ||
      is.na(risk_plan_json) || !nzchar(risk_plan_json)) {
    rlang::abort(
      "`risk_plan_json` must be a non-empty character scalar.",
      class = c("ledgr_invalid_risk_model", "ledgr_invalid_args")
    )
  }
  payload <- tryCatch(
    ledgr_json_read_nested(risk_plan_json),
    error = function(e) {
      rlang::abort(
        "`risk_plan_json` is not valid JSON.",
        class = c("ledgr_invalid_risk_model", "ledgr_invalid_args"),
        parent = e
      )
    }
  )
  ledgr_risk_model_from_payload(payload)
}

ledgr_risk_plan_compile <- function(risk_chain = NULL, params = list()) {
  risk_chain <- ledgr_risk_normalize(risk_chain)
  if (!is.list(params)) {
    rlang::abort(
      "`strategy_params` must be a list when compiling a risk plan.",
      class = c("ledgr_invalid_risk_plan", "ledgr_invalid_args")
    )
  }
  steps <- lapply(ledgr_risk_flat_steps(risk_chain), ledgr_risk_compile_step, params = params)
  structure(
    list(
      risk_schema_version = ledgr_risk_schema_version,
      steps = steps
    ),
    class = c("ledgr_compiled_risk_plan", "list")
  )
}

ledgr_risk_validate_compiled_plan <- function(risk_plan) {
  if (is.null(risk_plan)) {
    return(ledgr_risk_plan_compile(NULL, params = list()))
  }
  if (!inherits(risk_plan, "ledgr_compiled_risk_plan") ||
      !is.list(risk_plan) ||
      !identical(as.integer(risk_plan$risk_schema_version), ledgr_risk_schema_version) ||
      is.null(risk_plan$steps) ||
      !is.list(risk_plan$steps)) {
    rlang::abort(
      "`risk_plan` must be a compiled ledgr risk plan.",
      class = c("ledgr_invalid_risk_plan", "ledgr_invalid_execution_spec")
    )
  }
  lapply(risk_plan$steps, ledgr_risk_validate_compiled_step)
  invisible(risk_plan)
}

ledgr_risk_validate_compiled_step <- function(step) {
  if (!inherits(step, "ledgr_compiled_risk_step") ||
      !is.list(step) ||
      !is.character(step$type_id) || length(step$type_id) != 1L ||
      !(step$type_id %in% c("long_only", "max_weight")) ||
      !identical(as.integer(step$schema_version), ledgr_risk_schema_version) ||
      is.null(step$args) ||
      !is.list(step$args)) {
    rlang::abort(
      "`risk_plan` contains an invalid compiled risk step.",
      class = c("ledgr_invalid_risk_plan", "ledgr_invalid_execution_spec")
    )
  }
  if (identical(step$type_id, "long_only") && length(step$args) != 0L) {
    rlang::abort(
      "`risk_plan` contains an invalid long-only compiled risk step.",
      class = c("ledgr_invalid_risk_plan", "ledgr_invalid_execution_spec")
    )
  }
  if (identical(step$type_id, "max_weight")) {
    if (!identical(names(step$args), "max_weight")) {
      rlang::abort(
        "`risk_plan` contains an invalid max-weight compiled risk step.",
        class = c("ledgr_invalid_risk_plan", "ledgr_invalid_execution_spec")
      )
    }
    step$args$max_weight <- ledgr_risk_validate_max_weight(step$args$max_weight)
  }
  invisible(step)
}

ledgr_risk_compile_step <- function(step, params) {
  step <- ledgr_risk_validate_model(step)
  args <- ledgr_risk_compile_args(step$args, params = params)
  structure(
    list(
      type_id = step$type_id,
      schema_version = step$risk_schema_version,
      args = args
    ),
    class = c(paste0("ledgr_compiled_risk_step_", step$type_id), "ledgr_compiled_risk_step", "list")
  )
}

ledgr_risk_compile_args <- function(args, params) {
  if (length(args) == 0L) {
    return(list())
  }
  stats::setNames(
    lapply(names(args), function(arg) ledgr_risk_compile_arg(args[[arg]], arg, params = params)),
    names(args)
  )
}

ledgr_risk_compile_arg <- function(value, arg, params) {
  if (!ledgr_is_param_ref(value)) {
    return(value)
  }
  name <- ledgr_param_name(value)
  if (is.null(params[[name]])) {
    rlang::abort(
      sprintf("Risk parameter `%s` is missing from strategy params.", name),
      class = c("ledgr_risk_plan_parameter_missing", "ledgr_invalid_risk_plan")
    )
  }
  resolved <- params[[name]]
  if (identical(arg, "max_weight")) {
    return(ledgr_risk_validate_max_weight(resolved))
  }
  resolved
}

ledgr_apply_risk_plan <- function(targets, risk_plan, ctx) {
  risk_plan <- ledgr_risk_validate_compiled_plan(risk_plan)
  if (length(risk_plan$steps) == 0L) {
    return(targets)
  }
  out <- targets
  for (step in risk_plan$steps) {
    out <- ledgr_apply_risk_step(out, step, ctx)
  }
  out
}

ledgr_apply_risk_step <- function(targets, step, ctx) {
  switch(
    step$type_id,
    long_only = ledgr_apply_risk_step_long_only(targets, step, ctx),
    max_weight = ledgr_apply_risk_step_max_weight(targets, step, ctx),
    rlang::abort(
      sprintf(
        "Risk step `%s` is not supported by this ledgr version.",
        step$type_id
      ),
      class = c("ledgr_unsupported_risk_step", "ledgr_risk_application_error")
    )
  )
}

ledgr_apply_risk_step_long_only <- function(targets, step, ctx) {
  force(step)
  force(ctx)
  out <- as.numeric(targets)
  out[out < 0] <- 0
  stats::setNames(out, names(targets))
}

ledgr_apply_risk_step_max_weight <- function(targets, step, ctx) {
  max_weight <- ledgr_risk_validate_max_weight(step$args$max_weight)
  equity <- ledgr_risk_context_equity(ctx)
  prices <- ledgr_risk_context_prices(ctx, names(targets))
  out <- as.numeric(targets)
  nonzero <- abs(out) > sqrt(.Machine$double.eps)
  invalid_price <- nonzero & (!is.finite(prices) | is.na(prices) | prices <= 0)
  if (any(invalid_price)) {
    rlang::abort(
      sprintf(
        "Cannot apply `ledgr_risk_max_weight()`: decision-time close price is missing, non-finite, or non-positive for: %s.",
        paste(names(targets)[invalid_price], collapse = ", ")
      ),
      class = c("ledgr_invalid_risk_context", "ledgr_risk_application_error")
    )
  }
  if (!any(nonzero) || equity == 0) {
    out[nonzero] <- 0
    return(stats::setNames(out, names(targets)))
  }
  max_abs_qty <- (as.numeric(max_weight) * equity) / prices[nonzero]
  out[nonzero] <- sign(out[nonzero]) * pmin(abs(out[nonzero]), max_abs_qty)
  stats::setNames(out, names(targets))
}

ledgr_risk_context_equity <- function(ctx) {
  equity <- ctx$equity
  if (!is.numeric(equity) || length(equity) != 1L ||
      is.na(equity) || !is.finite(equity) || equity < 0) {
    rlang::abort(
      "`ctx$equity` must be a finite non-negative numeric scalar for risk application.",
      class = c("ledgr_invalid_risk_context", "ledgr_risk_application_error")
    )
  }
  as.numeric(equity)
}

ledgr_risk_context_prices <- function(ctx, universe) {
  close_vec <- NULL
  if (is.list(ctx$vec) &&
      is.numeric(ctx$vec$close) &&
      length(ctx$vec$close) == length(universe)) {
    close_vec <- as.numeric(ctx$vec$close)
  }
  if (is.null(close_vec)) {
    if (!is.function(ctx$close)) {
      rlang::abort(
        "Risk application requires decision-time close prices from `ctx$vec$close` or `ctx$close(id)`.",
        class = c("ledgr_invalid_risk_context", "ledgr_risk_application_error")
      )
    }
    close_vec <- vapply(universe, function(id) as.numeric(ctx$close(id)), numeric(1))
  }
  stats::setNames(as.numeric(close_vec), universe)
}

ledgr_validate_post_risk_targets <- function(targets, universe) {
  tryCatch(
    ledgr_validate_strategy_targets(targets, universe),
    error = function(e) {
      rlang::abort(
        conditionMessage(e),
        class = c("ledgr_invalid_post_risk_targets", "ledgr_risk_application_error"),
        parent = e
      )
    }
  )
}

ledgr_risk_model_from_payload <- function(payload) {
  if (!is.list(payload) ||
      !identical(as.integer(payload$risk_schema_version), ledgr_risk_schema_version) ||
      !is.character(payload$type_id) || length(payload$type_id) != 1L ||
      !(payload$type_id %in% c("none", "chain")) ||
      is.null(payload$steps) || !is.list(payload$steps)) {
    rlang::abort(
      "`risk_plan_json` has an invalid ledgr risk payload shape.",
      class = c("ledgr_invalid_risk_model", "ledgr_invalid_args")
    )
  }
  if (identical(payload$type_id, "none")) {
    if (length(payload$steps) != 0L) {
      rlang::abort(
        "`risk_plan_json` has an invalid no-op risk payload shape.",
        class = c("ledgr_invalid_risk_model", "ledgr_invalid_args")
      )
    }
    return(ledgr_risk_none())
  }
  steps <- lapply(payload$steps, ledgr_risk_step_from_payload)
  if (length(steps) == 0L) {
    return(ledgr_risk_none())
  }
  do.call(ledgr_risk_chain, steps)
}

ledgr_risk_step_from_payload <- function(step) {
  if (!is.list(step) ||
      !is.character(step$type_id) || length(step$type_id) != 1L ||
      !identical(as.integer(step$schema_version), ledgr_risk_schema_version) ||
      is.null(step$args) || !is.list(step$args)) {
    rlang::abort(
      "`risk_plan_json` has an invalid ledgr risk step shape.",
      class = c("ledgr_invalid_risk_model", "ledgr_invalid_args")
    )
  }
  switch(
    step$type_id,
    long_only = ledgr_risk_long_only(),
    max_weight = ledgr_risk_max_weight(ledgr_risk_payload_arg(step$args$max_weight, "max_weight")),
    rlang::abort(
      sprintf("Unsupported risk step type: %s.", step$type_id),
      class = c("ledgr_invalid_risk_model", "ledgr_invalid_args")
    )
  )
}

ledgr_risk_payload_arg <- function(arg_payload, arg) {
  if (!is.list(arg_payload) ||
      !is.character(arg_payload$kind) || length(arg_payload$kind) != 1L) {
    rlang::abort(
      sprintf("`risk_plan_json` has an invalid `%s` argument payload.", arg),
      class = c("ledgr_invalid_risk_model", "ledgr_invalid_args")
    )
  }
  if (identical(arg_payload$kind, "param_ref")) {
    return(ledgr_param(arg_payload$name))
  }
  if (identical(arg_payload$kind, "value")) {
    return(arg_payload$value)
  }
  rlang::abort(
    sprintf("`risk_plan_json` has an unsupported `%s` argument kind.", arg),
    class = c("ledgr_invalid_risk_model", "ledgr_invalid_args")
  )
}

ledgr_risk_arg_text <- function(args) {
  if (length(args) == 0L) {
    return("")
  }
  pieces <- vapply(names(args), function(arg) {
    value <- args[[arg]]
    if (ledgr_is_param_ref(value)) {
      return(sprintf("%s=ledgr_param('%s')", arg, ledgr_param_name(value)))
    }
    sprintf("%s=%s", arg, format(value))
  }, character(1))
  paste0(" ", paste(pieces, collapse = ", "))
}
