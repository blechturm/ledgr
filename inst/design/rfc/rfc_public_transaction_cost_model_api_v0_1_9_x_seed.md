# RFC Seed: Public Transaction-Cost Model API For ledgr

**Status:** RFC seed - public API planning input, not accepted.
**Author:** Codex draft for maintainer review.
**Date:** 2026-05-27
**Target window:** v0.1.9.x / v0.2.0, after target risk and walk-forward
evaluation have stabilized enough to share execution identity.
**Primary research input:** `inst/design/research/Transaction-Cost-Models.md`
**Predecessor RFC thread:** `inst/design/rfc/rfc_cost_model_architecture.md`,
`inst/design/rfc/rfc_cost_model_architecture_response.md`
**Constrained by:** `inst/design/contracts.md`,
`inst/design/ledgr_roadmap.md`,
`inst/design/rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md`,
`inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md`,
`inst/design/rfc/rfc_ledgr_oms_seed_synthesis.md`,
`inst/design/rfc/rfc_execution_policy_pipeline_audit_signal_north_star.md`

---

## 0. Scope And Non-Scope

This seed addresses the future public transaction-cost model API.

It does not reopen the v0.1.8 internal timing/cost boundary. That earlier
thread asked whether the fold core should reserve an internal proposal ->
cost-resolver seam. The codebase now has that seam:

```text
target delta
  -> ledgr_next_open_fill_proposal()
  -> ledgr_resolve_fill_proposal()
  -> internal cost resolver
  -> ledgr_fill_intent
  -> ledger event
```

The unresolved question is now public API:

```text
How should users declare, identify, compose, sweep, document, and audit
transaction-cost assumptions without turning cost into a second execution
engine, liquidity engine, OMS, or arbitrary closure surface?
```

Non-scope for this first public cost API:

- quantity clipping;
- liquidity refusal;
- partial fills;
- order-book queue simulation;
- venue/order lifecycle;
- broker reconciliation;
- paper/live adapter behavior;
- stateful rolling-volume fee tiers;
- borrow, margin interest, carry, or perpetual funding;
- tax-lot and capital-gains accounting;
- implementation-shortfall or TCA reporting;
- arbitrary user functions with replay-stable identity guarantees.

The seed assumes ledgr remains pre-CRAN. Breaking the existing scalar
`fill_model = list(type = "next_open", spread_bps = ..., commission_fixed =
...)` public shape is allowed if the public cost spec deliberately binds a
cleaner API and migration wording.

---

## 1. Current Code And Contract Baseline

The current public surface exposes costs through `fill_model` fields:

```r
fill_model = list(
  type = "next_open",
  spread_bps = 0,
  commission_fixed = 0
)
```

This surface conflates two ideas:

- fill timing: current default is next-open;
- cost application: current default is per-leg spread adjustment plus fixed
  commission.

The internal implementation has already separated the concepts enough to
support later public design:

- `ledgr_next_open_fill_proposal()` creates an internal `ledgr_fill_proposal`;
- `ledgr_fill_context()` carries execution-bar information separately from
  strategy `ctx`;
- `ledgr_cost_spread_commission_internal()` creates the default internal
  resolver;
- `ledgr_resolve_fill_proposal()` applies the resolver inside the fold before
  output handlers see events.

The contract index already binds the load-bearing rules:

- cost resolution belongs inside the fold;
- output handlers must not compute or reinterpret fill prices, fees, cash
  deltas, or cost metadata;
- strategy contexts carry decision-time information only;
- future cost/fill contexts may carry execution-bar data, but must remain
  separate from strategy contexts;
- the private v0.1.8 boundary preserves scalar `fill_model` config identity.

This seed builds on those rules. It does not propose a second execution path.

---

## 2. Research Conclusions

The transaction-cost research note produces eight design conclusions that
should constrain the public API.

### 2.1 Cost is not one economic object

