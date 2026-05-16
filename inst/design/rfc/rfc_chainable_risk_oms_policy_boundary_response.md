# Response: Chainable Risk And OMS Policy Boundary

**Status:** Reviewer response; design input for v0.1.9 risk layer and later.
**Respondent:** Codex
**Date:** 2026-05-16
**Responds to:** `inst/design/rfc/rfc_chainable_risk_oms_policy_boundary.md`

---

## Summary Verdict

The RFC identifies the right problem space and the right sequencing discipline.
Section 3 (target-risk chain) is accepted as a design direction for v0.1.9 with
five clarifications required before spec cut. Section 4 (research order-policy
chain) is deferred — it conflicts with the accepted cost model architecture
response and pre-empts the v0.2.x OMS design in a way that would constrain it
badly.

This response also adds a first-class design direction not in the RFC: a tiered
output policy that captures intent, derisked targets, and realized fills as
observable fold-core outputs. The risk chain creates the intent/derisked
boundary. Making that boundary observable is the natural next step.

---

## Section 3: Target Risk Chain

Accept the design direction. The fold core already reserves this slot. The
chainable contract is clean and sweep-compatible. Five clarifications are
required before the v0.1.9 spec is cut.

### Clarification 1: Restrict initial release to classed ledgr risk objects

Q1 asks whether `ledgr_risk_chain()` should accept plain functions satisfying
`risk_step(targets, ctx, params) -> targets`.

The cost model architecture response answers this clearly:

> "Function-valued cost models need identity handling before they become public.
> The design should not export user-supplied cost functions until ledgr can
> answer: how is the cost function fingerprinted? How are captured objects
> represented? How is source captured? Does strategy preflight inspect cost
> functions, or does cost get its own preflight?"

Plain function risk steps that enter the execution config hash require all the
same machinery: source capture, fingerprinting, captured-object classification,
and preflight tier. The v0.1.9 release should restrict `ledgr_risk_chain()` to
classed `ledgr_risk_step` objects only. Plain function risk steps are deferred
until ledgr has a preflight-equivalent for risk. The v0.1.9 spec must include
this as an explicit non-goal.

### Clarification 2: Canonical null-risk config hash representation

The RFC correctly identifies that risk chain identity should enter the execution
config hash. It does not address the migration consequence.

Existing runs created before v0.1.9 have no risk chain. A v0.1.9 `ledgr_run()`
with an explicit `ledgr_risk_chain(ledgr_risk_identity())` must hash differently
from a run with no risk chain. But loading a pre-v0.1.9 run must not change its
stored `config_hash`.

Required design: `risk_chain = NULL` serializes as `{"risk_chain": null}` in
canonical JSON. Pre-v0.1.9 runs store no `risk_chain` field; the config hash
contract must specify how absence is treated at hash comparison time. The v0.1.9
spec must address this explicitly rather than leaving backward-compat hash
behavior implicit.

### Clarification 3: Compiled plan is instantiated once per candidate fold

The sweep optimization synthesis identifies per-pulse allocation overhead as the
dominant sweep cost. Risk chain steps must not reconstruct closures or lookup
structures on every pulse call.

The compiled plan (Section 6) must be resolved once at candidate fold setup, not
per pulse. The plan may construct local helper closures at that point; those
closures are then called per pulse without being reallocated. The v0.1.9 spec
must state this explicitly as an implementation constraint, not leave it as a
performance-by-convention expectation.

### Clarification 4: `risk_params` provenance boundary

When risk chain steps are parameterized via `param = "max_weight"`, the
per-candidate `max_weight` value is already captured in the candidate's `params`
field in the sweep result row.

`risk_params` in Section 7's provenance model should refer to the fixed-argument
portion of the risk chain — the parts that do not vary per candidate. The
per-candidate values are captured in `params` and already flow into candidate
identity. Duplicating them in `risk_params` would create ambiguity about which
field is authoritative for candidate comparison and promotion. The v0.1.9 spec
must define the boundary: `risk_chain_hash` covers chain structure and fixed
arguments; per-candidate parameter values are part of `params`, not a separate
`risk_params` column.

### Clarification 5: Future risk-specific context obligation

The RFC proposes `risk_step(targets, ctx, params) -> targets` with the full
strategy `ctx`. This is consistent with the roadmap v0.1.9 note:

> "Risk functions may initially receive the same strategy-context shape as the
> strategy function, including helpers such as `ctx$hold()`. If a future
> risk-specific context is introduced, the equivalence and method surface must be
> specified rather than assumed."

