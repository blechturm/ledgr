ledgr_corporate_action_rows <- function(con, snapshot_id) {
  if (!ledgr_experiment_store_table_exists(con, "snapshot_equity_corporate_actions")) {
    return(data.frame())
  }
  DBI::dbGetQuery(
    con,
    paste(
      "SELECT * FROM snapshot_equity_corporate_actions",
      "WHERE snapshot_id = ? ORDER BY entitlement_time, fact_id"
    ),
    params = list(snapshot_id)
  )
}

ledgr_corporate_action_existing_events <- function(con, run_id) {
  DBI::dbGetQuery(
    con,
    paste(
      "SELECT event_id, run_id, ts_utc, event_type, instrument_id, side,",
      "qty, price, fee, meta_json, event_seq FROM ledger_events",
      "WHERE run_id = ? ORDER BY event_seq"
    ),
    params = list(run_id)
  )
}

ledgr_corporate_action_event_meta <- function(events) {
  if (is.null(events) || nrow(events) == 0L) return(list())
  lapply(events$meta_json, function(value) {
    if (is.na(value) || !nzchar(value)) return(list())
    ledgr_json_read_nested(value)
  })
}

# The quantity each selected fact is entitled to, recounted from the ledger as
# the fresh fold binds it. The fold binds pulse e's entitlement while it
# processes pulse e - 1, after that pulse's dispositions and the fills decided
# earlier, and before the fills decided at e - 1, which execute at pulse e's
# session open (or bar, in a dense run). So the recount is the position after
# every event at or before pulse e - 1 (`cum_boundaries`); an entitlement on
# the run's first pulse (NA boundary) binds the opening positions. Positions
# come from one sequential replay; a ledger whose timestamps decrease in event
# order (never written by ledgr) is replayed per boundary instead.
ledgr_corporate_action_past_quantities <- function(events,
                                                    rows,
                                                    selected,
                                                    instrument_ids,
                                                    cum_boundaries) {
  out <- rep(0, length(selected))
  if (length(selected) == 0L || is.null(events) || nrow(events) == 0L) {
    return(out)
  }
  ids <- as.character(rows$parent_instrument_id[selected])
  cum_boundaries <- as.POSIXct(cum_boundaries, tz = "UTC")
  known <- ids %in% instrument_ids
  replay <- ledgr_replay_accounting_events(ledgr_prepare_accounting_events(events))

  later <- which(known & !is.na(cum_boundaries))
  if (length(later) > 0L) {
    position <- ledgr_accounting_positions_at_pairs(replay, ids[later], cum_boundaries[later])
    if (is.null(position)) {
      event_time <- as.POSIXct(events$ts_utc, tz = "UTC")
      position <- vapply(later, function(k) {
        prefix <- events[event_time <= cum_boundaries[[k]], , drop = FALSE]
        if (nrow(prefix) == 0L) return(0)
        held <- ledgr_replay_accounting_events(ledgr_prepare_accounting_events(prefix))$positions
        value <- unname(held[ids[[k]]])
        if (length(value) == 0L || is.na(value)) 0 else value
      }, numeric(1))
    }
    out[later] <- position
  }

  first <- which(known & is.na(cum_boundaries))
  if (length(first) > 0L) {
    prepared <- replay$prepared
    opening <- prepared$operation == 3L
    opening_position <- rowsum(
      prepared$position_delta[opening],
      group = prepared$instrument_id[opening],
      reorder = FALSE
    )
    value <- opening_position[match(ids[first], rownames(opening_position)), 1L]
    out[first] <- ifelse(is.na(value), 0, value)
  }
  out
}

ledgr_corporate_action_clock_index <- function(clock,
                                                pulses_posix,
                                                label) {
  clock <- as.POSIXct(clock, tz = "UTC")
  idx <- match(as.numeric(clock), as.numeric(pulses_posix))
  inside <- !is.na(clock) & clock >= min(pulses_posix) &
    clock <= max(pulses_posix)
  if (any(inside & is.na(idx))) {
    rlang::abort(
      sprintf("Corporate-action %s time must match a run pulse.", label),
      class = c(
        "ledgr_corporate_action_clock_mismatch",
        "ledgr_invalid_state"
      )
    )
  }
  as.integer(idx)
}

