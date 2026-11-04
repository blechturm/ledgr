# RFC: Core Extension Architecture (v0.2.3), Seed v1

- Status: **seed v1** of an active RFC cycle
  ([pipeline](README.md#core-extension-architecture)). Not binding.
- Authors: maintainer with Claude, 2026-11-04.
- Parent: the accepted [lean fold core synthesis](rfc_lean_fold_core_v0_2_3_synthesis.md).
  Opened by [skeleton maintainer decision D2](rfc_lean_core_skeleton_v0_2_3_maintainer_decisions.md);
  no lean-core code is written before this RFC is accepted.
- No external research stage (maintainer, 2026-11-04): this seed draws on
  ledgr's own records only.
- Neighbours, not duplicated here: the core-boundary ADR in
  [macro WS11](../ledgr_v0_2_3_spec_packet/macro_plan.md#ws11-surface-and-cran-preparation-h4-h1-c10-c9-u3)
  owns which capabilities live in the core and which in sister packages; the
  [asset precision](README.md#asset-precision-tradability) RFC in macro WS10
  owns price and quantity granularity; the
  [OMS synthesis](rfc_ledgr_oms_seed_synthesis.md) owns order lifecycle
  semantics.

## 1. The Question

The lean core is the one moment when the core's internal shape is cheap to
change. The maintainer's goal is a core that can later be extended "easily
and cleanly ... to approach feature completeness for a backtesting/trading
framework", and stays maintainable while it grows.

Two failures are possible. The core can **foreclose**: today's assumptions
(long-only spot, market orders at the next open, one currency, FIFO) get
inlined across stages, so each new capability means reshaping several of
them. Or the core can **overbuild**: plugin hooks, generic metadata and mode
switches added "for later", which break principle 0, the line budgets and
the one-engine rule.

The question for this cycle:

> What fixed internal shape lets each future capability enter the lean core
> by adding one typed piece at one named place, with its contract and its
> tests, while nothing else changes?

This RFC decides that shape and the procedure for using it. It implements no
capability.

## 2. What Already Exists

| Record | What it fixes | Status |
| --- | --- | --- |
| [OMS synthesis](rfc_ledgr_oms_seed_synthesis.md) | Strategies stay target functions (3.1); OMS is a layer inside the one fold, between target deltas and ledger writing (3.2); `order_events` is a second append-only stream (3.3); outstanding-order accounting for paper and live (3.5); FIX-aligned lifecycle states (5); research fills stay synchronous market next-open (6.1) | accepted 2026-05-26; [obligations open](README.md#oms-order-lifecycle) |
| [Execution-policy north star](rfc_execution_policy_pipeline_audit_signal_north_star.md) | The pipeline targets, risk, order policy and sizing, timing, fill proposals, cost, liquidity, ledger validation, events (Section 2); each stage has its own input and output type | proposal, never cycled |
| [Target-risk contract](../contracts.md#contract-execution-target-risk) | Risk is a closed set of classed objects; no user risk callbacks; explicitly not margin, shorting, borrow, liquidity or OMS | shipped |
| [Accounting events contract](../contracts.md#contract-execution-accounting-events) | Closed kind dictionary (`FILL`, `CASHFLOW`, `DISPOSITION`); every arm handles every declared kind or fails closed; one wide typed `ledger_events` table; no JSON evidence | shipped (typed accounting, v0.2.3) |
| [Typed accounting synthesis](rfc_typed_accounting_event_boundary_v0_2_3_synthesis.md) Section 9 | A new event kind or source for another asset class adds typed fields, vocabulary entries and a schema reset through its own focused RFC | accepted |
| [Compiled accounting dispatch](../contracts.md#contract-execution-compiled-accounting) | Accounting is closed by model; `spot_fifo` is not a derivatives or margin engine | shipped |
| [Short exposure rule](../contracts.md#contract-availability-targets) | New or enlarged short exposure is refused before any fill; an existing short is holdable and coverable; lots already take signed quantities | shipped |
| [Shorting and leverage](README.md#shorting-leverage-contract), [cross-asset accounting](README.md#cross-asset-accounting-events) | Each needs its own RFC when triggered | obligations open |
| Horizon, 2026-06-11 strategy gaps | Intra-bar protective exits (stops), lot-selection policies, accrual events (interest, borrow, funding), the unseeded shorting RFC | parked |
| Horizon, 2026-05-25 | Liquidity and capacity are not transaction cost | parked |
| Fold state | One locked environment with a declared slot list (`.ledgr_fold_state_slots`); data-frame slots refused | shipped |

The pieces agree on direction: one fold, closed typed vocabularies, policy
before the ledger, strategies that return targets. What is missing is one
statement of where each kind of extension enters and what adding one costs.

One conflict exists between them. The OMS synthesis's `order_events` design
(4.1) predates typed accounting: it uses string enums and a `meta_json`
column for extra fields, which the typed-accounting boundary has since
retired for ledger events. Section 7 asks how to reconcile them.

## 3. Feature Completeness, Execution Side

A proposal for the execution-side capability map. The WS11 core-boundary ADR
decides the final core and sister list; this table only says which
capabilities the core's internal shape must be able to take.

| Capability | Today | Shape must take it |
| --- | --- | --- |
| Market order at next open | shipped | yes (the only order type) |
| Limit, stop, stop-limit, market-on-close, trailing and bracket orders | none | yes |
| Time in force; orders that stay open across pulses | none | yes |
| Partial fills, volume and participation limits | none | yes (liquidity stage) |
| Short selling, borrow and locate costs | refused (new exposure) | yes |
| Margin and leverage | none | yes |
| Futures (multiplier, variation margin) | none | yes |
| Multi-currency cash and FX | one base currency | yes |
| Lot selection beyond FIFO (LIFO, specific lot, tax-aware) | FIFO | yes |
| Accrual events (interest, borrow, funding) | none | yes |
| Spot crypto | spike green; sister package planned | yes, through precision and adapters |
| OMS lifecycle records in research | none | yes (OMS synthesis 7.3) |
| Paper and live adapters | none | yes, at the edge (OMS synthesis 3.2, 8) |
| Options and other path-dependent derivatives | none | not designed here; a future trigger |
| Intraday below whole-second, HFT | none | never (standing non-goal) |
| Optimizers, ML, validation statistics | sisters | not execution; ledgrverse direction |

## 4. Proposed Shape

### 4.1 One pipeline, named stages, typed handoffs

The lean core keeps E and P1 to P5. Inside planning, the north star's stages
become named sub-stages, each a small function with one typed input and one
typed output:

| Stage | Input -> output | Extension that enters here |
| --- | --- | --- |
| P2 decide | decision view -> raw targets | none (strategies return targets) |
| risk | targets -> targets | risk objects (closed set) |
| order construction | target deltas and holdings -> order intents | order types, sizing policies, OMS outstanding-order netting |
| fill resolution | order intents and execution bars -> fill proposals or no-fill reasons | order-type trigger rules, time in force, intra-bar triggers |
| cost | fill proposals -> priced fills | cost objects (public cost API) |
| liquidity and affordability | priced fills -> fills, clips or refusals | liquidity and capacity policies, margin checks |
| P4 apply | fills and non-fill events -> book, cash, positions | lot-selection policy, accounting models |
| P5 commit | pulse records -> publication | new record streams (`order_events`) |

Today all planning sub-stages exist inside `ledgr_fold_stage_plan()`
(`R/fold-engine.R:1077`), with timing, cost and affordability interleaved.
Naming them changes no behavior (principle 0); it gives each later
extension one place to enter. The order intent is the typed record of the
skeleton's D1: instrument position, side, quantity, order type, timing.
Today the only order type is market at the next open, resolved in the same
pulse.

### 4.2 Closed dictionaries, not plugins

Every extension axis is a closed, versioned dictionary of typed codes, as the
accounting kinds, risk objects and cost objects already are: order types,
time-in-force codes, accounting event kinds, lot-selection policies,
accounting models, instrument-term fields. An unknown code fails closed.

Adding an entry means: a contract section, its typed columns, its case in
the one stage that handles it, a parity or test family with negative
witnesses, and a stated identity and schema impact. No user callback runs
inside execution, as the target-risk contract already rules for risk.

### 4.3 State that outlives a pulse

Outstanding orders, borrow accrual and margin balances are state that lives
across pulses. They enter the same way: a declared, typed fold-state slot
owned by the fold, carried and recorded under the per-pulse records rules
(WS15). Research has none today; adding one is a slot in
`.ledgr_fold_state_slots`, not a new structure beside it.

### 4.4 Instrument terms

Terms that valuation, costs, sizing and accounting need per instrument
(multiplier, currency, price and quantity steps, shortable, margin class) are
typed per-instrument columns of the prepared run, sourced from snapshot facts
when a contract adds them. Until then each term has one declared default in
one place, not a constant inlined across stages. The asset precision RFC
owns the precision terms.

### 4.5 Money and valuation

Cash and valuation pass through one family of functions: publication deltas
(`ledgr_fill_publication_deltas()`, accounting events contract), valuation
and affordability. Multi-currency cash, futures variation margin and
accruals then change that family rather than every stage that touches cash.

### 4.6 Research, paper and live

One pipeline for all three (OMS synthesis 3.2). They differ only in fill
resolution and the edges: simulation in research, an adapter in paper and
live, with asynchronous I/O at the edge, not in the kernel (horizon,
2026-06-13).

## 5. Adding A Capability: The Procedure

1. Route it under `rfc_cycle.md` (Routes): a capability that changes public
   semantics needs an RFC; one that adds a dictionary entry under an accepted
   contract is a direct ticket.
2. Name the one stage, the dictionary entry, the typed columns and the
   fold-state slot (if any) it adds.
3. Write the contract section before the code.
4. Add the parity or test family, with negative witnesses.
5. State identity, schema and store-version impact; a stored-format change
   bumps its version (`AGENTS.md`, no backward compatibility before CRAN).
6. Answer the skeleton D1 check: which other stage changes. Any answer but
   none is a finding.
7. Close with the A2 microsecond and line budgets and A4 subtraction review.

## 6. What This Rules Out

- Plugin or callback hooks inside execution.
- Generic metadata or JSON fields as an extension mechanism.
- Mode or feature-flag branches in fold, run, sweep or walk-forward code.
- A second engine or fold for paper, live, or any asset class.
- Per-asset-class copies of the lot kernel.
- Unused code paths added ahead of a capability.

## 7. Questions For The Response

1. **Sub-stages.** Should the lean core name the planning sub-stages of 4.1
   now, or keep one P3 with internal helpers until the first extension
   needs the seam? Naming now costs some lines; later costs a re-cut of P3.
2. **OMS reconciliation.** The OMS synthesis uses string enums and
   `meta_json`; typed accounting retired both for ledger events. Amend the
   OMS synthesis now, or reconcile at the OMS cut?
3. **Accounting models.** Do shorting, margin and futures extend the one
   signed-lot kernel with per-class valuation and cash rules, or become
   separate closed accounting models like `spot_fifo`?
4. **Cash.** Keep cash a base-currency scalar behind the one function
   family of 4.5, or make it a typed per-currency vector from the start?
5. **Intra-bar triggers.** Can a stop or limit fill inside the pulse's own
   execution bar (conservative OHLC simulation) keep the no-lookahead and
   two-clock guarantees, or must it trigger at the next pulse?
6. **Orders across pulses.** How do outstanding orders appear in the
   per-pulse records and in resume-free reconstruction (WS15)?
7. **Core line.** Does this RFC wait for the WS11 core-boundary ADR, or may
   it fix the execution-side subset of Section 3 for that ADR to adopt?
8. **Is anything missing** from the capability map, or from the shape, that
   would force a second engine or a kernel rewrite later?

## 8. Scope

This RFC binds the core's internal extension shape and the procedure in
Section 5, once a synthesis is accepted. It changes no public behavior,
implements no capability and changes no contract by itself. Each capability
in Section 3 later arrives through its own route. If the synthesis changes a
structure the [lean core skeleton](README.md#lean-core-skeleton) RFC binds,
that synthesis is amended before lean-core code is written.
