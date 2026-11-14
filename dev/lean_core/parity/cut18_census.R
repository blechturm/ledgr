# Cut 18 (LDG-3234): the source census of the lean loop's per-pulse
# orchestration and its inventory checker.
#
#   Rscript dev/lean_core/parity/cut18_census.R --mode=census [--commit=<sha>] --out=<census.csv>
#   Rscript dev/lean_core/parity/cut18_census.R --mode=check --commit=<sha>
#     [--census=<csv>] [--inventory=<csv>] [--statements=<csv>]
#   Rscript dev/lean_core/parity/cut18_census.R --mode=selftest --commit=<sha>
#
# Roots (Cut 18, LDG-3234): run_loop(), the stage functions E and P1-P5,
# context construction (lean_context()) and the strategy/context read
# boundary (lean_ctx_dollar(), the context helpers), and lean_plan_pulse().
# Every lean-owned function a root reaches by a lexical call (a function
# assigned by name in loop.R or plan.R, nested closures included) is added;
# calls into package or user code are recorded as boundaries; edges resolved
# at run time (closures stored in the context or hooks) are listed in
# cut18_dynamic_edges and reviewed in the inventory. A site is a lexical call
# (SYMBOL_FUNCTION_CALL), an operator or a replacement call (assignment,
# extraction, arithmetic, comparison, logic) in the reached functions; a
# site is an allocation/copy candidate by the rule list cut18_alloc_rules.
# Debug-only sites (inside an `if (.lean_debug)` branch) are kept and marked.
# A site's identity is file|function|line:col|token|text; it belongs to the
# top-level statement of its lexical function that contains it.

cut18_roots <- c("run_loop", "lean_p1_value", "lean_p2_decide", "lean_p3_plan", "lean_p4_apply", "lean_p5_commit",
                 "lean_e_advance", "lean_context", "lean_ctx_dollar", "lean_ctx_helpers", "lean_strategy_view",
                 "lean_plan_pulse")
# Edges no lexical call shows: closures built in a pulse and called later.
cut18_dynamic_edges <- data.frame(
  from = c("lean_context", "lean_context", "lean_context", "lean_p2_decide", "lean_p2_decide", "lean_p3_plan"),
  to = c("feature_fn", "schedule_fn", "lean_ctx_helpers", "check_uncovered", "lean_ctx_dollar", "lean_exec_view"),
  how = c("lean_context() calls feature_fn(); the closure it returns is ctx$.feature_vector, read by the strategy",
          "ctx$.schedule_query is schedule_fn(i); called only by a strategy that queries the schedule",
          "ctx$flat and ctx$hold are lean_ctx_helpers() closures, called by the strategy",
          "check_uncovered() calls hooks$uncovered() (loop_harness.R or the inert hooks)",
          "every ctx$name read by the strategy dispatches to $.ledgr_pulse_context, bound to lean_ctx_dollar()",
          "lean_exec_view is a closure defined in the envelope and called in P3"),
  stringsAsFactors = FALSE)
cut18_operators <- c("'+'", "'-'", "'*'", "'/'", "'^'", "EQ", "NE", "GT", "LT", "GE", "LE", "'!'", "AND", "AND2", "OR", "OR2",
                     "LEFT_ASSIGN", "EQ_ASSIGN", "'$'", "'['", "LBB", "'@'", "':'", "SPECIAL")
cut18_alloc_rules <- c("list", "c", "rep", "rep.int", "rep_len", "numeric", "integer", "logical", "character", "vector",
                       "matrix", "list2env", "new.env", "function", "as.numeric", "as.integer", "as.logical", "as.character",
                       "unname", "names<-", "setNames", "stats::setNames", "seq_len", "seq_along", "which", "paste", "paste0",
                       "sprintf", "lapply", "vapply", "unlist", "unclass", "structure", "canonical_json", "length<-")

cut18_parse <- function(lines, file) {
  pd <- utils::getParseData(parse(text = lines, keep.source = TRUE))
  pd$file <- file
  pd
}

