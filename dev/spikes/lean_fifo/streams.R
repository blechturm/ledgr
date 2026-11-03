# Fill streams for kernel parity, shared by the runners: the recorded fill
# blocks of the changing-axis seams and random streams aimed at edge cases.

r_lean_fifo_fields <- c("position_before", "position_after", "close_qty", "open_qty",
  "realized_close", "realized_delta", "event_realized", "event_cost_basis")

r_lean_fifo_seam_blocks <- function(n_inst) {
  ns <- asNamespace("ledgr")
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

r_lean_fifo_random_blocks <- function(n, k, seed) {
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

# Feeds a stream through the canonical kernel and `fill`, comparing the book
# and every applied-row field after every block; returns blocks differing.
r_lean_fifo_compare <- function(n, blocks, fill) {
  ns <- asNamespace("ledgr")
  real_book <- ns$ledgr_lot_book(n); other_book <- real_book
  bad <- 0L
  for (b in blocks) {
    r <- ns$ledgr_lot_fill(real_book, b$pos, b$side, b$qty, b$price, b$fee)
    o <- fill(other_book, b$pos, b$side, b$qty, b$price, b$fee)
    same <- identical(r$book, o$book) && all(vapply(r_lean_fifo_fields,
      function(f) identical(r$applied[[f]], o$applied[[f]]), TRUE))
    if (!same) bad <- bad + 1L
    real_book <- r$book; other_book <- o$book
  }
  bad
}
