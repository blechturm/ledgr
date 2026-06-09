# ledgr v0.1.9.3 Tickets

Version: v0.1.9.3
Date: 2026-06-09
Total Tickets: 15

## Ticket Organization

This packet implements the scoped v0.1.9.3 plan from `v0_1_9_3_spec.md`:
the target-risk boundary, behavior-preserving phased-pulse substrate, classed
risk-chain API, deterministic risk identity, saved-sweep schema v2 risk fields,
promotion/reopen compatibility, and release-gate evidence.

Ticket IDs start at `LDG-2597` because `LDG-2581` through `LDG-2596` were used
by the v0.1.9.2 packet.

The release spine is:

```text
packet alignment
  -> risk object and identity foundation
     -> phased-pulse no-op parity substrate
        -> risk-chain fold integration
           -> built-in risk steps
              -> sweep / saved-sweep / promotion identity
                 -> parallel and compiled safety
                    -> docs and release surfaces
                       -> release gate
```

## Dependency DAG

```text
LDG-2597 Packet Alignment And v0.1.9.3 Ticket Cut
  |-- LDG-2598 Risk Object Constructors And Validation
  |     `-- LDG-2599 Risk Plan Compilation And Identity
  |           |-- LDG-2600 Experiment Config And Reopen Compatibility
  |           |-- LDG-2601 Phased-Pulse No-Op Parity Substrate
  |           |     `-- LDG-2602 Risk-Chain Fold Integration And Post-Risk Validation
  |           |           ^ also depends on LDG-2600 config wiring
  |           |           |-- LDG-2603 Long-Only Risk Step
  |           |           |-- LDG-2604 Max-Weight Risk Step
  |           |           `-- LDG-2605 Sweep Risk Identity And Candidate Failures
  |           |                 |-- LDG-2606 Saved Sweep Schema v2 Risk Fields
  |           |                 |     `-- LDG-2607 Promotion And Reopened-Candidate Risk Provenance
  |           |                 `-- LDG-2608 Parallel And Compiled-Path Risk Safety
  |-- LDG-2609 Documentation, Examples, And NEWS
  |-- LDG-2610 Release Surfaces And Planning Docs
  `-- LDG-2611 v0.1.9.3 Release Gate
```

`LDG-2609` depends on the public API and identity tickets before final examples
are locked. `LDG-2611` depends on every prior implementation, test,
documentation, and release-surface ticket in this packet.

## Priority Levels

- P0: packet alignment, public API, execution parity, identity correctness,
  persistence schema, release-gate tests, or release gate.
- P1: documentation, examples, release surface updates, or CI/release evidence
  required by the spec.
- P2: small polish that improves reviewability without changing scope.

---

## LDG-2597: Packet Alignment And v0.1.9.3 Ticket Cut

Priority: P0
Effort: S
Dependencies: none
Status: Completed

### Description

Finalize the v0.1.9.3 planning packet after spec review and cut the human
ticket list, machine-readable ticket YAML, and batch plan before implementation
starts.

### Tasks

- Keep `v0_1_9_3_spec.md`, `v0_1_9_3_tickets.md`, `tickets.yml`,
  `batch_plan.md`, and `README.md` synchronized.
- Confirm the packet opens from
  `rfc_chainable_risk_oms_policy_boundary_synthesis.md`.
- Confirm the spec amendments from the first Claude review are reflected:
  affordability enforcement deferred, `sweep_schema_version = 2`,
  no `failure_type` column, all `risk_plan_json` byte-stable, and future
  risk-context obligation carried forward.
- Confirm the current strategy context exposes the decision-time price and
  equity surfaces needed by `ledgr_risk_max_weight()`. If either surface is
  missing, record the maintainer disposition, defer `LDG-2604` before Batch 1
  starts, and trim dependent tests/docs/gates rather than discovering the
  deferral mid-implementation.
- Submit the packet cut and batch plan for Claude review before Batch 1 starts.

### Acceptance Criteria

- Spec, ticket markdown, YAML, README, and batch plan agree on IDs,
  dependencies, priorities, statuses, and scope.
