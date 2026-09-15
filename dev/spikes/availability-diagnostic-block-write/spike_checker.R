# Checker for the availability diagnostic-block spike (Charter v2).
#
# Three actions, per spike_protocol.md section 6:
#   1. rerun the deterministic phases (semantic, tests) into a scratch
#      evidence directory;
#   2. diff: the deterministic CSVs (fixture.csv, cases.csv,
#      diagnostics_reference.csv, coverage.csv, setv_trace.csv,
#      regression_tests.csv) must be byte-identical to the rerun; the
#      measurement CSVs are validated against the Charter's rules: arm
#      attestation (stamped writer mode, observed provider arm, traced
#      constructor counts), repetition shape, the wall and relative-spread and
#      memory components of the envelope, the current-arm stop, persisted
#      parity with exactly the registered exclusions, lane shares, and the
#      GREEN / kill-and-recharter reading;
#   3. guard package scope over every Git change type: the seam is
#      R/availability-diagnostic-writer.R and R/fold-engine.R modified beside
#      the reviewed provider seam and the maintainer's pre-existing edits.
# Attestation is not self-asserted: every fold run carries the mode stamped on
# the writer ledgr actually built and the traced counts of the scalar and
# block constructors; a block-arm run with any scalar construction, no block
# construction, or a non-block stamp fails before any equality can pass, and a
# gutted append_block() that fell back to per-row writes fails the
# collapse::setv() call-count bound on the traced semantic scenarios.
#
# Usage, from the repository root:
#   Rscript dev/spikes/availability-diagnostic-block-write/spike_checker.R \
#       [--skip-rerun | --rerun-dir <dir>] [--evidence <dir>]
# Exit status is non-zero on any failure. No hash ledger, registry, or
# workspace-cleanliness gate.

args <- commandArgs(trailingOnly = TRUE)
script_path <- local({
  f <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  normalizePath(sub("^--file=", "", f[[1L]]), winslash = "/")
})
spike_dir <- dirname(script_path)
repo_root <- normalizePath(file.path(spike_dir, "..", "..", ".."), winslash = "/")
runner <- file.path(spike_dir, "spike_runner.R")
arg_value <- function(flag, default) { i <- match(flag, args); if (is.na(i) || i == length(args)) default else args[[i + 1L]] }
skip_rerun <- "--skip-rerun" %in% args
evidence <- normalizePath(arg_value("--evidence", file.path(spike_dir, "evidence")), winslash = "/", mustWork = TRUE)
scratch <- tempfile("spike_checker_evidence_")
rerun_dir <- if ("--rerun-dir" %in% args) normalizePath(arg_value("--rerun-dir", NULL), winslash = "/", mustWork = TRUE) else scratch

failures <- character()
note <- function(ok, what) {
  cat(sprintf("[%s] %s\n", if (isTRUE(ok)) "PASS" else "FAIL", what))
  if (!isTRUE(ok)) failures <<- c(failures, what)
  invisible(isTRUE(ok))
}
finish <- function() {
  if (dir.exists(scratch)) unlink(scratch, recursive = TRUE, force = TRUE)
  cat(sprintf("\nspike_checker: %d failure(s)\n", length(failures)))
  if (length(failures)) { cat(paste0("  - ", failures), sep = "\n"); quit(status = 1L) }
  quit(status = 0L)
}
read_ev <- function(name, dir = evidence) utils::read.csv(file.path(dir, name), stringsAsFactors = FALSE, check.names = FALSE, na.strings = "NA")
read_bytes <- function(path) readBin(path, what = "raw", n = file.size(path))
first_diff <- function(a, b) {
  la <- readLines(a, warn = FALSE); lb <- readLines(b, warn = FALSE)
  n <- max(length(la), length(lb)); length(la) <- n; length(lb) <- n
  i <- which(is.na(la) | is.na(lb) | la != lb)
  if (length(i)) sprintf("first differing line %d", i[[1L]]) else "differs only in line endings or trailing bytes"
}
git_lines <- function(...) {
  out <- suppressWarnings(system2("git", c("-C", shQuote(repo_root), ...), stdout = TRUE, stderr = FALSE))
  status <- attr(out, "status")
  if (!is.null(status) && status != 0L) { note(FALSE, sprintf("git %s failed with status %d", paste(c(...), collapse = " "), status)); finish() }
  as.character(out)
}
all_true <- function(x) length(x) > 0L && !anyNA(x) && all(x)
true_where_present <- function(x) any(!is.na(x)) && all(x[!is.na(x)])
SETV_COLUMNS <- 13L   # numeric, integer, and POSIXct diagnostic columns written with collapse::setv()
ROWS_757 <- 757L * 505L + 757L

