# Target Risk Layer


**Status:** Reviewable maintainer-manual article for v0.1.9.5 LDG-2638.

**Authority:** Synthesis plus implementation trace. Binding scope
remains in `../contracts.md`, the chainable-risk synthesis, and the
v0.1.9.3 spec packet.

This article explains the bounded target-risk layer. It does not
authorize a portfolio optimizer, affordability model, liquidity model,
OMS policy, or arbitrary user callback surface.

## Synthesis

Strategies produce full named numeric target vectors. The risk layer
transforms those targets before the fold converts target deltas into
fill proposals. The first public layer is intentionally small:

- `ledgr_risk_none()` represents the explicit no-op plan;
- `ledgr_risk_long_only()` clamps negative targets;
- `ledgr_risk_max_weight()` caps target weights;
- `ledgr_risk_chain()` composes classed steps in order.

Risk plans are durable data. Public constructors create classed objects
that normalize into a plain plan. That plan is serialized to
`risk_plan_json` and hashed as `risk_chain_hash`. Sweep candidates can
bind risk arguments through parameter references; workers receive a
compiled plain plan rather than a live function or environment.

The layer is target-risk only. It may alter target weights or quantities
inside the bounded step semantics. It must not infer missing targets as
zero, estimate trading costs, check market liquidity, model
affordability or margin, create orders, or implement broker policy.

## Implementation Trace

| Concern | Code |
|----|----|
| Public constructors | `R/risk-model.R`: `ledgr_risk_chain()`, `ledgr_risk_none()`, `ledgr_risk_long_only()`, `ledgr_risk_max_weight()` |
| Plan identity | `R/risk-model.R`: `ledgr_risk_plan_json()`, `ledgr_risk_chain_hash()`, `ledgr_risk_plan_reconstruct()` |
| Worker-safe compile | `R/risk-model.R`: `ledgr_risk_plan_compile()` and compiled-plan validation |
| Step application | `R/risk-model.R`: `ledgr_apply_risk_plan()`, `ledgr_apply_risk_step_long_only()`, `ledgr_apply_risk_step_max_weight()` |
| Execution spec | `R/execution-spec.R` carries the compiled risk plan into the fold |
| Fold integration | `R/fold-engine.R` validates strategy targets, applies the risk plan, then computes fill proposals |
| Run and sweep identity | `R/backtest.R` stores risk identity; `R/sweep.R` compiles candidate plans and verifies promotion identity |

The fold ordering is load-bearing. Strategy output is validated first.
The risk plan is then applied to the full target vector. Only after that
does the fold compare target quantities to current positions and
construct proposed fills.

Because the plan JSON participates in identity, semantically meaningful
risk arguments must be represented in the plan. Display choices, object
class machinery, and helper defaults that normalize to the same no-op
plan must not create distinct candidate identities.

## Maintainer Checklist

Before changing this area:

- keep every public step classed and serializable;
- reject bare functions, lists, and unknown classed objects before
  execution;
- keep the no-op spellings normalized to the same plan;
- keep parameter references durable and reconstructable;
- update identity tests before changing plan keys or canonical JSON
  bytes;
- do not fold affordability, liquidity, cost, OMS, or portfolio
  optimization behavior into this layer.

## Source Links

- `../rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md`
- `../ledgr_v0_1_9_3_spec_packet/v0_1_9_3_spec.md`
- `identity_contract.qmd`
- `execution_fold_core.qmd`
