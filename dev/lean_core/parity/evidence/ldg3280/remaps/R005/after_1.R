  # The typed block as the lean terminal transfer hands it to
  # writer$append_block(): run, sequence and pulse-time columns, then the
  # rows' columns in the writer's order, the two epoch fields as POSIXct.
  n_rows <- rows$n
  list(
    run_id = rep_len("diagnostic-production", n_rows),
    diagnostic_seq = as.integer(first_seq) + seq_len(n_rows) - 1L,
    ts_utc = .POSIXct(rep_len(as.numeric(ts_utc), n_rows), tz = "UTC"),
    instrument_id = rows$instrument_id, stage = rows$stage, outcome = rows$outcome,
    reason_code = rows$reason_code, reasons = rows$reasons, target = rows$target,
    quantity = rows$quantity, price = rows$price, mark_source = rows$mark_source,
    mark_age = rows$mark_age, decision_ts_utc = .POSIXct(rows$decision_ts_utc, tz = "UTC"),
    execution_ts_utc = .POSIXct(rows$execution_ts_utc, tz = "UTC"), event_seq = rows$event_seq,
    target_before_risk = rows$target_before_risk, target_after_risk = rows$target_after_risk,
    position_before = rows$position_before, position_after = rows$position_after,
    feature_identity_json = rows$feature_identity_json, detail_json = rows$detail_json
  )
}
