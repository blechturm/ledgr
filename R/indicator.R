#' Construct a ledgr indicator
#'
#' @param id Unique indicator identifier.
#' @param fn Indicator function: function(window) -> numeric | list.
#' @param requires_bars Minimum lookback period (integer).
#' @param params Named list of deterministic parameters for fingerprinting.
#' @param stable_after Number of bars after which the indicator output is stable.
#' @param series_fn Optional vectorized indicator function:
#'   function(bars, params) -> numeric vector aligned to `bars`.
#' @param source Indicator source label. Built-in ledgr indicators use
#'   `"ledgr"`, TTR-backed indicators use `"TTR"`, and user/adapted indicators
#'   use `"custom"`.
#'
#' @return A `ledgr_indicator` object.
#' @examples
#' last_close <- ledgr_indicator(
#'   id = "last_close",
#'   fn = function(window) tail(window$close, 1),
#'   requires_bars = 1
#' )
#' last_close$id
#' @export
ledgr_indicator <- function(id,
                            fn,
                            requires_bars,
                            params = list(),
                            stable_after = requires_bars,
                            series_fn = NULL,
                            source = "custom") {
  ledgr_assert_no_param_refs(
    list(id = id, requires_bars = requires_bars, params = params, stable_after = stable_after),
    "ledgr_indicator()"
  )
  if (!is.character(id) || length(id) != 1 || !nzchar(id)) {
    rlang::abort("`id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (!is.function(fn)) {
    rlang::abort("`fn` must be a function.", class = "ledgr_invalid_args")
  }
  if (!is.numeric(requires_bars) || length(requires_bars) != 1 || is.na(requires_bars)) {
    rlang::abort("`requires_bars` must be a non-missing numeric scalar.", class = "ledgr_invalid_args")
  }
  if (requires_bars < 1 || requires_bars %% 1 != 0) {
    rlang::abort("`requires_bars` must be an integer >= 1.", class = "ledgr_invalid_args")
  }
  if (!is.numeric(stable_after) || length(stable_after) != 1 || is.na(stable_after)) {
    rlang::abort("`stable_after` must be a non-missing numeric scalar.", class = "ledgr_invalid_args")
  }
  if (stable_after < requires_bars || stable_after %% 1 != 0) {
    rlang::abort("`stable_after` must be an integer >= requires_bars.", class = "ledgr_invalid_args")
  }
  if (!is.list(params)) {
    rlang::abort("`params` must be a named list.", class = "ledgr_invalid_args")
  }
  if (length(params) > 0 && (is.null(names(params)) || any(!nzchar(names(params))))) {
    rlang::abort("`params` must be a named list with non-empty names.", class = "ledgr_invalid_args")
  }
  if (!ledgr_are_params_deterministic(params)) {
    rlang::abort(
      "`params` must contain only deterministic, stable values. Use strings for timestamps.",
      class = "ledgr_invalid_args"
    )
  }
  if (!is.character(source) || length(source) != 1L || is.na(source) || !(source %in% c("ledgr", "TTR", "custom"))) {
    rlang::abort("`source` must be one of 'ledgr', 'TTR', or 'custom'.", class = "ledgr_invalid_args")
  }
  ledgr_assert_indicator_fn_pure(fn)
  ledgr_assert_indicator_safe(fn)
  if (!is.null(series_fn)) {
    if (!is.function(series_fn)) {
      rlang::abort("`series_fn` must be NULL or a function.", class = "ledgr_invalid_args")
    }
    ledgr_assert_indicator_fn_pure(series_fn)
    ledgr_assert_indicator_safe(series_fn)
  }

  structure(
    list(
      id = id,
      fn = fn,
      series_fn = series_fn,
      requires_bars = as.integer(requires_bars),
      stable_after = as.integer(stable_after),
      params = params,
      source = source
    ),
    class = "ledgr_indicator"
  )
}

#' Get feature IDs from ledgr indicators
#'
#' Returns the exact feature ID strings that strategies should pass to
#' `ctx$feature(instrument_id, name)`. This helper reads the existing indicator
#' IDs; it does not generate aliases or change the ID scheme.
#'
#' @param x A `ledgr_indicator` object, a `ledgr_indicator_bundle`, a list of
#'   `ledgr_indicator`/`ledgr_indicator_bundle` objects, or a
#'   `ledgr_feature_map`.
#'
#' @return A character vector. List input returns a plain unnamed character
#'   vector in list order. Feature-map input returns IDs named by alias.
#' @examples
#' sma_20 <- ledgr_ind_sma(20)
#' ledgr_feature_id(sma_20)
#'
#' features <- list(ledgr_ind_sma(20), ledgr_ind_returns(5))
#' ledgr_feature_id(features)
#'
#' mapped <- ledgr_feature_map(
#'   trend = ledgr_ind_sma(20),
#'   momentum = ledgr_ind_returns(5)
#' )
#' ledgr_feature_id(mapped)
#'
#' @section Articles:
#' Indicators, feature IDs, and warmup:
#' `vignette("indicators", package = "ledgr")`
#' `system.file("doc", "indicators.html", package = "ledgr")`
#' @export
ledgr_feature_id <- function(x) {
  if (ledgr_feature_declaration_is_unresolved(x)) {
    ledgr_abort_unresolved_feature_id()
  }
  if (inherits(x, "ledgr_indicator")) {
    return(unname(as.character(x$id)))
  }
  if (inherits(x, "ledgr_indicator_bundle")) {
    return(ledgr_feature_id(ledgr_indicator_bundle_indicators(x)))
  }
  if (inherits(x, "ledgr_feature_map")) {
    ledgr_validate_feature_map_object(x)
    if (any(vapply(x$indicators, ledgr_feature_declaration_is_unresolved, logical(1)))) {
      ledgr_abort_unresolved_feature_id()
    }
    return(x$feature_ids)
  }
  if (is.list(x)) {
    if (any(vapply(x, ledgr_feature_declaration_is_unresolved, logical(1)))) {
      ledgr_abort_unresolved_feature_id()
    }
    flattened <- ledgr_flatten_feature_list(x, context = "`x`")
    ids <- vapply(flattened, function(ind) as.character(ind$id), character(1))
    return(unname(ids))
  }
  rlang::abort(
    "`x` must be a ledgr_indicator, ledgr_indicator_bundle, ledgr_feature_map, or list of those feature declarations.",
    class = "ledgr_invalid_args"
  )
}

#' Print a ledgr indicator
#'
#' @param x A `ledgr_indicator` object.
#' @param ... Unused.
#'
#' @return Invisibly returns `x`.
#' @examples
#' ledgr_ind_sma(20)
#' @export
print.ledgr_indicator <- function(x, ...) {
  cat("ledgr indicator\n")
  cat("  ID:            ", x$id, "\n", sep = "")
  cat("  Requires bars: ", x$requires_bars, "\n", sep = "")
  cat("  Stable after:  ", x$stable_after, "\n", sep = "")
  cat("  Series fn:     ", if (is.null(x$series_fn)) "no" else "yes", "\n", sep = "")
  invisible(x)
}

ledgr_indicator_fingerprint <- function(indicator) {
  if (!inherits(indicator, "ledgr_indicator")) {
    rlang::abort("`indicator` must be a ledgr_indicator object.", class = "ledgr_invalid_args")
  }
  payload <- list(
    id = indicator$id,
    fn = ledgr_function_fingerprint(indicator$fn, include_captures = FALSE, label = sprintf("indicator `%s`", indicator$id)),
    series_fn = if (is.null(indicator$series_fn)) {
      NULL
    } else {
      ledgr_function_fingerprint(indicator$series_fn, include_captures = FALSE, label = sprintf("indicator `%s` series_fn", indicator$id))
    },
    requires_bars = indicator$requires_bars,
    stable_after = indicator$stable_after,
    params = ledgr_stable_payload(indicator$params, sprintf("indicator `%s` params", indicator$id))
  )
  digest::digest(canonical_json(payload), algo = "sha256")
}

.ledgr_indicator_registry <- new.env(parent = emptyenv())

#' Register an indicator in the global registry
#'
#' @param indicator A `ledgr_indicator` object.
#' @param name Optional registry name (defaults to indicator id).
#' @param overwrite Replace an existing registration with the same name.
#'
#' @return The indicator, invisibly.
#' @examples
#' local({
#'   registry <- get(".ledgr_indicator_registry", asNamespace("ledgr"))
#'   if (exists("example_last_close", envir = registry, inherits = FALSE)) {
#'     rm(list = "example_last_close", envir = registry)
#'   }
#'   on.exit(if (exists("example_last_close", envir = registry, inherits = FALSE)) {
#'     rm(list = "example_last_close", envir = registry)
#'   }, add = TRUE)
#'   ind <- ledgr_indicator(
#'     id = "example_last_close",
#'     fn = function(window) tail(window$close, 1),
#'     requires_bars = 1
#'   )
#'   ledgr_indicator_register(ind)
#' })
#' @export
ledgr_indicator_register <- function(indicator, name = NULL, overwrite = FALSE) {
  if (!inherits(indicator, "ledgr_indicator")) {
    rlang::abort("`indicator` must be a ledgr_indicator object.", class = "ledgr_invalid_args")
  }
  if (is.null(name)) {
    name <- indicator$id
  }
  if (!is.character(name) || length(name) != 1 || !nzchar(name)) {
    rlang::abort("`name` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (!is.logical(overwrite) || length(overwrite) != 1 || is.na(overwrite)) {
    rlang::abort("`overwrite` must be TRUE or FALSE.", class = "ledgr_invalid_args")
  }

  if (exists(name, envir = .ledgr_indicator_registry, inherits = FALSE) && !isTRUE(overwrite)) {
    existing <- get(name, envir = .ledgr_indicator_registry, inherits = FALSE)
    if (identical(ledgr_indicator_fingerprint(existing), ledgr_indicator_fingerprint(indicator))) {
      return(invisible(indicator))
    }
    rlang::abort(
      sprintf(
        "Indicator '%s' is already registered with different logic. Existing registration is unchanged, so downstream lookups still use the previous definition. Use overwrite = TRUE only for an intentional same-ID replacement, or choose a distinct indicator id/name.",
        name
      ),
      class = "ledgr_invalid_args"
    )
  }

  assign(name, indicator, envir = .ledgr_indicator_registry)
  invisible(indicator)
}

#' Deregister an indicator from the session registry
#'
#' Removes an indicator registration from the current R session. This only
#' affects the in-memory registry used for interactive lookup and tests; it does
#' not alter any persisted snapshots, runs, features, or ledger artifacts.
#'
#' @param name Indicator registry name.
#' @param missing_ok If `TRUE`, missing names are ignored. If `FALSE`, missing
#'   names are an error.
#'
#' @return Invisibly returns `TRUE` when an indicator was removed and `FALSE`
#'   when the indicator was already absent and `missing_ok = TRUE`.
#' @examples
#' local({
#'   ind <- ledgr_indicator(
#'     id = "example_deregister",
#'     fn = function(window) tail(window$close, 1),
#'     requires_bars = 1
#'   )
#'   ledgr_indicator_register(ind)
#'   ledgr_indicator_remove("example_deregister")
#' })
#' @export
ledgr_indicator_remove <- function(name, missing_ok = TRUE) {
  if (!is.character(name) || length(name) != 1 || !nzchar(name)) {
    rlang::abort("`name` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (!is.logical(missing_ok) || length(missing_ok) != 1 || is.na(missing_ok)) {
    rlang::abort("`missing_ok` must be TRUE or FALSE.", class = "ledgr_invalid_args")
  }

  if (!exists(name, envir = .ledgr_indicator_registry, inherits = FALSE)) {
    if (isTRUE(missing_ok)) {
      return(invisible(FALSE))
    }
    rlang::abort(
      sprintf("Indicator '%s' is not registered.", name),
      class = "ledgr_invalid_args"
    )
  }

  rm(list = name, envir = .ledgr_indicator_registry)
  invisible(TRUE)
}

#' Get an indicator by name
#'
#' @param name Indicator name.
#'
#' @return A `ledgr_indicator` object.
#' @examples
#' local({
#'   registry <- get(".ledgr_indicator_registry", asNamespace("ledgr"))
#'   if (exists("example_lookup", envir = registry, inherits = FALSE)) {
#'     rm(list = "example_lookup", envir = registry)
#'   }
#'   on.exit(if (exists("example_lookup", envir = registry, inherits = FALSE)) {
#'     rm(list = "example_lookup", envir = registry)
#'   }, add = TRUE)
#'   ind <- ledgr_indicator(
#'     id = "example_lookup",
#'     fn = function(window) tail(window$close, 1),
#'     requires_bars = 1
#'   )
#'   ledgr_indicator_register(ind)
#'   ledgr_indicator_get("example_lookup")$id
#' })
#' @export
ledgr_indicator_get <- function(name) {
  if (!is.character(name) || length(name) != 1 || !nzchar(name)) {
    rlang::abort("`name` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (!exists(name, envir = .ledgr_indicator_registry, inherits = FALSE)) {
    available <- sort(ls(envir = .ledgr_indicator_registry))
    if (length(available) == 0) {
      msg <- sprintf("Indicator '%s' not found in registry.", name)
    } else {
      msg <- paste0(
        sprintf("Indicator '%s' not found in registry.\n", name),
        "Available indicators: ", paste(available, collapse = ", "), "\n\n",
        "Register custom indicators with:\n  ledgr_indicator_register(my_indicator)"
      )
    }
    rlang::abort(msg, class = "ledgr_invalid_args")
  }

  get(name, envir = .ledgr_indicator_registry, inherits = FALSE)
}

#' List registered indicators
#'
#' @param pattern Optional regex filter for names.
#'
#' @return Character vector of indicator names.
#' @examples
#' local({
#'   registry <- get(".ledgr_indicator_registry", asNamespace("ledgr"))
#'   if (exists("example_list", envir = registry, inherits = FALSE)) {
#'     rm(list = "example_list", envir = registry)
#'   }
#'   on.exit(if (exists("example_list", envir = registry, inherits = FALSE)) {
#'     rm(list = "example_list", envir = registry)
#'   }, add = TRUE)
#'   ind <- ledgr_indicator(
#'     id = "example_list",
#'     fn = function(window) tail(window$close, 1),
#'     requires_bars = 1
#'   )
#'   ledgr_indicator_register(ind)
#'   ledgr_indicator_list("example")
#' })
#' @export
ledgr_indicator_list <- function(pattern = NULL) {
  if (!is.null(pattern) && (!is.character(pattern) || length(pattern) != 1 || !nzchar(pattern))) {
    rlang::abort("`pattern` must be NULL or a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  names <- sort(ls(envir = .ledgr_indicator_registry))
  if (!is.null(pattern)) {
    names <- grep(pattern, names, value = TRUE)
  }
  names
}
