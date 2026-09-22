# RFC Seed v2: Accounting-Core Consolidation For v0.2.0.2

**Status:** Seed v2; non-binding. Supersedes the first seed after the Type 2
response in `rfc_accounting_core_consolidation_v0_2_0_2_response.md`.
**Author/date:** Codex, 2026-09-22
**Next step:** synthesis, then independent Type 1 final review.

## 1. Question

What should the accounting core's state representation and event contract
be, given that the duplication is six driver loops around one shared R
kernel, and that the existing compiled kernel is throttled by its own R-side
state marshalling rather than by arithmetic?

## 2. What Changed After The Response

The first seed made a false inference. The inventory's 77x fixed-shape result
showed that the current algorithmic shapes are expensive; it did not show that
nested lot lists must be replaced before consolidation.

The respondent kept the existing list representation and removed two scans:

- `ledgr_lot_apply_fill()` no longer rescanned every lot for net position;
- `ledgr_lot_set()` no longer rescanned every lot for cost basis.

On the inventory's 2,400-event shape, with identical realized PnL and total
cost basis, the measured result was:

| variant | time per event | relative to current |
| --- | ---: | ---: |
| current list kernel with two scans | 162.5 us | 1.0x |
| list kernel without the scans | 5.83 us | 28x |
| flat-vector prototype | 3.23 us | 50x |

The list-preserving change captured most of the measured opportunity without
changing the external lot-state shape. Flat vectors added 1.8x at that depth.
Their residual advantage grew at hundreds of simultaneously open lots per
instrument, but that is not enough to put a state-contract migration in front
of equity settlement.

The response was wrong on three supporting facts, which v2 does not adopt:

1. A chunked replay exists. `backtest-fills.R:121-139` streams ordered events
   with `dbFetch(..., n = 50000)` and threads lot state across fetches.
2. FEE and FILL_PARTIAL are both dead in current production, but they are not
   the same schema case. The schema admits FEE and rejects FILL_PARTIAL.
3. Sweep lot state is constructed inside the worker at `sweep.R:1364-1405`.
   Candidate tasks cross the `mirai` boundary first; `everywhere()` only loads
   ledgr and attached dependencies on workers.

The central correction still holds: consolidation should precede any flat
carrier. It reduces the number of representation-sensitive call sites and
keeps the current release focused on correctness and equity settlement.

## 3. Established Facts

These facts remain closed:

- There is one canonical R lot kernel, one independent C++ implementation,
  six drivers, two consumers of a driver, and one duplicated basis projection.
- BUY and SELL are the reachable side vocabulary.
- R and C++ both preserve compensated realized-PnL accumulation and use the
  same fractional-dust formula.
- DuckDB I/O was 1.7 percent of measured reconstruction.
- The production-wired C++ path measured 175 us per event against 250 us for
  the original R shapes; flat-state marshalling dominated the C++ path.
- The fixed-shape prototypes omitted some production validation and are not
  release performance records.

The roadmap's eight-replay premise is refuted and must be corrected after the
RFC binds. It does not justify preserving duplicate drivers.

## 4. Revised Direction

Bind one canonical R lot-transition kernel, one prepared-event replay driver,
projection-specific boundary code, and one independent optional C++
implementation for its supported subset.

Keep the current nested-list lot representation for this consolidation. Make
its derived state incremental so the kernel does not rescan open lots on every
fill. Hide the representation behind the transition and replay boundaries so
a later carrier change touches those boundaries rather than every consumer.

Cash and positions remain outside the lot-transition kernel. The live fold and
the replay coordinator own them today; moving them into the kernel would widen
the contract to match the C++ signature without evidence that this is the
right ownership boundary. The consolidated replay updates them from validated
event deltas and calls the lot kernel only for lot-affecting operations.

Flat state and a redesigned R/C++ boundary move to the compiled-execution RFC.
That later decision can test the residual benefit at realistic lot depths and
choose a carrier without blocking current accounting work.

