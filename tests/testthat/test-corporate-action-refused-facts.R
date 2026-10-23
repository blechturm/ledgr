# Cut 17 LDG-3089: refused (complete = FALSE) corporate-action facts are
# counted, and a held one takes the unsupported-quantity route (LFB-014).

refused_fact_days <- function() as.Date("2021-01-04") + c(0:4, 7:11, 14:18)

refused_fact_at <- function(day) as.POSIXct(paste(day, "21:00:00"), tz = "UTC")

# Cash-dividend rows: `cash` NA makes the row refused with `reason`.
refused_fact_rows <- function(fact_id, parent, day, reason = NA_character_, cash = NA_real_) {
  at <- refused_fact_at(day)
  data.frame(
    fact_id = fact_id, subtype = "ordinary_cash_dividend", parent_instrument_id = parent,
    entitlement_time = at, effective_time = at, knowledge_time = at - 86400 * 3,
    complete = !is.na(cash), refusal_reason = reason, provenance_tier = "snapshot_bound",
    gross_cash_per_parent_unit = cash, gross_cash_validated = !is.na(cash),
    source = "refused_fact_test", stringsAsFactors = FALSE
  )
}

# Buys 10 AAA at the first decision and holds; BBB is never held.
refused_fact_strategy <- function(ctx, params) {
  target <- ctx$hold()
  if (identical(substr(ctx$ts_utc, 1, 10), "2021-01-04")) target[["AAA"]] <- 10
  target
}

refused_fact_dense_snapshot <- function(rows) {
  days <- refused_fact_days()[1:10]
  bars <- data.frame(
    instrument_id = rep(c("AAA", "BBB"), each = length(days)),
    ts_utc = rep(refused_fact_at(days), 2),
    open = 10, high = 10, low = 10, close = 10, volume = 100
  )
  ledgr_snapshot_from_df(
    bars,
    db_path = tempfile(fileext = ".duckdb"), price_basis = "split_adjusted",
    facts = ledgr_facts(ledgr_facts_equity_corporate_actions(rows))
  )
}

refused_fact_experiment <- function(snapshot, policy, availability) {
  args <- list(
    snapshot, refused_fact_strategy,
    cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1000),
    corporate_action_policy = policy
  )
  args <- c(args, if (availability) {
    list(universe = ledgr_universe_members("u"), valuation_policy = ledgr_valuation_stale(2))
  } else {
    list(universe = c("AAA", "BBB"))
  })
  do.call(ledgr_experiment, args)
}

testthat::test_that("[LTB-0451] a held refused dividend is counted and reads unsupported (LFB-014)", {
  days <- refused_fact_days()
  rows <- rbind(
    refused_fact_rows("div_paid", "AAA", days[[5]], cash = 0.5),
    refused_fact_rows("div_refused", "AAA", days[[7]], reason = "basis_unverified"),
    refused_fact_rows("div_unheld", "BBB", days[[7]], reason = "basis_unverified"),
    refused_fact_rows("div_other", "BBB", days[[8]], reason = "same_date_unresolved")
  )
  availability <- scale_test_events_snapshot(
    corporate_actions = ledgr_facts_equity_corporate_actions(rows)
  )
  on.exit(ledgr_snapshot_close(availability), add = TRUE)
  dense <- refused_fact_dense_snapshot(rows)
  on.exit(ledgr_snapshot_close(dense), add = TRUE)

  for (mode in c("availability", "dense")) {
    snapshot <- if (mode == "availability") availability else dense
    bt <- ledgr_run(
      refused_fact_experiment(snapshot, ledgr_corporate_actions_research(), mode == "availability"),
      run_id = paste0("refused_research_", mode)
    )
    summary <- ledgr_corporate_action_summary(bt)
    printed <- capture.output(summary(bt))
    status <- ledgr_run_info(snapshot, bt$run_id)$status
    close(bt)
    info <- paste("mode:", mode)
    # The research run completes, posts the complete dividend only and
    # reports the held refused one.
    testthat::expect_identical(status, "DONE", info = info)
    testthat::expect_identical(summary$corporate_action_fidelity, "unsupported", info = info)
    testthat::expect_identical(summary$unsupported_facts, 1L, info = info)
    testthat::expect_identical(summary$gross_cash_posted, 5, info = info)
    testthat::expect_identical(
      summary$refusal_counts,
      c(basis_unverified = 1L, same_date_unresolved = 0L),
      info = info
    )
    testthat::expect_identical(
      summary$refusal_entitled_quantity,
      c(basis_unverified = 10, same_date_unresolved = 0),
      info = info
    )
    testthat::expect_identical(
      summary$sealed_refusal_counts,
      c(basis_unverified = 2L, same_date_unresolved = 1L),
      info = info
    )
    expected_lines <- c(
      "Corporate actions: UNSUPPORTED - supplied effects were not represented",
      "  Refusal reasons:",
      "    basis_unverified: 1 (entitled quantity 10)",
      "    same_date_unresolved: 0",
      "  Sealed refusal reasons:",
      "    basis_unverified: 2",
      "    same_date_unresolved: 1"
    )
    testthat::expect_true(
      all(expected_lines %in% printed),
      info = paste(info, "missing:", paste(setdiff(expected_lines, printed), collapse = " | "))
    )
  }
})

