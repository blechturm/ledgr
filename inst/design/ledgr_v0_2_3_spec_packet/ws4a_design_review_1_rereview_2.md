# LDG-3162 design review 1: focused re-review 2

- Reviewer: Codex, independent clean-context reviewer; author of neither the note nor earlier reviews.
- Date: 2026-10-30.
- Mode: Type 1 against the accepted synthesis, cut and N1-N5; Type 2 scrutiny limited to defects introduced by revision 3. Findings below are Type 1 conformance/evidence corrections; no architecture is reopened.
- Reviewed commit: `268301270f5673a3aa32402767cf8e101d15d528`, `release/v0.2.3`; note revision 3, diff from `ac93ce17`.
- Verdict: **PASS_AFTER_PATCHES**.

Revision 3 resolves the original N1-N5 gaps in substance. Two new defects in the replacement controls block LDG-3162 as written; the exact N6-N7 patches below suffice without another review. Optional O1-O2 do not condition this verdict. No additional owner gap, test-oracle weakening or unresolved design choice was found in the revision. Memory-method validation remains LDG-3163 work, not a condition for passing LDG-3162.

This is after the second correction round. Under `inst/design/rfc_cycle.md:314-322`, disposition of a third correction belongs to the maintainer. These patches are supplied for that disposition, not an instruction to begin another autonomous correction/re-review cycle.

References are repository-relative. `Note` = `inst/design/ledgr_v0_2_3_spec_packet/ws4a_carrier_design.md`; `Cut` = that directory's `tickets.yml`; `Synthesis` = `inst/design/rfc/rfc_typed_fold_carrier_v0_2_3_synthesis.md`; `T/` = `tests/testthat/`. Lines refer to the reviewed commit. Exact patches below edit the note only.

Read-only inspection covered AGENTS.md, the complete note and both earlier reviews, the revision diff, cut 5 and LDG-3162 through LDG-3169, the accepted synthesis, relevant contract groups, governance, cited R sources, the phase checker and LTB-0019. No R execution, test suite or timing ran. Only this review file was written; no commit was made.

| Finding | Resolved? | Evidence and disposition |
| --- | --- | --- |
| N1: missing carrier groups and combined edges | **Yes** | Note:128-135 separates plan, rejection and fill readers; :159-175 adds E95-E101 for opening/replay/P4/disposition inputs and applied results, distinguishing 3164 representation from 3167 batching. Verified against R/lot-accounting.R:147-213,407-487, R/accounting-replay.R:299-327, R/terminal-outcomes.R:159-195 and R/output-handler.R:787-813. E73a has the optional stage-label correction O1. |
| N2: universal validation and joint ownership | **Yes** | Note:388-400 registers types, exact lengths, bounds and typed empties by owner, preserving scalar/opaque exceptions; :674-682 names all missing validators and the three V-packet subgroups. E5.09a/b (:475-476) and S7a/b (:512-513) split the duties; :762-767 gates them at the corresponding tickets. This implements Synthesis:90-94,252-254 without deferring construction validation. |
| N3: blind check/control mappings | **Yes, original mappings** | O3.14 now uses D24 (:310,670), matching tools/check-fold-phase-contract.R:66-81,149-153. O3.48a/b separates duplicate refusal from vectorization (:344-345). W1 replaces final-output/early-failure checks for application order (:360,363,672), with 3167/3169 gates (:765,767); compiled book/sequence installation is at R/fold-engine.R:1329-1336. The newly worded D25 is overbroad: N6 below. |
| N4: records confused with execution history | **Yes, original distinction** | Note:381-386 separates structural from transition/preservation observations. F4.19 compares adapter inputs/output (:424); F4.35 observes caller cash (:440); F4.37 uses C5b/D7 (:442); F4.49 counts E applications separately from V-stop (:454). Owners remain 3165/3164/3168. The newly added structural example in F4.35 is invalid as a control: N7 below. |
| N5: LTB-0019 witness loss | **Yes** | Note:566 explicitly preserves every assertion, original inputs and tolerances, including live tuples, all intermediate values, empty/deep-book results, no cash/positions fields, transition dust/sign checks and final fractional values. These match T/test-accounting-core-consolidation.R:31-102. Its controls now cover those distinct assertions; only representation extraction changes. |

