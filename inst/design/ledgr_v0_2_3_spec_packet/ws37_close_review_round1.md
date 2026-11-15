CHANGES_REQUIRED

Mode: Type 1 close review, round 1, whole workstream 37 (Cut 19). Independent fresh session at b3584b58b9cc5a4e31d723ca44f002552b6ed9c7; reviewed dev/lean_core changes from bdeea449 and the fc0a0b8c..b3584b58 refactor against pin d5b3a151. No settled decision reopened.

F1. Required: the growth variant does not lose an existing record.

Claim: LDG-3238's required prefix-loss fault remains untested. The registered record_lost_at_growth variant drops an incoming row instead.

Evidence: tickets.yml:6115 explicitly requires a reached variant that loses an existing record at growth. In dev/lean_core/parity/loop_parity.R:245-247 the variant decrements s3$nx immediately after growing xr. But dev/lean_core/marks.R:41 computes the incoming row indices before that decrement; lines 48-51 write those original indices, and line 52 advances the decremented count. Every pre-growth row stays intact. The final incoming row falls outside the used range and can be overwritten by the next append.

The direct probe C:/Users/maxth/ledgr-wt/ws37-close-review-out/growth_variant_probe.R applies exactly that registered edit, writes 60 distinct existing records, then appends ten records across the 64-row capacity. Its output, growth_variant_probe.txt:1-6, is:

```text
marker TRUE
used 69 allocated 128
all_existing_prefix_columns_identical TRUE
existing_rows_lost
incoming_rows_lost new10
physical_row70 new10
```

I also reran the registered variant on s3_many_gaps at debug 0: record_lost_at_growth.csv reports CAUGHT, 16 tables, three different. That result detects its incoming-row/count fault; it does not establish the required existing-prefix fault.

Consequence: the cut's explicit mutation obligation is incomplete, despite its CAUGHT result. This is a proof defect; I found no corresponding error in the unmodified buffer implementation.

Fix: change the variant to lose or corrupt a record that was already within the nonempty used prefix before growth. Keep the reach marker inside the growth branch, verify the chosen prefix record actually changes, and require its diagnostic/codec consequence to catch it on the registered workload. Record the correction and rerun that variant before the planned final check set. Do not change the workload's expected pin output.

What I checked:

- Read Cut 19 decisions 1-10, workstream 37 and LDG-3237 through LDG-3240, interface Sections 19.2 and 19.11, both cut reviews, the relevant contracts (including contract-availability-valuation), the seven coding shapes, the changed core/harness and the pin's valuation, provider, carrier, diagnostic, schedule and history paths. The bdeea449..HEAD diff changes nothing in R/, tests/, DESCRIPTION or NAMESPACE. Tracked files remain untouched and the worktree is clean.
- Traced the marked-run trigger over the full prepared planes. The marked path calls the pin's valuation state with full bars, session axis and history_reader$pulse_columns, provider decision_view, frozen restriction, carrier provider view and production strategy-target availability check. For the admitted complete fixed basket, each decision close is finite and current; the constant packet and publication constants are consistent with that boundary. I found no copied mark rule or marked path that takes the constant packet.
- Traced both stop sites, the skip head, frozen transition order, decision fields, stale-risk rows, implicit eligibility, completion exposure and the new publication counts. The reason-based no_decision computation distinguishes valuation stops and skips from risk stops. New row columns are typed and grown together; xr is detached before indexed writes. New field loops have fixed width, and frozen/skip group loops have bounded group counts. No additional coding-style finding.
- Independently ran s3_many_gaps, s3_mixed_transition, s3_multi_stop, s3_skip_stop_first, s3_offset_first_stale, s3_tail_gap, s3_risk_mark_never and s3_sched_stale against the freeze in both debug modes: 125 tables per mode, zero differences, eight matching frozen paths. Ran the mixed-transition and multi-stop workloads at batch one in both modes: 32 tables per mode, zero differences, append and expansion bounds one. Ran s3_freeze_exit with inert hooks in both modes: 16 identical tables per mode. Inert PASS* reports hook counters, not absence of lean execution.
- Added nine small independent probes in probe.R, with outputs probes_debug0.csv and probes_debug1.csv and saved arm records. Every table and captured fold status, processed, full_run, state, strategy state and next-event sequence matched. Cases cover 180 instruments with many gaps; a first-pulse risk stop; freeze entry and freeze exit on risk-stop pulses; an offset first-pulse stop; skips with multiple marked holdings; a skipped prefix; frozen liquidation; and complete-plane explicit decisions. The growth case uses 1,620 decision rows in capacity 2,048 and 720 slice-3 rows in capacity 1,024. Thus the previously ungrown decision buffer's new columns survive growth on this review's probe. The absence of such a gate case is worth retaining as a regression witness, but did not reveal a product defect.
- Reran cut18_witness.R: 145 cases in each debug mode, 290 identical outcomes, no missing or unlisted manifest cases.
- Recounted committed proofs using audit.R; evidence_audit.txt records the calculations. Each pre-refactor gate has 111 workloads, 1,878 comparisons, zero differences, 110 PASS and one PASS*. Batch one has 17 workloads/264 comparisons; inert has eight/124. Planner evidence has 427 identical comparisons per mode; dispatch has 26 passing rows; Cut 18 has 290. Effective variant results have 75 rows/45 variants at debug 0 and 61/33 at debug 1, all CAUGHT; the three negative controls have their declared failing verdicts. Exactly 32 history rows are retired. The committed reach cross-check has 41 passing checks, including four constant-read controls. Its code refuses missing predicates and dumps. F1 is the exception to the intended-fault claim.
- Recomputed frozen_moves.csv with cut19_moves.R: byte-equivalent parsed contents, 30 changed rows covering exactly the declared 15 existing workloads in both debug modes, 80 additions and no removals. Reviewed the surviving re-anchors. The FIFO scope pattern still selects every FIFO function previously selected; it excludes the unrelated checks.R state helpers. The implicit-row re-anchor still removes only tq == sq while preserving the skip guard. Neither fix weakens its stated check.
- Recomputed final lines: loop.R 974 production/119 debug; marks.R 152 production; total 2,256 to 2,433 production (+177), debug 177 to 179. Both caps hold. Committed lines.csv describes fc0a0b8c (995/114), as distinguished in the ticket; it still needs the stated final refresh.
- Ran the shared timing checker on the committed record: CHECK PASS, 192 slots, eight pairs per cell. Recomputed run/fold ratios: 0.177/0.139, 0.156/0.134, 0.487/0.377, 0.761/0.564, 0.221/0.197; marked descriptive 0.306/0.274. Work strings agree within every cell. Recomputed paired-comparison raw data: cmp1 slowdowns 3.7/3.9/3.8 percent on the three cited shapes; cmp3 changes +1.5/+1.6/-1.4/+1.5 percent, with slower-pair counts 6/5/2/5. Reported medians reproduce.
- The final cheap proof files contain 54 workloads and 872 identical comparisons per debug mode, both batch-one witnesses, and the eight cited caught variants. Together with inspection and the targeted final-code probes, these support the refactor under the maintainer's tiering. The full final check set and replacement timing record remain due after review; their authorized deferral is not a finding. The old record does not prove final-code timing.

What I did not check: I did not run timing windows, the full gate, variant driver, FIFO/planner suites or full package tests/checks. I inspected their committed evidence rather than rerunning them. I did not regenerate all slice-3 pin dumps or rerun the complete reach cross-check, remeasure the explanatory frame-binding microsecond estimates, exhaust public API combinations, or assess slices 4-5. I found no wrong product answer or wrong refusal in the executions performed. No tracked file was edited and no commit was made. Probes and outputs are confined to C:/Users/maxth/ledgr-wt/ws37-close-review-out.
