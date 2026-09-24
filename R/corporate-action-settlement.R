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

ledgr_corporate_action_cumulative_at <- function(times,
                                                 deltas,
                                                 boundaries,
                                                 include_equal) {
  if (length(times) == 0L) return(rep(0, length(boundaries)))
  time_number <- as.numeric(times)
  time_order <- order(time_number)
  time_number <- time_number[time_order]
  unique_times <- unique(time_number)
  grouped <- rowsum(
    as.numeric(deltas)[time_order],
    group = match(time_number, unique_times),
    reorder = FALSE
  )
  cumulative <- cumsum(as.numeric(grouped[, 1L]))
  idx <- findInterval(as.numeric(boundaries), unique_times)
  if (!isTRUE(include_equal)) {
    equal <- idx > 0L & unique_times[pmax(idx, 1L)] == as.numeric(boundaries)
    idx[equal] <- idx[equal] - 1L
  }
  ifelse(idx > 0L, cumulative[pmax(idx, 1L)], 0)
}

ledgr_corporate_action_past_quantities <- function(events,
                                                    rows,
                                                    selected,
                                                    instrument_ids) {
  out <- rep(0, length(selected))
  if (length(selected) == 0L || is.null(events) || nrow(events) == 0L) {
    return(out)
  }
  meta <- ledgr_corporate_action_event_meta(events)
  event_time <- as.POSIXct(events$ts_utc, tz = "UTC")
  opening <- vapply(meta, function(x) identical(x$source, "opening_position"), logical(1))
  delta <- vapply(meta, function(x) as.numeric(x$position_delta %||% 0), numeric(1))
  if (any(!is.finite(delta))) {
    rlang::abort(
      "Corporate-action entitlement encountered a non-finite position delta.",
      class = c("ledgr_invalid_corporate_action_event", "ledgr_invalid_state")
    )
  }
  event_instrument <- as.character(events$instrument_id)
  fact_instrument <- as.character(rows$parent_instrument_id[selected])
  boundaries <- as.POSIXct(rows$entitlement_time[selected], tz = "UTC")
  for (instrument_id in intersect(unique(fact_instrument), instrument_ids)) {
    fact_idx <- which(fact_instrument == instrument_id)
    event_idx <- which(event_instrument == instrument_id)
    opening_idx <- event_idx[opening[event_idx]]
    ordinary_idx <- event_idx[!opening[event_idx]]
    out[fact_idx] <-
      ledgr_corporate_action_cumulative_at(
        event_time[opening_idx],
        delta[opening_idx],
        boundaries[fact_idx],
        include_equal = TRUE
      ) +
      ledgr_corporate_action_cumulative_at(
        event_time[ordinary_idx],
        delta[ordinary_idx],
        boundaries[fact_idx],
        include_equal = FALSE
      )
  }
  out
}

