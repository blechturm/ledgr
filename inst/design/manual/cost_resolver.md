# Cost Resolver


**Status:** Reviewable maintainer-manual article for v0.1.9.5 LDG-2638.

**Authority:** Synthesis plus implementation trace. Binding scope
remains in `../contracts.md`, the public transaction-cost RFC synthesis,
and the v0.1.9.1 spec packet.

This article explains how public cost models become fold-time fill
prices and fees. It is maintainer prose, not a new contract.

## Synthesis

The cost layer sits after strategy targets and target-risk transforms,
and after the timing model has proposed a fill. It may resolve the
proposed fill price and fee. It must not choose targets, mutate
quantities, model liquidity, implement OMS behavior, or reconcile broker
state.

The public API is model-first:

- users construct a timing model, usually `ledgr_timing_next_open()`;
- users construct an explicit cost model such as `ledgr_cost_zero()`,
  `ledgr_cost_spread_bps()`, `ledgr_cost_fixed_fee()`,
  `ledgr_cost_notional_bps_fee()`, or `ledgr_cost_chain()`;
- ledgr serializes the model to `cost_plan_json`;
- ledgr hashes that plan into `cost_model_hash`;
- the fold reconstructs a resolver from the serialized plan.

This route is deliberate. A cost model is durable experiment
configuration, not a callback captured from the caller session. The
resolver used by the fold is compiled from a plain plan and is safe to
send through sweep workers.

Cost identity is part of the experiment, sweep candidate, promotion, and
walk-forward evidence chain. Toggling from zero cost to a spread/fee
chain must change identity. Changing unrelated inspection or display
settings must not.

## Implementation Trace

| Concern | Code |
|----|----|
| Public constructors and validators | `R/cost-model.R`: `ledgr_timing_next_open()`, `ledgr_cost_zero()`, `ledgr_cost_spread_bps()`, `ledgr_cost_fixed_fee()`, `ledgr_cost_notional_bps_fee()`, `ledgr_cost_chain()` |
| Cost identity | `R/cost-model.R`: `ledgr_cost_plan_json()`, `ledgr_cost_model_hash()`, `ledgr_cost_plan_reconstruct()` |
| Resolver construction | `R/cost-model.R`: `ledgr_cost_resolver_from_model()`, `ledgr_cost_resolver_from_plan_json()` |
| Step application | `R/cost-model.R`: `ledgr_cost_model_resolve()` applies steps, with descriptors from `ledgr_cost_steps()` / `ledgr_cost_flat_steps()` |
| Fold integration | `R/fill-model.R` defines `ledgr_resolve_fill_proposal()`; `R/fold-engine.R` calls it to resolve proposed fills before event emission |
| Run integration | `R/backtest.R` stores cost identity; `R/backtest-runner.R` reconstructs the resolver for execution |
| Sweep integration | `R/sweep.R` reconstructs per-candidate execution specs and verifies cost identity during promotion |

The key fold boundary is `ledgr_resolve_fill_proposal()`. It receives a
proposal that already carries side, quantity, timestamp, and instrument.
The resolver may return a resolved `fill_price` and `fee`. The fold then
validates that resolved accounting state is usable before it reaches lot
accounting.

The fee-versus-rounding order is intentional: percentage fees use the
pre-rounding notional base, while rounded fill prices affect the emitted
fill price. That behavior is pinned in the cost-model tests and should
not be changed as formatting cleanup.

## Maintainer Checklist

Before changing this area:

- preserve the serialized plan as the durable source of resolver
  behavior;
- keep function callbacks out of committed cost identity;
- keep timing, cost, target risk, liquidity, OMS, and broker
  reconciliation as separate concerns;
- update cost identity tests when durable constructor arguments change;
- verify sweep promotion and reopened-run identity when touching plan
  JSON.

## Source Links

- `../rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md`
- `../ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md`
- `identity_contract.qmd`
- `execution_fold_core.qmd`
