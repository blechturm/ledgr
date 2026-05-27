# RFC Seed v2: Public Transaction-Cost Model API For ledgr

**Status:** Revised RFC seed - maintainer decisions resolved 2026-05-27; ready for synthesis.
**Author:** Codex revision after Claude response; in-place patches applied 2026-05-27 after maintainer resolution.
**Date:** 2026-05-27
**Target window:** v0.1.9.x / v0.2.0, after target risk and walk-forward
evaluation have stabilized enough to share execution identity.
**Revises:** `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_seed.md`
**Reviewer response:** `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_response.md`
**Maintainer decisions:** `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_maintainer_decisions.md`
**Primary research input:** `inst/design/research/Transaction-Cost Models.md`
**Predecessor RFC thread:** `inst/design/rfc/rfc_cost_model_architecture.md`,
`inst/design/rfc/rfc_cost_model_architecture_response.md`
**Constrained by:** `inst/design/contracts.md`,
`inst/design/ledgr_roadmap.md`,
`inst/design/rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md`,
`inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md`,
`inst/design/rfc/rfc_ledgr_oms_seed_synthesis.md`,
`inst/design/rfc/rfc_execution_policy_pipeline_audit_signal_north_star.md`

**Revision note:** This v2 seed preserves the v1 seed as a historical artifact.
It incorporates most of Claude's response, narrows the first public cost API,
and originally escalated two product-facing choices (timing-argument name,
spread convention) to maintainer decision.

**Maintainer-resolution patch note (2026-05-27):** The two escalated decisions
were resolved as Option B in both cases — rename `fill_model` to `timing_model`
and adopt quoted-spread semantics under `ledgr_cost_spread_bps()`. Rationale:
ledgr is pre-CRAN with no external users and no user-facing docs that teach
`fill_model` (only roxygen + internal code reference it); the cost model is
being designed from a clean slate alongside the rename. Sections §4.1, §4.2,
§5, §6, §7, §15, §17, §18 patched in place to reflect the bindings. The
historical narrative in §0 is preserved as audit trail; the body below is the
current binding.

---

## 0. Codex Disposition On Claude Response (Historical)

This section records the disposition of Claude's response at v2-seed authoring
time (2026-05-26). Two of the three "partial disagreement" items were
subsequently overturned by maintainer decisions on 2026-05-27 (see the
maintainer-resolution patch note at the top of this file). The text below is
preserved as audit trail; the binding for those items now lives in §5, §7,
and the maintainer decision note.

The response correctly read the current codebase and the load-bearing design
documents.

Accepted from the response (still binding in v2 post-patch):

- keep the public API quantity-preserving;
- keep arbitrary user functions out of v1;
- do not expose liquidity, partial-fill, OMS, financing, tax, or TCA behavior;
- drop broker-like convenience templates from v1;
- bind fee component summation into one accounting fee;
- keep cost experiment-level in v1;
- defer cost grids and cost parameter references;
- simplify persisted identity to a hash plus canonical plan JSON;
- make the fill-intent shape explicit;
- remove open questions that the body already answers.

Partial disagreements at v2-seed authoring time:

- v2 recommended a three-primitive minimum (price-adjustment, fixed-fee,
  notional-bps-fee) rather than Claude's two-primitive minimum, on the grounds
  that notional-bps-fee is asset-agnostic and forces percentage-fee composition
  semantics to be bound up front. **Status: still binding.** The synthesis
  carries the three-primitive minimum (plus `ledgr_cost_zero()` and the chain
  composition) as v1.
- v2 originally recommended keeping `fill_model` as the timing argument as the
  pragmatic default, escalating the decision to the maintainer. **Status:
  overturned 2026-05-27.** Maintainer chose Option B: rename to `timing_model`.
  Rationale: ledgr is pre-CRAN with no external users and no user-facing docs
  teaching `fill_model` outside roxygen, so the migration cost is essentially
  zero. See §5 for the current binding.
