#' Classify a functional strategy's reproducibility tier
#'
#' `ledgr_strategy_preflight()` statically inspects a `function(ctx, params)`
#' strategy before execution. It classifies the strategy into ledgr's
#' reproducibility tiers:
#'
#' - `tier_1`: self-contained strategy logic using only explicit `params`,
#'   base/recommended R references, and ledgr's exported public namespace.
#' - `tier_2`: inspectable strategy logic that also uses package-qualified
#'   calls outside the active R distribution, such as `pkg::fn()`, or resolved
#'   non-function closure objects that ledgr does not store as standalone
#'   replayable artifacts.
#' - `tier_3`: strategy logic with unresolved free symbols or user helpers that
#'   ledgr cannot recover from stored run metadata.
#'
#' The preflight is static analysis, not proof of semantic reproducibility.
#' Dynamic dispatch, mutable captured environments, and dynamically constructed
#' code remain user responsibilities.
#'
#' @param strategy A function with signature `function(ctx, params)`.
#' @return A `ledgr_strategy_preflight` object with fields `tier`, `allowed`,
#'   `reason`, `unresolved_symbols`, `package_dependencies`, and `notes`.
#' @section Articles:
#' Reproducibility model:
#' `vignette("reproducibility", package = "ledgr")`
#' `system.file("doc", "reproducibility.html", package = "ledgr")`
#' @examples
#' strategy <- function(ctx, params) {
#'   targets <- ctx$flat()
#'   targets
#' }
#' ledgr_strategy_preflight(strategy)
#' @export
ledgr_strategy_preflight <- function(strategy) {
  if (!is.function(strategy)) {
    rlang::abort("`strategy` must be a function.", class = "ledgr_invalid_strategy_preflight")
  }
  ledgr_strategy_signature(strategy)

  if (isTRUE(attr(strategy, "ledgr_signal_strategy_wrapper", exact = TRUE))) {
    return(structure(
      list(
        tier = "tier_2",
        allowed = TRUE,
        reason = "`ledgr_signal_strategy()` wrappers capture an inner signal function and quantity settings.",
        unresolved_symbols = character(),
        package_dependencies = character(),
        notes = "`ledgr_signal_strategy()` is an explicit compatibility wrapper; inspect the original signal function for full reproducibility."
      ),
      class = "ledgr_strategy_preflight"
    ))
  }

  analysis <- ledgr_strategy_preflight_analysis(strategy)
  unresolved_symbols <- analysis$unresolved_symbols
  package_dependencies <- analysis$package_dependencies
  external_objects <- analysis$external_objects
  notes <- analysis$notes

  if (length(unresolved_symbols) > 0L) {
    tier <- "tier_3"
    allowed <- FALSE
    reason <- sprintf(
      "Strategy references unresolved symbol(s): %s.",
      paste(unresolved_symbols, collapse = ", ")
    )
  } else if (length(package_dependencies) > 0L || length(external_objects) > 0L) {
    tier <- "tier_2"
    allowed <- TRUE
    reason_parts <- c(
      if (length(package_dependencies) > 0L) {
        sprintf(
          "package-qualified dependenc%s outside the active R distribution: %s",
          if (length(package_dependencies) == 1L) "y" else "ies",
          paste(package_dependencies, collapse = ", ")
        )
      },
      if (length(external_objects) > 0L) {
        sprintf(
          "resolved external object%s: %s",
          if (length(external_objects) == 1L) "" else "s",
          paste(external_objects, collapse = ", ")
        )
      }
    )
    reason <- paste0("Strategy uses ", paste(reason_parts, collapse = "; "), ".")
  } else {
    tier <- "tier_1"
    allowed <- TRUE
    reason <- "Strategy is self-contained under ledgr's static preflight rules."
  }

  structure(
    list(
      tier = tier,
      allowed = allowed,
      reason = reason,
      unresolved_symbols = unresolved_symbols,
      package_dependencies = package_dependencies,
      notes = notes
    ),
    class = "ledgr_strategy_preflight"
  )
}