ledgr_corporate_action_plan <- function(rows,
                                        policy_identity,
                                        pulses_posix,
                                        instrument_ids,
                                        existing_events = data.frame(),
                                        start_idx = 1L) {
  if (is.null(policy_identity) || is.null(rows) || nrow(rows) == 0L) return(NULL)
  settings <- ledgr_corporate_action_policy_settings(policy_identity)
  rows <- rows[
    rows$subtype == "ordinary_cash_dividend" &
      rows$complete & rows$gross_cash_validated &
      is.finite(rows$gross_cash_per_parent_unit),
    ,
    drop = FALSE
  ]
  if (nrow(rows) == 0L) return(NULL)
  if (anyDuplicated(rows$fact_id)) {
    rlang::abort(
      "Corporate-action source fact identifiers must be unique.",
      class = c("ledgr_duplicate_corporate_action_fact", "ledgr_invalid_state")
    )
  }
  entitlement_time <- as.POSIXct(rows$entitlement_time, tz = "UTC")
  knowledge_time <- as.POSIXct(rows$knowledge_time, tz = "UTC")
  entitlement_idx <- match(as.numeric(entitlement_time), as.numeric(pulses_posix))
  inside <- entitlement_time >= min(pulses_posix) & entitlement_time <= max(pulses_posix)
  if (any(inside & is.na(entitlement_idx))) {
    rlang::abort(
      "Corporate-action entitlement time must match a run pulse.",
      class = c("ledgr_corporate_action_clock_mismatch", "ledgr_invalid_state")
    )
  }
  posting_idx <- entitlement_idx
  if (identical(settings[["cash_posting"]], "next_open")) {
    posting_idx <- posting_idx + 1L
    posting_idx[posting_idx > length(pulses_posix)] <- NA_integer_
  }
  pulse_number <- as.numeric(pulses_posix)
  knowledge_number <- as.numeric(knowledge_time)
  knowledge_idx <- findInterval(knowledge_number, pulse_number)
  exact <- knowledge_idx > 0L &
    pulse_number[pmax(knowledge_idx, 1L)] == knowledge_number
  knowledge_idx <- knowledge_idx + as.integer(!exact)
  knowledge_idx[knowledge_idx < 1L | knowledge_idx > length(pulses_posix)] <- NA_integer_
  due_idx <- pmax(posting_idx, knowledge_idx, na.rm = FALSE)
  late <- !is.na(posting_idx) & !is.na(knowledge_idx) & knowledge_idx > posting_idx

  state <- new.env(parent = emptyenv())
  state$rows <- rows
  state$entitlement_idx <- as.integer(entitlement_idx)
  state$posting_idx <- as.integer(posting_idx)
  state$due_idx <- as.integer(due_idx)
  state$late <- as.logical(late)
  state$quantity <- rep(NA_real_, nrow(rows))
  state$bound <- rep(FALSE, nrow(rows))
  state$posted <- rep(FALSE, nrow(rows))
  state$settings <- settings
  state$identity <- policy_identity
  state$instrument_ids <- instrument_ids
  state$entitlement_by_pulse <- split(seq_len(nrow(rows)), entitlement_idx)
  state$due_by_pulse <- split(seq_len(nrow(rows)), due_idx)

  meta <- ledgr_corporate_action_event_meta(existing_events)
  posted_fact_ids <- vapply(meta, function(x) {
    if (identical(x$source, "corporate_action_cash")) {
      as.character(x$source_fact_id %||% "")
    } else {
      ""
    }
  }, character(1))
  posted_fact_ids <- posted_fact_ids[nzchar(posted_fact_ids)]
  if (anyDuplicated(posted_fact_ids)) {
    rlang::abort(
      "A corporate-action source fact was posted more than once.",
      class = c("ledgr_duplicate_corporate_action_event", "ledgr_invalid_state")
    )
  }
  state$posted <- rows$fact_id %in% posted_fact_ids

  past <- which(
    !is.na(entitlement_idx) &
      entitlement_idx <= as.integer(start_idx) &
      as.integer(start_idx) > 1L
  )
  if (length(past) > 0L) {
    past_quantity <- ledgr_corporate_action_past_quantities(
      existing_events,
      rows,
      past,
      instrument_ids
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

  has_cashflow <- function() nrow(state$rows) > 0L

  post <- function(index, run_id, event_seq, output_handler, state_value,
                   marks = NULL) {
    selected <- state$due_by_pulse[[as.character(index)]] %||% integer()
    selected <- selected[!state$posted[selected] & state$bound[selected]]
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
      state$posted <- replace(state$posted, selected, TRUE)
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
    state$posted <- replace(state$posted, selected, TRUE)
    list(
      state = state_value,
      next_event_seq = as.integer(event_seq) + nrow(event_rows)
    )
  }

  structure(
    list(
      bind_boundary = bind_boundary,
      post = post,
      has_cashflow = has_cashflow,
      state = state
    ),
    class = "ledgr_corporate_action_plan"
  )
}