## 5. Canonical R Lot State

The current state fields remain available internally:

- lots by instrument;
- cost basis by instrument and in total;
- realized PnL and its compensation term.

Add or maintain running net quantity by instrument. The fill transition must
update net quantity and basis from the quantities it already consumes and
opens. It must not recover either value by scanning all open lots. Opening
positions must initialize the same running fields through the same invariant.

Head removal with `lots[-1]` and one-at-a-time list append remain known linear
costs. They are accepted for this release because the scan-free list kernel
captured most of the measured gain at the registered depth. Their scaling
record stays visible as input to the compiled-execution RFC; they are not
declared harmless at arbitrary depth.

This is an internal state change, not a persisted one. Resume reconstructs lot
state from ordered ledger events, while walk-forward reads the resulting
per-instrument basis. No database migration, public result change, identity
field, or serialized state authority is introduced.

## 6. Prepared-Event Replay Contract

Database and memory inputs feed one replay through source-specific preparation
functions. Preparation establishes order, extracts columns, maps instrument
IDs, parses metadata, and validates source-specific properties once. The
replay receives typed primitives; it does not receive one-row data frames or
parse JSON inside its event loop.

The current reachable operations are:

- **fill:** FILL with BUY or SELL, positive quantity and price, and a
  non-negative fee;
- **cash/position delta:** an ordinary CASHFLOW updates coordinator-owned cash
  and positions but does not mutate lot state; and
- **opening seed:** an opening-position CASHFLOW also seeds the canonical lot
  state with signed quantity and finite unit basis.

The replay owns operation ordering and state threading. It returns primitive
trajectory facts needed by projections: post-event realized PnL and cost
basis, close and open quantities, realized close and delta, plus final lot
state. Equity, fills, trades, state-as-of, persistence, and memory materialize
their own boundary tables from those facts.

The durable fills reader may keep its 50,000-row fetch boundary, but every
block must pass its final state into the next block. Splitting the same ordered
stream at any event boundary must not change output. Memory inputs may be one
block; chunking is an input concern, not a second replay implementation.

Unknown accounting operations fail closed. This replaces the present generic
`kind = "ignored"` fallback at the consolidated boundary; it does not assign
new economics to dormant tokens.

## 7. Dead Vocabulary Is Cleanup, Not Event Design

FEE is admitted by the current ledger schema but has no package producer or
accounting handler. FILL_PARTIAL is checked by several readers but is neither
emitted nor admitted by the current schema. The four extra side tokens are
also unreachable.

These are bounded cleanup candidates after the RFC is accepted. Their tickets
must distinguish schema migration and historical-read compatibility from dead
R branches; they must not invent FEE, partial-fill, or short-side semantics.
They do not block the replay contract and require no spike.

## 8. Canonical R And LCL-0006

Canonical R remains the normative executable oracle. Consolidation removes
duplicate driver mechanics, not the independent R implementation.

`LCL-0006` continues to compare R and C++ separately on the supported FILL
intersection. Exact contractual outputs remain exact; an existing tolerance
may be used only where its contract already permits it. Public workflow
witnesses continue to guard dispatch, sinks, and projections.

The old replay drivers are not independent FIFO oracles: they call the same R
kernel. Deleting them therefore does not collapse R/C++ differential evidence
into self-comparison. CASHFLOW and opening-position behavior, which C++ does
not implement, stays protected by independently calculated canonical-R cases.

The compiled path remains optional and fill-only. If the scan-free R kernel
removes its measured speed advantage, documentation and later benchmarks must
say so. Performance does not alter its oracle role or silently widen its scope.

## 9. Equity Settlement And Future Events

Consolidation precedes equity settlement so each new economic operation gets
one preparation mapping, one canonical transition decision, and projection
tests rather than six driver edits.

This RFC does not design dividends, splits, acquisitions, fractional claims,
or settlement clocks. Keeping the current list carrier neither guarantees nor
precludes their representation. The settlement design may add explicit
operations or lot attributes after it states their economics. Until then,
unknown accounting types fail closed and no placeholder fields are added.

