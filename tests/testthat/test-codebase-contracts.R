ledgr_test_structure_inventory <- local({
  cached <- NULL
  function() {
    if (!is.null(cached)) return(cached)
    root <- ledgr_test_source_root()
    scanner <- new.env(parent = globalenv())
    sys.source(file.path(root, "tools", "codebase-structure.R"), envir = scanner)
    cached <<- list(
      root = root,
      scan = scanner$ledgr_structure_scan(root),
      bind_rows = scanner$ledgr_census_bind_rows,
      schemas = scanner$ledgr_census_schemas(),
      summarize = scanner$ledgr_census_summary
    )
    cached
  }
})

# ledgr-test-profile: fast
testthat::test_that("[LTB-0270] private helpers retain an executable caller", {
  inventory <- ledgr_test_structure_inventory()
  testthat::expect_gt(length(inventory$scan$helpers), 0L)
  testthat::expect_gt(length(inventory$scan$private_helpers), 0L)
  testthat::expect_identical(inventory$scan$orphan_helpers, character())

  if (ledgr_test_checkout_context(inventory$root)) {
    seams <- utils::read.csv(
      file.path(
        inventory$root, "dev", "bench", "v0_2_2_pre_cran_removal",
        "census", "test_only_seams.csv"
      ),
      stringsAsFactors = FALSE
    )
    testthat::expect_true(all(nzchar(seams$testing_contract)))
    testthat::expect_false(any(startsWith(
      seams$testing_contract, "direct_test_seam:"
    )))
  } else {
    testthat::expect_false(dir.exists(file.path(inventory$root, "dev")))
  }
})

# ledgr-test-profile: fast
testthat::test_that("[LTB-0271] public condition classes remain documented", {
  inventory <- ledgr_test_structure_inventory()
  reference <- readLines(
    file.path(inventory$root, "R", "condition-reference.R"),
    warn = FALSE
  )
  alias_lines <- grep("^#' @aliases ", reference, value = TRUE)
  aliases <- unique(unlist(strsplit(
    sub("^#' @aliases ", "", alias_lines),
    "[[:space:]]+"
  )))
  descriptions <- unique(gsub(
    "`", "",
    unlist(regmatches(
      reference,
      gregexpr("`ledgr_[A-Za-z0-9_]+`", reference, perl = TRUE)
    ))
  ))
  public <- inventory$scan$condition_classes[
    !grepl("^ledgr_internal_", inventory$scan$condition_classes)
  ]
  testthat::expect_gt(length(public), 0L)
  testthat::expect_true("ledgr_strategy_error" %in% public)
  if (ledgr_test_checkout_context(inventory$root)) {
    reported <- utils::read.csv(
      file.path(
        inventory$root, "dev", "bench", "v0_2_2_pre_cran_removal",
        "census", "condition_classes.csv"
      ),
      stringsAsFactors = FALSE
    )
    reported_public <- reported$condition_class[reported$public]
    testthat::expect_setequal(public, reported_public)
  } else {
    testthat::expect_false(dir.exists(file.path(inventory$root, "dev")))
  }
  testthat::expect_setequal(setdiff(public, aliases), character())
  testthat::expect_setequal(setdiff(public, descriptions), character())
})

# ledgr-test-profile: fast
testthat::test_that("[LTB-0272] an empty census family remains a valid table", {
  inventory <- ledgr_test_structure_inventory()
  empty <- lapply(inventory$schemas, function(schema) {
    inventory$bind_rows(list(), schema)
  })
  summary <- inventory$summarize(empty)

  testthat::expect_true(all(vapply(empty, inherits, logical(1), "data.frame")))
  testthat::expect_true(all(vapply(empty, nrow, integer(1)) == 0L))
  testthat::expect_identical(summary$rows, rep(0L, 6L))
  testthat::expect_identical(summary$findings, rep(0L, 6L))

  checker <- readLines(
    file.path(inventory$root, "tools", "check-codebase-contracts.R"),
    warn = FALSE
  )
  testthat::expect_match(
    paste(checker, collapse = "\n"),
    "version_rows <- ledgr_census_bind_rows\\(",
    perl = TRUE
  )
  testthat::expect_match(
    paste(checker, collapse = "\n"),
    "summary <- ledgr_census_summary\\(list\\(",
    perl = TRUE
  )
})