- v2 originally rejected Claude's suggestion to change `spread_bps` semantics
  to half-spread-per-leg, on the grounds that doing so would silently rewrite
  existing research economics. **Status: overturned 2026-05-27.** Maintainer
  chose Option B: adopt quoted-spread semantics under `ledgr_cost_spread_bps()`.
  Rationale: there is no existing research outside the maintainer's own
  development backtests, so the "silent rewrite" concern was phantom. See §7
  for the current binding.
  A clearer new constructor name is preferable to silently rewriting existing
  backtest economics.

---

## 1. Scope

This seed addresses the future public transaction-cost model API.

It does not reopen the v0.1.8 internal timing/cost boundary. That boundary is
already present in the codebase:

```text
target delta
  -> ledgr_next_open_fill_proposal()
  -> ledgr_resolve_fill_proposal()
  -> internal cost resolver
  -> ledgr_fill_intent
  -> ledger event
```

The remaining design question is public API:

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
- arbitrary user functions with replay-stable identity guarantees;
- broker-certified fee schedules in core ledgr.

---

## 2. Current Baseline

Current public cost configuration is embedded in `fill_model`:

```r
fill_model = list(
  type = "next_open",
  spread_bps = 0,
  commission_fixed = 0
)
```

Current semantics:

- `type = "next_open"` controls timing;
- `spread_bps` applies the full bps adjustment on each fill leg;
- `commission_fixed` is a non-negative fixed fee per fill event;
- `commission_fixed` maps to the ledger `fee` field;
- the internal `ledgr_fill_intent` currently carries `commission_fixed`.

Current code constraints verified for this revision:

- `R/experiment.R` exposes `fill_model` as a public argument and documents the
  per-leg spread convention.
- `R/config-validate.R` validates `fill_model.type`, `spread_bps >= 0`, and
  `commission_fixed >= 0`.
- `R/fill-model.R` creates proposals, fill contexts, the internal spread/fixed
  resolver, and the current fill intent.
- `R/fold-core.R` resolves cost before output handlers see events.
- `R/backtest-runner.R` writes a single ledger fee from
  `fill_intent$commission_fixed`.

The first public cost API must decide whether to preserve these names,
translate them, or deliberately break them. It must not accidentally change
cost math.

---

## 3. Research Conclusions Carried Forward

The transaction-cost research supports these constraints.

Cost is not one economic object. Spread/slippage, explicit fees, financing,
TCA, and liquidity constraints differ in timing and accounting semantics.

The first public API should model fill-time transaction costs that fit one of
two shapes:

```text
price transform:
  reference fill price -> adjusted fill price

explicit fee:
  priced fill -> fee cash amount
```

The first public API is quantity-preserving:

```text
same instrument
same side
same qty
same ts_exec_utc
resolved fill_price
resolved total fee
```

Cost may not create no-fill rows. Cost may not mutate quantity. Cost may not
perform order lifecycle work.

Public identity should be object-based, not closure-first. The first public
surface uses ledgr-classed cost objects with canonical constructor metadata.
Plain user-supplied functions are deferred.

NautilusTrader remains the strongest reference implementation for this layer:
copy its separation between fee/cost and fill/liquidity concerns, not its exact
API.

---

## 4. Proposed v1 Public Surface

Names remain provisional until synthesis or spec-cut, but v2 recommends a
narrower first public surface than v1 did.

### 4.1 Cost chain

```r
cost <- ledgr_cost_chain(
  ledgr_cost_spread_bps(5),
  ledgr_cost_notional_bps_fee(1),
  ledgr_cost_fixed_fee(1)
)
```

`ledgr_cost_chain()` is an ordered, classed ledgr object. It compiles before
fold execution:

```text
user cost object
  -> validated cost plan
  -> cost_model_hash / cost_plan_json
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

### 4.2 v1 primitive minimum

V1 primitive minimum (maintainer-bound 2026-05-27):

```r
ledgr_cost_spread_bps(bps)
ledgr_cost_fixed_fee(amount)
ledgr_cost_notional_bps_fee(bps)
ledgr_cost_zero()
ledgr_cost_chain(...)
```

Rationale:

- `ledgr_cost_spread_bps()` is the v1 symmetric price-adjustment primitive
  using quoted-spread semantics (see §7). `spread_bps = 5` means the bid-ask
  spread is 5 bps, charging ~5 bps round-trip cost.
- `ledgr_cost_fixed_fee()` is the per-fill fixed fee primitive replacing the
  legacy internal `commission_fixed`.
- `ledgr_cost_notional_bps_fee()` is the smallest asset-agnostic explicit fee
  primitive that makes the public API useful beyond current parity. Forces
  percentage-fee composition semantics to be bound up front (§4.4).
- `ledgr_cost_zero()` is a true identity cost, not a broker approximation.
- `ledgr_cost_chain()` establishes composition and identity.

Reserved for future RFCs (not in v1):

- `ledgr_cost_price_adjust_bps(bps, side = ...)` — reserved for future
  asymmetric markup/markdown semantics when concrete demand surfaces.

Deferred from the v1 minimum:

```r
ledgr_cost_per_share_fee(...)
ledgr_cost_per_contract_fee(...)
min_fee / max_fee caps
side-filtered fee steps
maker/taker fee steps
broker-like convenience composites
```

These are useful, but each carries additional semantics:

- per-share and per-contract naming implies asset/instrument-class decisions;
- caps require per-step versus per-chain binding;
- side filters raise reporting and interaction questions;
- maker/taker requires an explicit liquidity convention;
- broker-like composites imply maintenance and approximation risk.

### 4.3 Stage discipline inside the chain

V1 cost chains have two internal stages:

```text
price transforms
fee adders
```

Price transforms produce the resolved fill price. Fee adders compute fees from
that resolved fill price unless a later RFC explicitly defines another
reference.

Therefore:

```text
reference_price
  -> price transforms
  -> resolved_fill_price
  -> fee adders
  -> total_fee
