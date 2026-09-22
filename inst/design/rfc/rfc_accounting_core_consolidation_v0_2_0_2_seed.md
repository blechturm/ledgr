# RFC Seed: Accounting-Core Consolidation For v0.2.0.2

**Status:** Seed; non-binding. Input to an independent Type 2 response.
**Author/date:** Codex, 2026-09-22
**Evidence:** `post_v0_2_0_1_accounting_core_inventory.md` and its companion
site table.

## 1. Question

What should the accounting core's state representation and event contract
be, given that the duplication is six driver loops around one shared R
kernel, and that the existing compiled kernel is throttled by its own R-side
state marshalling rather than by arithmetic?

## 2. What The Inventory Changed

The roadmap's premise is wrong. There are not eight independent FIFO
replays. There is one canonical R transition kernel, one independent C++
implementation, six drivers, two consumers of a driver, and one duplicated
cost-basis projection. The roadmap must be corrected after this RFC binds;
it is not authority for preserving a refuted count.

The measurements also reject compiled-everywhere as the premise:

| arm | time per event | relative to current R |
| --- | ---: | ---: |
| current R shapes | 250 us | 1.0x |
| compiled as wired | 175 us | 1.4x |
| compiled with flat state threaded | 4.17 us | 60x |
| fixed-shape R prototype | 3.23 us | 77x |

At the measured 1,600-lot peak, R-side pack/unpack is 98 percent of the
compiled path. It traverses all open lots on every pulse, so the compiled
path inherits the same nonlinear shape it was meant to remove. The R
prototype omits validation, CASHFLOW, and equity-row assembly; it is proof
about representation, not a candidate implementation and not proof that R
arithmetic is faster than C++.

Three facts are closed and are not design questions here:

- BUY and SELL are the live side vocabulary. The extra R tokens and their
  directional guards are unreachable from the producer and schema.
- Both implementations use compensated realized-PnL accumulation and the
  same dust-tolerance formula.
- DuckDB I/O was 1.7 percent of measured reconstruction. Moving more work
  into SQL would not address the measured bottleneck.

## 3. Proposed Direction

Bind one semantic contract, two deliberately independent arithmetic
implementations, one replay driver, and projection-specific boundary code.

The canonical implementation remains R. Its state becomes flat and indexed
end to end. C++ is a later accelerator over that contract, not the shape from
which the contract is inferred and not the authority that defines correct
results.

This is a full RFC under governance decision D6. It changes the internal
state contract, the accounting-event boundary, and the placement of the
canonical executable oracle. The exact flat carrier has an executable
feasibility question, so one bounded prerequisite spike should inform the
synthesis before implementation tickets are cut.

## 4. State Representation

### 4.1 Bound invariants

The accounting state should contain only primitive, indexed structures:

- one stable integer index per instrument;
- aligned atomic lot-quantity and lot-price vectors;
- integer ownership and FIFO-order metadata with constant-time head removal;
- running net quantity and cost basis per instrument;
- running total cost basis; and
- realized PnL plus its compensation term.

The lot store may grow geometrically. It must not grow a list one lot at a
time, remove a head with `lots[-1]`, rescan an instrument's lots to recover
net quantity or basis, or convert the whole state at every pulse. Frames are
permitted only at source and result boundaries.

The exact queue carrier is not yet bound. Contiguous segments, integer-linked
queues, and another primitive representation are acceptable candidates only
if they preserve FIFO order, avoid per-event full-state copies, and satisfy
the same complexity gate. A classed environment with by-reference writes is
not automatically better: base subassignment into environment-held vectors
is itself a documented quadratic shape. Ownership and mutation must be
measured, not assumed.

### 4.2 Lifetime and boundaries

Flat state must remain the fold's `state$lot_state` for the whole fold. A
list-to-flat compatibility adapter may run once when an old internal fixture
or opening state enters; a flat-to-boundary adapter may run once when a
legacy internal view genuinely requires it. Neither conversion may run per
pulse, per event, or per result row.

The state is transient and internal. Resume currently reconstructs it from
ordered ledger events, and walk-forward carry reads per-instrument cost basis
from that reconstruction. Therefore this change should require no durable
schema migration and no new identity field. It does require coordinated
changes to:

- opening-state construction and event replay;
- the fold's direct realized-PnL and total-basis reads;
- resume and walk-forward carry;
- the duplicated derived-state basis projection;
- compiled pack/unpack and dispatch; and
- tests that compare the present nested-list shape directly.