Spread, slippage, commissions, exchange fees, regulatory fees, rebates,
transaction taxes, borrow cost, financing, opportunity cost, and implementation
shortfall have different timing and accounting semantics. Collapsing them into
one "cost function" makes the API simpler but hides the distinctions that users
need for audit and later OMS/TCA work.

### 2.2 Price adjustments and explicit fees are the first clean boundary

The first public cost API should model fill-time transaction costs that fit one
of two shapes:

```text
price transform:
  reference fill price -> adjusted fill price

explicit fee:
  fill proposal / priced fill -> fee cash amount
```

This covers the existing spread/commission behavior and a useful set of
common EOD backtest assumptions.

### 2.3 Liquidity and execution are separate from cost

If a policy changes quantity, refuses a trade, creates partial fills, models
queue position, or consumes volume, it is not merely a cost policy. It belongs
to a later liquidity/execution layer.

The first public cost API should be quantity-preserving.

### 2.4 Full TCA is not the cost API

Delay cost, opportunity cost, benchmark-relative shortfall, VWAP/TWAP
comparison, venue analysis, and implementation-shortfall reporting require
benchmark and lifecycle context. They belong to a later TCA/reporting layer,
not to the fill-time cost API.

### 2.5 Financing is not fill-time transaction cost

Borrow fees, margin interest, carry, and perpetual funding are stateful
calendar or position cashflows. They should not be squeezed into the first
trade-cost API.

### 2.6 Public identity should be object-based, not closure-first

Competitor frameworks generally support custom model objects but do not
document deterministic hashes for arbitrary user callbacks. R closures make
the problem sharper because captured environments are part of behavior.

For ledgr, deterministic run identity is a product promise. The first public
API should therefore use ledgr-classed cost objects with canonical constructor
metadata, not arbitrary functions.

### 2.7 NautilusTrader is the strongest reference implementation

The research points to NautilusTrader as the best conceptual influence:
deterministic event-driven architecture, fee/fill separation, venue-oriented
model assignment, and explicit humility about what historical data can prove.

The lesson is not "copy Nautilus." The lesson is: keep fee logic separate from
fill/liquidity logic, prefer object/config surfaces over naked callbacks, and
solve ledgr's R-native identity problem explicitly.

### 2.8 Core should own primitives, not volatile broker schedules

Broker and exchange fee schedules are account-specific, jurisdiction-specific,
product-specific, and mutable. Core ledgr should own stable primitives and
maybe approximation examples. Authoritative broker templates belong in adapter
packages or user-maintained code unless ledgr later accepts the maintenance
burden explicitly.

---

## 3. Design Thesis

The first public transaction-cost API should expose a small, deterministic,
quantity-preserving, classed cost-object system.

The proposed public mental model:

```text
timing model produces fill proposals
cost model prices proposals and adds explicit fees
ledger records resulting fill intents
```

The proposed first cost contract:

```text
cost_model:
  ledgr_fill_proposal + ledgr_fill_context + explicit cost params
  -> same instrument, side, qty, ts_exec_utc
  -> resolved fill_price and explicit fee amount(s)
```

The cost model may adjust price and add fees. It may not change side, quantity,
execution timestamp, or instrument. It may not create no-fill rows. It may not
implement order lifecycle.

---

## 4. Proposed Public Surface

Names are provisional. The synthesis or future spec may rename them.

### 4.1 Cost chain

```r
cost <- ledgr_cost_chain(
  ledgr_cost_spread_bps(5),
  ledgr_cost_per_share_fee(0.005, min_fee = 1),
  ledgr_cost_notional_bps_fee(0.1, side = "SELL")
)
```

`ledgr_cost_chain()` is an ordered composition of ledgr-classed cost steps.
Order is part of identity. The first public chain should accept ledgr-owned
cost objects only.

The chain compiles before fold execution:

```text
user cost object
  -> validated cost plan
  -> cost_model_hash / provenance
  -> fold execution
```

