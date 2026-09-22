# Fill a CREATED snapshot with bars and instruments directly.
#
# The connection-first CSV import lifecycle (ledgr_snapshot_import_bars_csv,
# ledgr_snapshot_import_instruments_csv) was removed in v0.2.0.2 cut 3 under
# LDG-2787. Seal, hash and info tests still need an unsealed snapshot that
# already carries data, and they test the seal, not the import, so they build
# one here rather than through a public ingestion surface. This writes the
# canonical columns a sealed snapshot holds: ts_utc as POSIXct UTC, OHLCV
# rounded to eight decimals, and instruments generated from the bars when none
# are supplied, matching what the removed importer persisted.
ledgr_test_fill_snapshot <- function(con, snapshot_id, bars, instruments = NULL) {
  instrument_id <- as.character(bars$instrument_id)

  ts_raw <- bars$ts_utc
  ts_utc <- if (inherits(ts_raw, "POSIXt")) {
    as.POSIXct(ts_raw, tz = "UTC")
  } else if (inherits(ts_raw, "Date")) {
    as.POSIXct(ts_raw, tz = "UTC")
  } else {
    as.POSIXct(as.character(ts_raw), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
  }
  if (anyNA(ts_utc)) {
    stop("ledgr_test_fill_snapshot: unparseable ts_utc in the supplied bars.")
  }

  num <- function(x) round(as.numeric(x), digits = 8L)

  if (is.null(instruments)) {
    ids <- sort(unique(instrument_id))
    instruments <- data.frame(
      instrument_id = ids,
      symbol = ids,
      currency = "USD",
      asset_class = "EQUITY",
      multiplier = 1,
      tick_size = 0.01,
      stringsAsFactors = FALSE
    )
  }

  inst_out <- data.frame(
    snapshot_id = rep(snapshot_id, nrow(instruments)),
    instrument_id = as.character(instruments$instrument_id),
    symbol = as.character(instruments$symbol),
    currency = as.character(instruments$currency),
    asset_class = as.character(instruments$asset_class),
    multiplier = as.numeric(instruments$multiplier),
    tick_size = as.numeric(instruments$tick_size),
    meta_json = NA_character_,
    stringsAsFactors = FALSE
  )
  DBI::dbAppendTable(con, "snapshot_instruments", inst_out)

  bars_out <- data.frame(
    snapshot_id = rep(snapshot_id, length(instrument_id)),
    instrument_id = instrument_id,
    ts_utc = ts_utc,
    open = num(bars$open),
    high = num(bars$high),
    low = num(bars$low),
    close = num(bars$close),
    volume = if ("volume" %in% names(bars)) num(bars$volume) else NA_real_,
    stringsAsFactors = FALSE
  )
  bars_out <- bars_out[order(bars_out$instrument_id, bars_out$ts_utc), , drop = FALSE]
  DBI::dbAppendTable(con, "snapshot_bars", bars_out)

  invisible(TRUE)
}
