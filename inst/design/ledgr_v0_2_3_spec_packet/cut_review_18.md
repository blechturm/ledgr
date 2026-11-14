CHANGES_REQUIRED
Mode: Type 2 cut review, independently reviewed at 6ece42c8.

The cut is justified as a measured simplification before later slices. Its protected stages, fresh context, pin reuse and unchanged execution paths are appropriate. It needs the bounded corrections below before implementation: the reference is a narrower input than claimed, the inventory does not define complete coverage, and the proposed proof leaves gaps around removed checks, relocated faults and clock maintenance. These corrections follow existing authority; none requires a new maintainer decision about behavior.

Source paths below are relative to C:/Users/maxth/ledgr-wt/cut18-review. Citation aliases: tickets.yml and the interface mean inst/design/ledgr_v0_2_3_spec_packet/tickets.yml and lean_core_interface.md; contracts.md means inst/design/contracts.md; the pulse-plumbing synthesis is inst/design/rfc/rfc_lean_core_pulse_plumbing_v0_2_3_synthesis.md. Unqualified stage-2b source names mean dev/spikes/r_floor/stage2b/; loop.R, plan.R and loop_harness.R mean dev/lean_core/; loop_* parity files mean dev/lean_core/parity/. stop_state_patch.R/.txt are in dev/lean_core/parity/evidence/cut16/. Probe files and outputs are in C:/Users/maxth/ledgr-wt/cut18-review-out.

R1 (required): Qualify the reference and remove the unsupported attribution.

Claim: Stage 2b establishes record equivalence for its two fixed strategies and selected contract fixtures. It does not establish that its implementation keeps the lean context and external-return guarantees. Its time therefore cannot establish an attainable endpoint for this cut. Also, subtracting the name-check microbenchmark from the state cell does not identify the remainder as the value validator.

Evidence: tickets.yml:2239-2248 claims every guarantee; :2335-2337 calls the reference a ceiling. reference.R:93-107 uses a plain list and creates hold() over a variable reassigned in the same loop frame. It omits the class, lookup service and much of the context surface required by contracts.md:2260-2274 and interface Section 19.4 (:947-953). reference.R:121-133 omits some typed sizing checks. fixtures.R:80 compares refusal class membership; summarise.R:45-57 compares the reference's selected compact fields and selected public fills/equity fields, rather than every public diagnostic field or refusal precedence.

Probe reference_guarantees.R, output reference_guarantees.txt: a saved pulse-1 context has position 0 but hold() returns 1 after the next pulse. Sizing evidence with NaN requested_quantity is refused by the pin with ledgr_invalid_strategy_result ("Strategy sizing evidence contains an invalid typed value.") and accepted as DONE by the reference. These are extra probes, not changes to registered fixtures. The original two strategies do not expose these differences.

The numeric literals in measured_input do trace to committed evidence. numeric_audit.py / numeric_audit.txt recompute all 30 loop medians from 210 raw observations and check the quoted rounded cells, reference increments, helper price and aggregate clock deltas. However, tickets.yml:2282-2284's inference about "most" of the state cell has no separate measurement: stop_state_patch.R:5-14 and stop_state_patch.txt:1-2 measure only the name predicate; loop.R:496-514 and :820-833 contain other work in that cell.

Consequence: The input supports investigating these cells, but cannot classify their entire gap as removable forwarding or route an unmeasured remainder to package work. The cut must preserve guarantees that the faster reference avoids.

Exact replacement text for the first sentence of opening:

> R-floor stage 2b (dev/spikes/r_floor/stage2b, committed 5c3f9c4a) built a plain-R reference whose compared compact records match the lean loop for two fixed strategies; six fixtures additionally compare accepted records or refusal class membership. It is an attribution input, not a full context-service, external-return-validation or refusal-precedence oracle. Its plain-list context omits the lean lookup service and does not preserve a retained hold() closure across pulses. Cut 18 retains those guarantees and uses the pin and existing witnesses as its behavioral oracle.

Replace the state-name-check inference in measured_input with:

> LDG-3230's stop evidence measures the state patch's name predicate at 3.60 and 3.75 us per pulse. It does not separately measure ledgr_strategy_state_validate_value() or establish ownership of the rest of the state-update cell; LDG-3234 measures that remainder before routing it.

Replace decision (6)'s "Expected, not a gate" sentence with:

> The reference's 108 and 345 us per pulse are descriptive results for its measured surface, not an attainable endpoint asserted for this cut. Preserved context guarantees and pin-owned costs constrain the available simplification; LDG-3234 determines the actionable portion.

R2 (required): Define an exhaustive source census that the inventory checker can actually enforce.