deterministic <- c("fixture.csv", "cases.csv", "diagnostics_reference.csv", "coverage.csv", "setv_trace.csv", "regression_tests.csv")
measurement <- c("environment.csv", "regression_optional.csv", "regression_attestation.csv", "fold_757.csv", "lanes_757.csv", "fold_757_parity.csv")
optional_tests <- "parallel availability sweeps return the same compact terminal evidence"
present <- file.exists(file.path(evidence, c(deterministic, measurement)))
note(all(present), sprintf("evidence: all twelve CSVs present in %s%s", evidence,
     if (all(present)) "" else paste0(" (missing: ", paste(c(deterministic, measurement)[!present], collapse = ", "), ")")))
if (!all(file.exists(file.path(evidence, deterministic)))) finish()

# 1. Rerun the deterministic phases into scratch.
if (!skip_rerun && identical(rerun_dir, scratch)) {
  dir.create(scratch, recursive = TRUE)
  rscript <- file.path(R.home("bin"), c("Rscript.exe", "x64/Rscript.exe", "Rscript")); rscript <- rscript[file.exists(rscript)][[1L]]
  for (phase in c("semantic", "tests")) {
    cat("rerunning", phase, "into", scratch, "\n")
    log <- system2(rscript, c(shQuote(runner), phase, "--evidence", shQuote(scratch)), stdout = TRUE, stderr = TRUE)
    if (!is.null(attr(log, "status"))) cat(utils::tail(log, 20), sep = "\n")
  }
  rerun_ok <- all(file.exists(file.path(scratch, deterministic)))
  note(rerun_ok, "rerun produced every deterministic CSV")
  if (!rerun_ok) finish()
}

# 2a. Deterministic evidence: byte-exact.
if (!skip_rerun) {
  for (name in deterministic) {
    a <- file.path(evidence, name); b <- file.path(rerun_dir, name)
    same <- file.exists(b) && file.size(a) == file.size(b) && identical(read_bytes(a), read_bytes(b))
    detail <- if (same) sprintf("%d bytes", file.size(a)) else if (!file.exists(b)) "missing from the rerun" else first_diff(a, b)
    note(same, sprintf("%s: rerun byte-identical to recorded evidence (%s)", name, detail))
  }
}

# 2b. Fixture registration and environment.
fx <- read_ev("fixture.csv")
note(setequal(fx$fixture, c("semantic", "fold757_static")), "fixture.csv: semantic and static fold fixtures registered")
sem <- fx[fx$fixture == "semantic", ]
note(nrow(sem) == 1L && sem$n_instruments == 14 && sem$n_sessions == 30 && grepl("missing_bars=1", sem$counts) && grepl("chunk_rows 7", sem$formula),
     sprintf("fixture.csv: semantic fixture is the provider spike's with one missing bar and the 7-row chunk (%s)", sem$counts))
note(grepl("spike_fixture\\(FIXTURES\\$envelope757\\)", fx$formula[fx$fixture == "fold757_static"]) && all(grepl("fold_wall_s<=60", fx$envelope)),
     "fixture.csv: fold fixture cites the writer runner's spike_fixture(FIXTURES$envelope757); the 60 s envelope is registered")
env <- read_ev("environment.csv")
collapse_versions <- as.character(env$collapse)

# 2c. Fold scenarios: attestation, equality, sequence, chunk sizes, failures, reopen.
cases <- read_ev("cases.csv")
scenarios <- c("S1_direct", "S1_direct_chunk4096", "S2_interrupt_resume", "S3_exception_rollback", "S4_nonmember_increase_rollback",
               "S5_resume_then_exception", "S6_exit_before_terminal_direct", "S7_exit_before_terminal_resume")
