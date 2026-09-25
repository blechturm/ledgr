test_that("[LTB-0042] fact preparation preserves frozen identity", {
  matrix <- ws14_fact_matrix()
  expected_hashes <- c(
    membership =
      "6a7db910dd6274869b5f1bc9cc2c8bf5ba7097f92363962863d5957333ca4845",
    trading_status =
      "5194c9d0f0d4d52e14b62ecddfa17a15c5de3b697fce28e3a87813b7b940ac8d",
    lifetime =
      "8667ce315441d7bb9ecfc20c3bfe25fa3ceb351cbf6669c3528eaeb486474cf4",
    equity_corporate_actions =
      "bf0c34930d7166ef0b6cfb837d057121e958cfff7a536f9b1864db4fa227da51",
    sessions =
      "57f659aca780ba28f6f59afb2119e022f50f3ec2c5ef45f5d6814d4844b5f51a"
  )
  actual_hashes <- vapply(
    matrix$families,
    `[[`,
    character(1),
    "fact_hash"
  )
  expect_identical(actual_hashes, expected_hashes)
  expect_identical(
    matrix$facts$bundle_hash,
    "6f514e58e04230366fb7aed2c9d209bf1d388f3f3f8326269f3aec419f2aaaa1"
  )
  expect_identical(
    matrix$families$membership$rows$fact_id,
    c(
      "fact_e57309813aca420a370d042e5e61e374",
      "fact_6973cc57ea5d8c2df52e6b991a1bcefa",
      "fact_bad890b12d6eb9babe8f8803b995c368",
      "fact_150dbee2f738b5c1d21cde6430e2a1c0"
    )
  )
})

test_that("[LTB-0043] fact deduplication retains exact outcomes", {
  matrix <- ws14_fact_matrix()
  identity_families <- matrix$families[c(
    "membership",
    "trading_status",
    "lifetime",
    "equity_corporate_actions"
  )]
  for (family in identity_families) {
    rows <- family$rows
    compatible <- rbind(rows, rows[1L, , drop = FALSE])
    expect_identical(
      ledgr:::ledgr_fact_deduplicate(compatible, family$family),
      rows
    )

    conflicting <- rbind(rows, rows[1L, , drop = FALSE])
    conflicting$source[[nrow(conflicting)]] <- "conflicting_source"
    condition <- tryCatch(
      ledgr:::ledgr_fact_deduplicate(conflicting, family$family),
      error = identity
    )
    expect_s3_class(condition, "ledgr_fact_identity_conflict")
    expect_identical(
      condition$message,
      paste0(
        family$family,
        " contains incompatible payloads for the same canonical fact identity."
      )
    )
    expect_identical(condition$fact_ids, rows$fact_id[[1L]])
  }

  original_row_payload <- ledgr:::ledgr_fact_row_payload
  original_canonical_json <- ledgr:::canonical_json
  original_time_token <- ledgr:::ledgr_fact_time_token
  observe_counts <- function(n) {
    counts <- c(row_payload = 0L, canonical_json = 0L, time_token = 0L)
    rows <- ws14_scale_action_rows(n)
    normalized <- ledgr_facts_equity_corporate_actions(rows)$rows
    testthat::local_mocked_bindings(
      ledgr_fact_row_payload = function(...) {
        counts[["row_payload"]] <<- counts[["row_payload"]] + 1L
        original_row_payload(...)
      },
      canonical_json = function(...) {
        counts[["canonical_json"]] <<- counts[["canonical_json"]] + 1L
        original_canonical_json(...)
      },
      ledgr_fact_time_token = function(...) {
        counts[["time_token"]] <<- counts[["time_token"]] + 1L
        original_time_token(...)
      },
      .package = "ledgr"
    )
    ledgr:::ledgr_fact_deduplicate(normalized, "equity corporate actions")
    ledgr:::ledgr_fact_family_hash(
      "equity_corporate_actions",
      "equity",
      normalized,
      NULL,
      list(contract = "count_probe")
    )
    counts
  }
  expect_identical(observe_counts(20L), observe_counts(200L))
  expect_identical(observe_counts(20L)[["row_payload"]], 0L)
})

