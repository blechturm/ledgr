# Logical diagnostic read boundary. LDG-3207 introduces this boundary while
# every logical row is still stored explicitly. The codec may change the
# physical representation, but readers must continue to call these functions.
ledgr_diagnostic_add_in <- function(where, params, column, values) {
  if (is.null(values)) return(list(where = where, params = params))
  values <- as.character(values)
  if (length(values) == 0L) return(list(where = c(where, "FALSE"), params = params))
  list(
    where = c(where, sprintf("%s IN (%s)", column, paste(rep("?", length(values)), collapse = ", "))),
    params = c(params, as.list(values))
  )
}

ledgr_diagnostic_decode <- function(con,
                                    run_ids,
                                    stage = NULL,
                                    outcome = NULL,
                                    reason_code = NULL,
                                    mark_source = NULL,
                                    instrument_id = NULL,
                                    explain_ts_utc = NULL,
                                    include_strategy_intent = FALSE) {
  run_ids <- unique(as.character(run_ids))
  where <- character()
  params <- list()
  add <- function(column, values) {
    result <- ledgr_diagnostic_add_in(where, params, column, values)
    where <<- result$where
    params <<- result$params
  }
  add("run_id", run_ids)
  add("stage", stage)
  add("outcome", outcome)
  add("reason_code", reason_code)
  add("mark_source", mark_source)
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
      "SELECT * FROM run_diagnostics",
      if (length(where) > 0L) paste("WHERE", paste(where, collapse = " AND ")) else "",
      paste("ORDER BY", order)
    ),
    params = params
  )
  absent_sizing_reason <- rows$stage == "sizing" & !nzchar(rows$reasons)
  rows$reasons[absent_sizing_reason] <- NA_character_
  tibble::as_tibble(rows)
}

# Exact summaries owned by the decoder. LDG-3208 may replace these internals.
ledgr_diagnostic_next_seq <- function(con, run_id) {
  as.integer(DBI::dbGetQuery(
    con,
    paste0("SELECT COALESCE(MAX(diagnostic_seq), 0) + 1 AS next_seq ",
           "FROM run_diagnostics WHERE run_id = ?"),
    params = list(run_id)
  )$next_seq[[1L]])
}

ledgr_diagnostic_present <- function(con, run_id, stage = NULL, outcome = NULL, reason_code = NULL) {
  nrow(ledgr_diagnostic_decode(
    con, run_id, stage = stage, outcome = outcome, reason_code = reason_code
  )) > 0L
}

ledgr_diagnostic_flag_counts <- function(con, run_ids) {
  run_ids <- unique(as.character(run_ids))
  if (length(run_ids) == 0L) {
    return(data.frame(run_id = character(), decisions = integer(), stale = integer(),
                      frozen = integer(), assumed = integer(), stringsAsFactors = FALSE))
  }
  quoted <- paste(DBI::dbQuoteString(con, run_ids), collapse = ", ")
  DBI::dbGetQuery(con, sprintf(paste(
    "SELECT run_id,",
    "COUNT(*) FILTER (WHERE stage = 'decision') AS decisions,",
    "COUNT(*) FILTER (WHERE quantity <> 0 AND (stage = 'decision' OR (stage = 'valuation' AND outcome = 'marked')) AND mark_source = 'stale_close') AS stale,",
    "COUNT(*) FILTER (WHERE quantity <> 0 AND (stage = 'decision' OR (stage = 'valuation' AND outcome = 'marked')) AND mark_source = 'frozen_close') AS frozen,",
    "COUNT(*) FILTER (WHERE stage = 'valuation' AND reason_code = 'terminal_disposition') AS assumed",
    "FROM run_diagnostics WHERE run_id IN (%s) GROUP BY run_id"
  ), quoted))
}
