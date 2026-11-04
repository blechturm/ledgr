# The typed lot book and its one FIFO implementation.
#
# Carrier contract: inst/design/rfc/rfc_typed_fold_carrier_v0_2_3_synthesis.md
# Section 4, groups "book", "lot input" and "applied row"; the operations are
# Section 3.4. Every consumer (fold, replay, readers, opening and resume,
# walk-forward carry, dispositions, terminal recovery, the handler's accounting
# fact and the compiled boundary) uses these functions; there is no second
# FIFO. Instruments are integer positions on the book's axis (the run axis
# inside the fold). ID-to-position conversion happens only in the named
# boundary helpers that build books from openings or ledger events.
#
# Book layout: flat segments. Instrument i owns the slots
# offset[i] + 1 .. offset[i] + capacity[i] of lot_qty and lot_price; its live
# FIFO lots are the segment slots head[i] .. tail[i] (empty: head 1, tail 0).
# Dead and unused slots hold NA. net_by_inst and cost_basis_by_inst are cached
# lot-derived aggregates maintained by the operations, never recomputed by a
# reduction. The kernel copies on modify; no book column is written by
# reference (decision 7).

# Lot input operation codes. They equal the prepared accounting-event codes of
# ledgr_prepare_accounting_events() (1 FILL, 3 opening CASHFLOW, 4
# DISPOSITION), so replay passes its operation column through unchanged.
.ledgr_lot_fill <- 1L
.ledgr_lot_opening <- 3L
.ledgr_lot_disposition <- 4L

ledgr_lot_book <- function(n = 0L) {
  n <- as.integer(n)
  list(
    offset = integer(n),
    capacity = integer(n),
    head = rep(1L, n),
    tail = integer(n),
    lot_qty = numeric(),
    lot_price = numeric(),
    net_by_inst = numeric(n),
    cost_basis_by_inst = numeric(n),
    total_cost_basis = 0,
    realized_pnl = 0,
    realized_comp = 0
  )
}

.ledgr_lot_book_fields <- c(
  "offset", "capacity", "head", "tail", "lot_qty", "lot_price",
  "net_by_inst", "cost_basis_by_inst", "total_cost_basis", "realized_pnl",
  "realized_comp"
)

# V-book: the first violated rule of the book group, or NULL. Types, exact
# lengths, disjoint prefix segments, live bounds, finite live and NA dead
# slots, and lot-derived aggregates.
#
# How the cached aggregates are derived decides what can be checked. An
# opening adds its quantity to the net and quantity times basis to the cost
# basis, so a book built by openings alone (`reduction = TRUE`) caches the
# left-to-right sums of its live lots in FIFO order, and the same additions
# repeated here are equal exactly. A fill or disposition instead updates the
# net as (net - consumed lot) + remainder, so its rounding error accumulates
# over every update since the instrument was last flat, including lots that
# are no longer live: buying 1e9, then 0.1, then selling 1e9 leaves a 0.1 lot
# under a cached net of 0.10000002384 (the base computes the same value).
# The error is bounded only by the history, which the book does not hold, so
# no bound in terms of the live lots is sound, and books reached by
# transitions (`reduction = FALSE`) are checked only where the arithmetic is
# exact: a flat instrument's net is 0. Transitions are checked where they
# happen (V-applied-row).
ledgr_lot_book_problem <- function(book, n = NULL, reduction = TRUE) {
  if (!is.list(book) || !identical(names(book), .ledgr_lot_book_fields)) {
    return("the book does not have exactly the typed book fields")
  }
  axis <- list(book$offset, book$capacity, book$head, book$tail)
  if (!all(vapply(axis, is.integer, logical(1))) ||
      !is.double(book$lot_qty) || !is.double(book$lot_price) ||
      !is.double(book$net_by_inst) || !is.double(book$cost_basis_by_inst)) {
    return("a book column has the wrong storage type")
  }
  totals <- list(book$total_cost_basis, book$realized_pnl, book$realized_comp)
  if (!all(vapply(totals, function(v) {
    is.double(v) && length(v) == 1L && is.finite(v)
  }, logical(1)))) {
    return("book totals must be finite double scalars")
  }
  size <- length(book$offset)
  if (!is.null(n) && size != n) return("the book axis does not match the run axis")
  if (any(lengths(axis) != size) || length(book$net_by_inst) != size ||
      length(book$cost_basis_by_inst) != size) {
    return("book axis columns have unequal lengths")
  }
  if (anyNA(book$capacity) || any(book$capacity < 0L) ||
      length(book$lot_qty) != sum(as.numeric(book$capacity)) ||
      length(book$lot_price) != length(book$lot_qty)) {
    return("book slot columns do not match the segment capacities")
  }
  # Segments are disjoint and laid out in axis order from slot 1.
  if (size > 0L && !identical(book$offset, c(0L, cumsum(book$capacity)[-size]))) {
    return("book segments are not disjoint prefix segments")
  }
  if (anyNA(book$head) || anyNA(book$tail) || any(book$head < 1L) ||
      any(book$tail > book$capacity) || any(book$head > book$tail + 1L)) {
    return("book live bounds are outside their segments")
  }
  live_n <- book$tail - book$head + 1L
  if (any(live_n == 0L & (book$head != 1L | book$tail != 0L))) {
    return("an empty segment must have head 1 and tail 0")
  }
  live <- ledgr_lot_book_live(book)
  dead <- rep(TRUE, length(book$lot_qty))
  dead[live$slot] <- FALSE
  if (!all(is.finite(live$qty)) || !all(is.finite(live$price)) ||
      !all(is.na(book$lot_qty[dead])) || !all(is.na(book$lot_price[dead]))) {
    return("live lots must be finite and dead slots NA")
  }
  if (!all(is.finite(book$net_by_inst)) || !all(is.finite(book$cost_basis_by_inst))) {
    return("book aggregates must be finite")
  }
  if (any(book$net_by_inst[live_n == 0L] != 0)) {
    return("a cached net position is not derived from its live lots")
  }
  if (isTRUE(reduction)) {
    net <- numeric(size)
    basis <- numeric(size)
    # FIFO depth iteration, vectorized across instruments.
    for (k in seq_len(max(0L, live_n))) {
      i <- which(live_n >= k)
      slot <- book$offset[i] + book$head[i] + k - 1L
      net[i] <- net[i] + book$lot_qty[slot]
      basis[i] <- basis[i] + book$lot_qty[slot] * book$lot_price[slot]
    }
    if (any(net != book$net_by_inst)) {
      return("a cached net position is not derived from its live lots")
    }
    if (any(basis != book$cost_basis_by_inst)) {
      return("a cached cost basis is not derived from its live lots")
    }
  }
  NULL
}

