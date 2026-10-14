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
