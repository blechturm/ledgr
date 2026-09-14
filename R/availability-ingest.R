ledgr_availability_validate_inputs <- function(facts,
                                               bars_df,
                                               instruments_df,
                                               invalid_observations) {
  facts <- ledgr_facts_assert(facts)
  instruments <- ledgr_availability_prepare_instruments(bars_df, instruments_df)
  observations <- ledgr_availability_prepare_observations(
    bars_df,
    instruments$instrument_id,
    facts
  )
  fact_rows <- ledgr_availability_fact_report(facts, instruments$instrument_id)

  structural_observation <- observations$report$outcome == "rejected"
  quarantine_candidate <- observations$report$outcome == "quarantine_candidate"
  fact_rejected <- fact_rows$outcome == "rejected"
  sessions_declared <- !is.null(ledgr_session_family(facts))
  quarantine_allowed <- identical(invalid_observations, "quarantine") && sessions_declared
  observation_blocked <- any(structural_observation) ||
    (any(quarantine_candidate) && !isTRUE(quarantine_allowed))
  can_seal <- !observation_blocked && !any(fact_rejected) && nrow(observations$accepted) > 0L

  if (identical(invalid_observations, "quarantine") && !sessions_declared) {
    can_seal <- FALSE
    observations$report <- rbind(
      observations$report,
      tibble::tibble(
        row = NA_integer_,
        instrument_id = NA_character_,
        ts_utc = NA_character_,
        outcome = "rejected",
        reason = "quarantine_requires_sessions"
      )
    )
  }
  if (nrow(observations$accepted) == 0L) {
    can_seal <- FALSE
  }

  quarantine <- if (isTRUE(quarantine_allowed)) observations$quarantine else observations$quarantine[0, , drop = FALSE]
  summary <- ledgr_availability_validation_summary(fact_rows, observations$report)
  list(
    can_seal = isTRUE(can_seal),
    invalid_observations = invalid_observations,
    summary = summary,
    facts = fact_rows,
    observations = observations$report,
    prepared_bars = observations$accepted,
    prepared_instruments = instruments,
    quarantine_rows = quarantine
  )
}

ledgr_availability_prepare_instruments <- function(bars_df, instruments_df) {
  if (!is.data.frame(bars_df)) {
    rlang::abort("`bars_df` must be a data.frame (or tibble).", class = "ledgr_invalid_args")
  }
  if (!"instrument_id" %in% names(bars_df)) {
    rlang::abort("bars_df missing required column(s): instrument_id.", class = "ledgr_invalid_args")
  }
  bar_ids <- enc2utf8(as.character(bars_df$instrument_id))
  if (is.null(instruments_df)) {
    ids <- sort(unique(bar_ids[!is.na(bar_ids) & nzchar(bar_ids)]))
    if (length(ids) == 0L) {
      rlang::abort("At least one valid instrument is required.", class = c("ledgr_fact_invalid_instrument_master", "ledgr_invalid_args"))
    }
    return(data.frame(
      instrument_id = ids,
      symbol = ids,
      currency = rep("USD", length(ids)),
      asset_class = rep("EQUITY", length(ids)),
      multiplier = rep(1, length(ids)),
      tick_size = rep(0.01, length(ids)),
      stringsAsFactors = FALSE
    ))
  }
  if (!is.data.frame(instruments_df) || !"instrument_id" %in% names(instruments_df)) {
    rlang::abort(
      "`instruments_df` must be a data frame containing `instrument_id`.",
      class = c("ledgr_fact_invalid_instrument_master", "ledgr_invalid_args")
    )
  }
  ids <- enc2utf8(as.character(instruments_df$instrument_id))
  if (anyNA(ids) || any(!nzchar(trimws(ids))) || anyDuplicated(ids)) {
    rlang::abort(
      "Instrument master IDs must be non-empty and unique.",
      class = c("ledgr_fact_invalid_instrument_master", "ledgr_invalid_args")
    )
  }
  instruments_df
}

