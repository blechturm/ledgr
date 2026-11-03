# Workstream 23 implementation closeout

Status: close-review corrections complete; focused independent confirmation
pending. The private Sharadar aggregate remains an explicit open gate before
Workstream 24 product implementation.

Workstream 23 implements the schema-124 half of the accepted typed-accounting
boundary. It does not change the ledger DDL or publish schema 125. The product
commits are:

- `ce3371da`: typed carrier, grouped validator, carried block boundary and
  replay;
- `29b6dd1e`: accounting-semantic readers and terminal recovery converge on
  that replay; the accepted INCOMPLETE annualized-return correction lands;
- `d3b8dfef`: the corporate-action summary reuses one prepared replay.

The pre-change evidence commit is `16b64066`. The corrected evidence separates
the 290-file historical integrity corpus from the 281-file successor A0
parity record made from immutable base `0d6c0b11`. The producer/writer/reader/
test/doc ownership census and the two field maps are checked literally against
the current source tree.

## Implemented boundary

`ledgr_prepare_accounting_events()` is the only schema-124 JSON extraction
boundary. It produces flat vectors and operation codes, carries the previous
sequence and timestamp across fetched blocks, and validates the accepted
per-kind field matrix. Append validation carries the same boundary across
memory and DuckDB-live writes. Required, null, integral, unknown-key and
formula mutations refuse. Fill effects are exact and use
`ledgr_fill_publication_deltas()` as the single formula authority: an absent
or inconsistent effect refuses rather than being re-derived. The old WS4a D8
arm that deliberately shifted a fill effect by 0.5 is therefore superseded by
a wrong-effect refusal witness; its independent source/runtime checks still
prove that P3 computes publication effects once.

The replay owns lot application and disposition reconciliation. Headline
trade counts, corporate-action entitlement/composition/summary projections,
terminal outcomes and terminal recovery read the prepared replay. Terminal
recovery queries and replays once, then projects positions, cash, realized
PnL and basis forward over requested pulses. The former unsorted and per-time
availability fallbacks are deleted. `inline_summary()` remains the detected
memory-candidate exception. Raw ledger, identity/order, cleanup and typed
dedupe queries remain narrow exceptions and derive no competing state.

## Evidence run

The following focused suites passed on the final product tree:

- `test-accounting-reader-convergence.R` (LTB-0551);
- `test-ws4a-carrier.R`, including split replay, formula mutations and D8;
- corporate-action cash, composition, disposition, results and recovery;
- terminal outcomes and terminal reporting;
- result output, accounting-core consolidation, derived state and
  availability finalization/parity (LTB-0552).

The successor A0 comparator passes over 281 files. Exactly the two
`avail_incomplete` sweep files differ, each in two `annualized_return` cells
from `0` to typed missing; every other byte is equal. The wrapper adds the
former `ledgr_opening(cash = 100000)` default only to the two fixture families
that omitted an opening. `dev/bench/v0_2_3_typed_accounting/check.R` passes.
The current-format fixture changes only make hand-built schema-124 rows state
fields already required by the accepted matrix; they do not weaken an
economic oracle.

The seven optimization shapes were walked over every changed reader:

1. no growing `c()`, `rbind()` or list append remains on an event path;
2. validation is grouped/vectorized, not one call per event;
3. each top-level migrated projection prepares/replays once where its output
   needs replay state; the corporate-action summary retains its narrow fact
   query and shares one replay with composition and unsupported holdings;
4. terminal recovery performs one stream replay, not one per pulse;
5. the only loops are bounded projection loops over requested instruments or
   sequential valuation pulses, with preallocated output;
6. no candidate-invariant query moved into a pulse or candidate loop; and
7. schema-124 necessarily decodes one payload block at the preparation
   boundary, but fill-only blocks do not extract disposition evidence or parse
   all-missing mark timestamps; replay adds no JSON encode, database write or
   hash.

## Open evidence gates

The private Sharadar aggregate record is **OPEN**. No private data was
available in this implementation session, so no digest, count, latency or
peak-memory result is claimed.

The private record is routed as a mandatory precondition before Workstream 24
changes the store: take it from immutable base `0d6c0b11`, compare it with the
final WS23 candidate, and commit only the permitted aggregate evidence. Until
then LDG-3200, LDG-3202 and Workstream 23 remain pending rather than claiming a
pass.

The registered timing protocol now uses the public run-info signature, pins
event/fill counts and a ledger digest, and makes the fill-heavy arm genuinely
fill-heavy. `protocol_smoke.csv` records one successful, explicitly non-gating
candidate execution at product commit `7361951e`; clocks remain descriptive
under macro-plan rule 16 and no timing pass is claimed.

The independent close review is preserved in `close_review_23.md`. Its seven
findings drove these corrections; it is not overwritten by this closeout.
