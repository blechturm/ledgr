ledgr_sweep_storage_json_columns <- c(
  "retention_json",
  "metric_context_json",
  "execution_assumptions_json",
  "candidate_features_json",
  "grid_json",
  "cost_plan_json",
  "metrics_json",
  "params_json",
  "feature_params_json",
  "warnings_json",
  "feature_fingerprints_json",
  "provenance_json"
)

ledgr_sweep_storage_json <- function(x) {
  as.character(canonical_json(x))
}

ledgr_sweep_storage_parent_row <- function(sweep,
                                           sweep_id = attr(sweep, "sweep_id", exact = TRUE),
                                           snapshot_id = attr(sweep, "snapshot_id", exact = TRUE),
                                           snapshot_hash = attr(sweep, "snapshot_hash", exact = TRUE),
                                           note = NULL,
                                           created_at_utc = as.POSIXct(Sys.time(), tz = "UTC"),
                                           engine_version = as.character(utils::packageVersion("ledgr"))) {
  ledgr_sweep_storage_assert_sweep(sweep)
  cost_model_hash <- attr(sweep, "cost_model_hash", exact = TRUE)
  cost_plan_json <- attr(sweep, "cost_plan_json", exact = TRUE)
  if (!ledgr_sweep_storage_scalar_chr(cost_model_hash) ||
      !ledgr_sweep_storage_scalar_chr(cost_plan_json)) {
    rlang::abort(
      "Saved sweeps require non-empty cost identity metadata.",
      class = c("ledgr_sweep_storage_invalid_identity", "ledgr_invalid_args")
    )
  }
  metric_context <- attr(sweep, "metric_context", exact = TRUE)
  metric_context_record <- if (inherits(metric_context, "ledgr_metric_context")) {
    ledgr_metric_context_record(metric_context)
  } else if (is.list(metric_context)) {
    metric_context
  } else {
    list()
  }
  tibble::tibble(
    sweep_id = as.character(sweep_id),
    snapshot_id = as.character(snapshot_id),
    snapshot_hash = as.character(snapshot_hash),
    created_at_utc = as.POSIXct(created_at_utc, tz = "UTC"),
    engine_version = as.character(engine_version),
    sweep_schema_version = as.integer(ledgr_saved_sweep_schema_version),
    note = note %||% NA_character_,
    retention_json = ledgr_sweep_storage_json(attr(sweep, "sweep_retention", exact = TRUE)),
    metric_context_json = ledgr_sweep_storage_json(metric_context_record),
    metric_context_hash = as.character(attr(sweep, "metric_context_hash", exact = TRUE)),
    metric_context_version = as.integer(attr(sweep, "metric_context_version", exact = TRUE)),
    cost_model_hash = as.character(cost_model_hash),
    cost_plan_json = ledgr_sweep_storage_json(cost_plan_json),
    execution_assumptions_json = ledgr_sweep_storage_json(attr(sweep, "execution_assumptions", exact = TRUE)),
    feature_union_hash = as.character(attr(sweep, "feature_union_hash", exact = TRUE)),
    feature_engine_version = as.character(attr(sweep, "feature_engine_version", exact = TRUE)),
    candidate_features_json = ledgr_sweep_storage_json(
      ledgr_sweep_storage_records(attr(sweep, "candidate_features", exact = TRUE))
    ),
    grid_json = ledgr_sweep_storage_json(ledgr_sweep_storage_grid_records(sweep))
  )
}

