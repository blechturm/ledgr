CHANGES_REQUIRED
Mode: Type 2 cut review; independent session, no authorship of the cut.

Reviewed commit: ff90fa3bf759cff6e1f56d8ea10d97547e5ac3c8.
Paths below are relative to C:/Users/maxth/ledgr-wt/cut14-review unless stated otherwise.
For compact citations, tickets.yml, macro_plan.md and lean_core_interface.md
refer to inst/design/ledgr_v0_2_3_spec_packet/. Bare loop.R refers to
dev/lean_core/loop.R; bare loop_parity.R, loop_workloads.R, loop_checklist.md
and loop_mutations.sh refer to dev/lean_core/parity/. Bare profile.R and
features.R refer to dev/bench/v0_2_3_lean_tuning_profile/. Bare run2.R refers
to dev/spikes/r_floor/run2.R. review_probe.txt is in cut14-review-out.

The cut is necessary. Named stages restore an already accepted boundary, and
the existing profile leaves a substantial loop bucket unexplained. Restructure
and measurement are the right two tickets in one workstream. The H1 and
outside-loop work can start independently, as the cut already permits. Keep
tuning, feature dispatch design, store-format changes and the five deferred D3
census cases outside this cut. No new product decision requiring an RFC was
found. The corrections below make the existing intent enforceable; none needs
a new maintainer design choice.

R1. Required — Freeze execution coverage, debug obligations and the hooks seam,
not just output parity.

Claim: LDG-3220's gate can pass after losing a covered execution path or an
internal check. Running with debug enabled does not prove that its checks still
run. The inert-hooks output check does not prove the fold has no direct harness
dependency.

Evidence: tickets.yml:4618-4620 requires final parity and registered variants.
dev/lean_core/parity/loop_parity.R:252-266 accepts identical output when the
candidate refuses and runs the pin; only four refusal names are asserted in
dev/lean_core/parity/loop_workloads.R:556-560. The large crossover workloads
are registered at loop_parity.R:170-172, while most mutation witnesses are
small (loop_mutations.sh:11-35). Target, packet and gross debug checks have
no dedicated disabling variant (loop.R:533-548,584-586,749-752;
loop_parity.R:49-98). The hooks-only rule includes a code-inspection obligation,
not merely an inert output test (loop_checklist.md:83-85;
lean_core_interface.md:829-842). AGENTS.md:50-52 retains debug hand-off checks.
Stable behavior groups: contracts.md:1771,2029,244 (strategy outputs,
reproducibility, typed fold carrier).

Consequence: a size-dependent coverage refusal could send the large workloads
back to the pin while the small variants still pass. Removing the target or
gross debug comparison would leave correct positive examples unchanged. A
stage could refer directly to the always-loaded lean_entry object and still
pass the registered inert output checks. Those are changes to what this cut
claims to preserve.

Replacement: replace LDG-3220's second acceptance item with:

> Before editing, freeze the registered workloads, modes, batch-one and inert
> workloads, expected lean-fold counts, refusal names and backstop paths from
> 4a3e08b8. Run the unchanged gate before and after restructuring against the
> same pin; require identical outputs and the same expected execution paths.
> Preserve every behavioral obligation in loop_checklist.md. Record where each
> existing debug check and each hooks call moves; removal of a shortcut may
> remove only checks specific to that implementation, with its surviving
> contract witness named. Check that loop.R still reaches the harness only
> through lean_hooks and contains no harness record or variant branch. Batch
> one and inert-hooks checks retain their existing workloads and detector
> demonstrations. Registered variants satisfy the separate variant acceptance.

R2. Required — A unique function anchor does not establish a meaningful mutant;
the registry must also be complete and fail closed.

Claim: function-scoped matching is a useful syntactic check, but neither it nor
the current expected-signal gate rejects an unrelated runtime failure. The cut
also permits deleting the only mutation for a contract obligation when deleting
a shortcut.

Evidence: tickets.yml:4620-4621; loop_parity.R:41-98 defines 23 variants, 11
expecting only "differ". Any escaped error becomes output at :208-210, and any
table difference satisfies that signal at :253-254,268-271. A missing lean
execution yields NOT RUN, which is not a failing exit at :289-290.
loop_mutations.sh:15-17 pipes R through grep and sed without propagating the R
failure, and has no census of expected result rows. The checklist binds
obligations to witnesses and variants at loop_checklist.md:3-11,21-24.
AGENTS.md:28-30 forbids weakening registered tests to accommodate product
failures. The isolated execution of the actual verdict expression in
C:/Users/maxth/ledgr-wt/cut14-review-out/review_probe.txt confirms both
CAUGHT for an unrelated differing error and the non-failing NOT RUN case.

