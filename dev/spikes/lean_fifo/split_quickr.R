# Splits the quickr kernel cost into the compiled core and its R wrapper.
# Usage: Rscript dev/spikes/lean_fifo/split_quickr.R <ledgr lib> <quickr lib>
suppressPackageStartupMessages(library(ledgr, lib.loc = commandArgs(TRUE)[[1]])); .libPaths(c(commandArgs(TRUE)[[2]], .libPaths()))
here <- file.path("dev", "spikes", "lean_fifo"); for (f in c("quickr_kernel.R", "streams.R")) source(file.path(here, f))
for (f in c("axes_fixture.R", "seam_p2.R", "seam_p35.R")) source(file.path("dev", "spikes", "r_floor", f))
r_quickr_fifo_core <- quickr::quick(r_quickr_fifo_core_source()); ns <- asNamespace("ledgr")
s <- r_lean_fifo_seam_blocks(200L)
# Record the exact core inputs of every block, then time the core alone.
args_list <- list(); bk <- ns$ledgr_lot_book(s$n)
for (b in s$blocks) { q0 <- bk$lot_qty; q0[is.na(q0)] <- 0; p0 <- bk$lot_price; p0[is.na(p0)] <- 0
  args_list[[length(args_list) + 1L]] <- list(b$pos, b$side, b$qty, b$price, rep_len(as.numeric(b$fee), length(b$pos)), q0, p0, bk$offset, bk$head, bk$tail, bk$net_by_inst, bk$cost_basis_by_inst, c(bk$total_cost_basis, bk$realized_pnl, bk$realized_comp))
  bk <- r_quickr_fifo_fill(bk, b$pos, b$side, b$qty, b$price, b$fee)$book }
core <- stats::median(vapply(1:3, function(r) system.time(for (k in 1:50) for (a in args_list) do.call(r_quickr_fifo_core, a))[["elapsed"]], 1)) / 50
full <- stats::median(vapply(1:3, function(r) system.time(for (k in 1:50) { bk <- ns$ledgr_lot_book(s$n); for (b in s$blocks) bk <- r_quickr_fifo_fill(bk, b$pos, b$side, b$qty, b$price, b$fee)$book })[["elapsed"]], 1)) / 50
cat(sprintf("200x250, %d blocks: compiled core %.1f us/block, full wrapper %.1f us/block, wrapper share %.0f%%\n", length(s$blocks), core / length(s$blocks) * 1e6, full / length(s$blocks) * 1e6, (1 - core / full) * 100))
