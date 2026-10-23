#' Read a run's valuation evidence
#'
#' Availability-aware runs value every held instrument at a current close, a
#' permissible stale close, or, under `ledgr_valuation_stale(exhausted =
#' "freeze")`, a frozen close carried beyond `max_sessions`. Frozen equity is
#' an assumption-backed estimate: cash and quantity are exact, but the frozen
#' mark is not an observed price.
#'
#' The summary counts held instrument-sessions valued at stale and frozen
#' closes, the largest frozen gross value and its share of equity, the longest
#' continuous freeze, and what was still frozen at the end of the run.
#' `total_return_if_frozen_worthless` subtracts the frozen-at-end long value
#' from final equity before computing the endpoint return. It is a bound for
#' the endpoint only; it does not correct Sharpe, volatility, drawdown or the
#' stored equity path. Dense runs have no valuation policy and report
#' `valuation_state = "not_applicable"`.
#'
#' The summary also records what the run's point-in-time view rested on:
#' `universe_kind` (`"membership"` for a membership rule, with its
#' `universe_id`, or `"fixed"` for a fixed basket; `membership_declared` says
#' whether the snapshot declares membership facts a fixed basket does not
#' apply), `assumption_backed_families` with their `assumption_reasons`
#' (`"knowledge_assume_effective"`, `"generated_schedule"`, joined by `|`, as
#' in [ledgr_experiment_plan()]), and `max_sessions_default`, `TRUE` when the
#' stale-mark horizon (`max_sessions`) is the `ledgr_valuation_stale()` default
#' of 5 sessions. `print()` of a result shows these on one `Point in time:`
#' line that names the valuation stale-mark horizon as such, followed by a
#' `History policy:` line with the experiment's [ledgr_history_policy()]
#' (price carry, output carry and segment limit, each marked `default` or
#' `declared`); the stale-mark horizon is a valuation setting, not the history
#' policy's price carry. `history_policy` holds those three fields as a tibble
#' (`setting`, `label`, `value`, `default`). `summary()` lists the same fields
#' with the valuation evidence and a `History Policy` section.
#'
#' A run that stopped `INCOMPLETE` because a holding had no permissible mark
#' (`valuation_horizon_exhausted`, a holding never priced or, under
#' `exhausted = "refuse"`, a mark older than `max_sessions`) records the stop
#' in `valuation_stop_reason`, `valuation_stop_ts_utc` and
#' `valuation_stop_instruments` (`NA`, `NA` and empty otherwise), and the
#' valuation headline of `print()` and `summary()` reads `STOPPED` with the
#' stop pulse, the holdings and the reason. `valuation_state` still describes
#' the marks of the pulses before the stop.
#'
#' @param bt A `ledgr_backtest` object.
#' @param con An optional open database connection used internally. Public
#'   callers should leave this as `NULL`.
#' @return A list-like `ledgr_valuation_summary` object.
#' @export
ledgr_valuation_summary <- function(bt, con = NULL) {
  if (!inherits(bt, "ledgr_backtest")) {
    rlang::abort("`bt` must be a ledgr_backtest object.", class = "ledgr_invalid_backtest")
  }
  if (!ledgr_availability_config_active(bt$config)) {
    return(ledgr_valuation_summary_object(list(valuation_state = "not_applicable")))
  }
  if (is.null(con)) {
    opened <- ledgr_backtest_read_connection(bt)
    con <- opened$con
    on.exit(opened$close(), add = TRUE)
  }
  ledgr_store_assert_current(con, bt$db_path)
  ledgr_backtest_ensure_snapshot(bt, con)
  out <- ledgr_valuation_summary_evidence(bt, con)
  out <- ledgr_valuation_summary_add_stop(out, bt$run_id, con)
  ledgr_valuation_summary_add_basis(out, bt$config, con)
}

