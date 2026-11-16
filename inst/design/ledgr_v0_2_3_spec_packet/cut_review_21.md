CHANGES_REQUIRED

Mode: Type 2 cut review; independent session, review tree supplied at dcc2fa9d, oracle d5b3a151.

The cut is necessary. Its two workstreams and its boundary with slice 5 are sound. Calling the package owners, selecting the marked path as decision 5 specifies, and keeping the current size limits are reasonable choices. The probe establishes useful attachment points, but its successful small cases do not establish a complete design. Independent executions found missing records, an incorrect refusal, incomplete committed-prefix reads and an unbounded terminal append. The cut needs the changes below before implementation. None requires reopening the maintainer's stated choices.

Paths beginning with inst/, R/ or dev/ below are relative to the review tree. tickets.yml means inst/design/ledgr_v0_2_3_spec_packet/tickets.yml. Review scripts, CSVs and dumps are in C:/Users/maxth/ledgr-wt/cut21-review-out. The executable review runner is review_probe_21.R, with cases in review_cases_21.R; final_details_21.txt summarizes their final executions. Earlier exploratory results are retained separately and are not the final cases.

R1. Required: distinguish a repeated freeze-entry transition from a frozen decision record.

Claim: LDG-3243's requirement for "no valuation_frozen row" on the first pulse of a carried frozen holding forbids a row the pin requires.

Evidence: tickets.yml:6747; R/fold-engine.R:522 emits only newly entered freeze transitions, whereas the decision restriction remains in the decision trace at R/fold-engine.R:937. The independent review_carried case reaches the pin through ledgr_walk_forward_experiment_with_opening() and ledgr_run(), without walk-forward orchestration. It opens on prepared day 5 with two FIFO lots, an entry anchor on day 1, a carried frozen holding and a pending entitlement for 7 units while holding 10. The pin finishes DONE, credits 3.5, exposes entry_price 32 and bars_since_entry 4 on its first decision, and later exposes entry_price 40 after selling five units. Its first pulse contains decision/recorded/valuation_frozen and no valuation/frozen transition (carried_route.csv; final_details_21.txt, CARRIED ROUTE ON PIN).

Consequence: a correct implementation cannot satisfy the literal absence predicate. A broad absence assertion would require deleting the frozen holding's decision evidence.

Exact replacement for LDG-3243's carried-freeze branch item:

> On the carried holding's first pulse, no row has stage = valuation, outcome = frozen and reason_code = valuation_frozen. Retain its decision/recorded/valuation_frozen row and the pin's mark metadata. Assert the carried lot quantities and prices through a partial sale that distinguishes FIFO lots from one average-price lot; assert the carried entry anchor through entry_at and bars_since_entry; and assert a nonempty pending entitlement whose bound quantity differs from the opening holding. Compare all pin tables. The frozen_opening_ignored variant must introduce the repeated valuation/frozen transition and be caught with debug off.

This route belongs in slice 4. The constructor is a package helper, not an exported public constructor (R/walk-forward.R:1142). The unknown-basis route also exists: setting the experiment's package payload field reaches R/sweep.R:1402 and :1746 in a one-worker sweep. My pin strategy buys one B when A's entry price is masked, against two B in the known-basis control (review_prefix0.csv and probe_details_21.txt). These tests need no new public API and no slice-5 orchestrator.

R2. Required: extend implicit-position reconstruction to P1 position changes.

Claim: porting dispositions also changes the inputs to the after-loop position reconstruction. Decisions 4 and 7 do not specify this change, and the probe's original acquisition fixture masks it with lifetime-restricted explicit decisions.

Evidence: dev/lean_core/loop.R:1211 reconstructs a hold from the initial carry and earlier fills only. The probe leaves that function unchanged. Its acquisition fixture removes the parent's bars and declares lifetime inactivity (dev/spikes/slice4_probe/probe.patch:916). In review_acq_marked, a scheduled cash acquisition disposes A on day 5 while A remains an ordinary visible member with current bars; an unrelated gap forces the marked path. Events, equity and metrics match, but six implicit decisions report target 10 instead of 0. Both debug modes miss the error; the two diagnostic tables differ (final_debug0.csv, final_debug1.csv). The final 70-instrument review_multi_pulse case reproduces it; batch one also retains it (final_batch1.csv).

