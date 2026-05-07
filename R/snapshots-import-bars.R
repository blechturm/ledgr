#' Import snapshot bars from CSV (v0.1.1)
#'
#' Imports EOD bars into `snapshot_bars` for a snapshot in status `CREATED`
#' (snapshot mutability rule). Optionally imports instruments from CSV, or
#' auto-generates them from bars.
#'
#' CSV contract (v0.1.1 spec section 6.1):
#' - Required columns: `instrument_id`, `ts_utc`, `open`, `high`, `low`, `close`
#' - Optional columns: `volume` (defaults to `NA`)
#' - Timestamp format: ISO8601 UTC with trailing `Z`, e.g. `2020-01-01T00:00:00Z`
#' - Encoding: UTF-8 (BOM tolerated and stripped)
#' - Rounding: OHLCV are rounded to 8 decimals on import
#'
#' @param con A DBI connection to DuckDB.
#' @param snapshot_id Snapshot id (must exist and be status `CREATED`).
#' @param bars_csv_path Path to bars CSV.
#' @param instruments_csv_path Optional path to instruments CSV.
#' @param auto_generate_instruments If TRUE and `instruments_csv_path` is NULL,
#'   auto-generate instruments from bars.
#' @param encoding File encoding (default `"UTF-8"`).
#' @param validate Validation mode (default `"fail_fast"`).
#' @return Invisibly returns `TRUE` on success.
#' @details
#' Errors:
#' - `LEDGR_SNAPSHOT_NOT_FOUND` if `snapshot_id` does not exist.
#' - `LEDGR_SNAPSHOT_NOT_MUTABLE` if snapshot status is not `CREATED`.
#' - `LEDGR_CSV_FORMAT_ERROR` on CSV contract/parse violations or duplicate PKs.
#'
#' @section Articles:
#' Durable experiment stores:
#' `vignette("experiment-store", package = "ledgr")`
#' `system.file("doc", "experiment-store.html", package = "ledgr")`
#'
#' @examples
#' db_path <- tempfile(fileext = ".duckdb")
#' con <- ledgr_db_init(db_path)
#' snapshot_id <- ledgr_snapshot_create(
#'   con,
#'   snapshot_id = "snapshot_20200101_000000_abcd"
#' )
#' bars_csv <- tempfile(fileext = ".csv")
#' utils::write.csv(data.frame(
#'   instrument_id = "AAA",
#'   ts_utc = c("2020-01-01T00:00:00Z", "2020-01-02T00:00:00Z"),
#'   open = c(100, 101),
#'   high = c(101, 102),
#'   low = c(99, 100),
#'   close = c(100, 101),
#'   volume = 1000
#' ), bars_csv, row.names = FALSE)
#' ledgr_snapshot_import_bars_csv(con, snapshot_id, bars_csv)
#' DBI::dbDisconnect(con, shutdown = TRUE)
#' @export
ledgr_snapshot_import_bars_csv <- function(con,
                                          snapshot_id,
                                          bars_csv_path,
                                          instruments_csv_path = NULL,
                                          auto_generate_instruments = TRUE,
                                          encoding = "UTF-8",
                                          validate = c("fail_fast", "none")) {
  if (!DBI::dbIsValid(con)) {
    rlang::abort("`con` must be a valid DBI connection.", class = "ledgr_invalid_con")
  }
  ledgr_snapshot_require_created(con, snapshot_id)

  validate <- match.arg(validate)
  validate_fast <- identical(validate, "fail_fast")

  if (!is.logical(auto_generate_instruments) || length(auto_generate_instruments) != 1 || is.na(auto_generate_instruments)) {
    rlang::abort("`auto_generate_instruments` must be TRUE or FALSE.", class = "ledgr_invalid_args")
  }

  if (!is.null(instruments_csv_path)) {
    ledgr_snapshot_import_instruments_csv(
      con = con,
      snapshot_id = snapshot_id,
      instruments_csv_path = instruments_csv_path,
      encoding = encoding,
      strict = TRUE
    )
  }

  df <- ledgr_read_csv_strict(bars_csv_path, encoding = encoding, strict = TRUE)
  ledgr_csv_require_columns(df, c("instrument_id", "ts_utc", "open", "high", "low", "close"), label = "bars CSV")

  instrument_id <- as.character(df$instrument_id)
  if (anyNA(instrument_id) || any(!nzchar(instrument_id))) {
    rlang::abort("bars CSV `instrument_id` must be non-empty strings.", class = "LEDGR_CSV_FORMAT_ERROR")
  }

  ts_utc <- ledgr_csv_parse_ts_utc(as.character(df$ts_utc), "bars CSV `ts_utc`")

  open <- ledgr_csv_parse_num(df$open, "bars CSV `open`", required = TRUE, round_digits = 8L)
  high <- ledgr_csv_parse_num(df$high, "bars CSV `high`", required = TRUE, round_digits = 8L)
  low <- ledgr_csv_parse_num(df$low, "bars CSV `low`", required = TRUE, round_digits = 8L)
  close <- ledgr_csv_parse_num(df$close, "bars CSV `close`", required = TRUE, round_digits = 8L)
  volume <- if ("volume" %in% names(df)) {
    ledgr_csv_parse_num(df$volume, "bars CSV `volume`", required = FALSE, round_digits = 8L)
  } else {
    rep(NA_real_, length(open))
  }

  if (isTRUE(validate_fast)) {
    # OHLC constraints.
    max_ohlc <- pmax(open, close, low, na.rm = TRUE)
    min_ohlc <- pmin(open, close, high, na.rm = TRUE)
    bad_high <- which(high < max_ohlc)
    bad_low <- which(low > min_ohlc)
    if (length(bad_high) > 0 || length(bad_low) > 0) {
      rlang::abort("bars CSV contains an OHLC violation (high/low bounds).", class = "LEDGR_CSV_FORMAT_ERROR")
    }

    # Duplicate (instrument_id, ts_utc) within CSV.
    key <- paste0(instrument_id, "\n", format(ts_utc, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
    if (anyDuplicated(key)) {
      rlang::abort("bars CSV contains duplicate (instrument_id, ts_utc) rows.", class = "LEDGR_CSV_FORMAT_ERROR")
    }
  }

  # If instruments were not provided, handle auto-generation requirement.
  if (is.null(instruments_csv_path)) {
    if (isTRUE(auto_generate_instruments)) {
      ids <- sort(unique(instrument_id))
      gen <- data.frame(
        snapshot_id = rep(snapshot_id, length(ids)),
        instrument_id = ids,
        symbol = ids,
        currency = rep("USD", length(ids)),
        asset_class = rep("EQUITY", length(ids)),
        multiplier = rep(1.0, length(ids)),
        tick_size = rep(0.01, length(ids)),
        meta_json = rep(NA_character_, length(ids)),
        stringsAsFactors = FALSE
      )
      tryCatch(
        DBI::dbAppendTable(con, "snapshot_instruments", gen),
        error = function(e) {
          rlang::abort(
            sprintf("Auto-generated instruments insert failed (likely duplicate PKs): %s", conditionMessage(e)),
            class = "LEDGR_CSV_FORMAT_ERROR"
          )
        }
      )
    } else {
      rlang::abort(
        "instruments_csv_path is NULL and auto_generate_instruments is FALSE.",
        class = "LEDGR_CSV_FORMAT_ERROR"
      )
    }
  }

  if (isTRUE(validate_fast)) {
    # Referential integrity (v0.1.1 I11): ensure all bar instrument_ids exist in snapshot_instruments.
    uniq_ids <- sort(unique(instrument_id))
    ids_sql <- paste(DBI::dbQuoteString(con, uniq_ids), collapse = ", ")
    present <- DBI::dbGetQuery(
      con,
      paste0(
        "SELECT instrument_id FROM snapshot_instruments ",
        "WHERE snapshot_id = ? AND instrument_id IN (", ids_sql, ")"
      ),
      params = list(snapshot_id)
    )$instrument_id
    missing <- setdiff(uniq_ids, as.character(present))
    if (length(missing) > 0) {
      rlang::abort(
        sprintf("bars CSV references instruments not present in snapshot_instruments: %s", paste(missing, collapse = ", ")),
        class = "LEDGR_CSV_FORMAT_ERROR"
      )
    }
  }

  out <- data.frame(
    snapshot_id = rep(snapshot_id, length(instrument_id)),
    instrument_id = instrument_id,
    ts_utc = ts_utc,
    open = open,
    high = high,
    low = low,
    close = close,
    volume = volume,
    stringsAsFactors = FALSE
  )

  ord <- order(out$instrument_id, out$ts_utc)
  out <- out[ord, , drop = FALSE]

  ok <- tryCatch(
    {
      DBI::dbAppendTable(con, "snapshot_bars", out)
      TRUE
    },
    error = function(e) {
      rlang::abort(
        sprintf("Bars import failed (likely duplicate PKs): %s", conditionMessage(e)),
        class = "LEDGR_CSV_FORMAT_ERROR"
      )
    }
  )

  invisible(ok)
}
