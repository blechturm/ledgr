# Where does ledgr's lot kernel spend its time? Replays the per-pulse fill
# blocks of the 200 x 250 changing-axis seam through variants of the same
# kernel: input validation moved out, applied-row validation stubbed, the
# dust helper stubbed, and the book copies timed alone. A variant's time
# counts only if its final book equals the real kernel's.
# Usage: Rscript dev/spikes/r_floor/probe_lot.R <ledgr lib> [n_inst] [reps]
args <- commandArgs(TRUE)
suppressPackageStartupMessages(library(ledgr, lib.loc = args[[1]]))
n_inst <- if (length(args) >= 2) as.integer(args[[2]]) else 200L
reps <- if (length(args) >= 3) as.integer(args[[3]]) else 10L
here <- file.path("dev", "spikes", "r_floor")
for (f in c("axes_fixture.R", "seam_p2.R", "seam_p35.R")) source(file.path(here, f))
ns <- asNamespace("ledgr")

fx <- r_floor_axes_fixture(n_inst, 250L)
rec <- r_floor_p35_record(fx, "lot")
p <- r_floor_p2_prepare(fx, rec$fills)
# The fill blocks the seam applies, one per pulse with fills.
blocks <- list(); book <- ns$ledgr_lot_book(length(p$ids))
for (t in seq_len(ncol(p$close) - 1L)) {
  a <- match(rec$axis[[t]], p$ids)
  delta <- rec$targets[[t]] - book$net_by_inst[a]
  go <- which(delta != 0 & p$has_bar[a, t + 1L])
  if (!length(go)) next
  b <- list(pos = a[go], side = as.integer(sign(delta[go])), qty = abs(delta[go]),
            price = p$open[a[go], t + 1L])
  book <- ns$ledgr_lot_fill(book, b$pos, b$side, b$qty, b$price, 0)$book
  blocks[[length(blocks) + 1L]] <- b
}
reference_book <- book
inputs <- lapply(blocks, function(b) ns$ledgr_lot_input(1L, b$pos, b$side, b$qty, b$price, 0))

# Kernel variants: the real apply with chosen helpers replaced in its scope.
variant <- function(stub_applied = FALSE, stub_dust = FALSE) {
  f <- ns$ledgr_lot_apply
  env <- new.env(parent = ns)
  if (stub_applied) env$ledgr_lot_applied <- function(input, position_before, position_after,
      close_qty, open_qty, realized_close, realized_delta, event_realized, event_cost_basis,
      lots = NULL) list(position_before = position_before, position_after = position_after,
      close_qty = close_qty, open_qty = open_qty, realized_close = realized_close,
      realized_delta = realized_delta, event_realized = event_realized,
      event_cost_basis = event_cost_basis)
  if (stub_dust) env$ledgr_lot_dust_tolerance_rows <- function(...) 0
  environment(f) <- env
  # Byte-compile every variant the same way, so a variant is not slower
  # merely for losing compilation when its scope changes.
  compiler::cmpfun(f)
}
run <- function(apply_fn, prebuilt) {
  bk <- ns$ledgr_lot_book(length(p$ids))
  for (i in seq_along(blocks)) {
    b <- blocks[[i]]
    input <- if (prebuilt) inputs[[i]] else ns$ledgr_lot_input(1L, b$pos, b$side, b$qty, b$price, 0)
    bk <- apply_fn(bk, input)$book
  }
  bk
}
time_it <- function(fn) stats::median(vapply(seq_len(3L), function(r)
  system.time(for (k in seq_len(reps)) fn())[["elapsed"]], 1)) / reps
v_control <- variant()
v_no_applied <- variant(stub_applied = TRUE)
v_no_dust <- variant(stub_applied = TRUE, stub_dust = TRUE)
cases <- list(
  real_kernel = function() run(ns$ledgr_lot_apply, FALSE),
  input_prebuilt = function() run(ns$ledgr_lot_apply, TRUE),
  same_path_control = function() run(v_control, TRUE),
  no_applied_check = function() run(v_no_applied, TRUE),
  no_dust_helper = function() run(v_no_dust, TRUE))
res <- do.call(rbind, lapply(names(cases), function(nm) {
  same <- identical(cases[[nm]](), reference_book)
  data.frame(variant = nm, book_identical = same, seconds = time_it(cases[[nm]]))
}))
# Book copies alone: copying the lot vectors once per block, as the kernel's
# q[slot] <- ... and p[slot] <- ... do on a shared book.
copy_s <- time_it(function() for (b in blocks) {
  q <- reference_book$lot_qty; q[1L] <- q[1L]; pr <- reference_book$lot_price; pr[1L] <- pr[1L]
})
res <- rbind(res, data.frame(variant = "book_copies_only", book_identical = NA, seconds = copy_s))
res$us_per_block <- res$seconds / length(blocks) * 1e6
res$us_per_fill <- res$seconds / sum(vapply(blocks, function(b) length(b$pos), 1L)) * 1e6
cat(sprintf("%d instruments, %d blocks, %d fills, %d lot slots in the final book\n", n_inst,
  length(blocks), sum(vapply(blocks, function(b) length(b$pos), 1L)), length(reference_book$lot_qty)))
print(res, row.names = FALSE)
