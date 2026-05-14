#' Precompute feature payloads for a parameter grid
#'
#' `ledgr_precompute_features()` resolves the feature definitions required by a
#' parameter grid, deduplicates identical indicators by fingerprint, computes
#' their series once against a sealed snapshot, and returns a typed payload for
#' future sweep execution.
#'
#' @param exp A `ledgr_experiment` object.
#' @param param_grid A `ledgr_param_grid` object.
#' @param start Optional scoring-range start. Defaults to the snapshot start.
#' @param end Optional scoring-range end. Defaults to the snapshot end.
#' @return A `ledgr_precomputed_features` object.
#' @examples
#' bars <- data.frame(
#'   ts_utc = as.POSIXct("2020-01-01", tz = "UTC") + 86400 * 0:4,
#'   instrument_id = "AAA",
#'   open = 100:104,
#'   high = 101:105,
#'   low = 99:103,
#'   close = 100:104,
#'   volume = 1000
#' )
#' snapshot <- ledgr_snapshot_from_df(bars)
#' strategy <- function(ctx, params) ctx$flat()
#' exp <- ledgr_experiment(snapshot, strategy, features = list(ledgr_ind_sma(2)))
#' grid <- ledgr_param_grid(list(qty = 1), list(qty = 2))
#' features <- ledgr_precompute_features(exp, grid)
#' print(features)
#' ledgr_snapshot_close(snapshot)
#' @export
ledgr_precompute_features <- function(exp, param_grid, start = NULL, end = NULL) {
  if (!inherits(exp, "ledgr_experiment")) {
    rlang::abort("`exp` must be a ledgr_experiment object.", class = "ledgr_invalid_args")
  }
  if (!inherits(param_grid, "ledgr_param_grid")) {
    rlang::abort("`param_grid` must be a ledgr_param_grid object.", class = "ledgr_invalid_args")
  }

  meta <- ledgr_precompute_snapshot_meta(exp$snapshot)
  range <- ledgr_precompute_scoring_range(meta, start = start, end = end)
  bars_by_id <- ledgr_precompute_fetch_bars(exp$snapshot, exp$universe, range$warmup_start, range$scoring_end)
  scoring_bars_by_id <- ledgr_precompute_fetch_bars(exp$snapshot, exp$universe, range$scoring_start, range$scoring_end)
  ledgr_precompute_validate_static_coverage(scoring_bars_by_id, exp$universe)

  resolved <- ledgr_precompute_resolve_grid(exp, param_grid)
  unique_defs <- ledgr_precompute_unique_feature_defs(resolved$candidates)
  payload <- ledgr_precompute_payload(unique_defs, bars_by_id)
  warmup <- ledgr_precompute_warmup_table(resolved$candidates, bars_by_id, range$scoring_start)

  out <- list(
    snapshot_id = exp$snapshot$snapshot_id,
    snapshot_hash = meta$snapshot_hash,
    universe = exp$universe,
    scoring_range = list(start = range$scoring_start, end = range$scoring_end),
    warmup_range = list(start = range$warmup_start, end = range$scoring_start),
    feature_engine_version = ledgr_feature_engine_version(),
    grid_labels = param_grid$labels,
    feature_union = ledgr_precompute_feature_union(unique_defs),
    candidate_features = resolved$candidate_features,
    warmup = warmup,
    payload = payload
  )
  structure(out, class = c("ledgr_precomputed_features", "list"))
}

#' @export
print.ledgr_precomputed_features <- function(x, ...) {
  if (!inherits(x, "ledgr_precomputed_features")) {
    rlang::abort("`x` must be a ledgr_precomputed_features object.", class = "ledgr_invalid_args")
  }
  cat("ledgr_precomputed_features\n")
  cat("===========================\n")
  cat("Snapshot:   ", x$snapshot_id, "\n", sep = "")
  cat("Candidates: ", length(x$grid_labels), "\n", sep = "")
  cat("Features:   ", nrow(x$feature_union), "\n", sep = "")
  cat("Universe:   ", paste(x$universe, collapse = ", "), "\n", sep = "")
  cat("Scoring:    ", x$scoring_range$start, " to ", x$scoring_range$end, "\n", sep = "")
  invisible(x)
}