note(setequal(cases$scenario, scenarios) && all(table(cases$scenario) == 2L) && all(table(cases$selected_arm) == length(scenarios)), "cases.csv: eight scenarios, both arms each")
note(all(cases$chunk_rows[cases$scenario != "S1_direct_chunk4096"] == 7L) && all(cases$chunk_rows[cases$scenario == "S1_direct_chunk4096"] == 4096L),
     "cases.csv: every scenario ran on 7-row chunks, S1 additionally on 4,096-row chunks")
cur <- cases[cases$selected_arm == "current", ]; blk <- cases[cases$selected_arm == "block", ]
finished <- function(x) x$final_status %in% c("DONE", "INCOMPLETE")
note(all_true(cur$observed_mode_run == "columnar") && all(cur$block_calls == 0L) && all(cur$scalar_calls > 0L) &&
     all(cur$scalar_calls[finished(cur)] == cur$diagnostic_rows[finished(cur)]),
     "cases.csv: current arm stamped columnar on every run, no block construction, one scalar construction per persisted row on finished runs")
note(all_true(blk$observed_mode_run == "block") && all(blk$scalar_calls == 0L) && all(blk$block_calls > 0L) &&
     all(blk$block_calls[finished(blk)] == blk$pulses_with_diagnostics[finished(blk)]),
     "cases.csv: block arm stamped block on every run, no scalar construction, one block per pulse with diagnostics on finished runs")
reopened <- !is.na(cases$observed_provider_reopen_current)
note(all_true(cases$observed_provider_run == "prepared") && all_true(cases$observed_provider_reopen_current[reopened] == "prepared") &&
     all_true(cases$observed_provider_reopen_block[reopened] == "prepared"), "cases.csv: the prepared provider was observed on every run and reopen")
note(all_true(cases$seq_continuous), "cases.csv: diagnostic_seq continuous in every scenario and arm")
parity_cols <- c("diagnostics_identical_to_current_arm", "events_identical_to_current_arm", "equity_identical_to_current_arm", "state_identical_to_current_arm",
                 "completion_identical_to_current_arm", "identity_identical_to_current_arm")
note(all_true(unlist(cases[, parity_cols])), "cases.csv: diagnostics, events, equity, strategy state, completion, and run identity (creation time and store locators excluded) identical to the current arm in every scenario")
direct_like <- cases$scenario %in% c("S1_direct", "S1_direct_chunk4096", "S2_interrupt_resume", "S6_exit_before_terminal_direct", "S7_exit_before_terminal_resume")
note(all_true(cases$diagnostics_identical_to_direct[direct_like]) && all_true(!cases$diagnostics_identical_to_direct[!direct_like]),
     "cases.csv: interrupted-and-resumed diagnostics equal the direct run; failed runs differ from it")
chunk_pair <- cases$scenario == "S1_direct_chunk4096"
note(all_true(cases$diagnostics_identical_across_chunk[chunk_pair]) && all(is.na(cases$diagnostics_identical_across_chunk[!chunk_pair])),
     "cases.csv: S1 diagnostics identical between 7-row and 4,096-row chunks in both arms")
note(true_where_present(cases$session_reader_matches_store) && true_where_present(cases$reopen_same_arm_matches_session), "cases.csv: public reader and same-arm reopen match the stored rows")
cross <- c("availability_reopen_arms_identical", "explain_reopen_arms_identical", "availability_identical_to_current_arm", "explain_identical_to_current_arm")
note(all(vapply(cross, function(cn) true_where_present(cases[[cn]]), logical(1))) &&
     all(reopened == (cases$scenario %in% c("S1_direct", "S1_direct_chunk4096", "S2_interrupt_resume", "S6_exit_before_terminal_direct", "S7_exit_before_terminal_resume"))),
     "cases.csv: availability views and explanations identical whichever arm serves the reopen, on every reopened run")
