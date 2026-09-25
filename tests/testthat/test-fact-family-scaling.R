# LTB-0042
test_that("fact preparation preserves frozen family and bundle identity", {
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

# LTB-0043
test_that("fact deduplication is set-wise and retains exact outcomes", {
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

# LTB-0044
test_that("pre-deduplication validators retain error precedence", {
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
