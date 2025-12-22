#' Snapshot info (v0.1.1)
#'
#' Returns snapshot metadata plus computed row counts for bars and instruments.
#' This function does not mutate the database.
#'
#' Timestamps are returned as ISO8601 UTC strings with trailing `Z`.
#'
#' @param con A DBI connection to DuckDB or a `ledgr_snapshot`.
#' @param snapshot_id Snapshot id (must exist) when `con` is a connection.
#' @return A 1-row data.frame with:
#'   snapshot_id, status, created_at_utc, sealed_at_utc, snapshot_hash,
#'   bar_count, instrument_count, meta_json, error_msg.
#' @details
#' Errors:
#' - `ledgr_invalid_con` if `con` is not a valid DBI connection.
#' - `ledgr_invalid_args` if `snapshot_id` is not a non-empty character scalar.
#' - `LEDGR_SNAPSHOT_NOT_FOUND` if `snapshot_id` does not exist.
#' @export
ledgr_snapshot_info <- function(con, snapshot_id) {
  if (inherits(con, "ledgr_snapshot")) {
    snapshot_id <- con$snapshot_id
    con <- get_connection(con)
  }
  if (!DBI::dbIsValid(con)) {
    rlang::abort("`con` must be a valid DBI connection.", class = "ledgr_invalid_con")
  }
  if (!is.character(snapshot_id) || length(snapshot_id) != 1 || is.na(snapshot_id) || !nzchar(snapshot_id)) {
    rlang::abort("`snapshot_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }

  df <- DBI::dbGetQuery(
    con,
    "
    SELECT
      s.snapshot_id,
      s.status,
      s.created_at_utc,
      s.sealed_at_utc,
      s.snapshot_hash,
      COALESCE(b.bar_count, 0) AS bar_count,
      COALESCE(i.instrument_count, 0) AS instrument_count,
      s.meta_json,
      s.error_msg
    FROM snapshots s
    LEFT JOIN (
      SELECT snapshot_id, COUNT(*) AS bar_count
      FROM snapshot_bars
      GROUP BY snapshot_id
    ) b
      ON s.snapshot_id = b.snapshot_id
    LEFT JOIN (
      SELECT snapshot_id, COUNT(*) AS instrument_count
      FROM snapshot_instruments
      GROUP BY snapshot_id
    ) i
      ON s.snapshot_id = i.snapshot_id
    WHERE s.snapshot_id = ?
    ",
    params = list(snapshot_id)
  )

  if (nrow(df) != 1) {
    rlang::abort(sprintf("Snapshot not found: %s", snapshot_id), class = "LEDGR_SNAPSHOT_NOT_FOUND")
  }

  df$created_at_utc <- ledgr_normalize_ts_utc(df$created_at_utc[[1]])
  df$sealed_at_utc <- {
    x <- df$sealed_at_utc[[1]]
    if (is.null(x) || (is.atomic(x) && length(x) == 1 && is.na(x))) {
      NA_character_
    } else {
      ledgr_normalize_ts_utc(x)
    }
  }
  df$bar_count <- as.integer(df$bar_count)
  df$instrument_count <- as.integer(df$instrument_count)

  df[, c(
    "snapshot_id",
    "status",
    "created_at_utc",
    "sealed_at_utc",
    "snapshot_hash",
    "bar_count",
    "instrument_count",
    "meta_json",
    "error_msg"
  ), drop = FALSE]
}
