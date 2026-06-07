#' Save, reopen, list, and inspect sweep artifacts
#'
#' `ledgr_sweep_save()` persists a compact saved-sweep artifact in the
#' snapshot's experiment store. Saved sweeps are candidate evidence, not
#' committed runs: they store scalar candidate rows and retained return rows
#' when present, but not ledgers, fills, trades, or per-instrument artifacts.
#' Promotion from a reopened saved sweep re-executes the selected candidate from
#' its reproduction key against the sealed snapshot.
#'
#' @param sweep A `ledgr_sweep_results` object.
#' @param snapshot A sealed `ledgr_snapshot` object locating the experiment
#'   store.
#' @param sweep_id Optional saved sweep id. `NULL` uses the in-session sweep id.
#' @param note Optional length-one character note.
#' @return The saved `sweep_id`, invisibly.
#' @examples
#' bars <- data.frame(
#'   instrument_id = "AAA",
#'   ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:4,
#'   open = c(10, 11, 12, 11, 13),
#'   high = c(11, 12, 13, 12, 14),
#'   low = c(9, 10, 11, 10, 12),
#'   close = c(10, 11, 12, 11, 13),
#'   volume = 1000
#' )
#' snapshot <- ledgr_snapshot_from_df(bars, db_path = tempfile(fileext = ".duckdb"))
#' strategy <- function(ctx, params) {
#'   targets <- ctx$flat()
#'   targets["AAA"] <- params$qty
#'   targets
#' }
#' exp <- ledgr_experiment(snapshot, strategy, cost_model = ledgr_cost_zero())
#' grid <- ledgr_param_grid(flat = list(qty = 0), long = list(qty = 1))
#' sweep <- ledgr_sweep(exp, grid, retain = ledgr_sweep_retention("completed"))
#'
#' saved_id <- ledgr_sweep_save(sweep, snapshot, sweep_id = "example_sweep")
#' ledgr_sweep_list(snapshot)
#' reopened <- ledgr_sweep_open(snapshot, saved_id)
#' ledgr_sweep_info(reopened)
#' ledgr_sweep_returns(reopened)
#'
#' ledgr_snapshot_close(snapshot)
#' @export
ledgr_sweep_save <- function(sweep, snapshot, sweep_id = NULL, note = NULL) {
  ledgr_sweep_storage_assert_sweep(sweep)
  db_path <- ledgr_run_store_snapshot_path(snapshot)
  sweep_id <- ledgr_sweep_normalize_save_id(sweep_id, sweep)
  note <- ledgr_sweep_normalize_note(note)

  opened <- ledgr_run_store_open(db_path)
  on.exit(ledgr_run_store_close(opened), add = TRUE)
  ledgr_experiment_store_check_schema(opened$con, write = TRUE, inform = TRUE)
  ledgr_sweep_assert_schema_compatible(opened$con)
  ledgr_sweep_assert_snapshot_matches(opened$con, sweep, snapshot)
  ledgr_sweep_assert_id_available(opened$con, sweep_id)

  parent <- ledgr_sweep_storage_parent_row(sweep, sweep_id = sweep_id, note = note)
  candidates <- ledgr_sweep_storage_candidate_rows(sweep, sweep_id = sweep_id)
  returns <- ledgr_sweep_storage_return_rows(sweep, sweep_id = sweep_id)

  DBI::dbWithTransaction(opened$con, {
    DBI::dbAppendTable(opened$con, "sweeps", parent)
    DBI::dbAppendTable(opened$con, "sweep_candidates", candidates)
    if (nrow(returns) > 0L) {
      DBI::dbAppendTable(opened$con, "sweep_returns", returns)
    }
  })
  ledgr_checkpoint_duckdb(opened$con, strict = TRUE)
  invisible(sweep_id)
}

