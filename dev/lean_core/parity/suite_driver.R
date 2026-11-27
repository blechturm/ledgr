# The switch's suite driver (Cut 27, LDG-3280): the new pin's own test suite
# with a candidate lean core installed as the switch would install it
# (lean_loop_install(hooks = FALSE): the envelope, the context read method
# and the worker channel; no harness hooks, no pin fallback).
#
# Two sources, named separately and recorded:
# - the pin: an immutable source archive of the reference build (it holds
#   LEDGR_SOURCE_COMMIT, which must equal load.R's lean_core_pin, and a DLL
#   built beforehand by one process). Its package is loaded from there; its
#   tests are the ones run unless --tests names a scratch copy.
# - the candidate: a dev/lean_core directory (default: the one beside this
#   file). Its load.R and lean files are the ones sourced.
# The record holds both origins, the pin marker, an md5 over the pin's R/ and
# the tests run, and the candidate's per-file md5 with its git commit and
# whether those files differ from it.
#
# Guard: before the suite, one smoke run (a two-instrument fixture of the
# suite's helpers, fills on most pulses) runs on the pin and then on the
# candidate. The candidate must enter its own envelope (the bound envelope is
# the candidate's, and a counting wrapper sees an entry) and reproduce the
# pin's ledger, equity and fills exactly; otherwise the driver stops with
# status 2 before any test runs. A broken candidate is refused this way
# (suite_driver_broken.R writes three). With --witness=1, for a run against a
# deliberately mutated candidate (remap_demo.R), the guard's verdict is
# recorded in smoke.txt and the tests run anyway; such a run is never the
# suite run of record.
#
# Tests reach the candidate as the switch will expose it: its lean
# environment is attached on the search path right after package:ledgr (so a
# package name still resolves to the package), and
# getOption("ledgr.candidate_lean") is the candidate's directory.
#
#   Rscript suite_driver.R --pin=<pin source archive> --out=<dir>
#     [--lean=<candidate dev/lean_core>] [--tests=<testthat dir>]
#     [--files=<regex over test file names>] [--debug=1|0] [--smoke-only=1]
#     [--witness=1]
#
# Writes <out>/identity.csv, <out>/smoke.txt, <out>/tests.csv (one row per
# test: file, test, counts, first problem) and <out>/summary.txt.
local({
  argv <- commandArgs(TRUE)
  arg <- function(n, d = NULL) {
    v <- grep(paste0("^--", n, "="), argv, value = TRUE)
    if (length(v)) sub(paste0("^--", n, "="), "", v[[1L]]) else d
  }
  here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
                                winslash = "/"))
  pin <- arg("pin")
  out <- arg("out")
  if (is.null(pin) || is.null(out)) stop("suite_driver.R: --pin and --out are required", call. = FALSE)
  assign("drv", list(
    pin = normalizePath(pin, winslash = "/", mustWork = TRUE),
    lean = normalizePath(arg("lean", file.path(here, "..")), winslash = "/", mustWork = TRUE),
    tests = arg("tests"),
    files = arg("files", ""),
    debug = identical(arg("debug", "1"), "1"),
    smoke_only = identical(arg("smoke-only", "0"), "1"),
    witness = identical(arg("witness", "0"), "1"),
    out = out
  ), globalenv())
})
if (is.null(drv$tests)) drv$tests <- file.path(drv$pin, "tests", "testthat")
drv$tests <- normalizePath(drv$tests, winslash = "/", mustWork = TRUE)
dir.create(drv$out, recursive = TRUE, showWarnings = FALSE)
drv$out <- normalizePath(drv$out, winslash = "/")
# Never inside a source package: a worker started from one would load it.
setwd(drv$out)
fail <- function(...) {
  msg <- paste0(...)
  writeLines(msg, file.path(drv$out, "smoke.txt"))
  cat("GUARD REFUSED:", msg, "\n")
  quit(save = "no", status = 2L)
}
# A smoke-run failure: refused, or recorded on a witness run.
guard_notes <- character()
guard <- function(...) {
  if (!drv$witness) fail(...)
  guard_notes <<- c(guard_notes, paste0(...))
  invisible(NULL)
}

# --- identity ---------------------------------------------------------------
# One md5 over a directory's matching files: the md5 of "relative path md5"
# lines in path order.
md5_of <- function(dir, pattern) {
  f <- sort(list.files(dir, pattern = pattern, full.names = TRUE, recursive = TRUE), method = "radix")
  lines <- paste(substring(f, nchar(dir) + 2L), unname(tools::md5sum(f)))
  p <- tempfile(fileext = ".txt")
  writeLines(lines, p)
  list(n = length(f), all = unname(tools::md5sum(p)))
}
lean_files <- sort(list.files(drv$lean, pattern = "[.]R$", full.names = TRUE), method = "radix")
lean_md5 <- unname(tools::md5sum(lean_files))
git <- function(...) suppressWarnings(tryCatch(system2("git", c("-C", shQuote(drv$lean), ...), stdout = TRUE, stderr = FALSE),
                                               error = function(e) character()))
