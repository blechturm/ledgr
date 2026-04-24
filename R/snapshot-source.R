ledgr_db_path_key <- function(path) {
  if (is.null(path)) return(NULL)
  if (!is.character(path) || length(path) != 1 || is.na(path) || !nzchar(path)) {
    rlang::abort("Database paths must be non-empty character scalars.", class = "ledgr_invalid_args")
  }
  if (identical(path, ":memory:")) return(path)
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

ledgr_same_db_path <- function(a, b) {
  identical(ledgr_db_path_key(a), ledgr_db_path_key(b))
}

ledgr_snapshot_db_path_from_config <- function(cfg, default_db_path) {
  snapshot_db_path <- NULL
  if (!is.null(cfg$data) && is.list(cfg$data)) {
    snapshot_db_path <- cfg$data$snapshot_db_path
  }
  if (is.null(snapshot_db_path)) snapshot_db_path <- default_db_path
  snapshot_db_path
}

ledgr_prepare_snapshot_source_tables <- function(con, snapshot_db_path, run_db_path) {
  if (!DBI::dbIsValid(con)) {
    rlang::abort("`con` must be a valid DBI connection.", class = "ledgr_invalid_con")
  }
  if (ledgr_same_db_path(snapshot_db_path, run_db_path)) {
    return(FALSE)
  }
  if (identical(ledgr_db_path_key(snapshot_db_path), ":memory:")) {
    rlang::abort(
      "Cannot use an in-memory snapshot database as a separate run database source.",
      class = "ledgr_invalid_config"
    )
  }

  try(DBI::dbExecute(con, "DROP VIEW IF EXISTS temp.instruments"), silent = TRUE)
  try(DBI::dbExecute(con, "DROP VIEW IF EXISTS temp.bars"), silent = TRUE)
  try(DBI::dbExecute(con, "DROP VIEW IF EXISTS temp.snapshots"), silent = TRUE)
  try(DBI::dbExecute(con, "DROP VIEW IF EXISTS temp.snapshot_instruments"), silent = TRUE)
  try(DBI::dbExecute(con, "DROP VIEW IF EXISTS temp.snapshot_bars"), silent = TRUE)
  try(DBI::dbExecute(con, "DETACH ledgr_snapshot_src"), silent = TRUE)

  snapshot_path_sql <- DBI::dbQuoteString(con, ledgr_db_path_key(snapshot_db_path))
  DBI::dbExecute(con, paste0("ATTACH ", snapshot_path_sql, " AS ledgr_snapshot_src (READ_ONLY)"))
  DBI::dbExecute(con, "CREATE TEMP VIEW snapshots AS SELECT * FROM ledgr_snapshot_src.snapshots")
  DBI::dbExecute(con, "CREATE TEMP VIEW snapshot_instruments AS SELECT * FROM ledgr_snapshot_src.snapshot_instruments")
  DBI::dbExecute(con, "CREATE TEMP VIEW snapshot_bars AS SELECT * FROM ledgr_snapshot_src.snapshot_bars")

  TRUE
}

ledgr_prepare_snapshot_runtime_views <- function(con,
                                                 snapshot_id,
                                                 instrument_ids,
                                                 start_ts_utc,
                                                 end_ts_utc) {
  if (!DBI::dbIsValid(con)) {
    rlang::abort("`con` must be a valid DBI connection.", class = "ledgr_invalid_con")
  }
  if (!is.character(snapshot_id) || length(snapshot_id) != 1 || is.na(snapshot_id) || !nzchar(snapshot_id)) {
    rlang::abort("`snapshot_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (!is.character(instrument_ids) || length(instrument_ids) < 1 || anyNA(instrument_ids) || any(!nzchar(instrument_ids))) {
    rlang::abort("`instrument_ids` must be a non-empty character vector.", class = "ledgr_invalid_args")
  }

  start_iso <- ledgr_normalize_ts_utc(start_ts_utc)
  end_iso <- ledgr_normalize_ts_utc(end_ts_utc)
  start_str <- sub("Z$", "", sub("T", " ", start_iso))
  end_str <- sub("Z$", "", sub("T", " ", end_iso))
  ids_sql <- paste(DBI::dbQuoteString(con, instrument_ids), collapse = ", ")
  snapshot_sql <- DBI::dbQuoteString(con, snapshot_id)

  try(DBI::dbExecute(con, "DROP VIEW IF EXISTS temp.instruments"), silent = TRUE)
  try(DBI::dbExecute(con, "DROP VIEW IF EXISTS temp.bars"), silent = TRUE)

  DBI::dbExecute(
    con,
    paste0(
      "CREATE TEMP VIEW instruments AS ",
      "SELECT instrument_id, symbol, currency, asset_class ",
      "FROM snapshot_instruments ",
      "WHERE snapshot_id = ", snapshot_sql, " ",
      "AND instrument_id IN (", ids_sql, ")"
    )
  )
  DBI::dbExecute(
    con,
    paste0(
      "CREATE TEMP VIEW bars AS ",
      "SELECT instrument_id, ts_utc, open, high, low, close, volume, ",
      "CAST('NONE' AS TEXT) AS gap_type, CAST(FALSE AS BOOLEAN) AS is_synthetic ",
      "FROM snapshot_bars ",
      "WHERE snapshot_id = ", snapshot_sql, " ",
      "AND instrument_id IN (", ids_sql, ") ",
      "AND ts_utc >= CAST(", DBI::dbQuoteString(con, start_str), " AS TIMESTAMP) ",
      "AND ts_utc <= CAST(", DBI::dbQuoteString(con, end_str), " AS TIMESTAMP)"
    )
  )

  invisible(TRUE)
}