ledgr_availability_prepare_observations <- function(bars_df, instrument_ids, facts) {
  required <- c("instrument_id", "ts_utc", "open", "high", "low", "close")
  missing <- setdiff(required, names(bars_df))
  if (length(missing) > 0L) {
    rlang::abort(
      sprintf("bars_df missing required column(s): %s.", paste(missing, collapse = ", ")),
      class = c("ledgr_observation_invalid_shape", "ledgr_invalid_args"),
      missing_columns = missing
    )
  }
  n <- nrow(bars_df)
  if (n == 0L) {
    rlang::abort("`bars_df` must contain at least one row.", class = c("ledgr_observation_invalid_shape", "ledgr_invalid_args"))
  }
  instrument_id <- enc2utf8(as.character(bars_df$instrument_id))
  ts <- ledgr_availability_observation_times(bars_df$ts_utc, facts)
  numeric_values <- lapply(c("open", "high", "low", "close"), function(field) suppressWarnings(as.numeric(bars_df[[field]])))
  names(numeric_values) <- c("open", "high", "low", "close")
  volume <- if ("volume" %in% names(bars_df)) suppressWarnings(as.numeric(bars_df$volume)) else rep(NA_real_, n)
  reason <- rep("", n)
  set_reason <- function(which_rows, value) {
    idx <- which(which_rows & reason == "")
    if (length(idx) > 0L) reason[idx] <<- value
  }
  set_reason(is.na(instrument_id) | !nzchar(trimws(instrument_id)), "instrument_id_invalid")
  set_reason(!instrument_id %in% instrument_ids, "instrument_unknown")
  set_reason(is.na(ts), "timestamp_invalid")
  bad_numeric <- Reduce(`|`, lapply(numeric_values, function(x) is.na(x) | !is.finite(x)))
  set_reason(bad_numeric, "ohlc_non_finite")
  set_reason(!is.na(volume) & !is.finite(volume), "volume_non_finite")
  max_ohlc <- pmax(numeric_values$open, numeric_values$close, numeric_values$low, na.rm = TRUE)
  min_ohlc <- pmin(numeric_values$open, numeric_values$close, numeric_values$high, na.rm = TRUE)
  set_reason(numeric_values$high < max_ohlc | numeric_values$low > min_ohlc, "ohlc_invalid")
  outside_expectation <- !is.na(ts) & !ledgr_availability_times_are_session_closes(ts, facts)

  valid_before_duplicates <- reason == ""
  key <- paste(instrument_id, ledgr_fact_time_token(ts), sep = "\r")
  duplicate_key <- duplicated(key) | duplicated(key, fromLast = TRUE)
  structural_duplicate <- valid_before_duplicates & duplicate_key
  set_reason(structural_duplicate, "duplicate_valid_observation_key")
  outcome <- ifelse(reason == "", "accepted", "quarantine_candidate")
  outcome[reason == "duplicate_valid_observation_key"] <- "rejected"

  report <- tibble::tibble(
    row = seq_len(n),
    instrument_id = instrument_id,
    ts_utc = ledgr_fact_time_token(ts),
    outcome = outcome,
    reason = ifelse(
      reason == "" & outside_expectation,
      "observed_row_outside_expectation",
      ifelse(reason == "", "accepted", reason)
    )
  )
  keep <- outcome == "accepted"
  accepted <- data.frame(
    instrument_id = instrument_id[keep],
    ts_utc = as.POSIXct(ts[keep], tz = "UTC"),
    open = round(numeric_values$open[keep], 8L),
    high = round(numeric_values$high[keep], 8L),
    low = round(numeric_values$low[keep], 8L),
    close = round(numeric_values$close[keep], 8L),
    volume = round(volume[keep], 8L),
    stringsAsFactors = FALSE
  )
  accepted <- accepted[order(accepted$instrument_id, accepted$ts_utc), , drop = FALSE]
  rownames(accepted) <- NULL

  bad <- outcome == "quarantine_candidate"
  quarantine <- data.frame(
    quarantine_id = character(sum(bad)),
    supplied_instrument_id = instrument_id[bad],
    supplied_ts_utc = as.POSIXct(ts[bad], tz = "UTC"),
    reason = reason[bad],
    original_row_json = vapply(which(bad), function(i) ledgr_availability_original_row_json(bars_df[i, , drop = FALSE]), character(1)),
    provenance_json = rep(as.character(canonical_json(list(source = "ledgr_snapshot_from_df"))), sum(bad)),
    stringsAsFactors = FALSE
  )
  if (nrow(quarantine) > 0L) {
    quarantine$quarantine_id <- vapply(seq_len(nrow(quarantine)), function(i) {
      payload <- ledgr_fact_row_payload(quarantine[i, setdiff(names(quarantine), "quarantine_id"), drop = FALSE])
      paste0("quarantine_", substr(digest::digest(as.character(canonical_json(payload)), algo = "sha256"), 1L, 32L))
    }, character(1))
    if (anyDuplicated(quarantine$quarantine_id)) {
      rlang::abort(
        "Duplicate invalid observations cannot be quarantined ambiguously.",
        class = c("ledgr_observation_quarantine_duplicate", "ledgr_invalid_args")
      )
    }
  }
  list(accepted = accepted, quarantine = quarantine, report = report)
}

