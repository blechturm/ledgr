ledgr_census_bind_rows <- function(rows, columns) {
  if (length(rows) == 0L) {
    return(as.data.frame(
      stats::setNames(rep(list(character()), length(columns)), columns),
      stringsAsFactors = FALSE
    ))
  }
  do.call(rbind, rows)
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

ledgr_structure_condition_classes <- function(expressions, functions) {
  found <- character()
  walk <- function(x) {
    if (!is.call(x) && !is.expression(x) && !is.pairlist(x) && !is.list(x)) {
      return(invisible(NULL))
    }
    if (is.call(x)) {
      name <- ledgr_structure_call_name(x[[1L]])
      fields <- names(x)
      class_at <- which(fields == "class")
      if (
        length(class_at) == 1L &&
          grepl("(^|::)(abort|warn)$", name, perl = TRUE)
      ) {
        class_expression <- x[[class_at]]
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

  list(
    helpers = helpers,
    private_helpers = sort(private, method = "radix"),
    orphan_helpers = sort(private[counts < 2L], method = "radix"),
    direct_condition_classes = ledgr_structure_condition_classes(
      r_parsed,
      function_definitions
    )
  )
}
