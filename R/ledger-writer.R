# The one computation of fill publication effects: cash and position deltas
# (fold-phase synthesis Section 11, R3; typed-fold-carrier synthesis 3.3;
# contract-execution-accounting-events). P3 calls it once per pulse on the
# batch of resolved fills (`side` +1 buy, -1 sell); the typed plan carries
# the results, and affordability, fold cash, the reconciliation sums and
# every publication sink reuse them. No sink recomputes them.
ledgr_fill_publication_deltas <- function(side, qty, fill_price, fee) {
  qty <- as.numeric(qty)
  price <- as.numeric(fill_price)
  fee <- as.numeric(fee)
  buy <- side > 0L
  cash_delta <- +(qty * price - fee)
  cash_delta[buy] <- -(qty[buy] * price[buy] + fee[buy])
  position_delta <- -qty
  position_delta[buy] <- qty[buy]
  list(cash_delta = cash_delta, position_delta = position_delta)
}

# The reader boundary validates published effects against the same formula
# without becoming another P3 computation site. This binding is refreshed
# from ledgr_fill_publication_deltas() whenever the namespace is loaded.
.ledgr_fill_publication_formula <- ledgr_fill_publication_deltas

# The db_live writer: row `i` of the typed fill group `fill` (P3's columns
# and computed effects), published for `instrument_id`. A zero-length `i` is
# the no-op.
ledgr_write_fill_events <- function(con, run_id, fill, i, instrument_id, event_seq_start = NULL, use_transaction = TRUE) {
  if (!DBI::dbIsValid(con)) {
    rlang::abort("`con` must be a valid DBI connection.", class = "ledgr_invalid_con")
  }
  if (!is.character(run_id) || length(run_id) != 1 || is.na(run_id) || !nzchar(run_id)) {
    rlang::abort("`run_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }

  if (length(i) == 0L) {
    return(structure(
      list(
        status = "NO_OP",
        next_event_seq = event_seq_start
      ),
      class = "ledgr_ledger_write_result"
    ))
  }

  if (!is.logical(use_transaction) || length(use_transaction) != 1 || is.na(use_transaction)) {
    rlang::abort("`use_transaction` must be TRUE or FALSE.", class = "ledgr_invalid_args")
  }

  ledgr_fill_input_check(fill, i, single = TRUE)
  side <- fill$side[[i]]
  qty <- fill$qty[[i]]
  fill_price <- fill$price[[i]]
  fee <- fill$fee[[i]]

  if (!is.character(instrument_id) || length(instrument_id) != 1 || is.na(instrument_id) || !nzchar(instrument_id)) {
    rlang::abort("`fill_intent$instrument_id` must be a non-empty character scalar.", class = "ledgr_invalid_fill_intent")
  }
  if (is.na(side) || !(side %in% c(1L, -1L))) {
    rlang::abort("`fill_intent$side` must be 'BUY' or 'SELL'.", class = "ledgr_invalid_fill_intent")
  }
  if (is.na(qty) || !is.finite(qty) || qty <= 0) {
    rlang::abort("`fill_intent$qty` must be a finite numeric scalar > 0.", class = "ledgr_invalid_fill_intent")
  }
  if (is.na(fill_price) || !is.finite(fill_price) || fill_price <= 0) {
    rlang::abort("`fill_intent$fill_price` must be a finite numeric scalar > 0.", class = "ledgr_invalid_fill_intent")
  }
  if (is.na(fee) || !is.finite(fee) || fee < 0) {
    rlang::abort("`fill_intent$fee` must be a finite numeric scalar >= 0.", class = "ledgr_invalid_fill_intent")
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

  # The effects P3 computed for this fill.
  signed_qty <- fill$position_delta[[i]]
  cash_delta <- fill$cash_delta[[i]]

  # The execution epoch materializes as POSIXct at this output boundary.
  ts_exec_posix <- ledgr_assert_whole_second_utc(
    .POSIXct(fill$exec_ts[[i]], tz = "UTC"),
    label = "`fill_intent$ts_exec_utc`",
    class = "ledgr_invalid_fill_intent"
  )
  side_token <- if (side > 0L) "BUY" else "SELL"

  meta_json <- canonical_json(
    list(
      fee = as.numeric(fee),
      cash_delta = as.numeric(cash_delta),
      position_delta = as.numeric(signed_qty),
      realized_pnl = NULL
    )
  )

  do_write <- function() {
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
        side_token,
        as.numeric(qty),
        as.numeric(fill_price),
        as.numeric(fee),
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
  }

  if (isTRUE(use_transaction)) {
    DBI::dbWithTransaction(con, do_write())
  } else {
    do_write()
  }
}

# The fill input of a publication boundary: a typed fill group (its
# publication columns and computed effects) and distinct row indexes within
# it: a block for the buffered and memory sinks, one row (`single`) for the
# db_live writer.
ledgr_fill_input_check <- function(fill, i, single = FALSE) {
  columns <- c("side", "qty", "price", "fee", "cash_delta", "position_delta", "exec_ts")
  n <- if (is.list(fill)) length(fill$qty) else NA_integer_
  ok <- is.list(fill) && !is.data.frame(fill) && all(columns %in% names(fill)) &&
    all(lengths(fill[columns]) == n) && is.integer(fill$side) &&
    all(vapply(fill[columns[-1L]], is.double, logical(1))) &&
    is.numeric(i) && length(i) >= 1L && !anyNA(i) && all(i >= 1 & i <= n & i %% 1 == 0) &&
    !anyDuplicated(i) && (!single || length(i) == 1L)
  if (!isTRUE(ok)) {
    rlang::abort("`fill` must be a typed fill group with row `i`.", class = "ledgr_invalid_fill_intent")
  }
  invisible(TRUE)
}
