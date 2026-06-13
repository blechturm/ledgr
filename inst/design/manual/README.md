# ledgr Maintainer Manual


**Status:** Internal maintainer manual.

**Audience:** maintainers and coding agents.

**Authority:** Synthesis plus implementation traces. Binding decisions
remain in `../contracts.md`, `../rfc/README.md`, ADRs, and versioned
spec packets.

This directory turns the governance record into readable maintainer
prose. It does not create new execution contracts, public API, release
scope, or benchmark claims. When this manual disagrees with a contract,
ADR, accepted RFC, or versioned packet, the governance artifact wins and
this manual should be fixed.

## Article Order

The v0.1.8.11 manual foundation follows the priority order recorded in
`../ledgr_v0_1_8_11_spec_packet/v0_1_8_11_tickets.md`:

1.  execution / fold core;
2.  observability / determinism;
3.  snapshots/data;
4.  sweep;
5.  features;
6.  performance arc;
7.  benchmark methodology;
8.  identity contract;
9.  cost resolver;
10. target risk layer;
11. walk-forward machinery.

## Articles

| Article | Source | Status | Scope |
|----|----|----|----|
| [`execution_fold_core.md`](execution_fold_core.md) | `execution_fold_core.qmd` | Reviewable first batch | Shared fold core, pulse lifecycle, output handlers, trust boundary, B2 guard, and maintainer checklist. |
| [`observability_determinism.md`](observability_determinism.md) | `observability_determinism.qmd` | Reviewable LDG-2540 batch | Fingerprints, closure captures, preflight/RNG determinism, telemetry, replay, and event evidence. |
| [`snapshots_data.md`](snapshots_data.md) | `snapshots_data.qmd` | Reviewable LDG-2541 batch | Snapshot sealing, split stores, fold-entry guards, hot-path trust boundary, and data provenance. |
| [`sweep.md`](sweep.md) | `sweep.qmd` | Reviewable LDG-2542 batch | Sweep candidate identity, parallel dispatch, memory output handler, B2 scope guard, and promotion. |
| [`features.md`](features.md) | `features.qmd` | Reviewable LDG-2543 batch | Feature maps, aliases, cache/projection path, TTR adapters, and runtime `ctx$feature()` lookup. |
| [`performance_arc_v0_1_8_x.md`](performance_arc_v0_1_8_x.md) | `performance_arc_v0_1_8_x.qmd` | Reviewable LDG-2534 batch | v0.1.8.7 to v0.1.8.10 performance arc, benchmark evidence map, peer caveats, and public-claim boundaries. |
| [`benchmark_methodology.md`](benchmark_methodology.md) | `benchmark_methodology.qmd` | Reviewable LDG-2545 batch | Local benchmark record generation, repeatability expectations, release-gate checks, and public-claim boundaries. |
| [`identity_contract.md`](identity_contract.md) | `identity_contract.qmd` | Reviewable v0.1.9.1 LDG-2563 batch | Config, feature, alias, and cost identity fields after the public cost API and identity hardening work. |
| [`cost_resolver.md`](cost_resolver.md) | `cost_resolver.qmd` | Reviewable v0.1.9.5 LDG-2638 batch | Public cost-model plans, resolver reconstruction, cost identity, and fold integration boundaries. |
| [`target_risk_layer.md`](target_risk_layer.md) | `target_risk_layer.qmd` | Reviewable v0.1.9.5 LDG-2638 batch | Classed risk steps, risk-chain identity, worker-safe plans, and target-risk layer boundaries. |
| [`walk_forward_machinery.md`](walk_forward_machinery.md) | `walk_forward_machinery.qmd` | Reviewable v0.1.9.5 LDG-2638 batch | Walk-forward fold orchestration, scalar selection, locator verification, persistence, and inspection surfaces. |

## Rendered Output

Manual articles use Quarto source and render to sibling GitHub-flavored
Markdown. Commit both forms so maintainers and coding agents can read
the same content in plain text, while GitHub can render `README.md` as
the browsable directory landing page.

Run this after changing any manual `.qmd` source:

``` powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" tools/render-maintainer-manual.R
```

The render helper updates article siblings, renders `README.qmd`
explicitly as the GitHub directory landing page, and normalizes Mermaid
fences for GitHub.

## Source Map

Start with these binding or source-of-truth documents before revising
manual articles:

- `../contracts.md`
- `../rfc/README.md`
- `../horizon.md` (2026-06-02 `[architecture]` B2 spot-FIFO accelerator
  scope guard)
- `../rfc/rfc_compiled_hot_frame_b2_v0_1_9_x_maintainer_decisions.md`
  (Decision 2 narrowing)
- `execution_fold_core.qmd` (`## Implementation Trace`)
- `features.qmd` (`## Implementation Trace`)
- `sweep.qmd` (`## Implementation Trace`)
- `benchmark_methodology.qmd` (`## Implementation Trace`)
- `cost_resolver.qmd` (`## Implementation Trace`)
- `target_risk_layer.qmd` (`## Implementation Trace`)
- `walk_forward_machinery.qmd` (`## Implementation Trace`)
- `../ledgr_v0_1_8_7_spec_packet/benchmark_attribution_closeout.md`
- `../ledgr_v0_1_8_8_spec_packet/peer_benchmark_parity_closeout.md`
- `../ledgr_v0_1_8_9_spec_packet/v0_1_8_9_release_closeout.md`
- `../ledgr_v0_1_8_10_spec_packet/v0_1_8_10_spec.md`
- `../ledgr_v0_1_8_10_spec_packet/v0_1_8_10_release_closeout.md`
- `../ledgr_v0_1_8_11_spec_packet/v0_1_8_11_spec.md`
- `../ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md`
- `../ledgr_v0_1_9_3_spec_packet/v0_1_9_3_spec.md`
- `../ledgr_v0_1_9_4_spec_packet/v0_1_9_4_spec.md`
- `../rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md`
- `../rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md`
- `../rfc/rfc_walk_forward_evaluation_v0_1_9_x_synthesis.md`
- `../rfc/rfc_sweep_artifact_persistence_v0_1_9_x_synthesis.md`