#' @describeIn ledgr_sweep_save Reopen a compact saved sweep from the snapshot
#'   experiment store.
#' @return `ledgr_sweep_open()` returns a `ledgr_sweep_results`-compatible
#'   tibble.
#' @export
ledgr_sweep_open <- function(snapshot, sweep_id) {
  db_path <- ledgr_run_store_snapshot_path(snapshot)
  sweep_id <- ledgr_sweep_normalize_id(sweep_id)

  opened <- ledgr_run_store_open(db_path)
  on.exit(ledgr_run_store_close(opened), add = TRUE)
  ledgr_experiment_store_check_schema(opened$con, write = FALSE)
  ledgr_sweep_assert_schema_compatible(opened$con)

  parent <- ledgr_sweep_fetch_parent(opened$con, sweep_id)
  ledgr_sweep_assert_parent_snapshot(parent, snapshot, opened$con)
  ledgr_sweep_assert_parent_schema_version(parent)

  candidates <- ledgr_sweep_fetch_candidates(opened$con, sweep_id)
  returns <- ledgr_sweep_fetch_returns(opened$con, sweep_id, candidates)
  universe <- ledgr_sweep_fetch_universe(opened$con, as.character(parent$snapshot_id[[1]]))
  out <- ledgr_sweep_reconstruct(parent, candidates, returns, universe = universe)
  out
}

#' @describeIn ledgr_sweep_save List saved sweeps in a snapshot experiment
#'   store.
#' @return `ledgr_sweep_list()` returns a tibble with one row per saved sweep.
#' @export
ledgr_sweep_list <- function(snapshot) {
  db_path <- ledgr_run_store_snapshot_path(snapshot)
  opened <- ledgr_run_store_open(db_path)
  on.exit(ledgr_run_store_close(opened), add = TRUE)
  ledgr_experiment_store_check_schema(opened$con, write = FALSE)
  ledgr_sweep_assert_schema_compatible(opened$con)

  rows <- DBI::dbGetQuery(
    opened$con,
    "
    SELECT
      s.sweep_id,
      s.created_at_utc,
      s.engine_version,
      s.sweep_schema_version,
      COUNT(c.candidate_row) AS n_candidates,
      SUM(CASE WHEN c.status = 'DONE' THEN 1 ELSE 0 END) AS n_completed,
      s.retention_json,
      s.note
    FROM sweeps s
    LEFT JOIN sweep_candidates c
      ON s.sweep_id = c.sweep_id
    WHERE s.snapshot_id = ?
    GROUP BY
      s.sweep_id, s.created_at_utc, s.engine_version,
      s.sweep_schema_version, s.retention_json, s.note
    ORDER BY s.created_at_utc DESC, s.sweep_id DESC
    ",
    params = list(ledgr_run_store_snapshot_id(snapshot))
  )
  if (nrow(rows) == 0L) {
    return(structure(tibble::tibble(
      sweep_id = character(),
      created_at_utc = as.POSIXct(character(), tz = "UTC"),
      engine_version = character(),
      sweep_schema_version = integer(),
      n_candidates = integer(),
      n_completed = integer(),
      retention_returns = character(),
      note = character()
    ), class = c("ledgr_sweep_list", "tbl_df", "tbl", "data.frame")))
  }
  rows$created_at_utc <- as.POSIXct(rows$created_at_utc, tz = "UTC")
  rows$sweep_schema_version <- as.integer(rows$sweep_schema_version)
  rows$n_candidates <- as.integer(rows$n_candidates)
  rows$n_completed <- as.integer(rows$n_completed)
  rows$retention_returns <- vapply(rows$retention_json, ledgr_sweep_retention_returns_from_json, character(1))
  rows$retention_json <- NULL
  rows <- rows[, c(
    "sweep_id", "created_at_utc", "engine_version", "sweep_schema_version",
    "n_candidates", "n_completed", "retention_returns", "note"
  ), drop = FALSE]
  structure(tibble::as_tibble(rows), class = c("ledgr_sweep_list", class(tibble::as_tibble(rows))))
}

