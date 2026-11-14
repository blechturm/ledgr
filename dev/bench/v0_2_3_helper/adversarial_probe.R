# Cut 17 (WS35 final check): the adversarial probe set written by the final
# Codex check (2026-11-14), kept as a regression witness. One arm per run:
#   Rscript dev/bench/v0_2_3_helper/adversarial_probe.R --arm=pin|candidate --lib=<library> --out=<dir>
# then adversarial_compare.R --out=<dir>. 1,382 cases: names() methods returning lists,
# classed, dimensioned and named characters, factors, numeric and logical vectors;
# class-preserving as.double(); plain, classed, named and matrix universes and keeps;
# 4-ID and 40-ID universes; both verbs, the four strategy types and the validators;
# four string encodings (UTF-8, latin1, bytes, unknown). Traces every collapse::fmatch() call.
args <- commandArgs(TRUE)
opt <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), args, value = TRUE)[[1L]])
out <- opt("out"); dir.create(out, recursive = TRUE, showWarnings = FALSE)
arm <- opt("arm")
lib <- opt("lib")
suppressPackageStartupMessages(library(ledgr, lib.loc = lib))
cat("loaded:", getNamespaceInfo(asNamespace("ledgr"), "path"), "\n")
cat("installed:", readLines(file.path(lib, "LEDGR_INSTALLED_FROM_COMMIT")), "\n")
cat("R:", R.version.string, "collapse:", as.character(packageVersion("collapse")), "\n")

# All methods are pure and shared by the two arms. The numeric conversion
# deliberately retains the amount class and its unusual names() method.
names.review_payload <- function(x) attr(x, "emitted_names", exact = TRUE)
as.double.review_payload <- function(x, ...) x
names.review_mask <- names.review_payload
as.logical.review_mask <- function(x, ...) x
new_payload <- function(x, nm, logical = FALSE) {
  structure(x, names = as.character(nm), emitted_names = nm,
            class = if (logical) "review_mask" else "review_payload")
}
plain <- function(x) is.character(x) && is.null(attributes(x))
trace_records <- list()
probe_case <- ""
trace("fmatch", where = asNamespace("collapse"), print = FALSE,
      tracer = quote({
        .GlobalEnv$trace_records[[length(.GlobalEnv$trace_records) + 1L]] <-
          list(case = .GlobalEnv$probe_case, x = x, table = table,
               x_plain = .GlobalEnv$plain(x), table_plain = .GlobalEnv$plain(table),
               calls = vapply(sys.calls(), function(z) paste(deparse(z), collapse = " "), ""))
      }))
cond <- function(c) {
  if (is.null(c)) return(NULL)
  f <- unclass(c)
  list(class = class(c), message = conditionMessage(c), call = conditionCall(c),
       parent = cond(f$parent), fields = f[setdiff(names(f), c("trace", "parent", "message", "call"))],
       field_names = setdiff(names(f), "trace"))
}
results <- list()
record <- function(id, expr, data) {
  probe_case <<- id
  e <- list2env(data, parent = globalenv())
  notes <- new.env(parent = emptyenv())
  if (exists("ctx", envir = e, inherits = FALSE)) e$ctx$.notes <- notes
  signals <- list()
  value <- NULL
  error <- tryCatch({
    value <- withCallingHandlers(eval(expr, e),
      warning = function(w) { signals[[length(signals) + 1L]] <<- list(type = "warning", condition = cond(w)); invokeRestart("muffleWarning") },
      message = function(w) { signals[[length(signals) + 1L]] <<- list(type = "message", condition = cond(w)); invokeRestart("muffleMessage") })
    NULL
  }, error = function(e) cond(e))
  results[[id]] <<- list(value = value, error = error, signals = signals, notes = as.list(notes, all.names = TRUE))
}
mk_ctx <- function(u) {
  n <- length(u)
  list(universe = u, equity = 10000, close = rep(10, n), position = rep(1, n),
       holding_value = rep(10, n), member = rep(TRUE, n), buyable = rep(TRUE, n))
}
wraps <- list(plain = identity, named = function(x) setNames(x, paste0("n", seq_along(x))),
              classed = function(x) structure(x, class = "review_ids"),
              matrix = function(x) matrix(x, ncol = 1L))
