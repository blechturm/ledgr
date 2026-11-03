# Workstream 23 implementation closeout

Status: implementation complete; independent Type 1 close review pending.

Workstream 23 implements the schema-124 half of the accepted typed-accounting
boundary. It does not change the ledger DDL or publish schema 125. The product
commits are:

- `ce3371da`: typed carrier, grouped validator, carried block boundary and
  replay;
- `29b6dd1e`: accounting-semantic readers and terminal recovery converge on
  that replay; the accepted INCOMPLETE annualized-return correction lands;
- `d3b8dfef`: the corporate-action summary reuses one prepared replay.

The pre-change evidence commit is `16b64066`. Its checked-in checker reports
93 literal source seams, 30 accounting fields, 22 diagnostic fields and 290
frozen A0 files.

## Implemented boundary

`ledgr_prepare_accounting_events()` is the only schema-124 JSON extraction
boundary. It produces flat vectors and operation codes, carries the previous
sequence and timestamp across fetched blocks, and validates the accepted
per-kind field matrix. Fill effects are exact: an absent or inconsistent
cash/position effect refuses rather than being re-derived. The old WS4a D8
test arm that deliberately shifted a fill effect by 0.5 is therefore
superseded by a wrong-effect refusal witness; its independent source/runtime
checks still prove that P3 computes publication effects once.

The replay owns lot application and disposition reconciliation. Headline
trade counts, corporate-action entitlement/composition/summary projections,
terminal outcomes and terminal recovery read the prepared replay. Terminal
recovery queries and replays once, then projects positions, cash, realized
PnL and basis forward over requested pulses. `inline_summary()` remains the
detected memory-candidate exception. Raw ledger, identity/order, cleanup and
typed dedupe queries remain narrow exceptions and derive no competing state.

## Evidence run

The following focused suites passed on the final product tree:

- `test-accounting-reader-convergence.R` (LTB-0551);
- `test-ws4a-carrier.R`, including split replay, formula mutations and D8;
- corporate-action cash, composition, disposition, results and recovery;
- terminal outcomes and terminal reporting;
- result output, accounting-core consolidation, derived state and
  availability finalization/parity (LTB-0552).

`dev/bench/v0_2_3_typed_accounting/check.R` passes. `git diff --check` was
clean before each implementation commit. The current-format fixture changes
only make hand-built schema-124 rows state fields already required by the
accepted matrix; they do not weaken an economic oracle.

The seven optimization shapes were walked over every changed reader:

1. no growing `c()`, `rbind()` or list append remains on an event path;
2. validation is grouped/vectorized, not one call per event;
3. each top-level migrated projection prepares/replays once (the summary
   passes its replay to the composition projection);
4. terminal recovery performs one stream replay, not one per pulse;
5. the only loops are bounded projection loops over requested instruments or
   sequential valuation pulses, with preallocated output;
6. no candidate-invariant query moved into a pulse or candidate loop; and
7. no new data-frame conversion, JSON encode, database write or hash was
   introduced in replay.

## Open evidence gates

The private Sharadar aggregate record is **OPEN**. No private data was
available in this implementation session, so no digest, count, latency or
peak-memory result is claimed.

The historical A0 successor recorder cannot execute on the current public
API: its frozen fixture omits the now-required `opening = ledgr_opening(...)`
argument and refuses before a workload runs. The checked-in 290-file manifest
is internally valid, but a candidate A0 re-record is therefore not claimed.
This harness/API handoff and the private aggregate record must be dispositioned
before Workstream 23 acceptance.

The registered timing protocol was invoked for `0d6c0b11..29b6dd1e`, but the
shared runner refused before provisioning because the invoking root process
did not have the registered P-core affinity. Under macro-plan rule 16 the
clock is descriptive, not a correctness gate; no timing result is fabricated.
