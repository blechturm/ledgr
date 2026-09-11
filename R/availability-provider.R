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

ledgr_availability_members_at <- function(data, universe_rule, fixed_ids, cutoff) {
  if (is.null(universe_rule)) return(as.character(fixed_ids))
  universe_id <- as.character(universe_rule$universe_id)
  headers <- data$membership_sets
  headers <- headers[headers$universe_id == universe_id, , drop = FALSE]
  if (nrow(headers) > 0L) {
    eligible <- !is.na(headers$effective_from) & headers$effective_from <= cutoff &
      !is.na(headers$knowledge_time) & headers$knowledge_time <= cutoff
    headers <- headers[eligible, , drop = FALSE]
  }
  members <- character()
  if (nrow(headers) > 0L) {
    header_order <- order(
      headers$effective_from,
      headers$knowledge_time,
      headers$set_id
    )
    headers <- headers[header_order, , drop = FALSE]
    rows <- data$membership
    for (i in seq_len(nrow(headers))) {
      set_ids <- as.character(rows$instrument_id[
        rows$universe_id == universe_id & rows$set_id == headers$set_id[[i]]
      ])
      if (isTRUE(headers$complete[[i]])) members <- character()
      members <- unique(c(members, set_ids))
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
        members <- unique(c(members, id))
      } else {
        members <- setdiff(members, id)
      }
    }
  }
  ledgr_availability_stable_ids(members)
}

ledgr_availability_status_at <- function(rows, ids, cutoff) {
  out <- stats::setNames(rep("active", length(ids)), ids)
  if (nrow(rows) == 0L || length(ids) == 0L) return(out)
  for (id in ids) {
    current <- rows[rows$instrument_id == id, , drop = FALSE]
    current <- current[ledgr_availability_applicable(current, cutoff), , drop = FALSE]
    if (nrow(current) == 0L) {
      out[[id]] <- "unknown"
      next
    }
    superseded <- as.character(current$supersedes_fact_id)
    superseded <- superseded[!is.na(superseded) & nzchar(superseded)]
    current <- current[!current$fact_id %in% superseded, , drop = FALSE]
    top <- max(as.integer(current$precedence))
    values <- unique(as.character(current$status[current$precedence == top]))
    out[[id]] <- if (length(values) == 1L) values else "conflicting"
  }
  out
}

ledgr_availability_lifetime_at <- function(rows, ids, cutoff) {
  out <- stats::setNames(rep("unknown", length(ids)), ids)
  if (nrow(rows) == 0L || length(ids) == 0L) return(out)
  for (id in ids) {
    current <- rows[rows$instrument_id == id, , drop = FALSE]
    current <- current[ledgr_availability_applicable(current, cutoff), , drop = FALSE]
    if (nrow(current) > 0L) {
      current <- current[order(current$effective_from, current$knowledge_time), , drop = FALSE]
      out[[id]] <- as.character(current$assertion[[nrow(current)]])
    }
  }
  out
}

ledgr_availability_restrictions <- function(status, lifetime, status_declared, lifetime_declared) {
  ids <- names(status)
  restricted <- stats::setNames(rep(FALSE, length(ids)), ids)
  reason <- stats::setNames(rep("", length(ids)), ids)
  if (isTRUE(status_declared)) {
    map <- c(
      halted = "status_halted",
      quotation_only = "status_quotation_only",
      unknown = "status_unknown",
      conflicting = "status_unknown_or_conflicting"
    )
    hit <- status %in% names(map)
    restricted[hit] <- TRUE
    reason[hit] <- unname(map[status[hit]])
  }
  if (isTRUE(lifetime_declared)) {
    hit <- lifetime == "known_inactive"
    restricted[hit] <- TRUE
    reason[hit & !nzchar(reason)] <- "lifetime_inactive"
  }
  list(restricted = restricted, reason = reason)
}

ledgr_availability_provider <- function(con, config, snapshot_hash) {
  if (!ledgr_availability_config_active(config)) return(NULL)
  snapshot_id <- as.character(config$data$snapshot_id)
  data <- ledgr_availability_provider_data(con, snapshot_id)
  family_order <- c("membership", "sessions", "trading_status", "lifetime")
  families <- family_order[family_order %in% as.character(data$families$family)]
  universe_rule <- config$availability$universe_rule
  if (!is.null(universe_rule)) class(universe_rule) <- c("ledgr_universe_rule", "list")

  facts <- function(cutoff, ids = config$universe$instrument_ids) {
    cutoff <- as.POSIXct(cutoff, tz = "UTC")
    status <- ledgr_availability_status_at(data$status, ids, cutoff)
    lifetime <- ledgr_availability_lifetime_at(data$lifetime, ids, cutoff)
    list(
      status = status,
      lifetime = lifetime,
      cutoff = cutoff
    )
  }

  decision_view <- function(cutoff, positions) {
    cutoff <- as.POSIXct(cutoff, tz = "UTC")
    members <- ledgr_availability_members_at(
      data,
      universe_rule,
      config$universe$instrument_ids,
      cutoff
    )
    held <- names(positions)[as.numeric(positions) != 0]
    held_nonmembers <- ledgr_availability_stable_ids(setdiff(held, members))
    axis <- unique(c(members, held_nonmembers))
    resolved <- facts(cutoff, axis)
    restrictions <- ledgr_availability_restrictions(
      resolved$status,
      resolved$lifetime,
      "trading_status" %in% families,
      "lifetime" %in% families
    )
    list(
      axis = axis,
      members = members,
      member = stats::setNames(axis %in% members, axis),
      held = stats::setNames(axis %in% held, axis),
      target_restricted = restrictions$restricted,
      target_restriction_reason = restrictions$reason,
      status = resolved$status,
      lifetime = resolved$lifetime
    )
  }

  execution_view <- function(cutoff, ids) {
    resolved <- facts(cutoff, ids)
    restrictions <- ledgr_availability_restrictions(
      resolved$status,
      resolved$lifetime,
      "trading_status" %in% families,
      "lifetime" %in% families
    )
    c(resolved, restrictions)
  }

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

  identity <- function() {
    list(
      provider_version = ledgr_availability_provider_version(),
      snapshot_hash = snapshot_hash,
      declared_families = families
    )
  }

  structure(
    list(
      facts = facts,
      decision_view = decision_view,
      execution_view = execution_view,
      history = history,
      identity = identity,
      sessions = data$sessions
    ),
    class = c("ledgr_availability_provider", "list")
  )
}

ledgr_availability_calendar <- function(provider, start_ts_utc, end_ts_utc) {
  sessions <- provider$sessions
  sessions <- sessions[sessions$status == "open", , drop = FALSE]
  start <- as.POSIXct(ledgr_normalize_ts_utc(start_ts_utc), tz = "UTC")
  end <- as.POSIXct(ledgr_normalize_ts_utc(end_ts_utc), tz = "UTC")
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
  list(
    pulses = pulses_posix,
    pulses_posix = pulses_posix,
    pulses_iso = format(pulses_posix, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
}
