# Cut 25 close review F2: LTB-0567's sweep checks must fail when sweep
# execution reads a wrong feature value or wrong evidence. Adapted from the
# reviewer's sweep_proof_mutant.R. Loads an installed ledgr, wraps
# ledgr_sweep_candidate_execution() so each sweep candidate (not pulse
# inspection) executes on a corrupted projection, and runs LTB-0567:
#   --fault=none            no corruption: LTB-0567 passes;
#   --fault=recovery_value  the finite recovery value at session 5, 105,
#                           becomes -999 (NA mask, prices and targets equal);
#   --fault=na_evidence     the NA cell at session 4 gains an output-carry-expired
#                           reason plane, so its evidence changes while its
#                           value stays NA.
#
#   Rscript sweep_witness.R --tests=<tree> --lib=<library> --fault=<none|recovery_value|na_evidence>
local({
  argv <- commandArgs(TRUE)
  arg <- function(name) sub(paste0("^--", name, "="), "", grep(paste0("^--", name, "="), argv, value = TRUE)[[1L]])
  tree <- arg("tests")
  lib <- normalizePath(arg("lib"), winslash = "/")
  fault <- arg("fault")
  .libPaths(c(lib, .libPaths()))
  Sys.setenv(R_LIBS = paste(c(lib, Sys.getenv("R_LIBS")), collapse = ";"))
  suppressPackageStartupMessages(library(ledgr, lib.loc = lib))
  ns <- asNamespace("ledgr")
  env <- new.env(parent = ns)
  for (h in list.files(file.path(tree, "tests", "testthat"), "^helper.*[.]R$", full.names = TRUE)) sys.source(h, envir = env)
  exprs <- parse(file.path(tree, "tests", "testthat", "test-indicator-evidence.R"))
  eval(exprs[[1L]], envir = env)
  target <- Filter(function(e) any(grepl("LTB-0567", deparse(e), fixed = TRUE)), as.list(exprs))
  stopifnot(length(target) == 1L)
  hits <- new.env()
  hits$n <- 0L
  if (!identical(fault, "none")) {
    f <- ns$ledgr_sweep_candidate_execution
    fenv <- new.env(parent = ns)
    fenv$hits <- hits
    fenv$fault <- fault
    environment(f) <- fenv
    body(f) <- as.call(c(list(as.name("{")), list(quote({
      p <- history_substrate$feature_projection
      if (!identical(run_id, "pulse_inspection") && !is.null(p$feature_values$gap) &&
          identical(as.numeric(p$feature_values$gap[1L, 5L]), 105)) {
        if (identical(fault, "recovery_value")) {
          p$feature_values$gap[1L, 5L] <- -999
        } else {
          planes <- p$feature_planes$gap
          planes$reason_start <- 4
          planes$reason_end <- 4
          planes$reason_code <- 3L
          p$feature_planes$gap <- planes
        }
        history_substrate$feature_projection <- p
        hits$n <- hits$n + 1L
      }
    })), as.list(body(f))[-1L]))
    unlockBinding("ledgr_sweep_candidate_execution", ns)
    assign("ledgr_sweep_candidate_execution", f, envir = ns)
    lockBinding("ledgr_sweep_candidate_execution", ns)
  }
  cat("library", lib, "fault", fault, "\n")
  # A top-level test_that() signals an error when any expectation fails.
  result <- tryCatch({
    eval(target[[1L]], envir = env)
    "passed"
  }, error = function(e) paste("failed:", substr(gsub("\\s+", " ", conditionMessage(e)), 1L, 300L)))
  cat("LTB-0567:", result, "\n")
  cat("corrupted candidate executions:", hits$n, "\n")
  cat(if (identical(result, "passed")) "WITNESS PASS" else "WITNESS FAIL", "\n")
})
