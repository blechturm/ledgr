ledgr_universe_rule_schema_version <- 1L

#' Point-in-time universe and valuation policies
#'
#' These constructors opt an experiment into point-in-time availability
#' semantics without adding an execution-mode flag. A membership rule selects
#' one declared membership universe. A stale-valuation policy supplies the
#' session horizon of every availability-aware experiment; an experiment that
#' supplies none uses `ledgr_valuation_stale()` with its defaults.
#'
#' `max_sessions` separates ordinarily stale valuation from what happens after
#' it. Up to that age a carried close is a permissible mark. Beyond it,
#' `exhausted` decides: `"freeze"` keeps the holding at its last reference as
#' an explicitly assumption-backed frozen valuation, with quantity and cash
#' unchanged, while `"refuse"` stops the run `INCOMPLETE`. Neither choice
#' establishes an economic terminal: an aged mark proves no delisting, sale or
#' loss, so it never creates a fill, a disposition or a cash change. Terminal
#' outcomes come only from sealed lifetime facts and the corporate-action
#' policy. The default horizon is 5 sessions, chosen from real-data gap
#' evidence (US equity vendor data for S&P 500 members, 1998 to 2026: a
#' handful of held missing-bar runs exceed it and, under `"freeze"`, none
#' stops a run). Plans and results mark a horizon of 5 as the default.
#'
#' The valuation policy and its stored identity use `schema_version` 2.
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
      schema_version = ledgr_universe_rule_schema_version,
      type_id = "membership_universe",
      universe_id = universe_id
    ),
    class = c("ledgr_universe_rule", "list")
  )
}

