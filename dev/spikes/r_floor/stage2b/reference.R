# R-floor stage 2b: the guarantee-preserving reference loop (CHARTER_stage2b.md).
# A research instrument, not product code. One plain-R loop over prepared
# planes; each guarantee is a switch in `g`, so it can be priced alone,
# accumulated or with all others on:
#
#   cost    cost steps, affordability scan and its reconciliation (charter 1)
#   risk    max_weight and the post-risk and short-exposure checks (2)
#   sizing  the sizing evidence checked at the strategy boundary, its rows (3)
#   fifo    lots through dev/lean_core/fifo.R and position facts (4)
#   state   declared strategy state checked on every patch (5)
#   rng     the run seed and per-pulse seeds, caller state restored (6)
#
# Always on (the stage-2 floor): the strategy call on a plain list context,
# target validation, fixed-basket availability, the equity row, the compact
# decision records and the reconciliation record. Package code it calls, as
# the lean loop does: the strategy, the sizing helper, ledgr_strategy_result(),
# ledgr_lot_book(), lean_lot_fill() and the run's seed functions (reuse).

s2b_all <- c(cost = TRUE, risk = TRUE, sizing = TRUE, fifo = TRUE, state = TRUE, rng = TRUE)

# The workload as the reference sees it: planes, strategy and run settings.
s2b_workload <- function(id, defs) {
  desc <- defs$bench_descriptor(id)
  fx <- list(bars = desc$bars(), n_pulse = desc$pulses)
  p <- defs$r_floor_prepare(fx)
  n <- length(p$ids)
  plane <- function(col) matrix(fx$bars[[col]], nrow = n, byrow = TRUE)
  w <- list(id = id, ids = p$ids, ts = as.numeric(p$ts), open = unname(p$open), close = unname(p$close),
            high = plane("high"), low = plane("low"), volume = plane("volume"), cash = 1e7, seed = 20260530L)
  w$iso <- format(p$ts, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  if (desc$family == "crossover") {
    w$strategy <- defs$r_floor_transition
    environment(w$strategy) <- asNamespace("ledgr")
    w$fast <- unname(p$fast); w$slow <- unname(p$slow)
    w$steps <- list(); w$max_weight <- NULL
    w$fields <- list(above = list(scope = "asset", type = "logical"), usable = list(scope = "asset", type = "logical"))
    w$state0 <- list(above = stats::setNames(logical(n), p$ids), usable = stats::setNames(logical(n), p$ids))
  } else {
    w$strategy <- defs$bench_slice2_strategy(stats::setNames(rep(0.08, n), p$ids))
    w$steps <- list(list(type = "spread_bps", bps = 10), list(type = "fixed_fee", amount = 1),
                    list(type = "notional_bps_fee", bps = 5))
    w$max_weight <- 0.05
    w$fields <- list(k = list(scope = "portfolio", type = "integer"))
    w$state0 <- list(k = 0L)
  }
  w
}

s2b_refuse <- function(class, message) rlang::abort(message, class = class)

# Charter 1: the cost steps in their order on whole columns, price rounded last.
s2b_cost <- function(steps, side, qty, open) {
  price <- open; fee <- numeric(length(open))
  for (s in steps) {
    if (s$type == "spread_bps") price <- price * ifelse(side > 0L, 1 + s$bps / 20000, 1 - s$bps / 20000)
    else if (s$type == "fixed_fee") fee <- fee + s$amount
    else fee <- fee + abs(qty * price) * s$bps / 10000
  }
  list(price = round(price, 8L), fee = fee)
}

s2b_gross <- function(q, m) { v <- abs(q * m); v[q == 0] <- 0; if (anyNA(v) || !all(is.finite(v))) NA_real_ else sum(v) }

s2b_run <- function(w, g = s2b_all, gut = "") {
  ids <- w$ids; n <- length(ids); T <- length(w$ts)
  tol <- sqrt(.Machine$double.eps); cash_tol <- ledgr:::ledgr_availability_cash_tolerance
  rank <- integer(n); rank[order(enc2utf8(ids), method = "radix")] <- seq_len(n)
  pulse_seed <- NULL
  if (g[["rng"]]) {
    rng <- ledgr:::ledgr_rng_caller_state(); on.exit(ledgr:::ledgr_rng_restore(rng), add = TRUE)
    ledgr:::ledgr_rng_seed_pinned(w$seed); pulse_seed <- ledgr:::ledgr_pulse_seeds(w$seed, seq_len(T))
  }
  pos <- numeric(n); cash <- w$cash
  book <- if (g[["fifo"]]) ledgr:::ledgr_lot_book(n)
  entry_bar <- exit_bar <- rep(NA_integer_, n)
  state <- w$state0
  named <- function(x) { names(x) <- ids; x }
  eq <- list(ts = numeric(T), cash = numeric(T), positions_value = numeric(T), realized_pnl = numeric(T), cost_basis = numeric(T))
  cap <- 16L * T
  fl <- list(pulse = integer(cap), k = integer(cap), side = integer(cap), qty = numeric(cap), price = numeric(cap),
             fee = numeric(cap), cash_delta = numeric(cap), position_delta = numeric(cap), exec_ts = numeric(cap),
             position_before = numeric(cap), planned_position_after = numeric(cap), clean = logical(cap),
             target = numeric(cap), strategy_target = numeric(cap), close_qty = numeric(cap), open_qty = numeric(cap),
             realized_close = numeric(cap), net_after = numeric(cap))
  dr <- list(pulse = integer(cap), k = integer(cap), target = numeric(cap), target_after = numeric(cap), position = numeric(cap))
  szr <- list(pulse = integer(cap), id = character(cap), reason = character(cap), target = numeric(cap), quantity = numeric(cap),
              price = numeric(cap), requested = numeric(cap), before = numeric(cap))
  rj <- list(pulse = integer(), k = integer(), primary = character(), target = numeric(), strategy_target = numeric(),
             position = numeric(), resolved_price = numeric())
  recon <- matrix(NA_real_, T, 6L); pre <- integer(T); notice <- logical(T); notice_written <- FALSE
  nf <- 0L; nd <- 0L; nsz <- 0L
  status <- "DONE"; stop_reason <- NA_character_
  ctx <- list(universe = ids, buyable = named(rep(TRUE, n)), member = named(rep(TRUE, n)), seed = w$seed)
  for (i in seq_len(T)) {
    # P1: valuation at the close and the equity row
    close <- w$close[, i]
    pv <- if (any(pos != 0)) sum(pos[pos != 0] * close[pos != 0]) else 0
    eq$ts[[i]] <- w$ts[[i]]; eq$cash[[i]] <- cash; eq$positions_value[[i]] <- pv
    if (g[["fifo"]]) { eq$realized_pnl[[i]] <- book$realized_pnl; eq$cost_basis[[i]] <- book$total_cost_basis }
    # P2: the context, the strategy call and the checks on its output
    ctx$ts_utc <- w$iso[[i]]; ctx$cash <- cash; ctx$equity <- cash + pv
    ctx$close <- named(close); ctx$position <- named(pos); ctx$holding_value <- named(pos * close)
    ctx$open <- named(w$open[, i]); ctx$high <- named(w$high[, i]); ctx$low <- named(w$low[, i])
    ctx$volume <- named(w$volume[, i]); ctx$state <- state; ctx$pulse_seed <- pulse_seed[[i]]
    if (!is.null(w$fast)) { ctx$fast <- named(w$fast[, i]); ctx$slow <- named(w$slow[, i]) }
    held <- named(pos); ctx$hold <- function() held
    result <- w$strategy(ctx, NULL)
    if (is.numeric(result)) result <- list(targets = result, state_update = NULL)
    raw <- result$targets
    if (!is.numeric(raw) || length(raw) != n || is.null(names(raw))) s2b_refuse("ledgr_invalid_strategy_result", "Strategy targets must be a full named numeric vector.")
    if (!identical(names(raw), ids)) {
      at <- match(ids, names(raw))
      if (anyNA(at) || anyDuplicated(names(raw))) s2b_refuse("ledgr_invalid_strategy_result", "Strategy targets must name every instrument once.")
      raw <- raw[at]
    }
    sq <- as.numeric(raw)
    if (!all(is.finite(sq))) s2b_refuse("ledgr_invalid_strategy_result", "Strategy targets must be finite.")
    if (g[["sizing"]]) {
      e <- attr(result$targets, "sizing_evidence", exact = TRUE)
      if (!is.null(e)) {
        if (!inherits(e, "ledgr_sizing_evidence") || !identical(names(e), c("instrument_id", "requested_quantity",
            "pre_floor_quantity", "rounded_quantity", "price", "position_before", "reason_code")) ||
            any(lengths(e) != length(e$instrument_id)) || !is.character(e$instrument_id) || anyDuplicated(e$instrument_id))
          s2b_refuse("ledgr_invalid_strategy_result", "Strategy sizing evidence has an invalid shape.")
        k <- match(e$instrument_id, ids)
        if (anyNA(k) || !all(e$reason_code %in% ledgr:::.ledgr_sizing_reason_codes) ||
            any(!is.finite(e$rounded_quantity)) || any(!is.finite(e$position_before)))
          s2b_refuse("ledgr_invalid_strategy_result", "Strategy sizing evidence contains an invalid value.")
        priced <- is.finite(e$price) & e$price > 0
        free <- rep(TRUE, n); free[k] <- FALSE
        # evidence that no longer matches the targets, positions or marks is stale
        if (!identical(as.numeric(e$rounded_quantity), sq[k]) || !identical(as.numeric(e$position_before), pos[k]) ||
            !identical(as.numeric(e$price[priced]), close[k[priced]]) || !identical(sq[free], pos[free])) e <- NULL
      }
      m <- length(e$instrument_id)
      if (m > 0L) {
        r <- nsz + seq_len(m)
        szr$pulse[r] <- i; szr$id[r] <- e$instrument_id; szr$reason[r] <- e$reason_code; szr$target[r] <- e$pre_floor_quantity
        szr$quantity[r] <- e$rounded_quantity; szr$price[r] <- e$price; szr$requested[r] <- e$requested_quantity
        szr$before[r] <- e$position_before; nsz <- nsz + m; pre[[i]] <- m
      } else if (is.null(e) && !notice_written) { notice[[i]] <- TRUE; pre[[i]] <- 1L; notice_written <- TRUE }
    }
    tq <- sq
    if (g[["risk"]]) {
      if (!is.null(w$max_weight)) {
        nz <- abs(tq) > tol
        if (any(nz & !(is.finite(close) & close > 0))) s2b_refuse("ledgr_invalid_risk_context", "max_weight needs a positive close.")
        tq[nz] <- if (ctx$equity == 0) 0 else sign(tq[nz]) * pmin(abs(tq[nz]), (w$max_weight * ctx$equity) / close[nz])
        if (any(!(tq == 0 | (sign(tq) == sign(sq) & abs(tq) <= abs(sq)))))
          s2b_refuse("ledgr_post_risk_inadmissible", "Post-risk targets may only preserve or reduce strategy exposure.")
      }
      if (any(tq < pmin(pos, 0))) s2b_refuse("ledgr_short_exposure_unsupported", "Cannot open or enlarge short exposure.")
    }
    # P3: the order plan at the next open, or the affordability stop
    act <- which(abs(tq - pos) > tol)
    fills <- integer(); expected <- cash; cd <- numeric()
    if (length(act)) {
      before <- pos[act]; delta <- tq[act] - before; side <- ifelse(delta > 0, 1L, -1L); qty <- abs(delta)
      if (i == T) {
        m <- length(act)
        rj$pulse <- c(rj$pulse, rep(i, m)); rj$k <- c(rj$k, act); rj$primary <- c(rj$primary, rep("final_pulse_no_execution", m))
        rj$target <- c(rj$target, tq[act]); rj$strategy_target <- c(rj$strategy_target, sq[act])
        rj$position <- c(rj$position, before); rj$resolved_price <- c(rj$resolved_price, rep(NA_real_, m))
      } else {
        open <- w$open[act, i + 1L]
        if (any(!is.finite(open) | open <= 0)) s2b_refuse("ledgr_invalid_fold_execution", "Missing execution bars are outside this reference.")
        rs <- if (g[["cost"]]) s2b_cost(w$steps, side, qty, open) else list(price = open, fee = numeric(length(open)))
        cd <- ifelse(side > 0L, -(qty * rs$price + rs$fee), qty * rs$price - rs$fee)
        # a resolved price that is not positive rejects the fill (execution_bar_missing)
        early <- which(!(is.finite(rs$price) & rs$price > 0))
        accepted <- rep(TRUE, length(act)); accepted[early] <- FALSE; expected <- cash + sum(cd[accepted])
        insufficient <- logical(length(act))
        if (g[["cost"]]) {
          gen <- side == -1L & before > 0 & delta < 0 & cd >= 0
          virtual <- cash; cand <- which(accepted)
          for (j in cand[order(!gen[cand], rank[act[cand]], method = "radix")]) {
            ok <- cd[[j]] >= 0 || virtual + cd[[j]] >= -cash_tol
            if (ok) virtual <- virtual + cd[[j]] else { accepted[[j]] <- FALSE; insufficient[[j]] <- TRUE }
          }
          expected <- virtual
        }
        b <- c(early, which(insufficient)); m <- length(b)
        if (m > 0L) {
          rj$pulse <- c(rj$pulse, rep(i, m)); rj$k <- c(rj$k, act[b])
          rj$primary <- c(rj$primary, rep(c("execution_bar_missing", "insufficient_cash"), c(length(early), m - length(early))))
          rj$target <- c(rj$target, tq[act[b]]); rj$strategy_target <- c(rj$strategy_target, sq[act[b]])
          rj$position <- c(rj$position, before[b]); rj$resolved_price <- c(rj$resolved_price, ifelse(b %in% early, NA_real_, rs$price[b]))
        }
        if (g[["cost"]]) {
          recorded <- cash + sum(cd[accepted])
          if (identical(gut, "reconciliation") || (!isTRUE(recorded == expected) &&
              !isTRUE(all.equal(recorded, expected, tolerance = cash_tol)))) {
            r <- nd + seq_len(n)
            dr$pulse[r] <- i; dr$k[r] <- seq_len(n); dr$target[r] <- sq; dr$target_after[r] <- tq; dr$position[r] <- pos
            nd <- nd + n; status <- "INCOMPLETE"; stop_reason <- "affordability_reconciliation_failed"
            break
          }
        }
        fills <- which(accepted)
      }
    }
    # P4: fills applied to the book and the fill records; explicit decisions
    differs <- which(!(is.finite(sq) & sq == pos & tq == sq & is.finite(close)))
    clean_k <- integer()
    m <- length(fills)
    if (m > 0L) {
      k <- act[fills]; s <- side[fills]; q <- qty[fills]; pr <- rs$price[fills]; fe <- rs$fee[fills]; c_d <- cd[fills]
      p_d <- ifelse(s > 0L, q, -q); after <- before[fills] + p_d
      clean <- is.finite(sq[k]) & is.finite(close[k]) & sq[k] == after & tq[k] == sq[k]
      clean_k <- k[clean]
      r <- nf + seq_len(m)
      if (g[["fifo"]]) {
        a <- lean_lot_fill(book, k, s, q, pr, fe); book <- a$book
        fl$close_qty[r] <- a$applied$close_qty; fl$open_qty[r] <- a$applied$open_qty; fl$realized_close[r] <- a$applied$realized_close
        pos[k] <- book$net_by_inst[k]
        entry_bar[k[before[fills] == 0]] <- i + 1L; exit_bar[k[pos[k] == 0]] <- i + 1L
      } else pos[k] <- after
      fl$pulse[r] <- i; fl$k[r] <- k; fl$side[r] <- s; fl$qty[r] <- q; fl$price[r] <- pr; fl$fee[r] <- fe
      fl$cash_delta[r] <- c_d; fl$position_delta[r] <- p_d; fl$exec_ts[r] <- w$ts[[i + 1L]]
      fl$position_before[r] <- before[fills]; fl$planned_position_after[r] <- after; fl$clean[r] <- clean
      fl$target[r] <- tq[k]; fl$strategy_target[r] <- sq[k]; fl$net_after[r] <- pos[k]
      nf <- nf + m
      for (x in c_d) cash <- cash + x   # booked fill by fill
    }
    ex <- if (length(clean_k)) differs[match(differs, clean_k, 0L) == 0L] else differs
    if (length(ex)) {
      r <- nd + seq_along(ex)
      dr$pulse[r] <- i; dr$k[r] <- ex; dr$target[r] <- sq[ex]; dr$target_after[r] <- tq[ex]
      dr$position[r] <- unname(held[ex]); nd <- nd + length(ex)
    }
    # P5: the cash check, the reconciliation record and the state update
    if (m > 0L && !isTRUE(cash == expected) && !isTRUE(all.equal(cash, expected, tolerance = cash_tol)))
      s2b_refuse("ledgr_affordability_reconciliation_failed", "Recorded cash does not reconcile.")
    recon[i, ] <- c(s2b_gross(pos, close), cash - sum(cd[fills]), s2b_gross(sq, close),
                    s2b_gross(if (g[["risk"]] && !is.null(w$max_weight)) tq else sq, close), cash, expected)
    if (any(!is.finite(recon[i, ]))) s2b_refuse("ledgr_config_non_finite", "Reconciliation values must be finite.")
    up <- result$state_update
    if (!is.null(up)) {
      up <- unclass(up)
      for (nm in names(up)) {
        v <- up[[nm]]
        if (g[["state"]]) {
          f <- w$fields[[nm]]
          if (is.null(f)) s2b_refuse("ledgr_invalid_strategy_state", sprintf("Undeclared state field `%s`.", nm))
          if (is.object(v)) s2b_refuse("ledgr_invalid_strategy_state", "State values must be unclassed.")
          if (f$scope == "asset") {
            if (length(v) == 1L && is.null(names(v))) v <- named(rep(v, n))
            else if (!identical(names(v), ids)) s2b_refuse("ledgr_invalid_strategy_state", "Asset state must be a named full-axis vector.")
          } else if (length(v) != 1L || !is.null(names(v))) s2b_refuse("ledgr_invalid_strategy_state", "Portfolio state must stay scalar.")
          if (!switch(f$type, logical = is.logical(v), integer = is.integer(v), numeric = is.double(v), FALSE))
            s2b_refuse("ledgr_invalid_strategy_state", sprintf("State field `%s` has the wrong type.", nm))
          if (is.double(v) && any(is.nan(v) | is.infinite(v))) s2b_refuse("ledgr_invalid_strategy_state", "State must be finite.")
          if (anyNA(v)) v[is.na(v)] <- w$state0[[nm]][is.na(v)]
        }
        state[[nm]] <- v
      }
    }
  }
  keep <- function(x, k) lapply(x, function(v) v[seq_len(k)])
  list(fills = keep(fl, nf), equity = eq, decisions = keep(dr, nd), sizing = keep(szr, nsz), rejections = rj,
       recon = recon, pre = pre, sizing_notice = notice, strategy_state = state, cash = cash, pos = pos, book = book,
       status = status, stop_reason = stop_reason)
}
