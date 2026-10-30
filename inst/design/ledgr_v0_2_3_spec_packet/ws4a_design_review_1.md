# LDG-3162 independent design review 1

- Reviewer: Codex, independent clean-context reviewer; not the note's author.
- Date: 2026-10-30.
- Mode: Type 1 against the accepted synthesis and draft cut; Type 2 scrutiny of the note's evidence-method choices only.
- Reviewed commit: `c4c39a8e65db37f1d84ef4abc3edbec5e7af45d7`, `release/v0.2.3`.
- Verdict: **CHANGES_REQUIRED**.

The note does not yet satisfy LDG-3162. Several controls cannot establish their assigned claims; C8 specifies the wrong failure boundary, C13 conflates two different contracts, and the memory method does not measure the stated quantity. The accepted architecture need not be reopened to correct these findings. Completion requires a corrected clause/test census and validated evidence specifications, so this is not PASS_AFTER_PATCHES.

References below are repository-relative. `Note` means `inst/design/ledgr_v0_2_3_spec_packet/ws4a_carrier_design.md`; `Cut` means that directory's `tickets.yml`; `Synthesis` means `inst/design/rfc/rfc_typed_fold_carrier_v0_2_3_synthesis.md`; `T/` means `tests/testthat/`. Line numbers refer to the reviewed commit. Quoted patches are replacement/addition text for the note, not authorization to change another file.

Read-only review: inspected the note, synthesis, cut, governing contract groups, source, tests and shared timing implementation. No suite, timing, package load, or product execution ran. One successful small R inspection confirmed installed `ps` 1.9.3 exposes `pagefile`, `peak_pagefile` and `mem_private`; its first invocation failed from command-line quoting. Neither invocation wrote repository output or called `pkgload::load_all()`.

## Required findings

### F1. The consumer map is an index, not the required per-consumer census

Evidence: Note:24-48 combines plan/fill/rejection, lot input/applied row and timing/telemetry; the entire external book census is one row with consumer "same". Note:33 has no code citations. Cut:1104-1108 requires stage, file:line and adapter/direct for each producer/consumer. All named source-table external consumers appear in Note:36, but their individual edges and adapters do not. Note:45 cites the eventual inline summary but omits the intervening leg-buffer consumers (`R/output-handler.R:196-283,600`), which materialize its `inline_fills`. `to` and `cas` are undefined aliases. Note:53 leaves the settlement adapter's remover as "WS4b or WS8".

Why it matters: a reader cannot determine which boundary remains named, which reads become positional, or who removes each transitional adapter. This is an acceptance gap even where the underlying file range is real.

Exact patch: replace Note:24-26 with:

> The table below is the group index. Its consumer census must give each edge a separate row with group, producing stage/function, consuming stage/function, file:line, direct or named adapter, implementing ticket and (for transitional adapters) one removing owner. Split the combined plan/fill/rejection, lot input/applied row and timing/telemetry rows. The external book rows are replay, chunked fills, run opening/resume, sweep opening/resume, result replay, walk-forward carry/as-of, dispositions, recovery, handler accounting facts and compiled pack/unpack, individually, using the ranges below. The unchanged slots require their actual E/P1-P5 write/read sites rather than "as Phase 5.1". This census is not complete until those rows are present and checked.

Replace the leg consumer cell with `memory sink stage_leg/add_leg and flush_legs (R/output-handler.R:196-283, :600), then inline_summary (:313-351) and retained fills/trades`. Expand `to` to `R/terminal-outcomes.R` and `cas` to `R/corporate-action-settlement.R`. Replace `WS4b or WS8` with `WS8 (non-fill accounting boundary); WS4b removes only the provider/valuation adapter`. This last assignment follows Synthesis:380-387; it does not authorize moving non-fill semantics into WS4a.

### F2. The register does not enumerate indivisible obligations or unique owners

Evidence: Note:170-172 and :220 assign multiple implementing tickets; :222, :225 and :226 collapse whole sections/scenarios. `n/a` remains at :201, :218 and :227. Missing explicit obligations include Section 2's configuration/snapshot/dependency identity and release deliverables (Synthesis:78-80), Section 3.1's locked environment and validation after callbacks/deserialization (:91-102), and Section 4's empty-group typing and per-field missingness (:248-308). A generic D14 description does not enumerate these clauses. Cut:1113-1128 expressly demands one implementing owner and affected producers/consumers per obligation.

