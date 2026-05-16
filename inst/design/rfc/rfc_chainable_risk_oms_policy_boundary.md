# RFC: Chainable Risk And OMS Policy Boundary

**Status:** Request for comment - design proposal, no implementation started.
**Author:** ledgr maintainer
**Reviewer:** Codex
**Date:** 2026-05-16
**Target cycles:** v0.1.9 target risk, v0.2.x OMS semantics, future parallel sweep
**Context files:**
- `inst/design/contracts.md` - current execution and strategy contracts
- `inst/design/ledgr_roadmap.md` - v0.1.8.x, v0.1.9, and v0.2.x sequencing
- `inst/design/rfc/rfc_sweep_single_core_optimization_routes_v0_1_8_synthesis.md`
- `inst/design/spikes/ledgr_parallelism_spike/`
- `inst/design/architecture/ledgr_v0_1_8_sweep_architecture.md`

---

## 1. Background

ledgr already reserves a future target-risk step between strategy target
validation and fill timing:

```text
strategy targets
  -> target validation
  -> reserved target-risk step
  -> fill timing
  -> cost resolution
  -> state transitions
```

The roadmap also reserves later OMS semantics: orders, cancellations, partial
fills, execution reports, paper trading, and broker reconciliation.

The design question is whether these later layers should be chainable, and how
chainability interacts with sweep mode and parallel candidate dispatch.

This RFC proposes a strict boundary:

```text
Target risk chain:
  targets -> targets

Research order-policy chain:
  desired portfolio delta -> order intents

Paper/live OMS adapter:
  stateful external order management and reconciliation
```

The first two may be chainable in deterministic research runs. The live OMS
adapter must remain outside sweep candidate execution.

---

## 2. Design Principles

1. Preserve one execution semantics.
   Chainable policies must plug into the existing fold core. They must not
   create a second execution engine.

2. Keep target risk pure.
   A target-risk adapter transforms desired portfolio targets. It must not
   write to storage, emit fills, compute metrics, rank candidates, or select
   winners.

3. Keep order policy separate from target risk.
   Target risk decides what portfolio the strategy is allowed to want. Order
   policy decides how the desired change becomes executable order intents.

4. Keep paper/live OMS state out of research sweeps.
   Broker state, open orders, cancellation state, partial fills, latency, and
   reconciliation are not deterministic sweep inputs unless a future RFC
   explicitly models them as snapshot-like research artifacts.

5. Make parallel safety a first-class constraint.
   Any risk or order-policy plan used in sweep must be serializable, hashable,
   deterministic, and independent of worker scheduling.

---

## 3. Target Risk Chain

The target-risk layer should be chainable in v0.1.9.

User-facing sketch:

```r
risk <- ledgr_risk_chain(
  ledgr_risk_long_only(),
  ledgr_risk_max_weight(0.20),
  ledgr_risk_min_trade_value(100),
  ledgr_risk_round_lots(1)
)
```

Each step obeys one pure contract:

```r
risk_step(targets, ctx, params) -> targets
```

The fold order should be:

```text
strategy targets
  -> target validation
  -> risk chain
  -> target validation
  -> fill timing
```

The second validation is required because a risk adapter can change target
values. The final vector must still be complete, named, numeric, finite, and
aligned to the experiment universe.

### Parameterized Risk

Risk settings may be swept through ordinary candidate params:

```r
grid <- ledgr_param_grid(
  sma_n = c(20, 50),
  max_weight = c(0.10, 0.20)
)

risk <- ledgr_risk_chain(
  ledgr_risk_long_only(),
  ledgr_risk_max_weight(param = "max_weight")
)
```

The risk chain is part of the experiment definition. Candidate-specific values
come from `params`, not from a separate tuning mechanism.

---

## 4. Research Order-Policy Chain

OMS-adjacent policy should be chainable only for deterministic research order
intent generation.

User-facing sketch:

```r
orders <- ledgr_order_policy_chain(
  ledgr_order_min_notional(100),
  ledgr_order_round_lots(1),
  ledgr_order_participation_cap(0.10),
  ledgr_order_time_in_force("day")
)
```

The intended contract is different from target risk:

```text
desired portfolio delta -> order intents
```

The later fold shape would be:

```text
strategy targets
  -> risk chain
  -> desired target deltas
  -> research order-policy chain
  -> order intents
  -> simulated execution / fill resolver
```

Research order policies may be deterministic transforms. Paper/live OMS
adapters are not just transforms. They interact with broker state and must sit
outside sweep candidate execution.

---

## 5. Sweep Contract

Sweep mode can use target-risk chains and research order-policy chains only if
they are pure candidate inputs.

Required sweep behavior:

- same chain for every candidate unless candidate `params` select step values;
- per-candidate params are already captured in sweep result rows;
- risk/order-policy identity is captured in candidate provenance;
- failed chain construction or application becomes a candidate failure row when
  `stop_on_error = FALSE`;
- result row order is determined by grid order, not worker completion order.

Forbidden sweep behavior:

- no target-risk adapter may choose a winning candidate;
- no order-policy adapter may query or write DuckDB inside the fold;
- no broker or paper/live OMS state may enter `ledgr_sweep()`;
- no adapter may consume ambient RNG unless a future stochastic policy contract
  explicitly defines seed handling.

---

## 6. Parallel Dispatch Constraints

Parallel sweep dispatch should treat risk and order policy as compiled plans.

Internal pattern:

```text
user chain -> validated plan -> hash/provenance -> worker-safe execution
```

The compiled plan must be:

- a plain serializable value object;
- deterministic from explicit inputs;
- free of live DB connections, external pointers, active bindings, and mutable
  reference state;
- safe to send to PSOCK workers on Windows;
- hashable through ledgr's canonical identity helpers;
- reconstructable on a worker with only package code, snapshot payloads,
  candidate params, and the compiled plan.

Workers may instantiate local helper closures from the plan, but those closures
must not be part of the serialized identity object.

---

## 7. Provenance And Identity

Target-risk and research order-policy chains should have explicit identity.

Minimum provenance fields to consider:

- `risk_chain_hash`
- `risk_chain_version`
- `risk_step_ids`
- `risk_params`
- `order_policy_hash`
- `order_policy_version`
- `order_policy_step_ids`
- `order_policy_params`

Open question: whether risk and order-policy identity belongs in the execution
config hash. The likely answer is yes for committed runs, because these layers
change fills and equity. Metric context is different because it changes only
post-run analysis.

Sweep rows and promotion context should carry enough identity to explain why a
candidate produced its fills.

---

## 8. Non-Goals

This RFC does not propose:

- implementing v0.1.9 risk adapters now;
- implementing OMS or paper/live adapters now;
- adding a public parallel sweep API now;
- adding objective/ranking ownership to ledgr;
- adding broker-state simulation to sweep;
- changing the v0.1.8 fold core before the optimization sequence lands.

---

## 9. Open Questions

1. Should `ledgr_risk_chain()` accept only ledgr risk objects, or also plain
   functions that satisfy `risk_step(targets, ctx, params) -> targets`?
2. Should risk adapters receive the full strategy `ctx`, or a narrower
   risk-specific context?
3. Which risk-chain fields must enter execution config hash versus run
   metadata only?
4. Should research order-policy chains ship before or after paper/live OMS
   design?
5. Should order-policy chain identity be represented separately from fill-model
   identity, or as part of a broader execution-policy identity?
6. How should chain failures be classified in sweep rows: target validation,
   risk validation, order-policy validation, or execution failure?
7. What is the minimum set of chainable risk adapters that proves the design
   without overbuilding v0.1.9?