Consequence: correct economic state can be published with false position/target evidence. A successful disposition followed by clean holds is outside the proposed proof even though it is inside the promised coverage. Section 19.5 requires exact recorded book nets, not a fill-only reconstruction.

Exact addition to decisions 4 and 7, Section 19.13 Records, and LDG-3247:

> The position history used for implicit records includes accepted P1 non-fill position changes as well as fills. Record exact installed book nets with their effective pulse and stage, so a P1 disposition affects that pulse's decisions and a P4 fill affects subsequent decisions. Carry those nets across terminal expansion ranges. Do not reconstruct this history solely from fills or by summing position deltas. Add a scheduled disposition with no lifetime fact, current parent bars, and subsequent clean holds; repeat with another fill before or after it and at batch one. Assert zero post-disposition implicit targets, quantities and positions, with every pin table identical in both debug modes. Add a reached nonfill_position_history_ignored variant caught by the implicit and decoded diagnostic tables with debug off.

R3. Required: capture must preserve append acceptance before installing settlement state.

Claim: a capture handler that only stores rows postpones a production refusal that the pin raises inside append_event_rows(). Strictly increasing event_seq at final publication is insufficient.

Evidence: tickets.yml:2946-2954; R/output-handler.R:666 and :699 validate before appending; R/accounting-replay.R:88 and :174 reject non-finite accounting deltas. R/corporate-action-settlement.R:490 appends before changing cash, and R/terminal-outcomes.R:213 appends before returning the candidate state. The probe's capture merely saves frames (probe.patch:56). In review_cash_overflow, finite public inputs (10 entitled units, a validated gross dividend of 1e308) overflow their cash delta. The pin refuses with ledgr_invalid_accounting_event/ledgr_invalid_ledger_meta at valuation. The probe installs the effect and later fails with ledgr_config_non_finite at accounting (capture_acceptance.csv; final_details_21.txt, OVERFLOW ACCEPTANCE).

Consequence: the proposed replacement can change refusal class, message, stage and precedence and run later work after a rejected settlement. This is a reachable input refusal, not an internal debug assertion.

Exact addition to decision 4, Section 19.13's capture paragraph and LDG-3244:

> The capture append is the in-memory acceptance boundary. Before accepting rows or allowing the caller to install returned settlement state, call the package's accounting append validator with the current mixed-event sequence and timestamp boundary. Advance that boundary only on acceptance, including accepted fills; preserve the original condition and valuation-stage attribution on refusal. This validation remains in production. Reuse its owner rather than copying its predicates. Add the finite-input dividend-overflow witness, comparing the pin's condition classes, message, pulse, stage and rolled-back output with debug off and on. A capture_validation_deferred variant must reach this input and fail on that refusal difference. Final transfer validation does not replace this boundary.

R4. Required: include openings and P1 rows in committed-prefix reads at their own boundaries.

Claim: decision 4 describes final publication but leaves the running fold's committed-prefix reader on its old fill-only implementation.

Evidence: dev/lean_core/loop.R:350 exposes n_committed and materializes only fill records; the probe does not change it. D3's P1/opening/non-fill row expressly requires visibility without waiting for P5 (inst/design/rfc/rfc_diagnostic_records_v0_2_3_synthesis_d3.md:301). In a one-worker sweep with no opening positions, review_prefix_sweep_bought buys B and later earns a dividend. At the day-4 strategy call the pin's memory handler exposes two events and the probe's reader exposes one. All ordinary result tables match; only the additional prefix_reads table fails, in both debug modes (final_debug0.csv, final_debug1.csv; final_details_21.txt, COMMITTED PREFIX WITHOUT OPENING). With an opening holding the reader is already one event short on the first strategy call (review_prefix0.csv).

Consequence: the original gate's prefix witnesses can pass because they have only fills. Final table parity does not establish the mid-run commitment contract.

