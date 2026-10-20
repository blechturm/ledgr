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
#' Strategies read the pulse context only through its public fields, its
#' public functions and exported ledgr helpers such as
#' [ledgr_history_frame()]. Reaching private context internals is Tier 3:
#' extracting a dot-prefixed member of any object (`ctx$.history`,
#' `x[[".notes"]]`), naming a private context field in a string, or
#' introspecting closure or call environments with `environment()`,
#' `parent.env()`, `parent.frame()`, the `sys.*()` frame functions,
#' `as.environment()`, `topenv()` or their `rlang` equivalents. The private
#' history carrier and the environments behind public context functions hold
#' prepared data beyond the pulse, so such a read could see the future.
#' Dynamically constructed names, positional extraction from `ctx` and
#' iteration over it remain outside what static analysis detects.
#'
#' Ambient strategy RNG calls such as `runif(1)` are Tier 2 under the execution
#' seed contract for ordinary sequential runs, but they are not certified for
#' resume or parallel equivalence. Strategies that need pulse-specific
#' stochastic inputs in those paths should derive them from `ctx$pulse_seed`
#' without reading ambient `.Random.seed`. Custom indicator generation has a
#' stricter deterministic feature contract; do not infer indicator RNG policy
#' from strategy preflight.
#'
#' @param strategy A function with signature `function(ctx, params)`.
#' @return A `ledgr_strategy_preflight` object with fields `tier`, `allowed`,
#'   `reason`, `unresolved_symbols`, `package_dependencies`,
#'   `qualified_package_dependencies`, `attached_package_dependencies`,
#'   `worker_dependencies`, `ambient_rng_symbols`, and `notes`.
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
        qualified_package_dependencies = character(),
        attached_package_dependencies = character(),
        worker_dependencies = ledgr_strategy_worker_dependencies_fields(
          require_namespace = character(),
          attach = character()
        ),
        ambient_rng_symbols = character(),
        notes = "`ledgr_signal_strategy()` is an explicit compatibility wrapper; inspect the original signal function for full reproducibility."
      ),
      class = "ledgr_strategy_preflight"
    ))
  }

  analysis <- ledgr_strategy_preflight_analysis(strategy)
  unresolved_symbols <- analysis$unresolved_symbols
  package_dependencies <- analysis$package_dependencies
  qualified_package_dependencies <- analysis$qualified_package_dependencies
  attached_package_dependencies <- analysis$attached_package_dependencies
  external_objects <- analysis$external_objects
  rng_mutation_symbols <- analysis$rng_mutation_symbols
  ambient_rng_symbols <- analysis$ambient_rng_symbols
  forbidden_call_symbols <- analysis$forbidden_call_symbols
  has_global_assignment <- analysis$has_global_assignment
  unsupported_context_mutations <- analysis$unsupported_context_mutations
  private_context_access <- analysis$private_context_access
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
  } else if (length(private_context_access) > 0L) {
    tier <- "tier_3"
    allowed <- FALSE
    reason <- sprintf(
      paste(
        "Strategy reaches private context internals: %s.",
        "Read the context through its public fields and functions and",
        "history through `ledgr_history_frame()`."
      ),
      paste(private_context_access, collapse = ", ")
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
          "package dependenc%s outside the active R distribution: %s",
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
      qualified_package_dependencies = qualified_package_dependencies,
      attached_package_dependencies = attached_package_dependencies,
      worker_dependencies = ledgr_strategy_worker_dependencies_fields(
        require_namespace = qualified_package_dependencies,
        attach = attached_package_dependencies
      ),
      ambient_rng_symbols = ambient_rng_symbols,
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
  functions <- sort(unique(as.character(globals$functions)), method = "radix")
  variables <- sort(unique(as.character(globals$variables)), method = "radix")
  qualified <- ledgr_strategy_qualified_calls(body(strategy))
  string_constants <- unique(ledgr_strategy_character_constants(body(strategy)))
  forbidden_do_call_symbols <- ledgr_strategy_forbidden_do_call_targets(body(strategy))
  unsupported_context_mutations <- ledgr_strategy_unsupported_context_mutations(body(strategy))
  private_context_access <- ledgr_strategy_private_context_access(
    body(strategy),
    symbols = union(as.character(globals$functions), as.character(globals$variables)),
    qualified = qualified,
    string_constants = string_constants
  )
  raw_functions <- functions
  global_assignment_lhs <- ledgr_strategy_global_assignment_lhs(body(strategy))
  qualified_names <- if (nrow(qualified) > 0L) as.character(qualified$name) else character()
  rng_mutation_symbols <- sort(unique(c(
    intersect(raw_functions, ledgr_strategy_rng_mutation_functions()),
    intersect(qualified_names, ledgr_strategy_rng_mutation_functions())
  )), method = "radix")
  ambient_rng_symbols <- sort(unique(c(
    intersect(raw_functions, ledgr_strategy_ambient_rng_functions()),
    intersect(qualified_names, ledgr_strategy_ambient_rng_functions())
  )), method = "radix")
  forbidden_call_symbols <- sort(unique(intersect(
    c(raw_functions, qualified_names),
    ledgr_determinism_forbidden_calls(allow_rng = TRUE)
  )), method = "radix")
  forbidden_call_symbols <- sort(
    unique(c(forbidden_call_symbols, forbidden_do_call_symbols)),
    method = "radix"
  )
  has_global_assignment <- ledgr_strategy_has_global_assignment(strategy)

  functions <- setdiff(functions, ledgr_strategy_syntax_functions())
  functions <- setdiff(functions, ledgr_strategy_dynamic_qualified_operator(qualified))
  functions <- setdiff(functions, forbidden_call_symbols)

  functions <- functions[!vapply(functions, ledgr_strategy_symbol_is_tier1, logical(1))]
  unqualified_package_functions <- ledgr_strategy_unqualified_package_functions(
    functions,
    env = environment(strategy)
  )
  functions <- setdiff(functions, names(unqualified_package_functions))

  variables <- setdiff(variables, c("ctx", "params", ledgr_strategy_literal_constants(), string_constants))
  variables <- setdiff(variables, global_assignment_lhs)
  variables <- variables[!vapply(variables, ledgr_strategy_symbol_is_tier1, logical(1))]
  resolved_external_objects <- variables[
    vapply(variables, ledgr_strategy_symbol_resolves_to_external_object, logical(1), env = environment(strategy))
  ]
  variables <- setdiff(variables, resolved_external_objects)

  qualified_dependency_packages <- character()
  if (nrow(qualified) > 0L) {
    qualified_dependency_packages <- qualified$package[
      !vapply(qualified$package, ledgr_strategy_package_is_tier1, logical(1))
    ]
  }
  attached_dependency_packages <- unname(unqualified_package_functions)
  dependency_packages <- sort(unique(c(
    qualified_dependency_packages,
    attached_dependency_packages
  )), method = "radix")

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
        paste(sort(dynamic_symbols, method = "radix"), collapse = ", ")
      )
    )
  }
  if (length(resolved_external_objects) > 0L) {
    notes <- c(
      notes,
      sprintf(
        "Resolved external object(s) detected (%s); ledgr stores the strategy source but not those objects.",
        paste(sort(resolved_external_objects, method = "radix"), collapse = ", ")
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
        paste(sort(mutable_external_objects, method = "radix"), collapse = ", ")
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
  if (length(unqualified_package_functions) > 0L) {
    notes <- c(
      notes,
      sprintf(
        "Unqualified package call(s) detected (%s); parallel workers must attach package(s): %s.",
        paste(sprintf("%s from %s", names(unqualified_package_functions), unname(unqualified_package_functions)), collapse = ", "),
        paste(sort(
          unique(unname(unqualified_package_functions)),
          method = "radix"
        ), collapse = ", ")
      )
    )
  }

  list(
    unresolved_symbols = sort(unique(c(functions, variables)), method = "radix"),
    package_dependencies = sort(unique(dependency_packages), method = "radix"),
    qualified_package_dependencies = sort(
      unique(qualified_dependency_packages),
      method = "radix"
    ),
    attached_package_dependencies = sort(
      unique(attached_dependency_packages),
      method = "radix"
    ),
    external_objects = sort(unique(resolved_external_objects), method = "radix"),
    rng_mutation_symbols = rng_mutation_symbols,
    ambient_rng_symbols = ambient_rng_symbols,
    forbidden_call_symbols = forbidden_call_symbols,
    has_global_assignment = has_global_assignment,
    unsupported_context_mutations = unsupported_context_mutations,
    private_context_access = private_context_access,
    notes = notes
  )
}

# Dot-prefixed members of a ledgr pulse context. They are private runtime
# carriers: `.history` holds the whole prepared history substrate and the
# others hold lookup state behind the public accessors (LDG-3072).
ledgr_pulse_context_private_fields <- function() {
  c(
    ".feature_table_current", ".feature_vector", ".history", ".notes",
    ".positions", ".pulse_lookup", ".safety_state"
  )
}

# Functions that return a closure, call or frame environment. Public context
# functions are closures over prepared state that extends past the pulse
# (for example the feature accessor's projection and the context itself), so
# a strategy may not introspect them (LDG-3072).
ledgr_strategy_environment_functions <- function() {
  list(
    base = c(
      "environment", "environment<-", "parent.env", "parent.env<-",
      "parent.frame", "sys.function", "sys.frame", "sys.frames", "sys.call",
      "sys.calls", "sys.parent", "sys.parents", "sys.on.exit", "sys.status",
      "as.environment", "topenv"
    ),
    rlang = c(
      "fn_env", "get_env", "env_parent", "env_parents", "env_tail",
      "caller_env", "caller_fn", "current_env", "current_fn",
      "as_environment", "env_get", "env_get_list"
    )
  )
}

# Static reads of private context internals: `$`, `@`, `[[` or `[` with a
# literal dot-prefixed name on any object (a context is easily aliased), a
# string constant naming a private context field, and environment
# introspection, called, passed by name or named in `do.call()`.
ledgr_strategy_private_context_access <- function(expr,
                                                  symbols,
                                                  qualified,
                                                  string_constants) {
  out <- character()
  dot_name <- function(x) {
    name <- if (is.symbol(x)) as.character(x) else if (is.character(x) && length(x) == 1L) x else NA_character_
    if (!is.na(name) && nchar(name) >= 2L && startsWith(name, ".")) name else NA_character_
  }
  visit <- function(node) {
    if (is.call(node) && length(node) >= 3L) {
      head <- ledgr_strategy_call_head_name(node)
      if (head %in% c("$", "@", "$<-", "@<-")) {
        name <- dot_name(node[[3L]])
        if (!is.na(name)) out <<- c(out, paste0(head, name))
      } else if (head %in% c("[[", "[", "[[<-", "[<-")) {
        for (i in seq.int(3L, length(node))) {
          name <- if (identical(node[[i]], quote(expr = ))) NA_character_ else dot_name(node[[i]])
          if (!is.na(name) && is.character(node[[i]])) {
            out <<- c(out, sprintf("%s\"%s\"]%s", sub("<-$", "", head), name, if (startsWith(head, "[[")) "]" else ""))
          }
        }
      }
      if (head %in% c("do.call", "base::do.call")) {
        target <- ledgr_strategy_do_call_target_name(node[[2L]])
        env_fns <- ledgr_strategy_environment_functions()
        if (!is.null(target) && target$name %in% c(env_fns$base, env_fns$rlang)) {
          out <<- c(out, sprintf("do.call(%s)", target$label))
        }
      }
    }
    if (is.recursive(node)) {
      for (i in seq_along(node)) {
        if (!identical(node[[i]], quote(expr = ))) visit(node[[i]])
      }
    }
    invisible(NULL)
  }
  visit(expr)
  env_fns <- ledgr_strategy_environment_functions()
  out <- c(out, sprintf("%s()", intersect(symbols, env_fns$base)))
  if (nrow(qualified) > 0L) {
    hit <- (qualified$package == "base" & qualified$name %in% env_fns$base) |
      (qualified$package == "rlang" & qualified$name %in% env_fns$rlang)
    out <- c(out, sprintf("%s%s%s()", qualified$package[hit], qualified$operator[hit], qualified$name[hit]))
  }
  out <- c(out, sprintf("\"%s\"", intersect(string_constants, ledgr_pulse_context_private_fields())))
  sort(unique(out), method = "radix")
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
  sort(unique(out), method = "radix")
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

ledgr_strategy_priority_package_has_symbol <- function(package, symbol) {
  available <- if (package %in% loadedNamespaces()) {
    TRUE
  } else {
    suppressWarnings(suppressMessages(tryCatch(
      requireNamespace(package, quietly = TRUE),
      error = function(e) FALSE
    )))
  }
  isTRUE(available) && ledgr_strategy_package_exports(package, symbol)
}

# Whether `package` exports `symbol`, looked up in the namespace's export table
# rather than by building the list of every export.
ledgr_strategy_package_exports <- function(package, symbol) {
  if (identical(package, "base")) {
    return(exists(symbol, envir = baseenv(), inherits = FALSE))
  }
  exists(symbol, envir = getNamespaceInfo(package, "exports"), inherits = FALSE)
}

# Base and recommended packages in the order a default R session searches the
# attached ones, then the rest alphabetically.
ledgr_strategy_tier1_search_order <- function() {
  packages <- ledgr_strategy_priority_packages()
  attached <- c("stats", "graphics", "grDevices", "utils", "datasets", "methods", "base")
  c(
    intersect(attached, packages),
    sort(setdiff(packages, attached), method = "radix")
  )
}

# The package a Tier 1 strategy's unqualified symbol resolves to: ledgr's
# exports first, then the exports of base and recommended R. Preflight and
# trusted recovery share this rule, so a recovered strategy resolves exactly
# what preflight allowed.
ledgr_strategy_tier1_package <- function(symbol) {
  if (!is.character(symbol) || length(symbol) != 1L || is.na(symbol) || !nzchar(symbol)) {
    return(NA_character_)
  }
  if (ledgr_strategy_package_exports("ledgr", symbol)) {
    return("ledgr")
  }
  for (package in ledgr_strategy_tier1_search_order()) {
    if (ledgr_strategy_priority_package_has_symbol(package, symbol)) {
      return(package)
    }
  }
  NA_character_
}

ledgr_strategy_symbol_is_tier1 <- function(symbol) {
  !is.na(ledgr_strategy_tier1_package(symbol))
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

ledgr_strategy_worker_dependencies_fields <- function(require_namespace,
                                                       attach) {
  list(
    require_namespace = sort(
      unique(as.character(require_namespace)),
      method = "radix"
    ),
    attach = sort(unique(as.character(attach)), method = "radix")
  )
}

ledgr_strategy_unqualified_package_functions <- function(symbols, env) {
  if (length(symbols) == 0L) {
    return(stats::setNames(character(), character()))
  }
  packages <- vapply(
    symbols,
    ledgr_strategy_symbol_package_function,
    character(1),
    env = env
  )
  keep <- nzchar(packages) &
    !vapply(packages, ledgr_strategy_package_is_tier1, logical(1))
  sort(packages[keep], method = "radix")
}

ledgr_strategy_symbol_package_function <- function(symbol, env) {
  if (!is.character(symbol) || length(symbol) != 1L || is.na(symbol) || !nzchar(symbol)) {
    return("")
  }
  if (!is.environment(env) || !exists(symbol, envir = env, inherits = TRUE)) {
    return("")
  }
  value <- tryCatch(get(symbol, envir = env, inherits = TRUE), error = function(e) NULL)
  if (!is.function(value)) {
    return("")
  }
  fn_env <- tryCatch(environment(value), error = function(e) NULL)
  while (is.environment(fn_env)) {
    namespace_name <- tryCatch(getNamespaceName(fn_env), error = function(e) "")
    if (is.character(namespace_name) &&
        length(namespace_name) == 1L &&
        nzchar(namespace_name)) {
      return(namespace_name)
    }
    env_name <- environmentName(fn_env)
    if (is.character(env_name) &&
        length(env_name) == 1L &&
        startsWith(env_name, "namespace:")) {
      return(sub("^namespace:", "", env_name))
    }
    if (identical(fn_env, emptyenv())) {
      break
    }
    parent <- parent.env(fn_env)
    if (identical(parent, fn_env)) {
      break
    }
    fn_env <- parent
  }
  ""
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
  sort(unique(out), method = "radix")
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
  sort(unique(out), method = "radix")
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

ledgr_strategy_preflight_ambient_rng_symbols <- function(preflight) {
  symbols <- preflight$ambient_rng_symbols
  if (is.null(symbols)) {
    return(character())
  }
  sort(unique(as.character(symbols)), method = "radix")
}

ledgr_strategy_preflight_uses_ambient_rng <- function(preflight) {
  length(ledgr_strategy_preflight_ambient_rng_symbols(preflight)) > 0L
}

ledgr_abort_strategy_ambient_rng_for_resume <- function(preflight) {
  symbols <- ledgr_strategy_preflight_ambient_rng_symbols(preflight)
  if (length(symbols) == 0L) {
    return(invisible(FALSE))
  }
  rlang::abort(
    paste0(
      "Refusing to resume a strategy that reads ambient RNG state: ",
      paste(symbols, collapse = ", "),
      ". Resume equivalence is guaranteed only for strategies deterministic in `(ctx, params)`. ",
      "Use `ctx$pulse_seed` to derive pulse-specific stochastic inputs without reading `.Random.seed`."
    ),
    class = c(
      "ledgr_strategy_ambient_rng_resume",
      "ledgr_strategy_ambient_rng_not_supported",
      "ledgr_strategy_preflight_error"
    )
  )
}

ledgr_abort_strategy_ambient_rng_for_parallel <- function(preflight) {
  symbols <- ledgr_strategy_preflight_ambient_rng_symbols(preflight)
  if (length(symbols) == 0L) {
    return(invisible(FALSE))
  }
  rlang::abort(
    paste0(
      "Refusing to run a parallel sweep for a strategy that reads ambient RNG state: ",
      paste(symbols, collapse = ", "),
      ". Parallel equivalence is guaranteed only for strategies deterministic in `(ctx, params)`. ",
      "Use `ctx$pulse_seed` to derive pulse-specific stochastic inputs without reading `.Random.seed`."
    ),
    class = c(
      "ledgr_strategy_ambient_rng_parallel",
      "ledgr_strategy_ambient_rng_not_supported",
      "ledgr_strategy_preflight_error"
    )
  )
}
