Verdict: PASS_AFTER_PATCHES
Role: record; independent clean-context Type 1 close review of cut 2 workstream 2.
Status: review recorded 2026-10-30; awaiting maintainer acceptance.
Authority: review evidence against the accepted cut; this file grants no new implementation scope.

Reviewed `0aad4ff9..ada7c319` on `codex/ws3-amendment-v0.2.3` (LDG-3138
`26ea8fb4`, LDG-3133 `b7ccdfd3`, recorder `328998db`, freeze `cbf25359`,
checks `4f49bb7b`, request `ada7c319`). Authority: cut 2 revision 3.2,
workstream 2's review claim and LDG-3133..3135/3138 in [tickets.yml](tickets.yml);
peer-suite synthesis D4/D6 with Amendment 1; cut 4 decisions (8) and (17).

The claim holds. The freeze `cbf25359` is acceptable as C1's dense oracle
commit; no patch below touches oracle bytes, recorder code or a check.

## Findings, ranked by severity

**F1 (required, record). LDG-3135's A0 gate was substituted without a
maintainer record.** LDG-3135 scope and acceptance (tickets.yml:463-472, :492)
require A0's original `check.R` to pass. After cut 4 it cannot: on this tree
it fails on the files cut 4 intentionally changed, and at the pinned
pre-cut-4 source it fails on the wall-clock field `selected_at_utc` (cut 4
decision 17). The implementer ran cut 4's accepted successor gate instead and
recorded this in protocol.md:99-107 and inventory.md:42-52. That substitution
is correct: it follows cut 4 decision (8), and the reviewer rerun below
passes. But an implementer cannot change an accepted acceptance criterion.
Patch: the maintainer records the substitution in LDG-3135 at acceptance,
for example: "Post-cut-4 disposition: A0's executable gate is cut 4's
successor record.R plus compare.R (decision 8); the original check.R is
history and runs only to show that its failures are exactly the successor
population." Not NEEDS_TYPE_2, because cut 4 already decided which gate
applies.
Also add one inventory sentence. For `dense_risk_features/run`, the
`a0_references.csv` pointers name original tables whose equity, fills,
ledger, metrics and trades the current product no longer reproduces.
Current expected values are the successor model files. C1 uses the
successor gate, never those pointer bytes, as the exact expectation.

**F2 (required, trivial). The live open-cut scan reports the
review-request commit.** The LDG-3138 selector, run on HEAD, returns one
finding: `malformed_ticket_evidence LDG-3133:evidence:1`
(tickets.yml:401). The line has a pointer, but its prose contains no
result verb from `governance_evidence_has_result`. Patch: change "every D4
surface is assigned" to "verified that every D4 surface is assigned". The
scan should then be clean. This also confirms that the LDG-3138 fix works
on the real packet.

**F3 (required, wording). Exclusions are understated and missing from the
inventory.** protocol.md:87 says "Only runs.created_at_utc is omitted".
native.R:95 also drops `run_provenance.created_at_utc`. LDG-3135 asks the
inventory to record exclusions, but inventory.md has no exclusion list.
Patch: list all four exclusions in the inventory, and correct the protocol
sentence to match:
- `runs.created_at_utc`
- `run_provenance.created_at_utc`
- `runs.config_json` `db_path`
- `runs.config_json` `data.snapshot_db_path`

All four are locators or wall clocks. Dropping them weakens nothing.

**F4 (required, evidence accuracy). LDG-3138's empirical evidence names
cuts that were not scanned.** tickets.yml:647 claims zero findings "across
both open cuts" with "accepted Cut 1 ticket evidence" as input. At
`26ea8fb4`, cuts 1 and 4 were closed and only cut 2 was open, so the live
scan covered workstreams 2 and 3 only. Cut 1 closed on 2026-10-29 and is
excluded by design. Its visibility while it was open is moot now. The
two-open-cut claim is the fixture test's, not the live scan's. Patch: say
"across the one open cut (cut 2); cuts 1 and 4 are closed and excluded by
design; the two-open-cut case is the fixture witness".

Optional, not conditioning the verdict:
- native.R:15 hardcodes `C:/Program Files/Git/cmd/git.exe`, so check/gut run
  only on this Windows host layout.
- The `asset_quantity_aggregate_unchanged` gut (gut.R:41-44) keeps the
  aggregate unchanged trivially, because it mutates only `rebuilt_positions`.
  Detection is still per asset (`instrument_id=P01`), which meets the ticket.
  A one-unit move between two assets would be a stronger witness.
