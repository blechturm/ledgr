# v0.1.9.5 Spec Review

**Status:** Review complete. Revisions required before ticket cut.
**Date:** 2026-06-12
**Reviewer:** Codex
**Artifact under review:** `v0_1_9_5_spec.md`

This review verifies the draft spec against the accepted API naming synthesis,
the v0.1.9.4 deep-code audit, the vignette-screening audit, and the roadmap
v0.1.9.5 workstreams. It does not reopen accepted RFCs, redesign the release,
or cut tickets.

---

## 1. Coverage Verification

### 1.1 Naming-Synthesis Coverage

The draft spec is broadly faithful to the accepted naming synthesis.

| Synthesis requirement | Spec coverage | Review |
| --- | --- | --- |
| R1-R7 naming rules and same-release `contracts.md` binding (`rfc_api_naming_consistency_v0_1_9_5_synthesis.md:37-72`) | Batch 5 binds R1-R7 into contracts (`v0_1_9_5_spec.md:181-192`). | Covered. F1's `ledgr_promote` allowlist is covered by importing R1-R7, though tickets should make the allowlist explicit. |
| Complete Section 2.1 rename/unexport table (`rfc_api_naming_consistency_v0_1_9_5_synthesis.md:82-108`) | Batch 3 applies the full table, including six DSL prefixes, snapshot open collision fix, walk-forward rename, and unexports (`v0_1_9_5_spec.md:158-168`). | Covered. |
| Section 2.2 unchanged-name reconciliation (`rfc_api_naming_consistency_v0_1_9_5_synthesis.md:110-224`) | Batch 3 updates export lock and docs; Batch 5 re-verifies unchanged citations (`v0_1_9_5_spec.md:165-167`, `v0_1_9_5_spec.md:181-192`). | Covered by reference and gate. |
| Candidate generic contract, locator attributes, override semantics, Amendment 2 discipline (`rfc_api_naming_consistency_v0_1_9_5_synthesis.md:227-291`) | Batch 4 implements the generic, locators, resolve-at-call verification, override mismatch, class reuse, and v0.1.9.4 supersession (`v0_1_9_5_spec.md:170-179`). | Covered. |
| F3 missing/moved-db class reuse | Batch 4 names `LEDGR_SNAPSHOT_DB_NOT_FOUND` plus existing walk-forward classes (`v0_1_9_5_spec.md:176-177`). | Covered. |
| Bucket A unexports and recovery pair docs (`rfc_api_naming_consistency_v0_1_9_5_synthesis.md:295-324`) | Batch 3 unexports Bucket A; Batch 7 routes Recovery into the Split-D successor Experiment Store article (`v0_1_9_5_spec.md:160-168`, `v0_1_9_5_spec.md:206-215`). | Covered. F4 is reflected in the sequencing constraint and Batch 7. |
| Contracts ticket (`rfc_api_naming_consistency_v0_1_9_5_synthesis.md:327-346`) | Batch 5 is a dedicated contracts pass (`v0_1_9_5_spec.md:181-192`). | Covered. |
| Cost surfaces and NEWS table (`rfc_api_naming_consistency_v0_1_9_5_synthesis.md:350-358`, `rfc_api_naming_consistency_v0_1_9_5_synthesis.md:445-455`) | Batch 3 includes NEWS consolidated table; Batch 12 includes NEWS gate (`v0_1_9_5_spec.md:165-168`, `v0_1_9_5_spec.md:257-264`). | Covered. F2 is reflected. |
| Mechanical gates (`rfc_api_naming_consistency_v0_1_9_5_synthesis.md:385-456`) | Section 3 imports the gates wholesale; Batch 12 names export-lock, old-name sweep, collision, M-8, candidate-generic, streaming, contracts/docs, NEWS gates (`v0_1_9_5_spec.md:255-274`). | Covered, with one release-playbook explicitness finding below. |

No naming-synthesis row is missing.

### 1.2 Deep-Code Audit Disposition

The spec accounts for every deep-code-audit finding in the severity index
(`v0_1_9_4_deep_code_review_audit.md:25-46`).

