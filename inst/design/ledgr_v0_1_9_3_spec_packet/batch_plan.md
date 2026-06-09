# ledgr v0.1.9.3 Batch Plan

**Status:** Batch 2 implementation ready for Claude review.

This batch plan sequences the v0.1.9.3 target-risk packet without expanding
scope beyond `v0_1_9_3_spec.md` and the accepted
`rfc_chainable_risk_oms_policy_boundary_synthesis.md`. The packet deliberately
separates behavior-preserving phased-pulse substrate work from public risk-step
behavior so execution changes remain attributable.

## Review Protocol

Each implementation batch stops after local verification and asks for Claude
review. The branch is not committed before review. After review, maintainer
disposition decides whether to patch, commit, and move to the next batch.

If a batch requires a broad diff outside its listed tickets, stop before
expanding scope and write a short disposition note. Small mechanical follow-on
edits are acceptable when they are directly required by the batch exit
criteria.

No batch may add arbitrary risk callbacks, affordability enforcement,
liquidity/capacity policy, OMS behavior, walk-forward implementation,
`failure_type` schema columns, portfolio optimization, or compiled-core
architecture work.

## Batch 0 - Packet Review And Batch Plan Alignment

Ticket: `LDG-2597`
Status: Completed

Goal: finalize the packet cut and review `v0_1_9_3_spec.md`,
`v0_1_9_3_tickets.md`, `tickets.yml`, `README.md`, and this batch plan as one
aligned planning surface.

Exit criteria:

- Spec, tickets, YAML, README, and batch plan agree on scope, IDs,
  dependencies, statuses, and release gates.
- Claude review findings against the ticket cut and batch plan are patched or
  explicitly accepted by maintainer decision.
- Existing decision-time price/equity surfaces needed by
  `ledgr_risk_max_weight()` are confirmed. If unavailable, `LDG-2604` is
  deferred and dependent tests/docs/gates are trimmed before Batch 1 starts.
- Roadmap, horizon, design index, and AGENTS identify v0.1.9.3 as the active
  packet where appropriate.
- The spec-cut amendments remain bound: affordability enforcement deferred,
  `sweep_schema_version = 2`, no `failure_type` column, all `risk_plan_json`
  byte-stable, and future risk-context obligation carried forward.

Review focus:

- The batch boundaries follow the ticket dependency graph.
- The first implementation batch starts from public object validation and
  identity, not fold-core mutation.
- The phased-pulse batch is no-op parity only.
- Affordability enforcement and failure-schema work remain deferred.

Closeout notes:

- Claude ticket-cut and batch-plan review had no blockers. Minor observations
  were patched before implementation started: LDG-2602 depends on LDG-2600,
  LDG-2609 depends on LDG-2606 and LDG-2607, LDG-2610 includes
  `contracts.md`, LDG-2611 release-gate evidence mirrors YAML, and LDG-2606
  binds `risk_plan_json` to byte-equivalent canonical-JSON round-trip parity.
- The max-weight pre-check passed. Current strategy contexts expose
  decision-time equity through `ctx$equity` and decision-time prices through
  `ctx$vec$close` or `ctx$close(id)`, matching the existing
  `target_rebalance()` helper contract.
- Roadmap, design index, AGENTS, spec, tickets, YAML, README, and batch plan
  now identify v0.1.9.3 as the active target-risk packet.

## Batch 1 - Risk Object Surface And Identity Floor

Tickets: `LDG-2598`, `LDG-2599`
Status: Completed

Goal: add classed risk constructors, risk-plan compilation, and stable risk
identity before any fold execution behavior changes.

Exit criteria:

- `ledgr_risk_chain()`, `ledgr_risk_none()`, `ledgr_risk_long_only()`, and
  `ledgr_risk_max_weight()` exist and validate inputs.
- Arbitrary user functions and unknown risk objects are rejected.
- Risk objects compile to worker-safe plan value objects.
- `risk_chain_hash` and `risk_plan_json` are deterministic and byte-stable.
- Omitted, `NULL`, and explicit no-op risk normalize to the same no-op plan.
- Parameter references use existing candidate params rather than a new
  `risk_params` layer.

Review focus:

- Constructor objects do not perform execution or data access.
- Risk identity mirrors the v0.1.9.1 cost identity pattern without copying cost
  semantics.
- Durable identity contains no closures, mutable environments, DB handles,
  external pointers, or active bindings.

Implementation notes:

- Added inert classed risk objects for `none`, `long_only`, `max_weight`, and
  ordered chains, plus a print method, Rd page, and export lock updates.
- Added internal plan compilation, canonical `risk_plan_json`,
  `risk_chain_hash`, no-op normalization, and plan reconstruction helpers.
