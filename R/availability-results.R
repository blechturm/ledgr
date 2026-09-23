ledgr_backtest_terminal_evidence <- function(bt, con = NULL) {
  if (!inherits(bt, "ledgr_backtest")) {
    rlang::abort("`bt` must be a ledgr_backtest object.", class = "ledgr_invalid_backtest")
  }
  opened <- if (is.null(con)) ledgr_backtest_read_connection(bt) else list(
    con = con,
    close = function() invisible(FALSE)
  )
  on.exit(opened$close(), add = TRUE)
  status <- DBI::dbGetQuery(
    opened$con,
    "SELECT status FROM runs WHERE run_id = ?",
    params = list(bt$run_id)
  )
  completion <- ledgr_run_completion_read(opened$con, bt$run_id, required = FALSE)
  list(
    status = if (nrow(status) == 1L) as.character(status$status[[1L]]) else NA_character_,
    completion = completion,
    completion_json = ledgr_completion_json(completion)
  )
}

ledgr_backtest_diagnostics <- function(con, run_id) {
  tibble::as_tibble(DBI::dbGetQuery(
    con,
    paste(
      "SELECT * FROM run_diagnostics WHERE run_id = ?",
      "ORDER BY diagnostic_seq"
    ),
    params = list(run_id)
  ))
}

ledgr_run_completion_info_empty <- function() {
  missing_time <- as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC")
  list(
    completion_evidence_available = FALSE,
    completion_status = NA_character_,
    requested_start_utc = missing_time,
    requested_end_utc = missing_time,
    achieved_start_utc = missing_time,
    achieved_end_utc = missing_time,
    stop_reason = NA_character_,
    last_fully_valued_ts_utc = missing_time,
    last_executed_ts_utc = missing_time,
    complete_performance = NA,
    affected_instrument_ids = NA_character_
  )
}

ledgr_run_completion_info <- function(con, run_id) {
  if (!ledgr_experiment_store_table_exists(con, "run_completion")) {
    return(ledgr_run_completion_info_empty())
  }
  completion <- ledgr_run_completion_read(con, run_id, required = FALSE)
  if (is.null(completion) || nrow(completion) == 0L) {
    return(ledgr_run_completion_info_empty())
  }
  affected_ids <- character()
  if (ledgr_experiment_store_table_exists(con, "run_diagnostics")) {
    stopped <- DBI::dbGetQuery(
      con,
      paste(
        "SELECT instrument_id FROM run_diagnostics",
        "WHERE run_id = ? AND outcome = 'stopped' ORDER BY diagnostic_seq"
      ),
      params = list(run_id)
    )
    affected_ids <- unique(as.character(stopped$instrument_id))
    affected_ids <- affected_ids[!is.na(affected_ids) & nzchar(affected_ids)]
  }
  ledgr_run_completion_info_from_rows(completion, affected_ids)
}

ledgr_run_completion_info_from_rows <- function(completion, affected_ids = character()) {
  time_value <- function(name) {
    as.POSIXct(completion[[name]][[1L]], tz = "UTC")
  }
  list(
    completion_evidence_available = TRUE,
    completion_status = as.character(completion$intended_terminal_status[[1L]]),
    requested_start_utc = time_value("intended_start_utc"),
    requested_end_utc = time_value("intended_end_utc"),
    achieved_start_utc = time_value("achieved_start_utc"),
    achieved_end_utc = time_value("achieved_end_utc"),
    stop_reason = as.character(completion$stop_reason[[1L]]),
    last_fully_valued_ts_utc = time_value("last_fully_valued_ts_utc"),
    last_executed_ts_utc = time_value("last_executed_ts_utc"),
    complete_performance = isTRUE(completion$complete_performance[[1L]]),
    affected_instrument_ids = affected_ids
  )
}

