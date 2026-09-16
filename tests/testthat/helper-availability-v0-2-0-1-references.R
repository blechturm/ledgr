# Test-owned v0.2.0.0 references retained for the v0.2.0.1 optimization
# packet. These functions deliberately live outside R/ so the optimized
# production path can be compared with the retired semantics without shipping
# a fallback execution path.

availability_reference_intervals_overlap <- function(a_from,
                                                     a_to,
                                                     b_from,
                                                     b_to) {
  a_end <- if (is.na(a_to)) as.POSIXct("9999-12-31", tz = "UTC") else a_to
  b_end <- if (is.na(b_to)) as.POSIXct("9999-12-31", tz = "UTC") else b_to
  a_from < b_end && b_from < a_end
}

availability_reference_validate_status_conflicts <- function(rows) {
  if (nrow(rows) < 2L) return(invisible(TRUE))
  for (i in seq_len(nrow(rows) - 1L)) {
    for (j in seq.int(i + 1L, nrow(rows))) {
      same_scope <- identical(rows$instrument_id[[i]], rows$instrument_id[[j]]) &&
        identical(rows$source[[i]], rows$source[[j]]) &&
        identical(rows$precedence[[i]], rows$precedence[[j]])
      superseded_pair <-
        identical(rows$supersedes_fact_id[[i]], rows$fact_id[[j]]) ||
        identical(rows$supersedes_fact_id[[j]], rows$fact_id[[i]])
      if (
        same_scope &&
          !superseded_pair &&
          !identical(rows$status[[i]], rows$status[[j]]) &&
          availability_reference_intervals_overlap(
            rows$effective_from[[i]],
            rows$effective_to[[i]],
            rows$effective_from[[j]],
            rows$effective_to[[j]]
          )
      ) {
        rlang::abort(
          paste(
            "One trading-status source cannot assert conflicting tied",
            "statuses over the same interval."
          ),
          class = c("ledgr_fact_structural_conflict", "ledgr_invalid_args")
        )
      }
    }
  }
  invisible(TRUE)
}

availability_reference_validate_membership_conflicts <- function(rows) {
  if (nrow(rows) < 2L) return(invisible(TRUE))
  for (i in seq_len(nrow(rows) - 1L)) {
    for (j in seq.int(i + 1L, nrow(rows))) {
      same_scope <- identical(rows$instrument_id[[i]], rows$instrument_id[[j]]) &&
        identical(rows$universe_id[[i]], rows$universe_id[[j]])
      if (
        same_scope &&
          !identical(rows$member[[i]], rows$member[[j]]) &&
          availability_reference_intervals_overlap(
            rows$effective_from[[i]],
            rows$effective_to[[i]],
            rows$effective_from[[j]],
            rows$effective_to[[j]]
          )
      ) {
        rlang::abort(
          "Membership facts cannot assert incompatible overlapping states.",
          class = c("ledgr_fact_structural_conflict", "ledgr_invalid_args")
        )
      }
    }
  }
  invisible(TRUE)
}

availability_reference_validate_lifetime_conflicts <- function(rows) {
  if (nrow(rows) < 2L) return(invisible(TRUE))
  for (i in seq_len(nrow(rows) - 1L)) {
    for (j in seq.int(i + 1L, nrow(rows))) {
      same_scope <- identical(rows$instrument_id[[i]], rows$instrument_id[[j]])
      if (
        same_scope &&
          !identical(rows$assertion[[i]], rows$assertion[[j]]) &&
          availability_reference_intervals_overlap(
            rows$effective_from[[i]],
            rows$effective_to[[i]],
            rows$effective_from[[j]],
            rows$effective_to[[j]]
          )
      ) {
        rlang::abort(
          "Lifetime facts cannot assert incompatible overlapping states.",
          class = c("ledgr_fact_structural_conflict", "ledgr_invalid_args")
        )
      }
    }
  }
  invisible(TRUE)
}