```

This avoids the surprising case where a notional fee placed before a price
transform computes on a different notional than a fee placed after it. The
user-facing chain remains ordered, but v1 rejects interleaved ordering that
violates the two-stage discipline. The rejection fires at
`ledgr_cost_chain()` construction time with a classed error
`ledgr_invalid_cost_chain_order` listing the offending step positions, so the
user gets the error before any fold execution.

### 4.4 Percentage-fee semantics

`ledgr_cost_notional_bps_fee(bps)` computes on the resolved fill price:

```text
fee = abs(qty) * resolved_fill_price * bps / 10000
```

This makes "notional bps fee" mean a fee on the actual simulated fill value.
It also aligns with the current event accounting path: the ledger records the
fill price actually used for cash and P&L.

### 4.5 Fee summation

V1 accounting records one total fee per fill. If multiple fee adders exist,
they sum into that total:

```text
total_fee = sum(component_fees)
```

Component-level details may be retained in `meta_json` or a future diagnostic
retention surface, but they are not required in every run and do not require a
new durable cost table in v1.

### 4.6 Fill intent shape

The v1 logical fill intent should use a total `fee` field:

```text
instrument_id
side
qty
fill_price
fee
ts_exec_utc
```

Current code uses `commission_fixed` internally. The implementation spec must
either:

1. migrate internal fill intents to `fee`, keeping compatibility shims where
   needed; or
2. keep `commission_fixed` as a legacy internal field while documenting that
   public cost objects emit a total fee.

This seed recommends the first option for public clarity. The accounting
ledger already exposes `fee`, so carrying `commission_fixed` into a public cost
API would leak obsolete naming.

---

## 5. Experiment Integration

The public integration splits timing from cost. Maintainer-bound v1 surface
(2026-05-27):

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

Rationale (maintainer rationale 2026-05-27): ledgr is pre-CRAN with no
external users; user-facing docs (vignettes, README) do not currently teach
`fill_model` (verified via grep — only roxygen, internal code, and design docs
reference it). The rename cost is internal-only (roxygen, config-validate,
internal helpers, tests, internal architecture notes). v0.1.9.x is the right
moment to pay it because `cost_model` is being added beside it; teaching both
names together for the first time is cleaner than teaching `fill_model` then
renaming later.

The rename touches:

- argument name on `ledgr_experiment()` ([R/experiment.R](R/experiment.R));
- normalization helper (`ledgr_experiment_normalize_fill_model()` →
  `ledgr_experiment_normalize_timing_model()`);
- `validate_ledgr_config()` ([R/config-validate.R](R/config-validate.R));
- internal config field reads;
- `ledgr_run_open()` reopen path for stored config_json;
- roxygen across `ledgr_experiment` and related;
- tests that pin the field name;
- internal architecture notes that mention `fill_model`.

User-facing vignettes do not change because they do not currently teach the
old name.

---

## 6. Legacy Scalar Handling

The existing scalar shape:

```r
fill_model = list(type = "next_open", spread_bps = 5, commission_fixed = 1)
```

is removed from the v1 public surface. The replacement is the classed-object
form bound in §5:

```r
timing_model = ledgr_timing_next_open()
cost_model = ledgr_cost_chain(
  ledgr_cost_spread_bps(5),       # NOTE: quoted-spread semantics now (§7)
  ledgr_cost_fixed_fee(1)
)
```

**Convention shift note (2026-05-27):** the legacy scalar `spread_bps = 5` and
the new `ledgr_cost_spread_bps(5)` are *not* numerically equivalent.

- Legacy scalar applied full bps per leg → ~10 bps round trip at `spread_bps = 5`.
- New constructor applies quoted-spread semantics → ~5 bps round trip at
  `spread_bps = 5`.

For users (none external currently) reproducing pre-v0.1.9.x backtest numbers
exactly, the equivalent new constructor is `ledgr_cost_spread_bps(10)`. This
shift is intentional and bound by the maintainer (§7).

Because ledgr is pre-CRAN with no external users, the legacy scalar shape does
not need a compatibility parser. The implementation may reject it with a
classed error pointing users to the new constructors, or may accept it for a
single transitional release with an explicit deprecation message. Spec-cut
chooses; v1 docs teach only the classed-object form.

---

## 7. Spread Convention

V1 public spread semantics (maintainer-bound 2026-05-27): **quoted-spread**
under `ledgr_cost_spread_bps()`.

```text
BUY  fill_price = open * (1 + spread_bps / 20000)
SELL fill_price = open * (1 - spread_bps / 20000)
```

`spread_bps = 5` means "the bid-ask spread is 5 bps" and produces ~5 bps
round-trip cost before explicit fees. This matches finance-native vocabulary
and what most users would predict.

Internal current behavior (legacy scalar `fill_model$spread_bps`) uses
full-bps-per-leg → ~10 bps round trip at `spread_bps = 5`. That convention is
not preserved in the new public surface (§6).

**Rationale (maintainer 2026-05-27):** ledgr is pre-CRAN with no external
users and no existing research outside the maintainer's own development
backtests. The "silent rewrite of stored research" argument that the v2 seed
originally leaned on is phantom in this context. With no constraint to
preserve old numbers, the public constructor adopts the intuitive convention.

A future `ledgr_cost_price_adjust_bps(bps, side = ...)` constructor is
reserved for asymmetric per-leg adjustments when concrete demand surfaces
(e.g., simulating broker-specific markup vs markdown). The reserved
constructor would use the full-bps-per-leg convention because that's its
literal semantics; users wanting asymmetric or per-leg control would use that
constructor, not `ledgr_cost_spread_bps()`.

---

## 8. Identity And Provenance

Cost affects fill prices, fees, cash, positions, equity, metrics, and promoted
run evidence. It belongs to execution identity.

Persisted identity should be smaller than v1 proposed. V2 recommends two
semantic fields:

```text
cost_model_hash
cost_plan_json
```

`cost_model_hash` is the deterministic content hash of the public cost object.
`cost_plan_json` is canonical JSON for the compiled worker-safe plan. Version,
type, step metadata, and step ordering live inside `cost_plan_json`.

A cost object hashes from canonical JSON of:

```text
cost_schema_version
type_id
named fixed arguments
ordered child steps, if any
```

It must not hash from:

- function memory addresses;
- R environment serialization;
- object print output;
- package load order;
- transient run IDs;
- metric context.

Metric context is orthogonal. Cost identity affects execution; metric context
affects analysis. A future config may include both, but `cost_model_hash` does
not depend on `metric_context_hash`.

Walk-forward handoff: after public cost models land, future walk-forward
`candidate_key` and `session_id` must include `cost_model_hash`. The current
walk-forward synthesis predates the public cost API and must be extended at
v0.1.9.x spec-cut to reflect this addition; the omission is on record as a
future-obligation handoff.

---

## 9. Context And No-Lookahead

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

The cost layer may see next-bar execution data only after strategy targets
have been returned. That is not lookahead because strategy code cannot observe
the fill context.

With EOD OHLCV bars, v1 can support coarse price adjustments and fee schedules.
It cannot honestly infer queue position, maker/taker state, venue routing, or
persistent information impact.

---

## 10. Sweep And Parameterization

V1 cost is experiment-level.

Users should not vary cost per sweep candidate in v1. They may run separate
experiments with different cost models, but `ledgr_sweep()` candidates should
not silently pick up cost assumptions from `strategy_params`.

Deferred future shapes:

```r
ledgr_cost_grid(spread_bps = c(0, 5, 10), fixed_fee = c(0, 1))
ledgr_grid_cross(features = ..., strategy = ..., cost = ...)
```

or:

```r
cost <- ledgr_cost_chain(
  ledgr_cost_price_adjust_bps(ledgr_cost_param("spread_bps"))
)
```

These require explicit namespace and identity rules. They are not part of the
first public cost API.

---

## 11. Negative Fees, Rebates, And Fee Currency

V1 continues the current non-negative fee invariant:

```text
fee >= 0
```

Rebates are deferred. If later admitted, they should use explicit rebate or
maker/taker classes, not arbitrary negative outputs from any fee step.

V1 fees are denominated in the run/account currency. Non-account fee currencies
and currency conversion are deferred.

---

## 12. Broker And Exchange Templates

Core ledgr owns primitives and examples, not authoritative broker schedules.

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

V1 core convenience composites:

```r
ledgr_cost_zero()
```

Not admitted in v1 core:

```r
ledgr_cost_equity_retail()
ledgr_cost_ibkr()
ledgr_cost_binance()
ledgr_cost_cme()
```

Template-like examples may appear in documentation, but should not be exported
as authoritative cost functions.

---

## 13. Relationship To Target Risk, OMS, And Liquidity

Target risk transforms targets before timing. Cost prices proposed fills after
timing.

```text
alpha-vs-cost filter:
  risk or target construction helper