# Every function assigned by name: name, expr id of the FUNCTION expression, lines.
cut18_functions <- function(pd) {
  out <- list()
  for (p in pd$parent[pd$token == "LEFT_ASSIGN"]) {
    kids <- pd[pd$parent == p, ]; kids <- kids[order(kids$line1, kids$col1), ]
    if (nrow(kids) != 3L) next
    lhs <- pd[pd$parent == kids$id[[1L]], ]
    if (nrow(lhs) != 1L || !identical(lhs$token, "SYMBOL")) next
    rhs <- pd[pd$parent == kids$id[[3L]], ]
    if (!"FUNCTION" %in% rhs$token) next
    out[[length(out) + 1L]] <- data.frame(name = lhs$text, fid = kids$id[[3L]], from = kids$line1[[3L]], to = kids$line2[[3L]],
                                          file = pd$file[[1L]], stringsAsFactors = FALSE)
  }
  do.call(rbind, out)
}

cut18_ancestors <- function(pd, id) {
  out <- integer(); par <- stats::setNames(pd$parent, pd$id)
  while (!is.na(id) && id != 0L) { out <- c(out, id); id <- par[[as.character(id)]] }
  out
}

# The census of a pair of source texts (loop.R, plan.R).
cut18_census <- function(loop_lines, plan_lines) {
  pds <- list(loop.R = cut18_parse(loop_lines, "loop.R"), plan.R = cut18_parse(plan_lines, "plan.R"))
  fns <- do.call(rbind, lapply(pds, cut18_functions))
  if (anyDuplicated(fns$name)) stop("cut18: a function name is assigned twice: ", paste(fns$name[duplicated(fns$name)], collapse = ", "))
  lexical <- function(pd, id) {   # innermost named function containing token id
    anc <- cut18_ancestors(pd, id); hit <- fns[fns$file == pd$file[[1L]] & fns$fid %in% anc, ]
    if (!nrow(hit)) return(NA_character_)
    hit$name[[which.max(match(hit$fid, anc) * -1L + 1e6)]]
  }
  # reach: roots plus every lean function lexically called, plus reviewed dynamic edges
  reach <- cut18_roots; frontier <- cut18_roots
  calls_of <- function(name) {
    f <- fns[fns$name == name, ]; pd <- pds[[f$file]]
    toks <- pd[pd$token == "SYMBOL_FUNCTION_CALL" & pd$line1 >= f$from & pd$line2 <= f$to, ]
    unique(toks$text[vapply(toks$id, function(i) identical(lexical(pd, i), name), TRUE)])
  }
  while (length(frontier)) {
    nxt <- character()
    for (nm in frontier) {
      callees <- intersect(c(calls_of(nm), cut18_dynamic_edges$to[cut18_dynamic_edges$from == nm]), fns$name)
      nxt <- c(nxt, setdiff(callees, reach)); reach <- union(reach, callees)
    }
    frontier <- unique(nxt)
  }
  sites <- list(); all_stmts <- list()
  for (nm in reach) {
    f <- fns[fns$name == nm, ]; pd <- pds[[f$file]]
    body_ids <- pd$id[pd$parent == f$fid & pd$token == "expr"]
    body <- body_ids[length(body_ids)]                       # the function body expression
    braced <- any(pd$parent == body & pd$token == "'{'")
    stmts <- if (braced) pd[pd$parent == body & pd$token == "expr", ] else pd[pd$id == body, ]  # one statement without `{`
    stmts <- stmts[order(stmts$line1, stmts$col1), ]
    all_stmts[[nm]] <- data.frame(statement = sprintf("%s|%s|%d", f$file, nm, seq_len(nrow(stmts))), fn = nm,
      line = stmts$line1, text = substr(vapply(stmts$id, function(i) gsub("\\s+", " ", utils::getParseText(pd, i)), ""), 1L, 120L),
      stringsAsFactors = FALSE)
    tok <- pd[(pd$token == "SYMBOL_FUNCTION_CALL" | pd$token %in% cut18_operators) & pd$line1 >= f$from & pd$line2 <= f$to, ]
    for (r in seq_len(nrow(tok))) {
      id <- tok$id[[r]]
      if (!identical(lexical(pd, id), nm)) next
      anc <- cut18_ancestors(pd, id)
      k <- which(stmts$id %in% anc)
      if (length(k) != 1L) next                               # a formal's default value, not a statement
      # inside the consequent of `if (.lean_debug ...)` (the condition itself is production)
      debug <- any(vapply(seq_along(anc)[-1L], function(j) {
        a <- anc[[j]]
        kids <- pd[pd$parent == a, ]; kids <- kids[order(kids$line1, kids$col1), ]
        nrow(kids) >= 5L && identical(kids$token[[1L]], "IF") && identical(anc[[j - 1L]], kids$id[[5L]]) &&
          grepl("^\\.lean_debug($|[^A-Za-z0-9_.])", utils::getParseText(pd, kids$id[[3L]]))
      }, TRUE))
      text <- tok$text[[r]]
      if (tok$token[[r]] == "LEFT_ASSIGN") {
        lhs <- pd[pd$parent == tok$parent[[r]], ]; lhs <- lhs[order(lhs$line1, lhs$col1), ][1L, ]
        if (any(pd$token[pd$parent == lhs$id] %in% c("'['", "LBB", "'$'", "SYMBOL_FUNCTION_CALL", "'@'"))) text <- paste0(text, " (replacement)")
      }
      sites[[length(sites) + 1L]] <- data.frame(
        site = sprintf("%s|%s|%d:%d|%s|%s", f$file, nm, tok$line1[[r]], tok$col1[[r]], tok$token[[r]], tok$text[[r]]),
        file = f$file, fn = nm, line = tok$line1[[r]], col = tok$col1[[r]], token = tok$token[[r]], text = text,
        statement = sprintf("%s|%s|%d", f$file, nm, k), statement_line = stmts$line1[[k]],
        debug = debug, alloc = text %in% cut18_alloc_rules || tok$token[[r]] == "FUNCTION",
        boundary = tok$token[[r]] == "SYMBOL_FUNCTION_CALL" && !text %in% fns$name, stringsAsFactors = FALSE)
    }
  }
  out <- do.call(rbind, sites)
  # A function called only from debug sites (and not a root or dynamic edge
  # target) is debug-only as a whole.
  repeat {
    calls <- out[out$token == "SYMBOL_FUNCTION_CALL" & out$text %in% out$fn, ]
    prod_called <- unique(c(cut18_roots, cut18_dynamic_edges$to, calls$text[!calls$debug]))
    flip <- out$fn %in% setdiff(unique(out$fn), prod_called) & !out$debug
    if (!any(flip)) break
    out$debug[flip] <- TRUE
  }
  out <- out[order(out$file, out$line, out$col), ]
  st <- do.call(rbind, all_stmts)
  st$debug_fn <- !st$fn %in% out$fn[!out$debug]
  attr(out, "statements") <- st[order(st$statement), ]
  out
}

