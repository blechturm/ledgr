testthat::test_that("LDG-509 ticket metadata mirrors markdown ticket IDs", {
  ticket_md <- system.file(
    "design",
    "ledgr_v0_1_2_spec_packet",
    "v0_1_2_tickets.md",
    package = "ledgr"
  )
  ticket_yml <- system.file(
    "design",
    "ledgr_v0_1_2_spec_packet",
    "tickets.yml",
    package = "ledgr"
  )

  testthat::expect_true(file.exists(ticket_md))
  testthat::expect_true(file.exists(ticket_yml))

  md <- readLines(ticket_md, warn = FALSE)
  yml <- readLines(ticket_yml, warn = FALSE)

  heading_lines <- grep("^### LDG-[0-9]+:", md, value = TRUE)
  md_ids <- sub("^### (LDG-[0-9]+):.*$", "\\1", heading_lines)
  yml_id_lines <- grep("^  - id: LDG-[0-9]+$", yml, value = TRUE)
  yml_ids <- sub("^  - id: (LDG-[0-9]+)$", "\\1", yml_id_lines)

  testthat::expect_setequal(yml_ids, md_ids)
  testthat::expect_equal(length(yml_ids), length(unique(yml_ids)))

  all_refs <- unique(unlist(regmatches(yml, gregexpr("LDG-[0-9]+", yml))))
  testthat::expect_true(all(all_refs %in% yml_ids))
})

testthat::test_that("LDG-509 contract index and ADRs are packaged", {
  contracts <- system.file("design", "contracts.md", package = "ledgr")
  adr_names <- c(
      "0001-split-db-semantics.md",
      "0002-registry-fingerprint-policy.md",
      "0003-closure-fingerprinting.md"
  )
  adr_files <- vapply(
    adr_names,
    function(name) system.file("design", "adr", name, package = "ledgr"),
    character(1)
  )

  testthat::expect_true(file.exists(contracts))
  testthat::expect_true(all(file.exists(adr_files)))

  contracts_text <- paste(readLines(contracts, warn = FALSE), collapse = "\n")
  testthat::expect_match(contracts_text, "Execution Contract", fixed = TRUE)
  testthat::expect_match(contracts_text, "Strategy Contract", fixed = TRUE)
  testthat::expect_match(contracts_text, "Verification Contract", fixed = TRUE)
})

testthat::test_that("LDG-509 root AGENTS handoff file is present in source checkouts", {
  find_repo_root <- function() {
    candidates <- normalizePath(
      c(getwd(), file.path(getwd(), ".."), file.path(getwd(), "..", "..")),
      winslash = "/",
      mustWork = FALSE
    )
    for (candidate in unique(candidates)) {
      desc <- file.path(candidate, "DESCRIPTION")
      if (!file.exists(desc)) next
      first <- readLines(desc, n = 1L, warn = FALSE)
      if (length(first) == 1L && identical(first, "Package: ledgr")) {
        return(candidate)
      }
    }
    NULL
  }

  repo_root <- find_repo_root()
  if (is.null(repo_root)) {
    testthat::skip("Source checkout root is not available in this installed-package test context.")
  }

  agents <- file.path(repo_root, "AGENTS.md")
  if (!file.exists(agents)) {
    testthat::skip("Root AGENTS.md is source-only and not available in this installed-package test context.")
  }
  agents_text <- paste(readLines(agents, warn = FALSE), collapse = "\n")
  testthat::expect_match(agents_text, "Local Verification", fixed = TRUE)
  testthat::expect_match(agents_text, "Ticket Workflow", fixed = TRUE)
})
