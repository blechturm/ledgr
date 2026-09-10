availability_test_sessions <- function(start = as.Date("2024-01-01"), days = 5L) {
  dates <- start + seq_len(days) - 1L
  weekday <- as.POSIXlt(dates)$wday %in% 1:5
  data.frame(
    session_date = dates,
    status = ifelse(weekday, "open", "closed"),
    session_open = ifelse(weekday, "09:30:00", NA_character_),
    session_close = ifelse(weekday, "16:00:00", NA_character_),
    knowledge_time = as.POSIXct("2023-12-01", tz = "UTC"),
    stringsAsFactors = FALSE
  )
}

availability_test_bars <- function(dates = as.Date("2024-01-02") + 0:2) {
  data.frame(
    instrument_id = "AAA",
    ts_utc = dates,
    open = c(10, 11, 12)[seq_along(dates)],
    high = c(11, 12, 13)[seq_along(dates)],
    low = c(9, 10, 11)[seq_along(dates)],
    close = c(10, 11, 12)[seq_along(dates)],
    volume = 100,
    stringsAsFactors = FALSE
  )
}

availability_test_facts <- function() {
  ledgr_facts(
    ledgr_facts_sessions(
      availability_test_sessions(),
      venue_id = "XNYS",
      timezone = "America/New_York"
    )
  )
}

testthat::test_that("fact constructors preserve completeness, knowledge, and conflicts", {
  membership <- ledgr_facts_membership_snapshots(
    data.frame(
      effective_from = as.POSIXct(c("2024-01-01", "2024-02-01"), tz = "UTC"),
      knowledge_time = as.POSIXct(c("2023-12-31", "2024-01-31"), tz = "UTC"),
      instrument_id = c("AAA", NA_character_)
    ),
    universe_id = "research",
    complete = c(FALSE, TRUE)
  )
  testthat::expect_s3_class(membership, "ledgr_fact_family")
  testthat::expect_equal(nrow(membership$headers), 2L)
  testthat::expect_equal(nrow(membership$rows), 1L)
  testthat::expect_identical(membership$headers$complete, c(FALSE, TRUE))

  status <- ledgr_facts_trading_status(data.frame(
    instrument_id = c("AAA", "AAA"),
    effective_from = as.POSIXct("2024-01-01", tz = "UTC"),
    effective_to = as.POSIXct("2024-02-01", tz = "UTC"),
    knowledge_time = as.POSIXct("2023-12-31", tz = "UTC"),
    status = c("active", "halted"),
    source = c("exchange", "vendor"),
    precedence = 1L
  ))
  facts <- ledgr_facts(membership, status)
  report <- ledgr_facts_validate(facts, availability_test_bars())
  testthat::expect_s3_class(report, "ledgr_facts_report")
  conflict <- report$facts[report$facts$family == "trading_status", , drop = FALSE]
  testthat::expect_true(report$can_seal)
  testthat::expect_true(all(conflict$outcome == "runtime_conflict"))
  testthat::expect_true(all(conflict$reason == "status_unknown_or_conflicting"))

  resolved_status <- ledgr_facts_trading_status(data.frame(
    instrument_id = "AAA",
    effective_from = as.POSIXct("2024-01-01", tz = "UTC"),
    effective_to = as.POSIXct("2024-02-01", tz = "UTC"),
    knowledge_time = as.POSIXct("2023-12-31", tz = "UTC"),
    status = c("active", "halted", "active"),
    source = c("exchange", "vendor", "authority"),
    precedence = c(1L, 1L, 5L)
  ))
  resolved_report <- ledgr_facts_validate(
    ledgr_facts(resolved_status),
    availability_test_bars()
  )
  testthat::expect_true(all(resolved_report$facts$outcome == "accepted"))

  partial_rows <- resolved_status$rows
  high <- partial_rows$precedence == 5L
  partial_rows$effective_from[high] <- as.POSIXct("2024-01-10", tz = "UTC")
  partial_rows$effective_to[high] <- as.POSIXct("2024-01-20", tz = "UTC")
  partial <- ledgr_facts_trading_status(data.frame(
    instrument_id = partial_rows$instrument_id,
    effective_from = partial_rows$effective_from,
    effective_to = partial_rows$effective_to,
    knowledge_time = partial_rows$knowledge_time,
    status = partial_rows$status,
    source = partial_rows$source,
    precedence = partial_rows$precedence
  ))
  partial_report <- ledgr_facts_validate(ledgr_facts(partial), availability_test_bars())
  partial_outcome <- stats::setNames(partial_report$facts$outcome, partial_report$facts$fact_id)
  testthat::expect_true(all(
    partial_outcome[partial$rows$fact_id[partial$rows$precedence == 1L]] == "runtime_conflict"
  ))
  testthat::expect_identical(
    unname(partial_outcome[partial$rows$fact_id[partial$rows$precedence == 5L]]),
    "accepted"
  )

  lifetime <- ledgr_facts_lifetime(data.frame(
    instrument_id = "AAA",
    effective_from = as.POSIXct("2024-01-01", tz = "UTC"),
    assertion = "unknown"
  ))
  audit <- ledgr_facts_validate(ledgr_facts(lifetime), availability_test_bars())
  testthat::expect_identical(audit$facts$outcome, "audit_only")
  testthat::expect_identical(audit$facts$reason, "knowledge_time_missing")
  assumed <- ledgr_facts_lifetime(
    data.frame(
      instrument_id = "AAA",
      effective_from = as.POSIXct("2024-01-01", tz = "UTC"),
      assertion = "unknown"
    ),
    knowledge = "assume_effective"
  )
  testthat::expect_null(lifetime$metadata$knowledge_assumption)
  testthat::expect_identical(assumed$metadata$knowledge_assumption, "effective")
  assumed_report <- ledgr_facts_validate(ledgr_facts(assumed), availability_test_bars())
  testthat::expect_identical(assumed_report$facts$outcome, "accepted")
})

