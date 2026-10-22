# Cut 17 LDG-3085 (register D1-F7): corporate-action knowledge filled by the
# known-when-effective rule is labelled assumed and disclosed in results.

assumed_knowledge_rows <- function(knowledge_time) {
  at <- as.POSIXct(c("2021-01-08 21:00:00", "2021-01-12 21:00:00"), tz = "UTC")
  data.frame(
    fact_id = c("div_filled", "div_supplied"),
    subtype = "ordinary_cash_dividend", parent_instrument_id = c("AAA", "BBB"),
    entitlement_time = at, effective_time = at, knowledge_time = knowledge_time,
    complete = TRUE, provenance_tier = "snapshot_bound",
    gross_cash_per_parent_unit = 0.5, gross_cash_validated = TRUE,
    source = "assumed_knowledge_test", stringsAsFactors = FALSE
  )
}

testthat::test_that("[LTB-0454] assumed corporate-action knowledge reads assumed and is disclosed", {
  # The first row has no knowledge time (filled known-when-effective); the
  # second supplies one.
  supplied_at <- as.POSIXct("2021-01-11 21:00:00", tz = "UTC")
  mixed <- ledgr_facts_equity_corporate_actions(
    assumed_knowledge_rows(as.POSIXct(c(NA, supplied_at), origin = "1970-01-01", tz = "UTC"))
  )
  provenance <- lapply(mixed$rows$provenance_json, ledgr:::ledgr_json_read_nested)
  filled <- provenance[[match("AAA", mixed$rows$parent_instrument_id)]]
  supplied <- provenance[[match("BBB", mixed$rows$parent_instrument_id)]]
  testthat::expect_identical(filled$knowledge, "assumed")
  testthat::expect_identical(filled$knowledge_reason, "knowledge_assume_effective")
  testthat::expect_identical(supplied$knowledge, "evidenced")
  testthat::expect_null(supplied$knowledge_reason)
  testthat::expect_identical(mixed$metadata$knowledge, "assume_effective")
  # The filled clock is the event instant, as before (Cut 16 decision 11).
  testthat::expect_equal(
    mixed$rows$knowledge_time[mixed$rows$parent_instrument_id == "AAA"],
    as.POSIXct("2021-01-08 21:00:00", tz = "UTC"),
    ignore_attr = TRUE
  )

  # Every knowledge time supplied: no assumption, no metadata label.
  evidenced <- ledgr_facts_equity_corporate_actions(
    assumed_knowledge_rows(rep(supplied_at - 86400 * 7, 2))
  )
  testthat::expect_true(all(vapply(evidenced$rows$provenance_json, function(json) {
    identical(ledgr:::ledgr_json_read_nested(json)$knowledge, "evidenced")
  }, logical(1))))
  testthat::expect_null(evidenced$metadata$knowledge)

  # Sealed and run: the assumed family is disclosed in the result; the
  # all-evidenced one is not. Sessions and membership are evidenced so the
  # corporate-action family is the only possible assumption.
  disclosed <- function(family, run_id) {
    snapshot <- scale_test_events_snapshot(corporate_actions = family, knowledge = "evidenced")
    on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
    sealed <- DBI::dbGetQuery(
      ledgr:::get_connection(snapshot),
      "SELECT parent_instrument_id, provenance_json FROM snapshot_equity_corporate_actions ORDER BY parent_instrument_id"
    )
    bt <- ledgr_run(
      ledgr_experiment(
        snapshot, function(ctx, params) ctx$hold(),
        universe = ledgr_universe_members("u"), valuation_policy = ledgr_valuation_stale(2),
        cost_model = ledgr_cost_zero(), opening = ledgr_opening(cash = 1000)
      ),
      run_id = run_id
    )
    on.exit(close(bt), add = TRUE, after = FALSE)
    list(
      sealed = vapply(sealed$provenance_json, function(json) {
        ledgr:::ledgr_json_read_nested(json)$knowledge
      }, character(1), USE.NAMES = FALSE),
      summary = ledgr_valuation_summary(bt),
      printed = capture.output(print(bt))
    )
  }
  assumed_run <- disclosed(mixed, "assumed_knowledge")
  testthat::expect_identical(assumed_run$sealed, c("assumed", "evidenced"))
  testthat::expect_identical(assumed_run$summary$assumption_backed_families, "equity_corporate_actions")
  testthat::expect_identical(assumed_run$summary$assumption_reasons, "knowledge_assume_effective")
  testthat::expect_true(any(grepl(
    "assumption-backed facts: equity_corporate_actions (knowledge assumed effective)",
    assumed_run$printed,
    fixed = TRUE
  )))

  evidenced_run <- disclosed(evidenced, "evidenced_knowledge")
  testthat::expect_identical(evidenced_run$sealed, c("evidenced", "evidenced"))
  testthat::expect_length(evidenced_run$summary$assumption_backed_families, 0L)
  testthat::expect_false(any(grepl("assumption-backed facts", evidenced_run$printed, fixed = TRUE)))
})