## N6. Blocking: D25 also rejects the required ordered aggregate scan

Evidence: Note:345 says "sequential only within an instrument"; D25 at :671 prohibits all R-level iteration over distinct input instrument rows. Synthesis:162-166 expressly requires scalar event-order total-basis and Kahan updates as well as vectorized independent lot work. Its cited executable example, `dev/spikes/ws4a-carrier-probe/typed-lots.R:85-95`, loops over those same rows for ordered scalar totals and per-event facts. Note:346 independently retains that obligation.

Why it matters: the new detector can reject a conforming canonical kernel. Satisfying it by replacing the aggregate scan with `sum`/`cumsum` would violate the accepted arithmetic order. This is a conflict in the new predicate, not a request to redesign the kernel or reopen the synthesis.

Exact patch: replace the complete O3.48b row with:

> | O3.48b | Independent lot work vectorized across distinct instruments; FIFO consumption sequential within each instrument; scalar event-order aggregate updates retained (3.4) | E18 | 3164 | D25 | restore a scalar per-instrument lot-operation loop |

Replace the complete D25 row with:

> | D25 | Independent lot consumption, append, compaction and growth are not dispatched through an R loop one input instrument at a time. Permit FIFO depth iteration and the scalar event-order total-basis/Kahan scan that writes per-event aggregate facts; opening rows perform no Kahan step. Cash remains outside the lot kernel. | parse regions of the kernel, with the ordered aggregate-scan region explicitly identified | restore a scalar per-instrument lot-operation loop: must fail D25; retain the permitted aggregate scan: must pass D25 |

Keep O3.49, D7, D17 and M11 unchanged. The exception permits only the already-bound ordered aggregate work, not scalar lot processing hidden inside that region.

## N7. Blocking: an "unsigned opening quantity" is not a rejectable record

Evidence: Note:440 introduces `invalid record: unsigned opening quantity` under V-lot-input. Synthesis:168-170 permits signed opening quantities, including positive ones; its lot-input schema (:292) carries a double quantity, not an unsigned type or sign-provenance field. R/lot-accounting.R:152-178 accepts finite nonzero quantities of either sign; T/test-accounting-core-consolidation.R:33 uses the valid positive opening `10`.

Why it matters: a positive double is a valid signed quantity. If "unsigned" means `abs()` of a negative source quantity, the resulting positive record cannot reveal that history to V-lot-input. Requiring refusal either yields a non-failing control or rejects a valid opening. The new example repeats the observation problem N4 otherwise repaired.

Exact patch: in F4.35 replace only:

> `(invalid record: unsigned opening quantity)`

with:

> `(invalid record: operation-row pos = 0L, outside the one-based run-axis bounds)`

Keep the caller cash-before/after witness, its cash-changing control, C5b/D7 and the existing opening inputs unchanged. This uses the already-required bounds validation (Synthesis:90-94), introduces no sign-provenance field and changes no opening semantics.

## O1. Optional: E73a places the kind check in the wrong stage

Evidence: Note:131 calls fe:1115-1125 a "P4 kind check". That code is inside `ledgr_fold_stage_plan` (R/fold-engine.R:1046-1282), hence P3. The P4 helper at :1313-1314 extracts fills; R/fold-engine.R:232-234 shows it does not read event kinds. E73b already covers P4 fill consumption. The correct implementation owner remains 3166 and the cited refusal itself exists.

Exact patch: in E73a replace the Consumer cell `P4 kind check and compiled dispatch fe:1115-1125, :1313-1314` with `P3 canonical and compiled kind checks fe:1115-1125`. This removes a misleading stage attribution without changing the gate.

## O2. Optional: refresh two check-list cross-references

Evidence: E5.07 at Note:473 still says D1-D23 after :670-671 adds D24-D25. The 3164 gate at :762 lists D17 but omits an explicit reference to F4.35's separate caller-cash witness at :440. Both checks already have implementing owners in their register rows, and Cut:416-418 requires applicable detectors, so these are navigation omissions rather than unowned obligations.

Exact patches: in E5.07 replace its Check cell `D1-D23` with `D1-D13, D15-D25`. In Section 8's 3164 row append `; F4.35 opening caller cash-before/after witness` to the Detectors, validators, mutations cell.
