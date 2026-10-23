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
  ledgr_corporate_action_decoded_settings(
    identity,
    ledgr_corporate_action_identity_decode(identity)
  )
}

ledgr_corporate_action_decoded_settings <- function(identity, decoded) {
  policy <- decoded$policy
  # Scheduled corporate-action rows carry no terminal label, so they resolve
  # the held-terminal map through its required default entry.
  c(
    cash_amount = policy$cash_amount,
    cash_posting = policy$cash_posting,
    held_terminal_position = unname(policy$held_terminal_position[["default"]]),
    unsupported_quantity = policy$unsupported_quantity,
    frozen_terminal_position = policy$frozen_terminal_position
  )
}

# Display form of a recorded policy: one string per setting and identity.
ledgr_corporate_action_policy_display <- function(identity) {
  decoded <- ledgr_corporate_action_identity_decode(identity)
  settings <- ledgr_corporate_action_decoded_settings(identity, decoded)
  policy <- decoded$policy
  map_text <- function(values) {
    if (length(values) == 1L) return(unname(values))
    paste(paste0(names(values), "=", values), collapse = "; ")
  }
  held <- identity$held_terminal_position
  settings[["held_terminal_position"]] <- map_text(policy$held_terminal_position)
  identities <- c(
    cash_amount = identity$cash_amount,
    cash_posting = identity$cash_posting,
    held_terminal_position = map_text(
      stats::setNames(held$policy_ids, held$labels)
    ),
    unsupported_quantity = identity$unsupported_quantity,
    frozen_terminal_position = identity$frozen_terminal_position
  )
  if (!is.null(policy$haircut)) {
    haircut <- format(policy$haircut, scientific = FALSE, trim = TRUE)
    settings[["haircut_fraction"]] <- haircut
    identities[["haircut_fraction"]] <- haircut
  }
  list(settings = settings, identities = identities)
}

ledgr_corporate_action_choice_keys <- function() {
  choices <- ledgr_corporate_action_policy_choices()
  unlist(lapply(names(choices), function(field) {
    paste(field, choices[[field]], sep = ".")
  }), use.names = FALSE)
}

# The sealed corporate-action rows and every sealed refusal reason with its
# row count, counted by one grouped query.
ledgr_corporate_action_fact_state <- function(con, snapshot_id) {
  supplied <- FALSE
  sealed_refusal_counts <- stats::setNames(integer(), character())
  rows <- data.frame()
  supplied <- DBI::dbGetQuery(
    con,
    paste(
      "SELECT COUNT(*) AS n FROM snapshot_fact_families",
      "WHERE snapshot_id = ? AND family = 'equity_corporate_actions'"
    ),
    params = list(snapshot_id)
  )$n[[1L]] > 0L
  if (isTRUE(supplied)) {
    rows <- ledgr_corporate_action_rows(con, snapshot_id)
    sealed <- DBI::dbGetQuery(
      con,
      paste(
        "SELECT refusal_reason, COUNT(*) AS n",
        "FROM snapshot_equity_corporate_actions",
        "WHERE snapshot_id = ? AND refusal_reason IS NOT NULL",
        "AND refusal_reason <> ''",
        "GROUP BY refusal_reason ORDER BY refusal_reason"
      ),
      params = list(snapshot_id)
    )
    sealed_refusal_counts <- stats::setNames(
      as.integer(sealed$n),
      as.character(sealed$refusal_reason)
    )
  }
  list(
    supplied = isTRUE(supplied),
    refusal_reasons = names(sealed_refusal_counts),
    sealed_refusal_counts = sealed_refusal_counts,
    rows = rows
  )
}

