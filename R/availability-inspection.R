#' Inspect point-in-time fact evidence
#'
#' `ledgr_facts_history()` returns supplied assertions retrospectively.
#' `ledgr_facts_resolve()` returns only the state supported at one decision
#' cutoff. Both functions accept an in-memory fact family or bundle, or a
#' sealed snapshot. Results are eager and read-only.
#'
#' @param facts A fact-family object, a `ledgr_facts` bundle, or a sealed
#'   `ledgr_snapshot`.
#' @param family Either `"membership"` or `"sessions"`.
#' @param scope_id The membership universe or session venue identifier.
#' @param instruments Optional instrument identifiers. Valid only for
#'   membership. History filters assertions; resolution retains each distinct
#'   requested identifier, including false and unknown states.
#' @param from,to Optional history bounds. Membership bounds are full UTC
#'   instants interpreted as `[from, to)`. Session bounds are inclusive civil
#'   dates.
#' @param at One full UTC cutoff for resolution. Bare dates are rejected.
#' @param x A `ledgr_facts_history` or `ledgr_facts_resolution` result.
#' @param ... Unused.
#'
#' @return A classed list with eager tibble `rows` and `evidence` members plus
#'   serializable `metadata`.
#' @section Information boundary:
#' History may include future-effective, future-known, and audit-only evidence.
#' Resolution excludes evidence not yet effective and knowable at `at`.
#' Neither result is a strategy context or a selection surface.
#' @section Errors:
#' Invalid argument combinations raise `ledgr_facts_inspection_invalid_args`.
#' Missing scopes raise `ledgr_facts_scope_not_found`. Snapshot inputs must be
#' sealed and hash-valid on every call.
#' @name ledgr_facts_inspection
NULL

#' @rdname ledgr_facts_inspection
#' @export
ledgr_facts_history <- function(facts,
                                family,
                                scope_id,
                                instruments = NULL,
                                from = NULL,
                                to = NULL) {
  family <- ledgr_facts_inspection_family(family)
  scope_id <- ledgr_fact_scalar_id(scope_id, "scope_id")
  source <- ledgr_facts_inspection_source(facts)
  family_row <- ledgr_facts_inspection_scope(source, family, scope_id)
  instruments <- ledgr_facts_inspection_instruments(instruments, family)

  if (identical(family, "membership")) {
    bounds <- ledgr_facts_history_time_bounds(from, to)
    full <- ledgr_membership_evidence(source$data, scope_id)
    selected <- ledgr_membership_history_select(full, instruments, bounds$from, bounds$to)
    rows <- selected[, setdiff(names(selected), "provenance_json"), drop = FALSE]
    range_metadata <- list(from = bounds$from_label, to = bounds$to_label)
  } else {
    bounds <- ledgr_facts_history_date_bounds(from, to, family_row$metadata)
    selected <- source$data$sessions[
      source$data$sessions$venue_id == scope_id &
        source$data$sessions$session_date >= bounds$from &
        source$data$sessions$session_date <= bounds$to,
      ,
      drop = FALSE
    ]
    selected <- ledgr_session_evidence(selected)
    rows <- selected[, setdiff(names(selected), "provenance_json"), drop = FALSE]
    range_metadata <- list(from = as.character(bounds$from), to = as.character(bounds$to))
  }

  ledgr_facts_inspection_result(
    class = "ledgr_facts_history",
    rows = rows,
    evidence = selected,
    metadata = c(
      list(
        operation = "history",
        family = family,
        scope_id = scope_id,
        normalization_version = 1L,
        knowledge = family_row$metadata$knowledge %||% NA_character_
      ),
      range_metadata,
      source$metadata
    )
  )
}

