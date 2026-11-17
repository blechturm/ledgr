# Candidate 6 (engine-version census), step 1: the call graph by execution
# of codetools over the pinned namespace. Lists every ledgr namespace
# function reachable from the feature calculation, sweep preparation and
# projection roots, and whether ledgr_feature_engine_version() names it.
# The hand classification (category, bound_by) is in census.csv; this file
# only proves which helpers are reachable and which are named.
#
#   Rscript census_walk.R --lib=<pinned library> --out=<csv>

arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)[[1L]])
.libPaths(c(arg("lib"), .libPaths()))
library(ledgr)
ns <- asNamespace("ledgr")
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
repo <- normalizePath(file.path(here, "..", "..", ".."), winslash = "/")

fns <- Filter(function(n) is.function(get(n, ns)), ls(ns, all.names = TRUE))
callees <- function(f) {
  g <- codetools::findGlobals(f, merge = TRUE)
  sort(intersect(g, fns))
}

# Names the engine version hashes: every symbol in its body that is a
# namespace function passed to ledgr_function_fingerprint() or helper().
ev_body <- body(ns$ledgr_feature_engine_version)
hashed <- character()
walk_ev <- function(e) {
  if (is.call(e)) {
    head <- as.character(e[[1L]])[[1L]]
    if (head %in% c("ledgr_function_fingerprint", "helper") && length(e) >= 2L && is.symbol(e[[2L]])) {
      hashed <<- c(hashed, as.character(e[[2L]]))
    }
    for (a in as.list(e)[-1L]) walk_ev(a)
  }
}
walk_ev(ev_body)
hashed <- unique(hashed)

# Roots: the run path, the sweep path, explicit precompute's projection, the
# history-read evidence entry and the emitted indicator closures (their
# called helpers are not captured by the indicator fingerprint, which hashes
# variables, not called functions).
roots <- c("ledgr_history_compute_feature_series", "ledgr_history_precompute_payload",
           "ledgr_projection_from_feature_matrix", "ledgr_projection_from_payload",
           "ledgr_history_feature_planes", "ledgr_precompute_feature_def_from_indicator")
closure_roots <- list(
  sma = ledgr::ledgr_ind_sma(3), ema = ledgr::ledgr_ind_ema(3), rsi = ledgr::ledgr_ind_rsi(3),
  returns = ledgr::ledgr_ind_returns(1), ttr = ledgr::ledgr_ind_ttr("SMA", input = "close", n = 3L))
reached <- list()
queue <- lapply(roots, function(r) list(name = r, via = r))
for (k in names(closure_roots)) for (slot in c("fn", "series_fn")) {
  for (callee in callees(closure_roots[[k]][[slot]])) queue[[length(queue) + 1L]] <- list(name = callee, via = paste0(k, "$", slot))
}
while (length(queue)) {
  item <- queue[[1L]]; queue <- queue[-1L]
  if (!is.null(reached[[item$name]])) next
  reached[[item$name]] <- item$via
  for (callee in callees(get(item$name, ns))) {
    if (is.null(reached[[callee]])) queue[[length(queue) + 1L]] <- list(name = callee, via = item$via)
  }
}

# file:line from the checkout's R/ (identical to the pin for these files).
src <- list.files(file.path(repo, "R"), pattern = "[.]R$", full.names = TRUE)
where <- character()
for (f in src) {
  lines <- readLines(f, warn = FALSE)
  hit <- regmatches(lines, regexec("^([A-Za-z0-9_.]+) <- function", lines))
  for (i in which(lengths(hit) == 2L)) where[[hit[[i]][[2L]]]] <- paste0("R/", basename(f), ":", i)
}
out <- data.frame(helper = names(reached), first_root = unlist(reached, use.names = FALSE),
                  location = unname(where[names(reached)]), named_in_engine_version = names(reached) %in% hashed,
                  stringsAsFactors = FALSE)
out <- out[order(out$location, method = "radix"), ]
utils::write.csv(out, arg("out"), row.names = FALSE)
cat("reachable:", nrow(out), " named:", sum(out$named_in_engine_version), "\n")
cat("named but not reachable:", paste(setdiff(hashed, out$helper), collapse = ", "), "\n")
