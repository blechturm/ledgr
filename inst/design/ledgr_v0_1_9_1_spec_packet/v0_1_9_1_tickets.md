# ledgr v0.1.9.1 Tickets

Version: v0.1.9.1
Date: 2026-06-05
Total Tickets: 28

## Ticket Organization

This packet implements the scoped v0.1.9.1 plan from
`v0_1_9_1_spec.md`: public transaction-cost objects, explicit timing
models, cost identity, migration away from legacy `fill_model`, THEME-004
identity hardening, bounded auditr documentation fixes, and release-surface
housekeeping.

Ticket IDs start at `LDG-2547` because `LDG-2527` through `LDG-2546` were used
by the v0.1.8.11 packet.

The release spine is:

```text
packet alignment
  -> cost object surface
     -> timing and identity surface
        -> fold resolver wiring
           -> internal migration
              -> identity hardening
                 -> identity documentation
                    -> auditr remainder docs
                       -> release surfaces
                          -> release gate
```

## Dependency DAG

```text
LDG-2547 Packet Alignment And v0.1.9.1 Ticket Cut
  |-- LDG-2548 Cost Primitive Constructors
  |     `-- LDG-2549 Cost Composition And Validation
  |           |-- LDG-2551 Cost Identity Surface
  |           |     |-- LDG-2552 Cost Inspection Helpers
  |           |     |-- LDG-2553 Cost Resolver Wiring
  |           |     |-- LDG-2557 ledgr_backtest Public Surface Migration
  |           |     `-- LDG-2558 Required Cost Model On Experiment
  |           `-- LDG-2550 Timing Constructor And Experiment Surface
  |                 |-- LDG-2555 Timing Model Internal Migration
  |                 |     `-- LDG-2556 Reopen Path Legacy Config Rejection
  |                 `-- LDG-2557 ledgr_backtest Public Surface Migration
  |-- LDG-2554 Internal Fee Field Rename
  |-- LDG-2559 config_hash Store-Path Independence
  |     `-- LDG-2560 config_hash Alias Declaration-Order Independence
  |-- LDG-2561 alias_map_hash Parameter Independence
  |-- LDG-2564 DISCLAIMER.md Install Path Fix
  |-- LDG-2566 LEDGR_LAST_BAR_NO_FILL Help Topic
  |-- LDG-2569 Sweep Vignette Cost Non-Participation Note
  |-- LDG-2562 feature_set_hash Run Surface Exposure
  |     `-- LDG-2563 Identity Contract Reference And contracts.md Update
  |-- LDG-2565 Cost Condition Class Documentation
  |-- LDG-2567 Metrics And Accounting Vignette Cost Rewrite
  |-- LDG-2568 Cost API Runnable Examples
  |-- LDG-2570 NEWS Entry
  |     |-- LDG-2571 Roadmap Update
  |     |-- LDG-2572 Horizon Housekeeping
  |     `-- LDG-2573 Design And RFC Index Update
  `-- LDG-2574 v0.1.9.1 Release Gate
