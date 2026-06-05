ledgr_alias_map_version <- function() {
  1L
}

ledgr_alias_map_from_feature_map <- function(feature_map) {
  ledgr_validate_feature_map_object(feature_map)
  feature_ids <- ledgr_feature_id(feature_map)
  ledgr_normalize_alias_map(feature_ids)
}

ledgr_alias_identity_map_from_feature_map <- function(feature_map) {
  ledgr_validate_feature_map_object(feature_map)
  identities <- vapply(
    feature_map$aliases,
    function(alias) ledgr_alias_feature_identity(feature_map$indicators[[alias]]),
    character(1)
  )
  ledgr_normalize_alias_map(stats::setNames(unname(identities), feature_map$aliases))
}

ledgr_alias_feature_identity <- function(x) {
  payload <- ledgr_alias_feature_identity_payload(x)
  digest::digest(canonical_json(payload), algo = "sha256")
}

ledgr_alias_feature_identity_payload <- function(x) {
  if (inherits(x, "ledgr_parameterized_indicator")) {
    return(list(
      kind = "parameterized_indicator",
      constructor = x$constructor,
      args = ledgr_alias_param_identity_args(x$args)
    ))
  }
  if (inherits(x, "ledgr_parameterized_bundle_output")) {
    return(list(
      kind = "parameterized_bundle_output",
      constructor = x$bundle$constructor,
      output_alias = x$output_alias,
      args = ledgr_alias_param_identity_args(x$bundle$args)
    ))
  }
  if (inherits(x, "ledgr_indicator")) {
    return(list(
      kind = "indicator",
      source = x$source,
      fn = ledgr_function_fingerprint(
        x$fn,
        include_captures = FALSE,
        label = sprintf("alias identity indicator `%s`", x$id)
      ),
      series_fn = if (is.null(x$series_fn)) {
        NULL
      } else {
        ledgr_function_fingerprint(
          x$series_fn,
          include_captures = FALSE,
          label = sprintf("alias identity indicator `%s` series_fn", x$id)
        )
      }
    ))
  }
  rlang::abort(
    "`feature_map` entries must be concrete or parameterized ledgr indicators.",
    class = c("ledgr_invalid_feature_map", "ledgr_invalid_args")
  )
}

ledgr_alias_param_identity_args <- function(args) {
  lapply(args, function(value) {
    if (ledgr_is_param_ref(value)) {
      return(list(type = "ledgr_param", name = ledgr_param_name(value)))
    }
    ledgr_stable_payload(value, "alias-map declaration argument")
  })
}

ledgr_normalize_alias_map <- function(alias_map) {
  if (is.null(alias_map)) {
    return(NULL)
  }
  if (!is.character(alias_map) || is.null(names(alias_map)) ||
      anyNA(alias_map) || any(!nzchar(alias_map)) ||
      anyNA(names(alias_map)) || any(!nzchar(names(alias_map)))) {
    rlang::abort(
      "`alias_map` must be a named character vector of concrete feature IDs.",
      class = c("ledgr_invalid_alias_map", "ledgr_invalid_args")
    )
  }
  stats::setNames(unname(alias_map), names(alias_map))
}

