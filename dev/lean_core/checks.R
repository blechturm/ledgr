# Lean-owned checks and computations: fold-only package functions the lean
# loop called per pulse, reimplemented here as the implementation that
# survives the switch (lean_core_interface.md Section 19 lists each with its
# switch obligation). Each accepts exactly what the package accepts, with the
# package's value; an input outside its plain accept path goes to the
# package's function, which raises the package's refusal with its class,
# message, payload and precedence. With debug on, the loop compares each
# result with the package's on every pulse.

# Debug only: the lean call's outcome against the package's function on the same
# inputs. A value must be identical; a refusal must carry the same class
# vector, message, `reason`, `instrument_ids` and parent condition. A
# difference aborts with ledgr_internal_error; otherwise the lean value is
# returned or the lean condition re-signalled.
lean_debug_same <- function(lean, pin, what, i) {
  run <- function(f) tryCatch(list(value = f()), error = function(e) list(error = e))
  sig <- function(o) {
    if (is.null(o$error)) return(list(value = o$value))
    e <- o$error
    list(class = class(e), message = conditionMessage(e), reason = e$reason, ids = e$instrument_ids,
         parent = if (inherits(e$parent, "condition")) list(class(e$parent), conditionMessage(e$parent)))
  }
  a <- run(lean)
  if (!identical(sig(a), sig(run(pin)))) {
    rlang::abort(sprintf("Lean %s differs from the pin's at pulse %d.", what, i), class = "ledgr_internal_error")
  }
  if (!is.null(a$error)) stop(a$error)
  a$value
}

# The compiled risk plan as plain steps, once per run; NULL (the package's
# path for the whole run) for a step the lean path does not take: a type
# other than long_only and max_weight, or a max_weight argument the package's
# ledgr_risk_validate_max_weight() would not return as a finite number in
# (0, 1].
lean_risk_steps <- function(risk_plan) {
  steps <- list()
  for (s in risk_plan$steps) {
    if (identical(s$type_id, "long_only")) {
      steps[[length(steps) + 1L]] <- list(long_only = TRUE)
    } else if (identical(s$type_id, "max_weight")) {
      w <- s$args$max_weight
      if (ledgr_is_param_ref(w) || !is.numeric(w) || length(w) != 1L || !is.finite(w) || w <= 0 || w > 1) return(NULL)
      steps[[length(steps) + 1L]] <- list(long_only = FALSE, max_weight = as.numeric(w))
    } else {
      return(NULL)
    }
  }
  steps
}

# The risk plan on the strategy quantities `sq` (plain doubles in axis
# order), the package's ledgr_apply_risk_plan() on a fixed basket, whose
# context reads give equity = cash + positions value and the decision close
# as each instrument's price. Returns the post-risk quantities, or NULL
# where the package refuses (equity not finite and non-negative, a nonzero
# target without a positive finite close): the caller then takes the
# package's path, which raises that refusal.
lean_risk_apply <- function(sq, steps, equity, close) {
  out <- sq
  for (s in steps) {
    if (s$long_only) {
      out[out < 0] <- 0
      next
    }
    if (!(is.finite(equity) && equity >= 0)) return(NULL)
    nz <- abs(out) > sqrt(.Machine$double.eps)
    if (any(nz & !(is.finite(close) & close > 0))) return(NULL)
    if (!any(nz) || equity == 0) {
      out[nz] <- 0
      next
    }
    cap <- (s$max_weight * equity) / close[nz]
    out[nz] <- sign(out[nz]) * pmin(abs(out[nz]), cap)
  }
  out
}

# The post-risk quantities with the package's admissibility and short-exposure
# refusals (those raise through the package's functions, with their payload).
# `targets` is the validated named target vector, `held` the named
# decision-time positions.
lean_risk_targets <- function(sq, targets, pos, held, steps, equity, close, ids, risk_plan, ctx) {
  if (is.null(steps)) return(lean_risk_pin(targets, held, risk_plan, ctx))   # a plan the lean steps do not take
  tq <- lean_risk_apply(sq, steps, equity, close)
  if (is.null(tq)) return(lean_risk_pin(targets, held, risk_plan, ctx))
  if (any(!(tq == 0 | (sign(tq) == sign(sq) & abs(tq) <= abs(sq))))) {
    ledgr_availability_validate_post_risk(stats::setNames(tq, ids), targets)
  }
  if (any(tq < 0 & tq < pos)) ledgr_availability_validate_short_exposure(stats::setNames(tq, ids), held)
  tq
}

# The package's path (the fallback, and the debug comparison).
lean_risk_pin <- function(targets, held, risk_plan, ctx) {
  risked <- ledgr_apply_risk_plan(targets, risk_plan, ctx)
  tq <- as.numeric(risked)
  ledgr_availability_validate_post_risk(risked, targets)
  if (any(tq < 0 & tq < as.numeric(held))) ledgr_availability_validate_short_exposure(risked, held)
  tq
}