- No ticket authorizes arbitrary risk callbacks, affordability enforcement,
  liquidity/capacity, OMS, walk-forward, failure-schema columns, target-helper
  expansion, or compiled-core expansion.
- Review prompt is written and sent before implementation begins.

### Verification

Manual packet review, YAML review, batch-plan review, ASCII check, stale
reference `rg` checks, and Claude packet-cut review.

Closeout: Claude packet-cut review had no blockers. Minor dependency,
canonical-JSON, release-gate, and `contracts.md` observations were patched.
The max-weight pre-check confirmed decision-time equity via `ctx$equity` and
decision-time prices via `ctx$vec$close` or `ctx$close(id)`, so `LDG-2604`
remains in scope.

### Source Reference

- `v0_1_9_3_spec.md`
- `inst/design/rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md`
- `inst/design/ledgr_roadmap.md`
- `inst/design/horizon.md`

### Classification

```yaml
type: governance
surface: design_packet
scope: v0.1.9.3
```

---

## LDG-2598: Risk Object Constructors And Validation

Priority: P0
Effort: M
Dependencies: LDG-2597
Status: Pending

### Description

Add the classed public risk-object surface without connecting it to fold
execution yet.

### Tasks

- Implement `ledgr_risk_chain(...)`.
- Implement `ledgr_risk_none()`.
- Implement `ledgr_risk_long_only()`.
- Implement `ledgr_risk_max_weight(max_weight)`.
- Reject arbitrary user-supplied functions and unknown objects.
- Validate constructor arguments with classed errors.
- Add exports and focused constructor tests.

### Acceptance Criteria

- Public constructors return classed, printable, serializable ledgr risk
  objects.
- `ledgr_risk_chain()` accepts only classed ledgr risk steps.
- Invalid `max_weight` values fail before execution.
- No constructor performs execution, persistence, ranking, cost estimation, or
  data access.

### Verification

Constructor tests, invalid-input tests, export tests, print/str smoke tests, and
classed-condition tests.

### Source Reference

- `v0_1_9_3_spec.md` Sections 3 and 4
- Chainable-risk synthesis Sections 2 and 6

### Classification

```yaml
type: public_api
surface: target_risk
scope: risk_constructors
```

---

## LDG-2599: Risk Plan Compilation And Identity

Priority: P0
Effort: L
Dependencies: LDG-2598
Status: Pending

### Description

Compile public risk objects into worker-safe plans and derive deterministic
`risk_chain_hash` and byte-stable `risk_plan_json`.

### Tasks

- Add internal risk-plan compilation from classed risk objects.
- Serialize compiled plans with canonical JSON.
- Derive `risk_chain_hash` from the canonical plan.
- Normalize omitted, `NULL`, and `ledgr_risk_none()` to the same no-op plan.
- Support `ledgr_param("name")` references in risk-step arguments where
  parameter-grid semantics already exist.
- Add reconstruction helpers for plan JSON.

### Acceptance Criteria

- All compiled `risk_plan_json` values are byte-stable across reconstruction.
- `risk_chain_hash` is deterministic across sessions for equivalent plans.
- No-op risk identity is stable and shared across omitted, `NULL`, and
  explicit `ledgr_risk_none()`.
- Plans are plain serializable value objects with no DB connections, external
  pointers, active bindings, mutable environments, or closures in durable
  identity.

### Verification

Canonical JSON tests, hash stability tests, no-op normalization tests,
parameter-reference tests, reconstruction parity tests, and serialization
structure tests.

### Source Reference

- `v0_1_9_3_spec.md` Sections 3, 5, and 8
- Cost-API synthesis Section 6 identity precedent

### Classification

```yaml
type: identity
surface: target_risk
scope: risk_plan_hash_and_json
```

---

## LDG-2600: Experiment Config And Reopen Compatibility

Priority: P0
Effort: M
Dependencies: LDG-2599
Status: Pending

### Description

Thread risk-chain identity through experiment configuration, config hashes, and
stored-run reopen compatibility without rewriting historical rows.

### Tasks

- Add `risk_chain = ledgr_risk_none()` to the experiment configuration surface.
- Store `risk_chain_hash` and `risk_plan_json` in committed run config /
  provenance where cost identity is already stored.