ledgr_validate_precomputed_features <- function(precomputed,
                                                exp,
                                                param_grid,
                                                start = NULL,
                                                end = NULL,
                                                resolve_features = TRUE) {
  if (!inherits(precomputed, "ledgr_precomputed_features")) {
    rlang::abort("`precomputed_features` must be a ledgr_precomputed_features object.", class = "ledgr_invalid_precomputed_features")
  }
  if (!inherits(exp, "ledgr_experiment")) {
    rlang::abort("`exp` must be a ledgr_experiment object.", class = "ledgr_invalid_args")
  }
  if (!inherits(param_grid, "ledgr_param_grid")) {
    rlang::abort("`param_grid` must be a ledgr_param_grid object.", class = "ledgr_invalid_args")
  }

  meta <- ledgr_precompute_snapshot_meta(exp$snapshot)
  range <- ledgr_precompute_scoring_range(meta, start = start, end = end)
  if (!identical(precomputed$snapshot_hash, meta$snapshot_hash)) {
    rlang::abort("`precomputed_features` was built for a different snapshot hash.", class = "ledgr_precomputed_snapshot_mismatch")
  }
  if (!identical(precomputed$universe, exp$universe)) {
    rlang::abort("`precomputed_features` universe does not match the experiment universe.", class = "ledgr_precomputed_universe_mismatch")
  }
  if (!identical(precomputed$scoring_range$start, range$scoring_start) ||
      !identical(precomputed$scoring_range$end, range$scoring_end)) {
    rlang::abort("`precomputed_features` scoring range does not match the requested sweep range.", class = "ledgr_precomputed_range_mismatch")
  }
  if (!identical(precomputed$grid_labels, param_grid$labels)) {
    rlang::abort("`precomputed_features` candidate labels do not match `param_grid`.", class = "ledgr_precomputed_grid_mismatch")
  }
  if (!identical(precomputed$feature_engine_version, ledgr_feature_engine_version())) {
    rlang::abort(
      "`precomputed_features` was built with a different feature engine version. Rerun ledgr_precompute_features().",
      class = "ledgr_precomputed_engine_mismatch"
    )
  }
  params_hashes <- vapply(
    param_grid$params,
    function(params) digest::digest(canonical_json(params), algo = "sha256"),
    character(1)
  )
  if (!identical(as.character(precomputed$candidate_features$params_hash), params_hashes)) {
    rlang::abort(
      "`precomputed_features` candidate parameter hashes do not match `param_grid`.",
      class = "ledgr_precomputed_feature_mismatch"
    )
  }

  if (!isTRUE(resolve_features)) {
    return(invisible(TRUE))
  }

  resolved <- ledgr_precompute_resolve_grid(exp, param_grid)
  required <- sort(unique(unlist(lapply(resolved$candidates, function(candidate) {
    vapply(candidate$feature_defs, ledgr_feature_def_fingerprint, character(1))
  }), use.names = FALSE)))
  available <- sort(unique(as.character(precomputed$feature_union$fingerprint)))
  missing <- setdiff(required, available)
  if (length(missing) > 0L) {
    rlang::abort(
      sprintf("`precomputed_features` does not cover required feature fingerprint(s): %s.", paste(missing, collapse = ", ")),
      class = "ledgr_precomputed_feature_mismatch"
    )
  }

  invisible(TRUE)
}

ledgr_warn_large_grid_without_precomputed_features <- function(param_grid, precomputed_features, threshold = 20L) {
  if (!inherits(param_grid, "ledgr_param_grid") || !is.null(precomputed_features)) {
    return(invisible(FALSE))
  }
  if (length(param_grid$params) > threshold) {
    rlang::warn(
      sprintf(
        "Parameter grid has %d combinations and no precomputed features. Use ledgr_precompute_features(exp, param_grid) to compute shared feature series once.",
        length(param_grid$params)
      ),
      class = "ledgr_missing_precomputed_features_warning"
    )
    return(invisible(TRUE))
  }
  invisible(FALSE)
}

