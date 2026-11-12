# Probe: what each mechanism of the lean loop's skeleton costs alone, in
# nanoseconds per operation, and whether a write costs more as the written
# vector grows (a copy) or stays flat (in place).
#
#   Rscript dev/spikes/skeleton_floor/probe.R <out.csv>
#
# Every pattern runs `iters` operations inside one byte-compiled function;
# "call" patterns subtract an empty call of the same shape.

out <- commandArgs(TRUE)[[1L]]
iters <- 2e5L
time_ns <- function(f) {
  f()                                     # warm, JIT
  t <- vapply(1:5, function(r) system.time(f())[["elapsed"]], numeric(1))
  stats::median(t) / iters * 1e9
}
cmp <- compiler::cmpfun

patterns <- function(L) {
  idx <- (seq_len(iters) %% L) + 1L
  list(
    local_write = function() { x <- numeric(L); for (k in seq_len(iters)) x[[idx[[k]]]] <- 1; x },
    super_write = function() {
      x <- numeric(L); g <- function(j) x[[j]] <<- 1
      for (k in seq_len(iters)) g(idx[[k]]); x },
    super_list_column = function() {
      fl <- list(a = numeric(L), b = numeric(L)); g <- function(j) fl$a[[j]] <<- 1
      for (k in seq_len(iters)) g(idx[[k]]); fl },
    super_list_range = function() {
      fl <- list(a = numeric(L), b = numeric(L)); g <- function(j) fl$a[j:(j)] <<- 1
      for (k in seq_len(iters)) g(idx[[k]]); fl },
    super_matrix_row = function() {
      m <- matrix(NA_real_, L, 6L); g <- function(j) m[j, ] <<- c(1, 2, 3, 4, 5, 6)
      for (k in seq_len(iters)) g(idx[[k]]); m },
    env_column = function() {
      e <- new.env(parent = emptyenv()); e$a <- numeric(L); g <- function(j) e$a[[j]] <- 1
      for (k in seq_len(iters)) g(idx[[k]]); e },
    empty_call = function() {
      x <- numeric(L); g <- function(j) NULL
      for (k in seq_len(iters)) g(idx[[k]]); x }
  )
}

flat <- function() {
  hooks <- list(uncovered = function() character())
  live <- new.env(parent = emptyenv())
  n <- 0L
  list(
    empty_loop = function() { for (k in seq_len(iters)) NULL },
    call_5_args = function() { g <- function(a, b, c, d, e) NULL; for (k in seq_len(iters)) g(k, 1, 2, 3, 4) },
    list_handoff = function() {
      g <- function(v) v$pv
      for (k in seq_len(iters)) { v <- list(col = k, close = 1, pv = 2); g(v) } },
    hook_call = function() { for (k in seq_len(iters)) if (length(hooks$uncovered())) stop("x") },
    try_catch = function() { g <- function() 1; for (k in seq_len(iters)) tryCatch(g(), error = function(e) stop(e)) },
    try_catch_prebuilt_handler = function() { g <- function() 1; h <- function(e) stop(e); for (k in seq_len(iters)) tryCatch(g(), error = h) },
    try_catch_no_handler = function() { g <- function() 1; for (k in seq_len(iters)) tryCatch(g()) },
    calling_handlers = function() { g <- function() 1; h <- function(e) stop(e); for (k in seq_len(iters)) withCallingHandlers(g(), error = h) },
    try_catch_around_loop = function() { g <- function() 1; h <- function(e) stop(e); tryCatch(for (k in seq_len(iters)) g(), error = h) },
    plain_call0 = function() { g <- function() 1; for (k in seq_len(iters)) g() },
    env_scalar_write = function() { for (k in seq_len(iters)) live$cur_stage <- "valuation" },
    super_scalar = function() { g <- function() n <<- n + 1L; for (k in seq_len(iters)) g() }
  )
}

rows <- list()
for (L in c(1e3L, 1e4L, 1e5L)) {
  for (nm in names(p <- patterns(L))) {
    rows[[length(rows) + 1L]] <- data.frame(pattern = nm, length = L, ns_per_op = time_ns(cmp(p[[nm]])))
  }
}
for (nm in names(p <- flat())) {
  rows[[length(rows) + 1L]] <- data.frame(pattern = nm, length = NA_integer_, ns_per_op = time_ns(cmp(p[[nm]])))
}
res <- do.call(rbind, rows)
res$ns_per_op <- round(res$ns_per_op, 1)
utils::write.csv(res, out, row.names = FALSE)
print(res, row.names = FALSE)
