ledgr_strategy_state_rule_version <- 1L

ledgr_strategy_state_reserved_names <- function() {
  c("targets", "state_update", "asset_state", "portfolio_state",
    "intent_reason", "reset_state")
}

ledgr_strategy_state_abort <- function(message) {
  rlang::abort(message, class = "ledgr_invalid_strategy_state")
}

ledgr_strategy_state_scalar_type <- function(value, label) {
  if (length(value) != 1L || is.object(value) || is.list(value) ||
      !(is.double(value) || is.integer(value) || is.logical(value) ||
        is.character(value))) {
    ledgr_strategy_state_abort(sprintf(
      "`%s` must be one numeric, integer, logical, or character scalar.", label
    ))
  }
  if (is.double(value) && (is.nan(value) || is.infinite(value))) {
    ledgr_strategy_state_abort(sprintf("`%s` must not be NaN or infinite.", label))
  }
  if (is.character(value) && is.na(value)) return("character")
  if (is.double(value)) return("numeric")
  typeof(value)
}

ledgr_strategy_state_normalize <- function(asset_state = list(),
                                           portfolio_state = list()) {
  declarations <- list(asset = asset_state, portfolio = portfolio_state)
  for (scope in names(declarations)) {
    value <- declarations[[scope]]
    if (!is.list(value) || is.data.frame(value) ||
        (length(value) > 0L && (is.null(names(value)) || anyNA(names(value)) ||
          any(!nzchar(names(value))) || anyDuplicated(names(value))))) {
      ledgr_strategy_state_abort(sprintf(
        "`%s_state` must be a uniquely named flat list of scalar defaults.", scope
      ))
    }
  }
  all_names <- c(names(asset_state), names(portfolio_state))
  duplicates <- unique(all_names[duplicated(all_names)])
  reserved <- intersect(all_names, ledgr_strategy_state_reserved_names())
  if (length(duplicates) > 0L) {
    ledgr_strategy_state_abort(sprintf(
      "Strategy-state field names must be unique across scopes: %s.",
      paste(duplicates, collapse = ", ")
    ))
  }
  if (length(reserved) > 0L) {
    ledgr_strategy_state_abort(sprintf(
      "Strategy-state field names are reserved: %s.", paste(reserved, collapse = ", ")
    ))
  }
  fields <- vector("list", length(all_names))
  i <- 0L
  for (scope in c("asset", "portfolio")) {
    source <- declarations[[scope]]
    for (name in names(source)) {
      i <- i + 1L
      value <- source[[name]]
      type <- ledgr_strategy_state_scalar_type(value, paste0(scope, "_state$", name))
      missing <- is.na(value)
      fields[[i]] <- list(
        scope = scope,
        name = name,
        type = type,
        shape = "scalar",
        default_missing = isTRUE(missing),
        default_value = if (isTRUE(missing)) NULL else unname(value)
      )
    }
  }
  if (length(fields) > 0L) {
    field_names <- vapply(fields, `[[`, character(1L), "name")
    fields <- fields[order(field_names, method = "radix")]
  }
  structure(
    list(rule_version = ledgr_strategy_state_rule_version, fields = fields),
    class = c("ledgr_strategy_state_declaration", "list")
  )
}

ledgr_strategy_state_declaration_validate <- function(x) {
  if (!inherits(x, "ledgr_strategy_state_declaration") ||
      !identical(as.integer(x$rule_version), ledgr_strategy_state_rule_version) ||
      !is.list(x$fields)) {
    ledgr_strategy_state_abort("Strategy-state declaration is not current.")
  }
  rebuilt_asset <- list()
  rebuilt_portfolio <- list()
  for (field in x$fields) {
    valid <- is.list(field) &&
      is.character(field$scope) && length(field$scope) == 1L &&
      !is.na(field$scope) && field$scope %in% c("asset", "portfolio") &&
      is.character(field$name) && length(field$name) == 1L &&
      !is.na(field$name) && nzchar(field$name) &&
      is.character(field$type) && length(field$type) == 1L &&
      !is.na(field$type) &&
      field$type %in% c("numeric", "integer", "logical", "character") &&
      identical(field$shape, "scalar") &&
      is.logical(field$default_missing) &&
      length(field$default_missing) == 1L && !is.na(field$default_missing)
    if (!valid) {
      ledgr_strategy_state_abort("Strategy-state declaration contains an invalid field.")
    }
    value <- if (field$default_missing) {
      switch(field$type, numeric = NA_real_, integer = NA_integer_,
        logical = NA, character = NA_character_)
    } else {
      ledgr_strategy_state_cast(field$default_value, field$type)
    }
    if (identical(field$scope, "asset")) rebuilt_asset[[field$name]] <- value
    else rebuilt_portfolio[[field$name]] <- value
  }
  expected <- ledgr_strategy_state_normalize(rebuilt_asset, rebuilt_portfolio)
  if (!identical(
      canonical_json(unclass(x)),
      canonical_json(unclass(expected))
    )) ledgr_strategy_state_abort("Strategy-state declaration is not normalized.")
  invisible(x)
}

