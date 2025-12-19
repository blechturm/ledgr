#' List snapshots (v0.1.1)
#'
#' Returns snapshot metadata plus computed row counts for bars and instruments.
#' This function does not mutate the database.
#'
#' Timestamps are returned as ISO8601 UTC strings with trailing `Z`.
#'
#' @param con A DBI connection to DuckDB.
#' @param status Optional status filter (NULL for all, or one/more of
#'   `CREATED`, `SEALED`, `FAILED`).
#' @return A data.frame with snapshot metadata and counts.
#' @details
#' Errors:
#' - `ledgr_invalid_con` if `con` is not a valid DBI connection.
#' - `ledgr_invalid_args` if `status` is not NULL or contains invalid values.
#' @export
ledgr_snapshot_list <- function(con, status = NULL) {
  if (!DBI::dbIsValid(con)) {
    rlang::abort("`con` must be a valid DBI connection.", class = "ledgr_invalid_con")
  }

  allowed <- c("CREATED", "SEALED", "FAILED")
  where_sql <- ""
  params <- list()

  if (!is.null(status)) {
    if (!is.character(status) || length(status) < 1 || anyNA(status) || any(!nzchar(status))) {
      rlang::abort("`status` must be NULL or a non-empty character vector.", class = "ledgr_invalid_args")
    }
    status <- toupper(status)
    bad <- setdiff(unique(status), allowed)
    if (length(bad) > 0) {
      rlang::abort(
        sprintf("Invalid snapshot status filter: %s", paste(bad, collapse = ", ")),
        class = "ledgr_invalid_args"
      )
    }
    placeholders <- paste(rep("?", length(status)), collapse = ", ")
    where_sql <- paste0("WHERE s.status IN (", placeholders, ")")
    params <- as.list(status)
  }

  df <- DBI::dbGetQuery(
    con,
    paste0(
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
      ",
      where_sql,
      "
      ORDER BY s.created_at_utc, s.snapshot_id
      "
    ),
    params = params
  )

  if (nrow(df) == 0) {
    return(data.frame(
      snapshot_id = character(),
      status = character(),
      created_at_utc = character(),
      sealed_at_utc = character(),
      snapshot_hash = character(),
      bar_count = integer(),
      instrument_count = integer(),
      meta_json = character(),
      error_msg = character(),
      stringsAsFactors = FALSE
    ))
  }

  df$created_at_utc <- vapply(df$created_at_utc, ledgr_normalize_ts_utc, character(1))
  df$sealed_at_utc <- vapply(
    df$sealed_at_utc,
    function(x) {
      if (is.null(x) || (is.atomic(x) && length(x) == 1 && is.na(x))) return(NA_character_)
      ledgr_normalize_ts_utc(x)
    },
    character(1)
  )
  df$bar_count <- as.integer(df$bar_count)
  df$instrument_count <- as.integer(df$instrument_count)

  df
}

