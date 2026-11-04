# One logical diagnostic read boundary. Physical residual rows and certified
# implicit clean pairs are unioned here; no consumer may infer omitted rows.
ledgr_diagnostic_add_in <- function(where, params, column, values) {
  if (is.null(values)) return(list(where = where, params = params))
  values <- as.character(values)
  if (length(values) == 0L) return(list(where = c(where, "FALSE"), params = params))
  list(
    where = c(where, sprintf("%s IN (%s)", column, paste(rep("?", length(values)), collapse = ", "))),
    params = c(params, as.list(values))
  )
}

ledgr_diagnostic_logical_sql <- function() {
  paste(
    "SELECT * FROM run_diagnostics",
    "UNION ALL SELECT run_id, decision_seq AS diagnostic_seq, ts_utc,",
    "instrument_id, 'decision' AS stage, 'recorded' AS outcome,",
    "'decision_recorded' AS reason_code, 'decision_recorded' AS reasons,",
    '"target", position_before AS quantity, decision_price AS price,',
    "decision_mark_source AS mark_source, decision_mark_age AS mark_age,",
    "ts_utc AS decision_ts_utc, NULL::TIMESTAMP AS execution_ts_utc,",
    "NULL::INTEGER AS event_seq, \"target\" AS target_before_risk,",
    '"target" AS target_after_risk, position_before,',
    "position_before AS position_after, NULL::VARCHAR AS feature_identity_json,",
    "'{}' AS detail_json FROM run_diagnostic_implicit",
    "UNION ALL SELECT run_id, execution_seq AS diagnostic_seq, ts_utc,",
    "instrument_id, 'execution' AS stage, 'filled' AS outcome,",
    "'' AS reason_code, '' AS reasons, \"target\",",
    "fill_quantity AS quantity, fill_price AS price, '' AS mark_source,",
    "NULL::INTEGER AS mark_age, ts_utc AS decision_ts_utc, execution_ts_utc,",
    "event_seq, \"target\" AS target_before_risk, \"target\" AS target_after_risk,",
    "position_before, position_after, NULL::VARCHAR AS feature_identity_json,",
    "'{}' AS detail_json FROM run_diagnostic_implicit WHERE execution_seq IS NOT NULL"
  )
}

ledgr_diagnostic_require_coverage <- function(con,
                                              run_ids,
                                              instrument_id = NULL,
                                              explain_ts_utc = NULL) {
  if (length(run_ids) == 0L) return(invisible(TRUE))
  marks <- paste(rep("?", length(run_ids)), collapse = ", ")
  coverage <- DBI::dbGetQuery(
    con,
    paste0("SELECT run_id, logical_count, codec_rule_version FROM run_diagnostic_coverage WHERE run_id IN (", marks, ")"),
    params = as.list(run_ids)
  )
  missing <- setdiff(run_ids, as.character(coverage$run_id))
  if (length(missing) > 0L) {
    missing_marks <- paste(rep("?", length(missing)), collapse = ", ")
    uninitialized <- DBI::dbGetQuery(
      con,
      paste0(
        "SELECT r.run_id FROM runs r WHERE r.run_id IN (", missing_marks,
        ") AND r.status = 'RUNNING' AND NOT EXISTS ",
        "(SELECT 1 FROM run_diagnostics d WHERE d.run_id = r.run_id) AND NOT EXISTS ",
        "(SELECT 1 FROM run_diagnostic_implicit i WHERE i.run_id = r.run_id)"
      ),
      params = as.list(missing)
    )$run_id
    missing <- setdiff(missing, as.character(uninitialized))
  }
  if (length(missing) > 0L ||
      any(coverage$codec_rule_version != ledgr_diagnostic_codec_rule_version)) {
    rlang::abort("Diagnostic codec coverage is missing or uses an unsupported rule.",
                 class = "ledgr_diagnostic_corrupt")
  }
  counts <- DBI::dbGetQuery(
    con,
    paste0(
      "SELECT run_id, COUNT(*) AS n, COUNT(DISTINCT diagnostic_seq) AS distinct_n, ",
      "MIN(diagnostic_seq) AS first_seq, MAX(diagnostic_seq) AS last_seq FROM (",
      ledgr_diagnostic_logical_sql(), ") logical WHERE run_id IN (", marks,
      ") GROUP BY run_id"
    ),
    params = as.list(run_ids)
  )
  covered <- intersect(run_ids, as.character(coverage$run_id))
  expected <- as.integer(coverage$logical_count[match(covered, coverage$run_id)])
  row <- match(covered, as.character(counts$run_id))
  present <- !is.na(row)
  observed <- rep.int(NA_integer_, length(covered))
  distinct <- first <- last <- observed
  observed[present] <- as.integer(counts$n[row[present]])
  distinct[present] <- as.integer(counts$distinct_n[row[present]])
  first[present] <- as.integer(counts$first_seq[row[present]])
  last[present] <- as.integer(counts$last_seq[row[present]])
  ok <- (expected == 0L & !present) |
    (expected > 0L & present & observed == expected & distinct == expected &
       first == 1L & last == expected)
  if (any(!ok)) {
    rlang::abort(
      sprintf(
        "Diagnostic codec coverage is corrupt for run `%s`.",
        covered[which(!ok)[[1L]]]
      ),
      class = "ledgr_diagnostic_corrupt"
    )
  }
  association_where <- ""
  association_params <- as.list(run_ids)
  if (!is.null(instrument_id)) {
    association_where <- paste0(association_where, " AND i.instrument_id = ?")
    association_params <- c(association_params, list(as.character(instrument_id)))
  }
  if (!is.null(explain_ts_utc)) {
    association_where <- paste0(association_where, " AND i.ts_utc = ?")
    association_params <- c(
      association_params,
      list(as.POSIXct(explain_ts_utc, tz = "UTC"))
    )
  }
  association <- DBI::dbGetQuery(
    con,
    paste0(
      "SELECT COUNT(*) AS bad FROM run_diagnostic_implicit i ",
      "JOIN runs r ON r.run_id = i.run_id ",
      "LEFT JOIN snapshot_bars b ON b.snapshot_id = r.snapshot_id ",
      "AND b.instrument_id = i.instrument_id AND b.ts_utc = i.ts_utc ",
      "LEFT JOIN ledger_events e ON e.run_id = i.run_id AND e.event_seq = i.event_seq ",
      "WHERE i.run_id IN (", marks, ")", association_where, " AND (",
      "i.decision_mark_source <> 'current_close' OR i.decision_mark_age <> 0 OR ",
      "b.ts_utc IS NULL OR b.close IS DISTINCT FROM i.decision_price OR ",
      "(i.execution_seq IS NOT NULL AND (",
      "e.event_seq IS NULL OR e.event_type <> 'FILL' OR ",
      "e.instrument_id IS DISTINCT FROM i.instrument_id OR ",
      "e.ts_utc IS DISTINCT FROM i.execution_ts_utc OR ",
      "e.qty IS DISTINCT FROM i.fill_quantity OR ",
      "e.price IS DISTINCT FROM i.fill_price OR ",
      "i.position_after IS DISTINCT FROM (i.position_before + e.position_delta) OR ",
      "i.target IS DISTINCT FROM i.position_after OR ",
      "i.decision_seq >= i.execution_seq)) OR ",
      "(i.execution_seq IS NULL AND (i.target IS DISTINCT FROM i.position_before OR ",
      "i.position_after IS DISTINCT FROM i.position_before)))"
    ),
    params = association_params
  )$bad[[1L]]
  if (association != 0L) {
    rlang::abort("Diagnostic codec association evidence is corrupt.",
                 class = "ledgr_diagnostic_corrupt")
  }
  invisible(TRUE)
}

