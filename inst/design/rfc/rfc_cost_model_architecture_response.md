# Response: Cost Model Architecture RFC

**Status:** Reviewer response; architecture input for v0.1.8 and later.
**Respondent:** Codex
**Date:** 2026-05-11
**Responds to:** `inst/design/rfc/rfc_cost_model_architecture.md`

---

## Summary Verdict

The RFC identifies a real architecture risk. v0.1.8 is the right moment to
reserve an internal cost-model boundary because the fold-core extraction will
otherwise freeze cost as two scalar fields (`spread_bps`, `commission_fixed`)
inside the execution primitive.

The response is:

- Accept the timing/cost separation as an internal architecture direction.
- Do not ship a public user-facing cost-model API in v0.1.8.
- In v0.1.8, reserve the private fold-core slot and typed intermediate needed
  for a future function-valued cost model.
- Keep the existing public `fill_model = list(type = "next_open",
  spread_bps = ..., commission_fixed = ...)` surface unchanged.
- Treat quantity-changing liquidity behavior as a later execution-model
  decision, not as the first cost-model contract.

The most important distinction is this:

```text
timing model: decides when and at what reference bar a fill can occur
cost model:   resolves price and fees for an already proposed fill
ledger:       validates and records the resulting event
```

Cost should not silently become a second target/risk/fill engine.

---

## Minor RFC Correction

The RFC describes the ledger writer as computing:

```text
cash_delta = qty * fill_price - commission_fixed for BUY
cash_delta = qty * fill_price - commission_fixed for SELL
```

The current runner applies the expected sign convention:

```text
BUY:  cash_delta = -(qty * fill_price + commission_fixed)
SELL: cash_delta = +(qty * fill_price - commission_fixed)
```

The architectural argument is unaffected, but the correction matters because
the fixed-commission negative-sale-proceeds edge case is specifically a SELL
case.

---

## Recommended v0.1.8 Commitment

v0.1.8 should reserve the boundary, not expose the feature.

The minimum useful internal commitment is:

```text
targets -> timing proposal -> cost resolution -> fold event
```

with the current behavior represented by an internal default:

```text
next_open timing + spread/commission cost wrapper
```

The public config remains:

```r
fill_model = list(
  type = "next_open",
  spread_bps = 0,
  commission_fixed = 0
)
```

The private fold core should avoid taking `spread_bps` and
`commission_fixed` as primitive arguments. It should instead receive a resolved
execution-cost policy derived from the config. In v0.1.8 that policy can be
private and can wrap the existing scalar fields.

The v0.1.8 parity tests must prove that the refactor does not change current
outputs:

- fill timestamps;
- fill prices;
- fees;
- cash deltas;
- ledger rows;
- equity curves;
- realized/unrealized P&L;
- run comparison outputs.
- `config_hash` values for the same canonical scalar fill-model config.

No public `ledgr_cost_*()` exports are required for v0.1.8.

---

## Q1. Timing/Cost Separation Granularity

Use a typed internal `fill_proposal` concept.

Do not collapse timing and cost into one user-supplied
`fill_model(targets, ctx, params) -> fills` function. That would make the
function too powerful: it could change timing, quantity, price, fees, and
possibly target semantics in one opaque step. That is contrary to ledgr's
auditability model.

The better internal chain is:

```text
targets_risked
  -> next_open_timing()
  -> ledgr_fill_proposal
  -> cost_model()
  -> ledgr_fill_intent
  -> ledger event
```

The proposal is the audit boundary between "the strategy wanted this quantity
change" and "the execution assumptions priced it this way."

Minimum internal proposal fields:

```text
instrument_id
side
qty
ref_price
ts_decision_utc
ts_exec_utc
decision_bar identity
execution_bar identity
```

Useful future fields:

```text
target_before
target_after
qty_delta
execution_bar open/high/low/close/volume
proposal_id or sequence
reason/no-fill code
```

The first v0.1.8 version does not need to persist proposals. It only needs the
internal shape to exist so that a later cost API can be added without changing
the fold-core execution contract.

The proposal and fill-context shape should reserve the full execution bar:

```text
execution open/high/low/close/volume
```

The current default cost model only uses the next open, but volume-based market
impact, participation-rate diagnostics, and future liquidity policies need
volume. In `audit_log` mode the full bar is already available in cached bar
payloads; in `db_live` mode the next-bar query must be widened when this
boundary is extracted.

---

## Q2. Cost Model Signature

The RFC's direction is close, but the signature should not pass the ordinary
strategy `ctx` unqualified.

Recommended eventual shape:

```r
cost_model <- function(fill_proposals, fill_context, params) {
  # returns ledgr_fill_intent-like rows
}
```

Use `fill_context`, not plain `ctx`, because the cost layer legitimately needs
information that the strategy must not see at decision time. For example, a
next-open execution-cost model may need the next bar's open and volume. Passing
that through the strategy context would blur the no-lookahead boundary.

The fill context should be a post-strategy execution context, not the user
strategy context. It can contain:

- decision timestamp;
- execution timestamp;
- current-bar data;
- next-bar execution data;
- current cash, positions, and equity before the fill;
- universe;
- execution assumptions;
- possibly precomputed feature values if a future cost model needs them.

The cost model should return price and fee resolution for the proposals. The
initial contract should preserve side and quantity. It should receive all fill
proposals generated for one pulse, not just one proposal at a time. That batch
shape leaves room for same-pulse fee allocation later while keeping the first
contract stateless across pulses.

The first contract does not express portfolio-level cost state. Daily turnover
limits, cumulative commission budgets, soft-dollar tracking, and liquidity
budgets that span pulses require either the risk layer or a later stateful
execution/liquidity contract.

Quantity-changing behavior should be kept out of the first cost-model contract.
Examples:

- minimum trade value filters;
- volume clipping;
- partial fills;
- liquidity refusal;
- max participation rate.

Those are valid future execution features, but they are not just "cost." They
change what fills. They need a separate execution/liquidity contract or must be
expressed through the risk layer when they are target transforms.

Pre-trade cost filtering also belongs before timing. A rule such as "trade only
when expected alpha exceeds estimated transaction cost" must suppress or alter
targets in the risk layer. The v0.1.9 risk spec should record a bridge to the
future cost model: cost factories should eventually expose an estimation
function, or risk helpers should receive a cost-estimation helper that mirrors
the active cost policy without committing a fill.

---

## Q3. Negative SELL Cash Delta

The ledger writer should enforce structural validity, not business policy.

The ledger writer should validate:

- finite positive `qty`;
- finite positive `fill_price`;
- finite non-negative `fee`;
- valid side;
- valid execution timestamp;
- cash delta computed from the event fields.

It should not silently cap fees or rewrite a cost model's result.

Whether `fee > qty * fill_price` is invalid is a cost-policy decision. It can
be unreasonable for normal equity backtests, but it is not a ledger arithmetic
impossibility. A tiny sale with a large fixed commission can have negative net
proceeds.

Recommended policy:

- v0.1.8: preserve current behavior; no guardrail change.
- Future default cost factories: provide an explicit policy option, for example
  `allow_negative_sale_proceeds = FALSE` by default if the product decision is
  to protect most users.
- Ledger writer: continue to record the result if it is structurally valid.
- Documentation: state whether a cost model may produce negative sale proceeds.

If the product decision is later to ban negative SELL cash deltas globally, that
should be an execution contract change and must live in the ledger writer. It
should not be hidden in one cost factory.

---

## Q4. Roadmap Placement

Do not bundle a public cost-model API into v0.1.8.

Recommended roadmap:

| Milestone | Cost-model scope |
| --- | --- |
| v0.1.8 | Private fold-core boundary: fill proposals and default internal spread/commission cost wrapper. No public API. |
| v0.1.9 | Risk layer as planned. Cost model remains internal unless the risk work is smaller than expected. |
| v0.1.9.x or v0.2.0 | Public cost-model API: factories, validation, identity/fingerprinting, docs. |
| Before v0.3.0 adapters | Adapter-owned or user-owned exchange templates must have a stable cost-model interface. |

This keeps v0.1.8 focused on sweep and fold-core correctness, while avoiding a
signature trap that would make public cost models harder later.

The v0.1.8 spec should include a non-goal:

```text
No exported cost-model API in v0.1.8. The fold core may reserve a private
cost-model slot that preserves current spread/commission behavior exactly.
```

---

## Q5. Sweep Integration

Start with param-aware cost. Reserve space for a separate execution grid later.

The first function-valued cost model should be able to read `params`, so users
can sweep cost assumptions without a new sweep API:

```r
params = list(
  sma_n = 50,
  threshold = 0.02,
  cost = list(spread_bps = 5, commission_fixed = 1)
)
```

That is sufficient for:

- robustness checks across spread assumptions;
- commission sensitivity tests;
- strategy-plus-cost stress tests.

However, ledgr should not pretend strategy parameters and execution assumptions
are the same thing. The sweep candidate identity should eventually distinguish:

```text
strategy_params
feature_params
risk_params
cost_params / execution_assumptions
```

The separate execution grid is useful later:

```r
ledgr_sweep(
  exp,
  params = strategy_grid,
  execution = cost_grid
)
```

but it is not the right first API. It adds surface area and complicates the
candidate result shape before the basic fold-core and sweep contracts are
stable.

Recommended staged decision:

- first public cost release: param-aware cost functions;
- later: optional execution grid if users need labelled strategy-vs-execution
  axes in result tables.

The v0.1.8 fold-core result metadata should be designed so this later split is
possible.

---

## Q6. Exchange Template Ownership

Core ledgr should own primitives, not volatile broker schedules.

Recommended ownership split:

| Layer | Owner | Examples |
| --- | --- | --- |
| Core primitives | ledgr | fixed fee, bps fee, spread, min fee, max fee, composition helpers |
| Educational examples | ledgr docs | "example tiered equity commission", clearly not broker-certified |
| Broker/exchange templates | adapter packages or user code | IBKR, Binance, futures exchange schedules |
| Live adapter reconciliation | adapter packages | broker-specific cash/position/fill reconciliation |

Broker fee schedules change, can be account-specific, jurisdiction-specific,
volume-tier-specific, and product-specific. Shipping them in core ledgr would
create a maintenance and liability burden that does not match the package's
correctness-first posture unless each template carries versioned source
metadata and active maintenance.

Core ledgr should provide the composable API that lets adapter packages express
those schedules.

If ledgr includes any exchange-like template in core, it should be named as an
example or approximation, not as an authoritative broker schedule.

---

## Q7. Minimum v0.1.8 Internal Change

The minimum v0.1.8 change should be:

1. Extract fill timing into an internal next-open proposal step.
2. Introduce an internal typed `ledgr_fill_proposal`.
3. Introduce an internal default cost resolver that maps proposals to the
   current `ledgr_fill_intent` shape.
4. Derive that resolver from the existing scalar config fields.
5. Keep public config, docs, and behavior unchanged.
6. Add parity tests proving exact equivalence to current fill behavior.
7. Add config-hash parity tests proving the same scalar fill model serializes
   to the same `config_hash` across the internal refactor.

The private function names do not matter yet, but the conceptual shape should
be clear:

```text
ledgr_next_open_proposals(targets, state, bars, next_bars)
ledgr_cost_spread_commission_internal(spread_bps, commission_fixed)
ledgr_apply_cost_model(proposals, fill_context, params, cost_model)
```

The fold core should not directly call:

```text
ledgr_fill_next_open(delta, next_bar, spread_bps, commission_fixed)
```

as its primitive architecture. That would preserve the current coupling.

The current `ledgr_fill_next_open()` can remain as a compatibility/helper
function used by the default internal wrapper, as long as the fold core is not
architecturally locked to its scalar signature.

---

## Additional Design Constraints

### Cost Model Identity

Function-valued cost models need identity handling before they become public.
The design should not export user-supplied cost functions until ledgr can answer:

- how is the cost function fingerprinted?
- how are captured objects represented?
- how is source captured?
- does strategy preflight inspect cost functions, or does cost get its own
  preflight?
- how does sweep record cost identity in candidate metadata?

For v0.1.8, avoid this by keeping the cost resolver internal and derived from
existing scalar config.

### No-Lookahead Boundary

Cost models may use next-bar execution data after the strategy decision is
made. Strategies must not see that data.

This should be explicit in the architecture:

```text
strategy ctx: decision-time information only
fill context: execution-time information for pricing and fees only
```

Passing a cost model the ordinary strategy context plus hidden next-bar fields
would make this boundary harder to explain and test.

### Quantity Mutation

The first cost-model contract should not change quantity.

Allowed first contract:

```text
same instrument, side, qty, ts_exec_utc
resolved fill_price and fee
```

Deferred:

```text
partial fills
volume clipping
min-notional no-fill
participation limits
order rejection
```

These features deserve their own execution contract because they affect
positions, cash, event counts, and possibly final-bar/no-fill semantics.

### Output Handler Interaction

Cost resolution belongs inside the fold core before output handlers receive
events. Output handlers should not compute or reinterpret costs.

That preserves parity:

```text
same proposal + same cost model -> same fold event
```

regardless of whether the output handler writes DuckDB rows for `ledgr_run()`
or summary rows for `ledgr_sweep()`.

---

## Recommended Changes To v0.1.8 Planning Docs

Add a short requirement to the v0.1.8 sweep architecture note:

```text
Requirement: Fill timing and cost resolution remain separable inside the fold.

v0.1.8 does not export a cost-model API, but the fold-core extraction must not
hard-code spread_bps and commission_fixed as primitive fold arguments. The fold
should produce next-open fill proposals and resolve them through an internal
default cost resolver that preserves current spread/commission behavior exactly.
```

Add a non-goal:

```text
No exported cost-model factories, exchange templates, market-impact models,
liquidity clipping, or separate sweep execution grid in v0.1.8.
```

Add a parity assertion:

```text
The internal cost-boundary refactor must produce identical fill prices, fees,
cash deltas, ledger rows, equity curves, and metrics to the existing scalar
spread/commission implementation, and it must not change `config_hash` for the
same canonical config.
```

---

## Final Recommendation

Accept the RFC's central concern and act on it narrowly.

v0.1.8 should reserve the internal boundary:

```text
next_open timing -> fill proposal -> default cost resolver -> fill intent
```

It should not expose public cost models yet.

The design should explicitly protect three boundaries:

1. Strategy context remains no-lookahead.
2. Cost context may see execution-bar data but only after the strategy decision.
3. Cost resolution sets price and fees; quantity-changing liquidity behavior is
   deferred to a separate execution contract.

That gives ledgr the future path to function-valued, composable, sweep-aware
cost models without expanding v0.1.8 beyond its core sweep/fold objective.
