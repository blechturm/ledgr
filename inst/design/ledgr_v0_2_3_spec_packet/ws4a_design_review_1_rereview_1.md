# LDG-3162 design review 1: focused re-review 1

- Reviewer: Codex, independent clean-context reviewer; author of neither input.
- Date: 2026-10-30.
- Mode: Type 1 against the accepted synthesis, cut and round-1 findings; Type 2 limited to defects introduced by revision 2. Findings below are Type 1 compliance/evidence gaps; no accepted architecture is reopened.
- Reviewed commit: `ac93ce17d1b4b4cac6cabbd4df3567701a26bd9d`, `release/v0.2.3`; revision diff from `c4c39a8e`.
- Verdict: **CHANGES_REQUIRED**.

Revision 2 repairs the principal failure-boundary mistakes. The remaining census and evidence gaps prevent LDG-3162 completion. The memory method is correctly unvalidated and assigned to LDG-3163; lack of its validation is **not** a finding against this note. Corrections below require reconciliation of the affected tables, so this is not PASS_AFTER_PATCHES.

References are repository-relative. `Note` = `inst/design/ledgr_v0_2_3_spec_packet/ws4a_carrier_design.md`; `Cut` = that directory's `tickets.yml`; `Synthesis` = `inst/design/rfc/rfc_typed_fold_carrier_v0_2_3_synthesis.md`; `T/` = `tests/testthat/`. Line numbers are at the reviewed commit. Patches below are instructions/text for the note, not edits to product or tests.

Read-only inspection covered AGENTS.md, both review inputs, the revision diff, LDG-3162 and its downstream tickets, cut decisions, synthesis, relevant contract groups, R sources and test blocks. No R execution, tests or timing ran. Only this review file was written.

| Round-1 finding | Resolved? | Evidence and disposition |
| --- | --- | --- |
| F1 consumer census | **No** | Note:30-153 substantially expands external consumers, state sites, legs and adapter removers, but deletes the lot-input/applied-row census rather than splitting it; plan/fill/rejection remain combined at :126-130. N1. |
| F2 indivisible obligations/owners | **No** | Note:265-475 adds identities, locking, callback/deserialization validation, routes and scenarios. However, the universal exact-length/typed-empty obligation is still absent, several groups have no named validator, and joint rows remain at :433, :469. N2. |
| F3 blind detectors | **Yes, for the six cited defects** | D2/D10/D20-D23 at Note:605-625 now observe staging retention, the accumulator, scoped routes, history access, literal codes and replay cash. Revision 2's additional register mappings introduce separate blind controls: N3-N4. |
| F4 dictionaries | **Yes** | Note:178-203 adds all six decision restrictions, explicit zero decoding, character terminal fields and disposition `write_off`. Verified against R/availability-economics.R:171-185 and R/fold-engine.R:489-495. |
| F5 reconciliation seam | **Yes** | Note:493-494 separates planner-return INCOMPLETE from the post-P3 exception. The first precedes R/fold-engine.R:1140-1169; the second targets its P5 check. Both have suppression controls. |
| F6 candidate versus append atomicity | **Yes** | Note:499-501 separates base external failure, new candidate atomicity and independent append/fact/flush failures; explicitly disclaims private restoration after handler failure. Matches Synthesis:194-211 and `contract-execution-event-staging`. |
| F7 dense finalization gut | **Yes** | Note:506 forces the base branch and separately restores the old decision on a populated typed dense record. R/run-finalize.R:449-453 confirms why these controls differ. |
| F8 missing scenario/preconditions | **Yes** | Note:488-508 adds unequal-basis lots, direct nonzero-compensation openings, zero-price disposition/wrong witness, invocation counts, separate buffer ownership witnesses and C18's oversized pulse plus early stop. These are specifications for LDG-3163, not claimed results. |
| F9 migration preservation | **No** | The specifically named ledger, fill-model, event-kind, fault-timing and equity-growth repairs appear at Note:531-573 and :727-733. The remaining census still understates a registered block's retained assertions at :522; N5. |
| F10 absolute timing interface | **Yes** | Note:646-659 specifies one same-process marginal clock, candidate median, invalid-measurement refusal and checker controls; equity is correctly excluded from replay witnesses. Matches Cut:364-392. |
| F11 memory method | **Yes** | Note:661-686 withdraws the old claim, labels observations, assigns validation to 3163, preserves both scale axes and requires independently allocated excess to breach the budget. The first candidate remains expressly conditional; it is not certified here. |
| F12 gates/status | **Yes** | Note:702-715 requires the full suite, applicable isolation, M2/M3, C18 and final all-check verification. D9 covers legs (:612); :719-733 distinguishes future evidence and required acceptance of shape/fault changes. |
| F13 capacity derivation (optional) | **Yes** | Note:229-241 defines H/F/C, separates blocked disposition rows, defines absent Q_pulse and retains the conservative bound with no growth. |