ledgr_strategy_state_identity <- function(x) {
  ledgr_strategy_state_declaration_validate(x)
  unclass(x)
}

ledgr_strategy_state_from_identity <- function(x) {
  if (!is.list(x)) ledgr_strategy_state_abort("Config strategy_state is missing.")
  class(x) <- c("ledgr_strategy_state_declaration", "list")
  ledgr_strategy_state_declaration_validate(x)
  asset <- list()
  portfolio <- list()
  for (field in x$fields) {
    value <- if (isTRUE(field$default_missing)) {
      switch(field$type, numeric = NA_real_, integer = NA_integer_,
        logical = NA, character = NA_character_)
    } else {
      ledgr_strategy_state_cast(field$default_value, field$type)
    }
    if (identical(field$scope, "asset")) asset[[field$name]] <- value
    else portfolio[[field$name]] <- value
  }
  ledgr_strategy_state_normalize(asset, portfolio)
}

ledgr_strategy_state_cast <- function(value, type) {
  switch(type,
    numeric = as.double(value), integer = as.integer(value),
    logical = as.logical(value), character = as.character(value)
  )
}

ledgr_strategy_state_default_value <- function(field, n = 1L, names = NULL) {
  value <- if (field$default_missing) {
    switch(field$type, numeric = NA_real_, integer = NA_integer_,
      logical = NA, character = NA_character_)
  } else {
    ledgr_strategy_state_cast(field$default_value, field$type)
  }
  out <- rep(value, n)
  if (!is.null(names)) names(out) <- names
  out
}

ledgr_strategy_state_default_scalars <- function(declaration) {
  values <- vector("list", length(declaration$fields))
  names(values) <- vapply(declaration$fields, `[[`, character(1L), "name")
  for (i in seq_along(declaration$fields)) {
    values[[i]] <- ledgr_strategy_state_default_value(declaration$fields[[i]])
  }
  values
}

ledgr_strategy_state_defaults <- function(declaration, axis,
                                          default_scalars = NULL) {
  axis <- as.character(axis)
  if (anyNA(axis) || any(!nzchar(axis)) || anyDuplicated(axis)) {
    ledgr_strategy_state_abort("Strategy-state asset axis must use unique non-empty IDs.")
  }
  if (is.null(default_scalars)) {
    default_scalars <- ledgr_strategy_state_default_scalars(declaration)
  }
  values <- vector("list", length(default_scalars))
  names(values) <- names(default_scalars)
  for (i in seq_along(declaration$fields)) {
    field <- declaration$fields[[i]]
    values[[i]] <- if (identical(field$scope, "asset")) {
      out <- rep(default_scalars[[i]], length(axis))
      names(out) <- axis
      out
    } else {
      default_scalars[[i]]
    }
  }
  values
}

ledgr_strategy_state_view <- function(values) {
  structure(lapply(values, function(x) {
    if (is.atomic(x)) x[] else x
  }), class = c("ledgr_strategy_state_view", "list"))
}

#' @export
`$.ledgr_strategy_state_view` <- function(x, name) {
  value <- .subset2(unclass(x), name)
  if (is.null(value) && !name %in% names(unclass(x))) {
    ledgr_strategy_state_abort(sprintf("Unknown declared strategy-state field `%s`.", name))
  }
  value
}

#' @export
`[[.ledgr_strategy_state_view` <- function(x, i, ...) {
  if (!is.character(i) || length(i) != 1L || is.na(i) || !nzchar(i)) {
    ledgr_strategy_state_abort(
      "Declared strategy state must be read by its field name."
    )
  }
  value <- .subset2(unclass(x), i)
  if (is.null(value) && !i %in% names(unclass(x))) {
    ledgr_strategy_state_abort(sprintf(
      "Unknown declared strategy-state field `%s`.", i
    ))
  }
  value
}

ledgr_strategy_state_field <- function(declaration, name) {
  names <- vapply(declaration$fields, `[[`, character(1L), "name")
  i <- match(name, names)
  if (is.na(i)) ledgr_strategy_state_abort(sprintf(
    "Unknown declared strategy-state field `%s`.", name
  ))
  declaration$fields[[i]]
}

