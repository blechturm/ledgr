# ledgr-test-file-profile: review

testthat::test_that("[LTB-0406] results, plans and experiments name the stale-mark horizon and disclose the history policy", {
  default_line <- paste(
    "History policy: price carry 5 sessions (default); output carry off (default);",
    "segment limit 4 per fact, at least 16 (default)"
  )
  declared_line <- paste(
    "History policy: price carry off (declared); output carry 2 sessions (declared);",
    "segment limit 40 (declared)"
  )
  # The ws42 fixture declares ledgr_valuation_stale(3). Its declared history
  # policy below equals the default; a value-equal declaration is the same
  # policy and identity (contracts.md, Corporate-Action And Valuation
  # Policies), so it is marked default.
  defaulted <- ws42_history_fixture(policy = ledgr_history_policy(price_carry = 5L))
  on.exit(ledgr_snapshot_close(defaulted$snapshot), add = TRUE)
  declared <- ws42_history_fixture(
    policy = ledgr_history_policy(price_carry = NULL, output_carry = 2L, segment_limit = 40L),
    valuation_policy = ledgr_valuation_stale(5)
  )
  on.exit(ledgr_snapshot_close(declared$snapshot), add = TRUE)

  bt_default <- ledgr_run(defaulted$exp, run_id = "disclosure-default")
  on.exit(close(bt_default), add = TRUE)
  bt_declared <- ledgr_run(declared$exp, run_id = "disclosure-declared")
  on.exit(close(bt_declared), add = TRUE)

  # print(): the horizon is named as the valuation stale-mark horizon and the
  # history policy follows on its own line.
  printed <- utils::capture.output(print(bt_default))
  point_in_time <- grep("^Point in time: ", printed, value = TRUE)
  testthat::expect_length(point_in_time, 1L)
  testthat::expect_true(grepl(
    "^Point in time: membership rule 'u'; valuation stale-mark horizon 3 sessions \\(declared\\)(;|$)",
    point_in_time
  ))
  testthat::expect_true(default_line %in% printed)
  testthat::expect_false(any(grepl("max sessions", printed, fixed = TRUE)))
  printed_declared <- utils::capture.output(print(bt_declared))
  testthat::expect_true(any(grepl(
    "valuation stale-mark horizon 5 sessions (default)", printed_declared, fixed = TRUE
  )))
  testthat::expect_true(declared_line %in% printed_declared)
  # Every printed horizon carries its name.
  horizon_lines <- grep("horizon|sessions \\((default|declared)\\)", c(printed, printed_declared), value = TRUE)
  testthat::expect_true(all(grepl("stale-mark horizon|carry", horizon_lines)))

  # summary(): the valuation evidence names the horizon and a History Policy
  # section lists each field with its marker.
  summarized <- utils::capture.output(summary(bt_default))
  testthat::expect_true("  Stale-mark horizon:          3 sessions (declared)" %in% summarized)
  testthat::expect_false(any(grepl("Max sessions", summarized, fixed = TRUE)))
  policy_at <- match("History Policy:", summarized)
  testthat::expect_false(is.na(policy_at))
  testthat::expect_identical(
    summarized[policy_at + 1:3],
    c(
      "  Price carry:                 5 sessions (default)",
      "  Output carry:                off (default)",
      "  Segment limit:               4 per fact, at least 16 (default)"
    )
  )
  summarized_declared <- utils::capture.output(summary(bt_declared))
  declared_at <- match("History Policy:", summarized_declared)
  testthat::expect_identical(
    summarized_declared[declared_at + 1:3],
    c(
      "  Price carry:                 off (declared)",
      "  Output carry:                2 sessions (declared)",
      "  Segment limit:               40 (declared)"
    )
  )
  testthat::expect_true("  Stale-mark horizon:          5 sessions (default)" %in% summarized_declared)

  # ledgr_experiment_plan(): the printed plan names the horizon and shows the
  # policy; its assumptions table carries the history rows with markers.
  plan <- ledgr_experiment_plan(declared$exp)
  plan_printed <- utils::capture.output(print(plan))
  testthat::expect_true("Valuation:    stale-mark horizon 5 sessions (default)" %in% plan_printed)
  testthat::expect_true(
    paste("History:      ", sub("^History policy: ", "", declared_line), sep = "") %in% plan_printed
  )
  history_rows <- plan$assumptions[startsWith(plan$assumptions$setting, "history."), ]
  testthat::expect_identical(
    as.data.frame(history_rows),
    data.frame(
      setting = c("history.price_carry", "history.output_carry", "history.segment_limit"),
      value = c("off", "2 sessions", "40"),
      default = c(FALSE, FALSE, FALSE),
      stringsAsFactors = FALSE
    )
  )
  testthat::expect_true(any(grepl("^  history\\.output_carry +2 sessions$", plan_printed)))
  default_plan <- ledgr_experiment_plan(defaulted$exp)
  testthat::expect_true(all(
    default_plan$assumptions$default[startsWith(default_plan$assumptions$setting, "history.")]
  ))

  # print() of the experiment shows both beside the price basis.
  experiment_printed <- utils::capture.output(print(declared$exp))
  testthat::expect_identical(
    experiment_printed[match("Price basis: split_adjusted (declared)", experiment_printed) + 1:2],
    c(
      "Valuation:   stale-mark horizon 5 sessions (default)",
      paste0("History:     ", sub("^History policy: ", "", declared_line))
    )
  )

  # A dense run has no history policy to disclose.
  dense <- ws42_dense_snapshot()
  on.exit(ledgr_snapshot_close(dense), add = TRUE)
  dense_exp <- ledgr_experiment(dense, function(ctx, params) ctx$hold(), cost_model = ledgr_cost_zero())
  bt_dense <- ledgr_run(dense_exp, run_id = "disclosure-dense")
  on.exit(close(bt_dense), add = TRUE)
  testthat::expect_false(any(grepl("History", utils::capture.output(print(bt_dense)), fixed = TRUE)))
  testthat::expect_false(any(grepl("History", utils::capture.output(print(dense_exp)), fixed = TRUE)))
  testthat::expect_false(any(startsWith(ledgr_experiment_plan(dense_exp)$assumptions$setting, "history.")))
})