Why it matters: the claimed completeness cannot be audited, and a passing check for one clause can hide an untested sibling clause.

Exact patch: replace Note:153-157 with:

> Each register row names one indivisible obligation, its exact synthesis clause, affected producers/consumers, one implementing ticket, one check and a control that fails that check. Split R3.1e by constructed group: 3164 book/positions/import/replay/compiled ownership; 3165 observation/decision; 3166 execution view/plan/fills/rejections; 3167 publication/legs; 3168 diagnostics/equity/stops. Split R3.1f, R3.1g and R4.2 on those same boundaries. Verification at 3169 is a cross-reference, not another implementation owner. Give every Section 4 field invariant and Section 5 evidence row an explicit entry. Add locked-environment, callback/deserialization validation, identity/dependency and release-deliverable entries. Gates use deliberately invalid records as controls; review gates use a deliberately omitted stage explanation. No row uses "per group", "Section 4" or "n/a" in place of a check/control.

Replace R8.x with individually identified routes, all verified by 3169: `WS4b provider/valuation adapters; WS4b selective diagnostics; WS4b H5 JSON; WS4b/WS5 state normalization/serialization; WS5 intent JSON/typed declared state; WS6 context frames; WS7/WS8 metadata preparation/read architecture; WS7/WS8 non-fill builders/evidence; WS7/WS8 fill/non-fill JSON including db_live; WS7/WS8 memory meta/aggregate auxiliaries/store change; cold stop/exception encoding; JSON cache last-hot-caller retirement; compiled-envelope native state; WS5 D2 transitions/provenance with no WS4a D2 slots/schema`. Each route uses a named-boundary diff plus its relevant output witness, with a deliberate change to that boundary as control. Split R9.1-R9.7 into seven rows; S6 must reference F8's new capacity/stop case, not C17. Reconcile this expanded register before claiming completion.

### F3. Several detectors do not observe the violation assigned to them

Evidence: R2.5 at Note:165 uses finalization-route D10 to detect restoring an accumulator; route selection can remain correct with two accumulators. R3.2e at :178 uses a dense-builder hash to detect P3 history access. R3.4f at :197 assigns a no-cash-in-kernel predicate to a combined obligation that also requires replay to apply published effects exactly once; that predicate does not detect double application in replay. R4.3 at :221 says renumbering a token must fail output oracles, although consistently changing an internal code and its decoder preserves every output. D2 at :339 measures length, which remains constant even if a full preallocated block is wrongly retained. D20 at :357 freezes routed files/symbols although WS4a necessarily changes mixed functions in those files (Synthesis:184-193, :380-392).

Why it matters: these are false-negative controls, not just imprecise wording. They permit violations while their named checks pass.

Exact patch: add after the detector table:

> D10 additionally counts equity writers and inspects fold/service slots: both producers write exactly one record and no accumulator remains. R3.2e uses the phase-ownership checker on P3-P5 history/substrate access, with an injected P3 read. R3.4f adds a replay cash witness that fails when a published delta is applied twice. R4.3 uses literal dictionary/code fixtures, separately from round-trip diagnostic-byte checks. D2 checks used count returns to zero at each drain, verifies only the used prefix is handed out, and rejects retention of prior pulse staging even when capacity is constant. D20 protects individually enumerated routed operations and semantics, not whole mixed files or functions that this cut is required to migrate. Each detector names the exact functions/AST regions it examines, and demonstrates its own failing control; a different detector's failure is not evidence for it.

### F4. Dictionary pins omit decision restrictions and over-encode character fields

Evidence: Note:83-92 pins only P3 reasons. Synthesis:274 also requires a decision-packet restriction segment; `R/availability-economics.R:171-185` adds `valuation_frozen` after provider restrictions (`R/availability-provider.R:241-265`). Note:89-103 proposes dictionaries for carried IDs/terminal labels, but Synthesis:275 declares terminal_event/lifetime_fact_id character. Note:98 says `write_off` occurs only in meta, while `R/fold-engine.R:489-495` copies that mark source into disposition diagnostics. The P3 reason ordering, mark-source packet values, locator row/column and cash-effect formulas otherwise agree with the cited code; no cash arithmetic correction is warranted.

