# ledgr-test-profile: review
testthat::test_that("[LTB-0258] current schema definition matches the pre-cut catalogue", {
  connect <- function(path = ":memory:") {
    DBI::dbConnect(duckdb::duckdb(shared_home = FALSE), dbdir = path)
  }
  render <- function(definition) {
    con <- connect()
    on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
    ledgr:::ledgr_schema_render_current(con, definition)
    ledgr:::ledgr_schema_normalized_catalogue(con)
  }

  legacy_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(paste0(legacy_path, c("", ".wal")), force = TRUE), add = TRUE)
  legacy <- connect(legacy_path)
  suppressMessages(ledgr:::ledgr_create_schema_legacy(
    legacy,
    ledgr:::ledgr_schema_catalogue(legacy)
  ))
  DBI::dbDisconnect(legacy, shutdown = TRUE)
  legacy <- connect(legacy_path)
  on.exit(DBI::dbDisconnect(legacy, shutdown = TRUE), add = TRUE)
  expected <- ledgr:::ledgr_schema_normalized_catalogue(legacy)

  definition <- ledgr:::ledgr_current_schema_definition()
  actual <- render(definition)
  testthat::expect_identical(
    ledgr:::ledgr_schema_catalogue_difference(expected, actual),
    list(
      missing = ledgr:::ledgr_schema_catalogue_rows(expected)[0L, ],
      extra = ledgr:::ledgr_schema_catalogue_rows(actual)[0L, ]
    )
  )

  root <- testthat::test_path("..", "..")
  golden <- utils::read.csv(
    file.path(root, "tests", "testthat", "fixtures", "schema-current-golden.csv"),
    stringsAsFactors = FALSE
  )
  testthat::expect_identical(unique(golden$pre_cut_commit), "24bcc161")
  testthat::expect_identical(
    unique(golden$duckdb_version),
    as.character(utils::packageVersion("duckdb"))
  )
  digest <- ledgr:::ledgr_schema_catalogue_digest(expected)
  rownames(digest) <- NULL
  testthat::expect_identical(
    digest,
    golden[c("dimension", "rows", "sha256")]
  )

  expect_named_difference <- function(mutant, dimension, object) {
    difference <- ledgr:::ledgr_schema_catalogue_difference(
      expected,
      render(mutant)
    )
    testthat::expect_true(any(
      difference$missing$dimension == dimension &
        grepl(object, difference$missing$object, fixed = TRUE)
    ))
  }

  mutant <- definition
  mutant$tables <- mutant$tables[names(mutant$tables) != "run_tags"]
  expect_named_difference(mutant, "table", "run_tags")

  mutant <- definition
  mutant$tables[["run_promotion_context"]] <- sub(
    "note VARCHAR",
    "note_changed VARCHAR",
    mutant$tables[["run_promotion_context"]],
    fixed = TRUE
  )
  expect_named_difference(mutant, "column", "run_promotion_context.note")

  mutant <- definition
  mutant$tables[["runs"]] <- sub(
    "DEFAULT(109)",
    "DEFAULT(110)",
    mutant$tables[["runs"]],
    fixed = TRUE
  )
  expect_named_difference(mutant, "column", "runs.schema_version")

  mutant <- definition
  mutant$tables[["snapshot_sessions"]] <- sub(
    "('open', 'closed')",
    "('open')",
    mutant$tables[["snapshot_sessions"]],
    fixed = TRUE
  )
  expect_named_difference(mutant, "constraint", "snapshot_sessions.CHECK")

  mutant <- definition
  mutant$indexes <- mutant$indexes[
    names(mutant$indexes) != "idx_snapshot_sessions_close"
  ]
  expect_named_difference(mutant, "index", "idx_snapshot_sessions_close")

  source_files <- list.files(
    file.path(root, "R"), pattern = "[.]R$", full.names = TRUE
  )
  source_files <- source_files[
    basename(source_files) != "db-schema-current.R"
  ]
  production_source <- paste(
    unlist(lapply(source_files, readLines, warn = FALSE)),
    collapse = "\n"
  )
  testthat::expect_false(grepl(
    "ledgr_schema_render_current\\s*\\(",
    production_source,
    perl = TRUE
  ))
  testthat::expect_true(all(grepl(
    "^CREATE (TABLE|INDEX)",
    ledgr:::ledgr_current_schema_statements()
  )))
})
