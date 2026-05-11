ledgr_lot_state <- function(instrument_ids = character()) {
  instrument_ids <- as.character(instrument_ids)
  instrument_ids <- instrument_ids[!is.na(instrument_ids) & nzchar(instrument_ids)]
  list(
    lots = stats::setNames(vector("list", length(instrument_ids)), instrument_ids),
    cost_basis_by_inst = stats::setNames(rep(0, length(instrument_ids)), instrument_ids),
    total_cost_basis = 0,
    realized_pnl = 0,
    realized_comp = 0
  )
}

ledgr_lot_direction <- function(side) {
  side <- toupper(as.character(side))
  if (length(side) != 1L || is.na(side)) return(NA_integer_)
  if (side %in% c("BUY", "COVER", "BUY_TO_COVER")) return(1L)
  if (side %in% c("SELL", "SHORT", "SELL_SHORT")) return(-1L)
  NA_integer_
}

ledgr_lot_basis <- function(lots) {
  if (length(lots) < 1L) return(0)
  sum(vapply(lots, function(lot) {
    as.numeric(lot$qty) * as.numeric(lot$price)
  }, numeric(1)))
}

ledgr_lot_get <- function(state, instrument_id) {
  lots <- state$lots[[instrument_id]]
  if (is.null(lots)) list() else lots
}

ledgr_lot_set <- function(state, instrument_id, lots) {
  if (is.null(state$lots[[instrument_id]])) {
    state$lots[[instrument_id]] <- list()
  }
  if (is.null(names(state$cost_basis_by_inst)) || !(instrument_id %in% names(state$cost_basis_by_inst))) {
    state$cost_basis_by_inst[[instrument_id]] <- 0
  }

  old_basis <- as.numeric(state$cost_basis_by_inst[[instrument_id]])
  new_basis <- ledgr_lot_basis(lots)
  state$lots[[instrument_id]] <- lots
  state$cost_basis_by_inst[[instrument_id]] <- new_basis
  state$total_cost_basis <- as.numeric(state$total_cost_basis) - old_basis + new_basis
  state
}

ledgr_lot_add_realized <- function(state, delta) {
  y <- as.numeric(delta) - as.numeric(state$realized_comp)
  t <- as.numeric(state$realized_pnl) + y
  state$realized_comp <- (t - as.numeric(state$realized_pnl)) - y
  state$realized_pnl <- t
  state
}

ledgr_lot_apply_opening <- function(state, instrument_id, qty, cost_basis) {
  if (!is.character(instrument_id) || length(instrument_id) != 1L ||
    is.na(instrument_id) || !nzchar(instrument_id)) {
    return(state)
  }
  qty <- suppressWarnings(as.numeric(qty))
  cost_basis <- suppressWarnings(as.numeric(cost_basis))
  if (length(qty) != 1L || is.na(qty) || !is.finite(qty) || qty == 0 ||
    length(cost_basis) != 1L || is.na(cost_basis) || !is.finite(cost_basis)) {
    return(state)
  }

  lots <- ledgr_lot_get(state, instrument_id)
  lots[[length(lots) + 1L]] <- list(qty = qty, price = cost_basis)
  ledgr_lot_set(state, instrument_id, lots)
}

