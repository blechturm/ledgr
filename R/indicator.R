#' Construct a ledgr indicator
#'
#' @param id Unique indicator identifier.
#' @param fn Indicator function: function(window) -> numeric | list.
#' @param requires_bars Minimum lookback period (integer).
#' @param params Named list of deterministic parameters for fingerprinting.
#' @param stable_after Number of bars after which the indicator output is stable.
#' @param series_fn Optional vectorized indicator function:
#'   function(bars, params) -> numeric vector aligned to `bars`.
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
ledgr_indicator <- function(id, fn, requires_bars, params = list(), stable_after = requires_bars, series_fn = NULL) {
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
      params = params
    ),
    class = "ledgr_indicator"
  )
}

ledgr_assert_indicator_fn_pure <- function(fn) {
  fn_body <- paste(deparse(fn), collapse = "\n")
  if (grepl("<<-", fn_body, fixed = TRUE)) {
    rlang::abort(
      "Indicator function contains global assignment (<<-), which violates purity.",
      class = "ledgr_invalid_args"
    )
  }
  invisible(TRUE)
}

ledgr_assert_indicator_safe <- function(fn) {
  forbidden <- c("Sys.time", "Sys.Date", "date", "runif", "rnorm", "sample", "get", "eval", "assign", "Sys.getenv")
  symbols <- all.names(body(fn), functions = TRUE, unique = TRUE)
  if (any(symbols %in% forbidden)) {
    rlang::abort("Indicator function uses non-deterministic calls.", class = "ledgr_purity_violation")
  }
  invisible(TRUE)
}

ledgr_are_params_deterministic <- function(params) {
  ledgr_is_deterministic_value <- function(x) {
    if (is.null(x)) return(TRUE)
    if (inherits(x, "POSIXt") || inherits(x, "Date")) return(FALSE)
    if (is.atomic(x)) return(TRUE)
    if (is.list(x)) {
      return(all(vapply(x, ledgr_is_deterministic_value, logical(1))))
    }
    FALSE
  }

  all(vapply(params, ledgr_is_deterministic_value, logical(1)))
}

ledgr_deparse_one <- function(x) {
  paste(deparse(x, width.cutoff = 500L), collapse = "\n")
}

ledgr_static_function_signature <- function(fn) {
  if (!is.function(fn)) {
    rlang::abort("Expected a function to fingerprint.", class = "ledgr_invalid_args")
  }
  list(
    body = ledgr_deparse_one(body(fn)),
    formals = ledgr_stable_payload(as.list(formals(fn)), "`formals`"),
    environment_name = environmentName(environment(fn))
  )
}

ledgr_stable_payload <- function(x, path = "`value`") {
  if (is.null(x)) return(NULL)
  if (inherits(x, "POSIXt") || inherits(x, "Date")) {
    rlang::abort(
      sprintf("%s must not contain Date/POSIXt values; use ISO8601 UTC strings for deterministic fingerprints.", path),
      class = "ledgr_config_non_deterministic"
    )
  }
  if (is.environment(x) || inherits(x, "externalptr") || inherits(x, "connection")) {
    rlang::abort(
      sprintf("%s captures a non-serializable object; move it into deterministic scalar parameters instead.", path),
      class = "ledgr_config_non_deterministic"
    )
  }
  if (is.function(x)) {
    return(ledgr_static_function_signature(x))
  }
  if (is.symbol(x) || is.language(x) || is.expression(x)) {
    forbidden <- c("Sys.time", "Sys.Date", "date", "runif", "rnorm", "sample", "get", "eval", "assign", "Sys.getenv")
    symbols <- all.names(x, functions = TRUE, unique = TRUE)
    if (any(symbols %in% forbidden)) {
      rlang::abort(
        sprintf("%s contains non-deterministic code.", path),
        class = "ledgr_config_non_deterministic"
      )
    }
    return(list(type = typeof(x), code = ledgr_deparse_one(x)))
  }
  if (is.factor(x)) return(as.character(x))
  if (is.data.frame(x)) {
    out <- lapply(names(x), function(nm) ledgr_stable_payload(x[[nm]], paste0(path, "$", nm)))
    names(out) <- names(x)
    return(out)
  }
  if (is.atomic(x)) {
    if (is.double(x) && any(!is.finite(x))) {
      rlang::abort(sprintf("%s contains non-finite numeric values.", path), class = "ledgr_config_non_deterministic")
    }
    return(x)
  }
  if (is.list(x)) {
    nms <- names(x)
    out <- lapply(seq_along(x), function(i) {
      nm <- if (is.null(nms)) as.character(i) else nms[[i]]
      if (is.null(nm) || is.na(nm) || !nzchar(nm)) nm <- as.character(i)
      ledgr_stable_payload(x[[i]], paste0(path, "$", nm))
    })
    names(out) <- nms
    return(out)
  }
  rlang::abort(
    sprintf("%s has unsupported class for deterministic fingerprinting: %s", path, paste(class(x), collapse = "/")),
    class = "ledgr_config_non_deterministic"
  )
}

