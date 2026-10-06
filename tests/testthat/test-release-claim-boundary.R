# Release claim boundary (terminal-outcomes synthesis Section 6; v0.2.2
# release definition of done item 9). Remove this pin only together with
# linking accepted ledgr-research LFB-027 evidence and an end-to-end record.
ledgr_doc_sharadar_boundary <- function() {
  paste(
    "Halts and untraded sessions that a data source encodes as zero-volume",
    "bars carrying the previous close, as the reference Sharadar data does,",
    "are still read as observed prices: they can fill and they bypass",
    "valuation ageing and freezing."
  )
}

# Prose sentences only: code fences are dropped and paragraphs split first,
# so a negation in a neighbouring paragraph cannot excuse a claim.
ledgr_doc_sentences <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  fence <- grepl("^\\s*```", lines)
  in_code <- (cumsum(fence) %% 2L == 1L) | fence
  lines[in_code] <- ""
  paragraph <- cumsum(!nzchar(trimws(lines)))
  paragraphs <- vapply(split(lines, paragraph), paste, character(1), collapse = " ")
  out <- unlist(lapply(paragraphs, function(text) {
    text <- gsub("\\s+", " ", gsub("[>#*`]+", " ", text))
    strsplit(trimws(text), "(?<=[.!?])\\s+(?=[A-Z])", perl = TRUE)[[1L]]
  }), use.names = FALSE)
  out[nzchar(out)]
}

# Sentences that claim more than the boundary allows: any Sharadar sentence
# other than the boundary itself, and any sentence calling frozen or freeze
# equity exact without a negation.
ledgr_doc_terminal_claim_problems <- function(root) {
  boundary <- ledgr_doc_sharadar_boundary()
  sources <- c(
    file.path(root, c("README.Rmd", "README.md", "NEWS.md")),
    list.files(file.path(root, "vignettes"), pattern = "[.](qmd|md)$",
               full.names = TRUE, recursive = TRUE),
    list.files(file.path(root, "man"), pattern = "[.]Rd$", full.names = TRUE)
  )
  sources <- sources[file.exists(sources)]
  out <- character()
  for (path in sources) {
    sentences <- ledgr_doc_sentences(path)
    sharadar <- sentences[grepl("Sharadar", sentences, fixed = TRUE)]
    bad <- sharadar[!vapply(sharadar, function(x) grepl(boundary, x, fixed = TRUE), logical(1))]
    out <- c(out, sprintf("%s: unbounded Sharadar claim: %s", basename(path), bad))
    exact <- sentences[
      grepl("\\b(frozen|freeze)\\b", sentences, ignore.case = TRUE) &
        grepl("\\bequity\\b", sentences, ignore.case = TRUE) &
        grepl("\\bexact\\b", sentences, ignore.case = TRUE) &
        !grepl("\\b(not|never|estimate)\\b", sentences, ignore.case = TRUE)
    ]
    out <- c(out, sprintf("%s: frozen equity called exact: %s", basename(path), exact))
  }
  out
}

# ledgr-test-profile: fast
testthat::test_that("[LTB-0181] the Sharadar boundary is pinned and frozen equity is never called exact", {
  root <- testthat::test_path("..", "..")
  boundary <- ledgr_doc_sharadar_boundary()
  squish <- function(path) {
    text <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = " ")
    gsub("\\s+", " ", gsub("\\s>\\s", " ", text))
  }
  pinned <- c(
    file.path(root, "vignettes", c(
      "survivorship-bias.qmd", "survivorship-bias.md",
      "missing-data-and-sessions.qmd", "missing-data-and-sessions.md"
    )),
    file.path(root, "inst", "design", c("contracts.md", "release_ci_playbook.md"))
  )
  for (path in pinned) {
    testthat::expect_true(grepl(boundary, squish(path), fixed = TRUE), info = basename(path))
  }
  # The v0.2.2 release notes carry the boundary once they exist.
  news <- readLines(file.path(root, "NEWS.md"), warn = FALSE, encoding = "UTF-8")
  first_heading <- news[grep("^# ", news)[[1L]]]
  if (grepl("0\\.2\\.2", first_heading)) {
    testthat::expect_true(grepl(boundary, squish(file.path(root, "NEWS.md")), fixed = TRUE))
  }
  testthat::expect_identical(ledgr_doc_terminal_claim_problems(root), character())
})