```

`LDG-2574` depends on every prior ticket in this packet.

## Priority Levels

- P0: packet alignment, public cost API, identity correctness, release gate,
  or HIGH-severity auditr finding.
- P1: required internal migration, identity documentation, or bounded
  medium-severity auditr follow-up.
- P2: release-surface housekeeping or small documentation polish.

---

## LDG-2547: Packet Alignment And v0.1.9.1 Ticket Cut

Priority: P0
Effort: S
Dependencies: none
Status: Completed

### Description

Finalize the v0.1.9.1 planning packet after Codex spec review and cut the
ticket markdown, machine-readable ticket YAML, and batch plan before
implementation starts.

### Tasks

- Patch accepted Codex review findings into `v0_1_9_1_spec.md`.
- Keep `v0_1_9_1_spec.md`, `v0_1_9_1_tickets.md`, `tickets.yml`, and
  `batch_plan.md` synchronized.
- Confirm the packet preserves cost-API synthesis authority and does not
  authorize target-risk, walk-forward, or sweep artifact persistence work.
- Confirm the contracts.md question is resolved as a bounded identity-contract
  update, not a broad contract rewrite.
- Submit the ticket cut for review before Batch 1 starts.

### Acceptance Criteria

- Spec, tickets, YAML, and batch plan agree on IDs, dependencies, priorities,
  statuses, and scope.
- No implementation ticket is missing an acceptance or verification path.
- All previous Codex blocker findings are patched or explicitly accepted.

### Verification

Manual packet review, YAML review, ASCII check, `git diff --check`, and
review-response audit.

### Completion Note (2026-06-05)

Codex rechecked the patched v0.1.9.1 spec, resolved the remaining contracts.md
review question as bounded scope under LDG-2563, and cut `LDG-2547` through
`LDG-2574` plus `tickets.yml` and `batch_plan.md`.

### Source Reference

- `v0_1_9_1_spec.md`
- `codex_spec_review.md`
- `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md`
- `inst/design/horizon.md`

### Classification

```yaml
type: governance
surface: design_packet
scope: v0.1.9.1
```

---

## LDG-2548: Cost Primitive Constructors

Priority: P0
Effort: M
Dependencies: LDG-2547
Status: Planned

### Description

Implement the public cost primitive constructors accepted by the transaction
cost API synthesis.

### Tasks

- Implement `ledgr_cost_spread_bps(bps)`.
- Implement `ledgr_cost_fixed_fee(amount)`.
- Implement `ledgr_cost_notional_bps_fee(bps)`.
- Implement `ledgr_cost_zero()`.
- Validate scalar numeric arguments with classed, actionable errors.
- Bind quoted-spread semantics for `ledgr_cost_spread_bps()`:
  BUY uses `open * (1 + spread_bps / 20000)` and SELL uses
  `open * (1 - spread_bps / 20000)`.

### Acceptance Criteria

- Each constructor returns a classed ledgr cost object with stable type id,
  schema version, and fixed arguments.
- Invalid inputs fail loudly before fold entry.
- Quoted-spread semantics are covered by unit tests.
- No user-supplied cost functions are accepted.

### Verification

Cost constructor tests, invalid-input tests, quoted-spread arithmetic oracle,
and roxygen examples.

### Source Reference

- `v0_1_9_1_spec.md`
- `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md`

### Classification

```yaml
type: public_api
surface: transaction_cost_model
scope: cost_primitives
```

---

## LDG-2549: Cost Composition And Validation

Priority: P0
Effort: M
Dependencies: LDG-2548
Status: Planned

### Description

Implement `ledgr_cost_chain(...)` and construction-time order validation for
cost model composition.

### Tasks

- Implement `ledgr_cost_chain(...)` for ordered ledgr cost objects.
- Validate that price transforms precede fee adders.
- Raise `ledgr_invalid_cost_chain_order` when fee adders precede price
  transforms.
- Preserve child step order in the model object and canonical identity payload.

### Acceptance Criteria

- Valid cost chains preserve user-specified step order.
- Invalid chains fail at construction time, not during execution.
- Validation rejects non-ledgr cost objects.
- Chain identity is deterministic across sessions.

### Verification

Composition tests, classed error tests, deterministic identity fixture, and
roxygen examples.

### Source Reference

- `v0_1_9_1_spec.md`
- `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md`

### Classification

```yaml
type: public_api
surface: transaction_cost_model
scope: cost_chain_validation
```

---

## LDG-2550: Timing Constructor And Experiment Surface

Priority: P0
Effort: M
Dependencies: LDG-2548
Status: Planned

### Description

Implement `ledgr_timing_next_open()` and add the public `timing_model` argument
to `ledgr_experiment()`.

### Tasks

- Implement `ledgr_timing_next_open()`.
- Add `timing_model` to `ledgr_experiment()`.
- Make `timing_model` default to `ledgr_timing_next_open()`.
- Reject legacy `fill_model = list(...)` input with
  `ledgr_legacy_fill_model_shape`.
- Update roxygen and examples to teach timing-vs-cost separation.

### Acceptance Criteria

- `ledgr_experiment()` accepts the new timing constructor.
- Legacy `fill_model` input fails loudly with the bound condition class.
- Existing next-open execution semantics are unchanged.
- Tests prove no same-bar fill regression.

### Verification

Experiment-constructor tests, legacy-shape rejection tests, next-open timing
tests, and documentation render.

### Source Reference

- `v0_1_9_1_spec.md`
- `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md`

### Classification

```yaml
type: public_api
surface: timing_model
scope: next_open_constructor
```

---

## LDG-2551: Cost Identity Surface

Priority: P0
Effort: L
Dependencies: LDG-2549
Status: Planned

### Description

Implement deterministic cost identity and canonical cost-plan serialization.

### Tasks

- Implement `cost_model_hash` per synthesis Section 6.2.
- Implement `cost_plan_json` as canonical worker-safe plan JSON.
- Ensure hash composition includes schema version, type id, fixed arguments,
  ordered child steps, child type ids, and child versions.
- Forbid memory addresses, R environment serialization, object print output,
  and package load order from the hash payload.
- Persist `cost_model_hash` and `cost_plan_json` on run config and promotion
  provenance.
- Keep cost identity orthogonal to `metric_context_hash`.

### Acceptance Criteria

- Two identical cost models produce identical hashes across sessions.
- Different cost model content produces different hashes.
- `cost_plan_json` reconstructs the execution plan without closures or
  environment serialization.
- Run config, run info, sweep candidate, and promotion provenance expose the
  bound fields where applicable.

### Verification

Hash fixture tests, cross-session tests, plan reconstruction tests,
promotion-provenance tests, and sweep candidate identity tests.

### Source Reference

- `v0_1_9_1_spec.md`
- `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md`

### Classification

```yaml
type: identity
surface: transaction_cost_model
scope: cost_model_hash_and_plan_json
```

---

## LDG-2552: Cost Inspection Helpers

Priority: P1
Effort: S
Dependencies: LDG-2551
Status: Planned

### Description

Implement public inspection helpers for cost model objects.

### Tasks

- Implement `ledgr_cost_steps(cost_model)`.
- Implement `ledgr_cost_describe(cost_model)`.
- Ensure helpers expose stable, user-readable structure without leaking
  private implementation details.
- Document examples for primitive and chained models.

### Acceptance Criteria

- Helpers return deterministic output for identical cost models.
- Helpers work for primitives, zero-cost, and chains.
- Invalid inputs fail clearly.
- Examples are runnable.

### Verification

Inspection helper tests, snapshot-style expected-output tests, invalid-input
tests, and roxygen examples.

### Source Reference

- `v0_1_9_1_spec.md`
- `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md`

### Classification

```yaml
type: public_api
surface: transaction_cost_model
scope: inspection_helpers
```

---

## LDG-2553: Cost Resolver Wiring

Priority: P0
Effort: L
Dependencies: LDG-2550, LDG-2551
Status: Planned

### Description

Wire compiled cost plans into the existing proposal / resolver seam without
creating a second execution path or changing fold control flow.

### Tasks

- Compile cost models into worker-safe plans consumed by
  `ledgr_resolve_fill_proposal()`.
- Apply price transforms and explicit fee adders at the existing fill proposal
  boundary.
- Preserve quantity, side, instrument, and execution timestamp.
- Keep sequential run and sweep execution on the same fold core.
- Add parity tests for direct run, sweep candidate execution, and promotion.

### Acceptance Criteria

- Cost application changes only fill price and fee fields.
- No fold-control-flow branch or second execution engine is introduced.
- Sweep candidate execution and direct runs agree for the same cost model.
- Promotion preserves and materializes cost identity.

### Verification

Run parity tests, sweep parity tests, promotion parity tests, hand-checkable
cost arithmetic fixtures, and no-lookahead timing tests.

### Source Reference

- `v0_1_9_1_spec.md`
- `inst/design/contracts.md`
- `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md`

### Classification

```yaml
type: execution
surface: fold_resolver
scope: cost_plan_application
```

---

## LDG-2554: Internal Fee Field Rename

Priority: P0
Effort: M
Dependencies: LDG-2547
Status: Planned

### Description

Rename the internal and emitted fixed commission field from
`commission_fixed` to `fee` at the fill payload and accounting surfaces.

### Tasks

- Update `ledgr_fill_event_payload()` cash-delta computation to consume and
  emit `fee`.
- Update fill-model machinery, output handlers, and lot accounting.
- Remove `commission_fixed` from new config and event payload paths.
- Keep the ledger schema's existing `fee` field as canonical.
- Update tests that assert fill row shape, cash delta, and meta payloads.

### Acceptance Criteria

- Fill rows expose `fee`, not `commission_fixed`, as the public field.
- Cash-delta math is unchanged except for the field rename.
- Existing accounting identities continue to pass.
- Legacy stored shapes are handled only by the explicit reopen rejection ticket.

### Verification

Fill payload tests, cash identity tests, round-trip P&L tests, sweep parity
tests, and durable readback tests.

### Source Reference

- `v0_1_9_1_spec.md`
- `R/backtest-runner.R`

### Classification

```yaml
type: internal_migration
surface: fills_and_accounting
scope: fee_field_rename
```

---

## LDG-2555: Timing Model Internal Migration

Priority: P0
Effort: L
Dependencies: LDG-2550, LDG-2554
Status: Planned

### Description

Migrate internal config, validation, runner, store, and documentation paths
from `fill_model` to `timing_model`.

### Tasks

- Update `R/experiment.R`, `R/config-validate.R`, `R/backtest.R`,
  `R/backtest-runner.R`, and `R/run-store.R`.
- Rename required config fields and reopen config readers.
- Update internal helpers and tests.
- Update roxygen and package documentation references.
- Remove stale "fill_model" language except where documenting legacy rejection.

### Acceptance Criteria

- New runs persist `timing_model`, not `fill_model`.
- New configs validate without legacy field names.
- Search confirms only legacy-rejection documentation mentions `fill_model`.
- Existing next-open execution behavior remains unchanged.

### Verification

Config validation tests, runner tests, run-store tests, stale-scope `rg`
checks, and documentation render.

### Source Reference

- `v0_1_9_1_spec.md`
- `R/experiment.R`
- `R/config-validate.R`
- `R/backtest.R`
- `R/backtest-runner.R`
- `R/run-store.R`

### Classification

```yaml
type: internal_migration
surface: config_and_run_store
scope: timing_model_rename
```

---

## LDG-2556: Reopen Path Legacy Config Rejection

Priority: P0
Effort: M
Dependencies: LDG-2555
Status: Planned

### Description

Make `ledgr_run_open()` reject stored legacy `fill_model` configs with the
bound classed condition.

### Tasks

- Detect stored `config_json` containing legacy `fill_model`.
- Raise `ledgr_legacy_config_shape`.
- Message users to recreate the experiment under v0.1.9.1.
- Avoid translation, warning-only behavior, or silent compatibility.
- Add a stored-config fixture covering the legacy shape.

### Acceptance Criteria

- Legacy config reopen fails before replay or result access.
- Error class is stable and documented.
- New v0.1.9.1 configs reopen normally.
- Stored-artifact breakage is named in NEWS.

### Verification

Run-open tests, legacy config fixture, classed error test, and NEWS review.

### Source Reference

- `v0_1_9_1_spec.md`
- `R/run-store.R`

### Classification

```yaml
type: compatibility_boundary
surface: run_reopen
scope: legacy_fill_model_rejection
```

---

## LDG-2557: ledgr_backtest Public Surface Migration

Priority: P0
Effort: L
Dependencies: LDG-2550, LDG-2551, LDG-2558
Status: Planned

### Description

Migrate exported `ledgr_backtest()` to the same `timing_model` and
`cost_model` argument contract as `ledgr_experiment()`.

### Tasks

- Replace `fill_model = NULL` with `timing_model` and required `cost_model`.
- Remove `ledgr_fill_model_instant()` from the exported surface.
- Replace internal use with explicit `ledgr_timing_next_open()`.
- Reject legacy `fill_model = ...` with `ledgr_legacy_fill_model_shape`.
- Reject missing `cost_model` with `ledgr_cost_model_unspecified`.
- Update roxygen, print methods, examples, and tests.

### Acceptance Criteria

- `ledgr_backtest()` and `ledgr_experiment()` have symmetric public cost/timing
  behavior.
- Legacy input fails loudly with the same condition class as experiment
  construction.
- Missing `cost_model` fails loudly.
- Identity parity with equivalent `ledgr_experiment()` + `ledgr_run()` is
  proven.

### Verification

Backtest wrapper tests, public API examples, identity parity tests, legacy
input error tests, and roxygen render.

### Source Reference

- `v0_1_9_1_spec.md`
- `R/backtest.R`
- `tests/testthat/test-backtest-wrapper.R`

### Classification

```yaml
type: public_api
surface: ledgr_backtest
scope: cost_timing_contract
```

---

## LDG-2558: Required Cost Model On Experiment

Priority: P0
Effort: M
Dependencies: LDG-2550, LDG-2551
Status: Planned

### Description

Require explicit `cost_model` on `ledgr_experiment()` and fail loudly when it
is omitted.

### Tasks

- Add required `cost_model` to `ledgr_experiment()`.
- Raise `ledgr_cost_model_unspecified` when omitted or NULL.
- Point users at `ledgr_cost_zero()` for explicit zero-cost behavior.
- Ensure config identity includes cost fields only after a valid cost model is
  supplied.

### Acceptance Criteria

- No implicit zero-cost default exists.
- `ledgr_cost_zero()` is the documented explicit zero-cost route.
- Missing cost model fails at construction time.
- Error class is documented by LDG-2565.

### Verification

Experiment-constructor tests, classed error tests, identity field tests, and
examples.

### Source Reference

- `v0_1_9_1_spec.md`
- `R/experiment.R`

### Classification

```yaml
type: public_api
surface: ledgr_experiment
scope: required_cost_model
```

---

## LDG-2559: config_hash Store-Path Independence

Priority: P0
Effort: M
Dependencies: LDG-2547
Status: Planned

### Description

Remove storage-location fields from the `config_hash` canonical payload and
cover the auditr episode 043 store-path delta.

### Tasks

- Remove `db_path` from the canonical config-hash payload.
- Remove `snapshot_db_path` from the canonical config-hash payload.
- Evaluate explicit `run_id` exclusion as a precautionary scope item and
  document the rationale.
- Add regression coverage matching auditr episode 043 FB-002.
- Preserve intentional identity fields.

### Acceptance Criteria

- Identical logical configs with different DuckDB paths produce identical
  `config_hash`.
- Snapshot identity and data identity remain part of the hash where intended.
- Auto-generated fallback `run_id` remains outside the hash.
- Any explicit `run_id` handling is documented in the identity contract.

### Verification

Config-hash fixture tests, cross-path regression test, run-info checks, and
identity-contract documentation review.

### Source Reference

- `v0_1_9_1_spec.md`
- `categorized_feedback.yml`
- `R/config-hash.R`
- `R/backtest.R`
- `R/run-store.R`

### Classification

```yaml
type: identity
surface: config_hash
scope: store_path_independence
```

---

## LDG-2560: config_hash Alias Declaration-Order Independence

Priority: P0
Effort: M
Dependencies: LDG-2559
Status: Planned

### Description

Make `config_hash` invariant to alias declaration-order permutations while
preserving intentional feature identity.

### Tasks

- Identify where alias declaration order enters the config canonical payload.
- Normalize or omit order-only fields that should not affect `config_hash`.
- Preserve order where it is an explicit user-facing diagnostic, not identity.
- Add regression coverage for auditr episode 037 FB-003.

### Acceptance Criteria

- Alias maps with the same semantic aliases in different declaration order
  produce identical `config_hash`.
- `alias_map_order` can still be exposed as diagnostic metadata if needed.
- `alias_map_hash` and `feature_set_hash` semantics remain documented.

### Verification

Alias-order regression tests, config-hash fixtures, feature identity tests, and
identity-contract documentation review.

### Source Reference

- `v0_1_9_1_spec.md`
- `categorized_feedback.yml`
- `R/feature-alias-map.R`
- `R/config-canonical-json.R`
- `R/config-hash.R`

### Classification

```yaml
type: identity
surface: config_hash
scope: alias_order_independence
```

---

## LDG-2561: alias_map_hash Parameter Independence

Priority: P0
Effort: M
Dependencies: LDG-2547
Status: Planned

### Description

Remove concrete feature parameter values from `alias_map_hash`; concrete
feature identity belongs in `feature_set_hash`.

### Tasks

- Inspect current alias map canonicalization.
- Remove concrete parameter values from `alias_map_hash` payload.
- Ensure `feature_set_hash` still changes when concrete feature parameters
  change.
- Add regression coverage for auditr episode 037 FB-004.

### Acceptance Criteria

- The same alias declaration with different concrete feature parameter values
  has stable `alias_map_hash`.
- `feature_set_hash` remains parameter-sensitive.
- Documentation explains the layering distinction.

### Verification

Alias hash tests, feature-set hash tests, auditr regression fixture, and
identity-contract documentation review.

### Source Reference

- `v0_1_9_1_spec.md`
- `categorized_feedback.yml`
- `R/feature-alias-map.R`
- `R/precompute-features.R`

### Classification

```yaml
type: identity
surface: alias_map_hash
scope: parameter_independence
```

---

## LDG-2562: feature_set_hash Run Surface Exposure

Priority: P0
Effort: M
Dependencies: LDG-2559, LDG-2560, LDG-2561
Status: Planned

### Description

Expose `feature_set_hash` on documented run surfaces to close auditr episode
037 FB-001.

### Tasks

- Add `feature_set_hash` to `bt$config$features` or an equivalent accessor.
- Add `feature_set_hash` to `ledgr_run_info()`.
- Add `feature_set_hash` to `ledgr_run_list()`.
- Update help pages explaining the field.
- Add tests for in-session and reopened runs.

### Acceptance Criteria

- Users can inspect `feature_set_hash` without private object traversal.
- Run info and run list expose the same value for the same run.
- Reopen path preserves the value.
- Documentation distinguishes it from `feature_params_hash` and alias fields.

### Verification

Run-info tests, run-list tests, reopened-run tests, documentation examples, and
auditr regression review.

### Source Reference

- `v0_1_9_1_spec.md`
- `categorized_feedback.yml`
- `R/run-store.R`
- `R/results.R`

### Classification

```yaml
type: identity
surface: run_metadata
scope: feature_set_hash_exposure
```

---

## LDG-2563: Identity Contract Reference And contracts.md Update

Priority: P0
Effort: L
Dependencies: LDG-2551, LDG-2562
Status: Planned

### Description

Author the user-facing and maintainer-facing identity contract reference,
including a bounded `contracts.md` update for the new public cost API and
identity fields.

### Tasks

- Document `feature_set_hash`, `feature_params_hash`, `alias_map_hash`,
  `alias_map_json`, `alias_map_order`, `config_hash`, `cost_model_hash`, and
  `cost_plan_json`.
- For each field, document purpose, canonical-payload recipe, source surface,
  and related-field distinction.
- Cross-reference from `?ledgr_run`, `?ledgr_run_info`, `?ledgr_sweep`,
  `?ledgr_promote`, cost constructor help, and relevant vignettes.
- Add a bounded `inst/design/contracts.md` update for `timing_model`,
  required `cost_model`, cost identity, and legacy config rejection.
- Avoid a broad contracts.md structure pass.

### Acceptance Criteria

- Identity reference exists as a help topic and design/manual reference.
- Public help pages link to the reference.
- `contracts.md` names the new public contract without unrelated rewrites.
- Hash field semantics are aligned with tests from LDG-2559 through LDG-2562.

### Verification

Documentation render, help topic examples, link checks, contracts.md review,
and identity regression test review.

### Source Reference

- `v0_1_9_1_spec.md`
- `inst/design/contracts.md`
- `inst/design/manual/`
- `man/`

### Classification

```yaml
type: documentation
surface: identity_contract
scope: hash_reference_and_contracts_update
```

---

## LDG-2564: DISCLAIMER.md Install Path Fix

Priority: P0
Effort: S
Dependencies: LDG-2547
Status: Planned

### Description

Fix the HIGH-severity installed disclaimer link breakage from auditr episode
046 FB-001.

### Tasks

- Either install `DISCLAIMER.md` at the package path used by the vignette or
  update the vignette to point at an installed help/article surface carrying
  the same formal disclaimer.
- Re-run the failing auditr episode workflow or an equivalent local check.
- Keep FB-002 through FB-004 optional unless the chosen fix naturally covers
  them.

### Acceptance Criteria

- The installed package exposes the formal disclaimer at the documented link.
- The research-workflow vignette no longer points at a missing file.
- The fix works from an installed package, not only from the source checkout.

### Verification

Installed-path check, vignette link check, package build/install smoke, and
auditr episode 046 reproduction or equivalent.

### Source Reference

- `v0_1_9_1_spec.md`
- `categorized_feedback.yml`
- `DISCLAIMER.md`
- `vignettes/articles/research-workflow.qmd`

### Classification

```yaml
type: documentation
surface: disclaimer
scope: installed_link_fix
```

---

## LDG-2565: Cost Condition Class Documentation

Priority: P1
Effort: M
Dependencies: LDG-2549, LDG-2556, LDG-2558
Status: Planned

### Description

Document new v0.1.9.1 cost and legacy-shape condition classes.

### Tasks

- Add help topics for `ledgr_legacy_fill_model_shape`.
- Add help topic for `ledgr_legacy_config_shape`.
- Add help topic for `ledgr_cost_model_unspecified`.
- Add help topic for `ledgr_invalid_cost_chain_order`.
- Add help topic for `ledgr_invalid_cost_model`.
- Add help topic for `ledgr_invalid_timing_model`.
- Include minimal fail-closed examples and actionable message contracts.

### Acceptance Criteria

- Each new condition class has a discoverable help topic.
- Users can assert on top-level stable classes in tests.
- Examples run and fail in the documented way.
- Messages do not suggest legacy translation or deprecation behavior.

### Verification

Condition documentation tests where practical, roxygen render, example checks,
and error-class tests from implementation tickets.

### Source Reference

- `v0_1_9_1_spec.md`
- `categorized_feedback.yml`
- `man/`

### Classification

```yaml
type: documentation
surface: condition_classes
scope: cost_api_errors
```

---

## LDG-2566: LEDGR_LAST_BAR_NO_FILL Help Topic

Priority: P1
Effort: S
Dependencies: LDG-2547
Status: Planned

### Description

Add a help topic for the existing `LEDGR_LAST_BAR_NO_FILL` warning code.

### Tasks

- Document when final-bar deltas cannot fill.
- Document the warning code and expected behavior.
- Cross-reference from the execution-semantics vignette.
- Include a minimal example or test fixture reference.

### Acceptance Criteria

- `LEDGR_LAST_BAR_NO_FILL` is discoverable in help.
- Documentation states that no fill is emitted when there is no next bar.
- Existing final-bar no-fill tests remain aligned with the docs.

### Verification

Roxygen render, help-topic link check, final-bar warning tests, and vignette
cross-reference review.

### Source Reference

- `v0_1_9_1_spec.md`
- `categorized_feedback.yml`
- `dev/audit/verification_audit.R`

### Classification

```yaml
type: documentation
surface: execution_warnings
scope: final_bar_no_fill
```

---

## LDG-2567: Metrics And Accounting Vignette Cost Rewrite

Priority: P1
Effort: L
Dependencies: LDG-2553, LDG-2565
Status: Planned

### Description

Rewrite `vignettes/metrics-and-accounting.qmd` to teach the new cost API,
quoted-spread convention, and fail-closed accounting behavior.

### Tasks

- Explain quoted-spread convention and round-trip cost intuition.
- Teach timing-vs-cost separation.
- Teach price-transform-vs-explicit-fee separation.
- Add non-scope bullets for liquidity, financing, TCA, taxes, OMS, and broker
  reconciliation.
- Add a worked round-trip example confirming approximately `spread_bps` total
  round-trip cost.
- Document `compiled_accounting_model` fail-closed behavior and stable
  condition classes.
- Follow `inst/design/vignette_styleguide.md`.

### Acceptance Criteria

- The vignette is accurate for the v0.1.9.1 cost API.
- Examples run or are explicitly non-evaluated for a documented reason.
- Quoted-spread arithmetic is not presented as per-side full spread.
- Fail-closed compiled-accounting behavior is documented without expanding B2
  scope.

### Verification

Vignette render, example smoke tests, accounting test review, and styleguide
review.

### Source Reference

- `v0_1_9_1_spec.md`
- `categorized_feedback.yml`
- `inst/design/vignette_styleguide.md`
- `vignettes/metrics-and-accounting.qmd`

### Classification

```yaml
type: documentation
surface: vignette
scope: metrics_accounting_cost_api
```

---

## LDG-2568: Cost API Runnable Examples

Priority: P1
Effort: M
Dependencies: LDG-2548, LDG-2549, LDG-2550, LDG-2551, LDG-2552
Status: Planned

### Description

Add runnable examples to cost API help pages.

### Tasks

- Add examples for `?ledgr_cost_chain`.
- Add examples for each cost primitive constructor.
- Add examples for `?ledgr_timing_next_open`.
- Add examples for `?ledgr_cost_steps` and `?ledgr_cost_describe`.
- Include construction, chain composition, identity inspection, and the
  `ledgr_cost_model_unspecified` error path.

### Acceptance Criteria

- Cost help pages have runnable examples.
- Examples teach explicit `ledgr_cost_zero()` for zero-cost behavior.
- Examples do not require network, external data, or long-running fixtures.
- Example output is deterministic.

### Verification

Example checks, roxygen render, targeted documentation tests, and R CMD check
examples where applicable.

### Source Reference

- `v0_1_9_1_spec.md`
- `man/`
- `R/`

### Classification

```yaml
type: documentation
surface: examples
scope: cost_api_reference_examples
```

---

## LDG-2569: Sweep Vignette Cost Non-Participation Note

Priority: P1
Effort: S
Dependencies: LDG-2553
Status: Planned

### Description

Document that cost API parameters do not participate in sweep grid composition
in v0.1.9.1.

### Tasks

- Add a paragraph to the sweep vignette.
- State that cost models are fixed experiment inputs in v1, not sweep-grid
  dimensions.
- Reference future `ledgr_cost_grid()` as deferred work.
- Avoid adding sweep artifact persistence or cost-grid API scope.

### Acceptance Criteria

- Sweep docs accurately describe v0.1.9.1 cost behavior.
- Users are not led to expect `ledgr_cost_grid()` in this packet.
- The note cross-references cost identity where helpful.

### Verification

Vignette render, stale-scope review for `ledgr_cost_grid()` claims, and
documentation review.

### Source Reference

- `v0_1_9_1_spec.md`
- `vignettes/sweeps.qmd`
- `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md`

### Classification

```yaml
type: documentation
surface: sweep_vignette
scope: cost_non_participation
```

---

## LDG-2570: NEWS Entry

Priority: P1
Effort: S
Dependencies: LDG-2548, LDG-2549, LDG-2550, LDG-2551, LDG-2553, LDG-2554, LDG-2555, LDG-2556, LDG-2557, LDG-2558, LDG-2559, LDG-2560, LDG-2561, LDG-2562, LDG-2564, LDG-2569
Status: Planned

### Description

Add the v0.1.9.1 NEWS entry.

### Tasks

- Document the public transaction-cost API headline.
- Document breaking changes: `fill_model` to `timing_model`,
  `commission_fixed` to `fee`, and required `cost_model`.
- Document THEME-004 hash fixes and stored-run hash breakage.
- Document disclaimer-link and bounded auditr documentation fixes.

### Acceptance Criteria

- NEWS clearly separates user-facing changes from internal fixes.
- Breaking changes are explicit.
- No v0.1.9.2+ work is claimed as shipped.

### Verification

NEWS review, stale-claim `rg` checks, and release-gate review.

### Source Reference

- `v0_1_9_1_spec.md`
- `NEWS.md`

### Classification

```yaml
type: release_notes
surface: NEWS
scope: v0.1.9.1
```

---

## LDG-2571: Roadmap Update

Priority: P2
Effort: S
Dependencies: LDG-2570
Status: Planned

### Description

Update the roadmap to reflect v0.1.9.1 progress and cost-API ship state.

### Tasks

- Mark v0.1.9.1 as active while implementation is ongoing.
- At close, mark the cost-API spec-cut completed.
- Preserve v0.1.9.2 through v0.1.9.4 sequencing.
- Avoid implying walk-forward, target-risk, or sweep persistence has shipped.

### Acceptance Criteria

- Roadmap state matches ticket status.
- Forward packet sequencing remains intact.
- No stale v0.1.8.11 active-state language remains.

### Verification

Roadmap review and stale-state `rg` checks.

### Source Reference

- `v0_1_9_1_spec.md`
- `inst/design/ledgr_roadmap.md`

### Classification

```yaml
type: planning_docs
surface: roadmap
scope: v0.1.9.1_status
```

---

## LDG-2572: Horizon Housekeeping

Priority: P2
Effort: S
Dependencies: LDG-2570
Status: Planned

### Description

Update horizon entries as v0.1.9.1 implementation closes.

### Tasks

- Move the 2026-06-05 cost-API spec-cut decisions entry to `## Resolved` when
  v0.1.9.1 ships.