#' @rdname ledgr_facts_inspection
#' @export
ledgr_facts_resolve <- function(facts,
                                family,
                                scope_id,
                                at,
                                instruments = NULL) {
  family <- ledgr_facts_inspection_family(family)
  scope_id <- ledgr_fact_scalar_id(scope_id, "scope_id")
  at <- ledgr_facts_inspection_cutoff(at, "at")
  source <- ledgr_facts_inspection_source(facts)
  family_row <- ledgr_facts_inspection_scope(source, family, scope_id)
  instruments <- ledgr_facts_inspection_instruments(instruments, family)

  if (identical(family, "membership")) {
    resolved <- ledgr_membership_resolve_at(
      source$data,
      universe_id = scope_id,
      cutoff = at,
      instruments = instruments
    )
    rows <- resolved$rows
    all_evidence <- ledgr_membership_evidence(source$data, scope_id)
    evidence_ids <- unique(unlist(strsplit(rows$evidence_ids[nzchar(rows$evidence_ids)], "\\|")))
    evidence <- all_evidence[all_evidence$evidence_id %in% evidence_ids, , drop = FALSE]
  } else {
    resolved <- ledgr_session_resolve_at(
      source$data$sessions,
      scope_id,
      at,
      family_row$metadata
    )
    rows <- resolved$rows
    evidence <- resolved$evidence
  }

  ledgr_facts_inspection_result(
    class = "ledgr_facts_resolution",
    rows = rows,
    evidence = evidence,
    metadata = c(
      list(
        operation = "resolve",
        family = family,
        scope_id = scope_id,
        at = ledgr_fact_time_token(at),
        normalization_version = 1L,
        knowledge = family_row$metadata$knowledge %||% NA_character_
      ),
      source$metadata
    )
  )
}

#' @rdname ledgr_facts_inspection
#' @export
print.ledgr_facts_history <- function(x, ...) {
  cat("ledgr facts history\n")
  cat("Family: ", x$metadata$family, " [", x$metadata$scope_id, "]\n", sep = "")
  cat("Rows:   ", nrow(x$rows), "\n", sep = "")
  print(utils::head(x$rows, 10L))
  if (nrow(x$rows) > 10L) cat("# ... with ", nrow(x$rows) - 10L, " more row(s)\n", sep = "")
  invisible(x)
}

#' @rdname ledgr_facts_inspection
#' @export
print.ledgr_facts_resolution <- function(x, ...) {
  cat("ledgr facts resolution\n")
  cat("Family: ", x$metadata$family, " [", x$metadata$scope_id, "]\n", sep = "")
  cat("At:     ", x$metadata$at, "\n", sep = "")
  print(x$rows)
  invisible(x)
}

ledgr_facts_inspection_result <- function(class, rows, evidence, metadata) {
  structure(
    list(
      schema_version = 1L,
      rows = tibble::as_tibble(rows),
      evidence = tibble::as_tibble(evidence),
      metadata = metadata
    ),
    class = c(class, "list")
  )
}

ledgr_facts_inspection_family <- function(family) {
  allowed <- c("membership", "sessions")
  if (!is.character(family) || length(family) != 1L || is.na(family) ||
      !family %in% allowed) {
    rlang::abort(
      sprintf("`family` must be one of: %s.", paste(allowed, collapse = ", ")),
      class = c("ledgr_facts_inspection_invalid_args", "ledgr_invalid_args")
    )
  }
  family
}

ledgr_facts_inspection_instruments <- function(instruments, family) {
  if (is.null(instruments)) return(NULL)
  if (!identical(family, "membership")) {
    rlang::abort(
      "`instruments` is valid only for membership facts.",
      class = c("ledgr_facts_inspection_invalid_args", "ledgr_invalid_args")
    )
  }
  if (!is.character(instruments) || length(instruments) == 0L) {
    rlang::abort(
      "`instruments` must be NULL or a non-empty character vector.",
      class = c("ledgr_facts_inspection_invalid_args", "ledgr_invalid_args")
    )
  }
  ids <- ledgr_fact_instrument_ids(instruments, allow_missing = FALSE)
  unique(ids)
}