ledgr_strategy_state_validate_value <- function(value, field, axis,
                                                allow_broadcast = TRUE) {
  if (is.object(value) || (!is.null(attributes(value)) &&
      !identical(names(attributes(value)), "names"))) {
    ledgr_strategy_state_abort(sprintf(
      "Strategy-state field `%s` must be an unclassed atomic value.", field$name
    ))
  }
  is_asset <- identical(field$scope, "asset")
  if (is_asset && length(value) == 1L && is.null(names(value)) && allow_broadcast) {
    value <- rep(value, length(axis))
    names(value) <- axis
  } else if (is_asset) {
    value_names <- names(value)
    if (!identical(value_names, axis)) {
      index <- match(axis, value_names)
      if (length(value_names) != length(axis) || anyNA(value_names) ||
          any(!nzchar(value_names)) || anyDuplicated(value_names) || anyNA(index)) {
        ledgr_strategy_state_abort(sprintf(
          "Asset state `%s` must be an unnamed scalar or a named full-axis vector.",
          field$name
        ))
      }
      value <- value[index]
    }
  } else if (length(value) != 1L || !is.null(names(value))) {
    ledgr_strategy_state_abort(sprintf("Portfolio state `%s` must stay scalar.", field$name))
  }
  type_ok <- switch(field$type,
    numeric = is.double(value), integer = is.integer(value),
    logical = is.logical(value), character = is.character(value), FALSE
  )
  if (!type_ok) ledgr_strategy_state_abort(sprintf(
    "Strategy-state field `%s` must have declared type %s.", field$name, field$type
  ))
  if (is.double(value) && any(is.nan(value) | is.infinite(value))) {
    ledgr_strategy_state_abort(sprintf(
      "Strategy-state field `%s` must not contain NaN or infinity.", field$name
    ))
  }
  value
}

ledgr_strategy_state_align <- function(values, declaration, from_axis, to_axis,
                                       default_scalars = NULL) {
  defaults <- ledgr_strategy_state_defaults(
    declaration, to_axis, default_scalars = default_scalars
  )
  if (length(values) == 0L) return(defaults)
  unknown <- setdiff(names(values), names(defaults))
  if (length(unknown) > 0L) ledgr_strategy_state_abort(sprintf(
    "Persisted strategy state contains undeclared fields: %s.", paste(unknown, collapse = ", ")
  ))
  for (field in declaration$fields) {
    name <- field$name
    if (!name %in% names(values)) next
    value <- values[[name]]
    if (identical(field$scope, "asset")) {
      if (is.null(names(value))) names(value) <- from_axis
      keep <- match(to_axis, names(value))
      present <- !is.na(keep)
      defaults[[name]][present] <- value[keep[present]]
    } else {
      defaults[[name]] <- value
    }
  }
  defaults
}

ledgr_strategy_state_apply_values <- function(previous, update, declaration,
                                              axis, patch = FALSE,
                                              default_scalars = NULL) {
  if (!is.list(update) || is.data.frame(update) ||
      (length(update) > 0L && (is.null(names(update)) || anyNA(names(update)) ||
        any(!nzchar(names(update))) || anyDuplicated(names(update))))) {
    ledgr_strategy_state_abort("Strategy state update must be a uniquely named list.")
  }
  unknown <- setdiff(names(update), names(previous))
  if (length(unknown) > 0L) ledgr_strategy_state_abort(sprintf(
    "Strategy state update contains undeclared fields: %s.", paste(unknown, collapse = ", ")
  ))
  if (is.null(default_scalars)) {
    default_scalars <- ledgr_strategy_state_default_scalars(declaration)
  }
  out <- if (patch) previous else ledgr_strategy_state_defaults(
    declaration, axis, default_scalars = default_scalars
  )
  for (name in names(update)) {
    field <- ledgr_strategy_state_field(declaration, name)
    value <- ledgr_strategy_state_validate_value(update[[name]], field, axis)
    reset <- is.na(value)
    if (any(reset)) {
      value[reset] <- default_scalars[[name]]
    }
    out[[name]] <- value
  }
  out
}

#' Return targets with a declared strategy-state patch
#'
#' @param targets Complete named target quantities.
#' @param ... Named declared strategy-state fields to patch. A typed missing
#'   value restores that field's declared default.
#' @param intent_reason Optional non-empty decision note.
#' @param reset_state Whether to restore every declared default. It cannot be
#'   combined with state fields in `...`.
#' @return A structured ledgr strategy result.
#' @export
ledgr_strategy_result <- function(targets, ..., intent_reason = NULL,
                                  reset_state = FALSE) {
  patch <- list(...)
  if (length(patch) > 0L && (is.null(names(patch)) || any(!nzchar(names(patch))) ||
      anyDuplicated(names(patch)))) {
    ledgr_strategy_state_abort("Strategy-state patches must use unique field names.")
  }
  if (!is.logical(reset_state) || length(reset_state) != 1L || is.na(reset_state)) {
    ledgr_strategy_state_abort("`reset_state` must be TRUE or FALSE.")
  }
  if (isTRUE(reset_state) && length(patch) > 0L) {
    ledgr_strategy_state_abort("`reset_state = TRUE` cannot be combined with state patches.")
  }
  list(
    targets = targets,
    state_update = if (isTRUE(reset_state)) {
      structure(list(), class = "ledgr_strategy_state_reset")
    } else {
      structure(patch, class = "ledgr_strategy_state_patch")
    },
    intent_reason = intent_reason
  )
}
