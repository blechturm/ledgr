# The R floor: the smallest plain-R fold that reproduces ledgr's fills and
# equity for the SMA5/10 transition rule on a fixed basket. Not product code.
#
# Semantics taken from the probe: a decision at pulse t fills at the open of
# pulse t + 1, stamped with that bar's time; the last pulse never fills;
# equity at pulse t is valued at its close before decision t executes.

r_floor_prepare <- function(fx) {
  bars <- fx$bars
  ids <- unique(bars$instrument_id)
  n <- length(ids)
  t_n <- fx$n_pulse
  plane <- function(col) matrix(bars[[col]], nrow = n, ncol = t_n, byrow = TRUE,
                                dimnames = list(ids, NULL))
  close <- plane("close")
  sma <- function(k) {
    out <- t(vapply(seq_len(n), function(i) TTR::SMA(close[i, ], k), numeric(t_n)))
    dimnames(out) <- list(ids, NULL)
    out
  }
  list(ids = ids, ts = unique(bars$ts_utc), open = plane("open"), close = close,
       fast = sma(5L), slow = sma(10L))
}

# Preallocated typed fill buffers; written by index, never grown.
r_floor_fill_buffer <- function(capacity) {
  list(inst = integer(capacity), pulse = integer(capacity),
       qty = numeric(capacity), price = numeric(capacity), n = 0L)
}

r_floor_finish <- function(p, fills, equity, cash_path) {
  k <- seq_len(fills$n)
  list(
    fills = data.frame(instrument_id = p$ids[fills$inst[k]], ts_utc = p$ts[fills$pulse[k]],
                       side = ifelse(fills$qty[k] > 0, "BUY", "SELL"),
                       qty = abs(fills$qty[k]), price = fills$price[k],
                       stringsAsFactors = FALSE),
    equity = data.frame(ts_utc = p$ts, equity = equity, cash = cash_path)
  )
}

# Variant "inline": the rule is written into the loop; no strategy call.
r_floor_fold_inline <- function(p, capacity = 1e6, gut = "") {
  n <- length(p$ids); t_n <- ncol(p$close)
  pos <- numeric(n); cash <- 1e7
  prev_above <- prev_usable <- logical(n)
  equity <- cash_path <- numeric(t_n)
  fills <- r_floor_fill_buffer(capacity)
  for (t in seq_len(t_n)) {
    cl <- p$close[, t]
    cash_path[t] <- cash
    equity[t] <- cash + sum(pos * cl)
    fast <- p$fast[, t]; slow <- p$slow[, t]
    usable <- is.finite(fast) & is.finite(slow)
    above <- usable & fast > slow
    target <- pos
    target[prev_usable & usable & above & !prev_above] <- 1
    target[prev_usable & usable & !above & prev_above] <- 0
    prev_above <- above; prev_usable <- usable
    if (t < t_n) {
      delta <- target - pos
      hit <- which(delta != 0)
      if (length(hit)) {
        exec <- if (identical(gut, "same_bar_fill")) t else t + 1L
        price <- p$open[hit, exec]
        dest <- fills$n + seq_along(hit)
        fills$inst[dest] <- hit; fills$pulse[dest] <- exec
        fills$qty[dest] <- delta[hit]; fills$price[dest] <- price
        fills$n <- fills$n + length(hit)
        pos[hit] <- target[hit]
        # Cash moves fill by fill in event order, as ledgr books it.
        for (k in seq_along(hit)) cash <- cash - delta[[hit[[k]]]] * price[[k]]
      }
    }
  }
  r_floor_finish(p, fills, equity, cash_path)
}

# Variant "strategy": the same rule through the shared strategy function, a
# reused context environment and named vectors, as a ledgr strategy sees it.
r_floor_fold_strategy <- function(p, strategy, capacity = 1e6) {
  n <- length(p$ids); t_n <- ncol(p$close)
  pos <- stats::setNames(numeric(n), p$ids); cash <- 1e7
  state <- list(above = stats::setNames(logical(n), p$ids),
                usable = stats::setNames(logical(n), p$ids))
  equity <- cash_path <- numeric(t_n)
  fills <- r_floor_fill_buffer(capacity)
  ctx <- new.env(parent = emptyenv())
  ctx$hold <- function() pos
  env <- new.env(parent = asNamespace("stats"))
  env$ledgr_strategy_result <- function(targets, ...) list(targets = targets, state = list(...))
  environment(strategy) <- env
  for (t in seq_len(t_n)) {
    cl <- p$close[, t]
    cash_path[t] <- cash
    equity[t] <- cash + sum(pos * cl)
    ctx$fast <- p$fast[, t]; ctx$slow <- p$slow[, t]; ctx$state <- state
    res <- strategy(ctx, NULL)
    target <- res$targets
    state <- res$state
    if (t < t_n) {
      delta <- target - pos
      hit <- which(delta != 0)
      if (length(hit)) {
        price <- p$open[hit, t + 1L]
        dest <- fills$n + seq_along(hit)
        fills$inst[dest] <- hit; fills$pulse[dest] <- t + 1L
        fills$qty[dest] <- unname(delta[hit]); fills$price[dest] <- price
        fills$n <- fills$n + length(hit)
        pos[hit] <- target[hit]
        # Cash moves fill by fill in event order, as ledgr books it.
        for (k in seq_along(hit)) cash <- cash - delta[[hit[[k]]]] * price[[k]]
      }
    }
  }
  r_floor_finish(p, fills, equity, cash_path)
}
