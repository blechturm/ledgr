# RFC: Execution Policy Pipeline And Audit Signal North Star

**Status:** Request for comment - north-star architecture proposal, no implementation started.
**Author:** ledgr maintainer
**Reviewer:** Codex
**Date:** 2026-05-16
**Target cycles:** v0.1.9.x and v0.2.x architecture planning
**Spawned by:** `inst/design/rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md`
**Context files:**
- `inst/design/rfc/rfc_cost_model_architecture_response.md`
- `inst/design/rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md`
- `inst/design/rfc/rfc_sweep_single_core_optimization_routes_v0_1_8_synthesis.md`
- `inst/design/ledgr_roadmap.md`
- `inst/design/contracts.md`

---

## 1. Problem Statement

ledgr is moving toward several composable execution-adjacent layers:

- target-risk transforms;
- research order policies;
- timing models;
- cost models;
- liquidity and no-fill policies;
- later OMS and paper/live adapters.

Each of these can change the path from strategy intent to realized ledger
events. If they are designed independently, ledgr risks ending up with several
opaque mini-engines. That would undermine the package's central promise:
deterministic, event-sourced, inspectable backtesting.

The north-star question is:

```text
How should ledgr represent the path from strategy intent to realized events as
a typed, composable, observable execution policy pipeline?
```

This RFC is not an implementation plan for v0.1.9. It defines the architecture
direction that should keep v0.1.9 risk, later cost/liquidity work, parallel
sweeps, and v0.2.x OMS semantics aligned.

---

## 2. North-Star Pipeline

The long-run execution policy pipeline should make each transformation explicit:

```text
strategy targets
  -> target validation
  -> risk chain
  -> target validation
  -> order policy / sizing
  -> timing model
  -> fill proposals
  -> cost chain
  -> liquidity / execution chain
  -> ledger validation
  -> events
```

The stages have different contracts:

```text
risk chain:
  targets -> targets

order policy / sizing:
  target deltas -> order intents

timing model:
  order intents -> fill proposals

cost chain:
  fill proposals -> priced fill intents

liquidity / execution chain:
  fill proposals or fill intents -> fill intents / no-fill reasons

ledger:
  validated fill intents -> events
```

The exact split between cost and liquidity remains open. The key principle is
that quantity-preserving pricing/fee adjustments are not the same thing as
quantity-changing execution or liquidity decisions.

Ledger validation is structural, not a final policy veto. It should enforce
that a fill intent is internally valid for event writing (finite positive
quantity, valid side, valid price, valid timestamp, known instrument, and
similar invariants). Economic reasonableness belongs to risk, order policy,
cost, liquidity, or execution stages before the ledger writer.

---

## 3. Stage Boundaries

### Target Risk

Target risk transforms desired portfolio targets before fill timing:

```text
targets -> targets
```

Examples:

- long-only clipping;
- max weight;
- exposure constraints;
- sector/net exposure constraints.

Target risk must not decide fills, prices, fees, order lifecycle, or candidate
ranking.

### Research Order Policy

Research order policy transforms desired target deltas into order intents:

```text
target deltas -> order intents
```

Examples may eventually include:

- order-side intent records;
- notional sizing;
- lot handling if ledgr chooses order-level rounding rather than target-level
  rounding;
- time-in-force semantics after OMS lifecycle is defined.

This stage is deferred until order intents and OMS semantics are specified.

### Timing Model

Timing decides when an order intent can become a fill proposal:

```text
order intents -> fill proposals
```

The current default is next-open timing. A fill proposal is still not a ledger
event. It is an auditable intermediate: "under the timing assumption, this is
what could be filled."

This stage should remain consistent with the existing private
`ledgr_fill_proposal` direction from the cost-model architecture response. That
response already reserves proposal fields such as instrument, side, quantity,
decision timestamp, execution timestamp, and execution-bar identity. This RFC
extends that direction; it should not define an incompatible proposal shape.

### Cost Chain

The cost chain resolves price and fees for proposed fills.

Quantity-preserving examples:

- spread;
- commission;
- slippage price adjustment;
- fee schedules.

The cost chain should generally preserve side and quantity. If a policy changes
quantity or refuses fills, it belongs in liquidity/execution unless a future RFC
explicitly combines the stages.

### Liquidity / Execution Chain

Liquidity and execution policies change what fills:

- volume clipping;
- participation caps;
- no-fill decisions;
- partial fills;
- liquidity refusal;
- execution throttles.

These policies need a richer execution context than target risk. They may need
execution-bar data such as volume. They must be designed carefully to preserve
the no-lookahead boundary.

### OMS / Paper-Live Adapter

OMS semantics include order lifecycle, cancellations, replacements, partial
fills over time, broker-reported state, and reconciliation.

Research policies may be pure and sweep-compatible. Paper/live OMS adapters are
stateful external systems and must stay outside deterministic sweep candidate
execution unless represented by explicit research artifacts.

---

## 4. Audit Signal Model

Each stage should be able to emit structured audit signals. Signals are not
necessarily retained in every run. They define the common shape for diagnostic
output when retained.

Minimum fields to consider:

```text
run_id
pulse_ts_utc
instrument_id
stage
step_id
step_hash
input_target_qty
output_target_qty
input_order_qty
output_order_qty
input_fill_qty
output_fill_qty
reference_price
resolved_price
fee
reason_code
changed
severity
message
details_json
```

Not every field is meaningful at every stage. The design question is whether to
use one wide event-like table, per-stage typed tables, or a compact signal
record with stage-specific `details_json`.

`severity` is not yet defined. A future signal schema must decide whether
severity is emitted by the policy step, assigned by ledgr after inspecting the
signal, or derived from `reason_code`. It must not become an implicit
implementation convention.

Signals answer attribution questions:

```text
strategy wanted 100
risk clipped to 50
order policy rounded to 40
timing proposed next open
liquidity filled 25
cost adjusted price by 8 bps
ledger recorded 25
```

The goal is not to persist every signal by default. The goal is to have one
language for explaining changes when the user asks for diagnostic depth.

---

## 5. Output Retention Tiers

The chainable risk/OMS response proposed a tiered output policy. This RFC keeps
that idea but treats it as unresolved north-star design.

Possible tiers:

```text
fast:
  summary metrics and compact provenance only

standard:
  current durable run outputs: fills, equity, trades, metrics, events

diagnostic:
  selected audit signals and target/order/fill intermediates

full:
  complete stage-by-stage signal stream and state snapshots
```

Important correction: a sweep cannot retroactively retain diagnostic records for
a candidate selected after the sweep has already finished. Valid designs are:

- rerun the selected candidate during `ledgr_promote(..., analysis_mode =
  "diagnostic")`;
- require diagnostic candidate labels before sweep execution;
- store diagnostic records for every candidate with an explicit cost warning.

The diagnostic rerun path is valid only if promotion uses the stored
`execution_seed` from the selected sweep result row. That is already the sweep
promotion contract, and the diagnostic workflow must preserve it so stochastic
strategies replay the same path.

The north-star output policy must choose one or more of these, not imply
retroactive retention through `ledgr_candidate()`.

---

## 6. Identity And Provenance

Every executable policy stage needs explicit identity.

Questions for each stage:

- Does it enter execution config hash?
- What is its stable type ID?
- What fixed arguments are hashed?
- Which values come from candidate `params`?
- How are user functions represented, if they are ever allowed?
- How does sweep record stage identity in candidate rows?
- How does promotion context preserve the selected candidate's policy identity?

Likely rule:

- risk, order policy, timing, cost, and liquidity affect fills/equity and
  belong to execution identity;
- metric context affects post-run analysis only and does not belong to
  execution identity;
- paper/live adapter connection state does not belong to deterministic research
  config identity unless represented as an explicit sealed artifact.

---

## 7. Sweep And Parallel Constraints

Any policy stage used in sweep must compile to a worker-safe plan:

```text
user-facing policy -> validated plain plan -> hash/provenance -> fold execution
```

The plan must be:

- serializable on Windows PSOCK workers;
- deterministic from explicit inputs;
- independent of ambient RNG unless a future stochastic-policy contract defines
  seed handling;
- free of live DB connections, external pointers, mutable environments, and
  active bindings;
- reconstructable from package code, snapshot payloads, candidate params, and
  the plan.

Parallel execution must preserve:

- deterministic result row order;
- per-candidate warning/error association;
- per-candidate seed derivation independent of worker scheduling;
- failure classification by stage;
- promotion provenance.

No stage may query or write DuckDB inside the per-pulse candidate fold unless a
future RFC explicitly changes the no-DB sweep contract.

---

## 8. Release Sequencing

This RFC should inform but not expand near-term scopes.

Suggested sequence:

```text
v0.1.9:
  target-risk chain only
  classed ledgr risk steps
  long-only and max-weight adapters
  no order policy, public cost chain, liquidity chain, or OMS

v0.1.9.x:
  evaluate diagnostic signal retention and failure classification
  possibly specify target/risk signal schemas

v0.2.x:
  order intents, cost/liquidity composition, OMS research semantics

v0.3.x+:
  paper/live adapters after OMS semantics and reconciliation are stable
```

The north-star pipeline is allowed to influence v0.1.9 naming and internal
boundaries, but it should not cause v0.1.9 to ship multiple execution-policy
layers at once.

---

## 9. Open Questions

1. Should audit signals use one shared schema or stage-specific typed tables?
2. Should cost and liquidity be separate chains or one execution-policy chain
   with quantity-preserving and quantity-mutating steps?
3. Should target-risk adapters ever be allowed to emit audit signals without
   changing targets?
4. Where should round lots live: target risk, order policy, or both with
   distinct names? This must be answered before any public round-lot adapter is
   implemented.
5. Where should minimum notional live: target risk, order policy, or liquidity?
   This must be answered before any public minimum-notional/minimum-trade-value
   adapter is implemented.
6. What is the first output-retention tier that is worth implementing after
   v0.1.9 risk lands?
7. How should stage-level failure classification map to existing sweep
   `error_class` and `error_msg` fields?
8. What is the minimal policy-plan representation that supports hash stability,
   parallel dispatch, and readable provenance?
9. Which stage boundaries need separate contexts to preserve no-lookahead?
10. Which parts of the pipeline belong in public API versus private fold-core
    structure?
