# Cut preparation for the hashed-frame cut (macro WS16, 2026-11-16).
# Three questions the spike did not ask, on toy bodies and on loop.R's text:
#  (a) an early return() in a non-tail if-block, and on.exit(), inside a
#      compiled body evaluated in a hashed environment (loop.R's coverage
#      refusal returns the pin's envelope this way);
#  (b) a body-local binding named like a base function under
#      compiler::compile(), against cmpfun();
#  (c) the time to compile the envelope's body once per load.
# Usage: Rscript dev/spikes/hashed_frame/cut_prep.R [out.txt]
args <- commandArgs(TRUE)
out <- if (length(args)) args[[1L]] else "dev/spikes/hashed_frame/evidence/cut_prep.txt"
lines <- character()
say <- function(...) lines <<- c(lines, paste0(...))

# (a) early return and on.exit
plain_a <- function(x, log) {
  if (x < 0) {
    log$v <- c(log$v, "early")
    return("refused")
  }
  on.exit(log$v <- c(log$v, "exit"), add = TRUE)
  log$v <- c(log$v, "body")
  x + 1
}
code_a <- compiler::compile(body(plain_a), env = environment(plain_a))
hashed_a <- compiler::cmpfun(function(x, log) eval(code_a, new.env(hash = TRUE, parent = environment())))
ok_a <- TRUE
for (x in c(-1, 1)) {
  la <- new.env(); lb <- new.env()
  ra <- plain_a(x, la); rb <- hashed_a(x, lb)
  same <- identical(ra, rb) && identical(la$v, lb$v)
  ok_a <- ok_a && same
  say("(a) x=", x, ": plain ", deparse(ra), " [", paste(la$v, collapse = ","), "], hashed ",
      deparse(rb), " [", paste(lb$v, collapse = ","), "], identical ", same)
}

# (b) base-name shadowing
plain_b <- function(n) {
  length <- function(x) 99
  seq_len <- function(x) "mine"
  list(length(1:3), seq_len(n))
}
code_b <- compiler::compile(body(plain_b), env = environment(plain_b))
hashed_b <- function(n) eval(code_b, new.env(hash = TRUE, parent = environment()))
rb_plain <- plain_b(2); rb_cmp <- compiler::cmpfun(plain_b)(2); rb_hashed <- hashed_b(2)
ok_b <- identical(rb_plain, rb_cmp) && identical(rb_plain, rb_hashed) && identical(rb_hashed[[1L]], 99)
say("(b) local length() and seq_len(): plain ", deparse(rb_plain), "; cmpfun identical ",
    identical(rb_plain, rb_cmp), "; compiled body identical ", identical(rb_plain, rb_hashed))

# (c) compile time of the envelope body (loop.R as committed)
ex <- parse("dev/lean_core/loop.R", keep.source = FALSE)
e <- new.env(parent = globalenv())
for (x in ex) if (is.call(x) && identical(x[[1L]], as.name("<-")) && identical(x[[2L]], as.name("lean_fold_envelope"))) eval(x, e)
f <- e$lean_fold_envelope
secs <- replicate(5L, system.time(compiler::compile(body(f), env = environment(f)))[["elapsed"]])
say("(c) compile seconds, 5 runs: ", paste(format(secs, nsmall = 2), collapse = " "), "; median ", median(secs))
say("R ", R.version$major, ".", R.version$minor, "; loop.R at ", system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE))
writeLines(lines, out)
cat(lines, sep = "\n")
if (!ok_a || !ok_b) quit(status = 1L)
