ws10_fact_shapes <- function() {
  matrix <- ws14_fact_matrix()
  membership_intervals <- ledgr_facts_membership_intervals(
    data.frame(
      fact_id = c("interval-aaa", "interval-bbb"),
      instrument_id = c("AAA", "BBB"),
      effective_from = ws14_utc("2020-01-01 16:00:00"),
      effective_to = c(ws14_utc("2020-01-04 16:00:00"), NA),
      knowledge_time = ws14_utc("2019-12-31 12:00:00"),
      member = c(TRUE, FALSE),
      source = "fictional_matrix",
      stringsAsFactors = FALSE
    ),
    universe_id = "matrix_intervals"
  )

  list(
    membership_snapshots = matrix$families$membership,
    membership_intervals = membership_intervals,
    trading_status = matrix$families$trading_status,
    lifetime = matrix$families$lifetime,
    equity_corporate_actions = matrix$families$equity_corporate_actions,
    sessions = matrix$families$sessions
  )
}

ws10_fact_bundle <- function() {
  do.call(ledgr_facts, unname(ws10_fact_shapes()))
}

ws10_fact_snapshot <- function(db_path = tempfile(fileext = ".duckdb")) {
  ledgr_snapshot_from_df(
    ws14_matrix_bars(),
    instruments_df = data.frame(
      instrument_id = c("AAA", "BBB", "CHILD"),
      stringsAsFactors = FALSE
    ),
    db_path = db_path,
    facts = ws10_fact_bundle(),
    invalid_observations = "quarantine", price_basis = "split_adjusted"
  )
}

ws10_oracle_path <- function(...) {
  file.path(
    ledgr_test_source_root(),
    "tests",
    "testthat",
    "fixtures",
    "ws10-fact-integrity",
    ...
  )
}

ws10_read_oracle_manifest <- function() {
  utils::read.csv(
    ws10_oracle_path("manifest.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

ws10_read_oracle_bytes <- function(file) {
  path <- ws10_oracle_path(file)
  size <- file.info(path)$size
  readChar(path, nchars = size, useBytes = TRUE)
}
