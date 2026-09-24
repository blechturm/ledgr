corporate_action_result_fixture <- function(with_facts) {
  dates <- as.Date("2020-01-01") + 0:2
  bars <- ledgr_test_make_bars("AAA", dates)
  facts <- NULL
  if (isTRUE(with_facts)) {
    rows <- data.frame(
      fact_id = c("cash_fact", "incomplete_fact"),
      subtype = c("ordinary_cash_dividend", "spin_off"),
      parent_instrument_id = c("AAA", "AAA"),
      entitlement_time = as.POSIXct(
        c("2020-01-02 00:00:00", "2020-01-03 00:00:00"),
        tz = "UTC"
      ),
      effective_time = as.POSIXct(
        c("2020-01-02 00:00:00", "2020-01-03 00:00:00"),
        tz = "UTC"
      ),
      knowledge_time = as.POSIXct(
        c("2020-01-01 00:00:00", "2020-01-02 00:00:00"),
        tz = "UTC"
      ),
      complete = c(TRUE, FALSE),
      refusal_reason = c(NA, "missing_terms"),
      provenance_tier = "snapshot_bound",
      gross_cash_per_parent_unit = c(1.25, NA),
      gross_cash_validated = c(TRUE, FALSE),
      recipient_identity_validated = FALSE,
      recipient_quantity_validated = FALSE,
      source = "result_fixture",
      stringsAsFactors = FALSE
    )
    facts <- ledgr_facts(ledgr_facts_equity_corporate_actions(rows))
  }
  snapshot <- ledgr_snapshot_from_df(bars, facts = facts)
  exp <- ledgr_experiment(
    snapshot,
    function(ctx, params) ctx$flat(),
    cost_model = ledgr_cost_zero()
  )
  list(
    snapshot = snapshot,
    bt = ledgr_run(exp, run_id = if (with_facts) "facts-none" else "bars-only")
  )
}

# ledgr-test-profile: review
testthat::test_that("[LTB-0034] ordinary results distinguish absent from unused facts", {
  bars_only <- corporate_action_result_fixture(FALSE)
  withr::defer({
    close(bars_only$bt)
    ledgr_snapshot_close(bars_only$snapshot)
  })
  supplied <- corporate_action_result_fixture(TRUE)
  withr::defer({
    close(supplied$bt)
    ledgr_snapshot_close(supplied$snapshot)
  })

  absent <- ledgr:::ledgr_corporate_action_summary(bars_only$bt)
  none <- ledgr:::ledgr_corporate_action_summary(supplied$bt)
  testthat::expect_identical(absent$corporate_action_fidelity, "not_supplied")
  testthat::expect_identical(none$corporate_action_fidelity, "none")
  testthat::expect_identical(absent$price_basis, "undeclared")
  testthat::expect_identical(
    none$selected_settings,
    c(
      cash_amount = "gross",
      cash_posting = "effective_close",
      held_terminal_position = "last_permissible",
      unsupported_quantity = "report_only"
    )
  )
  testthat::expect_identical(
    none$selected_identities,
    c(
      cash_amount = "ledgr.corporate_action.cash_amount.gross.v001",
      cash_posting = "ledgr.corporate_action.cash_posting.effective_close.v001",
      held_terminal_position = "ledgr.corporate_action.held_terminal_position.last_permissible.v001",
      unsupported_quantity = "ledgr.corporate_action.unsupported_quantity.report_only.v001"
    )
  )
  testthat::expect_true(all(none$choice_counts == 0L))
  testthat::expect_identical(none$refusal_counts, c(missing_terms = 0L))
  testthat::expect_identical(none$late_arrival_count, 0L)
  testthat::expect_identical(none$affected_marked_exposure, 0)
  testthat::expect_identical(none$gross_cash_posted, 0)
  testthat::expect_identical(none$modeled_terminal_proceeds, 0)
  testthat::expect_identical(none$positions_disposed, 0L)
  testthat::expect_identical(none$realized_model_pnl, 0)
  testthat::expect_identical(none$unsupported_facts, 0L)

  ordinary <- capture.output(print(bars_only$bt))
  testthat::expect_true(any(
    ordinary == "Corporate actions: NOT SUPPLIED - returns may omit distributions"
  ))
  testthat::expect_true(any(
    ordinary == "Price basis: UNDECLARED - distribution double counting cannot be ruled out"
  ))
  detailed <- capture.output(summary(supplied$bt))
  expected_lines <- c(
    "Corporate actions: NONE - supplied facts did not affect held instruments",
    "  Setting cash_amount:              gross",
    "  Identity cash_amount:             ledgr.corporate_action.cash_amount.gross.v001",
    "    cash_amount.gross: 0",
    "    missing_terms: 0",
    "  Late arrivals:               0",
    "  Affected marked exposure:    0"
  )
  zero_fields <- c(
    "Gross cash posted", "Modeled terminal proceeds", "Positions disposed",
    "Realized model P&L", "Unsupported facts"
  )
  testthat::expect_true(all(vapply(zero_fields, function(label) {
    any(grepl(paste0("^  ", label, ":[ ]+0$"), detailed))
  }, logical(1))))
  testthat::expect_true(
    all(expected_lines %in% detailed),
    info = paste("missing:", paste(setdiff(expected_lines, detailed), collapse = " | "))
  )
  testthat::expect_error(
    ledgr:::ledgr_corporate_action_fidelity("evidenced"),
    class = "ledgr_invalid_corporate_action_fidelity"
  )
})
