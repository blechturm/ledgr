ws14_utc <- function(x) {
  as.POSIXct(x, tz = "UTC")
}

ws14_fact_matrix <- function() {
  membership_input <- data.frame(
    effective_from = rep(ws14_utc(c(
      "2020-01-01 16:00:00",
      "2020-01-02 16:00:00"
    )), c(2L, 2L)),
    knowledge_time = rep(ws14_utc(c(
      "2019-12-31 12:00:00",
      "2020-01-01 12:00:00"
    )), c(2L, 2L)),
    instrument_id = c("AAA", "BBB", "BBB", "CHILD"),
    source = "fictional_matrix",
    stringsAsFactors = FALSE
  )
  membership <- ledgr_facts_membership_snapshots(
    membership_input,
    universe_id = "matrix",
    complete = TRUE
  )

  status <- ledgr_facts_trading_status(data.frame(
    fact_id = c("matrix_status_aaa", "matrix_status_bbb"),
    instrument_id = c("AAA", "BBB"),
    effective_from = ws14_utc("2020-01-01 00:00:00"),
    effective_to = ws14_utc("2020-01-04 00:00:00"),
    knowledge_time = ws14_utc("2019-12-31 00:00:00"),
    status = c("active", "quotation_only"),
    source = "fictional_matrix",
    precedence = c(2L, 1L),
    revision_id = c("status-a", NA_character_),
    stringsAsFactors = FALSE
  ))

  lifetime <- ledgr_facts_lifetime(data.frame(
    fact_id = c("matrix_lifetime_aaa", "matrix_lifetime_bbb"),
    instrument_id = c("AAA", "BBB"),
    effective_from = ws14_utc("2020-01-01 00:00:00"),
    knowledge_time = ws14_utc("2019-12-31 00:00:00"),
    assertion = c("known_active", "known_inactive"),
    terminal_event = c(NA_character_, "delisted"),
    source = "fictional_matrix",
    stringsAsFactors = FALSE
  ))

  actions <- ledgr_facts_equity_corporate_actions(data.frame(
    fact_id = c("matrix_cash", "matrix_spin"),
    subtype = c("ordinary_cash_dividend", "spin_off"),
    parent_instrument_id = c("AAA", "BBB"),
    entitlement_time = ws14_utc(c(
      "2020-01-02 16:00:00",
      "2020-01-03 16:00:00"
    )),
    effective_time = ws14_utc(c(
      "2020-01-02 16:00:00",
      "2020-01-03 16:00:00"
    )),
    knowledge_time = ws14_utc(c(
      "2020-01-01 12:00:00",
      "2020-01-02 12:00:00"
    )),
    complete = c(TRUE, FALSE),
    refusal_reason = c(NA_character_, "recipient_quantity_unavailable"),
    provenance_tier = c("snapshot_bound", "upstream_vintage_bound"),
    upstream_build_id = c(NA_character_, "matrix-build"),
    bar_vintage_id = c(NA_character_, "matrix-bars"),
    gross_cash_per_parent_unit = c(1.25, NA_real_),
    gross_cash_validated = c(TRUE, FALSE),
    recipient_instrument_id = c(NA_character_, "CHILD"),
    recipient_identity_validated = c(FALSE, TRUE),
    recipient_quantity_validated = FALSE,
    source = "fictional_matrix",
    stringsAsFactors = FALSE
  ))

  session_dates <- as.Date("2020-01-01") + 0:2
  sessions <- ledgr_facts_sessions(
    data.frame(
      session_date = session_dates,
      status = "open",
      session_open = "09:30:00",
      session_close = "16:00:00",
      knowledge_time = ws14_utc("2019-12-31 00:00:00"),
      source = "fictional_matrix",
      stringsAsFactors = FALSE
    ),
    venue_id = "MATRIX",
    timezone = "UTC"
  )

  families <- list(membership, status, lifetime, actions, sessions)
  names(families) <- vapply(families, `[[`, character(1), "family")
  list(families = families, facts = do.call(ledgr_facts, families))
}

