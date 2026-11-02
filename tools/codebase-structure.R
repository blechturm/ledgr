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

ledgr_structure_reference_tokens <- function(source_files) {
  source <- unlist(source_files, use.names = FALSE)
  parsed <- parse(text = source, keep.source = TRUE, encoding = "UTF-8")
  data <- getParseData(attr(parsed, "srcfile"))
  values <- data$text[data$token %in% c(
    "SYMBOL", "SYMBOL_FUNCTION_CALL", "STR_CONST"
  )]
  sub("^(['\"])(.*)\\1$", "\\2", values, perl = TRUE)
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
  found <- list()
  wrappers <- list()
  add_found <- function(values) {
    if (length(values) > 0L) {
      found[[length(found) + 1L]] <<- values
    }
    invisible(NULL)
  }

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
      if (name %in% c("abort", "rlang::abort", "warn", "rlang::warn")) {
        class_expression <- ledgr_structure_class_expression(x)
        if (!is.null(class_expression)) {
        add_found(ledgr_structure_literal_classes(class_expression))
        resolver <- if (is.call(class_expression)) {
          ledgr_structure_call_name(class_expression[[1L]])
        } else {
          ""
        }
        if (nzchar(resolver) && resolver %in% names(functions)) {
          add_found(ledgr_structure_ledgr_literals(functions[[resolver]]))
        }
        }
      }
      matching <- wrappers_by_name[[name]]
      if (is.null(matching)) matching <- list()
      for (spec in matching) {
        add_found(ledgr_structure_resolved_classes(
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
  found <- unlist(found, use.names = FALSE)
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
  r_source <- lapply(r_files, readLines, warn = FALSE, encoding = "UTF-8")
  test_source <- lapply(
    test_files, readLines, warn = FALSE, encoding = "UTF-8"
  )
  parse_source <- function(source) {
    parse(text = source, keep.source = FALSE, encoding = "UTF-8")
  }
  r_parsed <- lapply(r_source, parse_source)
  test_parsed <- lapply(test_source, parse_source)

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
  # Parse one combined source for the reference census instead of building a
  # separate parse-data table for every R and test file.
  tokens <- ledgr_structure_reference_tokens(c(r_source, test_source))
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
  c(
    "ledgr_availability_config_active",
    "ledgr_backtest_availability_active",
    "ledgr_execution_clock_kind_from_config"
  )
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
    if (name %in% c("availability_active", "clock_kind")) return(name)
    if (name %in% aliases) return(paste0("alias:", name))
    return(NA_character_)
  }
  if (!is.call(x)) return(NA_character_)
  head <- ledgr_mode_branch_head(x)
  if (identical(head, "$") && length(x) == 3L && is.symbol(x[[3L]])) {
    field <- as.character(x[[3L]])
    if (identical(field, "availability_active")) return("$availability_active")
    if (identical(field, "clock_kind")) return("$clock_kind")
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
      if (item$name %in% c("availability_active", "clock_kind") ||
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
      # source text has none of them has no site and is not walked. The
      # execution-clock token owns result-reader differences after WS4b
      # removed the old availability/dense execution split.
      if (!grepl(
        "active|history_substrate|availability_provider|clock_kind",
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

## Shared source-index primitives ------------------------------------------
#
# Extracted from tools/check-codebase-contracts.R (cut 8, C2) so that the
# fast hot-path scanner reuses them without sourcing the CLI. The CLI keeps
# its historical helper names as thin wrappers over these.

ledgr_census_relative_path <- function(root, path) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  prefix <- paste0(root, "/")
  ifelse(startsWith(path, prefix), substring(path, nchar(prefix) + 1L), path)
}

ledgr_census_source_files <- function(root, paths) {
  files <- unlist(lapply(paths, function(path) {
    full <- file.path(root, path)
    if (!dir.exists(full)) return(character())
    list.files(full, pattern = "\\.[Rr]$", recursive = TRUE, full.names = TRUE)
  }), use.names = FALSE)
  files[order(ledgr_census_relative_path(root, files), method = "radix", na.last = TRUE)]
}

ledgr_census_parse_source <- function(root, path, keep_source = TRUE) {
  tryCatch(
    parse(path, keep.source = keep_source, encoding = "UTF-8"),
    error = function(e) {
      stop(sprintf(
        "Cannot parse %s: %s", ledgr_census_relative_path(root, path),
        conditionMessage(e)
      ), call. = FALSE)
    }
  )
}

ledgr_census_top_definitions <- function(root, path, parsed) {
  refs <- attr(parsed, "srcref")
  file <- ledgr_census_relative_path(root, path)
  out <- vector("list", 0L)
  for (i in seq_along(parsed)) {
    expr <- parsed[[i]]
    if (!is.call(expr) || length(expr) < 3L || !is.symbol(expr[[1L]]) ||
        !as.character(expr[[1L]]) %in% c("<-", "=")) next
    lhs <- expr[[2L]]
    rhs <- expr[[3L]]
    if (!is.symbol(lhs)) next
    ref <- refs[[i]]
    line_start <- if (is.null(ref)) NA_integer_ else as.integer(ref)[[1L]]
    line_end <- if (is.null(ref)) line_start else as.integer(ref)[[3L]]
    is_function <- is.call(rhs) && identical(as.character(rhs[[1L]]), "function")
    formals <- if (is_function) names(as.list(rhs[[2L]])) else character()
    out[[length(out) + 1L]] <- list(
      name = as.character(lhs),
      file = file,
      line = line_start,
      line_end = line_end,
      is_function = is_function,
      formals = formals,
      rhs = rhs,
      expression = expr
    )
  }
  out
}

## hot-path analyzer begin -------------------------------------------------
#
# Macro rule 17 (cut 8): banned calls and canonical JSON in code that can run
# per pulse are pinned in committed census records. The scan walks package
# source from the pulse loop body, the helper-bundle closures, every export or
# S3 method the surface table classifies per_pulse, and closures a family
# declares. Calls the walker cannot resolve fail until declared. The record
# set is compared exactly in check mode; report mode regenerates it, refusing
# unreasoned growth, coverage loss and input or analyzer changes. The text
# between this marker and the end marker is hashed into the policy record.

ledgr_hot_path_record_files <- function() {
  c(
    bans = "hot_path_bans.csv",
    surface = "hot_path_surface.csv",
    families = "hot_path_families.csv",
    declarations = "hot_path_declarations.csv",
    json = "hot_path_json.csv",
    policy = "hot_path_policy.csv",
    reach = "hot_path_reach.csv"
  )
}

ledgr_hot_path_input_names <- function() {
  c("surface", "families", "declarations", "json")
}

ledgr_hot_path_columns <- function() {
  list(
    bans = c("node", "file", "call", "count", "reason"),
    surface = c("name", "kind", "per_pulse", "family", "reason"),
    families = c("family", "roots", "returned_closures", "workload", "uncovered", "reason"),
    declarations = c("kind", "node", "site", "occurrence", "targets", "reason"),
    json = c("identity", "role", "counted", "reason"),
    policy = c("key", "value"),
    reach = c("node", "file", "root", "via")
  )
}

ledgr_hot_path_record_dir <- function(root) {
  file.path(root, "dev", "bench", "v0_2_2_pre_cran_removal", "census")
}

ledgr_hot_path_default_policy <- function() {
  list(
    banned = c(
      "match", "%in%", "setdiff", "setNames", "unique", "data.frame",
      "as.data.frame", "rbind", "all.equal"
    ),
    banned_packages = c("base", "stats"),
    json_packages = c("yyjsonr", "jsonlite"),
    loop_owner = "ledgr_fold_envelope/run_loop",
    loop_marker = "ledgr_fold_stage_observe_settle",
    bundle_owner = "ledgr_pulse_context_helper_bundle",
    known_packages = c(
      "base", "stats", "utils", "methods", "graphics", "grDevices", "tools"
    )
  )
}

# Function-valued argument of each higher-order call: its name and position.
ledgr_hot_path_apply_args <- function() {
  list(
    lapply = list("FUN", 2L), sapply = list("FUN", 2L),
    vapply = list("FUN", 2L), eapply = list("FUN", 2L),
    rapply = list("f", 2L), mapply = list("FUN", 1L), Map = list("f", 1L),
    Reduce = list("f", 1L), Filter = list("f", 1L), Find = list("f", 1L),
    Position = list("f", 1L), do.call = list("what", 1L),
    outer = list("FUN", 3L), tapply = list("FUN", 3L),
    apply = list("FUN", 3L), by = list("FUN", 3L), ave = list("FUN", NA_integer_),
    match.fun = list("FUN", 1L), Vectorize = list("FUN", 1L)
  )
}

ledgr_hot_path_not_executed <- function() {
  c("quote", "bquote", "substitute", "expression", "~", "alist")
}

ledgr_hot_path_is_function <- function(x) {
  is.call(x) && identical(x[[1L]], as.name("function"))
}

ledgr_hot_path_is_empty <- function(x) identical(x, quote(expr = ))

# Elements of a call or pairlist without empty arguments, which cannot be
# bound to a loop variable.
ledgr_hot_path_children <- function(x) {
  values <- as.list(x)
  if (!length(values)) return(list())
  values[!vapply(values, ledgr_hot_path_is_empty, logical(1))]
}

ledgr_hot_path_set <- function(names) {
  names <- unique(names[nzchar(names)])
  list2env(stats::setNames(as.list(rep(TRUE, length(names))), names),
           hash = TRUE, parent = emptyenv())
}

ledgr_hot_path_head <- function(x) {
  if (!is.call(x)) return("")
  head <- x[[1L]]
  if (is.symbol(head)) return(as.character(head))
  ""
}

ledgr_hot_path_member_name <- function(x) {
  # `x$m` or literal `x[["m"]]`; NA otherwise.
  if (!is.call(x) || length(x) != 3L) return(NA_character_)
  head <- ledgr_hot_path_head(x)
  if (identical(head, "$") && is.symbol(x[[3L]])) return(as.character(x[[3L]]))
  if (identical(head, "$") && is.character(x[[3L]])) return(x[[3L]])
  if (identical(head, "[[") && is.character(x[[3L]]) && length(x[[3L]]) == 1L) {
    return(x[[3L]])
  }
  NA_character_
}

ledgr_hot_path_qualified <- function(x) {
  # `pkg::f` / `pkg:::f` as c(pkg, f); NULL otherwise.
  if (is.call(x) && length(x) == 3L &&
      ledgr_hot_path_head(x) %in% c("::", ":::")) {
    return(c(as.character(x[[2L]]), as.character(x[[3L]])))
  }
  NULL
}

ledgr_hot_path_parent_scope <- function(key) {
  base <- sub("#[0-9]+$", "", key)
  cut <- regexpr("[/$][^/$]*$", base)
  if (cut < 1L) return("")
  substring(base, 1L, cut - 1L)
}

# Definitions: every top-level function, every closure assigned to a local
# symbol (`owner/name`), every member closure (`owner$name`, from a `list()`
# element or `x$name <- function`), and member aliases. A later definition
# under the same key gets an occurrence suffix (`key#2`) instead of
# overwriting the first.
ledgr_hot_path_definitions <- function(root, policy = ledgr_hot_path_default_policy()) {
  not_executed <- ledgr_hot_path_not_executed()
  files <- ledgr_census_source_files(root, "R")
  # JSON backend calls are recorded on this same pass, by top-level owner,
  # for the inventory completeness check.
  imported <- ledgr_hot_path_imported(root)
  backend_bare <- imported[sub("::.*$", "", imported) %in% policy$json_packages]
  backend_env <- list2env(as.list(backend_bare), hash = TRUE, parent = emptyenv())
  backend_owner <- character()
  backend_identity <- character()
  note_backend <- function(identity, scope) {
    backend_owner[[length(backend_owner) + 1L]] <<- sub("[/$#].*$", "", scope)
    backend_identity[[length(backend_identity) + 1L]] <<- identity
  }
  # Hashed stores: occurrence counts and nodes are written once per
  # definition, in source order.
  store <- new.env(hash = TRUE, parent = emptyenv())
  used <- new.env(hash = TRUE, parent = emptyenv())
  order_keys <- character()
  aliases <- list()
  top_assigned <- character()
  add <- function(base, fn, file, kind, alias = NULL) {
    n <- if (is.null(used[[base]])) 1L else used[[base]] + 1L
    used[[base]] <- n
    key <- if (n == 1L) base else paste0(base, "#", n)
    order_keys[[length(order_keys) + 1L]] <<- key
    store[[key]] <- list(
      key = key, base = base, fn = fn, file = file, kind = kind, alias = alias
    )
    key
  }
  # Called only on calls. Arguments that are not calls cannot hold a nested
  # definition, so only call arguments are visited (except list aliases).
  collect <- function(x, scope, file) {
    first <- x[[1L]]
    head <- if (is.symbol(first)) as.character(first) else ""
    if (head %in% not_executed) return(invisible(NULL))
    if (head == "::" || head == ":::") {
      if (as.character(x[[2L]]) %in% policy$json_packages) {
        note_backend(paste0(as.character(x[[2L]]), "::", as.character(x[[3L]])), scope)
      }
      return(invisible(NULL))
    }
    if (nzchar(head) && !is.null(backend_env[[head]])) note_backend(backend_env[[head]], scope)
    if (head == "function") {
      if (is.call(x[[3L]])) collect(x[[3L]], scope, file)
      return(invisible(NULL))
    }
    if ((head == "<-" || head == "=" || head == "<<-") && length(x) == 3L) {
      lhs <- x[[2L]]
      rhs <- x[[3L]]
      member <- ledgr_hot_path_member_name(lhs)
      if (ledgr_hot_path_is_function(rhs) && (is.symbol(lhs) || !is.na(member))) {
        key <- if (is.symbol(lhs)) {
          add(paste0(scope, "/", as.character(lhs)), rhs, file, "local")
        } else {
          add(paste0(scope, "$", member), rhs, file, "member")
        }
        if (is.call(rhs[[3L]])) collect(rhs[[3L]], key, file)
        return(invisible(NULL))
      }
      if (!is.na(member) && (is.symbol(rhs) || !is.null(ledgr_hot_path_qualified(rhs)) ||
          !is.na(ledgr_hot_path_member_name(rhs)))) {
        aliases[[length(aliases) + 1L]] <<- list(scope = scope, member = member, value = rhs)
      }
      if (is.call(rhs)) collect(rhs, scope, file)
      if (is.call(lhs)) collect(lhs, scope, file)
      return(invisible(NULL))
    }
    n <- length(x)
    if (head == "list" && !is.null(names(x))) {
      tags <- names(x)
      for (i in seq_len(n)[-1L]) {
        if (!nzchar(tags[[i]]) || ledgr_hot_path_is_empty(x[[i]])) {
          if (is.call(x[[i]])) collect(x[[i]], scope, file)
          next
        }
        arg <- x[[i]]
        if (ledgr_hot_path_is_function(arg)) {
          key <- add(paste0(scope, "$", tags[[i]]), arg, file, "member")
          if (is.call(arg[[3L]])) collect(arg[[3L]], key, file)
          next
        }
        if (is.symbol(arg) || !is.null(ledgr_hot_path_qualified(arg)) ||
            !is.na(ledgr_hot_path_member_name(arg))) {
          aliases[[length(aliases) + 1L]] <<- list(scope = scope, member = tags[[i]], value = arg)
        }
        if (is.call(arg)) collect(arg, scope, file)
      }
    } else if (n > 1L) {
      for (i in 2:n) if (is.call(x[[i]])) collect(x[[i]], scope, file)
    }
    if (is.call(first)) collect(first, scope, file)
    invisible(NULL)
  }
  for (path in files) {
    parsed <- ledgr_census_parse_source(root, path, keep_source = FALSE)
    file <- ledgr_census_relative_path(root, path)
    for (definition in ledgr_census_top_definitions(root, path, parsed)) {
      top_assigned <- c(top_assigned, definition$name)
      if (isTRUE(definition$is_function)) {
        key <- add(definition$name, definition$rhs, file, "top")
        if (is.call(definition$rhs[[3L]])) collect(definition$rhs[[3L]], key, file)
      } else if (is.symbol(definition$rhs) || !is.null(ledgr_hot_path_qualified(definition$rhs))) {
        add(definition$name, NULL, file, "alias", alias = definition$rhs)
      }
    }
  }
  nodes <- mget(order_keys, envir = store)
  list(
    nodes = nodes, aliases = aliases, top_assigned = unique(top_assigned),
    backend_calls = data.frame(
      owner = backend_owner, identity = backend_identity, stringsAsFactors = FALSE
    )
  )
}

.ledgr_hot_path_known_cache <- new.env(parent = emptyenv())

# A hashed set of external function names: base, the policy's packages and
# the root's imports. Cached per package set for repeated scans in one session.
ledgr_hot_path_known_externals <- function(root, policy) {
  imports <- character()
  description <- file.path(root, "DESCRIPTION")
  if (file.exists(description)) {
    fields <- read.dcf(description, fields = c("Imports", "Depends"))
    text <- paste(stats::na.omit(as.vector(fields)), collapse = ",")
    imports <- trimws(sub("\\(.*$", "", strsplit(text, ",")[[1L]]))
    imports <- imports[nzchar(imports) & imports != "R"]
  }
  packages <- sort(unique(c(policy$known_packages, imports)), method = "radix")
  cache_key <- paste(packages, collapse = ";")
  cached <- .ledgr_hot_path_known_cache[[cache_key]]
  if (!is.null(cached)) return(cached)
  known <- ls(baseenv(), all.names = TRUE)
  for (pkg in packages) {
    exported <- tryCatch(getNamespaceExports(pkg), error = function(e) character())
    known <- c(known, exported)
  }
  .ledgr_hot_path_known_cache[[cache_key]] <- ledgr_hot_path_set(known)
  .ledgr_hot_path_known_cache[[cache_key]]
}

ledgr_hot_path_imported <- function(root) {
  # Bare names imported with importFrom(pkg, name) -> "pkg::name".
  path <- file.path(root, "NAMESPACE")
  if (!file.exists(path)) return(character())
  out <- character()
  for (x in as.list(parse(path, keep.source = FALSE))) {
    if (!identical(ledgr_hot_path_head(x), "importFrom")) next
    pkg <- as.character(x[[2L]])
    for (i in seq_along(x)[-(1:2)]) {
      name <- as.character(x[[i]])
      out[[name]] <- paste0(pkg, "::", name)
    }
  }
  out
}

ledgr_hot_path_namespace_surface <- function(root) {
  path <- file.path(root, "NAMESPACE")
  out <- list(export = character(), S3method = character(), s4 = character())
  if (!file.exists(path)) return(out)
  for (x in as.list(parse(path, keep.source = FALSE))) {
    head <- ledgr_hot_path_head(x)
    if (identical(head, "export")) {
      out$export <- c(out$export, vapply(as.list(x)[-1L], as.character, character(1)))
    } else if (identical(head, "S3method")) {
      out$S3method <- c(out$S3method, paste0(as.character(x[[2L]]), ".", as.character(x[[3L]])))
    } else if (head %in% c("exportClasses", "exportMethods", "exportClassPattern", "exportPattern")) {
      out$s4 <- c(out$s4, head)
    }
  }
  out
}

# Walk one node: banned and JSON hits, edges, and unresolved callable sites.
ledgr_hot_path_scan_node <- function(node, context) {
  not_executed <- ledgr_hot_path_not_executed()
  fn <- node$fn
  hits <- character()
  edges <- character()
  sites <- list()
  site_seen <- list()
  banned <- context$policy$banned
  scope_of <- function(key) if (identical(node$kind, "loop")) node$scope else key
  own_scope <- scope_of(node$key)
  add_site <- function(kind, callee) {
    id <- paste(kind, callee, sep = ":")
    n <- if (is.null(site_seen[[id]])) 1L else site_seen[[id]] + 1L
    site_seen[[id]] <<- n
    sites[[length(sites) + 1L]] <<- list(site = id, occurrence = n)
  }
  locals <- character()
  alias_values <- list()
  scan_assignments <- function(x) {
    if (!is.call(x)) return(invisible(NULL))
    head <- ledgr_hot_path_head(x)
    if (head %in% not_executed) return(invisible(NULL))
    if ((head == "<-" || head == "=" || head == "<<-") && length(x) == 3L && is.symbol(x[[2L]])) {
      name <- as.character(x[[2L]])
      value <- x[[3L]]
      if (ledgr_hot_path_is_function(value)) return(invisible(NULL))
      if (is.symbol(value) || !is.null(ledgr_hot_path_qualified(value))) {
        alias_values[[name]] <<- c(alias_values[[name]], list(value))
      } else {
        locals <<- c(locals, name)
      }
    }
    if ((head == "<-" || head == "=" || head == "<<-") && length(x) == 3L &&
        ledgr_hot_path_is_function(x[[3L]])) {
      return(invisible(NULL))
    }
    for (child in ledgr_hot_path_children(x)) scan_assignments(child)
    invisible(NULL)
  }
  body <- if (is.null(fn)) NULL else fn[[3L]]
  formal_names <- if (is.null(fn)) character() else names(as.list(fn[[2L]]))
  if (!is.null(body)) scan_assignments(body)
  locals <- unique(c(locals, names(alias_values)[vapply(names(alias_values), function(n) {
    n %in% locals
  }, logical(1))]))
  # The node's lexical scope chain, innermost first, computed once.
  chain <- character()
  scope <- own_scope
  while (nzchar(scope)) {
    chain <- c(chain, scope)
    scope <- ledgr_hot_path_parent_scope(scope)
  }
  chain_prefix <- paste0(chain, "/")
  lexical <- function(name) {
    for (prefix in chain_prefix) {
      found <- context$local_index[[paste0(prefix, name)]]
      if (length(found)) return(found)
    }
    character()
  }
  # Resolve a function name to a result: list(hit, edges, unresolved).
  resolve_name <- function(name, shadow, depth = 0L) {
    if (name %in% shadow || (name %in% locals && is.null(alias_values[[name]]))) {
      # R's call lookup skips bindings that are not functions, so a formal or
      # local sharing an external function's name (`missing = "error"` beside
      # `missing(x)`) still calls that function. Any other shadowed call
      # goes through a value the walker cannot see.
      if (!is.null(context$known[[name]])) {
        return(list(hit = NA_character_, edges = character(), unresolved = FALSE))
      }
      return(list(hit = NA_character_, edges = character(), unresolved = TRUE))
    }
    local <- lexical(name)
    if (length(local)) return(list(hit = NA_character_, edges = local, unresolved = FALSE))
    if (!is.null(alias_values[[name]]) && depth < 5L) {
      results <- lapply(alias_values[[name]], resolve_value, shadow = shadow, depth = depth + 1L)
      return(list(
        hit = unique(stats::na.omit(unlist(lapply(results, `[[`, "hit")))),
        edges = unique(unlist(lapply(results, `[[`, "edges"))),
        unresolved = any(vapply(results, `[[`, logical(1), "unresolved"))
      ))
    }
    if (!is.null(context$banned[[name]])) return(list(hit = name, edges = character(), unresolved = FALSE))
    imported <- context$imported[[name]]
    if (!is.null(imported) && imported %in% context$json_counted) {
      return(list(hit = imported, edges = character(), unresolved = FALSE))
    }
    top_keys <- context$top_keys[[name]]
    if (!is.null(top_keys)) {
      hit <- if (name %in% context$json_counted) name else NA_character_
      return(list(hit = hit, edges = top_keys, unresolved = FALSE))
    }
    if (!is.null(context$known[[name]]) || !is.null(imported)) {
      return(list(hit = NA_character_, edges = character(), unresolved = FALSE))
    }
    list(hit = NA_character_, edges = character(), unresolved = TRUE)
  }
  resolve_value <- function(value, shadow, depth = 0L) {
    if (is.symbol(value)) return(resolve_name(as.character(value), shadow, depth))
    if (is.character(value) && length(value) == 1L) return(resolve_name(value, shadow, depth))
    qualified <- ledgr_hot_path_qualified(value)
    if (!is.null(qualified)) {
      identity <- paste0(qualified[[1L]], "::", qualified[[2L]])
      if (identical(qualified[[1L]], "ledgr")) return(resolve_name(qualified[[2L]], character(), depth))
      if (qualified[[1L]] %in% context$policy$banned_packages && qualified[[2L]] %in% banned) {
        return(list(hit = qualified[[2L]], edges = character(), unresolved = FALSE))
      }
      hit <- if (identity %in% context$json_counted) identity else NA_character_
      return(list(hit = hit, edges = character(), unresolved = FALSE))
    }
    member <- ledgr_hot_path_member_name(value)
    if (!is.na(member)) {
      targets <- context$member_index[[member]]
      return(list(hit = NA_character_, edges = targets, unresolved = length(targets) == 0L))
    }
    list(hit = NA_character_, edges = character(), unresolved = TRUE)
  }
  record <- function(result, kind, callee) {
    hits <<- c(hits, result$hit[!is.na(result$hit)])
    edges <<- c(edges, result$edges)
    if (isTRUE(result$unresolved)) add_site(kind, callee)
  }
  walk_value_symbol <- function(name, shadow) {
    # A symbol in value position: a function passed or stored by name.
    if (name %in% shadow || name %in% locals) return(invisible(NULL))
    if (!is.null(context$banned[[name]])) {
      hits <<- c(hits, name)
      return(invisible(NULL))
    }
    result <- resolve_name(name, shadow)
    if (!isTRUE(result$unresolved)) record(result, "value", name)
    invisible(NULL)
  }
  walk <- function(x, shadow) {
    if (is.symbol(x)) {
      if (!ledgr_hot_path_is_empty(x)) walk_value_symbol(as.character(x), shadow)
      return(invisible(NULL))
    }
    if (!is.call(x)) return(invisible(NULL))
    head_expr <- x[[1L]]
    head <- ledgr_hot_path_head(x)
    if (head %in% not_executed) return(invisible(NULL))
    if (identical(head, "function")) {
      inner <- c(shadow, names(as.list(x[[2L]])))
      for (default in ledgr_hot_path_children(x[[2L]])) walk(default, inner)
      walk(x[[3L]], inner)
      return(invisible(NULL))
    }
    if (head %in% c("$", "@")) {
      walk(x[[2L]], shadow)
      return(invisible(NULL))
    }
    qualified <- ledgr_hot_path_qualified(x)
    if (!is.null(qualified)) {
      record(resolve_value(x, shadow), "value", paste(qualified, collapse = "::"))
      return(invisible(NULL))
    }
    if ((head == "<-" || head == "=" || head == "<<-") && length(x) == 3L) {
      lhs <- x[[2L]]
      rhs <- x[[3L]]
      if (ledgr_hot_path_is_function(rhs) &&
          (is.symbol(lhs) || !is.na(ledgr_hot_path_member_name(lhs)))) {
        return(invisible(NULL))
      }
      # `f <- match` binds an alias; the calls through `f` are what count.
      alias_binding <- is.symbol(lhs) &&
        (is.symbol(rhs) || !is.null(ledgr_hot_path_qualified(rhs)))
      if (!alias_binding) walk(rhs, shadow)
      if (is.call(lhs)) {
        for (part in ledgr_hot_path_children(lhs)[-1L]) if (!is.symbol(part)) walk(part, shadow)
        if (!is.symbol(lhs[[1L]]) || !as.character(lhs[[1L]]) %in% c("$", "[", "[[", "@")) {
          walk(lhs[[1L]], shadow)
        }
      }
      return(invisible(NULL))
    }
    # The call head.
    if (is.symbol(head_expr)) {
      name <- as.character(head_expr)
      record(resolve_name(name, shadow), "call", name)
    } else if (ledgr_hot_path_is_function(head_expr)) {
      walk(head_expr, shadow)
    } else if (!is.null(ledgr_hot_path_qualified(head_expr))) {
      record(resolve_value(head_expr, shadow), "call",
             paste(ledgr_hot_path_qualified(head_expr), collapse = "::"))
    } else {
      member <- ledgr_hot_path_member_name(head_expr)
      if (!is.na(member)) {
        record(resolve_value(head_expr, shadow), "member", member)
      } else if (identical(ledgr_hot_path_head(head_expr), "[[")) {
        add_site("index", paste(deparse(head_expr, width.cutoff = 500L), collapse = " "))
      } else {
        add_site("computed", paste(deparse(head_expr, width.cutoff = 500L), collapse = " "))
      }
      if (is.call(head_expr)) {
        inner_head <- ledgr_hot_path_head(head_expr)
        parts <- if (inner_head %in% c("$", "@")) list(head_expr[[2L]]) else ledgr_hot_path_children(head_expr)[-1L]
        for (part in parts) {
          if (!ledgr_hot_path_is_empty(part) && !is.character(part)) walk(part, shadow)
        }
      }
    }
    args <- as.list(x)[-1L]
    tags <- names(args)
    if (is.null(tags)) tags <- rep("", length(args))
    skip <- integer()
    if (identical(head, "UseMethod") && length(args) >= 1L && is.character(args[[1L]])) {
      edges <<- c(edges, context$methods[[args[[1L]]]])
    }
    if (identical(head, "list")) {
      skip <- which(nzchar(tags) & vapply(args, ledgr_hot_path_is_function, logical(1)))
    }
    spec <- context$apply_args[[head]]
    if (!is.null(spec) && !(head %in% shadow)) {
      at <- which(tags == spec[[1L]])
      if (length(at) == 0L && !is.na(spec[[2L]])) {
        positional <- which(!nzchar(tags))
        if (length(positional) >= spec[[2L]]) at <- positional[[spec[[2L]]]]
      }
      if (length(at) == 1L && !ledgr_hot_path_is_empty(args[[at]])) {
        value <- args[[at]]
        if (!ledgr_hot_path_is_function(value)) {
          label <- if (is.character(value)) value else paste(deparse(value, width.cutoff = 500L), collapse = " ")
          result <- resolve_value(value, shadow)
          record(result, "argument", paste0(head, ":", spec[[1L]], "=", label))
          skip <- c(skip, at)
        }
      }
    }
    for (i in seq_along(args)) {
      if (i %in% skip || ledgr_hot_path_is_empty(args[[i]])) next
      walk(args[[i]], shadow)
    }
    invisible(NULL)
  }
  if (!is.null(fn)) {
    for (default in ledgr_hot_path_children(fn[[2L]])) walk(default, formal_names)
    walk(body, formal_names)
  }
  if (!is.null(node$alias)) record(resolve_value(node$alias, character()), "alias",
                                    paste(deparse(node$alias), collapse = " "))
  list(hits = hits, edges = unique(edges), sites = sites)
}

ledgr_hot_path_locate_loop <- function(nodes, policy) {
  owner <- nodes[[policy$loop_owner]]
  if (is.null(owner) || is.null(owner$fn)) return(list())
  found <- list()
  contains_marker <- function(x) {
    if (!is.call(x)) return(FALSE)
    if (identical(ledgr_hot_path_head(x), policy$loop_marker)) return(TRUE)
    any(vapply(as.list(x), function(child) {
      !ledgr_hot_path_is_empty(child) && contains_marker(child)
    }, logical(1)))
  }
  search <- function(x) {
    if (!is.call(x)) return(invisible(NULL))
    head <- ledgr_hot_path_head(x)
    if (identical(head, "function")) return(invisible(NULL))
    if (identical(head, "for") && contains_marker(x[[4L]])) {
      found[[length(found) + 1L]] <<- x[[4L]]
      return(invisible(NULL))
    }
    for (child in ledgr_hot_path_children(x)[-1L]) search(child)
    invisible(NULL)
  }
  search(owner$fn[[3L]])
  found
}

ledgr_hot_path_scan <- function(root, records, policy = ledgr_hot_path_default_policy()) {
  definitions <- ledgr_hot_path_definitions(root, policy)
  nodes <- definitions$nodes
  keys <- names(nodes)
  # One pass over the nodes; keys are grouped by base name with split().
  base_of <- vapply(nodes, `[[`, character(1), "base")
  kind_of <- vapply(nodes, `[[`, character(1), "kind")
  by_base <- split(keys, base_of)
  top <- keys[kind_of %in% c("top", "alias") & keys == base_of]
  top_keys <- by_base[top]
  local_keys <- keys[kind_of == "local"]
  local_index <- split(local_keys, base_of[local_keys])
  member_keys <- keys[kind_of == "member"]
  member_index <- split(member_keys, sub("^.*[$]", "", base_of[member_keys]))
  # S3 dispatch: UseMethod("g") reaches every package function g.<class>.
  methods <- new.env(hash = TRUE, parent = emptyenv())
  for (name in top[grepl(".", top, fixed = TRUE)]) {
    generic <- sub("[.][^.]*$", "", name)
    while (nzchar(generic)) {
      methods[[generic]] <- c(methods[[generic]], name)
      if (!grepl(".", generic, fixed = TRUE)) break
      generic <- sub("[.][^.]*$", "", generic)
    }
  }
  json <- records$json
  json_counted <- if (is.null(json)) character() else json$identity[json$counted %in% "TRUE"]
  # Hashed environments: every symbol in the package is looked up here.
  context <- list(
    policy = policy,
    top_keys = list2env(top_keys, hash = TRUE, parent = emptyenv()),
    local_index = list2env(local_index, hash = TRUE, parent = emptyenv()),
    member_index = list2env(member_index, hash = TRUE, parent = emptyenv()),
    methods = methods,
    known = ledgr_hot_path_known_externals(root, policy),
    banned = ledgr_hot_path_set(policy$banned),
    imported = list2env(as.list(ledgr_hot_path_imported(root)), hash = TRUE, parent = emptyenv()),
    json_counted = json_counted, apply_args = ledgr_hot_path_apply_args()
  )
  for (pass in 1:2) for (alias in definitions$aliases) {
    value <- alias$value
    targets <- if (is.symbol(value)) {
      name <- as.character(value)
      scope <- alias$scope
      found <- character()
      while (nzchar(scope) && !length(found)) {
        found <- context$local_index[[paste0(scope, "/", name)]]
        scope <- ledgr_hot_path_parent_scope(scope)
      }
      if (!length(found) && !is.null(top_keys[[name]])) found <- top_keys[[name]]
      found
    } else if (!is.na(ledgr_hot_path_member_name(value))) {
      context$member_index[[ledgr_hot_path_member_name(value)]]
    } else {
      qualified <- ledgr_hot_path_qualified(value)
      if (!is.null(qualified) && identical(qualified[[1L]], "ledgr")) top_keys[[qualified[[2L]]]] else character()
    }
    if (length(targets)) {
      context$member_index[[alias$member]] <- unique(c(context$member_index[[alias$member]], targets))
    }
  }
  loops <- ledgr_hot_path_locate_loop(nodes, policy)
  loop_key <- paste0(policy$loop_owner, "/<pulse-loop>")
  if (length(loops) == 1L) {
    nodes[[loop_key]] <- list(
      key = loop_key, base = loop_key, kind = "loop", scope = policy$loop_owner,
      file = nodes[[policy$loop_owner]]$file, alias = NULL,
      fn = call("function", as.pairlist(alist()), loops[[1L]])
    )
  }
  # Nodes are walked on demand: only reached nodes and declared sites.
  memo <- new.env(hash = TRUE, parent = emptyenv())
  scan_of <- function(key) {
    if (is.null(memo[[key]])) memo[[key]] <- ledgr_hot_path_scan_node(nodes[[key]], context)
    memo[[key]]
  }
  list(
    root = root, policy = policy, nodes = nodes, scan_of = scan_of, top = top,
    by_base = by_base,
    loop_count = length(loops), loop_key = loop_key,
    duplicates = table(base_of)[table(base_of) > 1L],
    top_assigned = definitions$top_assigned,
    backend_calls = definitions$backend_calls,
    namespace = ledgr_hot_path_namespace_surface(root)
  )
}

ledgr_hot_path_split <- function(x) {
  if (is.na(x) || !nzchar(x)) return(character())
  trimws(strsplit(x, ";", fixed = TRUE)[[1L]])
}

# Reach the per-pulse graph from the roots, following edges and declared
# targets. Returns the reached nodes with one provenance path each.
ledgr_hot_path_reach <- function(scan, records) {
  policy <- scan$policy
  nodes <- scan$nodes
  surface <- records$surface
  roots <- character()
  if (scan$loop_count == 1L) roots <- c(roots, scan$loop_key)
  bundle <- names(nodes)[startsWith(names(nodes), paste0(policy$bundle_owner, "/")) |
                         startsWith(names(nodes), paste0(policy$bundle_owner, "$"))]
  roots <- c(roots, bundle)
  if (!is.null(surface)) {
    hot <- surface$name[surface$per_pulse %in% "TRUE"]
    roots <- c(roots, unlist(lapply(hot, function(name) {
      scan$by_base[[name]]
    })))
  }
  if (!is.null(records$families)) {
    roots <- c(roots, unlist(lapply(records$families$returned_closures, ledgr_hot_path_split)))
  }
  roots <- unique(roots[roots %in% names(nodes)])
  declared <- list()
  declarations <- records$declarations
  if (!is.null(declarations)) {
    sites <- declarations[declarations$kind == "site", , drop = FALSE]
    for (i in seq_len(nrow(sites))) {
      targets <- setdiff(ledgr_hot_path_split(sites$targets[[i]]), "terminal")
      declared[[sites$node[[i]]]] <- c(declared[[sites$node[[i]]]], targets)
    }
  }
  root_of <- stats::setNames(roots, roots)
  via <- stats::setNames(rep("", length(roots)), roots)
  queue <- roots
  seen <- character()
  while (length(queue)) {
    key <- queue[[1L]]
    queue <- queue[-1L]
    if (key %in% seen) next
    seen <- c(seen, key)
    nexts <- unique(c(scan$scan_of(key)$edges, declared[[key]]))
    nexts <- nexts[nexts %in% names(nodes) & !nexts %in% seen & !nexts %in% names(root_of)]
    root_of[nexts] <- root_of[[key]]
    via[nexts] <- key
    queue <- c(queue, nexts)
  }
  data.frame(
    node = seen,
    file = vapply(seen, function(k) nodes[[k]]$file, character(1)),
    root = unname(root_of[seen]),
    via = unname(via[seen]),
    stringsAsFactors = FALSE
  )
}

ledgr_hot_path_bans <- function(scan, reach) {
  rows <- lapply(reach$node, function(key) {
    hits <- scan$scan_of(key)$hits
    if (!length(hits)) return(NULL)
    counts <- table(hits)
    data.frame(
      node = key, file = scan$nodes[[key]]$file, call = names(counts),
      count = as.integer(counts), stringsAsFactors = FALSE
    )
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (!length(rows)) {
    return(data.frame(node = character(), file = character(), call = character(),
                      count = integer(), stringsAsFactors = FALSE))
  }
  out <- do.call(rbind, rows)
  out <- out[order(out$node, out$call, method = "radix"), , drop = FALSE]
  rownames(out) <- NULL
  out
}

ledgr_hot_path_unresolved <- function(scan, reach) {
  rows <- lapply(reach$node, function(key) {
    sites <- scan$scan_of(key)$sites
    if (!length(sites)) return(NULL)
    data.frame(
      node = key,
      site = vapply(sites, `[[`, character(1), "site"),
      occurrence = vapply(sites, `[[`, integer(1), "occurrence"),
      stringsAsFactors = FALSE
    )
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (!length(rows)) {
    return(data.frame(node = character(), site = character(), occurrence = integer(),
                      stringsAsFactors = FALSE))
  }
  do.call(rbind, rows)
}

ledgr_hot_path_read_table <- function(path, columns) {
  x <- utils::read.csv(path, colClasses = "character", na.strings = character(),
                       encoding = "UTF-8", check.names = FALSE)
  missing <- setdiff(columns, names(x))
  if (length(missing)) {
    stop(sprintf("LEDGR_HOT_PATH_CENSUS_FAILED %s is missing columns: %s.",
                 basename(path), paste(missing, collapse = ", ")), call. = FALSE)
  }
  x[columns]
}

# Read the record set. Inputs are always required; generated records are
# required unless this is the explicit initial seeding.
ledgr_hot_path_read_records <- function(dir, initial = FALSE) {
  files <- ledgr_hot_path_record_files()
  columns <- ledgr_hot_path_columns()
  required <- if (isTRUE(initial)) ledgr_hot_path_input_names() else names(files)
  present <- file.exists(file.path(dir, files))
  missing <- names(files)[!present & names(files) %in% required]
  if (length(missing)) {
    stop(sprintf(
      "LEDGR_HOT_PATH_CENSUS_FAILED missing hot-path records in %s: %s.",
      dir, paste(files[missing], collapse = ", ")
    ), call. = FALSE)
  }
  if (isTRUE(initial) && any(present[!names(files) %in% ledgr_hot_path_input_names()])) {
    stop("LEDGR_HOT_PATH_CENSUS_FAILED initial seeding refuses an existing generated record.",
         call. = FALSE)
  }
  out <- list()
  for (name in names(files)[present]) {
    out[[name]] <- ledgr_hot_path_read_table(file.path(dir, files[[name]]), columns[[name]])
  }
  out$fingerprints <- vapply(ledgr_hot_path_input_names(), function(name) {
    ledgr_hot_path_fingerprint(file.path(dir, files[[name]]))
  }, character(1))
  out
}

ledgr_hot_path_fingerprint <- function(path) {
  text <- gsub("\r", "", paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n"))
  digest::digest(text, algo = "md5", serialize = FALSE)
}

ledgr_hot_path_analyzer_hash <- function(root) {
  lines <- gsub("\r", "", readLines(file.path(root, "tools", "codebase-structure.R"),
                                    warn = FALSE, encoding = "UTF-8"))
  begin <- grep("^## hot-path analyzer begin", lines)
  end <- grep("^## hot-path analyzer end", lines)
  if (length(begin) != 1L || length(end) != 1L || end <= begin) {
    stop("LEDGR_HOT_PATH_CENSUS_FAILED the analyzer markers are missing.", call. = FALSE)
  }
  digest::digest(paste(lines[begin:end], collapse = "\n"), algo = "md5", serialize = FALSE)
}

ledgr_hot_path_policy_rows <- function(scan, records, analyzer_hash, change_reason) {
  policy <- scan$policy
  fingerprints <- records$fingerprints
  if (length(fingerprints)) {
    fingerprints <- stats::setNames(fingerprints, paste0("input_", names(fingerprints)))
  } else {
    fingerprints <- character()
  }
  values <- c(
    analyzer_hash = analyzer_hash,
    banned = paste(policy$banned, collapse = ";"),
    banned_packages = paste(policy$banned_packages, collapse = ";"),
    json_packages = paste(policy$json_packages, collapse = ";"),
    loop_owner = policy$loop_owner,
    loop_marker = policy$loop_marker,
    bundle_owner = policy$bundle_owner,
    known_packages = paste(policy$known_packages, collapse = ";"),
    fingerprints,
    change_reason = change_reason
  )
  data.frame(key = names(values), value = unname(values), stringsAsFactors = FALSE)
}

# Static validity of the inputs against the scan. Returns problem strings.
ledgr_hot_path_problems <- function(scan, records, reach) {
  problems <- character()
  add <- function(...) problems <<- c(problems, sprintf(...))
  nodes <- scan$nodes
  if (scan$loop_count != 1L) {
    add("pulse loop: expected exactly one in %s, found %d", scan$policy$loop_owner, scan$loop_count)
  }
  if (length(scan$namespace$s4)) {
    add("S4 or pattern exports must be classified: %s", paste(scan$namespace$s4, collapse = ", "))
  }
  for (name in names(records)[names(records) %in% names(ledgr_hot_path_columns())]) {
    table <- records[[name]]
    if ("reason" %in% names(table) && any(!nzchar(trimws(table$reason)))) {
      add("%s: blank reason in %d row(s)", name, sum(!nzchar(trimws(table$reason))))
    }
  }
  surface <- records$surface
  if (!is.null(surface)) {
    # paste0() recycles a zero-length vector to one element, so guard each.
    prefixed <- function(prefix, x) if (length(x)) paste0(prefix, x) else character()
    expected <- c(prefixed("export:", scan$namespace$export),
                  prefixed("S3method:", scan$namespace$S3method))
    actual <- paste0(surface$kind, ":", surface$name)
    dup <- unique(actual[duplicated(actual)])
    if (length(dup)) add("surface: duplicate rows: %s", paste(dup, collapse = ", "))
    missing <- setdiff(expected, actual)
    if (length(missing)) add("surface: unclassified: %s", paste(missing, collapse = ", "))
    stale <- setdiff(actual, expected)
    if (length(stale)) add("surface: rows naming nothing: %s", paste(stale, collapse = ", "))
    bad <- !surface$per_pulse %in% c("TRUE", "FALSE")
    if (any(bad)) add("surface: per_pulse must be TRUE or FALSE: %s", paste(surface$name[bad], collapse = ", "))
    hot <- surface[surface$per_pulse %in% "TRUE", , drop = FALSE]
    no_node <- hot$name[!hot$name %in% names(scan$by_base)]
    if (length(no_node)) add("surface: per_pulse rows without a function definition: %s", paste(no_node, collapse = ", "))
    families <- if (is.null(records$families)) character() else records$families$family
    no_family <- hot$name[!hot$family %in% families]
    if (length(no_family)) add("surface: per_pulse rows without a known family: %s", paste(no_family, collapse = ", "))
  }
  families <- records$families
  if (!is.null(families)) {
    dup <- unique(families$family[duplicated(families$family)])
    if (length(dup)) add("families: duplicate rows: %s", paste(dup, collapse = ", "))
    closures <- unlist(lapply(families$returned_closures, ledgr_hot_path_split))
    absent <- setdiff(closures, names(nodes))
    if (length(absent)) add("families: returned closures naming nothing: %s", paste(absent, collapse = ", "))
    blank <- families$family[!nzchar(families$workload) & !nzchar(families$uncovered)]
    if (length(blank)) add("families: neither workload nor uncovered statement: %s", paste(blank, collapse = ", "))
  }
  declarations <- records$declarations
  if (!is.null(declarations)) {
    key <- paste(declarations$kind, declarations$node, declarations$site, declarations$occurrence, sep = "\r")
    if (any(duplicated(key))) add("declarations: duplicate rows: %d", sum(duplicated(key)))
    duplicates <- names(scan$duplicates)
    declared_dup <- declarations$node[declarations$kind == "duplicate"]
    undeclared_dup <- setdiff(duplicates, declared_dup)
    if (length(undeclared_dup)) add("same-key definitions not declared: %s", paste(undeclared_dup, collapse = ", "))
    stale_dup <- setdiff(declared_dup, duplicates)
    if (length(stale_dup)) add("declarations: stale duplicate rows: %s", paste(stale_dup, collapse = ", "))
    sites <- declarations[declarations$kind == "site", , drop = FALSE]
    unresolved <- ledgr_hot_path_unresolved(scan, reach)
    want <- paste(unresolved$node, unresolved$site, unresolved$occurrence, sep = "\r")
    have <- paste(sites$node, sites$site, sites$occurrence, sep = "\r")
    undeclared <- unresolved[!want %in% have, , drop = FALSE]
    if (nrow(undeclared)) {
      add("unresolved callables not declared: %s", paste(sprintf(
        "%s [%s #%d]", undeclared$node, undeclared$site, undeclared$occurrence
      ), collapse = "; "))
    }
    all_sites <- unlist(lapply(intersect(unique(sites$node), names(nodes)), function(k) {
      vapply(scan$scan_of(k)$sites, function(s) paste(k, s$site, s$occurrence, sep = "\r"), character(1))
    }))
    stale <- sites[!have %in% all_sites, , drop = FALSE]
    if (nrow(stale)) {
      add("declarations: stale site rows: %s", paste(sprintf(
        "%s [%s #%s]", stale$node, stale$site, stale$occurrence
      ), collapse = "; "))
    }
    targets <- unlist(lapply(sites$targets, ledgr_hot_path_split))
    absent <- setdiff(targets, c("terminal", names(nodes)))
    if (length(absent)) add("declarations: targets naming nothing: %s", paste(absent, collapse = ", "))
    empty <- sites$node[!nzchar(trimws(sites$targets))]
    if (length(empty)) add("declarations: site rows without targets: %s", paste(empty, collapse = ", "))
  }
  json <- records$json
  if (!is.null(json)) {
    dup <- unique(json$identity[duplicated(json$identity)])
    if (length(dup)) add("json: duplicate rows: %s", paste(dup, collapse = ", "))
    for (i in seq_len(nrow(json))) {
      identity <- json$identity[[i]]
      if (json$role[[i]] %in% c("backend", "option")) {
        parts <- strsplit(identity, "::", fixed = TRUE)[[1L]]
        ok <- length(parts) == 2L && requireNamespace(parts[[1L]], quietly = TRUE) &&
          exists(parts[[2L]], envir = asNamespace(parts[[1L]]), inherits = FALSE)
        if (!ok) add("json: %s is not an installed function", identity)
      } else if (identical(json$role[[i]], "wrapper")) {
        if (!identity %in% names(scan$by_base)) {
          add("json: wrapper %s is not a package function", identity)
        }
      } else {
        add("json: unknown role %s for %s", json$role[[i]], identity)
      }
    }
    # Completeness: every backend function called anywhere, and every
    # top-level package function calling a counted backend directly, is
    # inventoried. The calls were recorded during the definitions pass.
    calls <- scan$backend_calls
    missing <- setdiff(unique(calls$identity), json$identity)
    if (length(missing)) add("json: backend calls not inventoried: %s", paste(missing, collapse = ", "))
    counted <- json$identity[json$counted %in% "TRUE" & json$role == "backend"]
    callers <- unique(calls$owner[calls$identity %in% counted])
    missing_wrappers <- setdiff(callers, json$identity[json$role == "wrapper"])
    if (length(missing_wrappers)) add("json: direct backend callers not inventoried as wrappers: %s", paste(missing_wrappers, collapse = ", "))
  }
  problems
}

# One complete evaluation of the scan against a record set.
ledgr_hot_path_evaluate <- function(root, records, policy = ledgr_hot_path_default_policy()) {
  scan <- ledgr_hot_path_scan(root, records, policy)
  reach <- ledgr_hot_path_reach(scan, records)
  list(
    scan = scan,
    reach = reach,
    bans = ledgr_hot_path_bans(scan, reach),
    unresolved = ledgr_hot_path_unresolved(scan, reach),
    problems = ledgr_hot_path_problems(scan, records, reach)
  )
}

ledgr_hot_path_fail <- function(lines) {
  stop(paste0("LEDGR_HOT_PATH_CENSUS_FAILED ", paste(lines, collapse = "; "), "."),
       call. = FALSE)
}

ledgr_hot_path_row_key <- function(x, columns) {
  if (!nrow(x)) return(character())
  do.call(paste, c(unname(as.list(x[columns])), sep = "\r"))
}

# Check mode: every record must equal the scan exactly.
ledgr_hot_path_check <- function(evaluation, records, analyzer_hash) {
  if (length(evaluation$problems)) ledgr_hot_path_fail(evaluation$problems)
  problems <- character()
  bans <- records$bans
  if (any(duplicated(ledgr_hot_path_row_key(bans, c("node", "call"))))) {
    problems <- c(problems, "bans: duplicate node/call rows")
  }
  found <- ledgr_hot_path_row_key(evaluation$bans, c("node", "call", "count"))
  recorded <- ledgr_hot_path_row_key(bans, c("node", "call", "count"))
  unrecorded <- evaluation$bans[!found %in% recorded, , drop = FALSE]
  stale <- bans[!recorded %in% found, , drop = FALSE]
  if (nrow(unrecorded)) problems <- c(problems, paste0("unrecorded bans: ", paste(sprintf(
    "%s %s x%d", unrecorded$node, unrecorded$call, unrecorded$count), collapse = ", ")))
  if (nrow(stale)) problems <- c(problems, paste0("stale bans (regenerate): ", paste(sprintf(
    "%s %s x%s", stale$node, stale$call, stale$count), collapse = ", ")))
  reach_found <- ledgr_hot_path_row_key(evaluation$reach, c("node", "root", "via"))
  reach_recorded <- ledgr_hot_path_row_key(records$reach, c("node", "root", "via"))
  if (!setequal(reach_found, reach_recorded)) {
    gained <- setdiff(evaluation$reach$node, records$reach$node)
    lost <- setdiff(records$reach$node, evaluation$reach$node)
    problems <- c(problems, sprintf("reach differs (gained %d: %s; lost %d: %s; or provenance changed)",
      length(gained), paste(utils::head(gained, 10L), collapse = ", "),
      length(lost), paste(utils::head(lost, 10L), collapse = ", ")))
  }
  expected_policy <- ledgr_hot_path_policy_rows(evaluation$scan, records, analyzer_hash, "")
  recorded_policy <- stats::setNames(records$policy$value, records$policy$key)
  for (key in setdiff(expected_policy$key, "change_reason")) {
    if (!identical(unname(recorded_policy[key]), expected_policy$value[expected_policy$key == key])) {
      problems <- c(problems, sprintf("policy %s changed since the records were generated", key))
    }
  }
  if (length(problems)) ledgr_hot_path_fail(problems)
  invisible(TRUE)
}

# Report mode: the regenerated generated records, or a refusal.
ledgr_hot_path_regenerate <- function(evaluation, records, analyzer_hash, reason = "",
                                      initial = FALSE) {
  if (length(evaluation$problems)) ledgr_hot_path_fail(evaluation$problems)
  reason <- trimws(reason)
  bans <- evaluation$bans
  needs <- character()
  if (isTRUE(initial)) {
    if (!nzchar(reason)) ledgr_hot_path_fail("initial seeding needs a reason")
    bans$reason <- rep(reason, nrow(bans))
    change_reason <- reason
  } else {
    prior <- records$bans
    prior_key <- ledgr_hot_path_row_key(prior, c("node", "call"))
    key <- ledgr_hot_path_row_key(bans, c("node", "call"))
    prior_count <- stats::setNames(as.integer(prior$count), prior_key)
    prior_reason <- stats::setNames(prior$reason, prior_key)
    grown <- !key %in% prior_key | bans$count > prior_count[key]
    if (any(grown)) needs <- c(needs, sprintf("%d new or increased ban row(s)", sum(grown)))
    lost <- setdiff(records$reach$node, evaluation$reach$node)
    if (length(lost)) needs <- c(needs, sprintf("coverage loss: %s", paste(lost, collapse = ", ")))
    recorded_policy <- stats::setNames(records$policy$value, records$policy$key)
    expected <- ledgr_hot_path_policy_rows(evaluation$scan, records, analyzer_hash, "")
    changed <- expected$key[expected$key != "change_reason" & vapply(expected$key, function(k) {
      !identical(unname(recorded_policy[k]), expected$value[expected$key == k])
    }, logical(1))]
    if (length(changed)) needs <- c(needs, sprintf("input or analyzer change: %s", paste(changed, collapse = ", ")))
    if (length(needs) && !nzchar(reason)) {
      ledgr_hot_path_fail(c("regeneration refused without --hot-path-reason", needs))
    }
    bans$reason <- ifelse(grown, reason, unname(prior_reason[key]))
    change_reason <- if (length(needs)) reason else unname(recorded_policy["change_reason"])
    if (is.na(change_reason)) change_reason <- ""
  }
  list(
    bans = bans[ledgr_hot_path_columns()$bans],
    reach = evaluation$reach,
    policy = ledgr_hot_path_policy_rows(evaluation$scan, records, analyzer_hash, change_reason),
    needs = needs
  )
}

ledgr_hot_path_status <- function(mode, evaluation) {
  sprintf(
    "LEDGR_HOT_PATH_CENSUS mode=%s nodes=%d reached=%d call_sites=%d bans=%d unresolved=%d\n",
    mode, length(evaluation$scan$nodes), nrow(evaluation$reach), nrow(evaluation$bans),
    sum(evaluation$bans$count), nrow(evaluation$unresolved)
  )
}

## hot-path analyzer end ---------------------------------------------------