st <- function(s) cases[cases$scenario == s, ]
note(all(st("S1_direct")$final_status == "INCOMPLETE") && all(st("S1_direct_chunk4096")$final_status == "INCOMPLETE") &&
     all(st("S2_interrupt_resume")$first_status == "RUNNING") && all(st("S2_interrupt_resume")$final_status == "INCOMPLETE") &&
     all(st("S6_exit_before_terminal_direct")$final_status == "DONE") && all(st("S7_exit_before_terminal_resume")$first_status == "RUNNING") && all(st("S7_exit_before_terminal_resume")$final_status == "DONE"),
     "cases.csv: terminal stop yields INCOMPLETE, exiting before it yields DONE, interruption yields RUNNING then the same terminal status")
note(all(st("S3_exception_rollback")$final_status == "FAILED") && all(st("S3_exception_rollback")$error_rows == 1L) && all(st("S3_exception_rollback")$diagnostic_rows == 1L) &&
     all(grepl("injected fold failure", st("S3_exception_rollback")$first_error)) &&
     all(st("S4_nonmember_increase_rollback")$final_status == "FAILED") && all(st("S4_nonmember_increase_rollback")$diagnostic_rows == 1L) &&
     all(grepl("ledgr_nonmember_exposure_increase", st("S4_nonmember_increase_rollback")$first_error)) &&
     all(st("S5_resume_then_exception")$first_status == "RUNNING") && all(st("S5_resume_then_exception")$final_status == "FAILED") && all(st("S5_resume_then_exception")$error_rows == 1L),
     "cases.csv: injected and classed failures roll back to one error row written after the rollback, in both arms")
s2 <- st("S2_interrupt_resume")
note(all(grepl("ledgr_run_terminal_evidence_invalid", s2$reopen_error_current)) && identical(s2$reopen_error_current, s2$reopen_error_block) &&
     all(is.na(cases$reopen_error_current[cases$scenario != "S2_interrupt_resume"])),
     "cases.csv: reopening the interrupted-then-resumed INCOMPLETE run fails identically in both arms (package finding carried from the provider spike)")
ref <- read_ev("diagnostics_reference.csv")
note(nrow(ref) == st("S1_direct")$diagnostic_rows[[1L]] && identical(as.integer(ref$diagnostic_seq), seq_len(nrow(ref))),
     sprintf("diagnostics_reference.csv: %d rows, sequence 1..n", nrow(ref)))

# 2d. Semantic coverage by persisted token (Charter v2, claim 3) and completion status.
cov <- read_ev("coverage.csv"); cov$reason_code[is.na(cov$reason_code)] <- ""
has_token <- function(arm, stage, outcome, reasons) any(cov$selected_arm == arm & cov$stage == stage & cov$outcome == outcome & cov$reason_code %in% reasons)
restriction <- c("trading_halted", "quotation_only", "status_unknown", "status_unknown_or_conflicting", "lifetime_inactive")
required <- list(
  list(stage = "decision", outcome = "recorded", reasons = "decision_recorded"),
  list(stage = "decision", outcome = "recorded", reasons = restriction),
  list(stage = "execution", outcome = "no_fill", reasons = "execution_bar_missing"),
  list(stage = "execution", outcome = "no_fill", reasons = "final_pulse_no_execution"),
  list(stage = "execution", outcome = "filled", reasons = ""),
  list(stage = "reconciliation", outcome = "reconciled", reasons = "affordability_reconciled")
)
for (arm in c("current", "block")) {
  ok <- all(vapply(required, function(r) has_token(arm, r$stage, r$outcome, r$reasons), logical(1))) &&
    (has_token(arm, "risk", "passed", "stale_mark_pass_through") || has_token(arm, "risk", "reduced", "stale_mark_reduction")) &&
    any(cov$selected_arm == arm & cov$outcome == "error" & cov$reason_code == "fold_exception")
  note(ok, sprintf("coverage.csv (%s): decision_recorded, a restriction reason, a stale-mark risk row, execution_bar_missing and final_pulse_no_execution no-fills, a filled row with an empty reason, affordability_reconciled, and the fold_exception error row all persisted", arm))
}
cov_cur <- cov[cov$selected_arm == "current", setdiff(names(cov), "selected_arm")]; cov_blk <- cov[cov$selected_arm == "block", setdiff(names(cov), "selected_arm")]
rownames(cov_cur) <- NULL; rownames(cov_blk) <- NULL
note(identical(cov_cur, cov_blk), "coverage.csv: the persisted token census is identical between arms in every scenario")
note(all(c("DONE", "INCOMPLETE", "FAILED") %in% cur$final_status) && all(c("DONE", "INCOMPLETE", "FAILED") %in% blk$final_status), "cases.csv: runs.status DONE, INCOMPLETE, and FAILED each reached in both arms")
halted_no_fill <- has_token("block", "execution", "no_fill", "trading_halted")
cat(sprintf("[INFO] coverage.csv: execution no_fill with trading_halted %s on the semantic fixture (Charter Review v2 L1: the regression net asserts it)\n", if (halted_no_fill) "present" else "absent"))

