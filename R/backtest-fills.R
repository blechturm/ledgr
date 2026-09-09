ledgr_empty_fills_table <- function() {
  tibble::tibble(
    event_seq = integer(),
    ts_utc = as.POSIXct(character(), tz = "UTC"),
    instrument_id = character(),
    side = character(),
    qty = numeric(),
    price = numeric(),
    fee = numeric(),
    realized_pnl = numeric(),
    action = character()
  )
}
#' Extract fill events from a backtest
#'
#' @param bt A `ledgr_backtest` object.
#' @return A tibble of fill rows.
#' @details Fill rows describe execution events and may include both opening and
#'   closing actions. Closed trades are exposed by `ledgr_results(bt, what =
#'   "trades")`.
#' @examples
#' bars <- data.frame(
#'   ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:3,
#'   instrument_id = "AAA",
#'   open = c(100, 101, 102, 103),
#'   high = c(101, 102, 103, 104),
#'   low = c(99, 100, 101, 102),
#'   close = c(100, 101, 102, 103),
#'   volume = 1000
#' )
#' strategy <- function(ctx, params) {
#'   targets <- ctx$flat()
#'   targets["AAA"] <- 1
#'   targets
#' }
#' bt <- ledgr_backtest(data = bars, strategy = strategy, initial_cash = 1000, cost_model = ledgr_cost_zero())
#' ledgr_run_fills(bt)
#' close(bt)
#' @export
ledgr_run_fills <- function(bt) {
  ledgr_extract_fills_impl(bt)
}