ledgr_lot_book_validate <- function(book, n = NULL, reduction = TRUE) {
  problem <- ledgr_lot_book_problem(book, n, reduction)
  if (!is.null(problem)) {
    rlang::abort(
      paste0("Invalid typed lot book: ", problem, "."),
      class = c("ledgr_lot_state_invariant", "ledgr_invalid_state")
    )
  }
  invisible(book)
}

# Appends empty instruments at the end of the axis. Used where a book's axis
# is a prefix of a longer one (a chunked or seeded replay meeting new IDs).
ledgr_lot_book_extend <- function(book, n) {
  size <- length(book$offset)
  if (n < size) {
    rlang::abort(
      "A lot book axis cannot shrink.",
      class = c("ledgr_lot_state_invariant", "ledgr_invalid_state")
    )
  }
  if (n == size) return(book)
  added <- n - size
  book$offset <- c(book$offset, rep(length(book$lot_qty), added))
  book$capacity <- c(book$capacity, integer(added))
  book$head <- c(book$head, rep(1L, added))
  book$tail <- c(book$tail, integer(added))
  book$net_by_inst <- c(book$net_by_inst, numeric(added))
  book$cost_basis_by_inst <- c(book$cost_basis_by_inst, numeric(added))
  book
}

# Keeps the first n axis entries. A replay book's axis starts with the run's
# instrument IDs; any further entry must hold nothing, so truncating it
# changes no aggregate.
ledgr_lot_book_restrict <- function(book, n) {
  size <- length(book$offset)
  if (size == n) return(book)
  extra <- seq_len(size)[seq_len(size) > n]
  if (size < n || any(book$tail[extra] >= book$head[extra]) ||
      any(book$net_by_inst[extra] != 0) || any(book$cost_basis_by_inst[extra] != 0)) {
    rlang::abort(
      "A lot book does not fit the run's instrument axis.",
      class = c("ledgr_lot_state_invariant", "ledgr_invalid_state")
    )
  }
  keep <- seq_len(n)
  slots <- sum(book$capacity[keep])
  book$offset <- book$offset[keep]
  book$capacity <- book$capacity[keep]
  book$head <- book$head[keep]
  book$tail <- book$tail[keep]
  book$lot_qty <- book$lot_qty[seq_len(slots)]
  book$lot_price <- book$lot_price[seq_len(slots)]
  book$net_by_inst <- book$net_by_inst[keep]
  book$cost_basis_by_inst <- book$cost_basis_by_inst[keep]
  book
}