The v0.1.9 spec must record this as a standing design obligation, not leave it
implicit. Specifically: any future risk-specific context must define which
strategy-ctx fields it exposes, which it excludes, and how `ctx$hold()` and
similar position helpers behave. This obligation should be recorded in the v0.1.9
spec even if the risk-specific context ships later.

---

## Section 4: Research Order-Policy Chain

Defer. Do not include in v0.1.9.

### Conflict with the cost model architecture response

The cost model architecture response explicitly defers:

> "minimum trade value filters, volume clipping, partial fills, liquidity
> refusal, max participation rate. Those are valid future execution features, but
> they are not just 'cost.' They change what fills. They need a separate
> execution/liquidity contract or must be expressed through the risk layer when
> they are target transforms."

The RFC's research order-policy examples — `ledgr_order_min_notional(100)`,
`ledgr_order_round_lots(1)`, `ledgr_order_participation_cap(0.10)` — are
exactly this deferred list. The RFC is proposing the deferred contract without
acknowledging that the deferral was intentional.

### Execution-bar data dependency

`ledgr_order_participation_cap(0.10)` requires next-bar volume. Volume is
execution-bar data. Order-policy steps run after risk but before fill timing.
The strategy context available at that point is decision-time only. The order
policy would need a fill context (as defined in the cost model architecture
response) to access execution-bar volume — but that boundary is a future design
item and is not yet defined. Shipping `participation_cap` without defining what
context the order-policy step receives would require either breaking the
no-lookahead boundary or producing a meaningless policy.

### Pre-empts v0.2.x OMS design

`ledgr_order_time_in_force("day")` is a pure OMS concept. In ledgr's next-open
model, a day order either always fills at the next open or the concept is
semantically empty. Shipping this as part of a research order-policy chain
before the v0.2.x OMS design establishes what order lifecycle semantics mean in
a research context creates a naming and semantic conflict that the OMS design
will need to resolve.

### Overlap with risk-layer examples creates user confusion

The RFC presents both:

- Risk: `ledgr_risk_round_lots(1)`, `ledgr_risk_min_trade_value(100)`
- Order policy: `ledgr_order_round_lots(1)`, `ledgr_order_min_notional(100)`

These are the same user intent at different abstraction levels with materially
different semantics. Risk-layer `round_lots` rounds the stored target quantity,
so subsequent hold/rebalance decisions operate on a rounded base. Order-policy
`round_lots` rounds the order intent but leaves the logical target unrounded,
creating a persistent rounding gap. Users will not understand the distinction
from names and examples alone.

### Recommended path

File a separate RFC for the research order-policy chain after v0.2.x OMS design
begins. At that point the execution-bar context boundary will be defined, the
OMS lifecycle semantics will be established, and the overlap with risk-layer
target transforms can be resolved deliberately. Do not include Section 4 in the
v0.1.9 spec.

---

## New Direction: Tiered Output Policy And Execution Audit Record

The risk chain creates a boundary that does not currently exist: strategy intent
versus risk-adjusted targets. That boundary is only useful if it is observable.
This response proposes a tiered output policy as a first-class design direction,
to be developed in the synthesis for this RFC thread.

### The three observable layers

The fold-core execution chain after v0.1.9 has three natural observation points:

```text
strategy fn(ctx, params)
  -> strategy targets              [intent]
  -> target validation
  -> risk chain
  -> risk-adjusted targets         [derisked]
  -> target validation
  -> fill timing + cost resolution
  -> fold events                   [realized]
```

Intent is what the strategy wanted. Derisked is what the risk layer allowed.
Realized is what actually executed. These three layers answer different research
questions:

- Intent vs derisked: risk-layer attribution. Did the risk configuration destroy
  alpha? Which pulses did it fire? By how much did it adjust the portfolio?
- Derisked vs realized: execution attribution. Which intended positions failed to
  fill, and why?
- Intent vs realized: full gap between strategy signal and portfolio outcome.
  This is the number walk-forward validation and selection-bias diagnostics need.

Without this three-layer record, researchers can observe only realized and must
infer the rest. With it, "my risk overlay is too tight" and "my strategy has no
alpha" become distinguishable questions.

### The enabling architecture

The fold/output-handler split already established for v0.1.8 makes this
possible. The fold computes all three layers in the course of normal execution.
Today the output handler discards intent and derisked after the risk step
completes. A tiered output policy formalizes what each tier retains. The fold
semantics are identical across all tiers. No second execution engine is needed.

