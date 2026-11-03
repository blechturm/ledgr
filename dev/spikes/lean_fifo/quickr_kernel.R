# The lean FIFO kernel's arithmetic core compiled with quickr (the compiler
# spike's pick for typed numerical kernels). One loop per row: rows of a
# block are distinct instruments, so each row performs the same operations
# in the same order as the vectorized steps. Compaction, growth and appends
# stay in R; anything unusual falls back to the canonical kernel.
#
# quickr takes no NA input, so dead lot slots enter as 0 and leave as 0; a
# live lot is never exactly 0, so the wrapper restores NA unambiguously.
# One packed double vector returns everything: q, p (2 x slots), eleven
# per-row columns, three totals and a flag (1 = fall back).

r_quickr_fifo_core_source <- function() {
  function(pos, side, qty, price, fee, q, p, off, head, tail, net_in, basis_in, tot) {
    declare(
      type(pos = integer(NA)), type(side = integer(NA)), type(qty = double(NA)),
      type(price = double(NA)), type(fee = double(NA)), type(q = double(NA)),
      type(p = double(NA)), type(off = integer(NA)), type(head = integer(NA)),
      type(tail = integer(NA)), type(net_in = double(NA)), type(basis_in = double(NA)),
      type(tot = double(3))
    )
    eps <- 2.220446049250313e-16
    m <- length(pos)
    s_n <- length(q)
    # Inputs are read-only in quickr; the lot slots are updated in copies.
    qq <- double(s_n)
    pp <- double(s_n)
    for (j in seq_len(s_n)) {
      qq[j] <- q[j]
      pp[j] <- p[j]
    }
    out <- double(2 * s_n + 11 * m + 4)
    flag <- 0
    for (k in seq_len(m)) {
      i <- pos[k]; h <- head[i]; tl <- tail[i]; o <- off[i]
      s <- side[k]
      netk <- net_in[i]; oldb <- basis_in[i]; pb <- netk
      rem <- qty[k]; cq <- 0; rc <- 0; bd <- 0
      go <- 0
      if (h <= tl) {
        if (qq[o + h] * s < 0) go <- 1
      }
      while (go == 1) {
        old <- qq[o + h]; oldp <- pp[o + h]
        cur <- abs(old)
        take <- min(cur, rem)
        if (s > 0) {
          diff <- oldp - price[k]
        } else {
          diff <- price[k] - oldp
        }
        rc <- rc + diff * take
        tp <- take * oldp
        if (s > 0) {
          bd <- bd + tp
        } else {
          bd <- bd - tp
        }
        cur <- cur - take
        left <- rem - take
        cq <- cq + take
        tol <- eps * max(1, abs(qty[k]), abs(take), abs(cur), abs(left))
        if (abs(left) <= tol) left <- 0
        rem <- left
        if (cur <= tol) {
          ns <- 0
          qq[o + h] <- 0
          pp[o + h] <- 0
          netk <- (netk - old) + ns
          h <- h + 1L
        } else {
          if (s > 0) {
            ns <- -cur
          } else {
            ns <- cur
          }
          qq[o + h] <- ns
          netk <- (netk - old) + ns
        }
        go <- 0
        if (rem > 0 && h <= tl) {
          if (qq[o + h] * s < 0) go <- 1
        }
      }
      open <- rem
      if (h > tl) {
        h <- 1L
        tl <- 0L
      }
      live <- tl - h + 1L
      rdelta <- rc - fee[k]
      if (open > 0) {
        if (s > 0) {
          signed <- open
        } else {
          signed <- -open
        }
        bd <- bd + signed * price[k]
        netk <- netk + signed
        if (live > 0) {
          front <- qq[o + h]
          if (front * s <= 0) flag <- 1
        }
      } else {
        if (h > tl) netk <- 0
      }
      newb <- oldb + bd
      tol2 <- eps * max(1, abs(newb), abs(netk), abs(qty[k]), abs(price[k]))
      if (abs(newb) <= tol2) newb <- 0
      b <- 2 * s_n + (k - 1) * 11
      out[b + 1] <- as.double(h); out[b + 2] <- as.double(tl); out[b + 3] <- netk; out[b + 4] <- newb
      out[b + 5] <- pb; out[b + 6] <- cq; out[b + 7] <- open; out[b + 8] <- rc
      out[b + 9] <- rdelta; out[b + 10] <- oldb
    }
    # Event-order totals: the kernel's scalar scan and Kahan step.
    total <- tot[1]; realized <- tot[2]; comp <- tot[3]
    for (k in seq_len(m)) {
      b <- 2 * s_n + (k - 1) * 11
      total <- total - out[b + 10] + out[b + 4]
      y <- out[b + 9] - comp
      tt <- realized + y
      comp <- (tt - realized) - y
      realized <- tt
      out[b + 10] <- total
      out[b + 11] <- realized
    }
    for (j in seq_len(s_n)) {
      out[j] <- qq[j]
      out[s_n + j] <- pp[j]
    }
    e <- 2 * s_n + 11 * m
    out[e + 1] <- total; out[e + 2] <- realized; out[e + 3] <- comp; out[e + 4] <- flag
    out
  }
}