ledgr_availability_observation_times <- function(x, facts) {
  session_family <- ledgr_session_family(facts)
  date_labels <- inherits(x, "Date") ||
    (is.character(x) && all(is.na(x) | grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", x)))
  if (isTRUE(date_labels) && !is.null(session_family)) {
    dates <- suppressWarnings(as.Date(as.character(x), format = "%Y-%m-%d"))
    rows <- session_family$rows
    idx <- match(as.character(dates), as.character(rows$session_date))
    out <- as.POSIXct(rep(NA_real_, length(dates)), origin = "1970-01-01", tz = "UTC")
    mapped <- !is.na(idx) & rows$status[idx] == "open"
    out[mapped] <- rows$session_close[idx[mapped]]
    return(out)
  }
  out <- as.POSIXct(rep(NA_real_, length(x)), origin = "1970-01-01", tz = "UTC")
  for (i in seq_along(x)) {
    out[[i]] <- tryCatch(
      ledgr_fact_time(x[i], "ts_utc", allow_missing = TRUE)[[1L]],
      error = function(e) as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC")
    )
  }
  out
}

ledgr_availability_times_are_session_closes <- function(ts, facts) {
  rows <- ledgr_session_open_rows(facts)
  if (is.null(rows)) return(rep(TRUE, length(ts)))
  tokens <- ledgr_fact_time_token(ts)
  tokens %in% ledgr_fact_time_token(rows$session_close)
}

ledgr_availability_original_row_json <- function(row) {
  payload <- lapply(row, function(x) {
    value <- x[[1L]]
    if (inherits(value, "POSIXt")) return(ledgr_fact_time_token(value))
    if (inherits(value, "Date")) return(as.character(value))
    if (length(value) == 0L || is.na(value)) return(NULL)
    if (is.numeric(value) && !is.finite(value)) return(as.character(value))
    unname(value)
  })
  as.character(canonical_json(payload))
}

ledgr_availability_fact_report <- function(facts, instrument_ids) {
  out <- list()
  index <- 0L
  for (fact_family in facts$families) {
    rows <- fact_family$rows
    if (nrow(rows) == 0L) next
    fact_ids <- if ("fact_id" %in% names(rows)) {
      rows$fact_id
    } else {
      paste0(fact_family$family, "_", seq_len(nrow(rows)))
    }
    instrument <- if ("instrument_id" %in% names(rows)) rows$instrument_id else rep(NA_character_, nrow(rows))
    outcome <- rep("accepted", nrow(rows))
    reason <- rep("accepted", nrow(rows))
    audit <- "knowledge_time" %in% names(rows) & is.na(rows$knowledge_time)
    outcome[audit] <- "audit_only"
    reason[audit] <- "knowledge_time_missing"
    unknown <- !is.na(instrument) & !instrument %in% instrument_ids
    outcome[unknown] <- "rejected"
    reason[unknown] <- "instrument_unknown"
    if (identical(fact_family$family, "trading_status")) {
      conflict <- fact_ids %in% ledgr_status_runtime_conflicts(rows)
      retained_conflict <- conflict & !unknown & outcome == "accepted"
      outcome[retained_conflict] <- "runtime_conflict"
      reason[retained_conflict] <- "status_unknown_or_conflicting"
    }
    index <- index + 1L
    out[[index]] <- tibble::tibble(
      family = fact_family$family,
      scope_id = fact_family$scope_id,
      fact_id = fact_ids,
      instrument_id = instrument,
      outcome = outcome,
      reason = reason
    )
  }
  if (length(out) == 0L) {
    return(tibble::tibble(
      family = character(), scope_id = character(), fact_id = character(),
      instrument_id = character(), outcome = character(), reason = character()
    ))
  }
  do.call(rbind, out)
}

ledgr_availability_validation_summary <- function(fact_rows, observations) {
  fact_counts <- table(factor(fact_rows$outcome, levels = c("accepted", "runtime_conflict", "audit_only", "rejected")))
  observation_counts <- table(factor(observations$outcome, levels = c("accepted", "quarantine_candidate", "rejected")))
  tibble::tibble(
    category = c(
      paste0("facts_", names(fact_counts)),
      paste0("observations_", names(observation_counts))
    ),
    n = as.integer(c(fact_counts, observation_counts))
  )
}

ledgr_availability_abort_validation <- function(report) {
  rejected <- report$facts[report$facts$outcome == "rejected", , drop = FALSE]
  observations <- report$observations[report$observations$outcome != "accepted", , drop = FALSE]
  reason <- if (nrow(rejected) > 0L) rejected$reason[[1L]] else if (nrow(observations) > 0L) observations$reason[[1L]] else "no_valid_observations"
  rlang::abort(
    sprintf("Availability input cannot be sealed: %s.", reason),
    class = c("ledgr_availability_validation_failed", "ledgr_invalid_args"),
    validation = structure(report, class = c("ledgr_facts_report", "list"))
  )
}