testthat::test_that("status supersession is source-local and canonical", {
  status <- ledgr_facts_trading_status(data.frame(
    instrument_id = c("AAA", "AAA"),
    effective_from = as.POSIXct(c("2024-01-01", "2024-01-02"), tz = "UTC"),
    knowledge_time = as.POSIXct(c("2023-12-31", "2024-01-02"), tz = "UTC"),
    status = c("halted", "active"),
    source = "exchange",
    fact_id = c("halt-1", "resume-1"),
    supersedes_fact_id = c(NA_character_, "halt-1")
  ))
  testthat::expect_identical(status$rows$supersedes_fact_id[[2L]], status$rows$fact_id[[1L]])

  bad <- data.frame(
    instrument_id = c("AAA", "AAA"),
    effective_from = as.POSIXct("2024-01-01", tz = "UTC"),
    knowledge_time = as.POSIXct("2023-12-31", tz = "UTC"),
    status = c("active", "halted"),
    source = "exchange"
  )
  testthat::expect_error(
    ledgr_facts_trading_status(bad),
    class = "ledgr_fact_structural_conflict"
  )
  bad$fact_id <- c("one", "two")
  bad$supersedes_fact_id <- c(NA_character_, "missing")
  testthat::expect_error(
    ledgr_facts_trading_status(bad),
    class = "ledgr_fact_invalid_supersession"
  )
})

testthat::test_that("fact bundles reject mutation", {
  facts <- availability_test_facts()
  facts$families[[1L]]$rows$status[[1L]] <- "closed"
  testthat::expect_error(
    ledgr_facts_validate(facts, availability_test_bars()),
    class = "ledgr_invalid_facts"
  )
})

