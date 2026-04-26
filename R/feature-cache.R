.ledgr_feature_cache_registry <- new.env(parent = emptyenv())

ledgr_feature_engine_version <- function() {
  # Cache correctness depends on this payload. MUST include every feature-engine
  # helper whose semantics can change cached feature values.
  payload <- list(
    namespace = "v0.1.4-feature-engine",
    compute_series = ledgr_function_fingerprint(
      ledgr_compute_feature_series,
      include_captures = FALSE,
      label = "`ledgr_compute_feature_series()`"
    ),
    normalize_series = ledgr_function_fingerprint(
      ledgr_normalize_feature_series_output,
      include_captures = FALSE,
      label = "`ledgr_normalize_feature_series_output()`"
    ),
    call_series_fn = ledgr_function_fingerprint(
      ledgr_call_feature_series_fn,
      include_captures = FALSE,
      label = "`ledgr_call_feature_series_fn()`"
    ),
    call_fn = ledgr_function_fingerprint(
      ledgr_call_feature_fn,
      include_captures = FALSE,
      label = "`ledgr_call_feature_fn()`"
    )
  )
  digest::digest(canonical_json(payload), algo = "sha256")
}

#' Clear the session feature cache
#'
#' Clears feature series cached in the current R session. The cache is keyed by
#' snapshot hash, instrument, indicator fingerprint, feature-engine version, and
#' requested date range. It is never persisted to DuckDB.
#'
#' @return The number of cache entries removed, invisibly.
#' @examples
#' ledgr_clear_feature_cache()
#' @export
ledgr_clear_feature_cache <- function() {
  keys <- ls(.ledgr_feature_cache_registry, all.names = TRUE)
  if (length(keys) > 0) {
    rm(list = keys, envir = .ledgr_feature_cache_registry)
  }
  invisible(length(keys))
}

ledgr_feature_def_fingerprint <- function(feature_def) {
  if (!is.null(feature_def$fingerprint) &&
      is.character(feature_def$fingerprint) &&
      length(feature_def$fingerprint) == 1L &&
      !is.na(feature_def$fingerprint) &&
      nzchar(feature_def$fingerprint)) {
    return(feature_def$fingerprint)
  }

  payload <- list(
    id = feature_def$id,
    fn = ledgr_function_fingerprint(
      feature_def$fn,
      include_captures = FALSE,
      label = sprintf("feature `%s` fn", feature_def$id)
    ),
    series_fn = if (is.null(feature_def$series_fn)) {
      NULL
    } else {
      ledgr_function_fingerprint(
        feature_def$series_fn,
        include_captures = FALSE,
        label = sprintf("feature `%s` series_fn", feature_def$id)
      )
    },
    requires_bars = as.integer(feature_def$requires_bars),
    stable_after = as.integer(feature_def$stable_after),
    params = ledgr_stable_payload(feature_def$params, sprintf("feature `%s` params", feature_def$id))
  )

  digest::digest(canonical_json(payload), algo = "sha256")
}

ledgr_feature_cache_key <- function(snapshot_hash,
                                    instrument_id,
                                    feature_def,
                                    start_ts_utc,
                                    end_ts_utc) {
  if (!is.character(snapshot_hash) || length(snapshot_hash) != 1L || is.na(snapshot_hash) || !nzchar(snapshot_hash)) {
    return(NULL)
  }
  payload <- list(
    snapshot_hash = snapshot_hash,
    instrument_id = instrument_id,
    indicator_fingerprint = ledgr_feature_def_fingerprint(feature_def),
    feature_engine_version = ledgr_feature_engine_version(),
    start_ts_utc = ledgr_normalize_ts_utc(start_ts_utc),
    end_ts_utc = ledgr_normalize_ts_utc(end_ts_utc)
  )
  digest::digest(canonical_json(payload), algo = "sha256")
}

ledgr_feature_cache_get <- function(key, expected_len) {
  if (is.null(key) || !exists(key, envir = .ledgr_feature_cache_registry, inherits = FALSE)) {
    return(NULL)
  }
  values <- get(key, envir = .ledgr_feature_cache_registry, inherits = FALSE)
  if (!is.numeric(values) || length(values) != expected_len) {
    rm(list = key, envir = .ledgr_feature_cache_registry)
    return(NULL)
  }
  as.numeric(values)
}

ledgr_feature_cache_set <- function(key, values) {
  if (is.null(key)) return(invisible(FALSE))
  assign(key, as.numeric(values), envir = .ledgr_feature_cache_registry)
  invisible(TRUE)
}
