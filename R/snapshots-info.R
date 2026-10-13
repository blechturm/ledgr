#' Snapshot info
#'
#' Returns snapshot metadata plus computed row counts for bars and instruments.
#' This function does not mutate the database.
#'
#' Timestamps are returned as ISO8601 UTC strings with trailing `Z`.
#' Call it as `ledgr_snapshot_info(snapshot)` for a `ledgr_snapshot` handle, or
#' as `ledgr_snapshot_info(con, snapshot_id)` for a raw DuckDB connection.
#'
#' @param con A DBI connection to DuckDB or a `ledgr_snapshot`.
#' @param snapshot_id Snapshot id (must exist) when `con` is a connection.
#' @return A 1-row tibble with:
#'   snapshot_id, status, created_at_utc, sealed_at_utc, snapshot_hash,
#'   hash_rule_version, verified_in_process,
#'   bar_count, instrument_count, off_session_bar_count, start_date, end_date,
#'   meta_json, error_msg.
#'
#' `bar_count` and `instrument_count` are live counts from the snapshot tables.
#' `off_session_bar_count` counts sealed bars that fall on no declared
#' open-session close; they are never a pulse of an availability-aware run, and
#' [ledgr_snapshot_quarantine()] lists them with reason `off_session_bar`.
#' `start_date` and `end_date` are parsed from seal metadata when present.
#' `meta_json` remains available as the raw envelope metadata written on the
#' snapshot row. Seal-time metadata inside `meta_json` may use `n_bars` and
#' `n_instruments`; the public columns are `bar_count` and
#' `instrument_count`. Metadata is not part of `snapshot_hash`.
#' `verified_in_process` is `TRUE` only when the current process holds the
#' exact snapshot-store, snapshot-id, stored-root, and rule tuple in its private
#' PID-bound verified set. Reading metadata does not establish that proof, and
#' the value is never persisted or serialized.
#' @details
#' Errors:
#' - `ledgr_invalid_con` if `con` is not a valid DBI connection.
#' - `ledgr_invalid_args` if `snapshot_id` is not a non-empty character scalar.
#' - `LEDGR_SNAPSHOT_NOT_FOUND` if `snapshot_id` does not exist.
#'
#' @section Articles:
#' Durable experiment stores:
#' `vignette("experiment-store", package = "ledgr")`
#' `system.file("doc", "experiment-store.html", package = "ledgr")`
#'
#' @examples
#' bars <- ledgr_sim_bars(n_instruments = 1, n_days = 3, seed = 1)
#' snapshot <- ledgr_snapshot_from_df(bars)
#' ledgr_snapshot_info(snapshot)
#' ledgr_snapshot_close(snapshot)
#'
#' db_path <- tempfile(fileext = ".duckdb")
#' con <- ledgr_db_init(db_path)
#' snapshot_id <- ledgr_snapshot_create(
#'   con,
#'   snapshot_id = "snapshot_20200101_000000_abcd"
#' )
#' ledgr_snapshot_info(con, snapshot_id)
#' DBI::dbDisconnect(con, shutdown = TRUE)
#' @export
ledgr_snapshot_info <- function(con, snapshot_id) {
  store_key <- NULL
  if (inherits(con, "ledgr_snapshot")) {
    store_key <- ledgr_store_key(con$db_path)
    snapshot_id <- con$snapshot_id
    release <- ledgr_snapshot_hold(con)
    on.exit(release(), add = TRUE)
    con <- get_connection(con)
  } else {
    store_key <- ledgr_snapshot_connection_store_key(con)
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
      s.hash_rule_version,
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
  df$hash_rule_version <- as.integer(df$hash_rule_version)
  df$verified_in_process <- ledgr_snapshot_verified_contains(
    store_key,
    snapshot_id,
    df$snapshot_hash[[1L]],
    df$hash_rule_version[[1L]]
  )
  df$off_session_bar_count <- if (ledgr_experiment_store_table_exists(con, "snapshot_observation_quarantine")) {
    as.integer(DBI::dbGetQuery(
      con,
      "SELECT COUNT(*) AS n FROM snapshot_observation_quarantine WHERE snapshot_id = ? AND reason = ?",
      params = list(snapshot_id, ledgr_off_session_reason)
    )$n[[1L]])
  } else {
    0L
  }
  metadata <- ledgr_snapshot_info_parse_meta(df$meta_json[[1]])
  df$start_date <- ledgr_snapshot_info_meta_chr(metadata, "start_date")
  df$end_date <- ledgr_snapshot_info_meta_chr(metadata, "end_date")

  tibble::as_tibble(df[, c(
    "snapshot_id",
    "status",
    "created_at_utc",
    "sealed_at_utc",
    "snapshot_hash",
    "hash_rule_version",
    "verified_in_process",
    "bar_count",
    "instrument_count",
    "off_session_bar_count",
    "start_date",
    "end_date",
    "meta_json",
    "error_msg"
  ), drop = FALSE])
}

ledgr_snapshot_info_parse_meta <- function(meta_json) {
  if (is.null(meta_json) || length(meta_json) != 1L || is.na(meta_json) || !nzchar(meta_json)) {
    return(list())
  }
  out <- tryCatch(
    ledgr_json_read_nested(meta_json),
    error = function(e) list()
  )
  if (!is.list(out)) list() else out
}

ledgr_snapshot_info_meta_chr <- function(metadata, field) {
  value <- metadata[[field]]
  if (is.null(value) || length(value) != 1L || is.na(value) || !nzchar(as.character(value))) {
    return(NA_character_)
  }
  as.character(value)
}

# The first and last sealed bar timestamps inside [start, end] (UTC), one
# aggregate over snapshot_bars (a few ms at Sharadar scale); NA when the range holds no bar.
ledgr_snapshot_bar_range <- function(con, snapshot_id, start_ts_utc, end_ts_utc) {
  as_utc <- function(x) as.POSIXct(ledgr_normalize_ts_utc(x), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
  out <- DBI::dbGetQuery(
    con,
    "SELECT MIN(ts_utc) AS first, MAX(ts_utc) AS last FROM snapshot_bars WHERE snapshot_id = ? AND ts_utc >= ? AND ts_utc <= ?",
    params = list(snapshot_id, as_utc(start_ts_utc), as_utc(end_ts_utc))
  )
  list(first = as.POSIXct(out$first[[1L]], tz = "UTC"), last = as.POSIXct(out$last[[1L]], tz = "UTC"))
}