| Finding | Spec route | Review |
| --- | --- | --- |
| B-1 | Batch 1 (`v0_1_9_5_spec.md:122-124`) | Covered. |
| H-1 | Batch 1, with two-pulse fail-closed contract (`v0_1_9_5_spec.md:125-128`) | Covered; see Section 3. |
| H-2 | Batch 1 (`v0_1_9_5_spec.md:129-131`) | Covered. |
| H-3 | Batch 1 (`v0_1_9_5_spec.md:132-134`) | Covered. |
| M-1 | Batch 2 (`v0_1_9_5_spec.md:142-145`) | Covered. |
| M-2 | Batch 2 (`v0_1_9_5_spec.md:146-147`) | Covered. |
| M-3 | Batch 2 (`v0_1_9_5_spec.md:148`) | Covered. |
| M-4 | Batch 5 contract decision (`v0_1_9_5_spec.md:187-190`) | Covered, but see low-severity clarification. |
| M-5 | Deferred with reason (`v0_1_9_5_spec.md:154-156`) | Defensible. The audit frames it as db-live performance chatter only (`v0_1_9_4_deep_code_review_audit.md:230-237`). |
| M-6 | Batch 5 contract decision (`v0_1_9_5_spec.md:189-191`) | Covered, but see low-severity clarification. |
| M-7 | Batch 2 (`v0_1_9_5_spec.md:149-151`) | Covered. |
| M-8 | Batch 1 and Batch 12 gate (`v0_1_9_5_spec.md:117-121`, `v0_1_9_5_spec.md:257-260`) | Covered. |
| N-1 | Batch 2 ride-along discretion (`v0_1_9_5_spec.md:152-153`) | Defensible. |
| N-2 | Batch 2 ride-along discretion (`v0_1_9_5_spec.md:152-153`) | Defensible. |
| N-3 | Recorded, not scheduled (`v0_1_9_5_spec.md:152-153`) | Defensible. |
| N-4 | Recorded, not scheduled (`v0_1_9_5_spec.md:152-153`) | Mostly defensible, but tie it to M-4 if epsilon-pop is chosen. |
| N-5 | Recorded, not scheduled (`v0_1_9_5_spec.md:152-153`) | Defensible. |
| N-6 | Recorded, not scheduled (`v0_1_9_5_spec.md:152-153`) | Defensible. |

### 1.3 Vignette-Screening Audit Consumption

The screening audit's structural findings are covered.

- The three stale items are still present in the tree: the cost-API callout in
  `vignettes/execution-semantics.qmd:161`, the old walk-forward planning text
  in `vignettes/research-to-production.qmd:245`, and the old walk-forward
  pointers in `vignettes/sweeps.qmd:620` plus
  `vignettes/research-workflow.qmd:655-656`. The spec's carried-forward
  framing is accurate (`v0_1_9_5_spec.md:63-69`).
- Splits A-D are scheduled in Batch 7 (`v0_1_9_5_spec.md:204-215`) and match
  the audit's split recommendations (`v0_1_9_4_vignette_screening_audit.md:81-124`).
- Split E is correctly treated as a cut-line candidate (`v0_1_9_5_spec.md:211-212`,
  `v0_1_9_4_vignette_screening_audit.md:125-131`).
- The new risk-and-cost article, executable walk-forward article, and
  quickstart are scheduled in Batch 8 (`v0_1_9_5_spec.md:217-231`) and match
  the audit's missing-vignette priority list
  (`v0_1_9_4_vignette_screening_audit.md:141-168`).
- The pkgdown third nav group and reading-flow update are scheduled in Batch 7
  and Batch 11 (`v0_1_9_5_spec.md:213-215`, `v0_1_9_5_spec.md:245-253`),
  matching the audit's Section 5 items
  (`v0_1_9_4_vignette_screening_audit.md:181-188`).

### 1.4 Roadmap Workstream Mapping

Every v0.1.9.5 roadmap workstream is mapped.

| Roadmap workstream | Spec batch |
| --- | --- |
| A - Contracts audit and structural pass (`ledgr_roadmap.md:1072-1076`) | Batch 5 |
| B - User-facing vignette refresh (`ledgr_roadmap.md:1077-1080`) | Batches 1, 7, 8 |
| C - New vignettes (`ledgr_roadmap.md:1081-1085`) | Batch 8 |
| D - Maintainer manual articles (`ledgr_roadmap.md:1086-1089`) | Batch 9 |
| E - Identity contract reference v2 (`ledgr_roadmap.md:1090-1094`) | Batch 6 |
| F - v0.1.9.x performance and decisions arc (`ledgr_roadmap.md:1095-1099`) | Batch 10 |
| G - Release surfaces and roadmap audit (`ledgr_roadmap.md:1100-1108`) | Batch 11 |

