# The shared envelope state each stage closure reads and writes (Cut 27
# decision 4, LDG-3277): for E and P1 to P5 inside lean_fold_envelope_plain,
# the free variables it reads from the envelope frame (codetools) and the
# frame variables it writes with `<<-`. Functions are left out of the reads.
#   Rscript stage_state.R [--out=<csv>]
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
loop <- file.path(here, "..", "loop.R")
pd <- utils::getParseData(parse(loop, keep.source = TRUE))
txt <- readLines(loop, warn = FALSE, encoding = "UTF-8")
stages <- c(E = "lean_e_advance", P1 = "lean_p1_value", P2 = "lean_p2_decide", P3 = "lean_p3_plan",
            P4 = "lean_p4_apply", P5 = "lean_p5_commit")
# The envelope's own local names: everything it assigns with `<-` (its frame).
env_fn <- function(name) {
  sym <- pd[pd$token == "SYMBOL" & pd$text == name, ]
  for (k in seq_len(nrow(sym))) {
    a <- pd[pd$id == pd$parent[pd$id == sym$parent[[k]]], ]
    kids <- pd[pd$parent == a$id, ]
    kids <- kids[order(kids$line1, kids$col1), ]
    if (nrow(kids) == 3L && kids$token[[2L]] == "LEFT_ASSIGN" && kids$text[[2L]] == "<-") {
      rhs <- kids[3L, ]
      return(paste(txt[rhs$line1:rhs$line2], collapse = "\n"))
    }
  }
  NA_character_
}
# Frame variables a stage reads although it also assigns them locally: a name
# used before an unconditional top-level local assignment, or assigned from
# itself (pos <- pos[ctx_pos] on a marked run), reads the envelope value on
# the runs where the local assignment is skipped or not yet made. codetools
# counts such a name as local and leaves it out.
conditional_reads <- function(f, frame) {
  used <- function(e) all.names(e, functions = FALSE)
  defined <- names(formals(f))
  reads <- character()
  for (s in as.list(body(f))[-1L]) {
    if (is.call(s) && identical(s[[1L]], as.name("<-")) && is.symbol(s[[2L]])) {
      reads <- c(reads, setdiff(used(s[[3L]]), defined))
      defined <- c(defined, as.character(s[[2L]]))
    } else {
      reads <- c(reads, setdiff(used(s), defined))
    }
  }
  sort(unique(intersect(reads, frame)))
}
writes_of <- function(e) {
  out <- character()
  walk <- function(x) {
    if (is.call(x)) {
      if (identical(x[[1L]], as.name("<<-"))) {
        lhs <- x[[2L]]
        while (is.call(lhs)) lhs <- lhs[[2L]]
        out <<- c(out, as.character(lhs))
      }
      args <- as.list(x)[-1L]
      for (i in seq_along(args)) if (!identical(args[[i]], quote(expr = ))) walk(args[[i]])   # skip empty arguments, x[, 1]
    }
  }
  walk(e)
  sort(unique(out))
}
env_src <- env_fn("lean_fold_envelope_plain")
envelope <- eval(parse(text = env_src)[[1L]])
body_exprs <- as.list(body(envelope))[-1L]
frame <- unique(unlist(lapply(body_exprs, function(x) if (is.call(x) && identical(x[[1L]], as.name("<-")) && is.symbol(x[[2L]])) as.character(x[[2L]]))))
# Frame variables that hold environments (created with new.env() or a
# *_run_state() constructor): a stage that assigns one's fields writes
# envelope state by reference, which `<<-` targets do not show.
env_vars <- unique(unlist(lapply(body_exprs, function(e) {
  if (is.call(e) && identical(e[[1L]], as.name("<-")) && is.symbol(e[[2L]]) && is.call(e[[3L]])) {
    head <- as.character(e[[3L]][[1L]])[[1L]]
    if (identical(head, "new.env") || grepl("_run_state$", head)) as.character(e[[2L]])
  }
})))
field_writes_of <- function(e) {
  out <- character()
  walk <- function(x) {
    if (is.call(x)) {
      if (as.character(x[[1L]])[[1L]] %in% c("<-", "<<-", "=") && is.call(x[[2L]])) {
        lhs <- x[[2L]]
        while (is.call(lhs)) lhs <- lhs[[2L]]
        if (is.symbol(lhs) && as.character(lhs) %in% env_vars) out <<- c(out, as.character(lhs))
      }
      args <- as.list(x)[-1L]
      for (i in seq_along(args)) if (!identical(args[[i]], quote(expr = ))) walk(args[[i]])
    }
  }
  walk(e)
  sort(unique(out))
}
rows <- list()
for (s in names(stages)) {
  src <- env_fn(stages[[s]])
  if (is.na(src)) { cat("not found:", stages[[s]], "\n"); next }
  f <- eval(parse(text = src)[[1L]])
  g <- codetools::findGlobals(f, merge = FALSE)
  reads <- sort(union(intersect(g$variables, setdiff(frame, stages)), setdiff(conditional_reads(f, frame), stages)))
  calls <- sort(intersect(g$functions, frame))
  w <- sort(union(writes_of(body(f)), field_writes_of(body(f))))
  envs <- intersect(reads, env_vars)
  rows[[s]] <- data.frame(stage = s, fn = stages[[s]], reads = paste(reads, collapse = " "),
                          writes = paste(w, collapse = " "), environments = paste(envs, collapse = " "), calls = paste(calls, collapse = " "), stringsAsFactors = FALSE)
  cat(sprintf("%-3s %-16s\n  reads:  %s\n  writes: %s\n  calls:  %s\n", s, stages[[s]], paste(reads, collapse = " "),
              paste(w, collapse = " "), paste(calls, collapse = " ")))
}
out <- grep("^--out=", commandArgs(TRUE), value = TRUE)
if (length(out)) utils::write.csv(do.call(rbind, rows), sub("^--out=", "", out), row.names = FALSE)
