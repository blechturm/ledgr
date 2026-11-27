ws4a_sources <- function() {
  root <- ledgr_test_source_root()
  checker <- new.env(parent = baseenv())
  sys.source(file.path(root, "tools", "check-fold-phase-contract.R"), envir = checker)
  files <- list.files(file.path(root, "R"), "\\.R$", full.names = TRUE)
  checker$ledgr_fold_phase_function_sources(files)
}