## N1. The revised census loses two complete carrier groups (residual F1)

Evidence: Note:102-153 has no `lot input` or `applied row` group. Synthesis:292-294 requires both. R/fold-engine.R:1349-1375 passes operation inputs and consumes results; R/accounting-replay.R:299-327 consumes per-event result columns; R/terminal-outcomes.R:159-195 uses the disposition result to publish its realized witness. A book-consumer row is not a census of those transient columns. Note:126-130 still combines plan/fill/rejection, contrary to F1's requested split and Cut:1104-1108.

Why it matters: the mapping does not say where all operation inputs and per-event outputs are introduced, retained or adapted. Implementing the book alone does not discharge these interfaces.

Exact patch: insert these rows in Section 1, using its existing aliases and assigning fresh edge IDs; split E72-E75 into individual group/consumer rows with the same cited sites:

| Group/edge | Producer | Consumer | Via | Implementing ticket |
| --- | --- | --- | --- | --- |
| lot input: opening import | la:182-213 | opening operation la:147-179 | import_state | 3164 |
| lot input: replay opening/fill/disposition | prepared columns ar:299-308, la:420-466 | typed operation selected by event kind | named replay adapter | 3164 |
| lot input: P4 fill | fe:1344-1355 | typed fill operation | direct positional input | 3164; 3167 separately owns batching this edge |
| lot input: P1 disposition | to:159-166 | typed disposition operation | settlement_state | 3164 |
| applied row: canonical accounting fact | la:367-388, fe:1349-1357 | oh:787-813 | direct; typed scalar result initially | 3164; 3167 separately owns column batching |
| applied row: replay facts | la:434-487 | ar:309-327 | direct | 3164 |
| applied row: disposition witness | to:159-169 | to:187-195 | settlement_state | 3164 |

Add after the table: "The two sequential changes on an edge are separate obligations: 3164 migrates operation/result representation; 3167 changes P4 application/publication to a block. Neither defers the other's interface work. Reconcile every Synthesis Section 4 group against this census before marking it complete."

## N2. The expanded register still omits universal validation duties (residual F2)

Evidence: Synthesis:90-94,252-254 requires exact types/lengths at construction and typed empty columns with `n=0`. Note:364-414 lists selected field invariants but never registers the typed-empty rule. Note:626 names no lot-input, applied-row, execution-view, leg or stop validator, although :387,398-405,412 assigns their rows to a "named group validator" (:358-360). E5.09 (:433) and S7 (:469) still assign two tickets to one row despite :255-256 and Cut:1113-1128.

Why it matters: a length mismatch or incorrectly typed empty batch can pass the listed field checks; an implementer cannot identify the promised validator for several groups. Counting rows is not a complete clause census.

Exact patch: add to Section 3.2:

> For every column group, construction checks the exact declared storage types, axis lengths, bounds and typed length-zero representation with n=0 where applicable. Add separate register rows by owner: 3164 book, lot input and applied row; 3165 decision packet, decision data, execution packet and decision; 3166 execution view, plan, fill and rejection; 3167 publication and leg; 3168 diagnostic/equity groups and typed stop payload. Each row names its constructors and validator. Independent controls replace each storage type, shorten one column, violate a bound and replace a typed empty column with an untyped empty list; each must fail its corresponding check. Preserve the synthesis's scalar/opaque exceptions.

Replace Note:626 with an explicit validator-to-group map including `V-lot-input`, `V-applied-row`, `V-execution-view`, `V-leg` and `V-stop`; state that `V-packet` covers decision data and execution packet as separate subgroups. Split E5.09 into reader/replay gates owned by 3164 and final matrix gates owned by 3169; split S7 into C14a owned by 3164 and C14b owned by 3165. Reference those rows from Section 8 at their owning tickets.

## N3. New register mappings assign controls to checks that cannot see them