name_wraps <- c(wraps, list(list = as.list, factor = factor))
amount_fn <- getFromNamespace("ledgr_target_named_amount", "ledgr")
logical_fn <- getFromNamespace("ledgr_target_logical", "ledgr")
keep_fn <- getFromNamespace("ledgr_target_keep", "ledgr")
check_fn <- getFromNamespace("ledgr_strategy_type_check_names", "ledgr")
for (n in c(4L, 40L)) {
  for (family in c("ids", "numeric", "logical")) {
    u0 <- switch(family, ids = sprintf("P%02d", n:1), numeric = as.character(seq_len(n)),
                 logical = c("TRUE", "FALSE", sprintf("P%02d", seq_len(n - 2L))))
    sel <- u0[c(2L, 1L)]
    modes <- if (family == "ids") names(name_wraps) else family
    for (umode in names(wraps)) for (mode in modes) {
      u <- wraps[[umode]](u0)
      nm <- if (mode == "numeric") as.numeric(sel) else if (mode == "logical") as.logical(sel) else name_wraps[[mode]](sel)
      fullnm <- if (mode == "numeric") as.numeric(u0) else if (mode == "logical") u0 else name_wraps[[mode]](u0)
      amount <- new_payload(c(0.2, 0.1), nm)
      mask <- new_payload(rep(c(TRUE, FALSE), length.out = n), fullnm, TRUE)
      ctx <- mk_ctx(u)
      base <- paste(n, family, umode, mode, sep = "/")
      d <- list(ctx = ctx, amount = amount, mask = mask, u = u, keep = sel, exit = setNames(u0 %in% sel, u0))
      record(paste0(base, "/amount"), quote(amount_fn(amount, "weights", u)), d)
      record(paste0(base, "/logical"), quote(logical_fn(mask, u, "exit")), d)
      record(paste0(base, "/check"), quote(check_fn(amount, "x", u)), d)
      for (verb in c("rebalance", "adjust")) {
        expr <- if (verb == "rebalance") quote(ledgr_target_rebalance(ctx, weights = amount, capital_base = "total_equity")) else
          quote(ledgr_target_adjust(ctx, weights = amount))
        record(paste0(base, "/", verb, "/value"), expr, d)
        expr <- if (verb == "rebalance") quote(ledgr_target_rebalance(ctx, weights = amount, keep = keep, capital_base = "total_equity")) else
          quote(ledgr_target_adjust(ctx, weights = amount, exit = exit))
        record(paste0(base, "/", verb, "/overlap"), expr, d)
      }
      record(paste0(base, "/adjust/add"), quote(ledgr_target_adjust(ctx, add_value = amount)), d)
      record(paste0(base, "/adjust/weighted_added"), quote(ledgr_target_adjust(ctx, weights = amount, add_value = amount)), d)
      # Competing invalidities check that the early buyability refusal wins.
      d$ctx$buyable[1L] <- FALSE
      record(paste0(base, "/adjust/precedence"), quote(ledgr_target_adjust(ctx, weights = amount, add_value = amount, exit = exit)), d)
      for (type in c("ledgr_signal", "ledgr_selection", "ledgr_weights", "ledgr_target")) {
        d$x <- if (type == "ledgr_selection") mask else amount
        record(paste0(base, "/", type), substitute(FUN(x, universe = u), list(FUN = as.name(type))), d)
      }
    }
  }
  # Keeps and universes have their own gates, independent of amount names.
  u0 <- sprintf("P%02d", n:1)
  for (umode in names(wraps)) for (kmode in names(wraps)) {
    u <- wraps[[umode]](u0)
    keep <- wraps[[kmode]](u0[c(2L, 1L)])
    ctx <- mk_ctx(u)
    ctx$member[1:3] <- FALSE
    d <- list(u = u, ctx = ctx, keep = keep, amount = setNames(c(0.2, 0.1), u0[c(4L, 3L)]))
    base <- paste(n, "keep", umode, kmode, sep = "/")
    record(paste0(base, "/validator"), quote(keep_fn(keep, u)), d)
    for (policy in c("sell", "keep")) {
      d$policy <- policy
      record(paste0(base, "/", policy), quote(ledgr_target_rebalance(ctx, keep = keep, index_leavers = policy, capital_base = "total_equity")), d)
      record(paste0(base, "/", policy, "/overlap"), quote(ledgr_target_rebalance(ctx, weights = amount, keep = keep, index_leavers = policy, capital_base = "total_equity")), d)
    }
    record(paste0(base, "/missing_policy"), quote(ledgr_target_rebalance(ctx, keep = keep)), d)
  }
  # Skips, zero weights, priced additions, unavailable additions, and logical keep.
  u <- u0
  ctx <- mk_ctx(u)
  ctx$close[c(1L, 3L)] <- NA_real_
  d <- list(u = u, ctx = ctx, w = setNames(c(0.2, 0, 0.1), u[1:3]),
            a = setNames(c(100, 50), u[3:4]), k = setNames(seq_len(n) == 4L, u))
  record(paste0(n, "/derived/rebalance"), quote(ledgr_target_rebalance(ctx, weights = w, keep = k, capital_base = "total_equity")), d)
  record(paste0(n, "/derived/adjust"), quote(ledgr_target_adjust(ctx, weights = w)), d)
  record(paste0(n, "/derived/add"), quote(ledgr_target_adjust(ctx, add_value = a)), d)
}

