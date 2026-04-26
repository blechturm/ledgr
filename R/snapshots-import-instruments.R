#' Import snapshot instruments from CSV (v0.1.1)
#'
#' Imports instrument metadata into `snapshot_instruments` for a snapshot in
#' status `CREATED` (snapshot mutability rule).
#'
#' CSV contract (v0.1.1 spec section 6.2):
#' - Required columns: `instrument_id`, `symbol`
#' - Optional columns (defaults): `currency` (`"USD"`), `asset_class` (`"EQUITY"`),
#'   `multiplier` (`1.0`), `tick_size` (`0.01`)
#' - Encoding: UTF-8 (BOM tolerated and stripped)
#'
#' @param con A DBI connection to DuckDB.
#' @param snapshot_id Snapshot id (must exist and be status `CREATED`).
#' @param instruments_csv_path Path to instruments CSV.
#' @param encoding File encoding (default `"UTF-8"`).
#' @param strict If `TRUE`, fail loud on any contract violation.
#' @return Invisibly returns `TRUE` on success.
#' @details
#' Errors:
#' - `LEDGR_SNAPSHOT_NOT_FOUND` if `snapshot_id` does not exist.
#' - `LEDGR_SNAPSHOT_NOT_MUTABLE` if snapshot status is not `CREATED`.
#' - `LEDGR_CSV_FORMAT_ERROR` on CSV contract/parse violations or duplicate PKs.
#'
#' @examples
#' db_path <- tempfile(fileext = ".duckdb")
#' con <- ledgr_db_init(db_path)
#' snapshot_id <- ledgr_snapshot_create(
#'   con,
#'   snapshot_id = "snapshot_20200101_000000_abcd"
#' )
#' instruments_csv <- tempfile(fileext = ".csv")
#' utils::write.csv(data.frame(
#'   instrument_id = "AAA",
#'   symbol = "AAA"
#' ), instruments_csv, row.names = FALSE)
#' ledgr_snapshot_import_instruments_csv(con, snapshot_id, instruments_csv)
#' DBI::dbDisconnect(con, shutdown = TRUE)
#' @export
ledgr_snapshot_import_instruments_csv <- function(con,
                                                 snapshot_id,
                                                 instruments_csv_path,
                                                 encoding = "UTF-8",
                                                 strict = TRUE) {
  if (!DBI::dbIsValid(con)) {
    rlang::abort("`con` must be a valid DBI connection.", class = "ledgr_invalid_con")
  }
  ledgr_snapshot_require_created(con, snapshot_id)

  df <- ledgr_read_csv_strict(instruments_csv_path, encoding = encoding, strict = strict)
  ledgr_csv_require_columns(df, c("instrument_id", "symbol"), label = "instruments CSV")

  instrument_id <- as.character(df$instrument_id)
  symbol <- as.character(df$symbol)
  if (anyNA(instrument_id) || any(!nzchar(instrument_id))) {
    rlang::abort("instruments CSV `instrument_id` must be non-empty strings.", class = "LEDGR_CSV_FORMAT_ERROR")
  }
  if (anyNA(symbol) || any(!nzchar(symbol))) {
    rlang::abort("instruments CSV `symbol` must be non-empty strings.", class = "LEDGR_CSV_FORMAT_ERROR")
  }
  if (anyDuplicated(instrument_id)) {
    dups <- unique(instrument_id[duplicated(instrument_id)])
    rlang::abort(
      sprintf("instruments CSV contains duplicate instrument_id values: %s", paste(dups, collapse = ", ")),
      class = "LEDGR_CSV_FORMAT_ERROR"
    )
  }

  currency <- if ("currency" %in% names(df)) as.character(df$currency) else rep(NA_character_, length(instrument_id))
  asset_class <- if ("asset_class" %in% names(df)) as.character(df$asset_class) else rep(NA_character_, length(instrument_id))
  multiplier <- if ("multiplier" %in% names(df)) {
    ledgr_csv_parse_num(df$multiplier, "instruments CSV `multiplier`", required = FALSE)
  } else {
    rep(NA_real_, length(instrument_id))
  }
  tick_size <- if ("tick_size" %in% names(df)) {
    ledgr_csv_parse_num(df$tick_size, "instruments CSV `tick_size`", required = FALSE)
  } else {
    rep(NA_real_, length(instrument_id))
  }

  currency[is.na(currency) | !nzchar(currency)] <- "USD"
  asset_class[is.na(asset_class) | !nzchar(asset_class)] <- "EQUITY"
  multiplier[is.na(multiplier)] <- 1.0
  tick_size[is.na(tick_size)] <- 0.01

  out <- data.frame(
    snapshot_id = rep(snapshot_id, length(instrument_id)),
    instrument_id = instrument_id,
    symbol = symbol,
    currency = currency,
    asset_class = asset_class,
    multiplier = as.numeric(multiplier),
    tick_size = as.numeric(tick_size),
    meta_json = rep(NA_character_, length(instrument_id)),
    stringsAsFactors = FALSE
  )

  # Deterministic insertion order.
  ord <- order(out$instrument_id)
  out <- out[ord, , drop = FALSE]

  ok <- tryCatch(
    {
      DBI::dbAppendTable(con, "snapshot_instruments", out)
      TRUE
    },
    error = function(e) {
      rlang::abort(
        sprintf("Instrument import failed (likely duplicate PKs): %s", conditionMessage(e)),
        class = "LEDGR_CSV_FORMAT_ERROR"
      )
    }
  )

  invisible(ok)
}
