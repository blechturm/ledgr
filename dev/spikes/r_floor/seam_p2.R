# Stage 3 seam: a lean strategy-context boundary (P2) on a changing axis.
# It hands the strategy a fresh, frozen context built from prepared planes
# and must reproduce, pulse by pulse, everything ledgr's strategy sees and
# returns. Holdings come from ledgr's own fills (P3-P5 are not this seam).

# What a strategy sees on one pulse, as one comparable record.
r_floor_p2_view <- function(ctx, with_history) {
  out <- list(
    universe = ctx$universe, member = unname(ctx$member), held = unname(ctx$held),
    buyable = unname(ctx$buyable), open = unname(ctx$open), high = unname(ctx$high),
    low = unname(ctx$low), close = unname(ctx$close), volume = unname(ctx$volume),
    fast = unname(ctx$fast), slow = unname(ctx$slow), hold = ctx$hold())
  if (with_history) {
    h <- ledgr_history_matrix(ctx, bar = "close", lookback = 10L)
    out$history <- unclass(h)[seq_len(nrow(h)), , drop = FALSE]
    out$history_cols <- colnames(h)
    attr(out$history, "dimnames") <- NULL
  }
  out
}

# The strategy rule used on both sides; history is read when asked.
r_floor_p2_rule <- function(view) {
  usable <- is.finite(view$fast) & is.finite(view$slow)
  targets <- view$hold
  up <- usable & view$fast > view$slow
  targets[up & view$member] <- 10
  targets[usable & !up] <- 0
  targets
}

# ledgr side: run the real fold and record every pulse's view and targets.
r_floor_p2_record <- function(fx, with_history, run_id) {
  rec <- new.env(); rec$views <- list(); rec$ts <- character()
  # ledgr's preflight refuses calls to unresolved user helpers, so the view
  # capture and the rule (r_floor_p2_view(), r_floor_p2_rule()) are inlined.
  strategy <- function(ctx, params) {
    v <- list(
      universe = ctx$universe, member = unname(ctx$member), held = unname(ctx$held),
      buyable = unname(ctx$buyable), open = unname(ctx$open), high = unname(ctx$high),
      low = unname(ctx$low), close = unname(ctx$close), volume = unname(ctx$volume),
      fast = unname(ctx$fast), slow = unname(ctx$slow), hold = ctx$hold())
    if (with_history) {
      h <- ledgr_history_matrix(ctx, bar = "close", lookback = 10L)
      v$history <- unclass(h)[seq_len(nrow(h)), , drop = FALSE]
      v$history_cols <- colnames(h)
      attr(v$history, "dimnames") <- NULL
    }
    usable <- is.finite(v$fast) & is.finite(v$slow)
    targets <- v$hold
    up <- usable & v$fast > v$slow
    targets[up & v$member] <- 10
    targets[usable & !up] <- 0
    v$targets <- unname(targets)
    rec$views[[length(rec$views) + 1L]] <- v
    rec$ts <- c(rec$ts, ctx$ts_utc)
    stats::setNames(targets, ctx$universe)
  }
  exp <- ledgr::ledgr_experiment(fx$snapshot, strategy,
    features = ledgr::ledgr_feature_map(
      fast = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "fast", n = 5L),
      slow = ledgr::ledgr_ind_ttr("SMA", input = "close", id = "slow", n = 10L)),
    opening = ledgr::ledgr_opening(cash = 1e7), cost_model = ledgr::ledgr_cost_zero(),
    universe = ledgr::ledgr_universe_members("U"),
    valuation_policy = ledgr::ledgr_valuation_stale(5))
  bt <- suppressWarnings(ledgr::ledgr_run(exp, run_id = run_id, seed = 1L))
  fills <- as.data.frame(ledgr::ledgr_results(bt, "fills"))
  close(bt)
  list(views = rec$views, ts = rec$ts, fills = fills)
}

# ledgr's price-input carry (history projection v11, on by default): a
# missing session's input is the last observed value for up to five
# sessions; the strategy-visible close stays NA.
r_floor_carry <- function(x, max_sessions = 5L) {
  last <- NA_real_; age <- 0L
  for (i in seq_along(x)) {
    if (!is.na(x[[i]])) { last <- x[[i]]; age <- 0L }
    else { age <- age + 1L; if (age <= max_sessions) x[[i]] <- last }
  }
  x
}

