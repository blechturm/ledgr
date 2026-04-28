ledgr_strategy_extract_parse_json <- function(json, empty = list(), label = "JSON") {
  if (is.null(json) || length(json) != 1L || is.na(json) || !nzchar(json)) {
    return(empty)
  }
  tryCatch(
    jsonlite::fromJSON(json, simplifyVector = TRUE, simplifyDataFrame = FALSE, simplifyMatrix = FALSE),
    error = function(e) {
      rlang::abort(sprintf("Stored %s could not be parsed.", label), class = "ledgr_invalid_run", parent = e)
    }
  )
}

ledgr_strategy_extract_fetch <- function(con, run_id, snapshot_id = NULL) {
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
  provenance_join <- ledgr_run_store_optional_join(con, "run_provenance", "p", "p.run_id = r.run_id")
  where <- "r.run_id = ?"
  params <- list(run_id)
  if (!is.null(snapshot_id) && "snapshot_id" %in% runs_cols) {
    where <- paste(where, "AND r.snapshot_id = ?")
    params <- c(params, list(snapshot_id))
  }

  sql <- sprintf(
    "
    SELECT
      r.run_id,
      %s AS status,
      %s AS strategy_type,
      %s AS strategy_source,
      %s AS strategy_source_hash,
      %s AS strategy_source_capture_method,
      %s AS strategy_params_json,
      %s AS strategy_params_hash,
      COALESCE(%s, 'legacy') AS reproducibility_level,
      %s AS ledgr_version,
      %s AS R_version,
      %s AS dependency_versions_json
    FROM runs r
    %s
    WHERE %s
    ",
    run_expr("status"),
    prov_expr("strategy_type"),
    prov_expr("strategy_source"),
    prov_expr("strategy_source_hash"),
    prov_expr("strategy_source_capture_method"),
    prov_expr("strategy_params_json"),
    prov_expr("strategy_params_hash"),
    prov_expr("reproducibility_level"),
    prov_expr("ledgr_version"),
    prov_expr("R_version"),
    prov_expr("dependency_versions_json"),
    provenance_join,
    where
  )
  tibble::as_tibble(DBI::dbGetQuery(con, sql, params = params))
}

ledgr_strategy_source_available <- function(source) {
  is.character(source) && length(source) == 1L && !is.na(source) && nzchar(source)
}

ledgr_strategy_extract_warnings <- function(row, source_available) {
  warnings <- character()
  level <- row$reproducibility_level[[1]]
  capture_method <- row$strategy_source_capture_method[[1]]

  if (!isTRUE(source_available) || identical(capture_method, "legacy_pre_provenance")) {
    warnings <- c(warnings, "No stored strategy source is available for this legacy/pre-provenance run.")
  }
  if (!is.na(level) && nzchar(level) && !level %in% c("tier_1", "legacy")) {
    warnings <- c(
      warnings,
      sprintf(
        "This run is %s; recovered source may depend on external state or not be executable by itself.",
        level
      )
    )
  }
  warnings
}

