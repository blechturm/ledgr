# Synthesis: Accounting-Core Consolidation For v0.2.0.2

**Status:** Accepted by the maintainer on 2026-09-22 after Type 1 final
review passed with four patches. Binding for the accounting-core workstream
of v0.2.0.2; implements as direct tickets; no further RFC.
Amended 2026-09-22 on maintainer decision: the lot carrier is bound in this
cycle (section 2), departing from Seed v2's deferral; and one preparer
replaces v2's source-specific preparation (section 3.3).
**Author/date:** Claude, 2026-09-22. Author of the inventory and the Type 2
response; not author of either seed.
**Inputs:** Seed v2, the Type 2 response, the first seed, the accounting-core
inventory and site table, the testing-architecture synthesis, AGENTS.md,
`contracts.md`, the roadmap, and the optimization style manual.

## 1. Corrections The Synthesis Author Owes

Seed v2 rejected three facts from the response. All three rejections hold
against the tree, and this synthesis binds v2's version of each.

1. **A chunked replay exists.** `backtest-fills.R:121-139`: `dbSendQuery`,
   then `repeat { dbFetch(ledger_res, n = 50000) }` with `lot_state`
   initialised at line 134 and carried across fetches (updated at lines
   172 and 236). The response searched for the word,
   not the mechanism. Only that driver chunks; the others replay in one pass.
2. **FEE and FILL_PARTIAL differ at the schema.** `db-schema-create.R:198`
   binds `CHECK (event_type IN ('FILL','FEE','CASHFLOW'))`: FEE admitted and
   never produced, FILL_PARTIAL checked and never admitted. Both dead;
   different cleanups.
3. **Sweep lot state is built inside the worker.** `sweep.R:1272` ships a
   task to `mirai`; the daemon runs `ledgr_sweep_run_candidate` (via line
   1182), which builds lot state at line 1382 from opening numerics. Nothing
   built crosses the boundary; v2's construction-parity witness is right.

One figure in v2 must also be corrected. v2 sections 2 and 13 say scan
removal captured 28x. That prototype removed the two scans *and* the
kernel's per-call overhead (validation, `as.numeric()` coercion,
`ledgr_lot_get`/`_set` copies). Decomposed, one instrument, N buys then N
sells:

| peak lots | current kernel | scans and overhead removed | ratio |
| ---: | ---: | ---: | ---: |
| 2 | 35.0 us | ~2 us | 17x |
| 50 | 55.0 us | ~1.5 us | 37x |
| 200 | 162.5 us | ~1.5 us | 108x |

At depth 2 the scans are trivial and the ratio is still 17x, so about
30 us per fill is per-call overhead. Scan removal alone is about 5x at
depth 200 and 1x at ordinary depth. End to end, the kernel is 3.5% of a
shallow `ledgr_run()` and 25.1% of a deep one: a free kernel buys 1.04x
and 1.33x. Consolidation and the carrier are bound for correctness, house
style, and equity settlement, not for speed.

## 2. Decision

Accept Seed v2's direction with the corrections above, the decisions in
section 4, and one maintainer amendment. Do not write a third seed. No
prerequisite spike.

Bound: one canonical R lot-transition kernel whose lot store is a flat
per-instrument carrier with incremental derived state; one preparer and one
prepared-event replay driver; projection code outside the replay; cash and
positions owned by the fold and the replay, not the kernel; one optional,
independent C++ implementation for its supported subset; unknown accounting
operations failing closed; the C++ event envelope, supported call sites and
runtime default deferred to the compiled-execution RFC; equity settlement after
consolidation.

**The amendment.** v2 kept the nested-list lot store and deferred the
carrier. The maintainer bound it here, on three grounds the response and v2
underweighted:

