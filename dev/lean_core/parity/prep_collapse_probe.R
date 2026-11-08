# LDG-3216 scope: collapse vs base R for the three named operations, at
# 500 instruments and tile width 252 (500 x 5,040 shape).
#   1. working-tile derivation (carry fill per instrument across a tile)
#   2. one instrument's gathered feature input across tiles (row read)
#   3. multi-tile read assembly (a 500 x 63 window spanning two tiles)
set.seed(1)
n <- 500L; w <- 252L
reps <- 5000L
time_it <- function(f) {
  f(); gc()
  t0 <- proc.time()[["elapsed"]]
  for (r in seq_len(reps)) f()
  (proc.time()[["elapsed"]] - t0) / reps * 1e6
}
row <- list()
add <- function(op, impl, us, same) row[[length(row) + 1L]] <<- data.frame(op = op, impl = impl, us = round(us, 1), identical = same)

# 1. Carry fill: seeds with NA gaps, non-NA in column 1 (as prepared).
s <- matrix(rep(seq_len(w), each = n), n)
s[sample(length(s), length(s) %/% 3L)] <- NA_integer_
s[, 1L] <- 0L
base_locf <- function(s) {
  out <- s
  for (j in 2:ncol(out)) { na <- is.na(out[, j]); out[na, j] <- out[na, j - 1L] }
  out
}
col_locf <- function(s) matrix(as.integer(collapse::na_locf(as.vector(t(s)))), nrow = nrow(s), byrow = TRUE)
same <- identical(base_locf(s), col_locf(s))
add("carry_fill_tile", "base column sweep", time_it(function() base_locf(s)), same)
add("carry_fill_tile", "collapse::na_locf", time_it(function() col_locf(s)), same)

# 2/3. Tiles stored instrument-major; a request spanning tile edges.
tiles <- list(matrix(runif(n * w), n), matrix(runif(n * w), n))
j <- (w - 30L):(w + 32L)
tile <- (j - 1L) %/% w + 1L
gather <- function(i, splitter) {
  out <- matrix(NA_real_, length(i), length(j))
  for (at in splitter(seq_along(j), tile)) {
    k <- tile[[at[[1L]]]]
    out[, at] <- tiles[[k]][i, j[at] - (k - 1L) * w, drop = FALSE]
  }
  out
}
runs_split <- function(x, g) {
  # sorted tiles: contiguous runs, no hashing
  e <- c(which(diff(g) != 0L), length(g))
  b <- c(1L, e[-length(e)] + 1L)
  Map(function(a, z) x[a:z], b, e)
}
for (case in list(list(op = "feature_input_one_instrument", i = 17L),
                  list(op = "read_window_500x63", i = seq_len(n)))) {
  ref <- gather(case$i, split)
  add(case$op, "base split + [", time_it(function() gather(case$i, split)), TRUE)
  add(case$op, "collapse::gsplit + [", time_it(function() gather(case$i, collapse::gsplit)),
      identical(gather(case$i, collapse::gsplit), ref))
  add(case$op, "base runs + [", time_it(function() gather(case$i, runs_split)),
      identical(gather(case$i, runs_split), ref))
}
out <- do.call(rbind, row)
print(out, row.names = FALSE)
if (length(commandArgs(TRUE))) utils::write.csv(out, commandArgs(TRUE)[[1L]], row.names = FALSE)
# Usage: Rscript dev/lean_core/parity/prep_collapse_probe.R [out csv]
