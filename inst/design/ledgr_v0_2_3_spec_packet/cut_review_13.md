Verdict: NEEDS_TYPE_2

Reviewed detached `73e64d3a` against pin `d5b3a151`; `git diff d5b3a151 HEAD -- R` is empty. Repository files were not changed. Probe paths below are in `C:/Users/maxth/ledgr-wt/cut13-review-out/`.

1. **R1 — required. Section 19.4: reconciliation can stop an eligible run normally.** The claim that the only other exit is an error is false; slice 1 must preserve an `INCOMPLETE` prefix, not discard it or continue through P4/P5.

   Evidence: `R/fold-engine.R:1178-1204,2003-2006`; `contracts.md#contract-persistence-fold-evidence`. `boundary_probe.R` executes a cash-only, complete-bar, zero-cost fixed basket: first buy A at 1 and B at 1e16 with cash 1e16; next request selling both and buying C at 1e16. The pin stops in P3 with three explicit decision rows, no second-pulse fills/reconciliation, and status `INCOMPLETE` (`boundary_probe.txt:14-20`).

   Replace Section 19.4's last sentence with: “P3 can also return the pin's affordability reconciliation stop. E installs it with the same processed count, preserves the valued equity and accepted event prefix, records the deferred explicit decisions and stop row without certifying holds on that pulse, skips P4/P5, and publishes INCOMPLETE completion evidence. Add this workload to acceptance 1.”

2. **R2 — required. Section 19.2 decision 1 and acceptance 2: a sweep transaction does not roll back.** The memory handler retains writes on error, and even the durable envelope writes an exception after rollback; rollback alone does not produce a clean fallback attempt.

   Evidence: `R/output-handler.R:96-104,690`; `R/fold-engine.R:2064-2082`; `R/backtest-runner.R:846-858`. `review_probe.R` finds one retained memory diagnostic after a transaction error, zero durable transactional rows, and a public failed run with status `FAILED` and diagnostic 1 outside the transaction (`review_probe.txt`). Unseeded folds also have no envelope RNG restore (`R/fold-engine.R:1705-1712`).

   Replace the rollback/rerun wording with: “A missed call aborts the entire lean attempt. Durable transactional writes roll back; a memory candidate's handler and all its retained state are discarded. The harness reruns the complete public workload on the pin with fresh candidate state, or the same durable run_id through the pin's fresh-attempt cleanup, and restores the attempt-entry RNG state before retrying. Verify a late backstop after earlier fills, including an unseeded RNG draw, against a pin-only invocation.”

3. **R3 — required, NEEDS_TYPE_2. Sections 19.1 and 19.5 change logical publication, not just physical flushing.** One handler publication after the run conflicts with the accepted P4 acceptance/P5 publication protocol; maintainer acceptance of a cut note cannot amend that architecture implicitly.

   Evidence: pulse-plumbing synthesis R7/R9 and Section 5 (`rfc_lean_core_pulse_plumbing_v0_2_3_synthesis.md:147-178,263-268`) require accepted sequence/time boundaries and complete per-pulse commitment. Skeleton Section 2 separates planning, accounting and publication; macro Family method points 4-5 route boundary changes to an RFC. Compact-state point 4 authorizes one current-format diagnostic write and no in-loop DuckDB writes, but does not explicitly settle this logical-publication change.

   Replace Section 19.1's publication clause with: “Physical store writes occur after the loop. Whether slice 1 also defers logical P4/P5 publication is NEEDS_TYPE_2: reconcile the proposed whole-run handler call with pulse-plumbing R7/R9 and its failure-prefix protocol before coding.” Do not resolve that conflict merely by renaming publication “buffering.”

4. **R4 — required. Section 19.2 leaves supported inputs unclassified and untested.** In particular, `db_live` is neither covered nor refused despite its per-fill write contract, and the result-shape table omits ordinary `list(targets, state_update, intent_reason)` returns; mentioning a pulse seed does not specify ambient RNG behavior.

   Evidence: `R/backtest-runner.R:820`; `contracts.md#contract-execution-event-staging`; `R/fold-engine.R:847-860,1606-1629,1705-1712`; `contracts.md#contract-strategy-reproducibility`. These are reachable independently of costs, risk or missing bars.

   Add to 19.2: “Slice 1 refuses db_live before the first pulse. Covered strategy returns include the pin's numeric/ledgr_target and ordinary targets-list forms, intent_reason, and declared-state keep/patch/replacement/reset/default rules. Seeded and unseeded sequential RNG follow the pin's kind, stream and restoration rules. The context adapter preserves all current public fields, flat(), hold(), inspection and alias/concrete-feature resolution over the pin's prepared features; registration, feature_params and precomputed-feature preparation stay upstream. Add small parity/refusal witnesses for these cases, non-finite correctly named targets, retained uncached context fields, and max_pulses.”