testthat::test_that("session calendars are complete, knowledge-bounded, and DST-safe", {
  dst <- data.frame(
    session_date = as.Date("2024-03-09") + 0:2,
    status = "closed",
    session_open = NA_character_,
    session_close = NA_character_,
    knowledge_time = as.POSIXct("2024-03-01", tz = "UTC")
  )
  family <- ledgr_facts_sessions(dst, "XNYS", timezone = "America/New_York")
  duration_hours <- as.numeric(difftime(
    family$rows$effective_to,
    family$rows$effective_from,
    units = "hours"
  ))
  testthat::expect_identical(duration_hours, c(24, 23, 24))
  testthat::expect_identical(family$metadata$timezone, "America/New_York")

  assumed <- dst[, setdiff(names(dst), "knowledge_time"), drop = FALSE]
  assumed_family <- ledgr_facts_sessions(
    assumed,
    "XNYS",
    knowledge = "assume_effective",
    timezone = "America/New_York"
  )
  testthat::expect_identical(assumed_family$metadata$knowledge_assumption, "effective")
  testthat::expect_false(anyNA(assumed_family$rows$knowledge_time))
  testthat::expect_error(
    ledgr_facts_sessions(assumed, "XNYS", timezone = "America/New_York"),
    class = "ledgr_session_knowledge_late"
  )

  incomplete <- dst[c(1L, 3L), ]
  testthat::expect_error(
    ledgr_facts_sessions(incomplete, "XNYS", timezone = "America/New_York"),
    class = "ledgr_session_coverage_incomplete"
  )
  late <- availability_test_sessions()
  late$knowledge_time[late$status == "open"] <- as.POSIXct("2024-01-03 16:00:00", tz = "UTC")
  testthat::expect_error(
    ledgr_facts_sessions(late, "XNYS", timezone = "America/New_York"),
    class = "ledgr_session_knowledge_late"
  )
})