#' @rdname ledgr_availability_policy
#' @export
ledgr_valuation_stale <- function(max_sessions = 5, exhausted = "freeze") {
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

# The constructor default of `max_sessions` (LDG-3014).
ledgr_valuation_default_max_sessions <- 5L

ledgr_valuation_exhausted_choices <- function() {
  c("freeze", "refuse")
}

# Returns the schema version of an exact current valuation-policy record.
ledgr_valuation_policy_record_version <- function(x) {
  if (!is.list(x) || !identical(x$type_id, "stale_sessions") ||
      !is.integer(x$max_sessions) || length(x$max_sessions) != 1L ||
      is.na(x$max_sessions) || x$max_sessions < 0L) {
    return(NA_integer_)
  }
  fields <- sort(names(x))
  required <- sort(c("schema_version", "type_id", "max_sessions", "exhausted"))
  if (identical(x$schema_version, ledgr_valuation_policy_schema_version) &&
      identical(fields, required) &&
      is.character(x$exhausted) && length(x$exhausted) == 1L &&
      !is.na(x$exhausted) &&
      x$exhausted %in% ledgr_valuation_exhausted_choices()) {
    return(ledgr_valuation_policy_schema_version)
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
  ledgr_fact_headers_read(opened$con, snapshot$snapshot_id)
}

ledgr_fact_headers_read <- function(con, snapshot_id) {
  DBI::dbGetQuery(
    con,
    paste(
      "SELECT family, scope_id, metadata_json",
      "FROM snapshot_fact_families",
      "WHERE snapshot_id = ? ORDER BY family, scope_id"
    ),
    params = list(snapshot_id)
  )
}

# Assumption reasons per fact family from sealed fact headers: an assumed
# knowledge clock (corporate actions too, Cut 17 LDG-3085) or a generated
# session schedule. Shared by ledgr_experiment_plan() and result summaries.
ledgr_fact_assumption_reasons <- function(headers) {
  families <- c("membership", "sessions", "trading_status", "lifetime", "equity_corporate_actions")
  out <- stats::setNames(rep(list(character()), length(families)), families)
  if (is.null(headers) || nrow(headers) == 0L) return(out)
  for (i in seq_len(nrow(headers))) {
    family <- as.character(headers$family[[i]])
    if (!family %in% families) next
    metadata <- ledgr_json_read_nested(headers$metadata_json[[i]])
    reasons <- c(
      if (identical(metadata$knowledge, "assume_effective")) "knowledge_assume_effective",
      if (identical(metadata$schedule_basis, "generated")) "generated_schedule"
    )
    out[[family]] <- unique(c(out[[family]], reasons))
  }
  out
}

# The price basis an experiment or run executes on. ledgr accounts in
# split-adjusted share units, so an availability-aware experiment on a snapshot
# that declares no basis runs on that model as an assumed default (LDG-3013);
# identity keeps the undeclared basis. A dense run keeps "undeclared".
ledgr_price_basis_label <- function(price_basis, availability_active) {
  if (!is.null(price_basis)) return(list(value = price_basis, default = FALSE))
  if (isTRUE(availability_active)) return(list(value = "split_adjusted", default = TRUE))
  list(value = "undeclared", default = FALSE)
}

ledgr_price_basis_display <- function(value, default) {
  if (identical(value, "undeclared")) return(value)
  paste0(value, if (isTRUE(default)) " (assumed default; the snapshot declares none)" else " (declared)")
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
  # Facts activated availability, so an omitted policy is the constructor
  # default; it is the same record, and identity, as declaring it (LDG-3014).
  if (is.null(valuation_policy)) valuation_policy <- ledgr_valuation_stale()
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
  c(activation, list(universe_rule = rule, valuation_policy = valuation_policy))
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
  # Every concrete definition is bounded or history-dependent (v12 Section 6);
  # an undeclared one is calculated as history-dependent. Declarations are
  # still validated here so a malformed object refuses before execution.
  for (indicator in indicators) {
    if (inherits(indicator, "ledgr_unresolved_feature_declaration")) next
    ledgr_feature_certify(indicator)
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
#' @return A `ledgr_experiment_plan` object. `price_basis` is the basis the
#'   experiment executes on: the snapshot's declared basis, `"split_adjusted"`
#'   as an assumed default for an availability-aware experiment whose snapshot
#'   declares none (`price_basis_default` is then `TRUE`), or `"undeclared"`
#'   for a dense snapshot without one. Its `checks` tibble reports each
#'   family status and keeps generated-schedule and assumed-knowledge reasons
#'   separate in `assumption_reasons`. Its `assumptions` tibble lists the
#'   declared valuation-horizon and terminal-outcome choices, one row per
#'   `setting`, with `value` and a `default` flag that is `TRUE` when the
#'   value is the constructor default rather than a choice the caller changed.
#'   The held terminal map has one `held_terminal_position.<label>` row per
#'   entry, in map order. `history_policy` is the experiment's
#'   [ledgr_history_policy()]; an availability-aware plan, which alone uses
#'   it, adds `history.price_carry`, `history.output_carry` and
#'   `history.segment_limit` rows. Its print names
#'   `valuation.max_sessions` as the valuation stale-mark horizon and shows
#'   the history policy beside it, each value marked `default` or `declared`.
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
  assumption_reasons <- ledgr_fact_assumption_reasons(x$availability$headers)
  assumption_backed <- names(assumption_reasons)[lengths(assumption_reasons) > 0L]
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
      price_basis = ledgr_price_basis_label(x$data_identity$price_basis, active)$value,
      price_basis_default = ledgr_price_basis_label(x$data_identity$price_basis, active)$default,
      valuation_policy = x$valuation_policy,
      history_policy = x$history_policy,
      metric_calendar = ledgr_calendar_display(x$metric_context$calendar),
      checks = tibble::as_tibble(checks),
      assumptions = ledgr_experiment_plan_assumptions(
        x$valuation_policy,
        x$corporate_action_policy,
        x$history_policy
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
  cat("Price basis:  ", ledgr_price_basis_display(x$price_basis %||% "undeclared", x$price_basis_default), "\n", sep = "")
  cat("Metrics:      ", x$metric_calendar, "\n", sep = "")
  if (isTRUE(x$availability_active)) {
    cat("Universe:     ", x$universe_type, "\n", sep = "")
    cat(ledgr_experiment_plan_policy_lines(x, width = 14L), sep = "")
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

# Declared valuation-horizon, terminal-outcome and history-policy choices
# with a default marker against the constructor defaults. Disclosure only.
ledgr_experiment_plan_assumptions <- function(valuation_policy,
                                              corporate_action_policy,
                                              history_policy = NULL) {
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
    default <- c(
      default,
      identical(as.integer(valuation_policy$max_sessions), ledgr_valuation_default_max_sessions),
      identical(valuation_policy$exhausted %||% "freeze", "freeze")
    )
    # Only availability-aware experiments carry a valuation policy, and only
    # they use the history policy, so its rows join this block (LDG-3081).
    if (!is.null(history_policy)) {
      history <- ledgr_history_policy_disclosure(history_policy)
      setting <- c(setting, history$setting)
      value <- c(value, history$value)
      default <- c(default, history$default)
    }
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

# The plan's valuation stale-mark horizon and history policy as display
# lines, derived from its assumption rows (LDG-3081); none for a plan whose
# rows hold neither, such as a dense experiment's.
ledgr_experiment_plan_policy_lines <- function(plan, width) {
  rows <- plan$assumptions
  label <- function(text) formatC(text, width = -width)
  horizon <- rows[rows$setting == "valuation.max_sessions", , drop = FALSE]
  history <- rows[startsWith(rows$setting, "history."), , drop = FALSE]
  c(
    if (nrow(horizon) == 1L) {
      paste0(
        label("Valuation:"),
        ledgr_valuation_horizon_display(as.integer(horizon$value), horizon$default),
        "\n"
      )
    },
    if (nrow(history) > 0L) {
      history$label <- gsub("_", " ", sub("^history[.]", "", history$setting))
      paste0(label("History:"), ledgr_history_policy_rows_display(history), "\n")
    }
  )
}