- **Equity settlement transforms lots.** Roadmap line 1624 scopes v0.2.0.2
  equity as dividend entitlement and payment, cash/security/mixed
  acquisitions, spin-offs, fractional entitlements and unsettled-claim
  valuation. Acquisitions convert lots at a ratio with basis carry;
  spin-offs create lots from lots; claims attach to positions. Landing that
  on `list(qty, price)` makes each new attribute a list field to migrate
  later; landing it on aligned vectors makes it a column from day one.
- **The rule already exists.** Roadmap line 146 records "primitive internal
  shapes, data.frames as boundary views" as a permanent binding rule, and
  that Phase C.2, the FIFO lot store going primitive, was superseded by the
  compiled kernel at v0.1.8.10. The kernel is now throttled by marshalling
  to and from the store that Phase C.2 would have replaced.
- **Scan removal already opens the loop.** Doing scans now and the carrier
  later touches the same code twice, in front of and then behind equity.

The scope is one field. `ledgr_lot_state()` (`lot-accounting.R:1-11`)
already holds `cost_basis_by_inst` as a named vector and three scalars;
only `lots` is nested, read directly by the kernel's own `get`/`set`, the
compiled pack/unpack, and two sites this workstream deletes. The fold's
`state$lot_state` contract does not change; one field's shape does.

## 3. Bound Architecture

### 3.1 The kernel and its carrier

`ledgr_lot_apply_fill` and `ledgr_lot_apply_event` remain the canonical R
transition. The lot store becomes, per instrument index `i`: numeric
`lot_qty[[i]]` and `lot_price[[i]]` of equal length, signed quantity as
today; integer `lot_head[i]` and `lot_tail[i]` bounding the live segment;
geometric growth on push; head removal by advancing `lot_head`; compaction
of the segment when the dead prefix exceeds the live length. `net_by_inst`
is added. `cost_basis_by_inst`, `total_cost_basis`, `realized_pnl` and
`realized_comp` keep their names and types.

The two scans go with it: `lot-accounting.R:174` no longer sums lots for
net position, and `ledgr_lot_set` (`lot-accounting.R:54-69`) no longer
calls `ledgr_lot_basis()` per write. Basis and net are maintained from the
deltas the fill loop already computes, including the opening seed. `get`
and `set` are retired; the kernel writes the vectors by index.

A related prototype -- per-instrument vectors with head and tail indices
at fixed capacity, without growth or compaction -- measured 3.23 us per
event on the inventory's stream. The bound carrier is that family; its own
figure comes from the section 6 profile, not this number. It matches the
C++ kernel's segment. Subassignment into a list-held vector copies it (style
manual shape 7); at the registered depth that is kilobytes and inside the
measured figure. Recorded, not hidden; `collapse::setv` is the escape if a
depth profile ever needs it. Internal only: no persisted field, identity
component, or public result change.

### 3.2 Cash and positions stay outside the kernel

The fold computes cash and position deltas after the lot call
(`fold-engine.R:882-887`) and writes them at lines 888-889; each replay
coordinator does the same. Retained.
The first seed's transition would have absorbed both to match the C++
signature (`spot_fifo.cpp:61-78`); rejected as widening the kernel to fit
an accelerator whose boundary is unproven.

### 3.3 One preparer, one replay

The memory event buffer (`sweep.R:1534-1549`) and the `ledger_events` table
carry the same eleven source columns: `event_id`, `run_id`, `ts_utc`,
`event_type`, `instrument_id`, `side`, `qty`, `price`, `fee`, `meta_json`,
`event_seq`. Memory adds five auxiliaries: precomputed `cash_delta` and
`position_delta`, the replay outputs `event_realized` and
`event_cost_basis`, and an already-parsed `meta` list; materialisation
carries them as attributes (`sweep.R:1661-1665`). Memory's `ts_utc` is
already POSIXct; the table's needs coercion. The preparer's contract is the
eleven source columns. It derives the two deltas from `meta_json` when
absent and never trusts both; it treats `event_realized` and
`event_cost_basis` as outputs, never inputs; and it parses `meta_json`
itself rather than consuming memory's `meta`, so both sources reach one
block by one code path. The block-equality witness compares prepared
blocks, not source auxiliaries.