#' @describeIn ledgr_sweep_save Inspect in-memory or reopened sweep metadata.
#' @param x A `ledgr_sweep_results` object.
#' @return `ledgr_sweep_info()` returns a classed named list.
#' @export
ledgr_sweep_info <- function(x) {
  if (!inherits(x, "ledgr_sweep_results")) {
    rlang::abort(
      "`x` must be an in-memory or reopened ledgr_sweep_results object, not a bare sweep id.",
      class = c("ledgr_invalid_args")
    )
  }
  status <- as.character(x$status)
  retention <- attr(x, "sweep_retention", exact = TRUE)
  saved <- attr(x, "saved_sweep", exact = TRUE)
  info <- list(
    sweep_id = attr(x, "sweep_id", exact = TRUE),
    snapshot_id = attr(x, "snapshot_id", exact = TRUE),
    snapshot_hash = attr(x, "snapshot_hash", exact = TRUE),
    n_candidates = nrow(x),
    n_completed = sum(status == "DONE", na.rm = TRUE),
    n_failed = sum(status == "FAILED", na.rm = TRUE),
    retention = retention,
    retention_returns = if (inherits(retention, "ledgr_sweep_retention")) retention$returns else NA_character_,
    cost_model_hash = attr(x, "cost_model_hash", exact = TRUE),
    cost_plan_json = attr(x, "cost_plan_json", exact = TRUE),
    metric_context_hash = attr(x, "metric_context_hash", exact = TRUE),
    metric_context_version = attr(x, "metric_context_version", exact = TRUE),
    feature_union_hash = attr(x, "feature_union_hash", exact = TRUE),
    feature_engine_version = attr(x, "feature_engine_version", exact = TRUE),
    grid = list(
      n_candidates = nrow(x),
      candidate_ids = as.character(x$candidate_id),
      candidate_rows = as.integer(x$candidate_row)
    ),
    saved_artifact = saved %||% list(saved = FALSE)
  )
  structure(info, class = c("ledgr_sweep_info", "list"))
}

#' @export
print.ledgr_sweep_info <- function(x, ...) {
  if (!inherits(x, "ledgr_sweep_info")) {
    rlang::abort("`x` must be a ledgr_sweep_info object.", class = "ledgr_invalid_args")
  }
  value <- function(name, default = "NA") {
    val <- x[[name]]
    if (is.null(val) || length(val) == 0L || (is.atomic(val) && length(val) == 1L && is.na(val))) {
      return(default)
    }
    as.character(val[[1]])
  }
  saved <- x$saved_artifact
  cat("ledgr Sweep Info\n")
  cat("================\n\n")
  cat("Sweep ID:          ", value("sweep_id"), "\n", sep = "")
  cat("Snapshot:          ", value("snapshot_id"), "\n", sep = "")
  cat("Snapshot Hash:     ", value("snapshot_hash"), "\n", sep = "")
  cat("Candidates:        ", value("n_candidates", "0"), "\n", sep = "")
  cat("Completed:         ", value("n_completed", "0"), "\n", sep = "")
  cat("Failed:            ", value("n_failed", "0"), "\n", sep = "")
  cat("Retention returns: ", value("retention_returns"), "\n", sep = "")
  cat("Cost Model Hash:   ", value("cost_model_hash"), "\n", sep = "")
  cat("Metric Hash:       ", value("metric_context_hash"), "\n", sep = "")
  cat("Feature Union:     ", value("feature_union_hash"), "\n", sep = "")
  if (is.list(saved) && isTRUE(saved$saved)) {
    cat("\nSaved artifact\n")
    cat("Created At:        ", as.character(saved$created_at_utc %||% NA_character_), "\n", sep = "")
    cat("Schema Version:    ", as.character(saved$sweep_schema_version %||% NA_integer_), "\n", sep = "")
    cat("Engine Version:    ", as.character(saved$engine_version %||% NA_character_), "\n", sep = "")
    cat("Note:              ", as.character(saved$note %||% NA_character_), "\n", sep = "")
  }
  invisible(x)
}

#' @export
print.ledgr_sweep_list <- function(x, ...) {
  ledgr_print_curated_tibble(
    "# ledgr saved sweep list",
    x,
    cols = c(
      "sweep_id", "created_at_utc", "sweep_schema_version",
      "n_candidates", "n_completed", "retention_returns", "note"
    ),
    footer = "Open one saved sweep with ledgr_sweep_open(snapshot, sweep_id).",
    ...
  )
}

ledgr_sweep_normalize_save_id <- function(sweep_id, sweep) {
  if (is.null(sweep_id)) {
    sweep_id <- attr(sweep, "sweep_id", exact = TRUE)
  }
  ledgr_sweep_normalize_id(sweep_id)
}