# ledgr-test-profile: fast
testthat::test_that("[LTB-0331] execution-mode branches match the committed census record", {
  root <- ledgr_test_source_root()
  scanner <- new.env(parent = globalenv())
  sys.source(file.path(root, "tools", "codebase-structure.R"), envir = scanner)
  sites <- scanner$ledgr_mode_branch_scan(root)
  testthat::expect_gt(sum(sites$kind == "branch"), 0L)
  testthat::expect_gt(sum(sites$kind == "flow"), 0L)
  testthat::expect_true(all(
    c("R/fold-engine.R", "R/backtest-runner.R", "R/sweep.R", "R/walk-forward.R") %in%
      sites$file
  ))

  if (ledgr_test_checkout_context(root)) {
    record <- utils::read.csv(
      file.path(
        root, "dev", "bench", "v0_2_2_pre_cran_removal", "census",
        "mode_branches.csv"
      ),
      colClasses = "character",
      na.strings = character(),
      encoding = "UTF-8"
    )
    record$occurrence <- as.integer(record$occurrence)
    testthat::expect_true(scanner$ledgr_mode_branch_check(sites, record))
  } else {
    testthat::expect_false(dir.exists(file.path(root, "dev")))
  }

  # A synthetic source tree: each switch form is found, a matching record
  # passes, and one added branch or one removed site fails the check.
  probe <- withr::local_tempdir("ledgr-mode-branch-")
  dir.create(file.path(probe, "R"))
  probe_file <- file.path(probe, "R", "probe.R")
  base_source <- c(
    "probe_runner <- function(exp, services, history_substrate = NULL) {",
    "  use_dense <- !isTRUE(exp$availability$active)",
    "  if (use_dense) return(1)",
    "  if (services$availability_active && is.null(history_substrate)) 2",
    "  run(dispositions_active = ledgr_availability_config_active(exp))",
    "}"
  )
  writeLines(base_source, probe_file)
  recorded <- scanner$ledgr_mode_branch_scan(probe)
  testthat::expect_identical(
    recorded[, c("kind", "switch", "context")],
    data.frame(
      kind = c("branch", "branch", "flow", "flow", "flow"),
      switch = c(
        "$availability_active+is.null(history_substrate)", "alias:use_dense",
        "alias:use_dense", "availability$active",
        "ledgr_availability_config_active()"
      ),
      context = c(
        "if: services$availability_active && is.null(history_substrate)",
        "if: use_dense", "assign_target", "assign:use_dense",
        "arg:run:dispositions_active"
      ),
      stringsAsFactors = FALSE
    )
  )
  testthat::expect_true(scanner$ledgr_mode_branch_check(recorded, recorded))

  writeLines(
    c(base_source[1:5], "  if (!availability_active) 3", base_source[[6L]]),
    probe_file
  )
  added <- scanner$ledgr_mode_branch_scan(probe)
  testthat::expect_error(
    scanner$ledgr_mode_branch_check(added, recorded),
    "LEDGR_MODE_BRANCH_CENSUS_FAILED unrecorded=1 stale=0",
    fixed = TRUE
  )
  difference <- scanner$ledgr_mode_branch_compare(added, recorded)
  testthat::expect_identical(
    unlist(difference$unrecorded[1L, c("owner", "kind", "switch", "context")]),
    c(
      owner = "probe_runner", kind = "branch", switch = "availability_active",
      context = "if: !availability_active"
    )
  )
  writeLines(base_source[-4L], probe_file)
  testthat::expect_error(
    scanner$ledgr_mode_branch_check(scanner$ledgr_mode_branch_scan(probe), recorded),
    "LEDGR_MODE_BRANCH_CENSUS_FAILED unrecorded=0 stale=1",
    fixed = TRUE
  )

  # Check mode compares before it writes any record.
  checker <- paste(readLines(
    file.path(root, "tools", "check-codebase-contracts.R"),
    warn = FALSE
  ), collapse = "\n")
  check_at <- regexpr(
    "ledgr_mode_branch_check(mode_branch_sites, mode_branch_record)",
    checker, fixed = TRUE
  )
  write_at <- regexpr("dir.create(output, recursive = TRUE", checker, fixed = TRUE)
  testthat::expect_gt(check_at, 0L)
  testthat::expect_lt(check_at, write_at)
})
