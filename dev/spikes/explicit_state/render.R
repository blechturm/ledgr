# Renders loop.R as the transform rewrites it, comments kept (LDG-3278
# readability evidence). The transform's rewrites are token-local (a
# concern symbol becomes `<concern>$name`, a rewritten `<<-` becomes `<-`),
# plus the concern objects' creation lines and the snapshot lines; the
# rendered envelope is parsed back and must be identical to the
# transform's AST, so the rendering is the fork, not a hand edit.
#   Rscript render.R --set=commit|all [--out=<dir>]
# Writes <out>/loop_<set>.R (scratch) and, to the evidence directory,
# render_<set>.csv (line counts, long lines, rewrites) and
# stage_concerns_<set>.csv (which concern objects each stage touches).
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
arg <- function(name, default) {
  hit <- grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)
  if (!length(hit)) return(default)
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
set <- arg("set", "commit")
out <- arg("out", "C:/Users/maxth/ledgr-wt/cut27-scratch/spike/render")
evidence <- file.path(here, "evidence")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
source(file.path(here, "transform.R"))
loop <- normalizePath(file.path(here, "..", "..", "lean_core", "loop.R"), winslash = "/")
src <- readLines(loop, warn = FALSE, encoding = "UTF-8")
envelope_of <- function(exprs) {
  for (x in exprs) if (is.call(x) && identical(x[[1L]], as.name("<-")) && identical(x[[2L]], as.name("lean_fold_envelope_plain")))
    return(eval(x[[3L]], new.env()))
  stop("lean_fold_envelope_plain not found")
}
plain <- envelope_of(parse(text = src, keep.source = FALSE))
fork <- es_transform(plain, es_sets[[set]])
info <- attr(fork, "es")
attr(fork, "es") <- NULL
map <- info$map

# the envelope's tokens, in source order
pd <- utils::getParseData(parse(text = src, keep.source = TRUE))
pd <- pd[pd$terminal, ]
pd <- pd[order(pd$line1, pd$col1), ]
start <- grep("^lean_fold_envelope_plain <- function", src)
stop_line <- which(src == "}")
stop_line <- stop_line[stop_line > start][[1L]]
pd <- pd[pd$line1 >= start & pd$line2 <= stop_line, ]
prev <- c("", pd$token[-nrow(pd)])
sym <- pd[pd$token == "SYMBOL" & pd$text %in% names(map) & !prev %in% c("'$'", "'@'"), ]
if (!identical(sym$text, substring(info$visits, 2L))) {
  stop(sprintf("render: %d concern symbols in the source, %d visits; first mismatch at %d", nrow(sym), length(info$visits),
               which(c(sym$text, rep("", 1000)) != c(substring(info$visits, 2L), rep("", 1000)))[[1L]]))
}
sup <- pd[pd$token == "LEFT_ASSIGN" & pd$text == "<<-", ]
if (nrow(sup) != length(info$supers)) stop("render: <<- tokens and visits differ")
edits <- rbind(
  data.frame(line = sym$line1, col1 = sym$col1, col2 = sym$col2,
             text = paste0(map[sym$text], "$", sym$text), stringsAsFactors = FALSE)[substring(info$visits, 1L, 1L) != "k", ],
  data.frame(line = sup$line1, col1 = sup$col1, col2 = sup$col2, text = "<-", stringsAsFactors = FALSE)[info$supers == "1", ])
edits <- edits[order(edits$line, -edits$col1), ]
x <- src
for (k in seq_len(nrow(edits))) {
  e <- edits[k, ]
  s <- x[[e$line]]
  x[[e$line]] <- paste0(substr(s, 1L, e$col1 - 1L), e$text, substr(s, e$col2 + 1L, nchar(s)))
}
# insertions, bottom up: snapshots after their function's header, then the concern objects
ins <- list()
for (f in grep("^snapshot ", info$findings, value = TRUE)) {
  fn <- sub(".* inserted in ([A-Za-z0-9_.]+) .*", "\\1", f)
  nm <- sub("^snapshot `([^ ]+) <- .*", "\\1", f)
  at <- grep(paste0("^\\s*", fn, " <- function"), x)
  ind <- sub("^(\\s*).*", "\\1", x[[at]])
  ins[[length(ins) + 1L]] <- list(at = at, lines = paste0(ind, "  ", nm, " <- ", map[[nm]], "$", nm,
    "   # snapshot: a local assignment below shadows it on a marked run"))
}
ins[[length(ins) + 1L]] <- list(at = start, lines = c("  # Explicit stage state: each concern's shared variables, by field.",
  paste0("  ", names(es_sets[[set]]), " <- new.env(hash = TRUE, parent = emptyenv())")))
for (i in ins[order(-vapply(ins, `[[`, 0, "at"))]) x <- append(x, i$lines, after = i$at)
writeLines(x, file.path(out, paste0("loop_", set, ".R")))

# the rendering is the fork
rendered <- envelope_of(parse(text = x, keep.source = FALSE))
same <- identical(body(rendered), body(fork)) && identical(formals(rendered), formals(fork))
if (!same) stop("render: the rendered envelope differs from the transform's AST")
end_r <- start + length(x) - length(src)
env_lines <- function(v, a, b) v[a:b]
stats <- data.frame(set = set, loop_lines_before = length(src), loop_lines_after = length(x),
  envelope_lines_before = stop_line - start + 1L, envelope_lines_after = stop_line - start + 1L + length(x) - length(src),
  lines_over_120_before = sum(nchar(src) > 120L), lines_over_120_after = sum(nchar(x) > 120L),
  chars_before = sum(nchar(src)), chars_after = sum(nchar(x)),
  rewritten_reads = info$reads, rewritten_superassignments = info$writes, rewritten_envelope_assignments = info$top_assignments,
  superassignments_left = sum(info$supers == "0"), rendering_identical_to_ast = same, stringsAsFactors = FALSE)
utils::write.csv(stats, file.path(evidence, paste0("render_", set, ".csv")), row.names = FALSE)
print(stats, row.names = FALSE)

# stage x concern object: what each stage closure (and helper) touches
fns <- Filter(function(z) is.call(z) && identical(z[[1L]], as.name("<-")) && is.symbol(z[[2L]]) && is.call(z[[3L]]) &&
                identical(z[[3L]][[1L]], as.name("function")), as.list(body(fork)))
sc <- do.call(rbind, lapply(fns, function(z) {
  used <- intersect(names(es_sets[[set]]), all.names(z[[3L]]))
  if (!length(used)) return(NULL)
  data.frame(fn = as.character(z[[2L]]), concerns = paste(used, collapse = " "),
             fields = paste(sort(unique(unlist(lapply(used, function(o) {
               hits <- character()
               walk <- function(e) {
                 if (!is.call(e)) return(invisible())
                 if (identical(e[[1L]], as.name("$")) && identical(e[[2L]], as.name(o))) hits <<- c(hits, paste0(o, "$", as.character(e[[3L]])))
                 for (k in seq_along(e)) if (!es_missing(e[[k]])) walk(e[[k]])
               }
               walk(z[[3L]])
               hits
             })))), collapse = " "), stringsAsFactors = FALSE)
}))
utils::write.csv(sc, file.path(evidence, paste0("stage_concerns_", set, ".csv")), row.names = FALSE)
