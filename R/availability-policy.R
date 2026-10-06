#' Point-in-time universe and valuation policies
#'
#' These constructors opt an experiment into point-in-time availability
#' semantics without adding an execution-mode flag. A membership rule selects
#' one declared membership universe. A stale-valuation policy supplies the
#' explicit session horizon required by every availability-aware experiment.
#'
#' `max_sessions` separates ordinarily stale valuation from what happens after
#' it. Up to that age a carried close is a permissible mark. Beyond it,
#' `exhausted` decides: `"freeze"` keeps the holding at its last reference as
#' an explicitly assumption-backed frozen valuation, with quantity and cash
#' unchanged, while `"refuse"` stops the run `INCOMPLETE`. Neither choice
#' establishes an economic terminal: an aged mark proves no delisting, sale or
#' loss, so it never creates a fill, a disposition or a cash change. Terminal
#' outcomes come only from sealed lifetime facts and the corporate-action
#' policy. There is no default horizon.
#'
#' The valuation policy and its stored identity use `schema_version` 2. Runs
#' recorded under schema 1 remain readable, but cannot be resumed, rerun or
#' promoted into under schema 2.
#'
#' @param universe_id Non-empty membership-universe identifier.
#' @param max_sessions Non-negative whole number of venue sessions for which a
#'   prior accepted close remains a permissible valuation mark.
#' @param exhausted What happens to a holding whose mark is older than
#'   `max_sessions`: `"freeze"` (the default) or `"refuse"`.
#'
#' @return A classed universe rule or valuation policy.
#' @section Articles:
#' Point-in-time universe workflow:
#' `vignette("survivorship-bias", package = "ledgr")`
#' `system.file("doc", "survivorship-bias.html", package = "ledgr")`
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
ledgr_valuation_stale <- function(max_sessions, exhausted = "freeze") {
  if (!is.numeric(max_sessions) || length(max_sessions) != 1L ||
      is.na(max_sessions) || !is.finite(max_sessions) ||
      max_sessions < 0 || max_sessions %% 1 != 0) {
    rlang::abort(
      "`max_sessions` must be a non-negative whole number.",
      class = c("ledgr_invalid_valuation_policy", "ledgr_invalid_args")
    )
  }
  choices <- ledgr_valuation_exhausted_choices()
  if (!is.character(exhausted) || length(exhausted) != 1L ||
      is.na(exhausted) || !is.null(names(exhausted)) ||
      !exhausted %in% choices) {
    rlang::abort(
      sprintf(
        "`exhausted` must be exactly one of: %s.",
        paste(sprintf('"%s"', choices), collapse = ", ")
      ),
      class = c("ledgr_invalid_valuation_policy", "ledgr_invalid_args")
    )
  }
  structure(
    list(
      schema_version = ledgr_valuation_policy_schema_version,
      type_id = "stale_sessions",
      max_sessions = as.integer(max_sessions),
      exhausted = exhausted
    ),
    class = c("ledgr_valuation_policy", "list")
  )
}

ledgr_valuation_policy_schema_version <- 2L

ledgr_valuation_exhausted_choices <- function() {
  c("freeze", "refuse")
}