testthat::test_that("EOD labels map explicitly and the clock retains feed outages", {
  facts <- availability_test_facts()
  report <- ledgr_facts_validate(facts, availability_test_bars())
  testthat::expect_true(report$can_seal)
  testthat::expect_identical(
    report$observations$ts_utc,
    c("2024-01-02T21:00:00Z", "2024-01-03T21:00:00Z", "2024-01-04T21:00:00Z")
  )
  testthat::expect_identical(
    format(ledgr:::ledgr_session_decision_pulses(facts), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    c("2024-01-01T21:00:00Z", "2024-01-02T21:00:00Z", "2024-01-03T21:00:00Z",
      "2024-01-04T21:00:00Z", "2024-01-05T21:00:00Z")
  )
  testthat::expect_identical(
    format(ledgr:::ledgr_session_execution_opportunities(facts), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    c("2024-01-02T14:30:00Z", "2024-01-03T14:30:00Z", "2024-01-04T14:30:00Z",
      "2024-01-05T14:30:00Z")
  )

  off_calendar <- availability_test_bars(as.Date("2024-01-02"))[1L, ]
  off_calendar$ts_utc <- as.POSIXct("2024-01-06 21:00:00", tz = "UTC")
  off_report <- ledgr_facts_validate(facts, off_calendar)
  testthat::expect_true(off_report$can_seal)
  testthat::expect_identical(off_report$observations$outcome, "accepted")
  testthat::expect_identical(
    off_report$observations$reason,
    "observed_row_outside_expectation"
  )
})

testthat::test_that("availability validation is a dry-run and fails closed", {
  facts <- availability_test_facts()
  bars <- availability_test_bars()
  bars$high[[2L]] <- 8
  report <- ledgr_facts_validate(facts, bars)
  testthat::expect_false(report$can_seal)
  testthat::expect_identical(report$observations$outcome[[2L]], "quarantine_candidate")
  testthat::expect_identical(report$observations$reason[[2L]], "ohlc_invalid")

  report_q <- ledgr_facts_validate(facts, bars, invalid_observations = "quarantine")
  testthat::expect_true(report_q$can_seal)
  testthat::expect_identical(report_q$summary$n[report_q$summary$category == "observations_quarantine_candidate"], 1L)
  testthat::expect_false(any(c("con", "db_path", "snapshot_id") %in% names(report_q)))

  instruments <- data.frame(instrument_id = "BBB")
  testthat::expect_false(ledgr_facts_validate(facts, bars, instruments)$can_seal)
})

testthat::test_that("quarantine classifies malformed observation timestamps row by row", {
  facts <- availability_test_facts()
  bars <- availability_test_bars()
  bars$ts_utc <- as.POSIXct(
    paste(as.character(bars$ts_utc), "21:00:00"),
    tz = "UTC"
  )
  bars$ts_utc[[2L]] <- bars$ts_utc[[2L]] + 0.5

  report <- ledgr_facts_validate(
    facts,
    bars,
    invalid_observations = "quarantine"
  )
  testthat::expect_true(report$can_seal)
  testthat::expect_identical(report$observations$outcome, c(
    "accepted", "quarantine_candidate", "accepted"
  ))
  testthat::expect_identical(
    report$observations$reason,
    c("accepted", "timestamp_invalid", "accepted")
  )
})

testthat::test_that("fact-free snapshots retain hash rule 1", {
  bars <- data.frame(
    instrument_id = c("AAA", "AAA"),
    ts_utc = as.POSIXct(c("2024-01-01", "2024-01-02"), tz = "UTC"),
    open = c(10, 11), high = c(11, 12), low = c(9, 10), close = c(10, 11), volume = 100
  )
  first <- ledgr_snapshot_from_df(bars)
  second <- ledgr_snapshot_from_df(bars)
  on.exit(ledgr_snapshot_close(first), add = TRUE)
  on.exit(ledgr_snapshot_close(second), add = TRUE)
  first_info <- ledgr_snapshot_info(first)
  second_info <- ledgr_snapshot_info(second)
  testthat::expect_identical(first_info$snapshot_hash, second_info$snapshot_hash)
  testthat::expect_identical(
    ledgr:::ledgr_snapshot_hash_rule_version(ledgr:::get_connection(first), first$snapshot_id),
    1L
  )
  testthat::expect_null(first$metadata$snapshot_hash_rule_version)
})

testthat::test_that("hash rule 2 is canonical and facts survive reopening", {
  db_path <- tempfile(fileext = ".duckdb")
  bars <- availability_test_bars()
  sessions <- ledgr_facts_sessions(
    availability_test_sessions(),
    "XNYS",
    timezone = "America/New_York"
  )
  status_rows <- data.frame(
    instrument_id = c("AAA", "AAA"),
    effective_from = as.POSIXct("2024-01-01", tz = "UTC"),
    knowledge_time = as.POSIXct("2023-12-31", tz = "UTC"),
    status = c("active", "halted"),
    source = c("exchange", "vendor"),
    precedence = 1L
  )
  facts <- ledgr_facts(sessions, ledgr_facts_trading_status(status_rows))
  snapshot <- ledgr_snapshot_from_df(bars, db_path = db_path, facts = facts)
  hash <- ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]]
  id <- snapshot$snapshot_id
  testthat::expect_identical(
    ledgr:::ledgr_snapshot_hash_rule_version(ledgr:::get_connection(snapshot), id),
    2L
  )
  ledgr_snapshot_close(snapshot)

  reopened <- ledgr_snapshot_open(db_path, id, verify = TRUE)
  on.exit(ledgr_snapshot_close(reopened), add = TRUE)
  stored <- ledgr:::ledgr_snapshot_availability_read(ledgr:::get_connection(reopened), id)
  testthat::expect_equal(nrow(stored$snapshot_sessions), 5L)
  testthat::expect_equal(nrow(stored$snapshot_trading_status), 2L)
  testthat::expect_identical(ledgr_snapshot_info(reopened)$snapshot_hash[[1L]], hash)

  reversed <- ledgr_facts(
    ledgr_facts_trading_status(status_rows[2:1, , drop = FALSE]),
    ledgr_facts_sessions(availability_test_sessions(), "XNYS", timezone = "America/New_York")
  )
  same <- ledgr_snapshot_from_df(bars, facts = reversed)
  on.exit(ledgr_snapshot_close(same), add = TRUE)
  testthat::expect_identical(ledgr_snapshot_info(same)$snapshot_hash[[1L]], hash)

  future_membership <- ledgr_facts_membership_intervals(
    data.frame(
      instrument_id = "AAA",
      effective_from = as.POSIXct("2030-01-01", tz = "UTC"),
      knowledge_time = as.POSIXct("2029-12-31", tz = "UTC"),
      member = TRUE
    ),
    universe_id = "future"
  )
  changed <- ledgr_snapshot_from_df(
    bars,
    facts = ledgr_facts(sessions, ledgr_facts_trading_status(status_rows), future_membership)
  )
  on.exit(ledgr_snapshot_close(changed), add = TRUE)
  testthat::expect_false(identical(ledgr_snapshot_info(changed)$snapshot_hash[[1L]], hash))
})

