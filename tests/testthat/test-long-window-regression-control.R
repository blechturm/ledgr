# ledgr-test-profile: review
testthat::test_that("[LTB-0153] strict built-ins do linear public-run work", {
  # Preparation work is counted apart from the sampled causality check
  # (LDG-3067), whose recomputations run inside the same preparation.
  original <- ledgr:::ledgr_history_feature_segment
  original_check <- ledgr:::ledgr_history_feature_causality
  work <- 0L
  calls <- 0L
  check_work <- 0L
  check_calls <- 0L
  checking <- FALSE
  testthat::local_mocked_bindings(
    ledgr_history_feature_segment = function(cert, inputs, fields, rows, ...) {
      if (checking) {
        check_work <<- check_work + length(rows)
        check_calls <<- check_calls + 1L
      } else {
        work <<- work + length(rows)
        calls <<- calls + 1L
      }
      original(cert, inputs, fields, rows, ...)
    },
    ledgr_history_feature_causality = function(...) {
      checking <<- TRUE
      on.exit(checking <<- FALSE)
      original_check(...)
    },
    .package = "ledgr"
  )

  checks <- list()
  observed <- lapply(c(40L, 80L), function(days) {
    work <<- 0L
    calls <<- 0L
    check_work <<- 0L
    check_calls <<- 0L
    snapshot <- availability_runtime_fixture(days = days)
    on.exit(ledgr_snapshot_close(snapshot), add = TRUE)
    experiment <- ledgr_experiment(
      snapshot,
      function(ctx, params) ctx$hold(),
      features = list(ledgr_ind_sma(20L), ledgr_ind_returns(20L)),
      valuation_policy = ledgr_valuation_stale(2L),
      cost_model = ledgr_cost_zero()
    )
    bt <- ledgr_run(experiment, run_id = paste0("linear-strict-", days))
    on.exit(close(bt), add = TRUE)
    testthat::expect_identical(ledgr_run_info(snapshot, bt$run_id)$status,
                               "DONE")
    checks[[length(checks) + 1L]] <<- c(work = check_work, calls = check_calls)
    c(work = work, calls = calls)
  })

  testthat::expect_identical(unname(observed[[1L]]), c(80L, 2L))
  testthat::expect_identical(unname(observed[[2L]]), c(160L, 2L))
  testthat::expect_identical(
    unname(observed[[2L]][["work"]] / observed[[1L]][["work"]]),
    2
  )
  # The check adds a fixed number of segment calls per definition (its probe
  # and four sampled prefixes) and work bounded by five passes of the probe's
  # history, never one pass per prefix.
  for (i in seq_along(checks)) {
    testthat::expect_identical(unname(checks[[i]][["calls"]]), 2L * 5L)
    testthat::expect_lte(unname(checks[[i]][["work"]]), 2L * 5L * c(40L, 80L)[[i]])
  }
})

testthat::test_that("[LTB-0154] release-only regression cases stay explicit", {
  release_name <- paste0("run_", "release.R")
  repository <- if (exists("ledgr_test_source_root", mode = "function")) {
    ledgr_test_source_root()
  } else {
    normalizePath(".", winslash = "/")
  }
  forbidden <- c(
    list.files(file.path(repository, "tests"), recursive = TRUE,
               full.names = TRUE),
    list.files(file.path(repository, ".github", "workflows"), recursive = TRUE,
               full.names = TRUE)
  )
  forbidden <- forbidden[file.info(forbidden)$isdir %in% FALSE]
  uses <- vapply(forbidden, function(path) {
    any(grepl(release_name, readLines(path, warn = FALSE), fixed = TRUE))
  }, logical(1L))
  testthat::expect_false(any(uses))

  script <- file.path(
    repository, "dev", "bench", "v0_2_2_long_window_regression",
    release_name
  )
  checkout <- file.exists(file.path(repository, ".git")) ||
    file.exists(file.path(repository, ".Rbuildignore"))
  if (checkout) {
    testthat::expect_true(file.exists(script))
    build_ignore <- readLines(file.path(repository, ".Rbuildignore"), warn = FALSE)
    testthat::expect_true("^dev(/|$)" %in% build_ignore)
    result <- suppressWarnings(ledgr_test_system2(
      file.path(R.home("bin"), "Rscript"), shQuote(script),
      stdout = TRUE, stderr = TRUE
    ))
    testthat::expect_false(is.null(attr(result, "status")))
    testthat::expect_match(
      paste(result, collapse = "\n"),
      "Release-only cases require the explicit --release flag.",
      fixed = TRUE
    )
  } else {
    testthat::expect_false(file.exists(file.path(repository, ".git")))
    testthat::expect_false(file.exists(file.path(repository, ".Rbuildignore")))
    testthat::expect_false(dir.exists(file.path(repository, "dev")))
  }
})