ledgr_diagnostic_decode <- function(con, run_ids, stage = NULL, outcome = NULL,
                                    reason_code = NULL, mark_source = NULL,
                                    instrument_id = NULL, explain_ts_utc = NULL,
                                    include_strategy_intent = FALSE) {
  run_ids <- unique(as.character(run_ids))
  ledgr_diagnostic_require_coverage(
    con,
    run_ids,
    instrument_id = instrument_id,
    explain_ts_utc = explain_ts_utc
  )
  where <- character()
  params <- list()
  add <- function(column, values) {
    result <- ledgr_diagnostic_add_in(where, params, column, values)
    where <<- result$where
    params <<- result$params
  }
  add("run_id", run_ids); add("stage", stage); add("outcome", outcome)
  add("reason_code", reason_code); add("mark_source", mark_source)
  if (!is.null(instrument_id)) {
    if (length(instrument_id) != 1L || is.na(instrument_id)) {
      rlang::abort("`instrument_id` must be one non-missing value.", class = "ledgr_internal_error")
    }
    if (isTRUE(include_strategy_intent)) {
      where <- c(where, paste(
        "((instrument_id = ? AND stage IN ('decision', 'execution'))",
        "OR (instrument_id = '' AND stage = 'decision'",
        "AND reason_code = 'strategy_intent'))"
      ))
    } else {
      where <- c(where, "instrument_id = ?", "stage IN ('decision', 'execution')")
    }
    params <- c(params, list(as.character(instrument_id)))
  }
  if (!is.null(explain_ts_utc)) {
    if (length(explain_ts_utc) != 1L || is.na(explain_ts_utc)) {
      rlang::abort("`explain_ts_utc` must be one non-missing time.", class = "ledgr_internal_error")
    }
    where <- c(where, "((stage = 'decision' AND ts_utc = ?) OR (stage = 'execution' AND decision_ts_utc = ?))")
    time <- as.POSIXct(explain_ts_utc, tz = "UTC")
    params <- c(params, list(time, time))
  }
  order <- if (length(run_ids) > 1L) "run_id, diagnostic_seq" else "diagnostic_seq"
  rows <- DBI::dbGetQuery(
    con,
    paste(
      "SELECT * FROM (", ledgr_diagnostic_logical_sql(), ") logical",
      if (length(where) > 0L) paste("WHERE", paste(where, collapse = " AND ")) else "",
      paste("ORDER BY", order)
    ),
    params = params
  )
  absent_sizing_reason <- rows$stage == "sizing" & !nzchar(rows$reasons)
  rows$reasons[absent_sizing_reason] <- NA_character_
  tibble::as_tibble(rows)
}

ledgr_diagnostic_next_seq <- function(con, run_id) {
  row <- DBI::dbGetQuery(con,
    "SELECT logical_count FROM run_diagnostic_coverage WHERE run_id = ?",
    params = list(run_id))
  if (nrow(row) == 0L) 1L else as.integer(row$logical_count[[1L]]) + 1L
}

ledgr_diagnostic_present <- function(con, run_id, stage = NULL, outcome = NULL, reason_code = NULL) {
  nrow(ledgr_diagnostic_decode(con, run_id, stage = stage, outcome = outcome,
                              reason_code = reason_code)) > 0L
}

ledgr_diagnostic_flag_counts <- function(con, run_ids) {
  run_ids <- unique(as.character(run_ids))
  if (length(run_ids) == 0L) {
    return(data.frame(run_id = character(), decisions = integer(), stale = integer(),
                      frozen = integer(), assumed = integer(), stringsAsFactors = FALSE))
  }
  ledgr_diagnostic_require_coverage(con, run_ids)
  rows <- ledgr_diagnostic_summary_read(con, run_ids)
  rows[c("run_id", "decisions", "stale", "frozen", "assumed")]
}
