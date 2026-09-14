ledgr_snapshot_write_availability <- function(con,
                                              snapshot_id,
                                              facts,
                                              quarantine,
                                              invalid_observations) {
  status <- DBI::dbGetQuery(
    con,
    "SELECT status FROM snapshots WHERE snapshot_id = ?",
    params = list(snapshot_id)
  )$status
  if (length(status) != 1L || !identical(status[[1L]], "CREATED")) {
    rlang::abort(
      "Availability evidence can be written only to a CREATED snapshot.",
      class = "LEDGR_SNAPSHOT_IMMUTABLE"
    )
  }
  facts <- ledgr_facts_assert(facts)
  for (family in facts$families) {
    DBI::dbAppendTable(
      con,
      "snapshot_fact_families",
      data.frame(
        snapshot_id = snapshot_id,
        family = family$family,
        scope_id = family$scope_id,
        family_schema_version = as.integer(family$schema_version),
        metadata_json = as.character(canonical_json(family$metadata)),
        stringsAsFactors = FALSE
      )
    )
    ledgr_snapshot_write_fact_family(con, snapshot_id, family)
  }

  if (identical(invalid_observations, "quarantine")) {
    DBI::dbAppendTable(
      con,
      "snapshot_fact_families",
      data.frame(
        snapshot_id = snapshot_id,
        family = "observation_quarantine",
        scope_id = "invalid_observations",
        family_schema_version = ledgr_fact_schema_version,
        metadata_json = as.character(canonical_json(list(
          disposition = "excluded",
          invalid_observations = "quarantine",
          acknowledged = TRUE,
          row_count = nrow(quarantine)
        ))),
        stringsAsFactors = FALSE
      )
    )
    if (nrow(quarantine) > 0L) {
      rows <- quarantine
      rows$snapshot_id <- snapshot_id
      rows <- rows[, c(
        "snapshot_id", "quarantine_id", "supplied_instrument_id",
        "supplied_ts_utc", "reason", "original_row_json", "provenance_json"
      ), drop = FALSE]
      DBI::dbAppendTable(con, "snapshot_observation_quarantine", rows)
    }
  }

  DBI::dbExecute(
    con,
    "UPDATE snapshots SET hash_rule_version = 2 WHERE snapshot_id = ? AND status = 'CREATED'",
    params = list(snapshot_id)
  )
  invisible(TRUE)
}

ledgr_snapshot_write_fact_family <- function(con, snapshot_id, family) {
  rows <- family$rows
  if (identical(family$family, "membership")) {
    headers <- family$headers
    if (nrow(headers) > 0L) {
      headers$snapshot_id <- snapshot_id
      headers <- headers[, c(
        "snapshot_id", "universe_id", "set_id", "effective_from",
        "knowledge_time", "complete", "provenance_json"
      ), drop = FALSE]
      DBI::dbAppendTable(con, "snapshot_membership_sets", headers)
    }
    if (nrow(rows) > 0L) {
      rows$snapshot_id <- snapshot_id
      rows <- rows[, c(
        "snapshot_id", "fact_id", "instrument_id", "universe_id", "set_id",
        "effective_from", "effective_to", "knowledge_time", "member", "provenance_json"
      ), drop = FALSE]
      DBI::dbAppendTable(con, "snapshot_membership", rows)
    }
  } else if (identical(family$family, "trading_status")) {
    rows$snapshot_id <- snapshot_id
    rows <- rows[, c(
      "snapshot_id", "fact_id", "instrument_id", "effective_from", "effective_to",
      "knowledge_time", "status", "source", "precedence", "revision_id",
      "supersedes_fact_id", "provenance_json"
    ), drop = FALSE]
    DBI::dbAppendTable(con, "snapshot_trading_status", rows)
  } else if (identical(family$family, "lifetime")) {
    rows$snapshot_id <- snapshot_id
    rows <- rows[, c(
      "snapshot_id", "fact_id", "instrument_id", "effective_from", "effective_to",
      "knowledge_time", "assertion", "terminal_event", "provenance_json"
    ), drop = FALSE]
    DBI::dbAppendTable(con, "snapshot_lifetime", rows)
  } else if (identical(family$family, "sessions")) {
    rows$snapshot_id <- snapshot_id
    rows <- rows[, c(
      "snapshot_id", "venue_id", "session_date", "effective_from", "effective_to",
      "knowledge_time", "status", "session_open", "session_close", "provenance_json"
    ), drop = FALSE]
    DBI::dbAppendTable(con, "snapshot_sessions", rows)
  } else {
    rlang::abort(
      sprintf("Unsupported fact family: %s.", family$family),
      class = c("ledgr_invalid_facts", "ledgr_invalid_args")
    )
  }
  invisible(TRUE)
}