- The representation compares `run_provenance` `R_version` and
  `dependency_versions_json` exactly. C1 must rerun on the same library, or a
  dependency bump fails as a representation difference. Protocol.md:93
  discloses this.
- Base R has had `%||%` since R 4.4.0, not R 4.6 (protocol.md:38).

## Reruns (reviewer, this host, HEAD `ada7c319`, R 4.6.1)

- `check.R --pkg=. --records=<freeze> --out=<fresh>`: PASS. All nine arms
  identical; A0 pointers resolve; scope unchanged. The regenerated
  `first_divergences.csv` is byte-identical to the committed evidence.
- `gut.R` into fresh scratch: control PASS, and all six corruptions are
  detected on their intended fields:
  - `fills$qty` with event_seq 1
  - `equity$cash`, one ULP
  - `positions$qty` with P01
  - `ledger$instrument_id` from the order swap
  - `conditions`, warning removed
  - `ledger`/`fills` after prior usability is removed from the executed rule

  `gut_differences.csv` is byte-identical to the committed evidence.
- A0 successor `record.R` then `compare.R` into fresh scratch: 290 files,
  PASS with 295 checks and 0 failures. The result CSV is byte-identical to
  `evidence/a0_successor_compare.csv`. The fresh successor records are
  byte-identical to the committed `v0_2_3_cut3_successors/a0/records`.
- Original A0 `check.R` on this tree with scratch `--out` and `--agreement`:
  exit 1 with "52 record file(s) differ", the count in
  `a0_implementer.txt`. The differences sampled fall in cut 4's successor
  categories:
  - `seed_contract` v1 -> v2
  - `pulse_seed_rule = 2` in `config_json`
  - `wf_folds` `selected_at_utc`, 2026-10-28 -> 2026-10-30

  Not used as a pass (F1). The original check at the pinned pre-cut-4 source
  was not rerun.
- LDG-3138: `test-governance-report.R` passes in full. A revert witness
  sourced the pre-fix tool (`26ea8fb4~1`) on the committed fixture. It
  reported only `LDG-CLOSED`, losing both open-cut tickets. A variant whose
  highest cut is `proposed` also loses `LDG-LOWER` under the old selector.

## Claim checks

- **Unchanged meaning detected.** The economic projection (native.R:107-124)
  keeps these exactly and checks key uniqueness:
  - recording pulse, `event_seq` and instrument
  - qty, price and fee
  - every equity column
  - per-asset terminal quantities, including zeros
  - rebuilt cash, pnl and equity
  - complete `state_json`

  `dense_diff` gates on `identical`, so NA/NaN, attribute and one-ULP
  changes all fail.
- **Representation retained.** Execution stamps, diagnostics, completion,
  warning classes and messages, event IDs and parsed config are compared
  as complete frames. The only exclusions are those in F3.
- **No known difference silently exempted.** Both historical pairs are
  frozen separately, with no cross-arm equality gate. Late-opening first
  divergence: recording pulse 2020-02-25 (dense) versus 2020-02-12 (facts).
  WS4 and M8b own these decisions.
- **Identities not weakened.** The oracle directory is unchanged since
  `cbf25359`. R/src/DESCRIPTION/NAMESPACE are unchanged from `145cc93b`
  through HEAD. Frozen provenance names source `328998db`. The historical
  body is verbatim from `peer_strategy` at `7879e8ba`. The cost bars match
  A0 `fixtures.R:12-24` exactly. The fresh target function is economically
  equivalent to `open_end`: its day-3 target 1 equals the held 1.
- **Changes after the freeze.** native.R changes after the freeze touch only
  the scope guard, pointer row names, diff labelling and the
  history-divergence report, not extraction or projection. The reruns
  reproduce the frozen bytes under the final code.
- **Budgets.** 519 fresh R lines; six of ten detectors. No product, identity
  or stored-format change, so the seven shapes and timing do not apply.
- **Necessity.** The harness is small, uses public APIs and adds dense
  witnesses that A0 lacks (transition, return, mean reversion, EMA,
  late-opening pairs, final-pulse cost control). It references A0 instead of
  copying it. No manifest or registry was added.

Count: one independent verdict for workstream 2 (PASS_AFTER_PATCHES), recorded, not gated.
