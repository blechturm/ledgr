# Differential dispatch cases for the simple lot path (Cut 15, LDG-3223,
# decision 2): constructed books and fill blocks on both sides of
# lean_lot_simple()'s predicate and at its boundaries. Each case runs the
# lean fill (debug off and on) and the pinned ledgr_lot_fill() on the same
# book and input; results (book and applied rows) or refusals (class and
# message) must be identical, and the path taken must be the expected one.
#
#   Rscript dev/lean_core/parity/fifo_simple_cases.R --lib=<pinned library> --out=<csv>

here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), commandArgs(TRUE), value = TRUE)[[1L]])
source(file.path(here, "..", "load.R"))
lean <- lean_core_load(arg("lib"), debug = FALSE)
lean_dbg <- lean_core_load(arg("lib"), debug = TRUE)
source(file.path(here, "fifo_streams.R"))
ns <- asNamespace("ledgr")
`%||%` <- function(a, b) if (is.null(a)) b else a
outcome <- function(expr) tryCatch(expr, error = function(e) list(class = class(e), message = conditionMessage(e)))

lots <- function(...) fifo_lots_book(ns, list(...))
lot <- function(qty, price) list(qty = qty, price = price)
flat <- list(qty = numeric(), price = numeric())
# A flat instrument whose segment keeps capacity one (its lot was closed).
flat_cap1 <- function(book, at) {
  book$lot_qty[book$offset[[at]] + 1L] <- NA_real_
  book$lot_price[book$offset[[at]] + 1L] <- NA_real_
  book$total_cost_basis <- book$total_cost_basis - book$cost_basis_by_inst[[at]]
  book$head[[at]] <- 1L
  book$tail[[at]] <- 0L
  book$net_by_inst[[at]] <- 0
  book$cost_basis_by_inst[[at]] <- 0
  book
}
two <- flat_cap1(lots(lot(5, 10), lot(2, 20)), 1L)        # A flat (capacity 1), B long 2 @ 20
# Cut 16 (LDG-3230): an instrument's segment with its last `drop` lots taken
# out (free capacity), or its first `gone` lots consumed (the head moved).
free_tail <- function(book, at, drop = 1L) {
  s <- book$offset[[at]] + book$tail[[at]] - seq_len(drop) + 1L
  book$total_cost_basis <- book$total_cost_basis - sum(book$lot_qty[s] * book$lot_price[s])
  book$cost_basis_by_inst[[at]] <- book$cost_basis_by_inst[[at]] - sum(book$lot_qty[s] * book$lot_price[s])
  book$net_by_inst[[at]] <- book$net_by_inst[[at]] - sum(book$lot_qty[s])
  book$lot_qty[s] <- NA_real_
  book$lot_price[s] <- NA_real_
  book$tail[[at]] <- book$tail[[at]] - drop
  book
}
moved_head <- function(book, at, gone) {
  s <- book$offset[[at]] + seq_len(gone)
  book$total_cost_basis <- book$total_cost_basis - sum(book$lot_qty[s] * book$lot_price[s])
  book$cost_basis_by_inst[[at]] <- book$cost_basis_by_inst[[at]] - sum(book$lot_qty[s] * book$lot_price[s])
  book$net_by_inst[[at]] <- book$net_by_inst[[at]] - sum(book$lot_qty[s])
  book$lot_qty[s] <- NA_real_
  book$lot_price[s] <- NA_real_
  book$head[[at]] <- gone + 1L
  book
}
roomy <- free_tail(lots(lot(5, 10), list(qty = c(2, 1), price = c(20, 21))), 2L)   # B long 2 @ 20, capacity 2

