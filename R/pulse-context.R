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
  ctx <- ledgr_update_pulse_context_helpers(ctx)
  ledgr_validate_pulse_context(ctx)
  ctx
}

ledgr_feature_table_ready <- function(features) {
  !is.null(features) &&
    all(c("instrument_id", "feature_name", "feature_value") %in% names(features)) &&
    length(features[["feature_value"]]) > 0
}

ledgr_feature_accessor <- function(features) {
  force(features)

  function(instrument_id, feature_name, default = NA_real_) {
    if (!is.character(instrument_id) || length(instrument_id) != 1L || is.na(instrument_id) || !nzchar(instrument_id)) {
      rlang::abort("`instrument_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
    }
    if (!is.character(feature_name) || length(feature_name) != 1L || is.na(feature_name) || !nzchar(feature_name)) {
      rlang::abort("`feature_name` must be a non-empty character scalar.", class = "ledgr_invalid_args")
    }
    if (!ledgr_feature_table_ready(features)) return(default)

    idx <- which(
      as.character(features[["instrument_id"]]) == instrument_id &
        as.character(features[["feature_name"]]) == feature_name
    )
    if (length(idx) == 0L) return(default)

    features[["feature_value"]][[idx[[length(idx)]]]]
  }
}

ledgr_features_wide <- function(features) {
  if (!ledgr_feature_table_ready(features)) return(data.frame())

  instrument_id <- as.character(features[["instrument_id"]])
  feature_name <- as.character(features[["feature_name"]])
  feature_value <- as.numeric(features[["feature_value"]])

  valid <- !is.na(instrument_id) & nzchar(instrument_id) & !is.na(feature_name) & nzchar(feature_name)
  if (!any(valid)) return(data.frame())

  instrument_id <- instrument_id[valid]
  feature_name <- feature_name[valid]
  feature_value <- feature_value[valid]

  instruments <- unique(instrument_id)
  feature_names <- unique(feature_name)
  values <- matrix(
    NA_real_,
    nrow = length(instruments),
    ncol = length(feature_names),
    dimnames = list(instruments, feature_names)
  )

  for (i in seq_along(feature_value)) {
    values[instrument_id[[i]], feature_name[[i]]] <- feature_value[[i]]
  }

  out <- data.frame(instrument_id = instruments, stringsAsFactors = FALSE)
  if ("ts_utc" %in% names(features)) {
    ts_utc <- vapply(features[["ts_utc"]][valid], iso_utc, character(1))
    out$ts_utc <- vapply(
      instruments,
      function(inst) ts_utc[which(instrument_id == inst)[[1]]],
      character(1)
    )
  }

  out <- cbind(out, as.data.frame(values, check.names = FALSE, stringsAsFactors = FALSE))
  rownames(out) <- NULL
  out
}

ledgr_attach_feature_helpers <- function(ctx, features = ctx$features) {
  if (is.environment(ctx)) {
    ctx$features_wide <- ledgr_features_wide(features)
    ctx$feature <- ledgr_feature_accessor(features)
    return(invisible(ctx))
  }

  ctx$features_wide <- ledgr_features_wide(features)
  ctx$feature <- ledgr_feature_accessor(features)
  ctx
}

ledgr_update_pulse_context_helpers <- function(ctx,
                                               bars = ctx$bars,
                                               features = ctx$features,
                                               positions = ctx$positions,
                                               universe = ctx$universe) {
  ctx <- ledgr_ensure_pulse_context_accessors(ctx)
  ctx <- ledgr_attach_feature_helpers(ctx, features)
  ledgr_refresh_pulse_context_lookup(ctx, bars = bars, positions = positions, universe = universe)
  ctx
}

ledgr_ensure_pulse_context_accessors <- function(ctx) {
  lookup <- ctx$.pulse_lookup
  if (!is.environment(lookup)) {
    lookup <- new.env(parent = emptyenv())
  }

  bar <- function(id) ledgr_pulse_context_bar(lookup, id)
  open <- function(id) ledgr_pulse_context_scalar(lookup, id, "open")
  high <- function(id) ledgr_pulse_context_scalar(lookup, id, "high")
  low <- function(id) ledgr_pulse_context_scalar(lookup, id, "low")
  close <- function(id) ledgr_pulse_context_scalar(lookup, id, "close")
  volume <- function(id) ledgr_pulse_context_scalar(lookup, id, "volume")
  position <- function(id) ledgr_pulse_context_position(lookup, id)
  targets <- function(default = 0) ledgr_pulse_context_targets(lookup, default = default)

  if (is.environment(ctx)) {
    ctx$.pulse_lookup <- lookup
    ctx$bar <- bar
    ctx$open <- open
    ctx$high <- high
    ctx$low <- low
    ctx$close <- close
    ctx$volume <- volume
    ctx$position <- position
    ctx$targets <- targets
    return(ctx)
  }

  ctx$.pulse_lookup <- lookup
  ctx$bar <- bar
  ctx$open <- open
  ctx$high <- high
  ctx$low <- low
  ctx$close <- close
  ctx$volume <- volume
  ctx$position <- position
  ctx$targets <- targets
  ctx
}

ledgr_refresh_pulse_context_lookup <- function(ctx,
                                               bars = ctx$bars,
                                               positions = ctx$positions,
                                               universe = ctx$universe) {
  lookup <- ctx$.pulse_lookup
  if (!is.environment(lookup)) {
    rlang::abort("Pulse context accessors have not been initialized.", class = "ledgr_invalid_pulse_context")
  }

  universe <- as.character(universe)
  lookup$bars <- bars
  lookup$positions <- positions
  lookup$universe <- universe
  lookup$bar_index <- ledgr_pulse_context_bar_index(bars, universe)

  invisible(ctx)
}

ledgr_pulse_context_nrows <- function(x) {
  if (is.data.frame(x)) return(nrow(x))
  if (!is.list(x) || length(x) == 0L) return(0L)
  first <- x[[1L]]
  if (is.null(first)) return(0L)
  length(first)
}

ledgr_pulse_context_column <- function(bars, field) {
  if (!is.list(bars) && !is.data.frame(bars)) {
    rlang::abort("Pulse context `bars` must be a data.frame or list-like object.", class = "ledgr_invalid_pulse_context")
  }
  if (!(field %in% names(bars))) {
    rlang::abort(
      sprintf("Pulse context bars are missing required field `%s`.", field),
      class = "ledgr_invalid_pulse_context"
    )
  }
  bars[[field]]
}

ledgr_pulse_context_bar_index <- function(bars, universe) {
  n <- ledgr_pulse_context_nrows(bars)
  if (n == 0L) return(stats::setNames(integer(0), character(0)))

  instrument_id <- as.character(ledgr_pulse_context_column(bars, "instrument_id"))
  if (length(instrument_id) != n || anyNA(instrument_id) || any(!nzchar(instrument_id))) {
    rlang::abort("Pulse context bars must include non-empty `instrument_id` values.", class = "ledgr_invalid_pulse_context")
  }

  bad <- setdiff(unique(instrument_id), universe)
  if (length(bad) > 0L) {
    rlang::abort(
      sprintf(
        "Pulse context bars contain instrument_ids not in universe: %s. Available ctx$universe: %s.",
        paste(bad, collapse = ", "),
        ledgr_pulse_context_universe_message(universe)
      ),
      class = "ledgr_invalid_pulse_context"
    )
  }

  duplicated_ids <- unique(instrument_id[duplicated(instrument_id)])
  if (length(duplicated_ids) > 0L) {
    rlang::abort(
      sprintf("Pulse context bars contain duplicate rows for instrument_id: %s.", paste(duplicated_ids, collapse = ", ")),
      class = "ledgr_invalid_pulse_context"
    )
  }

  stats::setNames(seq_len(n), instrument_id)
}

ledgr_pulse_context_universe_message <- function(universe) {
  if (length(universe) == 0L) return("<empty>")
  paste(universe, collapse = ", ")
}

ledgr_pulse_context_require_id <- function(lookup, id) {
  if (!is.character(id) || length(id) != 1L || is.na(id) || !nzchar(id)) {
    rlang::abort("`id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }

  universe <- lookup$universe
  if (is.null(universe)) universe <- character(0)
  universe <- as.character(universe)
  if (match(id, universe, nomatch = 0L) == 0L) {
    rlang::abort(
      sprintf(
        "Unknown instrument_id '%s'. Available ctx$universe: %s.",
        id,
        ledgr_pulse_context_universe_message(universe)
      ),
      class = "ledgr_invalid_pulse_context"
    )
  }

  id
}

ledgr_pulse_context_row_index <- function(lookup, id) {
  id <- ledgr_pulse_context_require_id(lookup, id)
  bar_index <- lookup$bar_index
  row_idx <- if (length(bar_index) == 0L) 0L else match(id, names(bar_index), nomatch = 0L)
  if (row_idx == 0L) {
    rlang::abort(
      sprintf("No bar row for instrument_id '%s' in ctx$bars at the current pulse.", id),
      class = "ledgr_invalid_pulse_context"
    )
  }
  unname(as.integer(bar_index[[row_idx]]))
}

ledgr_pulse_context_bar <- function(lookup, id) {
  row_idx <- ledgr_pulse_context_row_index(lookup, id)
  bars <- lookup$bars

  if (is.data.frame(bars)) {
    out <- bars[row_idx, , drop = FALSE]
    rownames(out) <- NULL
    return(out)
  }

  out <- lapply(bars, function(column) column[row_idx])
  out <- as.data.frame(out, stringsAsFactors = FALSE, optional = TRUE)
  rownames(out) <- NULL
  out
}

ledgr_pulse_context_scalar <- function(lookup, id, field) {
  row_idx <- ledgr_pulse_context_row_index(lookup, id)
  values <- ledgr_pulse_context_column(lookup$bars, field)
  value <- values[[row_idx]]
  if (!is.numeric(value)) {
    rlang::abort(
      sprintf("Pulse context bars field `%s` must be numeric.", field),
      class = "ledgr_invalid_pulse_context"
    )
  }
  unname(as.numeric(value))
}

ledgr_pulse_context_position <- function(lookup, id) {
  id <- ledgr_pulse_context_require_id(lookup, id)
  positions <- lookup$positions
  if (is.null(positions) || length(positions) == 0L) return(0)
  if (!is.numeric(positions) || is.null(names(positions))) {
    rlang::abort("Pulse context `positions` must be a named numeric vector.", class = "ledgr_invalid_pulse_context")
  }
  idx <- match(id, names(positions), nomatch = 0L)
  if (idx == 0L) return(0)
  unname(as.numeric(positions[[idx]]))
}

ledgr_pulse_context_targets <- function(lookup, default = 0) {
  if (!is.numeric(default) || length(default) != 1L || is.na(default) || !is.finite(default)) {
    rlang::abort("`default` must be a finite numeric scalar.", class = "ledgr_invalid_args")
  }
  universe <- lookup$universe
  if (is.null(universe)) universe <- character(0)
  stats::setNames(rep(as.numeric(default), length(universe)), universe)
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