- Include normalized risk identity in modern `config_hash`.
- Add reopen-time compatibility normalization for pre-v0.1.9.3 configs with no
  risk fields.
- Preserve historical stored rows while making modern comparison see old
  no-risk configs as no-op risk configs.

### Acceptance Criteria

- Default no-risk experiments preserve existing execution behavior.
- Modern configs include risk identity in `config_hash`.
- Old no-risk runs reopen through the compatibility normalizer.
- Reopen does not mutate historical config JSON or stored historical hashes.
- Risk identity remains distinct from metric context and cost identity.

### Verification

Config hash tests, experiment constructor tests, stored-run reopen tests,
legacy/no-risk compatibility tests, and identity orthogonality tests.

### Source Reference

- `v0_1_9_3_spec.md` Section 5
- `inst/design/contracts.md` config and canonical JSON contracts

### Classification

```yaml
type: identity
surface: experiment_config
scope: risk_identity_reopen_compatibility
```

---

## LDG-2601: Phased-Pulse No-Op Parity Substrate

Priority: P0
Effort: XL
Dependencies: LDG-2599
Status: Pending

### Description

Restructure the fold's per-pulse fill path into a pulse-level plan while
`ledgr_risk_none()` is the only active behavior, proving no-op parity before
risk steps change targets.

### Tasks

- Introduce a private ephemeral pulse-plan value object.
- Plan all target deltas before emitting events or mutating state.
- Build timing proposals and resolved fill intents as batch pulse data.
- Keep the reserved net-feasibility hook as a no-op.
- Emit events and apply cash/position/lot/state changes atomically after the
  pulse plan is complete.
- Preserve final-bar no-fill behavior.

### Acceptance Criteria

- No-op risk execution produces the same canonical event stream as the old loop
  on reference workloads.
- Run and sweep summaries remain equivalent for deterministic strategies.
- The pulse plan is private and ephemeral; no new persisted artifact is added.
- No affordability enforcement, private cash gate, silent buy scaling, or
  sequential per-instrument rejection is introduced.

### Verification

Reference parity tests, event-stream tests, run/sweep parity tests, final-bar
no-fill tests, retained-return parity tests, and same-pulse rebalancing
order-independence tests.

### Source Reference

- `v0_1_9_3_spec.md` Sections 1 and 6
- Horizon phased-pulse and affordability entries

### Classification

```yaml
type: execution
surface: fold_core
scope: phased_pulse_noop_parity
```

---

## LDG-2602: Risk-Chain Fold Integration And Post-Risk Validation

Priority: P0
Effort: L
Dependencies: LDG-2600, LDG-2601
Status: Pending

### Description

Insert the compiled risk plan between strategy target validation and fill
timing, then validate the post-risk target vector before any proposals, costs,
or events are produced.

### Tasks

- Resolve the risk plan once per candidate fold.
- Apply risk steps after strategy target validation.
- Validate post-risk targets with a distinguishable risk-validation condition.
- Ensure risk steps see decision-time context only.
- Ensure final-bar no-fill still produces no proposals or risk/cost artifacts
  beyond validated targets.
- Preserve the no-op net-feasibility hook as no-op.

### Acceptance Criteria

- Risk is inserted at the reserved fold-core target-risk slot.
- Post-risk validation catches malformed outputs before fill timing.
- Risk steps cannot inspect execution-bar data, retained returns, candidate
  rankings, future folds, or cost outputs.
- `ledgr_run()` and `ledgr_sweep()` share the same risk-enabled fold core.

### Verification

Fold-integration tests, post-risk-validation tests, no-lookahead tests,
final-bar tests, and run/sweep parity tests.

### Source Reference

- `v0_1_9_3_spec.md` Sections 1, 4, and 6
- Chainable-risk synthesis Section 2

### Classification

```yaml
type: execution
surface: fold_core
scope: risk_chain_slot_and_validation
```

---

## LDG-2603: Long-Only Risk Step

Priority: P0
Effort: M
Dependencies: LDG-2602
Status: Pending

### Description

Implement `ledgr_risk_long_only()` as the first built-in target-risk step.

### Tasks