There is therefore one preparer, not two. It takes a list of column vectors
from either source -- `dbFetch` on one side, the buffer's vectors sliced to
the event count on the other, neither handoff carrying logic -- and
establishes order, maps instrument IDs to a stable index, coerces
timestamps once, parses metadata once, validates the contract once, and
assigns operation codes. The replay loop receives primitives: no one-row data
frames, no JSON per event, and no second validation vocabulary anywhere.
v2's source-specific preparation would have rewritten the three-vocabulary
defect at the boundary built to remove it.

| operation | source | lot effect |
| --- | --- | --- |
| fill | `FILL`, side `BUY` or `SELL`, positive qty and price, fee >= 0 | `ledgr_lot_apply_fill` |
| cash/position delta | ordinary `CASHFLOW` | none; coordinator updates cash and positions |
| opening seed | `CASHFLOW` with opening metadata (`ledgr_lot_meta_is_opening`) | `ledgr_lot_apply_opening` |

Any other `event_type`, side, or metadata shape fails closed at the
consolidated boundary; the `kind = "ignored"` fallthrough at
`lot-accounting.R:301`, and the NA early return at line 275, are removed
there. The replay returns per-event fact
vectors (post-event realized PnL and cost basis, close and open quantities,
realized close and delta, event sequence) plus final lot state: what the
fold's handler (`sweep.R:1799-1812`) and the fee split under
`contracts.md:949-953` consume today.

### 3.4 Projections stay outside

Equity maps facts to pulses; fills and trades split legs and allocate fees;
state-as-of and resume keep final state; walk-forward reads
`cost_basis_by_inst`. Handlers materialise their own tables. A projection
may subset the vectors; it may not own a second event loop, and the replay
takes no retention-policy argument. The fills reader may keep its
50,000-row fetch; each block passes final state to the next, and splitting
one stream at any event must not change output. One replay implementation.

### 3.5 Canonical R and LCL-0006

Canonical R remains the normative executable oracle. The C++ kernel remains
optional, fill-only, and confined to memory-backed sweep execution under
`contracts.md:98-108`. `LCL-0006` continues to compare R and C++ on the FILL
intersection with identical prepared inputs and initial state; exact
outputs stay exact; the dust tolerance (`contracts.md:183-185`) applies
where it already does. CASHFLOW and opening-seed behaviour, which C++ lacks,
are guarded by independently calculated canonical-R cases.

With the carrier bound, the R-to-C++ transfer becomes segment concatenation
and the return a split, replacing per-lot `list()` allocation: cheaper, not
free, and the compiled-execution RFC's to price. The five superseded loops
call the same kernel; deleting them does not collapse `LCL-0006`.

## 4. Open Decisions Resolved

**D1. Per-call overhead.** Validation redundancy, coercion, and residual
copying are a separate optional ticket, gated on keeping every validation
the kernel performs today. Not part of acceptance.

**D2. FEE.** Its ticket first checks persisted runs for any `FEE` row; none
means tighten the `CHECK`, any means document FEE as reserved. No new
economics. Promoted to spec-cut.

**D3. FILL_PARTIAL and the side tokens.** Dead R branches only: the four
extra tokens in `ledgr_lot_direction`, the two guards and their `net_pos`
rescan in `backtest-fills.R:196-224`, every `FILL_PARTIAL` check. No schema
change. One ticket, one commit message naming each.

**D4. Registered claims.** At minimum: fill transition parity across
opening, reversal, dust and deep-lot traces; cross-fetch equivalence for
the chunked reader; resume and walk-forward carry parity; construction
parity under a parallel sweep with opening positions; the existing
`LCL-0006`. Each carries an `[LTB-nnnn]` prefix and promised profile.