Why it matters: a valid frozen holding cannot be encoded by the supplied restriction dictionary, and broad open-vocabulary encoding silently changes the bound field types.

Exact patch: append to Section 2.1 and replace its open-vocabulary bullet:

> Decision-packet restriction codes have their own pinned levels: 1 trading_halted, 2 quotation_only, 3 status_unknown, 4 status_unknown_or_conflicting, 5 lifetime_inactive, 6 valuation_frozen; 0 is empty. Preserve the emitted segment order, including frozen appended after existing restrictions, independent of dictionary code order. P3 retains its listed dictionary. Encode only fields declared integer codes in Synthesis Section 4. Instrument IDs, terminal_event, lifetime_fact_id and opaque exception reasons remain character at their declared boundaries. Provider-internal terminal_levels remain provider internals. Decode code 0 explicitly as the empty string; it is not an ordinary R vector index.

Replace Note:98-99 with `write_off is excluded from the packet dictionary but preserved verbatim in disposition metadata and diagnostic mark_source (fe:489-495).` Replace Note:102-103 with `codes into those levels; terminal_event remains character in the carrier.` Keep non-P3 primary reasons independent of their reasons text as the note correctly specifies.

### F5. C8 injects too late to produce its promised stop

Evidence: Note:245 and :256-259 put the perturbation at P3/P4. `R/fold-engine.R:1140-1169` already performed the INCOMPLETE reconciliation check inside P3. After P4, :1445-1455 throws `ledgr_affordability_reconciliation_failed`; it does not return an INCOMPLETE stop. E handles P3 stops at :1986-1997. C8 also explicitly has no gut despite Note:231-234 and Cut:1171.

Why it matters: the base record would be a different failure class/lifecycle, and could not prove R3.3f/R3.6g.

Exact patch: replace C8 and its seam description with:

> C8a (3166): on a small-cash availability fixture, perturb the availability planner result's expected_final_cash by +1 before P3's reconciliation, at the return of ledgr_fold_build_availability_pulse_plan (ae:517-526). Freeze the INCOMPLETE completion, stopped diagnostic/detail, counts and valued/executed prefixes. The typed adapter attaches at the equivalent planner return, before the same reconciliation. Gut: suppress that stop; the frozen completion/trace must differ. C8b: perturb the plan after P3 returns, before P4; require the existing P5 reconciliation exception and invocation rollback/no successful memory result. Gut: suppress that exception. Assert each injection executed once and the mismatch exceeds the existing relative all.equal tolerance; do not change that tolerance.

### F6. C13 conflates new candidate atomicity with existing append failure semantics

Evidence: Note:250 freezes "state, buffers and outputs unchanged" for both failures, and :256 claims a common seam. The base installs the first lot and publishes/stages it before calculating the second (`R/fold-engine.R:1342-1375`). Synthesis:197-217 explicitly introduces candidate-block atomicity and explicitly disclaims private-state rollback after append/flush failure. `T/test-risk-fold.R:345-472` covers external rollback/FAILED results, not unchanged private state. Cut:1295 separately requires candidate, append and flush injections; C13 omits flush.

Why it matters: the unchanged base cannot pass the new private-state assertion, and enforcing it on handler failure would add an unauthorized transaction contract (`contract-execution-event-staging`).

Exact patch: replace C13 and its part of Note:256-259 with:

> C13 has separate gates. (a) On the base, inject the second lot-operation failure and freeze only the existing external failure class/stage, durable rollback and failed-memory result. Record the observed private prefix without treating it as the new atomicity oracle. (b) At 3167, inject the corresponding second-row failure during candidate computation and compare book, cash, positions, event_seq and output buffers with snapshots taken immediately before candidate computation; all must be unchanged. Gut: install/publish row one before row two validates. This is a new assertion implementing Synthesis 3.5, not a base identity claim. (c) On both representations, independently inject append, accounting-fact/leg and flush failures after successful calculation, checking abort, whole-invocation durable rollback, condition/stage evidence and absence of a successful partial memory result. Gut: swallow each injected error. Do not assert restoration of private state after handler failure. Name separate base/typed attachment adapters; no common candidate-block seam exists on the base.

