# Workstream 23 implementation closeout

Status: two close-review correction rounds complete; final bounded independent
confirmation is PASS_AFTER_PATCHES and its exact record patches are applied.
The private Sharadar aggregate remains an explicit open gate before Workstream
24 product implementation.

Workstream 23 implements the schema-124 half of the accepted typed-accounting
boundary. It does not change the ledger DDL or publish schema 125. The product
commits are:

- `ce3371da`: typed carrier, grouped validator, carried block boundary and
  replay;
- `29b6dd1e`: accounting-semantic readers and terminal recovery converge on
  that replay; the accepted INCOMPLETE annualized-return correction lands;
- `d3b8dfef`: the corporate-action summary reuses one prepared replay.

The focused re-review found that the narrowed corporate-action query omitted
FILL history for a position acquired during the run and later disposed at a
terminal. The correction keeps the parent-only query for composition, gives
the public summary a separate instrument-scoped query, and pins a public run
whose `FILL, DISPOSITION` ledger prints with one disposed position. Durable
and resumed handlers also seed their append boundary from the durable ledger
tail before accepting the first new block.

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
availability fallbacks are deleted. Walk-forward's former dead NULL-substrate
branch now projects the one prepared timeline, and its tests use an independent
prefix-query/replay oracle rather than a deleted product helper. The branch
remains unreachable from `ledgr_walk_forward()`; a direct review probe confirms
its result.
`inline_summary()` remains the detected memory-candidate exception. Raw
ledger, identity/order, cleanup and typed dedupe queries remain narrow
exceptions and derive no competing state.

## Evidence run

The following focused suites passed on the final product tree:

- `test-accounting-reader-convergence.R` (LTB-0551);
- `test-ws4a-carrier.R`, including split replay, formula mutations and D8;
- corporate-action cash, composition, disposition, results and recovery;
- terminal outcomes and terminal reporting;
- result output, accounting-core consolidation, derived state and
  availability finalization/parity (LTB-0552).

The complete package suite passed every WS23-owned block. Eight failures in
three historical/environment groups reproduce unchanged at immutable base
`0d6c0b11`: LTB-0408 and LTB-0416 scan a malformed historical v0.2.2 YAML
record; LTB-0247 is a Windows latin1 assertion; and five sweep-retention
assertions depend on native UTF-8 escaping. They are therefore not represented
as WS23 passes or regressions. One optional-package skip is unchanged.

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

The focused re-review correction removes the all-missing character timestamp
parse and makes db-live write the publication row it already validated instead
of rebuilding its payload. In a same-process descriptive replay of 400 calls
per arm, seven medians compared reviewed product `20026602` with the corrected
tree: 1/20/200-row fill blocks were 950/825/1175 microseconds before and
800/475/875 microseconds after (ratios 0.842/0.576/0.745). Clocks remain
descriptive under macro-plan rule 16.

LTB-0515 again shifts the publication formula through durable, db-live and
memory paths; the alias is included in the D8 source/runtime census so it
cannot hide a second publication computation. Its no-fee fixture uses 4
January solely to append monotonically after its 2 and 3 January witnesses.
The successor A0 comparator now recomputes each file's size and SHA-256 rather
than trusting a stored manifest.

## Private-gate reader corrections

The first private aggregate arm completed, but its public `ledgr_run_info()`,
corporate-action summary and metric reads exposed a reader-only regression.
Product `01cc546d` correctly narrowed subtype prohibitions to the event row;
LTB-0050 keeps an actual DISPOSITION subtype forbidden. That correction did
not close the private failure.

A non-reconstructive predicate census then isolated the real boundary defect:
the 146 lifetime DISPOSITION rows validate when decoded alone, but in the
35,264-row heterogeneous block every one loses its disposition evidence.
`yyjsonr::read_ndjson_str()` inferred the rectangular schema from its default
first 100 rows, before any disposition appeared, and therefore omitted all
later-only evidence columns. Product `b0c54217` supplies the complete block
length as `nprobe`, retaining one bulk decode and one final frame without a
per-row parser or growing collection. LTB-0550 pins the late typed fields in a
102-row mixed block. LTB-0553 moves a real terminal disposition behind 100
valid zero-effect accounting rows and exercises run info, corporate-action
summary and metrics. Restoring the default probe makes both blocks fail.

Focused typed-boundary, terminal-reporting, corporate-action, result-output,
run-store and run-compare suites pass. The source and A0 checkers pass after
the new test seams are registered. The private gate remains open for an
independent exact-candidate rerun; no private value was copied into this tree.

## Open evidence gates

The private Sharadar aggregate record is **OPEN**. Its first candidate arm and
predicate census found the bulk schema-probe defect above before producing an
accepted comparison; Claude must resume the aggregate comparison on product
candidate `b0c54217` plus these record-only changes. No digest, count, latency
or peak-memory pass is claimed yet.

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

The independent close review is preserved in `close_review_23.md`, its focused
re-review in `close_review_23_rereview_1.md`, and its bounded final confirmation
in `close_review_23_rereview_2.md`. Their findings drove the correction rounds;
the private-gate correction review is preserved in
`close_review_23_private_gate_fix.md`. None is overwritten by this closeout.
