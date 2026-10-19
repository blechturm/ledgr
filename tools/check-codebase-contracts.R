args <- commandArgs(trailingOnly = TRUE)

current_only_specs <- list(
  list(
    pattern = "identity_rule_version",
    bindings = "ledgr_identity_rule_version"
  ),
  list(
    pattern = "corporate_schema|(?<!valuation_)policy_schema_version",
    bindings = c(
      "ledgr_corporate_action_policy_schema_version",
      "ledgr_history_policy_schema_version"
    )
  ),
  list(
    pattern = "valuation_policy_record_version|valuation_schema",
    bindings = "ledgr_valuation_policy_schema_version"
  ),
  list(
    pattern = "retention_schema_version",
    bindings = "ledgr_sweep_retention_schema_version"
  ),
  list(
    pattern = "sweep_schema_version",
    bindings = "ledgr_saved_sweep_schema_version"
  ),
  list(
    pattern = "hash_rule_version|snapshot_hash_rule",
    bindings = "ledgr_snapshot_content_hash_rule_version"
  ),
  list(
    pattern = "execution_timing_version",
    bindings = "ledgr_availability_execution_timing_rule_version"
  ),
  list(
    pattern = "metric_context_version",
    bindings = "ledgr_metric_context_version"
  )
)

current_only_comparison_violation <- function(expression,
                                              operator,
                                              owner = NA_character_) {
  if (identical(owner, "ledgr_store_assert_current") &&
      grepl("schema_state.*schema_version", expression, perl = TRUE) &&
      grepl("ledgr_experiment_store_schema_version", expression, fixed = TRUE)) {
    return(FALSE)
  }
  specs <- current_only_specs[vapply(current_only_specs, function(spec) {
    grepl(spec$pattern, expression, perl = TRUE)
  }, logical(1))]
  if (identical(owner, "ledgr_parse_promotion_context") &&
      grepl("version|ledgr_promotion_v[0-9]+", expression, perl = TRUE)) {
    specs[[length(specs) + 1L]] <- list(
      pattern = "promotion_context_version",
      bindings = "ledgr_promotion_context_version"
    )
  }
  if (length(specs) == 0L) return(FALSE)
  equality <- operator %in% c("==", "!=", "identical")
  has_current_binding <- all(vapply(specs, function(spec) {
    any(vapply(spec$bindings, function(binding) {
      grepl(binding, expression, fixed = TRUE)
    }, logical(1)))
  }, logical(1)))
  !equality || !has_current_binding
}

current_only_literal_rows <- function(root) {
  files <- list.files(
    file.path(root, "R"),
    pattern = "[.]R$",
    full.names = TRUE
  )
  rows <- lapply(files, function(file) {
    lines <- readLines(file, warn = FALSE)
    hits <- grep("availability_close_v1", lines, fixed = TRUE)
    if (length(hits) == 0L) return(NULL)
    data.frame(
      file = file.path("R", basename(file)),
      line = as.integer(hits),
      owner = NA_character_,
      record_kind = "retired_literal",
      expression = trimws(lines[hits]),
      persisted_or_convention = TRUE,
      persistence_evidence = "literal_guard",
      fingerprint_member = FALSE,
      atomic_scalar = FALSE,
      outside_fingerprint = FALSE,
      comparison_operator = "literal",
      equality_assertion = FALSE,
      stringsAsFactors = FALSE
    )
  })
  rows <- Filter(Negate(is.null), rows)
  if (length(rows) == 0L) return(NULL)
  do.call(rbind, rows)
}