### F7. C16 has a valid observation seam but a no-op base gut

Evidence: Note:253 and D10 use "key on record length". That is already the base condition at `R/run-finalize.R:453`; dense contributes no fold-equity rows (`R/fold-engine.R:574-583,2094`). Reapplying the same condition cannot fail the base case. Finalization replay and prefix commit are traceable at `R/run-finalize.R:528` and :549.

Why it matters: an unchanged successful base run does not demonstrate detection of the future nonempty dense-record routing error.

Exact patch: replace C16 with:

> C16 traces ledgr_replay_accounting_events and ledgr_run_equity_prefix_commit only during ledgr_run_finalize. A completed dense durable run must use replay and not prefix commit, with identical equity bytes. Base gut: force use_fold_equity=TRUE at that finalization decision; the route assertion must fail even if downstream validation also fails. Candidate gut: restore the old availability_active || nonempty-record decision while first asserting that dense actually populated the new equity record. Both controls must hit their named branch. Traces from fills/trades reads outside finalization do not count.

### F8. The new cases omit a required scenario and have unproved mutation preconditions

Evidence: R9.S6 at Note:226 points to continuation C17 (:254), which neither exceeds a writer chunk nor stops early. Synthesis:403 and Cut:1320 require both. C5 (:242) assumes residual compensation crosses a carry boundary, but `R/walk-forward.R:1281-1304` carries lots, not realized_comp, and `R/lot-accounting.R:182-194` initializes a new zero-compensation state (:15-17). C4 need not have competing live lots, so LIFO may equal FIFO. C6 does not require zero price. C7 freezes outputs but an extra no-op planner call may leave them identical. C14's book mutation need not alias any retained ctx vector.

Why it matters: these cases can pass while the bound defect remains; workload labels are insufficient to establish mutation sensitivity.

Exact patch: append to Section 4:

> C5a retains the walk-forward carry identity case. C5b directly applies successive opening operations to a book with explicitly nonzero realized_comp, including signed quantities and finite positive/negative basis, and checks zero Kahan invocations and bit-identical compensation; M6 must fail the invocation check. C4 must hold at least two lots with unequal basis before the partial close; otherwise its LIFO gut is invalid. C6 includes a zero-price, zero-fee exhaustive disposition and a deliberately incorrect replay realized-model witness. C7 records strategy and planner invocation counts as well as outputs. C14 has separate ownership witnesses for book/compiled inputs (3164), retained context/state/corporate-action views (3165), and published event/leg buffers (3167); each mutation writes the actual shared buffer the witness retains.
>
> C18 (3168): an availability run with a diagnostic pulse larger than an injected writer chunk of 7, followed by an early stop. Freeze durable diagnostics, filtered memory diagnostics with sequence gaps, equity used prefix, processed count, and distinct last-valued/last-executed clocks. Assert the large pulse and early stop occurred. Separate guts drop a split tail, retain previous staging on the next pulse, and drain unused equity rows; each must fail. Reuse the existing v201 fixture where suitable, naming its scenario and helper, rather than changing its oracle. R3.6a and R9.S6 reference C18; C17 continues to own continuation execution.

### F9. Test migration is not yet a per-block preservation proof

Evidence: Note:300 groups seven ledger blocks under "wrong delta", which cannot fail the duplicate-sequence/transaction assertions in `T/test-ledger-writer.R:829-878`. Note:311 merges fill-model :59/:96 into C1/C2/:1, but those destination cases do not preserve the original instrument ID and OHLCV projection assertions (`T/test-fill-model.R:70-79,108-115`). Note:283 gives LTB-0026 a "declare FILL on empty" control; its actual fixture injects CASHFLOW/DISPOSITION/SYNTHETIC_UNKNOWN and accepts canonical CASHFLOW (`T/test-execution-spec.R:523-554`). Note:292 changes the LTB-0280 fixture/fault timing but :445 claims no fixture changes. Note:294 does not name the surviving post-risk invalid property. Note:307 loses LTB-0521's explicit capacity-crossing reason, beyond preserving numeric frames.