ledgr_run_completion_info_many <- function(con, run_ids) {
  run_ids <- as.character(run_ids)
  out <- stats::setNames(
    lapply(run_ids, function(run_id) ledgr_run_completion_info_empty()),
    run_ids
  )
  if (length(run_ids) == 0L || !ledgr_experiment_store_table_exists(con, "run_completion")) {
    return(out)
  }
  quoted_ids <- paste(DBI::dbQuoteString(con, unique(run_ids)), collapse = ", ")
  completion <- DBI::dbGetQuery(
    con,
    sprintf(
      "SELECT * FROM run_completion WHERE run_id IN (%s) ORDER BY run_id",
      quoted_ids
    )
  )
  stopped <- data.frame(run_id = character(), instrument_id = character())
  if (ledgr_experiment_store_table_exists(con, "run_diagnostics")) {
    stopped <- DBI::dbGetQuery(
      con,
      sprintf(
        paste(
          "SELECT run_id, instrument_id FROM run_diagnostics",
          "WHERE run_id IN (%s) AND outcome = 'stopped'",
          "ORDER BY run_id, diagnostic_seq"
        ),
        quoted_ids
      )
    )
  }
  for (run_id in unique(run_ids)) {
    row <- completion[completion$run_id == run_id, , drop = FALSE]
    if (nrow(row) == 0L) next
    if (nrow(row) != 1L) {
      ledgr_run_terminal_evidence_abort(
        sprintf("Run '%s' has ambiguous completion evidence.", run_id)
      )
    }
    affected <- unique(as.character(stopped$instrument_id[stopped$run_id == run_id]))
    affected <- affected[!is.na(affected) & nzchar(affected)]
    out[[run_id]] <- ledgr_run_completion_info_from_rows(row, affected)
  }
  out
}

ledgr_backtest_completion_info <- function(bt) {
  opened <- ledgr_backtest_read_connection(bt)
  on.exit(opened$close(), add = TRUE)
  ledgr_run_completion_info(opened$con, bt$run_id)
}

