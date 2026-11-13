# Generated streams for the FIFO parity runner (LDG-3213). A stream is a
# starting book and steps; a step names an operation ("opening", "fill",
# "disposition", "apply_blocks", the raw kernel "apply", or "input" for the
# input boundary alone) and its arguments, or a function of the pinned book
# that returns them. Both sides run the same steps, each from its own book.

fifo_run_stream <- function(stream, ns, env) {
  pin_book <- lean_book <- stream$book
  same <- rows <- refusals <- 0L
  messages <- character()
  for (s in stream$steps) {
    args <- if (is.function(s$args)) s$args(pin_book) else s$args
    if (identical(s$op, "input")) {
      pin <- outcome(do.call(ns$ledgr_lot_input, args))
      got <- outcome(do.call(env$lean_lot_input, args))
    } else {
      pin <- outcome(do.call(ns[[paste0("ledgr_lot_", s$op)]], c(list(pin_book), args)))
      got <- outcome(do.call(env[[paste0("lean_lot_", s$op)]], c(list(lean_book), args)))
    }
    ok <- identical(got, pin)
    if (ok && identical(s$op, "fill") && !refused(pin)) {
      fee <- rep_len(args$fee %||% 0, length(args$pos))
      ok <- identical(env$lean_fill_leg_fees(fee, got$applied$close_qty, got$applied$open_qty),
                      ns$ledgr_fill_leg_fees(fee, pin$applied$close_qty, pin$applied$open_qty))
    }
    same <- same + ok
    rows <- rows + length(args$pos %||% args$input$pos)
    refusals <- refusals + refused(pin)
    if (refused(got)) messages <- c(messages, got$message)
    if (!refused(pin) && !identical(s$op, "input")) pin_book <- pin$book
    if (!refused(got) && !identical(s$op, "input")) lean_book <- got$book
  }
  list(same = same, rows = rows, refusals = refusals, messages = messages)
}

# A book holding the given lots per instrument (a list of list(qty, price)),
# laid out as the kernel lays it out; cached net and basis are the
# left-to-right sums, totals as given. Used for states openings cannot reach
# (zero lots, mixed signs, corrupt caches).
fifo_lots_book <- function(ns, lots, net = NULL, realized = 0, comp = 0) {
  n <- length(lots)
  b <- ns$ledgr_lot_book(n)
  cnt <- vapply(lots, function(l) length(l$qty), integer(1))
  b$capacity <- cnt
  b$offset <- c(0L, cumsum(cnt)[-n])
  b$tail <- cnt
  b$lot_qty <- as.numeric(unlist(lapply(lots, `[[`, "qty")))
  b$lot_price <- as.numeric(unlist(lapply(lots, `[[`, "price")))
  b$net_by_inst <- net %||% vapply(lots, function(l) Reduce(`+`, l$qty, 0), numeric(1))
  b$cost_basis_by_inst <- vapply(lots, function(l) Reduce(`+`, l$qty * l$price, 0), numeric(1))
  b$total_cost_basis <- Reduce(`+`, b$cost_basis_by_inst, 0)
  b$realized_pnl <- realized
  b$realized_comp <- comp
  b
}

fifo_step <- function(op, ...) list(op = op, args = list(...))
fifo_blocks_args <- function(op, pos, side, qty, price, fee = 0, rmp = NA_real_) {
  n <- length(pos)
  list(operation = as.integer(op), pos = as.integer(pos), side = as.integer(side), qty = as.numeric(qty),
       price = as.numeric(price), fee = rep_len(as.numeric(fee), n), realized_model_pnl = rep_len(rmp, n),
       new_run = c(TRUE, op[-1L] != op[-n]))
}

# Disposes every held instrument of `pos` at `price` (full position).
fifo_dispose_all <- function(pos, price, witness = FALSE) {
  function(book) {
    held <- pos[book$net_by_inst[pos] != 0]
    if (!length(held)) held <- pos[[1L]]
    net <- book$net_by_inst[held]
    qty <- abs(net)
    qty[qty == 0] <- 1
    px <- rep_len(price, length(held))
    rmp <- if (witness) {
      live <- ns$ledgr_lot_book_live(book, held)
      w <- vapply(seq_along(held), function(i) {
        k <- live$pos == held[[i]]
        sum((px[[i]] - live$price[k]) * live$qty[k])
      }, numeric(1))
      w
    } else NA_real_
    list(pos = held, side = ifelse(net > 0, -1L, 1L), qty = qty, price = px, realized_model_pnl = rmp)
  }
}

