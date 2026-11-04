# The physical diagnostic codec is a store-format rule only. It does not
# participate in economic run identity.
ledgr_diagnostic_codec_rule_version <- 1L

# Every registered attempt has a valid empty logical trace before execution.
# This makes CREATED and crash-orphan RUNNING rows readable without inventing
# a read-time missing-evidence exception.
ledgr_diagnostic_initialize_run <- function(con, run_id) {
  DBI::dbExecute(
    con,
    paste(
      "INSERT INTO run_diagnostic_coverage",
      "(run_id, logical_count, codec_rule_version) VALUES (?, 0, ?)",
      "ON CONFLICT(run_id) DO UPDATE SET logical_count = 0,",
      "codec_rule_version = excluded.codec_rule_version"
    ),
    params = list(run_id, ledgr_diagnostic_codec_rule_version)
  )
  row <- ledgr_diagnostic_summary_from_store(con, run_id)
  row$summary_hash <- ledgr_diagnostic_summary_hash(row)
  DBI::dbExecute(con, "DELETE FROM run_diagnostic_summary WHERE run_id = ?", params = list(run_id))
  ledgr_store_append(con, "run_diagnostic_summary", row)
  invisible(TRUE)
}

ledgr_diagnostic_segment_at <- function(segment, name, index) {
  value <- segment[[name]]
  if (length(value) == 1L) rep_len(value, length(index)) else value[index]
}

# Exact clean-pair certification. The fill ordinals are already context
# ordinals, so this is one indexed comparison rather than a pairwise search.
ledgr_diagnostic_clean_fill <- function(decision, risk, fill, fill_reason) {
  if (length(fill$k) == 0L || decision$n == 0L) return(logical())
  k <- fill$k
  risk_ids <- if (is.null(risk)) character() else
    as.character(ledgr_diagnostic_segment_at(risk, "instrument_id", seq_len(risk$n)))
  instrument <- as.character(ledgr_diagnostic_segment_at(decision, "instrument_id", k))
  target <- as.numeric(ledgr_diagnostic_segment_at(decision, "target", k))
  target_after <- as.numeric(ledgr_diagnostic_segment_at(decision, "target_after_risk", k))
  before <- as.numeric(ledgr_diagnostic_segment_at(decision, "position_before", k))
  decision_after <- as.numeric(ledgr_diagnostic_segment_at(decision, "position_after", k))
  decision_reason <- as.character(ledgr_diagnostic_segment_at(decision, "reason_code", k))
  decision_reasons <- as.character(ledgr_diagnostic_segment_at(decision, "reasons", k))
  decision_price <- as.numeric(ledgr_diagnostic_segment_at(decision, "price", k))
  mark_source <- as.character(ledgr_diagnostic_segment_at(decision, "mark_source", k))
  mark_age <- as.integer(ledgr_diagnostic_segment_at(decision, "mark_age", k))
  is.finite(target) & is.finite(target_after) &
    target == target_after &
    is.finite(before) & is.finite(decision_after) & before == decision_after &
    is.finite(fill$position_before) & before == fill$position_before &
    is.finite(fill$planned_position_after) & target == fill$planned_position_after &
    decision_reason == "decision_recorded" &
    decision_reasons == "decision_recorded" &
    is.finite(decision_price) & mark_source == "current_close" & mark_age == 0L &
    !nzchar(fill_reason$reason) & !nzchar(fill_reason$reasons) &
    !(instrument %in% risk_ids)
}

