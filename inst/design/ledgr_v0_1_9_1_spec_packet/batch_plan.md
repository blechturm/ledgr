# ledgr v0.1.9.1 Batch Plan

**Status:** Planned; Batch 0 / LDG-2547 completed on 2026-06-05.

This batch plan sequences the v0.1.9.1 cost-API and auditr-hardening packet
without expanding scope beyond `v0_1_9_1_spec.md`. The public cost model,
timing model, identity fields, and migration work are reviewed in separate
units so behavioral changes stay attributable.

## Batch 0 - Packet Review And Ticket Alignment

Ticket: `LDG-2547`
Status: Completed

Goal: finalize the packet after Codex spec review and cut
`v0_1_9_1_tickets.md`, `tickets.yml`, and this batch plan.

Exit criteria:

- Spec, tickets, YAML, and batch plan agree.
- Prior Codex blocker findings are patched or accepted.
- The remaining contracts.md question is resolved as bounded scope under
  LDG-2563.
- No target-risk, walk-forward, or sweep persistence scope is introduced.

Completion note:

- Batch 0 completed on 2026-06-05. Tickets `LDG-2547` through `LDG-2574`
  are cut. `LDG-2547` is complete; all implementation and release-gate tickets
  remain planned.

## Batch 1 - Public Cost Object Surface

Tickets: `LDG-2548`, `LDG-2549`, `LDG-2550`, `LDG-2551`, `LDG-2552`
Status: Planned

Goal: land public cost primitives, chain composition, timing constructor, cost
identity, and inspection helpers before execution wiring.

Exit criteria:

- Cost primitives and `ledgr_cost_chain()` validate at construction time.
- `ledgr_timing_next_open()` and `timing_model` are available on
  `ledgr_experiment()`.
- `cost_model_hash` and `cost_plan_json` are deterministic and reconstructable.
- Inspection helpers return stable output.
- Roxygen examples render.

Review focus:

- Quoted-spread semantics use half-spread per side.
- Cost identity does not depend on memory addresses, R environments, object
  print output, or package load order.
- `metric_context_hash` remains orthogonal.

## Batch 2 - Execution And Migration Wiring

Tickets: `LDG-2553`, `LDG-2554`, `LDG-2555`, `LDG-2556`, `LDG-2557`, `LDG-2558`
Status: Planned

Goal: wire cost plans through the existing resolver seam, rename legacy fields,
reject legacy config shapes, and make both public entry points require explicit
cost models.

Exit criteria:

- Cost application mutates only price and fee, never quantity, side,
  instrument, or execution timestamp.
- `commission_fixed` is replaced by `fee` on new surfaces.
- `fill_model` becomes `timing_model` on new config paths.
- `ledgr_run_open()` rejects legacy stored `fill_model` configs.
- `ledgr_backtest()` and `ledgr_experiment()` share the public
  `timing_model` + required `cost_model` contract.

Review focus:

- No second execution engine.
- Sequential run and sweep candidate execution share the same fold core.
- Pre-CRAN no-translation posture is applied consistently.

## Batch 3 - Identity Hardening

Tickets: `LDG-2559`, `LDG-2560`, `LDG-2561`
Status: Planned

Goal: close the three THEME-004 hash hardening bugs from the auditr cycle.

Exit criteria:

- `config_hash` is independent of DuckDB store path.
- `config_hash` is independent of alias declaration order.
- `alias_map_hash` is independent of concrete feature parameter values.
- Regression tests cover auditr episode 043 FB-002 and episode 037 FB-003 /
  FB-004.

Review focus:

- Proven store-path contamination and precautionary explicit-run-id cleanup are
  kept distinct.
- Concrete feature identity remains in `feature_set_hash`.
- Any intentionally retained identity field has a written rationale.

## Batch 4 - Identity Surface And Contract Reference

Tickets: `LDG-2562`, `LDG-2563`
Status: Planned

Goal: expose `feature_set_hash` on documented surfaces and author the identity
contract reference, including the bounded `contracts.md` update.

Exit criteria:

- `feature_set_hash` is inspectable from in-session and reopened runs.
- `ledgr_run_info()` and `ledgr_run_list()` expose the field.
- Identity reference documents every hash and JSON identity field named in the
  spec.
- `contracts.md` names the new public cost/timing and identity contract
  without unrelated restructuring.

Review focus:

- Documentation agrees with the regression tests from Batch 3.
- `cost_model_hash` and `cost_plan_json` are explained as forward dependencies
  for walk-forward without implementing walk-forward.

## Batch 5 - High Auditr And Condition Documentation

Tickets: `LDG-2564`, `LDG-2565`, `LDG-2566`
Status: Planned

Goal: close the installed disclaimer link breakage and document new / existing
condition classes that are in this packet's bounded scope.

Exit criteria:

- The formal disclaimer resolves from an installed package.
- New v0.1.9.1 condition classes have help topics.
- `LEDGR_LAST_BAR_NO_FILL` is discoverable in help and cross-referenced from
  execution documentation.

Review focus:

- The disclaimer fix is tested from an installed package, not only from a
  source checkout.
- Condition docs teach stable top-level classes users can assert on.

## Batch 6 - Cost Documentation Surfaces

Tickets: `LDG-2567`, `LDG-2568`, `LDG-2569`
Status: Planned

Goal: refresh cost-facing vignettes and examples without opening sweep cost-grid
or broader docs-pass scope.

Exit criteria:

- `metrics-and-accounting` teaches quoted spread, explicit fees, timing-vs-cost
  separation, and fail-closed compiled-accounting behavior.
- Cost API help pages contain runnable examples.
- Sweep docs state that cost models do not participate in grid composition in
  v1 and route `ledgr_cost_grid()` to future work.

Review focus:

- Articles follow `inst/design/vignette_styleguide.md`.
- No liquidity, OMS, TCA, financing, taxes, or broker reconciliation features
  are implied.

## Batch 7 - Release Surfaces

Tickets: `LDG-2570`, `LDG-2571`, `LDG-2572`, `LDG-2573`
Status: Planned

Goal: update release notes and planning indexes after implementation tickets
close.

Exit criteria:

- NEWS names the cost-API headline and breaking changes.
- Roadmap reflects v0.1.9.1 state.
- Horizon moves the cost-API spec-cut decision to resolved only at release
  close while preserving forward obligations.
- Design and RFC indexes reflect v0.1.9.1 implementation state.

Review focus:

- No future packet is marked shipped prematurely.
- Cost identity forward obligation for v0.1.9.4 remains visible.

## Batch 8 - Release Gate

Ticket: `LDG-2574`
Status: Planned

Goal: verify and close v0.1.9.1 after all implementation, documentation, and
release-surface tickets are done.

Exit criteria:

- All prior tickets are completed or explicitly re-routed.
- Targeted cost, timing, identity, run-store, sweep, and docs checks pass.
- Full tests, package build, and R CMD check pass or have accepted gate
  disposition.
- Release closeout records the result and v0.1.9.2 can start from a stable
  cost-identity surface.
