stage4_executable_witnesses <- function() {
  c("W02", "W03", "W06", "W07", "W09", "W20", "W21", "W22", "W24", "W25")
}

stage4_w02_rows <- function() {
  s1 <- "2024-01-02T21:00:00Z"
  s1o <- "2024-01-02T14:30:00Z"
  s2o <- "2024-01-03T14:30:00Z"
  s2 <- "2024-01-03T21:00:00Z"
  stage4_bind_rows(
    stage4_rows(c("c1", "c2"), "opening_cash", c(10000, 0)),
    stage4_rows(c("c1", "c2"), "target", c(500L, 600L), s1, "A02"),
    stage4_rows(c("c1", "c2"), "opening_position", 300L, asset_id = "A01"),
    stage4_rows(c("c1", "c2"), "opening_position", 0L, asset_id = "A02"),
    stage4_rows(c("c1", "c2"), "member", TRUE, s1, "A02"),
    stage4_rows(c("c1", "c2"), "member", FALSE, s1, "A01"),
    stage4_rows(c("c1", "c2"), "close", 100, s2, "A01"),
    stage4_rows(c("c1", "c2"), "close", 50, s2, "A02"),
    stage4_rows(c("c1", "c2"), "observation_state", "accepted", s2, "A01"),
    stage4_rows(c("c1", "c2"), "observation_state", "accepted", s2, "A02"),
    stage4_rows(c("c1", "c2"), "trading_status", "active", s1, "A01"),
    stage4_rows(c("c1", "c2"), "trading_status", "active", s1, "A02"),
    stage4_rows(c("c1", "c2"), "execution_price", 100, s2o, "A01"),
    stage4_rows(c("c1", "c2"), "execution_price", 50, s2o, "A02"),
    stage4_rows(c("c1", "c2"), "trading_status", c("halted", "active"), s2o, "A01"),
    stage4_rows(c("c1", "c2"), "trading_status", "active", s2o, "A02"),
    stage4_rows("policy", "cash_tolerance", 1e-8),
    stage4_rows("policy", "decision_time", s1),
    stage4_rows("policy", "execution_time", s2o),
    stage4_rows("policy", "valuation_time", s2),
    stage4_rows("policy", "event_order", "A02|A01"),
    stage4_rows("policy", "package_instrument_order", "A01|A02"),
    stage4_rows("policy", "package_pulse_order", paste(c(s1, s2), collapse = "|")),
    stage4_rows(
      "policy", "package_execution_order", paste(c(s1o, s2o), collapse = "|")
    )
  )
}

stage4_w03_rows <- function() {
  s1 <- "2024-01-02T21:00:00Z"
  s2o <- "2024-01-03T14:30:00Z"
  s2 <- "2024-01-03T21:00:00Z"
  s3o <- "2024-01-04T14:30:00Z"
  stage4_bind_rows(
    stage4_rows("input", "cash", 90000),
    stage4_rows("input", "qty", 100L, asset_id = "A01"),
    stage4_rows("input", "price", 100, asset_id = "A01"),
    stage4_rows("c1", "member", TRUE, c(s1, s2), "A01"),
    stage4_rows("c1", "target", c(0L, 100L), c(s1, s2), "A01"),
    stage4_rows("c1", "trading_status", c("halted", "active"), c(s2o, s3o), "A01"),
    stage4_rows("policy", "decision_times", paste(c(s1, s2), collapse = "|")),
    stage4_rows("policy", "execution_times", paste(c(s2o, s3o), collapse = "|")),
    stage4_rows("policy", "valuation_time", "2024-01-04T21:00:00Z")
  )
}

stage4_w06_rows <- function() {
  times <- c(
    "2024-01-02T21:00:00Z", "2024-01-03T21:00:00Z",
    "2024-01-04T21:00:00Z", "2024-01-05T21:00:00Z",
    "2024-01-08T21:00:00Z"
  )
  stage4_bind_rows(
    stage4_rows("input", "cash", 90000),
    stage4_rows("input", "opening_position", 100L, asset_id = "A01"),
    stage4_rows("input", "target", 100L, asset_id = "A02"),
    stage4_rows("c1", "member", FALSE, times, "A01"),
    stage4_rows("c1", "member", TRUE, times, "A02"),
    stage4_rows("c1", "lifetime_state", "listed", times, "A01"),
    stage4_rows("c1", "close", 100, times[[1L]], "A01"),
    stage4_rows(
      "c1", "observation_state",
      c("accepted", rep("expected_session_absence", 3L)), times[1:4], "A01"
    ),
    stage4_rows("c1", "close", 50, times, "A02"),
    stage4_rows("c1", "observation_state", "accepted", times, "A02"),
    stage4_rows("c1", "execution_price", 50, "2024-01-03T14:30:00Z", "A02"),
    stage4_rows("c1", "trading_status", "active", "2024-01-03T14:30:00Z", "A02"),
    stage4_rows("policy", "decision_times", paste(times, collapse = "|")),
    stage4_rows("policy", "execution_time", "2024-01-03T14:30:00Z"),
    stage4_rows("policy", "max_stale_age", 2L)
  )
}

