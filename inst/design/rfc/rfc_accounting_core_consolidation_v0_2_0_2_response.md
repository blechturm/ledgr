# RFC Response: Accounting-Core Consolidation For v0.2.0.2

**Mode:** Type 2 adversarial response to the seed at
`rfc_accounting_core_consolidation_v0_2_0_2_seed.md`.
**Author/date:** Claude, 2026-09-22. Author of the inventory and its
measurements; not author of the seed. Section 3.1 corrected same day: the
28x bundled scan removal with per-call overhead; now decomposed.
**Verified against:** the working tree, the inventory and site table, the
testing-architecture synthesis, AGENTS.md, `contracts.md`, and the
optimization style manual. New measurements are reproducible from the
expressions given.

## 1. Verdict On The Direction

The seed's destination is right and its sequencing is wrong, and the
sequencing error is not a matter of taste: the premise behind it is refuted
by measurement.

Right: one semantic contract, canonical R normative, C++ an independent
counterparty on the subset it supports, one prepared-event replay with
projections outside it, unknown operations failing closed, no corporate
actions designed here. Every part of that survives this response.

Wrong: the claim that shape must change before drivers consolidate because
"consolidating around nested lists would make the measured nonlinear state
contract the new shared dependency" (seed section 8). The nonlinear cost is
not in the list representation. It is in two scans that recompute values the
state already has fields for. Remove the scans, keep the lists, and the
kernel is 28x faster with its external contract untouched. The flat carrier
adds 1.8x on top at the measured depth. The seed has therefore turned a
representation benchmark into a state-contract redesign that the evidence
does not require before consolidation, and placed it in front of equity
settlement, which this release must still land.

## 2. What The Seed Gets Right

- **Section 6 is the best part of the document.** Canonical R stays
  normative; C++ is a counterparty on the FILL intersection; LCL-0006
  survives by feeding identical prepared inputs and initial state to both;
  agreement on the intersection authorises no fallback. That is exactly the
  resolution AGENTS.md and the governance synthesis require, and it is
  stated without hedging.
- **The projection facts are the right facts.** Close quantity, open
  quantity, realized close and delta, post-event realized PnL and cost basis
  are precisely what the fold's `record_accounting_fact` handler
  (`sweep.R:1799-1812`) and the fills projection's fee split
  (`backtest-fills.R`, `ledgr_fill_leg_fees`) consume today. Verified.
- **Failing closed on unknown operations is a real correction.**
  `ledgr_lot_apply_event()` returning `kind = "ignored"` for an unrecognised
  type (`lot-accounting.R:300`) is a latent defect that equity settlement
  would otherwise inherit.
- **Rejecting compiled-everywhere and C++-authoritative** follows from the
  inventory and from `contracts.md:98-108`, which binds the compiled model
  as memory-backed-sweep opt-in only, failing closed for durable runs.

## 3. Blocking Architectural Objections

### 3.1 The shape-first premise is false, and measurably so

The seed reads the inventory's 77x as evidence that the list contract is the
bottleneck. It is not. Profiling attributed the reconstruction cost to
`vapply` (36.2%), `ledgr_lot_set` (20.9%) and `ledgr_lot_basis` (18.6%).
Those are two scans, both inside the kernel and both executed once per fill:

- `lot-accounting.R:174` recomputes net position by summing every open lot;
- `lot-accounting.R:63`, inside `ledgr_lot_set`, recomputes the instrument's
  cost basis by summing every open lot on every state write.

Neither scan is required by the representation. `ledgr_lot_state()` already
carries `cost_basis_by_inst` and `total_cost_basis` (`lot-accounting.R:6-7`);
the kernel computes the exact basis delta in its own loop (`take * price`
per consumed lot, `open_qty * price` per opened lot) and then throws it away
and rescans. Net position needs one more named vector.

I measured the seed's claim directly. Same 2,400-event stream as the
inventory, 8 instruments, peak 200 lots per instrument:

