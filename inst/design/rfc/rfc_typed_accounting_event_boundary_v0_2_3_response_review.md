# Review: Typed Accounting Event Boundary Type 2 Response

- Status: Response accepted after corrections; maintainer decisions and seed
  v2 are next
- Reviewer: Codex, seed v1 author
- Date: 2026-10-29
- Response: `rfc_typed_accounting_event_boundary_v0_2_3_response.md`
- Baseline checked: `269553ca`

## 1. Disposition

**RESPONSE_ACCEPTED_AFTER_PATCHES.** The response improves the design and its
central correction is right: keep `cash_delta` as the replay cash authority,
but keep lot state as the position authority and treat `position_delta` as a
persisted, exactly reconciled publication witness. A seed v2 is required. The
changes affect the field contract, reader census, validation ownership,
public ledger projection and WS7 content too materially for synthesis to
repair seed v1 implicitly.

The wide typed table, removal of accounting-critical JSON, one preparer and
one replay, schema reset and unconditional old-store refusal all survive.

## 2. Corrections Verified

**C1 holds.** The memory sink avoids fill JSON, but opening, corporate cash
and disposition producers still create JSON. `append_event_rows()` parses it
into a list and typed deltas; a later prepared replay parses the materialized
row again. Seed v1 generalized the fill path to every event kind.

**C2 to C4 hold.** The response names the real producers, finds the omitted
reconstruction, state-as-of, walk-forward, headline and public-ledger readers,
and identifies the direct resume-opening append outside the output handler.
The ticket-cut census must include compiled publication as well as canonical R.

**C5 and Q1 hold with one wording correction in Section 3 below.** Fold and
replay positions come from canonical lots, not cumulative
`position_delta`. Cash replay consumes `cash_delta` directly. The two
remaining cumulative position walks are exactly the kind of second accounting
logic WS7 should delete.

**C6 to C8 hold.** Quantity, mark and signed-effect reconciliation is exact;
disposition realized PnL uses the existing dust tolerance. Current fill,
terminal-choice and unsorted-timeline fallbacks must be explicitly deleted,
not inherited. The accounting-event and current-format contract groups require
amendment.

**C10 and C11 hold.** Ordinary memory candidates use `inline_summary()` and
do not replay their buffered event stream. Event-sequence uniqueness is scoped
per run. Scheduled dispositions persist null lifetime labels even though the
resolver can carry a default match internally.

The response also correctly identifies the missing chunk witnesses: cash to
disposition, opening blocks and a disposition whose prior block establishes
`position_before`.

## 3. Corrections to the Response

**R1. C9 is product-runtime deadness, not repository-wide deadness.** No
production reader consumes `ledgr_event_meta`, `ledgr_event_realized` or
`ledgr_event_cost_basis` outside `output-handler.R`, so deletion remains the
right product direction. Tests and `dev/bench/v0_2_3_output_freeze/lib.R` do
consume them. Seed v2 should call them product-dead and require the evidence
harness to migrate; it should not say they have no reader at all.

**R2. Do not generalize the measured storage mix.** The fork establishes the
wide table's result for one deterministic, fill-heavy shape. The response's
claim that a real ledger has the same 98-percent-null mix is not established
for corporate-action-heavy or future workloads. The result still justifies a
wide table as the smallest candidate because no measured companion benefit
exists. Later contrary scale evidence may reopen physical layout without
changing the typed logical carrier.

**R3. Q8 places too much arithmetic only in replay.** One validation
vocabulary may be invoked at two trust boundaries without becoming two
vocabularies. Append must reject structurally invalid rows and arithmetic
inconsistencies knowable from the typed row before they become durable. Read
preparation must validate persisted rows again. Lot-dependent reconciliation,
including disposition realized PnL, occurs during canonical replay. The same
vectorized kind rules should serve append and read; producer-specific one-row
preparer calls and projection-owned validators go away.

**R4. Typed resume dedupe needs source plus fact identity.** Replacing the
full metadata parse with `WHERE source_fact_id IS NOT NULL` alone loses the
cash-versus-disposition distinction used to detect double credit. The typed
query must read at least `source` and `source_fact_id`, then enforce uniqueness
within and incompatibility across the two posting sources.

**R5. Remove guessed migration counts.** The response's final reference to 44
test files mentioning `meta_json` is already 46 under a direct file census;
the count of ledger-projection consumers depends on the search vocabulary.
Seed v2 should require a literal, checked-in source/test/doc census at ticket
cut rather than pinning either count now.

**R6. Keep `position_delta` for a coherent reason.** After WS7 deletes the
entitlement and headline cumulative walks, `position_delta` is not a cheaper
position-state source. It remains a durable publication witness, a compiled
parity field and an exact event-shape reconciliation input. Lot-derived
`position_after` is the only position-state result.

These corrections do not change the response disposition or require another
Type 2 author.

## 4. Architectural Disposition

The response answers seed Section 12 adequately after R1 to R6:

- one wide typed logical table remains the least machinery;
- cash effect and lot-derived position authority are distinct;
- the apparently derivable evidence fields stay because they make the event
  independently auditable or preserve a shipped diagnostic;
- opening cost basis, write-off provenance, source nullability and event-time
  monotonicity need explicit rules;
- WS7 must leave one typed carrier rather than parsed `meta` plus typed vectors;
- public-result parity alone cannot protect resume dedupe or disposition
  reconciliation;
- the producer/consumer census expands materially;
- validation is one rule set reused at append and read, with lot-dependent
  checks in replay; and
- later cross-asset work adds an explicit schema version rather than a generic
  metadata mechanism now.

The response's proposed memory exception is consistent with "one replay":
`inline_summary()` is a specialized live projection over already-computed fill
legs and equity facts, not a second durable ledger replay. Seed v2 must name it
and give it parity evidence against the durable result path.

## 5. Maintainer Decisions

The response correctly promotes four product/sequence choices:

1. **Public ledger projection.** Recommendation confirmed: retain
   `ledgr_results(bt, "ledger")` as `SELECT *`. Its deliberate new wide typed
   shape is documented and tested; other public result tables remain stable.
2. **Opening cost basis.** Recommendation confirmed: preserve every finite
   value, including zero and negative values registered by LTB-0020. Tightening
   would be a separate economic decision, not storage cleanup.
3. **Cut shape.** One cut with WS7 then WS8 is efficient and prevents a
   temporary representation from becoming a release boundary. It is not a
   correctness requirement: WS7 can remain safe alone if it has one typed
   carrier and no dual authority. The maintainer decides whether to amend the
   macro-plan phase boundary.
4. **Memory candidate result path.** Recommendation confirmed: retain and name
   `inline_summary()`. Require parity against the durable path on the supported
   candidate shapes and a production-caller detector.

## 6. Seed-v2 Requirements

Seed v2 should incorporate the response plus R1 to R6 and bind:

- the corrected producer, writer and consumer census;
- cash authority versus lot-derived position authority;
- the flat typed field contract and per-kind required/null/forbidden matrix;
- one vectorized validator reused at append and read, plus lot-dependent replay
  reconciliation;
- removal of current missing-marker, partial-meta and unsorted fallbacks;
- the explicit `SELECT *` ledger decision if accepted;
- the named memory `inline_summary()` exception and parity obligation;
- WS7's surviving typed-scalar changes and WS8's direct typed persistence;
- contract amendments and current-format refusal; and
- source-derived rather than guessed migration counts.

After the maintainer resolves Section 5, Codex may write seed v2. Synthesis
then rotates to an author other than Codex, followed by Type 1 final review.