if ("--self-test-current-only" %in% args) {
  cases <- data.frame(
    expression = c(
      "identical(x$identity_rule_version, ledgr_identity_rule_version)",
      "identical(x$identity_rule_version, 1L)",
      "is.null(x$identity_rule_version)",
      "x$sweep_schema_version %in% 1:3",
      "identical(version, 'ledgr_promotion_v1')",
      "identical(history$policy_schema_version, ledgr_history_policy_schema_version)",
      "schema_state$schema_version < ledgr_experiment_store_schema_version"
    ),
    operator = c(
      "identical", "identical", "is.null", "%in%", "identical",
      "identical", "<"
    ),
    owner = c(
      NA, NA, NA, NA, "ledgr_parse_promotion_context", NA,
      "ledgr_store_assert_current"
    ),
    expected = c(FALSE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE),
    stringsAsFactors = FALSE
  )
  actual <- mapply(
    current_only_comparison_violation,
    cases$expression,
    cases$operator,
    cases$owner,
    USE.NAMES = FALSE
  )
  if (!identical(actual, cases$expected)) {
    stop("LEDGR_CURRENT_ONLY_SELF_TEST_FAILED", call. = FALSE)
  }
  probe <- tempfile("ledgr-current-only-source-")
  dir.create(file.path(probe, "R"), recursive = TRUE)
  on.exit(unlink(probe, recursive = TRUE), add = TRUE)
  writeLines(
    "if (identical(timing, 'availability_close_v1')) timing <- timing",
    file.path(probe, "R", "legacy.R"),
    useBytes = TRUE
  )
  literal_rows <- current_only_literal_rows(probe)
  if (is.null(literal_rows) || nrow(literal_rows) != 1L ||
      !identical(literal_rows$file[[1L]], "R/legacy.R") ||
      !identical(literal_rows$record_kind[[1L]], "retired_literal")) {
    stop("LEDGR_CURRENT_ONLY_SELF_TEST_FAILED", call. = FALSE)
  }
  cat("LEDGR_CURRENT_ONLY_SELF_TEST_OK\n")
  quit(save = "no", status = 0L)
}

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
structure_path <- file.path(root, "tools", "codebase-structure.R")
if (!file.exists(structure_path)) {
  stop("The shared codebase-structure scanner is missing.", call. = FALSE)
}
source(structure_path, local = TRUE)
if (!mode %in% c("report", "check")) {
  stop("`--mode` must be report or check.", call. = FALSE)
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

child_nodes <- function(x) {
  if (is.pairlist(x)) return(list())
  if (!(is.call(x) || is.expression(x) || is.list(x))) {
    return(list())
  }
  positions <- seq_along(x)
  keep <- vapply(positions, function(i) {
    nzchar(paste(deparse(x[[i]]), collapse = ""))
  }, logical(1))
  lapply(positions[keep], function(i) x[[i]])
}

literal_strings <- function(x) {
  if (is.character(x)) return(as.character(x))
  if (is.call(x) && identical(call_name(x), "c")) {
    return(unlist(lapply(as.list(x)[-1L], literal_strings), use.names = FALSE))
  }
  character()
}

ast_nodes <- function(x) {
  out <- vector("list", 0L)
  ordinal <- 0L
  walk <- function(node) {
    ordinal <<- ordinal + 1L
    here <- ordinal
    if (is.call(node)) {
      name <- call_name(node)
      kind <- if (!is.na(name) && name %in% c("<-", "=") &&
                    length(node) >= 3L && is.symbol(node[[2L]])) {
        "assignment"
      } else {
        "call"
      }
      out[[length(out) + 1L]] <<- list(
        ordinal = here,
        kind = kind,
        name = if (kind == "assignment") as.character(node[[2L]]) else name,
        node = node
      )
    }
    for (child in child_nodes(node)) walk(child)
  }
  walk(x)
  out
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
      definitions = top_definitions(path, parsed),
      nodes = ast_nodes(parsed)
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
  ledgr_census_empty_frame(stats::setNames(
    rep("character", length(columns)), columns
  ))
}

census_schemas <- ledgr_census_schemas()

namespace_calls <- as.list(parse(file.path(root, "NAMESPACE"), keep.source = FALSE))
exports <- unique(vapply(Filter(function(x) identical(call_name(x), "export"), namespace_calls), function(x) {
  as.character(x[[2L]])
}, character(1)))
s3_methods <- unique(vapply(Filter(function(x) identical(call_name(x), "S3method"), namespace_calls), function(x) {
  generic <- if (is.character(x[[2L]])) x[[2L]] else as.character(x[[2L]])
  method <- if (is.character(x[[3L]])) x[[3L]] else as.character(x[[3L]])
  paste0(generic, ".", method)
}, character(1)))

r_index <- source_index("R")
test_index <- source_index("tests/testthat")
bench_index <- source_index("dev/bench")
all_index <- c(r_index, test_index, bench_index)

call_rows <- function(index) {
  rows <- vector("list", 0L)
  for (entry in index) {
    calls <- entry$data[entry$data$token == "SYMBOL_FUNCTION_CALL", , drop = FALSE]
    if (nrow(calls) == 0L) next
    rows[[length(rows) + 1L]] <- data.frame(
      file = rep(entry$file, nrow(calls)),
      line = as.integer(calls$line1),
      owner = vapply(calls$line1, function(line) {
        owner_at(entry$definitions, line)
      }, character(1)),
      call = calls$text,
      stringsAsFactors = FALSE
    )
  }
  if (length(rows) == 0L) return(empty_frame(c("file", "line", "owner", "call")))
  do.call(rbind, rows)
}

r_calls <- call_rows(r_index)

## Connection census -------------------------------------------------------

connection_names <- c(
  "dbConnect", "ledgr_open_duckdb_with_retry", "ledgr_db_init",
  "ledgr_run_store_open", "get_connection", "ledgr_held_store",
  "ledgr_store_register", "ledgr_snapshot_connection",
  "ledgr_backtest_open"
)

call_occurrences <- function(entry, targets) {
  nodes <- Filter(function(x) {
    identical(x$kind, "call") && !is.na(x$name) && x$name %in% targets
  }, entry$nodes)
  if (length(nodes) == 0L) return(list())
  token_rows <- entry$data[
    entry$data$token == "SYMBOL_FUNCTION_CALL" & entry$data$text %in% targets,
    c("text", "line1"), drop = FALSE
  ]
  line_queues <- split(as.integer(token_rows$line1), token_rows$text)
  positions <- setNames(integer(length(line_queues)), names(line_queues))
  lapply(nodes, function(item) {
    name <- item$name
    positions[[name]] <<- positions[[name]] + 1L
    lines <- line_queues[[name]]
    line <- if (is.null(lines) || positions[[name]] > length(lines)) {
      NA_integer_
    } else {
      lines[[positions[[name]]]]
    }
    list(
      file = entry$file,
      line = line,
      owner = owner_at(entry$definitions, line),
      name = name,
      call = item$node,
      ordinal = item$ordinal
    )
  })
}

call_argument <- function(call, name = NULL, position = NULL) {
  args <- as.list(call)[-1L]
  tags <- names(args)
  if (is.null(tags)) tags <- rep("", length(args))
  if (!is.null(name)) {
    hit <- which(tags == name)
    if (length(hit) > 0L) return(args[[hit[[1L]]]])
  }
  if (!is.null(position)) {
    positional <- which(!nzchar(tags))
    if (length(positional) >= position) return(args[[positional[[position]]]])
  }
  NULL
}

is_memory_literal <- function(x) {
  is.character(x) && length(x) == 1L && identical(x, ":memory:")
}

duckdb_driver_is_memory <- function(x) {
  if (!is.call(x) || !identical(call_name(x), "duckdb")) return(FALSE)
  dbdir <- call_argument(x, "dbdir")
  if (is.null(dbdir)) return(TRUE)
  is_memory_literal(dbdir)
}

connection_is_memory <- function(name, call) {
  if (identical(name, "dbConnect")) {
    dbdir <- call_argument(call, "dbdir", 2L)
    if (!is.null(dbdir)) return(is_memory_literal(dbdir))
    driver <- call_argument(call, position = 1L)
    return(duckdb_driver_is_memory(driver))
  }
  args <- as.list(call)[-1L]
  any(vapply(args, is_memory_literal, logical(1)))
}

connection_items <- unlist(lapply(r_index, call_occurrences,
                                  targets = connection_names), recursive = FALSE)
connection_rows <- if (length(connection_items) == 0L) {
  data.frame(
    file = character(), line = integer(), owner = character(),
    entry_kind = character(), call = character(), persistent_store = logical(),
    classification = character(), current_guard = character(),
    stringsAsFactors = FALSE
  )
} else {
  do.call(rbind, lapply(connection_items, function(item) {
    memory <- connection_is_memory(item$name, item$call)
    data.frame(
      file = item$file,
      line = item$line,
      owner = item$owner,
      entry_kind = unname(c(
        dbConnect = "direct_connect",
        ledgr_open_duckdb_with_retry = "path_opener",
        ledgr_db_init = "public_init",
        ledgr_run_store_open = "run_store_opener",
        get_connection = "cached_or_handle_connection",
        ledgr_held_store = "held_store_borrow",
        ledgr_store_register = "held_store_register",
        ledgr_snapshot_connection = "cached_or_handle_connection",
        ledgr_backtest_open = "cached_or_handle_connection"
      )[[item$name]]),
      call = item$name,
      persistent_store = !memory,
      classification = if (memory) {
        "in_memory_reference_catalogue"
      } else {
        "persistent_ledgr_store"
      },
      current_guard = "none",
      stringsAsFactors = FALSE
    )
  }))
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
  attached <- do.call(rbind, attach_rows)
  attached$persistent_store <- TRUE
  attached$classification <- "persistent_ledgr_store"
  attached$current_guard <- "none"
  connection_rows <- rbind(connection_rows, attached[, names(connection_rows)])
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
  supplied <- do.call(rbind, caller_rows)
  supplied$persistent_store <- TRUE
  supplied$classification <- "persistent_ledgr_store"
  supplied$current_guard <- "none"
  connection_rows <- rbind(connection_rows, supplied[, names(connection_rows)])
}

guard_names <- c(
  "ledgr_store_open", "ledgr_store_assert_current",
  "ledgr_validate_schema", "ledgr_check_schema",
  "ledgr_create_schema", "ledgr_snapshot_ensure_verified"
)
calls_by_owner <- split(r_calls$call[!is.na(r_calls$owner)],
                        r_calls$owner[!is.na(r_calls$owner)])
guard_cache <- new.env(parent = emptyenv())
reachable_guards <- function(owner, seen = character()) {
  if (is.na(owner) || !nzchar(owner) || owner %in% seen) return(character())
  cached <- guard_cache[[owner]]
  if (!is.null(cached)) return(cached)
  direct <- unique(as.character(calls_by_owner[[owner]]))
  direct <- direct[!is.na(direct)]
  found <- intersect(direct, guard_names)
  callees <- setdiff(direct, c(guard_names, seen, owner))
  nested <- unlist(lapply(callees, reachable_guards,
                          seen = c(seen, owner)), use.names = FALSE)
  answer <- sort(unique(c(found, nested)), method = "radix")
  guard_cache[[owner]] <- answer
  answer
}

if (nrow(connection_rows) > 0L) {
  for (i in seq_len(nrow(connection_rows))) {
    owner <- connection_rows$owner[[i]]
    present <- reachable_guards(owner)
    if (length(present) > 0L) {
      connection_rows$current_guard[[i]] <- paste(present, collapse = ";")
    }
  }
}

## Version and convention census ------------------------------------------

fingerprint_names <- c(
  "ledgr_availability_execution_timing_rule_version",
  "ledgr_business_objective_schema_version",
  "ledgr_canonical_json_rule_version",
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
  "ledgr_snapshot_content_hash_rule_version",
  "ledgr_sweep_filter_schema_version",
  "ledgr_sweep_retention_schema_version",
  "ledgr_timing_schema_version",
  "ledgr_universe_rule_schema_version",
  "ledgr_valuation_policy_schema_version",
  "ledgr_walk_forward_candidate_schema_version",
  "ledgr_walk_forward_schema_version"
)

version_rows <- vector("list", 0L)
write_calls <- c(
  "dbAppendTable", "dbExecute", "dbWriteTable", "write_ndjson_str",
  "canonical_json", "ledgr_json_write_canonical_ndjson"
)
write_owners <- unique(r_calls$owner[r_calls$call %in% write_calls &
                                      !is.na(r_calls$owner)])
definition_lookup <- unlist(lapply(r_index, function(entry) {
  setNames(lapply(entry$definitions, function(definition) {
    list(entry = entry, definition = definition)
  }), vapply(entry$definitions, `[[`, character(1), "name"))
}), recursive = FALSE)

binding_write_sites <- function(name) {
  owners <- write_owners[vapply(write_owners, function(owner) {
    found <- definition_lookup[[owner]]
    if (is.null(found)) return(FALSE)
    text <- definition_text(found$entry, found$definition)
    grepl(sprintf("\\b%s\\b", name), text, perl = TRUE)
  }, logical(1))]
  sort(unique(owners), method = "radix")
}

for (entry in r_index) {
  for (definition in entry$definitions) {
    name <- definition$name
    version_like <- grepl("version|_rule_[0-9]+$|_v[0-9]+$", name)
    if (!version_like) next
    rhs <- definition$rhs
    is_atomic_scalar <- is.atomic(rhs) && length(rhs) == 1L
    write_sites <- binding_write_sites(name)
    version_rows[[length(version_rows) + 1L]] <- data.frame(
      file = definition$file,
      line = definition$line,
      owner = name,
      record_kind = "binding",
      expression = deparse_one(definition$expression),
      persisted_or_convention = length(write_sites) > 0L,
      persistence_evidence = if (length(write_sites) > 0L) {
        paste0("write_site:", paste(write_sites, collapse = ";"))
      } else {
        "none"
      },
      fingerprint_member = name %in% fingerprint_names,
      atomic_scalar = is_atomic_scalar,
      outside_fingerprint = is_atomic_scalar && !name %in% fingerprint_names,
      comparison_operator = "",
      equality_assertion = FALSE,
      stringsAsFactors = FALSE
    )
  }

  strings <- entry$data[entry$data$token == "STR_CONST", , drop = FALSE]
  if (nrow(strings) > 0L) {
    values <- vapply(strings$text, function(text) {
      tryCatch(eval(parse(text = text), envir = baseenv()), error = function(e) "")
    }, character(1))
    keep <- grepl("^[A-Za-z][A-Za-z0-9_.-]*_v[0-9]+$", values, perl = TRUE)
    for (i in which(keep)) {
      version_rows[[length(version_rows) + 1L]] <- data.frame(
        file = entry$file,
        line = as.integer(strings$line1[[i]]),
        owner = owner_at(entry$definitions, strings$line1[[i]]),
        record_kind = "convention_string",
        expression = values[[i]],
        persisted_or_convention = TRUE,
        persistence_evidence = "convention_literal",
        fingerprint_member = FALSE,
        atomic_scalar = TRUE,
        outside_fingerprint = FALSE,
        comparison_operator = "",
        equality_assertion = FALSE,
        stringsAsFactors = FALSE
      )
    }
  }

  comparison_names <- c(
    "==", "!=", ">", ">=", "<", "<=", "identical", "is.null", "is.na",
    "%in%"
  )
  comparisons <- Filter(function(x) {
    identical(x$kind, "call") && !is.na(x$name) && x$name %in% comparison_names
  }, entry$nodes)
  token_rows <- entry$data[
    entry$data$text %in% comparison_names &
      entry$data$token %in% c(
        "EQ", "NE", "GT", "GE", "LT", "LE", "SPECIAL",
        "SYMBOL_FUNCTION_CALL"
      ),
    c("text", "line1"), drop = FALSE
  ]
  line_queues <- split(as.integer(token_rows$line1), token_rows$text)
  positions <- setNames(integer(length(line_queues)), names(line_queues))
  for (item in comparisons) {
    operator <- item$name
    positions[[operator]] <- positions[[operator]] + 1L
    lines <- line_queues[[operator]]
    line <- if (is.null(lines) || positions[[operator]] > length(lines)) {
      NA_integer_
    } else {
      lines[[positions[[operator]]]]
    }
    expression <- deparse_one(item$node)
    if (!grepl("version|schema|rule_[0-9]+|_v[0-9]+", expression,
               ignore.case = TRUE)) next
    version_rows[[length(version_rows) + 1L]] <- data.frame(
      file = entry$file,
      line = as.integer(line),
      owner = owner_at(entry$definitions, line),
      record_kind = "read_branch_or_equality",
      expression = expression,
      persisted_or_convention = TRUE,
      persistence_evidence = "comparison",
      fingerprint_member = FALSE,
      atomic_scalar = FALSE,
      outside_fingerprint = FALSE,
      comparison_operator = operator,
      equality_assertion = operator %in% c("==", "!=", "identical"),
      stringsAsFactors = FALSE
    )
  }
}
literal_rows <- current_only_literal_rows(root)
if (!is.null(literal_rows)) {
  version_rows[[length(version_rows) + 1L]] <- literal_rows
}
version_rows <- ledgr_census_bind_rows(
  version_rows,
  census_schemas$versions[, setdiff(
    names(census_schemas$versions), "current_only_violation"
  ), drop = FALSE]
)
if (nrow(version_rows) > 0L) {
  version_rows <- unique(version_rows)
  version_rows$current_only_violation <- mapply(
    function(record_kind, expression, operator, owner) {
      identical(record_kind, "retired_literal") ||
        (identical(record_kind, "read_branch_or_equality") &&
           current_only_comparison_violation(expression, operator, owner))
    },
    version_rows$record_kind,
    version_rows$expression,
    version_rows$comparison_operator,
    version_rows$owner,
    USE.NAMES = FALSE
  )
} else {
  version_rows$current_only_violation <- logical()
}

## Hand-built run-config census -------------------------------------------

call_has_name <- function(x, target) {
  if (is.call(x)) {
    if (target %in% names(x)) return(TRUE)
    nodes <- as.list(x)[-1L]
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

config_shape <- function(x) {
  if (!is.call(x) || !identical(call_name(x), "list")) return(FALSE)
  fields <- names(as.list(x))
  all(c("data", "strategy") %in% fields) ||
    all(c("engine", "universe", "backtest", "strategy") %in% fields)
}

status_pair <- function(identity = "indeterminate", snapshot = "indeterminate",
                        origin = "indeterminate", origin_expression = "") {
  list(
    identity_rule_version = identity,
    data_snapshot_hash = snapshot,
    config_origin = origin,
    origin_expression = origin_expression
  )
}

definition_for <- function(name, index) {
  for (entry in index) {
    hit <- Filter(function(x) identical(x$name, name) && isTRUE(x$is_function),
                  entry$definitions)
    if (length(hit) > 0L) return(list(entry = entry, definition = hit[[1L]]))
  }
  NULL
}

resolve_config_expression <- function(expr, entry, before = Inf,
                                      visited = character()) {
  text <- deparse_one(expr)
  if (is.call(expr) && identical(call_name(expr), "ledgr_config")) {
    return(status_pair("supplied", "supplied", "ledgr_config", text))
  }
  if (is.call(expr) && identical(call_name(expr), "list")) {
    return(status_pair(
      if (call_has_name(expr, "identity_rule_version")) "supplied" else "absent",
      if (call_has_name(expr, "snapshot_hash")) "supplied" else "absent",
      "list_literal",
      text
    ))
  }
  if (is.call(expr) && call_name(expr) %in% c("$", "[[") &&
      grepl("(?:[$]|\\[\\[)config(?:\\]\\])?$", text, perl = TRUE)) {
    return(status_pair("supplied", "supplied", "run_derived", text))
  }
  if (is.symbol(expr)) {
    name <- as.character(expr)
    assignments <- Filter(function(item) {
      identical(item$kind, "assignment") && identical(item$name, name) &&
        item$ordinal < before
    }, entry$nodes)
    if (length(assignments) == 0L) {
      return(status_pair(origin = "unresolved_symbol", origin_expression = text))
    }
    assignment <- assignments[[length(assignments)]]
    return(resolve_config_expression(
      assignment$node[[3L]], entry, assignment$ordinal,
      visited = visited
    ))
  }
  if (is.call(expr)) {
    helper <- call_name(expr)
    if (!is.na(helper) && !helper %in% visited) {
      found <- definition_for(helper, c(test_index, bench_index, r_index))
      if (!is.null(found)) {
        formals <- names(as.list(found$definition$rhs[[2L]]))
        body <- found$definition$rhs[[3L]]
        body_text <- deparse_one(body)
        if (grepl("identity_rule_version", body_text, fixed = TRUE) &&
            grepl("snapshot_hash", body_text, fixed = TRUE)) {
          return(status_pair(
            "supplied", "supplied", paste0("helper:", helper, ":current"),
            text
          ))
        }
        returned <- if (is.call(body) && identical(call_name(body), "{")) {
          tail(as.list(body)[-1L], 1L)[[1L]]
        } else {
          body
        }
        if (is.symbol(returned) && as.character(returned) %in% formals) {
          formal <- as.character(returned)
          actual <- call_argument(expr, formal, match(formal, formals))
          if (!is.null(actual)) {
            result <- resolve_config_expression(
              actual, entry, before, visited = c(visited, helper)
            )
            result$config_origin <- paste0(
              "helper:", helper, ":pass_through:", result$config_origin
            )
            return(result)
          }
        }
        body_nodes <- ast_nodes(found$definition$rhs)
        body_start <- found$definition$line
        body_end <- found$definition$line_end
        candidates <- Filter(function(item) {
          identical(item$kind, "call") &&
            item$name %in% c("ledgr_config", "list")
        }, body_nodes)
        candidates <- Filter(function(item) {
          item_text <- deparse_one(item$node)
          identical(item$name, "ledgr_config") || config_shape(item$node) ||
            grepl("identity_rule_version|snapshot_hash", item_text)
        }, candidates)
        if (length(candidates) == 1L) {
          result <- resolve_config_expression(
            candidates[[1L]]$node, found$entry, candidates[[1L]]$ordinal,
            visited = c(visited, helper)
          )
          result$config_origin <- paste0("helper:", helper, ":", result$config_origin)
          return(result)
        }
        if (length(candidates) > 1L || (!is.na(body_start) && !is.na(body_end))) {
          return(status_pair(origin = paste0("helper:", helper, ":indeterminate"),
                             origin_expression = text))
        }
      }
    }
  }
  status_pair(origin_expression = text)
}

config_consumers <- c("ledgr_run_config", "ledgr_run_fold")
run_config_rows <- vector("list", 0L)
for (entry in c(test_index, bench_index)) {
  occurrences <- call_occurrences(entry, config_consumers)
  for (item in occurrences) {
    config <- call_argument(item$call, "config", 1L)
    resolved <- if (is.null(config)) {
      status_pair(origin = "missing_config_argument")
    } else {
      resolve_config_expression(config, entry, item$ordinal)
    }
    run_config_rows[[length(run_config_rows) + 1L]] <- data.frame(
      file = item$file,
      line = item$line,
      owner = item$owner,
      consumer = item$name,
      config_origin = resolved$config_origin,
      identity_rule_version = resolved$identity_rule_version,
      data_snapshot_hash = resolved$data_snapshot_hash,
      origin_expression = resolved$origin_expression,
      expression = deparse_one(item$call),
      stringsAsFactors = FALSE
    )
  }

  builders <- Filter(function(item) config_shape(item$call),
                     call_occurrences(entry, "list"))
  for (item in builders) {
    resolved <- resolve_config_expression(item$call, entry, item$ordinal)
    already <- vapply(run_config_rows, function(row) {
      identical(row$file, entry$file) &&
        identical(row$origin_expression, deparse_one(item$call))
    }, logical(1))
    if (length(already) > 0L && any(already)) next
    run_config_rows[[length(run_config_rows) + 1L]] <- data.frame(
      file = entry$file,
      line = item$line,
      owner = item$owner,
      consumer = "config_builder",
      config_origin = resolved$config_origin,
      identity_rule_version = resolved$identity_rule_version,
      data_snapshot_hash = resolved$data_snapshot_hash,
      origin_expression = resolved$origin_expression,
      expression = deparse_one(item$call),
      stringsAsFactors = FALSE
    )
  }
}
if (length(run_config_rows) == 0L) {
  run_config_rows <- data.frame(
    file = character(), line = integer(), owner = character(),
    consumer = character(), config_origin = character(),
    identity_rule_version = character(), data_snapshot_hash = character(),
    origin_expression = character(), expression = character(),
    stringsAsFactors = FALSE
  )
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
    calls <- call_occurrences(entry, dispatch)
    if (length(calls) == 0L) next
    for (item in calls) {
      args <- as.list(item$call)[-1L]
      names_found <- unique(unlist(lapply(args, literal_strings), use.names = FALSE))
      names_found <- names_found[
        grepl("^[.]?[A-Za-z][A-Za-z0-9_.]*$", names_found, perl = TRUE)
      ]
      for (name in unique(names_found)) {
        rows[[length(rows) + 1L]] <- data.frame(
          name = name,
          file = entry$file,
          line = as.integer(item$line),
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
helper_rows <- ledgr_census_bind_rows(helper_rows, census_schemas$helpers)

## Condition census --------------------------------------------------------

condition_reference <- read_source(file.path(root, "R", "condition-reference.R"))
alias_lines <- grep("^#' @aliases ", condition_reference, value = TRUE)
documented_aliases <- unique(unlist(strsplit(sub("^#' @aliases ", "", alias_lines), "[[:space:]]+")))
prose <- condition_reference[grepl("^#'", condition_reference) & !grepl("^#' @aliases ", condition_reference)]
prose_tokens <- unique(unlist(regmatches(
  prose,
  gregexpr("\\bledgr_[A-Za-z0-9_]+\\b", prose, perl = TRUE)
), use.names = FALSE))

symbols_in <- function(x) {
  if (is.symbol(x)) return(as.character(x))
  if (is.call(x) || is.pairlist(x) || is.expression(x) || is.list(x)) {
    return(unique(unlist(lapply(child_nodes(x), symbols_in), use.names = FALSE)))
  }
  character()
}

condition_row <- function(file, line, call_kind, condition_class = "",
                          recoverable = FALSE, expression = "") {
  data.frame(
    file = file,
    line = as.integer(line),
    call_kind = call_kind,
    condition_class = condition_class,
    recoverable = recoverable,
    expression = expression,
    documented_alias = condition_class %in% documented_aliases,
    documented_description = condition_class %in% prose_tokens,
    internal_prefix = startsWith(condition_class, "ledgr_internal_"),
    stringsAsFactors = FALSE
  )
}

condition_names <- c("abort", "stop", "warning", "warn")
condition_calls <- unlist(lapply(r_index, call_occurrences,
                                 targets = condition_names), recursive = FALSE)
condition_rows <- vector("list", 0L)
wrapper_specs <- vector("list", 0L)

for (item in condition_calls) {
  call <- item$call
  class_expression <- if (item$name %in% c("abort", "warn")) {
    call_argument(call, "class", 2L)
  } else {
    NULL
  }
  classes <- if (is.null(class_expression)) {
    character()
  } else {
    literal_strings(class_expression)
  }
  resolver <- if (is.call(class_expression)) call_name(class_expression) else ""
  if (nzchar(resolver) && !is.null(definition_lookup[[resolver]])) {
    classes <- unique(c(
      classes,
      ledgr_structure_ledgr_literals(
        definition_lookup[[resolver]]$definition$rhs
      )
    ))
  }
  classed <- item$name %in% c("abort", "warn") && !is.null(class_expression)
  if (classed && length(classes) > 0L) {
    for (class in classes) {
      condition_rows[[length(condition_rows) + 1L]] <- condition_row(
        item$file, item$line,
        if (identical(item$name, "abort")) "abort_class" else "warning_class",
        class, TRUE, deparse_one(class_expression)
      )
    }
  }
  unresolved <- classed && length(setdiff(
    symbols_in(class_expression), c("c")
  )) > 0L
  if (!classed || unresolved || length(classes) == 0L) {
    kind <- if (identical(item$name, "abort")) {
      "abort_dynamic"
    } else if (identical(item$name, "warn")) {
      "warning_dynamic"
    } else {
      item$name
    }
    condition_rows[[length(condition_rows) + 1L]] <- condition_row(
      item$file, item$line, kind, expression = if (!is.null(class_expression)) {
        deparse_one(class_expression)
      } else {
        deparse_one(call)
      }
    )
  }

  if (classed && !is.na(item$owner)) {
    found <- definition_lookup[[item$owner]]
    if (!is.null(found)) {
      formals <- names(as.list(found$definition$rhs[[2L]]))
      dynamic_formals <- intersect(symbols_in(class_expression), formals)
      if (length(dynamic_formals) > 0L) {
        wrapper_specs[[length(wrapper_specs) + 1L]] <- list(
          name = item$owner,
          class_expression = class_expression,
          definition = found$definition
        )
      }
    }
  }
}

actual_for_formal <- function(call, formal, formals) {
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

resolved_class_literals <- function(x, call, formals, seen = character()) {
  if (is.character(x)) return(as.character(x))
  if (is.symbol(x) && as.character(x) %in% names(formals)) {
    name <- as.character(x)
    if (name %in% seen) return(character())
    actual <- actual_for_formal(call, name, formals)
    if (is.null(actual)) return(character())
    return(resolved_class_literals(actual, call, formals, c(seen, name)))
  }
  if (is.call(x) && identical(call_name(x), "c")) {
    return(unlist(lapply(as.list(x)[-1L], resolved_class_literals,
                         call = call, formals = formals, seen = seen),
                  use.names = FALSE))
  }
  if (is.call(x)) {
    resolver <- call_name(x)
    if (!is.null(definition_lookup[[resolver]])) {
      return(ledgr_structure_ledgr_literals(
        definition_lookup[[resolver]]$definition$rhs
      ))
    }
  }
  character()
}

for (spec in wrapper_specs) {
  formals <- as.list(spec$definition$rhs[[2L]])
  invocations <- unlist(lapply(r_index, call_occurrences,
                               targets = spec$name), recursive = FALSE)
  for (item in invocations) {
    classes <- unique(resolved_class_literals(
      spec$class_expression, item$call, formals
    ))
    for (class in classes) {
      condition_rows[[length(condition_rows) + 1L]] <- condition_row(
        item$file, item$line, "abort_wrapper_class", class, TRUE,
        deparse_one(item$call)
      )
    }
    if (length(classes) == 0L) {
      condition_rows[[length(condition_rows) + 1L]] <- condition_row(
        item$file, item$line, "abort_wrapper_dynamic",
        expression = deparse_one(item$call)
      )
    }
  }
}
condition_rows <- ledgr_census_bind_rows(condition_rows, census_schemas$conditions)

condition_class_rows <- condition_rows[
  condition_rows$call_kind %in% c(
    "abort_class", "abort_wrapper_class", "warning_class"
  ),
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
  condition_classes <- census_schemas$condition_classes
}

structural_condition_classes <- ledgr_structure_scan(root)$condition_classes
structural_public_classes <- structural_condition_classes[
  startsWith(structural_condition_classes, "ledgr_") &
    !startsWith(structural_condition_classes, "ledgr_internal_")
]
census_public_classes <- condition_classes$condition_class[
  condition_classes$public
]
if (!setequal(structural_public_classes, census_public_classes)) {
  stop(sprintf(
    paste0(
      "The condition scanner and census disagree. Scanner-only: %s. ",
      "Census-only: %s."
    ),
    paste(setdiff(structural_public_classes, census_public_classes), collapse = ", "),
    paste(setdiff(census_public_classes, structural_public_classes), collapse = ", ")
  ), call. = FALSE)
}

test_seam_contracts <- c(
  ledgr_local_time_resolve = paste(
    "Exercise ambiguous and nonexistent local-time policy without building",
    "a complete availability input."
  ),
  ledgr_session_decision_pulses = paste(
    "Isolate session-to-decision-axis derivation and off-session exclusion."
  ),
  ledgr_business_objective_from_plan_json = paste(
    "Check canonical stored-plan decoding independently of experiment assembly."
  ),
  ledgr_with_collapse_deterministic = paste(
    "Verify the collapse determinism boundary and scoped option restoration."
  ),
  ledgr_validate_config = paste(
    "Target validation failures on controlled hand-built run configurations."
  ),
  ledgr_corporate_action_identity_schema = paste(
    "Inspect the exact private corporate-action identity payload and version."
  ),
  ledgr_create_schema = paste(
    "Create controlled schemas for catalogue and interrupted-transaction tests."
  ),
  ledgr_schema_catalogue_difference = paste(
    "Compare synthetic catalogue mutations without a public store workflow."
  ),
  ledgr_schema_catalogue_digest = paste(
    "Pin the deterministic digest of a controlled schema catalogue."
  ),
  ledgr_experiment_store_version = paste(
    "Inspect schema binding without creating an experiment store."
  ),
  ledgr_experiment_materialize_features = paste(
    "Exercise feature-map materialization independently of a complete run."
  ),
  ledgr_check_no_lookahead = paste(
    "Inject hostile callbacks into the prefix-invariance causality oracle."
  ),
  ledgr_equity_from_events = paste(
    "Reconstruct equity from controlled events for fold-parity assertions."
  ),
  ledgr_fills_from_events = paste(
    "Reconstruct fills from controlled events for fold-parity assertions."
  ),
  ledgr_pulse_context = paste(
    "Construct minimal pulse contexts for accessor contract tests."
  ),
  ledgr_projection_feature_at = paste(
    "Probe indexed projection reads and missing-value behavior directly."
  ),
  ledgr_snapshot_verified_reset = paste(
    "Clear the process-local verification registry between isolation tests."
  ),
  ledgr_snapshot_validate = paste(
    "Validate controlled and tampered snapshot roots without reopening a run."
  ),
  ledgr_strategy_preflight_uses_ambient_rng = paste(
    "Probe the static ambient-RNG classifier on controlled strategy bodies."
  ),
  ledgr_sweep_wide_candidate_id = paste(
    "Exercise wide-retention candidate-ID parsing and collision handling."
  ),
  ledgr_event_row_df = paste(
    "Build typed event rows for writer and reconstruction test oracles."
  ),
  ledgr_history_worker_clear = paste(
    "Reset daemon-local staged history between worker identity and cleanup tests."
  ),
  ledgr_history_substrate_query_facts = paste(
    "Probe literal two-clock fact answers independently of fold execution."
  ),
  ledgr_history_substrate_census = paste(
    "Inspect the per-instrument segment guard record on controlled fixtures."
  ),
  ledgr_history_evidence_fields = paste(
    "Pin the shared history-treatment evidence vocabulary before public views exist."
  ),
  ledgr_history_substrate_treated_field = paste(
    "Exercise treatment against late-known expected-session masks before WS42 exposes frames."
  ),
  ledgr_history_feature_planes = paste(
    "Observe per-instrument feature evidence planes from the production calculation before public history results consume them."
  )
)

test_only_seams <- helper_rows[
  helper_rows$classification == "test_only_private",
  c(
    "file", "line", "helper", "test_reference_count",
    "reference_locations"
  ),
  drop = FALSE
]
if (nrow(test_only_seams) == 0L) {
  test_only_seams <- empty_frame(c(
    "file", "line", "helper", "test_reference_count",
    "reference_locations", "testing_contract"
  ))
} else {
  missing_contract <- setdiff(test_only_seams$helper, names(test_seam_contracts))
  stale_contract <- setdiff(names(test_seam_contracts), test_only_seams$helper)
  if (length(missing_contract) > 0L || length(stale_contract) > 0L) {
    stop(sprintf(
      "Test-seam contracts disagree. Missing: %s. Stale: %s.",
      paste(missing_contract, collapse = ", "),
      paste(stale_contract, collapse = ", ")
    ), call. = FALSE)
  }
  test_only_seams$testing_contract <- unname(
    test_seam_contracts[test_only_seams$helper]
  )
}

condition_dynamics <- condition_rows[
  !condition_rows$call_kind %in% c(
    "abort_class", "abort_wrapper_class", "warning_class"
  ),
  c("file", "line", "call_kind", "expression"),
  drop = FALSE
]
if (nrow(condition_dynamics) == 0L) {
  condition_dynamics <- empty_frame(c(
    "file", "line", "call_kind", "expression", "disposition", "reason"
  ))
} else {
  base_condition <- condition_dynamics$call_kind %in% c("stop", "warning")
  condition_dynamics$disposition <- ifelse(
    base_condition,
    "base_condition",
    "runtime_class_expression"
  )
  condition_dynamics$reason <- ifelse(
    base_condition,
    "Base R condition without a ledgr public class-vector element.",
    paste(
      "The class is supplied by a validated caller, wrapper formal, or",
      "caught runtime condition and cannot be enumerated at this site."
    )
  )
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
test_only_seams <- write_table(
  test_only_seams,
  "test_only_seams.csv",
  c("file", "line", "helper")
)
condition_dynamics <- write_table(
  condition_dynamics,
  "condition_dynamics.csv",
  c("file", "line", "call_kind", "expression")
)

summary <- ledgr_census_summary(list(
  conditions = condition_rows,
  condition_classes = condition_classes,
  connections = connection_rows,
  helpers = helper_rows,
  run_configs = run_config_rows,
  versions = version_rows
))
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

if (identical(mode, "check")) {
  bad_configs <- run_config_rows$consumer != "config_builder" &
    (run_config_rows$identity_rule_version != "supplied" |
       run_config_rows$data_snapshot_hash != "supplied")
  bad_versions <- version_rows$current_only_violation
  if (any(bad_configs) || any(bad_versions)) {
    stop(sprintf(
      paste0(
        "LEDGR_CODEBASE_CENSUS_FAILED current-only versions=%d ",
        "run_configs=%d."
      ),
      sum(bad_versions),
      sum(bad_configs)
    ), call. = FALSE)
  }
}
