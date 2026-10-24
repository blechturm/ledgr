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
    completion_json = ledgr_completion_json(
      completion,
      affected_instrument_ids = ledgr_stopped_instrument_ids(DBI::dbGetQuery(
        opened$con,
        "SELECT instrument_id, outcome FROM run_diagnostics WHERE run_id = ? AND outcome = 'stopped' ORDER BY diagnostic_seq",
        params = list(bt$run_id)
      )),
      assumptions = if (ledgr_availability_config_active(bt$config)) {
        ledgr_assumption_flags_for_run(bt, opened$con)
      } else {
        NULL
      }
    )
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

ledgr_backtest_diagnostics_filtered <- function(con,
                                                 run_id,
                                                 instrument_id,
                                                 ts_utc = NULL,
                                                 include_strategy_intent = FALSE) {
  where_time <- ""
  params <- list(run_id, instrument_id)
  if (!is.null(ts_utc)) {
    where_time <- paste(
      "AND ((stage = 'decision' AND ts_utc = ?)",
      "OR (stage = 'execution' AND decision_ts_utc = ?))"
    )
    params <- c(params, list(ts_utc, ts_utc))
  }
  where_diagnostic <- if (isTRUE(include_strategy_intent)) {
    paste(
      "AND ((instrument_id = ? AND stage IN ('decision', 'execution'))",
      "OR (instrument_id = '' AND stage = 'decision'",
      "AND reason_code = 'strategy_intent'))"
    )
  } else {
    paste(
      "AND instrument_id = ?",
      "AND stage IN ('decision', 'execution')"
    )
  }
  tibble::as_tibble(DBI::dbGetQuery(
    con,
    paste(
      "SELECT * FROM run_diagnostics",
      "WHERE run_id = ?",
      where_diagnostic,
      where_time,
      "ORDER BY diagnostic_seq"
    ),
    params = params
  ))
}

