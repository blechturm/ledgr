args <- commandArgs(trailingOnly = TRUE)

value_arg <- function(name, default = NULL) {
  prefix <- paste0("--", name, "=")
  hit <- args[startsWith(args, prefix)]
  if (length(hit) == 0L) return(default)
  sub(prefix, "", hit[[length(hit)]], fixed = TRUE)
}

script_arg <- grep("^--file=", commandArgs(), value = TRUE)
script <- normalizePath(sub("^--file=", "", script_arg[[1L]]), winslash = "/")
default_root <- normalizePath(file.path(dirname(script), ".."), winslash = "/")
root <- normalizePath(value_arg("root", default_root), winslash = "/", mustWork = TRUE)
output_arg <- value_arg(
  "output",
  file.path(root, "dev", "bench", "v0_2_2_pre_cran_removal", "census")
)
output <- normalizePath(output_arg, winslash = "/", mustWork = FALSE)
source_commit <- value_arg("source-commit", "working-tree")
mode <- value_arg("mode", "report")
if (!identical(mode, "report")) {
  stop("LDG-3022 supports only --mode=report.", call. = FALSE)
}

dir.create(output, recursive = TRUE, showWarnings = FALSE)

radix_order <- function(...) order(..., method = "radix", na.last = TRUE)

relative_path <- function(path) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  prefix <- paste0(root, "/")
  ifelse(startsWith(path, prefix), substring(path, nchar(prefix) + 1L), path)
}

source_files <- function(paths) {
  files <- unlist(lapply(paths, function(path) {
    full <- file.path(root, path)
    if (!dir.exists(full)) return(character())
    list.files(full, pattern = "\\.[Rr]$", recursive = TRUE, full.names = TRUE)
  }), use.names = FALSE)
  files[radix_order(relative_path(files))]
}

read_source <- function(path) {
  readLines(path, warn = FALSE, encoding = "UTF-8")
}

parse_source <- function(path) {
  tryCatch(
    parse(path, keep.source = TRUE, encoding = "UTF-8"),
    error = function(e) {
      stop(sprintf("Cannot parse %s: %s", relative_path(path), conditionMessage(e)), call. = FALSE)
    }
  )
}

call_name <- function(x) {
  if (!is.call(x)) return(NA_character_)
  head <- x[[1L]]
  if (is.symbol(head)) return(as.character(head))
  if (is.call(head) && length(head) == 3L &&
      as.character(head[[1L]]) %in% c("::", ":::")) {
    return(as.character(head[[3L]]))
  }
  NA_character_
}

deparse_one <- function(x) {
  paste(deparse(x, width.cutoff = 500L), collapse = " ")
}