| variant | per event | vs current |
| --- | ---: | ---: |
| current kernel, list, two scans | 162.5 us | 1.0x |
| **list kept, scans and per-call overhead removed** | **5.83 us** | **28x** |
| flat vectors (inventory prototype) | 3.23 us | 50x |

Outputs are identical on realized PnL and total cost basis. The list
representation, the `lots[-1]` pop and the one-at-a-time append are all
kept in the second row; only the two scans and the kernel's per-call
overhead are gone. The representation change is worth 1.8x on top.

That 28x must be decomposed honestly, because the prototype removed two
things at once. Single instrument, N buys then N sells, per event:

| peak lots | current kernel | scans and overhead removed | ratio |
| ---: | ---: | ---: | ---: |
| 2 | 35.0 us | ~2 us | 17x |
| 10 | 30.0 us | ~1.5 us | 20x |
| 50 | 55.0 us | ~1.5 us | 37x |
| 200 | 162.5 us | ~1.5 us | 108x |

At depth 2 the scans are trivial and the ratio is still 17x, so about 30 us
per fill is a constant: validation, `as.numeric()` coercion, and the
`ledgr_lot_get`/`ledgr_lot_set` copies. The scans add roughly 130 us on top
by depth 200. Scan removal alone, with validation kept, is therefore about
5x at depth 200 and about 1x at ordinary depth; the rest is per-call
overhead production must partly keep. That weakens the seed's case, not
mine: at ordinary depth neither the scans nor the representation costs
anything measurable, and a flat carrier addresses only the depth term.

The residual does grow with depth. With lists kept and scans removed, the
per-event cost is below timer resolution to 200 lots per instrument, 9.4 us
at 400, and 14.8 us at 800. So `lots[-1]` is a real cost, but only at
hundreds of simultaneously open lots per instrument, which is not the
package's ordinary regime. That is where a flat carrier earns its keep, and
it belongs to the compiled-execution decision, not to consolidation.

The inventory's 250 us figure for "current shapes" included the derived-state
per-pulse basis recompute (`derived-state.R:305-315`). The kernel alone is
162.5 us. Both numbers are in the inventory's tables; the attribution of the
`lot_basis` share to derived-state was mine and was imprecise. It is called
from `ledgr_lot_set` on every fill, which strengthens rather than weakens the
point: the cost is in the kernel's scans, not in the projection.

### 3.2 The dependency runs the other way

Consolidating six drivers around one kernel does not freeze the
representation; it encapsulates it. Today the nested-list shape is reached
from `fold-engine.R`, `derived-state.R`, `backtest-fills.R`, two functions in
`fold-reconstruction.R`, `walk-forward.R`, `backtest-runner.R`, and the
compiled pack/unpack. After consolidation it is reached from one replay and
one live path. A later carrier change touches two call sites instead of
eight. Shape-first maximises the blast radius of the representation change;
consolidate-first minimises it. The seed's ordering is inverted.

### 3.3 The seed designs for a mechanism that does not exist

"Thread state across chunks," "chunk boundaries," and "cross-chunk
equivalence" appear in sections 5.2, 8 and 9 and in the spike's required
coverage. No chunked replay exists in the tree: `chunk` does not occur in
`fold-reconstruction.R`, `derived-state.R`, `backtest-fills.R`,
`lot-accounting.R`, `backtest-runner.R` or `run-finalize.R`. Every current
replay is a single ordered pass. The seed introduces chunking as a
requirement, then requires the spike to prove it, then lists cross-chunk
parity as evidence before old paths may leave. That is scope the evidence
did not ask for.

### 3.4 The transition quietly absorbs cash and positions

The current R kernel is lot-only. Cash and positions are updated by the fold
engine after the lot call (`fold-engine.R:882-887`). The seed's transition
(section 5.2) "updates cash, positions, lot state, cost basis, and
compensated realized PnL in one defined order." That moves two state
components into the kernel. It may be the right choice, but it is exactly
the C++ signature (`spot_fifo.cpp:61-78` takes positions and cash as state),
which the seed says it is not inferring the contract from. It should be an
explicit decision with its own parity evidence, not a sentence.