testthat::test_that("explicit quarantine persists originals and is hash verified", {
  db_path <- tempfile(fileext = ".duckdb")
  facts <- availability_test_facts()
  bars <- availability_test_bars()
  bars$high[[2L]] <- 8
  unknown <- bars[1L, , drop = FALSE]
  unknown$instrument_id <- "UNKNOWN"
  bars <- rbind(bars, unknown)
  instruments <- data.frame(instrument_id = "AAA", stringsAsFactors = FALSE)

  testthat::expect_error(
    ledgr_snapshot_from_df(
      bars,
      instruments_df = instruments,
      db_path = db_path,
      facts = facts
    ),
    class = "ledgr_availability_validation_failed"
  )
  con <- ledgr_db_init(db_path)
  testthat::expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM snapshots")$n[[1L]], 0)
  DBI::dbDisconnect(con, shutdown = TRUE)

  snapshot <- ledgr_snapshot_from_df(
    bars,
    instruments_df = instruments,
    db_path = db_path,
    facts = facts,
    invalid_observations = "quarantine"
  )
  printed <- paste(capture.output(print(snapshot)), collapse = "\n")
  testthat::expect_match(printed, "Fact families:", fixed = TRUE)
  testthat::expect_match(printed, "Quarantined:  2", fixed = TRUE)
  id <- snapshot$snapshot_id
  hash <- ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]]
  changed_bars <- bars
  changed_bars$high[[2L]] <- 7
  changed_snapshot <- ledgr_snapshot_from_df(
    changed_bars,
    instruments_df = instruments,
    facts = facts,
    invalid_observations = "quarantine"
  )
  on.exit(ledgr_snapshot_close(changed_snapshot), add = TRUE)
  testthat::expect_false(
    identical(ledgr_snapshot_info(changed_snapshot)$snapshot_hash[[1L]], hash)
  )
  ledgr_snapshot_close(snapshot)
  reopened <- ledgr_snapshot_open(db_path, id, verify = TRUE)
  on.exit(ledgr_snapshot_close(reopened), add = TRUE)
  con <- ledgr:::get_connection(reopened)
  stored_bars <- DBI::dbGetQuery(
    con,
    "SELECT * FROM snapshot_bars WHERE snapshot_id = ? ORDER BY ts_utc",
    params = list(id)
  )
  quarantine <- ledgr:::ledgr_snapshot_availability_read(con, id)$snapshot_observation_quarantine
  testthat::expect_equal(nrow(stored_bars), 2L)
  testthat::expect_equal(nrow(quarantine), 2L)
  testthat::expect_setequal(quarantine$reason, c("ohlc_invalid", "instrument_unknown"))
  testthat::expect_true(any(grepl('"high":8', quarantine$original_row_json, fixed = TRUE)))
  testthat::expect_identical(
    DBI::dbGetQuery(
      con,
      "SELECT instrument_id FROM snapshot_instruments WHERE snapshot_id = ?",
      params = list(id)
    )$instrument_id,
    "AAA"
  )
  testthat::expect_identical(ledgr_snapshot_info(reopened)$snapshot_hash[[1L]], hash)

  DBI::dbExecute(
    con,
    "UPDATE snapshot_observation_quarantine SET reason = 'tampered' WHERE snapshot_id = ?",
    params = list(id)
  )
  testthat::expect_error(ledgr_snapshot_validate(reopened), class = "ledgr_invalid_snapshot")
})

testthat::test_that("quarantine requires sessions and cannot hide duplicate valid keys", {
  bars <- availability_test_bars()
  testthat::expect_error(
    ledgr_snapshot_from_df(bars, invalid_observations = "quarantine"),
    class = "ledgr_quarantine_requires_sessions"
  )
  duplicated <- rbind(bars, bars[1L, , drop = FALSE])
  testthat::expect_error(
    ledgr_snapshot_from_df(
      duplicated,
      facts = availability_test_facts(),
      invalid_observations = "quarantine"
    ),
    class = "ledgr_availability_validation_failed"
  )
  all_bad <- bars
  all_bad$high <- 0
  testthat::expect_error(
    ledgr_snapshot_from_df(
      all_bad,
      facts = availability_test_facts(),
      invalid_observations = "quarantine"
    ),
    class = "ledgr_availability_validation_failed"
  )
})
