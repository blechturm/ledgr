# Dense instrument x session planes vs ragged per-instrument lifetimes.
# Synthetic data only. Times one pulse cross-section and two history windows.
suppressMessages(library(microbenchmark))
set.seed(1)

make_ragged <- function(n_inst, n_axis, life_min, life_max) {
  len <- if (life_min == life_max) rep.int(life_min, n_inst) else sample(life_min:life_max, n_inst, TRUE)
  len <- pmin(len, n_axis)
  start <- vapply(len, function(l) sample.int(n_axis - l + 1L, 1L), 1L)
  end <- start + len - 1L
  offset <- c(0L, cumsum(len)[-n_inst])
  list(start = start, end = end, offset = offset,
       v = runif(sum(len), 10, 100), n_inst = n_inst, n_axis = n_axis)
}
to_dense <- function(r) {
  m <- matrix(NA_real_, r$n_inst, r$n_axis)
  len <- r$end - r$start + 1L
  i <- rep.int(seq_len(r$n_inst), len)
  t <- sequence(len, from = r$start)
  m[i + (t - 1L) * r$n_inst] <- r$v
  m
}

# Reads. `rows` is the live decision axis (given by the fold, not computed here).
dense_pulse  <- function(m, rows, t) m[rows, t]
ragged_pulse <- function(r, rows, t) r$v[r$offset[rows] + (t - r$start[rows]) + 1L]
dense_hist   <- function(m, rows, t, L) t(m[rows, (t - L + 1L):t, drop = FALSE])
ragged_hist  <- function(r, rows, t, L) {
  base <- r$offset[rows] + (t - r$start[rows]) + 1L
  idx <- rep(base, each = L) + rep.int(seq.int(-(L - 1L), 0L), length(rows))
  matrix(r$v[idx], nrow = L)          # time rows x instrument columns
}

# Compact dense tiles: per block of TT sessions, a matrix over the instruments
# alive in that block, plus a global-row -> tile-row map.
make_tiles <- function(r, m, TT) {
  K <- (r$n_axis - 1L) %/% TT + 1L
  t0 <- (seq_len(K) - 1L) * TT + 1L
  t1 <- pmin(t0 + TT - 1L, r$n_axis)
  tiles <- vector("list", K); maps <- vector("list", K)
  for (k in seq_len(K)) {
    rows_k <- which(r$start <= t1[k] & r$end >= t0[k])
    tiles[[k]] <- m[rows_k, t0[k]:t1[k], drop = FALSE]
    mp <- rep(NA_integer_, r$n_inst); mp[rows_k] <- seq_along(rows_k)
    maps[[k]] <- mp
  }
  list(m = tiles, map = maps, t0 = t0, t1 = t1, TT = TT)
}
tile_pulse <- function(tl, rows, t) {
  k <- (t - 1L) %/% tl$TT + 1L
  tl$m[[k]][tl$map[[k]][rows], t - tl$t0[k] + 1L]
}
tile_hist <- function(tl, rows, t, L) {
  s <- t - L + 1L
  ks <- ((s - 1L) %/% tl$TT + 1L):((t - 1L) %/% tl$TT + 1L)
  if (length(ks) == 1L) {
    k <- ks
    return(t(tl$m[[k]][tl$map[[k]][rows], (s - tl$t0[k] + 1L):(t - tl$t0[k] + 1L), drop = FALSE]))
  }
  parts <- lapply(ks, function(k) {
    a <- max(s, tl$t0[k]); b <- min(t, tl$t1[k])
    tl$m[[k]][tl$map[[k]][rows], (a - tl$t0[k] + 1L):(b - tl$t0[k] + 1L), drop = FALSE]
  })
  t(do.call(cbind, parts))
}

us <- function(expr_q, times = 300L) {
  env <- parent.frame()
  f <- eval(call("function", as.pairlist(alist()), expr_q), env)
  mb <- microbenchmark(f(), times = times)
  median(mb$time) / 1000
}

run_shape <- function(label, n_inst, n_axis, life_min, life_max, Ls) {
  r <- make_ragged(n_inst, n_axis, life_min, life_max)
  m <- to_dense(r)
  tl <- make_tiles(r, m, 252L)
  t <- as.integer(n_axis * 0.7)
  live <- which(r$start <= t & r$end >= t)
  out <- list()
  # parity first
  stopifnot(identical(dense_pulse(m, live, t), ragged_pulse(r, live, t)),
            identical(dense_pulse(m, live, t), tile_pulse(tl, live, t)))
  out[[length(out) + 1L]] <- data.frame(shape = label, read = "pulse", rows = length(live),
    dense_us = us(quote(dense_pulse(m, live, t))),
    ragged_us = us(quote(ragged_pulse(r, live, t))),
    tiles_us = us(quote(tile_pulse(tl, live, t))))
  for (L in Ls) {
    adm <- live[r$start[live] <= t - L + 1L]
    stopifnot(identical(dense_hist(m, adm, t, L), ragged_hist(r, adm, t, L)),
              identical(unname(dense_hist(m, adm, t, L)), unname(tile_hist(tl, adm, t, L))))
    out[[length(out) + 1L]] <- data.frame(shape = label, read = paste0("history L=", L),
      rows = length(adm),
      dense_us = us(quote(dense_hist(m, adm, t, L)), 100L),
      ragged_us = us(quote(ragged_hist(r, adm, t, L)), 100L),
      tiles_us = us(quote(tile_hist(tl, adm, t, L)), 100L))
  }
  mem <- data.frame(shape = label, n_inst = n_inst, n_axis = n_axis,
    mean_life = round(mean(r$end - r$start + 1L)),
    dense_MB = round(as.numeric(object.size(m)) / 2^20, 1),
    ragged_MB = round(as.numeric(object.size(r)) / 2^20, 1),
    tiles_MB = round(as.numeric(object.size(tl)) / 2^20, 1))
  rm(m); invisible(gc())
  list(reads = do.call(rbind, out), mem = mem)
}

shapes <- list(
  run_shape("fixed basket 500x1260", 500L, 1260L, 1260L, 1260L, c(20L, 252L)),
  run_shape("survivorship-free 10000x5000", 10000L, 5000L, 250L, 2500L, c(20L, 252L)),
  run_shape("intraday 20x23400", 20L, 23400L, 23400L, 23400L, c(20L, 390L))
)
reads <- do.call(rbind, lapply(shapes, `[[`, "reads"))
for (k in c("dense_us", "ragged_us", "tiles_us")) reads[[k]] <- round(reads[[k]], 1)
print(reads, row.names = FALSE)
cat("\n")
print(do.call(rbind, lapply(shapes, `[[`, "mem")), row.names = FALSE)