**D5. Detector for reintroduced scans.** A timing threshold is
insufficient, and so is a superlinearity test: a rescan inside each write
makes per-event cost linear in depth, not superlinear (inventory section
9: 45 us at depth 50 to 695 us at 800). The detector records normalised
per-event cost across at least four depths and fails on any material
positive depth dependence beyond a preregistered noise allowance. The
workstream proves it with a mutation that reintroduces a write-path scan
and makes the detector fail.

**D6. Carrier.** Per-instrument segments with head index, as 3.1. Linked
queues and classed environments are not bound; a later RFC may replace the
carrier if D5's curve justifies it. Tests comparing the nested shape are
updated to compare through the kernel's accessors, not rebuilt lists.

## 5. Workstream

One workstream, one Type 1 review at its close, direct tickets in order:

1. The carrier, `net_by_inst`, and scan removal on the kernel together
   (sections 3.1, D6), with section 6's parity evidence and the D5 detector.
2. The preparer and replay (3.3) and redirection of every ledger reader
   the inventory names, including its 2026-09-22 correction; the fold
   keeps calling the transition.
3. Removal of the derived-state basis walk (`derived-state.R:305-315`), the
   superseded loops, the pack/unpack list allocation, and the `kind =
   "ignored"` fallthrough, each after its detecting witness passes.
4. Dead vocabulary (D2, D3). 5. Optional per-call overhead (D1).
6. Claims registration (D4) and roadmap correction of the eight-replay row.

Equity settlement opens after this workstream's review is accepted. The
compiled-execution RFC follows, inheriting the D5 curve and 3.5's transfer.

## 6. Evidence Before Old Paths Leave

- Exact parity on event order, cash, positions, lots, fills, trades, fees,
  opening state and event sequence for every supported behaviour; existing
  tolerance only where the contract already permits it.
- Block equality: `prepare(memory)` and `prepare(duckdb)` for the same run
  are identical before any replay, so a handoff bug fails structurally.
- Identical output across the 50,000-row fetch boundary and as one block;
  resume, state-as-of, and walk-forward carry parity.
- `LCL-0006` on the FILL intersection; independently calculated
  ordinary-CASHFLOW and opening-seed cases.
- The D5 detector; a parallel sweep with non-empty opening positions
  asserting worker-built state matches sequential.
- A production-validation profile; prototype multiples are not thresholds.

## 7. Rejected, One Line Each

- The first seed's flat scope: whole fold state contract, prerequisite
  spike, general cross-chunk parity. The carrier is bound narrowly instead.
- v2's source-specific preparation: the sources share one column contract;
  two preparers would duplicate validation, which is the defect at issue.
- v2's deferral of the carrier: overturned by the amendment on the three
  grounds in section 2; recorded as a named departure from v2.
- Compiled at every call site now: 1.4x as wired, no CASHFLOW, and it would
  remove the canonical oracle's counterparty.
- C++ as authority: AGENTS.md. Cash and positions in the kernel: 3.2.
- Six drivers as verifiers: they share the kernel. Replay in DuckDB: I/O
  is 1.7% and FIFO is sequential.
- A prerequisite spike: the carrier is measured; the rest is contract.
- Direct tickets without an RFC: the event contract, fail-closed rule, and
  oracle boundary are authority changes under D6.

## 8. Open Questions Promoted To Spec-Cut

- D2's persisted-`FEE` check and its migration decision.
- Whether walk-forward carry reads `net_by_inst` or keeps deriving from
  `cost_basis_by_inst`; either is acceptable.
- The compaction threshold and initial capacity for the carrier.
- The exact prefix set and profile for each D4 registration.

## 9. Future Obligations Recorded

- **Compiled-execution RFC:** the C++ event envelope (CASHFLOW, opening),
  supported call sites, the R/C++ transfer at the bound carrier, and any
  runtime-default decision; inputs are the D5 curve and inventory section 9.
