CHANGES_REQUIRED
Mode: Type 2 cut review of Cut 15 / workstream 32; independent fresh session, no implementation authorship.

Reviewed detached HEAD bd767d20bc8098b046c0fbc5267bd2fe88b1e86e. Repository citations resolve under C:/Users/maxth/ledgr-wt/cut15-review; probe citations resolve under C:/Users/maxth/ledgr-wt/cut15-review-out.

The cut is justified by the measured stage costs. The four serial tickets are a sensible split: P2, planner/FIFO, remaining recording/commit/valuation/expansion, then measurement. The cost-map cells have owners; strategy-owned computation, feature work and persistent writing are correctly excluded. The wording below needs correction before implementation. These are repairs to the proposed proof and measurement requirements, not a request for a new product decision or RFC.

1. R1 — required: define fast-path domains and preserve the shared kernels' existing proof surface.

   Claim: decision 2's “common case” and one variant per replacement do not establish the dispatch predicate or preservation outside the loop's exercised inputs. LDG-3223 also refers to FIFO and planner variants of a manifest that contains neither module's registry. Its blanket pin-fallback wording misdescribes the existing FIFO implementation.

   Evidence: inst/design/ledgr_v0_2_3_spec_packet/tickets.yml:1743, :4839 and :4846; dev/lean_core/parity/loop_variants.csv:1; dev/lean_core/parity/loop_variants.R:27; dev/lean_core/parity/fifo_parity.R:8 and :18; dev/lean_core/parity/fifo_check.R:43 and :52; dev/lean_core/parity/plan_parity.R:39. The loop registry has 128 rows and 23 variants, but its fill_price_ulp changes terminal publication, not FIFO arithmetic (loop_parity.R:76). The FIFO's six mutations and the planner's three mutations belong to separate runners. fifo.R:6 explicitly excludes calls to the pin's arithmetic; its tolerance fallback is its own general formula (fifo.R:41), not a pin call. boundary_probe.txt:19 confirms this distinction. The relevant rules are contracts.md:304 and :329, rule group #contract-execution-fold-carrier, and optimization_coding_style.qmd:331: differential testing includes the selection condition, refusals and ordering.

   Consequence: a shortcut can select correctly on all crossover runs but incorrectly on an untested boundary. A change to nonzero-fee arithmetic, opening/disposition handling, overflow or refusal order in the shared FIFO can escape a slice-1 gate whose other-feature workloads run on the pin. Debug comparisons on served gate calls and one easily caught mutation do not close that gap. Conversely, adding a production call from FIFO to the pin would violate its existing static-call proof.

   Exact replacement for decision 2:

   > (2) Every new or materially changed fast path names its exact dispatch predicate, the upstream guarantees it uses, its canonical comparator and its runtime fallback in Section 19's tuning paragraph. Registered differential cases exercise both sides of the predicate and its boundaries, with expected dispatch established independently from the pin and contracts. Compare complete results, ordering and refusal class/message/order exactly. In debug, compare each served deterministic computation with the canonical computation on independent input snapshots; do not execute user callbacks twice. Strategy-facing shortcuts delegate unchanged inputs outside their predicate to the pin. A specialization of the shared FIFO instead retains its existing general lean kernel as the runtime fallback; the pin remains its independent comparison oracle, not a new production arithmetic dependency. Each new path and each changed selection predicate has a reached variant demonstrating its intended fault. These are witnesses for existing behavior, not additional lean feature coverage; existing fixtures and oracles are not weakened.

   Exact replacement for LDG-3223's third acceptance item:

   > Preserve the loop manifest, including fill_price_ulp, and separately rerun the existing FIFO captured-call, generated-stream, ownership, input-refusal and six-mutation checks with debug off and on, plus the existing planner parity and three mutations. Name their runners and source/capture identities in the evidence; do not describe them as loop-manifest rows. For each new fast path add differential dispatch cases for admitted and fallback inputs, including empty/singleton batches, final-pulse rejection, invalid prices, insufficient cash, sell-before-buy order, tolerance boundaries, partial FIFO consumption and overflow where applicable. Preserve the complete book, applied rows, plan and refusal order; register a reached fault for each new path and changed guard. Retarget implementation anchors explicitly without changing the existing witnesses' inputs or expected behavior.

