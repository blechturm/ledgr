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
#'   immutable non-function closure objects that ledgr does not store as
#'   standalone replayable artifacts.
#' - `tier_3`: strategy logic with unresolved free symbols, user helpers,
#'   forbidden nondeterministic calls, or global assignment that ledgr cannot
#'   recover from stored run metadata.
#'
#' The preflight is static analysis, not proof of semantic reproducibility.
#' Dynamic dispatch, mutable captured environments, and dynamically constructed
#' code remain user responsibilities.
#'
#' Tier 3 strategies fail before execution with condition classes
#' `ledgr_strategy_tier3` and `ledgr_strategy_preflight_error`; there is no
#' `force = TRUE` override on `ledgr_run()` or `ledgr_sweep()`. Covered
#' forbidden calls include direct wall-clock/process-environment calls such as
#' `Sys.time()`, `Sys.Date()`, and `Sys.getenv()`, visible indirection such as
#' `do.call("Sys.time", list())`, dynamic lookup/evaluation helpers such as
#' `get()`, `eval()`, and `assign()`, global assignment with `<<-`, and visible
#' context mutation such as `attr(ctx, "secret") <- 1`.
#'
#' Ambient strategy RNG calls such as `runif(1)` are Tier 2 under the execution
#' seed contract. Custom indicator generation has a stricter deterministic
#' feature contract; do not infer indicator RNG policy from strategy preflight.
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
  rng_mutation_symbols <- analysis$rng_mutation_symbols
  ambient_rng_symbols <- analysis$ambient_rng_symbols
  forbidden_call_symbols <- analysis$forbidden_call_symbols
  has_global_assignment <- analysis$has_global_assignment
  unsupported_context_mutations <- analysis$unsupported_context_mutations
  notes <- analysis$notes

  if (isTRUE(has_global_assignment)) {
    tier <- "tier_3"
    allowed <- FALSE
    reason <- "Strategy uses global assignment (`<<-`), which ledgr cannot reproduce safely."
  } else if (length(unsupported_context_mutations) > 0L) {
    tier <- "tier_3"
    allowed <- FALSE
    reason <- sprintf(
      "Strategy uses unsupported context mutation(s): %s.",
      paste(unsupported_context_mutations, collapse = ", ")
    )
  } else if (length(forbidden_call_symbols) > 0L) {
    tier <- "tier_3"
    allowed <- FALSE
    reason <- sprintf(
      "Strategy uses forbidden nondeterministic call(s): %s.",
      paste(forbidden_call_symbols, collapse = ", ")
    )
  } else if (length(rng_mutation_symbols) > 0L) {
    tier <- "tier_3"
    allowed <- FALSE
    reason <- sprintf(
      "Strategy mutates RNG state with forbidden call(s): %s.",
      paste(rng_mutation_symbols, collapse = ", ")
    )
  } else if (length(unresolved_symbols) > 0L) {
    tier <- "tier_3"
    allowed <- FALSE
    reason <- sprintf(
      "Strategy references unresolved symbol(s): %s.",
      paste(unresolved_symbols, collapse = ", ")
    )
  } else if (length(package_dependencies) > 0L || length(external_objects) > 0L || length(ambient_rng_symbols) > 0L) {
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
      },
      if (length(ambient_rng_symbols) > 0L) {
        sprintf(
          "ambient RNG call%s: %s",
          if (length(ambient_rng_symbols) == 1L) "" else "s",
          paste(ambient_rng_symbols, collapse = ", ")
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
  forbidden_do_call_symbols <- ledgr_strategy_forbidden_do_call_targets(body(strategy))
  unsupported_context_mutations <- ledgr_strategy_unsupported_context_mutations(body(strategy))
  raw_functions <- functions
  global_assignment_lhs <- ledgr_strategy_global_assignment_lhs(body(strategy))
  qualified_names <- if (nrow(qualified) > 0L) as.character(qualified$name) else character()
  rng_mutation_symbols <- sort(unique(c(
    intersect(raw_functions, ledgr_strategy_rng_mutation_functions()),
    intersect(qualified_names, ledgr_strategy_rng_mutation_functions())
  )))
  ambient_rng_symbols <- sort(unique(c(
    intersect(raw_functions, ledgr_strategy_ambient_rng_functions()),
    intersect(qualified_names, ledgr_strategy_ambient_rng_functions())
  )))
  forbidden_call_symbols <- sort(unique(intersect(
    c(raw_functions, qualified_names),
    ledgr_determinism_forbidden_calls(allow_rng = TRUE)
  )))
  forbidden_call_symbols <- sort(unique(c(forbidden_call_symbols, forbidden_do_call_symbols)))
  has_global_assignment <- ledgr_strategy_has_global_assignment(strategy)

  functions <- setdiff(functions, ledgr_strategy_syntax_functions())
  functions <- setdiff(functions, ledgr_strategy_dynamic_qualified_operator(qualified))
  functions <- setdiff(functions, forbidden_call_symbols)

  functions <- functions[!vapply(functions, ledgr_strategy_symbol_is_tier1, logical(1))]

  variables <- setdiff(variables, c("ctx", "params", ledgr_strategy_literal_constants(), string_constants))
  variables <- setdiff(variables, global_assignment_lhs)
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
  mutable_external_objects <- resolved_external_objects[
    vapply(resolved_external_objects, ledgr_strategy_symbol_resolves_to_mutable_external_object, logical(1), env = environment(strategy))
  ]
  if (length(mutable_external_objects) > 0L) {
    notes <- c(
      notes,
      sprintf(
        "Captured mutable external object(s) detected (%s); these remain Tier 2 when statically resolved, but may be mutated externally outside stored run metadata.",
        paste(sort(mutable_external_objects), collapse = ", ")
      )
    )
  }
  if (length(ambient_rng_symbols) > 0L) {
    notes <- c(
      notes,
      sprintf(
        "Ambient RNG call(s) detected (%s); static preflight allows execution but does not certify stochastic reproducibility without explicit ledgr seed helpers.",
        paste(ambient_rng_symbols, collapse = ", ")
      )
    )
  }

  list(
    unresolved_symbols = sort(unique(c(functions, variables))),
    package_dependencies = sort(unique(dependency_packages)),
    external_objects = sort(unique(resolved_external_objects)),
    rng_mutation_symbols = rng_mutation_symbols,
    ambient_rng_symbols = ambient_rng_symbols,
    forbidden_call_symbols = forbidden_call_symbols,
    has_global_assignment = has_global_assignment,
    unsupported_context_mutations = unsupported_context_mutations,
    notes = notes
  )
}

ledgr_strategy_has_global_assignment <- function(strategy) {
  fn_body <- paste(deparse(strategy), collapse = "\n")
  grepl("<<-", fn_body, fixed = TRUE)
}

ledgr_strategy_global_assignment_lhs <- function(expr) {
  out <- character()
  visit <- function(node) {
    if (is.call(node) && length(node) >= 3L) {
      op <- as.character(node[[1L]])
      if (length(op) == 1L && identical(op, "<<-")) {
        # `assign()`/`eval()` indirection is handled by the forbidden-call path.
        lhs <- node[[2L]]
        if (is.symbol(lhs)) {
          out <<- c(out, as.character(lhs))
        }
      }
    }
    if (is.recursive(node)) {
      for (i in seq_along(node)) {
        visit(node[[i]])
      }
    }
    invisible(NULL)
  }
  visit(expr)
  sort(unique(out))
}

ledgr_strategy_rng_mutation_functions <- function() {
  c("set.seed", "RNGkind")
}

ledgr_strategy_ambient_rng_functions <- function() {
  c("runif", "rnorm", "sample")
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

ledgr_strategy_symbol_resolves_to_mutable_external_object <- function(symbol, env) {
  if (!is.character(symbol) || length(symbol) != 1L || is.na(symbol) || !nzchar(symbol)) {
    return(FALSE)
  }
  if (!is.environment(env) || !exists(symbol, envir = env, inherits = TRUE)) {
    return(FALSE)
  }
  value <- tryCatch(get(symbol, envir = env, inherits = TRUE), error = function(e) NULL)
  is.environment(value) || inherits(value, c("externalptr", "connection"))
}

ledgr_strategy_forbidden_do_call_targets <- function(expr) {
  forbidden <- ledgr_determinism_forbidden_calls(allow_rng = TRUE)
  out <- character()
  visit <- function(node) {
    if (is.call(node) && length(node) >= 2L && ledgr_strategy_call_head_name(node) %in% c("do.call", "base::do.call")) {
      target <- ledgr_strategy_do_call_target_name(node[[2L]])
      if (!is.null(target) && target$name %in% forbidden) {
        out <<- c(out, sprintf("do.call(%s)", target$label))
      }
    }
    if (is.recursive(node)) {
      for (i in seq_along(node)) {
        visit(node[[i]])
      }
    }
  }
  visit(expr)
  sort(unique(out))
}

ledgr_strategy_do_call_target_name <- function(target) {
  if (is.character(target) && length(target) == 1L && !is.na(target) && nzchar(target)) {
    return(list(name = target, label = sprintf("\"%s\"", target)))
  }
  if (is.symbol(target)) {
    name <- as.character(target)
    if (length(name) == 1L && !is.na(name) && nzchar(name)) {
      return(list(name = name, label = name))
    }
  }
  if (is.call(target) && length(target) >= 3L) {
    head <- as.character(target[[1L]])
    if (length(head) == 1L && head %in% c("::", ":::")) {
      package <- as.character(target[[2L]])
      name <- as.character(target[[3L]])
      if (length(package) == 1L && length(name) == 1L && nzchar(package) && nzchar(name)) {
        return(list(name = name, label = sprintf("%s::%s", package, name)))
      }
    }
  }
  NULL
}

ledgr_strategy_unsupported_context_mutations <- function(expr) {
  out <- character()
  visit <- function(node) {
    if (is.call(node) && length(node) >= 3L && ledgr_strategy_call_head_name(node) %in% c("<-", "=")) {
      lhs <- node[[2L]]
      if (ledgr_strategy_is_attr_ctx_call(lhs)) {
        out <<- c(out, "attr(ctx, ...) <- ...")
      }
    }
    if (is.call(node) && ledgr_strategy_call_head_name(node) %in% c("attr<-", "base::attr<-")) {
      if (length(node) >= 2L && identical(as.character(node[[2L]]), "ctx")) {
        out <<- c(out, "attr(ctx, ...) <- ...")
      }
    }
    if (is.recursive(node)) {
      for (i in seq_along(node)) {
        visit(node[[i]])
      }
    }
  }
  visit(expr)
  sort(unique(out))
}

ledgr_strategy_is_attr_ctx_call <- function(node) {
  is.call(node) &&
    length(node) >= 2L &&
    ledgr_strategy_call_head_name(node) %in% c("attr", "base::attr") &&
    identical(as.character(node[[2L]]), "ctx")
}

ledgr_strategy_call_head_name <- function(node) {
  if (!is.call(node) || length(node) < 1L) {
    return(NA_character_)
  }
  head <- node[[1L]]
  if (is.symbol(head)) {
    return(as.character(head))
  }
  if (is.call(head) && length(head) >= 3L) {
    op <- as.character(head[[1L]])
    if (length(op) == 1L && op %in% c("::", ":::")) {
      package <- as.character(head[[2L]])
      name <- as.character(head[[3L]])
      if (length(package) == 1L && length(name) == 1L && nzchar(package) && nzchar(name)) {
        return(sprintf("%s::%s", package, name))
      }
    }
  }
  NA_character_
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
  reason <- if (is.character(preflight$reason) && length(preflight$reason) == 1L && !is.na(preflight$reason) && nzchar(preflight$reason)) {
    sprintf(" Reason: %s", preflight$reason)
  } else {
    ""
  }
  rlang::abort(
    paste0(
      "Strategy preflight classified this strategy as tier_3, so ledgr will not execute it.",
      detail,
      reason,
      " Move external values into `params`, qualify package calls with `pkg::fn()`, or use ledgr's exported helpers.",
      " There is no force override on `ledgr_run()` or `ledgr_sweep()`."
    ),
    class = c("ledgr_strategy_tier3", "ledgr_strategy_preflight_error")
  )
}
