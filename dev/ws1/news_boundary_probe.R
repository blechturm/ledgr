# Phase B review P1 demonstration: with the development NEWS heading in
# place, LTB-0181 fails when the published v0.2.2 Sharadar boundary paragraph
# is missing from NEWS.md. NEWS.md is restored byte for byte on exit.
#
# Usage: Rscript dev/ws1/news_boundary_probe.R [repo root]
news_boundary_probe <- function(root) {
  news <- file.path(root, "NEWS.md")
  original <- readBin(news, "raw", file.info(news)$size)
  on.exit(writeBin(original, news), add = TRUE)
  pkgload::load_all(root, quiet = TRUE)
  desc <- "[LTB-0181] the Sharadar boundary is pinned and frozen equity is never called exact"
  run <- function(label) {
    res <- as.data.frame(testthat::test_file(file.path(root, "tests/testthat/test-release-claim-boundary.R"),
      desc = desc, reporter = "silent", stop_on_failure = FALSE, load_package = "none"))
    cat(sprintf("%s: failed=%d error=%s\n", label, res$failed, res$error))
    res$failed > 0 || res$error
  }
  text <- readLines(news, warn = FALSE, encoding = "UTF-8")
  stopifnot(grepl("development version", text[[1L]]))
  start <- grep("^Halts and untraded sessions that a data source encodes", text)
  stopifnot(length(start) == 1L, identical(text[[start + 3L]], "freezing."))
  clean <- run("NEWS with the boundary paragraph")
  writeLines(text[-seq.int(start, start + 4L)], news, useBytes = TRUE)
  missing <- run("NEWS without the boundary paragraph")
  writeBin(original, news)
  stopifnot(!clean, missing)
  cat("PROBE PASS: LTB-0181 passes with the paragraph and fails without it under the development heading\n")
  invisible(TRUE)
}

local({
  args <- commandArgs(trailingOnly = TRUE)
  news_boundary_probe(normalizePath(if (length(args)) args[[1L]] else ".", winslash = "/", mustWork = TRUE))
})