ledgr_diagnostic_clean_hold <- function(decision, risk, excluded_k = integer()) {
  if (decision$n == 0L) return(logical())
  k <- seq_len(decision$n)
  risk_ids <- if (is.null(risk)) character() else
    as.character(ledgr_diagnostic_segment_at(risk, "instrument_id", seq_len(risk$n)))
  instrument <- as.character(ledgr_diagnostic_segment_at(decision, "instrument_id", k))
  target <- as.numeric(ledgr_diagnostic_segment_at(decision, "target", k))
  target_after <- as.numeric(ledgr_diagnostic_segment_at(decision, "target_after_risk", k))
  before <- as.numeric(ledgr_diagnostic_segment_at(decision, "position_before", k))
  after <- as.numeric(ledgr_diagnostic_segment_at(decision, "position_after", k))
  reason <- as.character(ledgr_diagnostic_segment_at(decision, "reason_code", k))
  reasons <- as.character(ledgr_diagnostic_segment_at(decision, "reasons", k))
  mark_source <- as.character(ledgr_diagnostic_segment_at(decision, "mark_source", k))
  mark_age <- as.integer(ledgr_diagnostic_segment_at(decision, "mark_age", k))
  price <- as.numeric(ledgr_diagnostic_segment_at(decision, "price", k))
  clean <- is.finite(target) & is.finite(target_after) & target == target_after &
    is.finite(before) & is.finite(after) & target == before & before == after &
    is.finite(price) & reason == "decision_recorded" & reasons == "decision_recorded" &
    mark_source == "current_close" & mark_age == 0L &
    !(instrument %in% risk_ids) & !(k %in% excluded_k)
  clean[is.na(clean)] <- FALSE
  clean
}

ledgr_diagnostic_implicit_block <- function(run_id,
                                            decision,
                                            fill,
                                            fill_rows,
                                            decision_seq,
                                            execution_seq,
                                            event_seq,
                                            axis_size) {
  k <- fill$k[fill_rows]
  n <- length(k)
  list(
    n = n,
    run_id = rep_len(as.character(run_id), n),
    decision_seq = as.integer(decision_seq),
    execution_seq = as.integer(execution_seq),
    # One exact pair of context ordinal and run-axis position. The decoder
    # anchors the axis half to the stored run universe and the context half to
    # fixed-axis identity or the sealed membership facts, so a coordinated
    # rewrite of this value and decision_seq cannot silently reorder a pulse.
    decision_order = as.numeric(
      (fill$k[fill_rows] - 1) * axis_size + fill$pos[fill_rows]
    ),
    ts_utc = .POSIXct(rep_len(decision$ts, n), tz = "UTC"),
    instrument_id = as.character(ledgr_diagnostic_segment_at(decision, "instrument_id", k)),
    target = as.numeric(ledgr_diagnostic_segment_at(decision, "target", k)),
    position_before = as.numeric(ledgr_diagnostic_segment_at(decision, "position_before", k)),
    decision_price = as.numeric(ledgr_diagnostic_segment_at(decision, "price", k)),
    decision_mark_source = as.character(ledgr_diagnostic_segment_at(decision, "mark_source", k)),
    decision_mark_age = as.integer(ledgr_diagnostic_segment_at(decision, "mark_age", k)),
    fill_quantity = as.numeric(fill$qty[fill_rows]),
    fill_price = as.numeric(fill$price[fill_rows]),
    execution_ts_utc = .POSIXct(fill$exec_ts[fill_rows], tz = "UTC"),
    event_seq = as.integer(event_seq),
    position_after = as.numeric(fill$planned_position_after[fill_rows])
  )
}

ledgr_diagnostic_implicit_hold_block <- function(run_id,
                                                 decision,
                                                 rows,
                                                 decision_seq,
                                                 decision_order) {
  n <- length(rows)
  target <- as.numeric(ledgr_diagnostic_segment_at(decision, "target", rows))
  before <- as.numeric(ledgr_diagnostic_segment_at(decision, "position_before", rows))
  list(
    n = n,
    run_id = rep_len(as.character(run_id), n),
    decision_seq = as.integer(decision_seq),
    execution_seq = rep(NA_integer_, n),
    decision_order = as.numeric(decision_order),
    ts_utc = .POSIXct(rep_len(decision$ts, n), tz = "UTC"),
    instrument_id = as.character(ledgr_diagnostic_segment_at(decision, "instrument_id", rows)),
    target = target,
    position_before = before,
    decision_price = as.numeric(ledgr_diagnostic_segment_at(decision, "price", rows)),
    decision_mark_source = as.character(ledgr_diagnostic_segment_at(decision, "mark_source", rows)),
    decision_mark_age = as.integer(ledgr_diagnostic_segment_at(decision, "mark_age", rows)),
    fill_quantity = rep(NA_real_, n),
    fill_price = rep(NA_real_, n),
    execution_ts_utc = .POSIXct(rep(NA_real_, n), tz = "UTC"),
    event_seq = rep(NA_integer_, n),
    position_after = before
  )
}