testthat::test_that("[LTB-0182] the terminal release fixture stays release-only and recorded", {
  repository <- if (exists("ledgr_test_source_root", mode = "function")) {
    ledgr_test_source_root()
  } else {
    normalizePath(".", winslash = "/")
  }
  suite <- file.path(repository, "dev", "bench", "v0_2_2_long_window_regression")
  script_name <- paste0("terminal_", "release.R")
  checkout <- file.exists(file.path(repository, ".git")) ||
    file.exists(file.path(repository, ".Rbuildignore"))
  if (checkout) {
    testthat::expect_true(dir.exists(suite))
    build_ignore <- readLines(file.path(repository, ".Rbuildignore"), warn = FALSE)
    testthat::expect_true("^dev(/|$)" %in% build_ignore)
    forbidden <- c(
      list.files(file.path(repository, "tests"), recursive = TRUE, full.names = TRUE),
      list.files(file.path(repository, ".github", "workflows"), recursive = TRUE, full.names = TRUE)
    )
    forbidden <- forbidden[file.info(forbidden)$isdir %in% FALSE]
    uses <- vapply(forbidden, function(path) {
      any(grepl(script_name, readLines(path, warn = FALSE), fixed = TRUE))
    }, logical(1L))
    testthat::expect_false(any(uses))

    # The flag guard runs before the package or any fixture is loaded.
    source_lines <- readLines(file.path(suite, script_name), warn = FALSE)
    guard <- grep("Release-only cases require the explicit --release flag.", source_lines, fixed = TRUE)
    load <- grep("pkgload::load_all", source_lines, fixed = TRUE)
    testthat::expect_length(guard, 1L)
    testthat::expect_true(length(load) == 1L && guard < load)
    testthat::expect_true(any(grepl("\"terminal\"", readLines(file.path(suite, paste0("run_", "release.R")), warn = FALSE), fixed = TRUE)))

    # The checked-in record crosses every case the fixture promises.
    record <- yyjsonr::read_json_file(file.path(
      suite, "evidence", "terminal_release", "expected.json"
    ))$outputs
    testthat::expect_identical(record$status, "DONE")
    outcomes <- unlist(record$terminal_outcomes)
    testthat::expect_identical(substr(outcomes, 1L, 3L), c("T10", "T15", "T20"))
    testthat::expect_match(outcomes[[1L]], "|write_off|default: assumed worthless|0|", fixed = TRUE)
    testthat::expect_match(outcomes[[2L]], "|last_mark|declared: last observed mark|", fixed = TRUE)
    testthat::expect_identical(record$valuation$valuation_state, "frozen")
    testthat::expect_identical(record$valuation$frozen_at_end_count, "1")
    testthat::expect_identical(record$valuation$longest_freeze_sessions, "38")
    testthat::expect_true(length(unlist(record$warning)) > 0L)
  } else {
    testthat::expect_false(file.exists(file.path(repository, ".git")))
    testthat::expect_false(file.exists(file.path(repository, ".Rbuildignore")))
    testthat::expect_false(dir.exists(file.path(repository, "dev")))
  }
})
