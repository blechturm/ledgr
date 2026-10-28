# Demonstrates that LTB-0514 fails when either governance-report default is
# reverted to the v0.2.2 packet (LDG-3126). It mutates one default line at a
# time and restores tools/governance-report.R byte for byte when the function
# exits, including on error or interrupt.
#
# Usage: Rscript dev/governance_guard/default_packet_revert_demo.R [repo root]
default_packet_revert_demo <- function(root) {
  tool <- file.path(root, "tools", "governance-report.R")
  original <- readBin(tool, "raw", file.info(tool)$size)
  on.exit(writeBin(original, tool), add = TRUE)
  pkgload::load_all(root, quiet = TRUE)
  desc <- "[LTB-0514] both governance report entry points default to the v0.2.3 packet"
  run <- function(label) {
    res <- as.data.frame(testthat::test_file(
      file.path(root, "tests/testthat/test-governance-report.R"),
      desc = desc, reporter = "silent", stop_on_failure = FALSE
    ))
    cat(sprintf("%s: failed=%d error=%s\n", label, res$failed, res$error))
    res$failed > 0 || res$error
  }
  text <- readLines(tool, warn = FALSE)
  new <- "inst/design/ledgr_v0_2_3_spec_packet"
  old <- "inst/design/ledgr_v0_2_2_spec_packet"
  hits <- grep(new, text, fixed = TRUE)
  stopifnot(length(hits) == 2L)
  outcomes <- c(unchanged = run("unchanged tool"))
  for (line in hits) {
    mutated <- text
    mutated[[line]] <- sub(new, old, mutated[[line]], fixed = TRUE)
    writeLines(mutated, tool)
    outcomes[[sprintf("revert line %d", line)]] <- run(sprintf("default at line %d reverted", line))
    writeBin(original, tool)
  }
  print(outcomes)
  stopifnot(!outcomes[["unchanged"]], all(outcomes[-1L]))
  cat("DEMO PASS: LTB-0514 passes unchanged and fails on each reverted default\n")
  invisible(outcomes)
}

local({
  args <- commandArgs(trailingOnly = TRUE)
  root <- normalizePath(if (length(args)) args[[1L]] else ".", winslash = "/", mustWork = TRUE)
  default_packet_revert_demo(root)
})
