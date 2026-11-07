# Lean FIFO lot kernel (LDG-3213): the one R implementation of opening, fill
# and disposition over the typed lot book, for the fold (P4), replay, opening
# import and terminal disposition callers. It is the executable oracle for
# any later compiled kernel (pulse plumbing R12).
#
# It reproduces the pinned ledgr_lot_apply() (R/lot-accounting.R:402 at the
# pin) bit for bit: the same floating-point operations in the same order,
# the same refusals in the same order. It never calls the pinned kernel, its
# operation wrappers or its arithmetic helpers; it shares only boundary
# validators and condition constructors (ledgr_lot_input, ledgr_lot_applied,
# ledgr_lot_book_problem, ledgr_accounting_event_error, ledgr_lot_blocks).
#
# Validation (interface table Section 11, pulse plumbing R1-R3):
# - lean_lot_input() is the trusted boundary. It keeps the economic input
#   rules in production; shape, type and distinct-position checks run only in
#   debug (LR-18).
# - lean_lot_apply() keeps every contracted refusal: position outside the
#   axis, fill overflow, opening through an opposing lot, disposition
#   exhaustion, replay witness, capacity, and a non-finite result from a
#   corrupt book. The applied-row self-check (LR-13) and the book check after
#   the call run only in debug.
#
# Differences from the pinned code that do not change any bit: masked
# assignment instead of ifelse(), the dust tolerance computed with one pmax()
# (exact for finite values, falling back to the pinned rule otherwise), and
# the finiteness predicates evaluated only when one cheap sum() says some
# value is not finite.
#
# `.lean_debug` is set by lean_core_load() in the environment this file is
# sourced into.

.lean_eps <- .Machine$double.eps
.lean_fill <- 1L
.lean_opening <- 3L
.lean_disposition <- 4L

# Row-wise dust tolerance: eps * max(1, |a|, |b|, |c|, |d|) per row, where a
# non-finite value counts as 0 (the pinned ledgr_lot_dust_tolerance_rows()).
# pmax() of finite values is exact in any order, so the common case is one
# call; only a row with a non-finite value takes the second pass.
lean_lot_tol <- function(a, b = 0, c = 0, d = 0) {
  s <- pmax(1, abs(a), abs(b), abs(c), abs(d))
  if (is.finite(sum(s))) return(.lean_eps * s)
  fin <- function(v) {
    v <- abs(v)
    v[!is.finite(v)] <- 0
    v
  }
  .lean_eps * pmax(1, fin(a), fin(b), fin(c), fin(d))
}

# The sign of each row's head lot (0 when the row's segment is empty).
# Debug only: it feeds the applied-row self-check.
lean_lot_head_sign <- function(q, off, pos, head, tail) {
  s <- numeric(length(pos))
  held <- which(head <= tail)
  s[held] <- sign(q[off[pos[held]] + head[held]])
  s
}

lean_invalid_input <- function() {
  rlang::abort("Invalid fill input for lot accounting.", class = "ledgr_invalid_lot_fill")
}

lean_state_invariant <- function(message) {
  rlang::abort(message, class = c("ledgr_lot_state_invariant", "ledgr_invalid_state"))
}