- `ledgr_param()` references in `max_weight` compile to JSON-safe
  `{kind: "param_ref", name: ...}` records; fixed scalar values compile to
  `{kind: "value", value: ...}`.
- Batch 1 deliberately does not wire risk identity into experiment config,
  fold execution, sweep persistence, or promotion context; those remain for
  later batches.
- Claude review found no blockers. The recommended identity-byte patch was
  applied before commit: compiled step payloads now omit the in-memory
  `version` field so durable hash bytes match the spec's listed components.

## Batch 2 - Experiment Config And Reopen Compatibility

Ticket: `LDG-2600`
Status: Completed

Goal: thread no-op-normalized risk identity through experiment config,
`config_hash`, and stored-run reopen compatibility.

Exit criteria:

- `ledgr_experiment()` accepts `risk_chain = ledgr_risk_none()`.
- Modern run config stores `risk_chain_hash` and `risk_plan_json`.
- Modern `config_hash` includes normalized risk identity.
- Pre-v0.1.9.3 no-risk configs reopen through the compatibility normalizer.
- Historical stored rows and hashes are not rewritten.
- Metric context, cost identity, and risk identity remain separate.

Review focus:

- The default no-risk behavior is unchanged except for modern identity fields.
- Reopen compatibility is reopen-time/compare-time normalization, not a hidden
  migration.
- No legacy risk shape is introduced.

Implementation notes:

- Added `risk_chain = ledgr_risk_none()` to `ledgr_experiment()` and
  `ledgr_backtest()`, with no-op normalization through the Batch 1 risk
  helpers.
- Added `risk_chain_hash` and `risk_plan_json` to modern `ledgr_config()`
  payloads under `config$risk_chain`, mirroring the cost identity placement.
- `config_hash()` normalizes missing risk identity to the no-op plan before
  hashing, so pre-v0.1.9.3 no-risk configs compare as modern no-op risk
  configs without rewriting stored historical JSON.
- `ledgr_run_open()` normalizes missing risk fields in memory after reading
  stored `config_json`; the stored bytes remain unchanged.
- Validation now fail-closes on malformed or mismatched risk identity.
- Claude Batch 2 review had no blockers. The optional identity orthogonality
  recommendation was added before commit: cost-only and risk-only changes each
  move `config_hash`.

## Batch 3 - Phased-Pulse No-Op Parity Substrate

Ticket: `LDG-2601`
Status: Completed

Goal: restructure the per-pulse fill path into a private pulse plan while
`ledgr_risk_none()` is the only behavior, proving parity before target-changing
risk steps are enabled.

Exit criteria:

- The fold builds all deltas, timing proposals, and cost-resolved fill intents
  before emitting pulse events or mutating state.
- The pulse plan is private and ephemeral; events remain canonical evidence.
- The reserved net-feasibility hook exists only as a no-op.
- Reference workloads produce the same canonical events, fills, trades,
  equity, retained returns, and metrics as before.
- Same-pulse rebalancing tests prove the new substrate is independent of
  instrument iteration order and does not introduce sequential cash rejection.

Review focus:

- This batch is behavior-preserving with no-op risk.
- No public risk-step behavior is activated here.
- No affordability enforcement, buy scaling, warning-only feasibility feature,
  liquidity policy, or OMS behavior slips in.

Implementation notes:

- Added a private `ledgr_pulse_plan` substrate in `R/fold-engine.R` that builds
  cost-resolved fill intents for a pulse before event emission or state
  mutation.
- Added the reserved `ledgr_fold_apply_net_feasibility_noop()` hook as a
  private pass-through; no affordability enforcement or quantity mutation is
  active in this batch.
- The canonical R and compiled spot-FIFO paths now consume the same private
  pulse-plan fill intents after planning completes.
- Added `tests/testthat/test-risk-fold.R` with a resolver/write-order
  regression proving same-pulse fill resolution happens before any fill event
  write.
- Claude Batch 3 review had no blockers. Follow-up confirmed the v1
  `fill_context` carries only `execution_bar`, not mid-pulse cash, positions,
  or equity. The review noted the telemetry attribution shift from
  per-instrument proposal-build time toward `t_fill`; document that in
  Batch 9 rather than preserving the old attribution artifact.

## Batch 4 - Risk-Chain Fold Integration

Ticket: `LDG-2602`
Status: Completed

Goal: insert compiled risk plans at the reserved fold-core target-risk slot and
validate post-risk targets before timing and cost resolution.

Exit criteria:

- Risk plans resolve once per candidate fold.
- The chain runs after strategy target validation and before fill timing.
- Post-risk targets are validated with distinguishable risk-validation
  conditions.