ledgr_facts_inspection_source <- function(x) {
  if (inherits(x, "ledgr_fact_family")) x <- ledgr_facts(x)
  if (inherits(x, "ledgr_facts")) {
    x <- ledgr_facts_assert(x)
    return(list(
      data = ledgr_facts_inspection_data(x),
      metadata = list(source = "facts", bundle_hash = x$bundle_hash)
    ))
  }
  if (!inherits(x, "ledgr_snapshot")) {
    rlang::abort(
      "`facts` must be a fact family, facts bundle, or sealed snapshot.",
      class = c("ledgr_facts_inspection_invalid_args", "ledgr_invalid_args")
    )
  }
  opened <- ledgr_snapshot_connection(x)
  if (isTRUE(opened$opened_new)) on.exit(ledgr_snapshot_close(x), add = TRUE)
  info <- ledgr_snapshot_info(opened$con, x$snapshot_id)
  if (!identical(info$status[[1L]], "SEALED")) {
    rlang::abort(
      "Facts inspection requires a SEALED snapshot.",
      class = c("ledgr_facts_snapshot_not_sealed", "LEDGR_SNAPSHOT_NOT_SEALED")
    )
  }
  stored_hash <- info$snapshot_hash[[1L]]
  computed_hash <- ledgr_snapshot_hash(opened$con, x$snapshot_id)
  if (is.na(stored_hash) || !nzchar(stored_hash) || !identical(stored_hash, computed_hash)) {
    rlang::abort(
      "Snapshot hash mismatch; facts inspection refuses corrupted evidence.",
      class = c("ledgr_facts_snapshot_hash_mismatch", "ledgr_invalid_snapshot")
    )
  }
  data <- ledgr_availability_provider_data(opened$con, x$snapshot_id)
  data$families <- DBI::dbGetQuery(
    opened$con,
    paste(
      "SELECT family, scope_id, family_schema_version, metadata_json",
      "FROM snapshot_fact_families WHERE snapshot_id = ?",
      "ORDER BY family, scope_id"
    ),
    params = list(x$snapshot_id)
  )
  list(
    data = data,
    metadata = list(
      source = "snapshot",
      snapshot_id = x$snapshot_id,
      snapshot_hash = stored_hash,
      snapshot_hash_rule_version = ledgr_snapshot_hash_rule_version(opened$con, x$snapshot_id)
    )
  )
}

ledgr_facts_inspection_data <- function(facts) {
  data <- list(
    families = data.frame(
      family = character(), scope_id = character(), family_schema_version = integer(),
      metadata_json = character(), stringsAsFactors = FALSE
    ),
    membership_sets = ledgr_empty_membership_sets(),
    membership = ledgr_empty_membership_rows(),
    status = data.frame(),
    lifetime = data.frame(),
    sessions = ledgr_empty_session_rows()
  )
  for (family in facts$families) {
    data$families <- rbind(data$families, data.frame(
      family = family$family,
      scope_id = family$scope_id,
      family_schema_version = family$schema_version,
      metadata_json = as.character(canonical_json(family$metadata)),
      stringsAsFactors = FALSE
    ))
    if (identical(family$family, "membership")) {
      data$membership_sets <- rbind(data$membership_sets, family$headers)
      data$membership <- rbind(data$membership, family$rows)
    } else if (identical(family$family, "sessions")) {
      data$sessions <- rbind(data$sessions, family$rows)
    } else if (identical(family$family, "trading_status")) {
      data$status <- if (nrow(data$status) == 0L) family$rows else rbind(data$status, family$rows)
    } else if (identical(family$family, "lifetime")) {
      data$lifetime <- if (nrow(data$lifetime) == 0L) {
        family$rows
      } else {
        rbind(data$lifetime, family$rows)
      }
    }
  }
  data
}

ledgr_facts_inspection_scope <- function(source, family, scope_id) {
  row <- source$data$families[
    source$data$families$family == family & source$data$families$scope_id == scope_id,
    ,
    drop = FALSE
  ]
  if (nrow(row) != 1L) {
    rlang::abort(
      sprintf("Fact family '%s' does not declare scope '%s'.", family, scope_id),
      class = c("ledgr_facts_scope_not_found", "ledgr_invalid_args"),
      family = family,
      scope_id = scope_id
    )
  }
  list(row = row, metadata = ledgr_json_read_nested(row$metadata_json[[1L]]))
}

ledgr_empty_membership_rows <- function() {
  data.frame(
    fact_id = character(), instrument_id = character(), universe_id = character(),
    set_id = character(), effective_from = as.POSIXct(character(), tz = "UTC"),
    effective_to = as.POSIXct(character(), tz = "UTC"),
    knowledge_time = as.POSIXct(character(), tz = "UTC"), member = logical(),
    provenance_json = character(), source = character(), stringsAsFactors = FALSE
  )
}

ledgr_empty_session_rows <- function() {
  data.frame(
    venue_id = character(), session_date = as.Date(character()),
    effective_from = as.POSIXct(character(), tz = "UTC"),
    effective_to = as.POSIXct(character(), tz = "UTC"),
    knowledge_time = as.POSIXct(character(), tz = "UTC"), status = character(),
    session_open = as.POSIXct(character(), tz = "UTC"),
    session_close = as.POSIXct(character(), tz = "UTC"),
    provenance_json = character(), source = character(), stringsAsFactors = FALSE
  )
}