The compiled plan must be worker-safe:

- plain serializable value object;
- deterministic from explicit inputs;
- no live DB connections;
- no external pointers;
- no active bindings;
- no mutable reference state;
- reconstructable from package code and canonical plan metadata.

### 4.2 Primitive step families

The first useful primitive catalog should be small:

```r
ledgr_cost_spread_bps(bps)
ledgr_cost_price_adjust_bps(bps, side = c("BUY", "SELL", "both"))
ledgr_cost_fixed_fee(amount)
ledgr_cost_notional_bps_fee(bps, min_fee = NULL, max_fee = NULL, side = "both")
ledgr_cost_per_share_fee(amount, min_fee = NULL, max_fee = NULL, side = "both")
ledgr_cost_per_contract_fee(amount, min_fee = NULL, max_fee = NULL, side = "both")
```

This catalog intentionally separates price transforms from explicit fees. It
does not attempt to encode every broker schedule.

Whether maker/taker fees belong in the first catalog is open. If admitted,
they must be convention-driven and honest about missing order-book/queue state:

```r
ledgr_cost_maker_taker_fee(
  maker_bps,
  taker_bps,
  liquidity_flag = "explicit" # or another bound convention
)
```

The seed leans toward deferring maker/taker inference unless the spec binds a
clear approximation convention.

### 4.3 Convenience composites

Small composites may exist when they are transparent wrappers over primitives:

```r
ledgr_cost_equity_retail(spread_bps = 5, per_share = 0, min_fee = 0)
ledgr_cost_zero()
```

These should print their component steps and hash as their expanded chain.
They must not hide broker-certified fee schedules behind broad names such as
`ledgr_cost_ibkr()` unless ledgr accepts versioned schedule maintenance.

### 4.4 Experiment integration

The public integration point must split timing from cost. The spec-cut should
choose exact names.

Recommended direction:

```r
exp <- ledgr_experiment(
  snapshot = snapshot,
  strategy = strategy,
  features = features,
  timing_model = ledgr_timing_next_open(),
  cost_model = ledgr_cost_chain(
    ledgr_cost_spread_bps(5),
    ledgr_cost_fixed_fee(1)
  )
)
```

Alternative if preserving the `fill_model` argument is preferred:

```r
exp <- ledgr_experiment(
  ...,
  fill_model = ledgr_fill_next_open(),
  cost_model = cost
)
```

The seed recommends `timing_model` because `fill_model` has historically
conflated timing and costs. Pre-CRAN status makes the cleaner split available
if the maintainer wants it.

### 4.5 Legacy scalar config

The existing scalar public shape:

```r
fill_model = list(type = "next_open", spread_bps = 5, commission_fixed = 1)
```

should not remain the primary teaching path after the public cost API lands.

Spec-cut must decide whether to:

1. keep it as a compatibility alias translated into `timing_model +
   cost_model`;
2. reject it with a targeted migration error;
3. allow it only through a legacy helper.

Because ledgr is pre-CRAN, the seed prefers a clean break or explicit legacy
helper over indefinite dual teaching.

---

## 5. Identity And Provenance

Cost affects fill prices, fees, cash, positions, equity, metrics, and promoted
run evidence. It belongs to execution identity.

The public cost API must define:

```text
cost_model_version
cost_model_type
cost_model_json
cost_model_hash
cost_plan_hash
cost_step_hashes
```

The exact field names can differ, but the semantics must exist.

### 5.1 Canonical cost object

A cost object hashes from canonical JSON of:

```text
type_id
version
named fixed arguments
ordered child steps, if any
parameter-reference metadata, if admitted
```

It must not hash from:

- function memory addresses;
- R environment serialization;
- object print output;
- package load order;
- row order not part of the cost contract;
- transient run IDs.

### 5.2 Cost chain hash

For a chain:

```text
cost_chain_hash = sha256(canonical_json(
  version,
  ordered vector of cost_step_hash,
  chain-level options
))
```

The order matters. A price transform before a percentage fee may differ from a
percentage fee before a price transform if the fee is computed on adjusted
notional. The API must document ordering semantics.

### 5.3 Run and sweep provenance

Committed runs should store cost identity in config/provenance beside timing,
risk, feature, alias-map, metric-context, and strategy identity.

Sweep candidates should expose cost identity where costs vary across
candidates. If costs are fixed for the experiment, the sweep may record the
experiment-level hash once rather than duplicating it in every row.

Promotion context must preserve the selected candidate's cost identity. A run
promoted from a sweep must replay with the same cost model that produced the
candidate evidence.

---

## 6. Context And No-Lookahead

Cost models must not receive the strategy `ctx`.

They receive a fill/execution context after the strategy decision:

```text
fill_context:
  decision timestamp
  execution timestamp
  execution bar identity
  execution open/high/low/close/volume, when available
  pre-fill cash / positions / equity, if admitted
  account currency, if admitted
  instrument metadata, if admitted
```

The default next-open timing means the cost layer may see next-bar execution
data after the strategy decision. That is not lookahead because strategy code
has already returned targets. The boundary must remain mechanically separate
so next-bar fields cannot leak into strategy decisions.

The first public API should be honest about data limits. With EOD OHLCV bars,
ledgr can support spread proxies, fixed slippage, basis-point slippage, simple
fee schedules, and maybe simple participation-proxy price adjustments. It
cannot honestly infer queue position, maker/taker state, venue routing, or
persistent information impact.

---

## 7. Cost Step Semantics

### 7.1 Price transforms

Price transforms start from the timing proposal's reference price. The current
default reference is the next open.

Examples:

```text
BUY  adjusted_price = reference_price * (1 + bps / 10000)
SELL adjusted_price = reference_price * (1 - bps / 10000)
```

`ledgr_cost_spread_bps()` should preserve the current `spread_bps` public
semantics unless the spec deliberately changes the convention: current
behavior applies the full bps value on each leg, so a round trip costs roughly
`2 * spread_bps` before explicit fees.

### 7.2 Fee adders

Fee adders create explicit cash amounts attached to the fill. V1 should treat
fees as account-currency amounts unless a fee-currency story is explicitly
bound.

Examples:

```text
fixed fee
notional bps fee
per-share fee
per-contract fee
minimum / maximum fee caps
sell-side transaction fee
```

V1 should define whether fees are summed into one ledger field or preserved as
component details in `meta_json` or a future cost-details table. The accounting
ledger needs a total amount; audit/debug surfaces benefit from components.

### 7.3 Negative fees and rebates

Existing internal validation assumes non-negative fixed commissions. Real
markets can have rebates. The first public cost API must decide explicitly:

- ban negative fees in v1 and defer maker/taker rebates;
- allow negative fees only through explicit rebate classes;
- allow any step to emit negative fees subject to structural validation.

The seed leans toward banning general negative fees in v1 and admitting
rebates only if a dedicated rebate/maker-taker convention is bound.

### 7.4 Fee currency

V1 can stay single-account-currency, but it must say so. If a cost step accepts
`currency`, then conversion, missing FX data, and multi-currency ledger
semantics become in scope. That is likely too much for the first public cost
API.

Recommended v1 rule:

```text
All public v1 fees are denominated in the run/account currency. Non-account
fee currencies are deferred.
```

---

## 8. Sweep And Parameterization

The old cost RFC response recommended param-aware cost functions first and a
separate execution grid later. The codebase has since added feature grids and
strategy grids, so the public cost API should not casually reuse
`strategy_params` as the cost-parameter namespace.

This seed proposes:

- fixed cost object arguments are sufficient for the first public release;
- the public docs should teach cost assumptions as experiment/run config, not
  strategy parameters;