# 2e. collapse::setv() trace (Charter v2, claim 10), semantic scenarios only.
sv <- read_ev("setv_trace.csv")
blk_sv <- sv[sv$selected_arm == "block", ]; cur_sv <- sv[sv$selected_arm == "current", ]
note(!any(blk_sv$origin == "block_path" & blk_sv$storage_type %in% c("character", "list")) && sum(blk_sv$calls[blk_sv$origin == "block_path"]) > 0L &&
     !any(blk_sv$origin == "columnar_scalar_put"),
     sprintf("setv_trace.csv: block-path setv() targets are only %s; no character or list target; no scalar put in the block arm",
             paste(sort(unique(blk_sv$storage_type[blk_sv$origin == "block_path"])), collapse = "/")))
bound_ok <- TRUE
for (s in scenarios) {
  b <- sum(blk_sv$calls[blk_sv$scenario == s & blk_sv$origin == "block_path"])
  bc <- blk$block_calls[blk$scenario == s]; rows_built <- cur$scalar_calls[cur$scenario == s]; chunk <- blk$chunk_rows[blk$scenario == s]
  bound <- SETV_COLUMNS * (bc + ceiling(rows_built / chunk))
  if (!(b > 0L && b <= bound)) bound_ok <- FALSE
}
note(bound_ok, "setv_trace.csv: block-path setv() calls per scenario stay within 13 x (blocks + chunk splits), far below one call per row per column")
put_ok <- all(vapply(scenarios, function(s) sum(cur_sv$calls[cur_sv$scenario == s & cur_sv$origin == "columnar_scalar_put"]) == SETV_COLUMNS * cur$scalar_calls[cur$scenario == s], logical(1)))
note(put_ok && !any(cur_sv$origin == "block_path"), "setv_trace.csv: current arm made exactly 13 scalar setv() calls per constructed row and none from the block path")
other <- sv[sv$origin == "other_package", ]
cat(sprintf("[INFO] setv_trace.csv: unchanged package code made setv() calls with target types %s (recorded separately; not arm-deciding)\n",
            if (nrow(other)) paste(sort(unique(other$storage_type)), collapse = "/") else "none"))

# 2f. Regression net.
rt <- read_ev("regression_tests.csv")
note(setequal(rt$arm, c("current", "block")) && identical(sort(rt$test[rt$arm == "current"]), sort(rt$test[rt$arm == "block"])) && length(unique(rt$file)) >= 10L && !any(rt$test %in% optional_tests),
     "regression_tests.csv: the same test set ran under both arms, with the optional parallel-worker test kept out of the deterministic file")
note(all(rt$failed == 0L) && all(!rt$error) && all(!rt$skipped), sprintf("regression_tests.csv: no failure, error, or skip in %d tests per arm", sum(rt$arm == "block")))
halted_tests <- c("a blocked exit executes only after a new zero target", "execution diagnostics retain ordered gate reasons")
note(all(halted_tests %in% rt$test[rt$arm == "block"]) && all(rt$failed[rt$arm == "block" & rt$test %in% halted_tests] == 0L),
     "regression_tests.csv: the opening-halt no-fill tests (trading_halted, ordered with execution_bar_missing) passed under the block arm (Charter Review v2 L1)")
