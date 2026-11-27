# The clarity pass changes no code (Cut 27 decision 4, LDG-3277): for each
# lean production file, the parsed code at the base commit, with the symbols
# s3 and s4 renamed to marks_state and facts_state, must be identical to the
# parsed code in the working tree. Parsing without source references drops
# every comment, so only comments and those two names may differ.
#   Rscript clarity_equiv.R --base=<commit> [--files=a.R,b.R]   exits 1 on a difference
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
lean <- normalizePath(file.path(here, ".."), winslash = "/")
repo <- normalizePath(file.path(lean, "..", ".."), winslash = "/")
arg <- function(n, d = NULL) { v <- grep(paste0("^--", n, "="), commandArgs(TRUE), value = TRUE); if (length(v)) sub(paste0("^--", n, "="), "", v[[1L]]) else d }
base <- arg("base")
files <- strsplit(arg("files", "loop.R,plan.R,checks.R,fifo.R,prepare.R,loop_harness.R,marks.R,facts.R"), ",")[[1L]]
renames <- c(s3 = "marks_state", s4 = "facts_state")
rename <- function(e) {
  if (is.symbol(e)) {
    n <- as.character(e)
    if (nzchar(n) && n %in% names(renames)) return(as.name(renames[[n]]))
    return(e)
  }
  if (is.call(e) || is.pairlist(e)) {
    for (i in seq_along(e)) if (!is.null(e[[i]]) && !(is.symbol(e[[i]]) && !nzchar(as.character(e[[i]])))) e[[i]] <- rename(e[[i]])
    if (is.pairlist(e) && !is.null(names(e))) names(e) <- ifelse(names(e) %in% names(renames), renames[names(e)], names(e))
    return(e)
  }
  e
}
bad <- 0L
for (f in files) {
  old <- system2("git", c("-C", repo, "show", paste0(base, ":dev/lean_core/", f)), stdout = TRUE)
  a <- lapply(parse(text = old, keep.source = FALSE), rename)
  b <- as.list(parse(file.path(lean, f), keep.source = FALSE))
  same <- identical(length(a), length(b)) && all(mapply(identical, a, b))
  if (!same) {
    bad <- bad + 1L
    k <- if (length(a) == length(b)) which(!mapply(identical, a, b))[[1L]] else NA
    cat(sprintf("%-15s DIFFERS (expressions %d vs %d; first differing top-level expression %s)\n", f, length(a), length(b), k))
  } else cat(sprintf("%-15s code identical (%d top-level expressions)\n", f, length(b)))
}
cat(if (bad) "CLARITY EQUIVALENCE FAIL" else "CLARITY EQUIVALENCE PASS", "\n")
quit(status = if (bad) 1L else 0L)