availability_reference_applicable <- function(rows, cutoff) {
  if (nrow(rows) == 0L) return(logical())
  effective <- !is.na(rows$effective_from) & rows$effective_from <= cutoff
  knowable <- !is.na(rows$knowledge_time) & rows$knowledge_time <= cutoff
  before_end <- is.na(rows$effective_to) | cutoff < rows$effective_to
  effective & knowable & before_end
}

availability_reference_members_at <- function(data,
                                              universe_rule,
                                              fixed_ids,
                                              cutoff) {
  if (is.null(universe_rule)) return(as.character(fixed_ids))
  ledgr:::ledgr_membership_resolve_at(
    data,
    universe_id = as.character(universe_rule$universe_id),
    cutoff = cutoff
  )$members
}

availability_reference_status_at <- function(rows, ids, cutoff) {
  out <- stats::setNames(rep("active", length(ids)), ids)
  if (nrow(rows) == 0L || length(ids) == 0L) return(out)
  for (id in ids) {
    current <- rows[rows$instrument_id == id, , drop = FALSE]
    current <- current[
      availability_reference_applicable(current, cutoff),
      ,
      drop = FALSE
    ]
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

availability_reference_lifetime_at <- function(rows, ids, cutoff) {
  out <- stats::setNames(rep("unknown", length(ids)), ids)
  if (nrow(rows) == 0L || length(ids) == 0L) return(out)
  for (id in ids) {
    current <- rows[rows$instrument_id == id, , drop = FALSE]
    current <- current[
      availability_reference_applicable(current, cutoff),
      ,
      drop = FALSE
    ]
    if (nrow(current) > 0L) {
      current <- current[
        order(current$effective_from, current$knowledge_time),
        ,
        drop = FALSE
      ]
      out[[id]] <- as.character(current$assertion[[nrow(current)]])
    }
  }
  out
}

availability_reference_terminal_event_at <- function(rows, ids, cutoff) {
  out <- stats::setNames(rep("", length(ids)), ids)
  if (nrow(rows) == 0L || length(ids) == 0L) return(out)
  for (id in ids) {
    current <- rows[rows$instrument_id == id, , drop = FALSE]
    current <- current[
      availability_reference_applicable(current, cutoff),
      ,
      drop = FALSE
    ]
    if (nrow(current) > 0L) {
      current <- current[
        order(current$effective_from, current$knowledge_time),
        ,
        drop = FALSE
      ]
      value <- as.character(current$terminal_event[[nrow(current)]])
      if (!is.na(value) && nzchar(value)) out[[id]] <- value
    }
  }
  out
}

availability_reference_provider_build_current <- function(data,
                                                          config,
                                                          snapshot_hash,
                                                          history) {
  family_order <- c("membership", "sessions", "trading_status", "lifetime")
  families <- family_order[
    family_order %in% as.character(data$families$family)
  ]
  universe_rule <- config$availability$universe_rule
  if (!is.null(universe_rule)) {
    class(universe_rule) <- c("ledgr_universe_rule", "list")
  }

  facts <- function(cutoff, ids = config$universe$instrument_ids) {
    cutoff <- as.POSIXct(cutoff, tz = "UTC")
    list(
      status = availability_reference_status_at(data$status, ids, cutoff),
      lifetime = availability_reference_lifetime_at(
        data$lifetime,
        ids,
        cutoff
      ),
      terminal_event = availability_reference_terminal_event_at(
        data$lifetime,
        ids,
        cutoff
      ),
      cutoff = cutoff
    )
  }

  decision_view <- function(cutoff, positions) {
    cutoff <- as.POSIXct(cutoff, tz = "UTC")
    members <- availability_reference_members_at(
      data,
      universe_rule,
      config$universe$instrument_ids,
      cutoff
    )
    held <- names(positions)[as.numeric(positions) != 0]
    held_nonmembers <- ledgr:::ledgr_availability_stable_ids(
      setdiff(held, members)
    )
    axis <- unique(c(members, held_nonmembers))
    resolved <- facts(cutoff, axis)
    restrictions <- ledgr:::ledgr_availability_restrictions(
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
      target_restriction_reasons = restrictions$reasons,
      status = resolved$status,
      lifetime = resolved$lifetime,
      terminal_event = resolved$terminal_event
    )
  }

  execution_view <- function(cutoff, ids) {
    resolved <- facts(cutoff, ids)
    members <- availability_reference_members_at(
      data,
      universe_rule,
      config$universe$instrument_ids,
      as.POSIXct(cutoff, tz = "UTC")
    )
    restrictions <- ledgr:::ledgr_availability_restrictions(
      resolved$status,
      resolved$lifetime,
      "trading_status" %in% families,
      "lifetime" %in% families
    )
    c(
      resolved,
      list(member = stats::setNames(ids %in% members, ids)),
      restrictions
    )
  }

  identity <- function() {
    list(
      provider_version = ledgr:::ledgr_availability_provider_version(),
      execution_timing_version =
        config$availability$execution_timing_version %||% NULL,
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
      sessions = data$sessions,
      valuation_policy = config$availability$valuation_policy
    ),
    class = c("ledgr_availability_provider", "list")
  )
}

availability_reference_diagnostic_fields <- function(
    run_id,
    diagnostic_seq,
    ts_utc,
    instrument_id = "",
    stage,
    outcome,
    reason_code = "",
    reasons = reason_code,
    target = NA_real_,
    quantity = NA_real_,
    price = NA_real_,
    mark_source = "",
    mark_age = NA_integer_,
    decision_ts_utc = ts_utc,
    execution_ts_utc = as.POSIXct(NA, tz = "UTC"),
    event_seq = NA_integer_,
    target_before_risk = NA_real_,
    target_after_risk = NA_real_,
    position_before = NA_real_,
    position_after = NA_real_,
    feature_identity_json = NA_character_,
    detail_json = "{}") {
  list(
    run_id = as.character(run_id),
    diagnostic_seq = as.integer(diagnostic_seq),
    ts_utc = as.POSIXct(ts_utc, tz = "UTC"),
    instrument_id = as.character(instrument_id),
    stage = as.character(stage),
    outcome = as.character(outcome),
    reason_code = as.character(reason_code),
    reasons = as.character(reasons),
    target = as.numeric(target),
    quantity = as.numeric(quantity),
    price = as.numeric(price),
    mark_source = as.character(mark_source),
    mark_age = as.integer(mark_age),
    decision_ts_utc = as.POSIXct(decision_ts_utc, tz = "UTC"),
    execution_ts_utc = as.POSIXct(execution_ts_utc, tz = "UTC"),
    event_seq = as.integer(event_seq),
    target_before_risk = as.numeric(target_before_risk),
    target_after_risk = as.numeric(target_after_risk),
    position_before = as.numeric(position_before),
    position_after = as.numeric(position_after),
    feature_identity_json = as.character(feature_identity_json),
    detail_json = as.character(detail_json)
  )
}

availability_reference_row_list_writer <- function(run_id, pulses_posix) {
  diagnostic_rows <- list()
  append <- function(row, diagnostic_seq) {
    row$diagnostic_seq <- diagnostic_seq
    diagnostic_rows[[diagnostic_seq]] <<- row
    invisible(NULL)
  }
  drain <- function() {
    if (length(diagnostic_rows) == 0L) {
      return(ledgr:::ledgr_availability_diagnostic_row(
        run_id = run_id,
        diagnostic_seq = 1L,
        ts_utc = pulses_posix[[1L]],
        stage = "decision",
        outcome = "observed",
        reason_code = "no_diagnostics"
      )[0, , drop = FALSE])
    }
    do.call(rbind, diagnostic_rows)
  }
  list(
    mode = "rows",
    row = ledgr:::ledgr_availability_diagnostic_row,
    append = append,
    drain = drain
  )
}