# The valuation stop of a run that ended INCOMPLETE because a holding had no
# permissible mark (LDG-3090): the stop pulse and the unvalued holdings, read
# in one query from the stop rows the fold recorded. valuation_state still
# describes the marks of the pulses before the stop.
ledgr_valuation_summary_add_stop <- function(out, run_id, con) {
  stopped <- DBI::dbGetQuery(
    con,
    paste(
      "SELECT ts_utc, instrument_id FROM run_diagnostics WHERE run_id = ?",
      "AND stage = 'valuation' AND outcome = 'stopped'",
      "AND reason_code = 'valuation_horizon_exhausted' ORDER BY diagnostic_seq"
    ),
    params = list(run_id)
  )
  ids <- unique(as.character(stopped$instrument_id))
  found <- nrow(stopped) > 0L
  out$valuation_stop_reason <- if (found) "valuation_horizon_exhausted" else NA_character_
  out$valuation_stop_ts_utc <- as.POSIXct(
    if (found) as.numeric(as.POSIXct(stopped$ts_utc[[1L]], tz = "UTC")) else NA_real_,
    origin = "1970-01-01", tz = "UTC"
  )
  out$valuation_stop_instruments <- ids[!is.na(ids) & nzchar(ids)]
  out
}

# Valuation evidence of an availability-aware run from its diagnostics and
# equity; the assumption flags of run lists and completion need only this.
ledgr_valuation_summary_evidence <- function(bt, con) {
  config <- bt$config
  policy <- config$availability$valuation_policy
  held <- "run_id = ? AND stage = 'decision' AND quantity <> 0"
  stale <- DBI::dbGetQuery(
    con,
    paste(
      "SELECT COUNT(*) AS sessions, COUNT(DISTINCT instrument_id) AS instruments,",
      "MAX(mark_age) AS longest_age FROM run_diagnostics WHERE", held,
      "AND mark_source = 'stale_close'"
    ),
    params = list(bt$run_id)
  )
  frozen <- DBI::dbGetQuery(
    con,
    paste(
      "SELECT ts_utc, instrument_id, quantity, price FROM run_diagnostics WHERE",
      held, "AND mark_source = 'frozen_close' ORDER BY instrument_id, ts_utc"
    ),
    params = list(bt$run_id)
  )
  equity <- DBI::dbGetQuery(
    con,
    "SELECT ts_utc, equity FROM equity_curve WHERE run_id = ? ORDER BY ts_utc",
    params = list(bt$run_id)
  )

  ledgr_valuation_summary_compute(policy, stale, frozen, equity)
}

# What the run's point-in-time view rested on (LDG-3010): the universe kind
# and the fact families whose knowledge clocks or schedules were assumed.
ledgr_valuation_summary_add_basis <- function(out, config, con) {
  rule <- config$availability$universe_rule
  declared <- as.character(config$availability$declared_families %||% character())
  headers <- ledgr_fact_headers_read(con, config$data$snapshot_id)
  # A membership rule applies only its own universe's membership facts.
  if (!is.null(rule) && nrow(headers) > 0L) {
    other <- headers$family == "membership" & headers$scope_id != rule$universe_id
    headers <- headers[!other, , drop = FALSE]
  }
  reasons <- ledgr_fact_assumption_reasons(headers)
  # A fixed basket does not apply membership facts, so it rests on none.
  applied <- if (is.null(rule)) setdiff(declared, "membership") else declared
  reasons <- reasons[names(reasons) %in% applied & lengths(reasons) > 0L]
  out$universe_kind <- if (is.null(rule)) "fixed" else "membership"
  out$universe_id <- rule$universe_id %||% NA_character_
  out$membership_declared <- "membership" %in% declared
  out$assumption_backed_families <- names(reasons)
  out$assumption_reasons <- unname(vapply(reasons, paste, character(1), collapse = "|"))
  # The run's history policy is part of the same basis (LDG-3081).
  out$history_policy <- ledgr_history_policy_disclosure(
    ledgr_history_identity_require_current(config$history)
  )
  out
}

