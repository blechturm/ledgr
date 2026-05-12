# RFC: Cost Model Architecture

**Status:** Request for comment — pre-design, no implementation started.
**Author:** ledgr maintainer
**Reviewer:** Codex
**Date:** 2026-05-11
**Context files:**
- `R/fill-model.R` — current fill model implementation
- `inst/design/ledgr_v0_1_8_sweep_architecture.md` — fold-core/output-handler split
- `inst/design/ledgr_roadmap.md` — v0.1.8, v0.1.9, v0.2.0, v0.3.0 milestones
- `inst/design/contracts.md` — execution contracts

---

## Background

ledgr is a backtesting framework for R. The core execution loop is a left fold
over EOD pulses:

```text
final_state = Reduce(apply_pulse, pulses, initial_state)
```

Each pulse: strategy produces targets → fill model converts targets to fills →
ledger records fill events → state updates.

v0.1.8 (in progress) extracts an internal fold core so that `ledgr_run()`
(persisted DuckDB run) and `ledgr_sweep()` (lightweight parameter sweep) call
the same execution primitive. v0.1.9 adds a risk transform layer between
strategy and fill model:

```text
strategy(ctx, params)          -> targets_raw
risk(targets_raw, ctx, params) -> targets_risked
fill_model(targets_risked)     -> fills
```

The risk function is user-supplied and function-valued. It receives `params`,
allowing different sweep candidates to have different effective risk controls
from a single experiment configuration.

---

## The Current Fill Model

`ledgr_fill_next_open()` in `R/fill-model.R` is the only supported fill model.
It takes:

```r
ledgr_fill_next_open(
  desired_qty_delta,   # signed quantity from targets
  next_bar,            # list: instrument_id, ts_utc, open
  spread_bps,          # full spread per leg (BUY pays +bps, SELL pays -bps)
  commission_fixed,    # flat fee per fill event
  price_round_digits
)
```

It returns a `ledgr_fill_intent` with `fill_price = open * (1 ± spread_bps/10000)`
and `commission_fixed` passed through. The ledger writer then computes
`cash_delta = qty * fill_price - commission_fixed` for BUY and
`cash_delta = qty * fill_price - commission_fixed` for SELL.

`spread_bps` and `commission_fixed` are config-level scalars stored in
`fill_model.spread_bps` and `fill_model.commission_fixed`. They are fixed per
run/experiment and are not accessible from the parameter grid in sweep mode.

---

## The Problem

### 1. Fill timing and cost application are conflated

`fill_model.type = "next_open"` bundles two separate decisions:

- **When does the fill execute?** At the open price of the next bar. This is
  an execution timing decision and a ledgr invariant: strategies make decisions
  at the close, fills settle at the next open.
- **What does the fill cost?** Spread markup on the open price plus a fixed
  commission. This is a cost model and it should be independently configurable.

As long as these are one thing, every new cost model requires a new `type`
string. A `"next_open_with_volume_impact"` type would require a new branch in
the fill dispatch logic rather than a separate cost layer.

### 2. The cost model is not function-valued

The risk layer (v0.1.9) is function-valued:
`risk = function(targets, ctx, params) -> targets`. The cost model is not.
`spread_bps` and `commission_fixed` are scalars in `config$fill_model`.

Exchange-specific cost templates — IBKR US equities tiered commissions, a
future Binance maker/taker schedule, a futures-contract multiplier structure —
cannot be expressed as two scalars. They need to be functions.

### 3. The cost model does not receive `ctx` or `params`

`ledgr_fill_next_open` receives only `next_bar$open` from the bar data. It has
no access to volume, volatility, or any other pulse-context field.

Volume-based market-impact models (`fill_price += k * sqrt(qty / volume)`) and
liquidity models (flag or clip fills that would exceed a fraction of daily
volume) both require volume from the current bar or next bar. Neither is
expressible in the current interface.

`params` access is separately required for sweep: to test strategy robustness
across cost assumptions, the cost model must be able to read `params$spread_bps`
or similar. Currently `spread_bps` is a config constant invisible to the
parameter grid.

### 4. No composability

The risk layer will have `ledgr_risk_compose(f1, f2, ...)`. There is no
equivalent for cost. A realistic production cost model might compose:
- a spread layer (proportional to notional)
- a commission layer (fixed or tiered)
- a minimum-trade-value filter (zero fills below threshold)
- a future market-impact layer (adjust price by volume fraction)

Without composability, exchange templates are monolithic functions rather than
assembling shared primitive layers.

### 5. No roadmap milestone

The roadmap has no cost model milestone. The risk layer lands in v0.1.9. The
paper trading adapter lands in v0.3.0, which is the first point where exchange
adapters are introduced. Exchange adapters cannot ship useful built-in cost
templates if the cost model is still a pair of config scalars at that point.

---

## The Concern

v0.1.8 extracts the fold core. That extraction finalises the fold-core function
signature. If cost is baked into that signature as
`fold_core(..., spread_bps, commission_fixed)`, then:

- Market-impact models require a signature change in a future release.
- Exchange templates require either a signature change or an awkward workaround.
- Sweep-varying cost assumptions require a new mechanism.
- The v0.1.9 risk layer and the cost layer have inconsistent contracts: one is
  function-valued with ctx and params access, the other is not.

