# ledgr-test-profile: review
testthat::test_that("[LTB-0259] store-format bindings and JSON are exact", {
  expected_types <- c(
    ledgr_availability_execution_timing_rule_version = "integer",
    ledgr_business_objective_schema_version = "integer",
    ledgr_corporate_action_policy_schema_version = "integer",
    ledgr_cost_schema_version = "integer",
    ledgr_experiment_store_schema_version = "integer",
    ledgr_fact_schema_version = "integer",
    ledgr_fold_list_schema_version = "character",
    ledgr_fold_schema_version = "character",
    ledgr_identity_rule_version = "integer",
    ledgr_objective_criterion_schema_version = "integer",
    ledgr_risk_schema_version = "integer",
    ledgr_saved_sweep_schema_version = "integer",
    ledgr_selection_rule_schema_version = "character",
    ledgr_snapshot_content_hash_rule_version = "integer",
    ledgr_sweep_filter_schema_version = "integer",
    ledgr_sweep_retention_schema_version = "integer",
    ledgr_timing_schema_version = "integer",
    ledgr_valuation_policy_schema_version = "integer",
    ledgr_walk_forward_candidate_schema_version = "character",
    ledgr_walk_forward_schema_version = "character"
  )
  bindings <- ledgr:::ledgr_store_format_bindings()
  actual_types <- vapply(bindings, typeof, character(1))
  testthat::expect_identical(actual_types, expected_types)

  insertion_order <- bindings[rev(seq_along(bindings))]
  expected_json <- ledgr:::ledgr_store_format_json(bindings)
  testthat::expect_identical(
    ledgr:::ledgr_store_format_json(insertion_order),
    expected_json
  )
  parsed <- ledgr:::ledgr_json_read_config(expected_json)
  testthat::expect_identical(typeof(parsed[["ledgr_cost_schema_version"]]), "integer")
  testthat::expect_identical(typeof(parsed[["ledgr_fold_schema_version"]]), "character")

  old_locale <- Sys.getlocale("LC_COLLATE")
  on.exit(suppressWarnings(Sys.setlocale("LC_COLLATE", old_locale)), add = TRUE)
  candidates <- c(
    "C", "en_US.UTF-8", "English_United States.1252",
    "English_United States.utf8", "de_AT.UTF-8", "German_Germany.1252"
  )
  locale_rows <- lapply(candidates, function(candidate) {
    active <- suppressWarnings(Sys.setlocale("LC_COLLATE", candidate))
    if (is.na(active) || !nzchar(active)) return(NULL)
    list(
      active = active,
      ordinary = paste(order(c("a", "B")), collapse = ","),
      fingerprint = ledgr:::ledgr_store_format_json(insertion_order)
    )
  })
  locale_rows <- Filter(Negate(is.null), locale_rows)
  ordinary <- vapply(locale_rows, `[[`, character(1), "ordinary")
  fingerprints <- vapply(locale_rows, `[[`, character(1), "fingerprint")
  testthat::expect_gte(length(unique(ordinary)), 2L)
  testthat::expect_identical(length(unique(fingerprints)), 1L)

  changed <- bindings
  changed[["ledgr_cost_schema_version"]] <- 999L
  testthat::expect_identical(
    ledgr:::ledgr_store_differing_constants(changed, bindings),
    "ledgr_cost_schema_version"
  )

  testthat::expect_identical(length(bindings), 20L)
})