fifo_random_stream <- function(ns, seed, n = 12L, k = 300L) {
  set.seed(seed)
  qty_of <- function(m) {
    kind <- sample(c("int", "frac", "dust", "big"), m, replace = TRUE, prob = c(.5, .3, .1, .1))
    as.numeric(ifelse(kind == "int", sample(1:30, m, replace = TRUE),
               ifelse(kind == "frac", round(stats::runif(m, 0.01, 20), 6),
               ifelse(kind == "dust", 1e-13 * sample(1:9, m, replace = TRUE), 1e6 + stats::runif(m)))))
  }
  steps <- lapply(seq_len(k), function(i) {
    m <- sample.int(n, 1L)
    pos <- sort(sample.int(n, m))
    u <- stats::runif(1L)
    if (u < 0.78) {
      fifo_step("fill", pos = pos, side = sample(c(-1L, 1L), m, replace = TRUE), qty = qty_of(m),
                price = round(stats::runif(m, 1, 500), 4),
                fee = round(stats::runif(m, 0, 2), 2) * (stats::runif(m) < 0.4))
    } else if (u < 0.85) {
      fifo_step("opening", pos = pos, qty = qty_of(m) * sample(c(-1, 1), m, replace = TRUE),
                price = round(stats::runif(m, -50, 500), 4) * (stats::runif(m) < 0.9))
    } else if (u < 0.93) {
      list(op = "disposition", args = fifo_dispose_all(pos, if (stats::runif(1L) < 0.3) 0 else round(stats::runif(1L, 1, 500), 4),
                                                        witness = stats::runif(1L) < 0.5))
    } else {
      r <- sample.int(4L, 1L) + 1L
      rp <- sample.int(n, r * 3L, replace = TRUE)
      op <- rep(sample(c(1L, 1L, 3L), r, replace = TRUE), each = 3L)
      list(op = "apply_blocks", args = fifo_blocks_args(op, rp, ifelse(op == 3L, 0L, sample(c(-1L, 1L), length(rp), TRUE)),
                                                        qty_of(length(rp)) * ifelse(op == 3L, sample(c(-1, 1), length(rp), TRUE), 1),
                                                        round(stats::runif(length(rp), 1, 300), 3),
                                                        ifelse(op == 1L, round(stats::runif(length(rp), 0, 1), 2), 0)))
    }
  })
  list(book = ns$ledgr_lot_book(n), steps = steps)
}

