# Checker for the availability hot-path representation spike (Charter v2).
#
# Three actions, per spike_protocol.md section 6:
#   1. rerun the semantic phase into a scratch evidence directory;
#   2. diff the recorded evidence: the deterministic CSVs (fixture.csv,
#      cases.csv, diagnostics_40_rows.csv) must be byte-identical to the rerun;
#      the measurement CSVs (measurements_40.csv, envelope_757.csv,
#      lanes_757.csv) vary by host and run, so they are validated against the
#      charter's registered repetition shape, median/spread rule, envelope
#      bounds and completion states, lane shares, and the GREEN decision;
#   3. guard package scope: every tracked change from HEAD (any status; renames
#      appear as delete plus add) and every untracked path inside package scope
#      must be the declared seam (R/fold-engine.R modified,
#      R/availability-diagnostic-writer.R added), a pre-existing planning edit,
#      or this cycle's RFC artifacts. Git failures are fatal, not parsed.
#
# Usage, from the repository root:
#   Rscript dev/spikes/availability-hot-path-representation/spike_checker.R \
#       [--skip-rerun | --rerun-dir <dir>] [--evidence <dir>]
# --skip-rerun reuses an earlier byte-identical rerun; --rerun-dir diffs
# against an existing rerun directory instead of executing the runner;
# --evidence points the assertions at another evidence directory (both are for
# gut tests of the checker and for reusing an independent rerun).
# Exit status is non-zero on any failure. No hash ledger, registry, or
# workspace-cleanliness gate: identity is the recorded evidence itself.

args <- commandArgs(trailingOnly = TRUE)
script_path <- local({
  f <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  normalizePath(sub("^--file=", "", f[[1L]]), winslash = "/")
})
spike_dir <- dirname(script_path)
repo_root <- normalizePath(file.path(spike_dir, "..", "..", ".."), winslash = "/")
runner <- file.path(spike_dir, "spike_runner.R")
skip_rerun <- "--skip-rerun" %in% args
evidence <- if ("--evidence" %in% args) {
  normalizePath(args[[match("--evidence", args) + 1L]], winslash = "/", mustWork = TRUE)
} else {
  file.path(spike_dir, "evidence")
}
scratch <- tempfile("spike_checker_evidence_")
rerun_dir <- if ("--rerun-dir" %in% args) {
  normalizePath(args[[match("--rerun-dir", args) + 1L]], winslash = "/", mustWork = TRUE)
} else {
  scratch
}

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
read_ev <- function(name) utils::read.csv(file.path(evidence, name), stringsAsFactors = FALSE, check.names = FALSE)
read_bytes <- function(path) readBin(path, what = "raw", n = file.size(path))
first_diff_line <- function(a, b) {
  la <- readLines(a, warn = FALSE); lb <- readLines(b, warn = FALSE)
  n <- max(length(la), length(lb)); length(la) <- n; length(lb) <- n
  which(is.na(la) | is.na(lb) | la != lb)[[1L]]
}
git_lines <- function(...) {
  cmd <- c("-C", shQuote(repo_root), ...)
  out <- suppressWarnings(system2("git", cmd, stdout = TRUE, stderr = FALSE))
  status <- attr(out, "status")
  if (!is.null(status) && status != 0L) {
    note(FALSE, sprintf("git %s failed with status %d", paste(c(...), collapse = " "), status))
    finish()
  }
  as.character(out)
}

deterministic <- c("fixture.csv", "cases.csv", "diagnostics_40_rows.csv")
measurement <- c("measurements_40.csv", "envelope_757.csv", "lanes_757.csv")
present <- file.exists(file.path(evidence, c(deterministic, measurement)))
note(all(present), sprintf("evidence: all six CSVs present in %s%s", evidence,
     if (all(present)) "" else paste0(" (missing: ", paste(c(deterministic, measurement)[!present], collapse = ", "), ")")))
if (!all(present)) finish()