Exact addition to decision 4 and LDG-3244, extended to dispositions in LDG-3247:

> Extend the committed-prefix reader to the pre-loop opening boundary, each accepted P1 cash/disposition append, and accepted fill ranges. Reads return exactly the accepted mixed prefix with original event_seq and rows, without a sink call or store write. Non-fill acceptance is visible before that pulse's strategy call, including on a pulse that later stops. Keep the fill-only capacity population and its P5 acceptance boundary unchanged. Add memory-prefix observations before strategy and at reconciliation on dividend and disposition workloads, with and without openings, and on a later stop. Compare counts and full event digests against the pin. Add a nonfill_commit_late variant caught by prefix_reads even when final tables match.

No additional handler read was found in the package's plan or terminal posting methods: they use append_event_rows(). The fold's P5 flush/count operations and its existing read witnesses still need this in-memory replacement.

R5. Required: specify and prove a truly empty context, distinct from empty membership.

Claim: "empty public domain (no member)" in decision 7 conflates two states, and the proof does not bind the empty-domain record or transitions through zero context cells.

Evidence: tickets.yml:2990; contracts.md:1333 distinguishes empty Daxis from empty M with held nonmembers. The provider builds unique(c(members, held_nonmembers)) at R/availability-provider-prepared.R:522. R/fold-engine.R:927 emits one empty_public_domain row on a deciding empty context. In review_empty_return, context A shrinks to empty on days 4-6 and grows to C on day 7. The pin calls the strategy throughout, retains portfolio state and gives C its asset default. The probe loses three empty_public_domain rows, shifts later sequences and counts 17 decisions against the pin's 20; debug on instead fails its gross-exposure comparison on the first empty pulse (final_debug0.csv, final_debug1.csv; final_details_21.txt).

Consequence: the cut could accept an empty-axis target while omitting its contracted evidence, dropping portfolio state, carrying departed asset state, or incorrectly treating held nonmembers as an empty portfolio. A context-length predicate alone does not distinguish these failures.

Exact replacement for decision 7's last sentence and the corresponding Section 19.13 bullet; add to LDG-3246:

> Empty context means zero decision-axis instruments, not zero members. On a deciding empty context call the strategy, accept the pin's named zero-length target forms, preserve portfolio state, align asset state to the empty axis and emit the pin's one empty_public_domain decision row with its logical sequence and summary contribution. With no members but held nonmembers, retain those holdings on the context and apply the ordinary holding/target rules. Test both states. Include a context that shrinks through zero and grows again, with an entrant and a re-entering departed ID; assert their defaults and portfolio-state continuity through recorded strategy reads. Also test a noncontiguous strict subset of the run axis with distinct bar/feature/history values, clean fills and holds, so context ordinal differs from run position. Assert exact decision_seq and decision_order, fill/rejection mapping, and absence of decisions or fills for non-context IDs. Retain a context and read it after a later context change. Add empty_domain_row_dropped and outside_context_actionable variants; catch them and the four existing context/state variants with debug off by their intended records or conditions.

The decision_order formula itself agrees with the pin (R/fold-engine.R:1330). It needs a fixture containing actual implicit rows on that strict subset; an empty matching set must fail.

R6. Required: make the debug cash check independent of omission of the plan call.

Claim: comparing installed state with a returned plan state detects a missed installation, but does not by itself detect the probe's original fault: never calling post(). The comparison can disappear with the omitted branch, or compare unchanged state with itself.

Evidence: tickets.yml:2997-3001 and :6769 promise that corporate_action_dropped is caught by this check. The original silent dividend loss is recorded in c_corporate_debug1.csv: cash 10005 against 10000 and one missing CASHFLOW. No proposed acceptance item distinguishes omission of post(), omission of installing its cash result, and loss of a captured event after correct installation. These faults have different detecting signals.

Consequence: a variant may be CAUGHT by ordinary table parity with debug on while the new debug check remains ineffective. The stated acceptance requires the check itself to detect the loss.

Exact replacement for decision 9's first two sentences and LDG-3244's debug-variant item:

> At every entered P1 with an execution corporate-action plan, debug verifies exactly one post invocation and that its returned state was installed before valuation; after each disposition call it likewise verifies installation before the next view. The expectation must survive omission of the production call or installation, using a per-pulse unset result/call witness checked independently of that branch. Compare cash, run-axis positions and the lot book without replaying a second mutable plan. Keep all assertion machinery debug-only. Define separate reached faults for omitting the post invocation and for omitting its nonzero cash installation. With debug on each must raise the named settlement assertion at that pulse before a later generic error, and with debug off each must differ from the pin's economic tables. Separately drop or duplicate a captured corporate row after correct state installation and require the corresponding event-table difference; do not claim the state assertion detects those publication faults.

Also replace measured_input's facts-refusal sentence with this traceable statement:

> With the fact-family refusal lifted, s4_halt stops at the execution-view debug check on pulse 3. In e_facts_debug1.csv, s4_terminal instead silently misses its disposition (day-7 cash 9846.25 against 9546.25); the acquisition and v201 rows do not record that debug error. These are separate failures requiring separate checks.

The committed e CSV supports the halt claim, not the existing sentence saying halts, delistings and acquisitions all stop at pulse 3 (input_audit_21.txt).

R7. Required: bind the remaining policy routes and P1 precedence combinations to witnesses.

Claim: "port everything" is broader than the feature list and proof in decision 10. Listing subtypes and generic terminal outcomes leaves several reachable routes and the stop/disposition precedence unowned by a specific acceptance check. The restricted-target condition's reason token is also transposed in the brief.

Evidence: contracts.md rule groups contract-config-policies, contract-availability-affordability, contract-availability-valuation and contract-result-corporate-actions; R/corporate-action-settlement.R:154-166 admits incomplete and unknown subtypes to the quantity route, :194 handles next_open, :201 handles late knowledge, and :436-491 distinguish unheld/no-op, report-only, refusal and cash posting. R/terminal-outcomes.R:15-112 distinguish all terminal choices, frozen fallbacks and the scheduled-evidence barrier. P1 short-circuits a cash refusal before quantity checking at R/fold-engine.R:383; stops a blocked scheduled disposition before lifetime resolution at :416; refuses the entire lifetime group before posting any of it at :435; and re-reads after successful dispositions at :425 and :504. LDG-3247:6828 names only generic outcomes and a disposition plus valuation stop. The probe's reach_pin.txt does not establish these combinations. R/availability-economics.R:277 sets reason = restricted_target on ledgr_restricted_target; target_restricted is the logical view column, not that condition reason (tickets.yml:3017 and :6808).

Consequence: a copied stop dispatcher can return the wrong reason or exposure, dispose an otherwise eligible member of a blocked group, count a stopped pulse, or discard already accepted P1 effects while still passing the isolated happy-path cases. Policy inputs can be omitted from wiring without any fixture noticing.

Exact additions to decision 2's coverage list and decision 10/LDG-3244, LDG-3246 and LDG-3247's workload acceptance:

> Coverage includes held and unheld incomplete/refused corporate facts and unmodeled subtypes, including report_only, refuse and no-effective-clock reporting; effective_close and next_open cash posting, including late knowledge and a no-op/unheld cash row; quotation_only, status_unknown and status_unknown_or_conflicting restrictions; and the last_permissible, last_mark, write_off, haircut and refuse terminal choices, exact-label/default matching and the three frozen fallback choices. Package owner tests remain their semantic oracle; small integration witnesses prove these routes receive the correct inputs and their resulting rows/conditions reach the lean output. Combine cases where useful. Assert source/source_fact_id and policy/choice/basis/late-arrival fields as well as reason codes. A CASHFLOW predicate must select corporate_action_cash, not opening_position.
>
> Replace the restricted-target expectation with condition class ledgr_restricted_target and reason = restricted_target. Compare its class vector, message, reason and affected instrument_ids against the pin; target_restricted remains the view column. Quantity-effect witnesses assert the pin's report-only/refuse behavior and unchanged recipient positions.
>
> Freeze the pin's P1 precedence with collision witnesses: cash refusal together with a due quantity refusal; scheduled disposition blocked while lifetime policy would otherwise dispose; a lifetime group containing both disposable and blocked holdings; successful P1 cash and disposition effects followed by a valuation stop in another holding; and a normally completing pulse containing cash, a plan disposition, a lifetime disposition and fills. In the stopped cases assert exact reason/reasons and affected IDs/exposure, accepted event and diagnostic prefixes, processed/full_run and both clocks, with no stopped-pulse equity or P2-P5 effects. In the blocked lifetime group assert no partial lifetime disposition. Prove view re-read removes a disposed nonmember from that pulse's context. Assert the initial entitlement boundary and the next boundary after P1 dispositions but before P4 fills, including a skipped decision pulse, with quantities that distinguish wrong placement. All match every pin table with debug off and on.
>
> Register reached precedence faults: allowing lifetime fallback after a blocked scheduled disposition, posting the disposable subset of a blocked lifetime group, and binding entitlement after fills. Catch each by its specific condition, event or entitled-quantity consequence. Terminal-stop and disposition-skipped variants remain required.

Decision 6's high-level order agrees with the pin when these conditional returns and re-reads are preserved. This is completion of its proof, not a new economic order. Policy choices stay in the package owners.

R8. Required: exercise and bound the new buffers and publication paths, and preserve existing variant obligations.

Claim: "grown by doubling" and "spanning terminal batches" do not force growth after a nonempty prefix or splitting of a single multi-row captured block. Existing mutations also need recorded re-anchors when their implementation moves.

Evidence: decisions 4, 7 and 11-12 at tickets.yml:2948, :2983 and :3034; LDG-3244:6771. In the final review_multi_pulse case, 70 simultaneous dividends, a scheduled disposition and fills reach the pin in the same pulse. The probe publishes a 70-row captured block under --batch-rows=1 (final_batch1.csv, max_append_rows = 70). Its original small dividends never establish that bound. Context storage is new and therefore has no existing growth witness. The required unified stop helper removes the location patched by valuation_stop_counts_pulse (dev/lean_core/parity/loop_parity.R:222); the position-history change also affects existing hold/prefix witnesses. Cut 19 already used recorded re-anchors and genuine prefix-loss faults, rather than weakening their oracles.

Consequence: a correct small-fixture result can lose old records during growth, exceed the terminal memory bound, double-publish a tail or make an old mutation impossible to apply. A marker at entry to a growth-capable helper does not prove growth occurred.

Exact addition to decisions 10-11 and the close acceptance of LDG-3245/LDG-3248:

> Exercise each new growth branch after a nonempty prefix: captured-block storage and typed context-position storage, plus any new position-transition record. Report used and allocated capacity and prove the old prefix, incoming rows and typed columns survive. A small direct witness may lower initial capacity without changing a registered workload's setup or oracle. Lose an already written record at actual growth in a reached variant and require its intended output difference.
>
> At batch one, include a single captured block longer than the bound, simultaneous actions on several instruments, cash/disposition/fill interleaving, and a trailing non-fill block after the last fill. Bound every terminal append and expansion range, split captured blocks as well as fill blocks, and transfer each accepted row once in original event order. Repeat the mixed case with inert hooks and both debug settings. A reached nonfill_block_unsplit variant must fail the append-bound detector; a duplicated captured tail must fail event parity. No per-event R loop is introduced at publication.
>
> Record every surviving variant's changed anchor in loop_variant_changes.csv, preserving its fault and intended consequence, including valuation_stop_counts_pulse after stop unification. No existing row is retired merely because its code moved. The effective driver must report each required row CAUGHT and keep the three negative controls failing closed. slice4_reach_cross.R has an explicit required workload/predicate list, refuses missing pin dumps or predicates, requires nonempty own-case evidence and a false result on another workload, and checks these growth, ordering and prefix cases as well as the feature routes.

The existing source/role count and seven-shape walk remain appropriate. The 300-line allowance remains a stop signal; these proof requirements do not authorize exceeding it or hiding execution code in harness files.

