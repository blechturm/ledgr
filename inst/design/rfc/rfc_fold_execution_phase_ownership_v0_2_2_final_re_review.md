# Focused Type 1 Re-Review: Fold Execution Phases And State Ownership Synthesis

**Review point:** focused re-review of the synthesis patches made after the
Type 1 final review (`rfc_fold_execution_phase_ownership_v0_2_2_final_review.md`).
**Reviewer:** Codex, author of neither seed v2 nor the synthesis.
**Date:** 2026-10-15.
**Reviewed artifacts:** `rfc_fold_execution_phase_ownership_v0_2_2_synthesis.md`
(patched 2026-10-15) and `rfc_fold_execution_phase_ownership_v0_2_2_seed_v2.md`
(patched 2026-10-15), against the executable baseline
`07f91bcfa9455d5eafa5ef4c1712f0ccd7b6fee3` in the `ws38` worktree.
**Verdict:** CHANGES_REQUIRED, four findings.
**Record note:** saved by Claude, the synthesis author, from the maintainer's
paste of the reviewer's output; wording unchanged, formatting normalized to
ASCII markdown. The reviewer reported a wall time of 2 minutes 24 seconds.

## 1. Verdict

CHANGES_REQUIRED. The factual corrections largely hold. The live-return
direction is supported by response R4, but its acceptance gate and authority
treatment still need correction. No taxonomy redesign is required.

## 2. Findings

Four findings remain:

### 1. Gate C permits closure with failing registered parity tests.

Synthesis Section 8 (`rfc_fold_execution_phase_ownership_v0_2_2_synthesis.md:416`)
requires LTB-0006 and LTB-0013 to pass "or their failure is routed." Routing a
failure cannot satisfy the parity gate: repository rules require compiled
divergence to fail closed, and LDG-3054 requires passing package checks.

Section 5.5 also assumes any newly exposed failure is an existing
compiled-versus-canonical divergence. It could instead result from incorrect
extraction or return plumbing.

Smallest patch: Require both blocks to pass before WS38 closes. A failure
stops dependent work, preserves the tests, and receives causal investigation
and routing; routing alone does not clear the gate.

### 2. The live-return repair needs an explicit disposition under decision (7).

The sixteen assignment sites, three dead runner stores, and registered
consumers are now correctly recorded. The four return-field comparisons in
each block currently compare pre-loop values. Other assertions in those blocks
still compare produced events and summaries, so the blocks themselves are not
wholly hollow.

Returning live values changes an observable private result and repairs the
stale-return defect. Yet Section 3
(`rfc_fold_execution_phase_ownership_v0_2_2_synthesis.md:86`) marks decision
(7) - "fixes no defect" - unchanged.

Smallest patch: Name the live-return repair as a narrow, explicit exception
requiring maintainer acceptance, while retaining the prohibition on unrelated
fixes. Attribute this reversal to the synthesis author's response to F1: my
review established the consumers; it did not select live return over
deletion.

### 3. F8's no-copy claim remains false as written.

Section 2 (`rfc_fold_execution_phase_ownership_v0_2_2_synthesis.md:57`) still
says a scalar write inside an environment-backed stage "copies no
scale-growing vector." An environment does not prevent copying a vector shared
with another reference.

I checked this without loading production code or writing files: a locked
environment held a numeric vector, another binding retained that vector, and a
stage changed one element through the environment. `tracemem()` reported a
copy during the stage; the retained value stayed unchanged.

Smallest patch: Say the environment avoids passing and returning the carrier
by value. Remove the unconditional vector-copy guarantee and Section 9's
corresponding universal comparison. Leave actual copying to the stated
detectors and measurements.

### 4. The consistency record does not cover the remaining seed departures.

Seed v2 Section 6 still proposes deleting the return fields, while the
synthesis selects live return. Seed v2 Section 9 item 4 still requires
accounting-fact injection for both handlers, while the corrected synthesis
rightly limits it to memory. Section 13 nevertheless asks reviewers to
establish mutual consistency.

Smallest patch: Explicitly mark those seed provisions as superseded by
synthesis Sections 5.5 and 7. Also disclose Section 4's "count ... may change
only by RFC" restriction, which the original review identified as an
additional binding.

## 3. Original corrections re-reviewed

The other original corrections are satisfactory within this focused review:

| Finding | Re-review result |
| --- | --- |
| F2 | Family-set assertion now includes the added witness; historical transition differences are separated from subsequent exact comparisons. |
| F3 | The identified counter, service, stage-set and citation omissions are addressed. |
| F4 | Count -> flush -> break matches both counted stop paths. |
| F5 | The synthesis's handler/mode injection matrix matches the baseline. Seed consistency remains covered above. |
| F6 | Live-path arithmetic is corrected; the existing contract discrepancy is explicitly recorded and routed. |
| F7 | Ticket titles, scope/acceptance fields and review reason now have explicit dispositions. |

## 4. Recommended next step

Recommend these bounded corrections followed by focused confirmation before
acceptance. Production, tests and recorder sources still match the pinned
baseline. I changed no files, made no commit, and invoked no other agent.

## 5. Focused confirmation

PASS, Codex, 2026-10-15: all four dispositions close the findings and no
further correction round is required. One-line record per the cycle's record
rule; it confirms the document corrections, not implementation. The verdict is
provisional until the maintainer rereads the brief and review together.
