ledgr_census_empty_frame <- function(columns) {
  values <- lapply(columns, function(type) {
    if (identical(type, "character")) return(character())
    if (identical(type, "integer")) return(integer())
    if (identical(type, "logical")) return(logical())
    if (identical(type, "double")) return(double())
    stop(sprintf("Unsupported census column type `%s`.", type), call. = FALSE)
  })
  as.data.frame(values, stringsAsFactors = FALSE)
}

ledgr_census_schemas <- function() {
  list(
    conditions = ledgr_census_empty_frame(c(
      file = "character", line = "integer", call_kind = "character",
      condition_class = "character", recoverable = "logical",
      expression = "character", documented_alias = "logical",
      documented_description = "logical", internal_prefix = "logical"
    )),
    condition_classes = ledgr_census_empty_frame(c(
      condition_class = "character", first_file = "character",
      first_line = "integer", occurrence_count = "integer",
      public = "logical", internal_prefix = "logical",
      documented_alias = "logical", documented_description = "logical",
      classification = "character"
    )),
    connections = ledgr_census_empty_frame(c(
      file = "character", line = "integer", owner = "character",
      entry_kind = "character", call = "character",
      persistent_store = "logical", classification = "character",
      current_guard = "character"
    )),
    helpers = ledgr_census_empty_frame(c(
      file = "character", line = "integer", helper = "character",
      exported = "logical", s3_method = "logical", hook = "logical",
      in_scope_private = "logical", r_reference_count = "integer",
      test_reference_count = "integer",
      dynamic_reference_count = "integer", reference_locations = "character",
      classification = "character"
    )),
    run_configs = ledgr_census_empty_frame(c(
      file = "character", line = "integer", owner = "character",
      consumer = "character", config_origin = "character",
      identity_rule_version = "character", data_snapshot_hash = "character",
      origin_expression = "character", expression = "character"
    )),
    versions = ledgr_census_empty_frame(c(
      file = "character", line = "integer", owner = "character",
      record_kind = "character", expression = "character",
      persisted_or_convention = "logical",
      persistence_evidence = "character", fingerprint_member = "logical",
      atomic_scalar = "logical", outside_fingerprint = "logical",
      comparison_operator = "character", equality_assertion = "logical",
      current_only_violation = "logical"
    ))
  )
}

ledgr_census_bind_rows <- function(rows, prototype) {
  if (!is.data.frame(prototype) || nrow(prototype) != 0L) {
    stop("`prototype` must be a zero-row data frame.", call. = FALSE)
  }
  if (length(rows) == 0L) {
    return(prototype)
  }
  out <- do.call(rbind, rows)
  missing <- setdiff(names(prototype), names(out))
  if (length(missing) > 0L) {
    stop(sprintf(
      "Census rows are missing columns: %s.",
      paste(missing, collapse = ", ")
    ), call. = FALSE)
  }
  out[, names(prototype), drop = FALSE]
}

ledgr_census_summary <- function(families) {
  required <- names(ledgr_census_schemas())
  if (!identical(sort(names(families)), sort(required))) {
    stop("Census summary families do not match the declared schemas.", call. = FALSE)
  }
  data.frame(
    family = c(
      "condition_call_sites", "condition_classes", "connections", "helpers",
      "run_configs", "versions"
    ),
    rows = as.integer(c(
      nrow(families$conditions), nrow(families$condition_classes),
      nrow(families$connections), nrow(families$helpers),
      nrow(families$run_configs), nrow(families$versions)
    )),
    findings = as.integer(c(
      sum(!families$conditions$call_kind %in% c(
        "abort_class", "abort_wrapper_class", "warning_class"
      )),
      sum(families$condition_classes$public &
            (!families$condition_classes$documented_alias |
               !families$condition_classes$documented_description)),
      sum(
        families$connections$persistent_store &
          families$connections$current_guard == "none" &
          !families$connections$owner %in% c(
            "ledgr_open_duckdb_with_retry", "ledgr_join_open_duckdb"
          )
      ),
      sum(families$helpers$classification == "uncalled_private"),
      sum(families$run_configs$consumer != "config_builder" &
            (families$run_configs$identity_rule_version != "supplied" |
               families$run_configs$data_snapshot_hash != "supplied")),
      sum(families$versions$outside_fingerprint) +
        sum(families$versions$current_only_violation)
    )),
    stringsAsFactors = FALSE
  )
}

