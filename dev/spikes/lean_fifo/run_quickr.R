# The lean kernel's core compiled with quickr: parity on the same streams as
# run.R, and cost of canonical, lean R and quickr side by side.
# Usage: Rscript dev/spikes/lean_fifo/run_quickr.R <ledgr lib> <quickr lib> <out dir>
args <- commandArgs(TRUE)
suppressPackageStartupMessages(library(ledgr, lib.loc = args[[1]]))
.libPaths(c(args[[2]], .libPaths()))
out <- args[[3]]
dir.create(out, recursive = TRUE, showWarnings = FALSE)
here <- file.path("dev", "spikes", "lean_fifo")
for (f in c("kernel.R", "quickr_kernel.R", "streams.R")) source(file.path(here, f))
for (f in c("axes_fixture.R", "seam_p2.R", "seam_p35.R")) source(file.path("dev", "spikes", "r_floor", f))
ns <- asNamespace("ledgr")
compile_s <- system.time(r_quickr_fifo_core <- quickr::quick(r_quickr_fifo_core_source()))[["elapsed"]]

rows <- list(); seams <- list()
for (n_inst in c(30L, 200L)) {
  s <- r_lean_fifo_seam_blocks(n_inst); seams[[as.character(n_inst)]] <- s
  rows[[length(rows) + 1L]] <- data.frame(stream = sprintf("seam %dx250", n_inst),
    fills = sum(lengths(lapply(s$blocks, `[[`, "pos"))),
    blocks_differing = r_lean_fifo_compare(s$n, s$blocks, r_quickr_fifo_fill))
}
for (seed in 1:5) {
  bl <- r_lean_fifo_random_blocks(12L, 400L, seed)
  rows[[length(rows) + 1L]] <- data.frame(stream = sprintf("random 12 instruments, seed %d", seed),
    fills = sum(lengths(lapply(bl, `[[`, "pos"))),
    blocks_differing = r_lean_fifo_compare(12L, bl, r_quickr_fifo_fill))
}
parity <- do.call(rbind, rows)

time_kernel <- function(s, fill) {
  run <- function() {
    bk <- ns$ledgr_lot_book(s$n)
    for (b in s$blocks) bk <- fill(bk, b$pos, b$side, b$qty, b$price, b$fee)$book
  }
  run()
  stats::median(vapply(1:3, function(r) system.time(for (k in 1:20) run())[["elapsed"]], 1)) / 20
}
cost <- do.call(rbind, lapply(names(seams), function(nm) {
  s <- seams[[nm]]; fills <- sum(lengths(lapply(s$blocks, `[[`, "pos")))
  t <- c(canonical = time_kernel(s, ns$ledgr_lot_fill), lean_r = time_kernel(s, r_lean_fifo_fill),
         quickr = time_kernel(s, r_quickr_fifo_fill))
  data.frame(seam = sprintf("%sx250", nm), kernel = names(t),
             us_per_block = t / length(s$blocks) * 1e6, us_per_fill = t / fills * 1e6)
}))
cost$compile_s <- ifelse(cost$kernel == "quickr", compile_s, NA_real_)
utils::write.csv(parity, file.path(out, "parity_quickr.csv"), row.names = FALSE)
utils::write.csv(cost, file.path(out, "cost_quickr.csv"), row.names = FALSE)
print(parity, row.names = FALSE); print(cost, row.names = FALSE)
