testthat::test_that("[LTB-0026] accounting refuses every unhandled pulse event kind", {
  # LDG-3166 (design note Section 5, categories 3 and 5; the pulse-plan
  # object is retired): the typed plan builder is mocked and kinds are codes
  # (1 FILL, 2 CASHFLOW, 3 DISPOSITION); SYNTHETIC_UNKNOWN is a code outside
  # the dictionary.
  event_kinds <- c(CASHFLOW = 2L, DISPOSITION = 3L, SYNTHETIC_UNKNOWN = 99L)
  original_builder <- ledgr:::ledgr_fold_build_availability_pulse_plan

  run_with_kind <- function(event_kind, compiled_accounting_model) {
    testthat::local_mocked_bindings(
      ledgr_fold_build_availability_pulse_plan = function(...) {
        plan <- original_builder(...)
        plan$fill <- lapply(plan$fill, function(x) x[0L])
        plan$economic_event_kinds <- event_kind
        plan
      },
      .package = "ledgr"
    )
    ledgr_compiled_spot_fifo_test_run(compiled_accounting_model)
  }

  for (name in names(event_kinds)) {
    event_kind <- event_kinds[[name]]
    if (identical(name, "CASHFLOW")) {
      testthat::expect_no_error(suppressWarnings(run_with_kind(event_kind, NULL)))
    } else {
      testthat::expect_error(
        run_with_kind(event_kind, NULL),
        class = "ledgr_invalid_pulse_plan",
        info = paste("canonical R envelope must reject", name)
      )
    }
    testthat::expect_error(
      run_with_kind(event_kind, "spot_fifo"),
      class = "ledgr_compiled_spot_fifo_unavailable",
      info = paste("compiled envelope must reject", name)
    )
  }

  # covr rewrites function bodies, so the source text holds only in ordinary runs.
  # Both P4 paths consume the kind-checked plan's fill columns.
  if (!(requireNamespace("covr", quietly = TRUE) && covr::in_covr())) {
    fold_source <- paste(
      deparse(body(ledgr:::ledgr_fold_stage_apply)),
      collapse = "\n"
    )
    testthat::expect_match(fold_source, "fill <- plan$batch$fill", fixed = TRUE)
    testthat::expect_match(fold_source, "fills = fill", fixed = TRUE)
    # LDG-3167 (category 3): the canonical path consumes the fill columns as
    # one batch, not one row at a time.
    testthat::expect_match(fold_source, "candidate <- ledgr_fold_fill_candidate(fold_state$lot_state", fixed = TRUE)
    testthat::expect_false(grepl("for (i in seq_along(fill$k))", fold_source, fixed = TRUE))
  }
})
