#' Create a snapshot (v0.1.1)
#'
#' Creates a row in `snapshots` with status `CREATED`. Does not import any data.
#'
#' If `snapshot_id` is `NULL`, generates an id of the form
#' `snapshot_{YYYYmmdd_HHMMSS}_{4-hex}` (spec v0.1.1 §3.1).
#'
#' @param con A DBI connection to DuckDB.
#' @param snapshot_id Optional snapshot identifier.
#' @param meta Optional JSON-safe metadata list (stored as canonical JSON).
#' @return The snapshot_id (character(1)).
#' @export
ledgr_snapshot_create <- function(con, snapshot_id = NULL, meta = NULL) {
  if (!DBI::dbIsValid(con)) {
    rlang::abort("`con` must be a valid DBI connection.", class = "ledgr_invalid_con")
  }

  if (!is.null(snapshot_id)) {
    if (!is.character(snapshot_id) || length(snapshot_id) != 1 || is.na(snapshot_id) || !nzchar(snapshot_id)) {
      rlang::abort("`snapshot_id` must be NULL or a non-empty character scalar.", class = "ledgr_invalid_args")
    }
  }

  if (is.null(meta)) meta <- list()
  meta_json <- canonical_json(meta)

  created_at_iso <- format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  created_at_ts <- as.POSIXct(created_at_iso, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")

  if (is.null(snapshot_id)) {
    snapshot_id <- ledgr_snapshot_id_generate(created_at_iso)
  }

  exists <- DBI::dbGetQuery(
    con,
    "SELECT COUNT(*) AS n FROM snapshots WHERE snapshot_id = ?",
    params = list(snapshot_id)
  )$n[[1]] > 0
  if (isTRUE(exists)) {
    rlang::abort(
      sprintf("snapshot_id already exists: %s", snapshot_id),
      class = "ledgr_snapshot_exists"
    )
  }

  DBI::dbExecute(
    con,
    "
    INSERT INTO snapshots (
      snapshot_id,
      status,
      created_at_utc,
      sealed_at_utc,
      snapshot_hash,
      meta_json,
      error_msg
    ) VALUES (?, 'CREATED', ?, NULL, NULL, ?, NULL)
    ",
    params = list(snapshot_id, created_at_ts, meta_json)
  )

  snapshot_id
}

ledgr_snapshot_id_generate <- function(created_at_iso) {
  if (!is.character(created_at_iso) || length(created_at_iso) != 1 || is.na(created_at_iso) || !nzchar(created_at_iso)) {
    rlang::abort("Internal error: created_at_iso must be a non-empty character scalar.", class = "ledgr_internal_error")
  }

  ts <- gsub("[-:]", "", sub("^([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})Z$", "\\1\\2\\3_\\4\\5\\6", created_at_iso))

  env <- ledgr_snapshot_id_state_env()
  env$counter <- env$counter + 1L

  suffix <- substr(
    digest::digest(paste0(created_at_iso, ":", Sys.getpid(), ":", env$counter), algo = "sha256"),
    1,
    4
  )

  paste0("snapshot_", ts, "_", suffix)
}

ledgr_snapshot_id_state_env <- local({
  e <- new.env(parent = emptyenv())
  e$counter <- 0L
  function() e
})