- Risk steps see decision-time context only.
- Final-bar no-fill behavior remains unchanged.
- Run and sweep paths share the same risk-enabled fold core.

Review focus:

- The chain preserves the accepted `targets -> targets` contract.
- Risk steps cannot inspect execution-bar data, cost outputs, retained returns,
  rankings, or future folds.
- The net-feasibility hook remains no-op.

Implementation notes:

- Compiled risk plans are built once at run / sweep candidate setup and passed
  through the shared `ledgr_execution_spec()` into the fold core.
- The fold now applies the compiled risk plan after strategy target validation
  and before timing proposals, cost resolution, or event writes.
- Batch 4 keeps non-no-op risk steps fail-closed with
  `ledgr_risk_step_not_implemented`; Batch 5 owns the actual long-only and
  max-weight target transforms.
- Added `ledgr_invalid_post_risk_targets` so post-risk target failures are
  distinguishable from raw strategy target-validation failures.
- Deep compiled-plan validation rejects malformed worker/spec payloads before
  fold entry.

## Batch 5 - Built-In Risk Steps

Tickets: `LDG-2603`, `LDG-2604`
Status: Completed

Goal: implement the minimum public adapter set: long-only and max-weight.

Exit criteria:

- `ledgr_risk_long_only()` behaves deterministically and preserves full target
  shape.
- `ledgr_risk_max_weight()` uses only existing decision-time price/equity
  surfaces.
- If max-weight lacks sufficient decision-time state, the adapter is narrowed
  or deferred rather than inventing a risk-specific context.
- Fixed and parameterized risk-step values produce stable identity.
- Run and sweep tests cover both steps.

Review focus:

- Long-only does not imply broker-grade shorting or margin semantics.
- Max-weight is a target transform, not portfolio optimization.
- Built-in steps do not introduce liquidity, costs, ranking, or order policy.

Implementation notes:

- Added built-in risk-step application for `long_only` and `max_weight` in the
  Batch 4 fold slot.
- `long_only` maps negative target quantities to zero and preserves the full
  named target vector.
- `max_weight` caps absolute target exposure using decision-time equity and
  decision-time close prices from `ctx$vec$close` or `ctx$close(id)`.
- `max_weight` fails closed only when a nonzero target requires a missing,
  non-finite, or non-positive decision price; zero targets do not require a
  price.
- In-memory sweep candidate execution now carries the experiment risk chain so
  parameterized risk steps affect candidate outputs; sweep risk identity and
  candidate failure metadata remain Batch 6 scope.
- No affordability, liquidity, OMS, risk-specific public context, failure
  schema, persistence, promotion, or compiled-path changes are included.

## Batch 6 - Sweep Risk Identity And Candidate Failures

Ticket: `LDG-2605`
Status: Completed

Goal: thread risk identity into in-memory sweep candidates and represent risk
failures through condition classes and existing failure fields.

Exit criteria:

- Risk-enabled sweep rows carry stable `risk_chain_hash`.
- Candidate provenance carries `risk_plan_json`.
- `stop_on_error = FALSE` records risk failures as failed candidates.
- Row order, seed derivation, warning/error association, and candidate
  extraction remain stable.
- No schema-level `failure_type` column is added.

Review focus:

- Risk identity is candidate evidence, not a ranking or selection surface.
- Failure handling stays compatible with the existing sweep row contract.
- Condition classes are precise enough for users and tests.

Implementation notes:

- Added visible in-memory `risk_chain_hash` to sweep candidate rows.
- Added `risk_chain_hash` and `risk_plan_json` to row-level sweep provenance
  for success rows, feature-resolution failure rows, and execution/risk
  failure rows.
- Risk construction/application failures now flow through existing
  `error_class` / `error_msg` candidate fields under `stop_on_error = FALSE`;
  `stop_on_error = TRUE` still rethrows the original classed condition.
- Preserved grid row order, seed derivation, and warning/error association.
- No `failure_type` column, saved-sweep schema v2, promotion provenance,
  persistence-layer risk columns, or compiled-path changes are included.

## Batch 7 - Saved Sweep Schema v2 And Promotion Provenance

Tickets: `LDG-2606`, `LDG-2607`
Status: Completed

Goal: persist risk identity in saved sweeps and promotion context while
preserving v0.1.9.2 schema-1 reopen compatibility.

Exit criteria:

- Saved sweeps write `sweep_schema_version = 2`.
- `sweeps` and `sweep_candidates` store `risk_chain_hash` and
  `risk_plan_json`.
- `risk_plan_json` round-trips through canonical JSON.
- v0.1.9.2 schema-1 saved sweeps reopen through no-op risk normalization or
  fail closed when ambiguous.
