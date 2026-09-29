#' Create a feature map
#'
#' `ledgr_feature_map()` bundles user-facing aliases with ledgr indicator
#' definitions. The map is an authoring convenience: experiments register the
#' underlying indicators, while strategies can later use the aliases for
#' pulse-time feature lookup.
#'
#' A feature map is also accepted anywhere `features = list(...)` is accepted.
#' Plain lists remain valid; use a feature map when readable aliases make
#' strategy code clearer. The map is validated at construction time, and
#' `ledgr_feature_id()` returns a named character vector keyed by alias.
#' Indicator entries must be named. Bundle entries must be unnamed because
#' their output feature IDs become the aliases; use the bundle's `prefix` or
#' `naming` argument to control those names. An alias may equal its own entry's
#' feature ID, but it may not equal a different entry's feature ID.
#' Inside a strategy body, `ctx$features(instrument_id, feature_map)` returns a
#' named numeric vector keyed by the feature-map aliases. The same helper also
#' accepts a named character vector such as `c(alias = "feature_id")` for
#' explicit ad hoc aliasing. Use `ledgr_passed_warmup()` on the returned vector before
#' applying rules that require all mapped values to be finite.
#'
#' @param ... For `ledgr_feature_map()`, named `ledgr_indicator` objects or
#'   `ledgr_indicator_bundle` objects. Indicator names are strategy-facing
#'   aliases. Bundles expand to their ordinary indicators using feature IDs as
#'   aliases. For the print method, unused.
#' @return A `ledgr_feature_map` object.
#' @section Articles:
#' Feature maps are taught in the strategy-development article:
#'
#' `vignette("strategy-development", package = "ledgr")`
#' `system.file("doc", "strategy-development.html", package = "ledgr")`
#'
#' Indicator configuration is covered in:
#'
#' `vignette("indicators", package = "ledgr")`
#' `system.file("doc", "indicators.html", package = "ledgr")`
#' @examples
#' features <- ledgr_feature_map(
#'   ret_5 = ledgr_ind_returns(5),
#'   sma_10 = ledgr_ind_sma(10)
#' )
#'
#' ledgr_feature_id(features)
#'
#' strategy <- function(ctx, params) {
#'   targets <- ctx$flat()
#'   for (id in ctx$universe) {
#'     x <- ctx$features(id, features)
#'     if (ledgr_passed_warmup(x) && x[["ret_5"]] > params$min_return) {
#'       targets[id] <- params$qty
#'     }
#'   }
#'   targets
#' }
#' @export
ledgr_feature_map <- function(...) {
  entries <- list(...)
  entry_names <- names(entries)
  if (is.null(entry_names)) entry_names <- rep("", length(entries))

  if (length(entries) < 1L) {
    rlang::abort(
      "`...` must contain at least one ledgr_indicator or ledgr_indicator_bundle object.",
      class = c("ledgr_invalid_feature_map", "ledgr_invalid_args")
    )
  }

  indicators <- list()
  aliases <- character()
  feature_ids <- character()
  for (i in seq_along(entries)) {
    entry <- entries[[i]]
    alias <- entry_names[[i]]
    if (is.na(alias)) alias <- ""

    if (inherits(entry, "ledgr_indicator") || inherits(entry, "ledgr_parameterized_indicator")) {
      if (!nzchar(alias)) {
        rlang::abort(
          "Feature map indicator entries must be named.",
          class = c("ledgr_invalid_feature_map", "ledgr_invalid_args")
        )
      }
      indicators[[length(indicators) + 1L]] <- entry
      aliases <- c(aliases, alias)
      feature_ids <- c(feature_ids, if (inherits(entry, "ledgr_indicator")) ledgr_feature_id(entry) else NA_character_)
      next
    }

    if (inherits(entry, "ledgr_indicator_bundle")) {
      ledgr_feature_map_refuse_named_bundle(alias)
      bundle_indicators <- ledgr_indicator_bundle_indicators(entry)
      indicators <- c(indicators, bundle_indicators)
      bundle_ids <- ledgr_feature_id(bundle_indicators)
      aliases <- c(aliases, bundle_ids)
      feature_ids <- c(feature_ids, bundle_ids)
      next
    }

    if (inherits(entry, "ledgr_parameterized_indicator_bundle")) {
      ledgr_feature_map_refuse_named_bundle(alias)
      bundle_aliases <- entry$output_aliases
      indicators <- c(indicators, lapply(bundle_aliases, function(output_alias) {
        ledgr_new_parameterized_bundle_output(entry, output_alias)
      }))
      aliases <- c(aliases, bundle_aliases)
      feature_ids <- c(feature_ids, rep(NA_character_, length(bundle_aliases)))
      next
    }

    rlang::abort(
      sprintf("Feature map entry %s must be a ledgr_indicator, ledgr_indicator_bundle, or parameterized feature declaration.", i),
      class = c("ledgr_invalid_feature_map", "ledgr_invalid_args")
    )
  }

  ledgr_validate_feature_map_aliases(aliases, length(indicators))
  concrete_ids <- feature_ids[!is.na(feature_ids)]
  if (length(concrete_ids) > 0L) {
    ledgr_abort_duplicate_feature_ids(concrete_ids)
  }
  ledgr_validate_feature_map_alias_id_collisions(aliases, feature_ids)

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

ledgr_feature_map_refuse_named_bundle <- function(alias) {
  if (!nzchar(alias)) return(invisible(TRUE))
  rlang::abort(
    sprintf(
      paste(
        "Feature map bundle entries must be unnamed; outer alias `%s` would be ignored.",
        "Use the bundle's `prefix` or `naming` argument to control generated feature names."
      ),
      alias
    ),
    class = c("ledgr_invalid_feature_map", "ledgr_invalid_args")
  )
}

ledgr_validate_feature_map_alias_id_collisions <- function(aliases,
                                                           feature_ids) {
  owners <- match(aliases, feature_ids, nomatch = 0L)
  collision <- which(owners != 0L & owners != seq_along(aliases))
  if (length(collision) < 1L) return(invisible(TRUE))

  i <- collision[[1L]]
  owner <- owners[[i]]
  rlang::abort(
    sprintf(
      paste(
        "Feature map alias `%s` maps to feature `%s` but also names feature",
        "`%s` from entry `%s`; aliases must not name another entry's feature."
      ),
      aliases[[i]],
      feature_ids[[i]],
      feature_ids[[owner]],
      aliases[[owner]]
    ),
    class = c("ledgr_invalid_feature_map", "ledgr_invalid_args")
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
      sprintf(
        "Feature map aliases must be unique; duplicate alias: %s. If this alias came from a multi-output bundle, it is also the generated feature ID; change the bundle prefix or select distinct outputs.",
        dup[[1L]]
      ),
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

ledgr_resolve_feature_map <- function(x, feature_params = list()) {
  ledgr_validate_feature_map_object(x)
  resolved <- lapply(x$indicators, ledgr_resolve_feature_declaration, feature_params = feature_params)
  do.call(ledgr_feature_map, stats::setNames(resolved, x$aliases))
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
  bad <- bad[!vapply(indicators[bad], ledgr_feature_declaration_is_unresolved, logical(1))]
  if (length(bad) > 0L) {
    rlang::abort(
      sprintf("Feature map entry `%s` must be a ledgr_indicator object or unresolved parameterized feature declaration.", aliases[[bad[[1L]]]]),
      class = c("ledgr_invalid_feature_map", "ledgr_invalid_args")
    )
  }
  if (!is.character(feature_ids) ||
      length(feature_ids) != length(indicators) ||
      is.null(names(feature_ids)) ||
      !identical(names(feature_ids), aliases) ||
      anyNA(feature_ids) ||
      any(!nzchar(feature_ids))) {
    unresolved <- vapply(indicators, ledgr_feature_declaration_is_unresolved, logical(1))
    if (!isTRUE(all(is.na(feature_ids[unresolved]))) ||
        !isTRUE(all(!is.na(feature_ids[!unresolved]))) ||
        any(!nzchar(feature_ids[!unresolved]))) {
      rlang::abort(
        "`x$feature_ids` must contain concrete IDs for concrete entries and NA for unresolved parameterized entries.",
        class = c("ledgr_invalid_feature_map", "ledgr_invalid_args")
      )
    }
  }
  unresolved <- vapply(indicators, ledgr_feature_declaration_is_unresolved, logical(1))
  if (!any(unresolved) &&
      !identical(unname(feature_ids), unname(ledgr_feature_id(indicators)))) {
    rlang::abort(
      "`x$feature_ids` does not match the mapped indicator IDs.",
      class = c("ledgr_invalid_feature_map", "ledgr_invalid_args")
    )
  }
  concrete_ids <- feature_ids[!unresolved]
  if (length(concrete_ids) > 0L) {
    ledgr_abort_duplicate_feature_ids(concrete_ids)
  }
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
    feature_id <- x$feature_ids[[alias]]
    if (is.na(feature_id)) feature_id <- "<unresolved>"
    cat("  ", alias, " -> ", feature_id, "\n", sep = "")
  }
  if (length(x$aliases) > length(shown)) {
    cat("  ...\n")
  }
  invisible(x)
}

#' Check whether mapped feature values have passed warmup
#'
#' `ledgr_passed_warmup()` is a strategy-authoring guard for named numeric vectors
#' returned by `ctx$features(id, feature_map)`. For those vectors, `TRUE` means
#' every requested feature is usable at the current pulse. For arbitrary
#' vectors, it is only an `all(!is.na(x))` predicate.
#'
#' `ledgr_passed_warmup()` is not a signal pipeline transformation. It is a guard for
#' strategy conditions after feature values have been read. Zero-length input
#' aborts with classes `ledgr_empty_warmup_input` and
#' `ledgr_invalid_warmup_input`; non-numeric input aborts with class
#' `ledgr_invalid_warmup_input`.
#'
#' The context-aware form `ledgr_passed_warmup(ctx, values)` checks one value
#' per instrument on the decision axis, such as `ctx$vec$feature(id)` or a
#' context signal. It considers eligible instruments only (`ctx$vec$admissible`):
#' a missing value on a held nonmember or a target-restricted member does not
#' fail the check, and with no eligible instrument the check passes. `values`
#' aligns by position when unnamed and by name when named, as for
#' `ledgr_signal(ctx, values = ...)`; named values must cover every eligible
#' instrument. Non-numeric `values`, or `values` with an `x` that is not a pulse
#' context, abort with class `ledgr_invalid_warmup_input`.
#'
#' @param x A numeric vector, typically returned by `ctx$features()`; or, when
#'   `values` is supplied, the pulse context.
#' @param values Optional numeric decision-axis values or a context signal.
#' @return A logical scalar.
#' @section Articles:
#' Feature-map strategy authoring is taught in:
#'
#' `vignette("strategy-development", package = "ledgr")`
#' `system.file("doc", "strategy-development.html", package = "ledgr")`
#'
#' Indicator warmup is covered in:
#'
#' `vignette("indicators", package = "ledgr")`
#' `system.file("doc", "indicators.html", package = "ledgr")`
#' @examples
#' ledgr_passed_warmup(c(ret_5 = NA_real_, sma_10 = 101))
#' ledgr_passed_warmup(c(ret_5 = 0.02, sma_10 = 101))
#'
#' try(ledgr_passed_warmup(numeric(0)))
#'
#' # Inside a strategy, over every eligible instrument:
#' # if (!ledgr_passed_warmup(ctx, ctx$vec$feature("sma_10"))) return(ctx$hold())
#' @export
ledgr_passed_warmup <- function(x, values) {
  if (!missing(values)) {
    return(ledgr_passed_warmup_context(x, values))
  }
  if (!is.numeric(x)) {
    rlang::abort(
      "`x` must be a numeric vector.",
      class = c("ledgr_invalid_warmup_input", "ledgr_invalid_args")
    )
  }
  if (length(x) < 1L) {
    rlang::abort(
      "`x` must contain at least one feature value.",
      class = c("ledgr_empty_warmup_input", "ledgr_invalid_warmup_input", "ledgr_invalid_args")
    )
  }
  !anyNA(x)
}

# Eligible decision-axis values only; no eligible ID is a pass. A signal aligns
# by its names; every other payload goes through the context entrance.
ledgr_passed_warmup_context <- function(ctx, values) {
  if (!inherits(ctx, "ledgr_pulse_context")) {
    rlang::abort(
      "`x` must be a ledgr pulse context when `values` is supplied.",
      class = "ledgr_invalid_warmup_input"
    )
  }
  if (inherits(values, "ledgr_signal")) {
    values <- stats::setNames(as.numeric(values), names(values))
  }
  if (!is.numeric(values)) {
    rlang::abort(
      "`values` must be a numeric vector.",
      class = "ledgr_invalid_warmup_input"
    )
  }
  parts <- ledgr_strategy_context_parts(ctx, "ledgr_passed_warmup")
  eligible <- ledgr_strategy_eligible(ctx, parts$axis)
  all_eligible <- all(eligible)
  aligned <- ledgr_strategy_context_align(
    values, "values", "numeric", parts$axis, parts$axis,
    required = if (all_eligible) NULL else eligible
  )
  if (all_eligible) !anyNA(aligned) else !anyNA(aligned[eligible])
}