testthat::test_that("[LTB-0452] the strict preset refuses a held refused fact in each mode's existing form", {
  days <- refused_fact_days()
  # The refused AAA dividend is the only held corporate-action fact; the BBB
  # one is refused but never held.
  rows <- rbind(
    refused_fact_rows("div_refused", "AAA", days[[7]], reason = "basis_unverified"),
    refused_fact_rows("div_unheld", "BBB", days[[7]], reason = "basis_unverified")
  )
  testthat::expect_identical(
    ledgr_corporate_actions_research()$identity$unsupported_quantity,
    "ledgr.corporate_action.unsupported_quantity.report_only.v002"
  )
  testthat::expect_identical(
    ledgr_corporate_actions_strict()$identity$unsupported_quantity,
    "ledgr.corporate_action.unsupported_quantity.refuse.v002"
  )

  # Availability: a typed stop at the fact's effective pulse, INCOMPLETE.
  availability <- scale_test_events_snapshot(
    corporate_actions = ledgr_facts_equity_corporate_actions(rows)
  )
  on.exit(ledgr_snapshot_close(availability), add = TRUE)
  bt <- ledgr_run(
    refused_fact_experiment(availability, ledgr_corporate_actions_strict(), TRUE),
    run_id = "refused_strict_availability"
  )
  completion <- ledgr_run_completion(bt)
  summary <- ledgr_corporate_action_summary(bt)
  close(bt)
  testthat::expect_identical(ledgr_run_info(availability, "refused_strict_availability")$status, "INCOMPLETE")
  testthat::expect_identical(completion$stop_reason, "corporate_action_quantity_refused")
  stopped <- DBI::dbGetQuery(
    ledgr:::get_connection(availability),
    "SELECT ts_utc, instrument_id, reason_code FROM run_diagnostics WHERE run_id = ? AND outcome = 'stopped'",
    params = list("refused_strict_availability")
  )
  testthat::expect_identical(stopped$instrument_id, "AAA")
  testthat::expect_identical(stopped$reason_code, "corporate_action_quantity_refused")
  testthat::expect_equal(as.POSIXct(stopped$ts_utc, tz = "UTC"), refused_fact_at(days[[7]]), ignore_attr = TRUE)
  testthat::expect_identical(summary$corporate_action_fidelity, "unsupported")
  testthat::expect_identical(summary$refusal_counts, c(basis_unverified = 1L))
  testthat::expect_identical(summary$sealed_refusal_counts, c(basis_unverified = 2L))

  # Dense: no typed stop exists, so the existing refusal class is raised.
  dense <- refused_fact_dense_snapshot(rows)
  on.exit(ledgr_snapshot_close(dense), add = TRUE)
  error <- testthat::expect_error(
    ledgr_run(
      refused_fact_experiment(dense, ledgr_corporate_actions_strict(), FALSE),
      run_id = "refused_strict_dense"
    ),
    class = "ledgr_corporate_action_quantity_unsupported"
  )
  refused_id <- DBI::dbGetQuery(
    ledgr:::get_connection(dense),
    "SELECT fact_id FROM snapshot_equity_corporate_actions WHERE parent_instrument_id = 'AAA'"
  )$fact_id
  testthat::expect_identical(error$source_fact_ids, refused_id)
})