Consequence: after extraction, a patch using an out-of-scope variable can be
"caught" because the run errors, although it never changes the intended fill,
hold or commitment. A failed anchor or omitted invocation can disappear from
the shell summary. Retiring patch_container together with its shortcut could
silently retire proof of the production refusal.

Replacement: replace LDG-3220's third acceptance item and the deletion clause
of its fourth item with:

> Each edit names its lexical function and has exactly one anchor inside that
> function; missing functions and missing or repeated anchors fail. Freeze the
> pre-cut variant/workload/mode manifest. For each retained or retargeted
> variant, record the old defect, new patch and witness, and demonstrate the
> intended fault: expected differing fields or condition, detector path, or
> protocol boundary. An unrelated error or an unreached patch cannot count as
> CAUGHT. Every manifest row must execute and satisfy that expectation; missing
> rows, NOT RUN, MISSED, load errors and subprocess failures fail the aggregate
> runner. A deleted shortcut may retire its implementation-specific variant
> only with a recorded reason; its contract witness, refusal oracle and modes
> remain. Retarget a contract variant to break the candidate's delegated path
> when necessary. Record every retirement explicitly rather than shrinking the
> registry silently.

R3. Required — Define the two-percent experiment and make the regression
exception require disposition.

Claim: the shapes, debug setting and compilation requirement are specified,
but "with and without", the savings denominator and "loop time" are not.
Independent five-run medians can select different deletions through run order,
GC or the state of other shortcuts. Merely reporting a five-percent miss is
not a no-regression gate.

Evidence: tickets.yml:1638-1646,4621-4622. loop.R:775-779 separately clocks
pulses and publication, whereas :1067-1089 clocks the transaction including
publication. The cited timing protocol measures the entire envelope
(dev/bench/timing/records/cut13-loop-1/ldg3219-gate-r1/attempt-1/protocol/workloads.R:80-110).
The family method calls for alternating measurements (macro_plan.md:823-829).
LDG-3217's evidence already demonstrates GC-sensitive timing and an explicit
maintainer disposition (tickets.yml:4523-4524,4528).

Consequence: two conforming implementations can delete different shortcuts.
Deletion costs can accumulate, and a regression can pass simply because its
author reported it. A pulse-only check also misses a regression moved into
envelope setup or terminal transfer during extraction.

Replacement: replace LDG-3220's fourth and fifth acceptance items with:

> Use the same crossover fixtures on 10 x 7,200, 20 x 23,400 and 500 x 1,260.
> In a short in-process runner, warm both byte-compiled, debug-off arms and
> alternate at least five pairs with the same hooks, inputs and GC policy;
> retain raw observations. The shortcut comparison uses the restructured
> all-shortcuts arm and an otherwise identical arm delegating exactly one
> shortcut to the pin. Time the complete pulse loop, excluding envelope
> setup and terminal transfer, by one outer clock rather than per-pulse
> timers. Report both medians and paired savings, defined as
> (delegated_time - shortcut_time) / delegated_time. Delete a shortcut only
> when its median paired saving is below 0.02 on all three shapes and the
> result is resolved at that precision; report an unresolved threshold result
> for maintainer disposition. Delegation retains the pin's values, refusal
> class/message/order and timing; deletion never means deleting validation.
> After all deletions, compare the final arm with 4a3e08b8 loaded in the same
> process by the same method. Report pulse-loop, complete-envelope and
> whole-run times on all three shapes. A pulse-loop median regression above
> five percent, or a regression displaced outside the loop, blocks close
> until fixed or explicitly accepted by the maintainer. No full timing window
> or new frozen timing record is required.

R4. Required — Make the cost map a matched, reconciled measurement, and measure
the snapshot boundary it claims to cover.

Claim: LDG-3221 does not bind a common timing method, compilation/debug settings
or exclusive phase accounting. The existing runner opens and verifies the
snapshot before its clock, so extending only its phase markers cannot measure
snapshot open and verification. Historical floor layers are cumulative
guarantees, not costs of the new stage functions.

Evidence: tickets.yml:4633-4646; profile.R:25-27 compiles the current lean arm,
:40-50 opens the snapshot and builds the experiment, :52-67 then clocks only
ledgr_run with the harness installed. R/run-snapshot.R:20-29 also performs an
in-run ensure-verified check; its cost must be distinguished from the initial
verified open. :73-105 of profile.R defines markers, :112-130
assigns samples and estimates phase seconds from sample shares times the median
wall. Thus phase seconds are estimates too, not independently measured wall
times. The floor uses cumulative layers (dev/spikes/r_floor/README.md:81-103),
a different old oracle and partial surface (:19-21,54-60,238-244), and its
runner uses system.time and three or five repetitions (run2.R:24,44,70-73).
The current profile stores only lean samples, while the ticket promises both
arms outside the loop. Benchmark lifecycle rules require explicit boundaries
(inst/design/manual/benchmark_methodology.qmd:53-75,95-110).