ledgr_completion_time_label <- function(x) {
  if (length(x) != 1L || is.na(x)) return("unknown")
  format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

ledgr_print_completion_info <- function(info) {
  if (!isTRUE(info$completion_evidence_available)) return(invisible(FALSE))
  requested <- paste(
    ledgr_completion_time_label(info$requested_start_utc),
    ledgr_completion_time_label(info$requested_end_utc),
    sep = " to "
  )
  achieved <- paste(
    ledgr_completion_time_label(info$achieved_start_utc),
    ledgr_completion_time_label(info$achieved_end_utc),
    sep = " to "
  )
  stop_reason <- info$stop_reason
  if (length(stop_reason) != 1L || is.na(stop_reason) || !nzchar(stop_reason)) {
    stop_reason <- "none"
  }
  affected <- info$affected_instrument_ids
  affected <- affected[!is.na(affected) & nzchar(affected)]
  affected <- if (length(affected) == 0L) "none recorded" else paste(affected, collapse = ", ")
  performance <- if (isTRUE(info$complete_performance)) "complete" else "incomplete"

  cat("Completion Evidence:\n")
  cat("  Status:           ", info$completion_status, "\n", sep = "")
  cat("  Requested Window: ", requested, "\n", sep = "")
  cat("  Achieved Window:  ", achieved, "\n", sep = "")
  cat("  Stop Reason:      ", stop_reason, "\n", sep = "")
  cat(
    "  Last Fully Valued: ",
    ledgr_completion_time_label(info$last_fully_valued_ts_utc),
    "\n",
    sep = ""
  )
  cat(
    "  Last Executed:    ",
    ledgr_completion_time_label(info$last_executed_ts_utc),
    "\n",
    sep = ""
  )
  cat("  Performance:       ", performance, "\n", sep = "")
  cat("  Affected IDs:      ", affected, "\n\n", sep = "")
  invisible(TRUE)
}

ledgr_availability_result_empty <- function() {
  tibble::tibble(
    ts_utc = as.POSIXct(character(), tz = "UTC"),
    instrument_id = character(),
    member = logical(),
    held = logical(),
    target_restricted = logical(),
    admissible = logical(),
    target_restriction_reason = character(),
    target_restriction_reasons = character(),
    priced = logical(),
    mark_source = character(),
    mark_age = integer(),
    status = character()
  )
}

ledgr_availability_snapshot_connection <- function(bt, run_con) {
  path <- ledgr_snapshot_db_path_from_config(bt$config, bt$db_path)
  if (identical(path, ":memory:") || ledgr_same_db_path(path, bt$db_path)) {
    return(list(con = run_con, close = function() invisible(FALSE)))
  }
  opened <- ledgr_open_duckdb_with_retry(path)
  list(
    con = opened$con,
    close = function() {
      suppressWarnings(try(DBI::dbDisconnect(opened$con, shutdown = TRUE), silent = TRUE))
      suppressWarnings(try(duckdb::duckdb_shutdown(opened$drv), silent = TRUE))
      invisible(TRUE)
    }
  )
}

ledgr_availability_feature_identity_json <- function(config) {
  defs <- config$features$defs
  if (is.null(defs) || !is.list(defs) || length(defs) == 0L) {
    return(as.character(canonical_json(list(feature_set_hash = ledgr_feature_set_hash(character())))))
  }
  fingerprints <- vapply(defs, function(def) {
    value <- def$fingerprint
    if (is.null(value)) value <- ledgr_feature_def_fingerprint(def)
    as.character(value)
  }, character(1))
  as.character(canonical_json(list(
    feature_set_hash = ledgr_feature_set_hash(fingerprints),
    feature_fingerprints = sort(unique(unname(fingerprints)))
  )))
}

ledgr_availability_positions_asof <- function(con, run_id, ts_utc) {
  events <- DBI::dbGetQuery(
    con,
    paste(
      paste(
        "SELECT event_id, run_id, ts_utc, event_type, instrument_id, side,",
        "qty, price, fee, meta_json, event_seq FROM ledger_events"
      ),
      "WHERE run_id = ? AND ts_utc <= ? ORDER BY event_seq"
    ),
    params = list(run_id, ts_utc)
  )
  if (nrow(events) == 0L) return(numeric())
  prepared <- ledgr_prepare_accounting_events(events)
  ledgr_replay_accounting_events(prepared)$positions
}

ledgr_availability_marks_rows <- function(con,
                                          snapshot_id,
                                          instrument_ids,
                                          cutoff) {
  instrument_ids <- unique(as.character(instrument_ids))
  if (length(instrument_ids) == 0L) {
    return(data.frame(
      instrument_id = character(),
      ts_utc = as.POSIXct(character(), tz = "UTC"),
      close = numeric(),
      stringsAsFactors = FALSE
    ))
  }
  placeholders <- paste(rep("?", length(instrument_ids)), collapse = ", ")
  DBI::dbGetQuery(
    con,
    paste0(
      "SELECT instrument_id, ts_utc, close FROM snapshot_bars ",
      "WHERE snapshot_id = ? AND instrument_id IN (", placeholders, ") ",
      "AND ts_utc <= ? ORDER BY instrument_id, ts_utc"
    ),
    params = c(
      list(snapshot_id),
      as.list(instrument_ids),
      list(as.POSIXct(cutoff, tz = "UTC"))
    )
  )
}

ledgr_availability_marks_state <- function(con,
                                           snapshot_id,
                                           instrument_ids,
                                           calendar,
                                           final_pulse_idx,
                                           max_sessions) {
  instrument_ids <- ledgr_availability_stable_ids(instrument_ids)
  pulses <- as.POSIXct(calendar$pulses_posix, tz = "UTC")
  final_pulse_idx <- as.integer(final_pulse_idx)
  if (length(final_pulse_idx) != 1L || is.na(final_pulse_idx) ||
      final_pulse_idx < 1L || final_pulse_idx > length(pulses)) {
    rlang::abort(
      "Availability result marks require a final pulse inside the sealed calendar.",
      class = "ledgr_invalid_run"
    )
  }
  pulses <- pulses[seq_len(final_pulse_idx)]
  rows <- ledgr_availability_marks_rows(
    con,
    snapshot_id,
    instrument_ids,
    pulses[[final_pulse_idx]]
  )
  close <- matrix(
    NA_real_,
    nrow = length(instrument_ids),
    ncol = final_pulse_idx,
    dimnames = list(instrument_ids, NULL)
  )
  if (nrow(rows) > 0L) {
    row_index <- match(as.character(rows$instrument_id), instrument_ids)
    column_index <- match(
      as.numeric(as.POSIXct(rows$ts_utc, tz = "UTC")),
      as.numeric(pulses)
    )
    keep <- !is.na(row_index) & !is.na(column_index)
    close[cbind(row_index[keep], column_index[keep])] <- as.numeric(rows$close[keep])
  }
  ledgr_availability_valuation_state(
    bars_mat = list(close = close),
    instrument_ids = instrument_ids,
    pulses_posix = pulses,
    max_sessions = as.integer(max_sessions)
  )
}

ledgr_backtest_availability_active <- function(bt, con) {
  diagnostics <- ledgr_backtest_diagnostics(con, bt$run_id)
  if (nrow(diagnostics) == 0L) return(ledgr_availability_result_empty())

  snapshot <- ledgr_availability_snapshot_connection(bt, con)
  on.exit(snapshot$close(), add = TRUE)
  snapshot_id <- as.character(bt$config$data$snapshot_id)
  hash <- DBI::dbGetQuery(
    snapshot$con,
    "SELECT snapshot_hash FROM snapshots WHERE snapshot_id = ?",
    params = list(snapshot_id)
  )
  if (nrow(hash) != 1L) {
    rlang::abort("The run snapshot is unavailable for availability inspection.", class = "ledgr_invalid_snapshot")
  }
  provider <- ledgr_availability_provider(
    snapshot$con,
    bt$config,
    as.character(hash$snapshot_hash[[1L]])
  )
  calendar <- ledgr_availability_calendar(
    provider,
    bt$config$backtest$start_ts_utc,
    bt$config$backtest$end_ts_utc
  )
  pulses <- as.POSIXct(calendar$pulses_posix, tz = "UTC")

  times <- sort(unique(as.POSIXct(diagnostics$ts_utc, tz = "UTC")))
  prepared <- vector("list", length(times))
  mark_axis <- character()
  for (i in seq_along(times)) {
    pulse_idx <- match(as.numeric(times[[i]]), as.numeric(pulses))
    if (is.na(pulse_idx)) {
      rlang::abort(
        "Recorded diagnostics contain a timestamp outside the sealed session calendar.",
        class = "ledgr_invalid_run"
      )
    }
    positions <- ledgr_availability_positions_asof(con, bt$run_id, times[[i]])
    view <- provider$decision_view(times[[i]], positions)
    ids <- as.character(view$axis)
    mark_axis <- c(mark_axis, ids)
    prepared[[i]] <- list(
      pulse_idx = pulse_idx,
      view = view,
      ids = ids
    )
  }
  final_pulse_idx <- max(vapply(prepared, `[[`, integer(1L), "pulse_idx"))
  valuation_state <- ledgr_availability_marks_state(
    snapshot$con,
    snapshot_id,
    mark_axis,
    calendar,
    final_pulse_idx,
    provider$valuation_policy$max_sessions
  )

  rows <- vector("list", length(times))
  for (i in seq_along(times)) {
    item <- prepared[[i]]
    ids <- item$ids
    view <- item$view
    valuation <- valuation_state$advance(item$pulse_idx, ids)
    rows[[i]] <- data.frame(
      ts_utc = rep(as.POSIXct(times[[i]], tz = "UTC"), length(ids)),
      instrument_id = ids,
      member = as.logical(view$member[ids]),
      held = as.logical(view$held[ids]),
      target_restricted = as.logical(view$target_restricted[ids]),
      admissible = as.logical(view$member[ids]) & !as.logical(view$target_restricted[ids]),
      target_restriction_reason = as.character(view$target_restriction_reason[ids]),
      target_restriction_reasons = as.character(view$target_restriction_reasons[ids]),
      priced = as.logical(valuation$priced[ids]),
      mark_source = as.character(valuation$source[ids]),
      mark_age = as.integer(valuation$age[ids]),
      status = as.character(view$status[ids]),
      stringsAsFactors = FALSE
    )
  }
  rows <- Filter(Negate(is.null), rows)
  if (length(rows) == 0L) return(ledgr_availability_result_empty())
  tibble::as_tibble(do.call(rbind, rows))
}

ledgr_backtest_availability_dense <- function(bt, con) {
  equity <- ledgr_compute_equity_curve_impl(bt, con = con)
  ids <- as.character(bt$config$universe$instrument_ids)
  if (nrow(equity) == 0L || length(ids) == 0L) return(ledgr_availability_result_empty())
  rows <- vector("list", nrow(equity))
  for (i in seq_len(nrow(equity))) {
    ts <- as.POSIXct(equity$ts_utc[[i]], tz = "UTC")
    positions <- ledgr_availability_positions_asof(con, bt$run_id, ts)
    quantity <- stats::setNames(rep(0, length(ids)), ids)
    matched <- intersect(names(positions), ids)
    quantity[matched] <- positions[matched]
    rows[[i]] <- data.frame(
      ts_utc = rep(ts, length(ids)),
      instrument_id = ids,
      member = TRUE,
      held = as.numeric(quantity) != 0,
      target_restricted = FALSE,
      admissible = TRUE,
      target_restriction_reason = "",
      target_restriction_reasons = "",
      priced = TRUE,
      mark_source = "current_close",
      mark_age = 0L,
      status = "active",
      stringsAsFactors = FALSE
    )
  }
  tibble::as_tibble(do.call(rbind, rows))
}

ledgr_backtest_availability <- function(bt, con) {
  if (ledgr_availability_config_active(bt$config)) {
    ledgr_backtest_availability_active(bt, con)
  } else {
    ledgr_backtest_availability_dense(bt, con)
  }
}

#' Explain one recorded availability-aware run decision
#'
#' Joins the durable decision trace, execution diagnostics, completion evidence,
#' and the availability plane reconstructed from sealed facts. Strategy code is
#' never executed. Runs without a retained decision trace fail explicitly.
#'
#' @param bt A `ledgr_backtest` object.
#' @param instrument_id One stable instrument identifier.
#' @param ts_utc One decision timestamp coercible to POSIXct UTC.
#' @return A one-row tibble with:
#' - identifiers: `run_id`, `ts_utc`, and `instrument_id`;
#' - availability: `member`, `held`, `target_restricted`,
#'   `target_restriction_reason`, and `target_restriction_reasons`;
#' - decision evidence: `feature_identity_json`, `quantity`,
#'   `target_before_risk`, and `target_after_risk`;
#' - execution evidence: `execution_outcome`, `execution_reason`,
#'   `execution_reasons`, and `resulting_position`;
#' - valuation evidence: `mark_source` and `mark_age`; and
#' - terminal evidence: `completion_status` and `complete_performance`.
#'
#' When no execution diagnostic exists for an unchanged target,
#' `execution_outcome` is `"no_action"` and the two execution-reason fields
#' are `"no_target_change"`. These are explain-time values, not durable
#' diagnostic reason codes.
#' @section Articles:
#' Point-in-time universe workflow:
#' `vignette("survivorship-bias", package = "ledgr")`
#' `system.file("doc", "survivorship-bias.html", package = "ledgr")`
#' @export
ledgr_run_explain <- function(bt, instrument_id, ts_utc) {
  if (!inherits(bt, "ledgr_backtest")) {
    rlang::abort("`bt` must be a ledgr_backtest object.", class = "ledgr_invalid_backtest")
  }
  if (!is.character(instrument_id) || length(instrument_id) != 1L ||
      is.na(instrument_id) || !nzchar(instrument_id)) {
    rlang::abort("`instrument_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  ts <- tryCatch(as.POSIXct(ts_utc, tz = "UTC"), error = function(e) as.POSIXct(NA, tz = "UTC"))
  if (length(ts) != 1L || is.na(ts)) {
    rlang::abort("`ts_utc` must be one parseable timestamp.", class = "ledgr_invalid_args")
  }
  diagnostics <- tibble::as_tibble(bt, what = "diagnostics")
  decision <- diagnostics[
    diagnostics$stage == "decision" &
      diagnostics$instrument_id == instrument_id &
      as.POSIXct(diagnostics$ts_utc, tz = "UTC") == ts,
    ,
    drop = FALSE
  ]
  if (nrow(decision) != 1L) {
    rlang::abort(
      "No retained decision trace exists for that instrument and timestamp.",
      class = "ledgr_run_explanation_unavailable"
    )
  }
  availability <- tibble::as_tibble(bt, what = "availability")
  available <- availability[
    availability$instrument_id == instrument_id & availability$ts_utc == ts,
    ,
    drop = FALSE
  ]
  if (nrow(available) != 1L) {
    rlang::abort(
      "The retained decision trace has no matching availability evidence.",
      class = "ledgr_run_explanation_unavailable"
    )
  }
  execution <- diagnostics[
    diagnostics$stage == "execution" &
      diagnostics$instrument_id == instrument_id &
      as.POSIXct(diagnostics$decision_ts_utc, tz = "UTC") == ts,
    ,
    drop = FALSE
  ]
  if (nrow(execution) > 1L) execution <- execution[1L, , drop = FALSE]
  terminal <- ledgr_backtest_terminal_evidence(bt)
  completion <- terminal$completion
  complete_performance <- if (is.null(completion) || nrow(completion) == 0L) {
    identical(terminal$status, "DONE")
  } else {
    isTRUE(completion$complete_performance[[1L]])
  }
  execution_value <- function(column, default) {
    if (nrow(execution) == 0L) default else execution[[column]][[1L]]
  }
  tibble::tibble(
    run_id = bt$run_id,
    ts_utc = ts,
    instrument_id = instrument_id,
    member = available$member[[1L]],
    held = available$held[[1L]],
    target_restricted = available$target_restricted[[1L]],
    target_restriction_reason = available$target_restriction_reason[[1L]],
    target_restriction_reasons = available$target_restriction_reasons[[1L]],
    feature_identity_json = if (
      !is.na(decision$feature_identity_json[[1L]]) &&
        nzchar(decision$feature_identity_json[[1L]])
    ) decision$feature_identity_json[[1L]] else ledgr_availability_feature_identity_json(bt$config),
    quantity = decision$quantity[[1L]],
    target_before_risk = decision$target_before_risk[[1L]],
    target_after_risk = decision$target_after_risk[[1L]],
    execution_outcome = as.character(execution_value("outcome", "no_action")),
    execution_reason = as.character(execution_value("reason_code", "no_target_change")),
    execution_reasons = as.character(execution_value("reasons", "no_target_change")),
    resulting_position = as.numeric(execution_value("position_after", decision$position_after[[1L]])),
    mark_source = available$mark_source[[1L]],
    mark_age = available$mark_age[[1L]],
    completion_status = terminal$status,
    complete_performance = complete_performance
  )
}
