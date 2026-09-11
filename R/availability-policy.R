#' Point-in-time universe and valuation policies
#'
#' These constructors opt an experiment into point-in-time availability
#' semantics without adding an execution-mode flag. A membership rule selects
#' one declared membership universe. A stale-valuation policy supplies the
#' explicit session horizon required by every availability-aware experiment.
#'
#' @param universe_id Non-empty membership-universe identifier.
#' @param max_sessions Non-negative whole number of venue sessions for which a
#'   prior accepted close remains a permissible valuation mark.
#'
#' @return A classed universe rule or valuation policy.
#' @name ledgr_availability_policy
NULL

#' @rdname ledgr_availability_policy
#' @export
ledgr_universe_members <- function(universe_id) {
  universe_id <- ledgr_fact_scalar_id(universe_id, "universe_id")
  structure(
    list(
      schema_version = 1L,
      type_id = "membership_universe",
      universe_id = universe_id
    ),
    class = c("ledgr_universe_rule", "list")
  )
}

#' @rdname ledgr_availability_policy
#' @export
ledgr_valuation_stale <- function(max_sessions) {
  if (!is.numeric(max_sessions) || length(max_sessions) != 1L ||
      is.na(max_sessions) || !is.finite(max_sessions) ||
      max_sessions < 0 || max_sessions %% 1 != 0) {
    rlang::abort(
      "`max_sessions` must be a non-negative whole number.",
      class = c("ledgr_invalid_valuation_policy", "ledgr_invalid_args")
    )
  }
  structure(
    list(
      schema_version = 1L,
      type_id = "stale_sessions",
      max_sessions = as.integer(max_sessions)
    ),
    class = c("ledgr_valuation_policy", "list")
  )
}

#' @rdname ledgr_availability_policy
#' @param x A universe rule or valuation policy.
#' @param ... Unused.
#' @export
print.ledgr_universe_rule <- function(x, ...) {
  cat("ledgr membership-universe rule\n")
  cat("Universe ID: ", x$universe_id, "\n", sep = "")
  invisible(x)
}

#' @rdname ledgr_availability_policy
#' @export
print.ledgr_valuation_policy <- function(x, ...) {
  cat("ledgr stale-valuation policy\n")
  suffix <- if (x$max_sessions == 1L) "" else "s"
  cat("Maximum age: ", x$max_sessions, " session", suffix, "\n", sep = "")
  invisible(x)
}

ledgr_snapshot_fact_headers <- function(snapshot) {
  opened <- ledgr_snapshot_connection(snapshot)
  if (isTRUE(opened$opened_new)) {
    on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  }
  if (!ledgr_experiment_store_table_exists(opened$con, "snapshot_fact_families")) {
    return(data.frame())
  }
  DBI::dbGetQuery(
    opened$con,
    paste(
      "SELECT family, scope_id, metadata_json",
      "FROM snapshot_fact_families",
      "WHERE snapshot_id = ? ORDER BY family, scope_id"
    ),
    params = list(snapshot$snapshot_id)
  )
}

ledgr_availability_activation <- function(snapshot, valuation_policy = NULL) {
  headers <- ledgr_snapshot_fact_headers(snapshot)
  runtime_families <- c("membership", "sessions", "trading_status", "lifetime")
  declared <- if (nrow(headers) > 0L) {
    runtime_families[runtime_families %in% as.character(headers$family)]
  } else {
    character()
  }
  list(
    active = length(declared) > 0L || !is.null(valuation_policy),
    declared_families = declared,
    headers = headers
  )
}

ledgr_validate_valuation_policy <- function(x) {
  if (!inherits(x, "ledgr_valuation_policy") ||
      !identical(x$type_id, "stale_sessions") ||
      !is.integer(x$max_sessions) || length(x$max_sessions) != 1L ||
      is.na(x$max_sessions) || x$max_sessions < 0L) {
    rlang::abort(
      "`valuation_policy` must be created by `ledgr_valuation_stale()`.",
      class = c("ledgr_invalid_valuation_policy", "ledgr_invalid_experiment")
    )
  }
  invisible(TRUE)
}

