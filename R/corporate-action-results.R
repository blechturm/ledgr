ledgr_corporate_action_fidelity_values <- function() {
  c("not_supplied", "none", "modeled", "unsupported")
}

ledgr_corporate_action_fidelity <- function(value) {
  allowed <- ledgr_corporate_action_fidelity_values()
  if (!is.character(value) || length(value) != 1L || is.na(value) ||
      !value %in% allowed) {
    rlang::abort(
      sprintf(
        "Corporate-action fidelity must be exactly one of: %s.",
        paste(allowed, collapse = ", ")
      ),
      class = c("ledgr_invalid_corporate_action_fidelity", "ledgr_invalid_state")
    )
  }
  value
}

ledgr_corporate_action_policy_settings <- function(identity) {
  if (is.null(identity)) {
    return(stats::setNames(rep(NA_character_, 4L), names(
      ledgr_corporate_action_policy_choices()
    )))
  }
  ledgr_validate_corporate_action_policy_identity(identity)
  ids <- ledgr_corporate_action_policy_ids()
  out <- vapply(names(ids), function(field) {
    match_idx <- match(identity[[field]], ids[[field]])
    names(ids[[field]])[[match_idx]]
  }, character(1))
  out
}

ledgr_corporate_action_choice_keys <- function() {
  choices <- ledgr_corporate_action_policy_choices()
  unlist(lapply(names(choices), function(field) {
    paste(field, choices[[field]], sep = ".")
  }), use.names = FALSE)
}

ledgr_corporate_action_fact_state <- function(con, snapshot_id) {
  supplied <- FALSE
  refusal_reasons <- character()
  if (ledgr_experiment_store_table_exists(con, "snapshot_fact_families")) {
    supplied <- DBI::dbGetQuery(
      con,
      paste(
        "SELECT COUNT(*) AS n FROM snapshot_fact_families",
        "WHERE snapshot_id = ? AND family = 'equity_corporate_actions'"
      ),
      params = list(snapshot_id)
    )$n[[1L]] > 0L
  }
  if (isTRUE(supplied) && ledgr_experiment_store_table_exists(
      con,
      "snapshot_equity_corporate_actions"
    )) {
    refusal_reasons <- DBI::dbGetQuery(
      con,
      paste(
        "SELECT DISTINCT refusal_reason",
        "FROM snapshot_equity_corporate_actions",
        "WHERE snapshot_id = ? AND refusal_reason IS NOT NULL",
        "ORDER BY refusal_reason"
      ),
      params = list(snapshot_id)
    )$refusal_reason
    refusal_reasons <- as.character(refusal_reasons)
    refusal_reasons <- refusal_reasons[!is.na(refusal_reasons) &
      nzchar(refusal_reasons)]
  }
  list(supplied = isTRUE(supplied), refusal_reasons = refusal_reasons)
}

ledgr_corporate_action_summary <- function(bt, con = NULL) {
  if (!inherits(bt, "ledgr_backtest")) {
    rlang::abort("`bt` must be a ledgr_backtest object.", class = "ledgr_invalid_backtest")
  }
  opened <- NULL
  if (is.null(con)) {
    opened <- ledgr_backtest_read_connection(bt)
    con <- opened$con
    on.exit(opened$close(), add = TRUE)
  }
  config <- bt$config
  snapshot_id <- config$data$snapshot_id
  facts <- ledgr_corporate_action_fact_state(con, snapshot_id)
  identity <- config$corporate_actions %||% NULL
  settings <- ledgr_corporate_action_policy_settings(identity)
  identities <- if (is.null(identity)) {
    stats::setNames(rep(NA_character_, 4L), names(settings))
  } else {
    unlist(identity[names(settings)], use.names = TRUE)
  }
  choice_counts <- stats::setNames(
    integer(length(ledgr_corporate_action_choice_keys())),
    ledgr_corporate_action_choice_keys()
  )
  refusal_counts <- stats::setNames(
    integer(length(facts$refusal_reasons)),
    facts$refusal_reasons
  )

  out <- list(
    corporate_action_fidelity = ledgr_corporate_action_fidelity(
      if (facts$supplied) "none" else "not_supplied"
    ),
    facts_supplied = facts$supplied,
    price_basis = config$data$price_basis %||% "undeclared",
    selected_settings = settings,
    selected_identities = identities,
    choice_counts = choice_counts,
    refusal_counts = refusal_counts,
    late_arrival_count = 0L,
    affected_marked_exposure = 0,
    gross_cash_posted = 0,
    modeled_terminal_proceeds = 0,
    positions_disposed = 0L,
    realized_model_pnl = 0,
    unsupported_facts = 0L
  )
  class(out) <- c("ledgr_corporate_action_summary", "list")
  out
}

ledgr_corporate_action_headline <- function(summary) {
  switch(
    summary$corporate_action_fidelity,
    not_supplied = "Corporate actions: NOT SUPPLIED - returns may omit distributions",
    none = "Corporate actions: NONE - supplied facts did not affect held instruments",
    modeled = "Corporate actions: MODELED - configured settlement conventions were exercised",
    unsupported = "Corporate actions: UNSUPPORTED - supplied effects were not represented"
  )
}

ledgr_print_corporate_action_headline <- function(summary) {
  cat(ledgr_corporate_action_headline(summary), "\n", sep = "")
  if (identical(summary$price_basis, "undeclared")) {
    cat("Price basis: UNDECLARED - distribution double counting cannot be ruled out\n")
  } else {
    cat("Price basis: ", summary$price_basis, "\n", sep = "")
  }
  invisible(summary)
}

ledgr_corporate_action_value <- function(value) {
  if (length(value) != 1L || is.na(value)) return("not recorded")
  format(value, scientific = FALSE, trim = TRUE)
}

ledgr_print_corporate_action_summary <- function(summary) {
  cat("\nCorporate-Action Evidence:\n")
  ledgr_print_corporate_action_headline(summary)
  for (field in names(summary$selected_settings)) {
    cat(sprintf(
      "  Setting %-25s %s\n",
      paste0(field, ":"),
      ledgr_corporate_action_value(summary$selected_settings[[field]])
    ))
    cat(sprintf(
      "  Identity %-24s %s\n",
      paste0(field, ":"),
      ledgr_corporate_action_value(summary$selected_identities[[field]])
    ))
  }
  cat("  Exercised choices:\n")
  for (key in names(summary$choice_counts)) {
    cat(sprintf("    %s: %d\n", key, summary$choice_counts[[key]]))
  }
  cat("  Refusal reasons:\n")
  if (length(summary$refusal_counts) == 0L) {
    cat("    none declared: 0\n")
  } else {
    for (key in names(summary$refusal_counts)) {
      cat(sprintf("    %s: %d\n", key, summary$refusal_counts[[key]]))
    }
  }
  fields <- c(
    "Late arrivals" = "late_arrival_count",
    "Affected marked exposure" = "affected_marked_exposure",
    "Gross cash posted" = "gross_cash_posted",
    "Modeled terminal proceeds" = "modeled_terminal_proceeds",
    "Positions disposed" = "positions_disposed",
    "Realized model P&L" = "realized_model_pnl",
    "Unsupported facts" = "unsupported_facts"
  )
  for (label in names(fields)) {
    cat(sprintf(
      "  %-28s %s\n",
      paste0(label, ":"),
      ledgr_corporate_action_value(summary[[fields[[label]]]])
    ))
  }
  invisible(summary)
}