lean_commit <- git("rev-parse", "--short=8", "HEAD")
if (!length(lean_commit)) lean_commit <- "<no git>"
lean_dirty <- git("status", "--porcelain", "--", ".")
pin_marker <- readLines(file.path(drv$pin, "LEDGR_SOURCE_COMMIT"), warn = FALSE)[[1L]]
pin_r <- md5_of(file.path(drv$pin, "R"), "[.]R$")
tests_md5 <- md5_of(drv$tests, "[.]R$")
identity_rows <- rbind(
  data.frame(source = "pin", item = "origin", value = drv$pin),
  data.frame(source = "pin", item = "LEDGR_SOURCE_COMMIT", value = pin_marker),
  data.frame(source = "pin", item = "R/ md5 (all files)", value = pin_r$all),
  data.frame(source = "tests", item = "origin", value = drv$tests),
  data.frame(source = "tests", item = "md5 (all *.R)", value = tests_md5$all),
  data.frame(source = "candidate", item = "origin", value = drv$lean),
  data.frame(source = "candidate", item = "git commit", value = lean_commit),
  data.frame(source = "candidate", item = "files differ from commit",
             value = if (length(lean_dirty)) paste(sub("^...", "", lean_dirty), collapse = " ") else "none"),
  data.frame(source = "candidate", item = paste("md5", basename(lean_files)), value = lean_md5),
  data.frame(source = "run", item = "debug", value = as.character(drv$debug)),
  stringsAsFactors = FALSE
)
utils::write.csv(identity_rows, file.path(drv$out, "identity.csv"), row.names = FALSE)

# --- load the pin, then the candidate ----------------------------------------
source(file.path(drv$lean, "load.R"))
if (!identical(normalizePath(lean_core_home, winslash = "/"), drv$lean)) {
  fail("the sourced load.R reports home ", lean_core_home, ", not ", drv$lean)
}
lean <- lean_core_load(drv$pin, debug = drv$debug)
if (!identical(normalizePath(getNamespaceInfo("ledgr", "path"), winslash = "/"), drv$pin)) {
  fail("ledgr is loaded from ", getNamespaceInfo("ledgr", "path"), ", not the pin ", drv$pin)
}
if (!identical(normalizePath(lean$.lean_home, winslash = "/"), drv$lean)) {
  fail("the lean environment was sourced from ", lean$.lean_home, ", not the candidate ", drv$lean)
}
cat("pin", pin_marker, "from", drv$pin, "\ncandidate", drv$lean, "at", lean_commit,
    if (length(lean_dirty)) "(files differ from the commit)" else "", "\n")