ledgr_lot_book_live_count <- function(book, pos = seq_along(book$offset)) {
  pmax(0L, book$tail[pos] - book$head[pos] + 1L)
}

# Live lots of the axis positions `pos`, in the order of `pos` and FIFO order
# within each, gathered by slot index.
ledgr_lot_book_live <- function(book, pos = seq_along(book$offset)) {
  pos <- as.integer(pos)
  count <- ledgr_lot_book_live_count(book, pos)
  owner <- rep.int(pos, count)
  # The k-th live lot of instrument i sits at offset[i] + head[i] + k - 1.
  slot <- book$offset[owner] + book$head[owner] + sequence(count) - 1L
  list(pos = owner, slot = slot, qty = book$lot_qty[slot], price = book$lot_price[slot])
}

ledgr_lot_dust_tolerance <- function(...) {
  values <- abs(as.numeric(c(...)))
  values <- values[is.finite(values)]
  .Machine$double.eps * max(c(1, values))
}

# Row-wise form of ledgr_lot_dust_tolerance(): element k uses the k-th value
# of each argument. On scalar arguments the two agree exactly.
ledgr_lot_dust_tolerance_rows <- function(...) {
  scale <- 1
  for (value in list(...)) {
    value <- abs(as.numeric(value))
    value[!is.finite(value)] <- 0
    scale <- pmax(scale, value)
  }
  .Machine$double.eps * scale
}

# The canonical leg-fee split of each fill row: the closing leg takes the fee
# in proportion to its quantity, the opening leg the rest; a row with no
# positive finite quantity splits nothing.
ledgr_fill_leg_fees <- function(fee, close_qty, open_qty) {
  fee <- as.numeric(fee)
  close_qty <- as.numeric(close_qty)
  open_qty <- as.numeric(open_qty)
  total_qty <- close_qty + open_qty
  split <- is.finite(total_qty) & total_qty > 0
  close_fee <- numeric(length(fee))
  open_fee <- numeric(length(fee))
  closing <- split & close_qty > 0
  close_fee[closing] <- fee[closing] * close_qty[closing] / total_qty[closing]
  opening <- split & open_qty > 0
  open_fee[opening] <- fee[opening] - close_fee[opening]
  list(close = close_fee, open = open_fee)
}

# One compensated (Kahan) realized-P&L step: returns the new realized value
# and compensation. Fills and dispositions take one step each, in event
# order; openings take none.
ledgr_lot_add_realized <- function(realized, comp, delta) {
  y <- delta - comp
  t <- realized + y
  c(t, (t - realized) - y)
}

# Cash after each effect, added in event order. cumsum() accumulates in long
# double and can differ in the last bit, so this ordered scan stays scalar.
# It applies effects that were already computed; the lot kernel computes no
# cash.
ledgr_cash_scan <- function(cash, effects) {
  cash <- as.numeric(cash)
  out <- numeric(length(effects))
  for (i in seq_along(effects)) {
    cash <- cash + effects[[i]]
    out[[i]] <- cash
  }
  out
}

# Side tokens to carrier sides: BUY +1, SELL -1, anything else NA.
ledgr_lot_side <- function(side) {
  c(1L, -1L)[match(toupper(as.character(side)), c("BUY", "SELL"))]
}

