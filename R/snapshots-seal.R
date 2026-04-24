#' Seal a snapshot (v0.1.1)
#'
#' Transitions a snapshot from `CREATED` to `SEALED` and stores a deterministic
#' `snapshot_hash` in a single DuckDB transaction.
#'
#' Snapshot mutability rule: sealing is only allowed while status is `CREATED`.
#' After sealing, snapshot write operations must be rejected by ledgr code paths.
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
        error_msg = NULL
    WHERE snapshot_id = ?
      AND status = 'CREATED'
    ",
    params = list(sealed_at_iso, hash, snapshot_id)
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

  if (!is.null(snapshot_obj)) {
    snapshot_obj$metadata$snapshot_hash <- hash
    return(invisible(list(hash = hash, snapshot = snapshot_obj)))
  }

  hash
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
