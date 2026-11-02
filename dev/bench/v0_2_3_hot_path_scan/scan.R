# One-off hot-path scan (macro plan rule 17, WS14a input). Lists the banned
# calls in package code that can run per pulse. Not a test: run it by hand.
#
#   Rscript dev/bench/v0_2_3_hot_path_scan/scan.R           compare with scan.csv
#   Rscript dev/bench/v0_2_3_hot_path_scan/scan.R --write   rewrite scan.csv
#
# The walk is static and deliberately simple: calls through variables,
# arguments or computed `[[` are not followed unless listed below.

ledgr_hot_path_banned <- c(
  "match", "%in%", "setdiff", "setNames", "unique", "data.frame",
  "as.data.frame", "rbind", "all.equal",
  # Canonical JSON encode or parse (rule 14): yyjsonr and ledgr's wrappers.
  "read_json_str", "write_json_str", "write_ndjson_str", "validate_json_str",
  "canonical_json", "ledgr_canonical_json_encode", "ledgr_json_read_nested",
  "ledgr_json_read_config", "ledgr_json_write_canonical_v2",
  "ledgr_json_write_canonical_v2_verbatim", "ledgr_json_write_canonical_ndjson",
  "ledgr_parse_json_field"
)

# Where per-pulse code starts: the fold stages and the helpers the pulse loop
# calls between them, and what a strategy can call while deciding.
ledgr_hot_path_roots <- function(keys) {
  c(
    "ledgr_fold_stage_observe_settle", "ledgr_fold_stage_decide",
    "ledgr_fold_stage_plan", "ledgr_fold_stage_apply", "ledgr_fold_stage_commit",
    "ledgr_fold_scheduled_skip_decision", "ledgr_fold_scheduled_skip_plan",
    "ledgr_fold_apply_stop", "ledgr_strategy_result",
    "ledgr_align_weights", "ledgr_passed_warmup", "ledgr_select_lowest",
    "ledgr_select_top", "ledgr_selection", "ledgr_signal", "ledgr_signal_return",
    "ledgr_target", "ledgr_target_adjust", "ledgr_target_quantity",
    "ledgr_target_rebalance", "ledgr_weight_equal", "ledgr_weights",
    "ledgr_history_frame", "ledgr_history_matrix", "ledgr_history_info",
    "ledgr_schedule_due", "ledgr_signal_strategy",
    grep("\\.(ledgr_pulse_context|ledgr_strategy_state_view|ledgr_history_matrix)$", keys, value = TRUE),
    grep("^ledgr_pulse_context_helper_bundle[/$]", keys, value = TRUE)
  )
}

# Calls the walk cannot see: a closure passed in as an argument or returned
# by a factory. Each entry is caller -> callees.
ledgr_hot_path_edges <- list(
  ledgr_plan_resolve = "ledgr_cost_resolver_from_model/resolver",
  "ledgr_availability_provider_from_plan/decision_view" =
    "ledgr_availability_prepared_membership_from_plan/prepared_members_at",
  "ledgr_availability_provider_from_plan/execution_view" =
    "ledgr_availability_prepared_membership_from_plan/prepared_members_at",
  ledgr_schedule_due = "ledgr_strategy_schedule_query"
)

ledgr_hot_path_head <- function(x) {
  h <- x[[1L]]
  if (is.symbol(h)) return(as.character(h))
  if (is.call(h) && is.symbol(h[[1L]]) && as.character(h[[1L]]) %in% c("::", ":::")) {
    return(as.character(h[[3L]]))
  }
  ""
}