# V-lot-input: one row per operation, distinct axis positions per kernel call.
# Columns are typed (I operation, pos, side; D qty, price, fee,
# position_before, realized_model_pnl), one value per row; fee and the two
# witnesses may be given once for all rows. Openings carry a signed nonzero
# quantity, a finite basis of either sign and side 0; fills carry side +/-1,
# positive quantity and price and a non-negative fee; dispositions carry
# side +/-1, positive quantity, a non-negative price and a zero fee, with an
# optional replay witness.
ledgr_lot_input <- function(operation,
                            pos,
                            side,
                            qty,
                            price,
                            fee = 0,
                            position_before = NA_real_,
                            realized_model_pnl = NA_real_) {
  invalid <- function() {
    rlang::abort(
      "Invalid fill input for lot accounting.",
      class = "ledgr_invalid_lot_fill"
    )
  }
  m <- length(pos)
  shared <- list(fee, position_before, realized_model_pnl)
  if (!is.integer(operation) || length(operation) != 1L ||
      !is.integer(pos) || !is.integer(side) || length(side) != m ||
      !is.double(qty) || length(qty) != m ||
      !is.double(price) || length(price) != m ||
      !all(vapply(shared, is.double, logical(1))) ||
      !all(lengths(shared) %in% unique(c(1L, m)))) {
    invalid()
  }
  input <- list(
    operation = rep_len(operation, m),
    pos = pos,
    side = side,
    qty = qty,
    price = price,
    fee = rep_len(fee, m),
    position_before = rep_len(position_before, m),
    realized_model_pnl = rep_len(realized_model_pnl, m)
  )
  op <- input$operation
  opening <- op %in% .ledgr_lot_opening
  disposition <- op %in% .ledgr_lot_disposition
  if (!all(op %in% c(.ledgr_lot_fill, .ledgr_lot_opening, .ledgr_lot_disposition)) ||
      anyNA(input$pos) || any(input$pos < 1L) || anyDuplicated(input$pos) ||
      anyNA(input$side) || any(input$side[opening] != 0L) ||
      any(!input$side[!opening] %in% c(-1L, 1L)) ||
      any(!is.finite(input$qty)) || any(input$qty[!opening] <= 0) ||
      any(input$qty[opening] == 0) ||
      any(!is.finite(input$price)) || any(input$price[op == .ledgr_lot_fill] <= 0) ||
      any(input$price[disposition] < 0) ||
      any(!is.finite(input$fee)) || any(input$fee < 0) ||
      any(input$fee[!(op == .ledgr_lot_fill)] != 0)) {
    invalid()
  }
  input
}

# V-applied-row: per-event facts of one kernel call, actual positions from
# lots. Openings close and open nothing; a fill or disposition splits its
# quantity into a closing and an opening part. `lots`, which the kernel always
# supplies, holds each row's FIFO step count and the sign of its head lot
# before and after the operation (0 when flat).
#
# The split is checked against the lots, before and after: a row closes iff
# its head lot opposed it before, and opens iff it appended a lot, after which
# its head lot is on its own side. The sum of the parts misses the quantity only by rounding and
# one dust snap: the k FIFO steps add each take to close_qty and subtract it
# from the remainder (each rounding at most eps/2 of a value no larger than
# the quantity), and a snapped remainder is at most eps * max(1, quantity).
# Twice that, 2 * (k + 1) * eps * max(1, quantity), is the allowance.
ledgr_lot_applied <- function(input,
                              position_before,
                              position_after,
                              close_qty,
                              open_qty,
                              realized_close,
                              realized_delta,
                              event_realized,
                              event_cost_basis,
                              lots = NULL) {
  out <- list(
    position_before = position_before,
    position_after = position_after,
    close_qty = close_qty,
    open_qty = open_qty,
    realized_close = realized_close,
    realized_delta = realized_delta,
    event_realized = event_realized,
    event_cost_basis = event_cost_basis
  )
  m <- length(input$pos)
  opening <- input$operation == .ledgr_lot_opening
  cons <- !opening
  steps <- lots$steps %||% integer(m)
  slack <- 2 * (steps + 1) * .Machine$double.eps * pmax(1, input$qty)
  split <- if (is.null(lots)) {
    TRUE
  } else {
    (close_qty[cons] > 0) == (lots$before[cons] == -input$side[cons]) &
      (open_qty[cons] > 0) == lots$appended[cons] &
      (open_qty[cons] == 0 | lots$after[cons] == input$side[cons])
  }
  if (!all(vapply(out, is.double, logical(1))) || any(lengths(out) != m) ||
      !all(is.finite(unlist(out, use.names = FALSE))) ||
      any(close_qty < 0) || any(open_qty < 0) ||
      any(close_qty[opening] != 0) || any(open_qty[opening] != 0) ||
      any(abs(close_qty + open_qty - input$qty)[cons] > slack[cons]) || !all(split)) {
    rlang::abort(
      "Invalid applied lot rows.",
      class = c("ledgr_lot_state_invariant", "ledgr_invalid_state")
    )
  }
  out
}