The current C++ fill signature is not the universal event contract. A future
compiled implementation must support the complete envelope of any call site
it serves or fail before execution.

## 10. Sequencing

1. Accept this RFC's synthesis and cut the consolidation workstream.
2. Remove the repeated net-position and basis scans while retaining list lot
   state. Prove opening, reversal, fractional dust, short, and deep-lot parity.
3. Introduce one prepared-event replay and redirect the five replay drivers
   and their two consumers. The live fold continues to call the same lot
   transition directly. Preserve cross-fetch state and every public projection.
4. Remove the duplicated derived-state basis walk and the superseded driver
   loops only after their detecting witnesses pass.
5. Clean dead side and event vocabulary through bounded tickets with explicit
   migration and historical-read decisions.
6. Land equity-settlement semantics against the consolidated R core.
7. Revisit flat state, C++ marshalling, supported compiled call sites, and any
   runtime-default decision in the compiled-execution RFC.

No prerequisite spike is required. The scan-free list mechanism was measured;
the driver call graph is known; and the remaining choices are contract and
ownership decisions. Under D6, the implementation becomes direct tickets only
after synthesis accepts the direction.

## 11. Evidence Before Old Drivers Leave

- Exact event-order, cash, position, lot, fill, trade, fee, opening-state, and
  event-sequence parity on current supported behavior.
- Existing registered tolerance only where the contract already permits it;
  no widening for consolidation.
- Identical results when a durable event stream crosses the 50,000-row fetch
  boundary and when the same stream is replayed as one memory block.
- Resume, state-as-of, and walk-forward carry parity.
- Canonical R/C++ differential evidence for the supported FILL intersection.
- Independently calculated ordinary-CASHFLOW and opening-seed cases.
- A failure-sensitive scaling detector for reintroduced net-position or basis
  scans, plus the retained depth curve for list head removal.
- A parallel sweep witness with non-empty opening positions. State is built in
  the worker, so this guards construction parity rather than serialization of
  an already-built lot-state object.

## 12. Failure Scenarios

| Scenario | Required result | Design failure |
| --- | --- | --- |
| Shallow lots | exact behavior, modest absolute gain | release claim overstates value |
| Deep accumulating lots | scans stay absent; residual curve recorded | list costs are hidden |
| Durable fetch boundary | state threads across blocks identically | replay resets or reorders |
| Shared preparation bug | hand-calculated and public witnesses fail | parity shares bad input |
| Resume after opening positions | reconstructed basis and lots agree | opening invariant diverges |
| Parallel sweep with opening | worker-local state matches sequential | worker constructs another contract |
| Projection needs special ordering | projection owns it after replay | replay becomes a result-layer god object |
| Future event needs new lot data | later RFC extends explicit contract | current cleanup invented semantics |
| C++ sees unsupported operation | fail before execution | silent mixed engines define truth |

## 13. Rejected Directions And Next Step

- **Flat state before consolidation:** rejected because scan removal captured
  28x without the migration and consolidation reduces later blast radius.
- **Compiled at every call site:** rejected by marshalling, missing CASHFLOW,
  and canonical-R authority.
- **Keep duplicate drivers as oracles:** rejected because they share the R
  kernel and duplicate preparation rather than economic truth.
- **Move replay to DuckDB:** rejected because storage was not the measured
  bottleneck and FIFO transition is sequential.
- **Spike before synthesis:** rejected because the central representation
  question is deferred and the remaining direction is already measurable.

The author's bias remains toward unification and primitive hot-path state. The
response correctly exposed where that preference outran the evidence. v2 now
prefers the smallest reversible sequence: remove redundant scans, consolidate
around the current canonical state, then let later evidence decide its carrier.

Next: synthesis by an author independent of this seed's revision, followed by
Type 1 final review. No code, test, ticket, schema, or roadmap change is
authorized by this seed.
