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