#' @export
print.ledgr_strategy_preflight <- function(x, ...) {
  cat("ledgr Strategy Preflight\n")
  cat("=========================\n\n")
  cat("Tier:    ", x$tier, "\n", sep = "")
  cat("Allowed: ", if (isTRUE(x$allowed)) "TRUE" else "FALSE", "\n", sep = "")
  cat("Reason:  ", x$reason, "\n", sep = "")
  if (length(x$unresolved_symbols) > 0L) {
    cat("Unresolved Symbols: ", paste(x$unresolved_symbols, collapse = ", "), "\n", sep = "")
  }
  if (length(x$package_dependencies) > 0L) {
    cat("Package Dependencies: ", paste(x$package_dependencies, collapse = ", "), "\n", sep = "")
  }
  if (length(x$notes) > 0L) {
    cat("\nNotes:\n")
    for (note in x$notes) {
      cat("- ", note, "\n", sep = "")
    }
  }
  invisible(x)
}

ledgr_strategy_preflight_analysis <- function(strategy) {
  globals <- codetools::findGlobals(strategy, merge = FALSE)
  functions <- sort(unique(as.character(globals$functions)))
  variables <- sort(unique(as.character(globals$variables)))
  qualified <- ledgr_strategy_qualified_calls(body(strategy))
  string_constants <- unique(ledgr_strategy_character_constants(body(strategy)))

  functions <- setdiff(functions, ledgr_strategy_syntax_functions())
  functions <- setdiff(functions, ledgr_strategy_dynamic_qualified_operator(qualified))

  functions <- functions[!vapply(functions, ledgr_strategy_symbol_is_tier1, logical(1))]

  variables <- setdiff(variables, c("ctx", "params", ledgr_strategy_literal_constants(), string_constants))
  variables <- variables[!vapply(variables, ledgr_strategy_symbol_is_tier1, logical(1))]
  resolved_external_objects <- variables[
    vapply(variables, ledgr_strategy_symbol_resolves_to_external_object, logical(1), env = environment(strategy))
  ]
  variables <- setdiff(variables, resolved_external_objects)

  dependency_packages <- character()
  if (nrow(qualified) > 0L) {
    dependency_packages <- qualified$package[
      !vapply(qualified$package, ledgr_strategy_package_is_tier1, logical(1))
    ]
  }

  dynamic_symbols <- intersect(
    c("do.call", "get", "eval", "assign"),
    union(as.character(globals$functions), as.character(globals$variables))
  )
  notes <- character()
  if (length(dynamic_symbols) > 0L) {
    notes <- c(
      notes,
      sprintf(
        "Dynamic construct(s) detected (%s); static analysis cannot prove their runtime targets.",
        paste(sort(dynamic_symbols), collapse = ", ")
      )
    )
  }
  if (length(resolved_external_objects) > 0L) {
    notes <- c(
      notes,
      sprintf(
        "Resolved external object(s) detected (%s); ledgr stores the strategy source but not those objects.",
        paste(sort(resolved_external_objects), collapse = ", ")
      )
    )
  }

  list(
    unresolved_symbols = sort(unique(c(functions, variables))),
    package_dependencies = sort(unique(dependency_packages)),
    external_objects = sort(unique(resolved_external_objects)),
    notes = notes
  )
}

ledgr_strategy_syntax_functions <- function() {
  c(
    "{", "(", "<-", "=", "if", "else", "for", "while", "repeat",
    "break", "next", "return", "[", "[[", "$", "[<-", "[[<-", "$<-",
    "@", "@<-", "::", ":::", ":", "+", "-", "*", "/", "^", "%%", "%/%",
    "<", ">", "<=", ">=", "==", "!=", "&&", "||", "!", "&", "|",
    "~", "%in%"
  )
}

ledgr_strategy_literal_constants <- function() {
  c("TRUE", "FALSE", "NULL", "NA", "NaN", "Inf")
}

