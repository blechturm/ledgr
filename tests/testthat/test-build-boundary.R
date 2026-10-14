# ledgr-test-profile: fast
testthat::test_that("[LTB-0267] design memory stays source-only", {
  root <- ledgr_test_source_root()
  checkout <- ledgr_test_design_source_context(root)

  if (checkout) {
    build_ignore <- readLines(file.path(root, ".Rbuildignore"), warn = FALSE)
    design_rules <- grep("^\\^inst/design", build_ignore, value = TRUE)
    testthat::expect_identical(design_rules, "^inst/design$")

    workflow <- paste(
      readLines(
        file.path(root, ".github", "workflows", "R-CMD-check.yaml"),
        warn = FALSE
      ),
      collapse = "\n"
    )
    testthat::expect_match(
      workflow,
      "grep -qvE '^(inst/design/|docs/)'",
      fixed = TRUE
    )
  } else {
    testthat::expect_identical(
      system.file("design", package = "ledgr"),
      ""
    )
  }
})