ledgr_snapshot_hash_rule_version <- function(con, snapshot_id) {
  if (!ledgr_experiment_store_table_exists(con, "snapshots") ||
      !"hash_rule_version" %in% ledgr_experiment_store_columns(con, "snapshots")) {
    return(1L)
  }
  value <- DBI::dbGetQuery(
    con,
    "SELECT hash_rule_version FROM snapshots WHERE snapshot_id = ?",
    params = list(snapshot_id)
  )$hash_rule_version
  if (length(value) == 0L || is.na(value[[1L]])) return(1L)
  value <- as.integer(value[[1L]])
  if (!value %in% c(1L, 2L)) {
    rlang::abort(
      sprintf("Unsupported snapshot hash rule version: %s.", value),
      class = c("ledgr_snapshot_hash_rule_unsupported", "ledgr_invalid_state")
    )
  }
  value
}

ledgr_snapshot_availability_tables <- function() {
  c(
    snapshot_fact_families = "family, scope_id",
    snapshot_membership_sets = "universe_id, set_id",
    snapshot_membership = "fact_id",
    snapshot_trading_status = "fact_id",
    snapshot_lifetime = "fact_id",
    snapshot_sessions = "venue_id, session_date",
    snapshot_observation_quarantine = "quarantine_id"
  )
}

ledgr_snapshot_availability_read <- function(con, snapshot_id) {
  tables <- ledgr_snapshot_availability_tables()
  out <- lapply(names(tables), function(table_name) {
    if (!ledgr_experiment_store_table_exists(con, table_name)) return(data.frame())
    DBI::dbGetQuery(
      con,
      sprintf(
        "SELECT * EXCLUDE (snapshot_id) FROM %s WHERE snapshot_id = ? ORDER BY %s",
        table_name,
        tables[[table_name]]
      ),
      params = list(snapshot_id)
    )
  })
  names(out) <- names(tables)
  out
}

ledgr_snapshot_availability_hash_payload <- function(con, snapshot_id) {
  tables <- ledgr_snapshot_availability_read(con, snapshot_id)
  normalized <- lapply(tables, function(df) {
    if (nrow(df) == 0L) return(list())
    for (name in names(df)) {
      if (inherits(df[[name]], "POSIXt")) {
        df[[name]] <- ledgr_fact_time_token(df[[name]])
      } else if (inherits(df[[name]], "Date")) {
        df[[name]] <- as.character(df[[name]])
      }
    }
    lapply(seq_len(nrow(df)), function(i) ledgr_fact_row_payload(df[i, , drop = FALSE]))
  })
  list(
    schema = "ledgr_snapshot_hash_rule_2",
    fact_schema_version = ledgr_fact_schema_version,
    tables = normalized
  )
}