Consequence: the map can compare profiled lean costs with differently warmed
or compiled pin costs, omit the initial verified open while labeling an in-run
guard as that work, or double-count strategy time inside P2. Cut 15 needs measured
whole-run and pulse-loop totals beside attribution estimates; it cannot derive
a controlled stage premium by subtracting an old cumulative floor layer.

Replacement: add these acceptance items to LDG-3221:

> For both arms on all four shapes use the same fixture, seed, retained output,
> store-history state, warm-up, repetition method and clock boundaries;
> byte-compile both and disable debug. Record source identities, environment,
> commands and raw observations. Require matching result signatures and
> confirmation that the lean arm executed the lean fold before interpreting
> any timing. Measure unprofiled whole-run and pulse-loop
> totals beside separate profiling runs, identifying the hooks used. Define
> mutually exclusive phase attribution: strategy time is excluded from P2's
> own time; envelope setup, terminal expansion, writing, commit and finalisation
> do not overlap the pulse stages. Report measured wall totals separately from
> every sample-derived second or microsecond estimate, and reconcile the
> attribution, including residuals, to its stated clock. Publish the residual
> percentage rather than absorbing it into E to meet the ten-percent item.
> Instrument snapshot open and verification explicitly, reporting that reusable
> cost separately from the already-open-snapshot committed-run clock.

> Label the existing R-floor stage-2 layers as historical cumulative lower
> bounds with their original shape, oracle, method and omitted work. Label
> PMwR as the historical reference with its shape and lifecycle boundary.
> Neither is a matched stage comparison or a controlled speed ratio. Any
> stronger comparison requires matching the relevant input, compilation,
> timing method and output boundary first.

R5. Required — Specify the missing H1 runner and define what its TTR comparison
can prove.

Claim: features_h1.R is absent, and "the simple shape" has no definition.
Aggregates-only output is the correct vendor rule, but it does not establish
that the compared computations cover the same instruments or values.

Evidence: tickets.yml:4640,4644 names the absent runner; the profile directory
contains features.R, profile.R, drill.R and four result CSVs. features.R:47-57
times two SMAs but checks only fast, records a Boolean without refusing FALSE,
and compares numeric values without feature evidence. Production feature work
includes expected-session masks and input carry (R/history-features.R:169-206),
segmentation, readiness and terminal breaks (:329-392), and evidence plus
causality checks (:447-503). These are actual work the bare TTR calls omit.
Stable contract groups: contracts.md:2553,2722 (indicator computation and
feature path).

Consequence: H1 timing can compare all instruments on one side with a selected
subset on the other, or compare a segmented/carry-aware series with an
uninterrupted raw SMA. The resulting subtraction would misstate machinery
cost and misinform the feature RFC. An author cannot currently run the named
script as instructed.

Replacement: replace LDG-3221's H1 scope sentence and H1 acceptance item with:

> Add features_h1.R in the profile directory. Use the pinned production
> feature-series path and the same declared SMA5/SMA10 inputs as the portable
> split. Define and report an empirical simple-shape classification from the
> production calculation bounds, expected-session mask, usable input runs,
> carry and terminal boundaries; this is measurement only, not a production
> dispatch rule. Report total, eligible and ineligible instrument counts and
> aggregate exclusion reasons. Compare bare per-instrument TTR with the pin on
> exactly the same eligible rows and calculation interval; report full-H1 pin
> time separately. Before interpreting the timing difference, check both SMA
> value arrays and their NA placement exactly, and fail on a mismatch. Identify
> evidence construction, causality checks and other work omitted by bare TTR;
> do not claim full feature-surface equivalence. Warm and repeat both arms by
> the same method and retain aggregate timings and pass flags. Every output,
> including console/error logs and scratch artifacts, contains aggregates
> only: no vendor identifiers, values or per-instrument records. No vendor
> profiling dump is retained. Private input access remains with its authorized
> executor.

R6. Required — Correct the shape attribution and distinguish profile estimates
from measured times in measured_input.

Claim: most cited numbers trace, but the third fold number is assigned to the
wrong shape. The existing loop profile totals approximately 328 us per pulse,
not 340, and its phase seconds are sample-derived estimates.

