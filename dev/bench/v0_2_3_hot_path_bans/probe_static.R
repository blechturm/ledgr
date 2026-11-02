# Probe: static per-pulse call graph and banned calls.
# Usage: Rscript probe_static.R <pkg_dir> <out_dir> <ring: stages|ctx|helpers> [rprof.out]
args <- commandArgs(trailingOnly = TRUE)
pkg <- args[[1]]; out <- args[[2]]; ring <- args[[3]]
rprof <- if (length(args) >= 4) args[[4]] else NA
rdir <- file.path(pkg, "R")
dir.create(out, showWarnings = FALSE, recursive = TRUE)

stage_roots <- c("ledgr_fold_stage_observe_settle", "ledgr_fold_stage_decide",
  "ledgr_fold_stage_plan", "ledgr_fold_stage_apply", "ledgr_fold_stage_commit")
banned <- c("match", "%in%", "setdiff", "setNames", "unique", "data.frame",
  "as.data.frame", "rbind", "all.equal")
json <- c("toJSON", "fromJSON", "parse_json", "serializeJSON", "canonical_json",
  "ledgr_canonical_json_encode", "ledgr_canonical_json", "ledgr_json_read_nested",
  "ledgr_json_read_config", "ledgr_parse_json_field")
apply_heads <- c("vapply", "lapply", "sapply", "mapply", "Map", "Reduce", "Filter",
  "do.call", "outer", "tapply", "rapply")
cold_heads <- c("abort", "stop", "warning", "warn", "inform", "message", "signalCondition")
is_cold <- function(h) h %in% cold_heads || grepl("^ledgr_.*(abort|_fail|_refuse|_error)$", h)
is_fun <- function(e) is.call(e) && identical(e[[1]], as.name("function"))
is_empty <- function(e) identical(e, quote(expr = ))
head_name <- function(e) {
  h <- e[[1]]
  if (is.name(h)) return(as.character(h))
  if (is.call(h) && as.character(h[[1]]) %in% c("::", ":::")) return(as.character(h[[3]]))
  NA_character_
}

# Nodes: top-level functions plus closures defined inside them, keyed "owner$name".
nodes <- list(); node_file <- character(); node_owner <- character(); top_ids <- character()
aliases <- list()
add_node <- function(id, fn, file, owner) {
  nodes[[id]] <<- fn; node_file[[id]] <<- file; node_owner[[id]] <<- owner
}
collect <- function(e, owner, file) {
  if (!is.call(e)) return(invisible())
  h <- e[[1]]
  if (is.name(h) && as.character(h) %in% c("<-", "=", "<<-") && is_fun(e[[3]])) {
    lhs <- e[[2]]
    nm <- if (is.name(lhs)) as.character(lhs) else if (is.call(lhs) &&
      identical(lhs[[1]], as.name("$"))) as.character(lhs[[3]]) else NA
    if (!is.na(nm)) add_node(paste0(owner, "$", nm), e[[3]], file, owner)
  }
  is_member <- function(x) is.call(x) && identical(x[[1]], as.name("$"))
  if (is.name(h) && as.character(h) %in% c("<-", "=", "<<-") && is_member(e[[2]]) &&
      (is.name(e[[3]]) || is_member(e[[3]]))) {
    rhs <- e[[3]]
    aliases[[length(aliases) + 1L]] <<- c(owner, as.character(e[[2]][[3]]),
      if (is.name(rhs)) as.character(rhs) else paste0("$", as.character(rhs[[3]])))
  }
  nm <- names(e)
  for (i in seq_along(e)[-1]) {
    if (is_empty(e[[i]])) next
    a <- e[[i]]
    if (!is.null(nm) && nzchar(nm[[i]])) {
      if (is_fun(a)) add_node(paste0(owner, "$", nm[[i]]), a, file, owner)
      if (is.name(a)) aliases[[length(aliases) + 1L]] <<- c(owner, nm[[i]], as.character(a))
      if (is_member(a)) aliases[[length(aliases) + 1L]] <<- c(owner, nm[[i]],
        paste0("$", as.character(a[[3]])))
    }
    if (is.call(a)) collect(a, owner, file)
  }
}
for (f in list.files(rdir, pattern = "[.]R$", full.names = TRUE)) {
  for (e in parse(f, keep.source = FALSE)) {
    if (is.call(e) && as.character(e[[1]]) %in% c("<-", "=") && is.name(e[[2]]) && is_fun(e[[3]])) {
      nm <- as.character(e[[2]])
      add_node(nm, e[[3]], basename(f), nm); top_ids <- c(top_ids, nm)
      collect(e[[3]][[3]], nm, basename(f))
    }
  }
}
ids <- names(nodes)
top <- unique(top_ids)
local <- setdiff(ids, top)
member_of <- split(local, sub(".*\\$", "", local))
for (pass in 1:2) for (a in aliases) {
  target <- if (startsWith(a[[3]], "$")) member_of[[substring(a[[3]], 2)]] else
    intersect(c(paste0(a[[1]], "$", a[[3]]), a[[3]]), c(local, top))
  if (length(target)) member_of[[a[[2]]]] <- unique(c(member_of[[a[[2]]]], target))
}