- **Equity settlement:** explicit operation mappings and aligned per-lot
  columns under its own semantics; unknown types fail closed until then; no
  placeholder columns now.
- **Roadmap and horizon:** correct the eight-replay premise and add the
  post-acceptance horizon entry.

## 10. Failure Scenarios

| Scenario | Bound behaviour | Failure of this design |
| --- | --- | --- |
| Shallow lots | exact behaviour; small gain stated as such | a speed claim is made on the release |
| Deep accumulating lots | no scans; D5 curve flat; copy cost recorded | a rescan returns or the copy dominates unrecorded |
| Durable fetch boundary | state threads identically across blocks | replay resets or reorders |
| Source handoff bug | block-equality witness fails before replay | the bug is in the shared preparer, where block equality is blind |
| Preparer bug | hand-calculated and public witnesses fail | R/C++ parity shares the bad input |
| Resume after opening | reconstructed segments and basis agree | opening invariant diverges from live |
| Parallel sweep with opening | worker-built state equals sequential | worker constructs a different contract |
| Projection needs special order | projection owns it after replay | replay grows a policy argument |
| Equity needs per-lot data | an aligned column under its own contract | this cycle invents semantics |
| C++ sees an unsupported op | fails before execution | silent mixed engines |

## 11. Release Boundary And Final Review

This synthesis gates the accounting-core workstream of v0.2.0.2 and nothing
else. Equity settlement does not open until that workstream's Type 1 review
is accepted. No code, test, ticket, schema, or roadmap change is authorised
before maintainer acceptance.

Final review is Type 1: every line number in sections 1 to 3 resolves; the
carrier in 3.1 is the one measured; D5 is a detector, not a threshold; the
parallel-sweep witness asserts construction parity; no ticket writes cash
or positions inside the lot kernel. Design failure routes to `NEEDS_TYPE_2`.

## Revision History

- 2026-09-22 - Post-acceptance correction: the inventory's driver count was
  low. A full census of `ledger_events` readers found one more lot driver
  (`ledgr_compare_runs_fill_stats`, `run-store.R:366`), two live
  position/cash replays (`ledgr_availability_positions_asof`,
  `availability-results.R:243`; `ledgr_run_finalize`'s reconstruction
  branch, `run-finalize.R:423`), and three dead ones with no callers
  (`derived-state.R:1`, `:42`; `backtest-runner.R:1539`). The bound
  design is unchanged: the replay's cash/position facts serve the live
  ones. Operative scope is in `tickets.yml` LDG-2779 and LDG-2780.
- 2026-09-22 - Accepted by the maintainer. Indexed; horizon entry added;
  roadmap row corrected; AGENTS.md current state updated.
- 2026-09-22 - Type 1 final-review patches (Codex, PASS_AFTER_PATCHES):
  3.3 names all five memory auxiliaries and binds the preparer's handling
  of each; D5 rejects any material depth dependence and requires a
  mutation proof; 3.1 attributes 3.23 us to a related prototype, not the
  bound carrier; citations corrected (backtest-fills 134/172/236,
  fold-engine 888-889, lot-accounting 275/301). No decision changed.
- 2026-09-22 - Amended on maintainer decision: one preparer replaces v2's
  source-specific preparation (3.3, 6, 7, 10). Ground: the memory buffer
  and `ledger_events` share one column contract, so two preparers would
  duplicate validation. The synthesis author's earlier "six became three"
  framing is withdrawn; it is one preparer and one replay.
- 2026-09-22 - Amended on maintainer decision: lot carrier bound in this
  cycle (2, 3.1, D6, 5, 7, 9). Grounds: equity transforms lots; the
  primitive-shapes rule is permanent and Phase C.2 unfinished; scan removal
  already opens the loop. Named departure from Seed v2 section 4.
- 2026-09-22 - Synthesis by Claude from Seed v2, the Type 2 response, and
  the first seed. Section 1 corrects three response facts and the 28x
  figure; the direction is v2's.