ledgr_corporate_action_result_events <- function(con,
                                                  run_id,
                                                  instrument_ids) {
  instrument_ids <- unique(as.character(instrument_ids))
  instrument_ids <- instrument_ids[!is.na(instrument_ids) &
    nzchar(instrument_ids)]
  if (length(instrument_ids) == 0L) {
    return(data.frame())
  }
  placeholders <- paste(rep("?", length(instrument_ids)), collapse = ",")
  DBI::dbGetQuery(
    con,
    paste0(
      "SELECT event_id, run_id, ts_utc, event_type, instrument_id, side, qty, ",
      "price, fee, meta_json, event_seq FROM ledger_events WHERE run_id = ? ",
      "AND event_type IN ('FILL','CASHFLOW','DISPOSITION') ",
      "AND instrument_id IN (", placeholders, ") ORDER BY event_seq"
    ),
    params = c(list(run_id), as.list(instrument_ids))
  )
}

# Each selected fact's entitled parent quantity as the run's fold bound it,
# recounted from the run's ledger `events` (with their parsed `meta`); 0 for
# a fact entitled outside the pulses the run processed.
ledgr_corporate_action_run_quantities <- function(con, snapshot_id, run_id, rows, selected, events, meta) {
  instrument_ids <- DBI::dbGetQuery(
    con,
    paste(
      "SELECT instrument_id FROM snapshot_instruments",
      "WHERE snapshot_id = ? ORDER BY instrument_id"
    ),
    params = list(snapshot_id)
  )$instrument_id
  # The run's own pulses are its equity timestamps; each fact binds at the pulse
  # before its entitlement pulse, as the fold does. The fold binds no fact
  # entitled outside its pulses, so neither does the report.
  pulses <- as.numeric(as.POSIXct(DBI::dbGetQuery(
    con,
    "SELECT ts_utc FROM equity_curve WHERE run_id = ? ORDER BY ts_utc",
    params = list(run_id)
  )$ts_utc, tz = "UTC"))
  # Those pulses span the run unless it stopped: an INCOMPLETE run binds
  # through its stop pulse (its last equity row, the pulse after it, or its
  # first pulse), so its window ends at the stop recorded in its diagnostics.
  window <- if (length(pulses) > 0L) pulses[c(1L, length(pulses))] else c(NA_real_, NA_real_)
  completion <- ledgr_run_completion_read(con, run_id, required = FALSE)
  if (!is.null(completion) && nrow(completion) == 1L) {
    window[[1L]] <- as.numeric(as.POSIXct(completion$intended_start_utc[[1L]], tz = "UTC"))
    if (identical(as.character(completion$intended_terminal_status[[1L]]), "INCOMPLETE")) {
      stop_ts <- DBI::dbGetQuery(
        con,
        "SELECT MAX(ts_utc) AS ts_utc FROM run_diagnostics WHERE run_id = ? AND outcome = 'stopped'",
        params = list(run_id)
      )$ts_utc
      stop_ts <- as.numeric(as.POSIXct(stop_ts, tz = "UTC"))
      if (length(stop_ts) == 1L && !is.na(stop_ts)) window[[2L]] <- stop_ts
    }
  }
  entitlement <- as.numeric(as.POSIXct(rows$entitlement_time[selected], tz = "UTC"))
  inside <- !is.na(entitlement) & !anyNA(window) &
    entitlement >= window[[1L]] & entitlement <= window[[2L]]
  before <- findInterval(entitlement, pulses, left.open = TRUE)
  cum_boundaries <- .POSIXct(ifelse(before >= 1L, pulses[pmax(before, 1L)], NA_real_), tz = "UTC")
  quantity <- numeric(length(selected))
  quantity[inside] <- ledgr_corporate_action_past_quantities(
    events,
    meta,
    rows,
    selected[inside],
    as.character(instrument_ids),
    cum_boundaries[inside]
  )
  quantity
}