if (file.exists(file.path(evidence, "regression_optional.csv"))) {
  ro <- read_ev("regression_optional.csv")
  note(setequal(ro$arm, c("current", "block")) && all(table(ro$arm) == 1L) && all(ro$test %in% optional_tests) && all(ro$ran == !ro$skipped) && all(!ro$ran | (ro$failed == 0L & !ro$error)),
       sprintf("regression_optional.csv: the optional parallel-worker test recorded honestly per arm (%s)",
               paste(sprintf("%s: %s", ro$arm, ifelse(ro$ran, sprintf("ran, %d passed", ro$passed), "skipped")), collapse = "; ")))
}
if (!all(present)) finish()
ra <- read_ev("regression_attestation.csv")
note(ra$observed_modes[ra$arm == "block"] == "block" && ra$scalar_calls[ra$arm == "block"] == 0L && ra$block_calls[ra$arm == "block"] > 0L &&
     ra$observed_modes[ra$arm == "current"] == "columnar" && ra$block_calls[ra$arm == "current"] == 0L && ra$scalar_calls[ra$arm == "current"] > 0L &&
     all(ra$observed_providers == "prepared"),
     sprintf("regression_attestation.csv: every fold in the net was stamped block (%d blocks, no scalar construction) or columnar (%d scalar rows, no block); prepared provider throughout",
             ra$block_calls[ra$arm == "block"], ra$scalar_calls[ra$arm == "current"]))

# 2g. 757-pulse folds.
fd <- read_ev("fold_757.csv")
fd$killed[is.na(fd$killed)] <- ""
note(identical(fd$repetition[fd$arm == "current"], c("warmup", "run1", "run2", "run3")) && identical(fd$repetition[fd$arm == "block"], c("warmup", "run1", "run2", "run3", "profiled")) &&
     identical(fd$measured, fd$repetition %in% c("run1", "run2", "run3")) && sum(fd$profiled) == 1L && fd$arm[fd$profiled] == "block",
     "fold_757.csv: each arm warm-up plus three measured runs; one profiled block run")
note(all_true(fd$observed_mode[fd$arm == "current"] == "columnar") && all(fd$block_calls[fd$arm == "current"] == 0L) && all(fd$scalar_calls[fd$arm == "current"] == ROWS_757) &&
     all_true(fd$observed_mode[fd$arm == "block"] == "block") && all(fd$scalar_calls[fd$arm == "block"] == 0L) && all(fd$block_calls[fd$arm == "block"] == 757L) &&
     all_true(fd$observed_provider == "prepared"),
     "fold_757.csv: every current run stamped columnar with 383,042 scalar constructions; every block run stamped block with 757 blocks and no scalar construction; prepared provider throughout")
note(all(fd$killed == "") && all(fd$status == "DONE") && all(fd$store_diagnostic_rows == ROWS_757) && all(fd$decision_rows == 757L * 505L) && all(fd$pulses_with_diagnostics == 757L) &&
     all(is.finite(fd$wall_seconds) & is.finite(fd$t_loop_seconds) & fd$t_loop_seconds <= fd$wall_seconds),
     "fold_757.csv: every run finished DONE within the external stop, with the registered row counts and finite timings")
mc <- fd[fd$arm == "current" & fd$measured, ]; mb <- fd[fd$arm == "block" & fd$measured, ]
current_median <- stats::median(mc$wall_seconds); block_median <- stats::median(mb$wall_seconds); current_spread <- diff(range(mc$wall_seconds))
wall_ok <- nrow(mb) == 3L && nrow(mc) == 3L && block_median <= 60
spread_ok <- nrow(mb) == 3L && nrow(mc) == 3L && (current_median - block_median) > current_spread
peak_ok <- nrow(mb) == 3L && all(mb$peak_ws_mib <= 1024)
note(wall_ok, sprintf("envelope: block median 757-pulse wall %.2f s (runs %s) within 60 s", block_median, paste(round(mb$wall_seconds, 2), collapse = "/")))
note(spread_ok, sprintf("envelope: block median below the current median %.2f s (runs %s) by %.2f s, more than the current run-to-run spread diff(range()) = %.2f s",
     current_median, paste(round(mc$wall_seconds, 2), collapse = "/"), current_median - block_median, current_spread))