Why it matters: permission to change representation is being used as a blanket replacement of individual assertions. These entries cannot yet establish that no product failure is being masked; Cut:430-443 requires this before implementation.

Exact patch: replace the grouped entries and the final "No economic value, fixture or oracle changes" sentence with:

> Each listed test block has its own row and each retained assertion has a suitable control. Ledger :829 retains duplicate (run_id,event_seq) refusal and unchanged row count; control accepts the duplicate. Ledger :855 retains invalid-sequence refusal with zero inserted rows; control inserts before validation. Fill-model :59 and :96 retain their original instrument/side/quantity/OHLCV values as typed-input projection assertions; only proposal/context S3 shape assertions retire. Controls corrupt instrument mapping and each projected bar field, separately. LTB-0026 retains all three injected kinds, canonical CASHFLOW acceptance and compiled refusals with their original classes; empty-plan construction is a separate test, not its replacement.
>
> LTB-0280 preserves the existing fixture's economic values and separate write/accounting-fact failure checks at the corresponding block boundaries. A two-pulse fixture is an additional rollback witness, not a replacement fixture; its changed fault timing needs explicit cut acceptance. The post-risk test retains missing-target refusal at initial normalization; the moved post-risk check injects a nonfinite transformed quantity and must retain ledgr_invalid_post_risk_targets with parent ledgr_invalid_strategy_result. LTB-0521 explicitly retires only equity-buffer growth because the record is preallocated; preserve all 300 values, empty-record semantics and the unrelated diagnostic/state growth assertions. Its controls drop a used row or expose an unused row. Every other grouped migration is expanded by block before acceptance; fixture/fault changes are named individually, never described as purely mechanical.

### F10. The timing specification does not yet connect the marginal clock to the harness

Evidence: Note:379-388 calls all reader cells replay witnesses and leaves the absolute clock's reporting interface unspecified. `dev/bench/timing/measure.R:52-62` accepts one selected workload clock per cell; `check.R:247-259` computes medians of those seconds, not differences of other cells. Cut:379-389 explicitly excludes equity from replay witnesses and rejects nonpositive/nonfinite marginals. Separate wide/no-fill cells run in different child processes.

Why it matters: subtracting per-cell medians would violate the same-process measurement, while requiring nonzero replay for equity would reject a correct stored-equity reader.

Exact patch: replace Note:379-388 with:

> Fills and trades reader cells record nonzero replayed rows and a fixed count of complete calls. Equity is a result-reader cell, not a replay witness. The absolute marginal cell has one workload that times matched wide and no-fill sweeps in the same child process and returns the marginal as its own named seconds clock: (wide_total - nofill_total) / reps / fills_per_repetition. Record both totals, reps, actual fill counts and materialization policy in the work string; refuse unequal fill denominators across repetitions. The shared checker validates that cell's finite positive seconds and computes its candidate median. timing_absolute.R reads that median and requires <=40e-6; it does not subtract medians of separate cells. Demonstrate rejection of 45 us against 240 us base, acceptance of 30 us, and rejection of zero, negative and nonfinite measurements. Ratio cells remain exactly decision (4)'s matrix.

### F11. The proposed memory quantity and controlled excess are not validly specified

Evidence: Note:390-407 labels `peak_after - pagefile_before` peak live. `peak_pagefile` is a process-lifetime high-water mark: e.g. setup peak 1 GB, current pre-operation 300 MB, operation peak 400 MB yields a reported 700 MB. A fresh process does not erase its setup/load peak. Private commit also includes allocator-retained/dead storage and does not by itself identify live book memory. Copying lot_qty/lot_price can share R storage unless independently allocated, need not exceed 10% of process memory, and "peak length, observed after the last fill" does not define the actual peak or an injection before growth/replay. The deep variant specifies only 200 instruments against Cut:395-403's >=5,000-axis workload. Synthesis:326-352 distinguishes cumulative allocation from peak live.

