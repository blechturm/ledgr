ledgr_pulse_context <- function(run_id,
                                ts_utc,
                                universe,
                                bars,
                                features = data.frame(),
                                positions = numeric(),
                                cash,
                                equity,
                                seed = NULL,
                                pulse_seed = NULL,
                                state_prev = NULL,
                                safety_state = "GREEN") {
  ctx <- list(
    run_id = run_id,
    ts_utc = ledgr_normalize_ts_utc(ts_utc),
    universe = universe,
    bars = bars,
    feature_table = features,
    .positions = positions,
    cash = cash,
    equity = equity,
    seed = seed,
    pulse_seed = pulse_seed,
    state_prev = state_prev,
    members = universe,
    .safety_state = safety_state
  )

  class(ctx) <- "ledgr_pulse_context"
  ctx <- ledgr_update_pulse_context_helpers(ctx)
  ledgr_validate_pulse_context(ctx)
  ctx
}

# The author-facing context is a strict lazy list.  The ordinary list stores
# portfolio values and the four WS6-owned frame/bar surfaces; asset columns
# live behind the pulse-local lookup so a read can be cached without mutating
# the list (and without retaining a mutable fold buffer).
ledgr_pulse_context_asset_fields <- function() {
  c(
    "open", "high", "low", "close", "volume", "position", "held",
    "member", "buyable", "holding_value", "entry_price", "entry_at",
    "exit_at", "bars_since_entry", "bars_since_exit"
  )
}

ledgr_pulse_context_retired_fields <- function() {
  c("vec", "feature", "features", "position", "idx", "tradable")
}

ledgr_pulse_context_reserved_fields <- function() {
  unique(c(
    "run_id", "ts_utc", "universe", "members", "bars", "bar",
    "feature_table", "features_wide", "cash", "equity", "seed",
    "pulse_seed", "state_prev", "state", "flat", "hold",
    ledgr_pulse_context_asset_fields(), ledgr_pulse_context_retired_fields()
  ))
}

ledgr_pulse_context_feature_columns <- function(lookup) {
  prepared <- lookup$feature_lookup
  if (!is.list(prepared)) return(character())
  aliases <- as.character(prepared$name_lookup$aliases %||% character())
  ids <- as.character(prepared$name_lookup$feature_ids %||% character())
  mapped <- unname(prepared$name_lookup$alias_map %||% character())
  c(aliases, setdiff(ids, mapped))
}

ledgr_pulse_context_feature_reads <- function(lookup) {
  prepared <- lookup$feature_lookup
  if (!is.list(prepared)) return(character())
  aliases <- as.character(prepared$name_lookup$aliases %||% character())
  ids <- as.character(prepared$name_lookup$feature_ids %||% character())
  unique(c(aliases, ids))
}

ledgr_pulse_context_available_fields <- function(x) {
  lookup <- unclass(x)[[".pulse_lookup"]]
  stored <- names(unclass(x))
  stored <- stored[!startsWith(stored, ".")]
  stored <- setdiff(stored, ledgr_pulse_context_retired_fields())
  unique(c(stored, ledgr_pulse_context_asset_fields(),
    ledgr_pulse_context_feature_columns(lookup)))
}

ledgr_pulse_context_cache_set <- function(lookup, name, value) {
  if (is.environment(lookup$build_counts)) {
    count <- lookup$build_counts[[name]] %||% 0L
    lookup$build_counts[[name]] <- as.integer(count + 1L)
  }
  assign(name, value, envir = lookup$cache)
  value
}

ledgr_pulse_context_named <- function(value, universe) {
  stats::setNames(value, universe)
}