ledgr_membership_evidence <- function(data, scope_id) {
  headers <- data$membership_sets[data$membership_sets$universe_id == scope_id, , drop = FALSE]
  rows <- data$membership[data$membership$universe_id == scope_id, , drop = FALSE]
  header_evidence <- data.frame(
    evidence_type = rep("set_header", nrow(headers)),
    evidence_id = paste0(rep("set:", nrow(headers)), headers$set_id),
    instrument_id = rep(NA_character_, nrow(headers)),
    member = rep(NA, nrow(headers)),
    set_id = headers$set_id,
    effective_from = headers$effective_from,
    effective_to = as.POSIXct(rep(NA_real_, nrow(headers)), origin = "1970-01-01", tz = "UTC"),
    knowledge_time = headers$knowledge_time,
    complete = headers$complete,
    source = ledgr_fact_evidence_source(headers),
    provenance_json = headers$provenance_json,
    stringsAsFactors = FALSE
  )
  row_evidence <- data.frame(
    evidence_type = rep("membership_assertion", nrow(rows)),
    evidence_id = paste0(rep("fact:", nrow(rows)), rows$fact_id),
    instrument_id = rows$instrument_id,
    member = rows$member,
    set_id = rows$set_id,
    effective_from = rows$effective_from,
    effective_to = rows$effective_to,
    knowledge_time = rows$knowledge_time,
    complete = rep(NA, nrow(rows)),
    source = ledgr_fact_evidence_source(rows),
    provenance_json = rows$provenance_json,
    stringsAsFactors = FALSE
  )
  out <- rbind(header_evidence, row_evidence)
  out <- out[
    order(out$effective_from, out$knowledge_time, out$evidence_id, na.last = TRUE),
    ,
    drop = FALSE
  ]
  rownames(out) <- NULL
  out
}

ledgr_membership_history_select <- function(evidence, instruments, from, to) {
  keep <- rep(TRUE, nrow(evidence))
  if (!is.null(to)) keep <- keep & evidence$effective_from < to
  if (!is.null(from)) {
    is_header <- evidence$evidence_type == "set_header"
    is_set_row <- !is_header & !is.na(evidence$set_id)
    is_interval <- !is_header & is.na(evidence$set_id)
    overlaps <- is_interval & (is.na(evidence$effective_to) | evidence$effective_to > from)
    keep <- keep & (evidence$effective_from >= from | overlaps)
    headers_before <- which(
      is_header & evidence$effective_from < from &
        (is.null(to) | evidence$effective_from < to)
    )
    if (length(headers_before) > 0L) {
      ordered <- headers_before[order(
        evidence$effective_from[headers_before],
        evidence$knowledge_time[headers_before],
        evidence$evidence_id[headers_before],
        na.last = TRUE
      )]
      complete <- ordered[evidence$complete[ordered] %in% TRUE]
      anchor <- if (length(complete) > 0L) utils::tail(complete, 1L) else ordered[[1L]]
      context_headers <- ordered[match(anchor, ordered):length(ordered)]
      context_sets <- evidence$set_id[context_headers]
      keep[context_headers] <- TRUE
      keep[is_set_row & evidence$set_id %in% context_sets] <- TRUE
    }
  }
  if (!is.null(instruments)) {
    keep <- keep & (
      evidence$evidence_type == "set_header" |
        (!is.na(evidence$instrument_id) & evidence$instrument_id %in% instruments)
    )
  }
  evidence[keep, , drop = FALSE]
}

ledgr_session_evidence <- function(rows) {
  if (!"source" %in% names(rows)) rows$source <- ledgr_fact_evidence_source(rows)
  rows$evidence_type <- rep("session_assertion", nrow(rows))
  rows$evidence_id <- if (nrow(rows) == 0L) character() else {
    paste0("session:", rows$venue_id, ":", rows$session_date)
  }
  rows[, c(
    "evidence_type", "evidence_id", "venue_id", "session_date", "effective_from",
    "effective_to", "knowledge_time", "status", "session_open", "session_close",
    "source", "provenance_json"
  ), drop = FALSE]
}

ledgr_fact_evidence_source <- function(rows) {
  if ("source" %in% names(rows)) return(as.character(rows$source))
  vapply(rows$provenance_json, function(json) {
    parsed <- tryCatch(ledgr_json_read_nested(json), error = function(error) list())
    as.character(parsed$source %||% "")
  }, character(1))
}