# 1. Rerun the semantic phase into scratch (unless --rerun-dir supplies one).
if (!skip_rerun && identical(rerun_dir, scratch)) {
  dir.create(scratch, recursive = TRUE)
  rscript <- Sys.which("Rscript")
  candidates <- file.path(R.home("bin"), c("Rscript.exe", "Rscript", "x64/Rscript.exe"))
  candidates <- candidates[file.exists(candidates)]
  if (length(candidates)) rscript <- candidates[[1L]]
  cat("rerunning semantic phase into", scratch, "\n")
  log <- system2(rscript, c(shQuote(runner), "semantic", "--evidence", shQuote(scratch)), stdout = TRUE, stderr = TRUE)
  rerun_ok <- all(file.exists(file.path(scratch, deterministic)))
  if (!rerun_ok) cat(utils::tail(log, 20), sep = "\n")
  note(rerun_ok, "semantic rerun produced fixture.csv, cases.csv, and diagnostics_40_rows.csv")
  if (!rerun_ok) finish()
}

# 2a. Deterministic evidence: byte-exact.
if (!skip_rerun) {
  for (name in deterministic) {
    a <- file.path(evidence, name); b <- file.path(rerun_dir, name)
    same <- file.exists(b) && file.size(a) == file.size(b) && identical(read_bytes(a), read_bytes(b))
    detail <- if (same) sprintf("%d bytes", file.size(a)) else if (!file.exists(b)) "missing from the rerun" else sprintf("first differing line %d", first_diff_line(a, b))
    note(same, sprintf("%s: rerun byte-identical to recorded evidence (%s)", name, detail))
  }
}

# 2b. Fixture registration (Charter v2: shared shape, list placement, envelope).
fx <- read_ev("fixture.csv")
registered <- data.frame(
  fixture = c("compare40", "envelope757"), n_instruments = 563L, n_members = 505L,
  n_sessions = c(40L, 757L), n_lists = c(4L, 60L),
  list_session_indices = c("1 11 21 31", paste(1L + (0:59) * 12L, collapse = " ")),
  wall_ceiling_s = 1800L, ws_ceiling_mib = 4096L, stringsAsFactors = FALSE)
fx <- fx[match(registered$fixture, fx$fixture), ]
fixture_ok <- nrow(fx) == 2L && !anyNA(fx$fixture) &&
  all(vapply(names(registered), function(cn) identical(as.character(fx[[cn]]), as.character(registered[[cn]])), logical(1))) &&
  all(fx$chunk_rows >= 1L & fx$small_chunk_rows >= 1L & fx$small_chunk_rows < fx$chunk_rows)
note(fixture_ok, "fixture.csv: both fixtures match the charter's registered shapes, list placement, and envelope ceilings")
if (!fixture_ok) finish()
c40 <- fx[fx$fixture == "compare40", ]; e757 <- fx[fx$fixture == "envelope757", ]

# 2c. Semantic claims recorded in cases.csv.
cases <- read_ev("cases.csv")
semantic_failures_before <- length(failures)
all_true <- function(x) length(x) > 0L && all(!is.na(x)) && all(x)
true_where_present <- function(x) any(!is.na(x)) && all(x[!is.na(x)])
note(all_true(cases$seq_continuous), "cases.csv: diagnostic_seq continuous in every case and arm")
direct_like <- cases$case %in% c("C1_direct", "C2_direct_small_chunk", "C3_interrupt_resume")
note(all_true(cases$diagnostics_identical_to_direct[direct_like]),
     "cases.csv: direct, small-chunk, and interrupt/resume diagnostics identical to the direct rows-arm run (clean-versus-resumed equality)")
# C2 (small chunk) runs the columnar arm only and is compared to the direct
# run above; every other row must have a rows-arm peer and match it.
has_peer <- cases$case != "C2_direct_small_chunk"
note(all_true(cases$diagnostics_identical_to_rows_arm[has_peer]) && all(is.na(cases$diagnostics_identical_to_rows_arm[!has_peer])),
     "cases.csv: diagnostics identical to the rows arm in every case with a peer (arm parity)")