ledgr_structure_call_name <- function(x) {
  if (is.symbol(x)) {
    return(as.character(x))
  }
  if (
    is.call(x) &&
      identical(as.character(x[[1L]]), "::") &&
      length(x) == 3L
  ) {
    return(paste0(as.character(x[[2L]]), "::", as.character(x[[3L]])))
  }
  ""
}

ledgr_structure_literal_classes <- function(x) {
  if (is.character(x)) {
    return(x)
  }
  if (
    is.call(x) &&
      identical(ledgr_structure_call_name(x[[1L]]), "c")
  ) {
    values <- as.list(x)[-1L]
    literal <- vapply(values, is.character, logical(1))
    return(unlist(values[literal], use.names = FALSE))
  }
  character()
}

ledgr_structure_ledgr_literals <- function(x) {
  found <- character()
  walk <- function(value) {
    if (is.character(value)) {
      found <<- c(found, value[grepl("^ledgr_", value)])
      return(invisible(NULL))
    }
    if (
      !is.call(value) && !is.expression(value) &&
        !is.pairlist(value) && !is.list(value)
    ) {
      return(invisible(NULL))
    }
    for (i in seq_along(value)) {
      if (identical(value[[i]], quote(expr = ))) next
      walk(value[[i]])
    }
    invisible(NULL)
  }
  walk(x)
  unique(found)
}

ledgr_structure_symbols <- function(x) {
  if (is.symbol(x)) return(as.character(x))
  if (is.call(x) || is.expression(x) || is.pairlist(x) || is.list(x)) {
    return(unique(unlist(lapply(as.list(x), ledgr_structure_symbols))))
  }
  character()
}

ledgr_structure_class_expression <- function(call) {
  args <- as.list(call)[-1L]
  tags <- names(args)
  if (is.null(tags)) tags <- rep("", length(args))
  named <- which(tags == "class")
  if (length(named) > 0L) return(args[[named[[1L]]]])
  if (length(args) >= 2L) return(args[[2L]])
  NULL
}

ledgr_structure_actual_argument <- function(call, formal, formals) {
  args <- as.list(call)[-1L]
  tags <- names(args)
  if (is.null(tags)) tags <- rep("", length(args))
  named <- which(tags == formal)
  if (length(named) > 0L) return(args[[named[[1L]]]])
  position <- match(formal, names(formals))
  positional <- which(!nzchar(tags))
  if (!is.na(position) && length(positional) >= position) {
    return(args[[positional[[position]]]])
  }
  default <- formals[[formal]]
  if (is.null(default) || identical(default, quote(expr = ))) return(NULL)
  default
}

ledgr_structure_resolved_classes <- function(x, call, formals, functions,
                                             seen = character()) {
  if (is.character(x)) return(as.character(x))
  if (is.symbol(x) && as.character(x) %in% names(formals)) {
    name <- as.character(x)
    if (name %in% seen) return(character())
    actual <- ledgr_structure_actual_argument(call, name, formals)
    if (is.null(actual)) return(character())
    return(ledgr_structure_resolved_classes(
      actual, call, formals, functions, c(seen, name)
    ))
  }
  if (is.call(x) && identical(ledgr_structure_call_name(x[[1L]]), "c")) {
    return(unlist(lapply(
      as.list(x)[-1L], ledgr_structure_resolved_classes,
      call = call, formals = formals, functions = functions, seen = seen
    ), use.names = FALSE))
  }
  if (is.call(x)) {
    resolver <- ledgr_structure_call_name(x[[1L]])
    if (resolver %in% names(functions)) {
      return(ledgr_structure_ledgr_literals(functions[[resolver]]))
    }
  }
  character()
}