# The run's cost resolver as plain steps, once per run. The lean path takes
# the package's own resolver closure (ledgr_cost_resolver_from_model(),
# recognised by its body) whose steps carry numeric scalar arguments; NULL
# (the package's resolver for the whole run) otherwise. Step types the
# package ignores stay out, as in the package.
lean_cost_steps <- function(resolver) {
  ref <- ledgr_cost_resolver_from_model(ledgr::ledgr_cost_zero())
  e <- environment(resolver)
  if (!inherits(resolver, "ledgr_cost_resolver") || !identical(body(resolver), body(ref)) || !is.list(e$steps)) return(NULL)
  num <- function(x) is.numeric(x) && length(x) == 1L
  steps <- list()
  for (s in e$steps) {
    if (identical(s$type_id, "spread_bps")) {
      if (!num(s$args$bps)) return(NULL)
      bps <- as.numeric(s$args$bps)
      steps[[length(steps) + 1L]] <- list(kind = 1L, up = 1 + bps / 20000, down = 1 - bps / 20000)
    } else if (identical(s$type_id, "fixed_fee")) {
      if (!num(s$args$amount)) return(NULL)
      steps[[length(steps) + 1L]] <- list(kind = 2L, amount = as.numeric(s$args$amount))
    } else if (identical(s$type_id, "notional_bps_fee")) {
      if (!num(s$args$bps)) return(NULL)
      steps[[length(steps) + 1L]] <- list(kind = 3L, bps = as.numeric(s$args$bps))
    }
  }
  list(steps = steps, digits = as.integer(e$price_round_digits))
}

# The package's ledgr_cost_model_resolve() for one batch, the steps in their
# compiled order on whole columns: the spread multiplies the price, each
# fee adds in turn (an order-sensitive sum), the notional fee uses the
# spread-adjusted unrounded price, and the price is rounded last. `side`,
# `qty` and `open` are the planner's own columns (integer side, doubles of
# one length), so the package's input and output shape refusals cannot fire.
lean_cost_resolve <- function(cost, side, qty, open) {
  price <- as.numeric(open)
  fee <- numeric(length(price))
  for (s in cost$steps) {
    if (s$kind == 1L) {
      price <- price * ifelse(side > 0L, s$up, s$down)
    } else if (s$kind == 2L) {
      fee <- fee + s$amount
    } else {
      fee <- fee + abs(as.numeric(qty) * price) * s$bps / 10000
    }
  }
  list(price = round(price, digits = cost$digits), fee = fee)
}

# The strategy's targets, the package's ledgr_validate_strategy_targets(raw,
# ids, allow_empty = TRUE). Two plain accept paths: a numeric vector whose
# only attribute is the axis as names, returned as it is (the package's
# targets[universe] of it is identical); and a helper's ledgr_target (class
# exactly ledgr_target, numeric; none of the intermediate classes) whose
# unclassed values are finite and named exactly by the axis, returned as
# the package returns it, unclass(raw)[ids]. `ids_ok` is the package's
# universe predicate, evaluated once per run on the fixed axis; both paths
# need it. The helper path also needs a non-empty axis: on an empty one the
# package returns the unclassed helper with its attributes. Anything else
# goes to the package's validator, which normalises it or raises its refusal.
lean_targets <- function(raw, ids, ids_attr, ids_ok) {
  if (ids_ok && is.numeric(raw) && identical(attributes(raw), ids_attr) && all(is.finite(raw))) return(raw)
  if (ids_ok && length(ids) > 0L && identical(class(raw), c("ledgr_target", "numeric"))) {
    u <- unclass(raw)
    if (is.numeric(u) && identical(names(u), ids) && all(is.finite(u))) return(u[ids])
  }
  ledgr_validate_strategy_targets(raw, ids, allow_empty = TRUE)
}

# The package's universe predicate in ledgr_validate_strategy_targets()
# (allow_empty = TRUE), for the run's fixed axis.
lean_targets_axis_ok <- function(ids) {
  is.character(ids) && !anyNA(ids) && all(nzchar(ids)) && !anyDuplicated(ids)
}

# The sizing evidence a strategy returned, the package's
# ledgr_validate_sizing_evidence(x, targets, ids, position, mark). The plain
# path takes evidence that passes every one of the package's refusal tests with
# no `sizing_unavailable` row (whose typed tests then reduce to all-finite
# quantities, priced rows that need a price, and no price on an unpriced
# row), evaluated directly rather than through vapply() and repeated
# subsets; it returns the evidence, or NULL when it is stale by the package's
# four identical(as.numeric(...)) comparisons. The plain path reads no field
# before the container's shape holds (a list of exactly the helper's class
# and fields), and takes only columns without a class, on which these
# operations equal the package's. Anything else goes to the package.
lean_sizing_fields <- c("instrument_id", "requested_quantity", "pre_floor_quantity", "rounded_quantity", "price",
                        "position_before", "reason_code")
