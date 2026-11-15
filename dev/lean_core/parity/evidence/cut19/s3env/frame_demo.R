# How the number of bindings in an enclosing function frame affects lookups
# made by a closure defined inside it. Compiled like the lean loop.
make_run <- function(extra, hashed) {
  body_fn <- function() {
    pos <- c(1, 2, 3)                       # an early variable, like the loop's state
    for (j in seq_len(extra)) assign(paste0("v", j), j)   # later variables
    step <- function() sum(pos) + length(pos)   # pos: frame variable; sum, length: base functions
    function(n) { s <- 0; for (i in seq_len(n)) s <- s + step(); s }
  }
  if (hashed) {
    # the same code, but its variables live in a hashed environment
    e <- new.env(hash = TRUE)
    environment(body_fn) <- e
    evalq({
      pos <- c(1, 2, 3)
      for (j in seq_len(extra)) assign(paste0("v", j), j)
      step <- function() sum(pos) + length(pos)
      function(n) { s <- 0; for (i in seq_len(n)) s <- s + step(); s }
    }, envir = list2env(list(extra = extra), envir = e))
  } else body_fn()
}
time_it <- function(extra, hashed) {
  run <- compiler::cmpfun(make_run(extra, hashed))
  run(1e4)
  n <- 1e6
  t <- system.time(run(n))[["elapsed"]]
  1e9 * t / n   # nanoseconds per step() call
}
for (extra in c(0, 12, 140, 1000)) {
  cat(sprintf("%5d extra bindings: plain frame %6.0f ns per call, hashed %6.0f ns per call\n", extra,
              time_it(extra, FALSE), time_it(extra, TRUE)))
}