actual fee/spread application:
  cost model
```

If future risk helpers need cost estimates, those estimates must be a
decision-time approximation. They must not reuse the fill-time cost resolver if
that resolver sees execution-bar data.

The OMS synthesis expects:

```text
order intent -> fill proposal -> cost resolver -> fill intent -> ledger event
```

This seed preserves that seam. Liquidity/execution policy may later reduce
quantity, split fills, or produce no fill. Cost should price the proposals it
receives. It should not decide which proposals exist.

---

## 14. Data Model And Persistence

The first public cost API does not need a new durable cost table.

Required config/provenance capability:

- identify which cost model priced the run;
- reconstruct the ordered cost plan;
- preserve fixed arguments and schema version;
- distinguish cost fixed for an experiment from future cost-varying candidates;
- replay promoted candidates with the same cost assumptions.

Canonical accounting:

```text
one fill intent -> one ledger fee total
```

Component details are optional diagnostic metadata, not required accounting
rows. If retained, they may live in `meta_json` or a future diagnostic
retention surface.

---

## 15. Proposed v1 Minimum Scope

The first public cost API should include:

1. `ledgr_cost_chain()`.
2. `ledgr_cost_spread_bps()` with quoted-spread semantics per §7.
3. `ledgr_cost_fixed_fee()`.
4. `ledgr_cost_notional_bps_fee()`.
5. `ledgr_cost_zero()`.
6. Cost-object validation and canonical JSON.
7. `cost_model_hash` and `cost_plan_json`.
8. `timing_model` argument on `ledgr_experiment()` (rename from `fill_model`).
9. `ledgr_timing_next_open()` constructor for the v1 timing model.
10. Experiment/run integration with fixed experiment-level cost.
11. Legacy scalar handling: classed error pointing to new constructors, or a
    single-release deprecation message (spec-cut chooses).
12. Fold-core integration through the existing proposal -> resolver seam.
13. Logical fill intent with total `fee` (internal `commission_fixed` → `fee`
    migration).
14. Run provenance and promotion-context cost identity.
15. Documentation for price transforms versus explicit fees, including the
    quoted-spread convention.
16. Documentation for non-scope: liquidity, financing, TCA, taxes, OMS, and
    broker reconciliation.
17. Tests for the quoted-spread semantics (BUY/SELL round-trip = `spread_bps`).
18. Tests for deterministic cost hashes and order/stage validation.
19. Tests that cost models cannot mutate quantity, side, instrument, or
    execution timestamp.
20. Tests that strategy contexts never expose execution-bar fields.
21. Update the v0.1.8.5 workflow article forward-link wording if any cost
    teaching is added before v0.1.9.x ships.

---

## 16. Explicit Deferrals

Deferred:

- arbitrary user-supplied cost functions with reproducible identity;
- `ledgr_cost_grid()` / `execution_grid` / cost parameter references;
- stateful rolling-volume fee tiers;
- maker/taker inference and rebates;
- min/max fee caps;
- side-filtered fee steps;
- per-share/per-contract aliases;
- Almgren-Chriss or schedule-aware impact;
- liquidity clipping, no-fill, volume caps, and partial fills;
- borrow, margin interest, carry, and perpetual funding;
- multi-currency fee accounting;
- tax-lot and capital-gains policy;
- full TCA/reporting layer;
- broker-certified schedule templates in core;
- paper/live fee reconciliation.

---

## 17. Open Questions Before Synthesis

Questions 1 and 2 were resolved by maintainer decision 2026-05-27 (see
revision note and §5, §7). Remaining open for spec-cut:

1. **Legacy scalar handling shape.** Should v1 reject the old
   `fill_model = list(...)` shape with a classed error pointing to the new
   constructors, or accept it for one transitional release with a deprecation
   message? Either is consistent with the pre-CRAN no-users posture; spec-cut
   chooses based on transition ergonomics.

2. **Cost plan execution shape.** Should compiled cost plans be row-wise,
   vectorized per pulse, or internally free to choose as long as outputs and
   identity are stable? Likely defer to implementer.

3. **Cost component diagnostic retention.** Is component breakdown retained
   only in optional `meta_json`, or should the v1 spec reserve a future
   diagnostic table shape? Real spec-cut question.

---

## 18. Recommended Next Step

Both maintainer decisions resolved 2026-05-27 (Option B on both). The seed is
ready for synthesis. The synthesis writer takes v2 + Claude's response +
Claude's response-review + the resolved decision note as inputs.

Per role-rotation discipline from prior cycles, the synthesis is best
authored by Claude (Codex wrote v1, v2, and the decision note).
