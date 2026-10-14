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

ledgr_compute_feature_series_strict_scalar <- function(bars_df, feature_def) {
  ledgr_validate_feature_def(feature_def)
  if (!identical(feature_def$gap_contract, "strict_window")) {
    rlang::abort(
      sprintf(
        "Indicator '%s' does not declare the availability gap contract `strict_window`.",
        feature_def$id
      ),
      class = c("ledgr_indicator_gap_unsupported", "ledgr_invalid_feature_def")
    )
  }
  if (!is.data.frame(bars_df) || !all(c("ts_utc", "close") %in% names(bars_df))) {
    rlang::abort(
      "Strict feature input must be an expected-session-aligned data frame.",
      class = "ledgr_invalid_feature_input"
    )
  }
  n <- nrow(bars_df)
  width <- as.integer(feature_def$stable_after)
  out <- rep(NA_real_, n)
  if (n < width) return(out)
  value_columns <- intersect(c("open", "high", "low", "close"), names(bars_df))
  for (i in seq.int(width, n)) {
    window <- bars_df[seq.int(i - width + 1L, i), , drop = FALSE]
    complete <- all(vapply(window[value_columns], function(x) {
      values <- suppressWarnings(as.numeric(x))
      !anyNA(values) && all(is.finite(values))
    }, logical(1)))
    if (!complete) next
    scalar <- ledgr_normalize_feature_scalar_output(
      ledgr_call_feature_fn(feature_def$fn, window, feature_def$params %||% list()),
      feature_def$id
    )
    if (!is.null(feature_def$series_fn)) {
      series <- ledgr_call_feature_series_fn(
        feature_def$series_fn,
        window,
        feature_def$params %||% list()
      )
      terminal <- ledgr_normalize_feature_scalar_output(
        utils::tail(series, 1L),
        feature_def$id
      )
      same <- (is.na(scalar) && is.na(terminal)) ||
        isTRUE(all.equal(scalar, terminal, tolerance = sqrt(.Machine$double.eps)))
      if (!same) {
        rlang::abort(
          sprintf(
            "Indicator '%s' scalar and series functions disagree on a strict window.",
            feature_def$id
          ),
          class = c("ledgr_indicator_gap_parity", "ledgr_invalid_feature_output")
        )
      }
    }
    out[[i]] <- scalar
  }
  out
}

ledgr_strict_builtin_kind <- function(feature_def) {
  params <- feature_def$params
  width <- if (is.list(params)) params$n else NULL
  if (!is.numeric(width) || length(width) != 1L || is.na(width) ||
      !is.finite(width) || width < 1 || width %% 1 != 0) {
    return(NULL)
  }
  width <- as.integer(width)
  fingerprint <- ledgr_feature_def_fingerprint(feature_def)
  sma <- ledgr_precompute_feature_def_from_indicator(ledgr_ind_sma(width))
  sma_fingerprints <- c(
    ledgr_feature_def_fingerprint(sma),
    ledgr_active_feature_fingerprint(sma)
  )
  if (fingerprint %in% sma_fingerprints) {
    return("sma")
  }
  returns <- ledgr_precompute_feature_def_from_indicator(
    ledgr_ind_returns(width)
  )
  returns_fingerprints <- c(
    ledgr_feature_def_fingerprint(returns),
    ledgr_active_feature_fingerprint(returns)
  )
  if (fingerprint %in% returns_fingerprints) {
    return("returns")
  }
  NULL
}

ledgr_strict_complete_window_mask <- function(bars_df, width) {
  columns <- intersect(c("open", "high", "low", "close"), names(bars_df))
  values <- do.call(cbind, lapply(bars_df[columns], function(x) {
    suppressWarnings(as.numeric(x))
  }))
  if (is.null(dim(values))) values <- matrix(values, ncol = 1L)
  complete <- stats::complete.cases(values) &
    rowSums(is.finite(values)) == ncol(values)
  cumulative <- cumsum(!complete)
  previous <- c(rep(0, width), cumulative)[seq_along(cumulative)]
  seq_along(cumulative) >= width & cumulative - previous == 0
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

ledgr_compute_feature_series_strict_builtin <- function(bars_df,
                                                        feature_def,
                                                        kind) {
  n <- nrow(bars_df)
  width <- as.integer(feature_def$stable_after)
  if (n < width) return(rep(NA_real_, n))
  value <- if (identical(kind, "sma")) {
    ledgr_strict_sma_series(bars_df$close, width)
  } else {
    ledgr_call_feature_series_fn(
      feature_def$series_fn,
      bars_df,
      feature_def$params %||% list()
    )
  }
  if (!is.numeric(value) || !is.atomic(value) || !is.null(dim(value))) {
    rlang::abort(
      sprintf(
        "Feature %s returned a non-numeric or non-vector series.",
        feature_def$id
      ),
      class = "ledgr_invalid_feature_output"
    )
  }
  if (length(value) != n) {
    rlang::abort(
      sprintf(
        "Feature %s returned %d values; expected %d.",
        feature_def$id,
        length(value),
        n
      ),
      class = "ledgr_invalid_feature_output"
    )
  }
  value <- as.numeric(value)
  complete <- ledgr_strict_complete_window_mask(bars_df, width)
  if (any(is.nan(value[complete])) || any(is.infinite(value[complete]))) {
    rlang::abort(
      sprintf("Feature %s returned a non-finite value.", feature_def$id),
      class = "ledgr_invalid_feature_output"
    )
  }
  value[!complete] <- NA_real_
  value
}

ledgr_compute_feature_series_strict <- function(
  bars_df,
  feature_def,
  kind = ledgr_strict_builtin_kind(feature_def)
) {
  ledgr_validate_feature_def(feature_def)
  if (!identical(feature_def$gap_contract, "strict_window") ||
      !is.data.frame(bars_df) ||
      !all(c("ts_utc", "close") %in% names(bars_df))) {
    return(ledgr_compute_feature_series_strict_scalar(bars_df, feature_def))
  }
  if (is.null(kind)) {
    return(ledgr_compute_feature_series_strict_scalar(bars_df, feature_def))
  }
  ledgr_compute_feature_series_strict_builtin(bars_df, feature_def, kind)
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
