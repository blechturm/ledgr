ledgr_availability_validate_inputs <- function(facts,
                                               bars_df,
                                               instruments_df,
                                               invalid_observations) {
  facts <- ledgr_facts_unwrap_validated(facts)
  session_family <- ledgr_session_family(facts)
  session_rows <- ledgr_session_open_rows_validated(facts)
  instruments <- ledgr_availability_prepare_instruments(bars_df, instruments_df)
  observations <- ledgr_availability_prepare_observations(
    bars_df,
    instruments$instrument_id,
    facts,
    session_rows = session_rows
  )
  fact_rows <- ledgr_availability_fact_report(facts, instruments$instrument_id)

  structural_observation <- observations$report$outcome == "rejected"
  quarantine_candidate <- observations$report$outcome == "quarantine_candidate"
  fact_rejected <- fact_rows$outcome == "rejected"
  sessions_declared <- !is.null(session_family)
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
    quarantine_rows = quarantine,
    off_session_rows = observations$off_session
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

ledgr_availability_prepare_observations <- function(bars_df,
                                                    instrument_ids,
                                                    facts,
                                                    session_rows = ledgr_session_open_rows(facts)) {
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
  ts <- ledgr_availability_observation_times(
    bars_df$ts_utc,
    facts,
    session_rows = session_rows
  )
  # Bars share few distinct instants; each is formatted once.
  ts_token <- ledgr_fact_time_tokens_distinct(ts)
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
  # A price that is zero or negative once stored (rounded to 8 digits) can
  # never be a mark; zero volume with positive prices stays valid.
  non_positive <- Reduce(`|`, lapply(numeric_values, function(x) round(x, 8L) <= 0))
  set_reason(non_positive, "ohlc_non_positive")
  max_ohlc <-pmax(numeric_values$open, numeric_values$close, numeric_values$low, na.rm = TRUE)
  min_ohlc <- pmin(numeric_values$open, numeric_values$close, numeric_values$high, na.rm = TRUE)
  set_reason(numeric_values$high < max_ohlc | numeric_values$low > min_ohlc, "ohlc_invalid")
  outside_expectation <- !is.na(ts) & !ledgr_availability_times_are_session_closes(
    ts,
    facts,
    session_rows = session_rows,
    tokens = ts_token
  )

  valid_before_duplicates <- reason == ""
  key <- ledgr_pair_key(instrument_id, ts_token)
  duplicate_key <- duplicated(key) | duplicated(key, fromLast = TRUE)
  structural_duplicate <- valid_before_duplicates & duplicate_key
  set_reason(structural_duplicate, "duplicate_valid_observation_key")
  outcome <- ifelse(reason == "", "accepted", "quarantine_candidate")
  outcome[reason == "duplicate_valid_observation_key"] <- "rejected"

  report <- tibble::tibble(
    row = seq_len(n),
    instrument_id = instrument_id,
    ts_utc = ts_token,
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
  quarantine <- ledgr_availability_evidence_rows(
    bars_df, which(bad), instrument_id[bad], ts[bad], reason[bad],
    list(source = "ledgr_snapshot_from_df")
  )
  # A valid bar off every declared open-session close seals but is never a
  # pulse; it is recorded as observation evidence so it stays visible.
  # Built column-wise: a vendor whose stamps miss the calendar can make most
  # bars off-session. The id is the (instrument, time) key, unique because
  # duplicate keys are refused above.
  off_session <- keep & outside_expectation
  off_session_rows <- data.frame(
    quarantine_id = paste0("off_session_", instrument_id[off_session], "@", ts_token[off_session], recycle0 = TRUE),
    supplied_instrument_id = instrument_id[off_session],
    supplied_ts_utc = as.POSIXct(ts[off_session], tz = "UTC"),
    reason = rep(ledgr_off_session_reason, sum(off_session)),
    original_row_json = ledgr_availability_original_rows_json(bars_df[off_session, , drop = FALSE]),
    provenance_json = rep(as.character(canonical_json(list(
      source = "ledgr_snapshot_from_df", disposition = "sealed_not_a_pulse"
    ))), sum(off_session)),
    stringsAsFactors = FALSE
  )
  list(accepted = accepted, quarantine = quarantine, off_session = off_session_rows, report = report)
}

ledgr_off_session_reason <- "off_session_bar"

# Observation-evidence rows (the quarantine table's shape) for the supplied
# rows `rows` of `bars_df`; `instrument_id`, `ts` and `reason` are already
# subset to those rows. Built per row for quarantine candidates (invalid bars),
# whose digest ids and saved copies enter the hash; off-session rows, which
# can be most bars, are built column-wise above.
ledgr_availability_evidence_rows <- function(bars_df, rows, instrument_id, ts, reason, provenance) {
  n <- length(rows)
  out <- data.frame(
    quarantine_id = character(n),
    supplied_instrument_id = instrument_id,
    supplied_ts_utc = as.POSIXct(ts, tz = "UTC"),
    reason = reason,
    original_row_json = vapply(rows, function(i) ledgr_availability_original_row_json(bars_df[i, , drop = FALSE]), character(1)),
    provenance_json = rep(as.character(canonical_json(provenance)), n),
    stringsAsFactors = FALSE
  )
  if (n > 0L) {
    out$quarantine_id <- vapply(seq_len(n), function(i) {
      payload <- ledgr_fact_row_payload(out[i, setdiff(names(out), "quarantine_id"), drop = FALSE])
      paste0("quarantine_", substr(digest::digest(as.character(canonical_json(payload)), algo = "sha256"), 1L, 32L))
    }, character(1))
    if (anyDuplicated(out$quarantine_id)) {
      rlang::abort(
        "Duplicate invalid observations cannot be quarantined ambiguously.",
        class = c("ledgr_observation_quarantine_duplicate", "ledgr_invalid_args")
      )
    }
  }
  out
}

ledgr_availability_observation_times <- function(x,
                                                 facts,
                                                 session_rows = NULL) {
  if (is.null(session_rows)) {
    session_family <- ledgr_session_family(facts)
    session_rows <- if (is.null(session_family)) NULL else session_family$rows
  }
  date_labels <- inherits(x, "Date") ||
    (is.character(x) && all(is.na(x) | grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", x)))
  if (isTRUE(date_labels) && !is.null(session_rows)) {
    dates <- suppressWarnings(as.Date(as.character(x), format = "%Y-%m-%d"))
    idx <- match(as.character(dates), as.character(session_rows$session_date))
    out <- as.POSIXct(rep(NA_real_, length(dates)), origin = "1970-01-01", tz = "UTC")
    mapped <- !is.na(idx) & session_rows$status[idx] == "open"
    out[mapped] <- session_rows$session_close[idx[mapped]]
    return(out)
  }
  distinct <- unique(x)
  parsed <- vapply(seq_along(distinct), function(i) {
    as.numeric(tryCatch(
      ledgr_fact_time(distinct[i], "ts_utc", allow_missing = TRUE)[[1L]],
      error = function(e) as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC")
    ))
  }, numeric(1L))
  as.POSIXct(parsed[match(x, distinct)], origin = "1970-01-01", tz = "UTC")
}

ledgr_availability_times_are_session_closes <- function(
    ts,
    facts,
    session_rows = ledgr_session_open_rows(facts),
    tokens = ledgr_fact_time_token(ts)) {
  if (is.null(session_rows)) return(rep(TRUE, length(ts)))
  tokens %in% ledgr_fact_time_token(session_rows$session_close)
}

# ledgr_availability_original_row_json() for every row of `df` at once: the
# columns are formatted once, keys sorted, and the frame written as NDJSON,
# one canonical object per row, byte-identical to the per-row form; text is
# written as UTF-8 in both. A row holding an infinite value in an extra column,
# which the per-row form writes as a string, is rewritten by that form; only
# such rows are visited.
ledgr_availability_original_rows_json <- function(df) {
  if (nrow(df) == 0L) return(character())
  infinite <- Reduce(`|`, lapply(df, function(x) if (is.numeric(x)) is.infinite(x) else rep(FALSE, nrow(df))), rep(FALSE, nrow(df)))
  cols <- lapply(df, function(x) {
    if (inherits(x, "POSIXt")) return(ledgr_fact_time_tokens_distinct(x))
    if (inherits(x, "Date")) return(as.character(x))
    if (is.factor(x)) x <- as.character(x)
    if (is.character(x)) return(enc2utf8(unname(x)))
    unname(x)
  })
  frame <- as.data.frame(cols[order(names(cols))], stringsAsFactors = FALSE, optional = TRUE)
  lines <- strsplit(yyjsonr::write_ndjson_str(frame, opts = .ledgr_json_write_canonical_v2_opts), "\n", fixed = TRUE)[[1L]]
  lines <- lines[nzchar(lines)]
  # The per-row form writes an infinite value as a string; only those rows
  # take it.
  for (i in which(infinite)) lines[[i]] <- ledgr_availability_original_row_json(df[i, , drop = FALSE])
  lines
}

ledgr_availability_original_row_json <- function(row) {
  payload <- lapply(row, function(x) {
    value <- x[[1L]]
    if (inherits(value, "POSIXt")) return(ledgr_fact_time_token(value))
    if (inherits(value, "Date")) return(as.character(value))
    if (length(value) == 0L || is.na(value)) return(NULL)
    if (is.numeric(value) && !is.finite(value)) return(as.character(value))
    if (is.factor(value)) value <- as.character(value)
    # The JSON writer requires UTF-8 text.
    if (is.character(value)) value <- enc2utf8(value)
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
    instrument <- if ("instrument_id" %in% names(rows)) {
      rows$instrument_id
    } else if (identical(fact_family$family, "equity_corporate_actions")) {
      rows$parent_instrument_id
    } else {
      rep(NA_character_, nrow(rows))
    }
    outcome <- rep("accepted", nrow(rows))
    reason <- rep("accepted", nrow(rows))
    audit <- "knowledge_time" %in% names(rows) & is.na(rows$knowledge_time)
    outcome[audit] <- "audit_only"
    reason[audit] <- "knowledge_time_missing"
    unknown <- !is.na(instrument) & !instrument %in% instrument_ids
    outcome[unknown] <- "rejected"
    reason[unknown] <- "instrument_unknown"
    if (identical(fact_family$family, "equity_corporate_actions")) {
      recipient <- rows$recipient_instrument_id
      recipient_unknown <- !is.na(recipient) & !recipient %in% instrument_ids
      outcome[recipient_unknown] <- "rejected"
      reason[recipient_unknown] <- "recipient_instrument_unknown"
    }
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

# An exact numeric key for (a, b) pairs, equal exactly when the text of both
# components is equal, as a pasted key would be (paste renders NA as "NA").
# Only distinct values are rendered as text, never every row.
ledgr_pair_key <- function(a, b) {
  text_code <- function(x) {
    distinct <- unique(x)
    text <- as.character(distinct)
    text[is.na(text)] <- "NA"
    match(text, unique(text))[match(x, distinct)]
  }
  code_a <- text_code(a)
  code_b <- text_code(b)
  (code_a - 1) * max(code_b, 0L) + code_b
}