note(all_true((cases$events_identical_to_rows_arm & cases$equity_identical_to_rows_arm & cases$state_identical_to_rows_arm & cases$completion_identical_to_rows_arm)[has_peer]),
     "cases.csv: events, equity, strategy state, completion identical to the rows arm in every case with a peer")
note(true_where_present(cases$session_reader_matches_store), "cases.csv: public reader matches the stored rows in every completed invocation")
note(true_where_present(cases$reopened_matches_session) && true_where_present(cases$reopened_identical_to_rows_arm),
     "cases.csv: fresh-connection reopen matches the session read and the rows arm where the run reached DONE")
note(true_where_present(cases$explained_identical_to_rows_arm), "cases.csv: ledgr_run_explain() identical to the rows arm where the run reached DONE")
c4 <- cases[cases$case == "C4_exception_rollback", ]
note(nrow(c4) == 2L && all(c4$final_status == "FAILED") && all(c4$error_rows == 1L) && all(c4$diagnostic_rows == 1L) && all(c4$event_rows == 0L),
     "cases.csv: exception rollback leaves exactly one error diagnostic and no committed rows in both arms")
c5 <- cases[cases$case == "C5_resume_then_exception", ]
note(nrow(c5) == 2L && all(c5$first_status == "RUNNING") && all(c5$final_status == "FAILED") && all(c5$error_rows == 1L) && all(c5$diagnostic_rows == c5$decision_rows + 10L + 1L),
     "cases.csv: resume-then-exception keeps the committed prefix and appends exactly one error diagnostic in both arms")
note(sum(cases$case == "C1_direct") == 2L && setequal(cases$arm[cases$case == "C1_direct"], c("rows", "columnar")),
     "cases.csv: both arms present for the direct case")
ref <- read_ev("diagnostics_40_rows.csv")
expected_rows <- c40$n_sessions * c40$n_members + c40$n_sessions
note(nrow(ref) == expected_rows && identical(as.integer(ref$diagnostic_seq), seq_len(nrow(ref))),
     sprintf("diagnostics_40_rows.csv: %d rows (registered decision plus reconciliation rows), sequence 1..n", nrow(ref)))
semantic_ok <- length(failures) == semantic_failures_before

# 2d. 40-pulse measurement: registered repetition shape and the median/spread rule.
m <- read_ev("measurements_40.csv")
by_arm <- split(m, m$arm)
shape_ok <- setequal(names(by_arm), c("rows", "columnar")) && all(vapply(by_arm, function(s)
  identical(s$repetition, c("warmup", "run1", "run2", "run3")) && identical(s$measured, c(FALSE, TRUE, TRUE, TRUE)), logical(1)))
note(shape_ok, "measurements_40.csv: both arms, each one unmeasured warm-up then three measured runs")
note(all(is.finite(m$wall_seconds) & m$wall_seconds > 0 & is.finite(m$t_loop_seconds) & m$t_loop_seconds > 0 &
         m$t_loop_seconds <= m$wall_seconds & is.finite(m$peak_ws_mib) & m$peak_ws_mib > 0),
     "measurements_40.csv: wall, t_loop, and peak working set finite and positive, t_loop within wall")
note(all(m$status == "DONE") && all(m$decision_rows == c40$n_sessions * c40$n_members) && all(m$reconciliation_rows == c40$n_sessions),
     "measurements_40.csv: every run DONE with the registered decision and reconciliation row counts")
mm <- m[m$measured, ]
med <- function(arm, col) stats::median(mm[[col]][mm$arm == arm])
spread <- function(arm, col) diff(range(mm[[col]][mm$arm == arm]))
wall_rule <- isTRUE(shape_ok) && med("columnar", "wall_seconds") < med("rows", "wall_seconds") - spread("rows", "wall_seconds")
ws_rule <- isTRUE(shape_ok) && med("columnar", "peak_ws_mib") < med("rows", "peak_ws_mib") - spread("rows", "peak_ws_mib")
if (isTRUE(shape_ok)) {
  note(wall_rule, sprintf("measurements_40.csv: columnar median wall %.2f s is below the rows median %.2f s by more than the rows spread %.2f s",
       med("columnar", "wall_seconds"), med("rows", "wall_seconds"), spread("rows", "wall_seconds")))
  note(ws_rule, sprintf("measurements_40.csv: columnar median peak WS %.1f MiB is below the rows median %.1f MiB by more than the rows spread %.1f MiB",
       med("columnar", "peak_ws_mib"), med("rows", "peak_ws_mib"), spread("rows", "peak_ws_mib")))
}

