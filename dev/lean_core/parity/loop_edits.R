# Text edits applied to dev/lean_core sources at load (LDG-3220, Cut 14 R2):
# the broken variants of loop_parity.R and the delegation arms of the
# shortcut timing runner. The tracked code holds no variant or arm branch.
#
# An edit names a file, the function it patches (by the name it is
# assigned to, nested functions included) and one exact anchor line inside
# that function, with lines inserted before or after it or replacing it. A
# missing function, or an anchor missing or repeated inside it, fails.

lean_edit <- function(file, fn, at, lines = character(), where = "replace") {
  stopifnot(where %in% c("replace", "before", "after"))
  list(file = file, fn = fn, at = at, lines = lines, where = where)
}

# First and last line of the value assigned to `fn` in source lines `x`.
lean_fn_range <- function(x, fn) {
  pd <- utils::getParseData(parse(text = x, keep.source = TRUE))
  hits <- list()
  for (p in pd$parent[pd$token == "LEFT_ASSIGN"]) {
    kids <- pd[pd$parent == p, ]
    kids <- kids[order(kids$line1, kids$col1), ]
    if (nrow(kids) != 3L) next
    lhs <- pd[pd$parent == kids$id[[1L]], ]
    if (nrow(lhs) == 1L && identical(lhs$token, "SYMBOL") && identical(lhs$text, fn)) {
      hits[[length(hits) + 1L]] <- c(kids$line1[[3L]], kids$line2[[3L]])
    }
  }
  if (length(hits) != 1L) stop(sprintf("edit: function `%s` is assigned %d times", fn, length(hits)), call. = FALSE)
  hits[[1L]]
}

# Applies `edits` (all for one file) to its lines; `marker`, when given, is
# inserted with every edit so a run can show the edited code was reached.
lean_apply_edits <- function(x, edits, marker = NULL) {
  for (e in edits) {
    r <- lean_fn_range(x, e$fn)
    hit <- r[[1L]] - 1L + which(x[r[[1L]]:r[[2L]]] == e$at)
    if (length(hit) != 1L) {
      stop(sprintf("edit: anchor found %d times in `%s` (%s): %s", length(hit), e$fn, e$file, e$at), call. = FALSE)
    }
    ins <- c(marker, e$lines)
    x <- switch(e$where,
      replace = c(x[seq_len(hit - 1L)], ins, x[-seq_len(hit)]),
      before = c(x[seq_len(hit - 1L)], ins, x[hit:length(x)]),
      after = c(x[seq_len(hit)], ins, x[-seq_len(hit)]))
  }
  x
}

# Evaluates every file named in `edits`, edited, into `env`.
lean_load_edited <- function(env, home, edits, marker = NULL) {
  for (file in unique(vapply(edits, `[[`, "", "file"))) {
    x <- readLines(file.path(home, file))
    x <- lean_apply_edits(x, Filter(function(e) identical(e$file, file), edits), marker)
    eval(parse(text = x, keep.source = FALSE), envir = env)
  }
  invisible(env)
}
