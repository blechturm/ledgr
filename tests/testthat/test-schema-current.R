# ledgr-test-profile: review
testthat::test_that("[LTB-0258] current schema definition matches the schema-121 catalogue", {
  connect <- function(path = ":memory:") {
    DBI::dbConnect(duckdb::duckdb(shared_home = FALSE), dbdir = path)
  }
  render <- function(definition) {
    con <- connect()
    on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
    ledgr:::ledgr_schema_render_current(con, definition)
    ledgr:::ledgr_schema_normalized_catalogue(con)
  }

  definition <- ledgr:::ledgr_current_schema_definition()
  expected <- render(definition)

  root <- testthat::test_path("..", "..")
  golden <- utils::read.csv(
    file.path(root, "tests", "testthat", "fixtures", "schema-current-golden.csv"),
    stringsAsFactors = FALSE
  )
  testthat::expect_identical(unique(golden$schema_version), 121L)
  testthat::expect_identical(
    unique(golden$duckdb_version),
    as.character(utils::packageVersion("duckdb"))
  )
  golden_rows <- utils::read.csv(
    file.path(
      root, "tests", "testthat", "fixtures",
      "schema-current-golden-rows.csv"
    ),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  testthat::expect_identical(unique(golden_rows$schema_version), 121L)
  testthat::expect_identical(
    unique(golden_rows$duckdb_version),
    as.character(utils::packageVersion("duckdb"))
  )
  golden_rows$schema_version <- NULL
  golden_rows$duckdb_version <- NULL
  expected_rows <- ledgr:::ledgr_schema_catalogue_rows(expected)
  row_key <- function(x) {
    do.call(paste, c(x, sep = "\r"))
  }
  missing <- golden_rows[
    is.na(match(row_key(golden_rows), row_key(expected_rows))),
    ,
    drop = FALSE
  ]
  extra <- expected_rows[
    is.na(match(row_key(expected_rows), row_key(golden_rows))),
    ,
    drop = FALSE
  ]
  testthat::expect_identical(
    nrow(missing),
    0L,
    info = paste(
      "missing schema-121 catalogue rows:",
      paste(paste(missing$dimension, missing$object), collapse = ", ")
    )
  )
  testthat::expect_identical(
    nrow(extra),
    0L,
    info = paste(
      "extra current-definition rows:",
      paste(paste(extra$dimension, extra$object), collapse = ", ")
    )
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
  source_files <- source_files[basename(source_files) != "db-schema-current.R"]
  render_callers <- basename(source_files[vapply(
    source_files,
    function(path) {
      grepl(
        "ledgr_schema_render_current\\s*\\(",
        paste(readLines(path, warn = FALSE), collapse = "\n"),
        perl = TRUE
      )
    },
    logical(1)
  )])
  testthat::expect_identical(render_callers, "db-schema-validate.R")
  testthat::expect_true(all(grepl(
    "^CREATE (TABLE|INDEX)",
    ledgr:::ledgr_current_schema_statements()
  )))
})

# ledgr-test-profile: review
testthat::test_that("[LTB-0263] strict validation uses the complete current catalogue", {
  connect_current <- function(path = ":memory:") {
    ledgr:::ledgr_store_open(path, mode = "create")
  }
  expect_mutation <- function(sql, message) {
    opened <- connect_current()
    on.exit(DBI::dbDisconnect(opened$con, shutdown = TRUE))
    DBI::dbExecute(opened$con, sql)
    error <- testthat::expect_error(ledgr_validate_schema(opened$con))
    testthat::expect_s3_class(error, "simpleError")
    testthat::expect_identical(conditionMessage(error), message)
  }

  expect_mutation(
    "ALTER TABLE runs DROP COLUMN label",
    "Missing columns in runs: label"
  )
  expect_mutation(
    "ALTER TABLE runs ALTER COLUMN schema_version SET DEFAULT 120",
    paste0(
      "Schema catalogue mismatch: column runs.schema_version differs in ",
      "column_default (expected 109, got 120)."
    )
  )
  expect_mutation(
    "ALTER TABLE runs ADD COLUMN surprise INTEGER",
    "Schema catalogue mismatch: extra column runs.surprise."
  )
  expect_mutation(
    "DROP TABLE bars",
    "Missing table: bars"
  )
  expect_mutation(
    "DROP INDEX idx_snapshot_sessions_close",
    paste0(
      "Schema catalogue mismatch: missing index ",
      "snapshot_sessions.idx_snapshot_sessions_close."
    )
  )

  expect_mutation(
    "ALTER TABLE runs ALTER COLUMN schema_version SET DATA TYPE BIGINT",
    paste0(
      "Schema catalogue mismatch: column runs.schema_version differs in ",
      "data_type (expected INTEGER, got BIGINT)."
    )
  )

  temporary <- connect_current()
  on.exit(DBI::dbDisconnect(temporary$con, shutdown = TRUE), add = TRUE)
  DBI::dbExecute(temporary$con, "CREATE TEMP TABLE transient(value INTEGER)")
  testthat::expect_true(ledgr_validate_schema(temporary$con))

  attached_path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(c(attached_path, paste0(attached_path, ".wal"))), add = TRUE)
  DBI::dbExecute(
    temporary$con,
    paste0(
      "ATTACH ", DBI::dbQuoteString(temporary$con, attached_path),
      " AS foreign_catalog"
    )
  )
  on.exit(
    try(DBI::dbExecute(temporary$con, "DETACH foreign_catalog"), silent = TRUE),
    add = TRUE
  )
  DBI::dbExecute(
    temporary$con,
    "CREATE TABLE foreign_catalog.main.transient(value INTEGER)"
  )
  testthat::expect_true(ledgr_validate_schema(temporary$con))

  opened <- connect_current()
  on.exit(DBI::dbDisconnect(opened$con, shutdown = TRUE), add = TRUE)
  DBI::dbExecute(opened$con, "DROP TABLE snapshot_sessions")
  DBI::dbExecute(opened$con, paste(
    "CREATE TABLE snapshot_sessions (",
    "snapshot_id VARCHAR NOT NULL, venue_id VARCHAR NOT NULL,",
    "session_date DATE NOT NULL, effective_from TIMESTAMP NOT NULL,",
    "effective_to TIMESTAMP NOT NULL, knowledge_time TIMESTAMP,",
    "status VARCHAR NOT NULL CHECK (status IN ('open')),",
    "session_open TIMESTAMP, session_close TIMESTAMP,",
    "provenance_json VARCHAR NOT NULL,",
    "PRIMARY KEY (snapshot_id, venue_id, session_date))"
  ))
  testthat::expect_error(
    ledgr_validate_schema(opened$con),
    paste0(
      "snapshot_sessions.status must enforce status values ",
      "(open, closed)."
    ),
    fixed = TRUE
  )

  files <- function(path) c(path, paste0(path, ".wal"))
  path <- tempfile(fileext = ".duckdb")
  on.exit(unlink(files(path), force = TRUE), add = TRUE)
  con <- ledgr_db_init(path)
  DBI::dbDisconnect(con, shutdown = TRUE)
  rm(
    list = ls(ledgr:::.ledgr_schema_validation_cache, all.names = TRUE),
    envir = ledgr:::.ledgr_schema_validation_cache
  )
  con <- ledgr_db_init(path)
  DBI::dbDisconnect(con, shutdown = TRUE)
  damaged <- DBI::dbConnect(
    duckdb::duckdb(shared_home = FALSE),
    dbdir = path
  )
  DBI::dbExecute(damaged, "DROP INDEX idx_snapshot_sessions_close")
  DBI::dbDisconnect(damaged, shutdown = TRUE)
  for (attempt in 1:2) {
    testthat::expect_error(
      ledgr_db_init(path),
      paste0(
        "Schema catalogue mismatch: missing index ",
        "snapshot_sessions.idx_snapshot_sessions_close."
      ),
      fixed = TRUE
    )
  }

  noncurrent <- connect_current()
  on.exit(DBI::dbDisconnect(noncurrent$con, shutdown = TRUE), add = TRUE)
  DBI::dbExecute(
    noncurrent$con,
    paste0(
      "UPDATE ledgr_schema_metadata SET value = '118' ",
      "WHERE key = 'experiment_store_schema_version'"
    )
  )
  DBI::dbExecute(noncurrent$con, "DROP TABLE bars")
  error <- testthat::expect_error(
    ledgr_validate_schema(noncurrent$con),
    class = "ledgr_store_rebuild_required"
  )
  testthat::expect_identical(error$cause, "older")

  sweep_source <- paste(
    deparse(ledgr:::ledgr_sweep_assert_schema_compatible),
    collapse = "\n"
  )
  testthat::expect_match(
    sweep_source,
    "ledgr_validate_schema_once(con)",
    fixed = TRUE
  )
  testthat::expect_no_match(
    sweep_source,
    "sweep_candidates|sweep_returns|sweep_trades",
    perl = TRUE
  )
  testthat::expect_false(file.exists(testthat::test_path(
    "..", "..", "R", "schema-catalogue.R"
  )))
})
