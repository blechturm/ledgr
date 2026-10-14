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
      bind_rows = scanner$ledgr_census_bind_rows
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
  public <- inventory$scan$direct_condition_classes[
    !grepl("^ledgr_internal_", inventory$scan$direct_condition_classes)
  ]

  testthat::expect_gt(length(public), 0L)
  testthat::expect_true("ledgr_strategy_error" %in% public)
  testthat::expect_setequal(setdiff(public, aliases), character())
  testthat::expect_setequal(setdiff(public, descriptions), character())
})

# ledgr-test-profile: fast
testthat::test_that("[LTB-0272] an empty census family remains a valid table", {
  inventory <- ledgr_test_structure_inventory()
  columns <- c("file", "line", "record_kind")
  empty <- inventory$bind_rows(list(), columns)

  testthat::expect_s3_class(empty, "data.frame")
  testthat::expect_identical(names(empty), columns)
  testthat::expect_identical(nrow(empty), 0L)
})
