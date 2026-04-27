#' Create a snapshot from an in-memory data.frame
#'
#' Validates schema, normalizes timestamps, creates a snapshot via v0.1.1
#' functions, imports bars, seals the snapshot, and returns a lazy snapshot
#' object.
#'
#' @param bars_df data.frame with required columns: ts_utc, instrument_id,
#'   open, high, low, close. Optional: volume.
#' @param instruments_df Optional data.frame with instrument metadata.
#' @param db_path Optional DuckDB file path (default: tempfile).
#' @param snapshot_id Optional snapshot id (default: v0.1.1 canonical generation).
#' @return A `ledgr_snapshot` object.
#' @examples
#' bars <- data.frame(
#'   ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:2,
#'   instrument_id = "AAA",
#'   open = c(100, 101, 102),
#'   high = c(101, 102, 103),
#'   low = c(99, 100, 101),
#'   close = c(100, 101, 102),
#'   volume = 1000
#' )
#' snapshot <- ledgr_snapshot_from_df(bars)
#' ledgr_snapshot_info(snapshot)
#' ledgr_snapshot_close(snapshot)
#' @export
ledgr_snapshot_from_df <- function(bars_df,
                                   instruments_df = NULL,
                                   db_path = NULL,
                                   snapshot_id = NULL) {
  if (!is.data.frame(bars_df)) {
    rlang::abort("`bars_df` must be a data.frame (or tibble).", class = "ledgr_invalid_args")
  }

  ledgr_validate_snapshot_id(snapshot_id)

  required_cols <- c("ts_utc", "instrument_id", "open", "high", "low", "close")
  missing <- setdiff(required_cols, names(bars_df))
  if (length(missing) > 0) {
    rlang::abort(
      sprintf(
        "bars_df missing required column(s): %s. Required columns: %s",
        paste(missing, collapse = ", "),
        paste(required_cols, collapse = ", ")
      ),
      class = "ledgr_invalid_args"
    )
  }

  instrument_id <- as.character(bars_df$instrument_id)
  if (anyNA(instrument_id) || any(!nzchar(instrument_id))) {
    rlang::abort("bars_df `instrument_id` must be non-empty strings.", class = "ledgr_invalid_args")
  }

  ts_raw <- bars_df$ts_utc
  ts_posix <- NULL
  if (inherits(ts_raw, "POSIXt")) {
    ts_posix <- as.POSIXct(ts_raw, tz = "UTC")
    if (length(ts_posix) != length(ts_raw) || anyNA(ts_posix)) {
      rlang::abort("bars_df `ts_utc` must be valid POSIXt values.", class = "ledgr_invalid_args")
    }
    ts_utc <- format(ts_posix, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  } else if (inherits(ts_raw, "Date")) {
    if (length(ts_raw) == 0 || anyNA(ts_raw)) {
      rlang::abort("bars_df `ts_utc` must be valid Date values.", class = "ledgr_invalid_args")
    }
    ts_posix <- as.POSIXct(ts_raw, tz = "UTC")
    ts_utc <- sprintf("%sT00:00:00Z", format(ts_raw, "%Y-%m-%d"))
  } else if (is.character(ts_raw)) {
    if (anyNA(ts_raw) || any(!nzchar(ts_raw))) {
      rlang::abort("bars_df `ts_utc` must be non-empty timestamps.", class = "ledgr_invalid_args")
    }
    pat_date <- "^\\d{4}-\\d{2}-\\d{2}$"
    pat_dt <- "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}$"
    pat_dt_z <- "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$"

    if (all(grepl(pat_date, ts_raw))) {
      d <- as.Date(ts_raw, format = "%Y-%m-%d")
      if (anyNA(d)) {
        rlang::abort("bars_df `ts_utc` contains invalid dates.", class = "ledgr_invalid_args")
      }
      ts_posix <- as.POSIXct(d, tz = "UTC")
      ts_utc <- sprintf("%sT00:00:00Z", format(d, "%Y-%m-%d"))
    } else if (all(grepl(pat_dt_z, ts_raw))) {
      ts_posix <- as.POSIXct(ts_raw, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
      if (anyNA(ts_posix)) {
        rlang::abort("bars_df `ts_utc` contains invalid timestamps.", class = "ledgr_invalid_args")
      }
      ts_utc <- format(ts_posix, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    } else if (all(grepl(pat_dt, ts_raw))) {
      ts_posix <- as.POSIXct(ts_raw, tz = "UTC", format = "%Y-%m-%dT%H:%M:%S")
      if (anyNA(ts_posix)) {
        rlang::abort("bars_df `ts_utc` contains invalid timestamps.", class = "ledgr_invalid_args")
      }
      ts_utc <- format(ts_posix, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    } else {
      ts_utc <- vapply(ts_raw, iso_utc, character(1))
      ts_posix <- as.POSIXct(ts_utc, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
      if (anyNA(ts_posix)) {
        rlang::abort("bars_df `ts_utc` contains invalid timestamps.", class = "ledgr_invalid_args")
      }
    }
  } else {
    ts_utc <- vapply(ts_raw, iso_utc, character(1))
    ts_posix <- as.POSIXct(ts_utc, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
    if (anyNA(ts_posix)) {
      rlang::abort("bars_df `ts_utc` contains invalid timestamps.", class = "ledgr_invalid_args")
    }
  }

  open <- suppressWarnings(as.numeric(bars_df$open))
  high <- suppressWarnings(as.numeric(bars_df$high))
  low <- suppressWarnings(as.numeric(bars_df$low))
  close <- suppressWarnings(as.numeric(bars_df$close))
  if (anyNA(open) || anyNA(high) || anyNA(low) || anyNA(close) ||
      any(!is.finite(open), na.rm = TRUE) || any(!is.finite(high), na.rm = TRUE) ||
      any(!is.finite(low), na.rm = TRUE) || any(!is.finite(close), na.rm = TRUE)) {
    rlang::abort("bars_df OHLC columns must be finite numeric values.", class = "ledgr_invalid_args")
  }

  volume <- if ("volume" %in% names(bars_df)) {
    vol <- suppressWarnings(as.numeric(bars_df$volume))
    if (any(!is.na(vol) & !is.finite(vol))) {
      rlang::abort("bars_df `volume` must be finite when provided.", class = "ledgr_invalid_args")
    }
    vol
  } else {
    rep(NA_real_, length(open))
  }

  open <- round(open, digits = 8L)
  high <- round(high, digits = 8L)
  low <- round(low, digits = 8L)
  close <- round(close, digits = 8L)
  volume <- round(volume, digits = 8L)

  max_ohlc <- pmax(open, close, low, na.rm = TRUE)
  min_ohlc <- pmin(open, close, high, na.rm = TRUE)
  if (any(high < max_ohlc) || any(low > min_ohlc)) {
    rlang::abort("bars_df contains an OHLC violation (high/low bounds).", class = "ledgr_invalid_args")
  }

  bad_order <- tapply(ts_posix, instrument_id, function(x) any(diff(x) < 0))
  if (any(bad_order)) {
    rlang::abort(
      "bars_df must be chronological per instrument (non-decreasing ts_utc).",
      class = "ledgr_invalid_args"
    )
  }

  key <- paste0(instrument_id, "\n", ts_utc)
  if (anyDuplicated(key)) {
    rlang::abort("bars_df contains duplicate (instrument_id, ts_utc) rows.", class = "ledgr_invalid_args")
  }

  bars_out <- data.frame(
    instrument_id = instrument_id,
    ts_utc = ts_utc,
    open = open,
    high = high,
    low = low,
    close = close,
    volume = volume,
    stringsAsFactors = FALSE
  )

  if (is.null(db_path)) {
    db_path <- tempfile(pattern = "ledgr_", fileext = ".duckdb")
  }
  if (!is.character(db_path) || length(db_path) != 1 || is.na(db_path) || !nzchar(db_path)) {
    rlang::abort("`db_path` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }

  meta_updates <- NULL
  inst_out <- NULL
  if (!is.null(instruments_df)) {
    if (!is.data.frame(instruments_df)) {
      rlang::abort("`instruments_df` must be a data.frame (or tibble).", class = "ledgr_invalid_args")
    }
    if (!("instrument_id" %in% names(instruments_df))) {
      rlang::abort("instruments_df must include `instrument_id`.", class = "ledgr_invalid_args")
    }

    inst_id <- as.character(instruments_df$instrument_id)
    if (anyNA(inst_id) || any(!nzchar(inst_id))) {
      rlang::abort("instruments_df `instrument_id` must be non-empty strings.", class = "ledgr_invalid_args")
    }
    if (anyDuplicated(inst_id)) {
      rlang::abort("instruments_df contains duplicate instrument_id values.", class = "ledgr_invalid_args")
    }

    missing_inst <- setdiff(unique(instrument_id), inst_id)
    if (length(missing_inst) > 0) {
      rlang::abort(
        sprintf("bars_df references instruments not present in instruments_df: %s", paste(missing_inst, collapse = ", ")),
        class = "ledgr_invalid_args"
      )
    }

    symbol <- if ("symbol" %in% names(instruments_df)) as.character(instruments_df$symbol) else inst_id
    if (anyNA(symbol) || any(!nzchar(symbol))) {
      rlang::abort("instruments_df `symbol` must be non-empty strings.", class = "ledgr_invalid_args")
    }

    currency <- if ("currency" %in% names(instruments_df)) as.character(instruments_df$currency) else rep("USD", length(inst_id))
    asset_class <- if ("asset_class" %in% names(instruments_df)) as.character(instruments_df$asset_class) else rep("EQUITY", length(inst_id))

    multiplier <- if ("multiplier" %in% names(instruments_df)) {
      suppressWarnings(as.numeric(instruments_df$multiplier))
    } else {
      rep(1.0, length(inst_id))
    }
    tick_size <- if ("tick_size" %in% names(instruments_df)) {
      suppressWarnings(as.numeric(instruments_df$tick_size))
    } else {
      rep(0.01, length(inst_id))
    }

    if (anyNA(multiplier) || any(!is.finite(multiplier), na.rm = TRUE)) {
      rlang::abort("instruments_df `multiplier` must be finite when provided.", class = "ledgr_invalid_args")
    }
    if (anyNA(tick_size) || any(!is.finite(tick_size), na.rm = TRUE)) {
      rlang::abort("instruments_df `tick_size` must be finite when provided.", class = "ledgr_invalid_args")
    }

    if ("meta_json" %in% names(instruments_df)) {
      meta_updates <- as.character(instruments_df$meta_json)
      meta_updates[!nzchar(meta_updates)] <- NA_character_
    } else if ("metadata" %in% names(instruments_df)) {
      meta_updates <- vapply(
        instruments_df$metadata,
        function(x) {
          if (is.null(x) || (is.atomic(x) && length(x) == 1 && is.na(x))) {
            NA_character_
          } else {
            canonical_json(x)
          }
        },
        character(1)
      )
    }

    ord_inst <- order(inst_id)
    inst_out <- data.frame(
      instrument_id = inst_id[ord_inst],
      symbol = symbol[ord_inst],
      currency = currency[ord_inst],
      asset_class = asset_class[ord_inst],
      multiplier = multiplier[ord_inst],
      tick_size = tick_size[ord_inst],
      stringsAsFactors = FALSE
    )
    if (!is.null(meta_updates)) meta_updates <- meta_updates[ord_inst]
  } else {
    inst_id <- sort(unique(bars_out$instrument_id))
    inst_out <- data.frame(
      instrument_id = inst_id,
      symbol = inst_id,
      currency = rep("USD", length(inst_id)),
      asset_class = rep("EQUITY", length(inst_id)),
      multiplier = rep(1.0, length(inst_id)),
      tick_size = rep(0.01, length(inst_id)),
      stringsAsFactors = FALSE
    )
  }

  con <- NULL
  drv <- NULL
  on.exit(
    {
      if (!is.null(con) && DBI::dbIsValid(con)) {
        suppressWarnings(try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE))
      }
      if (!is.null(drv)) {
        suppressWarnings(try(duckdb::duckdb_shutdown(drv), silent = TRUE))
      }
    },
    add = TRUE
  )

  if (identical(db_path, ":memory:") || !file.exists(db_path)) {
    drv <- duckdb::duckdb()
    con <- DBI::dbConnect(drv, dbdir = db_path)
    attr(con, "ledgr_duckdb_drv") <- drv
    ledgr_create_schema(con)
  } else {
    con <- ledgr_db_init(db_path)
    drv <- attr(con, "ledgr_duckdb_drv")
  }

  snapshot_id <- ledgr_snapshot_create(con, snapshot_id = snapshot_id, meta = list())

  inst_db <- data.frame(
    snapshot_id = rep(snapshot_id, nrow(inst_out)),
    instrument_id = inst_out$instrument_id,
    symbol = inst_out$symbol,
    currency = inst_out$currency,
    asset_class = inst_out$asset_class,
    multiplier = as.numeric(inst_out$multiplier),
    tick_size = as.numeric(inst_out$tick_size),
    meta_json = rep(NA_character_, nrow(inst_out)),
    stringsAsFactors = FALSE
  )

  bars_db <- data.frame(
    snapshot_id = rep(snapshot_id, nrow(bars_out)),
    instrument_id = bars_out$instrument_id,
    ts_utc = ts_posix,
    open = bars_out$open,
    high = bars_out$high,
    low = bars_out$low,
    close = bars_out$close,
    volume = bars_out$volume,
    stringsAsFactors = FALSE
  )

  inst_db$meta_json <- if (is.null(meta_updates)) rep(NA_character_, nrow(inst_db)) else meta_updates

  bulk_copy_parquet <- function(df, table, select_sql) {
    reg_name <- paste0("ledgr_ingest_", paste(sample(c(letters, LETTERS, 0:9), 12, replace = TRUE), collapse = ""))
    tmp_path <- normalizePath(tempfile(pattern = "ledgr_ingest_", fileext = ".parquet"), winslash = "/", mustWork = FALSE)
    duckdb::duckdb_register(con, reg_name, df)
    on.exit(duckdb::duckdb_unregister(con, reg_name), add = TRUE)
    on.exit(unlink(tmp_path, force = TRUE), add = TRUE)

    DBI::dbExecute(
      con,
      sprintf("COPY (%s) TO '%s' (FORMAT PARQUET)", sprintf(select_sql, reg_name), tmp_path)
    )
    DBI::dbExecute(
      con,
      sprintf("COPY %s FROM '%s' (FORMAT PARQUET)", table, tmp_path)
    )
  }

  DBI::dbWithTransaction(con, {
    tryCatch(
      bulk_copy_parquet(
        inst_db,
        "snapshot_instruments",
        "SELECT CAST(snapshot_id AS TEXT) AS snapshot_id,
                CAST(instrument_id AS TEXT) AS instrument_id,
                CAST(symbol AS TEXT) AS symbol,
                CAST(currency AS TEXT) AS currency,
                CAST(asset_class AS TEXT) AS asset_class,
                CAST(multiplier AS DOUBLE) AS multiplier,
                CAST(tick_size AS DOUBLE) AS tick_size,
                CAST(meta_json AS TEXT) AS meta_json
         FROM %s"
      ),
      error = function(e) {
        rlang::abort(
          sprintf("Instrument insert failed (likely duplicate PKs): %s", conditionMessage(e)),
          class = "ledgr_invalid_args"
        )
      }
    )
    tryCatch(
      bulk_copy_parquet(
        bars_db,
        "snapshot_bars",
        "SELECT CAST(snapshot_id AS TEXT) AS snapshot_id,
                CAST(instrument_id AS TEXT) AS instrument_id,
                CAST(ts_utc AS TIMESTAMP) AS ts_utc,
                CAST(open AS DOUBLE) AS open,
                CAST(high AS DOUBLE) AS high,
                CAST(low AS DOUBLE) AS low,
                CAST(close AS DOUBLE) AS close,
                CAST(volume AS DOUBLE) AS volume
         FROM %s"
      ),
      error = function(e) {
        rlang::abort(
          sprintf("Bars insert failed (likely duplicate PKs): %s", conditionMessage(e)),
          class = "ledgr_invalid_args"
        )
      }
    )
  })

  DBI::dbExecute(
    con,
    "CREATE INDEX IF NOT EXISTS idx_snapshot_bars_ts ON snapshot_bars(snapshot_id, ts_utc)"
  )

  DBI::dbExecute(
    con,
    paste0(
      "CREATE OR REPLACE TEMP VIEW bars AS ",
      "SELECT instrument_id, ts_utc, open, high, low, close, volume ",
      "FROM snapshot_bars ",
      "WHERE snapshot_id = ",
      DBI::dbQuoteString(con, snapshot_id)
    )
  )
  on.exit(suppressWarnings(try(DBI::dbExecute(con, "DROP VIEW bars"), silent = TRUE)), add = TRUE)

  data_hash <- ledgr_snapshot_adapter_data_subset_hash(
    con,
    sort(unique(bars_out$instrument_id)),
    min(ts_posix),
    max(ts_posix)
  )

  created_at <- DBI::dbGetQuery(
    con,
    "SELECT created_at_utc FROM snapshots WHERE snapshot_id = ?",
    params = list(snapshot_id)
  )$created_at_utc[[1]]

  start_date <- ledgr_normalize_ts_utc(min(ts_posix))
  end_date <- ledgr_normalize_ts_utc(max(ts_posix))

  metadata <- list(
    n_bars = as.integer(nrow(bars_out)),
    n_instruments = as.integer(nrow(inst_out)),
    start_date = start_date,
    end_date = end_date,
    created_at = ledgr_normalize_ts_utc(created_at),
    data_hash = data_hash
  )

  DBI::dbExecute(
    con,
    "UPDATE snapshots SET meta_json = ? WHERE snapshot_id = ?",
    params = list(canonical_json(metadata), snapshot_id)
  )

  ledgr_snapshot_seal(con, snapshot_id)

  new_ledgr_snapshot(db_path = db_path, snapshot_id = snapshot_id, metadata = metadata)
}

#' Create a snapshot from a CSV file
#'
#' Reads a CSV file and delegates to `ledgr_snapshot_from_df()`.
#'
#' @param csv_path Path to a bars CSV file.
#' @param db_path Optional DuckDB file path (default: tempfile).
#' @param snapshot_id Optional snapshot id (default: v0.1.1 canonical generation).
#' @return A `ledgr_snapshot` object.
#' @examples
#' csv_path <- tempfile(fileext = ".csv")
#' utils::write.csv(data.frame(
#'   ts_utc = c("2020-01-01T00:00:00Z", "2020-01-02T00:00:00Z"),
#'   instrument_id = "AAA",
#'   open = c(100, 101),
#'   high = c(101, 102),
#'   low = c(99, 100),
#'   close = c(100, 101),
#'   volume = 1000
#' ), csv_path, row.names = FALSE)
#' snapshot <- ledgr_snapshot_from_csv(csv_path)
#' ledgr_snapshot_info(snapshot)
#' ledgr_snapshot_close(snapshot)
#' @export
ledgr_snapshot_from_csv <- function(csv_path,
                                    db_path = NULL,
                                    snapshot_id = NULL) {
  ledgr_validate_snapshot_id(snapshot_id)
  bars_df <- ledgr_read_csv_strict(csv_path, encoding = "UTF-8", strict = TRUE)
  ledgr_snapshot_from_df(bars_df = bars_df, db_path = db_path, snapshot_id = snapshot_id)
}

ledgr_yahoo_extract_bars <- function(x, symbol) {
  df <- as.data.frame(x)
  cols <- names(df)

  open_col <- grep("\\.Open$", cols, value = TRUE)
  high_col <- grep("\\.High$", cols, value = TRUE)
  low_col <- grep("\\.Low$", cols, value = TRUE)
  close_col <- grep("\\.Close$", cols, value = TRUE)
  volume_col <- grep("\\.Volume$", cols, value = TRUE)

  if (length(open_col) != 1 || length(high_col) != 1 || length(low_col) != 1 || length(close_col) != 1) {
    rlang::abort("Yahoo data is missing required OHLC columns.", class = "ledgr_invalid_args")
  }

  idx <- tryCatch(zoo::index(x), error = function(e) NULL)
  if (is.null(idx)) {
    idx <- rownames(df)
  }

  if (length(idx) != nrow(df)) {
    rlang::abort("Yahoo data has invalid time index.", class = "ledgr_invalid_args")
  }

  ts_utc <- vapply(idx, iso_utc, character(1))
  volume <- if (length(volume_col) == 1) df[[volume_col]] else rep(NA_real_, nrow(df))

  data.frame(
    ts_utc = ts_utc,
    instrument_id = rep(symbol, nrow(df)),
    open = as.numeric(df[[open_col]]),
    high = as.numeric(df[[high_col]]),
    low = as.numeric(df[[low_col]]),
    close = as.numeric(df[[close_col]]),
    volume = as.numeric(volume),
    stringsAsFactors = FALSE
  )
}

#' Create a snapshot from Yahoo Finance data (quantmod)
#'
#' Fetches historical data from Yahoo Finance via quantmod and delegates to
#' `ledgr_snapshot_from_df()`.
#'
#' @param symbols Character vector of ticker symbols.
#' @param from Start date (character, Date, or POSIXct).
#' @param to End date (character, Date, or POSIXct).
#' @param db_path Optional DuckDB file path (default: tempfile).
#' @param snapshot_id Optional snapshot id (default: v0.1.1 canonical generation).
#' @param ... Additional arguments passed to `quantmod::getSymbols()`.
#' @return A `ledgr_snapshot` object.
#' @examples
#' if (FALSE) {
#'   # Requires quantmod and network access. Yahoo data can change over time.
#'   snapshot <- ledgr_snapshot_from_yahoo(
#'     symbols = c("AAPL", "MSFT"),
#'     from = "2020-01-01",
#'     to = "2020-02-01"
#'   )
#'   ledgr_snapshot_close(snapshot)
#' }
#' @export
ledgr_snapshot_from_yahoo <- function(symbols,
                                      from,
                                      to,
                                      db_path = NULL,
                                      snapshot_id = NULL,
                                      ...) {
  if (!requireNamespace("quantmod", quietly = TRUE)) {
    rlang::abort(
      "quantmod package required. Install with: install.packages('quantmod')",
      class = "ledgr_missing_dependency"
    )
  }
  if (!is.character(symbols) || length(symbols) < 1 || anyNA(symbols) || any(!nzchar(symbols))) {
    rlang::abort("`symbols` must be a non-empty character vector.", class = "ledgr_invalid_args")
  }

  ledgr_validate_snapshot_id(snapshot_id)

  from_date <- as.Date(iso_utc(from))
  to_date <- as.Date(iso_utc(to))
  if (is.na(from_date) || is.na(to_date)) {
    rlang::abort("`from` and `to` must be valid dates or timestamps.", class = "ledgr_invalid_args")
  }

  bars_list <- lapply(symbols, function(sym) {
    x <- quantmod::getSymbols(
      sym,
      from = from_date,
      to = to_date,
      auto.assign = FALSE,
      ...
    )
    ledgr_yahoo_extract_bars(x, sym)
  })

  bars_df <- do.call(rbind, bars_list)
  ledgr_snapshot_from_df(bars_df = bars_df, db_path = db_path, snapshot_id = snapshot_id)
}

ledgr_validate_snapshot_id <- function(snapshot_id) {
  if (is.null(snapshot_id)) return(invisible(TRUE))
  if (!is.character(snapshot_id) || length(snapshot_id) != 1 || is.na(snapshot_id) || !nzchar(snapshot_id)) {
    rlang::abort("`snapshot_id` must be NULL or a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  pattern <- "^snapshot_[0-9]{8}_[0-9]{6}_[0-9a-f]{4}$"
  if (!grepl(pattern, snapshot_id)) {
    warning(
      "`snapshot_id` does not match 'snapshot_YYYYmmdd_HHMMSS_XXXX'. Using a canonical format improves provenance.",
      call. = FALSE
    )
  }
  invisible(TRUE)
}