If the representation becomes persisted, public, hashed, or serialized as a
new authority, this proposal has escaped its scope and must return to design.

## 5. Event Contract

### 5.1 Prepare once

Database and memory sources should both prepare the same typed event block.
Preparation establishes event order once, maps instrument IDs once, parses
distinct metadata once, validates the properties introduced at that boundary,
and carries primitive columns into the core. The live fold creates the same
internal operation from a validated fill intent; it does not round-trip
through a persisted row.

The core consumes a closed operation code rather than branching repeatedly on
strings and JSON. For the current contract the operations are:

- **fill:** FILL or FILL_PARTIAL, BUY or SELL, positive quantity and price,
  non-negative fee;
- **ledger delta:** a CASHFLOW's already-validated cash and position deltas,
  with no lot mutation; and
- **position seed:** the current opening-position CASHFLOW, including signed
  quantity and finite cost basis, which creates the opening lot.

This classification does not change the persisted event vocabulary. In this
release, opening positions remain compatible with their current CASHFLOW plus
metadata encoding. Metadata is decoded at the boundary and retained for
provenance; the hot core does not parse it per event.

The schema also admits FEE while the audited drivers do not treat it as a
lot operation. This seed assigns it no new economics. Before synthesis binds
the closed operation map, a probe or response must establish whether FEE is
unreachable, deliberately delta-only, or a current inconsistency. It must not
be silently folded into CASHFLOW.

### 5.2 State transition and trajectory

For each operation the canonical R transition updates cash, positions, lot
state, cost basis, and compensated realized PnL in one defined order. It
returns primitive transition facts needed by projections: close quantity,
open quantity, realized close and delta, post-event realized PnL, post-event
cost basis, and the next event sequence where applicable.

One block replay driver applies that transition to ordered event blocks and
threads state across chunks. Projection code remains outside it:

- equity maps the typed trajectory to pulses;
- fills and trades split reversal legs and allocate fees;
- state-as-of retains only final state; and
- persistence or memory handlers materialize their own boundary tables.

A projection may request fewer retained trajectory columns, but it may not
own another event loop with different validation or transition semantics.
The live fold and the replay driver share the R transition, not a data frame
and not a persistence implementation.

Unsupported accounting operations fail closed. The present behavior in which
`ledgr_lot_apply_event()` returns `kind = "ignored"` for an unknown type is not
an acceptable contract for future economic events.

## 6. Canonical R And LCL-0006

Consolidation must not mean one language implementation. The canonical R
transition remains runnable and normative under the accepted governance
decision. The C++ implementation remains an optional, independent
counterparty for the subset it supports.

`LCL-0006` therefore survives. Its cheapest differential traces should feed
the same prepared fill operations and initial flat state separately to R and
C++, then compare exact contractual outputs and only the already-registered
floating tolerance where that contract permits it. Public workflow witnesses
remain separate evidence for dispatch, sinks, and projections.

Old private replay drivers are not preserved merely to manufacture
independence. They already call the shared R kernel and are not independent
FIFO implementations. Independence lives in the R and C++ transition code,
in hand-calculated adversarial traces, and in public-path witnesses--not in six
copies of ordering and row assembly.

CASHFLOW and opening-position evidence cannot use the current C++ kernel as
an oracle because it has no such branch. Until C++ implements the full event
contract, canonical R is checked against independently specified examples for
those operations, and compiled dispatch remains unavailable at call sites
that require them. Agreement on the FILL intersection does not authorize a
fallback or silent mixed engine.

## 7. Equity Settlement And Future Events

Flat lot state does not by itself foreclose corporate-action event types.
Aligned primitive columns can be extended, and deterministic lot traversal
can support a future operation that must inspect or transform open lots.

The proposal would foreclose them if it made the current C++ fill signature
the universal contract, discarded raw event identity after preparation, or
assumed every accounting event has BUY/SELL quantity-price semantics. It does
none of those things.

This RFC does not design dividends, splits, acquisitions, fractional
entitlements, or settlement clocks. The following equity-settlement work must
add explicit operation mappings and state fields under its own accepted
semantics. Unknown types fail closed until then. No placeholder event token or
unused state column is added here in anticipation.

## 8. Sequencing

