ledgr_availability_provider_version <- function() {
  "ledgr_availability_provider_v1"
}

ledgr_availability_config_active <- function(config) {
  is.list(config$availability) && isTRUE(config$availability$active)
}

ledgr_availability_stable_ids <- function(ids) {
  ids <- unique(as.character(ids))
  ids <- ids[!is.na(ids) & nzchar(ids)]
  ids[order(enc2utf8(ids), method = "radix")]
}

ledgr_availability_read_table <- function(con, table, snapshot_id, order_by) {
  if (!ledgr_experiment_store_table_exists(con, table)) return(data.frame())
  DBI::dbGetQuery(
    con,
    sprintf(
      "SELECT * EXCLUDE (snapshot_id) FROM %s WHERE snapshot_id = ? ORDER BY %s",
      table,
      order_by
    ),
    params = list(snapshot_id)
  )
}

ledgr_availability_provider_data <- function(con, snapshot_id) {
  list(
    families = ledgr_availability_read_table(
      con, "snapshot_fact_families", snapshot_id, "family, scope_id"
    ),
    membership_sets = ledgr_availability_read_table(
      con, "snapshot_membership_sets", snapshot_id, "effective_from, knowledge_time, set_id"
    ),
    membership = ledgr_availability_read_table(
      con, "snapshot_membership", snapshot_id, "effective_from, knowledge_time, fact_id"
    ),
    status = ledgr_availability_read_table(
      con, "snapshot_trading_status", snapshot_id, "effective_from, knowledge_time, fact_id"
    ),
    lifetime = ledgr_availability_read_table(
      con, "snapshot_lifetime", snapshot_id, "effective_from, knowledge_time, fact_id"
    ),
    sessions = ledgr_availability_read_table(
      con, "snapshot_sessions", snapshot_id, "session_date"
    )
  )
}

ledgr_availability_applicable <- function(rows, cutoff) {
  if (nrow(rows) == 0L) return(logical())
  effective <- !is.na(rows$effective_from) & rows$effective_from <= cutoff
  knowable <- !is.na(rows$knowledge_time) & rows$knowledge_time <= cutoff
  before_end <- is.na(rows$effective_to) | cutoff < rows$effective_to
  effective & knowable & before_end
}

ledgr_membership_resolve_at <- function(data,
                                        universe_id,
                                        cutoff,
                                        instruments = NULL) {
  headers <- data$membership_sets
  headers <- headers[headers$universe_id == universe_id, , drop = FALSE]
  if (nrow(headers) > 0L) {
    eligible <- !is.na(headers$effective_from) & headers$effective_from <= cutoff &
      !is.na(headers$knowledge_time) & headers$knowledge_time <= cutoff
    headers <- headers[eligible, , drop = FALSE]
  }
  state <- logical()
  reason <- character()
  support <- list()
  last_complete <- NULL
  if (nrow(headers) > 0L) {
    header_order <- order(
      headers$effective_from,
      headers$knowledge_time,
      headers$set_id
    )
    headers <- headers[header_order, , drop = FALSE]
    rows <- data$membership
    for (i in seq_len(nrow(headers))) {
      set_rows <- rows[
        rows$universe_id == universe_id & rows$set_id == headers$set_id[[i]],
        ,
        drop = FALSE
      ]
      set_ids <- as.character(set_rows$instrument_id)
      header_ref <- paste0("set:", headers$set_id[[i]])
      if (isTRUE(headers$complete[[i]])) {
        if (length(state) > 0L) {
          state[] <- FALSE
          reason[] <- "omitted_from_complete_set"
          support <- stats::setNames(
            rep(list(header_ref), length(state)),
            names(state)
          )
        }
        last_complete <- list(
          header = headers[i, , drop = FALSE],
          reference = header_ref
        )
      }
      for (id in set_ids) {
        state[[id]] <- TRUE
        reason[[id]] <- "member_asserted"
        fact_ref <- paste0("fact:", set_rows$fact_id[set_rows$instrument_id == id][[1L]])
        support[[id]] <- c(header_ref, fact_ref)
      }
    }
  }
  rows <- data$membership
  rows <- rows[rows$universe_id == universe_id & is.na(rows$set_id), , drop = FALSE]
  rows <- rows[ledgr_availability_applicable(rows, cutoff), , drop = FALSE]
  if (nrow(rows) > 0L) {
    rows <- rows[order(rows$effective_from, rows$knowledge_time, rows$fact_id), , drop = FALSE]
    for (i in seq_len(nrow(rows))) {
      id <- as.character(rows$instrument_id[[i]])
      if (isTRUE(rows$member[[i]])) {
        state[[id]] <- TRUE
        reason[[id]] <- "member_asserted"
      } else {
        state[[id]] <- FALSE
        reason[[id]] <- "nonmember_asserted"
      }
      support[[id]] <- paste0("fact:", rows$fact_id[[i]])
    }
  }
  members <- ledgr_availability_stable_ids(names(state)[state])
  requested <- if (is.null(instruments)) {
    members
  } else {
    unique(as.character(instruments))
  }
  resolved <- lapply(requested, function(id) {
    if (id %in% names(state)) {
      return(list(
        instrument_id = id,
        member = unname(state[[id]]),
        reason = unname(reason[[id]]),
        evidence_ids = support[[id]] %||% character()
      ))
    }
    if (!is.null(last_complete)) {
      return(list(
        instrument_id = id,
        member = FALSE,
        reason = "omitted_from_complete_set",
        evidence_ids = last_complete$reference
      ))
    }
    list(
      instrument_id = id,
      member = NA,
      reason = "unknown_no_usable_evidence",
      evidence_ids = character()
    )
  })
  resolution_rows <- data.frame(
    instrument_id = vapply(resolved, `[[`, character(1), "instrument_id"),
    member = vapply(resolved, function(x) x$member, logical(1)),
    reason = vapply(resolved, `[[`, character(1), "reason"),
    evidence_ids = vapply(
      resolved,
      function(x) paste(x$evidence_ids, collapse = "|"),
      character(1)
    ),
    stringsAsFactors = FALSE
  )
  list(
    members = members,
    rows = resolution_rows,
    applicable_headers = headers,
    applicable_rows = rows
  )
}