# Shared arithmetic for durable runs and in-memory sweep candidates. `stale`
# holds sessions, instruments and longest_age; `frozen` holds held frozen
# decision rows (ts_utc, instrument_id, quantity, price); `equity` holds the
# accepted equity rows (ts_utc, equity).
ledgr_valuation_summary_compute <- function(policy, stale, frozen, equity) {
  equity <- equity[is.finite(equity$equity), , drop = FALSE]
  frozen <- frozen[order(as.character(frozen$instrument_id), as.numeric(as.POSIXct(frozen$ts_utc, tz = "UTC")), method = "radix"), , drop = FALSE]
  out <- list(
    valuation_state = if (nrow(frozen) > 0L) {
      "frozen"
    } else if (as.integer(stale$sessions) > 0L) {
      "stale"
    } else {
      "current"
    },
    max_sessions = as.integer(policy$max_sessions),
    max_sessions_default = identical(as.integer(policy$max_sessions), ledgr_valuation_default_max_sessions),
    exhausted = ledgr_availability_exhausted_choice(policy),
    stale_instrument_sessions = as.integer(stale$sessions),
    stale_instruments = as.integer(stale$instruments),
    longest_stale_age = if (as.integer(stale$sessions) > 0L) as.integer(stale$longest_age) else NA_integer_,
    frozen_instrument_sessions = nrow(frozen),
    frozen_instruments = length(unique(as.character(frozen$instrument_id))),
    longest_freeze_sessions = 0L,
    max_frozen_gross_value = 0,
    max_frozen_equity_weight = 0,
    frozen_at_end_count = 0L,
    frozen_at_end_value = 0,
    frozen_at_end_weight = 0,
    total_return = NA_real_,
    total_return_if_frozen_worthless = NA_real_
  )
  if (nrow(equity) > 0L) {
    out$total_return <- equity$equity[[nrow(equity)]] / equity$equity[[1L]] - 1
  }
  if (nrow(frozen) == 0L || nrow(equity) == 0L) {
    return(ledgr_valuation_summary_object(out))
  }

  pulse <- match(
    as.numeric(as.POSIXct(frozen$ts_utc, tz = "UTC")),
    as.numeric(as.POSIXct(equity$ts_utc, tz = "UTC"))
  )
  # A stopped pulse can record a decision without an equity row; it counts as
  # a frozen session but carries no equity weight.
  frozen <- frozen[!is.na(pulse), , drop = FALSE]
  pulse <- pulse[!is.na(pulse)]
  if (length(pulse) == 0L) return(ledgr_valuation_summary_object(out))
  instrument <- as.character(frozen$instrument_id)
  gross <- abs(as.numeric(frozen$quantity) * as.numeric(frozen$price))
  long_value <- pmax(as.numeric(frozen$quantity), 0) * as.numeric(frozen$price)

  # Rows are ordered by instrument and time, so a freeze is a run of
  # consecutive pulse indices for one instrument.
  starts <- c(TRUE, instrument[-1L] != instrument[-length(instrument)] |
    diff(pulse) != 1L)
  out$longest_freeze_sessions <- max(tabulate(cumsum(starts)))

  by_pulse <- rowsum(gross, pulse, reorder = TRUE)
  pulse_ids <- as.integer(rownames(by_pulse))
  out$max_frozen_gross_value <- max(by_pulse[, 1L])
  out$max_frozen_equity_weight <- max(by_pulse[, 1L] / equity$equity[pulse_ids])

  final <- nrow(equity)
  at_end <- pulse == final
  if (any(at_end)) {
    final_equity <- equity$equity[[final]]
    out$frozen_at_end_count <- length(unique(instrument[at_end]))
    out$frozen_at_end_value <- sum(gross[at_end])
    out$frozen_at_end_weight <- out$frozen_at_end_value / final_equity
    out$total_return_if_frozen_worthless <-
      (final_equity - sum(long_value[at_end])) / equity$equity[[1L]] - 1
  }
  ledgr_valuation_summary_object(out)
}

# Valuation inputs from an in-memory diagnostics table (sweep candidates).
ledgr_valuation_inputs_from_diagnostics <- function(diagnostics) {
  if (is.null(diagnostics) || nrow(diagnostics) == 0L) {
    diagnostics <- data.frame(stage = character(), quantity = numeric(), mark_source = character(),
                              mark_age = integer(), instrument_id = character(), price = numeric(),
                              ts_utc = as.POSIXct(character(), tz = "UTC"), stringsAsFactors = FALSE)
  }
  held <- diagnostics$stage == "decision" & !is.na(diagnostics$quantity) & diagnostics$quantity != 0
  stale <- held & diagnostics$mark_source %in% "stale_close"
  frozen <- held & diagnostics$mark_source %in% "frozen_close"
  list(
    stale = data.frame(
      sessions = sum(stale),
      instruments = length(unique(as.character(diagnostics$instrument_id[stale]))),
      longest_age = if (any(stale)) max(as.integer(diagnostics$mark_age[stale])) else NA_integer_
    ),
    frozen = data.frame(
      ts_utc = diagnostics$ts_utc[frozen],
      instrument_id = as.character(diagnostics$instrument_id[frozen]),
      quantity = as.numeric(diagnostics$quantity[frozen]),
      price = as.numeric(diagnostics$price[frozen]),
      stringsAsFactors = FALSE
    ),
    assumed_terminal_outcomes = sum(
      diagnostics$stage == "valuation" & diagnostics$reason_code %in% "terminal_disposition"
    )
  )
}

