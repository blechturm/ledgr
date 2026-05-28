# RFC Synthesis: Public Transaction-Cost Model API For ledgr

**Status:** Accepted synthesis — binding for the v0.1.9.x / v0.2.0 public transaction-cost API ticket cut.
**Date:** 2026-05-27
**Source seed v1:** `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_seed.md`
**Source seed v2:** `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_seed_v2.md`
**Reviewer response:** `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_response.md`
**Maintainer decisions:** `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_maintainer_decisions.md` (resolved 2026-05-27, both Option B)
**Predecessor cost RFC thread:** `inst/design/rfc/rfc_cost_model_architecture.md`, `inst/design/rfc/rfc_cost_model_architecture_response.md`
**Predecessor syntheses:** `inst/design/rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md`, `inst/design/rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md`, `inst/design/rfc/rfc_ledgr_oms_seed_synthesis.md`
**North-star context:** `inst/design/rfc/rfc_execution_policy_pipeline_audit_signal_north_star.md`
**Roadmap anchor:** `inst/design/ledgr_roadmap.md` (public transaction-cost API at v0.1.9.x/v0.2.0)

**Process note:** This synthesis incorporates the v1 seed, Codex response, maintainer response-review (Claude), v2 seed, maintainer decision note (both decisions resolved as Option B), and v2 in-place patches applied 2026-05-27. It does not edit prior artifacts. Per role-rotation discipline, this synthesis is authored by Claude (Codex authored both seeds and the decision note).

---

## 1. Decision Summary

The public transaction-cost model API is accepted as the v0.1.9.x / v0.2.0 design direction. It exposes a small, deterministic, quantity-preserving, classed cost-object system that splits timing from cost without changing the strategy contract or the fold core.

The strategy contract remains:

```text
strategy: function(ctx, params) -> full named numeric target vector
```

The execution pipeline becomes:

```text
strategy targets
  -> target validation
  -> target-risk chain (v0.1.9)
  -> target deltas
  -> timing_model -> fill proposals
  -> cost_model   -> resolved fill prices and explicit fees
  -> fill intents
  -> ledger events
```

Cost may adjust price and add fees. Cost may not change side, quantity, instrument, or execution timestamp. Cost may not create no-fill rows. Cost is quantity-preserving by contract.

Accepted v1 scope:

- `ledgr_cost_chain()` ordered composition of classed cost objects;
- four v1 primitives: `ledgr_cost_spread_bps()`, `ledgr_cost_fixed_fee()`, `ledgr_cost_notional_bps_fee()`, `ledgr_cost_zero()`;
- `timing_model` replaces `fill_model` as the public argument;
- `ledgr_timing_next_open()` as the v1 timing-model constructor;
- two-stage chain discipline: price transforms first, then fee adders;
- quoted-spread semantics for `ledgr_cost_spread_bps()`;
- internal `commission_fixed` migrates to total `fee` in the fill intent;
- deterministic object-based identity (`cost_model_hash` + `cost_plan_json`);
- experiment-level cost in v1 (cost does not vary per sweep candidate);
- one total fee per fill in the accounting ledger;
- component fee details optional in `meta_json`;
- ban on negative fees in v1.

Deferred:

- arbitrary user cost functions with replay-stable identity;
- per-instrument / per-venue / per-asset-class cost assignment;
- stateful rolling-volume fee tiers;
- maker/taker inference and rebates;
- cost sweep grids and cost parameter references;
- min/max fee caps;
- side-filtered fee steps;
- per-share / per-contract fee primitives;
- asymmetric price-adjustment constructor (`ledgr_cost_price_adjust_bps`) reserved for future;
- liquidity, partial fills, quantity clipping, no-fill rows;
- borrow, financing, carry, perpetual funding;
- TCA / implementation-shortfall reporting;
- multi-currency fee accounting;
- tax-lot and capital-gains policy;
- broker-certified fee schedules in core;
- paper/live fee reconciliation;
- quoted-spread vs per-leg constructor coexistence (the per-leg constructor is reserved, not deferred-then-banned).

---

## 2. Roadmap Sequencing

Bound sequencing (matches `inst/design/ledgr_roadmap.md`):