# The lot kernel: applies one block of operations whose instruments are
# distinct. Work on different instruments is independent and vectorized;
# FIFO consumption is sequential within an instrument (the depth loop); the
# total-basis and realized-P&L updates run as one scalar scan in row order,
# which is the canonical event order. Returns the new book and the applied
# rows. The input book is not modified.
ledgr_lot_apply <- function(book, input) {
  pos <- input$pos
  m <- length(pos)
  if (any(pos > length(book$offset))) {
    rlang::abort(
      "A lot operation names a position outside the book axis.",
      class = "ledgr_invalid_lot_fill"
    )
  }
  op <- input$operation
  side <- input$side
  quantity <- input$qty
  price <- input$price
  fee <- input$fee
  opening <- op == .ledgr_lot_opening
  consuming <- !opening

  q <- book$lot_qty
  p <- book$lot_price
  off <- book$offset
  cap <- book$capacity
  head <- book$head[pos]
  tail <- book$tail[pos]
  net <- book$net_by_inst[pos]
  old_basis <- book$cost_basis_by_inst[pos]
  position_before <- net
  # The sign of each row's head lot before the operation (0 when flat).
  head_sign <- function(h, t, o) {
    s <- numeric(m)
    held <- which(h <= t)
    s[held] <- sign(q[o[pos[held]] + h[held]])
    s
  }
  before <- head_sign(head, tail, off)

  # Fills and dispositions first consume opposing lots from the segment head.
  remaining <- ifelse(consuming, quantity, 0)
  close_qty <- numeric(m)
  realized_close <- numeric(m)
  basis_delta <- numeric(m)
  steps <- integer(m)
  # A row is active while it has quantity left and its head lot opposes it
  # (lot sign times side negative).
  active <- which(consuming & head <= tail & q[off[pos] + head] * side < 0)
  while (length(active) > 0L) {
    a <- active
    steps[a] <- steps[a] + 1L
    slot <- off[pos[a]] + head[a]
    old <- q[slot]
    old_price <- p[slot]
    buy <- side[a] > 0L
    current <- abs(old)
    take <- pmin(current, remaining[a])
    realized_close[a] <- realized_close[a] +
      ifelse(buy, old_price - price[a], price[a] - old_price) * take
    basis_delta[a] <- ifelse(
      buy,
      basis_delta[a] + take * old_price,
      basis_delta[a] - take * old_price
    )
    current <- current - take
    left <- remaining[a] - take
    close_qty[a] <- close_qty[a] + take
    tol <- ledgr_lot_dust_tolerance_rows(quantity[a], take, current, left)
    left[abs(left) <= tol] <- 0
    remaining[a] <- left
    consumed <- current <= tol
    new_signed <- ifelse(consumed, 0, ifelse(buy, -current, current))
    q[slot] <- ifelse(consumed, NA_real_, new_signed)
    p[slot[consumed]] <- NA_real_
    net[a] <- (net[a] - old) + new_signed
    head[a] <- head[a] + consumed
    rest <- a[remaining[a] > 0 & head[a] <= tail[a]]
    active <- rest[which(q[off[pos[rest]] + head[rest]] * side[rest] < 0)]
  }
  open_qty <- remaining

  # A consuming row that emptied its segment restarts it at slot 1.
  reset <- consuming & head > tail
  head[reset] <- 1L
  tail[reset] <- 0L
  live <- tail - head + 1L
  realized_delta <- realized_close - fee
  # A fill's closing results (realized P&L, closing basis change and the
  # position after closing) are complete here, before its through check.
  fill <- op == .ledgr_lot_fill
  closing_overflow <- fill & !(is.finite(realized_delta) & is.finite(basis_delta) & is.finite(net))

  # The appended lots' basis and positions, the dust rules and the
  # event-order totals are computed before the refusals; the slots are
  # written after them.
  appending <- opening | open_qty > 0
  a <- which(appending)
  if (length(a) > 0L) {
    # An opening's signed quantity, or a fill's unclosed remainder on its own
    # side. An opening's basis change is its quantity times its basis; a fill
    # adds the opened lot to its closing basis change.
    signed <- ifelse(
      opening[a],
      quantity[a],
      ifelse(side[a] > 0L, open_qty[a], -open_qty[a])
    )
    basis_delta[a] <- ifelse(
      opening[a],
      signed * price[a],
      basis_delta[a] + signed * price[a]
    )
    net[a] <- net[a] + signed
  }

  new_basis <- old_basis + basis_delta
  # Fills and dispositions: a flat instrument (an emptied segment that
  # appends nothing) has net exactly 0, and dust basis snaps to 0. Openings
  # keep their arithmetic (no dust rule).
  net[consuming & head > tail & !appending] <- 0
  f <- which(consuming)
  if (length(f) > 0L) {
    tol <- ledgr_lot_dust_tolerance_rows(new_basis[f], net[f], quantity[f], price[f])
    snap <- abs(new_basis[f]) <= tol
    new_basis[f[snap]] <- 0
  }

  # Canonical event-order totals: one scalar scan in row order (sum() and
  # cumsum() would use a different floating-point order). Openings take no
  # realized-P&L step.
  total <- book$total_cost_basis
  realized <- book$realized_pnl
  comp <- book$realized_comp
  event_cost_basis <- numeric(m)
  event_realized <- numeric(m)
  for (k in seq_len(m)) {
    total <- total - old_basis[[k]] + new_basis[[k]]
    if (consuming[[k]]) {
      step <- ledgr_lot_add_realized(realized, comp, realized_delta[[k]])
      realized <- step[[1L]]
      comp <- step[[2L]]
    }
    event_cost_basis[[k]] <- total
    event_realized[[k]] <- realized
  }
  # A fill's opened basis, position and totals come after its through
  # check. A non-finite compensation reaches the next row's realized total,
  # so only the last row's is checked here.
  late_overflow <- fill & !closing_overflow & !(is.finite(new_basis) & is.finite(net) &
    is.finite(event_cost_basis) & is.finite(event_realized))
  if (m > 0L && fill[[m]] && !is.finite(comp)) late_overflow[[m]] <- !closing_overflow[[m]]

  # Refusals keep the scalar event order: the earliest failing row refuses.
  # Within a row, a fill's closing overflow comes before opening through an
  # opposing lot, which comes before a disposition's exhaustion, its
  # realized witness, and then a fill's later overflow. The predicates are
  # vectorized; only the selection is ordered.
  witness <- input$realized_model_pnl
  bad_through <- integer()
  through <- which(consuming & open_qty > 0 & live > 0L)
  if (length(through) > 0L) {
    front <- sign(q[off[pos[through]] + head[through]])
    bad_through <- through[is.na(front) | front != side[through]]
  }
  d <- which(op == .ledgr_lot_disposition)
  # A fill whose finite inputs overflow lot accounting to a non-finite
  # value is refused as invalid fill input (cut 5 amendment_overflow). From
  # a corrupt book a non-finite result stays a state invariant (V-applied-row).
  overflow <- which(closing_overflow | late_overflow)
  if (length(overflow) > 0L && !is.null(ledgr_lot_book_problem(book, reduction = FALSE))) {
    overflow <- integer()
  }
  # Ordinary calls with no through failure, disposition or overflow skip the
  # failure selection.
  if (length(bad_through) > 0L || length(d) > 0L || length(overflow) > 0L) {
    fail <- integer(m)
    fail[bad_through] <- 1L
    fail[overflow[fail[overflow] == 0L | closing_overflow[overflow]]] <- 4L
    d <- d[fail[d] == 0L]
    if (length(d) > 0L) {
      # Replay compares the recorded realized model P&L with the canonical FIFO
      # realization at dust tolerance (all.equal() semantics on scalars).
      target <- realized_delta[d]
      tol <- ledgr_lot_dust_tolerance_rows(target)
      diff <- abs(target - witness[d])
      relative <- is.finite(abs(target)) & abs(target) > tol
      diff[relative] <- diff[relative] / abs(target[relative])
      mismatch <- !is.na(witness[d]) & target != witness[d] & (is.na(diff) | diff > tol)
      # A disposition must leave no live lot: none after consumption and none
      # appended.
      fail[d] <- ifelse(live[d] > 0L | open_qty[d] > 0, 2L, ifelse(mismatch, 3L, 0L))
    }
    first <- which(fail > 0L)
    if (length(first) > 0L) {
      k <- first[[1L]]
      if (fail[[k]] == 4L) {
        rlang::abort(
          "Invalid fill input for lot accounting.",
          class = "ledgr_invalid_lot_fill"
        )
      }
      if (fail[[k]] == 3L) {
        ledgr_accounting_event_error(
          "DISPOSITION realized model PnL does not match canonical FIFO realization.",
          "ledgr_invalid_ledger_meta"
        )
      }
      rlang::abort(
        if (fail[[k]] == 1L) {
          "Lot accounting cannot open through an unconsumed opposing lot."
        } else if (is.na(witness[[k]])) {
          "Disposition left live lots after reaching zero position."
        } else {
          "DISPOSITION must consume the position and every live lot exactly."
        },
        class = c("ledgr_lot_state_invariant", "ledgr_invalid_state")
      )
    }
  }

  # Compaction moves the live lots to the segment start: after consumption
  # when dead slots outnumber live ones, and before an append into a full
  # segment whose head has moved.
  compact <- which(live > 0L & (
    (consuming & head - 1L > live) |
      (appending & tail >= cap[pos] & head > 1L)
  ))
  if (length(compact) > 0L) {
    k <- compact
    moved <- rep.int(k, live[k])
    j <- sequence(live[k])
    src <- off[pos[moved]] + head[moved] + j - 1L
    dst <- off[pos[moved]] + j
    q[dst] <- q[src]
    p[dst] <- p[src]
    # Clear the segment slots after the moved lots.
    spare <- cap[pos[k]] - live[k]
    cleared <- rep.int(k, spare)
    clear <- off[pos[cleared]] + live[cleared] + sequence(spare)
    q[clear] <- NA_real_
    p[clear] <- NA_real_
    head[k] <- 1L
    tail[k] <- live[k]
  }

  # A full segment grows to max(4, 2 x capacity); every slot moves to the
  # same segment position under the new offsets.
  grow <- which(appending & tail >= cap[pos])
  if (length(grow) > 0L) {
    new_cap <- cap
    new_cap[pos[grow]] <- pmax(4L, 2L * cap[pos[grow]])
    if (sum(as.numeric(new_cap)) > .Machine$integer.max) {
      rlang::abort(
        "Lot book capacity exceeds the integer slot range.",
        class = c("ledgr_lot_state_invariant", "ledgr_invalid_state")
      )
    }
    size <- length(new_cap)
    new_off <- c(0L, cumsum(new_cap)[-size])
    owner <- rep.int(seq_len(size), cap)
    dst <- new_off[owner] + sequence(cap)
    new_q <- rep(NA_real_, sum(new_cap))
    new_p <- new_q
    new_q[dst] <- q
    new_p[dst] <- p
    q <- new_q
    p <- new_p
    cap <- new_cap
    off <- new_off
  }

  # Appends: the appended lots computed above, at the segment tails.
  tail_before_append <- tail
  if (length(a) > 0L) {
    slot <- off[pos[a]] + tail[a] + 1L
    q[slot] <- signed
    p[slot] <- price[a]
    tail[a] <- tail[a] + 1L
  }

  book$offset <- off
  book$capacity <- cap
  book$head[pos] <- head
  book$tail[pos] <- tail
  book$lot_qty <- q
  book$lot_price <- p
  book$net_by_inst[pos] <- net
  book$cost_basis_by_inst[pos] <- new_basis
  book$total_cost_basis <- total
  book$realized_pnl <- realized
  book$realized_comp <- comp
  list(
    book = book,
    applied = ledgr_lot_applied(
      input,
      position_before = position_before,
      position_after = net,
      close_qty = close_qty,
      open_qty = as.numeric(ifelse(opening, 0, open_qty)),
      realized_close = realized_close,
      realized_delta = as.numeric(ifelse(opening, 0, realized_delta)),
      event_realized = event_realized,
      event_cost_basis = event_cost_basis,
      lots = list(steps = steps, before = before, after = head_sign(head, tail, off),
        appended = tail > tail_before_append)
    )
  )
}

