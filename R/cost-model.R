ledgr_cost_schema_version <- 1L
ledgr_timing_schema_version <- 1L

#' Transaction cost model constructors
#'
#' These constructors create deterministic, classed cost model objects for
#' ledgr execution. Cost models are experiment-level objects: strategies do not
#' receive cost state and cost models may not change fill side, quantity,
#' instrument, or execution timestamp.
#' Cost identity is stored as `cost_plan_json` plus `cost_model_hash`; see
#' [ledgr_identity_fields] for how those fields relate to run and candidate
#' identity.
#'
#' @param bps Finite non-negative basis-point value.
#' @param amount Finite non-negative fixed fee per fill.
#' @param ... Cost model objects to compose in order.
#' @return A `ledgr_cost_model` object.
#' @examples
#' ledgr_cost_spread_bps(5)
#' ledgr_cost_fixed_fee(1)
#' ledgr_cost_chain(ledgr_cost_spread_bps(5), ledgr_cost_fixed_fee(1))
#' ledgr_cost_zero()
#' @export
ledgr_cost_spread_bps <- function(bps) {
  ledgr_cost_model(
    type_id = "spread_bps",
    stage = "price_transform",
    args = list(bps = ledgr_cost_validate_nonnegative_scalar(bps, "bps"))
  )
}

#' @rdname ledgr_cost_spread_bps
#' @export
ledgr_cost_fixed_fee <- function(amount) {
  ledgr_cost_model(
    type_id = "fixed_fee",
    stage = "fee_adder",
    args = list(amount = ledgr_cost_validate_nonnegative_scalar(amount, "amount"))
  )
}

#' @rdname ledgr_cost_spread_bps
#' @export
ledgr_cost_notional_bps_fee <- function(bps) {
  ledgr_cost_model(
    type_id = "notional_bps_fee",
    stage = "fee_adder",
    args = list(bps = ledgr_cost_validate_nonnegative_scalar(bps, "bps"))
  )
}

#' @rdname ledgr_cost_spread_bps
#' @export
ledgr_cost_zero <- function() {
  ledgr_cost_model(
    type_id = "zero",
    stage = "identity",
    args = list()
  )
}

#' @rdname ledgr_cost_spread_bps
#' @export
ledgr_cost_chain <- function(...) {
  children <- list(...)
  if (length(children) == 0L) {
    return(ledgr_cost_zero())
  }
  children <- ledgr_cost_flatten_children(children)
  if (length(children) == 0L) {
    return(ledgr_cost_zero())
  }
  ledgr_cost_validate_chain_order(children)
  ledgr_cost_model(
    type_id = "chain",
    stage = "chain",
    args = list(),
    children = children
  )
}

#' Inspect cost model structure
#'
#' `ledgr_cost_steps()` returns deterministic step descriptors for a cost
#' model. `ledgr_cost_describe()` returns a compact human-readable summary.
#'
#' @param cost_model A `ledgr_cost_model` object.
#' @return `ledgr_cost_steps()` returns a list; `ledgr_cost_describe()` returns
#'   a character scalar.
#' @examples
#' cost <- ledgr_cost_chain(ledgr_cost_spread_bps(5), ledgr_cost_fixed_fee(1))
#' ledgr_cost_steps(cost)
#' ledgr_cost_describe(cost)
#' @export
ledgr_cost_steps <- function(cost_model) {
  cost_model <- ledgr_cost_validate_model(cost_model)
  steps <- ledgr_cost_flat_steps(cost_model)
  if (length(steps) == 0L) {
    return(list())
  }
  lapply(seq_along(steps), function(i) {
    step <- steps[[i]]
    list(
      position = i,
      type_id = step$type_id,
      version = step$version,
      stage = step$stage,
      args = step$args
    )
  })
}

#' @rdname ledgr_cost_steps
#' @export
ledgr_cost_describe <- function(cost_model) {
  cost_model <- ledgr_cost_validate_model(cost_model)
  steps <- ledgr_cost_steps(cost_model)
  hash <- ledgr_cost_model_hash(cost_model)
  if (length(steps) == 0L) {
    return(sprintf("ledgr cost model: zero cost (hash %s)", substr(hash, 1L, 12L)))
  }
  step_lines <- vapply(steps, function(step) {
    args <- names(step$args)
    arg_text <- if (length(args) == 0L) {
      ""
    } else {
      paste(sprintf("%s=%s", args, unlist(step$args, use.names = FALSE)), collapse = ", ")
    }
    sprintf("%d. %s [%s]%s%s",
            step$position,
            step$type_id,
            step$stage,
            if (nzchar(arg_text)) " " else "",
            arg_text)
  }, character(1))
  paste(c(sprintf("ledgr cost model: %d step(s), hash %s", length(steps), substr(hash, 1L, 12L)), step_lines), collapse = "\n")
}