scan <- function(id) {
  fn <- nodes[[id]]; owner <- node_owner[[id]]
  edges <- character(); hits <- character()
  resolve <- function(s) {
    out <- character()
    if (s %in% top) out <- s
    own <- paste0(owner, "$", s)
    if (own %in% local) out <- c(out, own)
    out
  }
  walk <- function(e, cold) {
    if (is.name(e)) {
      s <- as.character(e)
      if (!cold && s %in% json) hits <<- c(hits, s)
      if (!s %in% json) edges <<- c(edges, resolve(s))
      return(invisible())
    }
    if (!is.call(e)) return(invisible())
    if (is_fun(e)) { walk(e[[3]], cold); return(invisible()) }
    h <- head_name(e)
    if (!is.na(h)) {
      if (!cold && h %in% c(banned, json)) hits <<- c(hits, h)
      if (!h %in% json) edges <<- c(edges, resolve(h))
      if (!cold && h %in% apply_heads) {
        for (j in seq_along(e)[-1]) if (!is_empty(e[[j]]) && is.name(e[[j]]) &&
            as.character(e[[j]]) %in% banned) hits <<- c(hits, as.character(e[[j]]))
      }
    }
    if (is.call(e[[1]]) && identical(e[[1]][[1]], as.name("$"))) {
      m <- as.character(e[[1]][[3]])
      if (!is.null(member_of[[m]])) edges <<- c(edges, member_of[[m]])
    }
    now_cold <- cold || (!is.na(h) && is_cold(h))
    nm <- names(e)
    for (i in seq_along(e)[-1]) {
      if (is_empty(e[[i]])) next
      a <- e[[i]]
      if (is_fun(a) && !is.null(nm) && nzchar(nm[[i]])) next
      if (is.call(a) && as.character(a[[1]])[1] %in% c("<-", "=", "<<-") && is_fun(a[[3]])) next
      walk(a, now_cold)
    }
    if (!is.name(e[[1]])) walk(e[[1]], cold)
  }
  walk(fn[[3]], FALSE)
  list(edges = unique(edges), hits = hits)
}
scanned <- setNames(lapply(ids, scan), ids)
# Declared edges: function-valued arguments the walker cannot resolve.
declared <- list(
  c("ledgr_plan_resolve", "ledgr_cost_resolver_from_model$resolver"),
  c("ledgr_availability_provider_from_plan$decision_view",
    "ledgr_availability_prepared_membership_from_plan$prepared_members_at"),
  c("ledgr_availability_provider_from_plan$decision_view",
    "ledgr_availability_prepared_membership_from_plan$prepared_resolve_at"))
for (d in declared) scanned[[d[[1]]]]$edges <- unique(c(scanned[[d[[1]]]]$edges, d[[2]]))

ctx_roots <- c(grep("\\.ledgr_(pulse_context|strategy_state_view)$", top, value = TRUE),
  grep("^ledgr_pulse_context_helper_bundle\\$", local, value = TRUE),
  "ledgr_strategy_result")
ctx_roots <- setdiff(ctx_roots, c("print.ledgr_pulse_context", "str.ledgr_pulse_context",
  "close.ledgr_pulse_context"))
ns <- readLines(file.path(pkg, "NAMESPACE"))
exports <- sub("^export\\((.*)\\)$", "\\1", grep("^export\\(", ns, value = TRUE))
helper_roots <- intersect(exports, top[node_file[top] %in% c("strategy-helpers.R",
  "sizing-evidence.R", "signal-strategy.R", "strategy-tools.R")])
roots <- switch(ring, stages = stage_roots, ctx = c(stage_roots, ctx_roots),
  helpers = c(stage_roots, ctx_roots, helper_roots))

seen <- character(); queue <- roots
while (length(queue)) {
  n <- queue[[1]]; queue <- queue[-1]
  if (n %in% seen || is.null(scanned[[n]])) next
  seen <- c(seen, n)
  queue <- c(queue, setdiff(scanned[[n]]$edges, seen))
}
rows <- do.call(rbind, lapply(seen, function(n) {
  h <- scanned[[n]]$hits
  if (!length(h)) return(NULL)
  t <- table(h)
  data.frame(node = n, file = node_file[[n]], call = names(t), count = as.integer(t))
}))
rows <- rows[order(rows$file, rows$node, rows$call), ]
write.csv(rows, file.path(out, paste0("baseline_", ring, ".csv")), row.names = FALSE)
writeLines(sort(seen), file.path(out, paste0("reachable_", ring, ".txt")))
cat(sprintf("[%s] roots %d; nodes %d (top %d, local %d); reachable %d; nodes with hits %d; hits %d\n",
  ring, length(roots), length(ids), length(top), length(local), length(seen),
  length(unique(rows$node)), sum(rows$count)))
print(setNames(aggregate(count ~ call, rows, sum), c("call", "count")), row.names = FALSE)

if (!is.na(rprof)) {
  lines <- readLines(rprof)[-1]
  stacks <- lapply(regmatches(lines, gregexpr('"[^"]*"', lines)), function(x) gsub('"', "", x))
  in_stage <- vapply(stacks, function(s) any(s %in% stage_roots), logical(1))
  dyn <- unique(unlist(lapply(stacks[in_stage], function(s) s[seq_len(which(s %in% stage_roots)[1])])))
  dyn_top <- intersect(dyn, top)
  reached_top <- unique(sub("\\$.*", "", seen))
  missed <- setdiff(dyn_top, c(seen, json))
  cat(sprintf("profiled ledgr functions under a stage: %d; missed by static walk: %d\n",
    length(dyn_top), length(missed)))
  if (length(missed)) print(missed)
}