ledgr_session_resolve_at <- function(rows, scope_id, at, metadata) {
  timezone <- metadata$timezone %||% "UTC"
  local_date <- as.Date(format(at, "%Y-%m-%d", tz = timezone))
  candidate <- rows[rows$venue_id == scope_id & rows$session_date == local_date, , drop = FALSE]
  evidence_id <- paste0("session:", scope_id, ":", local_date)
  if (nrow(candidate) == 0L) {
    result <- data.frame(
      venue_id = scope_id, session_date = local_date, status = NA_character_,
      session_open = as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC"),
      session_close = as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC"),
      reason = "missing_coverage", evidence_ids = "", stringsAsFactors = FALSE
    )
    return(list(rows = result, evidence = ledgr_session_evidence(candidate)))
  }
  usable <- !is.na(candidate$effective_from) & candidate$effective_from <= at &
    !is.na(candidate$knowledge_time) & candidate$knowledge_time <= at
  if (!any(usable)) {
    result <- data.frame(
      venue_id = scope_id, session_date = local_date, status = NA_character_,
      session_open = as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC"),
      session_close = as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC"),
      reason = "not_yet_knowable", evidence_ids = "", stringsAsFactors = FALSE
    )
    return(list(rows = result, evidence = ledgr_session_evidence(candidate[FALSE, , drop = FALSE])))
  }
  candidate <- candidate[which(usable)[[1L]], , drop = FALSE]
  result <- data.frame(
    venue_id = scope_id,
    session_date = local_date,
    status = as.character(candidate$status),
    session_open = as.POSIXct(candidate$session_open, tz = "UTC"),
    session_close = as.POSIXct(candidate$session_close, tz = "UTC"),
    reason = "session_asserted",
    evidence_ids = evidence_id,
    stringsAsFactors = FALSE
  )
  list(rows = result, evidence = ledgr_session_evidence(candidate))
}

ledgr_facts_inspection_cutoff <- function(x, arg) {
  if (inherits(x, "Date") && !inherits(x, "POSIXt")) {
    rlang::abort(
      sprintf("`%s` must be one full UTC instant, not a civil date.", arg),
      class = c("ledgr_facts_inspection_invalid_args", "ledgr_invalid_args")
    )
  }
  full_utc <- "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$"
  if (is.character(x) && (length(x) != 1L || !grepl(full_utc, x))) {
    rlang::abort(
      sprintf("`%s` must be one full UTC instant with a trailing Z.", arg),
      class = c("ledgr_facts_inspection_invalid_args", "ledgr_invalid_args")
    )
  }
  value <- ledgr_fact_time(x, arg, allow_missing = FALSE)
  if (length(value) != 1L) {
    rlang::abort(
      sprintf("`%s` must be one full UTC instant.", arg),
      class = c("ledgr_facts_inspection_invalid_args", "ledgr_invalid_args")
    )
  }
  value
}

ledgr_facts_history_time_bounds <- function(from, to) {
  from_value <- if (is.null(from)) NULL else ledgr_facts_inspection_cutoff(from, "from")
  to_value <- if (is.null(to)) NULL else ledgr_facts_inspection_cutoff(to, "to")
  if (!is.null(from_value) && !is.null(to_value) && to_value <= from_value) {
    rlang::abort(
      "Membership history requires `to > from`.",
      class = c("ledgr_facts_inspection_invalid_args", "ledgr_invalid_args")
    )
  }
  list(
    from = from_value,
    to = to_value,
    from_label = if (is.null(from_value)) NA_character_ else ledgr_fact_time_token(from_value),
    to_label = if (is.null(to_value)) NA_character_ else ledgr_fact_time_token(to_value)
  )
}

ledgr_facts_history_date_bounds <- function(from, to, metadata) {
  from_value <- if (is.null(from)) {
    as.Date(metadata$coverage_start)
  } else {
    ledgr_fact_date_scalar(from, "from")
  }
  to_value <- if (is.null(to)) as.Date(metadata$coverage_end) else ledgr_fact_date_scalar(to, "to")
  if (to_value < from_value) {
    rlang::abort(
      "Session history requires `to >= from`.",
      class = c("ledgr_facts_inspection_invalid_args", "ledgr_invalid_args")
    )
  }
  list(from = from_value, to = to_value)
}