test_that("[LTB-0044] constructors retain validation precedence", {
  stamp <- ws14_utc("2020-01-02 16:00:00")
  invalid_interval <- function() {
    data.frame(
      fact_id = c("shared", "shared"),
      instrument_id = "AAA",
      effective_from = stamp,
      effective_to = stamp,
      member = c(TRUE, FALSE),
      status = c("active", "halted"),
      assertion = c("known_active", "known_inactive"),
      source = "matrix",
      stringsAsFactors = FALSE
    )
  }
  cases <- list(
    membership = list(
      call = function() ledgr_facts_membership_intervals(
        invalid_interval(),
        universe_id = "matrix"
      ),
      class = "ledgr_fact_invalid_interval",
      message = paste0(
        "membership intervals effective intervals must be half-open with ",
        "`effective_to > effective_from`."
      )
    ),
    trading_status = list(
      call = function() ledgr_facts_trading_status(invalid_interval()),
      class = "ledgr_fact_invalid_interval",
      message = paste0(
        "trading status effective intervals must be half-open with ",
        "`effective_to > effective_from`."
      )
    ),
    lifetime = list(
      call = function() ledgr_facts_lifetime(invalid_interval()),
      class = "ledgr_fact_invalid_interval",
      message = paste0(
        "lifetime effective intervals must be half-open with ",
        "`effective_to > effective_from`."
      )
    ),
    equity_corporate_actions = list(
      call = function() ledgr_facts_equity_corporate_actions(data.frame(
        fact_id = c("shared", "shared"),
        subtype = "ordinary_cash_dividend",
        parent_instrument_id = "AAA",
        entitlement_time = stamp,
        effective_time = stamp,
        knowledge_time = stamp,
        complete = TRUE,
        provenance_tier = "snapshot_bound",
        gross_cash_per_parent_unit = c(1, 2),
        gross_cash_validated = FALSE,
        recipient_identity_validated = FALSE,
        recipient_quantity_validated = FALSE,
        stringsAsFactors = FALSE
      )),
      class = "ledgr_fact_identity_conflict",
      message = paste0(
        "Equity corporate-action `fact_id` values must be non-empty and ",
        "unique."
      )
    ),
    sessions = list(
      call = function() ledgr_facts_sessions(
        data.frame(
          session_date = as.Date(c("2020-01-01", "2020-01-01")),
          status = c("invalid", "closed"),
          session_open = c("09:30:00", NA_character_),
          session_close = c("16:00:00", NA_character_),
          stringsAsFactors = FALSE
        ),
        venue_id = "MATRIX"
      ),
      class = "ledgr_session_invalid",
      message = "Session calendar contains duplicate `session_date` values."
    )
  )
  for (case in cases) {
    condition <- tryCatch(case$call(), error = identity)
    expect_s3_class(condition, case$class)
    expect_identical(condition$message, case$message)
  }
})

# ledgr-test-profile: review
test_that("[LTB-0045] rule-2 identity retains frozen hashes", {
  expected <- c(
    `0` = "d148f57b818a615db3cb9a1a4ae78db9b972b537ba20e1528dbc5c3596b088f9",
    `20000` = "5f612f017cfefcb503833342acb1082e9c8ca5cfe3ad05f2bb029c474fa26148",
    `100000` = "d03a9d7f7faac4d87de0d421c92f4afaf23c7795049e5084abb739032a00fe68"
  )
  bars <- ws14_scale_bars()
  instruments <- ws14_scale_instruments()
  actual <- vapply(names(expected), function(size) {
    path <- tempfile(fileext = ".duckdb")
    snapshot <- ledgr_snapshot_from_df(
      bars,
      instruments_df = instruments,
      db_path = path,
      facts = ws14_scale_facts(as.integer(size))
    )
    on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
    ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]]
  }, character(1))
  expect_identical(unname(actual), unname(expected))

  snapshot <- ws14_matrix_snapshot()
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  expect_identical(
    ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]],
    "c4b2aea914f46e4ff97b6eead3fe7a42d618f56a8e948b4f256ab5cd03e4aa85"
  )
})