- `ledgr_promote()` re-executes with the selected candidate's risk chain.
- Promotion context records risk identity and reopened-candidate risk
  provenance.

Review focus:

- Schema v2 remains compact and does not retain full per-candidate ledgers,
  fills, trades, or per-instrument artifacts.
- Promotion still re-executes from reproduction identity.
- Saved-sweep risk fields satisfy the v0.1.9.4 walk-forward handoff.

Implementation notes:

- Bumped saved-sweep schema version to 2 and added compact parent/candidate
  risk identity columns.
- Reopen normalizes schema-1 saved sweeps to no-op risk identity while schema-2
  artifacts fail closed on missing or mismatched risk bytes.
- Promotion reconstructs the selected candidate risk plan before re-executing
  and records risk identity in promotion-context JSON.

## Batch 8 - Parallel And Compiled Safety

Ticket: `LDG-2608`
Status: Completed

Goal: verify risk plans are safe for parallel candidate dispatch and compiled /
memory-backed sweep paths either preserve parity or fail closed.

Exit criteria:

- Risk plans serialize into worker payloads as plain value objects.
- Parallel sweep row order, warnings, errors, and seeds remain deterministic.
- Workers do not perform durable risk writes.
- Compiled spot-FIFO / memory-backed paths preserve risk parity or fail closed
  for risk-enabled sweeps.
- Unsupported combinations fail before producing misleading candidate rows.

Review focus:

- No second execution engine is introduced.
- Worker setup reconstructs plans from package code, candidate params, and plan
  JSON only.
- Compiled paths never silently skip risk.

Implementation notes:

- Added PSOCK-safe risk value-object coverage over the sweep experiment payload.
- Added parallel sweep parity coverage for parameterized risk identity,
  deterministic row order, and reproduction keys.
- Added compiled spot-FIFO parity coverage for risk-enabled sweeps and retained
  the unsupported-model fail-closed assertion.

## Batch 9 - Documentation And Release Surfaces

Tickets: `LDG-2609`, `LDG-2610`
Status: Completed

Goal: update user-facing documentation, examples, NEWS, and planning surfaces
after the implementation surface is stable.

Exit criteria:

- Risk-chain help pages and examples are runnable.
- Docs explain target risk versus target construction, timing, cost,
  liquidity, and OMS.
- Docs name `risk_chain_hash` and `risk_plan_json` as execution identity.
- Docs explain that the first `ledgr_sweep_save()` against a v0.1.9.2 store
  performs an additive saved-sweep schema migration for risk identity columns.
- Docs explicitly avoid portfolio optimization, broker-grade risk, margin,
  shorting, liquidity/capacity, OMS, and automatic selection claims.
- `inst/design/contracts.md` records the new public risk API surface, risk
  identity fields, saved-sweep schema v2 risk placement, and affordability
  deferral.
- Roadmap, design index, AGENTS, NEWS, DESCRIPTION, and generated docs are
  updated as applicable.

Review focus:

- Documentation follows the existing styleguide and does not overclaim.
- The release surface reflects the narrowed spec, especially affordability
  deferral and no `failure_type` column.
- Horizon entries remain parked unless explicitly promoted.

Implementation notes:

- Expanded risk constructor and identity documentation for the public risk
  boundary, `risk_chain_hash`, and `risk_plan_json`.
- Updated README, strategy, sweep, metrics/accounting, and
  research-to-production articles for target-risk scope, saved-sweep risk
  identity, affordability deferral, and non-scope language.
- Added v0.1.9.3 NEWS and bumped package metadata to `0.1.9.3`.
- Updated `contracts.md` and AGENTS planning context for target-risk identity,
  saved-sweep schema v2 risk placement, and Batch 9 review state.

## Batch 10 - Release Gate

Ticket: `LDG-2611`
Status: Completed

Goal: run the full release gate from the release CI playbook and prepare the
branch for merge/tag.

Exit criteria:

- The release CI playbook is read into context before running the gate.
- Targeted risk tests pass.
- Full local tests pass.
- README cold-start check passes.
- Coverage check passes.
- Package build and `R CMD check --no-manual --no-build-vignettes` pass.
- pkgdown build passes if docs/reference pages changed.
- Branch CI, PR CI, main CI after merge, and tag/release CI are green.
- Release closeout records commands, CI status, tag, and accepted caveats.

Review focus:

- The release gate verifies readiness; it does not absorb broad migration work.
- Any broad executable-doc/example drift pauses the gate and becomes a reviewed
  pre-release batch.
- Local and remote evidence is sufficient to merge and tag.