1. Complete the Type 2 response to this seed.
2. Run one bounded state-through-fold spike under D6 before synthesis binds a
   concrete carrier. It must include ordinary fills, reversal and deep-lot
   traces, opening-position CASHFLOW, ordinary CASHFLOW, chunk boundaries,
   resume reconstruction, and walk-forward basis carry.
3. Bind the flat-state and operation contracts in synthesis. If no carrier
   satisfies the semantic and complexity gates, retain the existing R state
   and consolidate only the drivers; do not disguise a failed shape change as
   an implementation detail.
4. Implement the flat canonical R transition first, with adapters only at
   initialization and result boundaries. Preserve persisted and public
   outputs before making a performance claim.
5. Consolidate the six drivers around one prepared-event replay and remove the
   duplicated basis projection. Delete old loops only after each surface has a
   detecting parity witness.
6. Adapt C++ to the same flat contract as a follow-on. It must support the
   event envelope of any call site it serves and must not repack all open lots
   per pulse. Runtime default or scope expansion remains a later compiled-
   execution decision.
7. Add equity-settlement semantics after the consolidated current contract is
   green, so a new economic operation lands once rather than in six drivers.

Shape comes before consolidation because consolidating around nested lists
would make the measured nonlinear state contract the new shared dependency.
Compilation comes after both because the current FFI boundary is the measured
bottleneck and lacks CASHFLOW.

## 9. Evidence Required Before Old Paths Leave

- Exact current-output parity for event order, fills, trades, final state,
  cash, positions, fees, opening lots, and event sequence.
- Existing registered tolerance only for outputs whose contract already
  permits it; no tolerance widening for the refactor.
- Cross-chunk equivalence and identical resume/state-as-of results.
- Differential R/C++ evidence for the supported FILL intersection, with the
  canonical R path still independently executable.
- Independently calculated CASHFLOW and opening-position cases.
- A scaling record over lot depth that detects `lots[-1]`, repeated net/basis
  scans, and any per-pulse whole-state conversion. A single timing threshold
  without a failure-sensitive structural detector is insufficient.
- A profile with production validation restored. The prototype's 77x result
  is not an acceptance threshold.

## 10. Rejected Directions

- **Compiled at every call site now:** rejected by the 1.4x wired result,
  quadratic marshalling, missing CASHFLOW, and loss of the canonical oracle.
- **Make C++ authoritative:** rejected by AGENTS.md and the accepted governance
  synthesis. Runtime default and normative authority are separate decisions.
- **Consolidate first on nested lists:** reduces code duplication but freezes
  the measured nonlinear contract at the center of the package.
- **Keep six R drivers as verifiers:** they share the same R kernel and mostly
  duplicate preparation and projection mechanics. That is maintenance cost,
  not an independent economic oracle.
- **Move reconstruction to DuckDB:** database I/O is not the measured cost, and
  FIFO state is sequential. SQL remains appropriate for source ordering and
  set operations, not as an answer to the lot-state shape.
- **Direct tickets without an RFC:** the state, event, and oracle boundaries
  are exactly the authority changes for which D6 requires a full RFC.

## 11. Where This Direction Can Fail

| Scenario | Expected behavior | Failure of this design |
| --- | --- | --- |
| Shallow lots make speed immaterial | consolidation still reduces drift | migration cost exceeds correctness value |
| Adapter runs every pulse | structural gate fails | flat state becomes cosmetic |
| Validation dominates fixed R | preserve validation and report the result | performance case shrinks; correctness case remains |
| Chunk split changes accumulation | exact/tolerant parity fails as applicable | block contract changed operation order |
| Shared preparation has a bug | hand-calculated traces and public witnesses fail | R/C++ parity alone shares the bad input |
| Future event needs more lot fields | add aligned fields under its own contract | carrier cannot evolve without another rewrite |
| Projection needs special ordering | projection proves it outside transition | replay grows into a result-layer god object |
| C++ supports only fills | unsupported dispatch fails before execution | silent mixed execution corrupts authority |

## 12. Bias And Next Step

The author implemented much of the execution and optimization work that made
flat primitive state the house style. That creates a bias toward unification
and toward treating migration cost as temporary. The Type 2 respondent should
attack whether one replay driver is actually simpler at each projection
boundary, whether the state invariants are sufficient without prematurely
choosing a carrier, and whether the prerequisite spike is small enough to
answer rather than implement the RFC.

Next: Claude writes the Type 2 response. No production code, test, ticket, or
roadmap correction is authorized by this seed.
