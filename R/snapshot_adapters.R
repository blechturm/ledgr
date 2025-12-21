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
#' @export
ledgr_snapshot_from_df <- function(bars_df,
                                   instruments_df = NULL,
                                   db_path = NULL,
                                   snapshot_id = NULL) {
  if (!is.data.frame(bars_df)) {
    rlang::abort("`bars_df` must be a data.frame (or tibble).", class = "ledgr_invalid_args")
  }

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

  ts_utc <- vapply(bars_df$ts_utc, iso_utc, character(1))

  open <- suppressWarnings(as.numeric(bars_df$open))
  high <- suppressWarnings(as.numeric(bars_df$high))
  low <- suppressWarnings(as.numeric(bars_df$low))
  close <- suppressWarnings(as.numeric(bars_df$close))
  if (anyNA(open) || anyNA(high) || anyNA(low) || anyNA(close)) {
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

  max_ohlc <- pmax(open, close, low, na.rm = TRUE)
  min_ohlc <- pmin(open, close, high, na.rm = TRUE)
  if (any(high < max_ohlc) || any(low > min_ohlc)) {
    rlang::abort("bars_df contains an OHLC violation (high/low bounds).", class = "ledgr_invalid_args")
  }

  key <- paste0(instrument_id, "\n", ts_utc)
  if (anyDuplicated(key)) {
    rlang::abort("bars_df contains duplicate (instrument_id, ts_utc) rows.", class = "ledgr_invalid_args")
  }

  ord <- order(instrument_id, ts_utc)
  bars_out <- data.frame(
    instrument_id = instrument_id[ord],
    ts_utc = ts_utc[ord],
    open = open[ord],
    high = high[ord],
    low = low[ord],
    close = close[ord],
    volume = volume[ord],
    stringsAsFactors = FALSE
  )

  if (is.null(db_path)) {
    db_path <- tempfile(pattern = "ledgr_", fileext = ".duckdb")
  }
  if (!is.character(db_path) || length(db_path) != 1 || is.na(db_path) || !nzchar(db_path)) {
    rlang::abort("`db_path` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }

  bars_csv_path <- tempfile(fileext = ".csv")
  on.exit(unlink(bars_csv_path), add = TRUE)
  utils::write.csv(bars_out, bars_csv_path, row.names = FALSE)

  instruments_csv_path <- NULL
  meta_updates <- NULL
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

    if (anyNA(multiplier) || any(!is.finite(multiplier))) {
      rlang::abort("instruments_df `multiplier` must be finite when provided.", class = "ledgr_invalid_args")
    }
    if (anyNA(tick_size) || any(!is.finite(tick_size))) {
      rlang::abort("instruments_df `tick_size` must be finite when provided.", class = "ledgr_invalid_args")
    }

    inst_out <- data.frame(
      instrument_id = inst_id,
      symbol = symbol,
      currency = currency,
      asset_class = asset_class,
      multiplier = multiplier,
      tick_size = tick_size,
      stringsAsFactors = FALSE
    )

    instruments_csv_path <- tempfile(fileext = ".csv")
    on.exit(unlink(instruments_csv_path), add = TRUE)
    utils::write.csv(inst_out, instruments_csv_path, row.names = FALSE)

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

  con <- ledgr_db_init(db_path)
  drv <- attr(con, "ledgr_duckdb_drv")

  snapshot_id <- ledgr_snapshot_create(con, snapshot_id = snapshot_id)

  ledgr_snapshot_import_bars_csv(
    con = con,
    snapshot_id = snapshot_id,
    bars_csv_path = bars_csv_path,
    instruments_csv_path = instruments_csv_path,
    auto_generate_instruments = is.null(instruments_df)
  )

  if (!is.null(meta_updates)) {
    for (i in seq_along(meta_updates)) {
      if (!is.na(meta_updates[[i]]) && nzchar(meta_updates[[i]])) {
        DBI::dbExecute(
          con,
          "UPDATE snapshot_instruments SET meta_json = ? WHERE snapshot_id = ? AND instrument_id = ?",
          params = list(meta_updates[[i]], snapshot_id, inst_id[[i]])
        )
      }
    }
  }

  ledgr_snapshot_seal(con, snapshot_id)

  info <- ledgr_snapshot_info(con, snapshot_id)
  range <- DBI::dbGetQuery(
    con,
    "SELECT MIN(ts_utc) AS start_date, MAX(ts_utc) AS end_date FROM snapshot_bars WHERE snapshot_id = ?",
    params = list(snapshot_id)
  )

  start_date <- if (nrow(range) == 1 && !is.na(range$start_date[[1]])) {
    ledgr_normalize_ts_utc(range$start_date[[1]])
  } else {
    NA_character_
  }
  end_date <- if (nrow(range) == 1 && !is.na(range$end_date[[1]])) {
    ledgr_normalize_ts_utc(range$end_date[[1]])
  } else {
    NA_character_
  }

  metadata <- list(
    n_bars = as.integer(info$bar_count[[1]]),
    n_instruments = as.integer(info$instrument_count[[1]]),
    start_date = start_date,
    end_date = end_date,
    created_at = info$created_at_utc[[1]]
  )

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
#' @export
ledgr_snapshot_from_csv <- function(csv_path,
                                    db_path = NULL,
                                    snapshot_id = NULL) {
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