ledgr_sweep_normalize_id <- function(sweep_id) {
  if (!is.character(sweep_id) ||
      length(sweep_id) != 1L ||
      is.na(sweep_id) ||
      !nzchar(sweep_id) ||
      !nzchar(trimws(sweep_id)) ||
      nchar(sweep_id, type = "bytes") > 256L ||
      grepl("[^ -~]", sweep_id)) {
    rlang::abort(
      "`sweep_id` must be a non-empty, non-whitespace ASCII character scalar of at most 256 bytes.",
      class = c("ledgr_invalid_sweep_id", "ledgr_invalid_args")
    )
  }
  as.character(sweep_id)
}

ledgr_sweep_normalize_note <- function(note) {
  if (is.null(note)) {
    return(NA_character_)
  }
  if (!is.character(note) || length(note) != 1L || is.na(note)) {
    rlang::abort("`note` must be NULL or a length-one character scalar.", class = c("ledgr_invalid_args"))
  }
  as.character(note)
}

ledgr_sweep_assert_id_available <- function(con, sweep_id) {
  existing <- DBI::dbGetQuery(
    con,
    "SELECT sweep_id FROM sweeps WHERE sweep_id = ?",
    params = list(sweep_id)
  )
  if (nrow(existing) > 0L) {
    rlang::abort(
      sprintf("Saved sweep id already exists: %s", sweep_id),
      class = c("ledgr_sweep_id_exists", "ledgr_invalid_args")
    )
  }
  invisible(TRUE)
}

ledgr_sweep_assert_schema_compatible <- function(con) {
  required <- list(
    sweeps = c(
      "sweep_id", "snapshot_id", "snapshot_hash", "created_at_utc",
      "engine_version", "sweep_schema_version", "note", "retention_json",
      "metric_context_json", "metric_context_hash", "metric_context_version",
      "cost_model_hash", "cost_plan_json", "execution_assumptions_json",
      "feature_union_hash", "feature_engine_version", "candidate_features_json",
      "grid_json"
    ),
    sweep_candidates = c(
      "sweep_id", "candidate_id", "candidate_row", "status", "final_equity",
      "metrics_json", "total_return", "annualized_return", "volatility",
      "sharpe_ratio", "max_drawdown", "n_trades", "win_rate", "avg_trade",
      "time_in_market", "execution_seed", "error_class", "error_msg",
      "params_json", "feature_params_json", "warnings_json",
      "feature_set_hash", "feature_fingerprints_json", "provenance_json",
      "cost_model_hash", "metric_context_hash"
    ),
    sweep_returns = c("sweep_id", "candidate_row", "pulse_index", "ts_utc", "equity", "period_return")
  )
  for (table in names(required)) {
    if (!ledgr_experiment_store_table_exists(con, table)) {
      rlang::abort(
        sprintf("Saved sweep schema is missing required table: %s", table),
        class = c("ledgr_sweep_schema_incompatible", "ledgr_invalid_store")
      )
    }
    missing <- setdiff(required[[table]], ledgr_experiment_store_columns(con, table))
    if (length(missing) > 0L) {
      rlang::abort(
        sprintf("Saved sweep schema table %s is missing required column(s): %s.", table, paste(missing, collapse = ", ")),
        class = c("ledgr_sweep_schema_incompatible", "ledgr_invalid_store")
      )
    }
  }
  invisible(TRUE)
}

ledgr_sweep_assert_snapshot_matches <- function(con, sweep, snapshot) {
  snapshot_id <- attr(sweep, "snapshot_id", exact = TRUE)
  snapshot_hash <- attr(sweep, "snapshot_hash", exact = TRUE)
  ledgr_sweep_assert_snapshot_row(con, snapshot_id, snapshot_hash)
  if (!identical(as.character(snapshot$snapshot_id), as.character(snapshot_id))) {
    rlang::abort(
      sprintf(
        "Saved sweep belongs to snapshot '%s', but `snapshot` is '%s'.",
        snapshot_id,
        snapshot$snapshot_id
      ),
      class = c("ledgr_sweep_snapshot_hash_mismatch", "ledgr_invalid_args")
    )
  }
  invisible(TRUE)
}

