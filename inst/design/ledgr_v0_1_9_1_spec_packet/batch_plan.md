# ledgr v0.1.9.1 Batch Plan

**Status:** Completed on 2026-06-05; all batches closed.

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
Status: Completed

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
Status: Completed

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

## Batch 2.5 - Cost Resolver Measurement Spike

Ticket: `LDG-2575`
Status: Completed

Goal: measure the per-fill cost-resolver overhead introduced by Batch 2
against the v0.1.8.11 peer benchmark baseline. The spike output decides
whether v0.1.9.1 ships with an acknowledged perf delta, whether parked
optimization options from the 2026-06-05 post-LDG-2522 horizon entry
should be reopened, and produces the with-costs peer-benchmark row for
the v0.1.9.1 release bundle.

Exit criteria:

- Spike synthesis records three measurements: `ledgr_cost_zero()` floor,
  realistic `ledgr_cost_chain(ledgr_cost_spread_bps(5), ledgr_cost_fixed_fee(1))`,
  and equivalent v0.1.8.11 legacy `fill_model` baseline.
- Verdict recorded: `ship-as-is`, `ship-with-known-overhead`, or
  `horizon-signal`.
- Peer benchmark record bundle archived under
  `dev/bench/results/v0.1.9.1_record/` with the new with-costs row.
- Horizon status update applied if the verdict is `horizon-signal`.

Closeout:

- Record command completed on 2026-06-05 with `--engine-set ledgr-cost`,
  `--n-inst 500`, and `--n-days 1260`.
- Record bundle archived at `dev/bench/results/v0.1.9.1_record/`.
- Synthesis written to
  `inst/design/spikes/cost_resolver_measurement_spike/measurement_synthesis.md`.
- Verdict: `ship-with-known-overhead`; the single record row showed a
  5.26s / 6.5%
  engine-phase delta versus `ledgr_cost_zero()`, but a focused resolver-only
  loop over the same 68,201 fill count measured 0.26s total public-chain
  resolver delta, about 3.8 microseconds per fill. LDG-2570 NEWS should name
  the observed xlarge row delta with that attribution caveat.
- No horizon status update required.

Review focus:

- Same fixture as the v0.1.8.10 / v0.1.8.11 peer benchmark bundle
  (500-instrument SMA crossover, 5-year daily bars, same seed, same
  shared bars CSV).
- The spike informs release NEWS language and surfaces a horizon perf
  signal if material; it does not gate release on the measured delta
  unless the maintainer routes a severe regression to a follow-on
  optimization packet.
- Spike synthesis lives under
  `inst/design/spikes/cost_resolver_measurement_spike/`; raw bundle
  artifacts live under `dev/bench/results/`.

## Batch 3 - Identity Hardening

Tickets: `LDG-2559`, `LDG-2560`, `LDG-2561`
Status: Completed

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

Closeout:

- `config_hash()` now hashes a normalized payload that excludes `db_path`,
  `data$snapshot_db_path`, `run_id`, and diagnostic `alias_map_order` while
  preserving `data$snapshot_id` and other execution identity.
- Feature definitions are ordered by feature ID inside the config-hash payload,
  so feature-map declaration order no longer contaminates config identity.
- Active feature-map alias storage now separates the concrete runtime lookup
  map from the alias identity payload used for `alias_map_hash`; concrete
  parameter values remain represented by feature fingerprints /
  `feature_set_hash`.
- Focused verification: `test-config.R`, `test-active-alias-runtime.R`,
  `test-feature-map.R`, `test-precompute-features.R`,
  `test-feature-inspection.R`, `test-metric-context-storage.R`, and
  `test-sweep-parity.R`.

## Batch 4 - Identity Surface And Contract Reference

Tickets: `LDG-2562`, `LDG-2563`
Status: Completed

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

Closeout:

- `bt$config$features$feature_set_hash` is populated from resolved feature
  fingerprints for committed runs, including empty feature sets. This derived
  surface is excluded from `config_hash`; the underlying feature definitions
  remain hash-sensitive.
- `ledgr_run_info()` and `ledgr_run_list()` expose `feature_set_hash` by
  projecting it from stored `config_json`; no DuckDB schema column or migration
  was added.
- Added `?ledgr_identity_fields` plus
  `inst/design/manual/identity_contract.{qmd,md}` documenting config, feature,
  alias, and cost identity layering.
- `contracts.md` now names the v0.1.9.1 public timing/cost contract,
  required `cost_model`, cost identity, legacy config rejection, and identity
  field layering.
- Focused verification: `test-run-store.R`, `test-config.R`,
  `test-active-alias-runtime.R`, `test-sweep-parity.R`, and
  `test-documentation-contracts.R`.

## Batch 5 - High Auditr And Condition Documentation

Tickets: `LDG-2564`, `LDG-2565`, `LDG-2566`
Status: Completed

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

Closeout:

