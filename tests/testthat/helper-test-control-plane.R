source(testthat::test_path("..", "test-control-plane.R"), local = TRUE)

ledgr_test_checkout_context <- function(root = ledgr_test_source_root()) {
  file.exists(file.path(root, ".git")) ||
    file.exists(file.path(root, ".Rbuildignore"))
}

ledgr_test_design_source_context <- function(root = ledgr_test_source_root()) {
  checkout <- ledgr_test_checkout_context(root)
  design <- file.path(root, "inst", "design")
  if (checkout) {
    testthat::expect_true(
      dir.exists(design),
      info = "inst/design is required in a source checkout"
    )
  } else {
    testthat::expect_false(file.exists(file.path(root, ".git")))
    testthat::expect_false(file.exists(file.path(root, ".Rbuildignore")))
    testthat::expect_false(
      dir.exists(design),
      info = "inst/design must be absent from the built package"
    )
  }
  checkout
}
