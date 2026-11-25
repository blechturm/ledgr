ledgr_feature_engine_version <- function() {
  # Feature-engine provenance (Cut 22 decision 5). The deparsed formals and
  # body of every ledgr helper whose code can change prepared feature values,
  # evidence planes, refusals or the prepared representation, from the run,
  # sweep, explicit precompute and pulse-inspection preparation roots
  # (substrate construction and calculation bounds included) and the emitted
  # built-in and adapter closures. Each helper is named here or in its feature
  # adapter's `bind` (R/feature-adapters.R; Cut 24); the helpers it calls
  # are bound by their own entries, never by a recursive walk. The census
  # (dev/feature_parity/census.csv) classifies every reached helper and proves
  # each row by replacement. Bound too: the fingerprint, determinism and JSON
  # helpers certification compares claimed identities with. Not bound: the
  # read-side helpers (the evidence decoders, the recomputing
  # single-definition read entry, the bar-history readers), which produce no
  # reusable prepared state, and substrate guards, fold facts and storage.
  bound <- c(
    # input mapping and treatment (substrate construction included)
    "ledgr_availability_read_table", "ledgr_availability_provider_data",
    "ledgr_availability_calendar", "ledgr_availability_stable_ids", "ledgr_history_price_fields",
    "ledgr_history_feature_fields", "ledgr_history_feature_inputs", "ledgr_history_feature_frame",
    "ledgr_history_feature_window", "ledgr_history_policy", "ledgr_history_policy_normalize",
    "ledgr_history_policy_identity", "ledgr_history_lifetime_segments",
    "ledgr_history_terminal_segments", "ledgr_bar_native_sessions",
    "ledgr_history_segments_materialize", "ledgr_history_substrate_fact_plane",
    "ledgr_history_substrate_expected_at", "ledgr_history_substrate_terminal_planes",
    "ledgr_history_substrate", "ledgr_history_substrate_for_experiment",
    "ledgr_history_substrate_bar_matrices", "ledgr_history_lifetime_resolve_applicable",
    "ledgr_history_segment_dictionary", "ledgr_history_segment_epoch_cells",
    "ledgr_history_segment_bind", "ledgr_history_epoch_start", "ledgr_history_observation_breaks",
    "ledgr_history_sparse_fact_segments", "ledgr_history_fact_segments_by_instrument",
    "ledgr_history_input_carry_calculation", "ledgr_history_input_carry",
    "ledgr_history_required_field_admission",
    "ledgr_precompute_fetch_bars_frame",
    # certification and declarations
    "canonical_json", "ledgr_canonical_json_encode", ".ledgr_json_cache_get",
    ".ledgr_json_cache_set", ".ledgr_json_cache_key", "ledgr_function_fingerprint",
    "ledgr_assert_indicator_fn_pure", "ledgr_assert_indicator_safe",
    "ledgr_are_params_deterministic", "ledgr_deparse_one", "ledgr_static_function_signature",
    "ledgr_determinism_forbidden_calls", "ledgr_stable_payload", "ledgr_indicator_source",
    "ledgr_new_parameterized_indicator", "ledgr_is_param_ref", "ledgr_contains_param_ref",
    "ledgr_abort_unsupported_param_placement", "ledgr_assert_no_param_refs",
    "ledgr_validate_direct_param_args", "ledgr_feature_def_fingerprint",
    "ledgr_duplicate_feature_ids", "ledgr_abort_duplicate_feature_ids",
    "ledgr_active_feature_fingerprint", "ledgr_feature_certify",
    "ledgr_feature_catalogue_candidates", "ledgr_feature_adapters", "ledgr_indicator_sources",
    "ledgr_ind_sma", "ledgr_ind_returns",
    "ledgr_indicator_builtin", "ledgr_ind_ema", "ledgr_ind_rsi", "ledgr_indicator_bar_fields",
    "ledgr_indicator_default_required_fields", "ledgr_feature_def_declarations",
    "ledgr_indicator_history_classes", "ledgr_indicator_apply_declarations",
    "ledgr_indicator_history_catalogue", "ledgr_indicator_abort_declaration",
    "ledgr_indicator_catalogue_index", "ledgr_indicator_catalogue_row",
    "ledgr_indicator_catalogue_declarations", "ledgr_indicator_apply_catalogue",
    "ledgr_indicator_normalize_required_fields", "ledgr_indicator_declare",
    "ledgr_indicator_fingerprint",
    "ledgr_indicator_capture_overrides", "ledgr_indicator",
    "ledgr_precompute_feature_def_from_indicator", "ledgr_precompute_unique_feature_defs",
    # calculation and output selection
    "ledgr_rolling_mean", "ledgr_bounded_ema_series", "ledgr_simple_rsi_series",
    "ledgr_call_feature_series_fn", "ledgr_call_feature_fn",
    "ledgr_normalize_feature_series_output", "ledgr_normalize_feature_scalar_output",
    "ledgr_strict_sma_series", "ledgr_history_feature_segment", "ledgr_history_feature_segment_general",
    "ledgr_history_feature_calculate",
    "ledgr_history_compute_feature_series", "ledgr_history_output_carry",
    # bounds and ranges
    "ledgr_history_feature_runs", "ledgr_history_feature_terminal_breaks",
    "ledgr_history_feature_ranges", "ledgr_history_feature_bounds", "ledgr_history_utc",
    "ledgr_history_calculation_start", "ledgr_history_axis_lower_bound",
    # causality and refusals
    "ledgr_history_feature_refuse_parity", "ledgr_history_feature_causality_positions",
    "ledgr_history_feature_inputs_prefix", "ledgr_history_feature_causality",
    "ledgr_history_feature_check_definition", "ledgr_history_feature_refuse_lookahead",
    # planes
    "ledgr_feature_plane_fields", "ledgr_feature_plane_chunks", "ledgr_feature_plane_exceptions",
    "ledgr_feature_plane_records", "ledgr_projection_index_planes",
    # prepared representation
    "ledgr_history_precompute_payload", "ledgr_precompute_feature_union",
    "ledgr_precompute_available_counts", "ledgr_precompute_warmup_table",
    "ledgr_precompute_history_axis", "ledgr_normalize_ts_utc", "ledgr_runtime_projection",
    "ledgr_projection_pulse_names", "ledgr_projection_from_feature_matrix",
    "ledgr_projection_from_payload"
  )
  bound <- unique(c(bound, unlist(lapply(ledgr_feature_adapters(), function(adapter) adapter$bind),
                                  use.names = FALSE)))
  code <- lapply(mget(bound, envir = environment(), inherits = TRUE), function(fn) {
    c(ledgr_deparse_one(formals(fn)), ledgr_deparse_one(body(fn)))
  })
  digest::digest(canonical_json(list(
    namespace = "ledgr-feature-engine-v2",
    history_rule_version = ledgr_feature_history_rule_version,
    substrate_version = ledgr_history_substrate_version,
    code = code
  )), algo = "sha256")
}

