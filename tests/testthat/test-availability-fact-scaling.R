workstream9_sessions <- function(from = as.Date("2024-02-25"), days = 20L) {
  dates <- from + seq_len(days) - 1L
  open <- as.POSIXlt(dates)$wday %in% 1:5
  data.frame(
    session_date = dates,
    status = ifelse(open, "open", "closed"),
    session_open = ifelse(open, "09:30:00", NA_character_),
    session_close = ifelse(open, "16:00:00", NA_character_),
    knowledge_time = as.POSIXct("2020-01-01", tz = "UTC"),
    source = "workstream9",
    stringsAsFactors = FALSE
  )
}

workstream9_scalar_local_times <- function(labels, timezone) {
  resolved <- lapply(
    labels,
    ledgr:::ledgr_local_time_resolve,
    timezone = timezone
  )
  counts <- lengths(resolved)
  values <- as.POSIXct(
    rep(NA_real_, length(labels)),
    origin = "1970-01-01",
    tz = "UTC"
  )
  unique_match <- counts == 1L
  values[unique_match] <- as.POSIXct(
    vapply(resolved[unique_match], `[[`, numeric(1), 1L),
    origin = "1970-01-01",
    tz = "UTC"
  )
  list(values = values, counts = counts)
}

workstream9_membership_data <- function() {
  at <- as.POSIXct(c(
    "2024-01-01", "2024-01-20", "2024-02-01", "2024-03-01"
  ), tz = "UTC")
  headers <- data.frame(
    universe_id = "research",
    set_id = c("later", "complete_old", "early", "complete"),
    effective_from = at[c(4L, 2L, 1L, 3L)],
    knowledge_time = at[c(4L, 2L, 1L, 3L)] - 86400,
    complete = c(FALSE, TRUE, FALSE, TRUE),
    provenance_json = "{}",
    source = "workstream9",
    stringsAsFactors = FALSE
  )
  rows <- data.frame(
    fact_id = c(
      "f-later", "f-complete-old", "f-early", "f-complete", "f-interval"
    ),
    instrument_id = c("BBB", "OLD", "EARLY", "AAA", "INTERVAL"),
    universe_id = "research",
    set_id = c("later", "complete_old", "early", "complete", NA_character_),
    effective_from = as.POSIXct(c(
      "2024-03-01", "2024-01-20", "2024-01-01", "2024-02-01",
      "2024-01-15"
    ), tz = "UTC"),
    effective_to = as.POSIXct(rep(NA_real_, 5L), origin = "1970-01-01", tz = "UTC"),
    knowledge_time = as.POSIXct(c(
      "2024-02-29", "2024-01-19", "2023-12-31", "2024-01-31",
      "2024-01-14"
    ), tz = "UTC"),
    member = TRUE,
    provenance_json = "{}",
    source = "workstream9",
    stringsAsFactors = FALSE
  )
  list(membership_sets = headers, membership = rows)
}

testthat::test_that("[LTB-0145] session construction preserves civil-time semantics", {
  input <- workstream9_sessions()
  candidate <- ledgr_facts_sessions(
    input,
    "XNYS",
    timezone = "America/New_York"
  )
  reference <- testthat::with_mocked_bindings(
    ledgr_facts_sessions(
      input,
      "XNYS",
      timezone = "America/New_York"
    ),
    ledgr_local_times_resolve = workstream9_scalar_local_times,
    .package = "ledgr"
  )
  testthat::expect_identical(candidate$rows, reference$rows)
  testthat::expect_identical(candidate$fact_hash, reference$fact_hash)

  labels <- c(
    "2024-03-10 01:30:00",
    "2024-03-10 02:30:00",
    "2024-03-10 03:30:00",
    "2024-11-03 01:30:00",
    "2024-11-03 02:30:00",
    "2024-02-29 09:30:00"
  )
  expected <- workstream9_scalar_local_times(labels, "America/New_York")
  actual <- ledgr:::ledgr_local_times_resolve(labels, "America/New_York")
  testthat::expect_identical(actual$counts, expected$counts)
  testthat::expect_identical(actual$values, expected$values)

  calls <- 0L
  original <- ledgr:::ledgr_local_time_resolve
  testthat::with_mocked_bindings(
    ledgr_facts_sessions(
      input[1:20, ],
      "XNYS",
      timezone = "America/New_York"
    ),
    ledgr_local_time_resolve = function(...) {
      calls <<- calls + 1L
      original(...)
    },
    .package = "ledgr"
  )
  testthat::expect_identical(calls, 0L)
})

