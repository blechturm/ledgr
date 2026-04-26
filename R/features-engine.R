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

  json_safe_def <- list(
    id = id,
    requires_bars = as.integer(requires_bars),
    stable_after = as.integer(stable_after),
    params = params
  )
  invisible(canonical_json(json_safe_def))

  invisible(TRUE)
}

ledgr_validate_feature_defs <- function(feature_defs) {
  if (!is.list(feature_defs) || length(feature_defs) < 1) {
    rlang::abort("`feature_defs` must be a non-empty list of feature definitions.", class = "ledgr_invalid_feature_def")
  }
  ids <- vapply(feature_defs, function(d) if (is.null(d$id)) NA_character_ else d$id, character(1))
  if (anyNA(ids) || any(!nzchar(ids))) {
    rlang::abort("All feature_defs must include a non-empty `id`.", class = "ledgr_invalid_feature_def")
  }
  if (anyDuplicated(ids)) {
    rlang::abort(sprintf("feature_defs contain duplicate ids: %s", paste(unique(ids[duplicated(ids)]), collapse = ", ")), class = "ledgr_invalid_feature_def")
  }
  for (d in feature_defs) ledgr_validate_feature_def(d)
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
    params = list(n = n)
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
    params = list()
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

ledgr_compute_feature_series <- function(bars_df, feature_def) {
  ledgr_validate_feature_def(feature_def)

  if (!is.data.frame(bars_df) || nrow(bars_df) < 1) {
    rlang::abort("`bars_df` must be a non-empty data.frame.", class = "ledgr_invalid_feature_input")
  }
  if (!all(c("ts_utc", "close") %in% names(bars_df))) {
    rlang::abort("`bars_df` must include at least columns `ts_utc` and `close`.", class = "ledgr_invalid_feature_input")
  }

  stable_after <- as.integer(feature_def$stable_after)
  fn <- feature_def$fn
  series_fn <- feature_def$series_fn
  params <- feature_def$params
  if (is.null(params)) params <- list()

  n <- nrow(bars_df)
  if (!is.null(series_fn)) {
    value <- ledgr_call_feature_series_fn(series_fn, bars_df, params)
    return(ledgr_normalize_feature_series_output(value, n, stable_after, feature_def$id))
  }

  out <- rep(NA_real_, n)
  for (i in seq_len(n)) {
    if (i < stable_after) {
      out[[i]] <- NA_real_
      next
    }
    start_idx <- max(1L, i - stable_after + 1L)
    window <- bars_df[start_idx:i, , drop = FALSE]
    value <- ledgr_call_feature_fn(fn, window, params)
    out[[i]] <- ledgr_normalize_feature_scalar_output(value, feature_def$id)
  }
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

  stable_after <- as.integer(feature_def$stable_after)
  fn <- feature_def$fn
  params <- feature_def$params
  if (is.null(params)) params <- list()

  if (nrow(bars_df) < stable_after) return(NA_real_)

  window <- bars_df
  if (nrow(window) > stable_after) {
    window <- utils::tail(window, stable_after)
  }
  value <- ledgr_call_feature_fn(fn, window, params)
  ledgr_normalize_feature_scalar_output(value, feature_def$id)
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

ledgr_compute_features <- function(con, run_id, instrument_ids, start_ts_utc, end_ts_utc, feature_defs) {
  if (!DBI::dbIsValid(con)) {
    rlang::abort("`con` must be a valid DBI connection.", class = "ledgr_invalid_con")
  }
  if (!is.character(run_id) || length(run_id) != 1 || is.na(run_id) || !nzchar(run_id)) {
    rlang::abort("`run_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (!is.character(instrument_ids) || length(instrument_ids) < 1 || anyNA(instrument_ids) || any(!nzchar(instrument_ids))) {
    rlang::abort("`instrument_ids` must be a non-empty character vector of non-empty strings.", class = "ledgr_invalid_args")
  }

  ledgr_validate_feature_defs(feature_defs)
  feature_defs <- feature_defs[order(vapply(feature_defs, function(d) d$id, character(1)))]

  start_iso <- ledgr_normalize_ts_utc(start_ts_utc)
  end_iso <- ledgr_normalize_ts_utc(end_ts_utc)
  start_ts <- as.POSIXct(start_iso, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
  end_ts <- as.POSIXct(end_iso, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
  if (start_ts > end_ts) {
    rlang::abort("`start_ts_utc` must be <= `end_ts_utc`.", class = "ledgr_invalid_args")
  }

  run_exists <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM runs WHERE run_id = ?", params = list(run_id))$n[[1]] > 0
  if (!isTRUE(run_exists)) {
    rlang::abort(sprintf("run_id not found in runs table: %s", run_id), class = "ledgr_invalid_args")
  }

  ids_sql <- paste(DBI::dbQuoteString(con, instrument_ids), collapse = ", ")
  sql <- paste0(
    "SELECT instrument_id, ts_utc, open, high, low, close, volume ",
    "FROM bars ",
    "WHERE instrument_id IN (", ids_sql, ") ",
    "  AND ts_utc >= ? AND ts_utc <= ? ",
    "ORDER BY instrument_id, ts_utc"
  )

  res <- DBI::dbSendQuery(con, sql)
  on.exit(suppressWarnings(try(DBI::dbClearResult(res), silent = TRUE)), add = TRUE)
  DBI::dbBind(res, params = list(start_ts, end_ts))
  bars <- DBI::dbFetch(res)

  if (nrow(bars) == 0) {
    rlang::abort("No bars found for requested instruments and time range.", class = "ledgr_missing_bars")
  }

  present_ids <- unique(as.character(bars$instrument_id))
  missing_ids <- setdiff(instrument_ids, present_ids)
  if (length(missing_ids) > 0) {
    rlang::abort(
      sprintf("Missing bars for instruments in requested range: %s", paste(missing_ids, collapse = ", ")),
      class = "ledgr_missing_bars"
    )
  }

  out_rows <- vector("list", length(instrument_ids) * length(unique(bars$ts_utc)) * length(feature_defs))
  idx <- 1L

  for (instrument_id in instrument_ids) {
    b <- bars[bars$instrument_id == instrument_id, , drop = FALSE]
    b <- b[order(b$ts_utc), , drop = FALSE]
    if (nrow(b) == 0) next

    for (def in feature_defs) {
      values <- ledgr_compute_feature_series(b, def)
      for (i in seq_len(nrow(b))) {
        out_rows[[idx]] <- list(
          run_id = run_id,
          instrument_id = instrument_id,
          ts_utc = b$ts_utc[[i]],
          feature_name = def$id,
          feature_value = values[[i]]
        )
        idx <- idx + 1L
      }
    }
  }

  out_rows <- out_rows[seq_len(idx - 1L)]
  out_df <- data.frame(
    run_id = vapply(out_rows, `[[`, character(1), "run_id"),
    instrument_id = vapply(out_rows, `[[`, character(1), "instrument_id"),
    ts_utc = as.POSIXct(vapply(out_rows, function(x) format(x$ts_utc, "%Y-%m-%d %H:%M:%S", tz = "UTC"), character(1)), tz = "UTC"),
    feature_name = vapply(out_rows, `[[`, character(1), "feature_name"),
    feature_value = vapply(out_rows, function(x) as.numeric(x$feature_value), numeric(1)),
    stringsAsFactors = FALSE
  )

  feature_ids <- vapply(feature_defs, function(d) d$id, character(1))
  features_sql <- paste(DBI::dbQuoteString(con, feature_ids), collapse = ", ")
  inst_sql <- paste(DBI::dbQuoteString(con, instrument_ids), collapse = ", ")

  DBI::dbWithTransaction(con, {
    DBI::dbExecute(
      con,
      paste0(
        "DELETE FROM features WHERE run_id = ? ",
        "AND instrument_id IN (", inst_sql, ") ",
        "AND feature_name IN (", features_sql, ") ",
        "AND ts_utc >= ? AND ts_utc <= ?"
      ),
      params = list(run_id, start_ts, end_ts)
    )
    DBI::dbAppendTable(con, "features", out_df)
  })

  invisible(TRUE)
}