2. R2 — required: make error-handler equivalence include unwinding and the original condition.

   Claim: the proposed cheaper handler needs a proof at the callback's unwind boundary. An aborting calling handler is not equivalent merely because the current handler always aborts.

   Evidence: tickets.yml:4816 and :4824; dev/spikes/skeleton_floor/README.md:69; dev/lean_core/loop.R:549; R/fold-engine.R:835; R/backtest-runner.R:41. contracts.md:2548, rule group #contract-context-inspection, requires the original condition as parent. The gate's condition sink records class and message, not parent/original_error contents (dev/bench/v0_2_3_output_freeze/lib.R:299). Existing surface/backstop witnesses at loop_workloads.R:100 and :147 do not exercise strategy on.exit cleanup. Executing the pin's actual ledgr_abort_strategy_error in boundary_probe.R:18 showed cleanup -> wrapper with tryCatch, versus wrapper -> cleanup with withCallingHandlers (boundary_probe.txt:11). A deliberately mutable lookup probe then changed the wrapper's available-feature message from after_cleanup to before_cleanup (boundary_probe.txt:13). This is a mechanism counterexample, not a demonstrated defect in the unchanged fold.

   Consequence: a handler replacement can change when wrapping occurs or lose original condition data while passing all current witnesses. A handler around the loop must also distinguish the callback's dynamic extent from subsequent result validation; cur_stage alone remains “strategy” during those checks (loop.R:563).

   Exact replacement for LDG-3222's fourth acceptance item:

   > Strategy errors, callback coverage stubs and invalid results retain the pin's complete condition classes, message, original_error and parent condition data, wrapping boundary and refusal order. Add pin-versus-lean witnesses for a callback with on.exit cleanup, a cleanup that itself errors, and a custom error carrying additional data, observed by an outer handler. Compare cleanup/handler order and seeded and unseeded RNG state, as well as the final condition. The existing caught, rethrow, backstop and invalid-result witnesses remain unchanged. If handling moves outside P2, demonstrate that only errors escaping the callback are wrapped and that cleanup-time coverage marks retain precedence. Register faults for early wrapping and loss of the original parent. Do not replay the callback to perform a debug comparison. Retain the current exiting handler unless the replacement passes these witnesses.

3. R3 — required: the retained-context witness must test values that the proposed writes can mutate.

   Claim: “reads its fields and features” does not specify enough of the retained surface to prove the ownership requirement during context-build and state-write tuning.

   Evidence: tickets.yml:1749, :4823 and :4862; lean_core_interface.md:947; contracts.md:329, rule group #contract-execution-fold-carrier. The existing witness retains the first context but later reads only close, slow and entry_at (loop_workloads.R:113 and :121). The debug context comparison observes newly constructed contexts before the callback (loop.R:544); it does not revisit that strategy's retained values after later writes. The context includes a state view and closures over its lookup (loop.R:386 and :397).

   Consequence: retaining a fresh outer context while sharing and later mutating an asset-state vector or helper lookup can corrupt retained state or hold() values without affecting the three retained reads currently checked. A new witness that repeats only those reads would satisfy the ticket's present wording. Fresh allocation of the outer object alone does not prove immutable retained values.

   Exact replacement for LDG-3222's third acceptance item, also required after LDG-3224:

   > A gate witness retains an early context across later fills and state updates. Compare with the pin its retained positions, cash, equity, declared portfolio and asset state, hold()/flat() results, feature reads and lazy position-fact fields. Exercise both previously forced/cache-hit and previously unforced reads. Record the retained values on multiple later pulses; preserve any intentionally shared field's behavior exactly as the pin does. Register faults for a reused pulse lookup and for a later write through a retained state or position vector. Run this witness and its variants with debug off and on after context tuning and again after recording/commit tuning. Existing retained-context witnesses remain unchanged.

