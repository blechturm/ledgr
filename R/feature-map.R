#' Create a feature map
#'
#' `ledgr_feature_map()` bundles user-facing aliases with ledgr indicator
#' definitions. The map is an authoring convenience: experiments register the
#' underlying indicators, while strategies can later use the aliases for
#' pulse-time feature lookup.
#'
#' @param ... For `ledgr_feature_map()`, named `ledgr_indicator` objects.
#'   Names are strategy-facing aliases. For the print method, unused.
#' @return A `ledgr_feature_map` object.
#' @export
ledgr_feature_map <- function(...) {
  indicators <- list(...)
  aliases <- names(indicators)

  if (length(indicators) < 1L) {
    rlang::abort(
      "`...` must contain at least one named ledgr_indicator object.",
      class = c("ledgr_invalid_feature_map", "ledgr_invalid_args")
    )
  }

  ledgr_validate_feature_map_aliases(aliases, length(indicators))

  bad <- which(!vapply(indicators, inherits, logical(1), what = "ledgr_indicator"))
  if (length(bad) > 0L) {
    bad_alias <- aliases[[bad[[1L]]]]
    rlang::abort(
      sprintf("Feature map entry `%s` must be a ledgr_indicator object.", bad_alias),
      class = c("ledgr_invalid_feature_map", "ledgr_invalid_args")
    )
  }

  feature_ids <- ledgr_feature_id(indicators)
  ledgr_abort_duplicate_feature_ids(feature_ids)

  indicators <- stats::setNames(unname(indicators), aliases)
  feature_ids <- stats::setNames(unname(feature_ids), aliases)

  structure(
    list(
      aliases = aliases,
      indicators = indicators,
      feature_ids = feature_ids
    ),
    class = "ledgr_feature_map"
  )
}

ledgr_validate_feature_map_aliases <- function(aliases, n) {
  if (is.null(aliases) || length(aliases) != n) {
    rlang::abort(
      "Feature map entries must be named.",
      class = c("ledgr_invalid_feature_map", "ledgr_invalid_args")
    )
  }
  if (anyNA(aliases) || any(!nzchar(aliases))) {
    rlang::abort(
      "Feature map aliases must be non-empty and non-NA.",
      class = c("ledgr_invalid_feature_map", "ledgr_invalid_args")
    )
  }
  if (anyDuplicated(aliases)) {
    dup <- unique(aliases[duplicated(aliases)])
    rlang::abort(
      sprintf("Feature map aliases must be unique; duplicate alias: %s.", dup[[1L]]),
      class = c("ledgr_invalid_feature_map", "ledgr_invalid_args")
    )
  }
  invalid <- aliases[make.names(aliases) != aliases]
  if (length(invalid) > 0L) {
    rlang::abort(
      sprintf("Feature map aliases must be syntactically valid R names; invalid alias: %s.", invalid[[1L]]),
      class = c("ledgr_invalid_feature_map", "ledgr_invalid_args")
    )
  }
  invisible(TRUE)
}

ledgr_feature_map_indicators <- function(x, named = FALSE) {
  ledgr_validate_feature_map_object(x)
  indicators <- unname(x$indicators)
  if (isTRUE(named)) {
    indicators <- stats::setNames(indicators, names(x$indicators))
  }
  indicators
}

ledgr_validate_feature_map_object <- function(x) {
  if (!inherits(x, "ledgr_feature_map")) {
    rlang::abort(
      "`x` must be a ledgr_feature_map object.",
      class = c("ledgr_invalid_feature_map", "ledgr_invalid_args")
    )
  }
  aliases <- x$aliases
  indicators <- x$indicators
  feature_ids <- x$feature_ids

  if (!is.list(indicators) || length(indicators) < 1L) {
    rlang::abort(
      "`x$indicators` must be a non-empty list.",
      class = c("ledgr_invalid_feature_map", "ledgr_invalid_args")
    )
  }
  ledgr_validate_feature_map_aliases(aliases, length(indicators))

  if (is.null(names(indicators)) || !identical(names(indicators), aliases)) {
    rlang::abort(
      "`x$indicators` names must match `x$aliases`.",
      class = c("ledgr_invalid_feature_map", "ledgr_invalid_args")
    )
  }
  bad <- which(!vapply(indicators, inherits, logical(1), what = "ledgr_indicator"))
  if (length(bad) > 0L) {
    rlang::abort(
      sprintf("Feature map entry `%s` must be a ledgr_indicator object.", aliases[[bad[[1L]]]]),
      class = c("ledgr_invalid_feature_map", "ledgr_invalid_args")
    )
  }
  if (!is.character(feature_ids) ||
      length(feature_ids) != length(indicators) ||
      is.null(names(feature_ids)) ||
      !identical(names(feature_ids), aliases) ||
      anyNA(feature_ids) ||
      any(!nzchar(feature_ids))) {
    rlang::abort(
      "`x$feature_ids` must be a named character vector matching `x$aliases`.",
      class = c("ledgr_invalid_feature_map", "ledgr_invalid_args")
    )
  }
  if (!identical(unname(feature_ids), unname(ledgr_feature_id(indicators)))) {
    rlang::abort(
      "`x$feature_ids` does not match the mapped indicator IDs.",
      class = c("ledgr_invalid_feature_map", "ledgr_invalid_args")
    )
  }
  ledgr_abort_duplicate_feature_ids(feature_ids)
  invisible(TRUE)
}

#' Print a ledgr feature map
#'
#' @param x A `ledgr_feature_map` object.
#' @return The input object, invisibly.
#' @rdname ledgr_feature_map
#' @export
print.ledgr_feature_map <- function(x, ...) {
  ledgr_validate_feature_map_object(x)
  cat("ledgr_feature_map\n")
  cat("=================\n")
  cat("Features: ", length(x$aliases), "\n", sep = "")
  shown <- utils::head(x$aliases, 6L)
  for (alias in shown) {
    cat("  ", alias, " -> ", x$feature_ids[[alias]], "\n", sep = "")
  }
  if (length(x$aliases) > length(shown)) {
    cat("  ...\n")
  }
  invisible(x)
}
