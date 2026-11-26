# Cut 25: run one test file of the candidate tree against an installed ledgr
# (--lib, the base) or the candidate source (--source), and print every block
# with its failures. Base and candidate transcripts for LDG-3268 and LDG-3269.
#
#   Rscript test_transcript.R --tests=<tree> --file=<test file name> (--lib=<library> | --source=<tree>)
local({
  argv <- commandArgs(TRUE)
  arg <- function(name) {
    h <- grep(paste0("^--", name, "="), argv, value = TRUE)
    if (length(h)) sub(paste0("^--", name, "="), "", h[[1L]]) else NULL
  }
  tests <- file.path(arg("tests"), "tests", "testthat")
  if (!is.null(arg("lib"))) {
    lib <- normalizePath(arg("lib"), winslash = "/")
    suppressPackageStartupMessages(library(ledgr, lib.loc = lib))
    cat("ledgr from library", lib, "version", as.character(utils::packageVersion("ledgr", lib.loc = lib)), "\n")
    env <- new.env(parent = asNamespace("ledgr"))
    for (h in list.files(tests, "^helper.*[.]R$", full.names = TRUE)) sys.source(h, envir = env)
  } else {
    pkgload::load_all(arg("source"), quiet = TRUE, compile = FALSE, helpers = TRUE)
    cat("ledgr from source", arg("source"), "\n")
    env <- NULL
  }
  file <- file.path(tests, arg("file"))
  r <- if (is.null(env)) {
    testthat::test_file(file, reporter = "silent", package = "ledgr", load_package = "none")
  } else {
    testthat::test_file(file, reporter = "silent", env = env, load_package = "none")
  }
  for (res in r) {
    bad <- Filter(function(e) !inherits(e, c("expectation_success", "expectation_skip")), res$results)
    skip <- Filter(function(e) inherits(e, "expectation_skip"), res$results)
    cat(sprintf("%s | %s | expectations %d failed %d skipped %d\n", if (length(bad)) "FAIL" else "ok",
                res$test, length(res$results), length(bad), length(skip)))
    for (e in bad) cat("   NOT OK:", substr(gsub("\\s+", " ", conditionMessage(e)), 1L, 220L), "\n")
  }
})
