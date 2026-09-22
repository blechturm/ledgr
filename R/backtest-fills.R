ledgr_empty_fills_table <- function() {
  tibble::tibble(
    event_seq = integer(),
    ts_utc = as.POSIXct(character(), tz = "UTC"),
    recording_pulse_ts_utc = as.POSIXct(character(), tz = "UTC"),
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
#' @return A tibble of fill rows. `ts_utc` is the economic execution time.
#'   `recording_pulse_ts_utc` is the close of the uniquely associated execution
#'   session and is `NA` when that association is unavailable or ambiguous.
#' @details Fill rows describe execution events and may include both opening and
#'   closing actions. Closed trades are exposed by `ledgr_results(bt, what =
#'   "trades")`. To align fills with close-stamped equity, first aggregate fills
#'   by `recording_pulse_ts_utc`, then match or join that one-row-per-pulse table
#'   to equity `ts_utc`. A raw equality join on fill `ts_utc` is not session
#'   alignment, and joining unaggregated fills can duplicate equity rows.
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
#' fills <- ledgr_run_fills(bt)
#' equity <- ledgr_results(bt, "equity")
#' fills_by_pulse <- stats::aggregate(
#'   qty ~ recording_pulse_ts_utc,
#'   data = as.data.frame(fills),
#'   FUN = sum
#' )
#' equity$fill_qty <- fills_by_pulse$qty[match(
#'   equity$ts_utc,
#'   fills_by_pulse$recording_pulse_ts_utc
#' )]
#' nrow(equity)
#' close(bt)
#' @export
ledgr_run_fills <- function(bt) {
  ledgr_extract_fills_impl(bt)
}

ledgr_extract_fills_impl <- function(bt, con = NULL) {
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  old_seed <- if (had_seed) {
    get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  } else {
    NULL
  }
  on.exit({
    if (had_seed) {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)
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
    WHERE run_id = ? AND event_type = 'FILL'
    ",
    params = list(bt$run_id)
  )$n[[1]]
  total_rows <- as.integer(total_rows)
  if (is.na(total_rows) || total_rows < 1L) {
    return(ledgr_empty_fills_table())
  }

  # Temp-table accumulation handles dynamic sizing; no R-side caps needed.
  temp_table <- basename(tempfile(pattern = "temp_fills_"))
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
    SELECT event_id, run_id, ts_utc, event_type, instrument_id, side, qty, price, fee, meta_json, event_seq
    FROM ledger_events
    WHERE run_id = ?
      AND event_type IN ('CASHFLOW', 'FILL')
    ORDER BY event_seq
    ",
    params = list(bt$run_id)
  )
  on.exit(DBI::dbClearResult(ledger_res), add = TRUE)

  lot_state <- ledgr_lot_state()
  replay_positions <- numeric()
  replay_cash <- 0
  fetch_size <- 50000L

  repeat {
    rows <- DBI::dbFetch(ledger_res, n = fetch_size)
    if (nrow(rows) == 0) break

    prepared <- ledgr_prepare_accounting_events(rows, lot_state$instrument_ids)
    replay <- ledgr_replay_accounting_events(
      prepared,
      initial_cash = replay_cash,
      initial_positions = replay_positions,
      lot_state = lot_state
    )
    lot_state <- replay$lot_state
    replay_cash <- replay$cash
    replay_positions <- replay$positions
    block_fills <- ledgr_accounting_fills_from_replay(
      replay,
      as.POSIXct(character(), tz = "UTC")
    )
    if (nrow(block_fills) > 0L) {
      DBI::dbAppendTable(
        con,
        temp_table,
        as.data.frame(block_fills[, setdiff(names(block_fills), "recording_pulse_ts_utc")])
      )
    }
  }

  out <- tibble::as_tibble(DBI::dbGetQuery(con, sprintf("SELECT * FROM %s ORDER BY event_seq", temp_table)))
  ledgr_fills_add_recording_pulse(
    out,
    ledgr_run_fill_recording_pulses(bt, out, con)
  )
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
