ledgr_pulse_context <- function(run_id,
                                ts_utc,
                                universe,
                                bars,
                                features = data.frame(),
                                positions = numeric(),
                                cash,
                                equity,
                                state_prev = NULL,
                                safety_state = "GREEN") {
  ctx <- list(
    run_id = run_id,
    ts_utc = ledgr_normalize_ts_utc(ts_utc),
    universe = universe,
    bars = bars,
    features = features,
    positions = positions,
    cash = cash,
    equity = equity,
    state_prev = state_prev,
    safety_state = safety_state
  )

  class(ctx) <- "ledgr_pulse_context"
  ledgr_validate_pulse_context(ctx)
  ctx
}

ledgr_normalize_ts_utc <- function(x) {
  if (inherits(x, "POSIXt")) {
    x <- as.POSIXct(x, tz = "UTC")
    if (is.na(x)) {
      rlang::abort("`ts_utc` could not be converted to UTC POSIXct.", class = "ledgr_invalid_pulse_context")
    }
    return(format(x, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  }

  if (!is.character(x) || length(x) != 1 || is.na(x) || !nzchar(x)) {
    rlang::abort(
      "`ts_utc` must be a non-empty ISO8601 UTC string like 'YYYY-mm-ddTHH:MM:SSZ' (or POSIXct).",
      class = "ledgr_invalid_pulse_context"
    )
  }

  if (!grepl("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$", x)) {
    rlang::abort(
      "`ts_utc` must be an ISO8601 UTC string like 'YYYY-mm-ddTHH:MM:SSZ'.",
      class = "ledgr_invalid_pulse_context"
    )
  }

  parsed <- as.POSIXct(x, tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ")
  if (is.na(parsed)) {
    rlang::abort("`ts_utc` is not parseable as UTC.", class = "ledgr_invalid_pulse_context")
  }

  format(parsed, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

ledgr_validate_pulse_context <- function(ctx) {
  if (!inherits(ctx, "ledgr_pulse_context") || !is.list(ctx)) {
    rlang::abort("`ctx` must be a ledgr pulse context created by ledgr_pulse_context().", class = "ledgr_invalid_pulse_context")
  }

  if (!is.character(ctx$run_id) || length(ctx$run_id) != 1 || is.na(ctx$run_id) || !nzchar(ctx$run_id)) {
    rlang::abort("PulseContext `run_id` must be a non-empty character scalar.", class = "ledgr_invalid_pulse_context")
  }

  ctx$ts_utc <- ledgr_normalize_ts_utc(ctx$ts_utc)

  if (!is.character(ctx$universe) || length(ctx$universe) < 1 || anyNA(ctx$universe) || any(!nzchar(ctx$universe))) {
    rlang::abort("PulseContext `universe` must be a non-empty character vector of non-empty strings.", class = "ledgr_invalid_pulse_context")
  }
  if (anyDuplicated(ctx$universe)) {
    rlang::abort("PulseContext `universe` must not contain duplicate instrument_ids.", class = "ledgr_invalid_pulse_context")
  }

  validate_df_ts <- function(df, label) {
    if (!is.data.frame(df)) {
      rlang::abort(sprintf("PulseContext `%s` must be a data.frame (or tibble).", label), class = "ledgr_invalid_pulse_context")
    }
    if (nrow(df) == 0) return(invisible(TRUE))
    if (!("ts_utc" %in% names(df))) {
      rlang::abort(sprintf("PulseContext `%s` must include a `ts_utc` column.", label), class = "ledgr_invalid_pulse_context")
    }
    ts_norm <- vapply(df$ts_utc, ledgr_normalize_ts_utc, character(1))
    if (any(ts_norm != ctx$ts_utc)) {
      rlang::abort(
        sprintf("PulseContext `%s` must not contain timestamps other than ctx$ts_utc.", label),
        class = "ledgr_invalid_pulse_context"
      )
    }
    invisible(TRUE)
  }

  validate_df_instruments <- function(df, label) {
    if (nrow(df) == 0) return(invisible(TRUE))
    if (!("instrument_id" %in% names(df))) {
      rlang::abort(sprintf("PulseContext `%s` must include an `instrument_id` column.", label), class = "ledgr_invalid_pulse_context")
    }
    bad <- setdiff(unique(as.character(df$instrument_id)), ctx$universe)
    if (length(bad) > 0) {
      rlang::abort(
        sprintf("PulseContext `%s` contains instrument_ids not in universe: %s", label, paste(bad, collapse = ", ")),
        class = "ledgr_invalid_pulse_context"
      )
    }
    invisible(TRUE)
  }

  validate_df_ts(ctx$bars, "bars")
  validate_df_instruments(ctx$bars, "bars")

  if (!is.data.frame(ctx$features)) {
    rlang::abort("PulseContext `features` must be a data.frame (or tibble).", class = "ledgr_invalid_pulse_context")
  }
  if (nrow(ctx$features) > 0) {
    validate_df_ts(ctx$features, "features")
    validate_df_instruments(ctx$features, "features")
  }

  if (!is.numeric(ctx$positions)) {
    rlang::abort("PulseContext `positions` must be a named numeric vector.", class = "ledgr_invalid_pulse_context")
  }
  if (length(ctx$positions) > 0) {
    if (is.null(names(ctx$positions)) || any(!nzchar(names(ctx$positions))) || anyDuplicated(names(ctx$positions))) {
      rlang::abort("PulseContext `positions` must be a named numeric vector with unique, non-empty names.", class = "ledgr_invalid_pulse_context")
    }
    bad <- setdiff(names(ctx$positions), ctx$universe)
    if (length(bad) > 0) {
      rlang::abort(
        sprintf("PulseContext `positions` contains instrument_ids not in universe: %s", paste(bad, collapse = ", ")),
        class = "ledgr_invalid_pulse_context"
      )
    }
    if (any(!is.finite(ctx$positions))) {
      rlang::abort("PulseContext `positions` must contain only finite numbers.", class = "ledgr_invalid_pulse_context")
    }
  }

  if (!is.numeric(ctx$cash) || length(ctx$cash) != 1 || is.na(ctx$cash) || !is.finite(ctx$cash)) {
    rlang::abort("PulseContext `cash` must be a finite numeric scalar.", class = "ledgr_invalid_pulse_context")
  }
  if (!is.numeric(ctx$equity) || length(ctx$equity) != 1 || is.na(ctx$equity) || !is.finite(ctx$equity)) {
    rlang::abort("PulseContext `equity` must be a finite numeric scalar.", class = "ledgr_invalid_pulse_context")
  }

  if (!is.null(ctx$state_prev)) {
    if (!(is.list(ctx$state_prev) || (is.character(ctx$state_prev) && length(ctx$state_prev) == 1))) {
      rlang::abort("PulseContext `state_prev` must be NULL or a JSON-safe list (or JSON string).", class = "ledgr_invalid_pulse_context")
    }
    invisible(canonical_json(ctx$state_prev))
  }

  if (!is.character(ctx$safety_state) || length(ctx$safety_state) != 1 || is.na(ctx$safety_state) || !nzchar(ctx$safety_state)) {
    rlang::abort("PulseContext `safety_state` must be a non-empty character scalar.", class = "ledgr_invalid_pulse_context")
  }

  invisible(TRUE)
}
