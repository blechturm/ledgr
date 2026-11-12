# Text edits applied to dev/lean_core sources at load (LDG-3220, Cut 14 R2):
# the broken variants of loop_parity.R and the delegation arms of the
# shortcut timing runner. The tracked code holds no variant or arm branch.
#
# An edit names a file, the function it patches (by the name it is
# assigned to, nested functions included) and one exact anchor line inside
# that function, with lines inserted before or after it or replacing it. A
# missing function, or an anchor missing or repeated inside it, fails.

lean_edit <- function(file, fn, at, lines = character(), where = "replace", mark = TRUE) {
  stopifnot(where %in% c("replace", "before", "after"))
  list(file = file, fn = fn, at = at, lines = lines, where = where, mark = mark)
}

# Ranges of every name-assigned value in source lines `x` (name, first and
# last line); `fn` values are functions or, for a harness binding such as
# lean_sweep_impl, any assigned expression.
lean_assigned_ranges <- function(x) {
  pd <- utils::getParseData(parse(text = x, keep.source = TRUE))
  out <- list()
  for (p in pd$parent[pd$token == "LEFT_ASSIGN"]) {
    kids <- pd[pd$parent == p, ]
    kids <- kids[order(kids$line1, kids$col1), ]
    if (nrow(kids) != 3L) next
    lhs <- pd[pd$parent == kids$id[[1L]], ]
    if (nrow(lhs) != 1L || !identical(lhs$token, "SYMBOL")) next
    rhs <- pd[pd$parent == kids$id[[3L]], ]
    out[[length(out) + 1L]] <- data.frame(name = lhs$text, from = kids$line1[[3L]], to = kids$line2[[3L]],
                                          is_function = "FUNCTION" %in% rhs$token, stringsAsFactors = FALSE)
  }
  do.call(rbind, out)
}

# First and last line of the value assigned to `fn` in source lines `x`.
lean_fn_range <- function(x, fn) {
  a <- lean_assigned_ranges(x)
  hits <- a[a$name == fn, ]
  if (nrow(hits) != 1L) stop(sprintf("edit: function `%s` is assigned %d times", fn, nrow(hits)), call. = FALSE)
  c(hits$from, hits$to)
}

# Applies `edits` (all for one file) to its lines. The anchor must be unique
# inside `fn` and lie in `fn`'s own body: no named function nested in `fn`
# may contain it (the lexical function). `marker`, when given, is inserted
# with every edit whose `mark` is TRUE, so a run can show the edit ran; an
# edit with `mark = FALSE` carries its own marker where its fault executes.
lean_apply_edits <- function(x, edits, marker = NULL) {
  for (e in edits) {
    r <- lean_fn_range(x, e$fn)
    hit <- r[[1L]] - 1L + which(x[r[[1L]]:r[[2L]]] == e$at)
    if (length(hit) != 1L) {
      stop(sprintf("edit: anchor found %d times in `%s` (%s): %s", length(hit), e$fn, e$file, e$at), call. = FALSE)
    }
    a <- lean_assigned_ranges(x)
    inner <- a[a$is_function & a$name != e$fn & a$from >= r[[1L]] & a$to <= r[[2L]] & a$from <= hit & a$to >= hit, ]
    if (nrow(inner)) {
      stop(sprintf("edit: anchor lies in `%s`, nested in `%s` (%s): %s", inner$name[[which.min(inner$to - inner$from)]],
                   e$fn, e$file, e$at), call. = FALSE)
    }
    ins <- c(if (isTRUE(e$mark)) marker, e$lines)
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
