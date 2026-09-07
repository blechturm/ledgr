stage3_bar_matrix <- function(fixture, field) {
  ids <- fixture$instrument_ids
  pulses <- fixture$pulses
  out <- matrix(
    NA_real_,
    nrow = length(ids),
    ncol = length(pulses),
    dimnames = list(ids, stage3_iso(pulses))
  )
  for (id in ids) {
    rows <- fixture$bars$instrument_id == id
    index <- match(stage3_iso(fixture$bars$ts_utc[rows]), colnames(out))
    out[id, index] <- fixture$bars[[field]][rows]
  }
  out
}

stage3_lot_state <- function(ids, positions, basis) {
  lots <- stats::setNames(vector("list", length(ids)), ids)
  for (id in ids) {
    qty <- positions[[id]] %||% 0
    if (!is.na(qty) && qty != 0) {
      lots[[id]] <- data.frame(qty = qty, basis = basis[[id]], stringsAsFactors = FALSE)
    } else {
      lots[[id]] <- data.frame(qty = numeric(), basis = numeric())
    }
  }
  lots
}

stage3_apply_fifo <- function(lots, id, delta, price, fee) {
  current <- lots[[id]]
  realized <- -fee
  if (delta > 0) {
    current <- rbind(current, data.frame(qty = delta, basis = price))
  } else if (delta < 0) {
    remaining <- -delta
    while (remaining > 0 && nrow(current) > 0L) {
      take <- min(remaining, current$qty[[1L]])
      realized <- realized + (price - current$basis[[1L]]) * take
      current$qty[[1L]] <- current$qty[[1L]] - take
      remaining <- remaining - take
      if (current$qty[[1L]] == 0) current <- current[-1L, , drop = FALSE]
    }
    if (remaining > 0) {
      stop("Stage 3 W21 fork does not permit an uncovered short.", call. = FALSE)
    }
  }
  lots[[id]] <- current
  list(lots = lots, realized = realized)
}

stage3_apply_max_weight <- function(targets, equity, prices, max_weight) {
  out <- as.numeric(targets)
  names(out) <- names(targets)
  nonzero <- abs(out) > sqrt(.Machine$double.eps)
  if (!any(nonzero) || equity == 0) {
    out[nonzero] <- 0
    return(out)
  }
  cap <- max_weight * equity / prices[nonzero]
  out[nonzero] <- sign(out[nonzero]) * pmin(abs(out[nonzero]), cap)
  out
}

stage3_run_w21_fork <- function(fixture, source_identity) {
  ids <- fixture$instrument_ids
  close <- stage3_bar_matrix(fixture, "close")
  open <- stage3_bar_matrix(fixture, "open")
  positions <- fixture$opening$positions[ids]
  positions[is.na(positions)] <- 0
  cash <- fixture$opening$cash
  lots <- stage3_lot_state(ids, positions, fixture$opening$lot_basis)
  realized <- 0
  fills <- list()
  equity <- numeric(length(fixture$pulses))
  targets_pre <- targets_post <- vector("list", length(fixture$pulses))
  final_no_fill <- NULL

  for (pulse_index in seq_along(fixture$pulses)) {
    equity[[pulse_index]] <- cash + sum(positions * close[, pulse_index])
    pre <- fixture$targets[pulse_index, ids]
    post <- stage3_apply_max_weight(
      pre,
      equity[[pulse_index]],
      close[, pulse_index],
      fixture$max_weight
    )
    targets_pre[[pulse_index]] <- pre
    targets_post[[pulse_index]] <- post

    if (pulse_index == length(fixture$pulses)) {
      changed <- names(post)[post != positions]
      if (length(changed) > 0L) {
        final_no_fill <- list(
          asset_id = changed[[1L]],
          status = "no_fill",
          reason_code = "LEDGR_LAST_BAR_NO_FILL"
        )
      }
      next
    }

    for (id in ids) {
      delta <- post[[id]] - positions[[id]]
      if (delta == 0) next
      price <- open[id, pulse_index + 1L]
      fee <- fixture$fixed_fee
      cash_delta <- if (delta > 0) -(delta * price + fee) else (-delta * price - fee)
      accounting <- stage3_apply_fifo(lots, id, delta, price, fee)
      lots <- accounting$lots
      realized <- realized + accounting$realized
      cash <- cash + cash_delta
      positions[[id]] <- positions[[id]] + delta
      fills[[length(fills) + 1L]] <- data.frame(
        event_time = stage3_iso(fixture$execution_times[[pulse_index + 1L]]),
        asset_id = id,
        side = if (delta > 0) "BUY" else "SELL",
        qty = abs(delta),
        price = price,
        fee = fee,
        cash_delta = cash_delta,
        cash_after = cash,
        realized_delta = accounting$realized,
        realized_cumulative = realized,
        position_after = positions[[id]],
        lot_qty_after = sum(lots[[id]]$qty),
        lot_basis_after = if (nrow(lots[[id]]) == 0L) NA_real_ else lots[[id]]$basis[[1L]],
        stringsAsFactors = FALSE
      )
    }
  }

  fill_table <- if (length(fills) == 0L) data.frame() else do.call(rbind, fills)
  list(
    source = "fork",
    fixture = fixture,
    close = close,
    open = open,
    opening_cash = fixture$opening$cash,
    opening_positions = fixture$opening$positions,
    opening_basis = fixture$opening$lot_basis,
    targets_pre = targets_pre,
    targets_post = targets_post,
    fills = fill_table,
    equity = equity,
    cash = cash,
    positions = positions,
    lots = lots,
    realized = realized,
    final_no_fill = final_no_fill,
    source_identity = source_identity
  )
}