ledgr_precompute_snapshot_meta <- function(snapshot) {
  ledgr_feature_contract_check_validate_snapshot(snapshot)
  info <- ledgr_snapshot_info(snapshot)
  snapshot_hash <- info$snapshot_hash[[1]]
  start <- info$start_date[[1]]
  end <- info$end_date[[1]]
  if (!is.character(snapshot_hash) || length(snapshot_hash) != 1L || is.na(snapshot_hash) || !nzchar(snapshot_hash)) {
    rlang::abort("`snapshot` must have a stored snapshot_hash.", class = "ledgr_invalid_snapshot")
  }
  if (!is.character(start) || length(start) != 1L || is.na(start) || !nzchar(start) ||
      !is.character(end) || length(end) != 1L || is.na(end) || !nzchar(end)) {
    rlang::abort("`snapshot` must provide start/end metadata.", class = "ledgr_invalid_snapshot")
  }
  list(snapshot_hash = snapshot_hash, start = ledgr_normalize_ts_utc(start), end = ledgr_normalize_ts_utc(end))
}

ledgr_precompute_scoring_range <- function(meta, start = NULL, end = NULL) {
  scoring_start <- if (is.null(start)) meta$start else iso_utc(start)
  scoring_end <- if (is.null(end)) meta$end else iso_utc(end)
  start_posix <- as.POSIXct(scoring_start, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
  end_posix <- as.POSIXct(scoring_end, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
  meta_start <- as.POSIXct(meta$start, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
  meta_end <- as.POSIXct(meta$end, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
  if (start_posix > end_posix) {
    rlang::abort("`start` must be <= `end`.", class = "ledgr_invalid_precompute_range")
  }
  if (start_posix < meta_start || end_posix > meta_end) {
    rlang::abort("Precompute scoring range must be inside the sealed snapshot range.", class = "ledgr_invalid_precompute_range")
  }
  list(scoring_start = scoring_start, scoring_end = scoring_end, warmup_start = meta$start)
}

ledgr_precompute_fetch_bars <- function(snapshot, universe, start, end) {
  con <- get_connection(snapshot)
  placeholders <- paste(rep("?", length(universe)), collapse = ", ")
  rows <- DBI::dbGetQuery(
    con,
    sprintf(
      "
      SELECT instrument_id, ts_utc, open, high, low, close, volume
      FROM snapshot_bars
      WHERE snapshot_id = ?
        AND instrument_id IN (%s)
        AND ts_utc >= ?
        AND ts_utc <= ?
      ORDER BY instrument_id, ts_utc
      ",
      placeholders
    ),
    params = c(list(snapshot$snapshot_id), as.list(universe), list(start, end))
  )
  if (nrow(rows) == 0L) {
    rlang::abort("No snapshot bars cover the requested precompute range.", class = "ledgr_precomputed_coverage_error")
  }
  rows$instrument_id <- as.character(rows$instrument_id)
  rows$ts_utc <- as.POSIXct(rows$ts_utc, tz = "UTC")
  split(rows, rows$instrument_id)
}

ledgr_precompute_validate_static_coverage <- function(bars_by_id, universe) {
  missing <- setdiff(universe, names(bars_by_id))
  if (length(missing) > 0L) {
    rlang::abort(
      sprintf("Precomputed feature scoring range is missing bars for instrument(s): %s.", paste(missing, collapse = ", ")),
      class = "ledgr_precomputed_coverage_error"
    )
  }
  pulses <- NULL
  for (id in universe) {
    bars <- bars_by_id[[id]]
    if (is.null(bars) || nrow(bars) == 0L) {
      rlang::abort(
        sprintf("Precomputed feature scoring range is missing bars for instrument: %s.", id),
        class = "ledgr_precomputed_coverage_error"
      )
    }
    ts <- ledgr_precompute_ts_key(bars$ts_utc)
    if (is.null(pulses)) {
      pulses <- ts
    } else if (!identical(ts, pulses)) {
      rlang::abort("Precomputed feature scoring range has incomplete or misaligned per-instrument bars.", class = "ledgr_precomputed_coverage_error")
    }
  }
  invisible(TRUE)
}

ledgr_precompute_ts_key <- function(x) {
  vapply(as.POSIXct(x, tz = "UTC"), ledgr_normalize_ts_utc, character(1))
}

ledgr_precompute_resolve_grid <- function(exp, param_grid) {
  resolved <- ledgr_resolve_feature_candidates(exp, param_grid, stop_on_error = TRUE)
  list(candidates = resolved$candidates, candidate_features = resolved$candidate_features)
}

ledgr_resolve_feature_candidates <- function(exp, param_grid, stop_on_error = FALSE) {
  if (!inherits(exp, "ledgr_experiment")) {
    rlang::abort("`exp` must be a ledgr_experiment object.", class = "ledgr_invalid_experiment")
  }
  if (!inherits(param_grid, "ledgr_param_grid")) {
    rlang::abort("`param_grid` must be a ledgr_param_grid object.", class = "ledgr_invalid_args")
  }
  if (!is.logical(stop_on_error) || length(stop_on_error) != 1L || is.na(stop_on_error)) {
    rlang::abort("`stop_on_error` must be TRUE or FALSE.", class = "ledgr_invalid_args")
  }

  candidates <- vector("list", length(param_grid$params))
  candidate_labels <- character(length(param_grid$params))
  params_hashes <- character(length(param_grid$params))
  statuses <- character(length(param_grid$params))
  error_classes <- character(length(param_grid$params))
  error_msgs <- character(length(param_grid$params))
  feature_ids <- vector("list", length(param_grid$params))
  feature_fingerprints <- vector("list", length(param_grid$params))
  feature_set_hashes <- character(length(param_grid$params))
  for (i in seq_along(param_grid$params)) {
    params <- param_grid$params[[i]]
    label <- param_grid$labels[[i]]
    candidate_labels[[i]] <- label
    params_hashes[[i]] <- ledgr_strategy_params_info(params)$hash
    resolved <- tryCatch(
      ledgr_resolve_candidate_features(exp, params, label),
      error = function(e) {
        if (isTRUE(stop_on_error)) {
          stop(e)
        }
        e
      }
    )
    if (inherits(resolved, "error")) {
      candidates[[i]] <- list(label = label, params = params, feature_defs = list(), fingerprints = character(), error = resolved)
      statuses[[i]] <- "failed"
      error_classes[[i]] <- ledgr_condition_class(resolved)
      error_msgs[[i]] <- conditionMessage(resolved)
      feature_ids[[i]] <- character()
      feature_fingerprints[[i]] <- character()
      feature_set_hashes[[i]] <- NA_character_
    } else {
      candidates[[i]] <- resolved
      statuses[[i]] <- "ok"
      error_classes[[i]] <- NA_character_
      error_msgs[[i]] <- NA_character_
      feature_ids[[i]] <- resolved$feature_ids
      feature_fingerprints[[i]] <- resolved$fingerprints
      feature_set_hashes[[i]] <- resolved$feature_set_hash
    }
  }
  list(
    candidates = candidates,
    candidate_features = tibble::tibble(
      candidate_label = candidate_labels,
      params_hash = params_hashes,
      status = statuses,
      error_class = error_classes,
      error_msg = error_msgs,
      feature_ids = feature_ids,
      feature_fingerprints = feature_fingerprints,
      feature_set_hash = feature_set_hashes
    )
  )
}

ledgr_resolve_candidate_features <- function(exp, params, candidate_label = NULL) {
  features <- ledgr_experiment_materialize_features(exp, params)
  feature_defs <- ledgr_precompute_feature_defs_from_indicators(features)
  fingerprints <- unname(vapply(feature_defs, ledgr_feature_def_fingerprint, character(1)))
  feature_ids <- unname(vapply(feature_defs, function(def) def$id, character(1)))
  list(
    label = candidate_label,
    params = params,
    feature_defs = feature_defs,
    feature_ids = feature_ids,
    fingerprints = fingerprints,
    feature_set_hash = ledgr_feature_set_hash(fingerprints)
  )
}

ledgr_feature_set_hash <- function(feature_fingerprints) {
  if (is.null(feature_fingerprints)) {
    feature_fingerprints <- character()
  }
  if (!is.character(feature_fingerprints) || anyNA(feature_fingerprints) || any(!nzchar(feature_fingerprints))) {
    rlang::abort("`feature_fingerprints` must be a character vector of non-empty strings.", class = "ledgr_invalid_args")
  }
  normalized <- sort(unique(unname(feature_fingerprints)))
  digest::digest(canonical_json(list(feature_fingerprints = normalized)), algo = "sha256")
}

ledgr_condition_class <- function(condition) {
  classes <- class(condition)
  classes <- classes[!classes %in% c("rlang_error", "error", "condition")]
  if (length(classes) < 1L) {
    return(class(condition)[[1]])
  }
  classes[[1]]
}

ledgr_precompute_feature_defs_from_indicators <- function(indicators) {
  if (!is.list(indicators) || length(indicators) < 1L) {
    return(list())
  }
  bad <- which(!vapply(indicators, inherits, logical(1), what = "ledgr_indicator"))
  if (length(bad) > 0L) {
    rlang::abort("Resolved features must be a list of ledgr_indicator objects.", class = "ledgr_invalid_experiment_features")
  }
  ids <- vapply(indicators, function(ind) ind$id, character(1))
  ledgr_abort_duplicate_feature_ids(ids)
  lapply(indicators, ledgr_precompute_feature_def_from_indicator)
}

ledgr_precompute_feature_def_from_indicator <- function(indicator) {
  list(
    id = indicator$id,
    fn = indicator$fn,
    series_fn = indicator$series_fn,
    requires_bars = indicator$requires_bars,
    stable_after = indicator$stable_after,
    source = ledgr_indicator_source(indicator),
    params = indicator$params,
    fingerprint = ledgr_indicator_fingerprint(indicator)
  )
}

ledgr_precompute_unique_feature_defs <- function(candidates) {
  by_fingerprint <- list()
  for (candidate in candidates) {
    for (def in candidate$feature_defs) {
      fingerprint <- ledgr_feature_def_fingerprint(def)
      if (is.null(by_fingerprint[[fingerprint]])) {
        by_fingerprint[[fingerprint]] <- def
      }
    }
  }
  by_fingerprint
}

ledgr_precompute_feature_union <- function(unique_defs) {
  if (length(unique_defs) == 0L) {
    return(tibble::tibble(
      feature_id = character(),
      fingerprint = character(),
      source = character(),
      requires_bars = integer(),
      stable_after = integer()
    ))
  }
  rows <- lapply(unique_defs, function(def) {
    tibble::tibble(
      feature_id = def$id,
      fingerprint = ledgr_feature_def_fingerprint(def),
      source = def$source,
      requires_bars = as.integer(def$requires_bars),
      stable_after = as.integer(def$stable_after)
    )
  })
  out <- tibble::as_tibble(do.call(rbind, rows))
  out[order(out$feature_id, out$fingerprint), , drop = FALSE]
}

ledgr_precompute_payload <- function(unique_defs, bars_by_id) {
  out <- list()
  for (fingerprint in names(unique_defs)) {
    def <- unique_defs[[fingerprint]]
    values <- lapply(bars_by_id, function(bars) ledgr_compute_feature_series(bars, def))
    out[[fingerprint]] <- list(
      feature_id = def$id,
      fingerprint = fingerprint,
      values = values
    )
  }
  out
}

ledgr_precompute_warmup_table <- function(candidates, bars_by_id, scoring_start) {
  rows <- list()
  row_idx <- 1L
  scoring_start_posix <- as.POSIXct(scoring_start, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
  for (candidate in candidates) {
    for (def in candidate$feature_defs) {
      fingerprint <- ledgr_feature_def_fingerprint(def)
      for (instrument_id in names(bars_by_id)) {
        bars <- bars_by_id[[instrument_id]]
        available <- sum(as.POSIXct(bars$ts_utc, tz = "UTC") <= scoring_start_posix)
        rows[[row_idx]] <- data.frame(
          candidate_label = candidate$label,
          instrument_id = instrument_id,
          feature_id = def$id,
          fingerprint = fingerprint,
          stable_after = as.integer(def$stable_after),
          available_bars_at_scoring_start = as.integer(available),
          warmup_achievable = isTRUE(available >= as.integer(def$stable_after)),
          stringsAsFactors = FALSE
        )
        row_idx <- row_idx + 1L
      }
    }
  }
  if (length(rows) == 0L) {
    return(tibble::tibble(
      candidate_label = character(),
      instrument_id = character(),
      feature_id = character(),
      fingerprint = character(),
      stable_after = integer(),
      available_bars_at_scoring_start = integer(),
      warmup_achievable = logical()
    ))
  }
  tibble::as_tibble(do.call(rbind, rows))
}
