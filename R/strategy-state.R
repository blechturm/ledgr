ledgr_strategy_state_rule_version <- 1L

ledgr_strategy_state_cursor_marker <- "__ledgr_strategy_state_unchanged_v1__"

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

ledgr_strategy_state_defaults <- function(declaration, axis) {
  ledgr_strategy_state_declaration_validate(declaration)
  axis <- as.character(axis)
  if (anyNA(axis) || any(!nzchar(axis)) || anyDuplicated(axis)) {
    ledgr_strategy_state_abort("Strategy-state asset axis must use unique non-empty IDs.")
  }
  values <- vector("list", length(declaration$fields))
  names(values) <- vapply(declaration$fields, `[[`, character(1L), "name")
  for (i in seq_along(declaration$fields)) {
    field <- declaration$fields[[i]]
    values[[i]] <- if (identical(field$scope, "asset")) {
      ledgr_strategy_state_default_value(field, length(axis), axis)
    } else {
      ledgr_strategy_state_default_value(field)
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
  is_asset <- identical(field$scope, "asset")
  if (is_asset && length(value) == 1L && is.null(names(value)) && allow_broadcast) {
    value <- rep(value, length(axis))
    names(value) <- axis
  } else if (is_asset) {
    if (is.null(names(value)) || anyNA(names(value)) || any(!nzchar(names(value))) ||
        anyDuplicated(names(value)) || !setequal(names(value), axis)) {
      ledgr_strategy_state_abort(sprintf(
        "Asset state `%s` must be an unnamed scalar or a named full-axis vector.",
        field$name
      ))
    }
    value <- value[axis]
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

ledgr_strategy_state_align <- function(values, declaration, from_axis, to_axis) {
  defaults <- ledgr_strategy_state_defaults(declaration, to_axis)
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
                                              axis, patch = FALSE) {
  if (!is.list(update) || is.data.frame(update) ||
      (length(update) > 0L && (is.null(names(update)) || anyNA(names(update)) ||
        any(!nzchar(names(update))) || anyDuplicated(names(update))))) {
    ledgr_strategy_state_abort("Strategy state update must be a uniquely named list.")
  }
  unknown <- setdiff(names(update), names(previous))
  if (length(unknown) > 0L) ledgr_strategy_state_abort(sprintf(
    "Strategy state update contains undeclared fields: %s.", paste(unknown, collapse = ", ")
  ))
  out <- if (patch) previous else ledgr_strategy_state_defaults(declaration, axis)
  for (name in names(update)) {
    field <- ledgr_strategy_state_field(declaration, name)
    value <- ledgr_strategy_state_validate_value(update[[name]], field, axis)
    reset <- is.na(value)
    if (any(reset)) {
      defaults <- ledgr_strategy_state_defaults(declaration, axis)[[name]]
      value[reset] <- defaults[reset]
    }
    out[[name]] <- value
  }
  out
}

ledgr_strategy_state_encode <- function(values, declaration, axis) {
  fields <- vector("list", length(declaration$fields))
  for (i in seq_along(declaration$fields)) {
    field <- declaration$fields[[i]]
    value <- ledgr_strategy_state_validate_value(values[[field$name]], field, axis,
      allow_broadcast = FALSE)
    missing <- is.na(value)
    safe <- value
    safe[missing] <- switch(field$type,
      numeric = 0, integer = 0L, logical = FALSE, character = "")
    fields[[i]] <- list(
      name = field$name, type = field$type,
      missing = as.logical(missing), value = unname(safe)
    )
  }
  canonical_json(list(
    rule_version = ledgr_strategy_state_rule_version,
    axis = as.character(axis), fields = fields
  ))
}

ledgr_strategy_state_decode <- function(json, declaration) {
  if (!is.character(json) || length(json) != 1L || is.na(json) ||
      !nzchar(json) || identical(json, ledgr_strategy_state_cursor_marker)) {
    ledgr_strategy_state_abort(
      "Persisted strategy state is not a current typed checkpoint."
    )
  }
  decoded <- tryCatch(
    ledgr_json_read_nested(json),
    error = function(cnd) {
      rlang::abort(
        "Persisted strategy state is not valid JSON.",
        class = "ledgr_invalid_strategy_state",
        parent = cnd
      )
    }
  )
  axis_is_empty_array <- is.list(decoded$axis) && length(decoded$axis) == 0L
  if (!is.list(decoded) ||
      !identical(as.integer(decoded$rule_version), ledgr_strategy_state_rule_version) ||
      !(is.character(decoded$axis) || axis_is_empty_array) ||
      !is.list(decoded$fields)) {
    ledgr_strategy_state_abort("Persisted strategy state is not a current typed checkpoint.")
  }
  axis <- if (axis_is_empty_array) character() else as.character(decoded$axis)
  if (anyNA(axis) || any(!nzchar(axis)) || anyDuplicated(axis)) {
    ledgr_strategy_state_abort(
      "Persisted strategy state has an invalid asset axis."
    )
  }
  out <- ledgr_strategy_state_defaults(declaration, axis)
  seen <- character()
  for (entry in decoded$fields) {
    if (!is.list(entry) || !is.character(entry$name) || length(entry$name) != 1L) {
      ledgr_strategy_state_abort("Persisted strategy state contains a malformed field.")
    }
    field <- ledgr_strategy_state_field(declaration, entry$name)
    if (!identical(entry$type, field$type) || entry$name %in% seen) {
      ledgr_strategy_state_abort("Persisted strategy-state type or field identity differs from its declaration.")
    }
    seen <- c(seen, entry$name)
    value <- ledgr_strategy_state_cast(unlist(entry$value, use.names = FALSE), field$type)
    missing <- as.logical(unlist(entry$missing, use.names = FALSE))
    expected_n <- if (identical(field$scope, "asset")) length(axis) else 1L
    if (length(value) != expected_n || length(missing) != expected_n || anyNA(missing)) {
      ledgr_strategy_state_abort("Persisted strategy-state field has the wrong shape.")
    }
    value[missing] <- switch(field$type,
      numeric = NA_real_, integer = NA_integer_, logical = NA, character = NA_character_)
    if (identical(field$scope, "asset")) names(value) <- axis
    out[[field$name]] <- value
  }
  if (!setequal(seen, names(out))) {
    ledgr_strategy_state_abort("Persisted strategy state omits a declared field.")
  }
  list(values = out, axis = axis)
}

ledgr_strategy_state_equal <- function(x, y) identical(x, y)

ledgr_strategy_state_restore <- function(con, run_id, ts_utc,
                                         declaration, resume_axis) {
  ts_iso <- ledgr_normalize_ts_utc(ts_utc)
  cursor <- DBI::dbGetQuery(con, paste(
    "SELECT ts_utc FROM strategy_state",
    "WHERE run_id = ? AND ts_utc < ? ORDER BY ts_utc DESC LIMIT 1"
  ), params = list(run_id, ts_iso))
  defaults <- ledgr_strategy_state_defaults(declaration, resume_axis)
  if (nrow(cursor) == 0L) return(list(values = defaults, axis = resume_axis))
  payload <- DBI::dbGetQuery(con, paste(
    "SELECT state_json FROM strategy_state",
    "WHERE run_id = ? AND ts_utc <= ? AND state_json <> ?",
    "ORDER BY ts_utc DESC LIMIT 1"
  ), params = list(run_id, cursor$ts_utc[[1L]], ledgr_strategy_state_cursor_marker))
  if (nrow(payload) == 0L) return(list(values = defaults, axis = resume_axis))
  restored <- ledgr_strategy_state_decode(payload$state_json[[1L]], declaration)
  list(
    values = ledgr_strategy_state_align(
      restored$values, declaration, restored$axis, resume_axis
    ),
    axis = resume_axis
  )
}

#' Return targets with a declared strategy-state patch
#'
#' @param targets Complete named target quantities.
#' @param ... Named declared strategy-state fields to patch.
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