ledgr_structure_condition_classes <- function(expressions, functions) {
  found <- character()
  wrappers <- list()

  collect_calls <- function(x, target = NULL) {
    calls <- list()
    walk <- function(value) {
      if (!is.call(value) && !is.expression(value) &&
          !is.pairlist(value) && !is.list(value)) {
        return(invisible(NULL))
      }
      if (is.call(value)) {
        name <- ledgr_structure_call_name(value[[1L]])
        if (is.null(target) || name %in% target) {
          calls[[length(calls) + 1L]] <<- value
        }
      }
      for (i in seq_along(value)) {
        if (identical(value[[i]], quote(expr = ))) next
        walk(value[[i]])
      }
      invisible(NULL)
    }
    walk(x)
    calls
  }

  for (name in names(functions)) {
    definition <- functions[[name]]
    formals <- as.list(definition[[2L]])
    condition_calls <- collect_calls(definition[[3L]], c(
      "abort", "rlang::abort", "warn", "rlang::warn"
    ))
    for (condition_call in condition_calls) {
      class_expression <- ledgr_structure_class_expression(condition_call)
      if (is.null(class_expression)) next
      if (length(intersect(
        ledgr_structure_symbols(class_expression), names(formals)
      )) > 0L) {
        wrappers[[length(wrappers) + 1L]] <- list(
          name = name,
          formals = formals,
          class_expression = class_expression
        )
      }
    }
  }
  wrappers_by_name <- split(wrappers, vapply(
    wrappers, `[[`, character(1), "name"
  ))

  walk <- function(x) {
    if (!is.call(x) && !is.expression(x) && !is.pairlist(x) && !is.list(x)) {
      return(invisible(NULL))
    }
    if (is.call(x)) {
      name <- ledgr_structure_call_name(x[[1L]])
      if (grepl("(^|::)(abort|warn)$", name, perl = TRUE)) {
        class_expression <- ledgr_structure_class_expression(x)
        if (!is.null(class_expression)) {
        found <<- c(found, ledgr_structure_literal_classes(class_expression))
        resolver <- if (is.call(class_expression)) {
          ledgr_structure_call_name(class_expression[[1L]])
        } else {
          ""
        }
        if (nzchar(resolver) && resolver %in% names(functions)) {
          found <<- c(
            found,
            ledgr_structure_ledgr_literals(functions[[resolver]])
          )
        }
        }
      }
      matching <- wrappers_by_name[[name]]
      if (is.null(matching)) matching <- list()
      for (spec in matching) {
        found <<- c(found, ledgr_structure_resolved_classes(
          spec$class_expression, x, spec$formals, functions
        ))
      }
    }
    for (i in seq_along(x)) {
      if (identical(x[[i]], quote(expr = ))) next
      walk(x[[i]])
    }
    invisible(NULL)
  }
  walk(expressions)
  sort(unique(found[grepl("^ledgr_", found)]), method = "radix")
}