- `inst/DISCLAIMER.md` now installs the formal disclaimer at package root, so
  the existing research-workflow `../DISCLAIMER.md` link resolves from an
  installed package.
- `?ledgr_condition_classes` aliases the new v0.1.9.1 cost/timing/legacy
  classes plus the bounded existing `ledgr_run_not_found` and
  `ledgr_unresolved_feature_id` classes.
- `?LEDGR_LAST_BAR_NO_FILL` documents the final-bar warning contract and is
  cross-referenced from the execution-semantics vignette.
- Focused verification: `test-documentation-contracts.R`, `test-cost-model.R`,
  `test-backtest-wrapper.R`, no-vignette package build tar listing, and
  temporary-library install smoke resolving `system.file("DISCLAIMER.md")`.

## Batch 6 - Cost Documentation Surfaces

Tickets: `LDG-2567`, `LDG-2568`, `LDG-2569`
Status: Completed

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

Closeout:

- `metrics-and-accounting` now teaches the quoted-spread convention,
  timing-vs-cost separation, price-transform-vs-explicit-fee separation, and
  fail-closed compiled-accounting behavior without expanding liquidity, OMS,
  TCA, financing, tax, or broker-reconciliation scope.
- Cost API help pages include runnable construction, chain-composition,
  identity-inspection, explicit zero-cost, timing-model, and missing-cost-model
  examples.
- Sweep docs now state that cost models are fixed experiment inputs in v1 and
  route cost-grid composition such as `ledgr_cost_grid()` to future work.
- Focused verification: `test-documentation-contracts.R`, `test-cost-model.R`,
  `test-backtest-wrapper.R`, and direct Rd example smoke checks for the cost
  and timing help pages.

## Batch 7 - Release Surfaces

Tickets: `LDG-2570`, `LDG-2571`, `LDG-2572`, `LDG-2573`
Status: Completed

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

Closeout:

- `NEWS.md` now names the v0.1.9.1 public cost-API headline, breaking
  pre-CRAN changes, THEME-004 identity fixes, bounded auditr documentation
  fixes, and explicit v0.1.9.2+ non-claims.
- `ledgr_roadmap.md` and `inst/design/README.md` reflect that v0.1.9.1
  implementation / documentation / release-surface tickets are closed while the
  release gate remains pending.
- `inst/design/horizon.md` moves only the v0.1.9.1 cost-API spec-cut decision
  entry to `## Resolved`; sequencing, sweep persistence, and walk-forward
  forward-obligation entries remain open.
- `inst/design/rfc/README.md` records the cost-API synthesis as implemented by
  v0.1.9.1 and points at the identity contract reference.
- Focused verification: release-surface documentation contract tests and
  targeted `rg` checks for v0.1.9.1 / future-packet state.

## Batch 8 - Release Gate

Ticket: `LDG-2574`
Status: Completed

Goal: verify and close v0.1.9.1 after all implementation, documentation, and
release-surface tickets are done.

Exit criteria:

- All prior tickets are completed or explicitly re-routed.
- Targeted cost, timing, identity, run-store, sweep, and docs checks pass.
- Full tests, package build, and R CMD check pass or have accepted gate
  disposition.
- Batch 2 migration semantics have shipped before any v0.1.9.1 tag:
  `cost_model` is required, legacy `fill_model` shapes are rejected, legacy
  stored configs are rejected, and `ledgr_backtest()` has the same
  `timing_model` plus `cost_model` contract as `ledgr_experiment()`.
- `vignettes/research-to-production.qmd` (and the rendered `.md`) reflect
  the v0.1.9.1 cost-API surface: required `cost_model`, `ledgr_cost_zero()`
  zero-cost route, `timing_model` replacing `fill_model`, and the
  quoted-spread convention. No remaining `fill_model` or
  `commission_fixed` references.
- Release closeout records the result and v0.1.9.2 can start from a stable
  cost-identity surface.

Closeout:

- All v0.1.9.1 implementation, documentation, metadata, and release-surface
  tickets are completed.
- Targeted cost, timing, identity, run-store, sweep, and documentation-contract
  checks passed.
- Full Windows source tests passed with one expected Yahoo optional-package
  skip.
- A focused WSL schema/persistence gate passed after removing stale compiled
  objects left by the Windows/WSL toolchain switch.
- `vignettes/research-to-production.qmd` and every edited vignette rendered
  through the local Quarto executable.
- Plain `R CMD build .` still hits the established Quarto multi-format product
  issue; the accepted release build path, `R CMD build --no-build-vignettes .`,
  passed with the existing long-path warnings.
- `R CMD check --no-manual --no-build-vignettes ledgr_0.1.9.1.tar.gz` passed
  with the expected no-vignettes warnings and existing long-path note.
- `tools/check-coverage.R` passed at 85.55% coverage.
- `pkgdown::build_site()` passed after the cost API reference index was updated.