# One terminal reduction over the exact logical rows, in diagnostic sequence
# order. This intentionally mirrors the former read-time reduction rather
# than incrementally adding per-pulse floating-point subtotals.
ledgr_diagnostic_summary_from_store <- function(con, run_id) {
  ledgr_diagnostic_require_coverage(con, run_id)
  flags <- DBI::dbGetQuery(
    con,
    paste0(
      "SELECT COUNT(*) FILTER (WHERE stage = 'decision') AS decisions, ",
      "COUNT(*) FILTER (WHERE quantity <> 0 AND (stage = 'decision' OR ",
      "(stage = 'valuation' AND outcome = 'marked')) AND mark_source = 'stale_close') AS stale, ",
      "COUNT(*) FILTER (WHERE quantity <> 0 AND (stage = 'decision' OR ",
      "(stage = 'valuation' AND outcome = 'marked')) AND mark_source = 'frozen_close') AS frozen, ",
      "COUNT(*) FILTER (WHERE stage = 'valuation' AND reason_code = 'terminal_disposition') AS assumed ",
      "FROM (", ledgr_diagnostic_logical_sql(), ") logical WHERE run_id = ?"
    ),
    params = list(run_id)
  )
  decisions <- as.integer(flags$decisions[[1L]])
  stale <- as.integer(flags$stale[[1L]])
  frozen <- as.integer(flags$frozen[[1L]])
  assumed <- as.integer(flags$assumed[[1L]])
  rows <- DBI::dbGetQuery(
    con,
    "SELECT * FROM run_diagnostics WHERE run_id = ? AND stage = 'sizing' ORDER BY diagnostic_seq",
    params = list(run_id)
  )
  decision_times <- DBI::dbGetQuery(
    con,
    paste0(
      "SELECT DISTINCT ts_utc FROM (", ledgr_diagnostic_logical_sql(),
      ") logical WHERE run_id = ? AND stage = 'decision' AND instrument_id <> '' ORDER BY ts_utc"
    ),
    params = list(run_id)
  )$ts_utc
  evidenced_decisions <- unavailable_decisions <- rounded_to_zero <- 0L
  no_instruction <- length(decision_times)
  raw_notice <- FALSE
  available <- FALSE
  pooled_numerator <- pooled_denominator <- NA_real_
  minimum_coverage <- last_coverage <- NA_real_
  requested_total <- post_guard_total <- rounded_total <- NA_real_
  if (nrow(rows) > 0L) {
    time <- as.numeric(as.POSIXct(rows$ts_utc, tz = "UTC"))
    decision_time <- as.numeric(as.POSIXct(decision_times, tz = "UTC"))
    unavailable <- rows$reason_code == "sizing_unavailable"
    raw_notice <- any(rows$reason_code == "sizing_intent_unavailable")
    instrument_row <- !is.na(rows$instrument_id) & nzchar(rows$instrument_id)
    priced <- instrument_row & !unavailable & is.finite(rows$price) & rows$price > 0 &
      is.finite(rows$target) & is.finite(rows$quantity)
    requested_value <- abs(rows$target_before_risk * rows$price)
    post_guard_value <- abs(rows$target * rows$price)
    rounded_value <- abs(rows$quantity * rows$price)
    requested_value[!priced] <- NA_real_
    post_guard_value[!priced] <- NA_real_
    rounded_value[!priced] <- NA_real_
    unique_time <- sort(unique(time[instrument_row]), method = "radix")
    coverage <- rep(NA_real_, length(unique_time))
    if (length(unique_time) > 0L) {
      group <- match(time[instrument_row], unique_time)
      denominator_by_time <- rowsum(
        ifelse(priced[instrument_row], post_guard_value[instrument_row], 0),
        group, reorder = FALSE, na.rm = TRUE
      )[, 1L]
      numerator_by_time <- rowsum(
        ifelse(priced[instrument_row], rounded_value[instrument_row], 0),
        group, reorder = FALSE, na.rm = TRUE
      )[, 1L]
      covered <- denominator_by_time > 0
      coverage[covered] <- numerator_by_time[covered] / denominator_by_time[covered]
    }
    evidenced_times <- unique(time[instrument_row & !unavailable])
    missing_times <- decision_time[!decision_time %in% unique(time[instrument_row])]
    unavailable_times <- unique(c(time[unavailable], if (raw_notice) missing_times else numeric()))
    denominator <- sum(post_guard_value, na.rm = TRUE)
    available <- any(instrument_row)
    evidenced_decisions <- length(evidenced_times)
    unavailable_decisions <- length(unavailable_times)
    no_instruction <- if (raw_notice) 0L else length(missing_times)
    rounded_to_zero <- sum(rows$reason_code %in% c(
      "sizing_rounded_to_zero_addition", "sizing_rounded_to_zero_liquidation"
    ))
    if (denominator > 0) {
      pooled_numerator <- sum(rounded_value, na.rm = TRUE)
      pooled_denominator <- denominator
    }
    finite_coverage <- coverage[is.finite(coverage)]
    minimum_coverage <- if (length(finite_coverage)) min(finite_coverage) else NA_real_
    last_coverage <- if (length(coverage)) utils::tail(coverage, 1L) else NA_real_
    if (any(priced)) {
      requested_total <- sum(requested_value, na.rm = TRUE)
      post_guard_total <- sum(post_guard_value, na.rm = TRUE)
      rounded_total <- sum(rounded_value, na.rm = TRUE)
    }
  }
  data.frame(
    run_id = run_id, decisions = as.integer(decisions), stale = as.integer(stale),
    frozen = as.integer(frozen), assumed = as.integer(assumed), sizing_available = available,
    evidenced_decisions = as.integer(evidenced_decisions),
    unavailable_decisions = as.integer(unavailable_decisions),
    no_instruction_decisions = as.integer(no_instruction),
    raw_intent_unavailable = raw_notice,
    rounded_to_zero_instructions = as.integer(rounded_to_zero),
    pooled_numerator = pooled_numerator, pooled_denominator = pooled_denominator,
    minimum_decision_coverage = minimum_coverage,
    last_decision_coverage = last_coverage,
    requested_value_diagnostic = requested_total,
    post_guard_value_diagnostic = post_guard_total,
    rounded_value_diagnostic = rounded_total,
    stringsAsFactors = FALSE
  )
}