R9. Required: specify the mixed workloads' exact path moves, including their lean fold counts.

Claim: the six existing workload names in decision 10 are complete, but "now refused at slice 5" is not an exact expected path. Three of those workloads now execute four lean folds as well as refusing their slice-5 portion.

Evidence: tickets.yml:3028-3033; independently compared k_gate_debug0/1.csv with the effective loop_freeze.csv plus loop_freeze_changes.csv (input_audit_21.R and input_audit_21.txt). Both modes have exactly six existing gate-row moves. dense_risk_features, avail_terminal_resume and walk_forward each move from zero to four lean folds. Their refusal strings narrow as shown below. The original frozen values have zero folds and still include opening positions and imports.

Consequence: retaining zero folds and falling back more broadly can preserve every output table and fit the prose while failing the intended coverage expansion. Freezing such a candidate would bless the missing slice-4 execution.

Exact replacement for decision 10's existing-row move sentence, referenced by both closing tickets:

> Against the effective freeze at 381c0d0c, the final gate changes exactly these existing rows at each debug setting (backstop stays empty): dense_dividend_state: 0 folds, corporate actions -> 4 folds, no refusal; avail_acquisition: 0 folds, corporate actions -> 4 folds, no refusal; prep_fixture: 0 folds, opening positions and imports -> 1 fold, no refusal; dense_risk_features and avail_terminal_resume: each 0 folds, opening positions and imports; sweep workers -> 4 folds, sweep workers; walk_forward: 0 folds, opening positions and imports; walk-forward -> 4 folds, walk-forward. These are twelve existing gate-row updates across debug 0 and 1. Record exact intermediate workstream paths separately before running that workstream's freeze check; do not require the final facts lift at the no-facts close. Register every new workload/mode/debug row and enumerate batch-one and inert rows separately. Reject any other existing-row change. Apply and audit changes through loop_freeze_changes.csv.

Checked: the requested Cut 21 and Cut 19 briefs, acceptance/evidence and Cut 19 review; interface Sections 19.2, 19.4-5 and 19.10-13; the named loop, marks, harness, loaders, freeze/variant/reach machinery and hashed-frame obligations; the pin's P1, P2/P3 context, P4 entitlement and P5/state paths; corporate-action, terminal, position-fact, provider, opening, sweep and walk-forward input routes; the relevant contract rule groups, macro WS16 order, deletion-readiness seed, D3, AGENTS.md and optimization shapes. The read-only patched loop, marks and slice-4 workload blobs match probe.patch's new blob IDs (final_details_21.txt). Independent small executions are described above, including debug off/on and the targeted batch-one case. Early fixture-construction errors returned PASS* without a fold; those were corrected and are excluded from the final evidence.

Checked numerical inputs: j_all_debug0/1 each contain 16 workloads and 362 identical table comparisons; k_gate_debug0/1 each contain 121 workloads and 2,038 identical comparisons, with 104 PASS, one PASS* and 16 PATH. The ten additions and six existing-workload moves reproduce. Patch counts reproduce +261/-88 for loop.R and +21/-6 for marks.R. The missed-dividend cash and event difference is traceable to c_corporate_debug1.csv; the pulse-3 debug error is traceable only to the halt row in e_facts_debug1.csv, corrected in R6. The 982-line baseline is recorded in Cut 20's lines.csv. The line budget is decidable using the existing role count across all lean execution sources; the timing obligations are decidable using the named shared protocols and Cut 15/18 comparison rules. They are future final-code gates, not evidence supplied by the probe. No new timing claim is made here.

Not checked: a Cut 21 implementation, which does not exist; full gate or variant-driver reruns; timing windows, package tests/checks or long runs; exhaustive policy combinations or public API combinations. Several missing policy/precedence witnesses in R7 were identified from their existing owners and contracts, not independently executed in every combination. The carried and unknown-basis executions establish reachable pin inputs; the probe still refuses them, so their lean parity remains to be implemented. No tracked file was edited, no commit was made, and no vendor or E: data was used. All review writes are under cut21-review-out.