testthat::test_that("[LTB-0146] membership resolution preserves set precedence", {
  data <- workstream9_membership_data()
  at <- as.POSIXct("2024-03-15", tz = "UTC")
  requested <- c("EARLY", "OLD", "AAA", "BBB", "INTERVAL", "UNKNOWN")
  result <- ledgr:::ledgr_membership_resolve_at(
    data,
    "research",
    at,
    requested
  )
  testthat::expect_identical(result$rows$instrument_id, requested)
  testthat::expect_identical(
    result$rows$member,
    c(FALSE, FALSE, TRUE, TRUE, TRUE, FALSE)
  )
  testthat::expect_identical(
    result$rows$reason,
    c(
      "omitted_from_complete_set",
      "omitted_from_complete_set",
      "member_asserted",
      "member_asserted",
      "member_asserted",
      "omitted_from_complete_set"
    )
  )
  testthat::expect_identical(
    result$rows$evidence_ids,
    c(
      "set:complete",
      "set:complete",
      "set:complete|fact:f-complete",
      "set:later|fact:f-later",
      "fact:f-interval",
      "set:complete"
    )
  )
  before <- ledgr:::ledgr_membership_resolve_at(
    data,
    "research",
    as.POSIXct("2023-12-01", tz = "UTC"),
    requested
  )
  testthat::expect_true(all(is.na(before$rows$member)))
  testthat::expect_true(all(before$rows$reason == "unknown_no_usable_evidence"))
})

testthat::test_that("[LTB-0147] membership rows are indexed once", {
  data <- workstream9_membership_data()
  original <- ledgr:::ledgr_membership_index_set_rows
  calls <- 0L
  rows_seen <- 0L
  testthat::local_mocked_bindings(
    ledgr_membership_index_set_rows = function(rows, ...) {
      calls <<- calls + 1L
      rows_seen <<- rows_seen + nrow(rows)
      original(rows, ...)
    },
    .package = "ledgr"
  )
  ledgr:::ledgr_membership_resolve_at(
    data,
    "research",
    as.POSIXct("2024-03-15", tz = "UTC")
  )
  testthat::expect_identical(calls, 1L)
  testthat::expect_identical(rows_seen, nrow(data$membership))
  source <- paste(deparse(body(ledgr:::ledgr_membership_resolve_at)), collapse = "\n")
  testthat::expect_match(source, "ledgr_membership_index_set_rows", fixed = TRUE)
  testthat::expect_no_match(source, "rows$set_id ==", fixed = TRUE)
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0148] vector sessions preserve snapshot identity", {
  input <- workstream9_sessions(as.Date("2024-03-09"), 3L)
  candidate <- ledgr_facts_sessions(
    input,
    "XNYS",
    timezone = "America/New_York"
  )
  reference <- testthat::with_mocked_bindings(
    ledgr_facts_sessions(
      input,
      "XNYS",
      timezone = "America/New_York"
    ),
    ledgr_local_times_resolve = workstream9_scalar_local_times,
    .package = "ledgr"
  )
  bars <- data.frame(
    instrument_id = "AAA",
    ts_utc = as.POSIXct("2024-03-11 20:00:00", tz = "UTC"),
    open = 10,
    high = 11,
    low = 9,
    close = 10,
    volume = 100,
    stringsAsFactors = FALSE
  )
  hashes <- vapply(list(candidate, reference), function(family) {
    path <- tempfile(fileext = ".duckdb")
    snapshot <- ledgr_snapshot_from_df(
      bars,
      instruments_df = data.frame(instrument_id = "AAA"),
      facts = ledgr_facts(family),
      db_path = path
    )
    on.exit({
      ledgr_snapshot_close(snapshot)
      unlink(path)
    }, add = TRUE)
    ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]]
  }, character(1))
  testthat::expect_identical(hashes[[1L]], hashes[[2L]])
})
