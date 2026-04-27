ledgr_run_store_open <- function(db_path) {
  if (!is.character(db_path) || length(db_path) != 1 || is.na(db_path) || !nzchar(db_path)) {
    rlang::abort("`db_path` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (identical(db_path, ":memory:")) {
    rlang::abort("`db_path` cannot be ':memory:' for experiment-store discovery.", class = "ledgr_invalid_args")
  }
  if (!file.exists(db_path)) {
    rlang::abort(sprintf("DuckDB file does not exist: %s", db_path), class = "ledgr_db_not_found")
  }

  opened <- ledgr_open_duckdb_with_retry(db_path)
  attr(opened$con, "ledgr_duckdb_drv") <- opened$drv
  opened
}

ledgr_run_store_close <- function(opened) {
  if (is.list(opened) && !is.null(opened$con) && DBI::dbIsValid(opened$con)) {
    suppressWarnings(try(DBI::dbDisconnect(opened$con, shutdown = TRUE), silent = TRUE))
  }
  if (is.list(opened) && !is.null(opened$drv)) {
    suppressWarnings(try(duckdb::duckdb_shutdown(opened$drv), silent = TRUE))
  }
  invisible(TRUE)
}

ledgr_run_store_has_col <- function(con, table_name, column_name) {
  ledgr_experiment_store_table_exists(con, table_name) &&
    column_name %in% ledgr_experiment_store_columns(con, table_name)
}

ledgr_run_store_optional_join <- function(con, table_name, alias, on_sql) {
  if (!ledgr_experiment_store_table_exists(con, table_name)) return("")
  sprintf("LEFT JOIN %s %s ON %s", table_name, alias, on_sql)
}

ledgr_run_store_fetch <- function(con, include_archived = FALSE, run_id = NULL) {
  ledgr_experiment_store_check_schema(con, write = FALSE)
  if (!ledgr_experiment_store_table_exists(con, "runs")) {
    return(tibble::tibble())
  }

  runs_cols <- ledgr_experiment_store_columns(con, "runs")
  run_expr <- function(column, default = "NULL") {
    if (column %in% runs_cols) paste0("r.", column) else default
  }
  prov_expr <- function(column, default = "NULL") {
    if (ledgr_run_store_has_col(con, "run_provenance", column)) paste0("p.", column) else default
  }
  telem_expr <- function(column, default = "NULL") {
    if (ledgr_run_store_has_col(con, "run_telemetry", column)) paste0("t.", column) else default
  }
  snap_expr <- function(column, default = "NULL") {
    if (ledgr_run_store_has_col(con, "snapshots", column)) paste0("s.", column) else default
  }

  archived_expr <- run_expr("archived", "FALSE")
  where <- character()
  params <- list()
  if (!isTRUE(include_archived)) {
    where <- c(where, sprintf("COALESCE(%s, FALSE) = FALSE", archived_expr))
  }
  if (!is.null(run_id)) {
    where <- c(where, "r.run_id = ?")
    params <- c(params, list(run_id))
  }
  where_sql <- if (length(where) > 0L) paste("WHERE", paste(where, collapse = " AND ")) else ""

  provenance_join <- ledgr_run_store_optional_join(con, "run_provenance", "p", "p.run_id = r.run_id")
  telemetry_join <- ledgr_run_store_optional_join(con, "run_telemetry", "t", "t.run_id = r.run_id")
  snapshot_join <- ledgr_run_store_optional_join(con, "snapshots", "s", "s.snapshot_id = r.snapshot_id")
  equity_join <- if (ledgr_experiment_store_table_exists(con, "equity_curve")) {
    "
    LEFT JOIN (
      SELECT run_id,
             MAX(CASE WHEN rn_first = 1 THEN equity END) AS first_equity,
             MAX(CASE WHEN rn_last = 1 THEN equity END) AS final_equity,
             MIN(CASE
               WHEN running_max IS NULL OR running_max = 0 THEN NULL
               ELSE equity / running_max - 1
             END) AS max_drawdown
      FROM (
        SELECT run_id,
               equity,
               ROW_NUMBER() OVER (PARTITION BY run_id ORDER BY ts_utc ASC) AS rn_first,
               ROW_NUMBER() OVER (PARTITION BY run_id ORDER BY ts_utc DESC) AS rn_last,
               MAX(equity) OVER (
                 PARTITION BY run_id
                 ORDER BY ts_utc ASC
                 ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
               ) AS running_max
        FROM equity_curve
      ) eq_ranked
      GROUP BY run_id
    ) eq ON eq.run_id = r.run_id
    "
  } else {
    "
    LEFT JOIN (
      SELECT
        CAST(NULL AS TEXT) AS run_id,
        CAST(NULL AS DOUBLE) AS first_equity,
        CAST(NULL AS DOUBLE) AS final_equity,
        CAST(NULL AS DOUBLE) AS max_drawdown
      WHERE FALSE
    ) eq ON eq.run_id = r.run_id
    "
  }
  trades_join <- if (ledgr_experiment_store_table_exists(con, "ledger_events")) {
    "
    LEFT JOIN (
      SELECT run_id, COUNT(*) AS n_trades
      FROM ledger_events
      WHERE event_type = 'FILL'
      GROUP BY run_id
    ) tr ON tr.run_id = r.run_id
    "
  } else {
    "
    LEFT JOIN (
      SELECT CAST(NULL AS TEXT) AS run_id, CAST(NULL AS INTEGER) AS n_trades
      WHERE FALSE
    ) tr ON tr.run_id = r.run_id
    "
  }

  sql <- sprintf(
    "
    SELECT
      r.run_id,
      %s AS label,
      %s AS snapshot_id,
      %s AS snapshot_hash,
      %s AS created_at_utc,
      %s AS status,
      COALESCE(%s, FALSE) AS archived,
      %s AS archived_at_utc,
      %s AS archive_reason,
      COALESCE(%s, 'legacy') AS reproducibility_level,
      %s AS strategy_type,
      %s AS strategy_source_hash,
      %s AS strategy_source_capture_method,
      %s AS strategy_params_json,
      %s AS strategy_params_hash,
      %s AS ledgr_version,
      %s AS R_version,
      %s AS dependency_versions_json,
      %s AS config_hash,
      %s AS data_hash,
      COALESCE(%s, %s) AS execution_mode,
      %s AS elapsed_sec,
      %s AS feature_cache_hits,
      %s AS feature_cache_misses,
      %s AS error_msg,
      eq.final_equity,
      eq.max_drawdown,
      CASE
        WHEN eq.first_equity IS NULL OR eq.first_equity = 0 THEN NULL
        ELSE eq.final_equity / eq.first_equity - 1
      END AS total_return,
      COALESCE(tr.n_trades, 0) AS n_trades,
      %s AS config_json,
      %s AS schema_version
    FROM runs r
    %s
    %s
    %s
    %s
    %s
    %s
    ORDER BY %s, r.run_id
    ",
    run_expr("label"),
    run_expr("snapshot_id"),
    snap_expr("snapshot_hash"),
    run_expr("created_at_utc"),
    run_expr("status"),
    archived_expr,
    run_expr("archived_at_utc"),
    run_expr("archive_reason"),
    prov_expr("reproducibility_level"),
    prov_expr("strategy_type"),
    prov_expr("strategy_source_hash"),
    prov_expr("strategy_source_capture_method"),
    prov_expr("strategy_params_json"),
    prov_expr("strategy_params_hash"),
    prov_expr("ledgr_version"),
    prov_expr("R_version"),
    prov_expr("dependency_versions_json"),
    run_expr("config_hash"),
    run_expr("data_hash"),
    telem_expr("execution_mode"),
    run_expr("execution_mode"),
    telem_expr("elapsed_sec"),
    telem_expr("feature_cache_hits"),
    telem_expr("feature_cache_misses"),
    run_expr("error_msg"),
    run_expr("config_json"),
    run_expr("schema_version"),
    provenance_join,
    telemetry_join,
    snapshot_join,
    equity_join,
    trades_join,
    where_sql,
    run_expr("created_at_utc", "r.run_id")
  )

  out <- DBI::dbGetQuery(con, sql, params = params)
  if (nrow(out) == 0L) {
    return(tibble::as_tibble(out))
  }

  if ("created_at_utc" %in% names(out)) {
    out$created_at_utc <- vapply(out$created_at_utc, ledgr_run_store_format_ts, character(1))
  }
  if ("archived_at_utc" %in% names(out)) {
    out$archived_at_utc <- vapply(out$archived_at_utc, ledgr_run_store_format_ts, character(1))
  }
  if ("archived" %in% names(out)) out$archived <- as.logical(out$archived)
  if ("n_trades" %in% names(out)) out$n_trades <- as.integer(out$n_trades)
  tibble::as_tibble(out)
}

ledgr_run_store_format_ts <- function(x) {
  if (is.null(x) || length(x) != 1L || is.na(x)) return(NA_character_)
  ledgr_normalize_ts_utc(x)
}

ledgr_run_store_normalize_optional_text <- function(x, arg) {
  if (is.null(x)) {
    return(NA_character_)
  }
  if (!is.character(x) || length(x) != 1L || is.na(x)) {
    rlang::abort(sprintf("`%s` must be NULL or a character scalar.", arg), class = "ledgr_invalid_args")
  }
  if (!nzchar(x)) {
    return(NA_character_)
  }
  x
}

ledgr_run_store_assert_run_exists <- function(con, run_id) {
  row <- DBI::dbGetQuery(
    con,
    "SELECT run_id FROM runs WHERE run_id = ?",
    params = list(run_id)
  )
  if (nrow(row) != 1L) {
    rlang::abort(sprintf("Run not found: %s", run_id), class = "ledgr_run_not_found")
  }
  invisible(TRUE)
}

ledgr_run_info_from_row <- function(row, db_path) {
  if (nrow(row) != 1L) {
    rlang::abort("`row` must contain exactly one run.", class = "ledgr_internal_error")
  }
  info <- as.list(row[1, , drop = TRUE])
  info$db_path <- db_path
  info$telemetry_missing <- all(vapply(
    info[c("elapsed_sec", "feature_cache_hits", "feature_cache_misses")],
    function(x) is.null(x) || length(x) == 0L || is.na(x),
    logical(1)
  ))
  info$legacy_pre_provenance <- identical(info$reproducibility_level, "legacy") ||
    identical(info$strategy_source_capture_method, "legacy_pre_provenance")
  structure(info, class = c("ledgr_run_info", "list"))
}

#' List runs in a ledgr experiment store
#'
#' Discovers stored runs in a DuckDB experiment-store file without recomputing
#' or mutating runs. Archived runs are hidden by default.
#'
#' @param db_path Path to a DuckDB experiment-store file.
#' @param include_archived Logical scalar. If `TRUE`, include archived runs.
#' @return A tibble with run identity, provenance, status, telemetry summary,
#'   and basic result summary columns.
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
#' ledgr_run_list(db_path)
#' close(bt)
#' @export
ledgr_run_list <- function(db_path, include_archived = FALSE) {
  if (!is.logical(include_archived) || length(include_archived) != 1L || is.na(include_archived)) {
    rlang::abort("`include_archived` must be TRUE or FALSE.", class = "ledgr_invalid_args")
  }
  opened <- ledgr_run_store_open(db_path)
  on.exit(ledgr_run_store_close(opened), add = TRUE)
  out <- ledgr_run_store_fetch(opened$con, include_archived = include_archived)
  detail_cols <- c("config_json", "dependency_versions_json", "strategy_params_json")
  out[setdiff(names(out), detail_cols)]
}

#' Inspect one run in a ledgr experiment store
#'
#' Returns a structured `ledgr_run_info` object for a stored run. This function
#' reads run metadata and diagnostics only; it does not execute strategy code.
#'
#' @param db_path Path to a DuckDB experiment-store file.
#' @param run_id Run identifier.
#' @return A `ledgr_run_info` object.
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
#' ledgr_run_info(db_path, bt$run_id)
#' close(bt)
#' @export
ledgr_run_info <- function(db_path, run_id) {
  if (!is.character(run_id) || length(run_id) != 1L || is.na(run_id) || !nzchar(run_id)) {
    rlang::abort("`run_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  opened <- ledgr_run_store_open(db_path)
  on.exit(ledgr_run_store_close(opened), add = TRUE)

  row <- ledgr_run_store_fetch(opened$con, include_archived = TRUE, run_id = run_id)
  if (nrow(row) != 1L) {
    rlang::abort(sprintf("Run not found: %s", run_id), class = "ledgr_run_not_found")
  }

  ledgr_run_info_from_row(row, db_path)
}

#' @export
print.ledgr_run_info <- function(x, ...) {
  if (!inherits(x, "ledgr_run_info")) {
    rlang::abort("`x` must be a ledgr_run_info object.", class = "ledgr_invalid_args")
  }

  value <- function(name, default = "NA") {
    val <- x[[name]]
    if (is.null(val) || length(val) == 0L || is.na(val)) return(default)
    as.character(val[[1]])
  }

  cat("ledgr Run Info\n")
  cat("==============\n\n")
  cat("Run ID:          ", value("run_id"), "\n", sep = "")
  cat("Label:           ", value("label"), "\n", sep = "")
  cat("Status:          ", value("status"), "\n", sep = "")
  cat("Archived:        ", value("archived", "FALSE"), "\n", sep = "")
  cat("Snapshot:        ", value("snapshot_id"), "\n", sep = "")
  cat("Snapshot Hash:   ", value("snapshot_hash"), "\n", sep = "")
  cat("Config Hash:     ", value("config_hash"), "\n", sep = "")
  cat("Strategy Hash:   ", value("strategy_source_hash"), "\n", sep = "")
  cat("Params Hash:     ", value("strategy_params_hash"), "\n", sep = "")
  cat("Reproducibility: ", value("reproducibility_level"), "\n", sep = "")
  cat("Execution Mode:  ", value("execution_mode"), "\n", sep = "")
  cat("Elapsed Sec:     ", value("elapsed_sec"), "\n", sep = "")
  if (isTRUE(x$legacy_pre_provenance)) {
    cat("\nLegacy/pre-provenance run: strategy provenance is incomplete.\n")
  }
  if (!identical(value("status"), "DONE")) {
    cat("\nDiagnostics: ", value("error_msg"), "\n", sep = "")
  }
  invisible(x)
}

#' Reopen a completed run from a ledgr experiment store
#'
#' Returns a `ledgr_backtest`-compatible handle over an existing completed run.
#' The run is not recomputed and strategy code is not executed.
#'
#' @param db_path Path to a DuckDB experiment-store file.
#' @param run_id Run identifier. The run must have status `DONE`.
#' @return A `ledgr_backtest` object.
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
#' run_id <- bt$run_id
#' close(bt)
#' reopened <- ledgr_run_open(db_path, run_id)
#' summary(reopened)
#' close(reopened)
#' @export
ledgr_run_open <- function(db_path, run_id) {
  if (!is.character(run_id) || length(run_id) != 1L || is.na(run_id) || !nzchar(run_id)) {
    rlang::abort("`run_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  opened <- ledgr_run_store_open(db_path)
  on.exit(ledgr_run_store_close(opened), add = TRUE)
  ledgr_experiment_store_check_schema(opened$con, write = FALSE)

  row <- DBI::dbGetQuery(
    opened$con,
    "SELECT run_id, status, config_json FROM runs WHERE run_id = ?",
    params = list(run_id)
  )
  if (nrow(row) != 1L) {
    rlang::abort(sprintf("Run not found: %s", run_id), class = "ledgr_run_not_found")
  }
  status <- row$status[[1]]
  if (!identical(status, "DONE")) {
    rlang::abort(
      sprintf("Run '%s' has status %s and cannot be opened as a completed backtest. Use ledgr_run_info() for diagnostics.", run_id, status),
      class = "ledgr_run_not_complete"
    )
  }
  config_json <- row$config_json[[1]]
  if (is.null(config_json) || is.na(config_json) || !nzchar(config_json)) {
    rlang::abort(sprintf("Run '%s' has no stored config_json and cannot be reopened.", run_id), class = "ledgr_invalid_run")
  }

  cfg <- tryCatch(
    jsonlite::fromJSON(config_json, simplifyVector = TRUE, simplifyDataFrame = FALSE, simplifyMatrix = FALSE),
    error = function(e) {
      rlang::abort(sprintf("Run '%s' has invalid config_json and cannot be reopened.", run_id), class = "ledgr_invalid_run", parent = e)
    }
  )
  cfg$db_path <- db_path
  required_config_fields <- c("db_path", "engine", "universe", "backtest", "fill_model", "strategy")
  missing_config_fields <- setdiff(required_config_fields, names(cfg))
  if (length(missing_config_fields) > 0L) {
    rlang::abort(
      sprintf(
        "Run '%s' has legacy or incomplete config_json and cannot be reopened. Use ledgr_run_info() to inspect available metadata.",
        run_id
      ),
      class = "ledgr_invalid_run"
    )
  }
  class(cfg) <- unique(c("ledgr_config", class(cfg)))
  tryCatch(
    validate_ledgr_config(cfg),
    error = function(e) {
      rlang::abort(sprintf("Run '%s' has invalid config_json and cannot be reopened.", run_id), class = "ledgr_invalid_run", parent = e)
    }
  )
  new_ledgr_backtest(run_id = run_id, db_path = db_path, config = cfg)
}

#' Set a human-readable label for a run
#'
#' Updates only the mutable label metadata for a stored run. The immutable
#' `run_id` and experiment identity hashes are not changed.
#'
#' @param db_path Path to a DuckDB experiment-store file.
#' @param run_id Run identifier.
#' @param label Human-readable label. Use `NULL` or `""` to clear the label.
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
#' ledgr_run_label(db_path, bt$run_id, "baseline")
#' close(bt)
#' @export
ledgr_run_label <- function(db_path, run_id, label = NULL) {
  if (!is.character(run_id) || length(run_id) != 1L || is.na(run_id) || !nzchar(run_id)) {
    rlang::abort("`run_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  label <- ledgr_run_store_normalize_optional_text(label, "label")

  opened <- ledgr_run_store_open(db_path)
  on.exit(ledgr_run_store_close(opened), add = TRUE)
  ledgr_experiment_store_check_schema(opened$con, write = TRUE, inform = TRUE)
  ledgr_run_store_assert_run_exists(opened$con, run_id)

  DBI::dbExecute(
    opened$con,
    "UPDATE runs SET label = ? WHERE run_id = ?",
    params = list(label, run_id)
  )
  row <- ledgr_run_store_fetch(opened$con, include_archived = TRUE, run_id = run_id)
  ledgr_run_info_from_row(row, db_path)
}

#' Archive a run without deleting artifacts
#'
#' Marks a stored run as archived so it is hidden from default run lists while
#' remaining inspectable and, if completed, reopenable. Archiving is
#' idempotent and does not rewrite existing archive metadata.
#'
#' @param db_path Path to a DuckDB experiment-store file.
#' @param run_id Run identifier.
#' @param reason Optional archive reason. Empty strings are stored as `NULL`.
#' @return A `ledgr_run_info` object after the archive operation.
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
#' ledgr_run_archive(db_path, bt$run_id, reason = "example cleanup")
#' close(bt)
#' @export
ledgr_run_archive <- function(db_path, run_id, reason = NULL) {
  if (!is.character(run_id) || length(run_id) != 1L || is.na(run_id) || !nzchar(run_id)) {
    rlang::abort("`run_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  reason <- ledgr_run_store_normalize_optional_text(reason, "reason")

  opened <- ledgr_run_store_open(db_path)
  on.exit(ledgr_run_store_close(opened), add = TRUE)
  ledgr_experiment_store_check_schema(opened$con, write = TRUE, inform = TRUE)
  ledgr_run_store_assert_run_exists(opened$con, run_id)

  DBI::dbExecute(
    opened$con,
    "
    UPDATE runs
    SET archived = TRUE,
        archived_at_utc = CASE
          WHEN COALESCE(archived, FALSE) = TRUE THEN archived_at_utc
          ELSE ?
        END,
        archive_reason = CASE
          WHEN COALESCE(archived, FALSE) = TRUE THEN archive_reason
          ELSE ?
        END
    WHERE run_id = ?
    ",
    params = list(as.POSIXct(Sys.time(), tz = "UTC"), reason, run_id)
  )
  row <- ledgr_run_store_fetch(opened$con, include_archived = TRUE, run_id = run_id)
  ledgr_run_info_from_row(row, db_path)
}