#' Extract stored strategy source for a run
#'
#' Inspects strategy provenance stored in a ledgr experiment store. By default
#' this function returns source text and metadata only. It does not parse,
#' evaluate, or execute the stored source unless `trust = TRUE`. Stored source
#' hash mismatches abort in all modes because a mismatch means the stored
#' artifact is corrupt.
#'
#' @param snapshot A sealed `ledgr_snapshot` object. Use
#'   `ledgr_snapshot_load(db_path, snapshot_id)` to resume from a durable
#'   DuckDB file in a new R session.
#' @param run_id Run identifier.
#' @param trust Logical scalar. If `FALSE`, return source text and metadata
#'   only. If `TRUE`, verify the stored source hash before parsing/evaluating
#'   the source into a function object. Hash verification proves stored-text
#'   identity, not safety. Stored source hash mismatches abort even when
#'   `trust = FALSE`.
#'
#' @return A `ledgr_extracted_strategy` object, a list with fields:
#' \describe{
#'   \item{run_id}{Run identifier.}
#'   \item{strategy_source_text}{Stored strategy source text, or `NA` if no
#'   source is available.}
#'   \item{strategy_source_hash}{Stored source hash, or `NA` if unavailable.}
#'   \item{strategy_params}{Decoded strategy parameter list.}
#'   \item{strategy_params_hash}{Stored strategy parameter hash.}
#'   \item{reproducibility_level}{Stored reproducibility tier.}
#'   \item{strategy_type}{Stored strategy type.}
#'   \item{strategy_source_capture_method}{How source was captured.}
#'   \item{R_version}{R version recorded with the run.}
#'   \item{ledgr_version}{ledgr version recorded with the run.}
#'   \item{dependency_versions}{Decoded dependency-version metadata.}
#'   \item{trust}{Whether trusted recovery was requested.}
#'   \item{hash_verified}{Whether stored source matched its stored hash.}
#'   \item{warnings}{Character vector of provenance warnings.}
#'   \item{strategy_function}{Recovered function object. Present only when
#'   `trust = TRUE` succeeds.}
#' }
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
#' snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path)
#' strategy <- function(ctx, params) {
#'   targets <- ctx$flat()
#'   targets["AAA"] <- params$qty
#'   targets
#' }
#' bt <- ledgr_backtest(
#'   snapshot = snapshot, strategy = strategy, strategy_params = list(qty = 1),
#'   db_path = db_path
#' )
#' ledgr_extract_strategy(snapshot, bt$run_id)
#' close(bt)
#' @export
ledgr_extract_strategy <- function(snapshot, run_id, trust = FALSE) {
  if (!is.character(run_id) || length(run_id) != 1L || is.na(run_id) || !nzchar(run_id)) {
    rlang::abort("`run_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (!is.logical(trust) || length(trust) != 1L || is.na(trust)) {
    rlang::abort("`trust` must be TRUE or FALSE.", class = "ledgr_invalid_args")
  }

  db_path <- ledgr_run_store_snapshot_path(snapshot)
  snapshot_id <- ledgr_run_store_snapshot_id(snapshot)
  opened <- ledgr_run_store_open(db_path)
  on.exit(ledgr_run_store_close(opened), add = TRUE)
  row <- ledgr_strategy_extract_fetch(opened$con, run_id, snapshot_id = snapshot_id)
  if (nrow(row) != 1L) {
    rlang::abort(sprintf("Run not found: %s", run_id), class = "ledgr_run_not_found")
  }

  source <- row$strategy_source[[1]]
  source_available <- ledgr_strategy_source_available(source)
  stored_hash <- row$strategy_source_hash[[1]]
  hash_available <- is.character(stored_hash) && length(stored_hash) == 1L && !is.na(stored_hash) && nzchar(stored_hash)
  hash_verified <- FALSE
  if (source_available && hash_available) {
    computed_hash <- digest::digest(source, algo = "sha256")
    if (!identical(computed_hash, stored_hash)) {
      rlang::abort(
        sprintf("Stored strategy source hash mismatch for run '%s'.", run_id),
        class = "ledgr_strategy_hash_mismatch"
      )
    }
    hash_verified <- TRUE
  }

  warnings <- ledgr_strategy_extract_warnings(row, source_available)
  if (source_available && !hash_available) {
    warnings <- c(warnings, "Stored strategy source has no hash; source identity cannot be verified.")
  }

  out <- list(
    run_id = run_id,
    strategy_source_text = if (source_available) source else NA_character_,
    strategy_source_hash = if (hash_available) stored_hash else NA_character_,
    strategy_params = ledgr_strategy_extract_parse_json(row$strategy_params_json[[1]], empty = list(), label = "strategy_params_json"),
    strategy_params_hash = row$strategy_params_hash[[1]],
    reproducibility_level = row$reproducibility_level[[1]],
    strategy_type = row$strategy_type[[1]],
    strategy_source_capture_method = row$strategy_source_capture_method[[1]],
    R_version = row$R_version[[1]],
    ledgr_version = row$ledgr_version[[1]],
    dependency_versions = ledgr_strategy_extract_parse_json(row$dependency_versions_json[[1]], empty = list(), label = "dependency_versions_json"),
    trust = isTRUE(trust),
    hash_verified = isTRUE(hash_verified),
    warnings = warnings
  )

  if (isTRUE(trust)) {
    if (!source_available) {
      rlang::abort(
        sprintf("Run '%s' has no stored strategy source to recover.", run_id),
        class = "ledgr_strategy_source_unavailable"
      )
    }
    if (!isTRUE(hash_verified)) {
      rlang::abort(
        sprintf("Run '%s' strategy source could not be hash verified.", run_id),
        class = "ledgr_strategy_hash_unverified"
      )
    }
    expr <- tryCatch(
      parse(text = source, keep.source = FALSE),
      error = function(e) {
        rlang::abort(sprintf("Stored strategy source for run '%s' could not be parsed.", run_id), class = "ledgr_strategy_parse_failed", parent = e)
      }
    )
    if (length(expr) != 1L) {
      rlang::abort(sprintf("Stored strategy source for run '%s' must parse to exactly one expression.", run_id), class = "ledgr_strategy_parse_failed")
    }
    fn <- tryCatch(
      eval(expr[[1]], envir = new.env(parent = baseenv())),
      error = function(e) {
        rlang::abort(sprintf("Stored strategy source for run '%s' could not be evaluated as a function.", run_id), class = "ledgr_strategy_eval_failed", parent = e)
      }
    )
    if (!is.function(fn)) {
      rlang::abort(sprintf("Stored strategy source for run '%s' did not evaluate to a function.", run_id), class = "ledgr_strategy_not_function")
    }
    out$strategy_function <- fn
  }

  structure(out, class = c("ledgr_extracted_strategy", "list"))
}

#' Print extracted strategy metadata
#'
#' @param x A `ledgr_extracted_strategy` object.
#' @param ... Unused.
#' @return Invisibly returns `x`.
#' @export
print.ledgr_extracted_strategy <- function(x, ...) {
  value <- function(name, default = "NA") {
    val <- x[[name]]
    if (is.null(val) || length(val) == 0L || is.na(val[[1]])) return(default)
    as.character(val[[1]])
  }
  cat("ledgr Extracted Strategy\n")
  cat("========================\n\n")
  cat("Run ID:          ", value("run_id"), "\n", sep = "")
  cat("Reproducibility: ", value("reproducibility_level"), "\n", sep = "")
  cat("Source Hash:     ", value("strategy_source_hash"), "\n", sep = "")
  cat("Params Hash:     ", value("strategy_params_hash"), "\n", sep = "")
  cat("Hash Verified:   ", value("hash_verified", "FALSE"), "\n", sep = "")
  cat("Trust:           ", value("trust", "FALSE"), "\n", sep = "")
  cat("Source Available:", if (is.na(x$strategy_source_text[[1]])) "FALSE" else "TRUE", "\n", sep = "")
  if (!is.null(x$strategy_function)) {
    cat("Function:        recovered\n")
  }
  if (length(x$warnings) > 0L) {
    cat("\nWarnings:\n")
    for (warning in x$warnings) cat("- ", warning, "\n", sep = "")
  }
  invisible(x)
}