### 3.5 The spike is an implementation

Section 8 step 2 requires the spike to cover ordinary fills, reversal and
deep-lot traces, both CASHFLOW forms, chunk boundaries, resume, and
walk-forward carry: every call site in the inventory. A spike that must
exercise the full surface to answer one feasibility question is the RFC's
implementation under another name, built before the direction binds.
Section 3.1 removes the need for it.

### 3.6 Dead vocabulary routed into the RFC

FEE is admitted by the schema (`db-schema-create.R:198`) and has no producer
and no handler anywhere in `R/`. FILL_PARTIAL is never emitted; it appears
only in `%in%` and `identical()` checks. Both are the same class as the four
dead side tokens the inventory already settled: schema-admitted, unreachable.
The seed sends FEE to "a probe or response" before synthesis. It needs a
direct ticket that tightens the CHECK constraint and deletes the checks, with
a one-line reason. It does not need an RFC's attention.

## 4. The Strongest Smaller Alternative

Consolidate first, around the existing kernel, with the scans removed and
the state contract unchanged. Four steps, each reversible, each with its own
detecting evidence.

**Step 1 -- kernel repair, no contract change.** Add `net_by_inst` to
`ledgr_lot_state()`. Maintain `cost_basis_by_inst` and `total_cost_basis`
incrementally inside `ledgr_lot_apply_fill` from the deltas it already
computes; make `ledgr_lot_set` stop rescanning. Delete the four unreachable
side tokens from `ledgr_lot_direction` and the two dead directional guards
and their `net_pos` rescan from `backtest-fills.R:196-224`. Every caller is
untouched because `lots[[id]]`, `cost_basis_by_inst`, `total_cost_basis`,
`realized_pnl` and `realized_comp` keep their names and types. Evidence: the
existing parity suites plus a depth-scaling record. Measured: about 5x at
depth 200 from the scans alone; the per-call overhead is a separate,
smaller and optional follow-on.

**Step 2 -- one prepared-event replay.** One function prepares a typed
event block from either a DuckDB result or an in-memory ordered frame:
instrument index once, timestamps once, metadata parsed once, columns
carried as primitives. One replay applies `ledgr_lot_apply_event` over the
block and returns the transition facts the seed names. Projections stay
outside: equity maps facts to pulses, fills and trades split legs and
allocate fees under `contracts.md:949-953`, state-as-of and resume keep
final state, walk-forward reads `cost_basis_by_inst`. Delete the five old
driver loops and the derived-state basis recompute, which becomes one read
of `total_cost_basis`. Evidence: exact parity on every surface the seed
lists in section 9, minus the chunk items.

**Step 3 -- direct tickets.** Fail closed on unknown event types. Tighten
the schema to the reachable vocabulary. Decide explicitly whether cash and
positions move into the transition; if yes, do it here with its own parity
witness.

**Step 4 -- equity settlement**, against one kernel and one replay.

**Later, as the compiled-execution RFC:** flat carrier, marshalling
elimination, and the C++ event envelope, targeting the measured residual
(1.8x at ordinary depth, more at extreme depth) and the 98% marshalling
overhead. By then the representation sits behind two call sites.

This is smaller than the seed on every axis it names: fewer files touched
before equity, no state-contract change before equity, no spike, and each
step measurable against the same suite that exists today.

## 5. Scenario Results

The seed's table with the alternative added, plus the scenario it omitted.

