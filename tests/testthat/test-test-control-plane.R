testthat::test_that("control-plane metadata fails closed", {
  test_dir <- tempfile("ledgr-profile-")
  dir.create(test_dir)
  writeLines(
    c(
      "# ledgr-test-profile: unknown",
      "testthat::test_that(\"unknown\", { testthat::succeed() })"
    ),
    file.path(test_dir, "test-unknown.R")
  )
  testthat::expect_error(
    ledgr_test_preflight(test_dir),
    class = "ledgr_test_profile_unknown"
  )

  writeLines(
    c(
      "# ledgr-test-file-profile: review",
      "# ledgr-test-profile: review",
      "testthat::test_that(\"contradictory\", { testthat::succeed() })"
    ),
    file.path(test_dir, "test-contradictory.R")
  )
  unlink(file.path(test_dir, "test-unknown.R"))
  testthat::expect_error(
    ledgr_test_preflight(test_dir),
    class = "ledgr_test_profile_contradictory"
  )

  writeLines(
    c(
      "# ledgr-test-file-profile: review",
      "testthat::test_that('duplicate', { testthat::succeed() })",
      "testthat::test_that('duplicate', { testthat::succeed() })"
    ),
    file.path(test_dir, "test-contradictory.R")
  )
  expanded <- ledgr_test_preflight(test_dir)
  testthat::expect_identical(expanded$profile, c("review", "review"))
  testthat::expect_identical(expanded$occurrence, c(1L, 2L))
  testthat::expect_length(unique(expanded$key), 2L)

  writeLines(
    c(
      "title <- 'dynamic'",
      "testthat::test_that(title, { testthat::succeed() })"
    ),
    file.path(test_dir, "test-contradictory.R")
  )
  testthat::expect_error(
    ledgr_test_preflight(test_dir),
    class = "ledgr_test_profile_unclassified"
  )

  writeLines(
    c(
      "testthat::test_that('[LTB-9999] first', { testthat::succeed() })",
      "testthat::test_that('[LTB-9999] second', { testthat::succeed() })"
    ),
    file.path(test_dir, "test-contradictory.R")
  )
  testthat::expect_error(
    ledgr_test_preflight(test_dir),
    class = "ledgr_test_block_id_duplicate"
  )
})

