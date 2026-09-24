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
  } else if (identical(family$family, "equity_corporate_actions")) {
    rows$snapshot_id <- snapshot_id
    rows <- rows[, c(
      "snapshot_id", "fact_id", "subtype", "parent_instrument_id",
      "entitlement_time", "effective_time", "knowledge_time",
      "payment_time", "complete", "refusal_reason", "provenance_tier",
      "upstream_build_id", "bar_vintage_id",
      "gross_cash_per_parent_unit", "gross_cash_validated",
      "recipient_instrument_id", "recipient_identity_validated",
      "recipient_quantity_per_parent_unit",
      "recipient_quantity_validated", "provenance_json"
    ), drop = FALSE]
    DBI::dbAppendTable(con, "snapshot_equity_corporate_actions", rows)
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
    snapshot_equity_corporate_actions = "fact_id",
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

# How a quarantined row enters snapshot identity.
#
# A quarantined bar is not written to snapshot_bars, so `original_row_json` is
# the only record of its values and the hash has to cover them. But that field
# serializes *every* column of the supplied row, including ones ledgr never
# reads, and both ingestion surfaces document that extra columns "are ignored
# and do not become part of the sealed snapshot or its hash". Hashing the
# field whole made that false: a stray spreadsheet column moved the snapshot
# hash whenever a row was quarantined.
#
# So the hashed view keeps the row's canonical bar fields and drops the rest.
# `quarantine_id` is a digest of the whole quarantine row, `original_row_json`
# included, so it carries the discarded values straight back in, and it is
# also the read's ORDER BY key, which would leak them through row order. It is
# dropped from the view and the rows are ordered on stable fields instead.
#
# The stored field is untouched. A user still reads the complete supplied row.
#
# Maintainer decision, 2026-09-22, after close review W9-F5. This changes the
# rule-2 hash of any snapshot that has a quarantined row whose supplied file
# carried columns beyond the canonical set.
ledgr_snapshot_quarantine_hashed_row_keys <- function() {
  c("instrument_id", "ts_utc", "open", "high", "low", "close", "volume")
}

# The projection fails closed. A saved row that is not a JSON object carrying
# the required bar keys cannot be projected, and returning it raw would put
# the discarded columns back into the hash, or, for a scalar, leave the row's
# values out of identity altogether while the snapshot still verified. Close
# review W9-F8 reached that state through the lower-level store and seal
# boundary. Extra keys stay allowed and stay excluded.
ledgr_snapshot_quarantine_required_row_keys <- function() {
  c("instrument_id", "ts_utc", "open", "high", "low", "close")
}

ledgr_snapshot_quarantine_parse_hashed_row <- function(value) {
  invalid <- function(detail) {
    rlang::abort(
      sprintf(
        "snapshot_observation_quarantine.original_row_json %s.",
        detail
      ),
      class = c("ledgr_snapshot_fact_json_invalid", "ledgr_invalid_state")
    )
  }
  if (length(value) != 1L || is.na(value) || !nzchar(value)) {
    invalid("must be a non-empty canonical JSON object")
  }
  parsed <- tryCatch(ledgr_json_read_nested(value), error = function(e) NULL)
  if (!is.list(parsed) || is.null(names(parsed)) || any(!nzchar(names(parsed)))) {
    invalid("must be a JSON object with named keys")
  }
  if (anyDuplicated(names(parsed))) {
    invalid("must not repeat a key")
  }
  missing <- setdiff(ledgr_snapshot_quarantine_required_row_keys(), names(parsed))
  if (length(missing) > 0L) {
    invalid(sprintf("is missing required bar key(s): %s", paste(missing, collapse = ", ")))
  }
  keep <- intersect(ledgr_snapshot_quarantine_hashed_row_keys(), names(parsed))
  as.character(canonical_json(parsed[keep]))
}

ledgr_snapshot_quarantine_hashed_row <- function(original_row_json) {
  vapply(
    original_row_json,
    ledgr_snapshot_quarantine_parse_hashed_row,
    character(1),
    USE.NAMES = FALSE
  )
}

ledgr_snapshot_availability_hash_payload <- function(con, snapshot_id) {
  tables <- ledgr_snapshot_availability_read(con, snapshot_id)

  quarantine <- tables$snapshot_observation_quarantine
  if (!is.null(quarantine) && nrow(quarantine) > 0L) {
    if ("original_row_json" %in% names(quarantine)) {
      quarantine$original_row_json <-
        ledgr_snapshot_quarantine_hashed_row(quarantine$original_row_json)
    }
    order_by <- intersect(
      c("supplied_instrument_id", "supplied_ts_utc", "reason",
        "original_row_json", "provenance_json"),
      names(quarantine)
    )
    if (length(order_by) > 0L) {
      quarantine <- quarantine[do.call(order, unname(quarantine[order_by])), , drop = FALSE]
      rownames(quarantine) <- NULL
    }
    keep <- setdiff(names(quarantine), "quarantine_id")
    tables$snapshot_observation_quarantine <- quarantine[, keep, drop = FALSE]
  }

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

ledgr_snapshot_membership_set_abort <- function(message) {
  rlang::abort(
    message,
    class = c("ledgr_snapshot_membership_set_invalid", "ledgr_invalid_state")
  )
}

ledgr_snapshot_membership_time_equal <- function(left, right) {
  left <- as.numeric(left)
  right <- as.numeric(right)
  (is.na(left) & is.na(right)) |
    (!is.na(left) & !is.na(right) & left == right)
}

ledgr_snapshot_membership_sweep_rows <- function(membership,
                                                 membership_sets) {
  if (nrow(membership) == 0L) return(membership)
  set_rows <- !is.na(membership$set_id)
  if (!any(set_rows)) return(membership)

  if (any(!nzchar(membership$set_id[set_rows]))) {
    ledgr_snapshot_membership_set_abort(
      "Snapshot membership-set rows require a non-empty set identity."
    )
  }
  if (any(is.na(membership$member[set_rows]) |
      !membership$member[set_rows])) {
    ledgr_snapshot_membership_set_abort(
      "Snapshot membership-set rows must assert member = TRUE."
    )
  }
  if (nrow(membership_sets) == 0L ||
      anyNA(membership_sets$universe_id) ||
      anyNA(membership_sets$set_id) ||
      any(!nzchar(membership_sets$universe_id)) ||
      any(!nzchar(membership_sets$set_id)) ||
      anyNA(membership_sets$complete)) {
    ledgr_snapshot_membership_set_abort(
      "Snapshot membership-set headers are malformed."
    )
  }
  identity_columns <- c("universe_id", "set_id")
  identity_rows <- rbind(
    membership_sets[, identity_columns, drop = FALSE],
    membership[set_rows, identity_columns, drop = FALSE]
  )
  identity_group <- ledgr_fact_scope_group(identity_rows, identity_columns)
  header_count <- nrow(membership_sets)
  header_group <- identity_group[seq_len(header_count)]
  row_group <- identity_group[header_count + seq_len(sum(set_rows))]
  if (anyDuplicated(header_group)) {
    ledgr_snapshot_membership_set_abort(
      "Snapshot membership-set header identity is duplicated."
    )
  }
  header_index <- match(row_group, header_group)
  if (anyNA(header_index)) {
    rlang::abort(
      "Snapshot membership rows reference a missing membership-set header.",
      class = c("ledgr_snapshot_membership_set_missing", "ledgr_invalid_state")
    )
  }
  if (!all(ledgr_snapshot_membership_time_equal(
    membership$effective_from[set_rows],
    membership_sets$effective_from[header_index]
  ))) {
    ledgr_snapshot_membership_set_abort(
      "Snapshot membership-set rows do not match their header effective time."
    )
  }
  if (any(!is.na(membership$effective_to[set_rows]))) {
    ledgr_snapshot_membership_set_abort(
      "Snapshot membership-set rows must have an open effective interval."
    )
  }
  if (!all(ledgr_snapshot_membership_time_equal(
    membership$knowledge_time[set_rows],
    membership_sets$knowledge_time[header_index]
  ))) {
    ledgr_snapshot_membership_set_abort(
      "Snapshot membership-set rows do not match their header knowledge time."
    )
  }
  row_provenance <- as.character(membership$provenance_json[set_rows])
  header_provenance <- as.character(
    membership_sets$provenance_json[header_index]
  )
  if (anyNA(row_provenance) || anyNA(header_provenance) ||
      any(row_provenance != header_provenance)) {
    ledgr_snapshot_membership_set_abort(
      "Snapshot membership-set rows do not match their header provenance."
    )
  }
  member_columns <- c(identity_columns, "instrument_id")
  member_group <- ledgr_fact_scope_group(
    membership[set_rows, member_columns, drop = FALSE],
    member_columns
  )
  if (anyDuplicated(member_group)) {
    ledgr_snapshot_membership_set_abort(
      "Snapshot membership-set rows contain a duplicate member identity."
    )
  }

  interval_rows <- !set_rows
  if (!any(interval_rows)) return(membership[0, , drop = FALSE])
  scope <- ledgr_fact_scope_group(
    membership,
    c("instrument_id", "universe_id")
  )
  shared_scope <- set_rows & scope %in% scope[interval_rows]
  membership[interval_rows | shared_scope, , drop = FALSE]
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
  valid_families <- c(
    "membership", "trading_status", "lifetime",
    "equity_corporate_actions", "sessions", "observation_quarantine"
  )
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
    snapshot_equity_corporate_actions = "provenance_json",
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

  # Valid canonical JSON is not enough for a quarantined row's saved copy. The
  # hash covers its canonical bar keys and nothing else, so a scalar or an
  # object missing those keys would seal and verify with the row's values
  # absent from identity. Reject the shape here, at the seal boundary, rather
  # than only where the hash is computed. Close review W9-F8.
  quarantine_rows <- data$snapshot_observation_quarantine
  if (!is.null(quarantine_rows) && nrow(quarantine_rows) > 0L &&
      "original_row_json" %in% names(quarantine_rows)) {
    invisible(lapply(
      quarantine_rows$original_row_json,
      ledgr_snapshot_quarantine_parse_hashed_row
    ))
  }

  required_headers <- list(
    membership = unique(c(
      data$snapshot_membership$universe_id,
      data$snapshot_membership_sets$universe_id
    )),
    trading_status = if (nrow(data$snapshot_trading_status) > 0L) "instrument" else character(),
    lifetime = if (nrow(data$snapshot_lifetime) > 0L) "instrument" else character(),
    equity_corporate_actions = if (
      nrow(data$snapshot_equity_corporate_actions) > 0L
    ) "equity" else character(),
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
  corporate_actions <- data$snapshot_equity_corporate_actions
  if (nrow(corporate_actions) > 0L) {
    parent_unknown <- !corporate_actions$parent_instrument_id %in% known
    recipient_unknown <- !is.na(corporate_actions$recipient_instrument_id) &
      !corporate_actions$recipient_instrument_id %in% known
    if (any(parent_unknown) || any(recipient_unknown)) {
      rlang::abort(
        paste(
          "snapshot_equity_corporate_actions references an instrument",
          "absent from the snapshot master."
        ),
        class = c(
          "ledgr_snapshot_fact_referential_integrity",
          "ledgr_invalid_state"
        )
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
    snapshot_equity_corporate_actions = c(
      "entitlement_time", "effective_time", "knowledge_time", "payment_time"
    ),
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
    membership <- ledgr_snapshot_membership_sweep_rows(
      membership,
      membership_sets
    )
    ledgr_fact_validate_membership_conflicts(membership)
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
  if (nrow(corporate_actions) > 0L) {
    ledgr_validate_equity_corporate_action_rows(
      corporate_actions,
      state = TRUE
    )
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