# Canonical feature identity under rule 5: the base fingerprint
# (functions, captures, id, requires_bars, stable_after and params, which
# carry the TTR version and algorithm arguments) plus every calculation-
# affecting history declaration. Declaration provenance is display-only.
ledgr_active_feature_fingerprint <- function(feature_def) {
  base <- feature_def$fingerprint
  if (is.null(base)) base <- ledgr_feature_def_fingerprint(feature_def)
  declarations <- ledgr_feature_def_declarations(feature_def)
  digest::digest(
    canonical_json(list(
      schema = "ledgr_active_feature_v2",
      base_fingerprint = as.character(base),
      history_rule_version = ledgr_feature_history_rule_version,
      history_class = declarations$history_class,
      gap_behavior = declarations$gap_behavior,
      required_fields = declarations$required_fields,
      input_carry = declarations$input_carry,
      tolerance = declarations$tolerance,
      history_semantics = "expected_sessions_cutoff_causal"
    )),
    algo = "sha256"
  )
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
      include_captures = TRUE,
      label = sprintf("feature `%s` fn", feature_def$id)
    ),
    series_fn = if (is.null(feature_def$series_fn)) {
      NULL
    } else {
      ledgr_function_fingerprint(
        feature_def$series_fn,
        include_captures = TRUE,
        label = sprintf("feature `%s` series_fn", feature_def$id)
      )
    },
    requires_bars = as.integer(feature_def$requires_bars),
    stable_after = as.integer(feature_def$stable_after),
    params = ledgr_stable_payload(feature_def$params, sprintf("feature `%s` params", feature_def$id))
  )

  digest::digest(canonical_json(payload), algo = "sha256")
}

ledgr_duplicate_feature_ids <- function(ids) {
  ids <- as.character(ids)
  unique(ids[!is.na(ids) & nzchar(ids) & duplicated(ids)])
}

ledgr_abort_duplicate_feature_ids <- function(ids) {
  duplicates <- ledgr_duplicate_feature_ids(ids)
  if (length(duplicates) == 0L) {
    return(invisible(TRUE))
  }
  rlang::abort(
    sprintf(
      "Duplicate feature IDs are not allowed: %s. Use unique feature IDs or bundle prefixes; for parameterized feature sweeps, prefer active aliases with `ledgr_feature_grid()` and `ledgr_grid_cross()`.",
      paste(duplicates, collapse = ", ")
    ),
    class = c("ledgr_duplicate_feature_id", "ledgr_invalid_feature_def")
  )
}

