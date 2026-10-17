ledgr_feature_engine_version <- function(availability_active = FALSE) {
  # Feature-engine provenance includes every helper whose semantics can change
  # computed feature values.
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
    compute_scalar_at = ledgr_function_fingerprint(
      ledgr_compute_feature_scalar_at,
      include_captures = FALSE,
      label = "`ledgr_compute_feature_scalar_at()`"
    ),
    normalize_scalar = ledgr_function_fingerprint(
      ledgr_normalize_feature_scalar_output,
      include_captures = FALSE,
      label = "`ledgr_normalize_feature_scalar_output()`"
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
  if (isTRUE(availability_active)) {
    helper <- function(fn, name) {
      ledgr_function_fingerprint(
        fn,
        include_captures = FALSE,
        label = sprintf("`%s()`", name)
      )
    }
    payload$availability <- list(
      semantics = "history_segments_v1",
      history_rule_version = ledgr_feature_history_rule_version,
      compute = helper(
        ledgr_history_compute_feature_series,
        "ledgr_history_compute_feature_series"
      ),
      certify = helper(ledgr_feature_certify, "ledgr_feature_certify"),
      candidates = helper(
        ledgr_feature_catalogue_candidates,
        "ledgr_feature_catalogue_candidates"
      ),
      catalogue = helper(
        ledgr_indicator_history_catalogue,
        "ledgr_indicator_history_catalogue"
      ),
      declarations = helper(ledgr_indicator_declare, "ledgr_indicator_declare"),
      admission = helper(
        ledgr_history_required_field_admission,
        "ledgr_history_required_field_admission"
      ),
      inputs = helper(ledgr_history_feature_inputs, "ledgr_history_feature_inputs"),
      input_carry = helper(ledgr_history_input_carry, "ledgr_history_input_carry"),
      output_carry = helper(ledgr_history_output_carry, "ledgr_history_output_carry"),
      ranges = helper(ledgr_history_feature_ranges, "ledgr_history_feature_ranges"),
      runs = helper(ledgr_history_feature_runs, "ledgr_history_feature_runs"),
      calculate = helper(
        ledgr_history_feature_calculate,
        "ledgr_history_feature_calculate"
      ),
      segment = helper(ledgr_history_feature_segment, "ledgr_history_feature_segment"),
      frame = helper(ledgr_history_feature_frame, "ledgr_history_feature_frame"),
      window = helper(ledgr_history_feature_window, "ledgr_history_feature_window"),
      strict_sma = helper(ledgr_strict_sma_series, "ledgr_strict_sma_series"),
      fingerprint = helper(
        ledgr_active_feature_fingerprint,
        "ledgr_active_feature_fingerprint"
      )
    )
  }
  digest::digest(canonical_json(payload), algo = "sha256")
}

# Availability-aware feature identity under rule 4: the dense fingerprint
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

ledgr_validate_feature_def <- function(feature_def) {
  if (!is.list(feature_def)) {
    rlang::abort("Each feature_def must be a list.", class = "ledgr_invalid_feature_def")
  }

  id <- feature_def$id
  if (!is.character(id) || length(id) != 1 || is.na(id) || !nzchar(id)) {
    rlang::abort("feature_def$id must be a non-empty character scalar.", class = "ledgr_invalid_feature_def")
  }

  requires_bars <- feature_def$requires_bars
  if (!is.numeric(requires_bars) || length(requires_bars) != 1 || is.na(requires_bars) || !is.finite(requires_bars) ||
    requires_bars < 1 || (requires_bars %% 1) != 0) {
    rlang::abort(
      sprintf("feature_def$requires_bars must be an integer >= 1 (feature: %s).", id),
      class = "ledgr_invalid_feature_def"
    )
  }

  stable_after <- feature_def$stable_after
  if (!is.numeric(stable_after) || length(stable_after) != 1 || is.na(stable_after) || !is.finite(stable_after) ||
    stable_after < requires_bars || (stable_after %% 1) != 0) {
    rlang::abort(
      sprintf("feature_def$stable_after must be an integer >= requires_bars (feature: %s).", id),
      class = "ledgr_invalid_feature_def"
    )
  }

  fn <- feature_def$fn
  if (!is.function(fn)) {
    rlang::abort(sprintf("feature_def$fn must be a function (feature: %s).", id), class = "ledgr_invalid_feature_def")
  }

  series_fn <- feature_def$series_fn
  if (!is.null(series_fn) && !is.function(series_fn)) {
    rlang::abort(sprintf("feature_def$series_fn must be NULL or a function (feature: %s).", id), class = "ledgr_invalid_feature_def")
  }

  params <- feature_def$params
  if (!is.null(params) && !is.list(params)) {
    rlang::abort(sprintf("feature_def$params must be a list (feature: %s).", id), class = "ledgr_invalid_feature_def")
  }

  if (is.null(params)) params <- list()

  gap_contract <- feature_def$gap_contract
  if (!is.null(gap_contract) && !identical(gap_contract, "strict_window")) {
    rlang::abort(
      sprintf("feature_def$gap_contract is unsupported (feature: %s).", id),
      class = "ledgr_invalid_feature_def"
    )
  }

  json_safe_def <- list(
    id = id,
    requires_bars = as.integer(requires_bars),
    stable_after = as.integer(stable_after),
    params = params
  )
  invisible(canonical_json(json_safe_def))

  invisible(TRUE)
}

ledgr_feature_sma_n <- function(n) {
  if (!is.numeric(n) || length(n) != 1 || is.na(n) || !is.finite(n) || n < 1 || (n %% 1) != 0) {
    rlang::abort("`n` must be an integer >= 1.", class = "ledgr_invalid_feature_def")
  }
  n <- as.integer(n)

  list(
    id = paste0("sma_", n),
    requires_bars = n,
    stable_after = n,
    fn = function(window_bars_df, params = list(n = n)) {
      closes <- window_bars_df$close
      if (!is.numeric(closes)) closes <- as.numeric(closes)
      mean(utils::tail(closes, params$n))
    },
    series_fn = function(bars_df, params = list(n = n)) {
      closes <- bars_df$close
      if (!is.numeric(closes)) closes <- as.numeric(closes)
      ledgr_rolling_mean(closes, as.integer(params$n))
    },
    params = list(n = n),
    gap_contract = "strict_window"
  )
}

ledgr_feature_return_1 <- function() {
  list(
    id = "return_1",
    requires_bars = 2L,
    stable_after = 2L,
    fn = function(window_bars_df) {
      closes <- window_bars_df$close
      if (!is.numeric(closes)) closes <- as.numeric(closes)
      if (length(closes) < 2) return(NA_real_)
      (closes[[length(closes)]] / closes[[length(closes) - 1L]]) - 1
    },
    series_fn = function(bars_df, params = list()) {
      closes <- bars_df$close
      if (!is.numeric(closes)) closes <- as.numeric(closes)
      out <- rep(NA_real_, length(closes))
      if (length(closes) >= 2L) {
        out[2:length(closes)] <- (closes[2:length(closes)] / closes[1:(length(closes) - 1L)]) - 1
      }
      out
    },
    params = list(),
    gap_contract = "strict_window"
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

ledgr_compute_feature_scalar_at <- function(bars_df, feature_def, index) {
  index <- as.integer(index)
  stable_after <- as.integer(feature_def$stable_after)
  if (index < stable_after) return(NA_real_)

  start_idx <- index - stable_after + 1L
  window <- bars_df[seq.int(start_idx, index), , drop = FALSE]
  params <- feature_def$params
  if (is.null(params)) params <- list()
  value <- ledgr_call_feature_fn(feature_def$fn, window, params)
  ledgr_normalize_feature_scalar_output(value, feature_def$id)
}

ledgr_compute_feature_series <- function(bars_df, feature_def) {
  ledgr_validate_feature_def(feature_def)

  if (!is.data.frame(bars_df) || nrow(bars_df) < 1) {
    rlang::abort("`bars_df` must be a non-empty data.frame.", class = "ledgr_invalid_feature_input")
  }
  if (!all(c("ts_utc", "close") %in% names(bars_df))) {
    rlang::abort("`bars_df` must include at least columns `ts_utc` and `close`.", class = "ledgr_invalid_feature_input")
  }

  stable_after <- as.integer(feature_def$stable_after)
  series_fn <- feature_def$series_fn
  params <- feature_def$params
  if (is.null(params)) params <- list()

  n <- nrow(bars_df)
  if (n < stable_after) {
    return(rep(NA_real_, n))
  }
  if (!is.null(series_fn)) {
    value <- ledgr_call_feature_series_fn(series_fn, bars_df, params)
    return(ledgr_normalize_feature_series_output(value, n, stable_after, feature_def$id))
  }

  out <- rep(NA_real_, n)
  for (i in seq_len(n)) {
    out[[i]] <- ledgr_compute_feature_scalar_at(bars_df, feature_def, i)
  }
  out
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

ledgr_compute_feature_latest <- function(bars_df, feature_def) {
  ledgr_validate_feature_def(feature_def)

  if (!is.data.frame(bars_df) || nrow(bars_df) < 1) {
    rlang::abort("`bars_df` must be a non-empty data.frame.", class = "ledgr_invalid_feature_input")
  }
  if (!all(c("ts_utc", "close") %in% names(bars_df))) {
    rlang::abort("`bars_df` must include at least columns `ts_utc` and `close`.", class = "ledgr_invalid_feature_input")
  }

  ledgr_compute_feature_scalar_at(bars_df, feature_def, nrow(bars_df))
}

ledgr_check_no_lookahead <- function(feature_def, bars_df, horizons = c(1L, 3L)) {
  ledgr_validate_feature_def(feature_def)
  if (!is.data.frame(bars_df) || nrow(bars_df) < 2) {
    rlang::abort("`bars_df` must be a data.frame with at least 2 rows.", class = "ledgr_invalid_feature_input")
  }
  n <- nrow(bars_df)
  horizons <- as.integer(horizons)
  horizons <- horizons[horizons >= 1L]
  if (length(horizons) == 0) horizons <- 1L

  for (h in horizons) {
    for (k in seq_len(n - h)) {
      past <- bars_df[seq_len(k), , drop = FALSE]
      extended <- bars_df[seq_len(k + h), , drop = FALSE]
      v1 <- ledgr_compute_feature_series(past, feature_def)[[k]]
      v2 <- ledgr_compute_feature_series(extended, feature_def)[[k]]
      if (is.na(v1) && is.na(v2)) next
      if (!identical(v1, v2)) {
        rlang::abort(
          sprintf("No-lookahead check failed for feature %s at k=%d with horizon=%d.", feature_def$id, k, h),
          class = "ledgr_feature_lookahead_detected"
        )
      }
    }
  }
  invisible(TRUE)
}
