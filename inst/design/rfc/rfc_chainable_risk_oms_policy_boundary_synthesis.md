# RFC Synthesis: Chainable Risk And OMS Policy Boundary

**Status:** Accepted synthesis - binding for v0.1.9 target-risk ticket cut; broader execution-policy pipeline deferred to a new RFC.
**Date:** 2026-05-16
**Source RFC:** `inst/design/rfc/rfc_chainable_risk_oms_policy_boundary.md`
**Reviewer response:** `inst/design/rfc/rfc_chainable_risk_oms_policy_boundary_response.md`
**Follow-up RFC:** `inst/design/rfc/rfc_execution_policy_pipeline_audit_signal_north_star.md`

---

## 1. Decision Summary

The target-risk portion of the RFC is accepted as the v0.1.9 design direction.
The research order-policy and OMS portions are not accepted into v0.1.9 scope.

Accepted near-term shape:

```text
strategy targets
  -> target validation
  -> risk chain
  -> target validation
  -> fill timing
  -> cost resolution
  -> ledger events
```

The v0.1.9 release should introduce a chainable target-risk layer only. It must
not introduce research order-policy chains, OMS lifecycle semantics, public
cost/liquidity chains, or a broad tiered output policy.

The response correctly identified a larger north-star architecture: a typed,
composable, observable execution policy pipeline from strategy intent to
realized events. That direction is important, but it is larger than the current
RFC. It is routed into a separate north-star RFC.

---

## 2. Accepted v0.1.9 Target-Risk Direction

### Chain Contract

Risk steps are pure target transforms:

```r
risk_step(targets, ctx, params) -> targets
```

The final target vector after the chain must remain complete, named, numeric,
finite, and aligned to the experiment universe.

The fold must validate targets twice:

```text
strategy targets
  -> target validation
  -> risk chain
  -> target validation
  -> fill timing
```

The second validation is load-bearing. Risk adapters can alter targets, so the
engine must validate the final target vector before any fill timing or cost
resolution happens.

### Initial Public Surface

v0.1.9 should accept classed ledgr risk-step objects only:

```r
risk <- ledgr_risk_chain(
  ledgr_risk_long_only(),
  ledgr_risk_max_weight(0.20)
)
```

Plain user-supplied risk functions are deferred. They require source capture,
closure/captured-object treatment, fingerprinting, and preflight-equivalent
classification before they can enter execution identity safely.

Minimum adapter set for v0.1.9:

- `ledgr_risk_long_only()`
- `ledgr_risk_max_weight()`

Deferred adapters:

- `ledgr_risk_min_trade_value()`
- `ledgr_risk_round_lots()`
- participation caps, liquidity clipping, no-fill rules, partial fills, and
  other execution/liquidity policies

These deferred adapters blur target-risk, order-policy, cost, and liquidity
semantics. They should not be used to prove the first risk-chain release.

---

## 3. Params, Identity, And Sweep

Risk chain identity belongs to execution identity because risk changes fills,
equity, and run outcomes. Metric context is different: metric context changes
post-run analysis only and must not enter execution config hash.

The v0.1.9 spec must resolve the exact hash migration rule:

- whether `risk_chain = NULL` is omitted or serialized as an explicit null for
  new configs;
- whether explicit identity risk chains hash differently from omitted risk;
- how pre-v0.1.9 stored config hashes are compared when no risk field exists.

This synthesis intentionally does not hard-code that rule. It records the
requirement that the rule be explicit and tested.

Parameterized risk should use ordinary candidate params:

```r
grid <- ledgr_param_grid(max_weight = c(0.10, 0.20))

risk <- ledgr_risk_chain(
  ledgr_risk_max_weight(param = "max_weight")
)
```

Per-candidate values belong in the existing `params` payload. They should not be
duplicated into a separate `risk_params` column. Risk-chain provenance should
describe chain structure and fixed arguments; candidate-varying values remain
candidate params.

Sweep behavior:

- failed risk-chain construction or application becomes a candidate failure row
  when `stop_on_error = FALSE`;
- result row order remains grid order;
- seed derivation remains independent of risk execution order;
- risk identity is available in candidate/run provenance;
- no risk step may choose, rank, or promote candidates.

---

## 4. Implementation Constraints

### Compiled Plan

The user-facing risk chain should compile to a worker-safe plan before the fold:

```text
user chain -> validated risk plan -> hash/provenance -> fold execution
```

The plan must be:

- a plain serializable value object;
- deterministic from explicit inputs;
- free of live DB connections, external pointers, active bindings, and mutable
  reference state;
- safe to send to PSOCK workers on Windows;
- reconstructable on a worker from package code, snapshot/candidate payloads,
  candidate params, and the plan.

The plan is resolved once per candidate fold. Local helper closures may be
constructed at candidate setup time, but they must not be reconstructed on every
pulse and must not be part of the serialized identity object.

### Risk Context

For v0.1.9, ledgr-owned classed risk steps may use the same strategy-context
shape that the strategy receives. Public arbitrary risk functions are deferred,
so v0.1.9 does not expose a general user-code risk context contract.

The v0.1.9 spec must record a standing future obligation: if a narrower
risk-specific context is introduced later, it must define exactly which
strategy context fields it exposes, which it excludes, and how helpers such as
`ctx$hold()` behave.

### Failure Classification

v0.1.9 should distinguish where a failure occurred. Candidate failure rows may
need a new `failure_type` field, or an equivalent typed classification, in
addition to `error_class` and `error_msg`.

Minimum categories to consider:

- `strategy_error`
- `target_validation_error`
- `risk_step_error`
- `risk_validation_error`
- `execution_error`

This is a schema change and must be specified with column-order and promotion
context implications before implementation.

---

## 5. Explicit Deferrals

### Research Order-Policy Chain

Research order-policy chains are deferred. The examples in the RFC, including
minimum notional, round lots, participation caps, and time-in-force, overlap
with cost/liquidity and OMS semantics.

They require design answers that do not belong in v0.1.9:

- what an order intent is;
- whether order policies see execution-bar data;
- how no-lookahead is preserved;
- how order lifecycle semantics work in research mode;
- how order-policy identity relates to fill-model and cost identity;
- how broker/paper/live OMS state is kept out of deterministic sweeps.

### Tiered Output Policy

The reviewer response introduced a useful observation boundary:

```text
strategy intent -> risk-adjusted targets -> realized events
```

That boundary is accepted as an architectural insight. The proposed tiered
output policy is not accepted as-is.

Reasons:

- it introduces `analysis_mode`, new persistence tables, result accessors, and
  sweep/promotion behavior beyond the source RFC;
- `ledgr_candidate()` cannot retroactively preserve per-pulse diagnostic
  records for a sweep candidate selected after the sweep has already run;
- proposed risk summary fields such as `risk_mean_adjustment` need precise
  definitions before they can become contract fields.

The broader output-retention and audit-signal model is routed into the new
north-star RFC.

### Cost, Liquidity, And OMS

Composable cost, liquidity, order policy, and OMS behavior is deferred to the
north-star execution-policy pipeline RFC. v0.1.9 must not bolt these stages onto
the risk-chain release.

---

## 6. v0.1.9 Minimum Scope

The v0.1.9 target-risk ticket set should include:

1. `ledgr_risk_chain()` accepting classed ledgr risk-step objects only.
2. `ledgr_risk_long_only()` and `ledgr_risk_max_weight()`.
3. Fold-core insertion at the reserved target-risk slot.
4. Target validation before and after the risk chain.
5. Explicit risk-chain identity and config-hash rules, including legacy/null
   behavior.
6. Risk-chain provenance in committed runs, sweep candidates, and promotion
   context where applicable.
7. Worker-safe compiled risk plan resolved once per candidate fold.
8. Failure classification that distinguishes strategy, target validation, risk
   step, post-risk validation, and execution failures.
9. Documentation explaining target-risk as `targets -> targets`, not order
   sizing, cost, liquidity, ranking, or OMS.
10. A recorded future-context obligation: if ledgr later introduces a
    risk-specific context, the spec must define exactly which strategy-context
    fields it exposes, which it excludes, and how helpers such as `ctx$hold()`
    behave.

Non-goals for v0.1.9:

- plain user-supplied risk functions;
- research order-policy chains;
- public cost/liquidity chains;
- minimum trade value and round-lot helpers unless a follow-up design resolves
  their target-versus-order semantics;
- `analysis_mode` or tiered output retention;
- broker, paper/live, or OMS lifecycle semantics.