ledgr_diagnostic_summary_hash <- function(row) {
  payload <- as.list(row[1L, setdiff(names(row), "summary_hash"), drop = FALSE])
  digest::digest(payload, algo = "sha256")
}

ledgr_diagnostic_summary_read <- function(con, run_ids) {
  run_ids <- unique(as.character(run_ids))
  if (length(run_ids) == 0L) return(data.frame())
  marks <- paste(rep("?", length(run_ids)), collapse = ", ")
  rows <- DBI::dbGetQuery(
    con,
    paste0("SELECT * FROM run_diagnostic_summary WHERE run_id IN (", marks, ")"),
    params = as.list(run_ids)
  )
  if (nrow(rows) != length(run_ids) || !setequal(as.character(rows$run_id), run_ids)) {
    affected <- unique(c(
      setdiff(run_ids, as.character(rows$run_id)),
      as.character(rows$run_id[duplicated(rows$run_id)])
    ))
    if (length(affected) == 0L) affected <- run_ids
    rlang::abort(
      sprintf(
        "Run diagnostic summary evidence is missing or duplicated for run `%s`.",
        affected[[1L]]
      ),
      class = "ledgr_diagnostic_corrupt"
    )
  }
  expected <- vapply(seq_len(nrow(rows)), function(i) {
    ledgr_diagnostic_summary_hash(rows[i, , drop = FALSE])
  }, character(1L))
  if (!identical(as.character(rows$summary_hash), unname(expected))) {
    bad <- which(as.character(rows$summary_hash) != unname(expected))
    rlang::abort(
      sprintf(
        "Run diagnostic summary evidence is corrupt for run `%s`.",
        as.character(rows$run_id[[bad[[1L]]]])
      ),
      class = "ledgr_diagnostic_corrupt"
    )
  }
  rows
}