- Keep sequencing, walk-forward gate-row obligations, and sweep RFC schedule in
  `## Open`.
- Preserve forward dependency wording for v0.1.9.2 through v0.1.9.4.

### Acceptance Criteria

- Resolved/open horizon state matches actual release state.
- Forward obligations remain visible.
- No v0.1.9.1 ticket claims leak into future packets.

### Verification

Horizon review and targeted `rg` checks for 2026-06-05 entries.

### Source Reference

- `v0_1_9_1_spec.md`
- `inst/design/horizon.md`

### Classification

```yaml
type: planning_docs
surface: horizon
scope: cost_api_resolution_state
```

---

## LDG-2573: Design And RFC Index Update

Priority: P2
Effort: S
Dependencies: LDG-2570
Status: Planned

### Description

Update design and RFC indexes for the v0.1.9.1 cost-API ship state.

### Tasks

- Update `inst/design/README.md` to reflect v0.1.9.1 status.
- Add the identity contract reference to the design index.
- Update `inst/design/rfc/README.md` to mark the cost-API synthesis as
  implemented in v0.1.9.1 after release.
- Keep RFC authority and forward dependencies clear.

### Acceptance Criteria

- Design index points to the current packet and new identity reference.
- RFC index records implementation state after release.
- No forward RFC is marked implemented prematurely.