# The three operations. Each validates its lot input and calls the kernel.
ledgr_lot_opening <- function(book, pos, qty, price) {
  ledgr_lot_apply(
    book,
    ledgr_lot_input(.ledgr_lot_opening, pos, rep_len(0L, length(pos)), qty, price)
  )
}

ledgr_lot_fill <- function(book, pos, side, qty, price, fee = 0) {
  ledgr_lot_apply(book, ledgr_lot_input(.ledgr_lot_fill, pos, side, qty, price, fee))
}

ledgr_lot_disposition <- function(book, pos, side, qty, price,
                                  position_before = NA_real_,
                                  realized_model_pnl = NA_real_) {
  ledgr_lot_apply(
    book,
    ledgr_lot_input(
      .ledgr_lot_disposition, pos, side, qty, price, 0,
      position_before = position_before,
      realized_model_pnl = realized_model_pnl
    )
  )
}

# Consecutive conflict-free blocks of a row stream, as block numbers. A block
# ends where `new_run` starts a run or where an instrument repeats within
# its run; rows are never reordered, so repeated openings of one instrument
# stay successive transitions in successive blocks.
ledgr_lot_blocks <- function(pos, new_run) {
  n <- length(pos)
  if (n == 0L) return(integer())
  run <- cumsum(new_run)
  # A within-run repeat: the run number and position pair seen before.
  repeated <- duplicated(as.numeric(run) * (max(pos) + 1) + pos)
  cumsum(new_run | repeated)
}