# Strict SMA over the carried series: TTR's running mean on each run without
# a remaining gap, valid once a full window is inside the run.
r_floor_strict_sma <- function(x, n) {
  y <- r_floor_carry(x)
  out <- rep(NA_real_, length(y))
  runs <- rle(!is.na(y)); ends <- cumsum(runs$lengths); starts <- ends - runs$lengths + 1L
  for (k in which(runs$values & runs$lengths >= n)) {
    i <- starts[[k]]:ends[[k]]
    out[i] <- TTR::SMA(y[i], n)
  }
  out
}

# Prepared planes for the lean side: instruments x sessions.
r_floor_p2_prepare <- function(fx, fills) {
  ids <- sort(fx$ids, method = "radix"); n <- length(ids); t_n <- length(fx$dates)
  ts <- as.POSIXct(paste(fx$dates, "21:00:00"), tz = "UTC")
  plane <- function(col) {
    m <- matrix(NA_real_, n, t_n, dimnames = list(ids, NULL))
    # ledgr stores prices rounded to eight decimals.
    m[cbind(match(fx$bars$instrument_id, ids), match(as.numeric(fx$bars$ts_utc), as.numeric(ts)))] <-
      round(fx$bars[[col]], 8L)
    m
  }
  p <- list(ids = ids, ts = ts, open = plane("open"), high = plane("high"), low = plane("low"),
            close = plane("close"), volume = plane("volume"))
  p$has_bar <- !is.na(p$close)
  p$close_carried <- t(apply(p$close, 1L, r_floor_carry))
  p$fast <- t(apply(p$close, 1L, r_floor_strict_sma, n = 5L))
  p$slow <- t(apply(p$close, 1L, r_floor_strict_sma, n = 10L))
  # Membership at decision time t (assume_effective intervals, half-open).
  from <- as.POSIXct(paste(fx$dates[fx$enter], "00:00:00"), tz = "UTC")
  to <- rep(Inf, n); out <- !is.na(fx$leave) & fx$leave > fx$enter
  to[out] <- as.numeric(as.POSIXct(paste(fx$dates[fx$leave[out]], "00:00:00"), tz = "UTC"))
  ord <- match(ids, fx$ids)
  p$member <- outer(as.numeric(from)[ord], as.numeric(ts), "<=") &
              outer(to[ord], as.numeric(ts), ">")
  # Holdings at decision t: every fill executed at or before t. A fill at
  # the next session's open belongs to the first decision after it.
  q <- ifelse(fills$side == "BUY", fills$qty, -fills$qty)
  delta <- matrix(0, n, t_n)
  k <- findInterval(as.numeric(fills$ts_utc), as.numeric(ts), left.open = TRUE) + 1L
  delta[cbind(match(fills$instrument_id, ids), k)] <- q
  p$position <- t(apply(delta, 1L, cumsum))
  p
}

# Lean P2: one fresh list per pulse, so a retained context cannot change.
r_floor_p2_lean_view <- function(p, t, with_history) {
  pos <- p$position[, t]
  # The decision axis: members in stable order, then held former members.
  a <- c(which(p$member[, t]), which(!p$member[, t] & pos != 0))
  ids <- p$ids[a]
  hold <- stats::setNames(pos[a], ids)
  v <- list(universe = ids, member = p$member[a, t], held = pos[a] != 0,
            buyable = p$member[a, t],
            open = p$open[a, t], high = p$high[a, t], low = p$low[a, t],
            close = p$close[a, t], volume = p$volume[a, t],
            fast = p$fast[a, t], slow = p$slow[a, t], hold = unname(hold))
  if (with_history) {
    # Admissible: members with a complete ten-session window.
    rows <- max(1L, t - 9L):t
    adm <- a[p$member[a, t]]
    adm <- if (length(rows) < 10L) integer() else
      adm[rowSums(is.na(p$close_carried[adm, rows, drop = FALSE])) == 0L]
    v$history <- t(p$close_carried[adm, rows, drop = FALSE])
    v$history_cols <- p$ids[adm]
    attr(v$history, "dimnames") <- NULL
  }
  v
}