ledgr_strategy_intent_reasons <- function(detail_json) {
  detail_json <- as.character(detail_json)
  if (length(detail_json) == 0L) return(character())

  # The diagnostics contract fixes each payload to one JSON object with one
  # key. Decode the selected objects as one JSON array so explanation cost has
  # one parser call rather than one parser setup per decision pulse.
  parsed <- ledgr_json_read_nested(
    paste0("[", paste(detail_json, collapse = ","), "]")
  )
  flattened <- unlist(parsed, recursive = TRUE, use.names = TRUE)
  valid_shape <- is.list(parsed) &&
    length(parsed) == length(detail_json) &&
    all(lengths(parsed) == 1L) &&
    is.character(flattened) &&
    length(flattened) == length(detail_json) &&
    identical(names(flattened), rep("intent_reason", length(detail_json)))
  reasons <- if (valid_shape) {
    unname(flattened)
  } else {
    NULL
  }
  if (!is.character(reasons) || length(reasons) != length(detail_json) ||
      anyNA(reasons) || any(!nzchar(reasons))) {
    rlang::abort(
      "The retained strategy intent evidence is malformed.",
      class = "ledgr_run_explanation_unavailable"
    )
  }
  reasons
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
  completion <- ledgr_run_completion_read(con, run_id, required = FALSE)
  if (is.null(completion) || nrow(completion) == 0L) {
    return(ledgr_run_completion_info_empty())
  }
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
  if (length(run_ids) == 0L) {
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

#' Read one run's completion evidence
#'
#' Returns the persisted answer to whether a run covered its requested window,
#' including the achieved window, stop reason, and affected exposure recorded
#' at an incomplete boundary. It performs no new completion judgement.
#'
#' @param bt A `ledgr_backtest` object.
#' @return A `ledgr_run_completion` list. When the run has no completion row,
#'   `completion_evidence_available` is `FALSE` and every evidence field carries
#'   a typed missing value.
#' @export
ledgr_run_completion <- function(bt) {
  if (!inherits(bt, "ledgr_backtest")) {
    rlang::abort("`bt` must be a ledgr_backtest object.", class = "ledgr_invalid_backtest")
  }
  opened <- ledgr_backtest_read_connection(bt)
  on.exit(opened$close(), add = TRUE)
  info <- ledgr_run_completion_info(opened$con, bt$run_id)
  completion <- ledgr_run_completion_read(opened$con, bt$run_id, required = FALSE)
  missing_time <- as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC")
  if (is.null(completion) || nrow(completion) == 0L) {
    info$affected_exposure <- NA_real_
    info$affected_exposure_ts_utc <- missing_time
    info$affected_exposure_basis <- NA_character_
  } else {
    info$affected_exposure <- as.numeric(completion$affected_exposure[[1L]])
    info$affected_exposure_ts_utc <- as.POSIXct(
      completion$affected_exposure_ts_utc[[1L]],
      tz = "UTC"
    )
    info$affected_exposure_basis <- as.character(
      completion$affected_exposure_basis[[1L]]
    )
  }
  structure(info, class = c("ledgr_run_completion", "list"))
}

#' @export
print.ledgr_run_completion <- function(x, ...) {
  if (!inherits(x, "ledgr_run_completion")) {
    rlang::abort("`x` must be a ledgr_run_completion object.", class = "ledgr_invalid_args")
  }
  if (!isTRUE(x$completion_evidence_available)) {
    cat("Completion evidence is not available for this run.\n")
    return(invisible(x))
  }
  ledgr_print_completion_info(x)
  exposure <- if (is.finite(x$affected_exposure)) {
    format(x$affected_exposure, scientific = FALSE, trim = TRUE)
  } else {
    "unknown"
  }
  basis <- if (is.na(x$affected_exposure_basis) || !nzchar(x$affected_exposure_basis)) {
    "unknown"
  } else {
    x$affected_exposure_basis
  }
  cat("  Affected Exposure: ", exposure, "\n", sep = "")
  cat("  Exposure Basis:    ", basis, "\n", sep = "")
  invisible(x)
}

ledgr_completion_time_label <- function(x) {
  if (length(x) != 1L || is.na(x)) return("unknown")
  format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

ledgr_print_completion_info <- function(info, trailing_blank = TRUE) {
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
  ending <- if (isTRUE(trailing_blank)) "\n\n" else "\n"
  cat("  Affected IDs:      ", affected, ending, sep = "")
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
  opened <- ledgr_store_open(path, mode = "open")
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
    feature_fingerprints = sort(
      unique(unname(fingerprints)),
      method = "radix"
    )
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

# Each instrument's position at each requested time, from one ledger read and
# one replay: the position after its last event at or before that time. Event
# timestamps never decrease in event order, so the events at or before a time
# are a prefix of the ledger and the replay's sequential `position_after`
# values are exactly what replaying that prefix produces (the per-time reader
# above). ledgr_accounting_positions_at_pulses() is not used: its cumsum()
# accumulates in long double and can differ from the replay in the last bit.
# One findInterval() over sorted (instrument, event position) keys
# resolves every instrument and time pair. Returns NULL when timestamps do
# decrease in event order; callers then replay per time.
ledgr_availability_positions_timeline <- function(con, run_id, times) {
  events <- DBI::dbGetQuery(
    con,
    paste(
      paste(
        "SELECT event_id, run_id, ts_utc, event_type, instrument_id, side,",
        "qty, price, fee, meta_json, event_seq FROM ledger_events"
      ),
      "WHERE run_id = ? ORDER BY event_seq"
    ),
    params = list(run_id)
  )
  n_times <- length(times)
  if (nrow(events) == 0L) {
    return(list(ids = character(), position = matrix(0, 0L, n_times)))
  }
  event_num <- as.numeric(as.POSIXct(events$ts_utc, tz = "UTC"))
  if (is.unsorted(event_num)) return(NULL)
  prepared <- ledgr_prepare_accounting_events(events)
  replay <- ledgr_replay_accounting_events(prepared)
  ids <- prepared$instrument_ids
  inst <- prepared$instrument_index
  has <- !is.na(inst)
  big <- length(event_num) + 1
  key <- as.numeric(inst[has]) * big + which(has)
  ord <- order(key)
  key <- key[ord]
  key_inst <- inst[has][ord]
  after <- replay$position_after[has][ord]
  prefix <- findInterval(as.numeric(as.POSIXct(times, tz = "UTC")), event_num)
  q_inst <- rep(seq_along(ids), times = n_times)
  hit <- findInterval(q_inst * big + rep(prefix, each = length(ids)), key)
  found <- hit > 0L
  found[found] <- key_inst[hit[found]] == q_inst[found]
  position <- numeric(length(q_inst))
  position[found] <- after[hit[found]]
  list(ids = ids, position = matrix(position, nrow = length(ids), ncol = n_times, dimnames = list(ids, NULL)))
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
                                           max_sessions,
                                           exhausted = "refuse") {
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
    max_sessions = as.integer(max_sessions),
    exhausted = exhausted
  )
}

ledgr_backtest_availability_active <- function(bt,
                                               con,
                                               diagnostics = NULL,
                                               instrument_ids = NULL) {
  if (is.null(diagnostics)) {
    diagnostics <- ledgr_backtest_diagnostics(con, bt$run_id)
  }
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
  pulse_idx <- match(as.numeric(times), as.numeric(pulses))
  if (anyNA(pulse_idx)) {
    rlang::abort(
      "Recorded diagnostics contain a timestamp outside the sealed session calendar.",
      class = "ledgr_invalid_run"
    )
  }
  timeline <- ledgr_availability_positions_timeline(con, bt$run_id, times)
  positions_at <- function(i) {
    if (is.null(timeline)) return(ledgr_availability_positions_asof(con, bt$run_id, times[[i]]))
    timeline$position[, i]
  }
  # The decision view and the valuation state are sequential per pulse, as in
  # the fold; everything else is read once.
  views <- lapply(seq_along(times), function(i) provider$decision_view(times[[i]], positions_at(i)))
  axes <- lapply(views, function(view) {
    axis <- as.character(view$axis)
    if (is.null(instrument_ids)) return(axis)
    axis[!is.na(match(axis, instrument_ids))]
  })
  # Mark history starts at the data start, as in the fold: the marks state
  # runs on the session calendar from the snapshot's first bar.
  history_calendar <- ledgr_availability_calendar(
    provider,
    ledgr_run_snapshot_history_start(snapshot$con, snapshot_id),
    bt$config$backtest$end_ts_utc
  )
  history_idx <- match(as.numeric(times), as.numeric(history_calendar$pulses_posix))
  valuation_state <- ledgr_availability_marks_state(
    snapshot$con,
    snapshot_id,
    unlist(axes, use.names = FALSE),
    history_calendar,
    max(history_idx),
    provider$valuation_policy$max_sessions,
    ledgr_availability_exhausted_choice(provider$valuation_policy)
  )
  parts <- lapply(seq_along(times), function(i) {
    ids <- axes[[i]]
    view <- views[[i]]
    valuation <- valuation_state$advance(history_idx[[i]], ids, held = as.logical(view$held[ids]))
    view <- ledgr_availability_restrict_frozen(view, valuation)
    list(
      member = as.logical(view$member[ids]),
      held = as.logical(view$held[ids]),
      target_restricted = as.logical(view$target_restricted[ids]),
      target_restriction_reason = as.character(view$target_restriction_reason[ids]),
      target_restriction_reasons = as.character(view$target_restriction_reasons[ids]),
      priced = as.logical(valuation$priced[ids]),
      mark_source = as.character(valuation$source[ids]),
      mark_age = as.integer(valuation$age[ids]),
      status = as.character(view$status[ids])
    )
  })
  column <- function(name) unlist(lapply(parts, `[[`, name), use.names = FALSE)
  member <- column("member")
  target_restricted <- column("target_restricted")
  tibble::as_tibble(data.frame(
    ts_utc = .POSIXct(rep(as.numeric(times), lengths(axes)), tz = "UTC"),
    instrument_id = unlist(axes, use.names = FALSE),
    member = member,
    held = column("held"),
    target_restricted = target_restricted,
    admissible = member & !target_restricted,
    target_restriction_reason = column("target_restriction_reason"),
    target_restriction_reasons = column("target_restriction_reasons"),
    priced = column("priced"),
    mark_source = column("mark_source"),
    mark_age = column("mark_age"),
    status = column("status"),
    stringsAsFactors = FALSE
  ))
}

ledgr_backtest_availability_dense <- function(bt,
                                              con,
                                              instrument_ids = NULL,
                                              times = NULL) {
  ids <- as.character(bt$config$universe$instrument_ids)
  if (!is.null(instrument_ids)) {
    ids <- ids[!is.na(match(ids, instrument_ids))]
  }
  if (is.null(times)) {
    equity <- ledgr_compute_equity_curve_impl(bt, con = con)
    if (nrow(equity) == 0L) return(ledgr_availability_result_empty())
    times <- as.POSIXct(equity$ts_utc, tz = "UTC")
  } else {
    times <- as.POSIXct(times, tz = "UTC")
  }
  if (length(ids) == 0L || length(times) == 0L) {
    return(ledgr_availability_result_empty())
  }
  timeline <- ledgr_availability_positions_timeline(con, bt$run_id, times)
  quantity <- matrix(0, nrow = length(ids), ncol = length(times))
  if (is.null(timeline)) {
    for (i in seq_along(times)) {
      positions <- ledgr_availability_positions_asof(con, bt$run_id, times[[i]])
      matched <- intersect(names(positions), ids)
      quantity[match(matched, ids), i] <- positions[matched]
    }
  } else {
    row <- match(ids, timeline$ids)
    quantity[!is.na(row), ] <- timeline$position[row[!is.na(row)], , drop = FALSE]
  }
  n <- length(ids) * length(times)
  tibble::as_tibble(data.frame(
    ts_utc = .POSIXct(rep(as.numeric(times), each = length(ids)), tz = "UTC"),
    instrument_id = rep(ids, times = length(times)),
    member = rep(TRUE, n),
    held = as.vector(quantity != 0),
    target_restricted = rep(FALSE, n),
    admissible = rep(TRUE, n),
    target_restriction_reason = rep("", n),
    target_restriction_reasons = rep("", n),
    priced = rep(TRUE, n),
    mark_source = rep("current_close", n),
    mark_age = rep(0L, n),
    status = rep("active", n),
    stringsAsFactors = FALSE
  ))
}

ledgr_backtest_availability <- function(bt, con) {
  ledgr_backtest_ensure_snapshot(bt, con)
  if (ledgr_availability_config_active(bt$config)) {
    ledgr_backtest_availability_active(bt, con)
  } else {
    ledgr_backtest_availability_dense(bt, con)
  }
}

ledgr_backtest_availability_filtered <- function(bt,
                                                 con,
                                                 instrument_ids,
                                                 times) {
  if (ledgr_availability_config_active(bt$config)) {
    diagnostics <- data.frame(ts_utc = as.POSIXct(times, tz = "UTC"))
    ledgr_backtest_availability_active(
      bt,
      con,
      diagnostics = diagnostics,
      instrument_ids = instrument_ids
    )
  } else {
    ledgr_backtest_availability_dense(
      bt,
      con,
      instrument_ids = instrument_ids,
      times = times
    )
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
#' @param ts_utc Optional decision timestamp coercible to POSIXct UTC. When
#'   omitted, every retained decision for `instrument_id` is returned in pulse
#'   order.
#' @return A tibble with one row for a requested timestamp or one row per
#'   retained decision when `ts_utc` is omitted. An instrument absent from the
#'   retained trace returns a zero-row tibble in history mode. Columns are:
#' - identifiers: `run_id`, `ts_utc`, and `instrument_id`;
#' - availability: `member`, `held`, `target_restricted`,
#'   `target_restriction_reason`, and `target_restriction_reasons`;
#' - decision evidence: `feature_identity_json`, `quantity`,
#'   `target_before_risk`, and `target_after_risk`; on availability-aware runs,
#'   `intent_reason` is the optional portfolio-level note returned by the
#'   strategy at that decision pulse and is `NA_character_` when none was
#'   supplied. Dense explanation retains its existing schema;
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
ledgr_run_explain <- function(bt, instrument_id, ts_utc = NULL) {
  if (!inherits(bt, "ledgr_backtest")) {
    rlang::abort("`bt` must be a ledgr_backtest object.", class = "ledgr_invalid_backtest")
  }
  if (!is.character(instrument_id) || length(instrument_id) != 1L ||
      is.na(instrument_id) || !nzchar(instrument_id)) {
    rlang::abort("`instrument_id` must be a non-empty character scalar.", class = "ledgr_invalid_args")
  }
  history <- missing(ts_utc) || is.null(ts_utc)
  ts <- NULL
  if (!history) {
    ts <- tryCatch(as.POSIXct(ts_utc, tz = "UTC"), error = function(e) as.POSIXct(NA, tz = "UTC"))
    if (length(ts) != 1L || is.na(ts)) {
      rlang::abort("`ts_utc` must be one parseable timestamp.", class = "ledgr_invalid_args")
    }
  }
  opened <- ledgr_backtest_read_connection(bt)
  on.exit(opened$close(), add = TRUE)
  ledgr_backtest_ensure_snapshot(bt, opened$con)
  availability_active <- ledgr_availability_config_active(bt$config)
  diagnostics <- ledgr_backtest_diagnostics_filtered(
    opened$con,
    bt$run_id,
    instrument_id,
    ts,
    include_strategy_intent = availability_active
  )
  decision_idx <- diagnostics$stage == "decision" &
    diagnostics$instrument_id == instrument_id
  if (!history) {
    decision_idx <- decision_idx &
      as.POSIXct(diagnostics$ts_utc, tz = "UTC") == ts
  }
  decision <- diagnostics[decision_idx, , drop = FALSE]
  if (!history && nrow(decision) != 1L) {
    rlang::abort(
      "No retained decision trace exists for that instrument and timestamp.",
      class = "ledgr_run_explanation_unavailable"
    )
  }
  if (history && nrow(decision) > 1L) {
    decision <- decision[
      order(as.numeric(as.POSIXct(decision$ts_utc, tz = "UTC"))),
      ,
      drop = FALSE
    ]
  }
  decision_time <- as.POSIXct(decision$ts_utc, tz = "UTC")
  intent_reason <- NULL
  if (availability_active) {
    intent <- diagnostics[
      diagnostics$stage == "decision" &
        diagnostics$instrument_id == "" &
        diagnostics$reason_code == "strategy_intent",
      ,
      drop = FALSE
    ]
    intent_time <- as.numeric(as.POSIXct(intent$ts_utc, tz = "UTC"))
    if (anyDuplicated(intent_time)) {
      rlang::abort(
        "The retained decision trace has duplicate strategy intent evidence.",
        class = "ledgr_run_explanation_unavailable"
      )
    }
    intent_idx <- match(as.numeric(decision_time), intent_time)
    intent_reason <- rep(NA_character_, length(intent_idx))
    found_intent <- !is.na(intent_idx)
    if (any(found_intent)) {
      intent_reason[found_intent] <- ledgr_strategy_intent_reasons(
        intent$detail_json[intent_idx[found_intent]]
      )
    }
  }
  available <- if (nrow(decision) == 0L) {
    ledgr_availability_result_empty()
  } else {
    ledgr_backtest_availability_filtered(
      bt,
      opened$con,
      instrument_ids = instrument_id,
      times = decision_time
    )
  }
  available_time <- as.POSIXct(available$ts_utc, tz = "UTC")
  available_idx <- match(as.numeric(decision_time), as.numeric(available_time))
  if (anyNA(available_idx) || anyDuplicated(as.numeric(available_time))) {
    rlang::abort(
      "The retained decision trace has no matching availability evidence.",
      class = "ledgr_run_explanation_unavailable"
    )
  }
  available <- available[available_idx, , drop = FALSE]
  execution <- diagnostics[
    diagnostics$stage == "execution" &
      diagnostics$instrument_id == instrument_id,
    ,
    drop = FALSE
  ]
  execution_idx <- match(
    as.numeric(decision_time),
    as.numeric(as.POSIXct(execution$decision_ts_utc, tz = "UTC"))
  )
  terminal <- ledgr_backtest_terminal_evidence(bt, opened$con)
  completion <- terminal$completion
  complete_performance <- if (is.null(completion) || nrow(completion) == 0L) {
    identical(terminal$status, "DONE")
  } else {
    isTRUE(completion$complete_performance[[1L]])
  }
  execution_value <- function(column, default) {
    out <- default
    found <- !is.na(execution_idx)
    out[found] <- execution[[column]][execution_idx[found]]
    out
  }
  feature_identity <- as.character(decision$feature_identity_json)
  missing_identity <- is.na(feature_identity) | !nzchar(feature_identity)
  feature_identity[missing_identity] <- ledgr_availability_feature_identity_json(bt$config)
  out <- tibble::tibble(
    run_id = rep(bt$run_id, nrow(decision)),
    ts_utc = decision_time,
    instrument_id = rep(instrument_id, nrow(decision)),
    member = as.logical(available$member),
    held = as.logical(available$held),
    target_restricted = as.logical(available$target_restricted),
    target_restriction_reason = as.character(available$target_restriction_reason),
    target_restriction_reasons = as.character(available$target_restriction_reasons),
    feature_identity_json = feature_identity,
    quantity = as.numeric(decision$quantity),
    target_before_risk = as.numeric(decision$target_before_risk),
    target_after_risk = as.numeric(decision$target_after_risk),
    execution_outcome = as.character(execution_value("outcome", rep("no_action", nrow(decision)))),
    execution_reason = as.character(execution_value("reason_code", rep("no_target_change", nrow(decision)))),
    execution_reasons = as.character(execution_value("reasons", rep("no_target_change", nrow(decision)))),
    resulting_position = as.numeric(execution_value("position_after", as.numeric(decision$position_after))),
    mark_source = as.character(available$mark_source),
    mark_age = as.integer(available$mark_age),
    completion_status = rep(terminal$status, nrow(decision)),
    complete_performance = rep(complete_performance, nrow(decision))
  )
  if (availability_active) {
    out <- tibble::add_column(
      out,
      intent_reason = intent_reason,
      .after = "feature_identity_json"
    )
  }
  out
}