ledgr_valuation_summary_object <- function(fields) {
  structure(fields, class = c("ledgr_valuation_summary", "list"))
}

ledgr_valuation_headline <- function(summary) {
  state <- summary$valuation_state
  if (identical(state, "not_applicable")) return(NULL)
  plural <- function(n, word) sprintf("%d %s%s", n, word, if (n == 1L) "" else "s")
  # A run that stopped because a holding had no permissible mark reports the
  # stop, not the state of the pulses before it (LDG-3090).
  stop_reason <- summary$valuation_stop_reason
  if (length(stop_reason) == 1L && !is.na(stop_reason)) {
    ids <- summary$valuation_stop_instruments
    shown <- paste(utils::head(ids, 3L), collapse = ", ")
    if (length(ids) > 3L) shown <- sprintf("%s and %d more", shown, length(ids) - 3L)
    return(sprintf(
      "Valuation: STOPPED - %s without a permissible mark at %s (%s); the run is INCOMPLETE (%s)",
      plural(length(ids), "holding"),
      format(summary$valuation_stop_ts_utc, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      shown,
      stop_reason
    ))
  }
  if (identical(state, "frozen")) {
    detail <- sprintf(
      "%s frozen (longest %s, max %s or %s of equity)",
      plural(summary$frozen_instruments, "holding"),
      plural(summary$longest_freeze_sessions, "session"),
      ledgr_corporate_action_value(round(summary$max_frozen_gross_value, 2)),
      ledgr_valuation_percent(summary$max_frozen_equity_weight)
    )
    if (summary$frozen_at_end_count > 0L) {
      detail <- sprintf(
        "%s; %s still frozen at end worth %s",
        detail,
        summary$frozen_at_end_count,
        ledgr_corporate_action_value(round(summary$frozen_at_end_value, 2))
      )
    }
    return(paste("Valuation: FROZEN -", detail))
  }
  if (identical(state, "stale")) {
    return(sprintf(
      "Valuation: STALE - %s valued at a permitted stale close (longest age %s)",
      plural(summary$stale_instruments, "holding"),
      plural(summary$longest_stale_age, "session")
    ))
  }
  "Valuation: CURRENT - every held mark was a current close"
}

# Display parts for the universe kind, assumption-backed fact families and
# the horizon. A sweep candidate's in-memory summary has no universe fields.
ledgr_point_in_time_basis <- function(summary) {
  reason_labels <- c(knowledge_assume_effective = "knowledge assumed effective", generated_schedule = "generated schedule")
  universe <- if (identical(summary$universe_kind, "membership")) {
    sprintf("membership rule '%s'", summary$universe_id)
  } else if (identical(summary$universe_kind, "fixed")) {
    paste0("fixed basket", if (isTRUE(summary$membership_declared)) " (the snapshot's membership facts are not applied)")
  }
  families <- summary$assumption_backed_families
  assumed <- if (length(families) > 0L) {
    reasons <- vapply(strsplit(summary$assumption_reasons, "|", fixed = TRUE), function(r) {
      paste(reason_labels[r], collapse = ", ")
    }, character(1))
    paste(sprintf("%s (%s)", families, reasons), collapse = "; ")
  }
  list(
    universe = universe,
    assumed = assumed,
    horizon = ledgr_valuation_horizon_value(summary$max_sessions, summary$max_sessions_default)
  )
}

# The print() lines naming what the point-in-time view rested on. The
# valuation horizon is named as such (LDG-3081): it is the stale-mark limit
# of ledgr_valuation_stale(), not the history policy's price carry, which a
# second line discloses when the summary carries it.
ledgr_point_in_time_line <- function(summary) {
  if (identical(summary$valuation_state, "not_applicable")) return(NULL)
  basis <- ledgr_point_in_time_basis(summary)
  c(
    paste0(
      "Point in time: ", basis$universe %||% "universe not recorded",
      "; valuation stale-mark horizon ", basis$horizon,
      if (!is.null(basis$assumed)) paste0("; assumption-backed facts: ", basis$assumed)
    ),
    if (!is.null(summary$history_policy)) {
      paste0("History policy: ", ledgr_history_policy_rows_display(summary$history_policy))
    }
  )
}

ledgr_valuation_percent <- function(x) {
  if (length(x) != 1L || !is.finite(x)) return("not applicable")
  sprintf("%.2f%%", 100 * x)
}

#' @rdname ledgr_valuation_summary
#' @param x A `ledgr_valuation_summary` object.
#' @param ... Unused.
#' @export
print.ledgr_valuation_summary <- function(x, ...) {
  headline <- ledgr_valuation_headline(x)
  if (is.null(headline)) {
    cat("Valuation: not applicable (dense run without a valuation policy)\n")
    return(invisible(x))
  }
  ledgr_print_valuation_summary(x)
  invisible(x)
}

ledgr_print_valuation_summary <- function(summary) {
  headline <- ledgr_valuation_headline(summary)
  if (is.null(headline)) return(invisible(summary))
  cat("\nValuation Evidence:\n")
  cat(headline, "\n", sep = "")
  basis <- ledgr_point_in_time_basis(summary)
  fields <- c(
    if (!is.null(basis$universe)) c("Universe" = basis$universe),
    if (!is.null(basis$assumed)) c("Assumption-backed facts" = basis$assumed),
    "Stale-mark horizon" = basis$horizon,
    "Exhausted marks" = summary$exhausted,
    "Stale instrument-sessions" = as.character(summary$stale_instrument_sessions),
    "Frozen instrument-sessions" = as.character(summary$frozen_instrument_sessions),
    "Longest freeze" = sprintf("%d session%s", summary$longest_freeze_sessions, if (summary$longest_freeze_sessions == 1L) "" else "s"),
    "Max frozen value" = ledgr_corporate_action_value(round(summary$max_frozen_gross_value, 2)),
    "Max frozen weight" = ledgr_valuation_percent(summary$max_frozen_equity_weight),
    "Frozen at end" = sprintf(
      "%d holdings, %s (%s of equity)",
      summary$frozen_at_end_count,
      ledgr_corporate_action_value(round(summary$frozen_at_end_value, 2)),
      ledgr_valuation_percent(summary$frozen_at_end_weight)
    ),
    "Return if frozen worthless" = ledgr_valuation_percent(summary$total_return_if_frozen_worthless)
  )
  for (label in names(fields)) {
    cat(sprintf("  %-28s %s\n", paste0(label, ":"), fields[[label]]))
  }
  rows <- summary$history_policy
  if (!is.null(rows)) {
    cat("\nHistory Policy:\n")
    cat(sprintf(
      "  %-28s %s (%s)\n",
      paste0(toupper(substring(rows$label, 1L, 1L)), substring(rows$label, 2L), ":"),
      rows$value,
      ifelse(rows$default, "default", "declared")
    ), sep = "")
  }
  invisible(summary)
}

# One unavoidable warning, printed before metrics, whenever a holding froze or
# a terminal outcome rested on an assumption rather than settlement evidence.
# There is deliberately no materiality threshold.
ledgr_result_assumption_warning <- function(valuation, corporate) {
  plural <- function(n, word) sprintf("%d %s%s", n, word, if (n == 1L) "" else "s")
  lines <- character()
  if (isTRUE(valuation$frozen_instrument_sessions > 0L)) {
    lines <- c(lines, sprintf(
      "  Frozen valuation: %s carried at the last close beyond max_sessions = %d for %s (exhausted = \"%s\"%s).",
      plural(valuation$frozen_instruments, "holding"),
      valuation$max_sessions,
      plural(valuation$frozen_instrument_sessions, "instrument-session"),
      valuation$exhausted,
      if (identical(valuation$exhausted, "freeze")) ", the default" else ""
    ))
    if (valuation$frozen_at_end_count > 0L) {
      lines <- c(lines, sprintf(
        "  Still frozen at end: %s worth %s (%s of final equity); total return if worthless: %s.",
        plural(valuation$frozen_at_end_count, "holding"),
        ledgr_corporate_action_value(round(valuation$frozen_at_end_value, 2)),
        ledgr_valuation_percent(valuation$frozen_at_end_weight),
        ledgr_valuation_percent(valuation$total_return_if_frozen_worthless)
      ))
    }
  }
  outcomes <- corporate$terminal_outcomes
  if (is.data.frame(outcomes) && nrow(outcomes) > 0L) {
    assumed <- outcomes[outcomes$assumption != "evidence", , drop = FALSE]
    if (nrow(assumed) > 0L) {
      lines <- c(
        lines,
        sprintf("  Assumed terminal outcomes: %d.", nrow(assumed)),
        sprintf(
          "    %s %s: %s (%s).",
          assumed$instrument_id,
          format(assumed$ts_utc, "%Y-%m-%d", tz = "UTC"),
          assumed$assumption_label,
          ledgr_terminal_assumption_argument(assumed$choice, assumed$basis, assumed$matched_label)
        )
      )
    }
  }
  if (length(lines) == 0L) return(character())
  c("WARNING: this result relies on declared valuation or terminal assumptions.", lines)
}

ledgr_print_result_assumption_warning <- function(valuation, corporate) {
  lines <- ledgr_result_assumption_warning(valuation, corporate)
  if (length(lines) == 0L) return(invisible(lines))
  cat(lines, sep = "\n")
  cat("\n")
  invisible(lines)
}

# Compact valuation and terminal-assumption flags carried by selection
# surfaces (run lists, comparisons, sweeps, sweep review and walk-forward).
ledgr_assumption_flags <- function(valuation, assumed_terminal_outcomes) {
  list(
    valuation_state = valuation$valuation_state,
    frozen_instrument_sessions = as.integer(valuation$frozen_instrument_sessions),
    max_frozen_equity_weight = as.numeric(valuation$max_frozen_equity_weight),
    frozen_at_end_value = as.numeric(valuation$frozen_at_end_value),
    assumed_terminal_outcomes = as.integer(assumed_terminal_outcomes)
  )
}

ledgr_assumption_flags_from_memory <- function(policy, diagnostics, equity) {
  inputs <- ledgr_valuation_inputs_from_diagnostics(diagnostics)
  valuation <- ledgr_valuation_summary_compute(
    policy,
    inputs$stale,
    inputs$frozen,
    data.frame(ts_utc = equity$ts_utc, equity = as.numeric(equity$equity))
  )
  ledgr_assumption_flags(valuation, inputs$assumed_terminal_outcomes)
}

ledgr_assumption_flags_for_run <- function(bt, con) {
  if (!ledgr_availability_config_active(bt$config)) return(NULL)
  valuation <- ledgr_valuation_summary_evidence(bt, con)
  assumed <- DBI::dbGetQuery(
    con,
    paste(
      "SELECT COUNT(*) AS n FROM run_diagnostics WHERE run_id = ?",
      "AND stage = 'valuation' AND reason_code = 'terminal_disposition'"
    ),
    params = list(bt$run_id)
  )$n
  ledgr_assumption_flags(valuation, assumed)
}

# Typed columns derived from stored completion JSON. Every selection table
# that keeps completion_json exposes the same columns, whether the row came
# from a live sweep, a reopened sweep or a walk-forward score.
ledgr_completion_columns <- function(completion_json) {
  json <- as.character(completion_json)
  keys <- unique(json[!is.na(json) & nzchar(json)])
  parsed <- lapply(keys, ledgr_json_read_nested)
  idx <- match(json, keys)
  have <- !is.na(idx)
  pick <- function(read, default) {
    out <- rep(default, length(json))
    if (length(keys) == 0L) return(out)
    values <- vapply(parsed, function(p) {
      value <- read(p)
      if (is.null(value) || length(value) != 1L || is.na(value)) default else as.vector(value, mode = typeof(default))
    }, default)
    out[have] <- values[idx[have]]
    out
  }
  # No completion evidence reads as NA, matching ledgr_run_list().
  affected <- rep(list(NA_character_), length(json))
  if (length(keys) > 0L) {
    parsed_ids <- lapply(parsed, function(p) as.character(unlist(p$affected_instrument_ids)))
    affected[have] <- parsed_ids[idx[have]]
  }
  tibble::tibble(
    stop_reason = pick(function(p) p$stop_reason, NA_character_),
    affected_instrument_ids = affected,
    valuation_state = pick(function(p) p$assumptions$valuation_state, NA_character_),
    frozen_instrument_sessions = pick(function(p) p$assumptions$frozen_instrument_sessions, NA_integer_),
    max_frozen_equity_weight = pick(function(p) p$assumptions$max_frozen_equity_weight, NA_real_),
    frozen_at_end_value = pick(function(p) p$assumptions$frozen_at_end_value, NA_real_),
    assumed_terminal_outcomes = pick(function(p) p$assumptions$assumed_terminal_outcomes, NA_integer_)
  )
}

# Inserts the derived columns directly after completion_json.
ledgr_add_completion_columns <- function(x) {
  if (!"completion_json" %in% names(x)) return(x)
  derived <- ledgr_completion_columns(x$completion_json)
  base <- x[setdiff(names(x), names(derived))]
  at <- match("completion_json", names(base))
  out <- c(as.list(base)[seq_len(at)], as.list(derived), as.list(base)[-seq_len(at)])
  attrs <- attributes(x)
  result <- tibble::as_tibble(out)
  for (name in setdiff(names(attrs), c("names", "row.names", "class"))) {
    attr(result, name) <- attrs[[name]]
  }
  class(result) <- class(x)
  result
}

# Attempted, done, incomplete and failed counts plus the compact flag counts
# among completed rows. Counts are disclosure only; they never enter
# effective-trial or DSR inputs.
ledgr_selection_counts <- function(status, valuation_state = NULL, assumed = NULL) {
  status <- as.character(status)
  done <- status %in% "DONE"
  list(
    attempted = length(status),
    done = sum(done),
    incomplete = sum(status %in% "INCOMPLETE"),
    failed = sum(status %in% "FAILED"),
    other = sum(!status %in% c("DONE", "INCOMPLETE", "FAILED")),
    frozen_done = if (is.null(valuation_state)) 0L else sum(done & valuation_state %in% "frozen"),
    assumed_done = if (is.null(assumed)) 0L else sum(done & !is.na(assumed) & assumed > 0L)
  )
}

# Count lines for a printed table; none when the caller selected `status`
# away. Optional flag columns are read without partial-name warnings.
ledgr_selection_table_lines <- function(x, noun = "candidates") {
  status <- x[["status"]]
  if (is.null(status)) return(character())
  rows <- seq_along(status)
  pick <- function(name) {
    value <- x[[name]]
    if (is.null(value)) NULL else value[rows]
  }
  ledgr_selection_count_lines(
    ledgr_selection_counts(status, pick("valuation_state"), pick("assumed_terminal_outcomes")),
    noun = noun
  )
}

ledgr_selection_count_lines <- function(counts, noun = "candidates") {
  c(
    sprintf(
      "%d %s attempted: %d done, %d incomplete, %d failed%s.",
      counts$attempted, noun, counts$done, counts$incomplete, counts$failed,
      if (counts$other > 0L) sprintf(", %d not finished", counts$other) else ""
    ),
    if (counts$frozen_done > 0L || counts$assumed_done > 0L) {
      sprintf(
        "Of the done %s, %d froze a holding and %d used an assumed terminal outcome; see valuation_state and assumed_terminal_outcomes.",
        noun, counts$frozen_done, counts$assumed_done
      )
    }
  )
}

# Compact flags for many stored runs with one grouped diagnostics query; only
# runs that froze a holding read their frozen rows and equity.
ledgr_run_assumption_flags_many <- function(con, run_ids) {
  run_ids <- as.character(run_ids)
  out <- tibble::tibble(
    run_id = run_ids,
    valuation_state = rep(NA_character_, length(run_ids)),
    frozen_instrument_sessions = rep(NA_integer_, length(run_ids)),
    max_frozen_equity_weight = rep(NA_real_, length(run_ids)),
    frozen_at_end_value = rep(NA_real_, length(run_ids)),
    assumed_terminal_outcomes = rep(NA_integer_, length(run_ids))
  )
  if (length(run_ids) == 0L) {
    return(out)
  }
  quoted <- paste(DBI::dbQuoteString(con, unique(run_ids)), collapse = ", ")
  grouped <- DBI::dbGetQuery(
    con,
    sprintf(
      paste(
        "SELECT run_id,",
        "COUNT(*) FILTER (WHERE stage = 'decision') AS decisions,",
        "COUNT(*) FILTER (WHERE stage = 'decision' AND quantity <> 0 AND mark_source = 'stale_close') AS stale,",
        "COUNT(*) FILTER (WHERE stage = 'decision' AND quantity <> 0 AND mark_source = 'frozen_close') AS frozen,",
        "COUNT(*) FILTER (WHERE stage = 'valuation' AND reason_code = 'terminal_disposition') AS assumed",
        "FROM run_diagnostics WHERE run_id IN (%s) GROUP BY run_id"
      ),
      quoted
    )
  )
  grouped <- grouped[grouped$decisions > 0, , drop = FALSE]
  if (nrow(grouped) == 0L) return(out)
  # Map every output row, so a run ID repeated by ledgr_run_compare() gets
  # its flags on each row.
  at <- match(out$run_id, grouped$run_id)
  hit <- !is.na(at)
  g <- grouped[at[hit], , drop = FALSE]
  out$valuation_state[hit] <- ifelse(
    g$frozen > 0, "frozen", ifelse(g$stale > 0, "stale", "current")
  )
  out$frozen_instrument_sessions[hit] <- as.integer(g$frozen)
  out$max_frozen_equity_weight[hit] <- 0
  out$frozen_at_end_value[hit] <- 0
  out$assumed_terminal_outcomes[hit] <- as.integer(g$assumed)
  frozen_runs <- as.character(grouped$run_id[grouped$frozen > 0])
  if (length(frozen_runs) > 0L) {
    frozen_quoted <- paste(DBI::dbQuoteString(con, frozen_runs), collapse = ", ")
    frozen <- DBI::dbGetQuery(
      con,
      sprintf(
        paste(
          "SELECT run_id, ts_utc, instrument_id, quantity, price",
          "FROM run_diagnostics WHERE run_id IN (%s)",
          "AND stage = 'decision' AND quantity <> 0",
          "AND mark_source = 'frozen_close'",
          "ORDER BY run_id, instrument_id, ts_utc"
        ),
        frozen_quoted
      )
    )
    equity <- DBI::dbGetQuery(
      con,
      sprintf(
        paste(
          "SELECT run_id, ts_utc, equity FROM equity_curve",
          "WHERE run_id IN (%s) ORDER BY run_id, ts_utc"
        ),
        frozen_quoted
      )
    )
    frozen_by_run <- split(frozen, as.character(frozen$run_id), drop = TRUE)
    equity_by_run <- split(equity, as.character(equity$run_id), drop = TRUE)
    zero_stale <- data.frame(
      sessions = 0L,
      instruments = 0L,
      longest_age = NA_integer_
    )
    valuations <- lapply(frozen_runs, function(run_id) {
      ledgr_valuation_summary_compute(
        list(),
        zero_stale,
        frozen_by_run[[run_id]] %||% frozen[FALSE, , drop = FALSE],
        equity_by_run[[run_id]] %||% equity[FALSE, , drop = FALSE]
      )
    })
    names(valuations) <- frozen_runs
    frozen_at <- match(out$run_id, frozen_runs)
    frozen_hit <- !is.na(frozen_at)
    out$max_frozen_equity_weight[frozen_hit] <- vapply(
      valuations[frozen_at[frozen_hit]],
      function(x) x$max_frozen_equity_weight,
      numeric(1)
    )
    out$frozen_at_end_value[frozen_hit] <- vapply(
      valuations[frozen_at[frozen_hit]],
      function(x) x$frozen_at_end_value,
      numeric(1)
    )
  }
  out
}