ledgr_alias_map_storage <- function(alias_map, identity_map = NULL) {
  alias_map <- ledgr_normalize_alias_map(alias_map)
  if (is.null(alias_map)) {
    return(list(
      alias_map = NULL,
      alias_identity_map = NULL,
      alias_map_json = NA_character_,
      alias_map_hash = NA_character_,
      alias_map_version = NA_integer_,
      alias_map_order = character()
    ))
  }
  if (is.null(identity_map)) {
    identity_map <- alias_map
  }
  identity_map <- ledgr_normalize_alias_map(identity_map)
  if (!setequal(names(alias_map), names(identity_map))) {
    rlang::abort(
      "`identity_map` names must match `alias_map` names.",
      class = c("ledgr_invalid_alias_map", "ledgr_invalid_args")
    )
  }

  canonical_alias_map <- alias_map[order(names(alias_map))]
  mappings <- lapply(names(canonical_alias_map), function(alias) {
    list(alias = alias, feature_id = unname(canonical_alias_map[[alias]]))
  })
  canonical_identity_map <- identity_map[order(names(identity_map))]
  identity_mappings <- lapply(names(canonical_identity_map), function(alias) {
    list(alias = alias, feature_identity = unname(canonical_identity_map[[alias]]))
  })
  json_payload <- list(
    alias_map_version = ledgr_alias_map_version(),
    mappings = mappings,
    identity_mappings = identity_mappings
  )
  hash_payload <- list(
    alias_map_version = ledgr_alias_map_version(),
    mappings = identity_mappings
  )
  json <- canonical_json(json_payload)
  list(
    alias_map = alias_map,
    alias_identity_map = identity_map,
    alias_map_json = json,
    alias_map_hash = digest::digest(canonical_json(hash_payload), algo = "sha256"),
    alias_map_version = ledgr_alias_map_version(),
    alias_map_order = names(alias_map)
  )
}

ledgr_alias_map_from_json <- function(alias_map_json, alias_map_order = NULL) {
  if (is.null(alias_map_json) || length(alias_map_json) != 1L || is.na(alias_map_json) || !nzchar(alias_map_json)) {
    return(NULL)
  }
  payload <- tryCatch(
    ledgr_json_read_nested(alias_map_json),
    error = function(e) {
      rlang::abort("`alias_map_json` is not valid JSON.", class = c("ledgr_invalid_alias_map", "ledgr_invalid_config"))
    }
  )
  mappings <- payload$mappings
  if (is.null(mappings) || length(mappings) < 1L) {
    return(NULL)
  }
  aliases <- vapply(mappings, function(x) x$alias %||% NA_character_, character(1))
  feature_ids <- vapply(mappings, function(x) x$feature_id %||% NA_character_, character(1))
  alias_map <- ledgr_normalize_alias_map(stats::setNames(feature_ids, aliases))
  if (!is.null(alias_map_order)) {
    alias_map_order <- as.character(alias_map_order)
    alias_map_order <- alias_map_order[!is.na(alias_map_order) & nzchar(alias_map_order)]
    if (length(alias_map_order) > 0L && setequal(alias_map_order, names(alias_map))) {
      alias_map <- alias_map[alias_map_order]
    }
  }
  alias_map
}

ledgr_alias_map_from_config <- function(config) {
  ledgr_alias_map_from_json(
    config$alias_map_json,
    alias_map_order = config$alias_map_order
  )
}

ledgr_feature_lookup_map <- function(feature_map = NULL, active_alias_map = NULL) {
  if (missing(feature_map) || is.null(feature_map)) {
    storage <- ledgr_alias_map_storage(active_alias_map)
    if (is.null(storage$alias_map)) {
      rlang::abort(
        "`ctx$features(instrument_id)` requires an active alias map. Use `ctx$features(instrument_id, feature_map)` or `ctx$feature(instrument_id, feature_id)` for exact-ID lookup.",
        class = c("ledgr_no_active_alias_map", "ledgr_invalid_pulse_context")
      )
    }
    return(storage$alias_map)
  }

  if (is.character(feature_map)) {
    return(ledgr_normalize_alias_map(feature_map))
  }

  ledgr_validate_feature_map_object(feature_map)
  feature_ids <- ledgr_feature_id(feature_map)
  if (!is.character(feature_ids) || is.null(names(feature_ids)) ||
      anyNA(feature_ids) || any(!nzchar(feature_ids)) ||
      anyNA(names(feature_ids)) || any(!nzchar(names(feature_ids)))) {
    rlang::abort(
      "`feature_map` must resolve to a named character vector of concrete feature IDs.",
      class = c("ledgr_invalid_feature_map", "ledgr_invalid_args")
    )
  }
  stats::setNames(unname(feature_ids), names(feature_ids))
}