stage4_w07_rows <- function() {
  times <- c(
    "2024-01-02T21:00:00Z", "2024-01-03T21:00:00Z",
    "2024-01-04T21:00:00Z"
  )
  stage4_bind_rows(
    stage4_rows("input", "cash", 90000),
    stage4_rows("input", "opening_position", 100L, asset_id = "A01"),
    stage4_rows("c1", "member", TRUE, times, "A01"),
    stage4_rows("c1", "lifetime_state", c("listed", "listed", "terminal_accepted"), times, "A01"),
    stage4_rows("c1", "observation_state", "accepted", times[1:2], "A01"),
    stage4_rows("c1", "close", 100, times[1:2], "A01"),
    stage4_rows("c1", "terminal_event", "delisting_with_cash_distribution", times[[3L]], "A01"),
    stage4_rows("policy", "decision_times", paste(times, collapse = "|")),
    stage4_rows("policy", "max_stale_age", 2L)
  )
}

stage4_w09_rows <- function() {
  facts <- stage3_provider_status_facts(stage3_reference_provider())
  starts <- stage3_iso(facts$effective_from)
  stage4_bind_rows(
    stage4_rows("facts", "source", facts$source, starts, facts$asset_id),
    stage4_rows("facts", "precedence", facts$precedence, starts, facts$asset_id),
    stage4_rows("facts", "status", facts$status, starts, facts$asset_id),
    stage4_rows("facts", "effective_to", facts$effective_to, starts, facts$asset_id),
    stage4_rows("facts", "knowledge_time", facts$knowledge_time, starts, facts$asset_id),
    stage4_rows("policy", "opening_position", 100L, asset_id = "A01"),
    stage4_rows("policy", "opening_position", 100L, asset_id = "A05"),
    stage4_rows("policy", "opening_cash", 90000),
    stage4_rows("policy", "execution_price", 100, asset_id = "A01")
  )
}

stage4_w20_rows <- function() {
  c1 <- c("2024-01-02T21:00:00Z", "2024-01-03T21:00:00Z")
  c2 <- c(
    "2024-01-02T21:00:00Z", "2024-01-03T21:00:00Z",
    "2024-01-04T21:00:00Z", "2024-01-05T21:00:00Z",
    "2024-01-08T21:00:00Z"
  )
  open <- "2024-01-03T14:30:00Z"
  stage4_bind_rows(
    stage4_rows("c1", "member", TRUE, c1, "A02"),
    stage4_rows("c1", "close", 50, c1, "A02"),
    stage4_rows("c1", "observation_state", "accepted", c1, "A02"),
    stage4_rows("c1", "execution_price", 50, open, "A02"),
    stage4_rows("c1", "trading_status", "active", open, "A02"),
    stage4_rows("c1", "opening_cash", 100000),
    stage4_rows("c1", "target", 100L, asset_id = "A02"),
    stage4_rows("c2", "member", TRUE, c2, "A02"),
    stage4_rows("c2", "member", FALSE, c2, "A01"),
    stage4_rows("c2", "close", 50, c2, "A02"),
    stage4_rows("c2", "close", 100, c2[[1L]], "A01"),
    stage4_rows("c2", "observation_state", "accepted", c2, "A02"),
    stage4_rows(
      "c2", "observation_state",
      c("accepted", rep("expected_session_absence", 4L)), c2, "A01"
    ),
    stage4_rows("c2", "execution_price", 50, open, "A02"),
    stage4_rows("c2", "trading_status", "active", open, "A02"),
    stage4_rows("c2", "opening_cash", 90000),
    stage4_rows("c2", "target", 100L, asset_id = "A02"),
    stage4_rows("c2", "opening_position", 100L, asset_id = "A01"),
    stage4_rows("policy", "c1_pulses", paste(c1, collapse = "|")),
    stage4_rows("policy", "c2_pulses", paste(c2, collapse = "|")),
    stage4_rows("policy", "execution_time", open),
    stage4_rows("policy", "max_stale_age", 2L)
  )
}