ledgr_sweep_assert_parent_snapshot <- function(parent, snapshot, con) {
  snapshot_id <- as.character(parent$snapshot_id[[1]])
  snapshot_hash <- as.character(parent$snapshot_hash[[1]])
  if (!identical(as.character(snapshot$snapshot_id), snapshot_id)) {
    rlang::abort(
      sprintf("Saved sweep '%s' belongs to snapshot '%s', not '%s'.", parent$sweep_id[[1]], snapshot_id, snapshot$snapshot_id),
      class = c("ledgr_sweep_snapshot_not_found", "ledgr_invalid_args")
    )
  }
  ledgr_sweep_assert_snapshot_row(con, snapshot_id, snapshot_hash)
  invisible(TRUE)
}

ledgr_sweep_assert_snapshot_row <- function(con, snapshot_id, snapshot_hash) {
  row <- DBI::dbGetQuery(
    con,
    "SELECT snapshot_id, snapshot_hash FROM snapshots WHERE snapshot_id = ?",
    params = list(snapshot_id)
  )
  if (nrow(row) != 1L) {
    rlang::abort(
      sprintf("Saved sweep snapshot is not present in this store: %s", snapshot_id),
      class = c("ledgr_sweep_snapshot_not_found", "ledgr_invalid_args")
    )
  }
  if (!identical(as.character(row$snapshot_hash[[1]]), as.character(snapshot_hash))) {
    rlang::abort(
      sprintf("Saved sweep snapshot hash mismatch for snapshot: %s", snapshot_id),
      class = c("ledgr_sweep_snapshot_hash_mismatch", "ledgr_invalid_args")
    )
  }
  invisible(TRUE)
}

ledgr_sweep_assert_parent_schema_version <- function(parent) {
  version <- as.integer(parent$sweep_schema_version[[1]])
  if (is.na(version) || version > ledgr_saved_sweep_schema_version || version < 1L) {
    rlang::abort(
      sprintf(
        "Saved sweep schema version %s is incompatible with this ledgr version.",
        as.character(parent$sweep_schema_version[[1]])
      ),
      class = c("ledgr_sweep_schema_incompatible", "ledgr_invalid_store")
    )
  }
  invisible(TRUE)
}

ledgr_sweep_fetch_parent <- function(con, sweep_id) {
  row <- DBI::dbGetQuery(con, "SELECT * FROM sweeps WHERE sweep_id = ?", params = list(sweep_id))
  if (nrow(row) != 1L) {
    rlang::abort(sprintf("Saved sweep not found: %s", sweep_id), class = c("ledgr_sweep_not_found", "ledgr_invalid_args"))
  }
  row
}

ledgr_sweep_fetch_candidates <- function(con, sweep_id) {
  rows <- DBI::dbGetQuery(
    con,
    "SELECT * FROM sweep_candidates WHERE sweep_id = ? ORDER BY candidate_row",
    params = list(sweep_id)
  )
  if (nrow(rows) == 0L) {
    rlang::abort(
      sprintf("Saved sweep '%s' has no candidate rows.", sweep_id),
      class = c("ledgr_sweep_schema_incompatible", "ledgr_invalid_store")
    )
  }
  rows
}

ledgr_sweep_fetch_returns <- function(con, sweep_id, candidates) {
  returns <- DBI::dbGetQuery(
    con,
    "
    SELECT r.*, c.candidate_id
    FROM sweep_returns r
    INNER JOIN sweep_candidates c
      ON r.sweep_id = c.sweep_id
     AND r.candidate_row = c.candidate_row
    WHERE r.sweep_id = ?
    ORDER BY r.candidate_row, r.pulse_index
    ",
    params = list(sweep_id)
  )
  if (nrow(returns) == 0L) {
    return(ledgr_sweep_empty_returns(include_sweep_id = TRUE))
  }
  tibble::tibble(
    sweep_id = as.character(returns$sweep_id),
    candidate_id = as.character(returns$candidate_id),
    candidate_row = as.integer(returns$candidate_row),
    ts_utc = as.POSIXct(returns$ts_utc, tz = "UTC"),
    equity = as.numeric(returns$equity),
    period_return = as.numeric(returns$period_return)
  )
}