# Every function definition in R/: top level as `name`, closures assigned to
# a local as `owner/name`, member closures as `owner$name`. A second
# definition under one key gets a `#2` suffix.
ledgr_hot_path_functions <- function(root) {
  out <- new.env(hash = TRUE, parent = emptyenv())
  keys <- character()
  top <- character()
  add <- function(key, fn) {
    if (!is.null(out[[key]])) key <- paste0(key, "#", sum(sub("#.*", "", keys) == key) + 1L)
    out[[key]] <- fn
    keys[[length(keys) + 1L]] <<- key
    key
  }
  collect <- function(x, owner) {
    if (!is.call(x)) return(invisible())
    head <- ledgr_hot_path_head(x)
    if (head %in% c("<-", "=") && length(x) == 3L && is.call(x[[3L]]) &&
        identical(x[[3L]][[1L]], as.name("function"))) {
      lhs <- x[[2L]]
      key <- if (is.symbol(lhs)) paste0(owner, "/", lhs) else if (is.call(lhs) &&
        identical(lhs[[1L]], as.name("$"))) paste0(owner, "$", lhs[[3L]]) else NULL
      if (!is.null(key)) {
        key <- add(key, x[[3L]])
        return(collect(x[[3L]][[3L]], key))
      }
    }
    tags <- names(x)
    for (i in seq_along(x)[-1L]) {
      if (!is.call(x[[i]])) next
      arg <- x[[i]]
      if (head == "list" && !is.null(tags) && nzchar(tags[[i]]) &&
          identical(arg[[1L]], as.name("function"))) {
        key <- add(paste0(owner, "$", tags[[i]]), arg)
        collect(arg[[3L]], key)
      } else {
        collect(arg, owner)
      }
    }
  }
  for (path in list.files(file.path(root, "R"), pattern = "[.]R$", full.names = TRUE)) {
    for (x in parse(path, keep.source = FALSE)) {
      if (is.call(x) && as.character(x[[1L]]) %in% c("<-", "=") && is.symbol(x[[2L]]) &&
          is.call(x[[3L]]) && identical(x[[3L]][[1L]], as.name("function"))) {
        key <- add(as.character(x[[2L]]), x[[3L]])
        top <- c(top, key)
        collect(x[[3L]][[3L]], key)
      }
    }
  }
  list(functions = mget(keys, envir = out), top = top)
}

# Banned calls in one function body and the functions it reaches.
ledgr_hot_path_walk <- function(key, fn, index) {
  banned <- character()
  edges <- character()
  owners <- character()
  scope <- sub("#.*", "", key)
  while (nzchar(scope)) {
    owners <- c(owners, scope)
    scope <- sub("[/$][^/$]*$", "", scope)
    if (!grepl("[/$]", owners[[length(owners)]])) break
  }
  visit_name <- function(name) {
    if (name %in% ledgr_hot_path_banned) banned <<- c(banned, name)
    for (owner in owners) {
      local <- index$by_base[[paste0(owner, "/", name)]]
      if (length(local)) return(edges <<- c(edges, local))
    }
    if (!is.null(index$top[[name]])) edges <<- c(edges, index$by_base[[name]])
  }
  walk <- function(x) {
    if (is.symbol(x)) {
      name <- as.character(x)
      if (nzchar(name) && (name %in% ledgr_hot_path_banned || !is.null(index$top[[name]]))) visit_name(name)
      return(invisible())
    }
    if (!is.call(x)) return(invisible())
    head <- ledgr_hot_path_head(x)
    if (head %in% c("quote", "bquote", "~")) return(invisible())
    if (head %in% c("<-", "=") && length(x) == 3L && is.call(x[[3L]]) &&
        identical(x[[3L]][[1L]], as.name("function"))) return(invisible())
    first <- x[[1L]]
    if (nzchar(head)) {
      visit_name(head)
    } else if (is.call(first) && as.character(first[[1L]]) %in% c("$", "[[") &&
               (is.symbol(first[[3L]]) || is.character(first[[3L]]))) {
      edges <<- c(edges, index$member[[as.character(first[[3L]])]])
      walk(first[[2L]])
    } else {
      walk(first)
    }
    if (head %in% c("$", "@")) return(walk(x[[2L]]))
    if (head == "do.call" && length(x) > 1L && is.character(x[[2L]])) visit_name(x[[2L]])
    for (i in seq_along(x)[-1L]) {
      if (identical(x[[i]], quote(expr = ))) next
      arg <- x[[i]]
      if (head == "list" && is.call(arg) && identical(arg[[1L]], as.name("function")) &&
          nzchar(names(x)[[i]] %||% "")) next
      walk(arg)
    }
  }
  defaults <- as.list(fn[[2L]])
  for (i in seq_along(defaults)) if (!identical(defaults[[i]], quote(expr = ))) walk(defaults[[i]])
  walk(fn[[3L]])
  list(banned = banned, edges = unique(c(edges, ledgr_hot_path_edges[[key]])))
}