# Lot input for one operation (the trusted boundary). Same list as
# ledgr_lot_input(): operation, fee and the two witnesses recycled to the
# rows. Production checks the economic rules of each operation; debug first
# runs ledgr_lot_input() itself, which adds the shape, type and
# distinct-position checks with the same class and message.
lean_lot_input <- function(operation, pos, side, qty, price, fee = 0,
                           position_before = NA_real_, realized_model_pnl = NA_real_) {
  if (.lean_debug) ledgr_lot_input(operation, pos, side, qty, price, fee, position_before, realized_model_pnl)
  m <- length(pos)
  fee <- rep_len(fee, m)
  # One message for every rule, so their order is free. min() and one sum()
  # (non-finite or overflowing) replace the element-wise predicates; the
  # exact finiteness checks run only when the sum is not finite or a value
  # is not double (a mistyped value still refuses here, as pinned).
  bad <- m > 0L && (anyNA(pos) || anyNA(side) || min(pos) < 1L ||
    (!(is.double(qty) && is.double(price) && is.double(fee) && is.finite(sum(qty, price, fee))) &&
       (any(!is.finite(qty)) || any(!is.finite(price)) || any(!is.finite(fee)))) ||
    min(fee) < 0)
  if (!bad) {
    bad <- if (identical(operation, .lean_opening)) {
      m > 0L && (any(side != 0L) || any(qty == 0) || any(fee != 0))
    } else if (identical(operation, .lean_fill)) {
      m > 0L && (any(side != 1L & side != -1L) || min(qty) <= 0 || min(price) <= 0)
    } else if (identical(operation, .lean_disposition)) {
      m > 0L && (any(side != 1L & side != -1L) || min(qty) <= 0 || min(price) < 0 || any(fee != 0))
    } else {
      TRUE
    }
  }
  if (bad) lean_invalid_input()
  list(operation = rep_len(operation, m), pos = pos, side = side, qty = qty, price = price,
       fee = fee, position_before = rep_len(position_before, m),
       realized_model_pnl = rep_len(realized_model_pnl, m))
}

# The three operations, as the pinned wrappers build their input.
lean_lot_opening <- function(book, pos, qty, price) {
  lean_lot_apply(book, lean_lot_input(.lean_opening, pos, rep_len(0L, length(pos)), qty, price))
}

lean_lot_fill <- function(book, pos, side, qty, price, fee = 0) {
  lean_lot_apply(book, lean_lot_input(.lean_fill, pos, side, qty, price, fee))
}

lean_lot_disposition <- function(book, pos, side, qty, price,
                                 position_before = NA_real_, realized_model_pnl = NA_real_) {
  lean_lot_apply(book, lean_lot_input(.lean_disposition, pos, side, qty, price, 0,
                                      position_before = position_before,
                                      realized_model_pnl = realized_model_pnl))
}

# Close/open leg fees of fill rows: the closing leg takes the fee in
# proportion to its quantity, the opening leg the rest (CLOSE before OPEN).
# A row with no positive finite quantity splits nothing.
lean_fill_leg_fees <- function(fee, close_qty, open_qty) {
  total <- close_qty + open_qty
  split <- is.finite(total) & total > 0
  close_fee <- numeric(length(fee))
  open_fee <- numeric(length(fee))
  closing <- split & close_qty > 0
  close_fee[closing] <- fee[closing] * close_qty[closing] / total[closing]
  opening <- split & open_qty > 0
  open_fee[opening] <- fee[opening] - close_fee[opening]
  list(close = close_fee, open = open_fee)
}

