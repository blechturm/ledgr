#' Compute deterministic data hash for a run-relevant bars snapshot (v0.1.0)
#'
#' Computes a deterministic SHA-256 hash over:
#' - ordered `instrument_ids` (order-sensitive)
#' - canonical UTC `start_ts_utc` and `end_ts_utc` (ISO8601 with trailing `Z`)
#' - a bars fingerprint for the subset ordered by `(instrument_id, ts_utc)`
#'
#' Numeric OHLCV values are rounded to 8 decimal places before hashing.
#' Missing values are represented as the literal string `NA`.
#'
#' @param con A DBI connection to DuckDB.
#' @param instrument_ids Character vector of instrument ids (order-sensitive).
#' @param start_ts_utc Start timestamp (character ISO8601 `...Z` or POSIXt).
#' @param end_ts_utc End timestamp (character ISO8601 `...Z` or POSIXt).
#' @return A SHA-256 hex string.
#' @export
ledgr_data_hash <- function(con, instrument_ids, start_ts_utc, end_ts_utc) {
  if (!DBI::dbIsValid(con)) {
    rlang::abort("`con` must be a valid DBI connection.", class = "ledgr_invalid_con")
  }
  if (!is.character(instrument_ids) || length(instrument_ids) < 1 || anyNA(instrument_ids) || any(!nzchar(instrument_ids))) {
    rlang::abort("`instrument_ids` must be a non-empty character vector of non-empty strings.", class = "ledgr_invalid_args")
  }

  parse_ts_utc <- function(x) {
    if (inherits(x, "POSIXt")) {
      out <- as.POSIXct(x, tz = "UTC")
      if (is.na(out)) rlang::abort("Timestamp could not be converted to POSIXct.", class = "ledgr_invalid_args")
      return(out)
    }
    if (!is.character(x) || length(x) != 1 || is.na(x) || !nzchar(x)) {
      rlang::abort("Timestamps must be a non-empty scalar string (ISO8601) or POSIXt.", class = "ledgr_invalid_args")
    }

    if (grepl("Z$", x) && grepl("T", x, fixed = TRUE)) {
      out <- as.POSIXct(x, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
    } else {
      out <- as.POSIXct(x, tz = "UTC")
    }
    if (is.na(out)) {
      rlang::abort(
        sprintf("Timestamp is not parseable as UTC: %s", x),
        class = "ledgr_invalid_args"
      )
    }
    out
  }

  fmt_ts_utc <- function(x) {
    format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  }

  start_ts <- parse_ts_utc(start_ts_utc)
  end_ts <- parse_ts_utc(end_ts_utc)
  if (start_ts > end_ts) {
    rlang::abort("`start_ts_utc` must be <= `end_ts_utc`.", class = "ledgr_invalid_args")
  }

  format_num <- function(x, digits = 8L) {
    if (!is.numeric(x)) x <- as.numeric(x)
    out <- rep("NA", length(x))
    ok <- !is.na(x)
    if (any(ok)) {
      out[ok] <- formatC(round(x[ok], digits = digits), format = "f", digits = digits)
    }
    out
  }

  schema_header <- paste0(
    "instrument_ids|", paste(instrument_ids, collapse = ","), "\n",
    "start_ts_utc|", fmt_ts_utc(start_ts), "\n",
    "end_ts_utc|", fmt_ts_utc(end_ts), "\n"
  )

  chunk_hashes <- character(0)
  chunk_hashes <- c(chunk_hashes, digest::digest(schema_header, algo = "sha256", serialize = FALSE))

  ids_sql <- paste(DBI::dbQuoteString(con, instrument_ids), collapse = ", ")
  sql <- paste0(
    "SELECT instrument_id, ts_utc, open, high, low, close, volume ",
    "FROM bars ",
    "WHERE instrument_id IN (", ids_sql, ") ",
    "  AND ts_utc >= ? AND ts_utc <= ? ",
    "ORDER BY instrument_id, ts_utc"
  )

  res <- DBI::dbSendQuery(con, sql)
  on.exit(try(DBI::dbClearResult(res), silent = TRUE), add = TRUE)
  DBI::dbBind(res, params = list(start_ts, end_ts))

  repeat {
    chunk <- DBI::dbFetch(res, n = 100000)
    if (nrow(chunk) == 0) break

    inst <- as.character(chunk$instrument_id)
    ts <- fmt_ts_utc(chunk$ts_utc)
    open <- format_num(chunk$open, digits = 8L)
    high <- format_num(chunk$high, digits = 8L)
    low <- format_num(chunk$low, digits = 8L)
    close <- format_num(chunk$close, digits = 8L)
    vol <- format_num(chunk$volume, digits = 8L)

    lines <- paste(inst, ts, open, high, low, close, vol, sep = "|")
    chunk_text <- paste0(paste(lines, collapse = "\n"), "\n")
    chunk_hashes <- c(chunk_hashes, digest::digest(chunk_text, algo = "sha256", serialize = FALSE))
  }

  digest::digest(paste0(chunk_hashes, collapse = ""), algo = "sha256", serialize = FALSE)
}

