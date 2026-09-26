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

  testthat::expect_match(qmd, "Choose The Smallest Honest Input Set", fixed = TRUE)
  testthat::expect_match(qmd, "Rows, Keys And Required Columns", fixed = TRUE)
  testthat::expect_match(qmd, "What Sealing Establishes", fixed = TRUE)
  for (shape in c(
    "Dense static panel", "Session-aware data gaps",
    "Point-in-time universe", "Demonstrated full equity bundle"
  )) {
    testthat::expect_match(qmd, shape, fixed = TRUE)
    testthat::expect_match(md, shape, fixed = TRUE)
  }

  entities <- c(
    "SNAPSHOT", "INSTRUMENT", "BAR", "SESSION", "MEMBERSHIP",
    "TRADING_STATUS", "LIFETIME", "CORPORATE_ACTION"
  )
  testthat::expect_match(qmd, "erDiagram", fixed = TRUE)
  for (entity in entities) {
    testthat::expect_match(
      qmd,
      paste0("(?m)^  ", entity, " \\{$"),
      perl = TRUE
    )
  }
  testthat::expect_match(
    qmd,
    "INSTRUMENT ||--o{ CORPORATE_ACTION : parent_or_recipient",
    fixed = TRUE
  )
  testthat::expect_match(
    qmd,
    "INSTRUMENT ||--o{ MEMBERSHIP : referenced_by",
    fixed = TRUE
  )
  testthat::expect_match(
    qmd,
    "INSTRUMENT ||--o{ TRADING_STATUS : constrained_by",
    fixed = TRUE
  )
  testthat::expect_match(
    qmd,
    "INSTRUMENT ||--o{ LIFETIME : described_by",
    fixed = TRUE
  )
  testthat::expect_identical(
    length(regmatches(
      qmd,
      gregexpr(
        paste0("(?m)^  (", paste(entities, collapse = "|"), ") \\{$"),
        qmd,
        perl = TRUE
      )
    )[[1L]]),
    8L
  )

  for (call in c(
    "pit <- ledgr_demo_pit_inputs", "ledgr_snapshot_from_df(",
    "ledgr_snapshot_open(", "ledgr_experiment(", "ledgr_run("
  )) {
    testthat::expect_match(qmd, call, fixed = TRUE)
  }
  testthat::expect_match(
    md,
    "(?m)^\\s*1 halt knowledge arrives after effectiveness\\s+TRUE\\s*$",
    perl = TRUE
  )
  testthat::expect_match(md, "LEDGR_SUBSECOND_TIMESTAMP", fixed = TRUE)
  testthat::expect_match(
    md,
    "ledgr_availability_validation_failed",
    fixed = TRUE
  )
  testthat::expect_match(md, '"DONE"               "TRUE"', fixed = TRUE)
  testthat::expect_match(
    qmd_flat,
    "they are not a fact overlay for an unrelated observation panel",
    fixed = TRUE
  )
})

testthat::test_that("[LTB-0080] specialist articles join the input map", {
  article_names <- c(
    "missing-data-and-sessions",
    "survivorship-bias",
    "corporate-action-cash"
  )
  paths <- lapply(article_names, function(name) {
    c(
      qmd = testthat::test_path("..", "..", "vignettes", paste0(name, ".qmd")),
      md = testthat::test_path("..", "..", "vignettes", paste0(name, ".md"))
    )
  })
  all_paths <- unlist(paths, use.names = FALSE)
  testthat::expect_true(all(file.exists(all_paths)),
    info = "all three source and rendered specialist articles are required"
  )
  if (!all(file.exists(all_paths))) return(invisible())

  articles <- lapply(paths, function(article_paths) {
    lapply(article_paths, function(path) {
      paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    })
  })
  for (article in articles) {
    for (text in article) {
      testthat::expect_match(
        text,
        "Data Model And Point-In-Time Inputs",
        fixed = TRUE
      )
      testthat::expect_match(text, "ledgr_demo_pit_inputs", fixed = TRUE)
    }
    testthat::expect_match(
      article$qmd,
      "data(\"ledgr_demo_pit_inputs\", package = \"ledgr\")",
      fixed = TRUE
    )
    testthat::expect_match(article$qmd, "local to this article", fixed = TRUE)
  }

  testthat::expect_match(
    articles[[1L]]$md,
    paste0(
      "(?m)^#>\\s+[0-9]+\\s+missing_observation\\s+DEMO_04\\s+",
      "2020-01-09\\s+FALSE\\s*$"
    ),
    perl = TRUE
  )
  testthat::expect_match(
    articles[[1L]]$md,
    "stale_close          2 no_action",
    fixed = TRUE
  )
  testthat::expect_match(
    articles[[2L]]$md,
    "known_inactive       delisted",
    fixed = TRUE
  )
  testthat::expect_match(
    articles[[2L]]$md,
    "Point-in-time (AAA and BBB)               -0.19",
    fixed = TRUE
  )
  testthat::expect_match(
    articles[[3L]]$md,
    "Gross cash posted:           2.5",
    fixed = TRUE
  )
})