The fold-core extraction is the lowest-cost moment to reserve a typed slot for
a function-valued cost model, even if the only implementation shipped in v0.1.8
is the default `spread_bps`/`commission_fixed` wrapper.

---

## Proposed Direction (Sketch — Not A Decision)

Separate timing from cost internally. Keep `next_open` as the fold-core
execution timing invariant. Replace the inline cost computation with an optional
`cost_model` argument to the fold core:

```text
timing: fill_proposals <- next_open_timing(targets_risked, next_bar)
cost:   fills          <- cost_model(fill_proposals, ctx, params)
```

where `fill_proposal` carries at minimum `(instrument_id, side, qty, ref_price,
ts_exec_utc)` and the cost model returns the same shape with `fill_price` and
`fee` resolved.

The default cost model wraps current behavior:

```r
ledgr_cost_spread_commission <- function(spread_bps, commission_fixed) {
  function(fill_proposal, ctx, params) { ... }
}
```

Exchange templates become factories of the same shape:

```r
ledgr_cost_ibkr_us_tiered <- function(...) {
  function(fill_proposal, ctx, params) { ... }
}
```

Composability follows the risk pattern:

```r
ledgr_cost_compose <- function(...) { ... }
```

The cost model is included in `config_hash` and run identity, following the
same rule as `risk`.

This sketch is intentionally minimal. It does not propose user-facing API names,
result shape, or validation rules. Those are for the spec.

---

## Questions For Codex

The following are the decisions we need input on before the v0.1.8 fold-core
extraction finalises the internal signature.

**Q1. Timing/cost separation granularity.**
Should the fold core expose a `fill_proposals` intermediate — a typed object
representing "intended fills before cost application" — as a named internal
concept? Or should timing and cost be collapsed back into a single
`fill_model(targets_risked, ctx, params) -> fills` function that the user
supplies whole? The single-function approach is simpler but gives up the ability
to introspect fill proposals before cost is applied, which may matter for
future fill-audit tooling.

**Q2. Cost model signature.**
Is `function(fill_proposal, ctx, params) -> fill` the right signature? The
risk model receives the full `ctx` and `params`. Cost likely needs the same.
Are there fields `ctx` does not currently expose at fill time that a cost model
would need? (Volume of the next bar, for instance, is not currently in `ctx`
at the decision pulse; it would be available if the fill is timestamped at
`next_bar$ts_utc`.)

**Q3. Relationship to the negative cash-delta edge case.**
The execution engine audit identified that `commission_fixed > qty * fill_price`
produces a negative `cash_delta` for a SELL — a guardrail-free edge case
currently deferred. If the cost model becomes function-valued, should this
guard be the cost model's responsibility (validate that the returned fee is
less than notional value for a SELL), or should the ledger writer enforce it?

**Q4. Roadmap placement.**
Should the cost model milestone land alongside the risk layer (v0.1.9), making
the two function-valued execution layers consistent in the same release? Or
should it follow v0.1.9, giving risk time to stabilise before cost is redesigned?
The risk against coupling them is that v0.1.9 is already scoped; the risk
against separating them is that the fold-core signature would have one
function-valued layer and one scalar layer in v0.1.9, with an inconsistency
that persists until the cost model milestone lands.

**Q5. Sweep integration.**
When cost is function-valued, two sweep patterns become available:
- **Param-aware cost**: the cost function reads `params$spread_bps`; the user
  puts `spread_bps` in the parameter grid alongside strategy params.
- **Separate execution grid**: `ledgr_sweep()` accepts a distinct `execution`
  grid (e.g. multiple cost templates) that is crossed with the strategy `params`
  grid, producing a joint result table.

Which is the right model? The param-aware approach requires no new sweep API;
it just lets cost functions be param-aware. The separate execution grid produces
a cleaner result structure where strategy params and execution assumptions are
explicitly labelled as different axes, but it adds API surface and complicates
the candidate identity record.

**Q6. Exchange template ownership.**
Exchange cost templates will eventually need to be kept in sync with real broker
fee schedules. Should these live in the ledgr package itself (maintained by
ledgr), in separate adapter packages (one per broker), or be provided only as
documented examples that users copy and maintain themselves? The answer affects
how the cost model API is versioned and what guarantees ledgr makes about
template correctness.

**Q7. Minimum v0.1.8 commitment.**
Given that v0.1.8 extracts the fold core but does not ship a user-facing cost
model API, what is the minimum internal change that preserves optionality
without shipping incomplete user-facing API? Is reserving an internal
`cost_model` argument to the fold core (defaulting to the spread/commission
wrapper, not exported) sufficient? Or does the fold core need to emit
`fill_proposal` objects that can be inspected, even if nothing inspects them
yet?

---

## What We Are Not Asking

- We are not asking whether to support intraday fills, tick data, or order-book
  simulation. The fill timing model (`next_open`) is a ledgr invariant and is
  not in scope.
- We are not asking about options, futures multipliers, or multi-currency
  accounting. Those are explicitly parked in the roadmap.
- We are not asking for a full cost model implementation. This RFC is about the
  architectural boundary and the fold-core signature commitment for v0.1.8.
