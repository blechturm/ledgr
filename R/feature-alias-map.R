ledgr_alias_map_version <- function() {
  1L
}

ledgr_alias_map_from_feature_map <- function(feature_map) {
  ledgr_validate_feature_map_object(feature_map)
  feature_ids <- ledgr_feature_id(feature_map)
  ledgr_normalize_alias_map(feature_ids)
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

ledgr_alias_map_storage <- function(alias_map) {
  alias_map <- ledgr_normalize_alias_map(alias_map)
  if (is.null(alias_map)) {
    return(list(
      alias_map = NULL,
      alias_map_json = NA_character_,
      alias_map_hash = NA_character_,
      alias_map_version = NA_integer_,
      alias_map_order = character()
    ))
  }

  canonical_alias_map <- alias_map[order(names(alias_map))]
  mappings <- lapply(names(canonical_alias_map), function(alias) {
    list(alias = alias, feature_id = unname(canonical_alias_map[[alias]]))
  })
  payload <- list(
    alias_map_version = ledgr_alias_map_version(),
    mappings = mappings
  )
  json <- canonical_json(payload)
  list(
    alias_map = alias_map,
    alias_map_json = json,
    alias_map_hash = digest::digest(json, algo = "sha256"),
    alias_map_version = ledgr_alias_map_version(),
    alias_map_order = names(alias_map)
  )
}

ledgr_alias_map_from_json <- function(alias_map_json, alias_map_order = NULL) {
  if (is.null(alias_map_json) || length(alias_map_json) != 1L || is.na(alias_map_json) || !nzchar(alias_map_json)) {
    return(NULL)
  }
  payload <- tryCatch(
    jsonlite::fromJSON(alias_map_json, simplifyVector = FALSE, simplifyDataFrame = FALSE, simplifyMatrix = FALSE),
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
