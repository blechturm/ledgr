ledgr_cost_schema_version <- 1L
ledgr_timing_schema_version <- 1L

#' Transaction cost model constructors
#'
#' These constructors create deterministic, classed cost model objects for
#' ledgr execution. Cost models are experiment-level objects: strategies do not
#' receive cost state and cost models may not change fill side, quantity,
#' instrument, or execution timestamp.
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
    return(NULL)
  }
  ledgr_cost_validate_model(cost_model)
}