ledgr_corporate_action_knowledge_index <- function(knowledge_time,
                                                    pulses_posix) {
  pulse_number <- as.numeric(pulses_posix)
  knowledge_number <- as.numeric(as.POSIXct(knowledge_time, tz = "UTC"))
  idx <- findInterval(knowledge_number, pulse_number)
  exact <- idx > 0L & pulse_number[pmax(idx, 1L)] == knowledge_number
  idx <- idx + as.integer(!exact)
  idx[idx < 1L | idx > length(pulses_posix)] <- NA_integer_
  as.integer(idx)
}

ledgr_corporate_action_plan <- function(rows,
                                        policy_identity,
                                        pulses_posix,
                                        instrument_ids,
                                        existing_events = data.frame(),
                                        start_idx = 1L) {
  if (is.null(policy_identity) || is.null(rows) || nrow(rows) == 0L) return(NULL)
  settings <- ledgr_corporate_action_policy_settings(policy_identity)
  if (anyDuplicated(rows$fact_id)) {
    rlang::abort(
      "Corporate-action source fact identifiers must be unique.",
      class = c("ledgr_duplicate_corporate_action_fact", "ledgr_invalid_state")
    )
  }
  cash_eligible <- rows$subtype == "ordinary_cash_dividend" & rows$complete
  cash_eligible <- cash_eligible &
    if (all(c(
      "gross_cash_validated",
      "gross_cash_per_parent_unit"
    ) %in% names(rows))) {
      rows$gross_cash_validated & is.finite(rows$gross_cash_per_parent_unit)
    } else {
      rep(FALSE, nrow(rows))
    }
  disposition_eligible <- rows$subtype %in% c(
    "cash_acquisition", "stock_acquisition", "mixed_acquisition"
  ) & rows$complete
  quantity_eligible <- rows$subtype %in% c(
    "stock_acquisition", "mixed_acquisition", "spin_off"
  ) & rows$complete
  if (!any(cash_eligible | disposition_eligible | quantity_eligible)) {
    return(NULL)
  }

  entitlement_idx <- ledgr_corporate_action_clock_index(
    rows$entitlement_time,
    pulses_posix,
    "entitlement"
  )
  effective_idx <- ledgr_corporate_action_clock_index(
    rows$effective_time,
    pulses_posix,
    "effective"
  )
  knowledge_idx <- ledgr_corporate_action_knowledge_index(
    rows$knowledge_time,
    pulses_posix
  )
  posting_idx <- entitlement_idx
  if (identical(settings[["cash_posting"]], "next_open")) {
    posting_idx <- posting_idx + 1L
    posting_idx[posting_idx > length(pulses_posix)] <- NA_integer_
  }
  cash_due_idx <- pmax(posting_idx, knowledge_idx, na.rm = FALSE)
  cash_due_idx[!cash_eligible] <- NA_integer_
  disposition_due_idx <- pmax(effective_idx, knowledge_idx, na.rm = FALSE)
  disposition_due_idx[!disposition_eligible] <- NA_integer_
  quantity_due_idx <- pmax(effective_idx, knowledge_idx, na.rm = FALSE)
  quantity_due_idx[!quantity_eligible] <- NA_integer_
  late <- !is.na(posting_idx) & !is.na(knowledge_idx) & knowledge_idx > posting_idx

  state <- new.env(parent = emptyenv())
  state$rows <- rows
  state$entitlement_idx <- as.integer(entitlement_idx)
  state$posting_idx <- as.integer(posting_idx)
  state$cash_eligible <- cash_eligible
  state$disposition_eligible <- disposition_eligible
  state$quantity_eligible <- quantity_eligible
  state$cash_due_idx <- as.integer(cash_due_idx)
  state$disposition_due_idx <- as.integer(disposition_due_idx)
  state$quantity_due_idx <- as.integer(quantity_due_idx)
  state$late <- as.logical(late)
  state$quantity <- rep(NA_real_, nrow(rows))
  state$bound <- rep(FALSE, nrow(rows))
  state$cash_posted <- rep(FALSE, nrow(rows))
  state$disposition_posted <- rep(FALSE, nrow(rows))
  state$quantity_checked <- rep(FALSE, nrow(rows))
  state$settings <- settings
  state$policy <- ledgr_corporate_action_identity_decode(policy_identity)$policy
  state$identity <- policy_identity
  state$instrument_ids <- instrument_ids
  state$entitlement_by_pulse <- split(seq_len(nrow(rows)), entitlement_idx)
  state$cash_due_by_pulse <- split(seq_len(nrow(rows)), cash_due_idx)
  state$disposition_due_by_pulse <- split(
    seq_len(nrow(rows)),
    disposition_due_idx
  )
  state$quantity_due_by_pulse <- split(seq_len(nrow(rows)), quantity_due_idx)

  meta <- ledgr_corporate_action_event_meta(existing_events)
  cash_fact_ids <- vapply(meta, function(x) {
    if (identical(x$source, "corporate_action_cash")) {
      as.character(x$source_fact_id %||% "")
    } else {
      ""
    }
  }, character(1))
  cash_fact_ids <- cash_fact_ids[nzchar(cash_fact_ids)]
  disposition_fact_ids <- vapply(meta, function(x) {
    if (identical(x$source, "corporate_action_disposition")) {
      as.character(x$source_fact_id %||% "")
    } else {
      ""
    }
  }, character(1))
  disposition_fact_ids <- disposition_fact_ids[nzchar(disposition_fact_ids)]
  duplicated_effect <- intersect(cash_fact_ids, disposition_fact_ids)
  if (length(duplicated_effect) > 0L) {
    rlang::abort(
      paste(
        "A corporate-action source fact cannot credit a supplied cash leg",
        "and modeled disposition proceeds."
      ),
      class = c(
        "ledgr_corporate_action_double_credit",
        "ledgr_invalid_state"
      ),
      source_fact_ids = duplicated_effect
    )
  }
  if (anyDuplicated(cash_fact_ids) || anyDuplicated(disposition_fact_ids)) {
    rlang::abort(
      "A corporate-action source fact was posted more than once.",
      class = c("ledgr_duplicate_corporate_action_event", "ledgr_invalid_state")
    )
  }
  state$cash_posted <- rows$fact_id %in% cash_fact_ids
  state$disposition_posted <- rows$fact_id %in% disposition_fact_ids

  past <- which(
    !is.na(entitlement_idx) &
      entitlement_idx <= as.integer(start_idx) &
      as.integer(start_idx) > 1L
  )
  if (length(past) > 0L) {
    previous_pulse <- entitlement_idx[past] - 1L
    cum_boundaries <- .POSIXct(
      ifelse(previous_pulse >= 1L, as.numeric(pulses_posix)[pmax(previous_pulse, 1L)], NA_real_),
      tz = "UTC"
    )
    past_quantity <- ledgr_corporate_action_past_quantities(
      existing_events,
      rows,
      past,
      instrument_ids,
      cum_boundaries
    )
    state$quantity <- replace(state$quantity, past, past_quantity)
    state$bound <- replace(state$bound, past, TRUE)
  }

  bind_boundary <- function(index, positions) {
    selected <- state$entitlement_by_pulse[[as.character(index)]] %||% integer()
    selected <- selected[!state$bound[selected]]
    if (length(selected) > 0L) {
      ids <- as.character(state$rows$parent_instrument_id[selected])
      quantity <- as.numeric(positions[match(ids, names(positions))])
      quantity[is.na(quantity)] <- 0
      state$quantity <- replace(state$quantity, selected, quantity)
      state$bound <- replace(state$bound, selected, TRUE)
    }
    invisible(TRUE)
  }

  has_cashflow <- function() any(state$cash_eligible)
  has_disposition <- function() any(state$disposition_eligible)
  event_kinds <- function() c(
    if (has_cashflow()) "CASHFLOW",
    if (has_disposition()) "DISPOSITION"
  )

  check_quantity_effects <- function(index) {
    selected <- state$quantity_due_by_pulse[[as.character(index)]] %||%
      integer()
    selected <- selected[
      !state$quantity_checked[selected] & state$bound[selected]
    ]
    if (length(selected) == 0L) return(invisible(integer()))
    held <- selected[state$quantity[selected] != 0]
    if (length(held) > 0L &&
        identical(state$settings[["unsupported_quantity"]], "refuse")) {
      rlang::abort(
        paste(
          "Corporate-action quantity effects are unsupported for held",
          "positions under the selected policy."
        ),
        class = c(
          "ledgr_corporate_action_quantity_unsupported",
          "ledgr_corporate_action_unsupported",
          "ledgr_invalid_fold_execution"
        ),
        source_fact_ids = as.character(state$rows$fact_id[held])
      )
    }
    state$quantity_checked <- replace(state$quantity_checked, selected, TRUE)
    invisible(held)
  }

  post_cash <- function(index, run_id, event_seq, output_handler, state_value,
                        marks = NULL) {
    selected <- state$cash_due_by_pulse[[as.character(index)]] %||% integer()
    selected <- selected[!state$cash_posted[selected] & state$bound[selected]]
    if (length(selected) == 0L) {
      return(list(state = state_value, next_event_seq = as.integer(event_seq)))
    }
    held <- selected[state$quantity[selected] != 0]
    if (length(held) > 0L &&
        (identical(state$settings[["cash_amount"]], "refuse") ||
         identical(state$settings[["cash_posting"]], "refuse"))) {
      rlang::abort(
        "Corporate-action cash settlement is refused by the selected policy.",
        class = c("ledgr_corporate_action_unsupported", "ledgr_invalid_fold_execution")
      )
    }
    if (length(held) == 0L) {
      state$cash_posted <- replace(state$cash_posted, selected, TRUE)
      return(list(state = state_value, next_event_seq = as.integer(event_seq)))
    }
    source_rows <- state$rows[held, , drop = FALSE]
    ids <- as.character(source_rows$parent_instrument_id)
    quantity <- state$quantity[held]
    cash_delta <- quantity * as.numeric(source_rows$gross_cash_per_parent_unit)
    mark <- rep(NA_real_, length(held))
    if (!is.null(marks)) mark <- as.numeric(marks[match(ids, names(marks))])
    affected_exposure <- ifelse(is.finite(mark), abs(quantity * mark), 0)
    meta_json <- vapply(seq_along(held), function(k) {
      canonical_json(list(
        source = "corporate_action_cash",
        source_fact_id = as.character(source_rows$fact_id[[k]]),
        cash_delta = cash_delta[[k]],
        position_delta = 0,
        entitled_quantity = quantity[[k]],
        gross_cash_per_parent_unit = as.numeric(source_rows$gross_cash_per_parent_unit[[k]]),
        amount_policy_id = state$identity$cash_amount,
        posting_policy_id = state$identity$cash_posting,
        late_arrival = isTRUE(state$late[[held[[k]]]]),
        affected_marked_exposure = affected_exposure[[k]]
      ))
    }, character(1))
    seq_value <- as.integer(event_seq) + seq_along(held) - 1L
    event_rows <- data.frame(
      event_id = paste0(run_id, "_", sprintf("%08d", seq_value)),
      run_id = rep(run_id, length(held)),
      ts_utc = rep(pulses_posix[[index]], length(held)),
      event_type = rep("CASHFLOW", length(held)),
      instrument_id = ids,
      side = rep(NA_character_, length(held)),
      qty = rep(NA_real_, length(held)),
      price = rep(NA_real_, length(held)),
      fee = rep(0, length(held)),
      meta_json = meta_json,
      event_seq = seq_value,
      stringsAsFactors = FALSE
    )
    ledgr_prepare_accounting_events(event_rows, instrument_ids)
    output_handler$append_event_rows(event_rows)
    state_value$cash <- as.numeric(state_value$cash) + sum(cash_delta)
    state$cash_posted <- replace(state$cash_posted, selected, TRUE)
    list(
      state = state_value,
      next_event_seq = as.integer(event_seq) + nrow(event_rows)
    )
  }

  post_disposition <- function(index,
                               run_id,
                               event_seq,
                               output_handler,
                               state_value,
                               valuation) {
    none <- list(
      state = state_value,
      next_event_seq = as.integer(event_seq),
      dispositions = 0L,
      stopped = NULL
    )
    selected <- state$disposition_due_by_pulse[[as.character(index)]] %||%
      integer()
    selected <- selected[
      !state$disposition_posted[selected] & state$bound[selected]
    ]
    if (length(selected) == 0L) {
      return(none)
    }

    ids <- as.character(state$rows$parent_instrument_id[selected])
    position_names <- names(state_value$positions)
    if (is.null(position_names) &&
        length(state_value$positions) == length(state$instrument_ids)) {
      position_names <- state$instrument_ids
    }
    before <- as.numeric(state_value$positions[match(ids, position_names)])
    before[is.na(before)] <- 0
    held <- which(before != 0)
    if (length(held) == 0L) {
      state$disposition_posted <- replace(
        state$disposition_posted,
        selected,
        TRUE
      )
      return(none)
    }
    selected <- selected[held]
    ids <- ids[held]

    # Scheduled rows are settlement evidence. A refused or unpriceable row
    # stops typed, which also keeps the lifetime path from disposing the
    # holding on this pulse.
    resolved <- ledgr_terminal_resolve_scheduled(state$policy, ids, valuation)
    blocked <- resolved$outcome != "dispose"
    if (any(blocked)) {
      refused <- any(resolved$outcome == "refuse")
      return(c(none[c("state", "next_event_seq", "dispositions")], list(
        stopped = list(
          ids = ids[blocked],
          reason_code = if (refused) {
            "terminal_settlement_unsupported"
          } else {
            "terminal_mark_unavailable"
          },
          reasons = ifelse(
            resolved$outcome[blocked] == "refuse",
            "terminal_settlement_unsupported",
            paste("terminal_mark_unavailable", resolved$choice[blocked], sep = "|")
          )
        )
      )))
    }

    mark_meta <- ledgr_terminal_mark_meta(
      resolved,
      valuation,
      pulses_posix[[index]]
    )
    source_rows <- state$rows[selected, , drop = FALSE]
    meta <- lapply(seq_along(ids), function(k) {
      out <- list(
        source = "corporate_action_disposition",
        source_fact_id = as.character(source_rows$fact_id[[k]]),
        disposition_policy_id = resolved$policy_id[[k]],
        disposition_choice = resolved$choice[[k]],
        disposition_basis = resolved$basis[[k]],
        mark_source = mark_meta$source[[k]],
        mark_source_ts_utc = mark_meta$source_ts[[k]],
        mark_age = mark_meta$age[[k]]
      )
      if (identical(resolved$choice[[k]], "haircut")) {
        out$haircut_fraction <- resolved$haircut
      }
      out
    })
    posted <- ledgr_disposition_post(
      ids = ids,
      price = resolved$price,
      meta = meta,
      ts = pulses_posix[[index]],
      run_id = run_id,
      event_seq = event_seq,
      output_handler = output_handler,
      state_value = state_value,
      instrument_ids = state$instrument_ids,
      exposure_mark = resolved$reference
    )
    state$disposition_posted <- replace(
      state$disposition_posted,
      selected,
      TRUE
    )
    list(
      state = posted$state,
      next_event_seq = posted$next_event_seq,
      dispositions = posted$dispositions,
      stopped = NULL
    )
  }

  structure(
    list(
      bind_boundary = bind_boundary,
      post = post_cash,
      post_cash = post_cash,
      post_disposition = post_disposition,
      check_quantity_effects = check_quantity_effects,
      has_cashflow = has_cashflow,
      has_disposition = has_disposition,
      event_kinds = event_kinds,
      state = state
    ),
    class = "ledgr_corporate_action_plan"
  )
}
