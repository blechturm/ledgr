#' List snapshots (v0.1.1)
#'
#' Returns snapshot metadata plus computed row counts for bars and instruments.
#' This function does not mutate the database.
#'
#' Timestamps are returned as ISO8601 UTC strings with trailing `Z`.
#'
#' @param con A DBI connection to DuckDB or a path to a DuckDB snapshot file.
#'   This function does not accept a `ledgr_snapshot` object; use
#'   `ledgr_snapshot_info(snapshot)` for a single snapshot handle.
#' @param status Optional status filter (NULL for all, or one/more of
#'   `CREATED`, `SEALED`, `FAILED`).
#' @return A tibble with snapshot metadata and counts.
#' @details
#' Errors:
#' - `ledgr_invalid_con` if `con` is not a valid DBI connection.
#' - `ledgr_invalid_args` if `status` is not NULL or contains invalid values.
#'
#' @examples
#' db_path <- tempfile(fileext = ".duckdb")
#' con <- ledgr_db_init(db_path)
#' ledgr_snapshot_create(con, snapshot_id = "snapshot_20200101_000000_abcd")
#' ledgr_snapshot_list(con)
#' ledgr_snapshot_list(db_path)
#' DBI::dbDisconnect(con, shutdown = TRUE)
#' @export
ledgr_snapshot_list <- function(con, status = NULL) {
  if (missing(con)) {
    rlang::abort("`con` must be a DBI connection or DuckDB file path.", class = "ledgr_invalid_args")
  }

  if (is.character(con) && length(con) == 1 && !is.na(con) && nzchar(con)) {
    db_path <- con
    if (identical(db_path, ":memory:")) {
      rlang::abort("`con` cannot be ':memory:' when passed as a path.", class = "ledgr_invalid_args")
    }
    if (!file.exists(db_path)) {
      rlang::abort(sprintf("Snapshot database file does not exist: %s", db_path), class = "LEDGR_SNAPSHOT_DB_NOT_FOUND")
    }
    con <- ledgr_db_init(db_path)
    on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  }

  if (!DBI::dbIsValid(con)) {
    rlang::abort("`con` must be a valid DBI connection or DuckDB file path.", class = "ledgr_invalid_con")
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
    return(tibble::tibble(
      snapshot_id = character(),
      status = character(),
      created_at_utc = character(),
      sealed_at_utc = character(),
      snapshot_hash = character(),
      bar_count = integer(),
      instrument_count = integer(),
      meta_json = character(),
      error_msg = character()
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

  tibble::as_tibble(df)
}

#' Load an existing sealed snapshot
#'
#' Reopens a snapshot that already exists in a DuckDB file. This is the durable
#' research workflow counterpart to `ledgr_snapshot_from_df()`: create and seal a
#' snapshot once, then load it by path and snapshot id in later R sessions.
#'
#' @param db_path Path to an existing DuckDB file.
#' @param snapshot_id Snapshot id to load. The snapshot must exist and be
#'   `SEALED`.
#' @param verify Logical scalar. If `TRUE`, recompute the snapshot hash and
#'   compare it with the stored hash before returning.
#' @return A lazy `ledgr_snapshot` object.
#' @details
#' `ledgr_snapshot_load()` never creates or overwrites snapshots. It only returns
#' a handle to an existing sealed snapshot. Closing the returned object releases
#' its DuckDB connection; it does not delete the database file.
#'
#' @section Articles:
#' Durable experiment stores:
#' `vignette("experiment-store", package = "ledgr")`
#' `system.file("doc", "experiment-store.html", package = "ledgr")`
#'
#' @examples
#' db_path <- tempfile(fileext = ".duckdb")
#' bars <- data.frame(
#'   ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:2,
#'   instrument_id = "AAA",
#'   open = c(100, 101, 102),
#'   high = c(101, 102, 103),
#'   low = c(99, 100, 101),
#'   close = c(100, 101, 102),
#'   volume = 1000
#' )
#' snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
#' snapshot_id <- snapshot$snapshot_id
#' ledgr_snapshot_close(snapshot)
#'
#' snapshot <- ledgr_snapshot_load(db_path, snapshot_id, verify = TRUE)
#' ledgr_snapshot_info(snapshot)
#' ledgr_snapshot_close(snapshot)
#' @export
ledgr_snapshot_load <- function(db_path, snapshot_id = NULL, verify = FALSE) {
  if (!is.character(db_path) || length(db_path) != 1 || is.na(db_path) || !nzchar(db_path)) {
    rlang::abort("`db_path` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (identical(db_path, ":memory:")) {
    rlang::abort("`db_path` cannot be ':memory:' when loading an existing snapshot.", class = "ledgr_invalid_args")
  }
  if (!file.exists(db_path)) {
    rlang::abort(sprintf("Snapshot database file does not exist: %s", db_path), class = "LEDGR_SNAPSHOT_DB_NOT_FOUND")
  }
  if (!is.logical(verify) || length(verify) != 1 || is.na(verify)) {
    rlang::abort("`verify` must be TRUE or FALSE.", class = "ledgr_invalid_args")
  }

  con <- ledgr_db_init(db_path)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  if (is.null(snapshot_id)) {
    snapshots <- ledgr_snapshot_list(con)
    sealed <- snapshots[snapshots$status == "SEALED", , drop = FALSE]
    if (nrow(sealed) == 1L) {
      snapshot_id <- sealed$snapshot_id[[1]]
    } else if (nrow(sealed) == 0L) {
      rlang::abort(
        "No SEALED snapshots found in this DuckDB file. Use ledgr_snapshot_list(db_path) to inspect available snapshots.",
        class = "ledgr_snapshot_not_found"
      )
    } else {
      rlang::abort(
        "Multiple SEALED snapshots found. Supply `snapshot_id`; inspect candidates with ledgr_snapshot_list(db_path).",
        class = "ledgr_snapshot_id_required"
      )
    }
  }
  if (!is.character(snapshot_id) || length(snapshot_id) != 1 || is.na(snapshot_id) || !nzchar(snapshot_id)) {
    rlang::abort("`snapshot_id` must be NULL or a non-empty character scalar.", class = "ledgr_invalid_args")
  }

  info <- ledgr_snapshot_info(con, snapshot_id)
  if (!identical(info$status[[1]], "SEALED")) {
    rlang::abort(
      sprintf("Snapshot '%s' must be SEALED to load; current status is %s.", snapshot_id, info$status[[1]]),
      class = "LEDGR_SNAPSHOT_NOT_SEALED"
    )
  }

  if (isTRUE(verify)) {
    stored_hash <- info$snapshot_hash[[1]]
    if (is.null(stored_hash) || is.na(stored_hash) || !nzchar(stored_hash)) {
      rlang::abort("Snapshot hash missing; snapshot may not be sealed.", class = "ledgr_invalid_snapshot")
    }
    computed_hash <- ledgr_snapshot_hash(con, snapshot_id)
    if (!identical(computed_hash, stored_hash)) {
      rlang::abort("Snapshot hash mismatch; snapshot may be corrupted.", class = "ledgr_invalid_snapshot")
    }
  }

  metadata <- list()
  meta_json <- info$meta_json[[1]]
  if (!is.null(meta_json) && !is.na(meta_json) && nzchar(meta_json)) {
    metadata <- tryCatch(
      jsonlite::fromJSON(meta_json, simplifyVector = FALSE),
      error = function(e) list()
    )
  }
  if (!is.list(metadata)) metadata <- list()

  new_ledgr_snapshot(db_path = db_path, snapshot_id = snapshot_id, metadata = metadata)
}

