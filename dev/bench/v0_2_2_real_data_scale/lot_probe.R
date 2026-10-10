# Per-fill cost of the lot state's instrument-sized vectors (Cut 11 LDG-2988,
# finding F8's typed-lot-state part).
#
#   Rscript lot_probe.R <tree> <out_csv> [fills]
#
# Times ledgr_lot_apply_fill() for the same fill sequence on a lot state over
# one instrument and over 1,166 (the Sharadar universe). Holding lot state in
# typed vectors written by index would remove at most the difference: the
# copies of instrument-sized named vectors per fill. The FIFO arithmetic stays.

args <- commandArgs(trailingOnly = TRUE)
tree <- args[[1L]]; out_csv <- args[[2L]]
fills <- if (length(args) > 2L) as.integer(args[[3L]]) else 20000L
.libPaths(c("C:/Users/maxth/AppData/Local/R/win-library/4.6", .libPaths()))
suppressMessages(pkgload::load_all(tree, quiet = TRUE, compile = FALSE))
ns <- asNamespace("ledgr")
set.seed(1)
side <- ifelse(seq_len(fills) %% 3L == 0L, "SELL", "BUY")
qty <- rep(1, fills)
price <- 100 + stats::runif(fills)

run <- function(n_inst) {
  ids <- c("I0001", sprintf("X%04d", seq_len(n_inst - 1L)))
  state <- ns$ledgr_lot_state(ids)
  t0 <- Sys.time()
  for (i in seq_len(fills)) {
    state <- ns$ledgr_lot_apply_fill(state, "I0001", side[[i]], qty[[i]], price[[i]])$state
  }
  as.numeric(difftime(Sys.time(), t0, units = "secs"))
}
rows <- list()
for (r in 1:3) for (n in c(1L, 1166L)) {
  rows[[length(rows) + 1L]] <- data.frame(rep = r, instruments = n, fills = fills, seconds = run(n))
}
out <- do.call(rbind, rows)
med <- stats::aggregate(seconds ~ instruments, out, stats::median)
med$us_per_fill <- round(1e6 * med$seconds / fills, 2)
utils::write.csv(out, out_csv, row.names = FALSE)
print(med, row.names = FALSE)