# Encoding variants are plain characters and must be proved, not gated out.
utf <- enc2utf8("caf\u00e9")
latin <- iconv(utf, "UTF-8", "latin1")
bytes <- latin
Encoding(bytes) <- "bytes"
unknown <- latin
Encoding(unknown) <- "unknown"
variants <- list(utf8 = utf, latin1 = latin, bytes = bytes, unknown = unknown)
primitive <- list()
attempt <- function(expr) tryCatch(list(value = force(expr)), error = function(e) list(error = cond(e)))
for (xn in names(variants)) for (tn in names(variants)) {
  x <- c(variants[[xn]], "P01")
  table <- c(variants[[tn]], "P01", sprintf("P%02d", 2:39))
  probe_case <- paste("encoding_match", xn, tn, sep = "/")
  primitive[[probe_case]] <- list(base = attempt(match(x, table)), fast = attempt(collapse::fmatch(x, table)),
    base0 = attempt(match(x, table, 0L)), fast0 = attempt(collapse::fmatch(x, table, 0L)))
  for (n in c(4L, 40L)) {
    u <- table[seq_len(n)]
    ctx <- mk_ctx(u)
    d <- list(ctx = ctx, u = u, w = setNames(c(0.2, 0.1), x), k = x,
      mask = setNames(rep(TRUE, n), c(variants[[xn]], table[2:n])))
    base <- paste("encoding", n, xn, tn, sep = "/")
    record(paste0(base, "/amount"), quote(amount_fn(w, "weights", u)), d)
    record(paste0(base, "/logical"), quote(logical_fn(mask, u, "exit")), d)
    record(paste0(base, "/keep"), quote(keep_fn(k, u)), d)
    record(paste0(base, "/rebalance"), quote(ledgr_target_rebalance(ctx, weights = w, capital_base = "total_equity")), d)
    record(paste0(base, "/adjust"), quote(ledgr_target_adjust(ctx, weights = w)), d)
    for (type in c("ledgr_signal", "ledgr_selection", "ledgr_weights", "ledgr_target")) {
      d$x <- if (type == "ledgr_selection") d$mask else d$w
      record(paste0(base, "/", type), substitute(FUN(x, universe = u), list(FUN = as.name(type))), d)
    }
  }
}
saveRDS(list(results = results, trace = trace_records, primitive = primitive), file.path(out, paste0("probe_", arm, ".rds")))
bad <- which(!vapply(trace_records, function(r) r$x_plain && r$table_plain, TRUE))
cat("cases:", length(results), "values:", sum(vapply(results, function(r) is.null(r$error), TRUE)), "\n")
cat("fmatch calls:", length(trace_records), "nonplain:", length(bad), "\n")
cat("primitive mismatches:", sum(vapply(primitive, function(r) !identical(r$base, r$fast) || !identical(r$base0, r$fast0), TRUE)), "\n")
if (length(bad)) print(trace_records[bad])
untrace("fmatch", where = asNamespace("collapse"))
sink()
