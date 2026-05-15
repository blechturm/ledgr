ledgr_promotion_context_version <- "ledgr_promotion_v1"

ledgr_promote_write_context_or_warn <- function(bt, candidate, note = NULL) {
  tryCatch(
    {
      ledgr_write_promotion_context(bt, candidate, note = note)
      invisible(TRUE)
    },
    error = function(e) {
      rlang::warn(
        sprintf(
          "Committed run '%s' succeeded, but promotion context was not written: %s",
          bt$run_id,
          conditionMessage(e)
        ),
        class = "ledgr_promotion_context_write_failed"
      )
      invisible(FALSE)
    }
  )
}

ledgr_write_promotion_context <- function(bt, candidate, note = NULL) {
  if (!inherits(bt, "ledgr_backtest")) {
    rlang::abort("`bt` must be a ledgr_backtest object.", class = "ledgr_invalid_args")
  }
  if (!inherits(candidate, "ledgr_sweep_candidate")) {
    rlang::abort("`candidate` must be a ledgr_sweep_candidate object.", class = "ledgr_invalid_args")
  }

  opened <- ledgr_backtest_open(bt)
  con <- opened$con
  ledgr_create_schema(con)
  DBI::dbExecute(
    con,
    "
    INSERT OR REPLACE INTO run_promotion_context (
      run_id,
      promotion_context_version,
      source,
      promoted_at_utc,
      note,
      selected_candidate_json,
      source_sweep_json,
      candidate_summary_json
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ",
    params = list(
      bt$run_id,
      ledgr_promotion_context_version,
      "ledgr_promote",
      as.POSIXct(Sys.time(), tz = "UTC"),
      note %||% NA_character_,
      ledgr_selected_candidate_json(candidate),
      ledgr_source_sweep_json(candidate),
      ledgr_candidate_summary_json(candidate$selection_view)
    )
  )
  invisible(TRUE)
}

ledgr_selected_candidate_json <- function(candidate) {
  canonical_json(ledgr_candidate_summary_record(candidate$row[1, , drop = FALSE])[[1]])
}

ledgr_source_sweep_json <- function(candidate) {
  meta <- candidate$sweep_meta
  if (!is.list(meta)) {
    meta <- list()
  }
  canonical_json(list(
    sweep_id = meta$sweep_id,
    snapshot_id = meta$snapshot_id,
    snapshot_hash = meta$snapshot_hash %||% candidate$provenance$snapshot_hash,
    scoring_range = meta$scoring_range,
    universe = meta$universe,
    master_seed = meta$master_seed %||% candidate$provenance$master_seed,
    seed_contract = meta$seed_contract %||% candidate$provenance$seed_contract,
    evaluation_scope = meta$evaluation_scope %||% candidate$provenance$evaluation_scope,
    strategy_hash = meta$strategy_hash %||% candidate$provenance$strategy_hash,
    strategy_name = meta$strategy_name,
    strategy_source_capture_method = meta$strategy_source_capture_method,
    feature_union_hash = meta$feature_union_hash
  ))
}

ledgr_candidate_summary_json <- function(selection_view) {
  canonical_json(ledgr_candidate_summary_records(selection_view))
}

ledgr_candidate_summary_records <- function(selection_view) {
  view <- tibble::as_tibble(selection_view)
  if (nrow(view) < 1L) {
    return(list())
  }
  lapply(seq_len(nrow(view)), function(i) {
    ledgr_candidate_summary_record(view[i, , drop = FALSE])[[1]]
  })
}

ledgr_candidate_summary_record <- function(row) {
  list(list(
    run_id = ledgr_summary_scalar(row, "run_id", NULL),
    status = ledgr_summary_scalar(row, "status", NULL),
    final_equity = ledgr_summary_scalar(row, "final_equity", NULL),
    total_return = ledgr_summary_scalar(row, "total_return", NULL),
    annualized_return = ledgr_summary_scalar(row, "annualized_return", NULL),
    volatility = ledgr_summary_scalar(row, "volatility", NULL),
    sharpe_ratio = ledgr_summary_scalar(row, "sharpe_ratio", NULL),
    max_drawdown = ledgr_summary_scalar(row, "max_drawdown", NULL),
    n_trades = ledgr_summary_scalar(row, "n_trades", NULL),
    win_rate = ledgr_summary_scalar(row, "win_rate", NULL),
    avg_trade = ledgr_summary_scalar(row, "avg_trade", NULL),
    time_in_market = ledgr_summary_scalar(row, "time_in_market", NULL),
    execution_seed = ledgr_summary_scalar(row, "execution_seed", NULL),
    params_json = canonical_json(row$params[[1]]),
    provenance_json = canonical_json(row$provenance[[1]]),
    n_warnings = length(ledgr_summary_warnings(row)),
    warning_classes = ledgr_warning_classes(ledgr_summary_warnings(row)),
    error_class = ledgr_summary_scalar(row, "error_class", NULL),
    error_msg = ledgr_summary_scalar(row, "error_msg", NULL)
  ))
}

ledgr_summary_scalar <- function(row, column, default) {
  if (!column %in% names(row)) {
    return(default)
  }
  value <- row[[column]][[1]]
  if (length(value) == 0L) {
    return(default)
  }
  ledgr_json_safe_scalar(value, default)
}

ledgr_json_safe_scalar <- function(value, default) {
  if (is.numeric(value)) {
    value <- as.numeric(value)
    if (length(value) != 1L || is.na(value) || !is.finite(value)) {
      return(default)
    }
    if (!is.null(default) && is.integer(default)) {
      return(as.integer(value))
    }
    return(value)
  }
  if (is.character(value)) {
    if (length(value) != 1L || is.na(value)) {
      return(default)
    }
    return(value)
  }
  if (is.logical(value)) {
    if (length(value) != 1L || is.na(value)) {
      return(default)
    }
    return(value)
  }
  rlang::abort(
    sprintf("Unsupported candidate-summary scalar type: %s.", paste(class(value), collapse = "/")),
    class = "ledgr_invalid_promotion_context_summary"
  )
}

ledgr_summary_warnings <- function(row) {
  if (!"warnings" %in% names(row)) {
    return(list())
  }
  warnings <- row$warnings[[1]]
  if (is.null(warnings)) {
    return(list())
  }
  warnings
}

ledgr_warning_classes <- function(warnings) {
  classes <- unique(unlist(lapply(warnings, class), use.names = FALSE))
  sort(as.character(classes))
}

#' Read promotion context for a promoted run
#'
#' @param bt A `ledgr_backtest`.
#' @return Parsed promotion context, or `NULL` for direct runs.
#' @details
#' Promotion context is compact selection-audit metadata written by
#' [ledgr_promote()]. It stores the selected candidate, source sweep metadata,
#' and the filtered/sorted candidate-summary view used at selection time. It is
#' not a full sweep artifact and does not store full ledger rows or equity
#' curves for all candidates.
#'
#' @section Articles:
#' Exploratory sweeps and promotion:
#' `vignette("sweeps", package = "ledgr")`
#' `system.file("doc", "sweeps.html", package = "ledgr")`
#' @export
ledgr_promotion_context <- function(bt) {
  if (!inherits(bt, "ledgr_backtest")) {
    rlang::abort("`bt` must be a ledgr_backtest object.", class = "ledgr_invalid_args")
  }
  opened <- ledgr_backtest_read_connection(bt)
  on.exit(opened$close(), add = TRUE)
  ledgr_fetch_promotion_context(opened$con, bt$run_id)
}

#' Read promotion context from an experiment store
#'
#' @param exp A `ledgr_experiment`.
#' @param run_id Run identifier.
#' @return Parsed promotion context, or `NULL` for direct runs.
#' @details
#' Reads the same compact promotion context as [ledgr_promotion_context()] from
#' the experiment store without executing strategy code.
#'
#' @section Articles:
#' Exploratory sweeps and promotion:
#' `vignette("sweeps", package = "ledgr")`
#' `system.file("doc", "sweeps.html", package = "ledgr")`
#' @export
ledgr_run_promotion_context <- function(exp, run_id) {
  if (!inherits(exp, "ledgr_experiment")) {
    rlang::abort("`exp` must be a ledgr_experiment object.", class = "ledgr_invalid_args")
  }
  if (!is.character(run_id) || length(run_id) != 1L || is.na(run_id) || !nzchar(run_id)) {
    rlang::abort("`run_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  opened <- ledgr_run_store_open(exp$snapshot$db_path)
  on.exit(ledgr_run_store_close(opened), add = TRUE)
  ledgr_fetch_promotion_context(opened$con, run_id)
}

ledgr_fetch_promotion_context <- function(con, run_id) {
  ledgr_experiment_store_check_schema(con, write = FALSE)
  if (!ledgr_experiment_store_table_exists(con, "run_promotion_context")) {
    return(NULL)
  }
  row <- DBI::dbGetQuery(
    con,
    "
    SELECT *
    FROM run_promotion_context
    WHERE run_id = ?
    ",
    params = list(run_id)
  )
  if (nrow(row) == 0L) {
    return(NULL)
  }
  ledgr_parse_promotion_context(row[1, , drop = FALSE])
}

ledgr_parse_promotion_context <- function(row) {
  list(
    run_id = as.character(row$run_id[[1]]),
    promotion_context_version = as.character(row$promotion_context_version[[1]]),
    source = as.character(row$source[[1]]),
    promoted_at_utc = as.POSIXct(row$promoted_at_utc[[1]], tz = "UTC"),
    note = if (is.na(row$note[[1]])) NULL else as.character(row$note[[1]]),
    selected_candidate = ledgr_parse_candidate_summary_record(row$selected_candidate_json[[1]]),
    source_sweep = ledgr_parse_json_field(row$source_sweep_json[[1]]),
    candidate_summary = ledgr_parse_candidate_summary(row$candidate_summary_json[[1]])
  )
}

ledgr_parse_json_field <- function(json) {
  jsonlite::fromJSON(json, simplifyVector = FALSE)
}

ledgr_parse_candidate_summary <- function(json) {
  records <- ledgr_parse_json_field(json)
  lapply(records, ledgr_normalize_candidate_summary_record)
}

ledgr_parse_candidate_summary_record <- function(json) {
  ledgr_normalize_candidate_summary_record(ledgr_parse_json_field(json))
}

ledgr_normalize_candidate_summary_record <- function(record) {
  if (!is.null(record$warning_classes)) {
    record$warning_classes <- as.character(unlist(record$warning_classes, use.names = FALSE))
  }
  record
}
