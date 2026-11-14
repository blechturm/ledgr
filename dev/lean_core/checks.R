# Lean-owned checks and computations (Cut 18, amendment lean_owned): fold-only
# package functions the lean loop called per pulse on the pin, reimplemented
# here as the implementation that survives the switch (macro plan revision
# 15; lean_core_interface.md Section 19 lists each with its switch
# obligation). Each accepts exactly what the pin accepts, with the pin's
# value; an input outside its plain accept path goes to the pin's function,
# which raises the pin's refusal with its class, message, payload and
# precedence. With debug on, the loop compares each result with the pin's on
# every pulse.

# Debug only: the lean call's outcome against the pin's function on the same
# inputs. A value must be identical; a refusal must carry the same class
# vector, message, `reason`, `instrument_ids` and parent condition (cut
# review 18 amendment, A2). A difference aborts with ledgr_internal_error;
# otherwise the lean value is returned or the lean condition re-signalled.
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

# R1: the compiled risk plan as plain steps, once per run; NULL (the pin's
# path for the whole run) for a step the lean path does not take: a type
# other than long_only and max_weight, or a max_weight argument the pin's
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

# R1: the risk plan on the strategy quantities `sq` (plain doubles in axis
# order), the pin's ledgr_apply_risk_plan() on a fixed basket, whose
# context reads give equity = cash + positions value and the decision close
# as each instrument's price. Returns the post-risk quantities, or NULL
# where the pin refuses (equity not finite and non-negative, a nonzero
# target without a positive finite close): the caller then takes the pin's
# path, which raises that refusal.
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

# R1: the post-risk quantities with the pin's admissibility and short-exposure
# refusals (those raise through the pin's functions, with their payload).
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

# R1: the pin's path (the fallback, and the debug comparison).
lean_risk_pin <- function(targets, held, risk_plan, ctx) {
  risked <- ledgr_apply_risk_plan(targets, risk_plan, ctx)
  tq <- as.numeric(risked)
  ledgr_availability_validate_post_risk(risked, targets)
  if (any(tq < 0 & tq < as.numeric(held))) ledgr_availability_validate_short_exposure(risked, held)
  tq
}

# R2: the run's cost resolver as plain steps, once per run. The lean path
# takes the pin's own resolver closure (ledgr_cost_resolver_from_model(),
# recognised by its body) whose steps carry numeric scalar arguments; NULL
# (the pin's resolver for the whole run) otherwise. Step types the pin
# ignores stay out, as in the pin.
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

# R2: the pin's ledgr_cost_model_resolve() for one batch, the steps in their
# compiled order on whole columns: the spread multiplies the price, each
# fee adds in turn (an order-sensitive sum), the notional fee uses the
# spread-adjusted unrounded price, and the price is rounded last. `side`,
# `qty` and `open` are the planner's own columns (integer side, doubles of
# one length), so the pin's input and output shape refusals cannot fire.
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

# R3: the strategy's targets, the pin's ledgr_validate_strategy_targets(raw,
# ids, allow_empty = TRUE). Two plain accept paths: a numeric vector whose
# only attribute is the axis as names, returned as it is (the pin's
# targets[universe] of it is identical); and a helper's ledgr_target (class
# exactly ledgr_target, numeric; none of the intermediate classes) whose
# unclassed values are finite and named exactly by the axis, returned as
# the pin returns it, unclass(raw)[ids]. `ids_ok` is the pin's universe
# predicate, evaluated once per run on the fixed axis; both paths need it. Anything else goes to
# the pin's validator, which normalises it or raises its refusal.
lean_targets <- function(raw, ids, ids_attr, ids_ok) {
  if (ids_ok && is.numeric(raw) && identical(attributes(raw), ids_attr) && all(is.finite(raw))) return(raw)
  if (ids_ok && identical(class(raw), c("ledgr_target", "numeric"))) {
    u <- unclass(raw)
    if (is.numeric(u) && identical(names(u), ids) && all(is.finite(u))) return(u[ids])
  }
  ledgr_validate_strategy_targets(raw, ids, allow_empty = TRUE)
}

# R3: the pin's universe predicate in ledgr_validate_strategy_targets()
# (allow_empty = TRUE), for the run's fixed axis.
lean_targets_axis_ok <- function(ids) {
  is.character(ids) && !anyNA(ids) && all(nzchar(ids)) && !anyDuplicated(ids)
}

# R5: one declared-state field value. Accepts, unchanged, a value the pin's
# ledgr_strategy_state_validate_value() returns unchanged: an attribute-free
# scalar of the declared type for a portfolio field, or a vector of the
# declared type named exactly by the axis for an asset field, with no NaN or
# infinity in a double. Anything else (a broadcast scalar, reordered names,
# a classed or otherwise attributed value, a wrong type) goes to the pin.
lean_state_value <- function(value, field, axis, axis_attr) {
  plain <- if (identical(field$scope, "asset")) identical(attributes(value), axis_attr) else
    is.null(attributes(value)) && length(value) == 1L
  typed <- switch(field$type, numeric = is.double(value), integer = is.integer(value), logical = is.logical(value),
                  character = is.character(value), FALSE)
  if (plain && typed && !(is.double(value) && any(is.nan(value) | is.infinite(value)))) return(value)
  ledgr_strategy_state_validate_value(value, field, axis)
}

# R5: a declared-state patch, the pin's ledgr_strategy_state_apply_values(...,
# patch = TRUE) for a uniquely named list of declared fields; anything else
# goes to the pin. `names_ok` is the run's check that the state's own names
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