ledgr_snapshot_validate_availability_for_seal <- function(con, snapshot_id) {
  rule <- ledgr_snapshot_hash_rule_version(con, snapshot_id)
  if (identical(rule, 1L)) return(invisible(TRUE))

  data <- ledgr_snapshot_availability_read(con, snapshot_id)
  families <- data$snapshot_fact_families
  if (nrow(families) == 0L) {
    rlang::abort(
      "Hash rule 2 requires at least one declared fact-family header.",
      class = c("ledgr_snapshot_fact_family_missing", "ledgr_invalid_state")
    )
  }
  valid_families <- c("membership", "trading_status", "lifetime", "sessions", "observation_quarantine")
  if (any(!families$family %in% valid_families) ||
      any(families$family_schema_version != ledgr_fact_schema_version)) {
    rlang::abort(
      "Snapshot contains an unsupported fact family or family schema version.",
      class = c("ledgr_snapshot_fact_family_invalid", "ledgr_invalid_state")
    )
  }
  metadata_ok <- vapply(families$metadata_json, ledgr_snapshot_valid_canonical_json, logical(1))
  if (!all(metadata_ok)) {
    rlang::abort(
      "Snapshot fact-family metadata is not valid canonical JSON.",
      class = c("ledgr_snapshot_fact_family_invalid", "ledgr_invalid_state")
    )
  }

  json_columns <- list(
    snapshot_membership_sets = "provenance_json",
    snapshot_membership = "provenance_json",
    snapshot_trading_status = "provenance_json",
    snapshot_lifetime = "provenance_json",
    snapshot_sessions = "provenance_json",
    snapshot_observation_quarantine = c("original_row_json", "provenance_json")
  )
  for (table_name in names(json_columns)) {
    rows <- data[[table_name]]
    for (column_name in json_columns[[table_name]]) {
      if (nrow(rows) > 0L && !all(vapply(rows[[column_name]], ledgr_snapshot_valid_canonical_json, logical(1)))) {
        rlang::abort(
          sprintf("%s.%s is not valid canonical JSON.", table_name, column_name),
          class = c("ledgr_snapshot_fact_json_invalid", "ledgr_invalid_state")
        )
      }
    }
  }

  required_headers <- list(
    membership = unique(c(
      data$snapshot_membership$universe_id,
      data$snapshot_membership_sets$universe_id
    )),
    trading_status = if (nrow(data$snapshot_trading_status) > 0L) "instrument" else character(),
    lifetime = if (nrow(data$snapshot_lifetime) > 0L) "instrument" else character(),
    sessions = unique(data$snapshot_sessions$venue_id)
  )
  for (family_name in names(required_headers)) {
    scopes <- required_headers[[family_name]]
    if (length(scopes) > 0L && any(!scopes %in% families$scope_id[families$family == family_name])) {
      rlang::abort(
        sprintf("Snapshot %s rows lack their fact-family header.", family_name),
        class = c("ledgr_snapshot_fact_family_missing", "ledgr_invalid_state")
      )
    }
  }

  instrument_tables <- c("snapshot_membership", "snapshot_trading_status", "snapshot_lifetime")
  known <- DBI::dbGetQuery(
    con,
    "SELECT instrument_id FROM snapshot_instruments WHERE snapshot_id = ?",
    params = list(snapshot_id)
  )$instrument_id
  for (table_name in instrument_tables) {
    rows <- data[[table_name]]
    if (nrow(rows) > 0L && any(!rows$instrument_id %in% known)) {
      rlang::abort(
        sprintf("%s references an instrument absent from the snapshot master.", table_name),
        class = c("ledgr_snapshot_fact_referential_integrity", "ledgr_invalid_state")
      )
    }
  }

  intervals <- c(instrument_tables, "snapshot_sessions")
  for (table_name in intervals) {
    rows <- data[[table_name]]
    if (nrow(rows) > 0L && any(!is.na(rows$effective_to) & rows$effective_to <= rows$effective_from)) {
      rlang::abort(
        sprintf("%s contains an invalid half-open interval.", table_name),
        class = c("ledgr_snapshot_fact_interval_invalid", "ledgr_invalid_state")
      )
    }
  }

  timestamp_columns <- list(
    snapshot_membership_sets = c("effective_from", "knowledge_time"),
    snapshot_membership = c("effective_from", "effective_to", "knowledge_time"),
    snapshot_trading_status = c("effective_from", "effective_to", "knowledge_time"),
    snapshot_lifetime = c("effective_from", "effective_to", "knowledge_time"),
    snapshot_sessions = c(
      "effective_from", "effective_to", "knowledge_time", "session_open", "session_close"
    ),
    snapshot_observation_quarantine = "supplied_ts_utc"
  )
  for (table_name in names(timestamp_columns)) {
    rows <- data[[table_name]]
    for (column_name in timestamp_columns[[table_name]]) {
      values <- rows[[column_name]]
      keep <- !is.na(values)
      if (any(keep)) {
        ledgr_assert_whole_second_utc(
          values[keep],
          label = paste0(table_name, ".", column_name),
          class = c("ledgr_snapshot_fact_timestamp_invalid", "ledgr_invalid_state")
        )
      }
    }
  }

  membership <- data$snapshot_membership
  membership_sets <- data$snapshot_membership_sets
  if (nrow(membership) > 0L) {
    membership$source <- vapply(membership$provenance_json, function(x) {
      as.character(ledgr_json_read_nested(x)$source %||% "")
    }, character(1))
    ledgr_fact_validate_membership_conflicts(membership)
  }
  set_rows <- !is.na(membership$set_id)
  if (any(set_rows)) {
    member_keys <- paste(membership$universe_id[set_rows], membership$set_id[set_rows], sep = "\r")
    set_keys <- paste(membership_sets$universe_id, membership_sets$set_id, sep = "\r")
    if (any(!member_keys %in% set_keys)) {
      rlang::abort(
        "Snapshot membership rows reference a missing membership-set header.",
        class = c("ledgr_snapshot_membership_set_missing", "ledgr_invalid_state")
      )
    }
  }

  status_rows <- data$snapshot_trading_status
  if (nrow(status_rows) > 0L) {
    ledgr_fact_validate_intervals(status_rows$effective_from, status_rows$effective_to, "trading status")
    ledgr_fact_validate_status_supersession(status_rows)
    ledgr_fact_validate_source_conflicts(status_rows)
  }
  lifetime_rows <- data$snapshot_lifetime
  if (nrow(lifetime_rows) > 0L) {
    lifetime_rows$source <- vapply(lifetime_rows$provenance_json, function(x) {
      as.character(ledgr_json_read_nested(x)$source %||% "")
    }, character(1))
    ledgr_fact_validate_lifetime_conflicts(lifetime_rows)
  }

  sessions <- data$snapshot_sessions
  if (nrow(sessions) > 0L) {
    by_venue <- split(sessions, sessions$venue_id)
    complete <- vapply(by_venue, function(rows) {
      expected <- seq(min(rows$session_date), max(rows$session_date), by = "day")
      identical(as.character(expected), as.character(sort(rows$session_date)))
    }, logical(1))
    open <- sessions$status == "open"
    times_ok <- !any(open & (is.na(sessions$session_open) | is.na(sessions$session_close))) &&
      !any(!open & (!is.na(sessions$session_open) | !is.na(sessions$session_close))) &&
      !any(open & sessions$session_open >= sessions$session_close, na.rm = TRUE)
    if (!all(complete) || !times_ok) {
      rlang::abort(
        "Snapshot session facts are incomplete or malformed.",
        class = c("ledgr_snapshot_sessions_invalid", "ledgr_invalid_state")
      )
    }
    session_headers <- families[families$family == "sessions", , drop = FALSE]
    coverage_ok <- vapply(seq_len(nrow(session_headers)), function(i) {
      meta <- ledgr_json_read_nested(session_headers$metadata_json[[i]])
      rows <- sessions[sessions$venue_id == session_headers$scope_id[[i]], , drop = FALSE]
      timezone <- as.character(meta$timezone %||% "")
      bounds_ok <- FALSE
      knowledge_ok <- FALSE
      if (nrow(rows) > 0L && length(timezone) == 1L && timezone %in% OlsonNames()) {
        expected_from <- as.POSIXct(paste(rows$session_date, "00:00:00"), tz = timezone)
        expected_to <- as.POSIXct(paste(rows$session_date + 1, "00:00:00"), tz = timezone)
        bounds_ok <- identical(as.numeric(rows$effective_from), as.numeric(expected_from)) &&
          identical(as.numeric(rows$effective_to), as.numeric(expected_to))
        open_rows <- rows$status == "open"
        late <- ifelse(
          open_rows,
          rows$knowledge_time > rows$session_open,
          rows$knowledge_time > rows$effective_from
        )
        late[is.na(late)] <- TRUE
        knowledge_ok <- !any(late)
      }
      nrow(rows) > 0L && bounds_ok && knowledge_ok &&
        identical(meta$venue_id, session_headers$scope_id[[i]]) &&
        identical(meta$coverage_start, as.character(min(rows$session_date))) &&
        identical(meta$coverage_end, as.character(max(rows$session_date))) &&
        length(timezone) == 1L && timezone %in% OlsonNames()
    }, logical(1))
    if (!all(coverage_ok)) {
      rlang::abort(
        "Snapshot session metadata does not match its persisted calendar coverage.",
        class = c("ledgr_snapshot_sessions_invalid", "ledgr_invalid_state")
      )
    }
  }

  quarantine <- data$snapshot_observation_quarantine
  q_header <- families[
    families$family == "observation_quarantine" & families$scope_id == "invalid_observations",
    ,
    drop = FALSE
  ]
  if (nrow(quarantine) > 0L && nrow(q_header) != 1L) {
    rlang::abort(
      "Quarantined observations require an explicit acknowledgement header.",
      class = c("ledgr_snapshot_quarantine_unacknowledged", "ledgr_invalid_state")
    )
  }
  if (nrow(q_header) == 1L) {
    meta <- ledgr_json_read_nested(q_header$metadata_json[[1L]])
    acknowledged <- isTRUE(meta$acknowledged) && identical(meta$invalid_observations, "quarantine") &&
      identical(as.integer(meta$row_count), nrow(quarantine))
    if (!acknowledged) {
      rlang::abort(
        "Observation quarantine acknowledgement does not match its retained rows.",
        class = c("ledgr_snapshot_quarantine_unacknowledged", "ledgr_invalid_state")
      )
    }
  }
  invisible(TRUE)
}

ledgr_snapshot_valid_canonical_json <- function(x) {
  tryCatch(
    identical(as.character(canonical_json(ledgr_json_read_nested(x))), x),
    error = function(e) FALSE
  )
}