#' Timing model constructor
#'
#' `ledgr_timing_next_open()` creates ledgr's v1 next-open timing model. The
#' timing model proposes fills; cost models resolve prices and explicit fees.
#'
#' @return A `ledgr_timing_model` object.
#' @examples
#' ledgr_timing_next_open()
#' @export
ledgr_timing_next_open <- function() {
  structure(
    list(
      timing_schema_version = ledgr_timing_schema_version,
      type_id = "next_open",
      version = 1L,
      args = list()
    ),
    class = c("ledgr_timing_next_open", "ledgr_timing_model")
  )
}

ledgr_cost_model <- function(type_id, stage, args = list(), children = list(), version = 1L) {
  structure(
    list(
      cost_schema_version = ledgr_cost_schema_version,
      type_id = type_id,
      version = as.integer(version),
      stage = stage,
      args = args,
      children = children
    ),
    class = c(paste0("ledgr_cost_", type_id), "ledgr_cost_model")
  )
}

ledgr_cost_validate_nonnegative_scalar <- function(x, arg) {
  if (!is.numeric(x) || length(x) != 1L || is.na(x) || !is.finite(x) || x < 0) {
    rlang::abort(
      sprintf("`%s` must be a finite numeric scalar >= 0.", arg),
      class = "ledgr_invalid_cost_model"
    )
  }
  as.numeric(x)
}

ledgr_cost_validate_model <- function(cost_model) {
  if (!inherits(cost_model, "ledgr_cost_model")) {
    rlang::abort("`cost_model` must be a ledgr cost model object.", class = "ledgr_invalid_cost_model")
  }
  if (!is.list(cost_model) ||
      !identical(cost_model$cost_schema_version, ledgr_cost_schema_version) ||
      !is.character(cost_model$type_id) || length(cost_model$type_id) != 1L ||
      !is.character(cost_model$stage) || length(cost_model$stage) != 1L ||
      !is.list(cost_model$args) ||
      !is.list(cost_model$children)) {
    rlang::abort("`cost_model` has an invalid ledgr cost model shape.", class = "ledgr_invalid_cost_model")
  }
  cost_model
}

ledgr_cost_flatten_children <- function(children) {
  out <- list()
  for (child in children) {
    child <- ledgr_cost_validate_model(child)
    if (identical(child$type_id, "zero")) {
      next
    }
    if (identical(child$type_id, "chain")) {
      out <- c(out, ledgr_cost_flatten_children(child$children))
    } else {
      out[[length(out) + 1L]] <- child
    }
  }
  out
}

ledgr_cost_validate_chain_order <- function(children) {
  saw_fee <- FALSE
  for (i in seq_along(children)) {
    stage <- children[[i]]$stage
    if (identical(stage, "fee_adder")) {
      saw_fee <- TRUE
    } else if (identical(stage, "price_transform") && saw_fee) {
      rlang::abort(
        sprintf("Invalid cost chain order: price transform at step %d follows a fee adder.", i),
        class = "ledgr_invalid_cost_chain_order"
      )
    } else if (!stage %in% c("price_transform", "fee_adder", "identity")) {
      rlang::abort("Invalid cost chain stage.", class = "ledgr_invalid_cost_model")
    }
  }
  invisible(TRUE)
}

ledgr_cost_flat_steps <- function(cost_model) {
  cost_model <- ledgr_cost_validate_model(cost_model)
  if (identical(cost_model$type_id, "zero")) {
    return(list())
  }
  if (identical(cost_model$type_id, "chain")) {
    return(ledgr_cost_flatten_children(cost_model$children))
  }
  list(cost_model)
}

ledgr_cost_model_payload <- function(cost_model) {
  cost_model <- ledgr_cost_validate_model(cost_model)
  list(
    cost_schema_version = cost_model$cost_schema_version,
    type_id = cost_model$type_id,
    version = cost_model$version,
    args = cost_model$args,
    steps = lapply(ledgr_cost_flat_steps(cost_model), function(step) {
      list(
        type_id = step$type_id,
        version = step$version,
        stage = step$stage,
        args = step$args
      )
    })
  )
}

ledgr_cost_plan_json <- function(cost_model) {
  as.character(canonical_json(ledgr_cost_model_payload(cost_model)))
}

ledgr_cost_model_hash <- function(cost_model) {
  digest::digest(ledgr_cost_plan_json(cost_model), algo = "sha256")
}

ledgr_cost_model_unspecified <- function(arg = "cost_model") {
  rlang::abort(
    sprintf("`%s` is required. Use ledgr_cost_zero() for explicit zero-cost execution.", arg),
    class = "ledgr_cost_model_unspecified"
  )
}

ledgr_legacy_fill_model_abort <- function(arg = "fill_model") {
  rlang::abort(
    sprintf("`%s` is a legacy v0.1.8 shape and is no longer accepted. Use `timing_model` plus `cost_model`.", arg),
    class = "ledgr_legacy_fill_model_shape"
  )
}

ledgr_experiment_normalize_timing_model <- function(timing_model) {
  if (!inherits(timing_model, "ledgr_timing_model")) {
    rlang::abort("`timing_model` must be a ledgr timing model object.", class = "ledgr_invalid_timing_model")
  }
  if (!is.list(timing_model) ||
      !identical(timing_model$timing_schema_version, ledgr_timing_schema_version) ||
      !identical(timing_model$type_id, "next_open") ||
      !identical(as.integer(timing_model$version), 1L)) {
    rlang::abort("`timing_model` has an invalid ledgr timing model shape.", class = "ledgr_invalid_timing_model")
  }
  timing_model
}