Evidence: tickets.yml:1608-1609,1623-1634;
dev/bench/v0_2_3_lean_tuning_profile/results/crossover_10x7200_phases.csv:2-20;
profile.R:127-131. The frozen timing matrix ends with 1,166 x 252, not
500 x 1,260 (dev/bench/timing/records/cut13-loop-1/ldg3219-gate-r1/attempt-1/protocol/matrix.csv:2-7).
Recomputing candidate fold medians from that record's raw.csv gives
396.5244, 457.6304 and 4816.5813 us per pulse for 10 x 7,200,
20 x 23,400 and 1,166 x 252, respectively (review_probe.txt). The floor's
26/29/103 trace to dev/spikes/r_floor/evidence/timings_layers.csv:7,13,19;
the 0.75/0.93 machinery and 0.08/0.17 TTR values trace to
dev/bench/v0_2_3_lean_tuning_profile/results/feature_split.csv:3-4.

Consequence: the cut appears to establish a 500-instrument matched fold/floor
gap that its timing record never measured. It also presents estimated phase
seconds as measured phase clocks.

Replacement for the timing portion of measured_input:

> R-floor stage 2's trace-difference layer is 26, 29 and 103 us per pulse on
> 10 x 7,200, 20 x 23,400 and 500 x 1,260, respectively
> (dev/spikes/r_floor/evidence/timings_layers.csv). The separate timing record
> cut13-loop-1/ldg3219-gate-r1/attempt-1/raw.csv measures complete-envelope
> candidate medians of 397, 458 and 4,817 us per pulse on 10 x 7,200,
> 20 x 23,400 and 1,166 x 252, respectively; it has no 500 x 1,260 cell.
> These envelope clocks include setup and terminal transfer and are not
> pulse-loop-only clocks.

Replace "88 of about 340 us per pulse" in opening with "88 of approximately
328 estimated us per pulse". Prefix the profile phase figures in measured_input
with "Rprof-derived estimates" and call their per-run seconds estimates too.

R7. Required — Preserve the standing Type 1 scope and prevent the review stop
rule from becoming acceptance with unresolved findings.

Claim: one correction pass is an explicit maintainer instruction, and the
third-round escalation is retained. Neither conflicts merely by limiting the
number of reviews. However, "wrong answers and false evidence only" narrows
Type 1 beyond the binding scope, and the cut does not say what happens to
unresolved findings when another round is disallowed.

Evidence: tickets.yml:1665-1672; macro_plan.md:912-914. AGENTS.md:41-49 and
inst/design/rfc_cycle.md:274-282 require faithful implementation, contained
scope and the independent-input question, with NEEDS_TYPE_2 for a design
problem. rfc_cycle.md:291-294 places review before dependent work, and
:304-322 binds evidence, finding records and escalation.

Consequence: missing stage boundaries, weakened debug checks or an incomplete
measurement can be dismissed despite failing acceptance, or marked closed
after one unverified correction. The maintainer's stop rule does not authorize
either result.

Replacement for Cut 14's close-review portion of review_lifecycle:

> Workstream 31 receives one independent clean-context Type 1 close review of
> its whole diff, every acceptance item and the cost map. It verifies faithful
> implementation and contained scope and independently asks whether the inputs
> are right; a design concern returns NEEDS_TYPE_2. Under the maintainer's
> 2026-11-11 stop rule, findings receive one correction pass, with a further
> review round only for a wrong answer on a covered workload. That limit does
> not waive an acceptance item or convert CHANGES_REQUIRED to PASS: correction
> evidence is recorded, and any unresolved finding keeps the workstream open
> for maintainer disposition before Cut 15 or slice 2. A third correction round
> stops for maintainer disposition. Preserve findings, reviewed ranges and
> consequential rejection reasons under rfc_cycle.md's record rule.

Checked: Cut 13/14 and WS30/31 ticket text, LDG-3217/3219 evidence, WS16 family
and compact-state rules, interface Section 19, loop and harness code, parity
runner/workloads/checklist/mutation launcher, profile and feature runners and
committed CSVs, R-floor stage-2/fixed-cost sources and evidence, relevant
contracts, optimization style, benchmark method and governance rules. Read
production feature calculation to check the proposed comparison independently
of the cut's author. Ran one small R script that evaluates the existing verdict
expression and recomputes committed CSV aggregates; it writes only to the output
directory. Git status is clean. No tracked file was edited and no commit made.

Not checked: no timing window, new performance measurement, full suite, package
check, long parity run, private H1 execution or vendor-data inspection. No E:
or ledgr-research access. This is a design review, not certification of slice-1
implementation or of measurements that Cut 14 has yet to take.
