# Stage 3, second seam: lean P1 valuation and P3-P5 on a changing axis,
# reusing ledgr's own FIFO lot kernel (ledgr_lot_fill) and cash scan. It is
# fed the axis and targets ledgr's strategy produced on every pulse and must
# reproduce ledgr's fills table and equity exactly.

# ledgr side: a real run whose strategy varies quantities, so sells consume
# FIFO lots partially; records every pulse's axis and targets.
r_floor_p35_record <- function(fx, run_id) {
  rec <- new.env(); rec$axis <- list(); rec$targets <- list(); rec$ts <- character()
  strategy <- function(ctx, params) {
    i <- length(rec$ts) + 1L
    usable <- is.finite(ctx$fast) & is.finite(ctx$slow)
    targets <- ctx$hold()
    up <- usable & ctx$fast > ctx$slow
    targets[up & ctx$member] <- 5 + (i %% 4) * 5
    targets[usable & !up] <- 0
    rec$axis[[i]] <- ctx$universe
    rec$targets[[i]] <- unname(targets)
    rec$ts[[i]] <- ctx$ts_utc
    targets
  }
  exp <- ledgr::ledgr_experiment(fx$snapshot, strategy,
    features = ledgr::ledgr_feature_map(
      fast = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
      slow = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L)),
    opening = ledgr::ledgr_opening(cash = 1e7), cost_model = ledgr::ledgr_cost_zero(),
    universe = ledgr::ledgr_universe_members("U"),
    valuation_policy = ledgr::ledgr_valuation_stale(5))
  bt <- suppressWarnings(ledgr::ledgr_run(exp, run_id = run_id, seed = 1L))
  out <- list(axis = rec$axis, targets = rec$targets, ts = rec$ts,
              fills = as.data.frame(ledgr::ledgr_results(bt, "fills")),
              equity = as.data.frame(ledgr::ledgr_results(bt, "equity")), exp = exp)
  close(bt)
  out
}

# Lean P1 and P3-P5 over prepared planes and the recorded decisions.
r_floor_p35_fold <- function(p, fx, decisions) {
  n <- length(p$ids); t_n <- ncol(p$close)
  open_ts <- as.POSIXct(paste(fx$dates, "14:30:00"), tz = "UTC")
  book <- ledgr:::ledgr_lot_book(n)
  cash <- 1e7
  mark <- rep(NA_real_, n)
  eq <- numeric(t_n); cash_path <- numeric(t_n); pv <- numeric(t_n)
  cap <- 1e5
  f_seq <- integer(cap); f_ts <- numeric(cap); f_rec <- numeric(cap); f_inst <- integer(cap)
  f_side <- integer(cap); f_qty <- numeric(cap); f_price <- numeric(cap)
  f_real <- numeric(cap); f_close <- numeric(cap); f_n <- 0L
  for (t in seq_len(t_n)) {
    # P1: value held positions at the last observed close (stale and
    # frozen marks keep the last close).
    seen <- p$has_bar[, t]
    mark[seen] <- p$close[seen, t]
    held <- book$net_by_inst != 0
    pv[[t]] <- sum(book$net_by_inst[held] * mark[held])
    cash_path[[t]] <- cash
    eq[[t]] <- cash + pv[[t]]
    if (t == t_n) break  # the last decision has no next open
    # P3: the decision's orders, in decision-axis order; an instrument
    # without a bar at the next session does not fill.
    a <- match(decisions$axis[[t]], p$ids)
    delta <- decisions$targets[[t]] - book$net_by_inst[a]
    go <- which(delta != 0 & p$has_bar[a, t + 1L])
    if (!length(go)) next
    pos <- a[go]; side <- as.integer(sign(delta[go])); qty <- abs(delta[go])
    price <- p$open[pos, t + 1L]
    # P4: ledgr's FIFO lot kernel and cash scan, in event order.
    res <- ledgr:::ledgr_lot_fill(book, pos, side, qty, price, 0)
    book <- res$book
    cash <- ledgr:::ledgr_cash_scan(cash, -side * qty * price)[[length(go)]]
    k <- f_n + seq_along(go)
    f_seq[k] <- k; f_ts[k] <- as.numeric(open_ts[[t + 1L]]); f_rec[k] <- as.numeric(p$ts[[t + 1L]])
    f_inst[k] <- pos; f_side[k] <- side; f_qty[k] <- qty; f_price[k] <- price
    # The fills reader reports a closing leg's own realized P&L (not the
    # book's running total), and zero for openings.
    f_real[k] <- ifelse(res$applied$close_qty > 0, res$applied$realized_close, 0)
    f_close[k] <- res$applied$close_qty
    f_n <- f_n + length(go)
  }
  k <- seq_len(f_n)
  list(
    fills = data.frame(event_seq = f_seq[k], ts_utc = f_ts[k], recording_pulse_ts_utc = f_rec[k],
      instrument_id = p$ids[f_inst[k]], side = ifelse(f_side[k] > 0, "BUY", "SELL"),
      qty = f_qty[k], price = f_price[k], fee = 0, realized_pnl = f_real[k],
      action = ifelse(f_close[k] > 0, "CLOSE", "OPEN"), stringsAsFactors = FALSE),
    equity = data.frame(ts_utc = as.numeric(p$ts), equity = eq, cash = cash_path,
                        positions_value = pv))
}

r_floor_p35_ledgr_frames <- function(rec) {
  f <- rec$fills
  f$ts_utc <- as.numeric(f$ts_utc); f$recording_pulse_ts_utc <- as.numeric(f$recording_pulse_ts_utc)
  f$event_seq <- as.integer(f$event_seq); f$qty <- as.numeric(f$qty)
  e <- rec$equity[c("ts_utc", "equity", "cash", "positions_value")]
  e$ts_utc <- as.numeric(e$ts_utc)
  rownames(f) <- NULL; rownames(e) <- NULL
  list(fills = as.data.frame(f)[c("event_seq", "ts_utc", "recording_pulse_ts_utc",
    "instrument_id", "side", "qty", "price", "fee", "realized_pnl", "action")], equity = e)
}