Why it matters: both the budget and its negative control could certify a memory regression or fail solely because setup changed. This is an unsettled evidence-method choice, not a valid pin.

Exact patch: replace Note:390-407 with:

> The proposed ps lifetime-peak subtraction is withdrawn as a peak-live measure. Memory-method validation is unresolved and blocks cut acceptance. LDG-3163 must demonstrate phase isolation, covered memory domains, collection policy and sensitivity before assigning the decision (5) budget to a metric. Report ps private commit and the separately calculated GC maximum as labelled observations only until that validation succeeds; do not substitute either for peak live. If no validated method meets the bound claim, obtain maintainer disposition before acceptance, as decision (5) requires.
>
> Both the ordinary and deep-book workloads retain a >=5,000-instrument by 252-session axis; the deep case has at least 200 instruments consume 15 live lots in one fill. Forward and replay remain separate operations. Freeze a byte-sized, independently allocated and touched storage excess from base-only calibration, with the exact allocation/retention/release points spanning the measured growth or replay. Verify it is live at those points and that it actually breaches 1.10 x the matched base under the validated method. A pointer alias or a copy too small to breach the budget is not a successful control. Five repetitions and their aggregation, both producers' Rprofmem bytes per actual fill, and the GC-byte formula remain explicitly recorded.

### F12. Per-ticket gates omit required checks and overstate settled status

Evidence: Note:426-431 omits the full suite required at every implementation ticket by Cut:416-418. The 3167 row omits M3, explicitly required at Cut:1295, and 3165/3167 omit their own isolation parts of C14. D9's per-fill predicate does not expressly cover per-leg lists. Note:435-446 calls the pins settled despite F1-F11. Cut:337-339 says the new records do not exist yet; Note:413-414 should not read as completed evidence.

Why it matters: owners could close before their applicable acceptance checks run, and proposed validation would be mistaken for evidence.

Exact patch: append to Section 8 and replace Section 9's concluding claims:

> Every ticket 3164-3168 also requires the full suite green. 3165 runs its retained-view/state isolation witnesses; 3167 runs publication-buffer isolation and both reordered-publication M2 and dropped-fee M3 through the typed path. D9 rejects per-leg staging lists as well as per-fill economic staging lists, while allowing routed metadata. 3168 runs C18. 3169 reruns every applicable case, control and detector, plus the complete timing/memory matrix. Before acceptance, 3163 records the expected baseline outcome for each representation detector; a base failure of a detector targeting the old representation is expected evidence, not a reason to weaken it.
>
> The dictionary, consumer/register census, test migrations and memory method remain subject to correction and verification. The real-data unchanged and cost-mutant runs are required LDG-3163 evidence, not results claimed by this note. No semantic change beyond the synthesis is authorized. A memory metric that cannot meet decision (5), or any proposed weakening of fixture/fault/oracle semantics beyond an accepted representation reason, returns to the maintainer before acceptance.

## Optional finding

### F13. Make the conservative capacity derivation self-contained

Evidence: Note:129-139 refers to an unavailable "census item 6" and never defines H/F/C. Reading `R/fold-engine.R:489-537,878-1025,1171-1271,1484-1491` supports a conservative `5N+3` bound; the separate early Q stop is not additive to a completed due pulse. This review found no required capacity-formula correction. The stated harness estimates also sum correctly to 1,400 R lines, below decision (12); empirical feasibility remains unproved.

Exact optional patch: replace the opening capacity derivation with:

> Let H be lifetime-disposition rows, F freeze-entry plus freeze-exit rows (disjoint sets), and C context length. P1 contributes at most H+F; P2 at most one intent row, max(C,1) decision rows and C stale-risk rows; P3 at most C total accepted/rejected rows; P5 one reconciliation row. H,F,C<=N gives the conservative 5N+3 bound. Corporate-action refusal and blocked scheduled-disposition stops return before these later producers; bound them separately by N and Q_pulse. Define absent Q_pulse as integer zero and allocate max(5N+3, 0, Q_pulse) once. Stop cases after lifetime disposition and scheduled-skip producers also fit this bound. Overflow is the existing classed bug refusal, never growth.