ledgr_availability_validate_experiment <- function(snapshot,
                                                    universe,
                                                    valuation_policy) {
  activation <- ledgr_availability_activation(snapshot, valuation_policy)
  if (!isTRUE(activation$active)) {
    if (inherits(universe, "ledgr_universe_rule")) {
      rlang::abort(
        "A membership universe requires declared membership and session facts.",
        class = c("ledgr_availability_inactive", "ledgr_invalid_experiment")
      )
    }
    return(c(activation, list(universe_rule = NULL)))
  }
  if (!"sessions" %in% activation$declared_families) {
    rlang::abort(
      "Availability-aware experiments require a complete declared session calendar.",
      class = c("ledgr_availability_sessions_required", "ledgr_invalid_experiment")
    )
  }
  if (is.null(valuation_policy)) {
    rlang::abort(
      "Availability-aware experiments require `ledgr_valuation_stale(max_sessions)`.",
      class = c("ledgr_valuation_policy_required", "ledgr_invalid_experiment")
    )
  }
  ledgr_validate_valuation_policy(valuation_policy)

  rule <- if (inherits(universe, "ledgr_universe_rule")) universe else NULL
  if (!is.null(rule)) {
    scopes <- as.character(
      activation$headers$scope_id[activation$headers$family == "membership"]
    )
    if (!rule$universe_id %in% scopes) {
      rlang::abort(
        sprintf("Membership universe '%s' is not declared by the snapshot.", rule$universe_id),
        class = c("ledgr_membership_universe_not_found", "ledgr_invalid_experiment")
      )
    }
  }
  c(activation, list(universe_rule = rule))
}

ledgr_availability_validate_features <- function(features, features_mode) {
  if (identical(features_mode, "function")) {
    return(invisible(TRUE))
  }
  indicators <- if (identical(features_mode, "feature_map")) {
    ledgr_feature_map_indicators(features)
  } else {
    ledgr_flatten_feature_list(
      features,
      context = "`features`",
      class = "ledgr_invalid_experiment_features"
    )
  }
  unsupported <- vapply(indicators, function(indicator) {
    !identical(indicator$gap_contract, "strict_window")
  }, logical(1))
  if (any(unsupported)) {
    ids <- vapply(indicators[unsupported], `[[`, character(1), "id")
    rlang::abort(
      sprintf(
        paste0(
          "Availability-aware execution requires ",
          "`gap_contract = \"strict_window\"`; unsupported indicator(s): %s."
        ),
        paste(ids, collapse = ", ")
      ),
      class = c(
        "ledgr_indicator_gap_unsupported",
        "ledgr_invalid_experiment_features",
        "ledgr_invalid_experiment"
      ),
      indicator_ids = ids
    )
  }
  invisible(TRUE)
}

#' Inspect an experiment's effective execution plan
#'
#' Reports whether point-in-time availability is active and which fact-family
#' checks are declared, omitted, assumption-backed, or disabled. Inspection is
#' read-only and does not execute the strategy.
#'
#' @param x A `ledgr_experiment`.
#' @param ... Unused.
#'
#' @return A `ledgr_experiment_plan` object.
#' @export
ledgr_experiment_plan <- function(x, ...) {
  if (!inherits(x, "ledgr_experiment")) {
    rlang::abort("`x` must be a ledgr_experiment.", class = "ledgr_invalid_experiment")
  }
  active <- isTRUE(x$availability$active)
  declared <- as.character(x$availability$declared_families %||% character())
  headers <- x$availability$headers %||% data.frame()
  assumption_backed <- character()
  if (nrow(headers) > 0L) {
    assumed <- vapply(headers$metadata_json, function(json) {
      identical(ledgr_json_read_nested(json)$knowledge, "assume_effective")
    }, logical(1))
    assumption_backed <- unique(as.character(headers$family[assumed]))
  }
  checks <- data.frame(
    family = c("membership", "sessions", "trading_status", "lifetime"),
    status = vapply(
      c("membership", "sessions", "trading_status", "lifetime"),
      function(family) {
        if (!active) return("disabled")
        if (!family %in% declared) return("omitted")
        if (family %in% assumption_backed) return("assumption_backed")
        "declared"
      },
      character(1)
    ),
    stringsAsFactors = FALSE
  )
  structure(
    list(
      schema_version = 1L,
      availability_active = active,
      universe_type = if (is.null(x$universe_rule)) "fixed" else "membership",
      universe_id = x$universe_rule$universe_id %||% NA_character_,
      valuation_policy = x$valuation_policy,
      checks = tibble::as_tibble(checks)
    ),
    class = c("ledgr_experiment_plan", "list")
  )
}

#' @rdname ledgr_experiment_plan
#' @export
print.ledgr_experiment_plan <- function(x, ...) {
  cat("ledgr experiment plan\n")
  cat("Availability: ", if (isTRUE(x$availability_active)) "active" else "dense", "\n", sep = "")
  if (isTRUE(x$availability_active)) {
    cat("Universe:     ", x$universe_type, "\n", sep = "")
    cat("Checks:\n")
    print(x$checks, row.names = FALSE)
  }
  invisible(x)
}