ledgr_pulse_context_lazy_field <- function(x, name) {
  lookup <- unclass(x)[[".pulse_lookup"]]
  if (!is.environment(lookup) || !is.environment(lookup$cache)) {
    rlang::abort("Pulse context lazy service is not initialized.", class = "ledgr_invalid_pulse_context")
  }
  if (exists(name, envir = lookup$cache, inherits = FALSE)) {
    return(get(name, envir = lookup$cache, inherits = FALSE))
  }
  ids <- as.character(lookup$universe %||% character())
  if (name %in% c("open", "high", "low", "close", "volume")) {
    value <- ledgr_pulse_context_named(ledgr_pulse_context_vector_field(lookup, name), ids)
  } else if (identical(name, "position")) {
    value <- ledgr_pulse_context_named(ledgr_pulse_context_vector_positions(lookup), ids)
  } else if (name %in% c("held", "member")) {
    value <- lookup$availability[[name]]
    if (!isTRUE(lookup$availability_aligned)) value <- value[ids]
    value <- ledgr_pulse_context_named(as.logical(value), ids)
  } else if (identical(name, "buyable")) {
    member <- lookup$availability$member
    restricted <- lookup$availability$target_restricted
    if (!isTRUE(lookup$availability_aligned)) {
      member <- member[ids]
      restricted <- restricted[ids]
    }
    member <- as.logical(member)
    restricted <- as.logical(restricted)
    value <- ledgr_pulse_context_named(member & !restricted, ids)
  } else if (identical(name, "holding_value")) {
    position <- ledgr_pulse_context_vector_positions(lookup)
    held <- position != 0
    mark <- lookup$availability$risk_mark
    if (!isTRUE(lookup$availability_aligned)) mark <- mark[ids]
    mark <- as.numeric(mark)
    value <- numeric(length(ids))
    value[held] <- position[held] * mark[held]
    value[held & !is.finite(mark)] <- NA_real_
    value <- ledgr_pulse_context_named(value, ids)
  } else if (name %in% c("entry_price", "entry_at", "exit_at", "bars_since_entry", "bars_since_exit")) {
    value <- if (is.list(lookup$position_facts) && !is.null(lookup$position_facts$context_pos)) {
      ledgr_position_fact_field(lookup$position_facts, name)
    } else {
      lookup$position_facts[[name]]
    }
    if (is.null(value)) {
      value <- if (name %in% c("entry_at", "exit_at")) {
        as.POSIXct(rep(NA_real_, length(ids)), origin = "1970-01-01", tz = "UTC")
      } else if (identical(name, "bars_since_exit")) {
        rep(Inf, length(ids))
      } else {
        rep(NA_real_, length(ids))
      }
    }
    value <- ledgr_pulse_context_named(value, ids)
  } else if (name %in% ledgr_pulse_context_feature_reads(lookup)) {
    value <- lookup$feature_vector(name)
    value <- ledgr_pulse_context_named(as.numeric(value), ids)
  } else {
    rlang::abort(
      sprintf("Unknown pulse context field `%s`.", name),
      class = c("ledgr_unknown_context_field", "ledgr_invalid_pulse_context")
    )
  }
  ledgr_pulse_context_cache_set(lookup, name, value)
}

#' @export
`$.ledgr_pulse_context` <- function(x, name) {
  raw <- unclass(x)
  if (name %in% ledgr_pulse_context_retired_fields() &&
      !name %in% c("position")) {
    rlang::abort(
      sprintf("`ctx$%s` is not part of the flat strategy context; read a named context column instead.", name),
      class = c("ledgr_unknown_context_field", "ledgr_invalid_pulse_context")
    )
  }
  if (name %in% names(raw) && !startsWith(name, ".")) return(raw[[name]])
  if (name %in% c(ledgr_pulse_context_asset_fields(),
      ledgr_pulse_context_feature_reads(raw[[".pulse_lookup"]]))) {
    return(ledgr_pulse_context_lazy_field(x, name))
  }
  if (startsWith(name, ".") && name %in% names(raw)) return(raw[[name]])
  rlang::abort(
    sprintf("Unknown pulse context field `%s`.", name),
    class = c("ledgr_unknown_context_field", "ledgr_invalid_pulse_context")
  )
}

#' @export
`[[.ledgr_pulse_context` <- function(x, i, ...) {
  if (!is.character(i) || length(i) != 1L || is.na(i) || !nzchar(i)) {
    rlang::abort("A pulse context field name must be one non-empty string.", class = "ledgr_invalid_args")
  }
  `$.ledgr_pulse_context`(x, i)
}

#' @export
names.ledgr_pulse_context <- function(x) ledgr_pulse_context_available_fields(x)

#' @export
str.ledgr_pulse_context <- function(object, ...) {
  cat("List of ", length(names(object)), " pulse-frozen fields\n", sep = "")
  cat(" $ ", paste(names(object), collapse = "\n $ "), "\n", sep = "")
  invisible(object)
}

ledgr_feature_table_ready <- function(features) {
  !is.null(features) &&
    all(c("instrument_id", "feature_name", "feature_value") %in% names(features)) &&
    length(features[["feature_value"]]) > 0
}