test_that("[LTB-0046] rule-2 hashing performs fixed encoding work", {
  snapshots <- lapply(c(20L, 200L), function(size) {
    ledgr_snapshot_from_df(
      ws14_scale_bars(),
      instruments_df = ws14_scale_instruments(),
      facts = ws14_scale_facts(size)
    )
  })
  on.exit(lapply(snapshots, ledgr_snapshot_close), add = TRUE)

  original_row_payload <- ledgr:::ledgr_fact_row_payload
  original_canonical_json <- ledgr:::canonical_json
  original_time_token <- ledgr:::ledgr_fact_time_token
  observe_counts <- function(snapshot) {
    counts <- c(row_payload = 0L, canonical_json = 0L, time_token = 0L)
    testthat::local_mocked_bindings(
      ledgr_fact_row_payload = function(...) {
        counts[["row_payload"]] <<- counts[["row_payload"]] + 1L
        original_row_payload(...)
      },
      canonical_json = function(...) {
        counts[["canonical_json"]] <<- counts[["canonical_json"]] + 1L
        original_canonical_json(...)
      },
      ledgr_fact_time_token = function(...) {
        counts[["time_token"]] <<- counts[["time_token"]] + 1L
        original_time_token(...)
      },
      .package = "ledgr"
    )
    ledgr:::ledgr_snapshot_availability_hash_payload(
      ledgr:::get_connection(snapshot),
      snapshot$snapshot_id
    )
    counts
  }
  small <- observe_counts(snapshots[[1L]])
  large <- observe_counts(snapshots[[2L]])
  expect_identical(small, large)
  expect_identical(small[["row_payload"]], 0L)
})

# ledgr-test-profile: review
test_that("[LTB-0047] the full snapshot path asserts facts once", {
  matrix <- ws14_fact_matrix()
  calls <- 0L
  original <- ledgr:::ledgr_facts_assert
  testthat::local_mocked_bindings(
    ledgr_facts_assert = function(...) {
      calls <<- calls + 1L
      original(...)
    },
    .package = "ledgr"
  )
  snapshot <- ws14_matrix_snapshot()
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  expect_identical(calls, 1L)

  invalid <- matrix$facts
  invalid$bundle_hash <- paste0("0", substring(invalid$bundle_hash, 2L))
  expect_error(
    ledgr:::ledgr_availability_validate_inputs(
      invalid,
      ws14_matrix_bars(FALSE),
      data.frame(instrument_id = c("AAA", "BBB", "CHILD")),
      "error"
    ),
    class = "ledgr_invalid_facts"
  )

  path <- tempfile(fileext = ".duckdb")
  con <- ledgr_db_init(path)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  snapshot_id <- ledgr_snapshot_create(con)
  expect_error(
    ledgr:::ledgr_snapshot_write_availability(
      con,
      snapshot_id,
      invalid,
      data.frame(),
      "error"
    ),
    class = "ledgr_invalid_facts"
  )
})

