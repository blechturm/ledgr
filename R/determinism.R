# Determinism and fingerprint helpers moved from R/indicator.R during LDG-2212.
# For pre-refactor blame/history, inspect the git history of R/indicator.R.
# ledgr_assert_indicator_fn_pure() and ledgr_assert_indicator_safe() keep their
# indicator-prefixed names for compatibility; rename only via a later determinism-API ticket.

ledgr_determinism_forbidden_calls <- function(allow_rng = FALSE) {
  forbidden <- c("Sys.time", "Sys.Date", "date", "runif", "rnorm", "sample", "get", "eval", "assign", "Sys.getenv")
  if (isTRUE(allow_rng)) {
    forbidden <- setdiff(forbidden, ledgr_strategy_ambient_rng_functions())
  }
  forbidden
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
  forbidden <- ledgr_determinism_forbidden_calls()
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
    forbidden <- ledgr_determinism_forbidden_calls()
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

ledgr_function_fingerprint <- function(fn, include_captures = FALSE, label = "`function`", allow_rng = FALSE) {
  if (!is.function(fn)) {
    rlang::abort(sprintf("%s must be a function.", label), class = "ledgr_invalid_args")
  }

  body_symbols <- all.names(body(fn), functions = TRUE, unique = TRUE)
  forbidden <- ledgr_determinism_forbidden_calls(allow_rng = allow_rng)
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