Claim: Parsing the named functions alone misses per-pulse lean helpers and dispatch. "Every allocation site" also lacks an operational definition: an R parse tree cannot enumerate all runtime copies and allocations.

Evidence: LDG-3234 acceptance, tickets.yml:5748, names the stages, lean_context(), the P2 call path and lean_plan_pulse(). Per-pulse work also lives in run_loop() (loop.R:848-859), lean_state_patch() (:496-514), lean_ctx_helpers() (:184-194), feature_fn()/schedule_fn() (:385-395), lean_loop_add_sizing() (:869 onward), and planner helpers (plan.R:25-35, :66-124). Stage-body calls do not enumerate the bodies of those callees. The existing parse utility already distinguishes lexical function bodies (loop_edits.R:18-39, :54-58), so this is implementable with an explicit reachability census and reviewed dynamic edges.

Consequence: A script can pass with a complete CSV for an incomplete set of roots. It can miss the very forwarding work that scopes LDG-3235, or claim completeness over allocations it cannot identify.

Exact replacement for LDG-3234's first acceptance item:

> Freeze a source census at LDG-3234's closing commit. Its roots are run_loop(), E/P1-P5, context construction and the strategy/context read boundary, and lean_plan_pulse(). Recursively include every lean-owned helper and closure executed during a pulse, including context methods/helpers, state patching, record writers and planner helpers. Record package and user-code calls as boundaries; explicitly list and review dynamically resolved edges. Enumerate lexical call sites, including operators and replacement calls, and syntactic allocation/copy candidates under a committed rule list; do not claim to enumerate every runtime allocation. Each site has a stable file/function/parse-location identity and source line, stage cell, kind, owner/guarantee, disposition and routing in inventory.csv. The checker requires a bijection between this census and the CSV, rejects duplicate identities, and demonstrates rejection of an omitted helper site and an extra stale row. Keep the frozen census after simplification and cross-reference removed, changed and newly introduced sites rather than requiring deliberately removed sites to parse in the final source.

R3 (required): Complete the proof obligation for a check moved to debug.

Claim: The direction of decision (3) agrees with AGENTS.md and pulse plumbing. Its current acceptance proves only that an assertion can fire in debug. It omits the required producer-property tests and does not explicitly distinguish a trusted internal transformation from raw user data carried inside an internally constructed object.

Evidence: tickets.yml:2304-2308 names the producer and guarantee; :5766 requires a broken-guarantee debug witness. Pulse-plumbing synthesis:84-109 requires module tests, checks each user return, and preserves P5 state acceptance/normalization and its priority. Its R3 (:111-123) and Section 4 (:234-241) distinguish economic refusals from internal assertions, including overflow and finite/equality checks. R1 also preserves assertion classes and limits debug to assertions. interface Section 19.6:1050-1052 requires focused module-property checks for changed guarantees. The current gate has useful state-refusal and prefix witnesses, but one positive gate workload or one injected bad hand-off does not test the producer's output properties.

Consequence: An implementation could move an external or economic check under debug, or retain a debug detector over a producer whose guarantee has never been tested, and satisfy the written acceptance.

Exact replacement for LDG-3235's debug-move acceptance item:

> For each check moved to debug, record its precise predicate, original assertion class, producer, input origin, guarantee, and classification under pulse-plumbing R1-R3 and Section 4. Merely carrying a user-returned value through a lean list or stage does not make it trusted. Name the retained external-entry/user-return and R3 guards, including their acceptance point and precedence. Run focused producer-property tests in debug for the changed guarantee, covering its applicable empty, missing, boundary and overflow cases; identify existing tests reused and add missing cases under dev/lean_core/parity. A reached corruption must trigger the retained assertion with its original class in debug. Applicable external/economic negative cases must still produce the pin's class, message, stage, pulse and accepted prefix with debug off and on; use simultaneous faults where a changed boundary could alter precedence. Debug must change assertions only, with no arithmetic, ownership, callback-count or publication change. No production detector for an otherwise trusted module defect is required.

R4 (required): Tie simplification witnesses and re-anchored variants to the actual fault.

Claim: Existing witnesses give a strong baseline, but a passing variant driver alone does not certify preservation of the intended fault when an injection is rewritten. The cut also needs an explicit mapping from changed semantic hand-offs to detectors.

Evidence: loop_variant_changes.csv:2-11 already registers error-unwinding, parent-condition, retained-cache and live-position faults; loop_checklist.md:48-53 covers capacity and commitment. My unchanged four-workload gate sample passed at both debug settings: parity_debug0.csv and parity_debug1.csv each contain 58 identical table comparisons, four PASS verdicts and matching frozen paths. These witnesses should be reused.

