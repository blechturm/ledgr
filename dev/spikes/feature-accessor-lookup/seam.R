# In-memory seam for the feature-accessor lookup spike. Sourced by probe.R and
# spike_runner.R.
#
# The prepared arm replaces two loaded factories and nothing on disk. Both build
# the strategy-facing accessors once per run for the fast pulse context:
#   ledgr_projection_feature_accessor_state         ctx$feature(): hashed instrument
#       and feature-id lookups instead of `%in%` and named-vector subsetting;
#   ledgr_projection_feature_bundle_accessor_state  ctx$features(): hashed universe
#       check and the active alias map normalized once instead of on every call.
# Validation, error classes and messages are unchanged and still raised at call
# time. An explicit `feature_map` argument takes the production lookup path.
# gut = "shifted" maps every instrument to its neighbour's row.

fl_prepared_functions <- function(ns, gut = c("none", "shifted")) {
  gut <- match.arg(gut)
  seam_env <- new.env(parent = ns)
  seam_env$shift <- identical(gut, "shifted")

  scalar <- function(projection, state, feature_ids = NULL) {
    force(projection)
    force(state)
    available_features <- ledgr_projection_feature_ids(projection, feature_ids)
    available_message <- ledgr_feature_names_message(sort(available_features))
    instrument_index <- projection$instrument_index
    feature_values <- projection$feature_values
    rows <- as.list(unname(instrument_index))
    if (shift && length(rows) > 1L) rows <- rows[c(2:length(rows), 1L)]
    instrument_rows <- list2env(stats::setNames(rows, names(instrument_index)), hash = TRUE, parent = emptyenv())
    known_features <- list2env(stats::setNames(as.list(rep(TRUE, length(available_features))), available_features),
      hash = TRUE, parent = emptyenv())
    function(instrument_id, feature_name, default = NA_real_) {
      if (!is.character(instrument_id) || length(instrument_id) != 1L || is.na(instrument_id) || !nzchar(instrument_id)) {
        rlang::abort("`instrument_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
      }
      if (!is.character(feature_name) || length(feature_name) != 1L || is.na(feature_name) || !nzchar(feature_name)) {
        rlang::abort("`feature_name` must be a non-empty character scalar.", class = "ledgr_invalid_args")
      }
      if (length(available_features) == 0L || is.null(known_features[[feature_name]])) {
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
      inst_idx <- instrument_rows[[instrument_id]]
      if (is.null(inst_idx) || is.na(inst_idx)) {
        return(default)
      }
      mat <- feature_values[[feature_name]]
      if (is.null(mat)) {
        return(default)
      }
      mat[[as.integer(inst_idx), as.integer(state$pulse_idx)]]
    }
  }
  environment(scalar) <- seam_env

  bundle <- function(projection, state, universe, feature_ids = NULL, active_alias_map = NULL) {
    force(projection)
    force(state)
    feature <- ledgr_projection_feature_accessor_state(projection, state, feature_ids)
    universe <- as.character(universe)
    members <- list2env(stats::setNames(as.list(rep(TRUE, length(universe))), universe), hash = TRUE, parent = emptyenv())
    # Normalized once; if normalization would fail, every call takes the production
    # path and raises the production condition.
    active_lookup <- tryCatch(ledgr_feature_lookup_map(NULL, active_alias_map = active_alias_map), error = function(e) NULL)

    function(instrument_id, feature_map = NULL) {
      if (!is.character(instrument_id) || length(instrument_id) != 1L || is.na(instrument_id) || !nzchar(instrument_id)) {
        rlang::abort("`instrument_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
      }
      if (is.null(members[[instrument_id]])) {
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
        ledgr_feature_lookup_map(feature_map, active_alias_map = active_alias_map)
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
  environment(bundle) <- seam_env

  list(ledgr_projection_feature_accessor_state = scalar,
    ledgr_projection_feature_bundle_accessor_state = bundle)
}

# Bind a set of replacement functions in the loaded namespace for one call.
fl_with <- function(ns, functions, code) {
  if (is.null(functions)) return(force(code))
  old <- lapply(names(functions), get, envir = ns)
  names(old) <- names(functions)
  for (name in names(functions)) { unlockBinding(name, ns); assign(name, functions[[name]], envir = ns) }
  on.exit(for (name in names(old)) { assign(name, old[[name]], envir = ns); lockBinding(name, ns) }, add = TRUE)
  force(code)
}