stage4_w21_rows <- function() {
  fixture <- stage3_provider_w21(stage3_reference_provider())
  bar_rows <- lapply(c("open", "high", "low", "close", "volume"), function(field) {
    stage4_rows(
      "bars", field, fixture$bars[[field]],
      stage3_iso(fixture$bars$ts_utc), fixture$bars$instrument_id
    )
  })
  stage4_bind_rows(
    do.call(stage4_bind_rows, bar_rows),
    stage4_rows("policy", "instrument_order", paste(fixture$instrument_ids, collapse = "|")),
    stage4_rows("policy", "pulse_order", paste(stage3_iso(fixture$pulses), collapse = "|")),
    stage4_rows(
      "policy", "execution_time", fixture$execution_times,
      stage3_iso(fixture$pulses), "__axis__"
    ),
    stage4_rows(
      "targets", "target", as.vector(t(fixture$targets)),
      rep(stage3_iso(fixture$pulses), each = length(fixture$instrument_ids)),
      rep(fixture$instrument_ids, times = length(fixture$pulses))
    ),
    stage4_rows("opening", "cash", fixture$opening$cash),
    stage4_rows("opening", "position", unname(fixture$opening$positions),
      asset_id = names(fixture$opening$positions)),
    stage4_rows("opening", "lot_basis", unname(fixture$opening$lot_basis),
      asset_id = names(fixture$opening$lot_basis)),
    stage4_rows("policy", "fixed_fee", fixture$fixed_fee),
    stage4_rows("policy", "max_weight", fixture$max_weight)
  )
}

stage4_w22_rows <- function() {
  prior <- "2024-01-02T21:00:00Z"
  decision <- "2024-01-03T21:00:00Z"
  execution <- "2024-01-04T14:30:00Z"
  stage4_bind_rows(
    stage4_rows("policy", "opening_cash", 90000),
    stage4_rows("policy", "held_qty", 200L, asset_id = "A02"),
    stage4_rows(c("c0", "c1", "c2", "c3"), "max_weight", c(0.05, 0.05, 0.5, 0.5)),
    stage4_rows("c3", "target", 100L, asset_id = "A03"),
    stage4_rows("c0", "observation_state", "accepted", decision, "A02"),
    stage4_rows("c0", "close", 50, decision, "A02"),
    stage4_rows(c("c1", "c2"), "observation_state", "accepted", prior, "A02"),
    stage4_rows(c("c1", "c2"), "close", 50, prior, "A02"),
    stage4_rows(
      c("c1", "c2"), "observation_state", "expected_session_absence",
      decision, "A02"
    ),
    stage4_rows(c("c0", "c1", "c2"), "execution_price", 52, execution, "A02"),
    stage4_rows(c("c0", "c1", "c2"), "trading_status", "active", execution, "A02")
  )
}

stage4_w24_rows <- function() {
  fold1_close <- "2024-01-04T21:00:00Z"
  fold2_open <- "2024-01-05T21:00:00Z"
  stage4_bind_rows(
    stage4_rows("policy", "opening_cash", 100000),
    stage4_rows("policy", "buy_qty", 100L, asset_id = "A01"),
    stage4_rows("policy", "buy_price", 100, asset_id = "A01"),
    stage4_rows("policy", "fold2_members", "A02|A03"),
    stage4_rows("policy", "carried_id", "A01"),
    stage4_rows("policy", "carried_basis", 100, asset_id = "A01"),
    stage4_rows("c1", "member", FALSE, c(fold1_close, fold2_open), "A01"),
    stage4_rows("c1", "member", TRUE, fold2_open, c("A02", "A03")),
    stage4_rows("c1", "observation_state", "accepted", fold1_close, "A01"),
    stage4_rows("c1", "close", 100, fold1_close, "A01")
  )
}

stage4_w25_rows <- function() {
  fixture <- stage3_provider_w25(stage3_reference_provider())
  stage4_bind_rows(
    stage4_rows("input", "raw", fixture$raw, fixture$times, "A01"),
    stage4_rows("policy", "calendar", fixture$calendar),
    stage4_rows("policy", "classifier", fixture$classifier),
    stage4_rows("policy", "population", fixture$population),
    stage4_rows("policy", "cutoff", fixture$cutoff),
    stage4_rows("policy", "rng", fixture$rng)
  )
}

stage4_case_spec <- function(witness_id) {
  executable <- stage4_executable_witnesses()
  if (!witness_id %in% executable) {
    path <- file.path("fixtures", witness_id, "manifest.md")
    rows <- stage4_rows("policy", "fixture_manifest", path)
    return(list(
      witness_id = witness_id,
      role = "policy_example",
      mode = "policy_example",
      fixture = stage4_fixture(witness_id, rows)
    ))
  }
  rows <- get(paste0("stage4_", tolower(witness_id), "_rows"), mode = "function")()
  list(
    witness_id = witness_id,
    role = "executable",
    mode = switch(
      witness_id,
      W02 = "affordability", W03 = "no_fill", W06 = "valuation",
      W07 = "terminal", W09 = "status", W20 = "provider_roundtrip",
      W21 = "package_control", W22 = "risk_marks",
      W24 = "fold_boundary", W25 = "transform_identity"
    ),
    fixture = stage4_fixture(witness_id, rows)
  )
}