This is a genuine ledgr advantage over most backtesting frameworks, which
implement risk management inside the strategy function and therefore have no
principled boundary to observe.

### Four output tiers

**Tier 0 — Fast (sweep default)**

Summary statistics only. Core metrics, candidate identity, execution seed,
compact provenance. When a risk layer is present, two cheap per-run scalars:
`risk_fired_pulses` (count of pulses where the risk chain changed at least one
target) and `risk_mean_adjustment` (mean absolute target change across fired
pulses and instruments). These are computed incrementally in the fold at
negligible cost and fit in the existing sweep result row shape. No DuckDB writes.
Minimum per-pulse allocation. This is the path the sweep optimization synthesis
targets.

**Tier 1 — Standard (current `ledgr_run()` default)**

Realized fills, equity curve, closed trades, standard metrics. What ledgr
produces today. Sufficient for ranking, comparison, and most post-run analysis.
When a risk layer is present, risk summary stats are included as run metadata
(same scalars as Tier 0, stored durably).

**Tier 2 — Diagnostic (opt-in, moderately expensive)**

Adds per-pulse intent and derisked target records. Stored in a `pulse_targets`
table: `run_id`, `pulse_ts_utc`, `instrument_id`, `intent_qty`, `derisked_qty`.
`realized_qty` is derivable from fills. This table joins with fills to give the
complete three-layer picture.

When no risk layer is present, `intent_qty` equals `derisked_qty` and the table
still exists for API consistency. The risk-layer fields are not null; they are
identical to intent. This means Tier 2 runs created before v0.1.9 are valid and
consistent with Tier 2 runs after v0.1.9.

Accessing results: `ledgr_results(bt, what = "intent")` and
`ledgr_results(bt, what = "derisked")` follow the existing result-access
contract.

This tier is moderately expensive. For a run with 500 pulses and 20 instruments,
the `pulse_targets` table has 10,000 rows. Documentation must state the cost.
It is appropriate for risk-layer calibration, walk-forward attribution, and
understanding unexpected behavior, not for routine sweep ranking.

**Tier 3 — Full analysis (opt-in, expensive, not for production sweep)**

Everything in Tier 2, plus: fill proposals (typed intermediates before cost
resolution), per-pulse portfolio state snapshots (cash, positions, equity at
each pulse), and the full event stream with all metadata. Used for model
validation, debugging, regulatory-style audit trails, and research into
execution dynamics. Documentation must state the cost without apology and
recommend against use in large sweeps.

### User-facing API

The `analysis_mode` argument is added to `ledgr_run()` and `ledgr_sweep()`:

```r
ledgr_run(exp, analysis_mode = "standard")    # default: Tier 1
ledgr_run(exp, analysis_mode = "diagnostic")  # Tier 2
ledgr_run(exp, analysis_mode = "full")        # Tier 3

ledgr_sweep(exp, params)                             # default: Tier 0
ledgr_sweep(exp, params, analysis_mode = "diagnostic")
```

Internally `analysis_mode` compiles to an output policy that the output handler
executes. The fold does not inspect it.

### Sweep boundary for Tier 2

Tier 2 for all candidates in a large sweep is prohibitive. The recommended
boundary: `ledgr_sweep()` with `analysis_mode = "diagnostic"` stores Tier 0
summary stats per candidate row plus Tier 2 records only for candidates
explicitly requested via `ledgr_candidate()` or promoted via `ledgr_promote()`.
The promoted run is always committed at the requested analysis tier.

This keeps diagnostic-quality records available for the candidates researchers
care about without storing per-pulse target vectors for every candidate in a
200-candidate grid.

### Roadmap placement

| Milestone | Tiered output policy scope |
| --- | --- |
| v0.1.8.x | No change. Output handler produces Tier 0 (sweep) and Tier 1 (run). |
| v0.1.9 | Risk chain creates the intent/derisked boundary. Add `risk_fired_pulses` and `risk_mean_adjustment` to Tier 0 and Tier 1. Specify Tier 2 `pulse_targets` table schema. |
| v0.1.9.x | Implement Tier 2 `analysis_mode = "diagnostic"` for `ledgr_run()`. Implement sweep promotion at requested tier. |
| Later v0.1.9.x or v0.2.x | Tier 3 full analysis mode. |