- Apply long-only behavior deterministically to complete target vectors.
- Preserve names and universe order.
- Validate output through the post-risk validator.
- Record stable risk identity for chains containing the step.
- Add run and sweep tests.

### Acceptance Criteria

- Negative target quantities are transformed or rejected exactly as specified
  by the final implementation ticket.
- The step never creates missing, extra, duplicate, unnamed, or non-finite
  targets.
- The step does not imply short-selling support, broker margin semantics, or
  liquidity policy.

### Verification

Risk-step behavior tests, post-risk-validation tests, identity tests, run/sweep
tests, and documentation examples.

### Source Reference

- `v0_1_9_3_spec.md` Section 4
- Chainable-risk synthesis minimum adapter set

### Classification

```yaml
type: execution
surface: target_risk
scope: long_only_step
```

---

## LDG-2604: Max-Weight Risk Step

Priority: P0
Effort: L
Dependencies: LDG-2602
Status: Pending

### Description

Implement `ledgr_risk_max_weight(max_weight)` if the existing decision-time
price/equity surfaces are sufficient. If they are not sufficient, narrow or
defer the adapter rather than inventing a public risk-specific context.

### Tasks

- Confirm the available decision-time equity and price surfaces.
- Implement deterministic target capping from those surfaces.
- Validate `max_weight` and parameterized `max_weight` values.
- Preserve target names and universe order.
- Add run/sweep tests over fixed and parameterized values.

### Acceptance Criteria

- The step uses decision-time information only.
- The cap is deterministic and identity-bearing.
- Parameterized `max_weight` values participate through existing candidate
  params, not a separate `risk_params` layer.
- If the required decision-time surfaces are missing, the ticket records a
  reviewed deferral instead of adding an ad hoc context.

### Verification

Decision-time-surface tests, cap behavior tests, parameterized-risk tests,
identity tests, no-lookahead tests, and run/sweep parity tests.

### Source Reference

- `v0_1_9_3_spec.md` Sections 3, 4, and 15
- Chainable-risk synthesis minimum adapter set

### Classification

```yaml
type: execution
surface: target_risk
scope: max_weight_step
```

---

## LDG-2605: Sweep Risk Identity And Candidate Failures

Priority: P0
Effort: L
Dependencies: LDG-2602, LDG-2603, LDG-2604
Status: Pending

### Description

Thread risk identity through in-memory sweep candidate rows and represent
risk-chain failures through classed errors and existing candidate failure
fields.

### Tasks

- Add `risk_chain_hash` to visible sweep candidate identity where appropriate.
- Carry `risk_plan_json` in candidate provenance.
- Ensure `stop_on_error = FALSE` records risk construction/application failures
  as candidate failures.
- Add risk-specific condition classes.
- Do not add a schema-level `failure_type` column.
- Preserve row order, warning association, and seed derivation.

### Acceptance Criteria

- Risk-enabled sweeps produce candidate rows with stable risk identity.
- Risk failures are inspectable through `error_class` and `error_msg`.
- No `failure_type` column is added in v0.1.9.3.
- Risk steps do not rank, choose, promote, or otherwise alter candidate
  selection.

### Verification

Sweep identity tests, stop-on-error tests, classed-condition tests,
warning/error association tests, seed determinism tests, and stale-schema
searches for `failure_type`.

### Source Reference

- `v0_1_9_3_spec.md` Sections 7 and 9
- Chainable-risk synthesis Sections 3 and 4

### Classification

```yaml
type: sweep
surface: sweep_candidate_identity
scope: risk_identity_and_failures
```

---

## LDG-2606: Saved Sweep Schema v2 Risk Fields

Priority: P0
Effort: L
Dependencies: LDG-2605
Status: Pending

### Description

Extend saved-sweep persistence to schema version 2 with risk identity on
`sweeps` and `sweep_candidates`, plus schema-1 reopen normalization.

### Tasks

- Bump saved sweeps to `sweep_schema_version = 2`.
- Add `risk_chain_hash` and `risk_plan_json` to `sweeps`.
- Add `risk_chain_hash` and `risk_plan_json` to `sweep_candidates`.
- Store `risk_plan_json` through the v0.1.9.2 canonical-JSON
  byte-equivalent round-trip rule for `*_json` columns.
