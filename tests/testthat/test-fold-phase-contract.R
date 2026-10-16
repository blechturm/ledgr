# ledgr-test-file-profile: review

testthat::test_that("[LTB-0278] fold state and stop results have one closed typed shape", {
  state <- ledgr_fold_state_new(
    cash = 100,
    positions = c(AAA = 1, BBB = 0),
    lot_state = list(AAA = list(), BBB = list()),
    state_prev = list(month = "2026-10"),
    state_axis = c("AAA", "BBB"),
    event_seq = 3L
  )
  testthat::expect_true(is.environment(state))
  testthat::expect_true(environmentIsLocked(state))
  testthat::expect_setequal(ls(state, all.names = TRUE), .ledgr_fold_state_slots)
  testthat::expect_false(any(vapply(
    mget(.ledgr_fold_state_slots, envir = state, inherits = FALSE),
    is.data.frame,
    logical(1L)
  )))
  state$cash <- 90
  testthat::expect_identical(state$cash, 90)
  testthat::expect_error(state$undeclared <- 1, "locked environment")
  testthat::expect_error(
    ledgr_fold_state_new(
      cash = 100,
      positions = c(AAA = 1),
      lot_state = list(AAA = list()),
      state_prev = data.frame(value = 1)
    ),
    class = "ledgr_internal_error"
  )
  scalar_state <- ledgr_fold_state_new(
    cash = 100,
    positions = c(AAA = 1),
    lot_state = list(AAA = list()),
    state_prev = 5
  )
  testthat::expect_identical(scalar_state$state_prev, 5)
  facts <- ledgr_fold_equity_fact_accumulator(2L)
  facts$append(list(ts_utc = 1, cash = 100))
  facts$append(list(ts_utc = 2, cash = 101))
  testthat::expect_identical(
    facts$collect(),
    list(
      list(ts_utc = 1, cash = 100),
      list(ts_utc = 2, cash = 101)
    )
  )
  testthat::expect_error(
    facts$append(list(ts_utc = 3, cash = 102)),
    class = "ledgr_internal_error"
  )
  testthat::expect_error(
    ledgr_fold_state_new(
      cash = 100,
      positions = unname(c(AAA = 1)),
      lot_state = list(AAA = list())
    ),
    class = "ledgr_internal_error"
  )

  stop <- ledgr_fold_stop_result(
    status = "INCOMPLETE",
    reason_code = "risk_mark_unavailable",
    affected_instrument_ids = "AAA",
    affected_exposure = list(value = 10),
    diagnostic_segments = list(list(stage = "risk")),
    counts_processed = TRUE
  )
  testthat::expect_true(ledgr_is_fold_stop_result(stop))
  testthat::expect_identical(
    names(stop),
    c(
      "status", "reason_code", "affected_instrument_ids",
      "affected_exposure", "diagnostic_segments", "counts_processed"
    )
  )
  testthat::expect_true(stop$counts_processed)
  testthat::expect_error(
    ledgr_fold_stop_result("INCOMPLETE", NA_character_),
    class = "ledgr_internal_error"
  )
})

testthat::test_that("[LTB-0279] fold phase ownership rejects structural boundary drift", {
  repository <- ledgr_test_source_root()
  checker_path <- file.path(repository, "tools", "check-fold-phase-contract.R")
  testthat::expect_true(file.exists(checker_path))
  checker_env <- new.env(parent = baseenv())
  sys.source(checker_path, envir = checker_env)
  testthat::expect_silent(checker_env$ledgr_fold_phase_check(repository))

  check_fixture <- function(lines) {
    path <- tempfile(fileext = ".R")
    on.exit(unlink(path), add = TRUE)
    writeLines(lines, path)
    checker_env$ledgr_fold_phase_source_findings(path)
  }
  base_stages <- c(
    "ledgr_fold_stage_observe_settle <- function(fold_state, services, pulse_idx) NULL",
    "ledgr_fold_stage_decide <- function(fold_state, services, pulse_idx) NULL",
    "ledgr_fold_stage_plan <- function(fold_state, services, pulse_idx) NULL",
    "ledgr_fold_stage_apply <- function(fold_state, services, pulse_idx) NULL",
    "ledgr_fold_stage_commit <- function(fold_state, services, pulse_idx) NULL"
  )
  mutations <- list(
    data_frame_argument = "ledgr_fold_stage_decide <- function(fold_state, services, bars) NULL",
    data_frame_slot = "ledgr_fold_stage_decide <- function(fold_state, services) fold_state$cash <- data.frame(x = 1)",
    second_mutable_aggregate = "ledgr_fold_stage_decide <- function(fold_state, services) state_copy <- fold_state",
    ctx_references_carrier = "ledgr_fold_stage_decide <- function(fold_state, services) ctx$private <- fold_state",
    slot_owner = "ledgr_fold_stage_decide <- function(fold_state, services) fold_state$cash <- 1",
    service_owner = "ledgr_fold_stage_decide <- function(fold_state, services) valuation_state$advance(1)",
    history_service_owner =
      "ledgr_fold_stage_decide <- function(fold_state, services) services$history_reader$bars(1)",
    substrate_reference =
      "ledgr_fold_stage_decide <- function(fold_state, services) services$history_substrate$bars",
    duplicated_inline_stage_body = c(
      base_stages,
      "ledgr_fold_envelope <- function(execution, output_handler) output_handler$write_fill_events(data.frame())"
    ),
    environment_vector_write =
      "ledgr_fold_stage_apply <- function(fold_state, services) fold_state$positions[[1L]] <- 1",
    returned_data_frame =
      "ledgr_fold_stage_decide <- function(fold_state, services) list(value = data.frame(x = 1))",
    stage_call_count = c(
      base_stages,
      "ledgr_fold_envelope <- function(execution, output_handler) { ledgr_fold_stage_observe_settle(); ledgr_fold_stage_decide(); ledgr_fold_stage_plan(); ledgr_fold_stage_apply() }"
    ),
    stage_call_order = c(
      base_stages,
      "ledgr_fold_envelope <- function(execution, output_handler) { ledgr_fold_stage_decide(); ledgr_fold_stage_observe_settle(); ledgr_fold_stage_plan(); ledgr_fold_stage_apply(); ledgr_fold_stage_commit() }"
    ),
    envelope_slot_owner = c(
      base_stages,
      "ledgr_fold_envelope <- function(execution, output_handler) { fold_state$cash <- 1; ledgr_fold_stage_observe_settle(); ledgr_fold_stage_decide(); ledgr_fold_stage_plan(); ledgr_fold_stage_apply(); ledgr_fold_stage_commit() }"
    )
  )
  for (kind in names(mutations)) {
    findings <- check_fixture(mutations[[kind]])
    expected_kind <- if (identical(kind, "history_service_owner")) {
      "service_owner"
    } else {
      kind
    }
    testthat::expect_true(
      any(startsWith(findings, paste0(expected_kind, ":"))),
      info = kind
    )
  }
  duplicate_findings <- check_fixture(c(
    base_stages,
    paste0(
      "ledgr_fold_envelope <- function(execution, output_handler) { ",
      "ledgr_fold_stage_observe_settle(); ",
      "ledgr_fold_stage_decide(); ledgr_fold_stage_decide(); ",
      "ledgr_fold_stage_plan(); ledgr_fold_stage_apply(); ",
      "ledgr_fold_stage_commit() }"
    )
  ))
  testthat::expect_true(any(startsWith(
    duplicate_findings,
    "stage_call_count:"
  )))

})
