#' Seal a snapshot (v0.1.1)
#'
#' Transitions a snapshot from `CREATED` to `SEALED` and stores a deterministic
#' `snapshot_hash` in a single DuckDB transaction.
#'
#' Snapshot mutability rule: sealing is only allowed while status is `CREATED`.
#' After sealing, snapshot write operations must be rejected by ledgr code paths.
#' When basic metadata such as `start_date`, `end_date`, `n_bars`, or
#' `n_instruments` is missing, sealing derives it from the imported snapshot
#' tables. Metadata does not contribute to `snapshot_hash`.
#'
#' @param con A DBI connection to DuckDB or a `ledgr_snapshot`.
#' @param snapshot_id Snapshot id (must exist and be status `CREATED`) when `con` is a connection.
#' @return The computed snapshot hash (character(1)) or a list when called with a snapshot object.
#' @details
#' Errors:
#' - `LEDGR_SNAPSHOT_NOT_FOUND` if `snapshot_id` does not exist.
#' - `LEDGR_SNAPSHOT_ALREADY_SEALED` if the snapshot is already `SEALED`.
#' - `LEDGR_SNAPSHOT_NOT_MUTABLE` if the snapshot status is not `CREATED`.
#' - `LEDGR_SNAPSHOT_EMPTY` if there are 0 bars or 0 instruments.
#' - `LEDGR_SNAPSHOT_REFERENTIAL_INTEGRITY` if bars reference missing instruments.
#' - `LEDGR_SNAPSHOT_OHLC_INVALID` if OHLC bars are internally inconsistent.
#' - `LEDGR_SNAPSHOT_SEAL_FAILED` on hashing/transaction failures (snapshot is marked `FAILED`).
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
#' ledgr_snapshot_seal(con, snapshot_id)
#' DBI::dbDisconnect(con, shutdown = TRUE)
#' @export
ledgr_snapshot_seal <- function(con, snapshot_id) {
  snapshot_obj <- NULL
  if (inherits(con, "ledgr_snapshot")) {
    snapshot_obj <- con
    snapshot_id <- con$snapshot_id
    con <- get_connection(con)
  }
  if (!DBI::dbIsValid(con)) {
    rlang::abort("`con` must be a valid DBI connection.", class = "ledgr_invalid_con")
  }
  if (!is.character(snapshot_id) || length(snapshot_id) != 1 || is.na(snapshot_id) || !nzchar(snapshot_id)) {
    rlang::abort("`snapshot_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }

  snap <- DBI::dbGetQuery(
    con,
    "SELECT status, snapshot_hash, sealed_at_utc FROM snapshots WHERE snapshot_id = ?",
    params = list(snapshot_id)
  )
  if (nrow(snap) != 1) {
    rlang::abort(sprintf("Snapshot not found: %s", snapshot_id), class = "LEDGR_SNAPSHOT_NOT_FOUND")
  }

  status <- snap$status[[1]]
  if (identical(status, "SEALED")) {
    hash <- snap$snapshot_hash[[1]]
    if (!is.character(hash) || length(hash) != 1 || is.na(hash) || !nzchar(hash)) {
      hash <- ledgr_snapshot_hash(con, snapshot_id)
    }
    if (!is.null(snapshot_obj)) {
      snapshot_obj$metadata$snapshot_hash <- hash
      return(invisible(list(hash = hash, snapshot = snapshot_obj)))
    }
    return(hash)
  }
  if (!identical(status, "CREATED")) {
    rlang::abort(
      sprintf("LEDGR_SNAPSHOT_NOT_MUTABLE: snapshot status must be CREATED to seal (got %s).", status),
      class = "LEDGR_SNAPSHOT_NOT_MUTABLE"
    )
  }

  bar_count <- DBI::dbGetQuery(
    con,
    "SELECT COUNT(*) AS n FROM snapshot_bars WHERE snapshot_id = ?",
    params = list(snapshot_id)
  )$n[[1]]
  inst_count <- DBI::dbGetQuery(
    con,
    "SELECT COUNT(*) AS n FROM snapshot_instruments WHERE snapshot_id = ?",
    params = list(snapshot_id)
  )$n[[1]]

  if (isTRUE(bar_count == 0L) || isTRUE(inst_count == 0L)) {
    rlang::abort(
      "LEDGR_SNAPSHOT_EMPTY: snapshot must contain at least one bar and one instrument before sealing.",
      class = "LEDGR_SNAPSHOT_EMPTY"
    )
  }

  ledgr_snapshot_validate_for_seal(con, snapshot_id)
  metadata <- ledgr_snapshot_metadata_for_seal(con, snapshot_id)
  meta_json <- as.character(canonical_json(metadata))

  seal_failed <- function(msg) {
    # Best-effort: mark CREATED snapshot as FAILED with error_msg (no partial seal).
    try(DBI::dbExecute(con, "BEGIN TRANSACTION"), silent = TRUE)
    try(
      DBI::dbExecute(
        con,
        "
        UPDATE snapshots
        SET status = 'FAILED',
            error_msg = ?,
            sealed_at_utc = NULL,
            snapshot_hash = NULL
        WHERE snapshot_id = ?
          AND status = 'CREATED'
        ",
        params = list(msg, snapshot_id)
      ),
      silent = TRUE
    )
    try(DBI::dbExecute(con, "COMMIT"), silent = TRUE)
    invisible(TRUE)
  }

  DBI::dbExecute(con, "BEGIN TRANSACTION")
  on.exit(try(DBI::dbExecute(con, "ROLLBACK"), silent = TRUE), add = TRUE)

  hash <- tryCatch(
    ledgr_snapshot_hash(con, snapshot_id),
    error = function(e) {
      msg <- sprintf("LEDGR_SNAPSHOT_SEAL_FAILED: %s", conditionMessage(e))
      try(DBI::dbExecute(con, "ROLLBACK"), silent = TRUE)
      seal_failed(msg)
      rlang::abort(msg, class = "LEDGR_SNAPSHOT_SEAL_FAILED")
    }
  )

  sealed_at_iso <- format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

  DBI::dbExecute(
    con,
    "
    UPDATE snapshots
    SET status = 'SEALED',
        sealed_at_utc = CAST(? AS TIMESTAMP),
        snapshot_hash = ?,
        meta_json = ?,
        error_msg = NULL
    WHERE snapshot_id = ?
      AND status = 'CREATED'
    ",
    params = list(sealed_at_iso, hash, meta_json, snapshot_id)
  )

  check <- DBI::dbGetQuery(
    con,
    "SELECT status, sealed_at_utc, snapshot_hash FROM snapshots WHERE snapshot_id = ?",
    params = list(snapshot_id)
  )
  if (nrow(check) != 1 || !identical(check$status[[1]], "SEALED") || !identical(check$snapshot_hash[[1]], hash) || is.na(check$sealed_at_utc[[1]])) {
    msg <- "LEDGR_SNAPSHOT_SEAL_FAILED: snapshot did not transition to SEALED as expected."
    try(DBI::dbExecute(con, "ROLLBACK"), silent = TRUE)
    seal_failed(msg)
    rlang::abort(msg, class = "LEDGR_SNAPSHOT_SEAL_FAILED")
  }

  DBI::dbExecute(con, "COMMIT")
  on.exit(NULL, add = FALSE)
  ledgr_checkpoint_duckdb(con, strict = TRUE)

  if (!is.null(snapshot_obj)) {
    snapshot_obj$metadata <- metadata
    snapshot_obj$metadata$snapshot_hash <- hash
    return(invisible(list(hash = hash, snapshot = snapshot_obj)))
  }

  hash
}

ledgr_snapshot_metadata_for_seal <- function(con, snapshot_id) {
  raw <- DBI::dbGetQuery(
    con,
    "SELECT meta_json FROM snapshots WHERE snapshot_id = ?",
    params = list(snapshot_id)
  )$meta_json[[1]]

  metadata <- list()
  if (is.character(raw) && length(raw) == 1L && !is.na(raw) && nzchar(raw)) {
    metadata <- tryCatch(
      jsonlite::fromJSON(raw, simplifyVector = FALSE),
      error = function(e) list()
    )
    if (!is.list(metadata) || is.data.frame(metadata)) {
      metadata <- list()
    }
  }

  bar_stats <- DBI::dbGetQuery(
    con,
    "
    SELECT
      COUNT(*) AS n_bars,
      MIN(ts_utc) AS start_date,
      MAX(ts_utc) AS end_date
    FROM snapshot_bars
    WHERE snapshot_id = ?
    ",
    params = list(snapshot_id)
  )
  instrument_count <- DBI::dbGetQuery(
    con,
    "SELECT COUNT(*) AS n_instruments FROM snapshot_instruments WHERE snapshot_id = ?",
    params = list(snapshot_id)
  )$n_instruments[[1]]

  put_if_missing <- function(x, name, value) {
    existing <- x[[name]]
    missing <- is.null(existing) ||
      length(existing) == 0L ||
      (length(existing) == 1L && is.atomic(existing) && is.na(existing)) ||
      (is.character(existing) && length(existing) == 1L && !nzchar(existing))
    if (isTRUE(missing)) {
      x[[name]] <- value
    }
    x
  }

  metadata <- put_if_missing(metadata, "n_bars", as.integer(bar_stats$n_bars[[1]]))
  metadata <- put_if_missing(metadata, "n_instruments", as.integer(instrument_count))
  metadata <- put_if_missing(metadata, "start_date", ledgr_normalize_ts_utc(bar_stats$start_date[[1]]))
  metadata <- put_if_missing(metadata, "end_date", ledgr_normalize_ts_utc(bar_stats$end_date[[1]]))

  metadata
}

ledgr_snapshot_validate_for_seal <- function(con, snapshot_id) {
  missing_inst <- DBI::dbGetQuery(
    con,
    "
    SELECT DISTINCT b.instrument_id
    FROM snapshot_bars b
    LEFT JOIN snapshot_instruments i
      ON i.snapshot_id = b.snapshot_id
     AND i.instrument_id = b.instrument_id
    WHERE b.snapshot_id = ?
      AND i.instrument_id IS NULL
    ORDER BY b.instrument_id
    ",
    params = list(snapshot_id)
  )$instrument_id

  if (length(missing_inst) > 0) {
    rlang::abort(
      sprintf(
        "LEDGR_SNAPSHOT_REFERENTIAL_INTEGRITY: snapshot_bars references instruments absent from snapshot_instruments: %s",
        paste(missing_inst, collapse = ", ")
      ),
      class = "LEDGR_SNAPSHOT_REFERENTIAL_INTEGRITY"
    )
  }

  bad_ohlc <- DBI::dbGetQuery(
    con,
    "
    SELECT instrument_id, ts_utc
    FROM snapshot_bars
    WHERE snapshot_id = ?
      AND NOT (
        high >= open
        AND high >= low
        AND high >= close
        AND low <= open
        AND low <= high
        AND low <= close
      )
    ORDER BY instrument_id, ts_utc
    LIMIT 5
    ",
    params = list(snapshot_id)
  )

  if (nrow(bad_ohlc) > 0) {
    examples <- paste(
      paste0(
        bad_ohlc$instrument_id,
        "@",
        format(as.POSIXct(bad_ohlc$ts_utc, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
      ),
      collapse = ", "
    )
    rlang::abort(
      sprintf("LEDGR_SNAPSHOT_OHLC_INVALID: snapshot_bars contains invalid OHLC rows: %s", examples),
      class = "LEDGR_SNAPSHOT_OHLC_INVALID"
    )
  }

  invisible(TRUE)
}