testthat::test_that("control-plane mutations fail for distinct reasons", {
  expected <- data.frame(
    file = c("test-a.R", "test-a.R"),
    line = c(1L, 2L),
    title = c("one", "two"),
    block_id = c(NA_character_, NA_character_),
    key = c("test-a.R::one", "test-a.R::two"),
    profile = c("fast", "fast"),
    stringsAsFactors = FALSE
  )
  gutted <- expected[1L, , drop = FALSE]
  testthat::expect_error(
    ledgr_test_reconcile_selection(expected, gutted),
    class = "ledgr_test_profile_selection_mismatch"
  )
  reported <- data.frame(
    file = "test-a.R", title = "one", key = "test-a.R::one",
    status = "passed", stringsAsFactors = FALSE
  )
  testthat::expect_error(
    ledgr_test_reconcile_execution(expected, reported),
    class = "ledgr_test_profile_execution_mismatch"
  )
  testthat::expect_error(
    ledgr_test_select(expected, "typo"),
    class = "ledgr_test_profile_unknown"
  )

  # Exercise the real runner hooks as well as their pure reconciliation
  # helpers: removing either runner call must make this block fail.
  root <- tempfile("ledgr-runner-wiring-")
  test_dir <- file.path(root, "tests", "testthat")
  dir.create(test_dir, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writeLines(
    "testthat::test_that('[LTB-9000] runner detector', { testthat::succeed() })",
    file.path(test_dir, "test-runner-detector.R")
  )
  claims_path <- file.path(root, "claims.yml")
  yaml::write_yaml(list(claims = list(list(
    id = "LCL-runner",
    source = "defect:runner-wiring",
    scope = "runner selection and execution reconciliation",
    oracle_class = "negative witness",
    detecting_blocks = list("LTB-9000"),
    promised_profile = "fast",
    owner = "maintainer"
  ))), claims_path)
  run <- function(selector = identity, actual_filter = identity) {
    ledgr_test_run_profile(
      root,
      reporter = "silent",
      claims_path = claims_path,
      selector = selector,
      actual_filter = actual_filter
    )
  }

  testthat::expect_error(
    run(selector = function(selected) selected[0L, , drop = FALSE]),
    class = "ledgr_test_profile_selection_mismatch"
  )
  testthat::expect_error(
    run(actual_filter = function(actual) actual[0L, , drop = FALSE]),
    class = "ledgr_test_profile_execution_mismatch"
  )
  testthat::expect_error(
    run(actual_filter = function(actual) {
      extra <- actual[1L, , drop = FALSE]
      extra$title <- "injected"
      extra$key <- "test-runner-detector.R::injected::1"
      rbind(actual, extra)
    }),
    class = "ledgr_test_profile_execution_mismatch"
  )
})

testthat::test_that("claims use stable prefixes and fail when every detector skips", {
  preflight <- data.frame(
    file = "test-a.R",
    line = 1L,
    title = "[LTB-9999] detector",
    block_id = "LTB-9999",
    key = "test-a.R::[LTB-9999] detector",
    profile = "fast",
    stringsAsFactors = FALSE
  )
  claims <- list(list(
    id = "LCL-test",
    source = "defect:test",
    scope = "checker mutation",
    oracle_class = "negative witness",
    detecting_blocks = list("LTB-9999"),
    promised_profile = "fast",
    owner = "maintainer"
  ))
  actual <- data.frame(
    file = "test-a.R",
    title = "[LTB-9999] detector",
    key = preflight$key,
    status = "skipped",
    stringsAsFactors = FALSE
  )
  testthat::expect_error(
    ledgr_test_claims_check(claims, preflight, actual, "fast"),
    class = "ledgr_test_claims_all_skipped"
  )
  renamed <- preflight
  renamed$title <- "[LTB-9999] renamed detector"
  renamed$key <- "test-a.R::[LTB-9999] renamed detector"
  testthat::expect_identical(renamed$block_id, preflight$block_id)
  renamed_actual <- actual
  renamed_actual$title <- renamed$title
  renamed_actual$key <- renamed$key
  renamed_actual$status <- "passed"
  testthat::expect_true(
    ledgr_test_claims_check(claims, renamed, renamed_actual, "fast")
  )

  registry <- tempfile(fileext = ".yml")
  yaml::write_yaml(list(claims = claims), registry)
  testthat::expect_length(ledgr_test_claims_read(registry, renamed), 1L)
  removed <- renamed
  removed$block_id <- NA_character_
  testthat::expect_error(
    ledgr_test_claims_read(registry, removed),
    class = "ledgr_test_claims_unresolved_block"
  )

  yaml::write_yaml(list(claims = c(claims, claims)), registry)
  testthat::expect_error(
    ledgr_test_claims_read(registry, renamed),
    class = "ledgr_test_claims_duplicate"
  )
  ownerless <- claims
  ownerless[[1L]]$owner <- ""
  yaml::write_yaml(list(claims = ownerless), registry)
  testthat::expect_error(
    ledgr_test_claims_read(registry, renamed),
    class = "ledgr_test_claims_missing_owner"
  )
  unknown <- claims
  unknown[[1L]]$promised_profile <- "unknown"
  yaml::write_yaml(list(claims = unknown), registry)
  testthat::expect_error(
    ledgr_test_claims_read(registry, renamed),
    class = "ledgr_test_claims_unknown_profile"
  )
  mismatched <- claims
  mismatched[[1L]]$promised_profile <- "review"
  yaml::write_yaml(list(claims = mismatched), registry)
  testthat::expect_error(
    ledgr_test_claims_read(registry, renamed),
    class = "ledgr_test_claims_profile_mismatch"
  )
})

testthat::test_that("deliberately slow timing and missing release evidence fail gates", {
  testthat::expect_identical(
    ledgr_test_gate_decide(89, 90, 2L),
    89
  )
  testthat::expect_error(
    ledgr_test_gate_decide(c(91, 92), 90, 2L),
    class = "ledgr_test_timing_protocol_incomplete"
  )
  slow_seconds <- unname(system.time(Sys.sleep(0.02))[["elapsed"]])
  testthat::expect_error(
    ledgr_test_gate_decide(rep(slow_seconds, 3L), 0.001, 2L),
    class = "ledgr_test_timing_gate_failed"
  )
  testthat::expect_error(
    ledgr_test_release_gate(data.frame(profile = "fast", passed = TRUE)),
    class = "ledgr_test_release_profile_missing"
  )
  testthat::expect_true(ledgr_test_release_gate(data.frame(
    profile = c("fast", "review"),
    passed = c(TRUE, TRUE)
  )))
})

testthat::test_that("[LTB-0082] profile tools identify the exact failing condition", {
  root <- normalizePath(testthat::test_path("..", ".."), winslash = "/")
  rscript <- file.path(R.home("bin"), "Rscript")
  run_tool <- function(script, args) {
    suppressWarnings(system2(
      rscript,
      c("--vanilla", shQuote(script), args),
      stdout = TRUE,
      stderr = TRUE
    ))
  }

  probe <- tempfile("ledgr-runner-failure-")
  dir.create(file.path(probe, "R"), recursive = TRUE)
  dir.create(file.path(probe, "tests", "testthat"), recursive = TRUE)
  on.exit(unlink(probe, recursive = TRUE), add = TRUE)
  file.copy(
    file.path(root, "tests", "test-control-plane.R"),
    file.path(probe, "tests", "test-control-plane.R")
  )
  writeLines(c(
    "Package: ledgr",
    "Title: Test Profile Probe",
    "Version: 0.0.0.1",
    "Authors@R: person('Test', 'Probe', role = c('aut', 'cre'), email = 'test@example.com')",
    "Description: A minimal package used to execute the profile runner.",
    "License: MIT",
    "Encoding: UTF-8"
  ), file.path(probe, "DESCRIPTION"))
  writeLines(character(), file.path(probe, "NAMESPACE"))
  writeLines(
    "testthat::test_that('[LTB-9001] injected warning', { warning('injected warning'); testthat::succeed() })",
    file.path(probe, "tests", "testthat", "test-warning.R")
  )
  yaml::write_yaml(list(claims = list(list(
    id = "LCL-probe",
    source = "defect:runner-reporting",
    scope = "injected warning",
    oracle_class = "negative witness",
    detecting_blocks = list("LTB-9001"),
    promised_profile = "fast",
    owner = "maintainer"
  ))), file.path(probe, "tests", "claims.yml"))
  yaml::write_yaml(list(
    ordinary_fast_max_seconds = 100,
    cran_fast_max_seconds = 100,
    confirmation_runs_above_bound = 2L
  ), file.path(probe, "tests", "test-gates.yml"))
  runner_records <- file.path(probe, "records")
  runner_output <- run_tool(
    file.path(root, "tools", "run-test-profile.R"),
    c(
      shQuote(paste0("--root=", probe)),
      "--profile=fast", "--mode=ordinary",
      shQuote(paste0("--records=", runner_records)),
      "--run-index=1", "--reporter=silent"
    )
  )
  testthat::expect_false(is.null(attr(runner_output, "status")))
  testthat::expect_match(paste(runner_output, collapse = "\n"), "LTB-9001", fixed = TRUE)
  testthat::expect_no_match(
    paste(runner_output, collapse = "\n"),
    "LEDGR_TEST_PROFILE_OK",
    fixed = TRUE
  )

  write_gate_case <- function(profile = "fast", mode = "ordinary",
                              statuses = "passed", expected = length(statuses),
                              executed = sum(!is.na(statuses))) {
    records <- tempfile("ledgr-gate-case-")
    dir.create(records)
    keys <- sprintf("test-probe.R::block-%d::1", seq_along(statuses))
    census <- data.frame(
      profile = rep(profile, length(statuses)),
      key = keys,
      status = statuses,
      stringsAsFactors = FALSE
    )
    summary <- data.frame(
      profile = profile,
      mode = mode,
      elapsed_seconds = 1,
      expected_blocks = expected,
      executed_blocks = executed,
      skipped_blocks = sum(statuses == "skipped", na.rm = TRUE),
      failed_blocks = sum(statuses %in% c("failed", "error", "warning"), na.rm = TRUE),
      stringsAsFactors = FALSE
    )
    utils::write.csv(census, file.path(records, "run-1-census.csv"), row.names = FALSE)
    utils::write.csv(summary, file.path(records, "run-1-summary.csv"), row.names = FALSE)
    on.exit(unlink(records, recursive = TRUE), add = TRUE)
    run_tool(
      file.path(root, "tools", "check-test-gate.R"),
      c("--profile=fast", "--mode=ordinary", shQuote(paste0("--records=", records)))
    )
  }

  warning_output <- write_gate_case(statuses = "warning")
  testthat::expect_match(paste(warning_output, collapse = "\n"), "non-passing", fixed = TRUE)
  testthat::expect_match(paste(warning_output, collapse = "\n"), "test-probe.R::block-1::1", fixed = TRUE)

  profile_output <- write_gate_case(profile = "review")
  testthat::expect_match(paste(profile_output, collapse = "\n"), "profile mismatch", fixed = TRUE)
  testthat::expect_match(paste(profile_output, collapse = "\n"), "test-probe.R::block-1::1", fixed = TRUE)

  mode_output <- write_gate_case(mode = "cran")
  testthat::expect_match(paste(mode_output, collapse = "\n"), "mode mismatch", fixed = TRUE)
  testthat::expect_match(paste(mode_output, collapse = "\n"), "test-probe.R::block-1::1", fixed = TRUE)

  execution_output <- write_gate_case(
    statuses = c("passed", NA_character_), expected = 2L, executed = 1L
  )
  testthat::expect_match(
    paste(execution_output, collapse = "\n"),
    "executed/expected mismatch",
    fixed = TRUE
  )
  testthat::expect_match(
    paste(execution_output, collapse = "\n"),
    "test-probe.R::block-2::1",
    fixed = TRUE
  )
})

testthat::test_that("heavy protocols require an owner invocation and checker", {
  registry <- tempfile(fileext = ".yml")
  writeLines(c(
    "protocols:",
    "  - id: full-heavy",
    "    owner: maintainer",
    "    profile: heavy_protocol",
    "    invocation: run",
    "    checker: check",
    "    purpose: bounded heavy evidence"
  ), registry)
  protocols <- ledgr_test_heavy_protocols_read(registry)
  testthat::expect_identical(protocols[[1L]]$owner, "maintainer")
  writeLines(c(
    "protocols:",
    "  - id: broken",
    "    owner: ''",
    "    profile: heavy_protocol",
    "    invocation: run",
    "    checker: check",
    "    purpose: broken"
  ), registry)
  testthat::expect_error(
    ledgr_test_heavy_protocols_read(registry),
    class = "ledgr_test_heavy_registry_invalid"
  )
})