Evidence: O3.14 (Note:288) uses D3 to reject a provider call in P4, but D3 (:606) only forbids character indexing and does not even list P4. The actual service-ownership predicate is tools/check-fold-phase-contract.R:66-81,149-153. O3.48 (:322) uses duplicate refusal D18 (:620) to prove vectorization: a scalar loop can reject duplicates too. O3.63/:66 (:337,340) use C13b/output identity and C9 to prove install-before-publication. C13b fails during calculation, before that order is reached; C9 (:495) observes final state/events, which a successful reordered installation can preserve. Current compiled install-before-append is visible at R/fold-engine.R:1329-1336.

Why it matters: all four forbidden changes can leave their assigned observations unchanged. These are new mappings, not defects in the repaired D2/D10/D20-D23 predicates. The stage rule is also bound by `contract-execution-fold-core`.

Exact patch:

> O3.14 uses the phase service-ownership checker, extended to the named execution-view adapter; its own control calls that service from P4. Keep D3 only for positional-access obligations. Split O3.48: D18 checks distinct instruments; a separate kernel source detector rejects R-level iteration over the distinct input instrument rows while permitting the justified sequential FIFO consumption within an instrument. Its control restores a per-instrument operation loop. Add an application-order witness owned by 3167: at the canonical publication entry assert the candidate book is already installed; observe sequence advancement, leg recording and position/cash installation in their specified order. At compiled append entry assert the compiled lot state and next sequence are installed. Separately swap each observed pair and require that witness to fail. Add this witness to O3.63, O3.66 and the 3167/3169 gates; retain C13b solely for candidate-calculation atomicity and C9 for compiled value parity.

## N4. The new blanket validator rule confuses records with execution history

Evidence: Note:358-360 requires every listed control to be an invalid record refused by a group validator. F4.35 (:398) supplies "opening with positive cash", but the lot-input schema has no cash field (Synthesis:292), and the kernel owns no cash (Synthesis:170,174-175). F4.37 (:400) supplies "Kahan on opening": that is an operation mutation, and may leave a structurally valid result. F4.49 (:412) supplies "applied twice": a stop record cannot reveal how many times E applied it. D7 already correctly specifies an invocation counter (:610).

Why it matters: following this instruction either leaves the controls unobserved or invents new carrier fields/refusals to observe them. Neither is authorized by the accepted schema.

Exact patch: replace Note:358-360 with:

> Structural field controls are refused by construction validators. Transition and preservation controls are checked at the operation or handoff with their required before/after inputs; they are not malformed standalone records. F4.35 uses V-lot-input for the declared operation fields and D17 plus an opening caller cash-before/after witness for no cash effects (3164; mutant changes opening cash). F4.37 uses C5b/D7 (3164; injected Kahan invocation). F4.49 uses V-stop for payload shape and an E application counter (3168; invoke stop application twice). F4.19 compares provider/valuation inputs with the constructed packet field by field, including an expired unpriced mark with retained provenance; erase age/source/reference in the adapter as its control. No extra carrier field or new semantic refusal is introduced to make these observations.

Update Section 6 and the owning Section 8 gates accordingly. This also makes F4.19's provenance-loss control an adapter preservation check rather than asking a standalone packet to prove its own source history.

## N5. A remaining migration entry drops most of a registered block's witness (residual F9)

Evidence: Note:522 describes LTB-0019's retained assertions as "four literal values, dust bound". T/test-accounting-core-consolidation.R:31-102 additionally checks the live FIFO tuple, successive fee-adjusted realizations, zero live lots, the 512-opening/closing sequence, absence of cash/positions in the book, single-sign live lots after every fractional transition, and final fractional P&L/basis/lot values with 1e-12 tolerances. Those assertions are neither retired with a reason nor explicitly preserved by the row. Cut:430-443 requires the per-block preservation decision before implementation.

Why it matters: the stated replacement could keep its four numbers and dust bound while losing regressions the registered block detects. A generic M1 is not a control for the missing cash/positions-field assertion.

Exact patch: replace that row's Keeps cell with "Every assertion in the existing block (:36-101), with unchanged inputs and tolerances: all intermediate realized/net/basis values, exact logical live lots, empty live counts, the 512-lot result, no cash/positions book fields, per-transition dust and single-sign bounds, and the final fractional P&L, basis and live tuple. Only extraction from the container changes." Replace its Control cell with "M1 for FIFO; dropped fee for fee-adjusted values; retained consumed lot for empty/deep-book results; injected cash/positions field for book ownership; corrupt cached net or retain opposite-sign live quantity for the per-transition invariants; perturb each final fractional value beyond its existing tolerance." Keep the original fixture intact.