However, loop_parity.R:424-433 accepts a reached marker plus its named broad signal, allowed messages and any matching differing table. For example, risk_not_applied (:163-165) names several economic tables; that test does not independently assert that the injected fault actually skipped the risk plan. loop_variants.R:63-74 validates manifest result keys, not the semantic content of the replacement injection. The three controls (:76-87) test unrelated errors, reach and store paths; they do not certify a newly translated fault. tickets.yml:2329-2331 requires the same intended fault, but LDG-3235:5764 supplies no additional evidence for that claim.

Consequence: A relocated mutation can remain CAUGHT through a different corruption while the original lost guarantee has no detector. A new forwarding simplification can also affect an obligation outside the existing witness's exercised reads or failure path.

Exact text to append to LDG-3235's first acceptance item:

> Before editing, map each changed semantic hand-off to its invariant or contract, its existing detecting witness and a reached fault that breaks that property. Add a focused witness and variant wherever the existing ones do not discriminate the proposed failure: dropped side effects, stale pulse data, changed callback/unwinding order, or moved refusal/precedence. Pure forwarding deletions may reuse an existing detecting pair; no duplicate witness is needed. For each re-anchored variant record the old and new file/function/anchor, injected operation and expected observable consequence. Preserve its workload, debug settings, batch bound and fault-specific expectations. Demonstrate that the translated injection produces the same faulty intermediate property and is caught for that consequence; a reached marker and an unrelated table difference are insufficient. Do not widen allowed errors or table patterns to obtain CAUGHT. Preserve the existing manifest and negative controls; a fault that cannot be translated remains an unresolved obligation.

R5 (required): Include the measurement maintenance that the cut mandates in its allowed file scope.

Claim: Decision (2)'s source restriction is appropriate for execution, but does not authorize the benchmark and stage-2b maintenance required by the same cut.

Evidence: tickets.yml:2294-2299 lists three execution files and their parity harness. LDG-3236:5782 requires a new shared timing protocol and :5784 explicitly requires moving lean_clocks.R anchors. Those files live outside dev/lean_core. Cut 15 corrected the same distinction at :1746-1749; Cut 16 explicitly includes measurement adapters at :1983-1985. stage2b/check.R:51-59 additionally refuses a commit touching stage2b that also changes files outside dev/spikes/r_floor.

Consequence: Faithful close measurement needs edits outside the stated scope. Mixing anchor maintenance into an execution commit would also fail the existing stage-2b scope checker.

Exact text to append to decision (2):

> This execution-file restriction does not exclude the following measurement and design work: the inventory and parity tools/evidence under dev/lean_core/parity; the cut18-loop-1 protocol, necessary shared timing adapters and records under dev/bench/timing; maintenance of stage2b/lean_clocks.R and its runner/checker needed for the unchanged measurement definitions and the new evidence destination; lean_core_interface.md Section 19; the rules ledger for a surfaced rule; and tickets.yml. Preserve stage 2b's historical reference, fixtures and original evidence. Commit stage-2b measurement maintenance separately under dev/spikes/r_floor so its existing historical scope guard remains meaningful. No benchmark-harness copy or package execution change is authorized. Any fifo.R or prepare.R interface adaptation must retain its internals and run the affected module's parity/property checks.

R6 (required): Make the final clocked arm prove that it measures the same computation.

Claim: Stage 2b's current checker can pass without checking the clocked loop's records. Moving anchors makes this a material close-proof gap. The rerun also needs resolved source/library identities and host evidence to be reproducible independently.

Evidence: run.R:113-118 saves records only for the lean and reference arms; summarise.R:43-57 compares those arms. check.R:27-34 compares parity/contract CSVs and only the row keys of timing/attribution tables. It never compares the final clocked computation with the plain one. The earlier probe merely prints that comparison (probe.R:98); it is not part of the close checker. lean_clocks.R:20-23 enforces one textual anchor occurrence, which does not establish the semantic scope of a moved cell. :68-81 has a fixed execution-source list. summarise.R:64-66 records power plan, R and collapse, but no source identity or process affinity.

My tiny clock_parity_probe.R independently saved both lean and clocked records on 4x30; clock_parity_probe.txt reports identical TRUE. This confirms the current small case, not equivalence after moving anchors or on both full descriptors. The reported 18/38 us is the difference of arm medians (summarise.R:42), including instrumentation effects and run noise; it is not a per-cell correction.

Consequence: The final performance record could describe a different clocked computation, mislabeled cells, or an incompletely loaded source set while its named checker still passes.

Exact replacement for LDG-3236's stage-2b acceptance item:

> Rerun stage 2b on both original descriptors into a new evidence folder, preserving its reference, fixtures and original evidence. Record the resolved final lean commit and hashes of every loaded execution source, the pinned library identity, R/dependency versions, exact command, active power plan and child-process affinity. Load every execution source used by the final fold, retaining pin preparation. Maintain a crosswalk from each original semantic clock cell to its final anchors and measured operations, with exact-once anchors and untimed reach checks; report a removed or merged cell explicitly. Save and compare plain and clocked arms' compact records, fold outcome/state and public result records on both workloads, and make a mismatch fail the checker. Retain the reference parity, contract and gutted-path checks. Exercise a clocked-output corruption and a missing/misassigned cell to demonstrate failure. Report unclocked overhead ratios and gross clocked cell measurements separately, with the aggregate clocked-arm slowdown and unresolved small cells; do not subtract that aggregate from individual cells. Retain raw observations and reproduction commands for both before and after records. These are measurement checks, not a new performance target.

R7 (required): Resolve the stop rule's conflict with mandatory forwarding removal.

Claim: The stop rule is not decidable from the inventory as specified. It mixes the cost of an existing site with a not-yet-implemented change's measured saving, and can stop at one low-saving item while later forwarding deletions remain.

Evidence: LDG-3234:5748 inventories keep and out-of-scope sites as well as changes; :5749 measures sites or groups, and :5751 reports expected savings. Decision (6), :2331-2334, stops at the "next inventory item" unless it is a forwarder or has a measured 0.02 saving. A site's current cost is an upper bound on deleting it, not a measurement of an unbuilt rewrite's saving. Decision (3), :2302-2303, says forwarders are removed. LDG-3230's earlier acceptance explicitly addressed unresolved estimates and exhausted lists (:5658), and its evidence (:5663) did not certify all remaining work below threshold.

Consequence: A kept invariant at the head of the inventory could end the work before actionable removals. Alternatively, a speculative estimate could be reported as measured evidence for stopping. The two-day alternative supplies a bound, but does not repair the other stop branch.

Exact replacement for decision (6)'s stop sentences and LDG-3235's corresponding acceptance item:

> LDG-3234 derives an actionable worklist from the complete inventory; keep and out-of-scope rows are excluded from that worklist. Classify a forwarder removal before timing: it removes only forwarding work, preserving evaluation count/order, error unwinding, ownership and the invariant/contract owner; a new computation or dispatch specialization uses the other-change rule. Work in measured cost order, skipping a non-forwarder whose supported upper bound is below 0.02 on every comparison shape, while continuing to eligible forwarding removals. Stop when no eligible forwarder remains and every remaining proposed non-forwarder has a supported bound below 0.02 on every shape, or after the two working days. Record the evidence for each skipped item, the remaining actionable list, and the working-day dates and active intervals. An unresolved estimate or exhausted list is reported to the maintainer and does not certify that all remaining work is below threshold. Preserve decision (5)'s separate keep/delete and regression rules; report any inherited paired classifier's unresolved result rather than turning a noisy median into a keep.

What I checked: the requested Cut 18/WS36 tickets, Cut 15 and 16 decisions and LDG-3230 evidence; the stage-2b charter, reference, clocks, runner, fixtures, summarizer, checker and committed CSVs; the stage and context/planner/harness code; parity driver, manifest/change/freeze machinery and checklist; macro WS16 compact-state points 1-8; interface Section 19; AGENTS.md; pulse-plumbing R1-R5 and property/prefix dispositions; relevant contracts and the optimization manual's rules and seven shapes. Independently executed the two reference counterexamples, four short frozen gate workloads in each debug mode, a one-pair 4x30 compare smoke, a tiny plain/clocked equivalence probe, numeric recomputation and the inherited source-role count. The count reproduces 1,039 code lines: 925 production and 114 debug, so the inherited line-budget rule is usable. Production work remains production when relocated; moving it into an uncapped harness/debug category is not a deletion.

loop_shortcuts.R:120-154 and :205-219 load each commit's complete lean source set into its own environment; :225-232 uses shared descriptors, which define all four required shapes (descriptors.R:15-61). The tiny compare completed with matching signatures and per-arm hashes. Its zero-resolution pulse clocks provide no performance conclusion. The compare driver emits raw paired savings, not a keep/delete verdict in compare mode (:289-307); acceptance must apply the stated rules to those observations. The 0.01 forwarder-regression allowance is coherent beside the 0.02 speed case for added computation, provided classification is established before timing and the inherited whole-cut regression rule still applies.

What I did not check: no full gate, full variant run, full test suite, package check, timing windows or long workload runs. I did not rerun the original seven-round stage-2b measurement or independently authenticate its historical P-core affinity. I did not inspect E:, ledgr-research or vendor data. The known open switch-census cases remain open; this review does not claim they are covered. No tracked file was edited and no commit was made.