cut18_source_at <- function(repo, commit, file) {
  if (is.null(commit)) return(readLines(file.path(repo, "dev/lean_core", file), warn = FALSE))
  system2("git", c("-C", repo, "show", paste0(commit, ":dev/lean_core/", file)), stdout = TRUE)
}

# Inventory check: a bijection between the census and the inventory, every
# row classified, no duplicate identities.
cut18_check <- function(census, inventory, statements) {
  fail <- character()
  if (anyDuplicated(inventory$site)) fail <- c(fail, sprintf("duplicate inventory site: %s", inventory$site[duplicated(inventory$site)][[1L]]))
  missing <- setdiff(census$site, inventory$site); extra <- setdiff(inventory$site, census$site)
  if (length(missing)) fail <- c(fail, sprintf("%d census sites have no inventory row, first: %s", length(missing), missing[[1L]]))
  if (length(extra)) fail <- c(fail, sprintf("%d inventory rows name no census site, first: %s", length(extra), extra[[1L]]))
  need <- c("statement", "stage_cell", "kind", "owner_guarantee", "disposition", "routing")
  blank <- inventory$site[apply(inventory[need], 1L, function(v) any(is.na(v) | !nzchar(v)))]
  if (length(blank)) fail <- c(fail, sprintf("%d inventory rows are not classified, first: %s", length(blank), blank[[1L]]))
  all_st <- attr(census, "statements")$statement
  unclassified <- setdiff(all_st, statements$statement)
  if (length(unclassified)) fail <- c(fail, sprintf("%d census statements have no classification, first: %s", length(unclassified), unclassified[[1L]]))
  if (anyDuplicated(paste(statements$statement, statements$lines))) fail <- c(fail, "a statement or line range is classified twice")
  stale <- setdiff(statements$statement, all_st)
  if (length(stale)) fail <- c(fail, sprintf("%d classified statements are not in the census, first: %s", length(stale), stale[[1L]]))
  ok_kind <- c("invariant", "contract", "forwards", "package", "record", "local", "debug")
  bad <- setdiff(unique(statements$kind), ok_kind)
  if (length(bad)) fail <- c(fail, paste("unknown kind:", paste(bad, collapse = ", ")))
  ok_disp <- c("keep", "remove", "rewrite", "debug_move", "out_of_scope")
  bad <- setdiff(unique(statements$disposition), ok_disp)
  if (length(bad)) fail <- c(fail, paste("unknown disposition:", paste(bad, collapse = ", ")))
  fail
}