# 2e. 757-pulse envelope: bounds, completion states, and stop labels.
e <- read_ev("envelope_757.csv")
e$killed[is.na(e$killed)] <- ""
wall_cap <- e757$wall_ceiling_s; ws_cap <- e757$ws_ceiling_mib
note(nrow(e) == 3L && sum(e$arm == "rows" & !e$profiled) == 1L && sum(e$arm == "columnar" & !e$profiled) == 1L && sum(e$arm == "columnar" & e$profiled) == 1L,
     "envelope_757.csv: one unprofiled run per arm plus one profiled columnar run")
inside <- e$within_envelope
note(identical(inside, e$killed == ""), "envelope_757.csv: within_envelope agrees with the sampler's kill label")
in_ok <- all(!inside | (is.finite(e$run_elapsed_s) & e$run_elapsed_s <= wall_cap & is.finite(e$peak_ws_mib) & e$peak_ws_mib <= ws_cap &
  e$store_status == "DONE" & is.finite(e$wall_seconds) & is.finite(e$t_loop_seconds) & e$t_loop_seconds <= e$wall_seconds &
  e$decision_rows == e757$n_sessions * e757$n_members & e$store_diagnostic_rows == e$decision_rows + e757$n_sessions))
note(isTRUE(in_ok), sprintf("envelope_757.csv: within-envelope runs finished DONE under %d s wall and %d MiB working set with the registered row counts", wall_cap, ws_cap))
out_ok <- all(inside | (e$killed %in% c("wall", "working_set") & e$store_status != "DONE" &
  ifelse(e$killed == "wall", e$run_elapsed_s >= wall_cap, e$peak_ws_mib >= ws_cap)))
note(isTRUE(out_ok), "envelope_757.csv: stopped runs are labelled with the ceiling they reached and did not reach DONE")
columnar_inside <- isTRUE(in_ok) && all(inside[e$arm == "columnar"]) && sum(e$arm == "columnar") == 2L
note(columnar_inside, "envelope_757.csv: both columnar runs (unprofiled and profiled) completed within the envelope")

# 2f. Lane shares of the profiled columnar run.
l <- read_ev("lanes_757.csv")
lane_names <- c("provider_membership", "provider_status_lifetime", "provider_other", "valuation", "diag_construct",
                "diag_append_retain", "final_bind", "duckdb_diag_append", "residual_fold", "outside_loop")
note(setequal(l$lane, lane_names) && !anyDuplicated(l$lane), "lanes_757.csv: the ten classifier lanes present once each")
in_loop <- l$lane != "outside_loop"
shares_ok <- all(is.finite(l$share_in_loop) & l$share_in_loop >= 0 & l$share_in_loop <= 1) &&
  all(l$samples >= 0 & l$samples == round(l$samples)) && sum(l$samples[in_loop]) > 0 &&
  isTRUE(all.equal(sum(l$share_in_loop[in_loop]), 1, tolerance = 1e-9)) &&
  isTRUE(all.equal(l$share_in_loop, l$samples / sum(l$samples[in_loop]), tolerance = 1e-9))
note(shares_ok, "lanes_757.csv: shares finite in [0, 1], equal to samples over in-loop samples, summing to one over in-loop lanes")
# Same grouping as spike_runner.R.
groups <- list(diagnostics = c("diag_construct", "diag_append_retain", "final_bind", "duckdb_diag_append"),
               provider = c("provider_membership", "provider_status_lifetime", "provider_other"),
               valuation = "valuation", residual_fold = "residual_fold")
