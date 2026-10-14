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