ledgr_structure_scan <- function(root) {
  r_files <- list.files(
    file.path(root, "R"), pattern = "[.]R$", full.names = TRUE
  )
  test_files <- list.files(
    file.path(root, "tests", "testthat"),
    pattern = "[.]R$", recursive = TRUE, full.names = TRUE
  )
  if (length(r_files) == 0L || length(test_files) == 0L) {
    stop("The structural scan requires non-empty R/ and test sources.", call. = FALSE)
  }
  r_parsed <- lapply(r_files, parse, keep.source = TRUE)
  test_parsed <- lapply(test_files, parse, keep.source = TRUE)

  definitions <- unique(unlist(lapply(r_parsed, function(expressions) {
    vapply(expressions, function(expression) {
      if (
        is.call(expression) &&
          identical(as.character(expression[[1L]]), "<-") &&
          is.symbol(expression[[2L]]) &&
          is.call(expression[[3L]]) &&
          identical(as.character(expression[[3L]][[1L]]), "function")
      ) {
        return(as.character(expression[[2L]]))
      }
      NA_character_
    }, character(1))
  }), use.names = FALSE))
  definitions <- definitions[!is.na(definitions)]
  function_definitions <- list()
  for (expressions in r_parsed) {
    for (expression in expressions) {
      if (
        is.call(expression) &&
          identical(as.character(expression[[1L]]), "<-") &&
          is.symbol(expression[[2L]]) &&
          is.call(expression[[3L]]) &&
          identical(as.character(expression[[3L]][[1L]]), "function")
      ) {
        function_definitions[[as.character(expression[[2L]])]] <- expression[[3L]]
      }
    }
  }
  tokens <- unlist(lapply(c(r_parsed, test_parsed), function(expressions) {
    data <- getParseData(attr(expressions, "srcfile"))
    values <- data$text[data$token %in% c(
      "SYMBOL", "SYMBOL_FUNCTION_CALL", "STR_CONST"
    )]
    sub("^(['\"])(.*)\\1$", "\\2", values, perl = TRUE)
  }), use.names = FALSE)
  token_counts <- table(tokens)

  namespace <- readLines(file.path(root, "NAMESPACE"), warn = FALSE)
  exports <- sub(
    "^export[(]([^)]*)[)].*$", "\\1",
    grep("^export[(]", namespace, value = TRUE)
  )
  s3_lines <- grep("^S3method[(]", namespace, value = TRUE)
  s3_methods <- vapply(s3_lines, function(line) {
    fields <- strsplit(
      sub("^S3method[(]([^)]*)[)].*$", "\\1", line),
      ",", fixed = TRUE
    )[[1L]]
    fields <- trimws(gsub('^"|"$', "", fields))
    paste(fields[[1L]], fields[[2L]], sep = ".")
  }, character(1))
  helpers <- sort(definitions, method = "radix")
  private <- setdiff(helpers, c(exports, s3_methods, ".onLoad"))
  counts <- unname(token_counts[private])
  counts[is.na(counts)] <- 0L

  condition_classes <- ledgr_structure_condition_classes(
    r_parsed,
    function_definitions
  )
  list(
    helpers = helpers,
    private_helpers = sort(private, method = "radix"),
    orphan_helpers = sort(private[counts < 2L], method = "radix"),
    direct_condition_classes = condition_classes,
    condition_classes = condition_classes
  )
}

## Execution-mode branch census --------------------------------------------
#
# Cut 16 decision (17) and the macro plan's execution-core consolidation
# require every availability/dense switch in R/ to stay visible in review. A
# site is one reference to a mode switch inside one top-level function:
#
# - `availability_active` as a variable or field (`services$availability_active`,
#   `ctx$availability_active`, ...);
# - `availability$active` (`isTRUE(exp$availability$active)` and equivalents);
# - a call to `ledgr_availability_config_active()` or
#   `ledgr_backtest_availability_active()`;
# - `is.null(history_substrate)` or `is.null(availability_provider)`, the
#   substrate-presence form of the same split;
# - a function-local alias assigned a flag expression built from one of the
#   above (for example `use_fast_context <- !availability_active`).
#
# Each `if` or `ifelse` whose condition contains a switch is one `branch`
# site keyed by its condition text; every other switch reference is one
# `flow` site keyed by where the value goes (assignment target or call
# argument). Keys omit line numbers so unrelated edits do not churn the
# committed record; `occurrence` numbers repeated keys in source order.

ledgr_mode_branch_key_columns <- function() {
  c("file", "owner", "kind", "switch", "context", "occurrence")
}

ledgr_mode_branch_schema <- function() {
  ledgr_census_empty_frame(c(
    file = "character", owner = "character", kind = "character",
    switch = "character", context = "character", occurrence = "integer",
    line = "integer"
  ))
}

ledgr_mode_branch_helper_calls <- function() {
  c("ledgr_availability_config_active", "ledgr_backtest_availability_active")
}

ledgr_mode_branch_presence_symbols <- function() {
  c("history_substrate", "availability_provider")
}

ledgr_mode_branch_wrappers <- function() {
  c("isTRUE", "isFALSE", "!", "(", "&&", "||", "&", "|", "is.null")
}

