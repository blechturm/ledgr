# Parity and cost of the lean FIFO kernel against ledgr's canonical kernel.
# Usage: Rscript dev/spikes/lean_fifo/run.R <ledgr lib> <out dir> [gut]
#   gut: "plain_sum" replaces the Kahan step with a plain sum; parity must fail.
args <- commandArgs(TRUE)
suppressPackageStartupMessages(library(ledgr, lib.loc = args[[1]]))
out <- args[[2]]; gut <- if (length(args) >= 3) args[[3]] else ""
dir.create(out, recursive = TRUE, showWarnings = FALSE)
source(file.path("dev", "spikes", "lean_fifo", "kernel.R"))
for (f in c("axes_fixture.R", "seam_p2.R", "seam_p35.R")) source(file.path("dev", "spikes", "r_floor", f))
ns <- asNamespace("ledgr")
lean <- r_lean_fifo_fill
options(r_lean_fifo.gut = gut)
counted <- function(book, pos, side, qty, price, fee) lean(book, pos, side, qty, price, fee)
fields <- c("position_before", "position_after", "close_qty", "open_qty", "realized_close",
            "realized_delta", "event_realized", "event_cost_basis")

# Feeds a stream of blocks through both kernels, comparing after every block.
compare_stream <- function(n, blocks) {
  r_lean_fifo_stats$fallbacks <- 0L
  real_book <- ns$ledgr_lot_book(n); lean_book <- real_book
  bad <- 0L
  for (b in blocks) {
    r <- ns$ledgr_lot_fill(real_book, b$pos, b$side, b$qty, b$price, b$fee)
    l <- counted(lean_book, b$pos, b$side, b$qty, b$price, b$fee)
    same <- identical(r$book, l$book) &&
      all(vapply(fields, function(f) identical(r$applied[[f]], l$applied[[f]]), TRUE))
    if (!same) bad <- bad + 1L
    real_book <- r$book; lean_book <- l$book
  }
  attr(bad, "fallbacks") <- r_lean_fifo_stats$fallbacks
  bad
}

# 1. The recorded fill blocks of the changing-axis seams.
seam_blocks <- function(n_inst) {
  fx <- r_floor_axes_fixture(n_inst, 250L)
  rec <- r_floor_p35_record(fx, "lf")
  p <- r_floor_p2_prepare(fx, rec$fills)
  book <- ns$ledgr_lot_book(length(p$ids)); out <- list()
  for (t in seq_len(ncol(p$close) - 1L)) {
    a <- match(rec$axis[[t]], p$ids)
    delta <- rec$targets[[t]] - book$net_by_inst[a]
    go <- which(delta != 0 & p$has_bar[a, t + 1L])
    if (!length(go)) next
    b <- list(pos = a[go], side = as.integer(sign(delta[go])), qty = abs(delta[go]),
              price = p$open[a[go], t + 1L], fee = 0)
    book <- ns$ledgr_lot_fill(book, b$pos, b$side, b$qty, b$price, b$fee)$book
    out[[length(out) + 1L]] <- b
  }
  list(n = length(p$ids), blocks = out)
}

# 2. Random streams aimed at the edge cases.
random_blocks <- function(n, k, seed) {
  set.seed(seed)
  lapply(seq_len(k), function(i) {
    m <- sample.int(n, 1L)
    pos <- sort(sample.int(n, m))
    kind <- sample(c("int", "frac", "dust", "big"), m, replace = TRUE, prob = c(.5, .3, .1, .1))
    qty <- ifelse(kind == "int", sample(1:30, m, replace = TRUE),
           ifelse(kind == "frac", round(stats::runif(m, 0.01, 20), 6),
           ifelse(kind == "dust", 1e-13 * sample(1:9, m, replace = TRUE), 1e6 + stats::runif(m))))
    list(pos = as.integer(pos), side = sample(c(-1L, 1L), m, replace = TRUE), qty = as.numeric(qty),
         price = round(stats::runif(m, 1, 500), 4),
         fee = round(stats::runif(m, 0, 2), 2) * (stats::runif(m) < 0.4))
  })
}

rows <- list()
for (n_inst in c(30L, 200L)) {
  s <- seam_blocks(n_inst)
  rows[[length(rows) + 1L]] <- data.frame(stream = sprintf("seam %dx250", n_inst),
    blocks = length(s$blocks), fills = sum(lengths(lapply(s$blocks, `[[`, "pos"))),
    blocks_differing = (d <- compare_stream(s$n, s$blocks)), fallbacks = attr(d, "fallbacks"))
  if (n_inst == 200L) seam200 <- s
}
for (seed in 1:5) {
  bl <- random_blocks(12L, 400L, seed)
  rows[[length(rows) + 1L]] <- data.frame(stream = sprintf("random 12 instruments, seed %d", seed),
    blocks = length(bl), fills = sum(lengths(lapply(bl, `[[`, "pos"))),
    blocks_differing = (d <- compare_stream(12L, bl)), fallbacks = attr(d, "fallbacks"))
}
parity <- do.call(rbind, rows)
parity$blocks_differing <- as.integer(parity$blocks_differing)

# Cost on the recorded 200-instrument blocks, as the fold calls the kernel.
run_with <- function(fill) {
  bk <- ns$ledgr_lot_book(seam200$n)
  for (b in seam200$blocks) bk <- fill(bk, b$pos, b$side, b$qty, b$price, b$fee)$book
  bk
}
time_it <- function(fn) stats::median(vapply(1:3, function(r)
  system.time(for (k in 1:20) fn())[["elapsed"]], 1)) / 20
t_real <- time_it(function() run_with(ns$ledgr_lot_fill))
t_lean <- time_it(function() run_with(lean))
cost <- data.frame(kernel = c("canonical ledgr_lot_fill", "lean"),
  us_per_block = c(t_real, t_lean) / length(seam200$blocks) * 1e6,
  us_per_fill = c(t_real, t_lean) / sum(lengths(lapply(seam200$blocks, `[[`, "pos"))) * 1e6)
utils::write.csv(parity, file.path(out, "parity.csv"), row.names = FALSE)
utils::write.csv(cost, file.path(out, "cost.csv"), row.names = FALSE)
print(parity, row.names = FALSE); print(cost, row.names = FALSE)