# One row per fact whose parent the run held when the fact was entitled and
# that settles nothing: a complete fact of a subtype ledgr does not model
# (`refusal_reason` NA) or a refused (complete = FALSE) fact (Cut 17
# decision 12), with its entitled parent quantity.
ledgr_corporate_action_held_unsupported <- function(con, snapshot_id, run_id, rows) {
  none <- data.frame(
    refusal_reason = character(),
    entitled_quantity = numeric(),
    stringsAsFactors = FALSE
  )
  if (is.null(rows) || nrow(rows) == 0L) return(none)
  selected <- which(!rows$complete | !rows$subtype %in% ledgr_corporate_action_supported_subtypes())
  if (length(selected) == 0L) return(none)
  events <- ledgr_corporate_action_result_events(con, run_id, rows$parent_instrument_id[selected])
  if (nrow(events) == 0L) return(none)
  meta <- ledgr_corporate_action_event_meta(events)
  quantity <- ledgr_corporate_action_run_quantities(con, snapshot_id, run_id, rows, selected, events, meta)
  held <- selected[quantity != 0]
  reason <- as.character(rows$refusal_reason[held])
  reason[rows$complete[held]] <- NA_character_
  data.frame(
    refusal_reason = reason,
    entitled_quantity = as.numeric(quantity[quantity != 0]),
    stringsAsFactors = FALSE
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

  source_rows <- rows[selected, , drop = FALSE]
  events <- ledgr_corporate_action_result_events(
    con,
    run_id,
    source_rows$parent_instrument_id
  )
  if (nrow(events) == 0L) return(empty)
  meta <- ledgr_corporate_action_event_meta(events)
  quantity <- ledgr_corporate_action_run_quantities(
    con, snapshot_id, run_id, rows, selected, events, meta
  )
  relevant <- quantity != 0
  if (!any(relevant)) return(empty)
  selected <- selected[relevant]
  quantity <- quantity[relevant]
  source_rows <- source_rows[relevant, , drop = FALSE]
  source_fact_id <- vapply(
    meta,
    function(value) as.character(value$source_fact_id %||% ""),
    character(1)
  )
  cash_delta <- vapply(
    meta,
    function(value) as.numeric(value$cash_delta %||% 0),
    numeric(1)
  )
  usable_cash <- nzchar(source_fact_id)
  cash_keys <- unique(source_fact_id[usable_cash])
  cash_by_source <- if (length(cash_keys) == 0L) {
    numeric()
  } else {
    as.numeric(rowsum(
      cash_delta[usable_cash],
      group = match(source_fact_id[usable_cash], cash_keys),
      reorder = FALSE
    )[, 1L])
  }
  cash_idx <- match(as.character(source_rows$fact_id), cash_keys)
  modeled_cash <- rep(0, nrow(source_rows))
  matched_cash <- !is.na(cash_idx)
  modeled_cash[matched_cash] <- cash_by_source[cash_idx[matched_cash]]

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

#' Read a run's complete corporate-action policy record
#'
#' Returns the corporate-action fidelity, price basis, selected policy
#' settings and identities, exercised choices, refusal counts, settlement
#' totals, and effective-date omitted-value estimates recorded for one run.
#' `price_basis` is the declared basis, or `"split_adjusted"` with
#' `price_basis_default = TRUE` for an availability-aware run whose snapshot
#' declares none, or `"undeclared"` for such a dense run.
#'
#' A refused fact (`complete = FALSE`) settles nothing. `sealed_refusal_counts`
#' counts every sealed refused fact by `refusal_reason`. `refusal_counts`
#' counts, under the same reasons, the refused facts whose parent the run held
#' when the fact was entitled, and `refusal_entitled_quantity` sums their
#' absolute entitled parent quantities. A held refused fact takes the
#' unsupported-quantity route: under `unsupported_quantity = "report_only"` it
#' counts in `unsupported_facts` and `corporate_action_fidelity` reads
#' `"unsupported"`; under `"refuse"` an availability-aware run stops
#' `INCOMPLETE` with `corporate_action_quantity_refused` and a dense run raises
#' `ledgr_corporate_action_quantity_unsupported`. An unheld refused fact
#' changes neither fidelity nor the run outcome.
#'
#' `choice_counts` counts exercised choices: the cash amount and posting
#' choices once per corporate-action cash posting, the terminal choices once
#' per disposition, and `unsupported_quantity.report_only` once per held fact
#' on the unsupported-quantity route under `"report_only"`, where it equals
#' `unsupported_facts`. Every `refuse` choice reads 0: a refusal is reported
#' by the run's status and stop reason (in a dense run, by the raised
#' condition), not counted here.
#'
#' @param bt A `ledgr_backtest` object.
#' @param con An optional open database connection used internally. Public
#'   callers should leave this as `NULL`.
#' @return A list-like `ledgr_corporate_action_summary` object.
#' @export
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
  ledgr_store_assert_current(con, bt$db_path)
  ledgr_backtest_ensure_snapshot(bt, con)
  config <- bt$config
  snapshot_id <- config$data$snapshot_id
  facts <- ledgr_corporate_action_fact_state(con, snapshot_id)
  identity <- config$corporate_actions
  display <- ledgr_corporate_action_policy_display(identity)
  settings <- display$settings
  identities <- display$identities
  choice_counts <- stats::setNames(
    integer(length(ledgr_corporate_action_choice_keys())),
    ledgr_corporate_action_choice_keys()
  )
  event_rows <- DBI::dbGetQuery(
    con,
    paste(
      "SELECT ts_utc, instrument_id, qty, price, meta_json FROM ledger_events",
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
  # Scheduled corporate-action dispositions and lifetime terminal
  # dispositions share one terminal fidelity authority.
  event_sources <- vapply(
    event_meta,
    function(value) as.character(value$source %||% ""),
    character(1)
  )
  is_disposition <- event_sources %in% ledgr_disposition_sources()
  disposition_meta <- event_meta[is_disposition]
  terminal_outcomes <- ledgr_terminal_outcome_rows(
    event_rows[is_disposition, , drop = FALSE],
    disposition_meta
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
    # A frozen-terminal fallback is counted under its own field.
    keys <- ledgr_terminal_policy_id_keys()
    disposition_keys <- unname(keys[disposition_ids])
    for (key in unique(disposition_keys[!is.na(disposition_keys)])) {
      choice_counts[[key]] <- sum(disposition_keys == key, na.rm = TRUE)
    }
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
  # A held fact is unsupported when its effect is not represented: quantity
  # legs, an acquisition in a run where no disposition acts (dense), a
  # subtype ledgr does not model (Cut 12 LDG-2996) and a refused fact (Cut 17
  # LDG-3089).
  dispositions_active <- isTRUE(config$availability$active)
  unsupported <- if (nrow(composition) == 0L) {
    logical()
  } else {
    composition$subtype %in% c(
      "stock_acquisition", "mixed_acquisition", "spin_off",
      if (!dispositions_active) "cash_acquisition"
    )
  }
  held_route <- ledgr_corporate_action_held_unsupported(con, snapshot_id, bt$run_id, facts$rows)
  unsupported <- c(unsupported, rep(TRUE, nrow(held_route)))
  # Under report_only every held fact on the unsupported-quantity route,
  # refused facts included, exercised that choice (Cut 17 LDG-3091).
  if (identical(
    identity$unsupported_quantity,
    ledgr_corporate_action_policy_ids()$unsupported_quantity[["report_only"]]
  )) {
    choice_counts[["unsupported_quantity.report_only"]] <- as.integer(sum(unsupported))
  }
  # Held refused facts by sealed reason, counted and their entitled
  # quantities summed in one grouped pass.
  reasons <- facts$refusal_reasons
  refused <- !is.na(held_route$refusal_reason)
  reason_idx <- match(held_route$refusal_reason[refused], reasons)
  refusal_counts <- stats::setNames(tabulate(reason_idx, nbins = length(reasons)), reasons)
  refusal_entitled_quantity <- stats::setNames(numeric(length(reasons)), reasons)
  if (any(refused)) {
    by_reason <- rowsum(abs(held_route$entitled_quantity[refused]), reason_idx, reorder = FALSE)
    refusal_entitled_quantity[as.integer(rownames(by_reason))] <- by_reason[, 1L]
  }
  # A run stopped on a refused settlement did not represent that effect.
  completion <- ledgr_run_completion_read(con, bt$run_id, required = FALSE)
  refusal_stop <- !is.null(completion) && nrow(completion) == 1L &&
    isTRUE(completion$stop_reason[[1L]] %in% c("corporate_action_cash_refused", "corporate_action_quantity_refused"))

  basis <- ledgr_price_basis_label(config$data$price_basis, ledgr_availability_config_active(config))
  out <- list(
    corporate_action_fidelity = ledgr_corporate_action_fidelity(
      if (any(unsupported) || refusal_stop) {
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
    price_basis = basis$value,
    price_basis_default = basis$default,
    selected_settings = settings,
    selected_identities = identities,
    terminal_outcomes = terminal_outcomes,
    choice_counts = choice_counts,
    refusal_counts = refusal_counts,
    refusal_entitled_quantity = refusal_entitled_quantity,
    sealed_refusal_counts = facts$sealed_refusal_counts,
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
    cat("Price basis: ", ledgr_price_basis_display(summary$price_basis, summary$price_basis_default), "\n", sep = "")
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
      "  Setting %-26s %s\n",
      paste0(field, ":"),
      ledgr_corporate_action_value(summary$selected_settings[[field]])
    ))
    cat(sprintf(
      "  Identity %-25s %s\n",
      paste0(field, ":"),
      ledgr_corporate_action_value(summary$selected_identities[[field]])
    ))
  }
  cat("  Exercised choices:\n")
  for (key in names(summary$choice_counts)) {
    cat(sprintf("    %s: %d\n", key, summary$choice_counts[[key]]))
  }
  outcomes <- summary$terminal_outcomes
  if (is.data.frame(outcomes) && nrow(outcomes) > 0L) {
    cat("  Terminal outcomes:\n")
    cat(sprintf(
      "    %s %s: %s, proceeds %s%s\n",
      outcomes$instrument_id,
      format(outcomes$ts_utc, "%Y-%m-%d", tz = "UTC"),
      outcomes$assumption_label,
      vapply(outcomes$proceeds, ledgr_corporate_action_value, character(1)),
      ifelse(
        is.na(outcomes$terminal_event),
        "",
        sprintf(" (label %s)", outcomes$terminal_event)
      )
    ), sep = "")
  }
  # Held refused facts by reason, then every sealed refused fact by reason.
  cat("  Refusal reasons:\n")
  if (length(summary$refusal_counts) == 0L) {
    cat("    none declared: 0\n")
  } else {
    held <- summary$refusal_counts
    quantity <- summary$refusal_entitled_quantity[names(held)]
    cat(sprintf(
      "    %s: %d%s\n",
      names(held),
      held,
      ifelse(
        held > 0L,
        sprintf(" (entitled quantity %s)", vapply(quantity, ledgr_corporate_action_value, character(1))),
        ""
      )
    ), sep = "")
  }
  cat("  Sealed refusal reasons:\n")
  if (length(summary$sealed_refusal_counts) == 0L) {
    cat("    none declared: 0\n")
  } else {
    sealed <- summary$sealed_refusal_counts
    cat(sprintf("    %s: %d\n", names(sealed), sealed), sep = "")
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

ledgr_print_corporate_action_summary_compact <- function(summary) {
  if (!identical(summary$corporate_action_fidelity, "not_supplied")) {
    return(ledgr_print_corporate_action_summary(summary))
  }
  cat("\nCorporate-Action Evidence:\n")
  ledgr_print_corporate_action_headline(summary)
  cat("  Full policy record: ledgr_corporate_action_summary(bt)\n")
  invisible(summary)
}