note(peak_ok, sprintf("envelope: every measured block peak working set (%s MiB) within 1,024 MiB (current %s MiB)", paste(round(mb$peak_ws_mib, 1), collapse = "/"), paste(round(mc$peak_ws_mib, 1), collapse = "/")))
cat(sprintf("[INFO] fold_757.csv: sealing the registered store took %.0f s (cold clock, outside the comparison)\n", fd$seal_seconds[[1L]]))
collapse_versions <- c(collapse_versions, as.character(fd$collapse[!is.na(fd$collapse)]))
note(length(unique(collapse_versions)) == 1L, sprintf("environment: one collapse version across every process (%s)", paste(unique(collapse_versions), collapse = ", ")))

# 2h. Persisted 757-pulse outputs and identity, one non-measured pair with a shared run ID (Charter v2, claim 6).
fp <- read_ev("fold_757_parity.csv"); fp$excluded[is.na(fp$excluded)] <- ""
note(setequal(fp$table, c("runs", "run_completion", "run_diagnostics", "ledger_events", "equity_curve", "strategy_state")) &&
     all(fp$status_current == "DONE") && all(fp$status_block == "DONE") && all(fp$mode_current == "columnar") && all(fp$mode_block == "block") &&
     all(fp$scalar_calls_block == 0L) && all(fp$block_calls_block == 757L) && all(fp$scalar_calls_current == ROWS_757) && all(fp$block_calls_current == 0L) &&
     all(fp$provider_current == "prepared") && all(fp$provider_block == "prepared"),
     "fold_757_parity.csv: both arms of the parity pair finished DONE, each attested, six persisted tables compared")
note(all_true(fp$identical) && all(fp$rows_current == fp$rows_block) && all(fp$only_in_current == 0L) && all(fp$only_in_block == 0L) &&
     fp$rows_current[fp$table == "run_diagnostics"] == ROWS_757 && fp$rows_current[fp$table == "equity_curve"] == 757L &&
     fp$rows_current[fp$table == "runs"] == 1L && fp$rows_current[fp$table == "run_completion"] == 1L &&
     fp$excluded[fp$table == "runs"] == "created_at_utc|config_json.db_path|config_json.data.snapshot_db_path" && all(fp$excluded[fp$table != "runs"] == ""),
     sprintf("fold_757_parity.csv: persisted diagnostics (%d rows), events, equity, state, completion, and the runs row (run_id at both levels and archived_at_utc compared; exactly three exclusions) identical between arms",
             fp$rows_current[fp$table == "run_diagnostics"]))

# 2i. Lane shares of the profiled block run.
l <- read_ev("lanes_757.csv")
in_loop <- !l$lane %in% c("outside_loop", "provider_build")
note(all(c("provider_build", "provider_membership", "provider_status_lifetime", "provider_other", "valuation", "diag_construct", "diag_append_retain", "final_bind", "duckdb_diag_append", "residual_fold", "outside_loop") %in% l$lane) &&
     all(is.finite(l$share_in_loop) & l$share_in_loop >= 0 & l$share_in_loop <= 1) && isTRUE(all.equal(sum(l$share_in_loop[in_loop]), 1, tolerance = 1e-9)) &&
     isTRUE(all.equal(l$share_in_loop[in_loop], l$samples[in_loop] / sum(l$samples[in_loop]), tolerance = 1e-9)),
     "lanes_757.csv: every lane present, shares consistent with samples and summing to one over in-loop lanes")
groups <- list(provider = c("provider_membership", "provider_status_lifetime", "provider_other"), diagnostics = c("diag_construct", "diag_append_retain", "final_bind", "duckdb_diag_append"),
               valuation = "valuation", residual_fold = "residual_fold")
g <- sort(vapply(groups, function(x) sum(l$share_in_loop[l$lane %in% x]), numeric(1)), decreasing = TRUE)
note(g[[1L]] > g[[2L]], sprintf("lanes_757.csv: one largest grouped lane (%s %.1f%%, then %s %.1f%%; diagnostics %.1f%% of captured in-loop samples)",
     names(g)[[1L]], 100 * g[[1L]], names(g)[[2L]], 100 * g[[2L]], 100 * g[["diagnostics"]]))