ledgr_mode_branch_text <- function(x) {
  gsub(
    "[[:space:]]+", " ",
    paste(deparse(x, width.cutoff = 500L), collapse = " ")
  )
}

ledgr_mode_branch_head <- function(x) {
  if (!is.call(x)) return("")
  head <- x[[1L]]
  if (is.symbol(head)) return(as.character(head))
  if (is.call(head) && length(head) == 3L &&
      as.character(head[[1L]]) %in% c("::", ":::")) {
    return(as.character(head[[3L]]))
  }
  ""
}

ledgr_mode_branch_children <- function(x) {
  if (!is.call(x)) return(list())
  values <- as.list(x)[-1L]
  keep <- !vapply(values, function(value) {
    identical(value, quote(expr = ))
  }, logical(1))
  values[keep]
}

# The switch named by `x` itself, or NA. `aliases` are function-local flags.
ledgr_mode_branch_switch_at <- function(x, aliases = character()) {
  if (is.symbol(x)) {
    name <- as.character(x)
    if (identical(name, "availability_active")) return("availability_active")
    if (name %in% aliases) return(paste0("alias:", name))
    return(NA_character_)
  }
  if (!is.call(x)) return(NA_character_)
  head <- ledgr_mode_branch_head(x)
  if (identical(head, "$") && length(x) == 3L && is.symbol(x[[3L]])) {
    field <- as.character(x[[3L]])
    if (identical(field, "availability_active")) return("$availability_active")
    target <- x[[2L]]
    names_availability <- (is.symbol(target) &&
      identical(as.character(target), "availability")) ||
      (is.call(target) && identical(ledgr_mode_branch_head(target), "$") &&
        length(target) == 3L && is.symbol(target[[3L]]) &&
        identical(as.character(target[[3L]]), "availability"))
    if (identical(field, "active") && names_availability) {
      return("availability$active")
    }
    return(NA_character_)
  }
  if (head %in% ledgr_mode_branch_helper_calls()) return(paste0(head, "()"))
  if (identical(head, "is.null") && length(x) == 2L && is.symbol(x[[2L]]) &&
      as.character(x[[2L]]) %in% ledgr_mode_branch_presence_symbols()) {
    return(paste0("is.null(", as.character(x[[2L]]), ")"))
  }
  NA_character_
}

ledgr_mode_branch_switches_in <- function(x, aliases = character()) {
  here <- ledgr_mode_branch_switch_at(x, aliases)
  if (!is.na(here)) return(here)
  if (!is.call(x) || identical(ledgr_mode_branch_head(x), "function")) {
    return(character())
  }
  unique(unlist(lapply(
    ledgr_mode_branch_children(x), ledgr_mode_branch_switches_in,
    aliases = aliases
  ), use.names = FALSE))
}

ledgr_mode_branch_flag_expression <- function(x) {
  if (is.symbol(x)) return(TRUE)
  ledgr_mode_branch_head(x) %in% c(
    "isTRUE", "isFALSE", "!", "&&", "||", "&", "|", "identical", "is.null",
    "(", "$", ledgr_mode_branch_helper_calls()
  )
}

# Function-local aliases: symbols assigned a flag expression that contains a
# switch, repeated to a fixed point so an alias of an alias is found.
ledgr_mode_branch_aliases <- function(body) {
  assignments <- list()
  collect <- function(x) {
    if (!is.call(x)) return(invisible(NULL))
    if (ledgr_mode_branch_head(x) %in% c("<-", "=", "<<-") &&
        length(x) == 3L && is.symbol(x[[2L]])) {
      assignments[[length(assignments) + 1L]] <<- list(
        name = as.character(x[[2L]]), value = x[[3L]]
      )
    }
    for (child in ledgr_mode_branch_children(x)) collect(child)
    invisible(NULL)
  }
  collect(body)
  aliases <- character()
  repeat {
    found <- unique(unlist(lapply(assignments, function(item) {
      if (identical(item$name, "availability_active") ||
          item$name %in% aliases ||
          !ledgr_mode_branch_flag_expression(item$value) ||
          length(ledgr_mode_branch_switches_in(item$value, aliases)) == 0L) {
        return(character())
      }
      item$name
    }), use.names = FALSE))
    if (length(found) == 0L) break
    aliases <- sort(unique(c(aliases, found)), method = "radix")
  }
  aliases
}

