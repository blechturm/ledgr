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
rows <- list()
for (s in names(stages)) {
  src <- env_fn(stages[[s]])
  if (is.na(src)) { cat("not found:", stages[[s]], "\n"); next }
  f <- eval(parse(text = src)[[1L]])
  g <- codetools::findGlobals(f, merge = FALSE)
  reads <- sort(intersect(g$variables, setdiff(frame, stages)))
  calls <- sort(intersect(g$functions, frame))
  w <- writes_of(body(f))
  rows[[s]] <- data.frame(stage = s, fn = stages[[s]], reads = paste(reads, collapse = " "),
                          writes = paste(w, collapse = " "), calls = paste(calls, collapse = " "), stringsAsFactors = FALSE)
  cat(sprintf("%-3s %-16s\n  reads:  %s\n  writes: %s\n  calls:  %s\n", s, stages[[s]], paste(reads, collapse = " "),
              paste(w, collapse = " "), paste(calls, collapse = " ")))
}
out <- grep("^--out=", commandArgs(TRUE), value = TRUE)
if (length(out)) utils::write.csv(do.call(rbind, rows), sub("^--out=", "", out), row.names = FALSE)