lean_sizing_priced_codes <- c("sizing_rounded", "sizing_rounded_to_zero_addition", "sizing_rounded_to_zero_liquidation")
lean_sizing_evidence <- function(x, targets, ids, position, mark) {
  if (is.null(x)) return(NULL)
  ok <- is.list(x) && identical(class(x), "ledgr_sizing_evidence") && identical(names(x), lean_sizing_fields) &&
    !is.object(x$instrument_id) && !is.object(x$requested_quantity) && !is.object(x$pre_floor_quantity) &&
    !is.object(x$rounded_quantity) && !is.object(x$price) && !is.object(x$position_before) && !is.object(x$reason_code)
  id <- if (ok) x$instrument_id
  rc <- if (ok) x$reason_code
  ok <- ok && is.character(id) && is.character(rc) && all(lengths(x) == length(id)) && !anyNA(id) && all(nzchar(id)) &&
    !anyDuplicated(id) && is.numeric(x$requested_quantity) && is.numeric(x$pre_floor_quantity) &&
    is.numeric(x$rounded_quantity) && is.numeric(x$price) && is.numeric(x$position_before) && !anyNA(rc) &&
    all(rc %in% .ledgr_sizing_reason_codes) && !any(rc == "sizing_unavailable")
  k <- if (ok) match(id, ids)
  if (ok && !anyNA(k)) {
    priced <- is.finite(x$price) & x$price > 0
    if (all(is.finite(x$rounded_quantity)) && all(is.finite(x$position_before)) && all(is.finite(x$requested_quantity)) &&
        all(is.finite(x$pre_floor_quantity)) && all(priced[rc %in% lean_sizing_priced_codes]) && all(is.na(x$price[!priced]))) {
      free <- rep(TRUE, length(ids))
      free[k] <- FALSE
      stale <- !identical(as.numeric(x$rounded_quantity), as.numeric(targets[k])) ||
        !identical(as.numeric(x$position_before), as.numeric(position[k])) ||
        !identical(as.numeric(x$price[priced]), as.numeric(mark[k[priced]])) ||
        !identical(as.numeric(targets[free]), as.numeric(position[free]))
      return(if (stale) NULL else x)
    }
  }
  ledgr_validate_sizing_evidence(x, targets = targets, context_ids = ids, position = position, mark = mark)
}

# One declared-state field value. Accepts, unchanged, a value the package's
# ledgr_strategy_state_validate_value() returns unchanged: an attribute-free
# scalar of the declared type for a portfolio field, or a vector of the
# declared type named exactly by the axis for an asset field, with no NaN or
# infinity in a double. Anything else (a broadcast scalar, reordered names,
# a classed or otherwise attributed value, a wrong type) goes to the package.
lean_state_value <- function(value, field, axis, axis_attr) {
  plain <- if (identical(field$scope, "asset")) identical(attributes(value), axis_attr) else
    is.null(attributes(value)) && length(value) == 1L
  typed <- switch(field$type, numeric = is.double(value), integer = is.integer(value), logical = is.logical(value),
                  character = is.character(value), FALSE)
  if (plain && typed && !(is.double(value) && any(is.nan(value) | is.infinite(value)))) return(value)
  ledgr_strategy_state_validate_value(value, field, axis)
}

# A declared-state patch, the package's ledgr_strategy_state_apply_values(...,
# patch = TRUE) for a uniquely named list of declared fields; anything else
# goes to the package. `names_ok` is the run's check that the state's own names
# (`state_names`) pass the name predicate; a patch naming exactly those
# fields in that order, on a state still named so, needs no further name
# check. Typed missing values reset to the field's default scalar.
lean_state_apply <- function(update, state, fields, defaults, declaration, axis, axis_attr, state_names, names_ok) {
  if (!is.list(update) || is.data.frame(update)) {
    return(ledgr_strategy_state_apply_values(state, update, declaration, axis, patch = TRUE, default_scalars = defaults))
  }
  nm <- names(update)
  if (!(names_ok && identical(nm, state_names) && identical(names(state), state_names)) &&
      (length(update) == 0L || is.null(nm) || anyNA(nm) || !all(nzchar(nm)) || anyDuplicated(nm) ||
       !all(nm %in% names(state)) || !all(nm %in% names(fields)))) {
    return(ledgr_strategy_state_apply_values(state, update, declaration, axis, patch = TRUE, default_scalars = defaults))
  }
  for (name in nm) {
    value <- lean_state_value(update[[name]], fields[[name]], axis, axis_attr)
    reset <- is.na(value)
    if (any(reset)) value[reset] <- defaults[[name]]
    state[[name]] <- value
  }
  state
}