ledgr_strategy_priority_packages <- local({
  cache <- NULL
  function() {
    if (!is.null(cache)) {
      return(cache)
    }
    # The priority set is session-local. Package installs during the same R
    # session are picked up after restart, which is enough for preflight policy.
    installed <- tryCatch(
      utils::installed.packages(fields = "Priority"),
      error = function(e) NULL
    )
    if (is.null(installed) || !"Priority" %in% colnames(installed)) {
      cache <<- character()
      return(cache)
    }
    priority <- installed[, "Priority"]
    cache <<- rownames(installed)[!is.na(priority) & priority %in% c("base", "recommended")]
    cache
  }
})

ledgr_strategy_package_is_tier1 <- function(package) {
  is.character(package) &&
    length(package) == 1L &&
    !is.na(package) &&
    (identical(package, "ledgr") || package %in% ledgr_strategy_priority_packages())
}

ledgr_strategy_symbol_is_tier1 <- function(symbol) {
  if (!is.character(symbol) || length(symbol) != 1L || is.na(symbol) || !nzchar(symbol)) {
    return(FALSE)
  }
  if (symbol %in% getNamespaceExports("ledgr")) {
    return(TRUE)
  }
  any(vapply(
    ledgr_strategy_priority_packages(),
    function(package) {
      tryCatch(
        requireNamespace(package, quietly = TRUE) &&
          exists(symbol, envir = asNamespace(package), inherits = FALSE),
        error = function(e) FALSE
      )
    },
    logical(1)
  ))
}

ledgr_strategy_symbol_resolves_to_external_object <- function(symbol, env) {
  if (!is.character(symbol) || length(symbol) != 1L || is.na(symbol) || !nzchar(symbol)) {
    return(FALSE)
  }
  if (!is.environment(env) || !exists(symbol, envir = env, inherits = TRUE)) {
    return(FALSE)
  }
  value <- tryCatch(get(symbol, envir = env, inherits = TRUE), error = function(e) NULL)
  !is.function(value)
}

ledgr_strategy_qualified_calls <- function(expr) {
  out <- list()
  visit <- function(node) {
    if (is.call(node) && length(node) >= 3L) {
      head <- as.character(node[[1]])
      if (length(head) == 1L && head %in% c("::", ":::")) {
        package <- as.character(node[[2]])
        name <- as.character(node[[3]])
        if (length(package) == 1L && length(name) == 1L) {
          out[[length(out) + 1L]] <<- data.frame(
            package = package,
            name = name,
            operator = head,
            stringsAsFactors = FALSE
          )
        }
      }
    }
    if (is.recursive(node)) {
      for (i in seq_along(node)) {
        visit(node[[i]])
      }
    }
  }
  visit(expr)
  if (length(out) == 0L) {
    return(data.frame(package = character(), name = character(), operator = character()))
  }
  unique(do.call(rbind, out))
}

ledgr_strategy_dynamic_qualified_operator <- function(qualified) {
  if (nrow(qualified) > 0L) {
    return(c("::", ":::"))
  }
  character()
}

ledgr_strategy_character_constants <- function(expr) {
  out <- character()
  visit <- function(node) {
    if (is.character(node)) {
      out <<- c(out, as.character(node))
      return(invisible(NULL))
    }
    if (is.recursive(node)) {
      for (i in seq_along(node)) {
        visit(node[[i]])
      }
    }
    invisible(NULL)
  }
  visit(expr)
  out
}

ledgr_abort_strategy_preflight <- function(preflight) {
  unresolved <- preflight$unresolved_symbols
  detail <- if (length(unresolved) > 0L) {
    sprintf(" Unresolved symbol(s): %s.", paste(unresolved, collapse = ", "))
  } else {
    ""
  }
  rlang::abort(
    paste0(
      "Strategy preflight classified this strategy as tier_3, so ledgr will not execute it by default.",
      detail,
      " Move external values into `params`, qualify package calls with `pkg::fn()`, or use ledgr's exported helpers."
    ),
    class = c("ledgr_strategy_tier3", "ledgr_strategy_preflight_error")
  )
}
