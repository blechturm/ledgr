# Unwrapped per-call cost of reading a working plane through `[` against a
# plain matrix, 500 instruments x 5,040 sessions, width 252, inst-major.
# Evidence for the whole-planes amendment: it needs the tile prepare.R, so
# run it from a checkout of e17559aa; the current prepare.R has no tiles.
S <- commandArgs(TRUE)[[1L]]  # scratch dir holding ws16/lib-d5b3a151
repo <- normalizePath(".")
source(file.path(repo, "dev/lean_core/load.R"))
lean <- lean_core_load(file.path(S, "ws16/lib-d5b3a151"), debug = FALSE)
lean$lean_prep$orient <- "inst"
n <- 500L; t <- 5040L; w <- 252L
full <- matrix(rnorm(n * t) > 0, n, t)
p <- lean$lean_working_plane(n, t, w, TRUE, function(k) full[, lean$lean_tile_cols(p, k), drop = FALSE])
rows <- seq_len(n)
reps <- 3000L
bench <- function(f) { f(); t0 <- proc.time()[["elapsed"]]; for (r in seq_len(reps)) f(); (proc.time()[["elapsed"]] - t0) / reps * 1e6 }
out <- list()
for (fast in c(FALSE, TRUE)) for (len in c(21L, 63L, 252L)) {
  lean$lean_prep$fast_gather <- fast
  cols <- (2600L - len + 1L):2600L  # crosses the tile edge at 2520 for 252
  stopifnot(identical(p[rows, cols, drop = FALSE], full[rows, cols, drop = FALSE]))
  out[[length(out) + 1L]] <- data.frame(fast = fast, cols = len,
    plain_us = round(bench(function() full[rows, cols, drop = FALSE]), 1),
    lean_us = round(bench(function() p[rows, cols, drop = FALSE]), 1),
    tile_get_us = round(bench(function() lean$lean_tile_get(p, 11L)), 1))
}
print(do.call(rbind, out), row.names = FALSE)