### Verification

Design index review, RFC index review, link checks, and stale-state `rg`.

### Source Reference

- `v0_1_9_1_spec.md`
- `inst/design/README.md`
- `inst/design/rfc/README.md`

### Classification

```yaml
type: planning_docs
surface: design_index
scope: v0.1.9.1_cost_api
```

---

## LDG-2574: v0.1.9.1 Release Gate

Priority: P0
Effort: M
Dependencies: LDG-2547, LDG-2548, LDG-2549, LDG-2550, LDG-2551, LDG-2552, LDG-2553, LDG-2554, LDG-2555, LDG-2556, LDG-2557, LDG-2558, LDG-2559, LDG-2560, LDG-2561, LDG-2562, LDG-2563, LDG-2564, LDG-2565, LDG-2566, LDG-2567, LDG-2568, LDG-2569, LDG-2570, LDG-2571, LDG-2572, LDG-2573
Status: Planned

### Description

Run the v0.1.9.1 release gate after every implementation and documentation
ticket has closed.

### Tasks

- Confirm all tickets are completed or explicitly deferred with maintainer
  approval.
- Run targeted tests for cost API, timing migration, identity hardening,
  run-store reopen behavior, sweep parity, and documentation examples.
- Run the full test suite.
- Build the package.
- Run R CMD check.
- Verify NEWS, roadmap, horizon, design index, RFC index, and ticket metadata.
- Confirm no generated local artifacts are staged.
- Prepare release closeout notes.

### Acceptance Criteria

- All v0.1.9.1 tickets are closed or explicitly re-routed.
- Full tests and package check pass, or any failure has accepted release-gate
  disposition.
- Cost API synthesis obligations are satisfied.
- THEME-004 and HIGH disclaimer auditr findings are closed.
- v0.1.9.2 can begin from a stable cost-identity surface.

### Verification

Targeted tests, full test suite, package build, R CMD check, documentation
render checks, metadata review, release closeout review, and clean git-status
review.

### Source Reference

- `v0_1_9_1_spec.md`
- `v0_1_9_1_tickets.md`
- `tickets.yml`
- `inst/design/release_ci_playbook.md`

### Classification

```yaml
type: release_gate
surface: release_process
scope: v0.1.9.1
```