g <- sort(vapply(groups, function(x) sum(l$share_in_loop[l$lane %in% x]), numeric(1)), decreasing = TRUE)
one_largest <- isTRUE(shares_ok) && g[[1L]] > g[[2L]]
note(one_largest, sprintf("lanes_757.csv: one largest grouped lane (%s %.1f%%, then %s %.1f%%)", names(g)[[1L]], 100 * g[[1L]], names(g)[[2L]], 100 * g[[2L]]))
mechanism_removed <- one_largest && names(g)[[1L]] != "diagnostics" && isTRUE(l$share_in_loop[l$lane == "final_bind"] == 0)
note(mechanism_removed, "lanes_757.csv: diagnostics is not the largest grouped lane and the final bind lane has zero samples (diagnosed mechanism removed)")

# 2g. Decision (Charter v2, Measurement boundary and kill condition).
kill_fires <- mechanism_removed && !all(inside[e$arm == "columnar" & !e$profiled])
note(!kill_fires, "decision: the kill/recharter condition does not fire (mechanism removed and the alternative's 757-pulse run stayed within the envelope)")
green <- semantic_ok && wall_rule && ws_rule && columnar_inside && mechanism_removed
note(green, "decision: GREEN (every semantic claim holds; 40-pulse median/spread rule on wall and peak working set; alternative within the 757-pulse envelope; mechanism removed)")

# 3. Package-scope guard over every change type.
pre_existing <- c("AGENTS.md", "inst/design/README.md", "inst/design/horizon.md", "inst/design/ledgr_roadmap.md",
                  "inst/design/rfc/README.md", "tests/testthat/test-documentation-contracts.R")
seam_modified <- "R/fold-engine.R"
seam_added <- "R/availability-diagnostic-writer.R"
package_scope <- function(paths) paths[grepl("^(R/|src/|tests/|man/|inst/design/|NAMESPACE$|DESCRIPTION$)", paths)]
cycle_rfc <- function(paths) paths[startsWith(paths, "inst/design/rfc/rfc_availability_hot_path_representation_")]
tracked <- git_lines("diff", "--name-status", "--no-renames", "HEAD")
tracked_status <- sub("\t.*$", "", tracked)
tracked_path <- sub("^[^\t]*\t", "", tracked)
untracked <- git_lines("ls-files", "--others", "--exclude-standard")
in_scope <- tracked_path %in% package_scope(tracked_path)
allowed_tracked <- tracked_path %in% c(pre_existing, seam_modified) & tracked_status == "M"
unexpected_tracked <- paste(tracked_status, tracked_path)[in_scope & !allowed_tracked]
unexpected_untracked <- setdiff(package_scope(untracked), c(seam_added, cycle_rfc(untracked)))
note(length(unexpected_tracked) == 0L, sprintf("scope: tracked package changes (any status) are only modifications of the seam and pre-existing planning edits%s",
     if (length(unexpected_tracked)) paste0(" (unexpected: ", paste(unexpected_tracked, collapse = ", "), ")") else ""))
note(length(unexpected_untracked) == 0L, sprintf("scope: untracked package files are only the seam and this cycle's RFC artifacts%s",
     if (length(unexpected_untracked)) paste0(" (unexpected: ", paste(unexpected_untracked, collapse = ", "), ")") else ""))
seam_present <- any(tracked_path == seam_modified & tracked_status == "M") && seam_added %in% untracked && file.exists(file.path(repo_root, seam_added))
note(seam_present, "scope: seam present (R/fold-engine.R modified, R/availability-diagnostic-writer.R added and untracked)")
stat <- git_lines("diff", "--numstat", "--no-renames", "HEAD", "--", seam_modified)
nums <- if (length(stat)) as.integer(strsplit(stat[[length(stat)]], "\t")[[1L]][1:2]) else c(NA_integer_, NA_integer_)
note(!anyNA(nums) && all(nums <= 40L), sprintf("scope: R/fold-engine.R seam diff is small (+%s/-%s lines)", nums[[1L]], nums[[2L]]))

finish()
