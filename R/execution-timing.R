ledgr_availability_execution_timing_rule_version <- 2L

ledgr_execution_timing_provenance <- function(config) {
  unknown <- function(source = "unknown_config") {
    list(
      execution_timing_version = NA_integer_,
      execution_timing_convention = "unknown",
      execution_timing_source = source
    )
  }

  if (!is.list(config)) return(unknown())
  availability <- config$availability
  if (is.null(availability)) {
    timing_model <- config$timing_model
    timing_model_recorded <- is.list(timing_model) &&
      is.character(timing_model$type_id) && length(timing_model$type_id) == 1L &&
      !is.na(timing_model$type_id) && nzchar(timing_model$type_id)
    if (!isTRUE(timing_model_recorded)) {
      return(unknown("insufficient_dense_timing_config"))
    }
    return(list(
      execution_timing_version = NA_integer_,
      execution_timing_convention = "dense_bar_timestamp",
      execution_timing_source = "recorded_dense_config"
    ))
  }
  if (!is.list(availability) || !isTRUE(availability$active)) {
    return(unknown("inconsistent_availability_config"))
  }

  provider_version <- availability$provider_version
  provider_known <- is.character(provider_version) &&
    length(provider_version) == 1L &&
    !is.na(provider_version) &&
    identical(provider_version, ledgr_availability_provider_version())
  if (!isTRUE(provider_known)) {
    return(unknown("unrecognized_provider_version"))
  }

  version <- availability$execution_timing_version
  if (is.numeric(version) && length(version) == 1L && !is.na(version) &&
      is.finite(version) &&
      identical(
        as.integer(version),
        ledgr_availability_execution_timing_rule_version
      ) && version == ledgr_availability_execution_timing_rule_version) {
    return(list(
      execution_timing_version = ledgr_availability_execution_timing_rule_version,
      execution_timing_convention = "availability_open_v2",
      execution_timing_source = "recorded_config"
    ))
  }
  unknown("unsupported_execution_timing_version")
}

ledgr_execution_timing_from_json <- function(config_json) {
  if (is.null(config_json) || length(config_json) != 1L ||
      is.na(config_json) || !nzchar(config_json)) {
    return(ledgr_execution_timing_provenance(NULL))
  }
  config <- tryCatch(ledgr_json_read_config(config_json), error = function(e) NULL)
  ledgr_execution_timing_provenance(config)
}

ledgr_execution_timing_require_current <- function(config) {
  if (!ledgr_availability_config_active(config)) return(invisible(TRUE))
  timing <- ledgr_execution_timing_provenance(config)
  if (!identical(
    timing$execution_timing_version,
    ledgr_availability_execution_timing_rule_version
  )) {
    rlang::abort(
      "Availability-aware execution requires execution timing version 2.",
      class = "ledgr_invalid_config"
    )
  }
  invisible(TRUE)
}

ledgr_fills_add_recording_pulse <- function(fills, recording_pulse_ts_utc) {
  if (!is.data.frame(fills)) {
    rlang::abort("`fills` must be a data frame.", class = "ledgr_internal_error")
  }
  if (length(recording_pulse_ts_utc) != nrow(fills)) {
    rlang::abort(
      "`recording_pulse_ts_utc` must contain one value per fill row.",
      class = "ledgr_internal_error"
    )
  }
  out <- tibble::as_tibble(fills)
  out$recording_pulse_ts_utc <- as.POSIXct(
    recording_pulse_ts_utc,
    origin = "1970-01-01",
    tz = "UTC"
  )
  columns <- names(out)
  columns <- append(
    setdiff(columns, "recording_pulse_ts_utc"),
    "recording_pulse_ts_utc",
    after = match("ts_utc", setdiff(columns, "recording_pulse_ts_utc"))
  )
  out[, columns, drop = FALSE]
}