ledgr_extract_fills_impl <- function(bt, con = NULL) {
  if (is.null(con)) {
    opened <- ledgr_backtest_read_connection(bt)
    con <- opened$con
    on.exit(opened$close(), add = TRUE)
  }
  total_rows <- DBI::dbGetQuery(
    con,
    "
    SELECT COUNT(*) AS n
    FROM ledger_events
    WHERE run_id = ? AND event_type IN ('FILL', 'FILL_PARTIAL')
    ",
    params = list(bt$run_id)
  )$n[[1]]
  total_rows <- as.integer(total_rows)
  if (is.na(total_rows) || total_rows < 1L) {
    return(ledgr_empty_fills_table())
  }

  # Temp-table accumulation handles dynamic sizing; no R-side caps needed.
  temp_table <- paste0("temp_fills_", paste(sample(c(letters, LETTERS, 0:9), 12, replace = TRUE), collapse = ""))
  DBI::dbExecute(con, sprintf("DROP TABLE IF EXISTS %s", temp_table))
  DBI::dbExecute(
    con,
    sprintf(
      "
    CREATE TEMP TABLE %s (
      event_seq INTEGER,
      ts_utc TIMESTAMP,
      instrument_id TEXT,
      side TEXT,
      qty DOUBLE,
      price DOUBLE,
      fee DOUBLE,
      realized_pnl DOUBLE,
      action TEXT
    )
    ",
      temp_table
    )
  )

  if (!(exists("opened", inherits = FALSE) && isTRUE(opened$temporary))) {
    on.exit(DBI::dbExecute(con, sprintf("DROP TABLE IF EXISTS %s", temp_table)), add = TRUE)
  }

  ledger_res <- DBI::dbSendQuery(
    con,
    "
    SELECT event_seq, ts_utc, event_type, instrument_id, side, qty, price, fee, meta_json
    FROM ledger_events
    WHERE run_id = ?
      AND event_type IN ('CASHFLOW', 'FILL', 'FILL_PARTIAL')
    ORDER BY event_seq
    ",
    params = list(bt$run_id)
  )
  on.exit(DBI::dbClearResult(ledger_res), add = TRUE)

  lot_state <- ledgr_lot_state()
  fetch_size <- 50000L

  repeat {
    rows <- DBI::dbFetch(ledger_res, n = fetch_size)
    if (nrow(rows) == 0) break

    fill_rows <- ledgr_fill_row_buffer(nrow(rows) * 2L)

    for (i in seq_len(nrow(rows))) {
      event_type <- as.character(rows$event_type[[i]])
      inst <- as.character(rows$instrument_id[[i]])
      side <- as.character(rows$side[[i]])
      qty <- suppressWarnings(as.numeric(rows$qty[[i]]))
      price <- suppressWarnings(as.numeric(rows$price[[i]]))
      fee <- suppressWarnings(as.numeric(rows$fee[[i]]))
      meta_raw <- rows$meta_json[[i]]
      meta_parse_error <- FALSE
      meta <- NULL
      if (!is.null(meta_raw) &&
        !(is.atomic(meta_raw) && length(meta_raw) == 1 && is.na(meta_raw)) &&
        !(is.character(meta_raw) && length(meta_raw) == 1 && !nzchar(meta_raw))) {
        meta <- tryCatch(
          ledgr_json_read_nested(meta_raw),
          error = function(e) {
            meta_parse_error <<- TRUE
            NULL
          }
        )
      }

      if (identical(event_type, "CASHFLOW")) {
        lot_res <- ledgr_lot_apply_event(
          lot_state,
          event_type = event_type,
          instrument_id = inst,
          meta = meta
        )
        lot_state <- lot_res$state
        next
      }

      if (is.na(qty) || qty <= 0 || is.na(price)) {
        ledgr_fill_row_buffer_add(
          fill_rows,
          rows$event_seq[[i]], rows$ts_utc[[i]], inst, side, qty, price, fee,
          NA_real_, NA_character_
        )
        next
      }

      side_norm <- toupper(side)
      if (!(side_norm %in% c("BUY", "COVER", "BUY_TO_COVER", "SELL", "SHORT", "SELL_SHORT"))) {
        ledgr_fill_row_buffer_add(
          fill_rows,
          rows$event_seq[[i]], rows$ts_utc[[i]], inst, side, qty, price, fee,
          NA_real_, NA_character_
        )
        next
      }

      lots <- ledgr_lot_get(lot_state, inst)
      net_pos <- if (length(lots) > 0L) {
        sum(vapply(lots, function(lot) as.numeric(lot$qty), numeric(1)))
      } else {
        0
      }
      if (side_norm == "BUY_TO_COVER" && net_pos >= 0) {
        warning(
          sprintf("[%s:%d] Semantic Violation: BUY_TO_COVER rejected (currently Long)", inst, rows$event_seq[[i]]),
          call. = FALSE
        )
        ledgr_fill_row_buffer_add(
          fill_rows,
          rows$event_seq[[i]], rows$ts_utc[[i]], inst, side, qty, price, fee,
          NA_real_, "REJECTED"
        )
        next
      }
      if (side_norm == "SELL_SHORT" && net_pos <= 0) {
        warning(
          sprintf("[%s:%d] Semantic Violation: SELL_SHORT rejected (currently Short)", inst, rows$event_seq[[i]]),
          call. = FALSE
        )
        ledgr_fill_row_buffer_add(
          fill_rows,
          rows$event_seq[[i]], rows$ts_utc[[i]], inst, side, qty, price, fee,
          NA_real_, "REJECTED"
        )
        next
      }

      lot_res <- ledgr_lot_apply_event(
        lot_state,
        event_type = event_type,
        instrument_id = inst,
        side = side,
        qty = qty,
        price = price,
        fee = fee,
        meta = meta
      )
      lot_state <- lot_res$state
      close_qty <- lot_res$close_qty
      open_qty <- lot_res$open_qty
      realized_close <- lot_res$realized_close
      leg_fees <- ledgr_fill_leg_fees(fee, close_qty, open_qty)

      if (!is.null(meta_raw) &&
        !(is.atomic(meta_raw) && length(meta_raw) == 1 && is.na(meta_raw)) &&
        !(is.character(meta_raw) && length(meta_raw) == 1 && !nzchar(meta_raw))) {
        if (isTRUE(meta_parse_error)) {
          warning("Malformed meta_json for fill; realized_pnl set to NA.", call. = FALSE)
        } else if (!is.null(meta$realized_pnl)) {
          meta_val <- suppressWarnings(as.numeric(meta$realized_pnl))
          if (is.na(meta_val)) {
            warning("Malformed meta_json for fill; realized_pnl set to NA.", call. = FALSE)
          } else {
            tol <- max(1e-6, 1e-7 * abs(meta_val))
            if (abs(meta_val - realized_close) > tol) {
              warning(
                sprintf(
                  "[%s:%d] FIFO Mismatch: Expected %.8f, Found %.8f",
                  inst,
                  rows$event_seq[[i]],
                  realized_close,
                  meta_val
                ),
                call. = FALSE
              )
            }
          }
        }
      }

      if (close_qty > 0) {
        ledgr_fill_row_buffer_add(
          fill_rows,
          rows$event_seq[[i]], rows$ts_utc[[i]], inst, side, close_qty, price, leg_fees[["close"]],
          realized_close, "CLOSE"
        )
      }
      if (open_qty > 0) {
        ledgr_fill_row_buffer_add(
          fill_rows,
          rows$event_seq[[i]], rows$ts_utc[[i]], inst, side, open_qty, price, leg_fees[["open"]],
          0, "OPEN"
        )
      }
    }

    if (fill_rows$n > 0L) {
      DBI::dbAppendTable(con, temp_table, ledgr_fill_row_buffer_data_frame(fill_rows))
    }
  }

  tibble::as_tibble(DBI::dbGetQuery(con, sprintf("SELECT * FROM %s ORDER BY event_seq", temp_table)))
}

ledgr_closed_trade_rows <- function(fills) {
  if (nrow(fills) == 0L) {
    return(fills)
  }
  tibble::as_tibble(fills[ledgr_col_equals(fills$action, "CLOSE"), , drop = FALSE])
}

ledgr_extract_trades <- function(bt, con = NULL) {
  ledgr_closed_trade_rows(ledgr_extract_fills_impl(bt, con = con))
}

ledgr_col_equals <- function(x, value) {
  !is.na(x) & as.character(x) == value
}