# The kernel: one block of operations on distinct instruments. Work on
# different instruments is vectorized; FIFO consumption is sequential within
# an instrument (the depth loop); total basis and realized P&L are one scalar
# scan in row order, the canonical event order. Returns list(book, applied);
# the input book is not modified (copy on modify).
lean_lot_apply <- function(book, input) {
  pos <- input$pos
  m <- length(pos)
  if (m > 0L && max(pos) > length(book$offset)) {
    rlang::abort("A lot operation names a position outside the book axis.",
                 class = "ledgr_invalid_lot_fill")
  }
  op <- input$operation
  side <- input$side
  quantity <- input$qty
  price <- input$price
  fee <- input$fee
  opening <- op == .lean_opening
  consuming <- !opening
  debug <- .lean_debug

  q <- book$lot_qty
  p <- book$lot_price
  off <- book$offset
  # Each row's segment offset, fixed until the segments grow (below).
  base <- off[pos]
  cap <- book$capacity
  head <- book$head[pos]
  tail <- book$tail[pos]
  net <- book$net_by_inst[pos]
  old_basis <- book$cost_basis_by_inst[pos]
  position_before <- net
  if (debug) {
    before <- lean_lot_head_sign(q, off, pos, head, tail)
    steps <- integer(m)
  }

  # Fills and dispositions consume opposing lots from the segment head while
  # quantity is left and the head lot opposes the row (lot sign * side < 0).
  remaining <- quantity
  remaining[opening] <- 0
  close_qty <- numeric(m)
  realized_close <- numeric(m)
  basis_delta <- numeric(m)
  active <- which(consuming & head <= tail & q[base + head] * side < 0)
  while (length(active) > 0L) {
    a <- active
    if (debug) steps[a] <- steps[a] + 1L
    slot <- base[a] + head[a]
    old <- q[slot]
    old_price <- p[slot]
    s <- side[a]
    current <- abs(old)
    take <- pmin(current, remaining[a])
    # Buy closes a short: (old price - price) * take; sell: (price - old) *
    # take. The side (+1 or -1) carries the sign: negation and a product
    # with +-1 are exact, so these are the pinned operations bit for bit.
    realized_close[a] <- realized_close[a] + ((price[a] - old_price) * -s) * take
    basis_delta[a] <- basis_delta[a] + s * (take * old_price)
    current <- current - take
    left <- remaining[a] - take
    close_qty[a] <- close_qty[a] + take
    # Dust snap: a remainder or lot within eps * scale of zero is zero. The
    # pinned scale also takes |take| and |left|; both are at most the row's
    # quantity (take <= remaining <= quantity), so they never set the max.
    tol <- lean_lot_tol(quantity[a], current)
    left[abs(left) <= tol] <- 0
    remaining[a] <- left
    consumed <- current <= tol
    new_signed <- -s * current
    new_signed[consumed] <- 0
    written <- new_signed
    written[consumed] <- NA_real_
    q[slot] <- written
    p[slot[consumed]] <- NA_real_
    net[a] <- (net[a] - old) + new_signed
    head[a] <- head[a] + consumed
    rest <- a[remaining[a] > 0 & head[a] <= tail[a]]
    active <- rest[which(q[base[rest] + head[rest]] * side[rest] < 0)]
  }
  open_qty <- as.numeric(remaining)

  # A consuming row that emptied its segment restarts it at slot 1.
  reset <- consuming & head > tail
  head[reset] <- 1L
  tail[reset] <- 0L
  live <- tail - head + 1L
  realized_delta <- realized_close - fee
  # A fill's closing results matter only to its overflow check: kept (copy
  # on modify) only when one sum() says some value is not finite.
  closing_nonfinite <- !is.finite(sum(realized_delta, basis_delta, net))
  if (closing_nonfinite) {
    basis_closing <- basis_delta
    net_closing <- net
  }

  # Appended lots: an opening's signed quantity at its basis (no realized
  # step, no cash), or a consuming row's remainder on its own side.
  appending <- opening | open_qty > 0
  a <- which(appending)
  if (length(a) > 0L) {
    signed <- quantity[a]
    cons_a <- consuming[a]
    signed[cons_a] <- side[a][cons_a] * open_qty[a][cons_a]
    bd <- signed * price[a]
    bd[cons_a] <- basis_delta[a][cons_a] + bd[cons_a]
    basis_delta[a] <- bd
    net[a] <- net[a] + signed
  }

  new_basis <- old_basis + basis_delta
  # Consuming rows: a flat instrument has net exactly 0 and dust basis snaps
  # to 0. Openings keep their arithmetic.
  net[consuming & head > tail & !appending] <- 0
  f <- which(consuming)
  if (length(f) > 0L) {
    tol <- lean_lot_tol(new_basis[f], net[f], quantity[f], price[f])
    new_basis[f[abs(new_basis[f]) <= tol]] <- 0
  }

  # Event-order totals: one scalar scan in row order (sum() and cumsum()
  # would add in a different order). Fills and dispositions take one
  # compensated (Kahan) realized step each; openings take none.
  total <- book$total_cost_basis
  realized <- book$realized_pnl
  comp <- book$realized_comp
  event_cost_basis <- numeric(m)
  event_realized <- numeric(m)
  for (k in seq_len(m)) {
    total <- total - old_basis[[k]] + new_basis[[k]]
    if (consuming[[k]]) {
      y <- realized_delta[[k]] - comp
      t <- realized + y
      comp <- (t - realized) - y
      realized <- t
    }
    event_cost_basis[[k]] <- total
    event_realized[[k]] <- realized
  }

  # Overflow: only when some value is not finite (one sum() decides). A fill
  # refuses at its closing overflow or, after its through check, at a later
  # overflow; a non-finite compensation reaches only the last row. From a
  # corrupt book a non-finite result is a state invariant instead.
  overflow <- integer()
  nonfinite <- closing_nonfinite ||
    !is.finite(sum(position_before, net, close_qty, open_qty, realized_close,
                   realized_delta, event_realized, event_cost_basis, new_basis, comp))
  if (nonfinite) {
    fill <- op == .lean_fill
    closing_overflow <- if (closing_nonfinite) {
      fill & !(is.finite(realized_delta) & is.finite(basis_closing) & is.finite(net_closing))
    } else {
      logical(m)
    }
    late_overflow <- fill & !closing_overflow & !(is.finite(new_basis) & is.finite(net) &
      is.finite(event_cost_basis) & is.finite(event_realized))
    if (m > 0L && fill[[m]] && !is.finite(comp)) late_overflow[[m]] <- !closing_overflow[[m]]
    overflow <- which(closing_overflow | late_overflow)
    if (length(overflow) > 0L && !is.null(ledgr_lot_book_problem(book, reduction = FALSE))) {
      overflow <- integer()
    }
  }

  # Refusals in scalar event order: the earliest failing row refuses. Within
  # a row: closing overflow, opening through an opposing lot, disposition
  # exhaustion, realized witness, later overflow.
  witness <- input$realized_model_pnl
  bad_through <- integer()
  through <- which(consuming & open_qty > 0 & live > 0L)
  if (length(through) > 0L) {
    front <- sign(q[base[through] + head[through]])
    bad_through <- through[is.na(front) | front != side[through]]
  }
  d <- which(op == .lean_disposition)
  if (length(bad_through) > 0L || length(d) > 0L || length(overflow) > 0L) {
    fail <- integer(m)
    fail[bad_through] <- 1L
    if (length(overflow) > 0L) fail[overflow[fail[overflow] == 0L | closing_overflow[overflow]]] <- 4L
    d <- d[fail[d] == 0L]
    if (length(d) > 0L) {
      # The replay witness matches the FIFO realization at dust tolerance
      # (all.equal() semantics on scalars).
      target <- realized_delta[d]
      tol <- lean_lot_tol(target)
      diff <- abs(target - witness[d])
      relative <- is.finite(abs(target)) & abs(target) > tol
      diff[relative] <- diff[relative] / abs(target[relative])
      mismatch <- !is.na(witness[d]) & target != witness[d] & (is.na(diff) | diff > tol)
      # A disposition leaves no live lot: none after consumption, none appended.
      fail[d] <- ifelse(live[d] > 0L | open_qty[d] > 0, 2L, ifelse(mismatch, 3L, 0L))
    }
    first <- which(fail > 0L)
    if (length(first) > 0L) {
      k <- first[[1L]]
      if (fail[[k]] == 4L) lean_invalid_input()
      if (fail[[k]] == 3L) {
        ledgr_accounting_event_error(
          "DISPOSITION realized model PnL does not match canonical FIFO realization.",
          "ledgr_invalid_ledger_meta"
        )
      }
      lean_state_invariant(
        if (fail[[k]] == 1L) {
          "Lot accounting cannot open through an unconsumed opposing lot."
        } else if (is.na(witness[[k]])) {
          "Disposition left live lots after reaching zero position."
        } else {
          "DISPOSITION must consume the position and every live lot exactly."
        }
      )
    }
  }

  # Compaction moves the live lots to the segment start: after consumption
  # when dead slots outnumber live ones, and before an append into a full
  # segment whose head has moved.
  compact <- which(live > 0L & ((consuming & head - 1L > live) | (appending & tail >= cap[pos] & head > 1L)))
  if (length(compact) > 0L) {
    k <- compact
    moved <- rep.int(k, live[k])
    j <- sequence(live[k])
    src <- base[moved] + head[moved] + j - 1L
    dst <- base[moved] + j
    q[dst] <- q[src]
    p[dst] <- p[src]
    spare <- cap[pos[k]] - live[k]
    cleared <- rep.int(k, spare)
    clear <- base[cleared] + live[cleared] + sequence(spare)
    q[clear] <- NA_real_
    p[clear] <- NA_real_
    head[k] <- 1L
    tail[k] <- live[k]
  }

  # A full segment grows to max(4, 2 x capacity); every slot keeps its
  # segment position under the new offsets.
  grow <- which(appending & tail >= cap[pos])
  if (length(grow) > 0L) {
    new_cap <- cap
    new_cap[pos[grow]] <- pmax(4L, 2L * cap[pos[grow]])
    if (sum(as.numeric(new_cap)) > .Machine$integer.max) {
      lean_state_invariant("Lot book capacity exceeds the integer slot range.")
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
  applied <- list(position_before = position_before, position_after = net, close_qty = close_qty,
                  open_qty = open_qty, realized_close = realized_close, realized_delta = realized_delta,
                  event_realized = event_realized, event_cost_basis = event_cost_basis)
  # A non-finite applied value with no refusal above (an opening or
  # disposition overflow, or any overflow from a corrupt book).
  if (nonfinite && !all(is.finite(unlist(applied, use.names = FALSE)))) {
    lean_state_invariant("Invalid applied lot rows.")
  }
  if (debug) {
    ledgr_lot_applied(input, position_before, net, close_qty, open_qty, realized_close,
                      realized_delta, event_realized, event_cost_basis,
                      lots = list(steps = steps, before = before,
                                  after = lean_lot_head_sign(q, off, pos, head, tail),
                                  appended = tail > tail_before_append))
    ledgr_lot_book_validate(book, reduction = FALSE)
  }
  list(book = book, applied = applied)
}

# Applies a row stream in consecutive conflict-free blocks (ledgr_lot_blocks:
# a block ends where `new_run` starts a run or an instrument repeats; rows
# are never reordered and repeated openings stay successive lots). Each
# block takes its first row's operation. Returns the final book and the
# applied rows in input order.
lean_lot_apply_blocks <- function(book, operation, pos, side, qty, price,
                                  fee, realized_model_pnl, new_run) {
  m <- length(pos)
  applied <- list(position_before = numeric(m), position_after = numeric(m),
                  close_qty = numeric(m), open_qty = numeric(m),
                  realized_close = numeric(m), realized_delta = numeric(m),
                  event_realized = numeric(m), event_cost_basis = numeric(m))
  if (m == 0L) return(list(book = book, applied = applied))
  block <- ledgr_lot_blocks(pos, new_run)
  starts <- which(c(TRUE, block[-1L] != block[-m]))
  ends <- c(starts[-1L] - 1L, m)
  for (b in seq_along(starts)) {
    j <- seq.int(starts[[b]], ends[[b]])
    op <- operation[[starts[[b]]]]
    res <- if (op == .lean_opening) {
      lean_lot_opening(book, pos[j], qty[j], price[j])
    } else if (op == .lean_fill) {
      lean_lot_fill(book, pos[j], side[j], qty[j], price[j], fee[j])
    } else {
      lean_lot_disposition(book, pos[j], side[j], qty[j], price[j],
                           realized_model_pnl = realized_model_pnl[j])
    }
    book <- res$book
    for (field in names(applied)) applied[[field]][j] <- res$applied[[field]]
  }
  list(book = book, applied = applied)
}