cases <- list(
  empty_block = list(book = two, pos = integer(), side = integer(), qty = numeric(), price = numeric(), simple = FALSE),
  open_flat_capacity_one = list(book = two, pos = 1L, side = 1L, qty = 3, price = 11, simple = TRUE),
  open_flat_capacity_zero = list(book = lots(flat, lot(2, 20)), pos = 1L, side = 1L, qty = 3, price = 11, simple = FALSE),
  close_exact_long = list(book = two, pos = 2L, side = -1L, qty = 2, price = 21, simple = TRUE),
  close_exact_short = list(book = lots(lot(-4, 7)), pos = 1L, side = 1L, qty = 4, price = 6.5, simple = TRUE),
  # Cut 16 (LDG-3230): a partial reduction of the head lot is now simple
  close_partial = list(book = two, pos = 2L, side = -1L, qty = 1, price = 21, simple = TRUE),
  close_through = list(book = two, pos = 2L, side = -1L, qty = 3, price = 21, simple = FALSE),
  add_to_long = list(book = two, pos = 2L, side = 1L, qty = 1, price = 21, simple = FALSE),
  two_live_lots = list(book = lots(list(qty = c(1, 1), price = c(10, 12))), pos = 1L, side = -1L, qty = 1, price = 11,
                       simple = FALSE),
  sell_then_buy = list(book = two, pos = c(2L, 1L), side = c(-1L, 1L), qty = c(2, 3), price = c(21, 11), simple = TRUE),
  buy_then_sell = list(book = two, pos = c(1L, 2L), side = c(1L, -1L), qty = c(3, 2), price = c(11, 21), simple = TRUE),
  # Cut 16 (LDG-3230): its second row is now a simple partial reduction
  one_row_not_simple = list(book = two, pos = c(1L, 2L), side = c(1L, -1L), qty = c(3, 1), price = c(11, 21), simple = TRUE),
  close_one_ulp_short = list(book = lots(lot(1 + 2^-52, 10)), pos = 1L, side = -1L, qty = 1, price = 10, simple = FALSE),
  close_one_ulp_over = list(book = lots(lot(1, 10)), pos = 1L, side = -1L, qty = 1 + 2^-52, price = 10, simple = FALSE),
  basis_dust_snapped = list(book = within(lots(lot(0.1, 0.3)), cost_basis_by_inst <- cost_basis_by_inst + 1e-18),
                            pos = 1L, side = -1L, qty = 0.1, price = 0.3, simple = TRUE),
  fee_on_both = list(book = two, pos = c(2L, 1L), side = c(-1L, 1L), qty = c(2, 3), price = c(21, 11), fee = c(0.5, 0.25),
                     simple = TRUE),
  flat_with_cached_net = list(book = within(two, net_by_inst[[1L]] <- 3), pos = 1L, side = 1L, qty = 1, price = 11,
                              simple = FALSE),
  open_overflow = list(book = two, pos = 1L, side = 1L, qty = 1e300, price = 1e300, simple = FALSE),
  close_overflow = list(book = lots(lot(1e300, 1e300)), pos = 1L, side = -1L, qty = 1e300, price = 1e-300, simple = FALSE),
  invalid_price = list(book = two, pos = 1L, side = 1L, qty = 1, price = 0, simple = NA),
  position_outside_axis = list(book = two, pos = 3L, side = 1L, qty = 1, price = 11, simple = FALSE),
  # Cut 16 (LDG-3230): partial reductions and same-side adds, both sides of
  # each predicate term
  one_row_through = list(book = two, pos = c(1L, 2L), side = c(1L, -1L), qty = c(3, 3), price = c(11, 21), simple = FALSE),
  reduce_short = list(book = lots(lot(-4, 7)), pos = 1L, side = 1L, qty = 1, price = 6.5, simple = TRUE),
  reduce_two_live = list(book = lots(list(qty = c(1, 1), price = c(10, 12))), pos = 1L, side = -1L, qty = 0.5,
                         price = 11, simple = TRUE),
  reduce_rest_above_dust = list(book = lots(lot(1 + 2^-51, 10)), pos = 1L, side = -1L, qty = 1, price = 10, simple = TRUE),
  reduce_rest_at_dust = list(book = lots(lot(1 + 2^-52, 10)), pos = 1L, side = -1L, qty = 1, price = 10, simple = FALSE),
  reduce_head_moved = list(book = moved_head(lots(list(qty = c(1, 2), price = c(10, 12))), 1L, 1L), pos = 1L,
                           side = -1L, qty = 1, price = 13, simple = TRUE),
  reduce_needs_compaction = list(book = moved_head(lots(list(qty = c(1, 1, 2), price = c(10, 11, 12))), 1L, 2L),
                                 pos = 1L, side = -1L, qty = 1, price = 13, simple = FALSE),
  reduce_fee = list(book = two, pos = 2L, side = -1L, qty = 0.75, price = 21, fee = 0.125, simple = TRUE),
  add_free_capacity = list(book = roomy, pos = 2L, side = 1L, qty = 1, price = 22, simple = TRUE),
  add_short_free_capacity = list(book = free_tail(lots(list(qty = c(-2, -1), price = c(20, 21))), 1L), pos = 1L,
                                 side = -1L, qty = 3, price = 19, simple = TRUE),
  add_head_moved_full = list(book = moved_head(lots(list(qty = c(1, 2), price = c(10, 12))), 1L, 1L), pos = 1L,
                             side = 1L, qty = 1, price = 13, simple = FALSE),
  add_needs_compaction = list(book = free_tail(moved_head(lots(list(qty = c(1, 1, 2, 1), price = c(10, 11, 12, 13))),
                              1L, 2L), 1L), pos = 1L, side = 1L, qty = 1, price = 14, simple = FALSE),
  mixed_block = list(book = flat_cap1(free_tail(lots(lot(5, 10), list(qty = c(2, 1), price = c(20, 21)), lot(-3, 9),
                                                     lot(4, 30)), 2L), 1L),
                     pos = c(3L, 2L, 1L, 4L), side = c(1L, 1L, 1L, -1L), qty = c(1, 1, 2, 4), price = c(8, 22, 11, 31),
                     fee = c(0.1, 0.2, 0.3, 0.4), simple = TRUE),
  mixed_block_one_through = list(book = roomy, pos = c(1L, 2L), side = c(-1L, -1L), qty = c(1, 3), price = c(9, 21),
                                 simple = FALSE),
  add_overflow = list(book = roomy, pos = 2L, side = 1L, qty = 1e300, price = 1e300, simple = FALSE)
)
rows <- lapply(names(cases), function(id) {
  k <- cases[[id]]
  fee <- k$fee %||% 0
  pin <- outcome(ns$ledgr_lot_fill(k$book, k$pos, k$side, k$qty, k$price, fee))
  off <- outcome(lean$lean_lot_fill(k$book, k$pos, k$side, k$qty, k$price, fee))
  on <- outcome(lean_dbg$lean_lot_fill(k$book, k$pos, k$side, k$qty, k$price, fee))
  input <- outcome(lean$lean_lot_input(1L, k$pos, k$side, k$qty, k$price, fee))
  took <- if (!is.null(input$class)) NA else !is.null(lean$lean_lot_simple(k$book, input))
  data.frame(case = id, simple_expected = k$simple, simple_taken = took, pin_refused = !is.null(pin$class),
             identical_debug_off = identical(off, pin), identical_debug_on = identical(on, pin),
             ok = identical(took, k$simple) && identical(off, pin) && identical(on, pin), stringsAsFactors = FALSE)
})
out <- do.call(rbind, rows)
utils::write.csv(out, arg("out"), row.names = FALSE)
print(out, row.names = FALSE)
if (!all(out$ok)) quit(status = 1L)