ledgr_mode_branch_function_sites <- function(definition, file, owner, line) {
  aliases <- ledgr_mode_branch_aliases(definition[[3L]])
  sites <- list()
  add <- function(kind, switch, context, at) {
    sites[[length(sites) + 1L]] <<- list(
      file = file, owner = owner, kind = kind, switch = switch,
      context = context, line = as.integer(at)
    )
  }
  walk <- function(x, context, at) {
    switch_here <- ledgr_mode_branch_switch_at(x, aliases)
    if (!is.na(switch_here)) {
      add("flow", switch_here, context, at)
      return(invisible(NULL))
    }
    if (!is.call(x)) return(invisible(NULL))
    head <- ledgr_mode_branch_head(x)
    if (identical(head, "{")) {
      refs <- attr(x, "srcref")
      children <- as.list(x)[-1L]
      for (i in seq_along(children)) {
        child_at <- if (length(refs) > i) as.integer(refs[[i + 1L]])[[1L]] else at
        walk(children[[i]], "statement", child_at)
      }
      return(invisible(NULL))
    }
    if (head %in% c("if", "ifelse") && length(x) >= 3L) {
      condition <- x[[2L]]
      switches <- ledgr_mode_branch_switches_in(condition, aliases)
      if (length(switches) > 0L) {
        add(
          "branch",
          paste(sort(switches, method = "radix"), collapse = "+"),
          paste0(head, ": ", ledgr_mode_branch_text(condition)),
          at
        )
      } else {
        walk(condition, paste0(head, "_condition"), at)
      }
      for (child in as.list(x)[-(1:2)]) {
        if (!identical(child, quote(expr = ))) walk(child, "statement", at)
      }
      return(invisible(NULL))
    }
    if (identical(head, "function")) {
      walk(x[[3L]], "statement", at)
      return(invisible(NULL))
    }
    if (head %in% c("<-", "=", "<<-") && length(x) == 3L) {
      walk(x[[2L]], "assign_target", at)
      walk(x[[3L]], paste0("assign:", ledgr_mode_branch_text(x[[2L]])), at)
      return(invisible(NULL))
    }
    wrapper <- head %in% ledgr_mode_branch_wrappers()
    args <- as.list(x)[-1L]
    tags <- names(args)
    if (is.null(tags)) tags <- rep("", length(args))
    for (i in seq_along(args)) {
      if (identical(args[[i]], quote(expr = ))) next
      child_context <- if (wrapper) {
        context
      } else {
        paste0("arg:", head, ":", if (nzchar(tags[[i]])) tags[[i]] else i)
      }
      walk(args[[i]], child_context, at)
    }
    invisible(NULL)
  }
  walk(definition[[3L]], "statement", line)
  sites
}