# Applies the rows of one operation kind through the matching operation, in
# consecutive conflict-free blocks. Returns the final book and the applied
# rows in input order.
ledgr_lot_apply_blocks <- function(book, operation, pos, side, qty, price,
                                   fee, realized_model_pnl, new_run) {
  block <- ledgr_lot_blocks(pos, new_run)
  m <- length(pos)
  applied <- list(
    position_before = numeric(m), position_after = numeric(m),
    close_qty = numeric(m), open_qty = numeric(m),
    realized_close = numeric(m), realized_delta = numeric(m),
    event_realized = numeric(m), event_cost_basis = numeric(m)
  )
  if (m == 0L) return(list(book = book, applied = applied))
  starts <- which(c(TRUE, block[-1L] != block[-m]))
  ends <- c(starts[-1L] - 1L, m)
  for (b in seq_along(starts)) {
    j <- seq.int(starts[[b]], ends[[b]])
    op <- operation[[starts[[b]]]]
    res <- if (op == .ledgr_lot_opening) {
      ledgr_lot_opening(book, pos[j], qty[j], price[j])
    } else if (op == .ledgr_lot_fill) {
      ledgr_lot_fill(book, pos[j], side[j], qty[j], price[j], fee[j])
    } else {
      ledgr_lot_disposition(
        book, pos[j], side[j], qty[j], price[j],
        realized_model_pnl = realized_model_pnl[j]
      )
    }
    book <- res$book
    for (field in names(applied)) {
      applied[[field]][j] <- res$applied[[field]]
    }
  }
  list(book = book, applied = applied)
}