ledgr_sweep_storage_candidate_rows <- function(sweep,
                                               sweep_id = attr(sweep, "sweep_id", exact = TRUE)) {
  ledgr_sweep_storage_assert_sweep(sweep)
  candidate_features <- tibble::as_tibble(attr(sweep, "candidate_features", exact = TRUE))
  cost_model_hash <- attr(sweep, "cost_model_hash", exact = TRUE)
  metric_context_hash <- attr(sweep, "metric_context_hash", exact = TRUE)
  rows <- lapply(seq_len(nrow(sweep)), function(i) {
    row <- sweep[i, , drop = FALSE]
    candidate_row <- as.integer(row$candidate_row[[1]])
    feature_row <- if ("candidate_row" %in% names(candidate_features)) {
      candidate_features[candidate_features$candidate_row == candidate_row, , drop = FALSE]
    } else {
      candidate_features[i, , drop = FALSE]
    }
    provenance <- row$provenance[[1]]
    if (!is.list(provenance)) {
      rlang::abort(
        "Sweep candidate provenance must be a list before persistence.",
        class = c("ledgr_sweep_storage_invalid_provenance", "ledgr_invalid_args")
      )
    }
    ledgr_sweep_storage_validate_candidate_identity(
      row = row,
      feature_row = feature_row,
      provenance = provenance,
      cost_model_hash = cost_model_hash,
      metric_context_hash = metric_context_hash
    )
    list(
      sweep_id = as.character(sweep_id),
      candidate_id = as.character(row$candidate_id[[1]]),
      candidate_row = candidate_row,
      status = as.character(row$status[[1]]),
      final_equity = ledgr_sweep_storage_num(row$final_equity[[1]]),
      metrics_json = ledgr_sweep_storage_json(ledgr_sweep_storage_metric_record(row)),
      total_return = ledgr_sweep_storage_num(row$total_return[[1]]),
      annualized_return = ledgr_sweep_storage_num(row$annualized_return[[1]]),
      volatility = ledgr_sweep_storage_num(row$volatility[[1]]),
      sharpe_ratio = ledgr_sweep_storage_num(row$sharpe_ratio[[1]]),
      max_drawdown = ledgr_sweep_storage_num(row$max_drawdown[[1]]),
      n_trades = ledgr_sweep_storage_int(row$n_trades[[1]]),
      win_rate = ledgr_sweep_storage_num(row$win_rate[[1]]),
      avg_trade = ledgr_sweep_storage_num(row$avg_trade[[1]]),
      time_in_market = ledgr_sweep_storage_num(row$time_in_market[[1]]),
      execution_seed = ledgr_sweep_storage_int(row$execution_seed[[1]]),
      error_class = ledgr_sweep_storage_chr(row$error_class[[1]]),
      error_msg = ledgr_sweep_storage_chr(row$error_msg[[1]]),
      params_json = ledgr_sweep_storage_json(row$params[[1]]),
      feature_params_json = ledgr_sweep_storage_json(row$feature_params[[1]] %||% list()),
      warnings_json = ledgr_sweep_storage_json(ledgr_sweep_storage_warning_records(row$warnings[[1]])),
      feature_set_hash = as.character(provenance$feature_set_hash),
      feature_fingerprints_json = ledgr_sweep_storage_json(row$feature_fingerprints[[1]]),
      provenance_json = ledgr_sweep_storage_json(provenance),
      cost_model_hash = as.character(cost_model_hash),
      metric_context_hash = as.character(metric_context_hash)
    )
  })
  tibble::as_tibble(do.call(rbind.data.frame, c(rows, stringsAsFactors = FALSE)))
}

ledgr_sweep_storage_return_rows <- function(sweep,
                                            sweep_id = attr(sweep, "sweep_id", exact = TRUE)) {
  ledgr_sweep_storage_assert_sweep(sweep)
  returns <- attr(sweep, "sweep_returns", exact = TRUE)
  if (is.null(returns) || nrow(returns) == 0L) {
    return(tibble::tibble(
      sweep_id = character(),
      candidate_row = integer(),
      pulse_index = integer(),
      ts_utc = as.POSIXct(character(), tz = "UTC"),
      equity = numeric(),
      period_return = numeric()
    ))
  }
  returns <- tibble::as_tibble(returns)
  split_rows <- split(returns, returns$candidate_row)
  out <- lapply(split_rows, function(candidate_returns) {
    candidate_returns <- candidate_returns[order(as.POSIXct(candidate_returns$ts_utc, tz = "UTC")), , drop = FALSE]
    data.frame(
      sweep_id = rep(as.character(sweep_id), nrow(candidate_returns)),
      candidate_row = as.integer(candidate_returns$candidate_row),
      pulse_index = seq_len(nrow(candidate_returns)),
      ts_utc = as.POSIXct(candidate_returns$ts_utc, tz = "UTC"),
      equity = as.numeric(candidate_returns$equity),
      period_return = as.numeric(candidate_returns$period_return),
      stringsAsFactors = FALSE
    )
  })
  tibble::as_tibble(do.call(rbind, out))
}

ledgr_sweep_storage_assert_sweep <- function(sweep) {
  if (!inherits(sweep, "ledgr_sweep_results")) {
    rlang::abort("`sweep` must be a ledgr_sweep_results object.", class = "ledgr_invalid_args")
  }
  invisible(TRUE)
}

ledgr_sweep_storage_records <- function(x) {
  if (is.null(x)) {
    return(list())
  }
  x <- tibble::as_tibble(x)
  if (nrow(x) == 0L) {
    return(list())
  }
  lapply(seq_len(nrow(x)), function(i) {
    row <- x[i, , drop = FALSE]
    stats::setNames(lapply(names(row), function(name) row[[name]][[1]]), names(row))
  })
}

