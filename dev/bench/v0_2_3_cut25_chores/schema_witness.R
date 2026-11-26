# Cut 25 decision 1 (LDG-3267): witnesses for the schema golden test without
# its duckdb-version expectations. Runs LTB-0258 from a scratch copy of the
# test, its two fixtures and R/, unchanged (--mode=plain), with one golden
# catalogue row altered (--mode=row) or with one dimension digest altered
# (--mode=digest). Prints the duckdb version and each failed expectation.
#
#   Rscript schema_witness.R --source=<tree> --scratch=<dir> --mode=<plain|row|digest> [--lib=<library>]
local({
  argv <- commandArgs(TRUE)
  arg <- function(name) {
    h <- grep(paste0("^--", name, "="), argv, value = TRUE)
    if (length(h)) sub(paste0("^--", name, "="), "", h[[1L]]) else NULL
  }
  if (!is.null(arg("lib"))) .libPaths(c(arg("lib"), .libPaths()))
  tree <- arg("source")
  mode <- arg("mode")
  root <- file.path(arg("scratch"), mode)
  dir.create(file.path(root, "tests", "testthat", "fixtures"), recursive = TRUE, showWarnings = FALSE)
  files <- c("test-schema-current.R", "fixtures/schema-current-golden.csv", "fixtures/schema-current-golden-rows.csv")
  for (f in files) {
    file.copy(file.path(tree, "tests", "testthat", f), file.path(root, "tests", "testthat", f), overwrite = TRUE)
  }
  # LTB-0263 in the same file reads the source tree under the test root.
  dir.create(file.path(root, "R"), showWarnings = FALSE)
  file.copy(list.files(file.path(tree, "R"), full.names = TRUE), file.path(root, "R"), overwrite = TRUE)
  rows_file <- file.path(root, "tests", "testthat", "fixtures", "schema-current-golden-rows.csv")
  golden_file <- file.path(root, "tests", "testthat", "fixtures", "schema-current-golden.csv")
  if (identical(mode, "row")) {
    rows <- utils::read.csv(rows_file, stringsAsFactors = FALSE, check.names = FALSE)
    i <- which(rows$dimension == "column")[[1L]]
    cat("altered row", i, ":", rows$object[[i]], rows$attribute[[i]], rows$value[[i]], "-> altered\n")
    rows$value[[i]] <- paste0(rows$value[[i]], "_altered")
    utils::write.csv(rows, rows_file, row.names = FALSE)
  } else if (identical(mode, "digest")) {
    g <- utils::read.csv(golden_file, stringsAsFactors = FALSE)
    cat("altered digest of dimension", g$dimension[[1L]], "\n")
    g$sha256[[1L]] <- strrep("0", 64L)
    utils::write.csv(g, golden_file, row.names = FALSE)
  }
  cat("mode", mode, "duckdb", as.character(utils::packageVersion("duckdb")), "\n")
  pkgload::load_all(tree, quiet = TRUE, compile = FALSE)
  r <- testthat::test_file(file.path(root, "tests", "testthat", "test-schema-current.R"),
                           reporter = "silent", package = "ledgr", load_package = "none")
  d <- as.data.frame(r)
  print(d[, c("test", "nb", "failed", "error")])
  for (res in r) for (e in res$results) {
    if (!inherits(e, "expectation_success")) cat("NOT OK:", substr(conditionMessage(e), 1L, 200L), "\n")
  }
  cat(if (sum(d$failed) + sum(d$error) == 0L) "WITNESS PASS" else "WITNESS FAIL", "\n")
})