ledgr_mode_branch_scan <- function(root) {
  files <- list.files(file.path(root, "R"), pattern = "[.]R$", full.names = TRUE)
  files <- files[order(basename(files), method = "radix")]
  sites <- list()
  for (path in files) {
    parsed <- parse(path, keep.source = TRUE, encoding = "UTF-8")
    refs <- attr(parsed, "srcref")
    for (i in seq_along(parsed)) {
      expression <- parsed[[i]]
      if (!is.call(expression) || length(expression) != 3L ||
          !ledgr_mode_branch_head(expression) %in% c("<-", "=") ||
          !is.symbol(expression[[2L]]) ||
          !identical(ledgr_mode_branch_head(expression[[3L]]), "function")) {
        next
      }
      # Every switch form names one of these tokens, so a definition whose
      # source text has none of them has no site and is not walked.
      if (!grepl(
        "active|history_substrate|availability_provider",
        paste(as.character(refs[[i]]), collapse = "\n")
      )) {
        next
      }
      sites <- c(sites, ledgr_mode_branch_function_sites(
        expression[[3L]],
        file = file.path("R", basename(path)),
        owner = as.character(expression[[2L]]),
        line = as.integer(refs[[i]])[[1L]]
      ))
    }
  }
  if (length(sites) == 0L) return(ledgr_mode_branch_schema())
  out <- data.frame(
    file = vapply(sites, `[[`, character(1), "file"),
    owner = vapply(sites, `[[`, character(1), "owner"),
    kind = vapply(sites, `[[`, character(1), "kind"),
    switch = vapply(sites, `[[`, character(1), "switch"),
    context = vapply(sites, `[[`, character(1), "context"),
    line = vapply(sites, `[[`, integer(1), "line"),
    stringsAsFactors = FALSE
  )
  key <- paste(out$file, out$owner, out$kind, out$switch, out$context, sep = "\r")
  out$occurrence <- as.integer(stats::ave(seq_along(key), key, FUN = seq_along))
  out <- out[order(
    out$file, out$owner, out$kind, out$switch, out$context, out$occurrence,
    method = "radix"
  ), names(ledgr_mode_branch_schema()), drop = FALSE]
  rownames(out) <- NULL
  out
}

ledgr_mode_branch_counts <- function(sites) {
  files <- sort(unique(sites$file), method = "radix")
  count <- function(f, kind) sum(sites$file == f & sites$kind == kind)
  data.frame(
    file = files,
    functions = vapply(files, function(f) {
      length(unique(sites$owner[sites$file == f]))
    }, integer(1), USE.NAMES = FALSE),
    branch_sites = vapply(files, count, integer(1), kind = "branch",
                          USE.NAMES = FALSE),
    flow_sites = vapply(files, count, integer(1), kind = "flow",
                        USE.NAMES = FALSE),
    stringsAsFactors = FALSE
  )
}

ledgr_mode_branch_compare <- function(sites, record) {
  columns <- ledgr_mode_branch_key_columns()
  missing <- setdiff(columns, names(record))
  if (length(missing) > 0L) {
    stop(sprintf(
      "The mode-branch record is missing columns: %s.",
      paste(missing, collapse = ", ")
    ), call. = FALSE)
  }
  key_of <- function(x) {
    if (nrow(x) == 0L) return(character())
    paste(x$file, x$owner, x$kind, x$switch, x$context,
          as.integer(x$occurrence), sep = "\r")
  }
  found <- key_of(sites)
  recorded <- key_of(record)
  list(
    unrecorded = sites[!found %in% recorded, , drop = FALSE],
    stale = record[!recorded %in% found, columns, drop = FALSE]
  )
}

ledgr_mode_branch_check <- function(sites, record) {
  difference <- ledgr_mode_branch_compare(sites, record)
  if (nrow(difference$unrecorded) == 0L && nrow(difference$stale) == 0L) {
    return(invisible(TRUE))
  }
  describe <- function(x) {
    if (nrow(x) == 0L) return("none")
    at <- if ("line" %in% names(x)) paste0(":", x$line) else ""
    # Keys carry no line: when a site is added beside equal ones, the
    # unrecorded row is the key's last occurrence, wherever the edit was.
    paste(sprintf(
      "%s%s %s %s [%s] %s (occurrence %d)", x$file, at, x$owner, x$kind,
      x$switch, x$context, as.integer(x$occurrence)
    ), collapse = "; ")
  }
  stop(sprintf(
    paste0(
      "LEDGR_MODE_BRANCH_CENSUS_FAILED unrecorded=%d stale=%d. ",
      "Unrecorded: %s. Stale: %s. Regenerate the committed record in report ",
      "mode only with a stated reason; execution-mode branches are frozen ",
      "pending execution-core consolidation."
    ),
    nrow(difference$unrecorded), nrow(difference$stale),
    describe(difference$unrecorded), describe(difference$stale)
  ), call. = FALSE)
}