- cost sensitivity sweeps are allowed only if the spec binds an explicit
  namespace and identity rule.

Possible future shapes:

```r
ledgr_cost_grid(spread_bps = c(0, 5, 10), fixed_fee = c(0, 1))
ledgr_grid_cross(features = ..., strategy = ..., cost = ...)
```

or:

```r
cost <- ledgr_cost_chain(
  ledgr_cost_spread_bps(ledgr_cost_param("spread_bps"))
)
```

The seed does not bind either. It records the requirement that cost-varying
candidates must not be indistinguishable from strategy-param candidates in
identity, reporting, or promotion context.

---

## 9. Relationship To Target Risk

Target risk lands before the public cost API.

Risk can suppress or reshape targets before timing. Cost prices a proposed
fill after timing. Therefore:

```text
alpha-vs-cost filter:
  target risk or target construction helper, because it decides whether to
  trade before a proposal exists

actual fee/spread application:
  cost model, because it prices an already proposed fill
```

If future risk helpers need cost estimates, the cost API should eventually
provide a read-only estimation surface or policy summary. That estimator is not
the same as applying fill costs. It must not see next-bar execution data if the
risk step runs before timing.

---

## 10. Relationship To OMS And Liquidity

OMS and liquidity are downstream.

The OMS synthesis expects:

```text
order intent -> fill proposal -> cost resolver -> fill intent -> ledger event
```

This cost API should preserve that seam. It should not add order IDs, broker
state, replacement/cancel semantics, or reconciliation state.

Liquidity/execution policy may later fan one order intent into multiple fill
proposals, reduce quantities, or produce no fills. Cost should then price the
proposals it receives. It should not decide which proposals exist.

Partial fills should remain a liquidity/OMS concern. A cost model that tries to
clip quantity is crossing the boundary.

---

## 11. Broker And Exchange Templates

Core ledgr should own primitives and examples, not authoritative broker
schedules.

Recommended ownership split:

```text
core ledgr:
  cost primitives, composition, identity, validation, docs

ledgr docs:
  educational approximations clearly labelled as examples

adapter packages or user code:
  IBKR/Binance/CME/broker-specific schedules

future live adapters:
  reconciliation against actual broker-reported fees
```

If core ledgr ships a recognizable template, it must carry explicit wording:

```text
This is an approximation for research examples. It is not a broker-certified
fee schedule and may not match your account, venue, jurisdiction, or date.
```

The package should avoid names that imply authoritative maintenance unless that
maintenance is actually accepted.

---

## 12. Data Model And Persistence

The first public cost API does not need a new durable cost table.

It does need enough config/provenance fields to answer:

- which cost model priced this run;
- which ordered steps were used;
- which fixed arguments were bound;
- which cost-model version interpreted them;
- whether the cost model was fixed for all candidates or varied by candidate;
- how to reconstruct the same cost plan on replay.

Cost component detail is a separate question. Options:

1. only persist total fee and fill price in existing ledger/fill rows;
2. persist component cost details in `ledger_events.meta_json`;
3. add a dedicated cost-details table;
4. expose component details only in diagnostic retention.

The seed recommends total fee in the canonical accounting path and component
details only when retained explicitly. Do not make every v1 run pay storage
overhead for detailed component rows unless a concrete inspection workflow
requires it.

---

## 13. Proposed v1 Minimum Scope

A first public cost API should include:

1. Public cost object constructors for a small primitive catalog.
2. `ledgr_cost_chain()` ordered composition.
3. Internal compilation to a worker-safe cost plan.
4. Canonical JSON and hash identity for cost objects and chains.
5. Experiment/run integration that cleanly separates timing from cost.
6. Preservation or explicit migration of current `spread_bps` and
   `commission_fixed` semantics.
7. Fold-core integration through the existing proposal -> resolver seam.
8. Run config/provenance fields for cost identity.
9. Sweep/promote provenance rules for fixed and, if admitted, varying costs.
10. Documentation explaining price transforms versus explicit fees.
11. Documentation explaining what is not a transaction-cost model:
    liquidity, financing, TCA, taxes, OMS, and broker reconciliation.
