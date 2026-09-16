# Checker for the availability provider-preparation spike (Charter v2).
#
# Three actions, per spike_protocol.md section 6:
#   1. rerun the deterministic phases (parity, semantic, tests) into a scratch
#      evidence directory;
#   2. diff: the deterministic CSVs (fixture.csv, cutoff_parity.csv, cases.csv,
#      diagnostics_reference.csv, regression_tests.csv) must be byte-identical
#      to the rerun; the measurement CSVs (provider_pass.csv, fold_757.csv,
#      lanes_757.csv) are validated against the Charter's rules: arm
#      attestation, repetition shape, the three envelope components, the
#      current-arm stop, lane shares, and the GREEN / recharter reading;
#   3. guard package scope over every Git change type: the seam is
#      R/availability-provider.R modified plus R/availability-provider-prepared.R
#      added, beside the pre-existing planning edits and this cycle's RFC files.
# Arm attestation is not self-asserted: every evidence row carries the arm
# observed on the provider object ledgr actually built, and a prepared row
# whose observed arm is not "prepared" fails before any equality can pass.
#
# Usage, from the repository root:
#   Rscript dev/spikes/availability-provider-preparation/spike_checker.R \
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
read_ev <- function(name, dir = evidence) utils::read.csv(file.path(dir, name), stringsAsFactors = FALSE, check.names = FALSE)
read_bytes <- function(path) readBin(path, what = "raw", n = file.size(path))
first_diff <- function(a, b) {
  la <- readLines(a, warn = FALSE); lb <- readLines(b, warn = FALSE)
  n <- max(length(la), length(lb)); length(la) <- n; length(lb) <- n
  i <- which(is.na(la) | is.na(lb) | la != lb)
  if (length(i)) sprintf("first differing line %d", i[[1L]]) else "differs only in line endings or trailing bytes"
}
git_lines <- function(...) {
  old_home <- Sys.getenv("HOME")
  on.exit(Sys.setenv(HOME = old_home), add = TRUE)
  profile_home <- Sys.getenv("USERPROFILE")
  if (nzchar(profile_home)) Sys.setenv(HOME = profile_home)
  out <- suppressWarnings(system2("git", c("-C", repo_root, ...), stdout = TRUE, stderr = FALSE))
  status <- attr(out, "status")
  if (!is.null(status) && status != 0L) { note(FALSE, sprintf("git %s failed with status %d", paste(c(...), collapse = " "), status)); finish() }
  as.character(out)
}
all_true <- function(x) length(x) > 0L && !anyNA(x) && all(x)
true_where_present <- function(x) any(!is.na(x)) && all(x[!is.na(x)])

deterministic <- c("fixture.csv", "cutoff_parity.csv", "cases.csv", "diagnostics_reference.csv", "regression_tests.csv")
measurement <- c("environment.csv", "regression_optional.csv", "provider_pass.csv", "fold_757.csv", "lanes_757.csv", "fold_757_parity.csv")
optional_tests <- "parallel availability sweeps return the same compact terminal evidence"
present <- file.exists(file.path(evidence, c(deterministic, measurement)))
note(all(present), sprintf("evidence: all eleven CSVs present in %s%s", evidence,
     if (all(present)) "" else paste0(" (missing: ", paste(c(deterministic, measurement)[!present], collapse = ", "), ")")))
if (!all(file.exists(file.path(evidence, deterministic)))) finish()