# The inventory: every census site with its classification row, the
# narrowest row of its statement whose `lines` range ("from-to", or empty
# for the whole statement) contains the site's line.
cut18_inventory <- function(census, statements) {
  pick <- function(st, line) {
    r <- statements[statements$statement == st, ]
    if (!nrow(r)) return(NA_integer_)
    lo <- ifelse(nzchar(r$lines), as.integer(sub("-.*", "", r$lines)), -Inf)
    hi <- ifelse(nzchar(r$lines), as.integer(sub(".*-", "", r$lines)), Inf)
    ok <- which(line >= lo & line <= hi)
    if (!length(ok)) return(NA_integer_)
    as.integer(rownames(r)[ok[which.min((hi - lo)[ok])]])
  }
  rownames(statements) <- seq_len(nrow(statements))
  idx <- mapply(pick, census$statement, as.integer(census$line))
  cls <- statements[idx, setdiff(names(statements), "statement")]
  rownames(cls) <- NULL
  inv <- cbind(census, cls)
  inv[order(inv$file, as.integer(inv$line), as.integer(inv$col)), ]
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  opt <- function(name, default = NULL) {
    hit <- grep(paste0("^--", name, "="), args, value = TRUE)
    if (length(hit)) sub(paste0("^--", name, "="), "", hit[[1L]]) else default
  }
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
  repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")
  source(file.path(here, "loop_edits.R"))
  ev <- file.path(here, "evidence", "cut18")
  commit <- opt("commit")
  census <- cut18_census(cut18_source_at(repo, commit, "loop.R"), cut18_source_at(repo, commit, "plan.R"))
  mode <- opt("mode", "census")
  if (mode == "census") {
    out_csv <- opt("out", file.path(ev, "census.csv"))
    utils::write.csv(census, out_csv, row.names = FALSE)
    utils::write.csv(attr(census, "statements"), file.path(dirname(out_csv), "census_statements.csv"), row.names = FALSE)
    cat(sprintf("census: %d sites in %d statements of %d functions (%d debug, %d boundary calls, %d allocation candidates)\n",
                nrow(census), length(unique(census$statement)), length(unique(census$fn)), sum(census$debug),
                sum(census$boundary), sum(census$alloc)))
    quit(status = 0L)
  }
  rd <- function(f) utils::read.csv(f, stringsAsFactors = FALSE, colClasses = "character")
  frozen <- rd(opt("census", file.path(ev, "census.csv")))
  statements <- rd(opt("statements", file.path(ev, "statements.csv")))
  inventory <- rd(opt("inventory", file.path(ev, "inventory.csv")))
  if (mode == "check") {
    fail <- character()
    if (!identical(frozen$site, census$site)) fail <- c(fail, "the frozen census differs from the census of the named commit")
    frozen_st <- rd(file.path(dirname(opt("census", file.path(ev, "census.csv"))), "census_statements.csv"))
    if (!identical(frozen_st$statement, attr(census, "statements")$statement)) fail <- c(fail, "the frozen statement list differs from the named commit's")
    fail <- c(fail, cut18_check(census, inventory, statements))
    if (length(fail)) { cat("CHECK FAILED\n", paste0("- ", fail, "\n"), sep = ""); quit(status = 1L) }
    cat(sprintf("CHECK PASSED: %d sites, %d statements, bijection with the inventory\n", nrow(census), nrow(statements)))
    quit(status = 0L)
  }
  if (mode == "selftest") {
    helper <- inventory$site[inventory$fn == "lean_loop_add_sizing"][[1L]]
    omitted <- cut18_check(census, inventory[inventory$site != helper, ], statements)
    stale <- inventory[1L, ]; stale$site <- "loop.R|lean_p1_value|1:1|SYMBOL_FUNCTION_CALL|gone"
    extra <- cut18_check(census, rbind(inventory, stale), statements)
    ok <- any(grepl("have no inventory row", omitted)) && any(grepl("name no census site", extra))
    cat("omitted helper site:", omitted[[1L]], "\nextra stale row:", extra[[1L]], "\n")
    quit(status = if (ok) 0L else 1L)
  }
}
