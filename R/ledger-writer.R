ledgr_write_fill_events <- function(con, run_id, fill_intent, event_seq_start = NULL) {
  if (!DBI::dbIsValid(con)) {
    rlang::abort("`con` must be a valid DBI connection.", class = "ledgr_invalid_con")
  }
  if (!is.character(run_id) || length(run_id) != 1 || is.na(run_id) || !nzchar(run_id)) {
    rlang::abort("`run_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }

  if (inherits(fill_intent, "ledgr_fill_none")) {
    return(structure(
      list(
        status = "NO_OP",
        next_event_seq = event_seq_start
      ),
      class = "ledgr_ledger_write_result"
    ))
  }

  if (!inherits(fill_intent, "ledgr_fill_intent") || !is.list(fill_intent)) {
    rlang::abort("`fill_intent` must be a `ledgr_fill_intent`.", class = "ledgr_invalid_fill_intent")
  }

  instrument_id <- fill_intent$instrument_id
  side <- fill_intent$side
  qty <- fill_intent$qty
  fill_price <- fill_intent$fill_price
  commission_fixed <- fill_intent$commission_fixed
  ts_exec_utc <- fill_intent$ts_exec_utc

  if (!is.character(instrument_id) || length(instrument_id) != 1 || is.na(instrument_id) || !nzchar(instrument_id)) {
    rlang::abort("`fill_intent$instrument_id` must be a non-empty character scalar.", class = "ledgr_invalid_fill_intent")
  }
  if (!is.character(side) || length(side) != 1 || is.na(side) || !(side %in% c("BUY", "SELL"))) {
    rlang::abort("`fill_intent$side` must be 'BUY' or 'SELL'.", class = "ledgr_invalid_fill_intent")
  }
  if (!is.numeric(qty) || length(qty) != 1 || is.na(qty) || !is.finite(qty) || qty <= 0) {
    rlang::abort("`fill_intent$qty` must be a finite numeric scalar > 0.", class = "ledgr_invalid_fill_intent")
  }
  if (!is.numeric(fill_price) || length(fill_price) != 1 || is.na(fill_price) || !is.finite(fill_price) || fill_price <= 0) {
    rlang::abort("`fill_intent$fill_price` must be a finite numeric scalar > 0.", class = "ledgr_invalid_fill_intent")
  }
  if (!is.numeric(commission_fixed) || length(commission_fixed) != 1 || is.na(commission_fixed) || !is.finite(commission_fixed) || commission_fixed < 0) {
    rlang::abort("`fill_intent$commission_fixed` must be a finite numeric scalar >= 0.", class = "ledgr_invalid_fill_intent")
  }
  if (is.null(ts_exec_utc)) {
    rlang::abort("`fill_intent$ts_exec_utc` is required.", class = "ledgr_invalid_fill_intent")
  }

  if (!is.null(event_seq_start)) {
    if (!is.numeric(event_seq_start) || length(event_seq_start) != 1 || is.na(event_seq_start) || !is.finite(event_seq_start) ||
      event_seq_start < 1 || (event_seq_start %% 1) != 0) {
      rlang::abort("`event_seq_start` must be an integer >= 1.", class = "ledgr_invalid_args")
    }
    event_seq_start <- as.integer(event_seq_start)
  }

  run_exists <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM runs WHERE run_id = ?", params = list(run_id))$n[[1]] > 0
  if (!isTRUE(run_exists)) {
    rlang::abort(sprintf("run_id not found in runs table: %s", run_id), class = "ledgr_invalid_args")
  }

  signed_qty <- if (side == "BUY") as.numeric(qty) else -as.numeric(qty)
  cash_delta <- if (side == "BUY") {
    -(as.numeric(qty) * as.numeric(fill_price) + as.numeric(commission_fixed))
  } else {
    +(as.numeric(qty) * as.numeric(fill_price) - as.numeric(commission_fixed))
  }

  ts_exec_iso <- ledgr_normalize_ts_utc(ts_exec_utc)
  ts_exec_posix <- as.POSIXct(ts_exec_iso, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
  if (is.na(ts_exec_posix)) {
    rlang::abort("`fill_intent$ts_exec_utc` must be a valid UTC timestamp.", class = "ledgr_invalid_fill_intent")
  }

  meta_json <- canonical_json(
    list(
      commission_fixed = as.numeric(commission_fixed),
      cash_delta = as.numeric(cash_delta),
      position_delta = as.numeric(signed_qty),
      realized_pnl = NULL
    )
  )

  DBI::dbWithTransaction(con, {
    event_seq <- event_seq_start
    if (is.null(event_seq)) {
      event_seq <- DBI::dbGetQuery(
        con,
        "SELECT COALESCE(MAX(event_seq), 0) + 1 AS next_seq FROM ledger_events WHERE run_id = ?",
        params = list(run_id)
      )$next_seq[[1]]
      event_seq <- as.integer(event_seq)
    }

    event_id <- paste0(run_id, "_", sprintf("%08d", event_seq))

    DBI::dbExecute(
      con,
      "
      INSERT INTO ledger_events (
        event_id,
        run_id,
        ts_utc,
        event_type,
        instrument_id,
        side,
        qty,
        price,
        fee,
        meta_json,
        event_seq
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ",
      params = list(
        event_id,
        run_id,
        ts_exec_posix,
        "FILL",
        instrument_id,
        side,
        as.numeric(qty),
        as.numeric(fill_price),
        as.numeric(commission_fixed),
        meta_json,
        as.integer(event_seq)
      )
    )

    structure(
      list(
        status = "WROTE",
        event_id = event_id,
        event_seq = as.integer(event_seq),
        next_event_seq = as.integer(event_seq) + 1L,
        cash_delta = as.numeric(cash_delta),
        position_delta = as.numeric(signed_qty)
      ),
      class = "ledgr_ledger_write_result"
    )
  })
}