# 1. Rerun the deterministic phases into scratch.
if (!skip_rerun && identical(rerun_dir, scratch)) {
  dir.create(scratch, recursive = TRUE)
  rscript <- file.path(R.home("bin"), c("Rscript.exe", "x64/Rscript.exe", "Rscript")); rscript <- rscript[file.exists(rscript)][[1L]]
  for (phase in c("parity", "semantic", "tests")) {
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
note(setequal(fx$fixture, c("semantic", "intervals", "fold757_static", "eventful757")), "fixture.csv: semantic, intervals, static fold, and eventful fixtures registered")
ev <- fx[fx$fixture == "eventful757", ]
counts <- function(x) { kv <- strsplit(strsplit(x, " ")[[1L]], "="); stats::setNames(as.numeric(vapply(kv, `[[`, "", 2L)), vapply(kv, `[[`, "", 1L)) }
ec <- counts(ev$counts)
note(nrow(ev) == 1L && ev$n_instruments == 563 && ev$n_sessions == 757 && all(c("rotated_members", "late_headers", "halts", "late_status", "conflict_facts",
     "supersession_pairs", "late_lifetime", "terminal_events") %in% names(ec)) && all(ec[c("rotated_members", "late_headers", "halts", "late_status", "conflict_facts",
     "supersession_pairs", "late_lifetime", "terminal_events")] > 0) && grepl("rotate", ev$formula),
     sprintf("fixture.csv: eventful formula and counts recorded (%s)", ev$counts))
note(grepl("spike_fixture\\(FIXTURES\\$envelope757\\)", fx$formula[fx$fixture == "fold757_static"]), "fixture.csv: fold control cites the writer runner's spike_fixture(FIXTURES$envelope757)")
env <- read_ev("environment.csv")
collapse_versions <- as.character(env$collapse)

# 2c. Provider-only cutoff parity.
cp <- read_ev("cutoff_parity.csv")
note(all_true(cp$observed_current == "current") && all_true(cp$observed_prepared == "prepared"), "cutoff_parity.csv: observed arms are current and prepared on every query")
note(all_true(cp$identical_between_arms), sprintf("cutoff_parity.csv: full views identical between arms on all %d queries", nrow(cp)))
note(true_where_present(cp$prepared_consistent_on_revisit), "cutoff_parity.csv: prepared answers identical when cutoffs are revisited out of order")
note(true_where_present(cp$resolve_matches_prepared_members), "cutoff_parity.csv: ledgr_facts_resolve() members equal the prepared members at every membership cutoff")
note(setequal(cp$fixture, c("semantic", "intervals")) && setequal(cp$config, c("membership", "fixed")) &&
     setequal(cp$kind, c("decision_zero", "decision_held", "execution", "facts")), "cutoff_parity.csv: both fixtures, both universe configs, and all four view kinds present")

# 2d. Fold scenarios.
cases <- read_ev("cases.csv")
scenarios <- c("S1_direct", "S2_interrupt_resume", "S3_exception_rollback", "S4_nonmember_increase_rollback", "S5_resume_then_exception",
               "S6_exit_before_terminal_direct", "S7_exit_before_terminal_resume")
note(setequal(cases$scenario, scenarios) && all(table(cases$scenario) == 2L) && all(table(cases$selected_arm) == length(scenarios)), "cases.csv: seven scenarios, both arms each")
note(all_true(cases$observed_arm_run == cases$selected_arm), "cases.csv: the observed arm of every fold run equals its selected arm")
reopened <- !is.na(cases$observed_arm_reopen_current)
note(all_true(cases$observed_arm_reopen_current[reopened] == "current") && all_true(cases$observed_arm_reopen_prepared[reopened] == "prepared"),
     "cases.csv: reopen under each arm observed that arm")
note(all_true(cases$seq_continuous), "cases.csv: diagnostic_seq continuous in every scenario and arm")
parity_cols <- c("diagnostics_identical_to_current_arm", "events_identical_to_current_arm", "equity_identical_to_current_arm", "state_identical_to_current_arm",
                 "completion_identical_to_current_arm", "identity_identical_to_current_arm")
note(all_true(unlist(cases[, parity_cols])), "cases.csv: diagnostics, events, equity, strategy state, completion, and run identity (runs row minus run_id, creation time, and config store locators) identical to the current arm in every scenario")
direct_like <- cases$scenario %in% c("S1_direct", "S2_interrupt_resume", "S6_exit_before_terminal_direct", "S7_exit_before_terminal_resume")
note(all_true(cases$diagnostics_identical_to_direct[direct_like]) && all_true(!cases$diagnostics_identical_to_direct[!direct_like]),
     "cases.csv: interrupted-and-resumed diagnostics equal the direct run; failed runs differ from it")
note(true_where_present(cases$session_reader_matches_store) && true_where_present(cases$reopen_same_arm_matches_session), "cases.csv: public reader and same-arm reopen match the stored rows")
cross <- c("availability_reopen_arms_identical", "explain_reopen_arms_identical", "availability_identical_to_current_arm", "explain_identical_to_current_arm")
note(all(vapply(cross, function(cn) true_where_present(cases[[cn]]), logical(1))) && all(reopened == (cases$scenario %in% c("S1_direct", "S6_exit_before_terminal_direct", "S7_exit_before_terminal_resume", "S2_interrupt_resume"))),
     "cases.csv: availability views and explanations identical whichever arm serves the reopen, on every reopened run")
st <- function(s) cases[cases$scenario == s, ]
note(all(st("S1_direct")$final_status == "INCOMPLETE") && all(st("S2_interrupt_resume")$first_status == "RUNNING") && all(st("S2_interrupt_resume")$final_status == "INCOMPLETE") &&
     all(st("S6_exit_before_terminal_direct")$final_status == "DONE") && all(st("S7_exit_before_terminal_resume")$first_status == "RUNNING") && all(st("S7_exit_before_terminal_resume")$final_status == "DONE"),
     "cases.csv: terminal stop yields INCOMPLETE, exiting before it yields DONE, interruption yields RUNNING then the same terminal status")
note(all(st("S3_exception_rollback")$final_status == "FAILED") && all(st("S3_exception_rollback")$error_rows == 1L) && all(st("S3_exception_rollback")$diagnostic_rows == 1L) &&
     all(grepl("injected fold failure", st("S3_exception_rollback")$first_error)) &&
     all(st("S4_nonmember_increase_rollback")$final_status == "FAILED") && all(st("S4_nonmember_increase_rollback")$diagnostic_rows == 1L) &&
     all(grepl("ledgr_nonmember_exposure_increase", st("S4_nonmember_increase_rollback")$first_error)) &&
     all(st("S5_resume_then_exception")$first_status == "RUNNING") && all(st("S5_resume_then_exception")$final_status == "FAILED") && all(st("S5_resume_then_exception")$error_rows == 1L),
     "cases.csv: injected and classed provider-semantic failures roll back to one error diagnostic in both arms")
s2 <- st("S2_interrupt_resume")
note(all(grepl("ledgr_run_terminal_evidence_invalid", s2$reopen_error_current)) && identical(s2$reopen_error_current, s2$reopen_error_prepared) && all(is.na(cases$reopen_error_current[cases$scenario != "S2_interrupt_resume"])),
     "cases.csv: reopening the interrupted-then-resumed INCOMPLETE run fails identically in both arms (package finding, not an arm difference)")
ref <- read_ev("diagnostics_reference.csv")
needed <- c("trading_halted", "status_unknown_or_conflicting", "status_unknown", "quotation_only", "lifetime_inactive", "membership_changed_before_execution", "terminal_settlement_unsupported")
note(nrow(ref) == st("S1_direct")$diagnostic_rows[[1L]] && identical(as.integer(ref$diagnostic_seq), seq_len(nrow(ref))) && all(needed %in% ref$reason_code),
     sprintf("diagnostics_reference.csv: %d rows, sequence 1..n, every evidence category's reason code present", nrow(ref)))

# 2e. Regression net.
rt <- read_ev("regression_tests.csv")
note(setequal(rt$arm, c("current", "prepared")) && all_true(rt$observed_arm == rt$arm), "regression_tests.csv: both arms, each observed as selected")
note(identical(sort(rt$test[rt$arm == "current"]), sort(rt$test[rt$arm == "prepared"])) && length(unique(rt$file)) >= 10L && !any(rt$test %in% optional_tests),
     "regression_tests.csv: the same test set ran under both arms, with the optional parallel-worker test kept out of the deterministic file")
note(all(rt$failed == 0L) && all(!rt$error) && all(!rt$skipped), sprintf("regression_tests.csv: no failure, error, or skip in %d tests per arm", sum(rt$arm == "prepared")))
if (file.exists(file.path(evidence, "regression_optional.csv"))) {
  ro <- read_ev("regression_optional.csv")
  note(setequal(ro$arm, c("current", "prepared")) && all(table(ro$arm) == 1L) && all_true(ro$observed_arm == ro$arm) && all(ro$test %in% optional_tests) &&
       all(ro$ran == !ro$skipped) && all(!ro$ran | (ro$failed == 0L & !ro$error)),
       sprintf("regression_optional.csv: the optional parallel-worker test recorded honestly per arm (%s)",
               paste(sprintf("%s: %s", ro$arm, ifelse(ro$ran, sprintf("ran, %d passed", ro$passed), "skipped")), collapse = "; ")))
}

if (!all(present)) finish()

# 2f. Provider-only passes.
pp <- read_ev("provider_pass.csv")
note(all(table(pp$facts, pp$arm) == 1L) && setequal(pp$facts, c("static", "eventful")), "provider_pass.csv: static and eventful facts, one pass per arm")
note(all_true(pp$observed_arm == pp$arm), "provider_pass.csv: each pass observed its selected arm")
note(all(pp$decision_views == 757L) && all(pp$execution_calls == 40L) && all(pp$decision_views_identical == 757L) && all(pp$execution_views_identical == 40L),
     "provider_pass.csv: 757 decision views and 40 execution views identical between arms on both fact sets")
note(all(pp$axis_width_min == 505L) && all(pp$axis_width_max == 505L), "provider_pass.csv: constant 505-wide axis on every pass")
ep <- pp[pp$facts == "eventful" & pp$arm == "prepared", ]
eventful_ok <- nrow(ep) == 1L && is.finite(ep$pass_seconds) && ep$pass_seconds <= 82
note(eventful_ok, sprintf("envelope: eventful provider-only pass %.2f s (build %.2f, decisions %.2f, executions %.2f) within 82 s",
     ep$pass_seconds, ep$build_seconds, ep$decision_seconds, ep$execution_seconds))
cs <- pp[pp$facts == "static" & pp$arm == "current", ]
note(nrow(cs) == 1L && is.finite(cs$decision_seconds) && cs$decision_seconds > 0, sprintf("provider_pass.csv: current static reference rerun once (%.2f s for 757 decision views; registered 396.02 s)", cs$decision_seconds))
collapse_versions <- c(collapse_versions, as.character(pp$collapse))

# 2g. 757-pulse folds.
fd <- read_ev("fold_757.csv")
fd$killed[is.na(fd$killed)] <- ""
note(sum(fd$arm == "current") == 1L && identical(fd$repetition[fd$arm == "prepared"], c("warmup", "run1", "run2", "run3", "profiled")) &&
     identical(fd$measured[fd$arm == "prepared"], c(FALSE, TRUE, TRUE, TRUE, FALSE)) && sum(fd$profiled) == 1L && fd$arm[fd$profiled] == "prepared",
     "fold_757.csv: current arm once; prepared arm warm-up, three measured runs, one profiled run")
note(all_true(fd$observed_arm == fd$arm), "fold_757.csv: every fold run observed its selected arm")
pr <- fd[fd$arm == "prepared", ]
note(all(pr$killed == "") && all(pr$status == "DONE") && all(pr$decision_rows == 757L * 505L) && all(pr$store_diagnostic_rows == 757L * 505L + 757L) &&
     all(is.finite(pr$wall_seconds) & is.finite(pr$t_loop_seconds) & pr$t_loop_seconds <= pr$wall_seconds),
     "fold_757.csv: every prepared run finished DONE with the registered row counts and finite timings")
cur <- fd[fd$arm == "current", ]
note((cur$killed == "" && cur$status == "DONE" && cur$decision_rows == 757L * 505L) || (cur$killed %in% c("wall", "working_set") && cur$status != "DONE" &&
     ((cur$killed == "wall" && cur$run_elapsed_s >= 1800) || (cur$killed == "working_set" && cur$peak_ws_mib >= 4096))),
     sprintf("fold_757.csv: current arm finished or was stopped by the registered control (killed='%s', %.1f s, %.1f MiB, %s)", cur$killed, cur$run_elapsed_s, cur$peak_ws_mib, cur$status))
m <- pr[pr$measured, ]
median_wall <- stats::median(m$wall_seconds)
wall_ok <- nrow(m) == 3L && median_wall <= 180
peak_ok <- nrow(m) == 3L && all(m$peak_ws_mib <= 1024)
note(wall_ok, sprintf("envelope: prepared median 757-pulse wall %.2f s (runs %s; spread %.2f) within 180 s", median_wall, paste(round(m$wall_seconds, 2), collapse = "/"), diff(range(m$wall_seconds))))
note(peak_ok, sprintf("envelope: every measured prepared peak working set (%s MiB) within 1,024 MiB", paste(round(m$peak_ws_mib, 1), collapse = "/")))
collapse_versions <- c(collapse_versions, as.character(fd$collapse[!is.na(fd$collapse)]))
note(length(unique(collapse_versions)) == 1L, sprintf("environment: one collapse version across every process (%s)", paste(unique(collapse_versions), collapse = ", ")))

# 2g'. Persisted 757-pulse outputs and identity, one non-measured pair (Charter claim 9).
fp <- read_ev("fold_757_parity.csv")
note(setequal(fp$table, c("runs", "run_completion", "run_diagnostics", "ledger_events", "equity_curve", "strategy_state")) &&
     all(fp$status_current == "DONE") && all(fp$status_prepared == "DONE") && all(fp$observed_arm_current == "current") && all(fp$observed_arm_prepared == "prepared"),
     "fold_757_parity.csv: both arms of the parity pair finished DONE, each observed as selected, six persisted tables compared")
note(all_true(fp$identical) && all(fp$rows_current == fp$rows_prepared) && all(fp$only_in_current == 0L) && all(fp$only_in_prepared == 0L) &&
     fp$rows_current[fp$table == "run_diagnostics"] == 757L * 505L + 757L && fp$rows_current[fp$table == "equity_curve"] == 757L &&
     fp$rows_current[fp$table == "runs"] == 1L && fp$rows_current[fp$table == "run_completion"] == 1L &&
     fp$excluded[fp$table == "runs"] == "run_id|created_at_utc|archived_at_utc|config_json.run_id|config_json.db_path|config_json.data.snapshot_db_path",
     sprintf("fold_757_parity.csv: persisted diagnostics (%d rows), events, equity, state, completion, and the runs identity row identical between arms by set difference",
             fp$rows_current[fp$table == "run_diagnostics"]))

# 2h. Lane shares of the profiled prepared run.
l <- read_ev("lanes_757.csv")
in_loop <- !l$lane %in% c("outside_loop", "provider_build")
note(all(c("provider_build", "provider_membership", "provider_status_lifetime", "provider_other", "valuation", "diag_construct", "diag_append_retain", "final_bind", "duckdb_diag_append", "residual_fold", "outside_loop") %in% l$lane) &&
     all(is.finite(l$share_in_loop) & l$share_in_loop >= 0 & l$share_in_loop <= 1) && isTRUE(all.equal(sum(l$share_in_loop[in_loop]), 1, tolerance = 1e-9)) &&
     isTRUE(all.equal(l$share_in_loop[in_loop], l$samples[in_loop] / sum(l$samples[in_loop]), tolerance = 1e-9)),
     "lanes_757.csv: every lane present, shares consistent with samples and summing to one over in-loop lanes")
groups <- list(provider = c("provider_membership", "provider_status_lifetime", "provider_other"), diagnostics = c("diag_construct", "diag_append_retain", "final_bind", "duckdb_diag_append"),
               valuation = "valuation", residual_fold = "residual_fold")
g <- sort(vapply(groups, function(x) sum(l$share_in_loop[l$lane %in% x]), numeric(1)), decreasing = TRUE)
note(g[[1L]] > g[[2L]], sprintf("lanes_757.csv: one largest grouped lane (%s %.1f%%, then %s %.1f%%; provider build %.1f s outside the loop)",
     names(g)[[1L]], 100 * g[[1L]], names(g)[[2L]], 100 * g[[2L]], l$seconds[l$lane == "provider_build"]))

# 2i. Decision (Charter v2).
claims_hold <- length(failures) == 0L
components_met <- isTRUE(wall_ok) && isTRUE(peak_ok) && isTRUE(eventful_ok)
if (claims_hold && !components_met) {
  destination <- if (names(g)[[1L]] == "provider") "recharter provider preparation (provider still leads)" else sprintf("route the new leading lane (%s)", names(g)[[1L]])
  note(FALSE, sprintf("decision: kill/recharter condition fires (claims hold, envelope breached); destination: %s", destination))
} else {
  note(claims_hold && components_met, "decision: GREEN (every claim holds; median fold wall, every measured peak, and the eventful pass inside the envelope)")
}

# 3. Package-scope guard over every change type.
# Planning edits the maintainer holds in the working tree beside this spike:
# six from before the stage, plus spike_protocol.md (section 10, performance
# clocks) and the benchmark-methodology manual pages edited during the
# evidence-review round. None is spike work.
pre_existing <- c("AGENTS.md", "inst/design/README.md", "inst/design/horizon.md", "inst/design/ledgr_roadmap.md", "inst/design/rfc/README.md",
                  "tests/testthat/test-documentation-contracts.R", "inst/design/spike_protocol.md",
                  "inst/design/manual/benchmark_methodology.md", "inst/design/manual/benchmark_methodology.qmd")
seam_modified <- "R/availability-provider.R"
seam_added <- "R/availability-provider-prepared.R"
package_scope <- function(paths) paths[grepl("^(R/|src/|tests/|man/|inst/design/|NAMESPACE$|DESCRIPTION$)", paths)]
tracked <- git_lines("diff", "--name-status", "--no-renames", "HEAD")
tracked_status <- sub("\t.*$", "", tracked); tracked_path <- sub("^[^\t]*\t", "", tracked)
untracked <- git_lines("ls-files", "--others", "--exclude-standard")
in_scope <- tracked_path %in% package_scope(tracked_path)
allowed_tracked <- tracked_path %in% c(pre_existing, seam_modified) & tracked_status == "M"
unexpected_tracked <- paste(tracked_status, tracked_path)[in_scope & !allowed_tracked]
unexpected_untracked <- setdiff(package_scope(untracked), c(seam_added, untracked[startsWith(untracked, "inst/design/rfc/rfc_availability_hot_path_representation_")]))
note(length(unexpected_tracked) == 0L, sprintf("scope: tracked package changes (any status) are only modifications of the seam and pre-existing planning edits%s",
     if (length(unexpected_tracked)) paste0(" (unexpected: ", paste(unexpected_tracked, collapse = ", "), ")") else ""))
note(length(unexpected_untracked) == 0L, sprintf("scope: untracked package files are only the prepared arm and this cycle's RFC artifacts%s",
     if (length(unexpected_untracked)) paste0(" (unexpected: ", paste(unexpected_untracked, collapse = ", "), ")") else ""))
tracked_seams <- git_lines("ls-files", "--", seam_modified, seam_added)
note(
  all(c(seam_modified, seam_added) %in% tracked_seams) &&
    all(file.exists(file.path(repo_root, c(seam_modified, seam_added)))),
  "scope: reviewed provider seam is present in the committed baseline"
)
stat <- git_lines(
  "diff", "--numstat", "--no-renames", "f0b847d^", "f0b847d", "--",
  seam_modified
)
nums <- if (length(stat)) as.integer(strsplit(stat[[length(stat)]], "\t")[[1L]][1:2]) else c(NA_integer_, NA_integer_)
note(!anyNA(nums) && all(nums <= 40L), sprintf("scope: recorded R/availability-provider.R seam diff was small (+%s/-%s lines)", nums[[1L]], nums[[2L]]))
harness_lines <- sum(vapply(c(runner, script_path, file.path(repo_root, seam_added)), function(f) length(readLines(f, warn = FALSE)), integer(1))) + nums[[1L]]
note(harness_lines <= 1500L, sprintf("scope: harness within budget (%d R lines: runner, checker, prepared arm, seam additions)", harness_lines))

finish()