ledgr_experiment_normalize_cost_model <- function(cost_model) {
  if (is.null(cost_model)) {
    ledgr_cost_model_unspecified()
  }
  ledgr_cost_validate_model(cost_model)
}

ledgr_cost_plan_reconstruct <- function(cost_plan_json) {
  if (!is.character(cost_plan_json) || length(cost_plan_json) != 1L ||
      is.na(cost_plan_json) || !nzchar(cost_plan_json)) {
    rlang::abort("`cost_plan_json` must be a non-empty character scalar.", class = "ledgr_invalid_cost_model")
  }
  payload <- tryCatch(
    ledgr_json_read_nested(cost_plan_json),
    error = function(e) {
      rlang::abort("`cost_plan_json` is not valid JSON.", class = "ledgr_invalid_cost_model", parent = e)
    }
  )
  ledgr_cost_model_from_payload(payload)
}

ledgr_cost_model_from_payload <- function(payload) {
  if (!is.list(payload) ||
      !identical(as.integer(payload$cost_schema_version), ledgr_cost_schema_version) ||
      !is.character(payload$type_id) || length(payload$type_id) != 1L ||
      !is.list(payload$args) ||
      is.null(payload$steps) || !is.list(payload$steps)) {
    rlang::abort("`cost_plan_json` has an invalid ledgr cost payload shape.", class = "ledgr_invalid_cost_model")
  }
  steps <- lapply(payload$steps, ledgr_cost_step_from_payload)
  if (length(steps) == 0L) {
    return(ledgr_cost_zero())
  }
  do.call(ledgr_cost_chain, steps)
}

ledgr_cost_step_from_payload <- function(step) {
  if (!is.list(step) ||
      !is.character(step$type_id) || length(step$type_id) != 1L ||
      !is.list(step$args)) {
    rlang::abort("`cost_plan_json` has an invalid ledgr cost step shape.", class = "ledgr_invalid_cost_model")
  }
  switch(
    step$type_id,
    spread_bps = ledgr_cost_spread_bps(step$args$bps),
    fixed_fee = ledgr_cost_fixed_fee(step$args$amount),
    notional_bps_fee = ledgr_cost_notional_bps_fee(step$args$bps),
    zero = ledgr_cost_zero(),
    rlang::abort(sprintf("Unsupported cost step type: %s.", step$type_id), class = "ledgr_invalid_cost_model")
  )
}

ledgr_cost_resolver_from_model <- function(cost_model, price_round_digits = 8L) {
  cost_model <- ledgr_cost_validate_model(cost_model)
  steps <- ledgr_cost_flat_steps(cost_model)
  force(steps)
  force(price_round_digits)
  resolver <- function(proposal, fill_context) {
    ledgr_cost_model_resolve(
      proposal = proposal,
      fill_context = fill_context,
      steps = steps,
      price_round_digits = price_round_digits
    )
  }
  structure(resolver, class = c("ledgr_cost_resolver", "function"))
}

ledgr_cost_resolver_from_plan_json <- function(cost_plan_json, price_round_digits = 8L) {
  ledgr_cost_resolver_from_model(
    ledgr_cost_plan_reconstruct(cost_plan_json),
    price_round_digits = price_round_digits
  )
}

ledgr_cost_model_resolve <- function(proposal,
                                     fill_context,
                                     steps,
                                     price_round_digits = 8L) {
  if (!inherits(proposal, "ledgr_fill_proposal")) {
    rlang::abort("`proposal` must be a ledgr_fill_proposal.", class = "ledgr_invalid_fill_proposal")
  }
  if (!inherits(fill_context, "ledgr_fill_context")) {
    rlang::abort("`fill_context` must be a ledgr_fill_context.", class = "ledgr_invalid_fill_context")
  }

  side <- proposal$side
  qty <- proposal$qty
  instrument_id <- proposal$instrument_id
  ts_exec_utc <- proposal$ts_exec_utc
  price <- fill_context$execution_bar$open
  fee <- 0

  for (step in steps) {
    if (identical(step$type_id, "spread_bps")) {
      bps <- as.numeric(step$args$bps)
      multiplier <- if (identical(side, "BUY")) (1 + bps / 20000) else (1 - bps / 20000)
      price <- price * multiplier
    } else if (identical(step$type_id, "fixed_fee")) {
      fee <- fee + as.numeric(step$args$amount)
    } else if (identical(step$type_id, "notional_bps_fee")) {
      fee <- fee + abs(as.numeric(qty) * as.numeric(price)) * as.numeric(step$args$bps) / 10000
    }
  }
  fill_price <- round(as.numeric(price), digits = as.integer(price_round_digits))

  structure(
    list(
      instrument_id = instrument_id,
      side = side,
      qty = qty,
      fill_price = fill_price,
      fee = as.numeric(fee),
      ts_exec_utc = ts_exec_utc
    ),
    class = "ledgr_fill_intent"
  )
}