# 2j. Decision (Charter v2).
claims_hold <- length(failures) == 0L
components_met <- isTRUE(wall_ok) && isTRUE(spread_ok) && isTRUE(peak_ok)
if (claims_hold && !components_met) {
  destination <- if (names(g)[[1L]] == "diagnostics") "recharter the block interface (diagnostics still lead)" else sprintf("route the new leading lane (%s)", names(g)[[1L]])
  note(FALSE, sprintf("decision: kill/recharter condition fires (claims hold, envelope breached); destination: %s", destination))
} else {
  note(claims_hold && components_met, "decision: GREEN (every claim holds, the mechanism was observed, median wall and relative spread and every measured peak inside the envelope)")
}

# 3. Package-scope guard over every change type.
# Planning edits the maintainer holds in the working tree beside this spike
# (none is spike work), plus the reviewed provider seam from the previous spike.
pre_existing <- c("inst/design/README.md", "inst/design/horizon.md", "inst/design/ledgr_roadmap.md", "inst/design/rfc/README.md", "inst/design/spike_protocol.md",
                  "inst/design/manual/README.md", "inst/design/manual/README.qmd", "inst/design/manual/benchmark_methodology.md", "inst/design/manual/benchmark_methodology.qmd",
                  "tests/testthat/test-documentation-contracts.R", "R/availability-provider.R")
pre_existing_untracked <- c("R/availability-provider-prepared.R", "inst/design/planning_context_history.md", "inst/design/manual/optimization_coding_style.md",
                            "inst/design/manual/optimization_coding_style.qmd")
seam_modified <- c("R/availability-diagnostic-writer.R", "R/fold-engine.R")
package_scope <- function(paths) paths[grepl("^(R/|src/|tests/|man/|inst/design/|NAMESPACE$|DESCRIPTION$)", paths)]
tracked <- git_lines("diff", "--name-status", "--no-renames", "HEAD")
tracked_status <- sub("\t.*$", "", tracked); tracked_path <- sub("^[^\t]*\t", "", tracked)
untracked <- git_lines("ls-files", "--others", "--exclude-standard")
in_scope <- tracked_path %in% package_scope(tracked_path)
allowed_tracked <- tracked_path %in% c(pre_existing, seam_modified) & tracked_status == "M"
unexpected_tracked <- paste(tracked_status, tracked_path)[in_scope & !allowed_tracked]
unexpected_untracked <- setdiff(package_scope(untracked), c(pre_existing_untracked, untracked[startsWith(untracked, "inst/design/rfc/rfc_availability_hot_path_representation_")]))
note(length(unexpected_tracked) == 0L, sprintf("scope: tracked package changes (any status) are only modifications of the two seam files, the reviewed provider seam, and pre-existing planning edits%s",
     if (length(unexpected_tracked)) paste0(" (unexpected: ", paste(unexpected_tracked, collapse = ", "), ")") else ""))
note(length(unexpected_untracked) == 0L, sprintf("scope: untracked package files are only the prepared provider, this cycle's RFC artifacts, and pre-existing untracked design pages%s",
     if (length(unexpected_untracked)) paste0(" (unexpected: ", paste(unexpected_untracked, collapse = ", "), ")") else ""))
note(all(seam_modified %in% tracked_path[tracked_status == "M"]), "scope: seam present (diagnostic writer and fold engine modified)")
stat <- git_lines("diff", "--numstat", "--no-renames", "HEAD", "--", seam_modified)
nums <- do.call(rbind, lapply(strsplit(stat, "\t"), function(x) as.integer(x[1:2])))
added <- sum(nums[, 1L]); removed <- sum(nums[, 2L])
note(nrow(nums) == 2L && !anyNA(nums) && added <= 320L && removed <= 60L, sprintf("scope: seam diff is small (+%d/-%d lines over the two files)", added, removed))
harness_lines <- sum(vapply(c(runner, script_path), function(f) length(readLines(f, warn = FALSE)), integer(1))) + added
note(harness_lines <= 1500L, sprintf("scope: harness and seam within budget (%d R lines: runner, checker, seam additions)", harness_lines))
probe_files <- c("probe.R", "probe_findings.md", "probe_measurements.csv")
probe_status <- git_lines("status", "--porcelain", "--", file.path("dev/spikes/availability-diagnostic-block-write", probe_files))
note(all(file.exists(file.path(spike_dir, probe_files))), "scope: the three prerequisite probe files are present beside the harness")

finish()
