PASS
Mode: Type 1 close review of workstream 37 (Cut 19), round 2. Fresh independent session at 5874613a73811858f75b447b8eef035949b28702; scope limited to round 1 F1 and regressions from its correction.

Repository references below are relative to C:/Users/maxth/ledgr-wt/ws37-close-review. Probe references are relative to C:/Users/maxth/ledgr-wt/ws37-close-review-out.

1. Required finding F1 from round 1: resolved. No new required or advisory finding.

   Claim: record_lost_at_growth now corrupts a record written before growth, inside the growth branch, with its reach marker executed. On s3_many_gaps, that corruption causes the catch with debug off and on.

   Evidence:

   - dev/lean_core/parity/loop_parity.R:247 defines the corrected edit. It inserts an overwrite of row s3$nx after column expansion. dev/lean_core/marks.R:41 computes incoming indices above that existing prefix; marks.R:44 contains the growth branch. The applied source in round2_marks_edited.txt:44 shows the marker at line 47 and overwrite at line 48, both inside that branch. The used count is no longer decremented.
   - round2_growth_probe.R extracts the actual registered edit and adapts round 1's direct witness. round2_growth_probe.txt:1 records debug 0 and line 11 debug 1. Both show marker FALSE before growth and TRUE after it, 70 used rows in capacity 128, existing record old60 lost, and no incoming record lost. All 17 columns of old60 become NA; the other 59 existing rows and all ten incoming rows remain identical to the unmodified writer, with column types preserved.
   - round2_variant_probe.R runs the registered single workload and observes growth calls. round2_variant_debug0_growth.csv:2 and round2_variant_debug1_growth.csv:2 show the first loss at growth from 64 to 128: existing row 46, pulse 6, I069, stale_mark_pass_through, while appending pulse 7. Lines 3 and 4 show losses of existing rows 117 and 237 at the next two growth calls. At each call only the last existing row changes, every column becomes NA, the used count advances normally, and the marker is TRUE.
   - round2_variant_debug0.txt:2 and round2_variant_debug1.txt:2 report 16 comparisons, 13 different, CAUGHT. Both reproduce the committed review CSVs exactly except elapsed-time fields. The error is "'vec' must be sorted non-decreasingly and not contain NAs". Its path is concrete: loop.R:1113 passes the corrupted used pulse column through lean_rows_in(), whose findInterval() call is at loop.R:1071.
   - The causal control, the same probe with --repair=1, lets the registered mutation execute and restores only its overwritten existing row after each growth. round2_repair_debug0.txt:2 and round2_repair_debug1.txt:2 report all 16 tables identical to the pin and no new error. The unchanged mutation detector reports MISSED, as expected when its corruption is repaired; its reach marker remains TRUE. This isolates the catch to the intended existing-record loss.

   Consequence: LDG-3238's existing-record-loss obligation is now demonstrated in both debug modes. The incoming-row/count fault identified in round 1 is gone.

   Fix: already implemented in the registered variant and recorded in tickets.yml:6175. No further correction is required for F1.

What I checked:

- Read round 1 F1, LDG-3238's relevant acceptance criteria, LDG-3240's correction evidence, the corrected variant, edit application, row writer and failing publication path.
- Inspected the full b3584b58..5874613a diff. The only executable dev/lean_core source change is the corrected variant, plus its explanatory comment. Four files were added under parity/evidence/cut19/review; these are the direct probe, its output and two variant CSVs. No other lean-core code, workload, oracle or detector changed. The remaining diff records the review and ticket evidence. round2_lean_source.diff preserves the source-only diff.
- Ran the direct witness in both debug modes and the targeted s3_many_gaps variant and row-restoration control in each mode against the read-only d5b3a151 library. The runner probe changes only the harness's source-directory and scratch-directory assignments in memory, then observes the original row writer; the repair control additionally restores the lost row. All final probes exit successfully.
- Verified detached HEAD at the requested commit and a clean worktree before and after probing. No tracked file was edited and no commit was made. Probe scripts, workload stores and result files are confined to the authorized output directory.

What I did not check: I did not rerun timing windows, the full gate, the variant driver, other workloads, FIFO/planner suites or package tests/checks. I did not repeat round 1's whole-cut review or reopen Cut 19, deletion-readiness seed v2 or proof tiering. The full final check set and final-code timing record remain due after this review, as settled by the maintainer; this PASS closes the scoped F1 review, not those later obligations.
