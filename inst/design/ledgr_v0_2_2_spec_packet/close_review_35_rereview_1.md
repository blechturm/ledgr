# Focused Type 1 re-review: Workstream 35 after reconciliation

**Reviewed tree:** `codex/ws35-v0.2.2` at `d6c4c85d`

## Verdict: CHANGES_REQUIRED

F1 to F8 from the first close review are closed. The merge that brought in
later Cut 15 work (`7a030be9`) nevertheless undid most of WS35's RFC-pipeline
normalization. It also re-pointed one accepted WS38 evidence item to a section
that does not support it. The fixes are mechanical and need no Type 2 round.

## Original findings

| Finding | Status | Evidence |
| --- | --- | --- |
| F1 | Closed | The three headers now say accepted and cite their approving final reviews and `v0_1_8_10_spec.md:45-52`. The 47-record tally is 28 accepted, 4 amended, 10 superseded, 2 superseded in part, 2 draft, 1 rejected and 0 under review. |
| F2 | Partly closed | Bare paths, bare anchors, `and/or`, empty evidence and count mismatch are caught. N3 records two residual detector gaps. |
| F3 | Closed | Packet README links Cut reviews 7, 9, 13 and 14; all packet README links resolve. |
| F4 | Closed | The rejected synthesis header now gives the enforcement-layer reason and preserves Sections 4.1 to 4.8. |
| F5 | Mostly closed | `Empirical:` and reviewed ranges are defined and the latter is mutation-sensitive. N4 records an application ambiguity. |
| F6 | Closed | Redirect stubs exist and all six old baseline entries resolve. |
| F7 | Closed | The history-wave register is paused for WS35 and WS39, is an input to the v11 amendment, and both drafts name receivers. |
| F8 | Closed | Re-measured packet counts are 684 raw / 582 non-blank lines and 45,534 bytes before, 115 / 93 / 5,686 after; the guard-role evidence cites files that state it. |

## New findings

### N1 (high): the merge reverted WS35 RFC-pipeline normalization

At `inst/design/rfc/README.md:3-5,14-21,48,74-75`, the merge retained the
integration side plus redirect stubs but lost the canonical Role/Status/
Authority header, Paused and Closed state definitions, governance-lifecycle
Trigger/Route, the compiled-envelope state correction, and the snapshot
`amended 2026-10-13` label. The history-wave row still uses now-undefined
`Paused`. The guard produces zero findings at `c5026268` and five at HEAD:
two `missing_obligation_routing`, one `invalid_row_state`, `missing_role` and
`invalid_status`. Restore those clauses from `c5026268`, express the existing
WS38 remaining text as Trigger/Route, and correct the reconciliation record.

### N2 (medium): an accepted WS38 evidence pointer is unsupported

LDG-3053 acceptance evidence in `tickets.yml` points callback-context,
momentum-feature, alias and helper claims at
`fold_phase_extraction_closeout.md#failure-interruption-and-state-boundaries`,
which covers fault injection and rollback instead. Cite
`#commit-and-exactness-ledger` and `#verification`, and restore the dropped
`adds exact availability witnesses` clause.

### N3 (medium): evidence-result detection still leaks verbs from paths

At `tools/governance-report.R:1053,1107`, the word count uses pointer-stripped
text but the verb regex uses the raw value. Thus a path containing `report`
can supply the only result verb. Removing the pointer requirement also leaves
all 191 expectations green. Run the verb test on stripped text and add tests
for a pointer-free conclusion and for a value whose only apparent result verb
is in its path; align LCL-0271.

### N4 (low): the mandatory `Empirical:` wording is applied only once

Clarify `README.md:92-96`: the prefix applies when an evidence item states an
observed result inline; a pointer to a durable record containing the required
Section 5 fields is sufficient. This follows the synthesis wording, `or its
necessary retained evidence`.

### N5 (low): the reconciliation run record is incomplete and stale

`governance_record_normalization.md:116-123`, WS35 integration evidence 3 and
`tickets.yml:1898` omit environment and reviewed range. The recorded 182
governance expectations do not reproduce; the reviewer got 191. The reviewer
also got 339 sources and 1,033 findings in 89.8 seconds, versus 1,034 at the
merge commit. Re-measure on the final correction and record the required
fields and actual count.

## Verification performed

- `test-governance-report.R`: 2 tests, 191 expectations, clean.
- `test-documentation-contracts.R`: 24 tests, 1,031 expectations, clean.
- `test-test-control-plane.R`: 8 tests, 66 expectations, clean.
- Governance report: report-only, 339 sources, 1,033 findings, six baseline
  entries resolved.
- Direct Cut 15 evidence scan: zero findings; completed tickets have matching
  acceptance/evidence counts.
- `rfc/README.md` header/state scan: zero at `c5026268`, five at `d6c4c85d`.
- `git diff --check 043a5ce1 d6c4c85d`: clean.
- Mutations: count check, empirical check, reviewed-range field, result
  requirement and missing-`tickets.yml` abort were detected; removing the
  pointer requirement was not detected.

WS35 is not ready for acceptance until N1-N5 are corrected. A focused
re-review should require zero RFC-index state/header findings and exercise the
two new LTB-0273 mutations.