ledgr_sweep_fetch_universe <- function(con, snapshot_id) {
  rows <- DBI::dbGetQuery(
    con,
    "SELECT instrument_id FROM snapshot_instruments WHERE snapshot_id = ? ORDER BY instrument_id",
    params = list(snapshot_id)
  )
  as.character(rows$instrument_id)
}

ledgr_sweep_reconstruct <- function(parent, candidates, returns, universe = character()) {
  parent <- parent[1, , drop = FALSE]
  out <- tibble::tibble(
    candidate_id = as.character(candidates$candidate_id),
    candidate_row = as.integer(candidates$candidate_row),
    status = as.character(candidates$status),
    final_equity = as.numeric(candidates$final_equity),
    total_return = as.numeric(candidates$total_return),
    annualized_return = as.numeric(candidates$annualized_return),
    volatility = as.numeric(candidates$volatility),
    sharpe_ratio = as.numeric(candidates$sharpe_ratio),
    max_drawdown = as.numeric(candidates$max_drawdown),
    n_trades = as.integer(candidates$n_trades),
    win_rate = as.numeric(candidates$win_rate),
    avg_trade = as.numeric(candidates$avg_trade),
    time_in_market = as.numeric(candidates$time_in_market),
    execution_seed = as.integer(candidates$execution_seed),
    error_class = as.character(candidates$error_class),
    error_msg = as.character(candidates$error_msg),
    params = lapply(candidates$params_json, ledgr_json_read_nested),
    feature_params = lapply(candidates$feature_params_json, ledgr_json_read_nested),
    warnings = lapply(candidates$warnings_json, ledgr_json_read_nested),
    feature_fingerprints = lapply(candidates$feature_fingerprints_json, ledgr_json_read_nested),
    provenance = lapply(candidates$provenance_json, ledgr_json_read_nested)
  )
  ledgr_sweep_validate_reconstructed_identity(parent, candidates, out)
  first_provenance <- ledgr_sweep_first_reconstructed_provenance(out)

  attr(out, "sweep_id") <- as.character(parent$sweep_id[[1]])
  attr(out, "snapshot_id") <- as.character(parent$snapshot_id[[1]])
  attr(out, "snapshot_hash") <- as.character(parent$snapshot_hash[[1]])
  attr(out, "scoring_range") <- ledgr_sweep_reconstructed_scoring_range(returns)
  attr(out, "universe") <- as.character(universe)
  attr(out, "master_seed") <- first_provenance$master_seed
  attr(out, "seed_contract") <- first_provenance$seed_contract
  attr(out, "metric_context") <- ledgr_json_read_nested(parent$metric_context_json[[1]])
  attr(out, "metric_context_hash") <- as.character(parent$metric_context_hash[[1]])
  attr(out, "metric_context_version") <- as.integer(parent$metric_context_version[[1]])
  attr(out, "cost_model_hash") <- as.character(parent$cost_model_hash[[1]])
  attr(out, "cost_plan_json") <- as.character(parent$cost_plan_json[[1]])
  attr(out, "strategy_hash") <- first_provenance$strategy_hash
  attr(out, "strategy_source_capture_method") <- NULL
  attr(out, "strategy_preflight") <- NULL
  attr(out, "feature_union_hash") <- as.character(parent$feature_union_hash[[1]])
  attr(out, "feature_engine_version") <- as.character(parent$feature_engine_version[[1]])
  attr(out, "candidate_features") <- ledgr_sweep_records_tibble(
    ledgr_json_read_nested(parent$candidate_features_json[[1]])
  )
  attr(out, "sweep_retention") <- ledgr_sweep_retention_from_json(parent$retention_json[[1]])
  attr(out, "execution_assumptions") <- ledgr_json_read_nested(parent$execution_assumptions_json[[1]])
  attr(out, "evaluation_scope") <- "exploratory"
  attr(out, "sweep_returns") <- returns
  attr(out, "saved_sweep") <- list(
    saved = TRUE,
    created_at_utc = as.POSIXct(parent$created_at_utc[[1]], tz = "UTC"),
    engine_version = as.character(parent$engine_version[[1]]),
    sweep_schema_version = as.integer(parent$sweep_schema_version[[1]]),
    note = ledgr_sweep_optional_chr(parent$note[[1]])
  )
  class(out) <- c("ledgr_saved_sweep_results", "ledgr_sweep_results", class(out))
  out
}

