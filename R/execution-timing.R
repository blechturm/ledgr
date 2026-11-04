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

ledgr_fill_recording_pulses_from_sessions <- function(fills, sessions, timing) {
  unavailable <- rep(as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC"), nrow(fills))
  if (nrow(fills) == 0L) return(unavailable)
  if (identical(timing$execution_timing_convention, "dense_bar_timestamp")) {
    return(as.POSIXct(fills$ts_utc, tz = "UTC"))
  }
  if (!identical(timing$execution_timing_convention, "availability_open_v2") ||
      !is.data.frame(sessions) || nrow(sessions) == 0L) {
    return(unavailable)
  }

  sessions <- sessions[as.character(sessions$status) == "open", , drop = FALSE]
  sessions <- sessions[order(as.POSIXct(sessions$session_close, tz = "UTC")), , drop = FALSE]
  if (nrow(sessions) < 2L) return(unavailable)

  fill_time <- as.numeric(as.POSIXct(fills$ts_utc, tz = "UTC"))
  session_open <- as.numeric(as.POSIXct(sessions$session_open, tz = "UTC"))
  session_close <- as.numeric(as.POSIXct(sessions$session_close, tz = "UTC"))
  recording <- rep(NA_real_, nrow(fills))
  # The configured opportunity calendar is session_open[-1]. A valid
  # single-venue snapshot therefore identifies the recording close directly.
  # Missing or duplicated opportunities stay unavailable rather than guessed.
  hit <- match(fill_time, session_open, incomparables = NA)
  duplicate_open <- session_open %in% session_open[
    duplicated(session_open, incomparables = NA)
  ]
  ok <- !is.na(hit) & hit >= 2L & !duplicate_open[hit]
  recording[ok] <- session_close[hit[ok]]
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

  snapshot <- ledgr_availability_snapshot_connection(bt, con)
  on.exit(snapshot$close(), add = TRUE)
  snapshot_id <- as.character(bt$config$data$snapshot_id)
  sessions <- DBI::dbGetQuery(
    snapshot$con,
    paste(
      "SELECT status, session_open, session_close FROM snapshot_sessions",
      "WHERE snapshot_id = ? AND status = 'open' ORDER BY session_close"
    ),
    params = list(snapshot_id)
  )
  ledgr_fill_recording_pulses_from_sessions(fills, sessions, timing)
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
