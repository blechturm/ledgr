# ledgr-test-file-profile: review

read_pit_article <- function(name, extension) {
  path <- testthat::test_path(
    "..", "..", "vignettes", paste0(name, ".", extension)
  )
  testthat::expect_true(
    file.exists(path),
    info = paste(name, extension, "is required in the review lane")
  )
  if (!file.exists(path)) return("")
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

pit_erd_lines <- function(text, pattern) {
  lines <- strsplit(text, "\n", fixed = TRUE)[[1L]]
  trimws(lines[grepl(pattern, lines, perl = TRUE)])
}

pit_erd_relationships <- function(text) {
  pit_erd_lines(
    text,
    "^[[:space:]]*[A-Z_]+[[:space:]]+[|}{o]+--[|}{o]+[[:space:]]+[A-Z_]+[[:space:]]+:"
  )
}

pit_erd_entity_attributes <- function(text, entity) {
  lines <- strsplit(text, "\n", fixed = TRUE)[[1L]]
  start <- which(trimws(lines) == paste0(entity, " {"))
  testthat::expect_length(start, 1L)
  if (length(start) != 1L) return(character())
  after <- seq.int(start + 1L, length(lines))
  close_offset <- which(trimws(lines[after]) == "}")[[1L]]
  trimws(lines[seq.int(start + 1L, start + close_offset - 1L)])
}

pit_flatten <- function(text) {
  gsub("[[:space:]]+", " ", text)
}

testthat::test_that("[LTB-0079] the input documentation spine is progressive", {
  import_qmd <- read_pit_article("data-input-and-snapshots", "qmd")
  import_md <- read_pit_article("data-input-and-snapshots", "md")
  point_qmd <- read_pit_article("point-in-time-inputs", "qmd")
  point_md <- read_pit_article("point-in-time-inputs", "md")
  store_qmd <- read_pit_article("experiment-store", "qmd")
  store_md <- read_pit_article("experiment-store", "md")
  if (any(!nzchar(c(
    import_qmd, import_md, point_qmd, point_md, store_qmd, store_md
  )))) {
    return(invisible())
  }

  testthat::expect_match(
    import_qmd, 'title: "Importing And Sealing Market Data"', fixed = TRUE
  )
  testthat::expect_lt(
    regexpr("## Seal A Snapshot", import_qmd, fixed = TRUE)[[1L]],
    regexpr("## Choose The Smallest Honest Input Set", import_qmd,
      fixed = TRUE
    )[[1L]]
  )
  for (shape in c(
    "Dense static panel", "Session-aware gaps", "Point-in-time universe",
    "Equity economic events"
  )) {
    testthat::expect_match(import_qmd, shape, fixed = TRUE)
    testthat::expect_match(import_md, shape, fixed = TRUE)
  }
  for (surface in c(
    "ledgr_snapshot_from_df(", "ledgr_snapshot_from_csv(",
    "ledgr_snapshot_from_yahoo(", "invalid_observations = \"quarantine\"",
    "ledgr_snapshot_open("
  )) {
    testthat::expect_match(import_qmd, surface, fixed = TRUE)
  }
  testthat::expect_match(
    import_qmd,
    'vignette("point-in-time-inputs", package = "ledgr")',
    fixed = TRUE
  )
  testthat::expect_no_match(import_qmd, "erDiagram", fixed = TRUE)
  testthat::expect_no_match(
    import_qmd, "ledgr_facts_membership_snapshots(", fixed = TRUE
  )
  testthat::expect_no_match(import_qmd, "capture_condition_class", fixed = TRUE)
  for (text in list(import_qmd, import_md)) {
    testthat::expect_no_match(text, "## Back Up A Closed Store", fixed = TRUE)
    testthat::expect_no_match(text, "file.copy(", fixed = TRUE)
  }

  testthat::expect_match(
    point_qmd, 'title: "Preparing Point-In-Time Inputs"', fixed = TRUE
  )
  sequence <- vapply(c(
    "## Start With The Missing Observation",
    "## Add A Point-In-Time Universe",
    "## Effective Time Is Not Knowledge Time",
    "## Add Lifetime And Economic Events When Needed",
    "## Seal And Run The Combined Evidence",
    "## Data Dictionary"
  ), function(heading) {
    regexpr(heading, point_qmd, fixed = TRUE)[[1L]]
  }, integer(1))
  testthat::expect_true(all(sequence > 0L))
  testthat::expect_true(all(diff(sequence) > 0L))

  expected_rows <- c(
    "| Bars |", "| Instruments |", "| Sessions |",
    "| Membership intervals |", "| Complete membership snapshots |",
    "| Trading status |", "| Lifetime |", "| Equity corporate actions |"
  )
  for (row in expected_rows) {
    testthat::expect_match(point_qmd, row, fixed = TRUE)
    testthat::expect_match(point_md, row, fixed = TRUE)
  }
  constructors <- c(
    "ledgr_snapshot_from_df", "ledgr_facts_sessions",
    "ledgr_facts_membership_intervals",
    "ledgr_facts_membership_snapshots", "ledgr_facts_trading_status",
    "ledgr_facts_lifetime", "ledgr_facts_equity_corporate_actions"
  )
  for (constructor in constructors) {
    testthat::expect_match(point_qmd, constructor, fixed = TRUE)
  }
  testthat::expect_no_match(point_qmd, "constructor_args", fixed = TRUE)
  testthat::expect_no_match(point_qmd, "do.call(", fixed = TRUE)
  testthat::expect_no_match(point_qmd, "capture_condition_class", fixed = TRUE)

  for (rule in c(
    "identifiers stay stable", "whole-second UTC",
    "knowledge is declared per family",
    "for membership, status and lifetime, missing evidenced knowledge remains audit-only",
    "Sessions instead require a valid knowledge time",
    "complete session calendar", "Corporate-action facts alone do not activate",
    "Status evidence may arrive late",
    "Lifetime follows the same late-knowledge rule"
  )) {
    testthat::expect_match(pit_flatten(point_qmd), rule, fixed = TRUE)
  }

  entities <- c(
    "SNAPSHOT", "INSTRUMENT", "BAR", "SESSION", "MEMBERSHIP",
    "TRADING_STATUS", "LIFETIME", "CORPORATE_ACTION"
  )
  expected_entities <- paste0(entities, " {")
  expected_edges <- c(
    "SNAPSHOT ||--o{ INSTRUMENT : contains",
    "INSTRUMENT ||--o{ BAR : observed_as",
    "SNAPSHOT ||--o{ SESSION : seals",
    "SNAPSHOT ||--o{ MEMBERSHIP : seals",
    "INSTRUMENT ||--o{ CORPORATE_ACTION : parent_or_recipient",
    "INSTRUMENT ||--o{ MEMBERSHIP : referenced_by",
    "INSTRUMENT ||--o{ TRADING_STATUS : constrained_by",
    "INSTRUMENT ||--o{ LIFETIME : described_by"
  )
  expected_attributes <- list(
    SNAPSHOT = c("string snapshot_id PK", "string snapshot_hash"),
    INSTRUMENT = "string instrument_id PK",
    BAR = c("string instrument_id PK,FK", "datetime ts_utc PK"),
    SESSION = c("string venue_id PK", "date session_date PK"),
    MEMBERSHIP = c(
      "string universe_id", "string instrument_id FK",
      "datetime effective_from", "datetime knowledge_time"
    ),
    TRADING_STATUS = c(
      "string instrument_id FK", "datetime effective_from",
      "datetime knowledge_time"
    ),
    LIFETIME = c(
      "string instrument_id FK", "datetime effective_from",
      "datetime knowledge_time"
    ),
    CORPORATE_ACTION = c(
      "string fact_id PK", "string parent_instrument_id FK",
      "string recipient_instrument_id FK"
    )
  )
  for (text in list(point_qmd, point_md)) {
    testthat::expect_match(text, "erDiagram", fixed = TRUE)
    testthat::expect_identical(
      sort(pit_erd_lines(text, "^  [A-Z_]+ \\{$")),
      sort(expected_entities)
    )
    testthat::expect_identical(
      sort(pit_erd_relationships(text)),
      sort(expected_edges)
    )
    for (entity in names(expected_attributes)) {
      testthat::expect_identical(
        pit_erd_entity_attributes(text, entity),
        expected_attributes[[entity]],
        info = paste(entity, "ERD attributes must remain exact")
      )
    }
  }

  for (call in c(
    "pit <- ledgr_demo_pit_inputs", "ledgr_snapshot_from_df(",
    "ledgr_snapshot_open(", "ledgr_experiment(", "ledgr_run("
  )) {
    testthat::expect_match(point_qmd, call, fixed = TRUE)
  }
  testthat::expect_match(
    point_md,
    '(?m)^\\s*1\\s+effective, not yet known\\s+FALSE\\s+""\\s*$',
    perl = TRUE
  )
  testthat::expect_match(
    point_md,
    '(?m)^\\s*2\\s+known\\s+TRUE\\s+"trading_halted"\\s*$',
    perl = TRUE
  )
  testthat::expect_match(
    point_md,
    '(?m)^\\s*"DONE"\\s+"TRUE"\\s*$',
    perl = TRUE
  )
  testthat::expect_match(
    point_qmd,
    "Do not attach its facts to an unrelated observation panel",
    fixed = TRUE
  )

  for (text in list(store_qmd, store_md)) {
    testthat::expect_match(text, "Back Up A Closed Store", fixed = TRUE)
    testthat::expect_match(text, "Back up closed stores", fixed = TRUE)
    testthat::expect_match(text, "file.copy(", fixed = TRUE)
  }
  for (text in list(point_qmd, point_md)) {
    testthat::expect_no_match(text, "## Back Up A Closed Store", fixed = TRUE)
    testthat::expect_no_match(text, "file.copy(", fixed = TRUE)
  }
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
        'vignette("point-in-time-inputs", package = "ledgr")',
        fixed = TRUE
      )
      testthat::expect_no_match(text, "point-in-time-inputs.qmd", fixed = TRUE)
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
  testthat::expect_match(
    articles[[3L]]$md,
    paste0(
      "(?m)^\\s*#>\\s+1\\s+ordinary_cash_dividend\\s+DEMO_03\\s+",
      "0[.]75\\s*$"
    ),
    perl = TRUE
  )
})