ledgr_rolling_mean <- function(x, n) {
  x <- as.numeric(x)
  n <- as.integer(n)
  out <- rep(NA_real_, length(x))
  if (length(x) < n) return(out)
  cs <- c(0, cumsum(x))
  idx <- n:length(x)
  out[idx] <- (cs[idx + 1L] - cs[idx - n + 1L]) / n
  out
}

ledgr_bounded_ema_series <- function(x, n) {
  x <- as.numeric(x)
  n <- as.integer(n)
  stable_after <- n + 1L
  out <- rep(NA_real_, length(x))
  if (length(x) < stable_after) return(out)

  alpha <- 2 / (n + 1)
  decay <- 1 - alpha
  weights <- c(
    alpha * decay^(0:(stable_after - 2L)),
    decay^(stable_after - 1L)
  )
  out <- as.numeric(stats::filter(x, filter = weights, sides = 1))
  out[seq_len(stable_after - 1L)] <- NA_real_
  out
}

ledgr_simple_rsi_series <- function(x, n) {
  x <- as.numeric(x)
  n <- as.integer(n)
  out <- rep(NA_real_, length(x))
  stable_after <- n + 1L
  if (length(x) < stable_after) return(out)

  changes <- diff(x)
  gains <- pmax(changes, 0)
  losses <- abs(pmin(changes, 0))
  avg_gain <- ledgr_rolling_mean(gains, n)
  avg_loss <- ledgr_rolling_mean(losses, n)

  idx <- stable_after:length(x)
  gain <- avg_gain[idx - 1L]
  loss <- avg_loss[idx - 1L]
  out[idx] <- ifelse(loss == 0, 100, 100 - (100 / (1 + gain / loss)))
  out
}

ledgr_call_feature_series_fn <- function(series_fn, bars_df, params) {
  if (length(formals(series_fn)) >= 2L) series_fn(bars_df, params) else series_fn(bars_df)
}

ledgr_call_feature_fn <- function(fn, bars_df, params) {
  if (length(formals(fn)) >= 2L) fn(bars_df, params) else fn(bars_df)
}

ledgr_normalize_feature_series_output <- function(value, expected_n, stable_after, feature_id) {
  if (!is.numeric(value) || !is.atomic(value) || !is.null(dim(value))) {
    rlang::abort(sprintf("Feature %s returned a non-numeric or non-vector series.", feature_id), class = "ledgr_invalid_feature_output")
  }
  if (length(value) != expected_n) {
    rlang::abort(
      sprintf("Feature %s returned %d values; expected %d.", feature_id, length(value), expected_n),
      class = "ledgr_invalid_feature_output"
    )
  }

  value <- as.numeric(value)
  stable_after <- as.integer(stable_after)
  idx <- seq_along(value)
  non_warmup <- idx >= stable_after
  if (any(is.infinite(value) & non_warmup)) {
    rlang::abort(sprintf("Feature %s returned infinite values.", feature_id), class = "ledgr_invalid_feature_output")
  }
  if (any(is.nan(value) & non_warmup)) {
    rlang::abort(sprintf("Feature %s returned NaN outside the warmup period.", feature_id), class = "ledgr_invalid_feature_output")
  }
  if (any(is.na(value) & !is.nan(value) & non_warmup)) {
    rlang::abort(sprintf("Feature %s returned NA outside the warmup period.", feature_id), class = "ledgr_invalid_feature_output")
  }
  value[is.nan(value)] <- NA_real_
  if (stable_after > 1L && length(value) > 0L) {
    value[seq_len(min(stable_after - 1L, length(value)))] <- NA_real_
  }
  value
}

ledgr_normalize_feature_scalar_output <- function(value, feature_id) {
  if (is.null(value) || length(value) < 1L) return(NA_real_)
  if (length(value) > 1L) value <- value[[length(value)]]
  if (!is.numeric(value) || length(value) != 1L) {
    rlang::abort(sprintf("Feature %s returned a non-numeric or non-scalar value.", feature_id), class = "ledgr_invalid_feature_output")
  }
  if (is.nan(value) || (!is.na(value) && !is.finite(value))) {
    rlang::abort(sprintf("Feature %s returned a non-finite value.", feature_id), class = "ledgr_invalid_feature_output")
  }
  as.numeric(value)
}

ledgr_strict_sma_series <- function(values, width) {
  values <- as.numeric(values)
  width <- as.integer(width)
  out <- rep(NA_real_, length(values))
  if (length(values) < width) return(out)
  ends <- seq.int(width, length(values))
  # Exact parity is the contract here. R's mean() may use a correction pass
  # and platform-specific extended precision, while rowMeans(embed()) changes
  # summation order. Retain one numeric slice per bounded window so this path
  # is bit-identical to the scalar mean(window$close) oracle.
  out[ends] <- vapply(ends, function(i) {
    mean(values[seq.int(i - width + 1L, i)])
  }, numeric(1))
  out
}
