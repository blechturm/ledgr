# RFC: Core Extension Architecture (v0.2.3), Seed v2

- Status: **seed v2** of an active RFC cycle
  ([pipeline](README.md#core-extension-architecture)). Not binding.
- Authors: maintainer with Claude, 2026-11-04. Revised from
  [seed v1](rfc_core_extension_architecture_v0_2_3_seed.md) after the
  [response](rfc_core_extension_architecture_v0_2_3_response.md) (Codex,
  Type 2, REVISE), whose framing the maintainer accepted in the
  [response review](rfc_core_extension_architecture_v0_2_3_response_review.md).
- Parent: the accepted [lean fold core synthesis](rfc_lean_fold_core_v0_2_3_synthesis.md).
  Opened by [skeleton decision D2](rfc_lean_core_skeleton_v0_2_3_maintainer_decisions.md#d2-the-extension-design-gets-its-own-cycle-and-gates-skeleton-code);
  no lean-core code is written before this RFC is accepted, and its synthesis
  may amend the accepted
  [skeleton synthesis](rfc_lean_core_skeleton_v0_2_3_synthesis.md).
- Neighbours, not duplicated: the core-boundary ADR in
  [macro WS11](../ledgr_v0_2_3_spec_packet/macro_plan.md#ws11-surface-and-cran-preparation-h4-h1-c10-c9-u3)
  decides what is core and what is a sister package; the
  [asset precision](README.md#asset-precision-tradability) RFC owns price and
  quantity granularity; the [OMS synthesis](rfc_ledgr_oms_seed_synthesis.md)
  owns order lifecycle semantics, except where Section 7 here proposes to
  supersede it.

## 1. The Question

The maintainer's goal: a core that can later be extended "easily and
cleanly ... to approach feature completeness for a backtesting/trading
framework", and that stays clean and maintainable while it grows.

Seed v1 asked how each capability could enter at one place. The response
showed that this test rewards hiding dependencies: shorting is already
checked in P2 and in planning, and a new accounting source touches its
producer, the writers and the readers. Those are legitimate shared rules.
The question is now:

> Which boundaries must stay fixed, and what is the smallest coherent change
> that adds a contracted capability through the one fold?

"Extension" here means package-owned, reviewed additions to the core. It is
not a public plugin interface, and it does not promise arbitrary feature
completeness: strategies that manage orders directly stay excluded (OMS
synthesis 3.1).

## 2. The Fixed Boundaries

Every extension preserves these. A design that cannot is a finding, not a
variant.

| Boundary | Rule | Authority |
| --- | --- | --- |
| Strategy | `function(ctx, params)` returns a full named target vector; no order objects, lifecycle or broker state reach the strategy | OMS synthesis 3.1; [strategy outputs](../contracts.md#contract-strategy-outputs) |
| Causal observation | P1 is the only substrate reader; P2 sees only its cutoff-bound view; P3 to P5 receive execution columns, not tiles or history | [Fold Core](../contracts.md#contract-execution-fold-core); skeleton synthesis Section 2.1 |
| Authoritative accounting | One ordered, typed `ledger_events` table; closed, validated event kinds; every arm handles each declared kind or fails closed; no JSON evidence | [Accounting events](../contracts.md#contract-execution-accounting-events) |
| Publication and reconstruction | Effects are computed once and published; reconstructed state equals recorded state; reads execute no strategy or callback | [State Reconstruction](../contracts.md#contract-result-reconstruction); per-pulse records synthesis Section 2 |
| One fold | Runs, sweeps, walk-forward, and later paper and live share the fold; no execution-mode branch or feature flag | `AGENTS.md`; OMS synthesis 3.2 |
| Contracts prevail | A conflict with an oracle or an older record goes to an explicit disposition | lean fold core synthesis Section 5 |

## 3. Today's Ownership Map

Seed v1 placed risk inside planning; that was wrong. The current fold, which
the lean core reproduces:

| Stage | Owns today |
| --- | --- |
| E | Sequencing, fold state slots, stop installation |
| P1 observe and settle | The substrate read; settlement and non-fill dispositions before the decision (accounting events contract); valuation marks; the private execution packet with next-bar OHLC |
| P2 decide | The strategy call and full-return validation; the risk chain; post-risk and short-exposure validation (`R/fold-engine.R:1013`) |
| P3 plan | Actionable targets against holdings; fill timing, cost resolution, affordability and short refusal through its planners (`R/fold-engine.R:1117`, `R/availability-economics.R:425`) |
| P4 apply | Lot operations in event order; book, position and cash installation; publication of accounting events |
| P5 commit | Reconciliation, pulse records, flush |

On a scheduled skip, P1, P4 and P5 run and P2 and P3 do not
([Fold Core](../contracts.md#contract-execution-fold-core)).

P3 stays one stage with helpers. A helper is extracted when it owns a real
rule or has a second caller, not to match a diagram
(`optimization_coding_style.qmd`). No stage registry, one carrier class per
step, or unused liquidity or OMS functions.

## 4. Extension Scenarios

The capability list is a set of scenarios the shape must survive, not a
statement of core ownership or delivery; WS11 decides the core line. For each
scenario, the owners it would touch and the open contract questions:

| Scenario | Owners touched | Open contract questions |
| --- | --- | --- |
| OMS lifecycle in research | P3 order construction (the skeleton's order-shaped handoff); P4/P5 publication of a second stream; output retention | Section 7 reconciliation; cross-stream commit (a lifecycle fill never survives without its accounting effect) |
| Orders outstanding across pulses, time in force | A typed fold-state slot; P3; the scheduled-skip path (outstanding orders must still fill, expire or cancel without a fresh strategy call); P4 batching | Per-order state derived from the order stream, not from holdings or strategy state; repeated fills for one instrument as ordered blocks, never merged |
| Limit, stop and other trigger orders, intra-bar | P1 execution packet (already carries OHLC); P3 fill resolution | A new timing contract (Section 6) |
| Protective-order parameters (stop levels, brackets, trailing) | A declared, identity-bearing parameter surface outside the strategy return | How levels are declared without the strategy managing orders (horizon 2026-06-11, gap 1) |
| Short selling, borrow, locate | P2 and P3 refusal rules; typed borrow events through P1 settlement; P4/P5 publication | The shorting and leverage contract |
| Margin and leverage | Affordability (a portfolio constraint, not a lot rule); valuation; typed financing events | Collateral and maintenance rules; same RFC |
| Futures | Valuation and settlement rules; publication (principal is not exchanged); instrument terms | A new economic model under the cross-asset route |
| Multi-currency, FX | Opening state, valuation, sizing, affordability, publication, replay, result currency disclosure | FX facts, conversion and settlement currency; reconstruction must still equal recording |
| Lot selection beyond FIFO | The lot kernel's selection order | Orthogonal to compiled acceleration (horizon gap 2) |
| Autonomous events: accruals, maintenance, expiry, settlement | P1 settlement on every pulse, without new targets | Typed event kinds through the cross-asset route; time-varying terms as causal facts, not timeless defaults |
| Liquidity, partial fills, capacity | P3 between proposal and final fill | Cost and liquidity composition stays open: a clipped fill must carry fees that match its final quantity |
| Paper and live execution truth | Fill resolution replaced by observed broker events at a typed boundary; reconciliation | Observed fills are not discarded by simulated affordability or repriced by the research cost chain; duplicates, late fills, corrections and recovery need their own contract; asynchronous I/O stays at the edge |

These scenarios show limits of today's shape. None shows that a second
engine is needed. Nor can this RFC promise that the event grammar or the
kernel is final: one fold constrains shared semantics, it does not freeze
them.

## 5. Mechanisms

1. **Closed, validated vocabularies.** Order types, time-in-force codes,
   event kinds, lot-selection rules and instrument terms are closed sets of
   validated values that fail closed on an unknown value. Textual tokens are
   fine; what matters is that the set is closed and checked
   (typed-accounting synthesis Section 3).
2. **Typed fields as needed.** A new evidence field becomes a typed column
   when a contract needs it. No generic metadata or JSON escape hatch.
3. **Cross-pulse state as fold-state slots.** Outstanding orders, accrual
   balances and margin state are declared, typed slots owned by the fold.
   A slot is necessary, not sufficient: the scheduling and batching
   boundaries in Section 4 change with it.
4. **Shared accounting primitives.** Signed-book operations are reused
   wherever their arithmetic applies. New settlement, valuation and financing
   rules get named owners in the same fold. `compiled_accounting_model`
   stays an accelerator choice, not a general economic-policy selector; a
   mixed-asset portfolio runs in one run. Today's FIFO is unchanged.
5. **Cash stays a scalar.** Existing economic computations are centralised;
   no currency machinery or term defaults are added before a contract needs
   them.
6. **No new execution-policy callbacks.** Strategies already run inside the
   fold; no further user code runs inside execution.

## 6. Intra-Bar Triggers

A trigger order fixed before an execution interval may use that interval's
OHLC to simulate an outcome, as long as nothing reaches the decision that
created it: P1 already passes next-bar OHLC privately and P2 sees only the
observation. A close-time decision cannot claim a fill from the same bar's
earlier high or low. Next-open behavior does not change.

A future timing RFC must define order activation, gap prices, ambiguous
stop-limit order within one bar, trailing updates, same-bar bracket
activation, fact cutoffs, and event time and recording pulse on both clocks.
OHLC carries no intra-bar ordering, so the convention must be an explicit,
identity-bearing conservative rule or a refusal, never an invented exact
time.

## 7. OMS Reconciliation (Proposed Supersessions)

The [OMS synthesis](rfc_ledgr_oms_seed_synthesis.md) predates typed
accounting, the one-fold rule's ban on feature flags, and the per-pulse
records rule against replay. This cycle's synthesis supersedes the clauses
below with `rfc_cycle.md` notices in the OMS record. Two streams, immutable
links and the lifecycle meaning stay.

| OMS clause | Conflict | Replacement |
| --- | --- | --- |
| 4.1 `meta_json` column and adapter fields stored in it (lines 156, 161) | Typed accounting retired JSON evidence | Typed columns, added as each field is contracted |
| 4.3 ledger link fields inside `meta_json` (line 211) | Same | Typed link columns on the ledger row when OMS lands |
| 12 item 7, a diagnostic feature flag or experiment option (line 566) | One fold, no mode branch; 7.3 already puts retention at the output handler (line 401) | One semantic path; whether lifecycle rows are kept is an output-retention choice |
| 7.4 research decisions "reconstructible from sealed evidence and deterministic execution inputs" (line 411) | Reads execute no strategy (per-pulse records synthesis Section 2) | Research decisions are read from recorded evidence, never regenerated by running strategy code |

Concrete order storage and retention stay with the OMS cut, under these
corrected rules. No columns are created now.

## 8. Proposed Amendment To Skeleton D1

The response argues that D1 promises too much: the lot kernel's fill
validator requires positive prices and distinct positions per call, and
publication computes spot principal exchange, so futures or other contracts
may need kernel changes. Proposed replacement for D1's last sentence, for the
maintainer to decide at synthesis acceptance:

> A design that needs a second engine, a mode branch, or a duplicated kernel
> is a finding. Shared primitives are reused wherever their arithmetic
> applies; a change to the strategy boundary or the lot kernel goes through
> its own contract with parity and is never made silently.

And for the skeleton synthesis's four-row check (Section 2.1): the OMS row
also names the scheduled-skip path and P4 batching as owners.

## 9. Adding A Capability: The Procedure

1. **Route** under `rfc_cycle.md` (Routes). A vocabulary entry under already
   accepted semantics is a direct ticket; a new economic model, event kind
   for another asset class, or timing rule needs its own focused RFC
   (typed-accounting synthesis Section 9).
2. **Owner map.** Name every owner it touches across production,
   reconstruction, identity and failure ordering, and which fixed boundary
   (Section 2) each change preserves.
3. **Contract first.** Write the contract section before the code.
4. **Tests.** A parity or test family with negative witnesses.
5. **Identity and format.** State identity, schema and store-version impact;
   a stored-format change bumps its version and older stores refuse.
6. **Budgets.** Close with the A2 microsecond and line budgets and the A4
   subtraction review.

## 10. What This Rules Out

- Plugin hooks or new user callbacks inside execution.
- Generic metadata or JSON fields as an extension mechanism.
- Mode or feature-flag branches in fold, run, sweep or walk-forward code.
- A second engine or fold for paper, live, or any asset class.
- Per-asset-class copies of the lot kernel; accounting model as a general
  policy selector.
- A stage registry, carrier class per step, or unused functions or columns
  added ahead of a capability.

## 11. Questions For The Synthesis

1. Adopt the D1 amendment of Section 8, as worded or otherwise?
2. Adopt the OMS supersessions of Section 7 now, with notices in the OMS
   record?
3. Should protective-order parameters (Section 4) get their own trigger in
   the pipeline, or wait inside the timing RFC of Section 6?
4. Is any fixed boundary in Section 2 missing or wrong?

## 12. Scope

Once a synthesis is accepted, this RFC binds the fixed boundaries, the
mechanisms and the procedure, and the OMS supersessions it adopts. It
changes no public behavior, implements no capability and adds no column. Each
scenario arrives later through its own route.