Extra batch content (rename/unexport, candidate generic, M-8, audit fixes) is
authorized by the later accepted naming synthesis and the deep-code audit, which
the spec lists as binding sources (`v0_1_9_5_spec.md:37-48`).

---

## 2. Findings

### M-1. Batch 12 imports the release playbook too implicitly

Severity: Medium

The spec says Batch 12 runs "the release_ci_playbook checks" plus packet gates
(`v0_1_9_5_spec.md:255-264`). That is directionally right, but the playbook
itself says every final release-gate ticket must explicitly include the
playbook as a source reference, a task to read it, and an explicit local-gate
checklist. It also says not to leave this as an implicit convention
(`release_ci_playbook.md:100-123`).

Because this spec is what ticket cut will follow, Batch 12 should spell out the
playbook checklist or state that the release-gate ticket must copy the exact
checklist from the playbook. Otherwise the release gate can pass spec review
while still violating the playbook's strongest process lesson.

Required revision:

- Expand Batch 12 to name the release-playbook source reference/read task and
  the explicit local-gate checklist: full tests, README cold-start,
  `R CMD check --no-manual --no-build-vignettes`, coverage when applicable,
  pkgdown build, local WSL/Ubuntu gate when applicable, branch/main/tag CI, and
  closeout notes for skipped or rerun gates.

### M-2. Batch 1 is too broad for reviewable execution

Severity: Medium

Batch 1 combines M-8, B-1, H-1, H-2, H-3, and three stale-vignette fixes
(`v0_1_9_5_spec.md:113-138`). Those are not one implementation unit:

- M-8 is a result-table / cursor-lifecycle fix.
- B-1 is C++ PROTECT hardening.
- H-1 is runner window validation.
- H-2 is lot-accounting input validation.
- H-3 is telemetry clock semantics.
- The stale items are documentation fixes.

The audit suggests an order of attack, not one giant batch
(`v0_1_9_4_deep_code_review_audit.md:319-331`). This is two or three batches
wearing one number. It would make Claude review harder and increases the risk
that a regression in one subsystem obscures another.

Required revision:

- Split Batch 1 before ticket cut. A workable shape is:
  - Batch 1A: release-blocking stale vignette fixes (or move them to the first
    documentation batch but keep the "before linked rewrites" sequencing gate).
  - Batch 1B: M-8 plus H-1/H-3 runner/results hardening.
  - Batch 1C: B-1/H-2 low-level accounting/kernel hardening.

The exact split can differ, but the final batch plan should not ask one review
to cover five unrelated runtime fixes plus docs.

### L-1. Scope-supersession note mislabels locator attributes as identity bytes

Severity: Low

The scope note says identity bytes change only where the naming synthesis binds
them, then names walk-forward result locator attributes
(`v0_1_9_5_spec.md:23-26`). Locator attributes are not identity bytes; they are
durable strings carried on result objects so `ledgr_candidate()` can resolve at
call time. The naming synthesis's candidate-generic contract requires locator
attributes and verification, but does not bind a hash-recipe change
(`rfc_api_naming_consistency_v0_1_9_5_synthesis.md:233-249`).

Suggested revision:

- Replace the sentence with: "Durable identity hash recipes do not change in
  this packet. The candidate-generic work changes walk-forward result object
  shape by adding locator attributes and resolve-at-call verification."

### L-2. Batch 5 title understates code/test work for M-4 and M-6

Severity: Low

Batch 5 is titled `contracts.md structural rework`, but it also resolves M-4
and M-6 (`v0_1_9_5_spec.md:181-192`). Both can require implementation and tests:
M-4 may require epsilon-pop changes in both R and C++ accounting paths if that
contract is chosen (`v0_1_9_4_deep_code_review_audit.md:217-228`), and M-6
requires a classed failure on non-POSIXct timestamp hash inputs
(`v0_1_9_4_deep_code_review_audit.md:239-247`).

