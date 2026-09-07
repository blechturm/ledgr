stage3_mutation_m1 <- function(observed) {
  observed <- stage3_set_observed(
    observed, "c1", "execution_bar_available", "false",
    event_time = "2024-01-04T14:30:00Z", asset_id = "A02"
  )
  stage3_set_observed(
    observed, "c1", "fill_price", "50",
    event_time = "2024-01-04T14:30:00Z", asset_id = "A02"
  )
}

stage3_mutation_m2 <- function(observed) {
  observed <- stage3_set_observed(
    observed, "c4", "resolved_status", "halted",
    event_time = "2024-01-08T14:30:00Z", asset_id = "A01"
  )
  stage3_set_observed(
    observed, "c4", "fill_status", "no_fill",
    event_time = "2024-01-08T14:30:00Z", asset_id = "A01",
    reason_code = "trading_halted"
  )
}

stage3_mutation_m3 <- function(observed) {
  observed <- stage3_set_observed(
    observed, "c1", "opening_axis", "A02|A03",
    event_time = "2024-01-05T21:00:00Z"
  )
  observed <- stage3_set_observed(
    observed, "c1", "held_qty", "0",
    event_time = "2024-01-05T21:00:00Z", asset_id = "A01"
  )
  stage3_set_observed(
    observed, "c1", "held_nonmember_count", "0",
    event_time = "2024-01-05T21:00:00Z"
  )
}

stage3_mutation_m4 <- function(observed) {
  baseline <- stage3_find_observed(observed, "g1", "fit_identity")
  stage3_assert(nrow(baseline) == 1L, "M4 requires W25 g1 fit identity.")
  stage3_set_observed(
    observed,
    "m_pop",
    "fit_identity",
    baseline$observed_value[[1L]]
  )
}

stage3_mutation_m5 <- function(observed) {
  observed <- stage3_set_observed(
    observed, "c2", "fill_status", "no_fill",
    event_time = "2024-01-03T14:30:00Z", asset_id = "A01",
    reason_code = "mutation_sale_dropped"
  )
  observed <- stage3_set_observed(
    observed, "c2", "event_cash_after", "-30000",
    event_time = "2024-01-03T14:30:00Z", asset_id = "A01"
  )
  observed <- stage3_set_observed(
    observed, "c2", "cash_after", "-30000",
    event_time = "2024-01-03T14:30:00Z"
  )
  observed <- stage3_set_observed(
    observed, "c2", "position_after", "300",
    event_time = "2024-01-03T14:30:00Z", asset_id = "A01"
  )
  stage3_set_observed(
    observed, "c2", "completed_pulse_valid", "false",
    event_time = "2024-01-03T14:30:00Z"
  )
}

stage3_mutations <- function() {
  list(
    M1 = list(witness = "W22", apply = stage3_mutation_m1, expected = "stale_execution_price"),
    M2 = list(witness = "W09", apply = stage3_mutation_m2, expected = "value_mismatch:resolved_status"),
    M3 = list(witness = "W24", apply = stage3_mutation_m3, expected = "value_mismatch:opening_axis"),
    M4 = list(witness = "W25", apply = stage3_mutation_m4, expected = "identity_relation_mismatch:fit_identity"),
    M5 = list(witness = "W02", apply = stage3_mutation_m5, expected = "affordability_reconciliation_failed")
  )
}