- Reopen v0.1.9.2 schema-1 saved sweeps through no-op risk normalization.
- Fail closed when schema-1 normalization is ambiguous.

### Acceptance Criteria

- New saved sweeps persist risk identity on parent and candidate tables.
- `risk_plan_json` round-trips byte-equivalently.
- Schema-1 saved sweeps reopen with no-op risk identity or fail closed through
  the existing schema-incompatibility path.
- Saved sweeps do not store full ledgers, fills, trades, or per-instrument
  artifacts for every candidate.

### Verification

Schema tests, canonical JSON tests, schema-version tests, v0.1.9.2 fixture
reopen tests, DB round-trip tests, and fail-closed incompatibility tests.

### Source Reference

- `v0_1_9_3_spec.md` Section 7
- v0.1.9.2 sweep persistence synthesis Section 6

### Classification

```yaml
type: persistence
surface: saved_sweep_schema
scope: risk_identity_schema_v2
```

---

## LDG-2607: Promotion And Reopened-Candidate Risk Provenance

Priority: P0
Effort: M
Dependencies: LDG-2606
Status: Pending

### Description

Ensure `ledgr_promote()` re-executes selected candidates with their risk chain
and records risk provenance, including reopened-sweep candidates.

### Tasks

- Pass selected candidate risk plans into `ledgr_run()`.
- Store `risk_chain_hash` and `risk_plan_json` in promotion context.
- Verify reopened-sweep candidates preserve risk plan JSON through promotion.
- Confirm promotion still re-executes rather than committing stored sweep rows.

### Acceptance Criteria

- Promoted runs reproduce the selected candidate's risk chain.
- Promotion context records risk identity alongside source sweep/candidate
  identity.
- Reopened saved sweeps can promote risk-enabled candidates.
- Promotion does not treat scalar rows or retained returns as committed runs.

### Verification

Promotion tests, reopened-sweep promotion tests, provenance JSON round-trip
tests, risk identity comparison tests, and candidate extraction tests.

### Source Reference

- `v0_1_9_3_spec.md` Section 7
- `inst/design/contracts.md` sweep promotion contract

### Classification

```yaml
type: promotion
surface: ledgr_promote
scope: risk_provenance
```

---

## LDG-2608: Parallel And Compiled-Path Risk Safety

Priority: P0
Effort: L
Dependencies: LDG-2605
Status: Pending

### Description

Verify risk plans are worker-safe and that compiled/accounting shortcuts either
preserve risk parity or fail closed for risk-enabled sweeps.

### Tasks

- Serialize risk plans through sequential and parallel sweep candidate payloads.
- Verify worker reconstruction uses package code, candidate params, and plan
  JSON only.
- Add tests for PSOCK-safe value-object shape.
- Test memory-backed / compiled spot-FIFO sweep behavior with risk.
- Fail closed when a compiled/accounting path cannot preserve risk parity.

### Acceptance Criteria

- Parallel sweep result row order, warnings, errors, and seeds remain
  deterministic.
- Workers do not write durable risk artifacts.
- Compiled spot-FIFO / memory-backed paths do not silently skip or reinterpret
  risk.
- Unsupported compiled/accounting combinations fail before producing misleading
  candidate rows.

### Verification

Parallel sweep tests, serialization tests, worker-safe plan tests, compiled
spot-FIFO parity or fail-closed tests, and seed/order determinism tests.

### Source Reference

- `v0_1_9_3_spec.md` Sections 8 and 10
- v0.1.8.8 parallel dispatch contracts
- v0.1.8.10 compiled accounting contract

### Classification

```yaml
type: execution
surface: parallel_and_compiled_sweep
scope: risk_plan_safety
```

---

## LDG-2609: Documentation, Examples, And NEWS

Priority: P1
Effort: L
Dependencies: LDG-2598, LDG-2599, LDG-2603, LDG-2604, LDG-2605, LDG-2606, LDG-2607
Status: Pending

### Description

Document the target-risk boundary, public risk constructors, identity fields,
and explicit non-scope without implying portfolio optimization, liquidity,
OMS, margin, or broker-grade risk controls.

