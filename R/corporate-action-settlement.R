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

ledgr_corporate_action_positions_before <- function(events,
                                                      instrument_ids,
                                                      boundary) {
  out <- stats::setNames(rep(0, length(instrument_ids)), instrument_ids)
  if (is.null(events) || nrow(events) == 0L) return(out)
  meta <- ledgr_corporate_action_event_meta(events)
  event_time <- as.POSIXct(events$ts_utc, tz = "UTC")
  opening <- vapply(meta, function(x) identical(x$source, "opening_position"), logical(1))
  include <- (opening & event_time <= boundary) | (!opening & event_time < boundary)
  if (!any(include)) return(out)
  for (i in which(include)) {
    instrument_id <- as.character(events$instrument_id[[i]])
    if (!instrument_id %in% instrument_ids) next
    delta <- as.numeric(meta[[i]]$position_delta %||% 0)
    if (!is.finite(delta)) {
      rlang::abort(
        "Corporate-action entitlement encountered a non-finite position delta.",
        class = c("ledgr_invalid_corporate_action_event", "ledgr_invalid_state")
      )
    }
    out[[instrument_id]] <- out[[instrument_id]] + delta
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
  knowledge_idx <- vapply(knowledge_time, function(value) {
    match_idx <- which(pulses_posix >= value)
    if (length(match_idx) == 0L) NA_integer_ else as.integer(match_idx[[1L]])
  }, integer(1))
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
  for (j in past) {
    positions <- ledgr_corporate_action_positions_before(
      existing_events,
      instrument_ids,
      entitlement_time[[j]]
    )
    id <- as.character(rows$parent_instrument_id[[j]])
    state$quantity[[j]] <- as.numeric(positions[[id]] %||% 0)
    state$bound[[j]] <- TRUE
  }

  bind_boundary <- function(index, positions) {
    selected <- which(!state$bound & state$entitlement_idx == as.integer(index))
    for (j in selected) {
      id <- as.character(state$rows$parent_instrument_id[[j]])
      state$quantity[[j]] <- as.numeric(positions[[id]] %||% 0)
      state$bound[[j]] <- TRUE
    }
    invisible(TRUE)
  }

  has_cashflow <- function() nrow(state$rows) > 0L

  post <- function(index, run_id, event_seq, output_handler, state_value,
                   marks = NULL) {
    selected <- which(
      !state$posted & state$bound & !is.na(state$due_idx) &
        state$due_idx == as.integer(index)
    )
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
      state$posted[selected] <- TRUE
      return(list(state = state_value, next_event_seq = as.integer(event_seq)))
    }
    rows_out <- vector("list", length(held))
    cash_delta <- numeric(length(held))
    for (k in seq_along(held)) {
      j <- held[[k]]
      source_row <- state$rows[j, , drop = FALSE]
      cash_delta[[k]] <- state$quantity[[j]] *
        as.numeric(source_row$gross_cash_per_parent_unit[[1L]])
      id <- as.character(source_row$parent_instrument_id[[1L]])
      mark <- as.numeric(marks[[id]] %||% NA_real_)
      meta_value <- list(
        source = "corporate_action_cash",
        source_fact_id = as.character(source_row$fact_id[[1L]]),
        cash_delta = cash_delta[[k]],
        position_delta = 0,
        entitled_quantity = state$quantity[[j]],
        gross_cash_per_parent_unit = as.numeric(source_row$gross_cash_per_parent_unit[[1L]]),
        amount_policy_id = state$identity$cash_amount,
        posting_policy_id = state$identity$cash_posting,
        late_arrival = isTRUE(state$late[[j]]),
        affected_marked_exposure = if (is.finite(mark)) abs(state$quantity[[j]] * mark) else 0
      )
      seq_value <- as.integer(event_seq) + k - 1L
      rows_out[[k]] <- data.frame(
        event_id = paste0(run_id, "_", sprintf("%08d", seq_value)),
        run_id = run_id,
        ts_utc = pulses_posix[[index]],
        event_type = "CASHFLOW",
        instrument_id = id,
        side = NA_character_,
        qty = NA_real_,
        price = NA_real_,
        fee = 0,
        meta_json = canonical_json(meta_value),
        event_seq = seq_value,
        stringsAsFactors = FALSE
      )
    }
    event_rows <- do.call(rbind, rows_out)
    ledgr_prepare_accounting_events(event_rows, instrument_ids)
    output_handler$append_event_rows(event_rows)
    state_value$cash <- as.numeric(state_value$cash) + sum(cash_delta)
    state$posted[selected] <- TRUE
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
