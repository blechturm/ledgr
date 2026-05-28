ledgr_runtime_projection <- function(feature_values,
                                     universe,
                                     pulses_posix,
                                     feature_engine_version = ledgr_feature_engine_version(),
                                     alias_index = NULL) {
  universe <- as.character(universe)
  pulses_posix <- as.POSIXct(pulses_posix, tz = "UTC")
  feature_values <- feature_values %||% list()
  if (!is.list(feature_values) || is.null(names(feature_values)) && length(feature_values) > 0L) {
    rlang::abort("`feature_values` must be a named list of feature matrices.", class = "ledgr_invalid_runtime_projection")
  }

  feature_ids <- names(feature_values)
  if (length(feature_ids) > 0L) {
    if (anyNA(feature_ids) || any(!nzchar(feature_ids))) {
      rlang::abort("`feature_values` names must be non-empty feature IDs.", class = "ledgr_invalid_runtime_projection")
    }
    ledgr_abort_duplicate_feature_ids(feature_ids)
  }

  n_inst <- length(universe)
  n_pulse <- length(pulses_posix)
  feature_values <- lapply(feature_values, function(value) {
    if (!is.matrix(value)) {
      rlang::abort("Each runtime projection feature value must be a matrix.", class = "ledgr_invalid_runtime_projection")
    }
    if (!identical(dim(value), c(n_inst, n_pulse))) {
      rlang::abort(
        "Each runtime projection matrix must have dimensions instruments x pulses.",
        class = "ledgr_invalid_runtime_projection"
      )
    }
    storage.mode(value) <- "double"
    dimnames(value) <- list(universe, ledgr_projection_pulse_names(pulses_posix))
    value
  })

  instrument_index <- stats::setNames(seq_along(universe), universe)
  pulse_index <- stats::setNames(seq_along(pulses_posix), ledgr_projection_pulse_names(pulses_posix))

  structure(
    list(
      feature_values = feature_values,
      instrument_index = instrument_index,
      pulse_index = pulse_index,
      pulses_posix = pulses_posix,
      pulses_iso = format(pulses_posix, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      feature_engine_version = feature_engine_version,
      alias_index = alias_index
    ),
    class = c("ledgr_runtime_projection", "list")
  )
}

ledgr_projection_pulse_names <- function(pulses_posix) {
  format(as.POSIXct(pulses_posix, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

ledgr_projection_from_feature_matrix <- function(feature_matrix,
                                                 universe,
                                                 pulses_posix,
                                                 feature_engine_version = ledgr_feature_engine_version(),
                                                 alias_index = NULL) {
  feature_matrix <- feature_matrix %||% list()
  ledgr_runtime_projection(
    feature_values = feature_matrix,
    universe = universe,
    pulses_posix = pulses_posix,
    feature_engine_version = feature_engine_version,
    alias_index = alias_index
  )
}

ledgr_projection_from_payload <- function(payload,
                                          universe,
                                          pulses_posix,
                                          feature_engine_version = ledgr_feature_engine_version(),
                                          alias_index = NULL) {
  payload <- payload %||% list()
  if (length(payload) == 0L) {
    return(ledgr_runtime_projection(
      feature_values = list(),
      universe = universe,
      pulses_posix = pulses_posix,
      feature_engine_version = feature_engine_version,
      alias_index = alias_index
    ))
  }

  feature_values <- list()
  for (entry in payload) {
    feature_id <- entry$feature_id
    if (!is.character(feature_id) || length(feature_id) != 1L || is.na(feature_id) || !nzchar(feature_id)) {
      rlang::abort("Precomputed payload entries must include a non-empty `feature_id`.", class = "ledgr_invalid_runtime_projection")
    }
    if (!is.null(feature_values[[feature_id]])) {
      rlang::abort(
        sprintf("Runtime projection cannot represent duplicate concrete feature ID `%s`.", feature_id),
        class = "ledgr_invalid_runtime_projection"
      )
    }
    mat <- matrix(NA_real_, nrow = length(universe), ncol = length(pulses_posix))
    for (j in seq_along(universe)) {
      values <- entry$values[[universe[[j]]]]
      if (is.null(values)) {
        next
      }
      mat[j, seq_along(values)] <- as.numeric(values)
    }
    feature_values[[feature_id]] <- mat
  }

  ledgr_runtime_projection(
    feature_values = feature_values,
    universe = universe,
    pulses_posix = pulses_posix,
    feature_engine_version = feature_engine_version,
    alias_index = alias_index
  )
}

ledgr_projection_feature_ids <- function(projection, feature_ids = NULL) {
  if (is.null(feature_ids)) {
    return(names(projection$feature_values))
  }
  feature_ids <- as.character(feature_ids)
  feature_ids[!is.na(feature_ids) & nzchar(feature_ids)]
}

ledgr_projection_feature_at <- function(projection,
                                        instrument_id,
                                        feature_id,
                                        pulse_idx,
                                        default = NA_real_,
                                        available_features = NULL) {
  if (!is.character(instrument_id) || length(instrument_id) != 1L || is.na(instrument_id) || !nzchar(instrument_id)) {
    rlang::abort("`instrument_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  if (!is.character(feature_id) || length(feature_id) != 1L || is.na(feature_id) || !nzchar(feature_id)) {
    rlang::abort("`feature_name` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  available_features <- ledgr_projection_feature_ids(projection, available_features)
  if (length(available_features) == 0L || !(feature_id %in% available_features)) {
    rlang::abort(
      sprintf(
        "Unknown feature ID `%s` for instrument_id `%s`. Available feature IDs: %s.",
        feature_id,
        instrument_id,
        ledgr_feature_names_message(sort(available_features))
      ),
      class = "ledgr_unknown_feature_id"
    )
  }

  inst_idx <- unname(projection$instrument_index[instrument_id])
  if (length(inst_idx) != 1L || is.na(inst_idx)) {
    return(default)
  }
  mat <- projection$feature_values[[feature_id]]
  if (is.null(mat)) {
    return(default)
  }
  mat[[as.integer(inst_idx), as.integer(pulse_idx)]]
}

ledgr_split_pulse_data_frame <- function(data, pulse_idx, n_pulses) {
  pulse_factor <- factor(pulse_idx, levels = seq_len(n_pulses))
  views <- unname(split(data, pulse_factor, drop = FALSE))
  for (i in seq_along(views)) {
    rownames(views[[i]]) <- NULL
  }
  views
}

ledgr_projection_feature_table <- function(projection, pulse_idx, feature_ids = NULL) {
  feature_ids <- ledgr_projection_feature_ids(projection, feature_ids)
  if (length(feature_ids) == 0L) {
    return(ledgr_projection_feature_table_schema())
  }
  instruments <- names(projection$instrument_index)
  n_inst <- length(instruments)
  n_def <- length(feature_ids)
  feature_value <- unlist(
    lapply(feature_ids, function(feature_id) {
      mat <- projection$feature_values[[feature_id]]
      if (is.null(mat)) {
        return(rep(NA_real_, n_inst))
      }
      as.numeric(mat[, pulse_idx])
    }),
    use.names = FALSE
  )
  out <- data.frame(
    instrument_id = rep(instruments, times = n_def),
    ts_utc = as.POSIXct(rep(projection$pulses_posix[[pulse_idx]], n_inst * n_def), tz = "UTC"),
    feature_name = rep(feature_ids, each = n_inst),
    feature_value = feature_value,
    stringsAsFactors = FALSE
  )
  out
}

ledgr_projection_feature_table_schema <- function() {
  data.frame(
    instrument_id = character(),
    ts_utc = as.POSIXct(character(), tz = "UTC"),
    feature_name = character(),
    feature_value = numeric(),
    stringsAsFactors = FALSE
  )
}

ledgr_projection_features_wide <- function(projection, pulse_idx, feature_ids = NULL) {
  feature_ids <- ledgr_projection_feature_ids(projection, feature_ids)
  if (length(feature_ids) == 0L) {
    return(data.frame())
  }
  instruments <- names(projection$instrument_index)
  values <- matrix(
    NA_real_,
    nrow = length(instruments),
    ncol = length(feature_ids),
    dimnames = list(instruments, feature_ids)
  )
  for (feature_id in feature_ids) {
    mat <- projection$feature_values[[feature_id]]
    if (!is.null(mat)) {
      values[, feature_id] <- as.numeric(mat[, pulse_idx])
    }
  }
  out <- data.frame(
    instrument_id = instruments,
    ts_utc = rep(projection$pulses_iso[[pulse_idx]], length(instruments)),
    stringsAsFactors = FALSE
  )
  out <- cbind(out, as.data.frame(values, check.names = FALSE, stringsAsFactors = FALSE))
  rownames(out) <- NULL
  out
}

ledgr_projection_pulse_views <- function(projection,
                                         feature_ids = NULL,
                                         feature_table = c("schema", "full")) {
  feature_table <- match.arg(feature_table)
  n_pulses <- length(projection$pulses_posix)
  feature_table_views <- vector("list", n_pulses)
  features_wide <- vector("list", n_pulses)
  if (n_pulses == 0L) {
    return(list(feature_table = feature_table_views, features_wide = features_wide))
  }

  feature_ids <- ledgr_projection_feature_ids(projection, feature_ids)
  instruments <- names(projection$instrument_index)
  n_inst <- length(instruments)
  n_def <- length(feature_ids)
  if (n_inst == 0L || n_def == 0L) {
    for (pulse_idx in seq_len(n_pulses)) {
      feature_table_views[[pulse_idx]] <- ledgr_projection_feature_table(
        projection,
        pulse_idx,
        feature_ids = if (identical(feature_table, "full")) feature_ids else character()
      )
      features_wide[[pulse_idx]] <- ledgr_projection_features_wide(
        projection,
        pulse_idx,
        feature_ids = feature_ids
      )
    }
    return(list(feature_table = feature_table_views, features_wide = features_wide))
  }

  feature_wide_values <- matrix(
    NA_real_,
    nrow = n_inst * n_pulses,
    ncol = n_def,
    dimnames = list(NULL, feature_ids)
  )
  for (feature_idx in seq_along(feature_ids)) {
    feature_id <- feature_ids[[feature_idx]]
    mat <- projection$feature_values[[feature_id]]
    if (is.null(mat)) {
      next
    }
    feature_wide_values[, feature_idx] <- as.numeric(as.vector(mat))
  }

  if (identical(feature_table, "full")) {
    feature_array <- array(NA_real_, dim = c(n_inst, n_def, n_pulses))
    for (feature_idx in seq_along(feature_ids)) {
      feature_id <- feature_ids[[feature_idx]]
      mat <- projection$feature_values[[feature_id]]
      if (!is.null(mat)) {
        feature_array[, feature_idx, ] <- mat
      }
    }
    feature_table_all <- data.frame(
      instrument_id = rep(rep(instruments, times = n_def), times = n_pulses),
      ts_utc = as.POSIXct(rep(projection$pulses_posix, each = n_inst * n_def), tz = "UTC"),
      feature_name = rep(rep(feature_ids, each = n_inst), times = n_pulses),
      feature_value = as.numeric(as.vector(feature_array)),
      stringsAsFactors = FALSE
    )
    feature_table_views <- ledgr_split_pulse_data_frame(
      feature_table_all,
      rep(seq_len(n_pulses), each = n_inst * n_def),
      n_pulses
    )
  } else {
    feature_table_views <- replicate(n_pulses, ledgr_projection_feature_table_schema(), simplify = FALSE)
  }

  features_wide_all <- data.frame(
    instrument_id = rep(instruments, times = n_pulses),
    ts_utc = rep(projection$pulses_iso, each = n_inst),
    stringsAsFactors = FALSE
  )
  features_wide_all <- cbind(
    features_wide_all,
    as.data.frame(feature_wide_values, check.names = FALSE, stringsAsFactors = FALSE)
  )
  features_wide <- ledgr_split_pulse_data_frame(
    features_wide_all,
    rep(seq_len(n_pulses), each = n_inst),
    n_pulses
  )

  list(
    feature_table = feature_table_views,
    features_wide = features_wide
  )
}

ledgr_projection_feature_accessor <- function(projection, pulse_idx, feature_ids = NULL) {
  force(projection)
  force(pulse_idx)
  pulse_idx <- as.integer(pulse_idx)
  available_features <- ledgr_projection_feature_ids(projection, feature_ids)
  available_message <- ledgr_feature_names_message(sort(available_features))
  instrument_index <- projection$instrument_index
  feature_values <- projection$feature_values
  function(instrument_id, feature_name, default = NA_real_) {
    if (!is.character(instrument_id) || length(instrument_id) != 1L || is.na(instrument_id) || !nzchar(instrument_id)) {
      rlang::abort("`instrument_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
    }
    if (!is.character(feature_name) || length(feature_name) != 1L || is.na(feature_name) || !nzchar(feature_name)) {
      rlang::abort("`feature_name` must be a non-empty character scalar.", class = "ledgr_invalid_args")
    }
    if (length(available_features) == 0L || !(feature_name %in% available_features)) {
      rlang::abort(
        sprintf(
          "Unknown feature ID `%s` for instrument_id `%s`. Available feature IDs: %s.",
          feature_name,
          instrument_id,
          available_message
        ),
        class = "ledgr_unknown_feature_id"
      )
    }
    inst_idx <- unname(instrument_index[instrument_id])
    if (length(inst_idx) != 1L || is.na(inst_idx)) {
      return(default)
    }
    mat <- feature_values[[feature_name]]
    if (is.null(mat)) {
      return(default)
    }
    mat[[as.integer(inst_idx), pulse_idx]]
  }
}

ledgr_projection_feature_accessor_state <- function(projection, state, feature_ids = NULL) {
  force(projection)
  force(state)
  available_features <- ledgr_projection_feature_ids(projection, feature_ids)
  available_message <- ledgr_feature_names_message(sort(available_features))
  instrument_index <- projection$instrument_index
  feature_values <- projection$feature_values
  function(instrument_id, feature_name, default = NA_real_) {
    if (!is.character(instrument_id) || length(instrument_id) != 1L || is.na(instrument_id) || !nzchar(instrument_id)) {
      rlang::abort("`instrument_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
    }
    if (!is.character(feature_name) || length(feature_name) != 1L || is.na(feature_name) || !nzchar(feature_name)) {
      rlang::abort("`feature_name` must be a non-empty character scalar.", class = "ledgr_invalid_args")
    }
    if (length(available_features) == 0L || !(feature_name %in% available_features)) {
      rlang::abort(
        sprintf(
          "Unknown feature ID `%s` for instrument_id `%s`. Available feature IDs: %s.",
          feature_name,
          instrument_id,
          available_message
        ),
        class = "ledgr_unknown_feature_id"
      )
    }
    inst_idx <- unname(instrument_index[instrument_id])
    if (length(inst_idx) != 1L || is.na(inst_idx)) {
      return(default)
    }
    mat <- feature_values[[feature_name]]
    if (is.null(mat)) {
      return(default)
    }
    mat[[as.integer(inst_idx), as.integer(state$pulse_idx)]]
  }
}

ledgr_projection_feature_bundle_accessor <- function(projection, pulse_idx, universe, feature_ids = NULL, active_alias_map = NULL) {
  force(projection)
  force(pulse_idx)
  feature <- ledgr_projection_feature_accessor(projection, pulse_idx, feature_ids)
  universe <- as.character(universe)

  function(instrument_id, feature_map = NULL) {
    if (!is.character(instrument_id) || length(instrument_id) != 1L || is.na(instrument_id) || !nzchar(instrument_id)) {
      rlang::abort("`instrument_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
    }
    if (!(instrument_id %in% universe)) {
      rlang::abort(
        sprintf(
          "Unknown instrument_id '%s'. Available ctx$universe: %s.",
          instrument_id,
          ledgr_pulse_context_universe_message(universe)
        ),
        class = "ledgr_invalid_pulse_context"
      )
    }

    lookup_map <- ledgr_feature_lookup_map(feature_map, active_alias_map = active_alias_map)
    values <- vapply(lookup_map, function(feature_id) {
      value <- feature(instrument_id, feature_id)
      if (!is.numeric(value) || length(value) != 1L) {
        rlang::abort(
          sprintf(
            "Feature `%s` for instrument_id `%s` must be a scalar numeric value.",
            feature_id,
            instrument_id
          ),
          class = "ledgr_invalid_feature_value"
        )
      }
      as.numeric(value)
    }, numeric(1))

    stats::setNames(unname(values), names(lookup_map))
  }
}

ledgr_projection_feature_bundle_accessor_state <- function(projection, state, universe, feature_ids = NULL, active_alias_map = NULL) {
  force(projection)
  force(state)
  feature <- ledgr_projection_feature_accessor_state(projection, state, feature_ids)
  universe <- as.character(universe)

  function(instrument_id, feature_map = NULL) {
    if (!is.character(instrument_id) || length(instrument_id) != 1L || is.na(instrument_id) || !nzchar(instrument_id)) {
      rlang::abort("`instrument_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
    }
    if (!(instrument_id %in% universe)) {
      rlang::abort(
        sprintf(
          "Unknown instrument_id '%s'. Available ctx$universe: %s.",
          instrument_id,
          ledgr_pulse_context_universe_message(universe)
        ),
        class = "ledgr_invalid_pulse_context"
      )
    }

    lookup_map <- ledgr_feature_lookup_map(feature_map, active_alias_map = active_alias_map)
    values <- vapply(lookup_map, function(feature_id) {
      value <- feature(instrument_id, feature_id)
      if (!is.numeric(value) || length(value) != 1L) {
        rlang::abort(
          sprintf(
            "Feature `%s` for instrument_id `%s` must be a scalar numeric value.",
            feature_id,
            instrument_id
          ),
          class = "ledgr_invalid_feature_value"
        )
      }
      as.numeric(value)
    }, numeric(1))

    stats::setNames(unname(values), names(lookup_map))
  }
}
