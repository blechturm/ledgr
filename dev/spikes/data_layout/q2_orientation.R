# Q2: tile orientation. Instrument-major tiles (instrument x time, today's
# layout) against time-major tiles (time x instrument, the public history
# shape). Synthetic; one tile per shape; identical values asserted.
suppressMessages(library(microbenchmark))
set.seed(2)
med <- function(f, times = 300L) median(microbenchmark(f(), times = times)$time) / 1000

one <- function(label, n_alive, tile_len, Ls) {
  im <- matrix(runif(n_alive * tile_len), n_alive, tile_len)   # instrument x time
  tm <- t(im)                                                   # time x instrument
  rows <- seq_len(n_alive); t <- tile_len
  stopifnot(identical(im[rows, t], tm[t, rows]))
  out <- list(data.frame(shape = label, read = "pulse",
    inst_major = med(function() im[rows, t]),
    time_major = med(function() tm[t, rows]),
    inst_major_no_t = NA_real_))
  for (L in Ls) {
    cols <- (t - L + 1L):t
    stopifnot(identical(t(im[rows, cols]), tm[cols, rows]))
    out[[length(out) + 1L]] <- data.frame(shape = label, read = paste0("history ", L),
      inst_major = med(function() t(im[rows, cols]), 100L),
      time_major = med(function() tm[cols, rows], 100L),
      inst_major_no_t = med(function() im[rows, cols], 100L))
  }
  do.call(rbind, out)
}

res <- rbind(one("fixed basket 500", 500L, 1260L, c(20L, 252L)),
             one("whole market 3,400 alive", 3400L, 1008L, c(20L, 252L)),
             one("intraday 20", 20L, 4680L, c(20L, 390L)))
for (k in c("inst_major", "time_major", "inst_major_no_t")) res[[k]] <- round(res[[k]], 1)
print(res, row.names = FALSE)