ledgr_sweep_first_reconstructed_provenance <- function(out) {
  for (provenance in out$provenance) {
    if (is.list(provenance)) {
      return(provenance)
    }
  }
  list()
}

ledgr_sweep_reconstructed_scoring_range <- function(returns) {
  if (!is.data.frame(returns) || nrow(returns) == 0L || !"ts_utc" %in% names(returns)) {
    return(NULL)
  }
  ts_utc <- as.POSIXct(returns$ts_utc, tz = "UTC")
  list(
    start = format(min(ts_utc, na.rm = TRUE), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    end = format(max(ts_utc, na.rm = TRUE), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
}

ledgr_sweep_validate_reconstructed_identity <- function(parent, candidates, out) {
  parent_metric_hash <- as.character(parent$metric_context_hash[[1]])
  parent_cost_hash <- as.character(parent$cost_model_hash[[1]])
  parent_cost_plan <- as.character(parent$cost_plan_json[[1]])
  for (i in seq_len(nrow(candidates))) {
    provenance <- out$provenance[[i]]
    if (!identical(as.character(candidates$feature_set_hash[[i]]), as.character(provenance$feature_set_hash))) {
      rlang::abort("Saved sweep candidate feature_set_hash does not match provenance.", class = c("ledgr_sweep_schema_incompatible", "ledgr_invalid_store"))
    }
    if (!identical(as.character(candidates$metric_context_hash[[i]]), parent_metric_hash)) {
      rlang::abort("Saved sweep candidate metric_context_hash does not match parent sweep.", class = c("ledgr_sweep_schema_incompatible", "ledgr_invalid_store"))
    }
    if (!identical(as.character(candidates$cost_model_hash[[i]]), parent_cost_hash)) {
      rlang::abort("Saved sweep candidate cost_model_hash does not match parent sweep.", class = c("ledgr_sweep_schema_incompatible", "ledgr_invalid_store"))
    }
    if (!is.null(provenance$cost_plan_json) &&
        !identical(ledgr_sweep_storage_json(provenance$cost_plan_json), ledgr_sweep_storage_json(parent_cost_plan))) {
      rlang::abort("Saved sweep candidate cost_plan_json does not match parent sweep.", class = c("ledgr_sweep_schema_incompatible", "ledgr_invalid_store"))
    }
  }
  invisible(TRUE)
}

ledgr_sweep_retention_from_json <- function(json) {
  record <- ledgr_json_read_nested(json)
  if (is.list(record) && is.character(record$returns) && length(record$returns) == 1L) {
    return(ledgr_sweep_retention(record$returns))
  }
  rlang::abort("Saved sweep retention_json is incompatible.", class = c("ledgr_sweep_schema_incompatible", "ledgr_invalid_store"))
}

ledgr_sweep_records_tibble <- function(records) {
  if (!is.list(records) || length(records) == 0L) {
    return(tibble::tibble())
  }
  record_names <- names(records[[1L]])
  if (is.null(record_names)) {
    rlang::abort(
      "Saved sweep record JSON is incompatible.",
      class = c("ledgr_sweep_schema_incompatible", "ledgr_invalid_store")
    )
  }
  out <- stats::setNames(vector("list", length(record_names)), record_names)
  for (name in record_names) {
    values <- lapply(records, function(record) record[[name]])
    scalar <- vapply(
      values,
      function(value) {
        is.null(value) || (is.atomic(value) && length(value) == 1L)
      },
      logical(1)
    )
    if (all(scalar)) {
      out[[name]] <- vapply(
        values,
        function(value) {
          if (is.null(value) || length(value) == 0L || is.na(value)) {
            return(NA_character_)
          }
          as.character(value[[1]])
        },
        character(1)
      )
    } else {
      out[[name]] <- values
    }
  }
  tibble::as_tibble(out)
}

ledgr_sweep_retention_returns_from_json <- function(json) {
  tryCatch(
    ledgr_sweep_retention_from_json(json)$returns,
    error = function(e) NA_character_
  )
}

ledgr_sweep_optional_chr <- function(x) {
  if (length(x) != 1L || is.na(x)) {
    return(NA_character_)
  }
  as.character(x)
}
