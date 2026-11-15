# Names bound at the top level of lean_fold_envelope's body (its frame), by commit or path.
args <- commandArgs(TRUE)
root <- "C:/Users/maxth/Documents/GitHub/ledgr"
get_names <- function(spec) {
  txt <- if (file.exists(spec)) readLines(spec) else system2("git", c("-C", root, "show", paste0(spec, ":dev/lean_core/loop.R")), stdout = TRUE)
  e <- new.env()
  for (x in parse(text = txt, keep.source = FALSE)) if (is.call(x) && identical(x[[1L]], as.name("<-")) &&
      identical(x[[2L]], as.name("lean_fold_envelope"))) fn <- x[[3L]]
  b <- as.list(fn[[3L]])[-1L]
  out <- character()
  walk <- function(s) {
    if (!is.call(s)) return()
    h <- as.character(s[[1L]])[[1L]]
    if (h %in% c("<-", "=") && is.name(s[[2L]])) out <<- c(out, as.character(s[[2L]]))
    if (h %in% c("if", "{")) for (k in as.list(s)[-1L]) walk(k)
  }
  for (s in b) walk(s)
  c(names(fn[[2L]]), unique(out))
}
a <- get_names(args[[1L]]); b <- get_names(args[[2L]])
cat(length(a), "->", length(b), "
added:", setdiff(b, a), "
removed:", setdiff(a, b), "
"); if (length(args) > 2L) print(b)