```text
v0.1.8.5           canonical research workflow and teachability
v0.1.8.6           feature-storage / out-of-core measurement spike
v0.1.8.7           parallel sweep dispatch
v0.1.9             target-risk chain
v0.1.9.x           walk-forward evaluation
v0.1.9.x           selection-integrity diagnostics after walk-forward
v0.1.9.x/v0.2.0    public transaction-cost model API  ← this synthesis
v0.2.x             OMS semantics, PIT data, snapshot lineage, related data work
v0.3.0+            paper/live adapters
```

This synthesis does not authorize OMS, liquidity policy, paper/live, selection-integrity diagnostics, or financing layers. The public cost API stabilizes before OMS implementation per the OMS synthesis future-obligations list.

---

## 3. Accepted Architecture

### 3.1 Strategy contract preservation

```text
strategy: function(ctx, params) -> full named numeric target vector
```

Strategies do not receive `fill_context` or any cost-related state. Strategies do not declare cost models. Cost is experiment-level engine work, not strategy-side input.

### 3.2 Single fold core

The fold core ([R/fold-core.R](R/fold-core.R)) does not change in control flow or execution semantics. Cost is consumed at the existing internal seam:

```text
ledgr_next_open_fill_proposal()
  -> ledgr_resolve_fill_proposal()
  -> internal cost resolver compiled from the public cost_model
  -> ledgr_fill_intent
  -> ledger event
```

The public `cost_model` argument on `ledgr_experiment()` compiles into a worker-safe cost plan that the existing internal resolver consumes. No second execution path; no new fold-core control flow.

The `commission_fixed` → `fee` field-name migration (§4.6) does require a mechanical edit inside the fold core — `R/fold-core.R` currently reads `fill$commission_fixed` for cash-delta computation at the fill-write site, and that read must change to `fill$fee`. This is a single-site rename, not a semantic change; the fold core's execution behavior is preserved.

### 3.3 Timing and cost are separate public arguments

```r
exp <- ledgr_experiment(
  snapshot     = snapshot,
  strategy     = strategy,
  features     = features,
  timing_model = ledgr_timing_next_open(),
  cost_model   = ledgr_cost_chain(
    ledgr_cost_spread_bps(5),
    ledgr_cost_fixed_fee(1)
  )
)
```

`timing_model` produces fill proposals. `cost_model` prices proposals and adds explicit fees. The legacy `fill_model` argument is removed from the v1 public surface (see §4.3).

### 3.4 Quantity-preserving cost contract

The cost contract is:

```text
cost_model:
  ledgr_fill_proposal + ledgr_fill_context
  -> same instrument
  -> same side
  -> same qty
  -> same ts_exec_utc
  -> resolved fill_price
  -> resolved total fee (>= 0)
```

Cost may not mutate quantity, side, instrument, or execution timestamp. Cost may not produce a no-fill outcome. Quantity-mutating concerns (partial fills, volume clipping, liquidity refusal) belong to the future liquidity/execution layer.

### 3.5 Classed objects only for v1

The v1 public surface accepts only ledgr-classed cost objects. Arbitrary user functions are deferred. This follows the chainable-risk synthesis discipline: deterministic run identity is a product promise; arbitrary closures cannot be deterministically fingerprinted in R without resolving captured-environment semantics, which is its own RFC.

---

## 4. Public Surface

### 4.1 v1 constructor catalog

```r
# Primitives
ledgr_cost_spread_bps(bps)            # quoted-spread price adjustment (§7)
ledgr_cost_fixed_fee(amount)          # fixed per-fill fee
ledgr_cost_notional_bps_fee(bps)      # percentage fee on resolved fill notional
ledgr_cost_zero()                     # true identity cost

# Composition
ledgr_cost_chain(...)                 # ordered composition of cost objects

# Timing
ledgr_timing_next_open()              # v1 timing-model constructor
```

The exact constructor names are bound. Argument validation, defaults, and additional arguments (e.g., currency tagging when admitted) are spec-cut details that must not contradict the bound semantics in §4.2–§4.5.

### 4.2 Two-stage chain discipline

A `ledgr_cost_chain()` has two internal stages in this order:

```text
price transforms
  -> fee adders
```

Price transforms produce the resolved fill price. Fee adders compute fees from that resolved fill price.

`ledgr_cost_chain()` validates at construction time that no fee adder precedes a price transform in the same chain. Interleaved ordering raises a classed error `ledgr_invalid_cost_chain_order` listing the offending step positions. The validation fires before any fold execution.

### 4.3 Legacy `fill_model` removed from public surface