ledgr_fill_recording_pulses_from_opportunities <- function(fills,
                                                            pulses_posix,
                                                            execution_opportunities_posix = NULL) {
  recording_pulse <- as.POSIXct(fills$ts_utc, tz = "UTC")
  if (is.null(execution_opportunities_posix) || nrow(fills) == 0L) {
    return(recording_pulse)
  }
  opportunity_idx <- match(
    as.numeric(as.POSIXct(fills$ts_utc, tz = "UTC")),
    as.numeric(as.POSIXct(execution_opportunities_posix, tz = "UTC"))
  )
  recording_idx <- opportunity_idx + 1L
  recording_idx[is.na(opportunity_idx) | recording_idx > length(pulses_posix)] <- NA_integer_
  as.POSIXct(
    pulses_posix[recording_idx],
    origin = "1970-01-01",
    tz = "UTC"
  )
}

ledgr_fill_recording_pulses_from_evidence <- function(fills,
                                                       diagnostics,
                                                       sessions,
                                                       timing) {
  unavailable <- rep(as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC"), nrow(fills))
  if (nrow(fills) == 0L) return(unavailable)
  if (identical(timing$execution_timing_convention, "dense_bar_timestamp")) {
    return(as.POSIXct(fills$ts_utc, tz = "UTC"))
  }
  if (!identical(timing$execution_timing_convention, "availability_open_v2") ||
      !is.data.frame(diagnostics) || nrow(diagnostics) == 0L ||
      !is.data.frame(sessions) || nrow(sessions) == 0L) {
    return(unavailable)
  }

  diagnostics <- diagnostics[
    as.character(diagnostics$stage) == "execution" &
      as.character(diagnostics$outcome) == "filled",
    ,
    drop = FALSE
  ]
  sessions <- sessions[as.character(sessions$status) == "open", , drop = FALSE]
  if (nrow(diagnostics) == 0L || nrow(sessions) == 0L) return(unavailable)

  fill_time <- as.numeric(as.POSIXct(fills$ts_utc, tz = "UTC"))
  diag_execution <- as.numeric(as.POSIXct(diagnostics$execution_ts_utc, tz = "UTC"))
  diag_decision <- as.numeric(as.POSIXct(diagnostics$decision_ts_utc, tz = "UTC"))
  session_open <- as.numeric(as.POSIXct(sessions$session_open, tz = "UTC"))
  session_close <- as.numeric(as.POSIXct(sessions$session_close, tz = "UTC"))
  diag_event_seq <- suppressWarnings(as.integer(diagnostics$event_seq))
  fill_event_seq <- suppressWarnings(as.integer(fills$event_seq))

  # Every fill resolves at once; each step keeps the per-fill rule.
  # (1) The diagnostic with the fill's event_seq, when exactly one exists.
  exactly_one <- function(fill_key, diag_key) {
    hit <- match(fill_key, diag_key, incomparables = NA)
    repeated <- diag_key[duplicated(diag_key, incomparables = NA)]
    count <- ifelse(is.na(hit), 0L, ifelse(fill_key %in% repeated, 2L, 1L))
    list(hit = hit, count = count)
  }
  by_seq <- exactly_one(fill_event_seq, diag_event_seq)
  # (2) Without an event_seq candidate, the diagnostic with the fill's
  # instrument and execution time, when exactly one exists. The pair is one
  # exact numeric key; a missing instrument or time never matches.
  fill_inst <- as.character(fills$instrument_id)
  diag_inst <- as.character(diagnostics$instrument_id)
  inst_levels <- unique(c(diag_inst, fill_inst))
  time_levels <- unique(c(diag_execution, fill_time))
  pair_key <- function(inst, time) {
    key <- (match(inst, inst_levels) - 1) * (length(time_levels) + 1) + match(time, time_levels)
    key[is.na(inst) | is.na(time)] <- NA_real_
    key
  }
  by_pair <- exactly_one(pair_key(fill_inst, fill_time), pair_key(diag_inst, diag_execution))
  diagnostic_idx <- ifelse(
    by_seq$count == 0L,
    ifelse(by_pair$count == 1L, by_pair$hit, NA_integer_),
    ifelse(by_seq$count == 1L, by_seq$hit, NA_integer_)
  )
  # (3) The diagnostic must record the fill's execution time.
  resolved <- !is.na(diagnostic_idx)
  same_time <- diag_execution[diagnostic_idx[resolved]] == fill_time[resolved]
  resolved[resolved] <- !is.na(same_time) & same_time
  # (4) Exactly one execution session at that time whose previous session
  # closed at the decision time; its close is the recording pulse.
  execution_time <- if (identical(
    timing$execution_timing_version,
    ledgr_availability_execution_timing_rule_version
  )) session_open else session_close
  shared_time <- execution_time[duplicated(execution_time)]
  session <- match(fill_time, execution_time)
  simple <- resolved & !(fill_time %in% shared_time) & !is.na(session) & session >= 2L
  prior_close <- session_close[session[simple] - 1L] == diag_decision[diagnostic_idx[simple]]
  simple[simple] <- !is.na(prior_close) & prior_close
  recording <- rep(NA_real_, nrow(fills))
  recording[simple] <- session_close[session[simple]]
  # Two sessions sharing one execution time keep the original per-fill rule.
  for (i in which(resolved & fill_time %in% shared_time)) {
    execution_sessions <- which(execution_time == fill_time[[i]])
    prior_sessions <- execution_sessions - 1L
    session_candidates <- execution_sessions[
      prior_sessions >= 1L &
        session_close[prior_sessions] == diag_decision[[diagnostic_idx[[i]]]]
    ]
    if (length(session_candidates) == 1L) recording[[i]] <- session_close[[session_candidates[[1L]]]]
  }
  as.POSIXct(recording, origin = "1970-01-01", tz = "UTC")
}

ledgr_run_fill_recording_pulses <- function(bt, fills, con) {
  timing <- ledgr_execution_timing_provenance(bt$config)
  if (identical(timing$execution_timing_convention, "dense_bar_timestamp")) {
    return(as.POSIXct(fills$ts_utc, tz = "UTC"))
  }
  if (identical(timing$execution_timing_convention, "unknown")) {
    return(rep(as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC"), nrow(fills)))
  }

  diagnostics <- DBI::dbGetQuery(
    con,
    paste(
      "SELECT event_seq, instrument_id, stage, outcome,",
      "decision_ts_utc, execution_ts_utc FROM run_diagnostics",
      "WHERE run_id = ? AND stage = 'execution' AND outcome = 'filled'",
      "ORDER BY diagnostic_seq"
    ),
    params = list(bt$run_id)
  )

  snapshot <- ledgr_availability_snapshot_connection(bt, con)
  on.exit(snapshot$close(), add = TRUE)
  snapshot_id <- as.character(bt$config$data$snapshot_id)
  sessions <- DBI::dbGetQuery(
    snapshot$con,
    paste(
      "SELECT status, session_open, session_close FROM snapshot_sessions",
      "WHERE snapshot_id = ? ORDER BY session_close"
    ),
    params = list(snapshot_id)
  )
  ledgr_fill_recording_pulses_from_evidence(fills, diagnostics, sessions, timing)
}

ledgr_fill_timing_comparison <- function(timing) {
  if (length(timing) == 0L) {
    return(list(comparable = FALSE, reason = "no_selected_runs"))
  }
  conventions <- vapply(
    timing,
    function(x) as.character(x$execution_timing_convention),
    character(1)
  )
  if (anyNA(conventions) || any(conventions == "unknown")) {
    return(list(comparable = FALSE, reason = "unknown_timing_convention"))
  }
  if (length(unique(conventions)) != 1L) {
    return(list(comparable = FALSE, reason = "mixed_timing_conventions"))
  }
  list(comparable = TRUE, reason = "same_timing_convention")
}

ledgr_comparison_assert_fill_timing_comparable <- function(comparison) {
  if (!inherits(comparison, "ledgr_comparison")) {
    rlang::abort(
      "`comparison` must be a ledgr_comparison object.",
      class = "ledgr_invalid_args"
    )
  }
  if (!isTRUE(attr(comparison, "fill_timing_comparable", exact = TRUE))) {
    reason <- attr(comparison, "fill_timing_comparability_reason", exact = TRUE)
    rlang::abort(
      sprintf(
        "Fill timing is not comparable for this selected run set: %s.",
        reason %||% "unknown"
      ),
      class = c("ledgr_fill_timing_not_comparable", "ledgr_invalid_args")
    )
  }
  invisible(TRUE)
}