top_definitions <- function(path, parsed = parse_source(path)) {
  refs <- attr(parsed, "srcref")
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
      file = relative_path(path),
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

source_index <- function(paths) {
  files <- source_files(paths)
  lapply(files, function(path) {
    parsed <- parse_source(path)
    data <- utils::getParseData(parsed, includeText = TRUE)
    list(
      path = path,
      file = relative_path(path),
      lines = read_source(path),
      parsed = parsed,
      data = data,
      definitions = top_definitions(path, parsed)
    )
  })
}

owner_at <- function(definitions, line) {
  candidates <- Filter(function(x) {
    isTRUE(x$is_function) && !is.na(x$line) && !is.na(x$line_end) &&
      line >= x$line && line <= x$line_end
  }, definitions)
  if (length(candidates) == 0L) return(NA_character_)
  candidates[[which.min(vapply(candidates, function(x) x$line_end - x$line, integer(1)))]]$name
}

definition_text <- function(entry, definition) {
  if (is.na(definition$line) || is.na(definition$line_end)) return("")
  paste(entry$lines[definition$line:definition$line_end], collapse = "\n")
}

write_table <- function(x, name, order_by = names(x)) {
  if (nrow(x) > 0L && length(order_by) > 0L) {
    key <- lapply(x[intersect(order_by, names(x))], function(column) {
      ifelse(is.na(column), "", as.character(column))
    })
    x <- x[do.call(radix_order, key), , drop = FALSE]
  }
  utils::write.csv(
    x,
    file.path(output, name),
    row.names = FALSE,
    na = "",
    fileEncoding = "UTF-8",
    eol = "\n"
  )
  invisible(x)
}

empty_frame <- function(columns) {
  setNames(as.data.frame(rep(list(character()), length(columns))), columns)
}

namespace_lines <- read_source(file.path(root, "NAMESPACE"))
exports <- sub("^export\\(([^)]+)\\)$", "\\1", grep("^export\\(", namespace_lines, value = TRUE))
s3_rows <- grep("^S3method\\(", namespace_lines, value = TRUE)
s3_methods <- vapply(strsplit(sub("^S3method\\((.*)\\)$", "\\1", s3_rows), ",", fixed = TRUE), function(x) {
  paste0(trimws(x[[1L]]), ".", trimws(x[[2L]]))
}, character(1))

r_index <- source_index("R")
test_index <- source_index("tests/testthat")
bench_index <- source_index("dev/bench")
all_index <- c(r_index, test_index, bench_index)

call_rows <- function(index) {
  rows <- vector("list", 0L)
  for (entry in index) {
    calls <- entry$data[entry$data$token == "SYMBOL_FUNCTION_CALL", , drop = FALSE]
    if (nrow(calls) == 0L) next
    for (i in seq_len(nrow(calls))) {
      rows[[length(rows) + 1L]] <- data.frame(
        file = entry$file,
        line = as.integer(calls$line1[[i]]),
        owner = owner_at(entry$definitions, calls$line1[[i]]),
        call = calls$text[[i]],
        stringsAsFactors = FALSE
      )
    }
  }
  if (length(rows) == 0L) return(empty_frame(c("file", "line", "owner", "call")))
  do.call(rbind, rows)
}

r_calls <- call_rows(r_index)
all_calls <- call_rows(all_index)

## Connection census -------------------------------------------------------

connection_names <- c(
  "dbConnect", "ledgr_open_duckdb_with_retry", "ledgr_db_init",
  "ledgr_run_store_open", "get_connection", "ledgr_held_store",
  "ledgr_store_register"
)
connection_rows <- r_calls[r_calls$call %in% connection_names, , drop = FALSE]
if (nrow(connection_rows) > 0L) {
  connection_rows$entry_kind <- unname(c(
    dbConnect = "direct_connect",
    ledgr_open_duckdb_with_retry = "path_opener",
    ledgr_db_init = "public_init",
    ledgr_run_store_open = "run_store_opener",
    get_connection = "cached_or_handle_connection",
    ledgr_held_store = "held_store_borrow",
    ledgr_store_register = "held_store_register"
  )[connection_rows$call])
}

attach_rows <- vector("list", 0L)
for (entry in r_index) {
  hits <- grep("\\bATTACH\\b", entry$lines)
  if (length(hits) == 0L) next
  for (line in hits) {
    attach_rows[[length(attach_rows) + 1L]] <- data.frame(
      file = entry$file,
      line = as.integer(line),
      owner = owner_at(entry$definitions, line),
      call = "ATTACH",
      entry_kind = "attach",
      stringsAsFactors = FALSE
    )
  }
}
if (length(attach_rows) > 0L) {
  connection_rows <- rbind(connection_rows, do.call(rbind, attach_rows))
}

caller_rows <- vector("list", 0L)
for (entry in r_index) {
  for (definition in entry$definitions) {
    if (!isTRUE(definition$is_function) || !"con" %in% definition$formals ||
        !definition$name %in% exports) next
    caller_rows[[length(caller_rows) + 1L]] <- data.frame(
      file = definition$file,
      line = definition$line,
      owner = definition$name,
      call = "con",
      entry_kind = "exported_caller_connection",
      stringsAsFactors = FALSE
    )
  }
}
if (length(caller_rows) > 0L) {
  connection_rows <- rbind(connection_rows, do.call(rbind, caller_rows))
}

if (nrow(connection_rows) > 0L) {
  connection_rows$persistent_store <- TRUE
  connection_rows$classification <- "persistent_ledgr_store"
  connection_rows$current_guard <- "none"
  for (i in seq_len(nrow(connection_rows))) {
    entry <- r_index[[match(connection_rows$file[[i]], vapply(r_index, `[[`, character(1), "file"))]]
    owner <- connection_rows$owner[[i]]
    definition <- Filter(function(x) identical(x$name, owner), entry$definitions)
    context <- if (length(definition) == 1L) definition_text(entry, definition[[1L]]) else entry$lines[[connection_rows$line[[i]]]]
    if (!identical(connection_rows$entry_kind[[i]], "exported_caller_connection") &&
        grepl(":memory:", context, fixed = TRUE)) {
      connection_rows$persistent_store[[i]] <- FALSE
      connection_rows$classification[[i]] <- "in_memory_reference_catalogue"
    } else if (grepl("read_csv|csv", ifelse(is.na(owner), "", owner), ignore.case = TRUE)) {
      connection_rows$persistent_store[[i]] <- FALSE
      connection_rows$classification[[i]] <- "csv_parser"
    }
    guard_names <- c(
      "ledgr_store_open", "ledgr_validate_schema", "ledgr_check_schema",
      "ledgr_create_schema", "ledgr_snapshot_ensure_verified"
    )
    present <- guard_names[vapply(guard_names, grepl, logical(1), x = context, fixed = TRUE)]
    if (length(present) > 0L) connection_rows$current_guard[[i]] <- paste(present, collapse = ";")
  }
  connection_rows <- connection_rows[, c(
    "file", "line", "owner", "entry_kind", "call", "persistent_store",
    "classification", "current_guard"
  )]
} else {
  connection_rows <- empty_frame(c(
    "file", "line", "owner", "entry_kind", "call", "persistent_store",
    "classification", "current_guard"
  ))
}

## Version and convention census ------------------------------------------

fingerprint_names <- c(
  "ledgr_business_objective_schema_version",
  "ledgr_corporate_action_policy_schema_version",
  "ledgr_cost_schema_version",
  "ledgr_experiment_store_schema_version",
  "ledgr_fact_schema_version",
  "ledgr_fold_list_schema_version",
  "ledgr_fold_schema_version",
  "ledgr_identity_rule_version",
  "ledgr_objective_criterion_schema_version",
  "ledgr_risk_schema_version",
  "ledgr_saved_sweep_schema_version",
  "ledgr_selection_rule_schema_version",
  "ledgr_sweep_filter_schema_version",
  "ledgr_sweep_retention_schema_version",
  "ledgr_timing_schema_version",
  "ledgr_valuation_policy_schema_version",
  "ledgr_walk_forward_candidate_schema_version",
  "ledgr_walk_forward_schema_version"
)

version_rows <- vector("list", 0L)
for (entry in r_index) {
  for (definition in entry$definitions) {
    name <- definition$name
    version_like <- grepl("version|_rule_[0-9]+$|_v[0-9]+$", name)
    if (!version_like) next
    rhs <- definition$rhs
    is_atomic_scalar <- is.atomic(rhs) && length(rhs) == 1L
    version_rows[[length(version_rows) + 1L]] <- data.frame(
      file = definition$file,
      line = definition$line,
      owner = name,
      record_kind = "binding",
      expression = deparse_one(definition$expression),
      persisted_or_convention = name %in% fingerprint_names || grepl("schema_version|rule_version", name),
      fingerprint_member = name %in% fingerprint_names,
      atomic_scalar = is_atomic_scalar,
      outside_fingerprint = is_atomic_scalar && !name %in% fingerprint_names,
      stringsAsFactors = FALSE
    )
  }
  comparison_tokens <- entry$data[
    entry$data$token %in% c("EQ", "NE", "GT", "GE", "LT", "LE", "SPECIAL") |
      (entry$data$token == "SYMBOL_FUNCTION_CALL" & entry$data$text == "identical"),
    , drop = FALSE
  ]
  candidate_lines <- unique(comparison_tokens$line1)
  candidate_lines <- candidate_lines[candidate_lines >= 1L & candidate_lines <= length(entry$lines)]
  for (line in candidate_lines) {
    from <- max(1L, line - 2L)
    to <- min(length(entry$lines), line + 2L)
    expression <- paste(entry$lines[from:to], collapse = " ")
    if (!grepl("version|schema|rule_[0-9]+|_v[0-9]+", expression)) next
    version_rows[[length(version_rows) + 1L]] <- data.frame(
      file = entry$file,
      line = as.integer(line),
      owner = owner_at(entry$definitions, line),
      record_kind = "read_branch_or_equality",
      expression = trimws(expression),
      persisted_or_convention = TRUE,
      fingerprint_member = FALSE,
      atomic_scalar = FALSE,
      outside_fingerprint = FALSE,
      stringsAsFactors = FALSE
    )
  }
}
if (length(version_rows) == 0L) {
  version_rows <- empty_frame(c(
    "file", "line", "owner", "record_kind", "expression",
    "persisted_or_convention", "fingerprint_member", "atomic_scalar",
    "outside_fingerprint"
  ))
} else {
  version_rows <- do.call(rbind, version_rows)
  version_rows <- unique(version_rows)
}

## Hand-built run-config census -------------------------------------------

child_nodes <- function(x) {
  positions <- seq_along(x)
  positions <- positions[vapply(positions, function(i) {
    !identical(as.character(x[i]), "")
  }, logical(1))]
  lapply(positions, function(i) x[[i]])
}

call_has_name <- function(x, target) {
  if (is.call(x)) {
    if (target %in% names(x)) return(TRUE)
    nodes <- child_nodes(x)[-1L]
    return(any(vapply(nodes, call_has_name, logical(1), target = target)))
  }
  if (is.pairlist(x) || is.expression(x) || is.list(x)) {
    return(any(vapply(child_nodes(x), call_has_name, logical(1), target = target)))
  }
  FALSE
}

collect_named_calls <- function(x, target, out = list()) {
  if (is.call(x) && identical(call_name(x), target)) out[[length(out) + 1L]] <- x
  if (is.call(x) || is.pairlist(x) || is.expression(x) || is.list(x)) {
    for (child in child_nodes(x)) out <- collect_named_calls(child, target, out)
  }
  out
}

run_config_rows <- vector("list", 0L)
for (entry in c(test_index, bench_index)) {
  calls <- collect_named_calls(entry$parsed, "ledgr_run_config")
  call_lines <- entry$data$line1[
    entry$data$token == "SYMBOL_FUNCTION_CALL" & entry$data$text == "ledgr_run_config"
  ]
  for (i in seq_along(calls)) {
    call <- calls[[i]]
    line <- if (i <= length(call_lines)) as.integer(call_lines[[i]]) else NA_integer_
    run_config_rows[[length(run_config_rows) + 1L]] <- data.frame(
      file = entry$file,
      line = line,
      owner = owner_at(entry$definitions, line),
      identity_rule_version = call_has_name(call, "identity_rule_version"),
      data_snapshot_hash = call_has_name(call, "snapshot_hash"),
      expression = deparse_one(call),
      stringsAsFactors = FALSE
    )
  }
}
if (length(run_config_rows) == 0L) {
  run_config_rows <- empty_frame(c(
    "file", "line", "owner", "identity_rule_version", "data_snapshot_hash",
    "expression"
  ))
} else {
  run_config_rows <- do.call(rbind, run_config_rows)
}

## Private-helper census ---------------------------------------------------

build_symbol_map <- function(index) {
  rows <- vector("list", 0L)
  for (entry in index) {
    hits <- entry$data[
      entry$data$token %in% c("SYMBOL", "SYMBOL_FUNCTION_CALL"),
      , drop = FALSE
    ]
    if (nrow(hits) == 0L) next
    rows[[length(rows) + 1L]] <- data.frame(
      name = hits$text,
      file = entry$file,
      line = as.integer(hits$line1),
      stringsAsFactors = FALSE
    )
  }
  if (length(rows) == 0L) return(list())
  rows <- unique(do.call(rbind, rows))
  split(rows[, c("file", "line"), drop = FALSE], rows$name)
}

build_dynamic_map <- function(index) {
  rows <- vector("list", 0L)
  dispatch <- c("get", "get0", "mget", "match.fun", "do.call", "exists", "assign")
  for (entry in index) {
    calls <- entry$data[
      entry$data$token == "SYMBOL_FUNCTION_CALL" & entry$data$text %in% dispatch,
      , drop = FALSE
    ]
    if (nrow(calls) == 0L) next
    for (line in unique(calls$line1)) {
      from <- max(1L, line)
      to <- min(length(entry$lines), line + 3L)
      text <- paste(entry$lines[from:to], collapse = " ")
      matches <- regmatches(
        text,
        gregexpr("['\"][.]?[A-Za-z][A-Za-z0-9_.]*['\"]", text, perl = TRUE)
      )[[1L]]
      if (identical(matches, character(0)) || identical(matches, "")) next
      names_found <- substring(matches, 2L, nchar(matches) - 1L)
      for (name in unique(names_found)) {
        rows[[length(rows) + 1L]] <- data.frame(
          name = name,
          file = entry$file,
          line = as.integer(line),
          stringsAsFactors = FALSE
        )
      }
    }
  }
  if (length(rows) == 0L) return(list())
  rows <- unique(do.call(rbind, rows))
  split(rows[, c("file", "line"), drop = FALSE], rows$name)
}

r_symbol_map <- build_symbol_map(r_index)
test_symbol_map <- build_symbol_map(test_index)
r_dynamic_map <- build_dynamic_map(r_index)
test_dynamic_map <- build_dynamic_map(test_index)
empty_locations <- empty_frame(c("file", "line"))

locations_for <- function(map, name) {
  value <- map[[name]]
  if (is.null(value)) empty_locations else value
}

helper_rows <- vector("list", 0L)
with_reference_kind <- function(x, kind) {
  x$reference_kind <- rep(kind, nrow(x))
  x
}
for (entry in r_index) {
  for (definition in entry$definitions) {
    if (!isTRUE(definition$is_function)) next
    name <- definition$name
    r_refs <- locations_for(r_symbol_map, name)
    r_refs <- r_refs[!(r_refs$file == definition$file & r_refs$line == definition$line), , drop = FALSE]
    test_refs <- locations_for(test_symbol_map, name)
    r_dynamic <- locations_for(r_dynamic_map, name)
    test_dynamic <- locations_for(test_dynamic_map, name)
    is_export <- name %in% exports
    is_s3 <- name %in% s3_methods
    is_hook <- name %in% c(".onLoad", ".onAttach", ".onUnload")
    locations <- rbind(
      with_reference_kind(r_refs, "R_static"),
      with_reference_kind(test_refs, "test_static"),
      with_reference_kind(r_dynamic, "R_string_dispatch"),
      with_reference_kind(test_dynamic, "test_string_dispatch")
    )
    locations_text <- if (nrow(locations) == 0L) "" else paste(
      sprintf("%s:%d:%s", locations$file, locations$line, locations$reference_kind),
      collapse = ";"
    )
    helper_rows[[length(helper_rows) + 1L]] <- data.frame(
      file = definition$file,
      line = definition$line,
      helper = name,
      exported = is_export,
      s3_method = is_s3,
      hook = is_hook,
      in_scope_private = !is_export && !is_s3 && !is_hook,
      r_reference_count = nrow(r_refs),
      test_reference_count = nrow(test_refs),
      dynamic_reference_count = nrow(r_dynamic) + nrow(test_dynamic),
      reference_locations = locations_text,
      classification = if (is_export) {
        "export"
      } else if (is_s3) {
        "s3_method"
      } else if (is_hook) {
        "hook"
      } else if (nrow(r_refs) > 0L || nrow(r_dynamic) > 0L) {
        "R_referenced_private"
      } else if (nrow(test_refs) > 0L || nrow(test_dynamic) > 0L) {
        "test_only_private"
      } else {
        "uncalled_private"
      },
      stringsAsFactors = FALSE
    )
  }
}
if (length(helper_rows) == 0L) {
  helper_rows <- empty_frame(c(
    "file", "line", "helper", "exported", "s3_method", "hook",
    "in_scope_private", "r_reference_count", "test_reference_count",
    "dynamic_reference_count", "reference_locations", "classification"
  ))
} else {
  helper_rows <- do.call(rbind, helper_rows)
}

## Condition census --------------------------------------------------------

condition_reference <- read_source(file.path(root, "R", "condition-reference.R"))
alias_lines <- grep("^#' @aliases ", condition_reference, value = TRUE)
documented_aliases <- unique(unlist(strsplit(sub("^#' @aliases ", "", alias_lines), "[[:space:]]+")))
prose <- condition_reference[grepl("^#'", condition_reference) & !grepl("^#' @aliases ", condition_reference)]

literal_strings <- function(x) {
  if (is.character(x)) return(x)
  if (is.call(x) && identical(call_name(x), "c")) {
    values <- unlist(lapply(as.list(x)[-1L], literal_strings), use.names = FALSE)
    if (length(values) == length(x) - 1L) return(values)
  }
  character()
}

abort_calls <- vector("list", 0L)
walk_conditions <- function(x, file) {
  if (is.call(x)) {
    leaf <- call_name(x)
    if (leaf %in% c("abort", "stop", "warning", "warn")) {
      abort_calls[[length(abort_calls) + 1L]] <<- list(file = file, leaf = leaf, call = x)
    }
  }
  if (is.call(x) || is.pairlist(x) || is.expression(x) || is.list(x)) {
    for (child in child_nodes(x)) walk_conditions(child, file)
  }
  invisible(NULL)
}
for (entry in r_index) walk_conditions(entry$parsed, entry$file)

condition_line_queues <- lapply(r_index, function(entry) {
  keep <- entry$data$token == "SYMBOL_FUNCTION_CALL" &
    entry$data$text %in% c("abort", "stop", "warning", "warn")
  data.frame(
    file = rep(entry$file, sum(keep)),
    leaf = entry$data$text[keep],
    line = entry$data$line1[keep],
    stringsAsFactors = FALSE
  )
})
condition_line_queues <- do.call(rbind, condition_line_queues)
queue_position <- integer(nrow(condition_line_queues))
condition_rows <- vector("list", 0L)
for (item in abort_calls) {
  candidates <- which(
    condition_line_queues$file == item$file &
      condition_line_queues$leaf == item$leaf &
      queue_position == 0L
  )
  line <- if (length(candidates) == 0L) NA_integer_ else condition_line_queues$line[[candidates[[1L]]]]
  if (length(candidates) > 0L) queue_position[[candidates[[1L]]]] <- 1L
  call <- item$call
  named <- names(as.list(call))
  class_index <- which(named == "class")
  classes <- if (length(class_index) == 1L) literal_strings(call[[class_index]]) else character()
  if (identical(item$leaf, "abort") && length(classes) > 0L) {
    for (class in classes) {
      condition_rows[[length(condition_rows) + 1L]] <- data.frame(
        file = item$file,
        line = line,
        call_kind = "abort_class",
        condition_class = class,
        recoverable = TRUE,
        expression = deparse_one(call[[class_index]]),
        documented_alias = class %in% documented_aliases,
        documented_description = any(grepl(class, prose, fixed = TRUE)),
        internal_prefix = startsWith(class, "ledgr_internal_"),
        stringsAsFactors = FALSE
      )
    }
  } else {
    condition_rows[[length(condition_rows) + 1L]] <- data.frame(
      file = item$file,
      line = line,
      call_kind = if (identical(item$leaf, "abort")) "abort_dynamic" else item$leaf,
      condition_class = "",
      recoverable = FALSE,
      expression = if (length(class_index) == 1L) deparse_one(call[[class_index]]) else deparse_one(call),
      documented_alias = FALSE,
      documented_description = FALSE,
      internal_prefix = FALSE,
      stringsAsFactors = FALSE
    )
  }
}
if (length(condition_rows) == 0L) {
  condition_rows <- empty_frame(c(
    "file", "line", "call_kind", "condition_class", "recoverable",
    "expression", "documented_alias", "documented_description",
    "internal_prefix"
  ))
} else {
  condition_rows <- do.call(rbind, condition_rows)
}

condition_class_rows <- condition_rows[
  condition_rows$call_kind == "abort_class",
  , drop = FALSE
]
if (nrow(condition_class_rows) > 0L) {
  condition_class_rows <- condition_class_rows[
    radix_order(condition_class_rows$condition_class, condition_class_rows$file,
                condition_class_rows$line),
    , drop = FALSE
  ]
  groups <- split(condition_class_rows, condition_class_rows$condition_class)
  condition_classes <- do.call(rbind, lapply(groups, function(group) {
    first <- group[1L, , drop = FALSE]
    is_public <- startsWith(first$condition_class, "ledgr_") &&
      !startsWith(first$condition_class, "ledgr_internal_")
    data.frame(
      condition_class = first$condition_class,
      first_file = first$file,
      first_line = first$line,
      occurrence_count = nrow(group),
      public = is_public,
      internal_prefix = first$internal_prefix,
      documented_alias = first$documented_alias,
      documented_description = first$documented_description,
      classification = if (first$internal_prefix) {
        "internal"
      } else if (!startsWith(first$condition_class, "ledgr_")) {
        "non_public_label"
      } else if (first$documented_alias && first$documented_description) {
        "documented_public"
      } else if (first$documented_alias) {
        "public_alias_only"
      } else if (first$documented_description) {
        "public_description_only"
      } else {
        "undocumented_public"
      },
      stringsAsFactors = FALSE
    )
  }))
  rownames(condition_classes) <- NULL
} else {
  condition_classes <- empty_frame(c(
    "condition_class", "first_file", "first_line", "occurrence_count",
    "public", "internal_prefix", "documented_alias",
    "documented_description", "classification"
  ))
}

## Records -----------------------------------------------------------------

connection_rows <- write_table(connection_rows, "connections.csv", c("file", "line", "entry_kind"))
version_rows <- write_table(version_rows, "versions.csv", c("file", "line", "record_kind", "owner"))
run_config_rows <- write_table(run_config_rows, "run_configs.csv", c("file", "line"))
helper_rows <- write_table(helper_rows, "helpers.csv", c("file", "line", "helper"))
condition_rows <- write_table(condition_rows, "conditions.csv", c("file", "line", "call_kind", "condition_class"))
condition_classes <- write_table(
  condition_classes,
  "condition_classes.csv",
  c("condition_class", "first_file", "first_line")
)

summary <- data.frame(
  family = c(
    "condition_call_sites", "condition_classes", "connections", "helpers",
    "run_configs", "versions"
  ),
  rows = c(
    nrow(condition_rows), nrow(condition_classes), nrow(connection_rows),
    nrow(helper_rows), nrow(run_config_rows), nrow(version_rows)
  ),
  findings = c(
    sum(condition_rows$call_kind != "abort_class"),
    sum(condition_classes$public &
          (!condition_classes$documented_alias |
             !condition_classes$documented_description)),
    sum(connection_rows$persistent_store & connection_rows$current_guard == "none"),
    sum(helper_rows$classification == "uncalled_private"),
    sum(!run_config_rows$identity_rule_version | !run_config_rows$data_snapshot_hash),
    sum(version_rows$outside_fingerprint)
  ),
  stringsAsFactors = FALSE
)
summary <- write_table(summary, "summary.csv", "family")

metadata <- data.frame(
  key = c("mode", "source_commit", "root", "fingerprint_members"),
  value = c(mode, source_commit, ".", as.character(length(fingerprint_names))),
  stringsAsFactors = FALSE
)
write_table(metadata, "metadata.csv", "key")

cat(sprintf(
  paste0(
    "LEDGR_CODEBASE_CENSUS_OK mode=%s connections=%d versions=%d ",
    "run_configs=%d helpers=%d conditions=%d findings=%d\n"
  ),
  mode,
  nrow(connection_rows),
  nrow(version_rows),
  nrow(run_config_rows),
  nrow(helper_rows),
  nrow(condition_rows),
  sum(summary$findings)
))