### Tasks

- Add risk-chain help pages and runnable examples.
- Document `ledgr_risk_long_only()` and `ledgr_risk_max_weight()`.
- Update execution / accounting / sweep docs for risk versus timing versus
  cost versus liquidity.
- Update identity docs for `risk_chain_hash` and `risk_plan_json`.
- Add NEWS entry.
- Keep examples small, deterministic, and snapshot-backed.

### Acceptance Criteria

- Docs teach target risk as target-vector transformation.
- Docs state affordability enforcement, liquidity, OMS, shorting, margin, and
  portfolio optimization are out of scope.
- Sweep docs explain risk identity in candidates and saved sweeps.
- Examples run under local checks.

### Verification

Documentation review, roxygen examples, README/example cold-start checks where
affected, pkgdown build where affected, and stale-claim searches.

### Source Reference

- `v0_1_9_3_spec.md` Section 11
- `inst/design/vignette_styleguide.md`

### Classification

```yaml
type: documentation
surface: user_docs
scope: target_risk_docs
```

---

## LDG-2610: Release Surfaces And Planning Docs

Priority: P1
Effort: M
Dependencies: LDG-2597, LDG-2609
Status: Pending

### Description

Keep planning surfaces and release metadata aligned with v0.1.9.3 scope.

### Tasks

- Update `inst/design/README.md` if needed.
- Update `inst/design/ledgr_roadmap.md` at closeout.
- Update `inst/design/contracts.md` for the new public risk API surface, risk
  identity fields, saved-sweep schema v2 risk placement, and affordability
  deferral.
- Update `AGENTS.md` current planning context at closeout.
- Update `DESCRIPTION`, `NEWS.md`, and pkgdown/reference surfaces as required.
- Confirm horizon entries are either consumed, deferred, or left parked with
  clear non-commitment.

### Acceptance Criteria

- Planning docs identify v0.1.9.3 as active during implementation and complete
  at closeout.
- No horizon parking-lot item is accidentally promoted to roadmap commitment.
- Release metadata and generated docs agree with the implemented public API.

### Verification

Planning-doc review, stale-reference searches, metadata review, pkgdown build
where affected, and Claude review before release gate.

### Source Reference

- `v0_1_9_3_spec.md`
- `inst/design/ledgr_roadmap.md`
- `inst/design/horizon.md`

### Classification

```yaml
type: governance
surface: release_surfaces
scope: planning_and_metadata
```

---

## LDG-2611: v0.1.9.3 Release Gate

Priority: P0
Effort: M
Dependencies: LDG-2597, LDG-2598, LDG-2599, LDG-2600, LDG-2601, LDG-2602, LDG-2603, LDG-2604, LDG-2605, LDG-2606, LDG-2607, LDG-2608, LDG-2609, LDG-2610
Status: Pending

### Description

Run the v0.1.9.3 release gate using the release CI playbook and record compact
evidence before merge/tag.

### Tasks

- Read and cite `inst/design/release_ci_playbook.md` before starting the gate.
- Run targeted target-risk tests.
- Run full local tests.
- Run README cold-start check.
- Run coverage check.
- Build package and run `R CMD check --no-manual --no-build-vignettes`.
- Build pkgdown if docs/reference pages changed.
- Push branch and verify remote CI.
- Merge, tag, and verify tag/release CI per the playbook.

### Acceptance Criteria

- Local and remote release gates pass.
- The release gate does not absorb broad API/example migration work.
- Release closeout records commands, CI status, tag, and any accepted caveats.
- `v0.1.9.3` is merged and tagged only after green gates.

### Verification

Release CI playbook checklist, targeted risk test output,
`testthat::test_local()` output, README cold-start log, coverage report,
`R CMD check` output, pkgdown build log if affected, GitHub CI checks for
branch/PR/main/tag, and release closeout file.

### Source Reference

- `v0_1_9_3_spec.md` Section 13
- `inst/design/release_ci_playbook.md`
- `inst/design/contracts.md` release validation contract

### Classification

```yaml
type: release
surface: release_gate
scope: v0.1.9.3
```
