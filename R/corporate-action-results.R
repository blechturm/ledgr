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
  rows <- data.frame()
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
    rows <- ledgr_corporate_action_rows(con, snapshot_id)
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
  list(
    supplied = isTRUE(supplied),
    refusal_reasons = refusal_reasons,
    rows = rows
  )
}

ledgr_corporate_action_composition_report <- function(con,
                                                       snapshot_id,
                                                       run_id,
                                                       rows) {
  columns <- list(
    source_fact_id = character(),
    subtype = character(),
    parent_instrument_id = character(),
    recipient_instrument_id = character(),
    entitled_parent_quantity = numeric(),
    modeled_cash_credited = numeric(),
    estimated_contractual_consideration = numeric(),
    difference = numeric(),
    successor_exposure_not_represented = numeric(),
    recipient_mark = numeric(),
    valuation_ts_utc = as.POSIXct(character(), tz = "UTC"),
    estimate_label = character(),
    affected_marked_exposure = numeric()
  )
  empty <- as.data.frame(columns, stringsAsFactors = FALSE)
  if (is.null(rows) || nrow(rows) == 0L) return(empty)
  subtypes <- c(
    "cash_acquisition", "stock_acquisition", "mixed_acquisition", "spin_off"
  )
  selected <- which(rows$complete & rows$subtype %in% subtypes)
  if (length(selected) == 0L) return(empty)

  events <- ledgr_corporate_action_existing_events(con, run_id)
  instrument_ids <- DBI::dbGetQuery(
    con,
    paste(
      "SELECT instrument_id FROM snapshot_instruments",
      "WHERE snapshot_id = ? ORDER BY instrument_id"
    ),
    params = list(snapshot_id)
  )$instrument_id
  quantity <- ledgr_corporate_action_past_quantities(
    events,
    rows,
    selected,
    as.character(instrument_ids)
  )
  relevant <- quantity != 0
  if (!any(relevant)) return(empty)
  selected <- selected[relevant]
  quantity <- quantity[relevant]
  source_rows <- rows[selected, , drop = FALSE]

  meta <- ledgr_corporate_action_event_meta(events)
  source_fact_id <- vapply(
    meta,
    function(value) as.character(value$source_fact_id %||% ""),
    character(1)
  )
  modeled_cash <- vapply(source_rows$fact_id, function(fact_id) {
    matched <- which(source_fact_id == fact_id)
    if (length(matched) == 0L) return(0)
    sum(vapply(
      meta[matched],
      function(value) as.numeric(value$cash_delta %||% 0),
      numeric(1)
    ))
  }, numeric(1))

  bar_rows <- DBI::dbGetQuery(
    con,
    paste(
      "SELECT instrument_id, ts_utc, close FROM snapshot_bars",
      "WHERE snapshot_id = ? ORDER BY instrument_id, ts_utc"
    ),
    params = list(snapshot_id)
  )
  time_tokens <- function(value) {
    value <- as.POSIXct(value, tz = "UTC")
    vapply(
      seq_along(value),
      function(i) ledgr_normalize_ts_utc(value[[i]]),
      character(1)
    )
  }
  bar_key <- paste(
    as.character(bar_rows$instrument_id),
    time_tokens(bar_rows$ts_utc),
    sep = "\r"
  )
  effective <- as.POSIXct(source_rows$effective_time, tz = "UTC")
  effective_token <- time_tokens(effective)
  recipient_key <- paste(
    as.character(source_rows$recipient_instrument_id),
    effective_token,
    sep = "\r"
  )
  parent_key <- paste(
    as.character(source_rows$parent_instrument_id),
    effective_token,
    sep = "\r"
  )
  recipient_mark <- as.numeric(bar_rows$close[match(recipient_key, bar_key)])
  parent_mark <- as.numeric(bar_rows$close[match(parent_key, bar_key)])

  security_case <- source_rows$subtype %in% c(
    "stock_acquisition", "mixed_acquisition", "spin_off"
  )
  cash_case <- source_rows$subtype %in% c(
    "cash_acquisition", "mixed_acquisition"
  )
  cash_unit <- ifelse(
    cash_case & source_rows$gross_cash_validated,
    as.numeric(source_rows$gross_cash_per_parent_unit),
    ifelse(cash_case, NA_real_, 0)
  )
  security_unit <- ifelse(
    security_case & source_rows$recipient_identity_validated &
      source_rows$recipient_quantity_validated & is.finite(recipient_mark),
    as.numeric(source_rows$recipient_quantity_per_parent_unit) * recipient_mark,
    ifelse(security_case, NA_real_, 0)
  )
  contractual <- quantity * (cash_unit + security_unit)
  successor <- quantity * security_unit
  contractual[!is.finite(cash_unit) | !is.finite(security_unit)] <- NA_real_
  successor[security_case & !is.finite(security_unit)] <- NA_real_
  difference <- contractual - modeled_cash
  affected <- abs(quantity * parent_mark)
  affected[!is.finite(parent_mark)] <- NA_real_

  data.frame(
    source_fact_id = as.character(source_rows$fact_id),
    subtype = as.character(source_rows$subtype),
    parent_instrument_id = as.character(source_rows$parent_instrument_id),
    recipient_instrument_id = as.character(source_rows$recipient_instrument_id),
    entitled_parent_quantity = as.numeric(quantity),
    modeled_cash_credited = as.numeric(modeled_cash),
    estimated_contractual_consideration = as.numeric(contractual),
    difference = as.numeric(difference),
    successor_exposure_not_represented = as.numeric(successor),
    recipient_mark = as.numeric(recipient_mark),
    valuation_ts_utc = effective,
    estimate_label = rep("effective-date estimate", length(selected)),
    affected_marked_exposure = as.numeric(affected),
    stringsAsFactors = FALSE
  )
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
  event_rows <- DBI::dbGetQuery(
    con,
    paste(
      "SELECT meta_json FROM ledger_events",
      "WHERE run_id = ? AND event_type IN ('CASHFLOW','DISPOSITION')",
      "ORDER BY event_seq"
    ),
    params = list(bt$run_id)
  )
  event_meta <- ledgr_corporate_action_event_meta(event_rows)
  cash_meta <- Filter(
    function(value) identical(value$source, "corporate_action_cash"),
    event_meta
  )
  disposition_meta <- Filter(
    function(value) identical(value$source, "corporate_action_disposition"),
    event_meta
  )
  if (length(cash_meta) > 0L) {
    amount_ids <- vapply(cash_meta, `[[`, character(1), "amount_policy_id")
    posting_ids <- vapply(cash_meta, `[[`, character(1), "posting_policy_id")
    ids <- ledgr_corporate_action_policy_ids()
    choice_counts[["cash_amount.gross"]] <- sum(
      amount_ids == ids$cash_amount[["gross"]]
    )
    choice_counts[["cash_posting.effective_close"]] <- sum(
      posting_ids == ids$cash_posting[["effective_close"]]
    )
    choice_counts[["cash_posting.next_open"]] <- sum(
      posting_ids == ids$cash_posting[["next_open"]]
    )
  }
  if (length(disposition_meta) > 0L) {
    disposition_ids <- vapply(
      disposition_meta,
      `[[`,
      character(1),
      "disposition_policy_id"
    )
    ids <- ledgr_corporate_action_policy_ids()
    choice_counts[["held_terminal_position.last_permissible"]] <- sum(
      disposition_ids == ids$held_terminal_position[["last_permissible"]]
    )
    choice_counts[["held_terminal_position.last_mark"]] <- sum(
      disposition_ids == ids$held_terminal_position[["last_mark"]]
    )
  }
  sum_meta <- function(values, name) {
    if (length(values) == 0L) return(0)
    sum(vapply(
      values,
      function(value) as.numeric(value[[name]] %||% 0),
      numeric(1)
    ))
  }
  composition <- ledgr_corporate_action_composition_report(
    con,
    snapshot_id,
    bt$run_id,
    facts$rows
  )
  unsupported <- if (nrow(composition) == 0L) {
    logical()
  } else {
    composition$subtype %in% c(
      "stock_acquisition", "mixed_acquisition", "spin_off"
    )
  }

  out <- list(
    corporate_action_fidelity = ledgr_corporate_action_fidelity(
      if (any(unsupported)) {
        "unsupported"
      } else if (length(cash_meta) > 0L || length(disposition_meta) > 0L) {
        "modeled"
      } else if (facts$supplied) {
        "none"
      } else {
        "not_supplied"
      }
    ),
    facts_supplied = facts$supplied,
    price_basis = config$data$price_basis %||% "undeclared",
    selected_settings = settings,
    selected_identities = identities,
    choice_counts = choice_counts,
    refusal_counts = refusal_counts,
    late_arrival_count = as.integer(sum_meta(cash_meta, "late_arrival")),
    affected_marked_exposure = sum(
      c(
        sum_meta(cash_meta, "affected_marked_exposure"),
        composition$affected_marked_exposure
      ),
      na.rm = TRUE
    ),
    gross_cash_posted = sum_meta(cash_meta, "cash_delta"),
    modeled_terminal_proceeds = sum_meta(disposition_meta, "cash_delta"),
    positions_disposed = as.integer(length(disposition_meta)),
    realized_model_pnl = sum_meta(disposition_meta, "realized_model_pnl"),
    unsupported_facts = as.integer(sum(unsupported)),
    omitted_value = composition
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
  if (nrow(summary$omitted_value) > 0L) {
    cat("  Effective-date omitted-value estimates:\n")
    for (i in seq_len(nrow(summary$omitted_value))) {
      row <- summary$omitted_value[i, , drop = FALSE]
      cat(sprintf(
        paste0(
          "    %s: modeled=%s contractual=%s difference=%s ",
          "successor=%s at %s\n"
        ),
        row$source_fact_id,
        ledgr_corporate_action_value(row$modeled_cash_credited),
        ledgr_corporate_action_value(row$estimated_contractual_consideration),
        ledgr_corporate_action_value(row$difference),
        ledgr_corporate_action_value(
          row$successor_exposure_not_represented
        ),
        ledgr_normalize_ts_utc(row$valuation_ts_utc)
      ))
    }
  }
  invisible(summary)
}