ledgr_function_fingerprint <- function(fn, include_captures = FALSE, label = "`function`") {
  if (!is.function(fn)) {
    rlang::abort(sprintf("%s must be a function.", label), class = "ledgr_invalid_args")
  }

  body_symbols <- all.names(body(fn), functions = TRUE, unique = TRUE)
  forbidden <- c("Sys.time", "Sys.Date", "date", "runif", "rnorm", "sample", "get", "eval", "assign", "Sys.getenv")
  if (any(body_symbols %in% forbidden)) {
    rlang::abort(
      sprintf("%s uses non-deterministic calls and cannot be fingerprinted safely.", label),
      class = "ledgr_config_non_deterministic"
    )
  }

  captures <- list()
  if (isTRUE(include_captures)) {
    globals <- codetools::findGlobals(fn, merge = FALSE)$variables
    env <- environment(fn)
    captures <- lapply(sort(unique(globals)), function(nm) {
      if (!exists(nm, envir = env, inherits = TRUE)) {
        return(list(type = "unresolved"))
      }
      ledgr_stable_payload(get(nm, envir = env, inherits = TRUE), paste0(label, " capture `", nm, "`"))
    })
    names(captures) <- sort(unique(globals))
  }

  payload <- list(
    body = ledgr_deparse_one(body(fn)),
    formals = ledgr_stable_payload(as.list(formals(fn)), paste0(label, " formals")),
    captures = captures
  )
  digest::digest(canonical_json(payload), algo = "sha256")
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
#'   ledgr_register_indicator(ind)
#' })
#' @export
ledgr_register_indicator <- function(indicator, name = NULL, overwrite = FALSE) {
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
      sprintf("Indicator '%s' is already registered with different logic. Use overwrite = TRUE only for an intentional replacement.", name),
      class = "ledgr_invalid_args"
    )
  }

  assign(name, indicator, envir = .ledgr_indicator_registry)
  invisible(indicator)
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
#'   ledgr_register_indicator(ind)
#'   ledgr_get_indicator("example_lookup")$id
#' })
#' @export
ledgr_get_indicator <- function(name) {
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
        "Register custom indicators with:\n  ledgr_register_indicator(my_indicator)"
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
#'   ledgr_register_indicator(ind)
#'   ledgr_list_indicators("example")
#' })
#' @export
ledgr_list_indicators <- function(pattern = NULL) {
  if (!is.null(pattern) && (!is.character(pattern) || length(pattern) != 1 || !nzchar(pattern))) {
    rlang::abort("`pattern` must be NULL or a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  names <- sort(ls(envir = .ledgr_indicator_registry))
  if (!is.null(pattern)) {
    names <- grep(pattern, names, value = TRUE)
  }
  names
}
