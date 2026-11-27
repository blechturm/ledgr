# Switch probe (Cut 27 drafting): which R/ functions does only the old fold
# reach? A static call graph of the package namespace, before and after the
# lean fold replaces its two bindings (ledgr_fold_envelope and the pulse
# context's `$` method; ledgr_run_fold stays, minus its restart check).
#
#   Rscript reachability.R --lib=<installed release build> --tree=<its source tree> --out=<dir>
#
# Nodes are namespace functions. An edge f -> g when g's name appears in f's
# body as a symbol (codetools::findGlobals, nested functions included) or as a
# string literal (do.call, get, match.fun, registerS3method). Roots: exports,
# registered S3 methods, and names referenced from .onLoad/.onAttach. The
# lean fold is one node whose edges are the union over its production files
# (loop.R, plan.R, fifo.R, marks.R, facts.R, checks.R). Static analysis:
# dynamic dispatch the scan cannot see makes "unreachable" an upper bound on
# dead code, to be confirmed by the frozen test suite.
arg <- function(n) sub(paste0("^--", n, "="), "", grep(paste0("^--", n, "="), commandArgs(TRUE), value = TRUE)[[1L]])
lib <- normalizePath(arg("lib"), winslash = "/", mustWork = TRUE)
tree <- normalizePath(arg("tree"), winslash = "/", mustWork = TRUE)
out <- arg("out")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
.libPaths(unique(c(lib, "C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths())))
suppressPackageStartupMessages(library(ledgr))
ns <- asNamespace("ledgr")
fns <- Filter(function(n) is.function(get(n, envir = ns)), ls(ns, all.names = TRUE))

refs <- function(f) {
  g <- tryCatch(codetools::findGlobals(f, merge = TRUE), error = function(e) character())
  s <- unique(unlist(regmatches(deparse(f), gregexpr("\"[A-Za-z._][A-Za-z0-9._]*\"", deparse(f)))))
  intersect(c(g, gsub("\"", "", s)), fns)
}
edges <- lapply(stats::setNames(fns, fns), function(n) refs(get(n, envir = ns)))

# the lean fold: every production function, as one node
lean_files <- file.path(tree, "dev", "lean_core", c("loop.R", "plan.R", "fifo.R", "marks.R", "facts.R", "checks.R"))
lean_env <- new.env(parent = ns)
lean_env$.lean_debug <- FALSE
for (f in lean_files) sys.source(f, envir = lean_env, keep.source = FALSE)
# Closures the lean files define; not the package functions they capture
# (loop.R keeps the old envelope as the harness fallback) nor the harness
# installers (*_install), which the switch removes.
lean_fns <- Filter(function(n) is.function(lean_env[[n]]) && identical(environment(lean_env[[n]]), lean_env) && !grepl("_install$", n),
                   ls(lean_env, all.names = TRUE))
lean_refs <- unique(unlist(lapply(lean_fns, function(n) refs(lean_env[[n]]))))

roots <- getNamespaceExports(ns)
s3 <- get(".__S3MethodsTable__.", envir = ns)
s3_names <- ls(s3, all.names = TRUE)
roots <- intersect(unique(c(roots, s3_names, ".onLoad", ".onAttach")), fns)

reach <- function(edges, roots) {
  seen <- character(); todo <- roots
  while (length(todo)) {
    seen <- union(seen, todo)
    todo <- setdiff(unique(unlist(edges[todo])), seen)
  }
  seen
}
before <- reach(edges, roots)
after_edges <- edges
replaced <- c("ledgr_fold_envelope", "$.ledgr_pulse_context")   # ledgr_run_fold stays the package runner (minus its restart check)
for (r in intersect(replaced, fns)) after_edges[[r]] <- lean_refs
after <- reach(after_edges, roots)

# code lines per function, from the source tree (non-blank, non-comment)
lines_of <- list(); file_of <- list()
for (f in list.files(file.path(tree, "R"), pattern = "[.]R$", full.names = TRUE)) {
  exprs <- parse(f, keep.source = TRUE)
  src <- attr(exprs, "srcref")
  for (i in seq_along(exprs)) {
    e <- exprs[[i]]
    if (is.call(e) && as.character(e[[1L]]) %in% c("<-", "=") && length(e) == 3L &&
        is.call(e[[3L]]) && identical(e[[3L]][[1L]], as.name("function"))) {
      nm <- as.character(e[[2L]])
      txt <- as.character(src[[i]])
      lines_of[[nm]] <- sum(!grepl("^\\s*$", txt) & !grepl("^\\s*#", txt))
      file_of[[nm]] <- basename(f)
    }
  }
}
tab <- data.frame(fn = fns, stringsAsFactors = FALSE)
tab$file <- vapply(tab$fn, function(n) if (is.null(file_of[[n]])) NA_character_ else file_of[[n]], "")
tab$lines <- vapply(tab$fn, function(n) if (is.null(lines_of[[n]])) NA_real_ else lines_of[[n]], 0)
tab$reach_before <- tab$fn %in% before
tab$reach_after <- tab$fn %in% after
tab$lean_calls <- tab$fn %in% lean_refs
tab$status <- ifelse(tab$reach_before & !tab$reach_after, "old fold only",
              ifelse(!tab$reach_before, "unreached today", "kept"))
utils::write.csv(tab[order(tab$status, tab$file, tab$fn), ], file.path(out, "reachability.csv"), row.names = FALSE)

sm <- aggregate(lines ~ status, tab, sum)
cat("namespace functions:", length(fns), " roots:", length(roots), " lean production functions:", length(lean_fns),
    " package functions the lean fold calls:", length(lean_refs), "\n")
print(merge(as.data.frame(table(status = tab$status)), sm, all.x = TRUE), row.names = FALSE)
old <- tab[tab$status == "old fold only", ]
byfile <- aggregate(lines ~ file, old, sum)
byfile$functions <- as.vector(table(old$file)[byfile$file])
print(byfile[order(-byfile$lines), ], row.names = FALSE)
