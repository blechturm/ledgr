availability_inspection_membership <- function() {
  ledgr_facts_membership_intervals(
    data.frame(
      instrument_id = c("AAA", "BBB", "CCC", "DDD", "EEE"),
      effective_from = as.POSIXct(c(
        "2024-01-01", "2024-01-01", "2024-02-01", "2024-01-01", "2024-01-01"
      ), tz = "UTC"),
      knowledge_time = as.POSIXct(c(
        "2023-12-31", "2023-12-31", "2024-01-01", "2024-02-01", NA
      ), tz = "UTC"),
      member = c(TRUE, FALSE, TRUE, TRUE, TRUE),
      source = "vendor",
      stringsAsFactors = FALSE
    ),
    universe_id = "research"
  )
}

availability_inspection_sessions <- function(start = as.Date("2024-01-01"), days = 5L) {
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

availability_inspection_bars <- function(date = as.Date("2024-01-02")) {
  data.frame(
    instrument_id = "AAA",
    ts_utc = date,
    open = 10, high = 11, low = 9, close = 10, volume = 100,
    stringsAsFactors = FALSE
  )
}

testthat::test_that("history is retrospective while cutoff resolution is causal", {
  membership <- availability_inspection_membership()
  facts <- ledgr_facts(membership)
  history <- ledgr_facts_history(facts, "membership", "research")
  testthat::expect_s3_class(history, "ledgr_facts_history")
  testthat::expect_s3_class(history$rows, "tbl_df")
  testthat::expect_s3_class(history$evidence, "tbl_df")
  testthat::expect_equal(nrow(history$rows), 5L)
  testthat::expect_setequal(history$rows$instrument_id, c("AAA", "BBB", "CCC", "DDD", "EEE"))
  testthat::expect_output(print(history), "Rows:   5", fixed = TRUE)
  bounded <- ledgr_facts_history(
    facts,
    "membership",
    "research",
    instruments = c("AAA", "CCC"),
    from = "2024-01-15T00:00:00Z",
    to = "2024-03-01T00:00:00Z"
  )
  testthat::expect_setequal(bounded$rows$instrument_id, c("AAA", "CCC"))

  requested <- c("AAA", "BBB", "CCC", "DDD", "EEE", "ZZZ", "AAA")
  resolved <- ledgr_facts_resolve(
    facts,
    "membership",
    "research",
    as.POSIXct("2024-01-15", tz = "UTC"),
    requested
  )
  testthat::expect_s3_class(resolved, "ledgr_facts_resolution")
  testthat::expect_identical(
    resolved$rows$instrument_id,
    c("AAA", "BBB", "CCC", "DDD", "EEE", "ZZZ")
  )
  testthat::expect_identical(resolved$rows$member, c(TRUE, FALSE, NA, NA, NA, NA))
  testthat::expect_identical(
    resolved$rows$reason,
    c(
      "member_asserted", "nonmember_asserted",
      rep("unknown_no_usable_evidence", 4L)
    )
  )
  testthat::expect_setequal(resolved$evidence$instrument_id, c("AAA", "BBB"))
  testthat::expect_false(any(grepl("CCC|DDD|EEE", resolved$rows$evidence_ids)))
  testthat::expect_false(any(resolved$evidence$instrument_id %in% c("CCC", "DDD", "EEE")))
  testthat::expect_output(print(resolved), "ledgr facts resolution", fixed = TRUE)

  default <- ledgr_facts_resolve(
    membership,
    "membership",
    "research",
    "2024-01-15T00:00:00Z"
  )
  testthat::expect_identical(default$rows$instrument_id, "AAA")
  runtime <- ledgr:::ledgr_availability_members_at(
    ledgr:::ledgr_facts_inspection_data(facts),
    ledgr_universe_members("research"),
    character(),
    as.POSIXct("2024-01-15", tz = "UTC")
  )
  testthat::expect_identical(runtime, default$rows$instrument_id)
})

testthat::test_that("complete sets distinguish omission from unknown", {
  input <- data.frame(
    effective_from = as.POSIXct("2024-01-01", tz = "UTC"),
    knowledge_time = as.POSIXct("2023-12-31", tz = "UTC"),
    stringsAsFactors = FALSE
  )
  input$members <- list("AAA")
  complete <- ledgr_facts_membership_snapshots(input, "complete", complete = TRUE)
  partial <- ledgr_facts_membership_snapshots(input, "partial", complete = FALSE)
  complete_result <- ledgr_facts_resolve(
    complete, "membership", "complete", "2024-01-15T00:00:00Z", c("AAA", "BBB")
  )
  partial_result <- ledgr_facts_resolve(
    partial, "membership", "partial", "2024-01-15T00:00:00Z", c("AAA", "BBB")
  )
  testthat::expect_identical(complete_result$rows$member, c(TRUE, FALSE))
  testthat::expect_identical(
    complete_result$rows$reason[[2L]],
    "omitted_from_complete_set"
  )
  testthat::expect_match(complete_result$rows$evidence_ids[[2L]], "^set:")
  testthat::expect_false(any(
    complete_result$evidence$evidence_type == "membership_assertion" &
      complete_result$evidence$instrument_id == "BBB"
  ))
  testthat::expect_identical(partial_result$rows$member, c(TRUE, NA))
})

testthat::test_that("session history and resolution retain civil-time semantics", {
  sessions <- ledgr_facts_sessions(
    availability_inspection_sessions(start = as.Date("2024-01-01"), days = 5L),
    "XNYS",
    timezone = "America/New_York"
  )
  history <- ledgr_facts_history(
    sessions,
    "sessions",
    "XNYS",
    from = as.Date("2024-01-02"),
    to = as.Date("2024-01-04")
  )
  testthat::expect_identical(history$rows$session_date, as.Date("2024-01-02") + 0:2)
  testthat::expect_error(
    ledgr_facts_history(sessions, "sessions", "XNYS", instruments = "AAA"),
    class = "ledgr_facts_inspection_invalid_args"
  )
  resolved <- ledgr_facts_resolve(
    sessions,
    "sessions",
    "XNYS",
    "2024-01-02T17:00:00Z"
  )
  testthat::expect_identical(resolved$rows$status, "open")
  testthat::expect_identical(resolved$rows$reason, "session_asserted")
  testthat::expect_equal(nrow(resolved$evidence), 1L)
  testthat::expect_error(
    ledgr_facts_resolve(sessions, "sessions", "XNYS", as.Date("2024-01-02")),
    class = "ledgr_facts_inspection_invalid_args"
  )
  testthat::expect_error(
    ledgr_facts_resolve(sessions, "sessions", "missing", "2024-01-02T17:00:00Z"),
    class = "ledgr_facts_scope_not_found"
  )
})

testthat::test_that("fact inspection prints curated causal evidence without mutation", {
  membership <- availability_inspection_membership()
  membership_history <- ledgr_facts_history(membership, "membership", "research")
  membership_resolution <- ledgr_facts_resolve(
    membership,
    "membership",
    "research",
    "2024-01-15T00:00:00Z",
    c("AAA", "CCC")
  )
  sessions <- ledgr_facts_sessions(
    availability_inspection_sessions(as.Date("2024-01-02"), 2L),
    "XNYS",
    timezone = "America/New_York"
  )
  session_history <- ledgr_facts_history(sessions, "sessions", "XNYS")
  session_resolution <- ledgr_facts_resolve(
    sessions, "sessions", "XNYS", "2024-01-02T17:00:00Z"
  )
  future_rows <- data.frame(
    session_date = as.Date("2024-01-02"),
    status = "open",
    session_open = "09:30:00",
    session_close = "16:00:00",
    knowledge_time = as.POSIXct("2024-01-02 08:00:00", tz = "UTC"),
    stringsAsFactors = FALSE
  )
  future_sessions <- ledgr_facts_sessions(
    future_rows, "XNYS", timezone = "UTC"
  )
  future_resolution <- ledgr_facts_resolve(
    future_sessions, "sessions", "XNYS", "2024-01-02T07:00:00Z"
  )
  testthat::expect_identical(nrow(future_resolution$evidence), 0L)
  results <- list(
    membership_history, membership_resolution, session_history,
    session_resolution, future_resolution
  )
  before <- lapply(results, serialize, connection = NULL)
  output <- lapply(results, function(result) utils::capture.output(print(result)))
  after <- lapply(results, serialize, connection = NULL)

  testthat::expect_identical(after, before)
  testthat::expect_match(
    paste(output[[1L]], collapse = "\n"),
    "evidence_type.+instrument_id.+member.+effective_from.+knowledge_time.+complete"
  )
  testthat::expect_match(
    paste(output[[2L]], collapse = "\n"),
    "instrument_id.+member.+reason"
  )
  testthat::expect_match(
    paste(output[[3L]], collapse = "\n"),
    "session_date.+status.+session_open.+session_close.+knowledge_time"
  )
  testthat::expect_match(
    paste(output[[4L]], collapse = "\n"),
    "session_date.+status.+session_open.+session_close.+reason.+knowledge_time"
  )
  testthat::expect_match(paste(output[[4L]], collapse = "\n"), "2023-12-01")
  testthat::expect_match(
    paste(output[[4L]], collapse = "\n"),
    "knowledge_time is derived from $evidence; it is not stored in $rows.",
    fixed = TRUE
  )
  testthat::expect_match(paste(output[[5L]], collapse = "\n"), "not_yet_knowable")
  testthat::expect_match(paste(output[[5L]], collapse = "\n"), "NA")
  testthat::expect_no_match(paste(output[[5L]], collapse = "\n"), "2024-01-02 08:00")
  for (printed in output) {
    text <- paste(printed, collapse = "\n")
    testthat::expect_match(text, "Rows:", fixed = TRUE)
    testthat::expect_match(text, "Omitted stored columns:", fixed = TRUE)
    testthat::expect_match(text, "Full rows remain in $rows", fixed = TRUE)
  }
})

testthat::test_that("resolution knowledge time ignores unsupported evidence", {
  supporting_time <- as.POSIXct("2024-01-01 08:00:00", tz = "UTC")
  unsupported_time <- as.POSIXct("2024-01-02 08:00:00", tz = "UTC")
  result <- list(
    rows = tibble::tibble(evidence_ids = "session:XNYS:2024-01-02"),
    evidence = tibble::tibble(
      evidence_id = c("session:XNYS:2024-01-02", "future:unsupported"),
      knowledge_time = c(supporting_time, unsupported_time)
    )
  )

  testthat::expect_identical(
    ledgr_facts_resolution_knowledge_time(result),
    supporting_time
  )
})

testthat::test_that("inspection argument combinations fail with typed errors", {
  membership <- availability_inspection_membership()
  testthat::expect_error(
    ledgr_facts_history(membership, "status", "research"),
    class = "ledgr_facts_inspection_invalid_args"
  )
  testthat::expect_error(
    ledgr_facts_history(membership, "membership", "research", instruments = character()),
    class = "ledgr_facts_inspection_invalid_args"
  )
  testthat::expect_error(
    ledgr_facts_history(
      membership,
      "membership",
      "research",
      from = "2024-02-01T00:00:00Z",
      to = "2024-01-01T00:00:00Z"
    ),
    class = "ledgr_facts_inspection_invalid_args"
  )
  testthat::expect_error(
    ledgr_facts_resolve(membership, "membership", "research", "2024-01-15"),
    class = "ledgr_facts_inspection_invalid_args"
  )
  testthat::expect_error(
    ledgr_facts_resolve(data.frame(), "membership", "research", "2024-01-15T00:00:00Z"),
    class = "ledgr_facts_inspection_invalid_args"
  )
})

testthat::test_that("sealed snapshot inspection verifies evidence and connection ownership", {
  membership <- availability_inspection_membership()
  bars <- availability_inspection_bars(as.Date("2024-01-02"))
  instruments <- data.frame(
    instrument_id = c("AAA", "BBB", "CCC", "DDD", "EEE"),
    stringsAsFactors = FALSE
  )
  db_path <- tempfile(fileext = ".duckdb")
  snapshot <- ledgr_snapshot_from_df(
    bars,
    instruments_df = instruments,
    facts = ledgr_facts(membership),
    db_path = db_path
  )
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  in_memory <- ledgr_facts_resolve(
    membership, "membership", "research", "2024-01-15T00:00:00Z", c("AAA", "BBB", "ZZZ")
  )
  con <- ledgr:::get_connection(snapshot)
  before_tables <- ledgr:::ledgr_snapshot_availability_read(con, snapshot$snapshot_id)
  set.seed(2708)
  rng_before <- .Random.seed
  from_snapshot <- ledgr_facts_resolve(
    snapshot, "membership", "research", "2024-01-15T00:00:00Z", c("AAA", "BBB", "ZZZ")
  )
  testthat::expect_true(DBI::dbIsValid(con))
  testthat::expect_identical(from_snapshot$rows, in_memory$rows)
  testthat::expect_identical(from_snapshot$evidence, in_memory$evidence)
  testthat::expect_identical(from_snapshot$metadata$source, "snapshot")
  testthat::expect_identical(from_snapshot$metadata$snapshot_id, snapshot$snapshot_id)
  testthat::expect_identical(.Random.seed, rng_before)
  testthat::expect_identical(
    ledgr:::ledgr_snapshot_availability_read(con, snapshot$snapshot_id),
    before_tables
  )
  testthat::expect_false(any(c("callback", "strategy") %in% names(formals(ledgr_facts_resolve))))

  ledgr_snapshot_close(snapshot)
  reopened <- ledgr_snapshot_open(db_path, snapshot$snapshot_id, verify = FALSE)
  reopened_result <- ledgr_facts_resolve(
    reopened, "membership", "research", "2024-01-15T00:00:00Z", c("AAA", "BBB")
  )
  testthat::expect_identical(reopened_result$rows, in_memory$rows[1:2, ])
  state <- ledgr:::snapshot_state(reopened)
  testthat::expect_null(state$con)

  corrupt <- ledgr_snapshot_open(db_path, snapshot$snapshot_id, verify = FALSE)
  corrupt_con <- ledgr:::get_connection(corrupt)
  DBI::dbExecute(
    corrupt_con,
    "UPDATE snapshot_membership SET member = FALSE WHERE snapshot_id = ? AND instrument_id = 'AAA'",
    params = list(snapshot$snapshot_id)
  )
  testthat::expect_error(
    ledgr_facts_resolve(corrupt, "membership", "research", "2024-01-15T00:00:00Z"),
    class = "ledgr_facts_snapshot_hash_mismatch"
  )
  ledgr_snapshot_close(corrupt)

  created_path <- tempfile(fileext = ".duckdb")
  created_con <- ledgr_db_init(created_path)
  created_id <- ledgr_snapshot_create(created_con)
  DBI::dbDisconnect(created_con, shutdown = TRUE)
  created <- ledgr:::new_ledgr_snapshot(created_path, created_id)
  testthat::expect_error(
    ledgr_facts_history(created, "membership", "research"),
    class = "ledgr_facts_snapshot_not_sealed"
  )
})

testthat::test_that("snapshot resolution works in a fresh process without a facts object", {
  testthat::skip_if_not_installed("pkgload")
  membership <- availability_inspection_membership()
  db_path <- tempfile(fileext = ".duckdb")
  snapshot <- ledgr_snapshot_from_df(
    availability_inspection_bars(as.Date("2024-01-02")),
    instruments_df = data.frame(instrument_id = c("AAA", "BBB", "CCC", "DDD", "EEE")),
    facts = ledgr_facts(membership),
    db_path = db_path
  )
  snapshot_id <- snapshot$snapshot_id
  ledgr_snapshot_close(snapshot)
  script <- tempfile(fileext = ".R")
  root <- normalizePath(testthat::test_path("..", ".."), winslash = "/")
  writeLines(c(
    "args <- commandArgs(trailingOnly = TRUE)",
    "pkgload::load_all(args[[1L]], quiet = TRUE)",
    "snapshot <- ledgr_snapshot_open(args[[2L]], args[[3L]], verify = FALSE)",
    "result <- ledgr_facts_resolve(snapshot, 'membership', 'research', '2024-01-15T00:00:00Z')",
    "cat(paste(result$rows$instrument_id, collapse = ','))"
  ), script)
  output <- system2(
    file.path(R.home("bin"), "Rscript"),
    c(shQuote(script), shQuote(root), shQuote(db_path), shQuote(snapshot_id)),
    stdout = TRUE,
    stderr = TRUE
  )
  testthat::expect_identical(attr(output, "status"), NULL)
  testthat::expect_match(paste(output, collapse = "\n"), "AAA", fixed = TRUE)
})