# ledgr-test-profile: review
test_that("[LTB-0048] every persisted fact table remains corruption-bound", {
  mutations <- list(
    snapshot_fact_families = paste(
      "UPDATE snapshot_fact_families",
      "SET metadata_json = '{\"tampered\":true}'",
      "WHERE snapshot_id = ? AND family = 'membership'"
    ),
    snapshot_membership_sets = paste(
      "UPDATE snapshot_membership_sets SET complete = FALSE",
      "WHERE snapshot_id = ? AND complete = TRUE"
    ),
    snapshot_membership = paste(
      "UPDATE snapshot_membership SET member = FALSE",
      "WHERE snapshot_id = ? AND member = TRUE"
    ),
    snapshot_trading_status = paste(
      "UPDATE snapshot_trading_status SET status = 'halted'",
      "WHERE snapshot_id = ? AND status <> 'halted'"
    ),
    snapshot_lifetime = paste(
      "UPDATE snapshot_lifetime SET assertion = 'unknown'",
      "WHERE snapshot_id = ? AND assertion = 'known_inactive'"
    ),
    snapshot_equity_corporate_actions = paste(
      "UPDATE snapshot_equity_corporate_actions",
      "SET gross_cash_per_parent_unit = gross_cash_per_parent_unit + 0.5",
      "WHERE snapshot_id = ? AND gross_cash_per_parent_unit IS NOT NULL"
    ),
    snapshot_sessions = paste(
      "UPDATE snapshot_sessions SET status = 'closed'",
      "WHERE snapshot_id = ? AND status = 'open'"
    ),
    snapshot_observation_quarantine = paste(
      "UPDATE snapshot_observation_quarantine",
      "SET reason = reason || '_tampered' WHERE snapshot_id = ?"
    )
  )
  for (table in names(mutations)) {
    snapshot <- ws14_matrix_snapshot()
    con <- ledgr:::get_connection(snapshot)
    stored_hash <- ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]]
    changed <- DBI::dbExecute(
      con,
      mutations[[table]],
      params = list(snapshot$snapshot_id)
    )
    expect_true(changed > 0L, info = table)
    expect_identical(
      ledgr_snapshot_info(snapshot)$snapshot_hash[[1L]],
      stored_hash,
      info = table
    )
    expect_error(
      ledgr_run(
        ws14_matrix_experiment(snapshot),
        run_id = paste0("tamper-", table)
      ),
      class = "LEDGR_SNAPSHOT_CORRUPTED",
      info = table
    )
    ledgr_snapshot_close(snapshot)
  }
})

# ledgr-test-profile: review
test_that("[LTB-0049] physical fact-row order cannot move identity", {
  snapshot <- ws14_matrix_snapshot()
  on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
  con <- ledgr:::get_connection(snapshot)
  before <- ledgr:::ledgr_snapshot_hash(
    con,
    snapshot$snapshot_id
  )
  order_keys <- c(
    snapshot_fact_families = "family, scope_id",
    snapshot_membership_sets = "universe_id, set_id",
    snapshot_membership = "fact_id",
    snapshot_trading_status = "fact_id",
    snapshot_lifetime = "fact_id",
    snapshot_equity_corporate_actions = "fact_id",
    snapshot_sessions = "venue_id, session_date",
    snapshot_observation_quarantine = paste(
      "supplied_instrument_id, supplied_ts_utc, reason,",
      "original_row_json, provenance_json"
    )
  )
  for (index in seq_along(order_keys)) {
    table <- names(order_keys)[[index]]
    temporary <- paste0("ws14_reordered_", index)
    DBI::dbExecute(
      con,
      sprintf(
        paste(
          "CREATE TEMP TABLE %s AS SELECT * FROM %s",
          "WHERE snapshot_id = ? ORDER BY %s DESC"
        ),
        temporary,
        table,
        order_keys[[index]]
      ),
      params = list(snapshot$snapshot_id)
    )
    DBI::dbExecute(
      con,
      sprintf("DELETE FROM %s WHERE snapshot_id = ?", table),
      params = list(snapshot$snapshot_id)
    )
    DBI::dbExecute(
      con,
      sprintf("INSERT INTO %s SELECT * FROM %s", table, temporary)
    )
    DBI::dbExecute(con, sprintf("DROP TABLE %s", temporary))
  }
  expect_identical(
    ledgr:::ledgr_snapshot_hash(con, snapshot$snapshot_id),
    before
  )
  expect_silent(ledgr_snapshot_validate(snapshot))
})
