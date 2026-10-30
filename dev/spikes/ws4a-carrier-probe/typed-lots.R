# Contract: typed_lots_findings.md. Column containers only; unnamed atomic axes.
# Import/export are legacy-fold boundaries. No instrument lookup occurs in core.
typed_lot_import <- function(x) {
  cap <- as.integer(lengths(x$lot_qty)); n <- length(cap)
  stopifnot(n > 0L, sum(cap) <= .Machine$integer.max, identical(cap, as.integer(lengths(x$lot_price))))
  list(offset = as.integer(c(0L, cumsum(cap[-n]))), capacity = cap,
    head = as.integer(x$lot_head), tail = as.integer(x$lot_tail),
    lot_qty = as.numeric(unlist(x$lot_qty, use.names = FALSE)),
    lot_price = as.numeric(unlist(x$lot_price, use.names = FALSE)),
    net_by_inst = as.numeric(x$net_by_inst), cost_basis_by_inst = as.numeric(x$cost_basis_by_inst),
    total_cost_basis = x$total_cost_basis, realized_pnl = x$realized_pnl, realized_comp = x$realized_comp)
}
typed_lot_export <- function(template, s, groups) {
  template$lot_qty <- unname(split(s$lot_qty, groups))
  template$lot_price <- unname(split(s$lot_price, groups))
  ids <- template$instrument_ids
  template$lot_head <- setNames(s$head, ids); template$lot_tail <- setNames(s$tail, ids)
  template$net_by_inst <- setNames(s$net_by_inst, ids)
  template$cost_basis_by_inst <- setNames(s$cost_basis_by_inst, ids)
  template$total_cost_basis <- s$total_cost_basis
  template$realized_pnl <- s$realized_pnl; template$realized_comp <- s$realized_comp
  template
}
# Pure base R. Base copy-on-modify preserves old views; columns are written once
# per pulse, never by reference through an environment. FIFO depth is sequential
# within a book; each depth step processes all independent instruments together.
typed_lot_kernel <- function(s, ix, quantity, price, fee, direction, cash, lifo = FALSE) {
  q <- s$lot_qty; p <- s$lot_price; off <- s$offset; cap <- s$capacity
  head <- s$head[ix]; tail <- s$tail[ix]; net <- s$net_by_inst[ix]
  old_basis <- s$cost_basis_by_inst[ix]; m <- length(ix)
  remaining <- quantity; closed <- numeric(m); pnl <- numeric(m); basis_delta <- numeric(m)
  eps <- .Machine$double.eps
  active <- which(remaining > 0 & head <= tail & q[off[ix] + if (lifo) tail else head] * direction < 0)
  while (length(active)) {
    a <- active; slot <- off[ix[a]] + if (lifo) tail[a] else head[a]
    old <- q[slot]; old_price <- p[slot]; current <- abs(old)
    take <- pmin(current, remaining[a])
    pnl[a] <- pnl[a] + ifelse(direction[a] > 0, old_price - price[a], price[a] - old_price) * take
    basis_delta[a] <- ifelse(direction[a] > 0,
      basis_delta[a] + take * old_price, basis_delta[a] - take * old_price)
    current <- current - take; remaining[a] <- remaining[a] - take; closed[a] <- closed[a] + take
    tol <- eps * pmax(1, quantity[a], take, abs(current), abs(remaining[a]))
    remaining[a[abs(remaining[a]) <= tol]] <- 0
    consumed <- current <= tol
    signed <- ifelse(direction[a] > 0, -current, current); signed[consumed] <- 0
    q[slot] <- ifelse(consumed, NA_real_, signed); p[slot[consumed]] <- NA_real_
    net[a] <- (net[a] - old) + signed
    if (lifo) tail[a[consumed]] <- tail[a[consumed]] - 1L else head[a[consumed]] <- head[a[consumed]] + 1L
    active <- which(remaining > 0 & head <= tail & q[off[ix] + if (lifo) tail else head] * direction < 0)
  }
  empty <- head > tail; head[empty] <- 1L; tail[empty] <- 0L
  live <- pmax(0L, tail - head + 1L)
  # Merge canonical normal compaction and append's forced compaction: identical
  # moves, no arithmetic reduction. Pure opens and full closes use these vectors.
  compact <- which(live > 0L & ((head - 1L > live) | (remaining > 0 & tail >= cap[ix] & head > 1L)))
  if (length(compact)) {
    g <- rep.int(compact, live[compact]); seq <- sequence(live[compact])
    src <- off[ix[g]] + head[g] + seq - 1L; dest <- off[ix[g]] + seq
    q[dest] <- q[src]; p[dest] <- p[src]
    g <- rep.int(compact, cap[ix[compact]] - live[compact])
    clear <- off[ix[g]] + live[g] + sequence(cap[ix[compact]] - live[compact])
    q[clear] <- NA_real_; p[clear] <- NA_real_
    head[compact] <- 1L; tail[compact] <- live[compact]
  }
  opens <- which(remaining > 0)
  grow <- opens[tail[opens] >= cap[ix[opens]]]
  if (length(grow)) {
    new_cap <- cap; new_cap[ix[grow]] <- as.integer(pmax(4L, 2L * cap[ix[grow]]))
    stopifnot(sum(new_cap) <= .Machine$integer.max)
    new_off <- as.integer(c(0L, cumsum(new_cap[-length(new_cap)])))
    owner <- rep.int(seq_along(cap), cap); dest <- new_off[owner] + sequence(cap)
    new_q <- rep(NA_real_, sum(new_cap)); new_p <- rep(NA_real_, sum(new_cap))
    new_q[dest] <- q; new_p[dest] <- p
    q <- new_q; p <- new_p; cap <- new_cap; off <- new_off
  }
  signed_open <- ifelse(direction[opens] > 0, remaining[opens], -remaining[opens])
  slot <- off[ix[opens]] + tail[opens] + 1L
  q[slot] <- signed_open; p[slot] <- price[opens]; tail[opens] <- tail[opens] + 1L
  basis_delta[opens] <- basis_delta[opens] + signed_open * price[opens]
  net[opens] <- net[opens] + signed_open
  net[head > tail] <- 0
  basis <- old_basis + basis_delta
  tol <- eps * pmax(1, abs(basis), abs(net), quantity, price)
  basis[abs(basis) <= tol] <- 0
  # Canonical event-order totals cannot use sum/cumsum (different FP order).
  # This loop writes only local fill vectors and scalars, never axis-wide state.
  total <- s$total_cost_basis; realized <- s$realized_pnl; comp <- s$realized_comp
  event_basis <- numeric(m); event_realized <- numeric(m)
  delta <- ifelse(direction > 0, -(quantity * price + fee), quantity * price - fee)
  for (k in seq_len(m)) {
    total <- total - old_basis[k] + basis[k]
    y <- (pnl[k] - fee[k]) - comp; next_realized <- realized + y
    comp <- (next_realized - realized) - y; realized <- next_realized
    cash <- cash + delta[k]; event_basis[k] <- total; event_realized[k] <- realized
  }
  s$lot_qty <- q; s$lot_price <- p; s$offset <- off; s$capacity <- cap
  s$head[ix] <- head; s$tail[ix] <- tail; s$net_by_inst[ix] <- net; s$cost_basis_by_inst[ix] <- basis
  s$total_cost_basis <- total; s$realized_pnl <- realized; s$realized_comp <- comp
  list(typed = s, cash = cash, close_qty = closed, open_qty = remaining,
    realized_close = pnl, event_realized = event_realized, event_basis = event_basis)
}
typed_cache <- new.env(parent = emptyenv())
carrier_lots_typed <- function(fold, ix, quantity, price, fee, direction, cash) {
  # One owner per fold. Settlement/resume changes are detected by the existing
  # event sequence; unchanged typed state is carried across pulse boundaries.
  if (!identical(typed_cache$owner, fold)) { typed_cache$owner <- fold; typed_cache$typed_lots <- NULL }
  s <- typed_cache$typed_lots
  if (is.null(s) || !identical(typed_cache$typed_seq, fold$event_seq)) {
    s <- typed_lot_import(fold$lot_state); typed_cache$typed_groups <- NULL
  }
  previous_capacity <- length(s$lot_qty)
  result <- typed_lot_kernel(s, ix, quantity, price, fee, direction, cash, mutation == 'lifo')
  s <- result$typed
  if (is.null(typed_cache$typed_groups) || previous_capacity != length(s$lot_qty))
    typed_cache$typed_groups <- factor(rep.int(seq_along(s$capacity), s$capacity), levels = seq_along(s$capacity))
  result$state <- typed_lot_export(fold$lot_state, s, typed_cache$typed_groups)
  typed_cache$typed_lots <- s; typed_cache$typed_seq <- as.integer(fold$event_seq + length(ix))
  result
}