Suggested revision:

- Rename or annotate Batch 5 as `contracts.md structural rework plus M-4/M-6
  contract-bound hardening`.
- State that if M-4 selects epsilon-pop, both R and C++ paths plus parity tests
  are in scope for that ticket or a directly adjacent ticket.
- State that M-6 requires a source-level test for non-POSIXct timestamp input,
  not only prose in `contracts.md`.

### L-3. N-4 should be tied conditionally to M-4

Severity: Low

The spec records N-3 through N-6 as not scheduled (`v0_1_9_5_spec.md:152-153`),
which is defensible. N-4, however, explicitly interacts with M-4 in the audit:
the actionable-delta tolerance is absolute and matters if fractional quantities
arrive (`v0_1_9_4_deep_code_review_audit.md:274-276`).

Suggested revision:

- Keep N-4 unscheduled by default, but add: "If M-4 selects the epsilon-pop /
  fractional-quantity-support route rather than a whole-ish-quantity contract,
  the ticket must re-check N-4 tolerance semantics."

---

## 3. New Bindings In The Spec

### 3.1 Scope Supersession

Confirmed with the low wording fix above.

The roadmap originally framed v0.1.9.5 as documentation, teaching, contracts,
and cleanup, with no execution semantics or durable identity bytes authorized
(`ledgr_roadmap.md:1126-1137`). The spec correctly records that later binding
inputs extend that frame: the naming synthesis requires implementation work
for renames, unexports, M-8, and the walk-forward candidate generic, and the
deep-code audit routes hardening into this release (`v0_1_9_5_spec.md:15-26`).

The implementation surface is tight enough: it is exactly the accepted naming
synthesis plus explicitly routed audit findings (`v0_1_9_5_spec.md:22-25`).
No extra feature work is authorized.

### 3.2 H-1 Contract Decision

Confirmed.

The audit presents two options and says the two-pulse fail-closed option is a
contract choice because the fill model needs a next bar and walk-forward already
requires at least two scoring pulses (`v0_1_9_4_deep_code_review_audit.md:116-121`).
The current runner hazard is real: `resume_exec_posix <- pulses_posix[[2]]` is
evaluated unconditionally (`R/backtest-runner.R:906-913`). Walk-forward already
fails closed when an experiment window has fewer than two scoring pulses
(`R/walk-forward-folds.R:566-581`).

The spec's binding -- fail closed at coverage check with a classed "window must
contain at least two pulses" error (`v0_1_9_5_spec.md:125-128`) -- is coherent
with both the audit and the existing walk-forward rule. No further RFC-level
deliberation is required.

---

## 4. Items Confirmed As-Is

- The naming synthesis Sections 2-7 are all scheduled or imported by reference.
- Final-review patches F1-F4 are reflected: `ledgr_promote` via R1 import,
  NEWS table in Batch 3/12, missing-db class reuse in Batch 4, and Split-D-aware
  Recovery landing in sequencing/Batch 7.
- M-5 deferral is defensible because the finding is db-live performance, not a
  correctness defect in the promoted teaching path.
- N-3 through N-6 can remain recorded rather than scheduled, subject to the
  N-4/M-4 caveat above.
- Screening-audit Splits A-D, Split E cut-line, missing-vignette list, pkgdown
  third group, and reading-flow update are all represented.
- Workstreams A-G all map to at least one batch.
- Batch 6 appears correctly sequenced after Batch 4 in the numbered order, so
  the identity reference can consume locator attributes and candidate-generic
  terminology.
- Twelve batches is not itself a problem. v0.1.8.11 used a longer sequence
  while preserving reviewability (`v0_1_8_11_spec.md:10-26`).

---

## 5. Verdict

Revisions required before ticket cut.

The spec is faithful in substance and no accepted RFC/audit gate is missing.
However, ticket cut should wait for four small but important revisions:

1. Make Batch 12 explicit enough to satisfy the release CI playbook.
2. Split Batch 1 into reviewable units.
3. Correct the scope note's "identity bytes" wording around locator attributes.
4. Clarify Batch 5's M-4/M-6 code/test implications and the N-4 conditional
   tie-in.

After those revisions, the spec should be ready for ticket cut.