The legacy scalar shape:

```r
fill_model = list(type = "next_open", spread_bps = 5, commission_fixed = 1)
```

is **not** part of the v1 public surface. The replacement is the classed-object form in §3.3.

Implementation note: ledgr is pre-CRAN with no external users, and no `.Rmd` vignette or `README.md` mentions `fill_model` (verified via grep before resolution). The legacy shape can either:

- be rejected at `ledgr_experiment()` with a classed error pointing users to the new constructors;
- be accepted for one transitional release with a deprecation message that auto-translates to the new shape.

Either is consistent with the no-users posture. Spec-cut chooses based on transition ergonomics. Public docs teach only the classed-object form regardless.

### 4.4 Percentage-fee semantics

`ledgr_cost_notional_bps_fee(bps)` computes against the resolved fill price (post-price-transform within the same chain):

```text
fee = abs(qty) * resolved_fill_price * bps / 10000
```

This means "X bps notional fee" applies to the fill value actually transacted, not the reference price. Combined with the §4.2 ordering discipline, chain composition is mechanically predictable: price transforms run first, the resolved fill price is fixed, then fee adders each compute against that resolved price.

### 4.5 Fee summation

V1 accounting records one total fee per fill:

```text
total_fee = sum(component_fees)
```

If a `ledgr_cost_chain()` includes multiple fee adders, they sum into one ledger `fee` field. Component breakdowns may be retained in `meta_json` or a future diagnostic surface; they are not required in every run and do not need a new durable cost table in v1.

### 4.6 Fill intent shape (internal)

The v1 logical fill intent uses a total `fee` field:

```text
instrument_id
side
qty
fill_price
fee
ts_exec_utc
```

Current internal code uses `commission_fixed`. The v0.1.9.x implementation migrates the internal field to `fee` and propagates the rename through:

- `ledgr_fill_intent` constructor at [R/fill-model.R](R/fill-model.R);
- `ledgr_default_cost_resolve()` output shape;
- the fold-core cash-delta computation site at [R/fold-core.R](R/fold-core.R) that currently reads `fill$commission_fixed`;
- output handlers that read `fill_intent$commission_fixed` (e.g., `write_fill_events` in [R/backtest-runner.R](R/backtest-runner.R));
- lot-accounting code in [R/lot-accounting.R](R/lot-accounting.R) if it reads the old field name;
- tests that pin the field name.

The accounting ledger schema already exposes `fee`, so no `ledger_events` schema change is required.

### 4.7 Convenience composites

Only one v1 core convenience composite:

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

Broker-shaped and asset-class-shaped composites belong in adapter packages or user code unless ledgr accepts maintenance of versioned schedules in a future RFC.

### 4.8 Inspection helpers

```r
ledgr_cost_steps(cost_model)          # returns ordered list of step descriptors
ledgr_cost_describe(cost_model)       # human-readable plain-text summary
```

Read-only. They do not mutate the cost object and do not re-execute.

---

## 5. Cost Resolver Inputs

Cost models do not receive the strategy `ctx`. They receive a `fill_context` after the strategy decision is sealed:

```text
fill_context:
  decision_timestamp
  execution_timestamp
  execution_bar_identity
  execution_bar OHLCV (when available)
  pre_fill_cash / positions / equity     # if admitted
  account_currency                       # if admitted
  instrument_metadata                    # if admitted
```

The default next-open timing means the cost layer sees next-bar execution data only after the strategy has returned targets. That is not lookahead because the strategy cannot observe `fill_context` by construction.

The v1 cost API uses execution-bar `open` and instrument identity. It does not honestly infer queue position, maker/taker state, venue routing, or persistent information impact from EOD OHLCV data. Future liquidity work owns those concerns.

---

## 6. Identity, Provenance, and Replay

### 6.1 Persisted cost identity

```text
cost_model_hash      deterministic content hash of the public cost object
cost_plan_json       canonical JSON of the compiled worker-safe plan
```

Both are stored in run config and promotion provenance. The plan JSON is sufficient to reconstruct the cost model on replay; the hash is sufficient for fast identity comparisons.

### 6.2 Hash composition

`cost_model_hash` is derived from canonical JSON of:

```text
cost_schema_version
type_id of the top-level cost object
named fixed arguments
ordered child steps (each with type_id, version, named args)
```

It must not hash from:

- function memory addresses;
- R environment serialization;
- object print output;
- package load order;
- transient run IDs;
- `metric_context_hash` (orthogonal — see §6.3).

### 6.3 Orthogonality with metric context

`cost_model_hash` and `metric_context_hash` are orthogonal. Cost affects execution; metric context affects post-run aggregation. Two runs with the same cost model and different metric contexts are different runs by metric identity, not cost identity.

### 6.4 Walk-forward identity handoff

After this public cost API lands, future walk-forward identity must include cost identity:

```text
walk_forward candidate_key  must include cost_model_hash
walk_forward session_id     must include cost_model_hash
```

The walk-forward synthesis predates this public cost API and does not yet name `cost_model_hash`. The v0.1.9.x walk-forward spec packet must be extended to add cost identity to its identity composition recipes; this synthesis records the obligation as a future handoff.

### 6.5 Risk-chain identity composition

After v0.1.9 target risk lands, `risk_chain_hash` is already part of execution identity per the chainable-risk synthesis. Cost identity does not duplicate or replace risk identity. Both participate in run/candidate identity alongside snapshot, strategy, features, and seed identities.

### 6.6 Legacy scalar identity migration

If the implementation accepts the legacy `fill_model = list(...)` shape for one transitional release (per §4.3), the spec packet must bind whether legacy-shape configs produce the same `cost_model_hash` as their classed-object equivalents. The convention shift in spread semantics (§7) means numeric equivalence is not preserved; a literal `fill_model = list(spread_bps = 5)` no longer maps to `ledgr_cost_spread_bps(5)`. Spec-cut binds the migration recipe explicitly.

---

## 7. Spread Convention

V1 binds quoted-spread semantics for `ledgr_cost_spread_bps()`:

```text
BUY  fill_price = open * (1 + spread_bps / 20000)
SELL fill_price = open * (1 - spread_bps / 20000)
```

`spread_bps = 5` means "the bid-ask spread is 5 bps" and produces ~5 bps round-trip cost before explicit fees. This matches finance-native vocabulary.

Legacy internal behavior (pre-rename, full-bps-per-leg) is **not** preserved. A user who previously specified `fill_model = list(spread_bps = 5)` and wants the same numeric behavior in the new public surface uses `ledgr_cost_spread_bps(10)` (since the legacy convention charged ~10 bps round-trip at `spread_bps = 5`).

**Rationale (maintainer 2026-05-27):** ledgr is pre-CRAN with no external users and no stored research outside the maintainer's own development backtests. The "silent breakage of existing research" concern that the v2 seed originally leaned on is phantom in this context.

A future `ledgr_cost_price_adjust_bps(bps, side = ...)` constructor is reserved for asymmetric markup/markdown semantics when concrete user demand surfaces. The reserved constructor uses per-leg semantics (`spread_bps / 10000` per leg) because that is its literal name. Users who want asymmetric or per-leg control will use that constructor; users who want quoted-spread semantics use `ledgr_cost_spread_bps()`.

---

## 8. Stage Boundaries (Risk / Cost / Liquidity / OMS)

The public cost API preserves the stage boundaries already bound by the chainable-risk synthesis, the OMS synthesis, and the execution-policy north star.

```text
target risk         transforms target vectors before timing
timing model        produces fill proposals from target deltas
cost model          prices fill proposals (price + fee)        ← this synthesis
liquidity policy    mutates fill existence/quantity            ← future
OMS                 owns order lifecycle                        ← v0.2.x
```

Cost may not:

- decide whether a proposal becomes a fill (liquidity territory);
- split one proposal into multiple fills (liquidity);
- assign or alter order identity (OMS);
- enforce or compute risk constraints (target risk).

Risk and cost identity both participate in execution identity but do not overlap. A future "alpha-vs-cost filter" that needs decision-time cost estimates uses a separate read-only estimator surface, not the fill-time cost resolver.

---

## 9. Implementation Constraints

The v0.1.9.x cost-API ticket packet must include:

- compiled cost plan that is worker-safe: plain serializable value object, deterministic from explicit inputs, no live DB connections, no external pointers, no active bindings, no mutable reference state, reconstructable from package code plus canonical plan metadata;
- batched persistence: no per-pulse DB writes in cost resolution;
- preservation of the existing fold-core proposal/resolver seam at [R/fill-model.R](R/fill-model.R) and [R/fold-core.R](R/fold-core.R) — no fold-core control-flow or execution-semantics changes, with a single mechanical `commission_fixed` → `fee` field-rename edit at the cash-delta site in [R/fold-core.R](R/fold-core.R);
- `commission_fixed` → `fee` internal migration across [R/fill-model.R](R/fill-model.R), [R/fold-core.R](R/fold-core.R), [R/backtest-runner.R](R/backtest-runner.R), output handlers, lot-accounting in [R/lot-accounting.R](R/lot-accounting.R), and tests;
- `fill_model` → `timing_model` migration across [R/experiment.R](R/experiment.R), [R/backtest.R](R/backtest.R) (exported `ledgr_backtest()` argument and `ledgr_fill_model_instant()` helper), [R/backtest-runner.R](R/backtest-runner.R) (cfg read), [R/run-store.R](R/run-store.R) (required-config-fields list and reopen path), [R/config-validate.R](R/config-validate.R), internal helpers, roxygen, internal architecture notes, and tests;
- `ledgr_run_open()` reopen path support for stored config_json containing either legacy or new shape (per §4.3 transition-release decision) — currently expects `fill_model` as a required config field;
- spec-cut decision on whether the exported `ledgr_backtest()` ([R/backtest.R](R/backtest.R)) gets the `timing_model` + `cost_model` arguments directly or becomes a legacy wrapper with classed migration guidance;
- classed errors: `ledgr_invalid_cost_chain_order` (per §4.2), legacy-shape rejection or deprecation per §4.3 spec-cut decision, structural validation failures (non-finite price, negative fee, side mutation attempt, qty mutation attempt, instrument mutation attempt);
- tests for quoted-spread round-trip semantics (round-trip ≈ `spread_bps` for `ledgr_cost_spread_bps(spread_bps)`);
- tests for deterministic `cost_model_hash` across reconstructions;
- tests for chain order validation;
- tests that cost models cannot mutate quantity, side, instrument, or execution timestamp;
- tests that strategy contexts never expose execution-bar fields;
- tests for fee summation (multiple fee adders sum into one ledger `fee`).

---

## 10. Mode and Retention

### 10.1 v1 retention

Default retention is scalar: one cost_model identity per run, one total fee per fill in `ledger_events`, optional component breakdown in `meta_json`.

V1 does not add:

- a durable `cost_details` table;
- per-fill component fee rows;
- per-step fee attribution as a first-class accounting artifact.

These belong in a future diagnostic retention tier if and when user demand surfaces.

### 10.2 Cost is experiment-level in v1

V1 binds cost as fixed for the experiment. Users do not vary cost per sweep candidate.

To explore cost sensitivity, users run separate experiments with different cost models. The `ledgr_sweep()` API does not pick up cost from `strategy_params`; cost is not part of the sweep candidate identity in v1.

Future shapes are deferred:

```r
ledgr_cost_grid(...)              # future
ledgr_grid_cross(..., cost = ...) # future
ledgr_cost_param("spread_bps")    # future parameter reference
```

When admitted, they must establish their own namespace and identity rules; they must not be silently mixed into `strategy_params`.

### 10.3 No paper/live cost behavior in v1

Per the OMS synthesis, paper/live cost reconciliation is v0.3.0+ scope. V1 research-mode cost runs against sealed snapshots only. No broker-reported fee ingestion, no live cost calibration, no reconciliation events.

---

## 11. Non-Goals (Explicit Deferrals)

The v0.1.9.x/v0.2.0 cost API does not include:

- arbitrary user-supplied cost functions with reproducible identity guarantees;
- per-instrument / per-asset-class / per-venue cost assignment;
- stateful rolling-volume fee tiers (e.g., monthly-volume-aware IBKR or Binance schedules);
- maker/taker fee inference and rebates;
- Almgren-Chriss or schedule-aware market-impact models;
- liquidity clipping, no-fill rows, volume caps, partial fills, queue position;
- borrow, margin interest, carry, perpetual funding;
- multi-currency fee accounting and currency conversion;
- tax-lot, wash-sale, and capital-gains policy;
- full TCA / implementation-shortfall reporting;
- broker-certified fee-schedule templates in core;
- paper/live fee reconciliation;
- min/max fee caps in v1 primitives;
- side-filtered fee steps in v1 primitives;
- per-share / per-contract fee primitives in v1;
- asymmetric `ledgr_cost_price_adjust_bps()` constructor (reserved name);
- cost grids and cost parameter references in v1;
- cost component diagnostic table.