ledgr_feature_names <- function(features) {
  if (!ledgr_feature_table_ready(features)) return(character(0))
  feature_names <- unique(as.character(features[["feature_name"]]))
  sort(
    feature_names[!is.na(feature_names) & nzchar(feature_names)],
    method = "radix"
  )
}

ledgr_feature_names_message <- function(feature_names) {
  if (length(feature_names) == 0L) return("<none>")
  paste(feature_names, collapse = ", ")
}

ledgr_feature_accessor <- function(features,
                                   active_alias_map = NULL,
                                   prepared = NULL) {
  force(features)
  available_features <- ledgr_feature_names(features)
  if (is.null(prepared)) {
    prepared <- ledgr_feature_name_lookup_state(
      available_features,
      active_alias_map = active_alias_map
    )
  }

  function(instrument_id, feature_name, default = NA_real_) {
    if (!is.character(instrument_id) || length(instrument_id) != 1L || is.na(instrument_id) || !nzchar(instrument_id)) {
      rlang::abort("`instrument_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
    }
    feature_name <- ledgr_resolve_feature_name(
      feature_name,
      prepared,
      instrument_id = instrument_id
    )

    idx <- which(
      as.character(features[["instrument_id"]]) == instrument_id &
        as.character(features[["feature_name"]]) == feature_name
    )
    if (length(idx) == 0L) return(default)

    features[["feature_value"]][[idx[[length(idx)]]]]
  }
}

ledgr_feature_bundle_accessor <- function(features,
                                          universe,
                                          active_alias_map = NULL,
                                          prepared = NULL) {
  force(features)
  if (is.null(prepared)) {
    prepared <- ledgr_feature_name_lookup_state(
      ledgr_feature_names(features),
      active_alias_map = active_alias_map
    )
  }
  feature <- ledgr_feature_accessor(features, prepared = prepared)
  universe <- as.character(universe)
  active_lookup <- prepared$alias_map

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

    lookup_map <- if (is.null(feature_map) && !is.null(active_lookup)) {
      active_lookup
    } else {
      ledgr_explicit_feature_lookup(feature_map, prepared)
    }

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

ledgr_feature_vector_accessor <- function(features,
                                          universe,
                                          active_alias_map = NULL,
                                          prepared = NULL) {
  force(features)
  universe <- as.character(universe)
  available_features <- ledgr_feature_names(features)
  if (is.null(prepared)) {
    prepared <- ledgr_feature_name_lookup_state(
      available_features,
      active_alias_map = active_alias_map
    )
  }

  function(feature_name, default = NA_real_) {
    feature_name <- ledgr_resolve_feature_name(feature_name, prepared)

    out <- rep(as.numeric(default), length(universe))
    instrument_id <- as.character(features[["instrument_id"]])
    feature_id <- as.character(features[["feature_name"]])
    values <- as.numeric(features[["feature_value"]])
    keep <- feature_id == feature_name
    if (any(keep)) {
      idx <- match(instrument_id[keep], universe, nomatch = 0L)
      valid <- idx > 0L
      out[idx[valid]] <- values[keep][valid]
    }
    out
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

  row_index <- match(instrument_id, instruments)
  column_index <- match(feature_name, feature_names)
  values[cbind(row_index, column_index)] <- feature_value

  out <- data.frame(instrument_id = instruments, stringsAsFactors = FALSE)
  if ("ts_utc" %in% names(features)) {
    ts_utc <- vapply(features[["ts_utc"]][valid], ledgr_iso_utc, character(1))
    out$ts_utc <- ts_utc[match(instruments, instrument_id)]
  }

  out <- cbind(out, as.data.frame(values, check.names = FALSE, stringsAsFactors = FALSE))
  rownames(out) <- NULL
  out
}

ledgr_attach_feature_helpers <- function(ctx,
                                         features = ctx$feature_table,
                                         universe = ctx$universe,
                                         projection = NULL,
                                         pulse_idx = NULL,
                                         feature_ids = NULL,
                                         features_wide = NULL,
                                         active_alias_map = NULL,
                                         feature_name_state = NULL,
                                         feature_lookup_state = NULL) {
  if (!is.null(projection)) {
    prepared_feature_lookup <- feature_lookup_state
    if (is.null(prepared_feature_lookup)) {
      prepared_feature_lookup <- ledgr_projection_feature_lookup_state(
        projection,
        feature_ids = feature_ids,
        universe = universe,
        active_alias_map = active_alias_map,
        feature_name_state = feature_name_state
      )
    }
    if (!is.data.frame(features)) {
      features <- ledgr_projection_feature_table(projection, pulse_idx, feature_ids = feature_ids)
    }
    if (!is.data.frame(features_wide)) {
      features_wide <- ledgr_projection_features_wide(projection, pulse_idx, feature_ids = feature_ids)
    }
    feature_vector <- ledgr_projection_feature_vector_accessor(
      projection,
      pulse_idx,
      feature_ids = feature_ids,
      prepared = prepared_feature_lookup
    )
    current_pulse_idx <- as.integer(pulse_idx)
    current_feature_ids <- ledgr_projection_feature_ids(projection, feature_ids)
    ctx$.pulse_lookup$feature_lookup <- prepared_feature_lookup
    feature_table_current <- function() {
      ledgr_projection_feature_table(
        projection,
        current_pulse_idx,
        feature_ids = current_feature_ids
      )
    }
    if (is.environment(ctx)) {
      ctx$feature_table <- features
      ctx$features_wide <- features_wide
      ctx$.feature_table_current <- feature_table_current
      ctx$.feature_vector <- feature_vector
      return(invisible(ctx))
    }

    ctx$feature_table <- features
    ctx$features_wide <- features_wide
    ctx$.feature_table_current <- feature_table_current
    ctx$.feature_vector <- feature_vector
    return(ctx)
  }

  prepared_feature_lookup <- ledgr_feature_name_lookup_state(
    ledgr_feature_names(features),
    active_alias_map = active_alias_map
  )
  feature_vector <- ledgr_feature_vector_accessor(
    features,
    universe,
    prepared = prepared_feature_lookup
  )
  ctx$.pulse_lookup$feature_lookup <- list(name_lookup = prepared_feature_lookup)

  if (is.environment(ctx)) {
    ctx$feature_table <- features
    ctx$features_wide <- ledgr_features_wide(features)
    ctx$.feature_table_current <- NULL
    ctx$.feature_vector <- feature_vector
    return(invisible(ctx))
  }

  ctx$feature_table <- features
  ctx$features_wide <- ledgr_features_wide(features)
  ctx$.feature_table_current <- NULL
  ctx$.feature_vector <- feature_vector
  ctx
}

ledgr_update_pulse_context_helpers <- function(ctx,
                                               bars = ctx$bars,
                                               features = if (is.data.frame(ctx$feature_table)) ctx$feature_table else data.frame(),
                                               positions = ctx$.positions,
                                               universe = ctx$universe,
                                               projection = NULL,
                                               pulse_idx = NULL,
                                               feature_ids = NULL,
                                               features_wide = NULL,
                                               active_alias_map = NULL,
                                               feature_name_state = NULL,
                                               feature_lookup_state = NULL,
                                               id_to_idx = NULL,
                                               availability = NULL,
                                               position_facts = NULL,
                                               build_counts = NULL,
                                               preparation_counts = NULL,
                                               bars_aligned = FALSE,
                                               positions_aligned = FALSE,
                                               availability_aligned = FALSE) {
  ctx <- ledgr_ensure_pulse_context_accessors(ctx)
  ctx <- ledgr_attach_feature_helpers(
    ctx,
    features,
    universe = universe,
    projection = projection,
    pulse_idx = pulse_idx,
    feature_ids = feature_ids,
    features_wide = features_wide,
    active_alias_map = active_alias_map,
    feature_name_state = feature_name_state,
    feature_lookup_state = feature_lookup_state
  )
  ledgr_refresh_pulse_context_lookup(
    ctx,
    bars = bars,
    positions = positions,
    universe = universe,
    id_to_idx = id_to_idx,
    availability = availability,
    position_facts = position_facts,
    build_counts = build_counts,
    preparation_counts = preparation_counts,
    bars_aligned = bars_aligned,
    positions_aligned = positions_aligned,
    availability_aligned = availability_aligned
  )
}

ledgr_filter_pulse_context_features <- function(ctx, universe, private_universe,
                                                context_pos = NULL) {
  universe <- as.character(universe)
  private_universe <- as.character(private_universe)
  raw <- unclass(ctx)
  feature_vector <- raw$.feature_vector
  force(feature_vector)
  context_index <- context_pos %||% match(universe, private_universe)
  ctx$.feature_vector <- function(feature_name, default = NA_real_) {
    feature_vector(feature_name, default = default)[context_index]
  }
  ctx$.pulse_lookup$feature_vector <- ctx$.feature_vector
  feature_table_current <- raw$.feature_table_current
  if (is.function(feature_table_current)) force(feature_table_current)
  if (is.function(feature_table_current)) {
    ctx$.feature_table_current <- function() {
      table <- feature_table_current()
      table[as.character(table$instrument_id) %in% universe, , drop = FALSE]
    }
  }
  ctx
}

ledgr_pulse_context_helper_bundle <- function(lookup) {
  bar <- function(id) ledgr_pulse_context_bar(lookup, id)
  flat <- function(default = 0) ledgr_pulse_context_targets(lookup, default = default)
  hold <- function() ledgr_pulse_context_current_targets(lookup)

  list(
    .pulse_lookup = lookup,
    bar = bar,
    flat = flat,
    hold = hold
  )
}

ledgr_ensure_pulse_context_accessors <- function(ctx) {
  lookup <- unclass(ctx)[[".pulse_lookup"]]
  if (!is.environment(lookup)) {
    lookup <- new.env(parent = emptyenv())
  }
  helpers <- ledgr_pulse_context_helper_bundle(lookup)

  if (is.environment(ctx)) {
    for (name in names(helpers)) {
      ctx[[name]] <- helpers[[name]]
    }
    return(ctx)
  }

  for (name in names(helpers)) {
    ctx[[name]] <- helpers[[name]]
  }
  ctx
}

ledgr_refresh_pulse_context_lookup <- function(ctx,
                                               bars = ctx$bars,
                                               positions = ctx$.positions,
                                               universe = ctx$universe,
                                               id_to_idx = NULL,
                                               availability = NULL,
                                               position_facts = NULL,
                                               build_counts = NULL,
                                               preparation_counts = NULL,
                                               bars_aligned = FALSE,
                                               positions_aligned = FALSE,
                                               availability_aligned = FALSE) {
  lookup <- ctx$.pulse_lookup
  if (!is.environment(lookup)) {
    rlang::abort("Pulse context accessors have not been initialized.", class = "ledgr_invalid_pulse_context")
  }

  universe <- as.character(universe)
  lookup$bars <- if (isTRUE(bars_aligned)) bars else if (is.data.frame(bars)) as.data.frame(bars, stringsAsFactors = FALSE) else lapply(bars, identity)
  lookup$positions <- if (is.null(positions)) NULL else if (isTRUE(positions_aligned)) positions else structure(as.numeric(positions), names = names(positions))
  lookup$universe <- universe
  lookup$id_to_idx <- ledgr_pulse_context_id_to_idx(universe, id_to_idx)
  lookup$feature_vector <- ctx$.feature_vector
  lookup$bar_index <- if (isTRUE(bars_aligned)) integer() else ledgr_pulse_context_bar_index(bars, universe)
  if (!is.list(availability)) {
    availability <- ledgr_pulse_context_default_availability(
      universe,
      positions,
      bars
    )
  }
  lookup$availability <- if (isTRUE(availability_aligned)) {
    availability
  } else {
    lapply(availability, function(value) {
      if (is.atomic(value)) structure(value, names = names(value)) else value
    })
  }
  lookup$bars_aligned <- isTRUE(bars_aligned)
  lookup$positions_aligned <- isTRUE(positions_aligned)
  lookup$availability_aligned <- isTRUE(availability_aligned)
  lookup$position_facts <- position_facts
  lookup$cache <- new.env(parent = emptyenv())
  lookup$build_counts <- build_counts
  lookup$preparation_counts <- preparation_counts
  if (is.environment(ctx)) {
    return(invisible(ctx))
  }
  ctx
}

ledgr_pulse_context_default_availability <- function(universe, positions, bars) {
  universe <- as.character(universe)
  held <- rep(FALSE, length(universe))
  if (is.numeric(positions) && length(positions) > 0L) {
    if (is.null(names(positions))) {
      if (length(positions) == length(universe)) held <- positions != 0
    } else {
      idx <- match(names(positions), universe, nomatch = 0L)
      keep <- idx > 0L
      held[idx[keep]] <- positions[keep] != 0
    }
  }
  close <- rep(NA_real_, length(universe))
  bar_index <- ledgr_pulse_context_bar_index(bars, universe)
  if (length(bar_index) > 0L && "close" %in% names(bars)) {
    idx <- as.integer(bar_index[universe])
    present <- !is.na(idx)
    close[present] <- as.numeric(bars$close[idx[present]])
  }
  priced <- is.finite(close) & close > 0
  list(
    member = stats::setNames(rep(TRUE, length(universe)), universe),
    held = stats::setNames(held, universe),
    target_restricted = stats::setNames(rep(FALSE, length(universe)), universe),
    target_restriction_reason = stats::setNames(rep("", length(universe)), universe),
    priced = stats::setNames(priced, universe),
    mark_age = stats::setNames(rep(0L, length(universe)), universe),
    risk_mark = stats::setNames(close, universe),
    mark_source = stats::setNames(ifelse(priced, "current_close", ""), universe)
  )
}

ledgr_pulse_context_id_to_idx <- function(universe, id_to_idx = NULL) {
  universe <- as.character(universe)
  if (is.null(id_to_idx)) {
    return(stats::setNames(as.integer(seq_along(universe)), universe))
  }
  out <- as.integer(id_to_idx)
  names(out) <- names(id_to_idx)
  if (!identical(names(out), universe) ||
      !identical(as.integer(out), as.integer(seq_along(universe)))) {
    rlang::abort("Pulse context `id_to_idx` must align with ctx$universe.", class = "ledgr_invalid_pulse_context")
  }
  out
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

ledgr_pulse_context_vector_field <- function(lookup, field) {
  universe <- as.character(lookup$universe %||% character())
  if (!(field %in% names(lookup$bars))) {
    return(rep(NA_real_, length(universe)))
  }
  values <- ledgr_pulse_context_column(lookup$bars, field)
  if (isTRUE(lookup$bars_aligned)) return(as.numeric(values))
  out <- rep(NA_real_, length(universe))
  bar_index <- lookup$bar_index
  if (length(bar_index) > 0L) {
    row_idx <- as.integer(bar_index[universe])
    valid <- !is.na(row_idx)
    out[valid] <- as.numeric(values[row_idx[valid]])
  }
  out
}

ledgr_pulse_context_vector_positions <- function(lookup) {
  universe <- as.character(lookup$universe %||% character())
  positions <- lookup$positions
  if (is.null(positions) || length(positions) == 0L) {
    return(rep(0, length(universe)))
  }
  if (!is.numeric(positions)) {
    rlang::abort("Pulse context `positions` must be numeric.", class = "ledgr_invalid_pulse_context")
  }
  if (isTRUE(lookup$positions_aligned)) return(as.numeric(positions))
  if (!is.null(names(positions))) {
    out <- rep(0, length(universe))
    idx <- match(names(positions), universe, nomatch = 0L)
    valid <- idx > 0L
    out[idx[valid]] <- as.numeric(positions[valid])
    return(out)
  }
  if (length(positions) != length(universe)) {
    rlang::abort("Pulse context primitive `positions` must align with ctx$universe.", class = "ledgr_invalid_pulse_context")
  }
  as.numeric(positions)
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

ledgr_pulse_context_targets <- function(lookup, default = 0) {
  if (!is.numeric(default) || length(default) != 1L || is.na(default) || !is.finite(default)) {
    rlang::abort("`default` must be a finite numeric scalar.", class = "ledgr_invalid_args")
  }
  universe <- lookup$universe
  if (is.null(universe)) universe <- character(0)
  stats::setNames(rep(as.numeric(default), length(universe)), universe)
}

ledgr_pulse_context_current_targets <- function(lookup) {
  universe <- lookup$universe
  if (is.null(universe)) universe <- character(0)
  universe <- as.character(universe)

  out <- stats::setNames(rep(0, length(universe)), universe)
  positions <- lookup$positions
  if (is.null(positions) || length(positions) == 0L) {
    return(out)
  }
  if (!is.numeric(positions)) {
    rlang::abort("Pulse context `positions` must be numeric.", class = "ledgr_invalid_pulse_context")
  }
  if (anyNA(positions) || any(!is.finite(positions))) {
    rlang::abort("Pulse context `positions` must contain only finite numbers.", class = "ledgr_invalid_pulse_context")
  }
  if (is.null(names(positions))) {
    if (length(positions) != length(universe)) {
      rlang::abort("Pulse context primitive `positions` must align with ctx$universe.", class = "ledgr_invalid_pulse_context")
    }
    out[] <- as.numeric(positions)
    return(out)
  }
  bad <- setdiff(names(positions), universe)
  if (length(bad) > 0L) {
    rlang::abort(
      sprintf("Pulse context `positions` contains instrument_ids not in universe: %s", paste(bad, collapse = ", ")),
      class = "ledgr_invalid_pulse_context"
    )
  }

  out[names(positions)] <- as.numeric(positions)
  out
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

  if (!is.character(ctx$universe) ||
      anyNA(ctx$universe) || any(!nzchar(ctx$universe))) {
    rlang::abort(
      "PulseContext `universe` must be a character vector of non-empty strings.",
      class = "ledgr_invalid_pulse_context"
    )
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

  feature_table <- ctx$feature_table
  if (is.null(feature_table)) {
    feature_table <- data.frame()
  }
  if (!is.data.frame(feature_table)) {
    rlang::abort("PulseContext `feature_table` must be a data.frame (or tibble).", class = "ledgr_invalid_pulse_context")
  }
  if (nrow(feature_table) > 0) {
    validate_df_ts(feature_table, "feature_table")
    validate_df_instruments(feature_table, "feature_table")
  }

  if (!is.numeric(ctx$.positions)) {
    rlang::abort("PulseContext private position state must be a named numeric vector.", class = "ledgr_invalid_pulse_context")
  }
  if (length(ctx$.positions) > 0) {
    if (is.null(names(ctx$.positions)) || any(!nzchar(names(ctx$.positions))) || anyDuplicated(names(ctx$.positions))) {
      rlang::abort("PulseContext private position state must have unique, non-empty names.", class = "ledgr_invalid_pulse_context")
    }
    bad <- setdiff(names(ctx$.positions), ctx$universe)
    if (length(bad) > 0) {
      rlang::abort(
        sprintf("PulseContext private position state contains instrument_ids not in universe: %s", paste(bad, collapse = ", ")),
        class = "ledgr_invalid_pulse_context"
      )
    }
    if (any(!is.finite(ctx$.positions))) {
      rlang::abort("PulseContext private position state must contain only finite numbers.", class = "ledgr_invalid_pulse_context")
    }
  }

  if (!is.numeric(ctx$cash) || length(ctx$cash) != 1 || is.na(ctx$cash) || !is.finite(ctx$cash)) {
    rlang::abort("PulseContext `cash` must be a finite numeric scalar.", class = "ledgr_invalid_pulse_context")
  }
  if (!is.numeric(ctx$equity) || length(ctx$equity) != 1 || is.na(ctx$equity) || !is.finite(ctx$equity)) {
    rlang::abort("PulseContext `equity` must be a finite numeric scalar.", class = "ledgr_invalid_pulse_context")
  }

  validate_optional_seed <- function(x, label) {
    if (is.null(x)) {
      return(invisible(TRUE))
    }
    if (!is.numeric(x) || length(x) != 1L || is.na(x) || !is.finite(x) || x %% 1 != 0) {
      rlang::abort(
        sprintf("PulseContext `%s` must be NULL or an integer-like scalar.", label),
        class = "ledgr_invalid_pulse_context"
      )
    }
    invisible(TRUE)
  }
  validate_optional_seed(ctx$seed, "seed")
  validate_optional_seed(ctx$pulse_seed, "pulse_seed")

  if (!is.null(ctx$state_prev)) {
    if (!(is.list(ctx$state_prev) || (is.character(ctx$state_prev) && length(ctx$state_prev) == 1))) {
      rlang::abort("PulseContext `state_prev` must be NULL or a JSON-safe list (or JSON string).", class = "ledgr_invalid_pulse_context")
    }
    invisible(canonical_json(ctx$state_prev))
  }

  if (!is.character(ctx$.safety_state) || length(ctx$.safety_state) != 1 || is.na(ctx$.safety_state) || !nzchar(ctx$.safety_state)) {
    rlang::abort("PulseContext private safety state must be a non-empty character scalar.", class = "ledgr_invalid_pulse_context")
  }

  invisible(TRUE)
}
