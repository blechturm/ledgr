# Copy probe (LDG-3278 timing diagnosis): which per-pulse write forms the
# transform produces copy a pulse-length vector. For n writes into vectors of
# length n, an in-place form grows linearly (4x n: ~4x time) and a copying
# one quadratically (~16x). Each form runs inside a closure
# nested in an envelope function, as the stages do.
#   Rscript copy_probe.R [--out=<csv>]
arg_out <- sub("^--out=", "", grep("^--out=", commandArgs(TRUE), value = TRUE))
forms <- list(
  super_vector = function(n) { x <- numeric(n); f <- function(i) x[[i]] <<- i; for (i in seq_len(n)) f(i); x },
  super_list_field = function(n) { eq <- list(ts = numeric(n)); f <- function(i) eq$ts[[i]] <<- i; for (i in seq_len(n)) f(i); eq },
  super_matrix_row = function(n) { m <- matrix(0, n, 6L); f <- function(i) m[i, ] <<- rep(i, 6L); for (i in seq_len(n)) f(i); m },
  env_vector = function(n) { s <- new.env(hash = TRUE, parent = emptyenv()); s$x <- numeric(n)
    f <- function(i) s$x[[i]] <- i; for (i in seq_len(n)) f(i); s$x },
  env_list_field = function(n) { s <- new.env(hash = TRUE, parent = emptyenv()); s$eq <- list(ts = numeric(n))
    f <- function(i) s$eq$ts[[i]] <- i; for (i in seq_len(n)) f(i); s$eq },
  env_matrix_row = function(n) { s <- new.env(hash = TRUE, parent = emptyenv()); s$m <- matrix(0, n, 6L)
    f <- function(i) s$m[i, ] <- rep(i, 6L); for (i in seq_len(n)) f(i); s$m },
  # alternatives (not in the fork): detach, modify, reattach; and a list
  # state passed in and returned (the ticket's "takes and returns" shape)
  env_detach = function(n) { s <- new.env(hash = TRUE, parent = emptyenv()); s$x <- numeric(n)
    f <- function(i) { x <- s$x; s$x <- NULL; x[[i]] <- i; s$x <- x }; for (i in seq_len(n)) f(i); s$x },
  list_in_out = function(n) { st <- list(x = numeric(n)); f <- function(st, i) { st$x[[i]] <- i; st }
    for (i in seq_len(n)) st <- f(st, i); st }
)
time_form <- function(f, n) { f <- compiler::cmpfun(f); f(10L); t0 <- proc.time()[["elapsed"]]; f(n); proc.time()[["elapsed"]] - t0 }
rows <- do.call(rbind, lapply(names(forms), function(nm) {
  t1 <- time_form(forms[[nm]], 5000L)
  t2 <- time_form(forms[[nm]], 20000L)
  data.frame(form = nm, seconds_n5000 = t1, seconds_n20000 = t2, growth_4x_n = round(t2 / max(t1, 1e-3), 1),
             stringsAsFactors = FALSE)
}))
print(rows, row.names = FALSE)
if (length(arg_out)) utils::write.csv(rows, arg_out, row.names = FALSE)