fifo_streams <- function(ns) {
  empty <- function(n) ns$ledgr_lot_book(n)
  s <- list()
  s$long_opening_negative_basis <- list(book = empty(2L), steps = list(
    fifo_step("opening", pos = 1L, qty = 100, price = -2.5),
    fifo_step("fill", pos = 1L, side = -1L, qty = 30, price = 1.25, fee = 0.5),
    fifo_step("fill", pos = 1L, side = -1L, qty = 80, price = 0.75, fee = 0.1),
    fifo_step("fill", pos = 1L, side = 1L, qty = 10, price = 0.5, fee = 0),
    fifo_step("opening", pos = c(1L, 2L), qty = c(3, 0.25), price = c(-0.1, -7))))
  s$short_opening_zero_basis <- list(book = empty(2L), steps = list(
    fifo_step("opening", pos = c(1L, 2L), qty = c(-50, -7.5), price = c(0, 0)),
    fifo_step("fill", pos = 1L, side = 1L, qty = 20, price = 3, fee = 0),
    fifo_step("fill", pos = c(1L, 2L), side = c(1L, 1L), qty = c(40, 7.5), price = c(2.5, 1), fee = c(1, 0.2)),
    fifo_step("disposition", pos = 1L, side = -1L, qty = 10, price = 0)))
  s$repeated_instruments <- list(book = empty(3L), steps = list(
    list(op = "apply_blocks", args = fifo_blocks_args(rep(3L, 5L), c(1, 1, 2, 1, 2), 0L, c(5, -2, 3, 4, 1),
                                                      c(10, 11, -1, 0, 2))),
    list(op = "apply_blocks", args = fifo_blocks_args(c(1L, 1L, 1L, 1L, 1L, 1L, 3L, 3L), c(1, 2, 1, 1, 3, 2, 3, 3),
                                                      c(-1, 1, -1, 1, 1, -1, 0, 0), c(4, 2, 6, 3, 1.5, 9, 2, -1),
                                                      c(12, 3, 13, 11, 7, 2, 6, 5), c(0.1, 0, 0.2, 0, 0.05, 0.3, 0, 0))),
    list(op = "disposition", args = fifo_dispose_all(1:3, 0, witness = TRUE))))
  s$dust_snaps <- list(book = empty(2L), steps = list(
    fifo_step("fill", pos = 1:2, side = c(1L, 1L), qty = c(0.1, 0.3), price = c(10, 10), fee = 0),
    fifo_step("fill", pos = 1L, side = 1L, qty = 0.2, price = 10, fee = 0),
    fifo_step("fill", pos = 1:2, side = c(-1L, -1L), qty = c(0.3, 0.1 + 0.2), price = c(11, 9), fee = 0),
    fifo_step("fill", pos = 1:2, side = c(1L, -1L), qty = c(1e-300, 1e-300), price = c(3, 3), fee = 0)))
  s$kahan_carried_compensation <- list(book = fifo_lots_book(ns, list(list(qty = numeric(), price = numeric()),
                                                                     list(qty = numeric(), price = numeric())),
                                                             realized = 10, comp = 1e-3), steps = list(
    fifo_step("opening", pos = 1L, qty = 5, price = 2),
    fifo_step("fill", pos = 1L, side = -1L, qty = 2, price = 3.1, fee = 0.01),
    fifo_step("opening", pos = 2L, qty = -4, price = 1)))
  s$reversal_fee_split <- list(book = empty(3L), steps = list(
    fifo_step("fill", pos = 1:3, side = c(1L, 1L, 1L), qty = c(10, 10, 10), price = c(5, 5, 5), fee = 1),
    fifo_step("fill", pos = 1:3, side = c(-1L, -1L, -1L), qty = c(15, 10, 4), price = c(6, 4, 7), fee = c(0.75, 0.3, 2)),
    fifo_step("fill", pos = 1L, side = 1L, qty = 20, price = 5.5, fee = 1.1)))
  for (seed in 1:5) s[[paste0("random_conflict_free_", seed)]] <- fifo_random_stream(ns, seed)

  # Refusals. `zero_lot` holds a short lot then a zero lot, so a buy that
  # consumes the short stops at the zero lot and would open through it.
  zero_lot <- list(qty = c(-5, 0), price = c(10, 10))
  flat <- list(qty = numeric(), price = numeric())
  s$refuse_through <- list(book = fifo_lots_book(ns, list(zero_lot, flat)), steps = list(
    fifo_step("fill", pos = 1L, side = 1L, qty = 10, price = 9, fee = 0)))
  s$refuse_overflow <- list(book = fifo_lots_book(ns, list(list(qty = 1e300, price = 1), flat)), steps = list(
    fifo_step("fill", pos = 2L, side = 1L, qty = 1e308, price = 10, fee = 0),
    fifo_step("fill", pos = 1L, side = -1L, qty = 1e300, price = 1e10, fee = 0),
    fifo_step("fill", pos = 2L, side = 1L, qty = 1, price = 1, fee = 1e308 * 10)))
  s$refuse_two_violations_one_row <- list(book = fifo_lots_book(ns, list(list(qty = c(-1e300, 0), price = c(1, 1)), zero_lot)),
    steps = list(
      # through and closing overflow: the closing overflow refuses
      fifo_step("fill", pos = 1L, side = 1L, qty = 2e300, price = 1e10, fee = 0),
      # through and later overflow: the through refuses
      fifo_step("fill", pos = 2L, side = 1L, qty = 1e308, price = 10, fee = 0)))
  s$refuse_earliest_row <- list(book = fifo_lots_book(ns, list(flat, zero_lot, flat, flat)), steps = list(
    fifo_step("fill", pos = 1:4, side = rep(1L, 4L), qty = c(1, 10, 1, 1e308), price = c(10, 9, 10, 10), fee = 0),
    fifo_step("fill", pos = c(1L, 3L, 4L), side = rep(1L, 3L), qty = c(1, 1e308, 1e308), price = c(10, 10, 10), fee = 0)))
  s$refuse_dispositions <- list(book = empty(3L), steps = list(
    fifo_step("opening", pos = 1:3, qty = c(10, 5, -5), price = c(5, 2, 4)),
    fifo_step("disposition", pos = 1L, side = -1L, qty = 4, price = 6),
    fifo_step("disposition", pos = 1L, side = -1L, qty = 4, price = 6, realized_model_pnl = 4),
    fifo_step("disposition", pos = 1L, side = -1L, qty = 12, price = 6),
    fifo_step("disposition", pos = 1L, side = -1L, qty = 10, price = 6, realized_model_pnl = 999),
    fifo_step("disposition", pos = 1L, side = -1L, qty = 4, price = 6, realized_model_pnl = 999),
    fifo_step("disposition", pos = 1:2, side = c(-1L, -1L), qty = c(10, 3), price = c(6, 7)),
    fifo_step("disposition", pos = 1L, side = -1L, qty = 10, price = 6, realized_model_pnl = 10 + 1e-15),
    fifo_step("disposition", pos = 3L, side = 1L, qty = 5, price = 0, realized_model_pnl = 20),
    fifo_step("disposition", pos = 2L, side = -1L, qty = 5, price = 0)))
  s$refuse_nonfinite_rows <- list(book = fifo_lots_book(ns, list(list(qty = 1e300, price = 1), flat, flat),
                                                        net = c(1e300, 0, 1)), steps = list(
    fifo_step("opening", pos = 2L, qty = 1e300, price = 1e300),
    fifo_step("disposition", pos = 1L, side = -1L, qty = 1e300, price = 1e300),
    # the book is corrupt (instrument 3 is flat with net 1): a fill overflow
    # is a state invariant, not invalid input
    fifo_step("fill", pos = 2L, side = 1L, qty = 1e308, price = 10, fee = 0)))
  s$refuse_input <- list(book = empty(2L), steps = list(
    fifo_step("fill", pos = 3L, side = 1L, qty = 1, price = 1, fee = 0),
    fifo_step("fill", pos = 1L, side = 1L, qty = 1, price = 1, fee = -1),
    fifo_step("fill", pos = 1L, side = 1L, qty = 1, price = 0, fee = 0),
    fifo_step("fill", pos = 1:2, side = c(1L, 1L), qty = c(1, NaN), price = c(1, 1), fee = 0),
    fifo_step("fill", pos = 1L, side = 0L, qty = 1, price = 1, fee = 0),
    fifo_step("fill", pos = 1L, side = 1L, qty = 0, price = 0, fee = -1),
    fifo_step("opening", pos = 1L, qty = 0, price = 1),
    fifo_step("opening", pos = 1L, qty = 1, price = Inf),
    fifo_step("disposition", pos = 1L, side = -1L, qty = 1, price = -1),
    fifo_step("input", operation = 2L, pos = 1L, side = 1L, qty = 1, price = 1),
    fifo_step("input", operation = 1L, pos = 0L, side = 1L, qty = 1, price = 1),
    fifo_step("input", operation = 1L, pos = NA_integer_, side = 1L, qty = 1, price = 1),
    fifo_step("input", operation = 1L, pos = 1L, side = NA_integer_, qty = 1, price = 1),
    fifo_step("input", operation = 3L, pos = 1L, side = 1L, qty = 1, price = 1),
    fifo_step("input", operation = 3L, pos = 1L, side = 0L, qty = 1, price = 1, fee = 0.5),
    fifo_step("input", operation = 4L, pos = 1L, side = -1L, qty = 1, price = 1, fee = 1),
    fifo_step("input", operation = 1L, pos = 1:2, side = c(1L, 1L), qty = c(1, 2), price = c(1, 2),
              fee = c(0, 0.1), realized_model_pnl = c(NA, 3))))
  s
}
