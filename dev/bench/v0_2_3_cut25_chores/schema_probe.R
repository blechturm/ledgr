# Cut 25 measuring step: the schema golden test under the installed duckdb.
#
#   Rscript dev/bench/v0_2_3_cut25_chores/schema_probe.R --source=<tree> [--lib=<library first on the path>]
local({
  argv <- commandArgs(TRUE)
  arg <- function(name) { h <- grep(paste0("^--", name, "="), argv, value = TRUE); if (length(h)) sub(paste0("^--", name, "="), "", h[[1L]]) else NULL }
  if (!is.null(arg("lib"))) .libPaths(c(arg("lib"), .libPaths()))
  tree <- arg("source")
  cat("duckdb", as.character(utils::packageVersion("duckdb")), "\n")
  pkgload::load_all(tree, quiet = TRUE)
  r <- testthat::test_file(file.path(tree, "tests", "testthat", "test-schema-current.R"), reporter = "silent",
                           package = "ledgr", load_package = "none")
  d <- as.data.frame(r)
  print(d[, c("test", "nb", "failed", "skipped", "error")])
  for (res in r) for (e in res$results) if (!inherits(e, "expectation_success")) cat("NOT OK:", conditionMessage(e), "\n")
})
