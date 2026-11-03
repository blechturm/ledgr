# A leaner implementation of ledgr's one FIFO kernel, for fills (the fold's
# hot path). It performs the same floating-point operations in the same
# order as ledgr_lot_apply(), so books and applied rows are bit-identical.
# Differences: masked assignment instead of ifelse(), the dust tolerance
# inlined, no input or applied-row validation (a trusted fold boundary
# validates once), no per-call lot diagnostics. Anything unusual (non-finite
# input or result, opening through an opposing lot) falls back to the
# canonical kernel, so refusals stay exactly ledgr's.

# Counts calls that fell back to the canonical kernel.
r_lean_fifo_stats <- new.env()
r_lean_fifo_stats$fallbacks <- 0L

r_lean_fifo_fill <- function(book, pos, side, qty, price, fee = 0) {
  ns <- asNamespace("ledgr")
  m <- length(pos)
  fee <- rep_len(as.numeric(fee), m)
  canonical <- function() {
    r_lean_fifo_stats$fallbacks <- r_lean_fifo_stats$fallbacks + 1L
    ns$ledgr_lot_apply(book, ns$ledgr_lot_input(1L, pos, side, qty, price, fee))
  }
  if (!all(is.finite(qty)) || !all(is.finite(price)) || !all(is.finite(fee))) return(canonical())
  eps <- .Machine$double.eps
  q <- book$lot_qty; p <- book$lot_price; off <- book$offset; cap <- book$capacity
  head <- book$head[pos]; tail <- book$tail[pos]
  net <- book$net_by_inst[pos]; old_basis <- book$cost_basis_by_inst[pos]
  position_before <- net
  remaining <- qty
  close_qty <- numeric(m); realized_close <- numeric(m); basis_delta <- numeric(m)
  active <- which(head <= tail & q[off[pos] + head] * side < 0)
  while (length(active) > 0L) {
    a <- active
    slot <- off[pos[a]] + head[a]
    old <- q[slot]; old_price <- p[slot]
    buy <- side[a] > 0L
    current <- abs(old)
    take <- pmin(current, remaining[a])
    # ifelse(buy, old_price - price, price - old_price) * take, as masked
    # assignment of the same operations.
    diff <- price[a] - old_price
    diff[buy] <- old_price[buy] - price[a][buy]
    realized_close[a] <- realized_close[a] + diff * take
    tp <- take * old_price
    bd <- basis_delta[a]
    bd[buy] <- bd[buy] + tp[buy]
    bd[!buy] <- bd[!buy] - tp[!buy]
    basis_delta[a] <- bd
    current <- current - take
    left <- remaining[a] - take
    close_qty[a] <- close_qty[a] + take
    # ledgr_lot_dust_tolerance_rows(quantity, take, current, left), inlined.
    tol <- eps * pmax(1, abs(qty[a]), abs(take), abs(current), abs(left))
    left[abs(left) <= tol] <- 0
    remaining[a] <- left
    consumed <- current <= tol
    new_signed <- current
    new_signed[buy] <- -current[buy]
    new_signed[consumed] <- 0
    written <- new_signed
    written[consumed] <- NA_real_
    q[slot] <- written
    p[slot[consumed]] <- NA_real_
    net[a] <- (net[a] - old) + new_signed
    head[a] <- head[a] + consumed
    rest <- a[remaining[a] > 0 & head[a] <= tail[a]]
    active <- rest[which(q[off[pos[rest]] + head[rest]] * side[rest] < 0)]
  }
  open_qty <- remaining
  reset <- head > tail
  head[reset] <- 1L; tail[reset] <- 0L
  live <- tail - head + 1L
  realized_delta <- realized_close - fee
  appending <- open_qty > 0
  a <- which(appending)
  if (length(a) > 0L) {
    signed <- open_qty[a]
    short <- side[a] < 0L
    signed[short] <- -open_qty[a][short]
    basis_delta[a] <- basis_delta[a] + signed * price[a]
    net[a] <- net[a] + signed
  }
  new_basis <- old_basis + basis_delta
  net[head > tail & !appending] <- 0
  tol <- eps * pmax(1, abs(new_basis), abs(net), abs(qty), abs(price))
  new_basis[abs(new_basis) <= tol] <- 0
  # Event-order totals: the same scalar scan and Kahan step as the kernel.
  total <- book$total_cost_basis; realized <- book$realized_pnl; comp <- book$realized_comp
  gut_plain_sum <- identical(getOption("r_lean_fifo.gut"), "plain_sum")
  event_cost_basis <- numeric(m); event_realized <- numeric(m)
  for (k in seq_len(m)) {
    total <- total - old_basis[[k]] + new_basis[[k]]
    if (gut_plain_sum) {
      realized <- realized + realized_delta[[k]]  # gutted: no Kahan step
    } else {
      y <- realized_delta[[k]] - comp
      t <- realized + y
      comp <- (t - realized) - y
      realized <- t
    }
    event_cost_basis[[k]] <- total
    event_realized[[k]] <- realized
  }
  # Unusual rows go to the canonical kernel, which refuses them in order.
  # Opening through an unconsumed opposing lot is refused by the kernel.
  through <- which(open_qty > 0 & live > 0L)
  bad_through <- through[sign(q[off[pos[through]] + head[through]]) != side[through]]
  if (length(bad_through) > 0L || !is.finite(comp) || !all(is.finite(c(realized_close, basis_delta,
      net, new_basis, event_cost_basis, event_realized)))) {
    return(canonical())
  }
  # Compaction, growth and appends: the kernel's code paths, taken only when
  # needed.
  compact <- which(live > 0L & ((head - 1L > live) | (appending & tail >= cap[pos] & head > 1L)))
  if (length(compact) > 0L) {
    k <- compact
    moved <- rep.int(k, live[k]); j <- sequence(live[k])
    src <- off[pos[moved]] + head[moved] + j - 1L
    dst <- off[pos[moved]] + j
    q[dst] <- q[src]; p[dst] <- p[src]
    spare <- cap[pos[k]] - live[k]
    cleared <- rep.int(k, spare)
    clear <- off[pos[cleared]] + live[cleared] + sequence(spare)
    q[clear] <- NA_real_; p[clear] <- NA_real_
    head[k] <- 1L; tail[k] <- live[k]
  }
  grow <- which(appending & tail >= cap[pos])
  if (length(grow) > 0L) {
    new_cap <- cap
    new_cap[pos[grow]] <- pmax(4L, 2L * cap[pos[grow]])
    size <- length(new_cap)
    new_off <- c(0L, cumsum(new_cap)[-size])
    owner <- rep.int(seq_len(size), cap)
    dst <- new_off[owner] + sequence(cap)
    new_q <- rep(NA_real_, sum(new_cap)); new_p <- new_q
    new_q[dst] <- q; new_p[dst] <- p
    q <- new_q; p <- new_p; cap <- new_cap; off <- new_off
  }
  if (length(a) > 0L) {
    slot <- off[pos[a]] + tail[a] + 1L
    q[slot] <- signed; p[slot] <- price[a]
    tail[a] <- tail[a] + 1L
  }
  book$offset <- off; book$capacity <- cap
  book$head[pos] <- head; book$tail[pos] <- tail
  book$lot_qty <- q; book$lot_price <- p
  book$net_by_inst[pos] <- net; book$cost_basis_by_inst[pos] <- new_basis
  book$total_cost_basis <- total; book$realized_pnl <- realized; book$realized_comp <- comp
  list(book = book, applied = list(position_before = position_before, position_after = net,
    close_qty = close_qty, open_qty = open_qty, realized_close = realized_close,
    realized_delta = realized_delta, event_realized = event_realized,
    event_cost_basis = event_cost_basis))
}
