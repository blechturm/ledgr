#' Construct a ledgr indicator
#'
#' @param id Unique indicator identifier.
#' @param fn Indicator function: function(window) -> numeric | list.
#' @param requires_bars Minimum lookback period (integer).
#' @param params Named list of deterministic parameters for fingerprinting.
#' @param stable_after Number of bars after which the indicator output is stable.
#'
#' @return A `ledgr_indicator` object.
ledgr_indicator <- function(id, fn, requires_bars, params = list(), stable_after = requires_bars) {
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

  structure(
    list(
      id = id,
      fn = fn,
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

.ledgr_indicator_registry <- new.env(parent = emptyenv())

#' Register an indicator in the global registry
#'
#' @param indicator A `ledgr_indicator` object.
#' @param name Optional registry name (defaults to indicator id).
#'
#' @return The indicator, invisibly.
ledgr_register_indicator <- function(indicator, name = NULL) {
  if (!inherits(indicator, "ledgr_indicator")) {
    rlang::abort("`indicator` must be a ledgr_indicator object.", class = "ledgr_invalid_args")
  }
  if (is.null(name)) {
    name <- indicator$id
  }
  if (!is.character(name) || length(name) != 1 || !nzchar(name)) {
    rlang::abort("`name` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }

  assign(name, indicator, envir = .ledgr_indicator_registry)
  invisible(indicator)
}

#' Get an indicator by name
#'
#' @param name Indicator name.
#'
#' @return A `ledgr_indicator` object.
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
