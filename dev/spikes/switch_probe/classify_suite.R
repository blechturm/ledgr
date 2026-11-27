# Switch probe: classifies the tests that fail only with the lean fold
# installed (b_suite_lean_tests.csv against b_suite_baseline_tests.csv).
#   Rscript classify_suite.R   (from this directory's parent or anywhere; paths are relative to this file)
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/"))
b <- utils::read.csv(file.path(here, "b_suite_baseline_tests.csv"), stringsAsFactors = FALSE)
l <- utils::read.csv(file.path(here, "b_suite_lean_tests.csv"), stringsAsFactors = FALSE)
bad <- function(x) x$failed > 0 | x$error
key <- function(x) paste(x$file, x$test, sep = " :: ")
x <- l[bad(l) & !key(l) %in% key(b)[bad(b)], c("file", "test", "problem")]
# Read one by one (the probe README names how): the fault or the observation
# goes through a function the lean fold never calls.
inspected_injection <- c(
  "[LTB-0026] accounting refuses every unhandled pulse event kind" = "mocks ledgr_fold_build_availability_pulse_plan (old plan builder) to inject event kinds",
  "[LTB-0089] strategy contexts expose only current feature values" = "observes state by wrapping ledgr_fold_stage_decide (old P2)",
  "[LTB-0091] authored surface table matches real callback contexts" = "observes state by wrapping ledgr_fold_stage_decide (old P2)",
  "[LTB-0119] every context exposes the common eligibility planes" = "observes state by wrapping ledgr_fold_stage_decide (old P2)",
  "[WS4a C13b] a candidate-calculation error leaves state and buffers unchanged" = "injects the fault through ledgr_lot_fill (old FIFO kernel) and wraps ledgr_fold_stage_apply")
inspected_harness <- c(
  "[LTB-0519] a worker-executed memory sink delivers the in-process native surfaces" =
    "its observer, appended to the worker load expression, is wiped when the harness worker boot reloads ledgr to install the lean core; the switch removes that reload")
inspected_real <- c(
  "[WS4a valuation overflow] a non-finite valuation reaches the base refusal point" =
    "a 1e308 holding sold at 1.9: the pin refuses at P4 (ledgr_invalid_accounting_event), the lean core later (ledgr_config_non_finite); LR-15 dropped the write validator (d_overflow.txt)")
x$class <- "structural (old-internals call counts, mocks or source text; classified from the message)"
x$inspected <- FALSE
x$note <- ""
for (set in list(list(inspected_injection, "fault or observation through an old function"),
                 list(inspected_harness, "harness artifact"),
                 list(inspected_real, "real difference"))) {
  hit <- x$test %in% names(set[[1L]])
  x$class[hit] <- set[[2L]]
  x$inspected[hit] <- TRUE
  x$note[hit] <- set[[1L]][x$test[hit]]
}
# From the message alone, the injected-fault pattern: an expected error or
# FAILED status that a mocked old function was to raise.
inj <- !x$inspected & grepl("to throw a error|identical to \"FAILED\"|`appended` > 0L", x$problem)
x$class[inj] <- "fault or observation through an old function (classified from the message)"
utils::write.csv(x[order(x$class, x$file), ], file.path(here, "e_suite_classification.csv"), row.names = FALSE)
print(table(x$class))