12. Tests for parity with current scalar spread/commission behavior.
13. Tests for deterministic cost hashes and order-sensitive cost chains.
14. Tests that cost models cannot mutate quantity, side, instrument, or
    execution timestamp.
15. Tests that strategy contexts do not expose execution-bar fields.

---

## 14. Explicit Deferrals

Deferred to future RFC/spec work:

- arbitrary user-supplied cost functions with reproducible identity;
- execution/cost grids and cost-param sweep namespaces;
- stateful rolling-volume fee tiers;
- true maker/taker inference from order-book/queue state;
- rebates unless explicitly scoped into v1;
- Almgren-Chriss or schedule-aware impact;
- liquidity clipping, no-fill, volume caps, and partial fills;
- borrow, margin interest, carry, and perpetual funding;
- multi-currency fee accounting;
- tax-lot and capital-gains policy;
- full TCA/reporting layer;
- broker-certified schedule templates in core;
- paper/live fee reconciliation.

---

## 15. Open Questions For Response

1. **Public split name.** Should the first public API introduce
   `timing_model` plus `cost_model`, or preserve `fill_model` as the timing
   argument and add `cost_model` beside it?

2. **Legacy scalar handling.** Should
   `fill_model = list(type = "next_open", spread_bps = ..., commission_fixed =
   ...)` become a compatibility alias, a targeted error, or a legacy helper?

3. **V1 primitive catalog.** Which constructors are essential for v1, and which
   should wait?

4. **Spread versus slippage naming.** Should `ledgr_cost_spread_bps()` preserve
   the existing per-leg spread convention, or should the new API use more
   neutral names such as `ledgr_cost_price_adjust_bps()`?

5. **Negative fees and rebates.** Are rebates admitted in v1, and if so under
   which explicit classes and validation rules?

6. **Fee currency.** Is v1 single-account-currency only, or should fee currency
   be a visible field from day one even if conversion is deferred?

7. **Cost detail retention.** Should component-level cost details be persisted
   in every run, in `meta_json`, in a diagnostic table, or not at all in v1?

8. **Cost sweep namespace.** Does v1 need an explicit `cost_grid` /
   `execution_grid`, or should cost-sensitivity sweeps remain future work?

9. **Parameter references.** If cost objects can contain parameter references,
   are they a new `ledgr_cost_param()` family, reuse of `ledgr_param()`, or
   explicitly deferred?

10. **Assignment model.** Is cost assigned globally to the experiment, per
    instrument, per asset class, per venue, or through ordered fallback rules?

11. **Simple impact proxy.** Does v1 admit a quantity-preserving impact proxy
    using execution-bar volume, or would that imply too much liquidity/execution
    realism?

12. **Maker/taker convention.** If maker/taker is admitted, what observable
    field or explicit user convention determines maker versus taker status?

13. **Broker templates.** Should core ledgr ship any recognizable templates, or
    only primitives plus examples?

14. **Identity migration.** How should existing config hashes be compared when
    old scalar fill-model configs are equivalent to new timing/cost objects?

15. **Cost plan shape.** Should public cost objects compile to one row-wise
    resolver, a vectorized per-pulse resolver, or a plan that can support both?

---

## 16. Recommended Next Step

Do not implement from this seed.

Write a response document against it, with special attention to:

- whether the proposed v1 surface is still too broad;
- whether `timing_model` is worth the pre-CRAN breaking change;
- whether cost sweeps should be in v1 or deferred;
- whether maker/taker and rebates are v1-safe;
- how much cost detail should be persisted;
- whether the object-only public stance is too restrictive for advanced users.

If the response converges, synthesize the accepted public cost API direction
before cutting any v0.1.9.x/v0.2.0 tickets.