Tier 2 is sequenced after the risk chain lands because its value is greatest
when intent and derisked are distinct. The schema should be specified in the
v0.1.9 packet even if the full Tier 2 implementation ships in a follow-on patch.

---

## Answers To Open Questions

### Q1: Plain functions versus classed objects

Classed ledgr risk objects only for v0.1.9. Plain functions that enter the
config hash require source capture, fingerprinting, and preflight classification.
That identity work is not resolved and must not be slipped into the first risk
release. This is an explicit non-goal for v0.1.9.

### Q2: Full ctx versus narrow risk context

Full strategy `ctx` initially, consistent with the roadmap v0.1.9 note. Record
the design obligation explicitly in the v0.1.9 spec: a future risk-specific
context must define which strategy-ctx fields it exposes, which it excludes, and
how position helpers such as `ctx$hold()` behave under that context shape.

### Q3: Risk chain in execution config hash

Yes. Risk chain changes fills and equity and must enter the execution config hash.
Canonical null representation for pre-v0.1.9 runs must be specified (see
Clarification 2). Metric context by contrast must not enter the config hash, as
established in the metric-context synthesis.

### Q4: Research order-policy timing

Defer entirely. File a separate RFC after v0.2.x OMS design establishes
execution-bar context boundaries and order lifecycle semantics. Do not include
in the v0.1.9 spec.

### Q5: Order-policy identity

Deferred with Q4.

### Q6: Chain failure classification

Failure classification must distinguish the fold-core layer where failure
occurred. Sweep failure rows should use a distinct `failure_type` value for each
layer:

- `strategy_error`: failure inside the strategy function
- `target_validation_error`: failure in the first target validator (before risk)
- `risk_step_error`: failure inside a risk chain step
- `risk_validation_error`: failure in the second target validator (after risk)
- `execution_error`: failure in fill timing or cost resolution

This matters for diagnostics: a `risk_step_error` on 30% of candidates
indicates a misconfigured risk adapter, not a strategy problem. Collapsing these
into a single `error` field loses that signal.

### Q7: Minimum adapter set for v0.1.9

`ledgr_risk_long_only()` and `ledgr_risk_max_weight()` only.

These are sufficient to prove the design: they are unambiguously target
transforms with no execution-bar data dependency, they exercise two distinct
step types (binary clip versus proportional scaling), and they are the adapters
systematic researchers actually need first.

`ledgr_risk_min_trade_value()` should be held back. It requires current-pulse
equity and close prices to estimate trade value and uses close as a proxy for
fill price. Since fills happen at next-bar open, this is an approximation that
should be explicitly documented before shipping. It is not needed to prove the
design.

`ledgr_risk_round_lots()` is deferred until the decision is made whether round
lots belong in the risk layer (target transform, stored quantity is rounded) or
the order-policy layer (order intent rounded, logical target unrounded). That
distinction has material consequences for rebalance behavior and should not be
decided by the first adapter shipped.

---

## Promotion Context And The Three-Layer Record

The sweep promotion contract stores `run_promotion_context` for committed runs.
That context should be extended in v0.1.9 to include risk chain identity
alongside the existing candidate and sweep metadata.

If the promoted run is committed at `analysis_mode = "diagnostic"` or higher,
the `pulse_targets` table for that run is available for post-promotion analysis.
This is the natural research workflow: sweep at Tier 0 for speed, promote the
selected candidate at Tier 2 to understand why it performed as it did.

---

## Final Recommendation

Accept the target-risk chain (Section 3) for v0.1.9 planning with the five
clarifications above. Defer the research order-policy chain (Section 4)
entirely. Add tiered output policy as a first-class design direction to the
synthesis.

The minimum v0.1.9 scope is:

1. `ledgr_risk_chain()` accepting classed `ledgr_risk_step` objects only.
2. `ledgr_risk_long_only()` and `ledgr_risk_max_weight()` as the initial
   adapter set.
3. Risk chain inserted in the fold core at the reserved slot.
4. Double target validation around the risk chain.
5. Risk chain identity in execution config hash with canonical null
   representation for pre-v0.1.9 runs.
6. `risk_fired_pulses` and `risk_mean_adjustment` summary stats in Tier 0 and
   Tier 1 output.
7. Tiered output policy schema specified, with Tier 2 `pulse_targets` table
   defined even if full implementation is a follow-on patch.
8. Failure type classification distinguishing risk-layer failures from strategy
   and execution failures.
9. Risk chain identity in sweep candidate rows and promotion context.