ledgr_sweep_storage_grid_records <- function(sweep) {
  lapply(seq_len(nrow(sweep)), function(i) {
    row <- sweep[i, , drop = FALSE]
    list(
      candidate_id = as.character(row$candidate_id[[1]]),
      candidate_row = as.integer(row$candidate_row[[1]]),
      params = row$params[[1]],
      feature_params = row$feature_params[[1]] %||% list(),
      execution_seed = as.integer(row$execution_seed[[1]])
    )
  })
}

ledgr_sweep_storage_metric_record <- function(row) {
  list(
    total_return = ledgr_sweep_storage_json_scalar(row$total_return[[1]]),
    annualized_return = ledgr_sweep_storage_json_scalar(row$annualized_return[[1]]),
    volatility = ledgr_sweep_storage_json_scalar(row$volatility[[1]]),
    sharpe_ratio = ledgr_sweep_storage_json_scalar(row$sharpe_ratio[[1]]),
    max_drawdown = ledgr_sweep_storage_json_scalar(row$max_drawdown[[1]]),
    n_trades = ledgr_sweep_storage_json_scalar(row$n_trades[[1]], integer = TRUE),
    win_rate = ledgr_sweep_storage_json_scalar(row$win_rate[[1]]),
    avg_trade = ledgr_sweep_storage_json_scalar(row$avg_trade[[1]]),
    time_in_market = ledgr_sweep_storage_json_scalar(row$time_in_market[[1]])
  )
}

ledgr_sweep_storage_warning_records <- function(warnings) {
  if (length(warnings) == 0L) {
    return(list())
  }
  lapply(warnings, function(warning) {
    list(
      class = ledgr_condition_class(warning),
      message = conditionMessage(warning)
    )
  })
}

ledgr_sweep_storage_validate_candidate_identity <- function(row,
                                                            feature_row,
                                                            provenance,
                                                            cost_model_hash,
                                                            metric_context_hash) {
  candidate_id <- if ("candidate_id" %in% names(row) &&
    length(row$candidate_id) == 1L &&
    !is.na(row$candidate_id[[1]])) {
    as.character(row$candidate_id[[1]])
  } else {
    "<unknown>"
  }
  if (nrow(feature_row) != 1L) {
    rlang::abort(
      paste0(
        "Sweep candidate '", candidate_id,
        "' must have one candidate-feature identity row."
      ),
      class = c("ledgr_sweep_storage_invalid_identity", "ledgr_invalid_args")
    )
  }
  feature_set_hash <- feature_row$feature_set_hash[[1]]
  if (!identical(as.character(feature_set_hash), as.character(provenance$feature_set_hash))) {
    rlang::abort(
      paste0(
        "Sweep candidate '", candidate_id,
        "' feature_set_hash does not match provenance feature_set_hash."
      ),
      class = c("ledgr_sweep_storage_identity_mismatch", "ledgr_invalid_args")
    )
  }
  if (!identical(as.character(cost_model_hash), as.character(provenance$cost_model_hash))) {
    rlang::abort(
      paste0(
        "Sweep candidate '", candidate_id,
        "' cost_model_hash does not match sweep cost_model_hash."
      ),
      class = c("ledgr_sweep_storage_identity_mismatch", "ledgr_invalid_args")
    )
  }
  if (!ledgr_sweep_storage_scalar_chr(metric_context_hash)) {
    rlang::abort(
      paste0(
        "Sweep candidate '", candidate_id,
        "' requires a non-empty metric_context_hash."
      ),
      class = c("ledgr_sweep_storage_invalid_identity", "ledgr_invalid_args")
    )
  }
  invisible(TRUE)
}

ledgr_sweep_storage_scalar_chr <- function(x) {
  is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)
}

ledgr_sweep_storage_chr <- function(x) {
  if (length(x) != 1L || is.na(x)) {
    return(NA_character_)
  }
  as.character(x)
}

ledgr_sweep_storage_num <- function(x) {
  if (length(x) != 1L || is.na(x)) {
    return(NA_real_)
  }
  as.numeric(x)
}

ledgr_sweep_storage_int <- function(x) {
  if (length(x) != 1L || is.na(x)) {
    return(NA_integer_)
  }
  as.integer(x)
}

ledgr_sweep_storage_json_scalar <- function(x, integer = FALSE) {
  if (length(x) != 1L || is.na(x) || (is.numeric(x) && !is.finite(x))) {
    return(NULL)
  }
  if (isTRUE(integer)) {
    return(as.integer(x))
  }
  if (is.numeric(x)) {
    return(as.numeric(x))
  }
  if (is.character(x)) {
    return(as.character(x))
  }
  if (is.logical(x)) {
    return(as.logical(x))
  }
  NULL
}