4. R4 — required: the per-ticket timing method must load a real previous-ticket arm, including planner and FIFO code.

   Claim: the cited final-comparison runner cannot perform the comparisons required by these tickets. Its baseline is hard-coded, and its two arms share the current kernels.

   Evidence: tickets.yml:1756, :4825, :4847 and :4868. loop_shortcuts.R:43 loads the current lean environment; :74 copies it into each arm; :75 reevaluates only loop.R and loop_harness.R. at_commit reads only those two files (:88), and final mode always names 4a3e08b8 (:93). boundary_probe.R:50 evaluates the actual make_arm definition without timing: both resulting arms share the same lean_plan_pulse and lean_lot_apply functions and their common original environment (boundary_probe.txt:21). The existing source commits do exist, as independently checked in audit_inputs.txt.

   Consequence: simply running --mode=final after LDG-3223 can show identical kernel performance in both arms because both use the new kernel. It also compares with Cut 13 rather than the immediately previous ticket. A planner/FIFO regression can therefore escape the proposed five-percent gate. Existing CSVs establish historical observations, not the required executable before arm.

   Exact replacement for decision 5, referenced by all three tuning tickets:

   > (5) Extend loop_shortcuts.R's shared comparison method with explicit base and candidate source identities. Before each tuning ticket, record its immutable base commit: Cut 14's accepted final code for LDG-3222, then the preceding ticket's closing commit. Load every lean source needed by each arm, including plan.R and fifo.R, from that arm's own identity into independent environments; use the same pinned package for both. Refuse missing source, unresolved commits or source-identity mismatch, and retain the identities and reproduction command with raw observations. A short untimed harness check must demonstrate that a planner-only change and a FIFO-only change affect only the candidate arm. Keep the seven alternating pairs, compilation, warm-up, fixtures, hooks, clocks, result-signature check, GC and host policy already specified. Report pulse-loop, complete-envelope and whole-run medians and paired observations on the three specified shapes. Apply the existing regression rule to these genuine before/after arms; an unresolved displaced-regression result is reported for maintainer disposition, not recorded as no regression.

5. R5 — required: correct the measured expansion input and retain unresolved cells as unresolved.

   Claim: measured_input understates expansion on two shapes and suppresses the E-advance resolution limitation.

   Evidence: tickets.yml:1721 says expansion is 0.06-0.07 seconds per run. results/cost_map/cells.csv in dev/bench/v0_2_3_lean_tuning_profile gives 0.059744 at :18, 0.352000 at :61, 0.123096 at :79 and 0.070175 at :29. Its E-advance rows at :49 and :72 have zero samples and unresolved estimates; summary.md:61 preserves that distinction. audit_inputs.txt independently rebuilds these values. The other nine four-shape cell vectors in measured_input reproduce after rounding.

   Consequence: the cost-order input for LDG-3224 understates expansion by about sixfold on 20 x 23,400. An unresolved cell cannot support a four-shape numeric cost or saving estimate.

   Exact replacement for “P1 8/11/11/26; E 1-2; terminal expansion 0.06-0.07 s per run”:

   > P1 8/11/11/26; E advance 1/unresolved/2/unresolved (no profile sample on the second and fourth shapes); terminal expansion, estimated seconds per run, 0.060/0.352/0.123/0.070 in the same shape order.