# R side: book in and out, compaction, growth and appends as in the lean kernel.
r_quickr_fifo_fill <- function(book, pos, side, qty, price, fee = 0) {
  ns <- asNamespace("ledgr")
  m <- length(pos); fee <- rep_len(as.numeric(fee), m)
  canonical <- function() ns$ledgr_lot_apply(book, ns$ledgr_lot_input(1L, pos, side, qty, price, fee))
  if (!all(is.finite(qty)) || !all(is.finite(price)) || !all(is.finite(fee))) return(canonical())
  q0 <- book$lot_qty; q0[is.na(q0)] <- 0
  p0 <- book$lot_price; p0[is.na(p0)] <- 0
  s_n <- length(q0)
  r <- r_quickr_fifo_core(pos, side, qty, price, fee, q0, p0, book$offset, book$head,
    book$tail, book$net_by_inst, book$cost_basis_by_inst,
    c(book$total_cost_basis, book$realized_pnl, book$realized_comp))
  e <- 2L * s_n + 11L * m
  if (r[[e + 4L]] != 0 || !all(is.finite(r))) return(canonical())
  q <- r[seq_len(s_n)]; p <- r[s_n + seq_len(s_n)]
  dead <- q == 0; q[dead] <- NA_real_; p[dead] <- NA_real_
  rows <- matrix(r[2L * s_n + seq_len(11L * m)], nrow = 11L)
  head <- as.integer(rows[1L, ]); tail <- as.integer(rows[2L, ])
  net <- rows[3L, ]; open_qty <- rows[7L, ]
  off <- book$offset; cap <- book$capacity
  live <- tail - head + 1L
  appending <- open_qty > 0
  a <- which(appending)
  signed <- open_qty[a]; signed[side[a] < 0L] <- -open_qty[a][side[a] < 0L]
  compact <- which(live > 0L & ((head - 1L > live) | (appending & tail >= cap[pos] & head > 1L)))
  if (length(compact) > 0L) {
    k <- compact
    moved <- rep.int(k, live[k]); j <- sequence(live[k])
    src <- off[pos[moved]] + head[moved] + j - 1L; dst <- off[pos[moved]] + j
    q[dst] <- q[src]; p[dst] <- p[src]
    spare <- cap[pos[k]] - live[k]; cleared <- rep.int(k, spare)
    clear <- off[pos[cleared]] + live[cleared] + sequence(spare)
    q[clear] <- NA_real_; p[clear] <- NA_real_
    head[k] <- 1L; tail[k] <- live[k]
  }
  grow <- which(appending & tail >= cap[pos])
  if (length(grow) > 0L) {
    new_cap <- cap; new_cap[pos[grow]] <- pmax(4L, 2L * cap[pos[grow]])
    size <- length(new_cap); new_off <- c(0L, cumsum(new_cap)[-size])
    owner <- rep.int(seq_len(size), cap); dst <- new_off[owner] + sequence(cap)
    new_q <- rep(NA_real_, sum(new_cap)); new_p <- new_q
    new_q[dst] <- q; new_p[dst] <- p
    q <- new_q; p <- new_p; cap <- new_cap; off <- new_off
  }
  if (length(a) > 0L) {
    slot <- off[pos[a]] + tail[a] + 1L
    q[slot] <- signed; p[slot] <- price[a]; tail[a] <- tail[a] + 1L
  }
  book$offset <- off; book$capacity <- cap
  book$head[pos] <- head; book$tail[pos] <- tail
  book$lot_qty <- q; book$lot_price <- p
  book$net_by_inst[pos] <- net; book$cost_basis_by_inst[pos] <- rows[4L, ]
  book$total_cost_basis <- r[[e + 1L]]; book$realized_pnl <- r[[e + 2L]]
  book$realized_comp <- r[[e + 3L]]
  list(book = book, applied = list(position_before = rows[5L, ], position_after = net,
    close_qty = rows[6L, ], open_qty = open_qty, realized_close = rows[8L, ],
    realized_delta = rows[9L, ], event_realized = rows[11L, ], event_cost_basis = rows[10L, ]))
}