---

## 12. v0.1.9.x / v0.2.0 Minimum Scope

Indicative ticket packet; LDG IDs assigned at spec-cut:

1. `ledgr_cost_chain()` constructor with two-stage validation (`ledgr_invalid_cost_chain_order`).
2. `ledgr_cost_spread_bps()` with quoted-spread semantics per §7.
3. `ledgr_cost_fixed_fee()` with non-negative validation.
4. `ledgr_cost_notional_bps_fee()` with resolved-fill-price semantics per §4.4.
5. `ledgr_cost_zero()` identity constructor.
6. Cost-object canonical JSON serialization and `cost_model_hash` derivation.
7. Compiled cost plan as worker-safe value object.
8. `ledgr_timing_next_open()` constructor; `timing_model` argument on `ledgr_experiment()`.
9. `fill_model` → `timing_model` argument rename across [R/experiment.R](R/experiment.R), [R/config-validate.R](R/config-validate.R), internal helpers, and roxygen.
10. `commission_fixed` → `fee` internal migration across [R/fill-model.R](R/fill-model.R), [R/backtest-runner.R](R/backtest-runner.R), output handlers, lot-accounting, and tests.
11. Legacy scalar shape handling (reject or deprecate-with-translation per spec-cut decision in §4.3).
12. `ledgr_run_open()` reopen-path compatibility for stored config_json.
13. Run config / provenance fields: `cost_model_hash`, `cost_plan_json` on `runs` and promotion context.
14. Fold-core integration through existing proposal/resolver seam (no fold-core changes).
15. Inspection helpers: `ledgr_cost_steps()`, `ledgr_cost_describe()`.
16. Documentation:
    - vignette section explaining timing vs cost separation;
    - vignette section explaining price transforms vs explicit fees;
    - vignette explanation of quoted-spread convention with worked round-trip example;
    - update `vignettes/metrics-and-accounting.Rmd` which currently teaches the legacy full-bps-per-leg convention ("buy/sell round trip costs approximately `2 * spread_bps`") — must be rewritten to teach the new quoted-spread semantics;
    - explicit non-scope documentation (liquidity, financing, TCA, taxes, OMS, broker reconciliation).
17. Tests:
    - quoted-spread round-trip semantics;
    - deterministic `cost_model_hash` across reconstructions;
    - chain order validation and error class;
    - cost models cannot mutate quantity, side, instrument, or execution timestamp;
    - strategy contexts never expose execution-bar fields;
    - fee summation to single ledger `fee`;
    - `cost_plan_json` reconstruction parity.
18. Update v0.1.8.5 workflow article forward-link if any cost teaching is added before v0.1.9.x ships.

---

## 13. Open Questions Promoted to Spec-Cut

Questions resolved during synthesis (no longer open):

- Public timing argument name → `timing_model` (maintainer 2026-05-27).
- Spread/price-adjustment naming and convention → `ledgr_cost_spread_bps()` with quoted-spread semantics (maintainer 2026-05-27).
- v1 primitive catalog → four primitives + chain (§4.1).
- Percentage-fee composition semantics → resolved-fill-price (§4.4).
- Chain-order validation → fires at construction with `ledgr_invalid_cost_chain_order` (§4.2).
- Fill-intent shape → migrate `commission_fixed` to total `fee` (§4.6).
- Negative fees → banned in v1, rebates deferred (§11).
- Fee currency → single account currency in v1 (§11).
- Identity field count → two: `cost_model_hash` + `cost_plan_json` (§6.1).
- Sum-to-one-fee-per-fill → bound (§4.5).
- Cost is experiment-level in v1 → bound (§10.2).
- Broker templates → not in core (§4.7).
- `metric_context_hash` orthogonality → bound (§6.3).

Remaining open for v0.1.9.x spec-cut:

1. **Legacy scalar handling shape.** Reject `fill_model = list(...)` with a classed error pointing to the new constructors, or accept it for one transitional release with a deprecation message and auto-translation? Both consistent with the no-users posture; spec-cut chooses based on transition ergonomics.
2. **Cost plan execution shape.** Row-wise resolver, vectorized per-pulse resolver, or implementer's choice with stable outputs and identity? Likely defer to implementer; spec-cut confirms.
3. **Cost component diagnostic retention.** Component breakdown only in `meta_json`, or reserve a future diagnostic table shape? Spec-cut decides what `meta_json` carries by default.
4. **Reopen-path compatibility for stored configs.** What does `ledgr_run_open()` do when it encounters a stored config_json that contains `fill_model`? Reject, translate, or read-only-with-warning?
5. **`cost_model = NULL` default.** What does `ledgr_experiment()` do when no `cost_model` is supplied? Default to `ledgr_cost_zero()`, require explicit argument, or use a sentinel that records "no cost" in identity?

---

## 14. Future Obligations Recorded

For follow-up RFCs:

- **Walk-forward identity extension.** The v0.1.9.x walk-forward spec packet must extend `walk_forward_candidate_key` and `walk_forward_session_id` recipes to include `cost_model_hash`. The walk-forward synthesis predates this public cost API and does not yet name cost identity; the omission is on record.
- **Asymmetric price-adjustment constructor.** `ledgr_cost_price_adjust_bps(bps, side = ...)` is reserved as a future constructor for users who need per-leg or asymmetric markup/markdown semantics. When admitted, it must use per-leg semantics distinct from `ledgr_cost_spread_bps()`'s quoted-spread semantics, with both constructors coexisting under clearly different names.
- **Stateful fee tiers RFC.** Rolling-volume fee tiers (IBKR-style, Binance-style) require a stateful cost-state envelope; if added, it must not blur the "cost is stateless per-fill" v1 contract.
- **Maker/taker / rebates RFC.** Maker/taker classification requires a liquidity convention; if admitted, negative-fee handling for rebates needs explicit rebate classes, not arbitrary negative outputs from any fee step.
- **Per-instrument / per-asset-class assignment RFC.** Multi-asset portfolios eventually need per-instrument or per-asset-class cost models; v1's experiment-level model is the floor, not the ceiling.
- **Cost sweep RFC.** `ledgr_cost_grid()` or `ledgr_grid_cross(..., cost = ...)` must establish their own namespace separate from `strategy_params` and define how cost identity participates in sweep candidate identity.
- **Liquidity / execution layer RFC.** Quantity-mutating concerns (partial fills, volume clipping, no-fill rows, queue position) belong to a future liquidity layer that consumes fill proposals and produces fewer or more fill intents than the cost layer alone.
- **Financing / margin-interest RFC.** Borrow cost, carry, perpetual funding, and margin interest are stateful position/calendar cashflows distinct from fill-time cost. They get their own family.
- **OMS interaction RFC.** Per the OMS synthesis, paper/live cost reconciliation requires a broker-fee-reporting layer that consumes external execution reports; this is v0.3.0+ work and must not blur the v1 fill-time cost contract.
- **TCA / reporting layer RFC.** Implementation shortfall, opportunity cost, benchmark-relative shortfall, and venue analysis require benchmark and lifecycle context that the v1 cost API does not provide. A separate TCA layer can compute these from cost-resolved fill rows plus future order-lifecycle data.

---

## 15. Acceptance

This synthesis is accepted as binding for the v0.1.9.x / v0.2.0 public transaction-cost model API ticket cut. It does not modify the v0.1.9 chainable-risk synthesis, the v0.1.9.x walk-forward synthesis, the v0.2.x OMS synthesis, or any predecessor accepted RFC.

The walk-forward synthesis incurs one obligation from this synthesis (cost identity inclusion per §6.4 and §14); the v0.1.9.x walk-forward spec packet must absorb it.

Spec-cut writers may resolve the open questions in §13 without a new RFC. Changing a bound decision in §1–§12 requires a follow-up RFC or explicit maintainer amendment.

---

## 16. Concerns Recorded

None blocking. Two informational items for the spec-cut writer:

1. The `commission_fixed` → `fee` internal migration (§4.6) is the largest single implementation chunk in the v0.1.9.x ticket packet. It touches multiple files but is mechanical; budget accordingly.
2. The convention shift in `spread_bps` semantics (§7) means any maintainer-side development backtests that used the legacy `fill_model$spread_bps` will produce different numbers under the new `ledgr_cost_spread_bps()` with the same `bps` argument. This is expected and intentional. If exact reproduction of pre-rename results is needed, use `ledgr_cost_spread_bps(legacy_bps * 2)`.