ledgr_lot_apply_fill <- function(state, instrument_id, side, qty, price, fee = 0) {
  direction <- ledgr_lot_direction(side)
  qty <- suppressWarnings(as.numeric(qty))
  price <- suppressWarnings(as.numeric(price))
  fee <- suppressWarnings(as.numeric(fee))
  if (is.na(direction) ||
    !is.character(instrument_id) || length(instrument_id) != 1L ||
    is.na(instrument_id) || !nzchar(instrument_id) ||
    length(qty) != 1L || is.na(qty) || !is.finite(qty) || qty <= 0 ||
    length(price) != 1L || is.na(price) || !is.finite(price) ||
    length(fee) != 1L || is.na(fee) || !is.finite(fee)) {
    return(list(
      state = state,
      close_qty = NA_real_,
      open_qty = NA_real_,
      realized_close = NA_real_,
      realized_delta = NA_real_,
      direction = direction
    ))
  }

  lots <- ledgr_lot_get(state, instrument_id)
  net_pos <- if (length(lots) > 0L) {
    sum(vapply(lots, function(lot) as.numeric(lot$qty), numeric(1)))
  } else {
    0
  }
  close_qty <- 0
  if (direction > 0L && net_pos < 0) {
    close_qty <- min(qty, abs(net_pos))
  } else if (direction < 0L && net_pos > 0) {
    close_qty <- min(qty, net_pos)
  }
  open_qty <- qty - close_qty

  remaining_close <- close_qty
  realized_close <- 0
  if (remaining_close > 0) {
    if (direction > 0L) {
      while (remaining_close > 0 && length(lots) > 0 && as.numeric(lots[[1]]$qty) < 0) {
        lot_qty <- abs(as.numeric(lots[[1]]$qty))
        lot_price <- as.numeric(lots[[1]]$price)
        take <- min(lot_qty, remaining_close)
        realized_close <- realized_close + (lot_price - price) * take
        lot_qty <- lot_qty - take
        remaining_close <- remaining_close - take
        if (lot_qty <= 0) {
          lots <- lots[-1]
        } else {
          lots[[1]]$qty <- -lot_qty
        }
      }
    } else {
      while (remaining_close > 0 && length(lots) > 0 && as.numeric(lots[[1]]$qty) > 0) {
        lot_qty <- as.numeric(lots[[1]]$qty)
        lot_price <- as.numeric(lots[[1]]$price)
        take <- min(lot_qty, remaining_close)
        realized_close <- realized_close + (price - lot_price) * take
        lot_qty <- lot_qty - take
        remaining_close <- remaining_close - take
        if (lot_qty <= 0) {
          lots <- lots[-1]
        } else {
          lots[[1]]$qty <- lot_qty
        }
      }
    }
  }

  if (open_qty > 0) {
    lots[[length(lots) + 1L]] <- list(
      qty = if (direction > 0L) open_qty else -open_qty,
      price = price
    )
  }

  state <- ledgr_lot_set(state, instrument_id, lots)
  realized_delta <- realized_close - fee
  state <- ledgr_lot_add_realized(state, realized_delta)

  list(
    state = state,
    close_qty = close_qty,
    open_qty = open_qty,
    realized_close = realized_close,
    realized_delta = realized_delta,
    direction = direction
  )
}

ledgr_lot_meta_is_opening <- function(meta) {
  is.list(meta) &&
    identical(meta$source, "opening_position") &&
    !is.null(meta$position_delta) &&
    !is.null(meta$cost_basis)
}

ledgr_lot_parse_meta <- function(meta_json) {
  if (is.null(meta_json) ||
    (is.atomic(meta_json) && length(meta_json) == 1L && is.na(meta_json)) ||
    (is.character(meta_json) && length(meta_json) == 1L && !nzchar(meta_json))) {
    return(NULL)
  }
  tryCatch(jsonlite::fromJSON(meta_json, simplifyVector = FALSE), error = function(e) NULL)
}

ledgr_lot_apply_event <- function(state,
                                  event_type,
                                  instrument_id,
                                  side = NA_character_,
                                  qty = NA_real_,
                                  price = NA_real_,
                                  fee = 0,
                                  meta = NULL) {
  event_type <- as.character(event_type)
  if (length(event_type) != 1L || is.na(event_type)) {
    return(list(state = state, kind = "ignored"))
  }

  if (identical(event_type, "CASHFLOW") && ledgr_lot_meta_is_opening(meta)) {
    state <- ledgr_lot_apply_opening(
      state,
      instrument_id = instrument_id,
      qty = meta$position_delta,
      cost_basis = meta$cost_basis
    )
    return(list(state = state, kind = "opening"))
  }

  if (event_type %in% c("FILL", "FILL_PARTIAL")) {
    out <- ledgr_lot_apply_fill(
      state,
      instrument_id = instrument_id,
      side = side,
      qty = qty,
      price = price,
      fee = fee
    )
    out$kind <- "fill"
    return(out)
  }

  list(state = state, kind = "ignored")
}