testthat::test_that("[LTB-0260] store gate classifies every marker failure", {
  connect <- function(path = ":memory:") {
    DBI::dbConnect(duckdb::duckdb(shared_home = FALSE), dbdir = path)
  }
  marker_store <- function(version, fingerprint = NULL) {
    con <- connect()
    DBI::dbExecute(
      con,
      paste0(
        "CREATE TABLE ledgr_schema_metadata(",
        "key VARCHAR PRIMARY KEY, value VARCHAR NOT NULL, ",
        "updated_at_utc TIMESTAMP NOT NULL)"
      )
    )
    if (!is.null(version)) {
      DBI::dbExecute(
        con,
        paste0(
          "INSERT INTO ledgr_schema_metadata VALUES ",
          "('experiment_store_schema_version', ?, CURRENT_TIMESTAMP)"
        ),
        params = list(version)
      )
    }
    if (!is.null(fingerprint)) {
      DBI::dbExecute(
        con,
        paste0(
          "INSERT INTO ledgr_schema_metadata VALUES ",
          "('format_fingerprint', ?, CURRENT_TIMESTAMP)"
        ),
        params = list(fingerprint)
      )
    }
    con
  }
  expect_cause <- function(con, cause, recorded_version = NA_integer_,
                           differing = character()) {
    on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
    error <- testthat::expect_error(
      ledgr:::ledgr_store_assert_current(con, "relative.duckdb"),
      class = "ledgr_store_rebuild_required"
    )
    testthat::expect_s3_class(error, "ledgr_invalid_store")
    testthat::expect_identical(error$cause, cause)
    testthat::expect_identical(error$recorded_version, recorded_version)
    testthat::expect_identical(error$differing_constants, differing)
    testthat::expect_true(grepl("relative.duckdb", error$path, fixed = TRUE))
    testthat::expect_match(
      conditionMessage(error),
      "rebuild it with this ledgr version",
      fixed = TRUE
    )
  }

  expect_cause(marker_store("118"), "older", 118L)
  expect_cause(marker_store("999"), "newer", 999L)
  expect_cause(marker_store(NULL), "missing_marker")
  expect_cause(marker_store("not-an-integer"), "invalid_marker")
  expect_cause(marker_store("119"), "missing_marker", 119L)
  expect_cause(marker_store("119", "not-json"), "invalid_marker", 119L)

  current <- ledgr:::ledgr_store_format_bindings()
  changed <- current
  changed[["ledgr_cost_schema_version"]] <- 999L
  changed[["ledgr_business_objective_schema_version"]] <- 999L
  expect_cause(
    marker_store("119", ledgr:::ledgr_store_format_json(changed)),
    "fingerprint_mismatch",
    119L,
    c(
      "ledgr_business_objective_schema_version",
      "ledgr_cost_schema_version"
    )
  )
})

testthat::test_that("[LTB-0261] store creation is empty-only and transactional", {
  files <- function(path) c(path, paste0(path, ".wal"))
  empty <- tempfile(fileext = ".duckdb")
  on.exit(unlink(files(empty), force = TRUE), add = TRUE)
  error <- testthat::expect_error(
    ledgr:::ledgr_store_open(empty, mode = "open"),
    class = "ledgr_store_rebuild_required"
  )
  testthat::expect_identical(error$cause, "missing_marker")
  inspect <- ledgr:::ledgr_open_duckdb_with_retry(empty)
  testthat::expect_identical(
    DBI::dbGetQuery(
      inspect$con,
      "SELECT COUNT(*) AS n FROM information_schema.tables WHERE table_schema = 'main'"
    )$n[[1L]],
    0
  )
  DBI::dbDisconnect(inspect$con, shutdown = TRUE)

  nonempty <- tempfile(fileext = ".duckdb")
  on.exit(unlink(files(nonempty), force = TRUE), add = TRUE)
  con <- DBI::dbConnect(duckdb::duckdb(shared_home = FALSE), dbdir = nonempty)
  DBI::dbExecute(con, "CREATE TABLE sentinel(value INTEGER)")
  DBI::dbDisconnect(con, shutdown = TRUE)
  error <- testthat::expect_error(
    ledgr:::ledgr_store_open(nonempty, mode = "create"),
    class = "ledgr_store_rebuild_required"
  )
  testthat::expect_identical(error$cause, "missing_marker")

  memory <- ledgr:::ledgr_store_open(":memory:", mode = "create")
  on.exit(DBI::dbDisconnect(memory$con, shutdown = TRUE), add = TRUE)
  testthat::expect_true(ledgr:::ledgr_store_assert_current(memory$con))
  testthat::expect_identical(
    names(ledgr:::ledgr_store_read_markers(memory$con)),
    c("experiment_store_schema_version", "format_fingerprint")
  )
  expected <- ledgr:::ledgr_schema_normalized_catalogue(memory$con)
  reference <- DBI::dbConnect(duckdb::duckdb(shared_home = FALSE), ":memory:")
  on.exit(DBI::dbDisconnect(reference, shutdown = TRUE), add = TRUE)
  ledgr:::ledgr_schema_render_current(reference)
  actual <- ledgr:::ledgr_schema_normalized_catalogue(reference)
  testthat::expect_identical(
    ledgr:::ledgr_schema_catalogue_difference(expected, actual),
    list(
      missing = ledgr:::ledgr_schema_catalogue_rows(expected)[0L, ],
      extra = ledgr:::ledgr_schema_catalogue_rows(actual)[0L, ]
    )
  )

  interrupted <- DBI::dbConnect(
    duckdb::duckdb(shared_home = FALSE), dbdir = ":memory:"
  )
  on.exit(DBI::dbDisconnect(interrupted, shutdown = TRUE), add = TRUE)
  statements <- ledgr:::ledgr_current_schema_statements()
  testthat::with_mocked_bindings(
    testthat::expect_error(ledgr:::ledgr_store_create_current(interrupted)),
    ledgr_current_schema_statements = function() {
      append(statements, "CREATE TABLE broken (", after = 5L)
    },
    .package = "ledgr"
  )
  testthat::expect_identical(
    DBI::dbGetQuery(
      interrupted,
      "SELECT COUNT(*) AS n FROM information_schema.tables WHERE table_schema = 'main'"
    )$n[[1L]],
    0
  )
  ledgr:::ledgr_store_create_current(interrupted)
  testthat::expect_true(ledgr:::ledgr_store_assert_current(interrupted))
})

