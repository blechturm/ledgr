# LDG-3129 demonstration: the focused publication-delta tests (LTB-0515) and
# the db_live writer test (LTB-0516) pass on the shared computation and fail
# when ledgr_fill_publication_deltas() is perturbed. The perturbation replaces
# the namespace binding in this process only; no file is changed.
#
# Usage: Rscript dev/ws1/r3_perturbation_demo.R [repo root]
r3_perturbation_demo <- function(root) {
  pkgload::load_all(root, quiet = TRUE)
  file <- file.path(root, "tests/testthat/test-ledger-writer.R")
  blocks <- c(
    "[LTB-0515] fill-row publication deltas are computed once for every publication path",
    "[LTB-0516] the db_live writer keeps its validation and transaction behavior around the shared deltas"
  )
  run <- function(label) {
    vapply(blocks, function(desc) {
      res <- as.data.frame(testthat::test_file(file, desc = desc, reporter = "silent",
        stop_on_failure = FALSE, load_package = "none"))
      bad <- res$failed > 0 || res$error
      cat(sprintf("%s | %s: failed=%d error=%s\n", label, substr(desc, 1, 10), res$failed, res$error))
      bad
    }, logical(1))
  }
  ns <- asNamespace("ledgr")
  original <- get("ledgr_fill_publication_deltas", envir = ns)
  restore <- function() {
    unlockBinding("ledgr_fill_publication_deltas", ns)
    assign("ledgr_fill_publication_deltas", original, envir = ns)
    lockBinding("ledgr_fill_publication_deltas", ns)
  }
  on.exit(restore(), add = TRUE)
  clean <- run("shared computation")
  perturb <- function(name, edit) {
    unlockBinding("ledgr_fill_publication_deltas", ns)
    assign("ledgr_fill_publication_deltas", function(side, qty, fill_price, fee) {
      edit(original(side, qty, fill_price, fee))
    }, envir = ns)
    lockBinding("ledgr_fill_publication_deltas", ns)
    on.exit(restore(), add = TRUE)
    run(name)
  }
  cash <- perturb("cash_delta + 1e-9", function(d) { d$cash_delta <- d$cash_delta + 1e-9; d })
  position <- perturb("position_delta sign flipped", function(d) { d$position_delta <- -d$position_delta; d })
  stopifnot(!any(clean), all(cash), all(position))
  cat("DEMO PASS: both blocks pass on the shared computation and fail on each perturbation\n")
  invisible(TRUE)
}

local({
  args <- commandArgs(trailingOnly = TRUE)
  r3_perturbation_demo(normalizePath(if (length(args)) args[[1L]] else ".", winslash = "/", mustWork = TRUE))
})
