availability_v201_capture_validation <- function(fn, rows) {
  tryCatch(
    {
      fn(rows)
      list(ok = TRUE, classes = character(), message = "")
    },
    error = function(error) {
      list(
        ok = FALSE,
        classes = class(error),
        message = conditionMessage(error)
      )
    }
  )
}

testthat::test_that("pairwise validators are retained exactly for later gates", {
  at <- availability_v201_at
  na_time <- availability_v201_na_time
  membership <- data.frame(
    instrument_id = c("AAA", "AAA"),
    universe_id = c("U", "U"),
    member = c(TRUE, FALSE),
    effective_from = at(c(1L, 2L)),
    effective_to = c(at(4L), na_time()),
    stringsAsFactors = FALSE
  )
  lifetime <- data.frame(
    instrument_id = c("AAA", "AAA"),
    assertion = c("known_active", "known_inactive"),
    effective_from = at(c(1L, 4L)),
    effective_to = c(at(4L), na_time()),
    stringsAsFactors = FALSE
  )
  status <- data.frame(
    instrument_id = c("AAA", "AAA", "AAA"),
    source = "venue",
    precedence = 5L,
    status = c("halted", "active", "quotation_only"),
    effective_from = at(c(1L, 2L, 3L)),
    effective_to = na_time(3L),
    fact_id = c("old", "new", "other"),
    supersedes_fact_id = c(NA_character_, "old", NA_character_),
    stringsAsFactors = FALSE
  )

  cases <- list(
    list(
      reference = availability_reference_validate_membership_conflicts,
      production = ledgr:::ledgr_fact_validate_membership_conflicts,
      rows = membership
    ),
    list(
      reference = availability_reference_validate_membership_conflicts,
      production = ledgr:::ledgr_fact_validate_membership_conflicts,
      rows = transform(membership, effective_from = at(c(1L, 4L)))
    ),
    list(
      reference = availability_reference_validate_lifetime_conflicts,
      production = ledgr:::ledgr_fact_validate_lifetime_conflicts,
      rows = lifetime
    ),
    list(
      reference = availability_reference_validate_status_conflicts,
      production = ledgr:::ledgr_fact_validate_source_conflicts,
      rows = status[1:2, ]
    ),
    list(
      reference = availability_reference_validate_status_conflicts,
      production = ledgr:::ledgr_fact_validate_source_conflicts,
      rows = status
    )
  )
  for (case in cases) {
    expected <- availability_v201_capture_validation(
      case$production,
      case$rows
    )
    actual <- availability_v201_capture_validation(case$reference, case$rows)
    testthat::expect_identical(actual, expected)
  }

  testthat::expect_error(
    availability_v201_assert_frozen(
      availability_v201_capture_validation(
        availability_reference_validate_membership_conflicts,
        membership
      ),
      availability_v201_capture_validation(
        availability_reference_validate_membership_conflicts,
        membership[1L, ]
      )
    ),
    "frozen witness mismatch"
  )
})

testthat::test_that("row-list writer reference preserves its production shape", {
  pulses <- availability_v201_at(1:2)
  reference <- availability_reference_row_list_writer("witness", pulses)
  production <- ledgr:::ledgr_row_list_diagnostic_writer("witness", pulses)
  row <- ledgr:::ledgr_availability_diagnostic_row(
    run_id = "witness",
    diagnostic_seq = 1L,
    ts_utc = pulses[[1L]],
    stage = "decision",
    outcome = "recorded",
    reason_code = "decision_recorded"
  )
  reference$append(row, 1L)
  production$append(row, 1L)
  testthat::expect_identical(reference$drain(), production$drain())

  empty_reference <- availability_reference_row_list_writer("witness", pulses)
  empty_production <- ledgr:::ledgr_row_list_diagnostic_writer(
    "witness",
    pulses
  )
  testthat::expect_identical(
    empty_reference$drain(),
    empty_production$drain()
  )
})