testthat::test_that("[LTB-0262] every persistent store route reaches one gate", {
  package_dir <- testthat::test_path("..", "..", "R")
  package_files <- list.files(package_dir, pattern = "[.]R$", full.names = TRUE)
  source_rows <- unlist(lapply(package_files, function(path) {
    lines <- readLines(path, warn = FALSE)
    lines <- lines[!grepl("^\\s*#", lines)]
    paste(basename(path), trimws(lines), sep = ":")
  }))

  low_open <- source_rows[grepl("ledgr_open_duckdb_with_retry", source_rows, fixed = TRUE)]
  testthat::expect_identical(
    sort(sub(":.*$", "", low_open), method = "radix"),
    c("public-api.R", "store-gate.R")
  )
  direct_connect <- source_rows[grepl("DBI::dbConnect", source_rows, fixed = TRUE)]
  testthat::expect_identical(
    sort(sub(":.*$", "", direct_connect), method = "radix"),
    c(
      "csv-utils.R", "db-schema-validate.R",
      "public-api.R", "public-api.R"
    )
  )

  function_source <- function(name) {
    paste(deparse(get(name, envir = asNamespace("ledgr"))), collapse = "\n")
  }
  asserted_entries <- c(
    "ledgr_snapshot_create", "ledgr_snapshot_info", "ledgr_snapshot_list",
    "ledgr_snapshot_seal", "ledgr_state_reconstruct",
    "ledgr_validate_schema", "ledgr_corporate_action_summary",
    "ledgr_valuation_summary"
  )
  for (name in asserted_entries) {
    testthat::expect_match(
      function_source(name),
      "ledgr_store_assert_current",
      fixed = TRUE,
      info = name
    )
  }

  cached_entries <- c(
    "ledgr_snapshot_connection", "ledgr_backtest_open",
    "ledgr_backtest_read_connection", "ledgr_run_store_open"
  )
  for (name in cached_entries) {
    testthat::expect_match(
      function_source(name),
      "ledgr_store_assert_current|ledgr_store_open",
      perl = TRUE,
      info = name
    )
  }

  attach_source <- function_source("ledgr_prepare_snapshot_source_tables")
  testthat::expect_match(
    attach_source,
    "ledgr_store_open\\(snapshot_db_path, mode = \"open\"\\)[\\s\\S]+ATTACH",
    perl = TRUE
  )

  retired <- c(
    "ledgr_create_schema_legacy", "ledgr_experiment_store_migrate",
    "ledgr_experiment_store_upgrade_", "ledgr_experiment_store_ensure_",
    "ledgr_schema_template", "ledgr_schema_try_triggers"
  )
  package_source <- paste(source_rows, collapse = "\n")
  testthat::expect_false(any(vapply(
    retired, grepl, logical(1), x = package_source, fixed = TRUE
  )))
})