| Scenario | Seed | Alternative |
| --- | --- | --- |
| Shallow lots, speed immaterial | migration cost may exceed value | step 1 is a few dozen lines; value is correctness of consolidation, not speed |
| Adapter runs every pulse | structural gate | no adapter exists; nothing to run per pulse |
| Validation dominates fixed R | performance case shrinks | same; validation is untouched by step 1 and shared by step 2 |
| Chunk split changes accumulation | parity fails | no chunks exist; not a scenario |
| Shared preparation has a bug | hand traces catch it | same exposure; same mitigation; step 2 keeps the DuckDB and memory sources as two preparation entry points feeding one block shape, so a bug in one does not silently match the other |
| Future event needs more lot fields | add aligned columns | add a field to `list(qty, price)`; lists extend at least as easily as aligned vectors, and without a carrier decision |
| Projection needs special ordering | proves it outside | same; projections stay outside the replay in both |
| C++ supports only fills | dispatch fails closed | same; unchanged by this response |
| **Initial state crosses the worker boundary** | not considered | `sweep.R:1404` places `lot_state` inside the execution spec, which `parallel-workers.R:338-341` ships to `mirai` daemons via `everywhere`. Any by-reference carrier is copied or loses identity at that boundary silently. Lists and flat vectors both serialize; a classed environment does not survive. The seed's section 4.1 discusses environments only for subassignment cost. |
| Opening positions at resume | not distinguished | `ledgr_lot_state_from_opening` seeds through `ledgr_lot_apply_opening` -> `ledgr_lot_set`, so step 1's incremental basis must cover the opening path; the existing fold-witness fixtures detect it |

The missing scenario is the worker boundary. Whichever direction synthesis
binds, its evidence must include a parallel sweep with non-empty opening
positions, or a carrier can pass every serial test and fail in production.

## 6. Where The Inventory Demonstrates And Where It Only Suggests

Demonstrated by mechanism: the call graph; the side vocabulary; accumulator
and tolerance parity; database I/O at 1.7%; the compiled path's marshalling
at 98% and its O(open lots) growth; and now that scan removal with the
contract unchanged removes the depth-dependent term, about 5x at depth 200.

Suggested, not demonstrated: that flat vectors are the *right* carrier. The
77x prototype proved that shape, not representation, is where the cost was.
I read it as decisive for representation when I wrote the inventory's
section 9, and the seed inherited that reading. Section 3.1 corrects it.

Not measured at all: the residual with production validation restored,
beyond the depth-2 floor above; the cost of moving cash and positions into
the transition; anything at depths beyond 800 lots per instrument.

## 7. Spike Versus RFC Decision

The questions that need an RFC decision are answerable from the tree now:
canonical R normative with C++ as counterparty (seed section 6, accept);
one replay with projections outside (accept); fail closed on unknown types
(accept); whether cash and positions join the transition (decide
explicitly). None needs a spike.

The question the seed's spike asks -- can flat state live in
`state$lot_state` through the whole fold -- is the wrong question now.
Section 3.1 shows consolidation does not depend on its answer. It becomes
the compiled-execution RFC's question, and that RFC can run a spike then,
against a consolidated tree with two call sites instead of eight.

No fourth artifact is required before synthesis.

## 8. Bias

I wrote the inventory and its prototype, and I read the 77x as more
architecturally decisive than it was. The seed's author built the flat
primitive house style and reads unification as cheap. Both biases pointed
the same way, toward changing the representation, which is why the seed's
sequencing went unchallenged in the inventory. The measurement in 3.1 is the
correction, and it cuts against my own earlier framing.

## 9. Recommended Next Stage

Revise the seed, not the direction. Seed v2 should keep sections 5.1, 5.2's
projection-fact contract, 6, 7, 10 and 11 substantially as they are, and:

1. Replace section 8 with consolidate-first sequencing: scan removal,
   prepared-event replay, direct tickets, then equity; flat carrier and C++
   envelope deferred to the compiled-execution RFC.
2. Remove chunking from sections 5.2, 8 and 9.
3. Make the cash-and-positions question an explicit open decision.
4. Route FEE and FILL_PARTIAL to a direct ticket alongside the side tokens.
5. Drop the prerequisite spike.
6. Add the worker-serialization scenario to section 11.

One revision should suffice; the false premise is single and measured.

RFC_RESPONSE_DISPOSITION: REVISE_SEED
