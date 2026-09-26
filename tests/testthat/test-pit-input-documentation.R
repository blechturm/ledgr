# ledgr-test-file-profile: review

testthat::test_that("[LTB-0079] input map binds scopes to the runnable bundle", {
  qmd_path <- testthat::test_path(
    "..", "..", "vignettes", "data-input-and-snapshots.qmd"
  )
  md_path <- testthat::test_path(
    "..", "..", "vignettes", "data-input-and-snapshots.md"
  )
  testthat::expect_true(file.exists(qmd_path),
    info = "the canonical input article is required in the review lane"
  )
  testthat::expect_true(file.exists(md_path),
    info = "the rendered input article is required in the review lane"
  )
  if (!file.exists(qmd_path) || !file.exists(md_path)) return(invisible())
  qmd <- paste(readLines(qmd_path, warn = FALSE, encoding = "UTF-8"),
    collapse = "\n"
  )
  md <- paste(readLines(md_path, warn = FALSE, encoding = "UTF-8"),
    collapse = "\n"
  )
  qmd_flat <- gsub("[[:space:]]+", " ", qmd)

  expected_rows <- c(
    "| Bars |", "| Instruments |", "| Sessions |",
    "| Membership intervals |", "| Complete membership snapshots |",
    "| Trading status |", "| Lifetime |", "| Equity corporate actions |"
  )
  for (row in expected_rows) {
    testthat::expect_match(qmd, row, fixed = TRUE)
    testthat::expect_match(md, row, fixed = TRUE)
  }
  constructors <- c(
    "ledgr_snapshot_from_df", "ledgr_facts_sessions",
    "ledgr_facts_membership_intervals",
    "ledgr_facts_membership_snapshots", "ledgr_facts_trading_status",
    "ledgr_facts_lifetime", "ledgr_facts_equity_corporate_actions"
  )
  for (constructor in constructors) {
    testthat::expect_match(qmd, constructor, fixed = TRUE)
  }
  for (rule in c(
    "identifiers stay stable", "whole-second UTC",
    "knowledge is declared per family"
  )) {
    testthat::expect_match(qmd, rule, fixed = TRUE)
  }

  node_lines <- c(
    "I[Physical instrument master]", "B[Bars by instrument]",
    "V[Venue scope: sessions]", "U[Universe scope: membership]",
    "S[Instrument scope: status and lifetime]",
    "C[Equity scope: corporate actions]", "P[Sealed snapshot]",
    "R[Availability-aware run]"
  )
  for (node in node_lines) {
    testthat::expect_match(qmd, node, fixed = TRUE)
  }
  testthat::expect_match(
    qmd,
    "C -- parent and optional recipient --> I",
    fixed = TRUE
  )
  testthat::expect_match(qmd, "U -- member identifiers --> I", fixed = TRUE)
  testthat::expect_identical(
    length(regmatches(qmd, gregexpr("(?m)^[ ]{2}[A-Z]\\[", qmd,
      perl = TRUE
    ))[[1L]]),
    8L
  )

  for (call in c(
    "pit <- ledgr_demo_pit_inputs", "ledgr_snapshot_from_df(",
    "ledgr_snapshot_open(", "ledgr_experiment(", "ledgr_run("
  )) {
    testthat::expect_match(qmd, call, fixed = TRUE)
  }
  testthat::expect_match(md, '"DONE"               "TRUE"', fixed = TRUE)
  testthat::expect_match(
    qmd_flat,
    "they are not a fact overlay for an unrelated observation panel",
    fixed = TRUE
  )
})
