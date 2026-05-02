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
#' @param snapshot A sealed `ledgr_snapshot` object. Use
#'   `ledgr_snapshot_load(db_path, snapshot_id)` to resume from a durable
#'   DuckDB file in a new R session.
#' @param run_id Run identifier.
#' @param tags Character vector of tags. Tags are trimmed, deduplicated, and
#'   must not contain commas or control characters.
#' @return The input `ledgr_snapshot`, invisibly.
#' @examples
#' bars <- subset(ledgr_demo_bars, instrument_id == "DEMO_01")
#' snapshot <- ledgr_snapshot_from_df(utils::head(bars, 10))
#' strategy <- function(ctx, params) ctx$flat()
#' exp <- ledgr_experiment(snapshot, strategy, opening = ledgr_opening(cash = 1000))
#' bt <- ledgr_run(exp, params = list(), run_id = "flat")
#' ledgr_run_tag(snapshot, bt$run_id, c("baseline", "demo"))
#' ledgr_run_tags(snapshot, bt$run_id)
#' close(bt)
#' ledgr_snapshot_close(snapshot)
#' @export
ledgr_run_tag <- function(snapshot, run_id, tags) {
  if (!is.character(run_id) || length(run_id) != 1L || is.na(run_id) || !nzchar(run_id)) {
    rlang::abort("`run_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  tags <- ledgr_run_tags_normalize(tags)

  db_path <- ledgr_run_store_snapshot_path(snapshot)
  snapshot_id <- ledgr_run_store_snapshot_id(snapshot)
  opened <- ledgr_run_store_open(db_path)
  on.exit(ledgr_run_store_close(opened), add = TRUE)
  ledgr_checkpoint_duckdb(opened$con, strict = TRUE)
  ledgr_experiment_store_check_schema(opened$con, write = TRUE, inform = TRUE)
  ledgr_run_store_assert_run_exists(opened$con, run_id, snapshot_id = snapshot_id)

  created_at <- as.POSIXct(Sys.time(), tz = "UTC")
  for (tag in tags) {
    DBI::dbExecute(
      opened$con,
      "
      INSERT INTO run_tags (run_id, \"tag\", created_at_utc)
      VALUES (?, ?, ?)
      ON CONFLICT DO NOTHING
      ",
      params = list(run_id, tag, created_at)
    )
  }
  ledgr_checkpoint_duckdb(opened$con, strict = TRUE)

  invisible(snapshot)
}

#' Remove tags from a stored run
#'
#' Removes mutable metadata tags from a run. If `tags = NULL`, all tags for the
#' run are removed. Removing absent tags is idempotent.
#'
#' @param snapshot A sealed `ledgr_snapshot` object. Use
#'   `ledgr_snapshot_load(db_path, snapshot_id)` to resume from a durable
#'   DuckDB file in a new R session.
#' @param run_id Run identifier.
#' @param tags Character vector of tags to remove, or `NULL` to remove all tags
#'   from the run. Use `NULL` for "all tags"; `character(0)` is treated as an
#'   invalid empty tag set.
#' @return The input `ledgr_snapshot`, invisibly.
#' @examples
#' bars <- subset(ledgr_demo_bars, instrument_id == "DEMO_01")
#' snapshot <- ledgr_snapshot_from_df(utils::head(bars, 10))
#' strategy <- function(ctx, params) ctx$flat()
#' exp <- ledgr_experiment(snapshot, strategy, opening = ledgr_opening(cash = 1000))
#' bt <- ledgr_run(exp, params = list(), run_id = "flat")
#' ledgr_run_tag(snapshot, bt$run_id, c("baseline", "demo"))
#' ledgr_run_untag(snapshot, bt$run_id, "demo")
#' close(bt)
#' ledgr_snapshot_close(snapshot)
#' @export
ledgr_run_untag <- function(snapshot, run_id, tags = NULL) {
  if (!is.character(run_id) || length(run_id) != 1L || is.na(run_id) || !nzchar(run_id)) {
    rlang::abort("`run_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  tags <- ledgr_run_tags_normalize(tags, allow_null = TRUE)

  db_path <- ledgr_run_store_snapshot_path(snapshot)
  snapshot_id <- ledgr_run_store_snapshot_id(snapshot)
  opened <- ledgr_run_store_open(db_path)
  on.exit(ledgr_run_store_close(opened), add = TRUE)
  ledgr_checkpoint_duckdb(opened$con, strict = TRUE)
  ledgr_experiment_store_check_schema(opened$con, write = TRUE, inform = TRUE)
  ledgr_run_store_assert_run_exists(opened$con, run_id, snapshot_id = snapshot_id)

  if (is.null(tags)) {
    DBI::dbExecute(opened$con, "DELETE FROM run_tags WHERE run_id = ?", params = list(run_id))
  } else {
    placeholders <- paste(rep("?", length(tags)), collapse = ", ")
    DBI::dbExecute(
      opened$con,
      sprintf("DELETE FROM run_tags WHERE run_id = ? AND \"tag\" IN (%s)", placeholders),
      params = c(list(run_id), as.list(tags))
    )
  }
  ledgr_checkpoint_duckdb(opened$con, strict = TRUE)

  invisible(snapshot)
}

#' List run tags
#'
#' Lists mutable run tags stored in a ledgr experiment store. This is a
#' read-only operation and does not migrate legacy stores.
#'
#' @param snapshot A sealed `ledgr_snapshot` object. Use
#'   `ledgr_snapshot_load(db_path, snapshot_id)` to resume from a durable
#'   DuckDB file in a new R session.
#' @param run_id Optional run identifier. If supplied, list tags for that run
#'   only.
#' @return A tibble with `run_id`, `tag`, and `created_at_utc`.
#' @examples
#' bars <- subset(ledgr_demo_bars, instrument_id == "DEMO_01")
#' snapshot <- ledgr_snapshot_from_df(utils::head(bars, 10))
#' strategy <- function(ctx, params) ctx$flat()
#' exp <- ledgr_experiment(snapshot, strategy, opening = ledgr_opening(cash = 1000))
#' bt <- ledgr_run(exp, params = list(), run_id = "flat")
#' ledgr_run_tag(snapshot, bt$run_id, "baseline")
#' ledgr_run_tags(snapshot)
#' close(bt)
#' ledgr_snapshot_close(snapshot)
#' @export
ledgr_run_tags <- function(snapshot, run_id = NULL) {
  if (!is.null(run_id) && (!is.character(run_id) || length(run_id) != 1L || is.na(run_id) || !nzchar(run_id))) {
    rlang::abort("`run_id` must be NULL or a non-empty character scalar.", class = "ledgr_invalid_args")
  }

  db_path <- ledgr_run_store_snapshot_path(snapshot)
  snapshot_id <- ledgr_run_store_snapshot_id(snapshot)
  opened <- ledgr_run_store_open(db_path)
  on.exit(ledgr_run_store_close(opened), add = TRUE)
  ledgr_experiment_store_check_schema(opened$con, write = FALSE)

  if (!is.null(run_id)) {
    ledgr_run_store_assert_run_exists(opened$con, run_id, snapshot_id = snapshot_id)
  }
  if (!ledgr_experiment_store_table_exists(opened$con, "run_tags")) {
    return(ledgr_run_tags_empty())
  }

  if (is.null(run_id)) {
    out <- DBI::dbGetQuery(
      opened$con,
      "
      SELECT rt.run_id, rt.tag, rt.created_at_utc
      FROM run_tags rt
      INNER JOIN runs r ON r.run_id = rt.run_id
      WHERE r.snapshot_id = ?
      ORDER BY rt.tag, rt.run_id
      ",
      params = list(snapshot_id)
    )
  } else {
    out <- DBI::dbGetQuery(
      opened$con,
      "
      SELECT rt.run_id, rt.tag, rt.created_at_utc
      FROM run_tags rt
      INNER JOIN runs r ON r.run_id = rt.run_id
      WHERE rt.run_id = ? AND r.snapshot_id = ?
      ORDER BY rt.tag, rt.run_id
      ",
      params = list(run_id, snapshot_id)
    )
  }
  if (nrow(out) == 0L) {
    return(ledgr_run_tags_empty())
  }
  out$created_at_utc <- vapply(out$created_at_utc, ledgr_run_store_format_ts, character(1))
  tibble::as_tibble(out)
}