# Returns the schema version of a valuation-policy record, or NA when the
# record matches neither the exact historical schema-1 shape nor schema 2.
ledgr_valuation_policy_record_version <- function(x) {
  if (!is.list(x) || !identical(x$type_id, "stale_sessions") ||
      !is.integer(x$max_sessions) || length(x$max_sessions) != 1L ||
      is.na(x$max_sessions) || x$max_sessions < 0L) {
    return(NA_integer_)
  }
  fields <- sort(names(x))
  v1_fields <- sort(c("schema_version", "type_id", "max_sessions"))
  if (identical(x$schema_version, 1L) && identical(fields, v1_fields)) {
    return(1L)
  }
  if (identical(x$schema_version, 2L) &&
      identical(fields, sort(c(v1_fields, "exhausted"))) &&
      is.character(x$exhausted) && length(x$exhausted) == 1L &&
      !is.na(x$exhausted) &&
      x$exhausted %in% ledgr_valuation_exhausted_choices()) {
    return(2L)
  }
  NA_integer_
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
  cat("Exhausted marks: ", x$exhausted %||% "not recorded", "\n", sep = "")
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
  # Corporate-action facts are sealed evidence, not an availability provider.
  # Activating on that family alone would incorrectly require a full session
  # calendar and a staleness policy before settlement policy is even chosen.
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
  version <- ledgr_valuation_policy_record_version(x)
  if (inherits(x, "ledgr_valuation_policy") && identical(version, 1L)) {
    rlang::abort(
      paste0(
        "Valuation policy schema 1 is retired. Construct the policy again ",
        "with `ledgr_valuation_stale()` (schema 2)."
      ),
      class = c("ledgr_invalid_valuation_policy", "ledgr_invalid_experiment")
    )
  }
  if (!inherits(x, "ledgr_valuation_policy") ||
      !identical(version, ledgr_valuation_policy_schema_version)) {
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
    if (inherits(indicator, "ledgr_unresolved_feature_declaration")) {
      return(FALSE)
    }
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
#' @return A `ledgr_experiment_plan` object. Its `checks` tibble reports each
#'   family status and keeps generated-schedule and assumed-knowledge reasons
#'   separate in `assumption_reasons`. Its `assumptions` tibble lists the
#'   declared valuation-horizon and terminal-outcome choices, one row per
#'   `setting`, with `value` and a `default` flag that is `TRUE` when the
#'   value is the constructor default rather than a choice the caller changed.
#'   The held terminal map has one `held_terminal_position.<label>` row per
#'   entry, in map order.
#' @section Articles:
#' Point-in-time universe workflow:
#' `vignette("survivorship-bias", package = "ledgr")`
#' `system.file("doc", "survivorship-bias.html", package = "ledgr")`
#' @export
ledgr_experiment_plan <- function(x, ...) {
  if (!inherits(x, "ledgr_experiment")) {
    rlang::abort("`x` must be a ledgr_experiment.", class = "ledgr_invalid_experiment")
  }
  active <- isTRUE(x$availability$active)
  declared <- as.character(x$availability$declared_families %||% character())
  headers <- x$availability$headers %||% data.frame()
  assumption_backed <- character()
  assumption_reasons <- stats::setNames(vector("list", 4L), c(
    "membership", "sessions", "trading_status", "lifetime"
  ))
  if (nrow(headers) > 0L) {
    parsed_metadata <- lapply(headers$metadata_json, ledgr_json_read_nested)
    assumed <- vapply(parsed_metadata, function(metadata) {
      identical(metadata$knowledge, "assume_effective") ||
        identical(metadata$schedule_basis, "generated")
    }, logical(1))
    assumption_backed <- unique(as.character(headers$family[assumed]))
    for (i in seq_len(nrow(headers))) {
      metadata <- parsed_metadata[[i]]
      reasons <- c(
        if (identical(metadata$knowledge, "assume_effective")) "knowledge_assume_effective",
        if (identical(metadata$schedule_basis, "generated")) "generated_schedule"
      )
      family <- as.character(headers$family[[i]])
      assumption_reasons[[family]] <- unique(c(assumption_reasons[[family]], reasons))
    }
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
    assumption_reasons = vapply(
      c("membership", "sessions", "trading_status", "lifetime"),
      function(family) paste(assumption_reasons[[family]], collapse = "|"),
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
      checks = tibble::as_tibble(checks),
      assumptions = ledgr_experiment_plan_assumptions(
        x$valuation_policy,
        x$corporate_action_policy
      )
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
  assumptions <- x$assumptions
  if (!is.null(assumptions) && nrow(assumptions) > 0L) {
    cat("Declared assumptions:\n")
    shown <- paste0(
      "  ", format(assumptions$setting), "  ", assumptions$value,
      ifelse(assumptions$default, " (default)", "")
    )
    cat(shown, sep = "\n")
  }
  invisible(x)
}

# Declared valuation-horizon and terminal-outcome choices with a default
# marker against the constructor defaults. Disclosure only.
ledgr_experiment_plan_assumptions <- function(valuation_policy, corporate_action_policy) {
  setting <- character()
  value <- character()
  default <- logical()
  if (!is.null(valuation_policy)) {
    setting <- c(setting, "valuation.max_sessions", "valuation.exhausted")
    value <- c(
      value,
      as.character(valuation_policy$max_sessions),
      as.character(valuation_policy$exhausted %||% "freeze")
    )
    default <- c(default, FALSE, identical(valuation_policy$exhausted %||% "freeze", "freeze"))
  }
  if (!is.null(corporate_action_policy)) {
    research <- ledgr_corporate_actions_research()
    map <- corporate_action_policy$held_terminal_position
    setting <- c(setting, paste0("held_terminal_position.", names(map)))
    value <- c(value, unname(map))
    # Added labels are always declared; the default entry keeps its marker
    # when it still holds the research default choice.
    default <- c(
      default,
      names(map) == "default" & unname(map) == unname(research$held_terminal_position[["default"]])
    )
    frozen <- corporate_action_policy$frozen_terminal_position
    setting <- c(setting, "frozen_terminal_position")
    value <- c(value, frozen)
    default <- c(default, identical(frozen, research$frozen_terminal_position))
    if (!is.null(corporate_action_policy$haircut)) {
      setting <- c(setting, "haircut")
      value <- c(value, format(corporate_action_policy$haircut))
      default <- c(default, FALSE)
    }
  }
  tibble::tibble(setting = setting, value = value, default = default)
}
