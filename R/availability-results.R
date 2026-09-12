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
      "SELECT instrument_id, meta_json FROM ledger_events",
      "WHERE run_id = ? AND ts_utc <= ? ORDER BY event_seq"
    ),
    params = list(run_id, ts_utc)
  )
  positions <- numeric()
  if (nrow(events) == 0L) return(positions)
  for (i in seq_len(nrow(events))) {
    id <- as.character(events$instrument_id[[i]])
    if (is.na(id) || !nzchar(id)) next
    meta <- ledgr_json_read_nested(events$meta_json[[i]])
    delta <- meta$position_delta
    if (!is.numeric(delta) || length(delta) != 1L || is.na(delta) || !is.finite(delta)) {
      rlang::abort(
        "ledger_events.meta_json must include a finite numeric scalar `position_delta`.",
        class = "ledgr_invalid_ledger_meta"
      )
    }
    if (!(id %in% names(positions))) positions[[id]] <- 0
    positions[[id]] <- positions[[id]] + as.numeric(delta)
  }
  positions
}

ledgr_availability_marks_at <- function(provider, axis, calendar, pulse_idx) {
  close <- matrix(
    NA_real_,
    nrow = length(axis),
    ncol = pulse_idx,
    dimnames = list(axis, NULL)
  )
  pulses <- as.POSIXct(calendar$pulses_posix, tz = "UTC")
  for (i in seq_along(axis)) {
    history <- provider$history(axis[[i]], pulses[[pulse_idx]])
    if (nrow(history) == 0L) next
    index <- match(
      as.numeric(as.POSIXct(history$ts_utc, tz = "UTC")),
      as.numeric(pulses[seq_len(pulse_idx)])
    )
    keep <- !is.na(index)
    close[i, index[keep]] <- as.numeric(history$close[keep])
  }
  ledgr_availability_valuation_marks(
    bars_mat = list(close = close),
    instrument_ids = axis,
    axis = axis,
    pulse_idx = pulse_idx,
    pulses_posix = pulses,
    max_sessions = as.integer(provider$valuation_policy$max_sessions)
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
  rows <- vector("list", length(times))
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
    valuation <- ledgr_availability_marks_at(provider, ids, calendar, pulse_idx)
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