6. R6 — advisory: explicitly include the close measurement runner/checker extensions.

   Claim: LDG-3225's lean-only rerun and two-version summary require small measurement-code changes; the current tools implement a single result directory and both arms.

   Evidence: tickets.yml:4881 and :4886. cost_map.R:273 fixes arms to lean and pin; :284 checks their signatures together. summary_check.R:8 reads one fixed results/cost_map directory and :21 expects both arms. cost_map.R:231 also identifies wrapper samples using the current tryCatch stack, which must be revisited if R2's handler changes. The shared timing harness itself supports the proposed eight pairs and four shapes: timing/protocol.R:75 and :113; the protocol-specific shape registry is at protocols/cut13-loop-1/workloads.R:37.

   Consequence: a literal reuse cannot produce/check the requested lean-only, old-beside-new summary. Overwriting the old directory would also remove the visible Cut 14 comparison input; a stale stack classifier could move costs between cells while preserving totals.

   Exact replacement for LDG-3225's cost-map acceptance item:

   > Extend cost_map.R with an explicit lean-only selection and summary_check.R with explicit Cut 14 and Cut 15 result directories. Preserve Cut 14's committed CSVs, write the final lean rerun separately on all four shapes, and compare its result signatures with the recorded pin signatures. Check the attribution rules against the final call stacks, including any changed handler frames, using synthetic stack witnesses without timing. The updated summary places old and new cells beside each other with their source identities, sample counts and resolution labels; its checker rebuilds both columns and rejects a missing required cell, mismatched signature or stale/missing comparison input. Preserve the existing reconciliation and rejection checks. These measurement-tool changes are in LDG-3225's scope; dev/lean_core remains unchanged in that ticket.

Checked:

- Read Cut 15, its four tickets and workstream, Cut 14's tickets/evidence and both close-review records, WS16's family method and compact-state points 1-6, interface Section 19, the requested loop/planner/FIFO/harness/parity sources, freeze and variant manifests, cost-map/drill runners and CSVs, both floor READMEs, shared timing protocol and Cut 13 protocol files, AGENTS.md, relevant contracts and optimization rules including the seven shapes.
- Independently traced the inputs to executable owners and CSVs, rather than treating prior review acceptance as proof. Rebuilt all 32 cost-map clock medians from raw observations, checked all eight residuals against ten percent and one result digest per shape across arms/repetitions, and rebuilt the four-shape cell vectors. Inspected the drill shares against their frame/callee rows. Counted 106 frozen paths and 128 loop-manifest rows/23 variants, and distinguished the separate FIFO/planner registries. The floor numbers are historical lower bounds with omitted work, not matched speed ratios; their rounded skeleton and stage-2 figures are traceable to the supplied evidence/READMEs.
- Ran only short mechanism probes using the read-only d5b3a151 library: the real pin error wrapper under exiting/calling handlers, and the comparison runner's actual make_arm definition without running its timing loop. Ran summary_check.R: native R exit 0, 25 table rows checked, none missing, H1 sentence ok. R startup emitted locale warnings; the initial PowerShell redirected invocation reported a shell error from stderr, so the native status was checked separately. Probe sources/results are in this output directory.
- The keep rule has an existing paired protocol, denominator and resolution rule (loop_shortcuts.R:22). The one-day stop and lack of a speed target bound effort rather than guarantee an improvement; they do not waive parity, regression, budget or close-measurement items. The 1,000-line loop ceiling and 300-line production growth allowance are reasonable stop signals for this scope, with the existing role count. Preserve their reporting and maintainer disposition requirements. The 1.0-against-pin milestone record cannot substitute for R4's previous-ticket comparisons.
- No requested optimization inherently requires a behavior/API/format/architecture change. Fresh retained contexts agree with Section 19 and the ownership contract. A cheaper handler is permitted only if it preserves the pin's boundary; a deliberate change would trigger the family method's RFC rule. No need was found to reopen the five D3 census cases expressly assigned to the switch cut. Hook and commitment obligations remain applicable to fewer-write edits; passing final tables alone does not waive them.

Not checked: no implementation was written or approved; no timing window, full test suite, full gate, long parity run, full mutation run, new cost-map/drill profiling, package build/check, memory run or private H1 execution. Historical host conditions and timing truth were not remeasured. No E:, ledgr-research or vendor data was accessed. No tracked file was edited and no commit was made; git status was clean. Git's ownership refusal was handled with a temporary safe-directory configuration in the output directory, without changing user or repository configuration.