ledgr_hot_path_scan <- function(root) {
  found <- ledgr_hot_path_functions(root)
  functions <- found$functions
  keys <- names(functions)
  base <- sub("#.*", "", keys)
  top <- unique(sub("#.*", "", found$top))
  members <- keys[grepl("[$][^/$]*$", base) & !base %in% top]
  index <- list(
    by_base = list2env(split(keys, base), hash = TRUE),
    top = list2env(stats::setNames(as.list(rep(TRUE, length(top))), top), hash = TRUE),
    member = list2env(split(members, sub("^.*[$]", "", sub("#.*", "", members))), hash = TRUE)
  )
  roots <- intersect(ledgr_hot_path_roots(keys), keys)
  seen <- new.env(hash = TRUE, parent = emptyenv())
  queue <- roots
  rows <- list()
  while (length(queue)) {
    key <- queue[[1L]]
    queue <- queue[-1L]
    if (!is.null(seen[[key]]) || is.null(functions[[key]])) next
    seen[[key]] <- TRUE
    walked <- ledgr_hot_path_walk(key, functions[[key]], index)
    if (length(walked$banned)) {
      counts <- table(walked$banned)
      rows[[length(rows) + 1L]] <- data.frame(node = key, call = names(counts),
                                              count = as.integer(counts), stringsAsFactors = FALSE)
    }
    queue <- c(queue, walked$edges)
  }
  out <- do.call(rbind, c(rows, list(data.frame(node = character(), call = character(),
                                                count = integer()))))
  out <- out[order(out$node, out$call, method = "radix"), , drop = FALSE]
  rownames(out) <- NULL
  attr(out, "roots") <- roots
  attr(out, "reached") <- ls(seen)
  out
}

ledgr_hot_path_baseline_path <- function(root) {
  file.path(root, "dev", "bench", "v0_2_3_hot_path_scan", "scan.csv")
}

# Differences between a scan and the baseline, one line per changed row.
ledgr_hot_path_diff <- function(scan, baseline) {
  key <- function(x) paste(x$node, x$call)
  now <- stats::setNames(scan$count, key(scan))
  was <- stats::setNames(as.integer(baseline$count), key(baseline))
  rows <- union(names(now), names(was))
  changed <- rows[!vapply(rows, function(r) identical(now[r], was[r]), logical(1))]
  sprintf("%s: baseline %s, now %s", changed,
          ifelse(is.na(was[changed]), 0L, was[changed]),
          ifelse(is.na(now[changed]), 0L, now[changed]))
}

if (sys.nframe() == 0L) {
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  root <- normalizePath(file.path(dirname(sub("^--file=", "", file_arg[[1L]])), "..", "..", ".."),
                        winslash = "/")
  scan <- ledgr_hot_path_scan(root)
  path <- ledgr_hot_path_baseline_path(root)
  if ("--write" %in% commandArgs(TRUE)) {
    utils::write.csv(scan, path, row.names = FALSE, fileEncoding = "UTF-8", eol = "\n")
    cat(sprintf("LEDGR_HOT_PATH_BANS written: %d rows, %d calls\n", nrow(scan), sum(scan$count)))
  } else {
    diff <- ledgr_hot_path_diff(scan, utils::read.csv(path, stringsAsFactors = FALSE))
    if (length(diff)) {
      cat("LEDGR_HOT_PATH_BANS_FAILED\n", paste0("  ", diff, "\n"), sep = "")
      quit(status = 1L)
    }
    cat(sprintf("LEDGR_HOT_PATH_BANS_OK %d rows, %d calls\n", nrow(scan), sum(scan$count)))
  }
}