stage3_resolve_status <- function(facts, asset_id, time) {
  rows <- facts$asset_id == asset_id &
    facts$knowledge_time <= time &
    facts$effective_from <= time &
    (is.na(facts$effective_to) | facts$effective_to > time)
  active <- facts[rows, , drop = FALSE]
  if (nrow(active) == 0L) return("status_unknown")
  best <- active[active$precedence == min(active$precedence), , drop = FALSE]
  statuses <- unique(best$status)
  if (length(statuses) != 1L) return("status_unknown_or_conflicting")
  statuses[[1L]]
}

stage3_status_fill_reason <- function(status) {
  switch(
    status,
    active = "",
    halted = "trading_halted",
    quotation_only = "quotation_only",
    status_unknown = "status_unknown",
    status_unknown_or_conflicting = "status_unknown_or_conflicting",
    "status_unknown_or_conflicting"
  )
}

stage3_affordability <- function(opening_cash, proposals, tolerance = 1e-8) {
  required <- c("asset_id", "cash_delta", "status", "execution_price")
  stage3_assert(
    all(required %in% names(proposals)),
    "Affordability proposals must carry status and execution-price evidence."
  )
  stage3_assert(
    all(is.finite(proposals$execution_price) & proposals$execution_price > 0),
    "Affordability is evaluated only when an execution price exists."
  )
  order <- order(proposals$asset_id, method = "radix")
  virtual_cash <- opening_cash
  accepted <- rep(FALSE, nrow(proposals))
  trial <- rep(NA_real_, nrow(proposals))
  after <- rep(NA_real_, nrow(proposals))

  for (kind in c("credit", "debit")) {
    selected <- order[if (kind == "credit") proposals$cash_delta[order] >= 0 else proposals$cash_delta[order] < 0]
    for (i in selected) {
      if (!identical(proposals$status[[i]], "active")) {
        after[[i]] <- virtual_cash
        next
      }
      trial[[i]] <- virtual_cash + proposals$cash_delta[[i]]
      if (proposals$cash_delta[[i]] >= 0 || trial[[i]] >= -tolerance) {
        accepted[[i]] <- TRUE
        virtual_cash <- trial[[i]]
      }
      after[[i]] <- virtual_cash
    }
  }
  list(accepted = accepted, trial = trial, after = after, final_cash = virtual_cash)
}

stage3_carry_forward <- function(x) {
  out <- x
  for (i in seq_along(out)) {
    if (is.na(out[[i]]) && i > 1L) out[[i]] <- out[[i - 1L]]
  }
  out
}

stage3_rolling_mean_two <- function(x) {
  out <- rep(NA_real_, length(x))
  if (length(x) < 2L) return(out)
  for (i in 2:length(x)) {
    pair <- x[(i - 1L):i]
    if (!anyNA(pair)) out[[i]] <- mean(pair)
  }
  out
}