5. **R5 — required. Sections 19.3-19.4 omit information required at retained boundaries.** The enumerated fill buffer loses the FIFO results needed for sweep legs, and the vector P3/P4 description omits the skeleton's required order-shaped handoff.

   Evidence: `R/output-handler.R:44-69,764-770` consumes `close_qty`, `open_qty` and `realized_close`; `dev/lean_core/fifo.R:412-414` produces them. Skeleton Section 2 (`:150-156`) requires instrument position, side, quantity, order type and timing. The combined-block probe gives identical events and legs when the applied FIFO columns are retained (`boundary_probe.txt:1-3`).

   Add: “Retain per-fill close_qty, open_qty and realized_close from the FIFO applied result for the memory sink's accounting facts; do not recompute realization during publication. P3 returns an explicit typed order-shaped handoff to P4, identifying position, side, quantity, market order type, next-open timing, resolved fills/rejections and carried economic effects. Fixed order/timing values may be shared constants.”

6. **R6 — required. Section 19.6's wrappers cannot prove that holds were never constructed.** Handler/writer interception observes publication, while rows can be built earlier and retained or discarded; that ordinary regression would pass the proposed construction check.

   Evidence: the pin already constructs decision columns upstream of the writer (`R/fold-engine.R:950-967`), with later clean-row selection (`:1268-1284`).

   Replace the structural-check clause with: “Wrap store-write boundaries during the loop to detect writes. Count calls/rows at the actual hold-expansion constructor and require zero during the loop; demonstrate the detector by moving one real hold expansion inside the loop. Retain the three registered parity mutations.” No general allocation monitor is needed.

7. **R7 — required. LDG-3219 omits surviving close obligations.** Timing reporting is sufficient under the amended gate, but the line budget, subtraction review, module-property checks and affected-owner check were not waived.

   Evidence: macro WS16 Family method point 3 (`macro_plan.md:823-833`), pulse-plumbing R1, and WS16's extension/observable-data bullets (`:750-765`).

   Add to scope/acceptance: “Record the maintainer's slice code-line budget before implementation. Time the rough end-to-end loop before hardening. Close records actual lines, subtraction findings, the five-scenario affected-owner check, and focused module-property checks for newly changed guarantees; run those checks debug-on and whole-run parity debug-on/off.” Keep one ticket: an early timing checkpoint provides the useful stop without a separate review unit.

8. **R8 — required. LDG-3219 scope contradicts its accepted context design.** “Through a reused context” permits the retained-view defect Section 19 explicitly prevents.

   Evidence: `tickets.yml:4471-4472` versus interface `:860-864`; `tests/testthat/test-flat-lazy-context.R:96-113` reads the saved context's previously unforced open column on later pulses.

   Replace “the unchanged strategy surface through a reused context” with “the unchanged strategy surface through a fresh pulse-frozen context per pulse”.

9. **R9 — optional. Measured input labels loop-only costs as including the full trace.** The numbers match, but reconstruction and durable writing are separate costs, and stage 3 is a different boundary experiment.

   Evidence: `dev/spikes/r_floor/evidence/timings_layers.csv`, trace_diff rows: 26.39/103.17 us loop, 0.18/0.28 s reconstruction, 0.08/0.10 s durable write; `parity_layers.csv` reports identical traces. Stage 2 uses reference `0d6c0b11` (`r_floor/README.md`), not the current pin.

   Replace the R-floor measured-input sentence and Section 19 starting-point parenthesis with: “R-floor stage 2 matched its 0d6c0b11 reference fills, equity, cash and reconstructed trace: loop-only 26/103 us per pulse, plus 0.18/0.28 s trace reconstruction and separately reported durable writes. Stage 3 separately supports fresh retained contexts; these figures are neither whole-run costs nor current-pin full-surface parity.”

Acceptance audit: item 6's prior Section 19 approval is already satisfied and cannot now discriminate implementations; “the close review passes” is a process gate, not an independent detector. Items 1-5 can fail. All three registered mutations can change decoded outputs on suitable covered durable workloads; no intrinsic blind spot was found in their exact table comparison. R6 identifies a separate structural-check blind spot.

Checked and found correct:

- The envelope entry/return list, ordinary error path and max_pulses completion omission match the cited pinned lines. Clean holds require exact equality and the additional codec conditions; sub-threshold differences remain explicit.
- Section 19.7 has no inherent handler/writer incompatibility: combined fill rows preserve IDs/order; one sufficiently sized diagnostic chunk preserves rows, coverage and summary. Position facts use fill transitions, the prepared absolute bar mapping and the retained book. Strategy-state rules are available in the pin; R5 supplies the missing retained leg data.
- P3 CSV medians reproduce 639→213 and 1,219→639 us/pulse, and whole-run ratios 0.86/0.92. Six diagnostic rebuild rows report exact traces; the later fractional evidence supports using book nets rather than summed deltas.
- One-worker candidates and the three constructed workloads were explicitly accepted. Fresh contexts preserve the existing contract. The amended timing gate reports rather than bounds; no timing threshold is missing.
- Named E/P1-P5, explicit coverage refusals, post-loop hold reconstruction and current-format writes implement the macro direction. Dev-only binding and unchanged R/tests/store format respect the frozen core and AGENTS rules. No extra tooling framework, worker expansion or separate rough-loop ticket is warranted.