ledgr_availability_restrictions <- function(status, lifetime, status_declared, lifetime_declared) {
  ids <- names(status)
  restricted <- stats::setNames(rep(FALSE, length(ids)), ids)
  reason <- stats::setNames(rep("", length(ids)), ids)
  reasons <- stats::setNames(rep("", length(ids)), ids)
  if (isTRUE(status_declared)) {
    map <- c(
      halted = "trading_halted",
      quotation_only = "quotation_only",
      unknown = "status_unknown",
      conflicting = "status_unknown_or_conflicting"
    )
    hit <- status %in% names(map)
    restricted[hit] <- TRUE
    reason[hit] <- unname(map[status[hit]])
    reasons[hit] <- reason[hit]
  }
  if (isTRUE(lifetime_declared)) {
    hit <- lifetime == "known_inactive"
    restricted[hit] <- TRUE
    reason[hit & !nzchar(reason)] <- "lifetime_inactive"
    reasons[hit] <- ifelse(
      nzchar(reasons[hit]),
      paste(reasons[hit], "lifetime_inactive", sep = "|"),
      "lifetime_inactive"
    )
  }
  list(restricted = restricted, reason = reason, reasons = reasons)
}

ledgr_availability_provider <- function(con, config, snapshot_hash) {
  if (!ledgr_availability_config_active(config)) return(NULL)
  snapshot_id <- as.character(config$data$snapshot_id)
  data <- ledgr_availability_provider_data(con, snapshot_id)
  history <- function(instrument_id, cutoff, sessions = NULL) {
    cutoff <- as.POSIXct(cutoff, tz = "UTC")
    rows <- DBI::dbGetQuery(
      con,
      paste(
        "SELECT instrument_id, ts_utc, open, high, low, close, volume",
        "FROM snapshot_bars WHERE snapshot_id = ? AND instrument_id = ?",
        "AND ts_utc <= ? ORDER BY ts_utc"
      ),
      params = list(snapshot_id, instrument_id, cutoff)
    )
    if (!is.null(sessions)) rows <- utils::tail(rows, as.integer(sessions))
    rows
  }
  ledgr_availability_provider_build(data, config, snapshot_hash, history)
}

ledgr_availability_provider_portable <- function(data,
                                                 config,
                                                 snapshot_hash,
                                                 bars_by_id) {
  history <- function(instrument_id, cutoff, sessions = NULL) {
    rows <- bars_by_id[[instrument_id]]
    if (is.null(rows)) rows <- data.frame()
    if (nrow(rows) > 0L) {
      rows <- rows[as.POSIXct(rows$ts_utc, tz = "UTC") <= as.POSIXct(cutoff, tz = "UTC"), , drop = FALSE]
    }
    if (!is.null(sessions)) rows <- utils::tail(rows, as.integer(sessions))
    rows
  }
  ledgr_availability_provider_build(data, config, snapshot_hash, history)
}

ledgr_availability_provider_build <- function(data, config, snapshot_hash, history) {
  ledgr_availability_provider_build_prepared(data, config, snapshot_hash, history)
}

ledgr_availability_calendar <- function(provider, start_ts_utc, end_ts_utc) {
  sessions <- provider$sessions
  sessions <- sessions[sessions$status == "open", , drop = FALSE]
  # `ledgr_normalize_ts_utc()` emits ISO8601 with `T`/`Z`, which base `as.POSIXct`
  # cannot parse without an explicit format: it falls back to `%Y-%m-%d` and
  # silently truncates the bound to midnight, dropping the final session close.
  start <- as.POSIXct(
    ledgr_normalize_ts_utc(start_ts_utc),
    tz = "UTC",
    format = "%Y-%m-%dT%H:%M:%SZ"
  )
  end <- as.POSIXct(
    ledgr_normalize_ts_utc(end_ts_utc),
    tz = "UTC",
    format = "%Y-%m-%dT%H:%M:%SZ"
  )
  sessions <- sessions[
    !is.na(sessions$session_close) &
      sessions$session_close >= start &
      sessions$session_close <= end,
    ,
    drop = FALSE
  ]
  sessions <- sessions[order(sessions$session_close), , drop = FALSE]
  pulses_posix <- as.POSIXct(sessions$session_close, tz = "UTC")
  if (length(pulses_posix) < 2L) {
    rlang::abort(
      paste(
        "The declared session calendar must provide at least two open-session",
        "pulses in the run window."
      ),
      class = c("ledgr_run_window_too_short", "ledgr_invalid_config")
    )
  }
  execution_opportunities_posix <- ledgr_session_execution_opportunities(sessions)
  list(
    pulses = pulses_posix,
    pulses_posix = pulses_posix,
    pulses_iso = format(pulses_posix, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    execution_opportunities_posix = execution_opportunities_posix
  )
}