# Opening and carried-lot import (E boundary): a typed book on the axis
# `instrument_ids`. Carried lots, when given, are the book; otherwise each
# opening position with a cost basis becomes one lot. Entries without a
# usable ID, a nonzero finite quantity or a finite basis carry no lot, as
# before. Repeated carried lots of one instrument stay successive openings.
ledgr_lot_book_from_opening <- function(instrument_ids,
                                        positions = numeric(0),
                                        cost_basis = numeric(0),
                                        lots = NULL) {
  instrument_ids <- as.character(instrument_ids)
  book <- ledgr_lot_book(length(instrument_ids))
  if (!is.null(lots) && length(lots$instrument_id) > 0L) {
    ids <- as.character(lots$instrument_id)
    qty <- suppressWarnings(as.numeric(lots$qty))
    price <- suppressWarnings(as.numeric(lots$price))
  } else {
    if (is.null(positions) || length(positions) == 0L) return(book)
    ids <- names(positions) %||% character(length(positions))
    qty <- suppressWarnings(as.numeric(positions))
    basis_ids <- names(cost_basis) %||% character(length(cost_basis))
    price <- suppressWarnings(as.numeric(cost_basis))[match(ids, basis_ids)]
  }
  usable <- !is.na(ids) & nzchar(ids) & is.finite(qty) & qty != 0 & is.finite(price)
  ids <- ids[usable]
  pos <- match(ids, instrument_ids)
  if (anyNA(pos)) {
    rlang::abort(
      "Opening lots name instruments outside the run's instrument axis.",
      class = c("ledgr_lot_state_invariant", "ledgr_invalid_state")
    )
  }
  book <- ledgr_lot_apply_blocks(
    book, rep(.ledgr_lot_opening, length(pos)), pos, integer(length(pos)),
    qty[usable], price[usable], numeric(length(pos)), rep(NA_real_, length(pos)),
    new_run = c(TRUE, logical(max(0L, length(pos) - 1L)))
  )$book
  # Construction boundary: openings alone built this book, so its net and
  # cost basis are exactly the FIFO-order reductions of its lots.
  ledgr_lot_book_validate(book)
}

# The book after replaying ledger events. Its axis is the prepared axis:
# `instrument_ids` first, then any further ledger IDs.
ledgr_lot_book_from_events <- function(events, instrument_ids = character()) {
  if (is.null(events) || nrow(events) == 0L) {
    ids <- unique(as.character(instrument_ids))
    return(ledgr_lot_book(sum(!is.na(ids) & nzchar(ids))))
  }
  prepared <- ledgr_prepare_accounting_events(events, instrument_ids)
  ledgr_replay_accounting_events(prepared)$lot_state
}

ledgr_lot_book_asof <- function(con, run_id, instrument_ids, ts_utc) {
  rows <- DBI::dbGetQuery(
    con,
    "
    SELECT *
    FROM ledger_events
    WHERE run_id = ? AND ts_utc <= ?
      AND event_type IN ('CASHFLOW', 'DISPOSITION', 'FILL')
    ORDER BY event_seq
    ",
    params = list(run_id, ts_utc)
  )
  ledgr_lot_book_from_events(rows, instrument_ids = instrument_ids)
}