ws14_matrix_bars <- function(include_quarantine = TRUE) {
  instruments <- c("AAA", "BBB", "CHILD")
  pulses <- ws14_utc("2020-01-01 16:00:00") + 86400 * 0:2
  grid <- expand.grid(
    instrument_id = instruments,
    ts_utc = pulses,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  grid$open <- 100 + seq_len(nrow(grid))
  grid$high <- grid$open + 1
  grid$low <- grid$open - 1
  grid$close <- grid$open + 0.5
  grid$volume <- 1000
  if (!isTRUE(include_quarantine)) return(grid)
  rejected <- grid[1L, , drop = FALSE]
  rejected$instrument_id <- "UNKNOWN"
  rbind(grid, rejected)
}

ws14_matrix_snapshot <- function(db_path = tempfile(fileext = ".duckdb")) {
  matrix <- ws14_fact_matrix()
  ledgr_snapshot_from_df(
    ws14_matrix_bars(),
    instruments_df = data.frame(
      instrument_id = c("AAA", "BBB", "CHILD"),
      stringsAsFactors = FALSE
    ),
    db_path = db_path,
    facts = matrix$facts,
    invalid_observations = "quarantine"
  )
}

ws14_matrix_experiment <- function(snapshot) {
  ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$flat(),
    universe = ledgr_universe_members("matrix"),
    valuation_policy = ledgr_valuation_stale(2L),
    cost_model = ledgr_cost_zero()
  )
}

ws14_scale_action_rows <- function(n) {
  n <- as.integer(n)
  if (n == 0L) return(NULL)
  index <- seq_len(n)
  instrument_index <- (index - 1L) %% 100L + 1L
  day_index <- (index - 1L) %% 300L
  entitlement <- ws14_utc("2020-01-01 16:00:00") + day_index * 86400
  data.frame(
    fact_id = sprintf("scale_cash_%06d", index),
    subtype = "ordinary_cash_dividend",
    parent_instrument_id = sprintf("I%03d", instrument_index),
    entitlement_time = entitlement,
    effective_time = entitlement,
    knowledge_time = entitlement - 86400,
    complete = TRUE,
    provenance_tier = "snapshot_bound",
    gross_cash_per_parent_unit = 1 + (index %% 17L) / 100,
    gross_cash_validated = TRUE,
    recipient_identity_validated = FALSE,
    recipient_quantity_validated = FALSE,
    source = "workstream14_scale",
    stringsAsFactors = FALSE
  )
}

ws14_scale_sessions <- function() {
  dates <- as.Date("2020-01-01") + 0:299
  ledgr_facts_sessions(
    data.frame(
      session_date = dates,
      status = "open",
      session_open = "09:30:00",
      session_close = "16:00:00",
      knowledge_time = ws14_utc("2019-12-01 00:00:00"),
      source = "workstream14_scale",
      stringsAsFactors = FALSE
    ),
    venue_id = "SCALE",
    timezone = "UTC"
  )
}

ws14_scale_facts <- function(n) {
  sessions <- ws14_scale_sessions()
  rows <- ws14_scale_action_rows(n)
  if (is.null(rows)) return(ledgr_facts(sessions))
  ledgr_facts(sessions, ledgr_facts_equity_corporate_actions(rows))
}

ws14_scale_instruments <- function() {
  data.frame(
    instrument_id = sprintf("I%03d", seq_len(100L)),
    stringsAsFactors = FALSE
  )
}

ws14_scale_bars <- function() {
  instruments <- sprintf("I%03d", seq_len(100L))
  pulses <- ws14_utc("2020-01-01 16:00:00") + 86400 * 0:299
  grid <- expand.grid(
    instrument_id = instruments,
    ts_utc = pulses,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  base <- 50 + match(grid$instrument_id, instruments) / 10
  drift <- as.numeric(grid$ts_utc - min(grid$ts_utc)) / 86400 / 100
  grid$open <- base + drift
  grid$high <- grid$open + 1
  grid$low <- grid$open - 1
  grid$close <- grid$open + 0.25
  grid$volume <- 1000
  grid
}
