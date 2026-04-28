ledgr_run_tags_normalize <- function(tags, arg = "tags", allow_null = FALSE) {
  if (is.null(tags)) {
    if (isTRUE(allow_null)) {
      return(NULL)
    }
    rlang::abort(sprintf("`%s` must be a character vector of tags.", arg), class = "ledgr_invalid_args")
  }
  if (!is.character(tags) || any(is.na(tags))) {
    rlang::abort(sprintf("`%s` must be a character vector of non-missing tags.", arg), class = "ledgr_invalid_args")
  }
  if (length(tags) == 0L) {
    rlang::abort(sprintf("`%s` must contain at least one tag.", arg), class = "ledgr_invalid_args")
  }
  tags <- trimws(tags)
  if (any(!nzchar(tags))) {
    rlang::abort(sprintf("`%s` must not contain empty tags.", arg), class = "ledgr_invalid_args")
  }
  if (any(grepl("[,\r\n\t]", tags))) {
    rlang::abort(sprintf("`%s` tags must not contain commas or control characters.", arg), class = "ledgr_invalid_args")
  }
  unique(tags)
}

ledgr_run_tags_empty <- function() {
  tibble::tibble(
    run_id = character(),
    tag = character(),
    created_at_utc = character()
  )
}

#' Add tags to a stored run
#'
#' Adds mutable metadata tags to a run in a ledgr experiment store. Tags do not
#' alter run identity hashes, stored artifacts, comparison semantics, or
#' strategy provenance. Re-adding an existing tag is idempotent.
#'
#' @param db_path Path to a DuckDB experiment-store file.
#' @param run_id Run identifier.
#' @param tags Character vector of tags. Tags are trimmed, deduplicated, and
#'   must not contain commas or control characters.
#' @return A `ledgr_run_info` object after the update.
#' @examples
#' db_path <- tempfile(fileext = ".duckdb")
#' bars <- data.frame(
#'   ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:3,
#'   instrument_id = "AAA",
#'   open = c(100, 101, 102, 103),
#'   high = c(101, 102, 103, 104),
#'   low = c(99, 100, 101, 102),
#'   close = c(100, 101, 102, 103),
#'   volume = 1000
#' )
#' strategy <- function(ctx) ctx$targets()
#' bt <- ledgr_backtest(data = bars, strategy = strategy, db_path = db_path)
#' ledgr_run_tag(db_path, bt$run_id, c("baseline", "demo"))
#' ledgr_run_tags(db_path, bt$run_id)
#' close(bt)
#' @export
ledgr_run_tag <- function(db_path, run_id, tags) {
  if (!is.character(run_id) || length(run_id) != 1L || is.na(run_id) || !nzchar(run_id)) {
    rlang::abort("`run_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  tags <- ledgr_run_tags_normalize(tags)

  opened <- ledgr_run_store_open(db_path)
  on.exit(ledgr_run_store_close(opened), add = TRUE)
  ledgr_experiment_store_check_schema(opened$con, write = TRUE, inform = TRUE)
  ledgr_run_store_assert_run_exists(opened$con, run_id)

  created_at <- as.POSIXct(Sys.time(), tz = "UTC")
  for (tag in tags) {
    DBI::dbExecute(
      opened$con,
      "
      INSERT INTO run_tags (run_id, tag, created_at_utc)
      VALUES (?, ?, ?)
      ON CONFLICT DO NOTHING
      ",
      params = list(run_id, tag, created_at)
    )
  }

  row <- ledgr_run_store_fetch(opened$con, include_archived = TRUE, run_id = run_id)
  ledgr_run_info_from_row(row, db_path)
}

#' Remove tags from a stored run
#'
#' Removes mutable metadata tags from a run. If `tags = NULL`, all tags for the
#' run are removed. Removing absent tags is idempotent.
#'
#' @param db_path Path to a DuckDB experiment-store file.
#' @param run_id Run identifier.
#' @param tags Character vector of tags to remove, or `NULL` to remove all tags
#'   from the run. Use `NULL` for "all tags"; `character(0)` is treated as an
#'   invalid empty tag set.
#' @return A `ledgr_run_info` object after the update.
#' @examples
#' db_path <- tempfile(fileext = ".duckdb")
#' bars <- data.frame(
#'   ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:3,
#'   instrument_id = "AAA",
#'   open = c(100, 101, 102, 103),
#'   high = c(101, 102, 103, 104),
#'   low = c(99, 100, 101, 102),
#'   close = c(100, 101, 102, 103),
#'   volume = 1000
#' )
#' strategy <- function(ctx) ctx$targets()
#' bt <- ledgr_backtest(data = bars, strategy = strategy, db_path = db_path)
#' ledgr_run_tag(db_path, bt$run_id, c("baseline", "demo"))
#' ledgr_run_untag(db_path, bt$run_id, "demo")
#' close(bt)
#' @export
ledgr_run_untag <- function(db_path, run_id, tags = NULL) {
  if (!is.character(run_id) || length(run_id) != 1L || is.na(run_id) || !nzchar(run_id)) {
    rlang::abort("`run_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  tags <- ledgr_run_tags_normalize(tags, allow_null = TRUE)

  opened <- ledgr_run_store_open(db_path)
  on.exit(ledgr_run_store_close(opened), add = TRUE)
  ledgr_experiment_store_check_schema(opened$con, write = TRUE, inform = TRUE)
  ledgr_run_store_assert_run_exists(opened$con, run_id)

  if (is.null(tags)) {
    DBI::dbExecute(opened$con, "DELETE FROM run_tags WHERE run_id = ?", params = list(run_id))
  } else {
    for (tag in tags) {
      DBI::dbExecute(
        opened$con,
        "DELETE FROM run_tags WHERE run_id = ? AND tag = ?",
        params = list(run_id, tag)
      )
    }
  }

  row <- ledgr_run_store_fetch(opened$con, include_archived = TRUE, run_id = run_id)
  ledgr_run_info_from_row(row, db_path)
}

#' List run tags
#'
#' Lists mutable run tags stored in a ledgr experiment store. This is a
#' read-only operation and does not migrate legacy stores.
#'
#' @param db_path Path to a DuckDB experiment-store file.
#' @param run_id Optional run identifier. If supplied, list tags for that run
#'   only.
#' @return A tibble with `run_id`, `tag`, and `created_at_utc`.
#' @examples
#' db_path <- tempfile(fileext = ".duckdb")
#' bars <- data.frame(
#'   ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:3,
#'   instrument_id = "AAA",
#'   open = c(100, 101, 102, 103),
#'   high = c(101, 102, 103, 104),
#'   low = c(99, 100, 101, 102),
#'   close = c(100, 101, 102, 103),
#'   volume = 1000
#' )
#' strategy <- function(ctx) ctx$targets()
#' bt <- ledgr_backtest(data = bars, strategy = strategy, db_path = db_path)
#' ledgr_run_tag(db_path, bt$run_id, "baseline")
#' ledgr_run_tags(db_path)
#' close(bt)
#' @export
ledgr_run_tags <- function(db_path, run_id = NULL) {
  if (!is.null(run_id) && (!is.character(run_id) || length(run_id) != 1L || is.na(run_id) || !nzchar(run_id))) {
    rlang::abort("`run_id` must be NULL or a non-empty character scalar.", class = "ledgr_invalid_args")
  }

  opened <- ledgr_run_store_open(db_path)
  on.exit(ledgr_run_store_close(opened), add = TRUE)
  ledgr_experiment_store_check_schema(opened$con, write = FALSE)

  if (!is.null(run_id)) {
    ledgr_run_store_assert_run_exists(opened$con, run_id)
  }
  if (!ledgr_experiment_store_table_exists(opened$con, "run_tags")) {
    return(ledgr_run_tags_empty())
  }

  if (is.null(run_id)) {
    out <- DBI::dbGetQuery(
      opened$con,
      "
      SELECT run_id, tag, created_at_utc
      FROM run_tags
      ORDER BY tag, run_id
      "
    )
  } else {
    out <- DBI::dbGetQuery(
      opened$con,
      "
      SELECT run_id, tag, created_at_utc
      FROM run_tags
      WHERE run_id = ?
      ORDER BY tag, run_id
      ",
      params = list(run_id)
    )
  }
  if (nrow(out) == 0L) {
    return(ledgr_run_tags_empty())
  }
  out$created_at_utc <- vapply(out$created_at_utc, ledgr_run_store_format_ts, character(1))
  tibble::as_tibble(out)
}