# --- the smoke guard ----------------------------------------------------------
helpers <- new.env(parent = globalenv())
# The helpers are sourced from inside the tests directory, where test_path()
# resolves only while testthat reports a test run.
Sys.setenv(TESTTHAT = "true")
invisible(utils::capture.output(testthat::source_test_helpers(drv$tests, env = helpers)))
Sys.unsetenv("TESTTHAT")
smoke_strategy <- function(ctx, params) {
  t <- ctx$flat()
  for (id in ctx$universe) t[[id]] <- floor(ctx$close[[id]] * 7) %% 3
  t
}
smoke <- function() {
  db <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db), add = TRUE)
  bt <- helpers$ledgr_test_run(data = helpers$test_bars, strategy = smoke_strategy, start = "2020-01-01",
                               end = "2020-03-31", db_path = db, run_id = "suite-driver-smoke",
                               cost_model = ledgr::ledgr_cost_chain(ledgr::ledgr_cost_spread_bps(5), ledgr::ledgr_cost_fixed_fee(1)))
  on.exit(close(bt), add = TRUE)
  out <- lapply(c("ledger", "equity", "fills"), function(w) as.data.frame(ledgr::ledgr_results(bt, what = w)))
  names(out) <- c("ledger", "equity", "fills")
  out
}
strip_clock <- function(x) lapply(x, function(d) d[, !grepl("wall|elapsed|created|_at$", names(d)), drop = FALSE])
on_pin <- tryCatch(strip_clock(smoke()), error = function(e) fail("the smoke run fails on the pin: ", conditionMessage(e)))
restore <- lean$lean_loop_install(hooks = FALSE)
ns <- asNamespace("ledgr")
if (!identical(get("ledgr_fold_envelope", envir = ns), lean$lean_fold_envelope)) {
  fail("the bound envelope is not the candidate's")
}
entries <- 0L
bound <- get("ledgr_fold_envelope", envir = ns)
rebind <- function(f) { unlockBinding("ledgr_fold_envelope", ns); assign("ledgr_fold_envelope", f, envir = ns); lockBinding("ledgr_fold_envelope", ns) }
rebind(function(execution, output_handler) { entries <<- entries + 1L; bound(execution, output_handler) })
on_lean <- tryCatch(strip_clock(smoke()), error = function(e) e, finally = rebind(bound))
if (inherits(on_lean, "error")) {
  guard("the smoke run fails on the candidate: ", class(on_lean)[[1L]], ": ", conditionMessage(on_lean))
} else {
  if (entries < 1L) guard("the smoke run never entered the candidate's envelope")
  diff <- names(on_pin)[!vapply(names(on_pin), function(n) identical(on_pin[[n]], on_lean[[n]]), logical(1))]
  if (length(diff)) guard("the candidate's smoke run differs from the pin's in: ", paste(diff, collapse = ", "))
}
smoke_line <- if (length(guard_notes)) {
  paste("WITNESS RUN, guard would refuse:", paste(guard_notes, collapse = "; "))
} else {
  sprintf("smoke PASS%s: %d envelope entries; ledger %d rows, equity %d, fills %d identical to the pin",
          if (drv$witness) " (witness run)" else "", entries, nrow(on_pin$ledger), nrow(on_pin$equity), nrow(on_pin$fills))
}
writeLines(smoke_line, file.path(drv$out, "smoke.txt"))
cat(smoke_line, "\n")
if (drv$smoke_only) quit(save = "no", status = 0L)
attach(lean, pos = match("package:ledgr", search()) + 1L, name = "ledgr:candidate", warn.conflicts = FALSE)
options(ledgr.candidate_lean = drv$lean)

# --- the suite ----------------------------------------------------------------
# A scratch copy of the tests has no package beside it: the tests that read
# the package source find the pin's.
if (!identical(drv$tests, normalizePath(file.path(drv$pin, "tests", "testthat"), winslash = "/"))) {
  Sys.setenv(LEDGR_TEST_SOURCE_ROOT = drv$pin)
}
# The tests run in environments whose parent is the global environment, so
# none of this driver's names may stay there (a global `identity` once
# shadowed base::identity in every tryCatch(error = identity)). What the
# driver needs afterwards is kept under one hidden name.
.suite_driver <- list(drv = drv, restore = restore, lean_commit = lean_commit, lean_dirty = lean_dirty,
                      pin_marker = pin_marker, t0 = proc.time()[["elapsed"]])
rm(list = ls(globalenv()), envir = globalenv())
res <- testthat::test_dir(.suite_driver$drv$tests,
                          filter = if (nzchar(.suite_driver$drv$files)) .suite_driver$drv$files else NULL,
                          load_package = "none", reporter = testthat::SummaryReporter$new(),
                          stop_on_failure = FALSE, stop_on_warning = FALSE)
drv <- .suite_driver$drv
lean_commit <- .suite_driver$lean_commit
lean_dirty <- .suite_driver$lean_dirty
pin_marker <- .suite_driver$pin_marker
t0 <- .suite_driver$t0
restore <- .suite_driver$restore
first_problem <- function(r) {
  for (e in r$results) {
    if (inherits(e, c("expectation_failure", "expectation_error"))) {
      return(substr(gsub("[\r\n]+", " ", conditionMessage(e)), 1L, 400L))
    }
  }
  ""
}
df <- data.frame(file = vapply(res, function(r) basename(r$file), ""), test = vapply(res, function(r) r$test, ""),
                 stringsAsFactors = FALSE)
s <- as.data.frame(res)
df$failed <- s$failed; df$error <- s$error; df$skipped <- s$skipped; df$passed <- s$passed
df$problem <- vapply(res, first_problem, "")
utils::write.csv(df, file.path(drv$out, "tests.csv"), row.names = FALSE)
summary_line <- sprintf("%d files, %d tests, %d failed, %d errors, %d skipped, %.0f s (candidate %s%s, pin %s, debug %s)",
                        length(unique(df$file)), nrow(df), sum(df$failed > 0), sum(df$error), sum(df$skipped),
                        proc.time()[["elapsed"]] - t0, lean_commit, if (length(lean_dirty)) "+changes" else "",
                        pin_marker, drv$debug)
writeLines(summary_line, file.path(drv$out, "summary.txt"))
cat(summary_line, "\n")
restore()
