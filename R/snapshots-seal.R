#' Seal a snapshot (v0.1.1)
#'
#' Transitions a snapshot from `CREATED` to `SEALED` and stores a deterministic
#' `snapshot_hash` in a single DuckDB transaction.
#'
#' Snapshot mutability rule: sealing is only allowed while status is `CREATED`.
#' After sealing, snapshot write operations must be rejected by ledgr code paths.
#'
#' @param con A DBI connection to DuckDB.
#' @param snapshot_id Snapshot id (must exist and be status `CREATED`).
#' @return The computed snapshot hash (character(1)).
#' @details
#' Errors:
#' - `LEDGR_SNAPSHOT_NOT_FOUND` if `snapshot_id` does not exist.
#' - `LEDGR_SNAPSHOT_ALREADY_SEALED` if the snapshot is already `SEALED`.
#' - `LEDGR_SNAPSHOT_NOT_MUTABLE` if the snapshot status is not `CREATED`.
#' - `LEDGR_SNAPSHOT_EMPTY` if there are 0 bars or 0 instruments.
#' - `LEDGR_SNAPSHOT_SEAL_FAILED` on hashing/transaction failures (snapshot is marked `FAILED`).
#' @export
ledgr_snapshot_seal <- function(con, snapshot_id) {
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
    rlang::abort("LEDGR_SNAPSHOT_ALREADY_SEALED: snapshot is already SEALED.", class = "LEDGR_SNAPSHOT_ALREADY_SEALED")
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

  hash
}
