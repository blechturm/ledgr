# ledgr v0.1.8 Tickets

**Version:** 0.1.8
**Date:** May 14, 2026
**Total Tickets:** 14

---

## Ticket Organization

v0.1.8 introduces lightweight sequential sweep mode over the same execution
semantics as `ledgr_run()`. The release extracts a private fold core, separates
execution from output persistence, adds typed sweep inputs and summary outputs,
threads explicit execution seeds, and defines an ergonomic promotion path from
sweep candidate to committed run.

The release is intentionally conservative. It does not add public parallel
sweep, walk-forward analysis, PBO/CSCV diagnostics, public risk-layer APIs,
public cost-model factories, paper/live adapters, intraday semantics, or full
sweep artifact save/load/replay helpers.

Tracks:

1. **Scope baseline:** lock the accepted spec and implementation sequencing.
2. **Execution spine:** extract the private fold core and output-handler
   boundary.
3. **Execution sub-boundaries:** preserve timing/cost separation and public seed
   semantics.
4. **Sweep inputs:** update `ledgr_param_grid()` and add precomputed feature
   support.
5. **Feature factories:** support indicator-parameter sweeps through
   params-aware feature materialization.
6. **Sweep output:** add sequential `ledgr_sweep()` and classed
   `ledgr_sweep_results`.
7. **Promotion identity:** add row-level execution seed/provenance, candidate
   selection, and promotion helpers.
8. **Promotion context:** store durable selection-audit metadata for promoted
   runs.
9. **Parity and docs:** prove semantic parity and teach evaluation discipline.
10. **Release gate:** complete status sync, docs/index sync, NEWS, checks, and
    CI.

### Dependency DAG

```text
LDG-2101 -> LDG-2102 -> LDG-2103 ---------------------.
              |          \                            |
              |           '-> LDG-2104 ---------------+--.
              |                                        |  |
LDG-2101 -> LDG-2105 -> LDG-2106 -> LDG-2107 ----------+  |
              |                                        |  |
              '------------------------------------.   |  |
                                                   v   v  v
                                             LDG-2108 -> LDG-2109
                                                            |
                                                            v
                                                      LDG-2110 -> LDG-2111
                                                            |       |
                                                            v       v
                                                      LDG-2112 -> LDG-2113
                                                            \       /
                                                             v     v
                                                            LDG-2114
```

`LDG-2114` is the v0.1.8 release gate. `LDG-2112` is the semantic parity gate
and must not be deferred into release closeout.

### Priority Levels

- **P0 (Blocker):** Required for execution correctness, parity, or release
  coherence.
- **P1 (Critical):** Required for the v0.1.8 public sweep contract.
- **P2 (Important):** Required for documentation, ergonomics, or future
  maintainability.
- **P3 (Optional):** Useful, but not required for this release.

---

## LDG-2101: Scope Baseline And Ticket Synchronization

**Priority:** P0
**Effort:** 0.5 day
**Dependencies:** None
**Status:** Done

**Description:**
Lock the v0.1.8 implementation scope before runtime work begins. Confirm the
accepted spec, architecture notes, RFC decisions, audit routing, and ticket
metadata are coherent.

**Tasks:**
1. Read `v0_1_8_spec.md`, `contracts.md`, `ledgr_roadmap.md`, and the active
   sweep architecture/UX notes.
2. Confirm the accepted promotion/RNG/cost/parallelism decisions are reflected
   in the spec.
3. Confirm public parallel sweep, walk-forward, PBO/CSCV, risk-layer,
   public cost-model, paper/live, intraday, and full sweep artifact persistence
   remain out of scope.
4. Confirm `v0_1_8_tickets.md` and `tickets.yml` agree on IDs, titles,
   statuses, dependencies, tests, and required context.

**Acceptance Criteria:**
- [x] Active spec, contracts, roadmap, and design index point to v0.1.8.
- [x] Ticket IDs and dependencies match `tickets.yml`.
- [x] All v0.1.8 non-goals are preserved.
- [x] No implementation starts from an unresolved design question.
- [x] No runtime files are changed by this ticket.

**Implementation Notes:**
- Confirmed `inst/design/README.md`, `AGENTS.md`, `docs/AGENTS.md`,
  `contracts.md`, and `ledgr_roadmap.md` point to the active v0.1.8 packet,
  ticket file, and `tickets.yml`.
- Confirmed `v0_1_8_tickets.md` and `tickets.yml` contain the same 14 ticket
  IDs and titles, with valid dependency references and no duplicate IDs.
- Confirmed the active spec carries the accepted RNG, cost-boundary,
  parallelism, candidate-promotion, and promotion-context decisions.
- Confirmed public parallel sweep, walk-forward, PBO/CSCV, public risk-layer
  APIs, public cost-model factories, paper/live adapters, intraday semantics,
  and full sweep artifact persistence remain non-goals or future constraints.
- Scope grep found no active runtime definitions for `ledgr_sweep()`,
  `ledgr_precompute_features()`, `ledgr_snapshot_split()`,
  `ledgr_save_sweep()`, `ledgr_load_sweep()`, `ledgr_walk_forward()`,
  `ledgr_tune()`, `risk_fn`, or public cost-model surfaces.
- Touched only ticket metadata/design documentation for this ticket.

**Verification:**
```text
documentation/routing review
ticket/yml consistency review
scope grep for forbidden public APIs
```

**Source Reference:** v0.1.8 spec sections 0, 1, 2, 9, 12, 13.

**Classification:**
```yaml
risk_level: high
implementation_tier: L
review_tier: M
classification_reason: >
  This ticket freezes the release scope and dependency graph before touching
  the execution engine. A bad baseline would make later code-review results
  hard to interpret.
invariants_at_risk:
  - release scope discipline
  - ticket/status consistency
  - roadmap/spec alignment
required_context:
  - inst/design/ledgr_v0_1_8_spec_packet/v0_1_8_spec.md
  - inst/design/ledgr_v0_1_8_spec_packet/v0_1_8_tickets.md
  - inst/design/ledgr_v0_1_8_spec_packet/tickets.yml
  - inst/design/contracts.md
  - inst/design/ledgr_roadmap.md
tests_required:
  - documentation/routing review
escalation_triggers:
  - a central design doc contradicts the active spec
  - a non-goal is required to satisfy a ticket
  - ticket and YAML metadata cannot be reconciled
forbidden_actions:
  - changing runtime R code
  - implementing sweep APIs
  - changing package version metadata
```

---

## LDG-2102: Private Fold Core And Output Handler Boundary

**Priority:** P0
**Effort:** 2-4 days
**Dependencies:** LDG-2101
**Status:** Done

**Description:**
Extract or define the private shared fold core used by `ledgr_run()` and future
`ledgr_sweep()`. Move persistence/status/telemetry side effects behind output
handler responsibilities without changing current `ledgr_run()` behavior.

**Tasks:**
1. Identify the current per-pulse execution loop and persistence/status
   coupling points.
2. Define a private internal fold function, tentatively `ledgr_run_fold()`.
3. Keep the fold core unexported and absent from pkgdown.
4. Define output-handler responsibilities for persistent `ledgr_run()` output.
5. Route telemetry, status mutation, failure records, and event accumulation
   through output-handler flow rather than hidden side channels.
6. Preserve existing `ledgr_run()` public behavior and result shape.
7. Reserve the future target-risk slot between target validation and fill
   timing as a no-op.

**Acceptance Criteria:**
- [x] `ledgr_run()` executes through the private fold core.
- [x] The fold core is not exported, not in `NAMESPACE`, and not in pkgdown.
- [x] Persistent `ledgr_run()` output is produced through an output handler or
      equivalent internal boundary.
- [x] Strategy preflight occurs before candidate fold execution.
- [x] Tier 3 strategies abort before fold execution or output-handler side
      effects.
- [x] Existing `ledgr_run()` tests continue to pass.
- [x] No public sweep API is required by this ticket.

**Implementation Notes:**
- Added private `ledgr_run_fold()` and routed `ledgr_backtest_run_internal()`
  through it without exporting the fold core.
- Added a private persistent DuckDB output handler for run status, failure
  recording, telemetry persistence, strategy-state writes, and audit-log event
  buffering/flushing.
- Kept strategy preflight in `ledgr_strategy_spec()` before low-level runner
  config construction, preserving Tier 3 abort-before-fold behavior.
- Added an explicit private no-op target-risk slot after target validation and
  before fill timing.
- Added an export-surface assertion that `ledgr_run_fold()` exists internally
  but is not exported.
- Did not add `ledgr_sweep()` or change fill, snapshot, config, or public run
  semantics.

**Verification:**
```text
tests/testthat targeted runner tests
tests/testthat targeted provenance/status/telemetry tests
full testthat recommended before review
```

**Verification Run:**
```text
test-api-exports.R
test-runner.R
test-run-telemetry.R
test-backtest-audit-log-equivalence.R
test-accounting-consistency.R
test-strategy-preflight.R
full testthat suite
```

**Source Reference:** v0.1.8 spec R1, R2, R3, sections 6 and 7.

**Classification:**
```yaml
risk_level: release-critical
implementation_tier: H
review_tier: H
classification_reason: >
  This is the central execution refactor. It touches runner control flow,
  persistence side effects, failure handling, and future sweep parity.
invariants_at_risk:
  - single execution semantics
  - ledger/event meaning
  - telemetry/status correctness
  - Tier 3 preflight rejection
  - no exported fold-core API
required_context:
  - inst/design/ledgr_v0_1_8_spec_packet/v0_1_8_spec.md
  - inst/design/contracts.md
  - inst/design/architecture/ledgr_v0_1_8_sweep_architecture.md
  - inst/design/architecture/sweep_mode_code_review.md
  - R/backtest-runner.R
  - R/backtest.R
tests_required:
  - targeted runner tests
  - targeted telemetry/status/failure tests
escalation_triggers:
  - fold extraction changes ledger event ordering
  - output-handler boundary cannot preserve existing fail_run semantics
  - telemetry side-channel removal requires schema changes
  - existing ledgr_run behavior changes outside documented parity work
forbidden_actions:
  - exporting ledgr_run_fold()
  - adding ledgr_sweep()
  - changing public fill semantics
  - changing snapshot or config identity
```

---

## LDG-2103: Internal Fill Timing And Cost Boundary Preservation

**Priority:** P1
**Effort:** 1-2 days
**Dependencies:** LDG-2102
**Status:** Todo

**Description:**
Preserve the private fill-timing/cost-resolution boundary needed for future cost
models while keeping current scalar `spread_bps` and `commission_fixed`
behavior byte-for-byte compatible.

**Tasks:**
1. Separate next-open timing proposal from cost resolution inside the fold.
2. Introduce or reserve typed internal fill proposal/fill intent shapes.
3. Keep strategy `ctx` decision-time only and separate from fill/execution
   context.
4. Reserve execution-bar OHLCV fields, including volume, without exposing a
   public cost-model API.
5. Prove current fill prices, fees, cash deltas, ledger rows, metrics, and
   `config_hash` stay unchanged.

**Acceptance Criteria:**
- [ ] Current `spread_bps` and `commission_fixed` behavior is unchanged.
- [ ] `config_hash` is byte-identical for unchanged scalar fill config.
- [ ] Output handlers do not compute or reinterpret costs.
- [ ] The fold core does not expose public cost-model factories or exchange fee
      templates.
- [ ] No quantity mutation, liquidity clipping, partial-fill, or
      volume-participation model is added.

**Verification:**
```text
targeted fill/cash-delta tests
config_hash fixture test
comparison metric parity checks
```

**Source Reference:** v0.1.8 spec R5 and sections 6, 11.

**Classification:**
```yaml
risk_level: high
implementation_tier: M
review_tier: H
classification_reason: >
  Cost and timing are load-bearing execution semantics. The ticket must create
  the future boundary without changing present fills or config identity.
invariants_at_risk:
  - fill timing
  - fee/cash delta semantics
  - config_hash stability
  - no-lookahead strategy context
required_context:
  - inst/design/rfc/rfc_cost_model_architecture_response.md
  - inst/design/contracts.md
  - R/backtest-runner.R
tests_required:
  - targeted fill model tests
  - config_hash stability tests
escalation_triggers:
  - existing helper cannot be wrapped without behavior drift
  - config_hash changes for unchanged scalar config
  - execution context would expose next-bar data to strategy ctx
forbidden_actions:
  - exporting cost-model APIs
  - adding broker/exchange fee templates
  - changing spread_bps semantics
  - adding liquidity or quantity mutation behavior
```

---

## LDG-2104: RNG Boundary And Execution Seed Support

**Priority:** P0
**Effort:** 1-2 days
**Dependencies:** LDG-2102
**Status:** Todo

**Description:**
Make execution seeds first-class fold-core inputs. `ledgr_run(seed = integer)`
must work and persist identity. `ledgr_sweep(seed = integer)` will later derive
per-candidate execution seeds before dispatch.

**Tasks:**
1. Remove the current public rejection of non-`NULL` `seed` in `ledgr_run()`.
2. Apply `set.seed(seed)` only at fold entry and only when `seed` is non-`NULL`.
3. Store accepted seed values in execution identity/provenance/config JSON as
   specified.
4. Add deterministic internal `ledgr_derive_seed(base_seed, salt)` using
   canonical JSON/digest-style stable derivation, independent of ambient RNG.
5. Ensure `seed = NULL` causes no fold-entry RNG side effect.
6. Leave user-facing `ctx$seed()` helpers deferred unless explicitly promoted.

**Acceptance Criteria:**
- [ ] `ledgr_run(seed = integer)` executes and stores the seed in run identity.
- [ ] `ledgr_run(seed = NULL)` preserves existing deterministic behavior and
      does not call `set.seed()` at fold entry.
- [ ] `ledgr_derive_seed()` is deterministic across sessions and independent
      of `.Random.seed`.
- [ ] Strategy bodies that call `set.seed()` or `RNGkind()` remain Tier 3.
- [ ] Ambient RNG strategy calls without ledgr seed helpers are not silently
      certified as reproducible.

**Verification:**
```text
targeted seed tests
preflight tests for RNG mutation patterns
config/provenance seed identity tests
```

**Source Reference:** v0.1.8 spec R6 and RNG RFC/response.

**Classification:**
```yaml
risk_level: high
implementation_tier: M
review_tier: H
classification_reason: >
  Seed support changes a previously rejected public argument and becomes part
  of promotion reproducibility. It must not depend on ambient session RNG.
invariants_at_risk:
  - deterministic execution
  - reproducible stochastic promotion
  - run identity
  - RNG preflight semantics
required_context:
  - inst/design/rfc/rfc_rng_contract_v0_1_8.md
  - inst/design/rfc/rfc_rng_contract_v0_1_8_response.md
  - R/backtest.R
  - R/backtest-runner.R
tests_required:
  - targeted seed tests
  - preflight RNG tests
escalation_triggers:
  - seed storage changes config_hash expectations unexpectedly
  - seed derivation cannot be made platform-stable
  - ctx$seed becomes required to satisfy basic promotion parity
forbidden_actions:
  - deriving seeds from .Random.seed
  - using worker/daemon assignment in seed derivation
  - adding public stochastic helper APIs without ticket scope
```

---

## LDG-2105: Parameter Grid Audit And Label Stability

**Priority:** P1
**Effort:** 1 day
**Dependencies:** LDG-2101
**Status:** Todo

**Description:**
Audit and update the existing exported `ledgr_param_grid()` object for sweep
execution. Preserve stable candidate labels and update stale messaging that
still frames sweep execution as unavailable.

**Tasks:**
1. Review `R/param-grid.R` and existing tests.
2. Confirm named labels are preserved verbatim.
3. Confirm unnamed labels use `canonical_json()` and stable SHA-256 short
   hashes.
4. Add duplicate label tests.
5. Update print/help text for v0.1.8 sweep while clarifying grid labels are not
   committed run IDs.
6. Ensure the object structure is suitable for candidate iteration and
   promotion identity.

**Acceptance Criteria:**
- [ ] `ledgr_param_grid()` remains the typed grid object for v0.1.8.
- [ ] Auto labels are stable and based on `canonical_json()`.
- [ ] Duplicate labels error loudly.
- [ ] Print/help text no longer says sweep execution is not exported once sweep
      work lands.
- [ ] No second parameter-grid class is added.

**Verification:**
```text
tests/testthat targeted param-grid tests
documentation contract tests if help text changes
```

**Source Reference:** v0.1.8 spec section 4.1.

**Classification:**
```yaml
risk_level: medium
implementation_tier: M
review_tier: M
classification_reason: >
  Candidate labels become user-facing promotion identity. Instability or
  duplicate handling errors would contaminate sweep outputs and seed derivation.
invariants_at_risk:
  - candidate label stability
  - canonical JSON identity
  - no duplicate candidate labels
required_context:
  - R/param-grid.R
  - R/config-canonical-json.R
  - inst/design/ledgr_v0_1_8_spec_packet/v0_1_8_spec.md
tests_required:
  - targeted param-grid tests
escalation_triggers:
  - existing auto labels are not stable enough for seed derivation
  - grid object structure cannot support promotion metadata
forbidden_actions:
  - adding a second grid constructor/class
  - using deparse() for candidate identity
  - treating grid labels as committed run IDs
```

---

## LDG-2106: Precomputed Feature Object And Warmup Validation

**Priority:** P1
**Effort:** 2-3 days
**Dependencies:** LDG-2102, LDG-2105
**Status:** Todo

**Description:**
Add `ledgr_precompute_features()` and a typed `ledgr_precomputed_features`
object that deduplicates resolved feature work across candidate grids and
validates snapshot, universe, feature, scoring-range, and warmup coverage.

**Tasks:**
1. Define the `ledgr_precomputed_features` object shape.
2. Support concrete feature lists/maps and params-aware feature factories.
3. Resolve and fingerprint the union of all feature definitions required by
   the grid.
4. Store snapshot hash, universe, scoring range, warmup metadata, feature union,
   and feature engine metadata.
5. Validate explicit scoring range separately from warmup lookback range.
6. Warn from `ledgr_sweep()` when grid size exceeds 20 and precomputed features
   are absent.

**Acceptance Criteria:**
- [ ] Concrete feature lists are computed once and reused across candidates.
- [ ] Feature factories are resolved per candidate and deduplicated by
      fingerprint.
- [ ] The object validates snapshot hash, universe, scoring range, and warmup
      coverage.
- [ ] The object covers the union of factory fingerprints across the grid.
- [ ] Static coverage mismatches abort the sweep as contract errors.
- [ ] Candidate-specific warmup infeasibility remains a candidate-level
      failure.

**Verification:**
```text
targeted feature precompute tests
warmup/scoring-range validation tests
snapshot mismatch tests
```

**Source Reference:** v0.1.8 spec sections 4.2, 7, 11.

**Classification:**
```yaml
risk_level: high
implementation_tier: H
review_tier: H
classification_reason: >
  Precomputed features sit on the no-lookahead and warmup boundary. Incorrect
  coverage or fingerprinting would make sweep results non-reproducible.
invariants_at_risk:
  - feature fingerprint identity
  - snapshot hash binding
  - warmup/scoring range separation
  - candidate-specific feature feasibility
required_context:
  - inst/design/architecture/ledgr_feature_map_ux.md
  - inst/design/architecture/ledgr_v0_1_8_sweep_architecture.md
  - R/experiment.R
  - R/features*.R
tests_required:
  - targeted precompute tests
  - warmup coverage tests
escalation_triggers:
  - feature factories cannot be resolved without executing strategy code
  - warmup metadata cannot be represented without changing snapshot APIs
  - precompute object cannot validate the union of feature fingerprints
forbidden_actions:
  - mutating sealed snapshots
  - exposing persisted feature-series retrieval as a public API
  - silently falling back to live feature computation when precompute mismatches
```

---

## LDG-2107: Feature-Factory Indicator Sweep Support

**Priority:** P1
**Effort:** 1-2 days
**Dependencies:** LDG-2105, LDG-2106
**Status:** Todo

**Description:**
Make indicator-parameter sweeps first-class by ensuring `features =
function(params)` is evaluated per candidate, candidate-specific feature
fingerprints are recorded, and invalid candidate-specific feature configs become
candidate failures.

**Tasks:**
1. Wire params-aware feature materialization into candidate evaluation.
2. Record candidate-specific `feature_fingerprints`.
3. Compute candidate-specific `feature_set_hash` for row-level provenance.
4. Distinguish structural feature-factory invalidity from one bad params row.
5. Add parity fixtures where changing params changes the registered feature set.

**Acceptance Criteria:**
- [ ] Candidate params can change indicator lookbacks or adapter parameters.
- [ ] Per-candidate `feature_fingerprints` differ when resolved features differ.
- [ ] `feature_set_hash` is derived from normalized candidate fingerprints.
- [ ] Invalid candidate-specific feature configs are captured as failed
      candidates when `stop_on_error = FALSE`.
- [ ] Structural feature-factory invalidity aborts before candidate evaluation.

**Verification:**
```text
targeted feature-factory sweep tests
candidate failure tests
parity fixture setup for LDG-2112
```

**Source Reference:** v0.1.8 spec R4 and sections 4.2, 7, 11.

**Classification:**
```yaml
risk_level: high
implementation_tier: M
review_tier: H
classification_reason: >
  Indicator-parameter sweeps are a core v0.1.8 workflow and stress the
  feature identity, warmup, and failure-classification boundaries.
invariants_at_risk:
  - feature-factory semantics
  - candidate-specific fingerprints
  - failure classification
  - sweep/run parity
required_context:
  - R/experiment.R
  - R/param-grid.R
  - inst/design/ledgr_v0_1_8_spec_packet/v0_1_8_spec.md
tests_required:
  - feature-factory sweep tests
escalation_triggers:
  - feature factories require strategy execution to discover features
  - candidate-specific feature failure cannot be isolated cleanly
forbidden_actions:
  - adding a separate indicator-sweep API
  - collapsing all feature identity into sweep-level union metadata only
  - silently skipping invalid candidate features
```

---

## LDG-2108: Sequential ledgr_sweep() And ledgr_sweep_results

**Priority:** P0
**Effort:** 2-4 days
**Dependencies:** LDG-2102, LDG-2104, LDG-2105, LDG-2106
**Status:** Todo

**Description:**
Add the first public sequential `ledgr_sweep()` runner and classed
`ledgr_sweep_results` object. The sweep must call the shared fold core and
return summary-only candidate rows in parameter-grid order.

**Tasks:**
1. Add exported `ledgr_sweep()`.
2. Evaluate candidates sequentially through the shared fold core.
3. Generate a non-RNG `sweep_id` at sweep start and carry it into the result
   object.
4. Add fold-core output-handler injection: `NULL` keeps the current persistent
   `ledgr_run()` handler; a supplied handler is used for sweep candidates.
5. Move the loop transaction boundary behind the output handler or equivalent
   control method so persistent runs wrap writes in a DuckDB transaction while
   sweep candidates do not require a store connection.
6. Route post-loop output materialization through the handler boundary:
   persisted runs continue writing features/equity/run status; sweep candidates
   retain only the summary data needed for result rows.
7. Support optional `ledgr_precomputed_features`.
8. Capture candidate-level execution failures by default.
9. Implement `stop_on_error = TRUE` for sequential debugging.
10. Abort unconditionally for contract validation errors.
11. Return a `ledgr_sweep_results` tibble subclass with standard metric columns.
12. Keep row order in parameter-grid order; ranking remains caller-owned.

**Acceptance Criteria:**
- [ ] Successful candidates produce summary rows with standard metric columns.
- [ ] Failed candidates keep params, status, error class, and error message.
- [ ] Contract errors abort regardless of `stop_on_error`.
- [ ] `stop_on_error = TRUE` rethrows candidate-level errors in sequential
      mode.
- [ ] Result rows remain in parameter-grid order.
- [ ] `ledgr_sweep()` does not write DuckDB run artifacts or persisted
      telemetry.
- [ ] `evaluation_scope` defaults to `"exploratory"`.
- [ ] A non-RNG `sweep_id` is generated at sweep start and attached to the
      `ledgr_sweep_results` object.

**Verification:**
```text
targeted ledgr_sweep tests
failure semantics tests
standard metric column tests
```

**Source Reference:** v0.1.8 spec sections 4.3, 4.4, 7, 8.

**Classification:**
```yaml
risk_level: release-critical
implementation_tier: H
review_tier: H
classification_reason: >
  This ticket introduces the public sweep API. It must reuse the fold core and
  preserve error semantics while avoiding durable run side effects.
invariants_at_risk:
  - single execution semantics
  - candidate failure isolation
  - contract error handling
  - summary metric correctness
required_context:
  - inst/design/architecture/ledgr_sweep_mode_ux.md
  - inst/design/contracts.md
  - R/backtest.R
  - R/backtest-runner.R
tests_required:
  - targeted sweep tests
  - failure semantics tests
escalation_triggers:
  - sweep requires a second execution loop
  - summary metrics cannot be produced without retaining full event streams
  - contract errors cannot be separated from candidate failures
  - injected output handlers cannot preserve current ledgr_run transaction
    behavior
  - post-loop feature/equity materialization cannot be separated cleanly from
    candidate summary output
forbidden_actions:
  - writing run artifacts for sweep candidates
  - adding objective/ranking arguments
  - adding public parallel execution
```

---

## LDG-2109: Sweep Output Provenance Columns And Print Curation

**Priority:** P1
**Effort:** 1-2 days
**Dependencies:** LDG-2107, LDG-2108
**Status:** Todo

**Description:**
Complete the v0.1.8 sweep result shape: row-level `execution_seed`, row-level
`provenance`, warnings as a list column, candidate-specific feature
fingerprints, sweep metadata attributes, and curated print output.

**Tasks:**
1. Add `execution_seed` as the visible per-candidate fold seed.
2. Add `provenance` list column with `provenance_version =
   "ledgr_provenance_v1"`.
3. Store `snapshot_hash`, `strategy_hash`, `feature_set_hash`, `master_seed`,
   `seed_contract`, and `evaluation_scope` in row-level provenance.
4. Keep `params`, `warnings`, `feature_fingerprints`, and `provenance` as list
   columns hidden from default print.
5. Add result-level attributes for sweep metadata, master seed, seed derivation
   contract, snapshot identity, strategy/preflight identity, feature union, and
   execution assumptions.
6. Ensure `sweep_id` generated by `ledgr_sweep()` is present in result metadata
   for later candidate promotion.
7. Implement curated print with `execution_seed` visible and all hidden list
   columns noted in the footer.

**Acceptance Criteria:**
- [ ] `execution_seed` is `NA_integer_` for unseeded sweeps and an integer for
      seeded candidates.
- [ ] Every candidate row has `provenance_version = "ledgr_provenance_v1"`.
- [ ] `warnings` preserves warning condition classes or condition objects as a
      list column.
- [ ] Default print shows scalar ranking/selection fields and hides the four
      list columns.
- [ ] Footer accounts for all visible and hidden columns, including `win_rate`.
- [ ] Result metadata lives in attributes, not duplicated scalar columns.
- [ ] Result metadata includes `sweep_id`.

**Verification:**
```text
targeted ledgr_sweep_results tests
print snapshot tests
column order tests
```

**Source Reference:** v0.1.8 spec section 4.4 and sweep UX object contract.

**Classification:**
```yaml
risk_level: high
implementation_tier: M
review_tier: H
classification_reason: >
  Sweep result rows are the user promotion surface. Missing seeds, ambiguous
  provenance, or unreadable print output would make promotion unsafe.
invariants_at_risk:
  - candidate replay identity
  - row-level provenance
  - result table usability
  - warning class preservation
required_context:
  - inst/design/rfc/rfc_sweep_candidate_promotion_contract_v0_1_8_synthesis_response.md
  - inst/design/architecture/ledgr_sweep_mode_ux.md
tests_required:
  - result shape tests
  - print tests
escalation_triggers:
  - dplyr operations drop required row-level identity
  - warnings cannot be preserved without unsafe condition serialization
  - print output cannot stay readable with list columns
forbidden_actions:
  - hiding execution_seed from default print
  - storing per-candidate feature identity only in attributes
  - replacing warnings list column with lossy strings
```

---

## LDG-2110: Candidate Selection And Promotion API

**Priority:** P1
**Effort:** 1-2 days
**Dependencies:** LDG-2109
**Status:** Todo

**Description:**
Add `ledgr_candidate()`, `ledgr_sweep_candidate`, and `ledgr_promote()` so users
can promote sweep results without manually extracting `params[[1]]` or seed
values.

**Tasks:**
1. Implement `ledgr_candidate()` selection by row position or `run_id` label.
2. Preserve selected row fields plus available sweep metadata.
3. Error by default on failed candidates; allow diagnostic extraction with
   `allow_failed = TRUE`.
4. Support degraded mode for tibble-like inputs that retain required columns
   but lack full sweep metadata.
5. Implement `ledgr_promote(exp, candidate, run_id, note = NULL,
   require_same_snapshot = FALSE)`.
6. Forward candidate params and `execution_seed` to `ledgr_run()`.
7. Add candidate print output with strategy name plus hash when available.

**Acceptance Criteria:**
- [ ] `ledgr_candidate(results, "label")` selects by `run_id`.
- [ ] `ledgr_candidate(results, 1)` selects by row position.
- [ ] Failed candidates error by default.
- [ ] Degraded tibble-like input emits a message, not warning/error, when
      sweep metadata is missing.
- [ ] `ledgr_promote()` calls `ledgr_run()` with the selected params and seed.
- [ ] `require_same_snapshot = TRUE` validates `provenance$snapshot_hash`.
- [ ] Candidate print shows strategy name plus hash when available and falls
      back to hash only.

**Verification:**
```text
targeted candidate/promotion tests
same-snapshot validation tests
print tests
```

**Source Reference:** v0.1.8 spec section 4.6.

**Classification:**
```yaml
risk_level: high
implementation_tier: M
review_tier: H
classification_reason: >
  This API is the ergonomic bridge from exploratory sweep to committed run.
  Errors here could silently promote the wrong params or seed.
invariants_at_risk:
  - promotion params correctness
  - promotion seed correctness
  - snapshot lineage checking
  - failed-candidate safety
required_context:
  - inst/design/rfc/rfc_sweep_candidate_promotion_contract_v0_1_8_synthesis_response.md
  - inst/design/contracts.md
tests_required:
  - candidate extraction tests
  - promotion forwarding tests
escalation_triggers:
  - dplyr-stripped sweep rows cannot retain enough metadata for promotion
  - selected candidate cannot be represented without full sweep attributes
forbidden_actions:
  - requiring users to manually extract params[[1]]
  - promoting failed candidates by default
  - treating missing snapshot provenance as success under require_same_snapshot
```

---

## LDG-2111: Promotion Context Store And Read Helpers

**Priority:** P1
**Effort:** 1-2 days
**Dependencies:** LDG-2110
**Status:** Todo

**Description:**
Add durable `run_promotion_context` storage for runs created through
`ledgr_promote()` and read-only helpers for retrieving parsed promotion
context.

**Tasks:**
1. Add schema version `107` table `run_promotion_context`.
2. Write `sweep_id` from `ledgr_sweep_results` / `ledgr_sweep_candidate`
   metadata into `source_sweep_json`.
3. Serialize `selected_candidate_json`, `source_sweep_json`, and
   `candidate_summary_json` as canonical JSON strings.
4. Store `promotion_context_version = "ledgr_promotion_v1"`.
5. Serialize warning summaries as `n_warnings` and `warning_classes`, not full
   R conditions.
6. Write promotion context only after `ledgr_run()` succeeds.
7. Warn and return the committed run if promotion-context write fails.
8. Add `ledgr_promotion_context(bt)`,
   `ledgr_run_promotion_context(exp, run_id)`, and
   `ledgr_run_info(... )$promotion_context`.

**Acceptance Criteria:**
- [ ] Old/new stores can create or validate `run_promotion_context`.
- [ ] Promoted runs have parsed promotion context.
- [ ] Direct `ledgr_run()` runs return `NULL` promotion context.
- [ ] `candidate_summary_json` preserves the filtered/sorted selection view
      passed to `ledgr_candidate()`.
- [ ] `source_sweep_json` records the `sweep_id` produced by the source sweep.
- [ ] Promotion-context write failure warns without rolling back a successful
      run.
- [ ] Read helpers are read-only and do not execute strategy code.

**Verification:**
```text
schema migration tests
promotion context write/read tests
source_sweep_json sweep_id tests
run_info integration tests
```

**Source Reference:** v0.1.8 spec section 4.7 and promotion-context decision.

**Classification:**
```yaml
risk_level: high
implementation_tier: M
review_tier: H
classification_reason: >
  This ticket adds a durable store table and selection-audit metadata. It must
  not corrupt existing run stores or turn sweep outputs into full persisted
  artifacts.
invariants_at_risk:
  - experiment-store schema compatibility
  - promoted run auditability
  - read-only inspection
  - no full sweep persistence
required_context:
  - inst/design/rfc/rfc_sweep_promotion_context_v0_1_8_decision.md
  - R/run-store.R
  - R/backtest.R
tests_required:
  - schema migration tests
  - promotion context read/write tests
escalation_triggers:
  - schema version 107 conflicts with another pending schema change
  - canonical JSON cannot safely represent candidate summaries
  - promotion context write failures cannot be isolated from successful runs
forbidden_actions:
  - adding ledgr_save_sweep()
  - storing full sweep ledger/equity/event streams
  - storing full R warning condition objects durably
  - rolling back successful ledgr_run() because context write failed
```

---

## LDG-2112: Sweep Parity Test Suite

**Priority:** P0
**Effort:** 2-3 days
**Dependencies:** LDG-2103, LDG-2107, LDG-2109, LDG-2111
**Status:** Todo

**Description:**
Build the parity test suite proving that `ledgr_run()` and `ledgr_sweep()` agree
on same-platform execution semantics for deterministic and explicitly seeded
strategies.

**Tasks:**
1. Compare `ledgr_run()` and `ledgr_sweep()` outputs for simple deterministic
   strategies.
2. Add explicit seed fixtures and verify same candidate seed produces same
   promoted run result.
3. Compare target validation, feature values, pulse order, fill timing, prices,
   fees, cash deltas, final cash, positions, equity, and retained metrics.
4. Include final-bar no-fill and warmup behavior cases.
5. Include a params grid where changing params changes the registered feature
   set.
6. Include config hash stability after timing/cost boundary extraction.
7. Include promotion context verification for promoted sweep candidates.

**Acceptance Criteria:**
- [ ] Same inputs produce equivalent `ledgr_run()` and `ledgr_sweep()` summary
      metrics on the same platform/R version.
- [ ] Feature-factory sweeps are covered by parity tests.
- [ ] Seeded candidate promotion reproduces the selected candidate's result.
- [ ] Cost/fill/cash semantics are unchanged.
- [ ] `config_hash` stays stable for unchanged scalar execution config.
- [ ] Parity failures are CI failures, not manual review notes.

**Verification:**
```text
dedicated parity tests
targeted runner/sweep tests
full testthat required before release gate
```

**Source Reference:** v0.1.8 spec sections 6 and 11.

**Classification:**
```yaml
risk_level: release-critical
implementation_tier: H
review_tier: H
classification_reason: >
  The release promise is one execution semantics. This suite is the gate that
  prevents sweep from becoming a second engine.
invariants_at_risk:
  - ledgr_run/ledgr_sweep parity
  - feature-factory parity
  - seeded promotion reproducibility
  - fill/cost semantics
  - config_hash stability
required_context:
  - inst/design/ledgr_v0_1_8_spec_packet/v0_1_8_spec.md
  - inst/design/contracts.md
  - tests/testthat
tests_required:
  - dedicated parity test suite
escalation_triggers:
  - parity requires retaining full event streams for all sweep candidates
  - seeded promotion cannot reproduce the selected candidate
  - feature-factory parity exposes unresolved feature lookup differences
forbidden_actions:
  - weakening parity assertions to fit implementation drift
  - accepting same-platform numeric divergence without a bug ticket
  - bypassing the shared fold core in tests
```

---

## LDG-2113: Evaluation Discipline And Sweep Documentation

**Priority:** P1
**Effort:** 1-2 days
**Dependencies:** LDG-2110, LDG-2111, LDG-2112
**Status:** Todo

**Description:**
Document the v0.1.8 sweep workflow, including train/sweep/evaluate discipline,
promotion helpers, failure handling, precomputed features, indicator-parameter
sweeps, seed/provenance interpretation, and explicit non-goals.

**Tasks:**
1. Add user-facing sweep documentation and examples.
2. Teach manual train snapshot, sweep, locked params, test snapshot evaluation.
3. Explain that provenance records what ran; it does not prove selection
   integrity.
4. Document `ledgr_param_grid()`, `ledgr_precompute_features()`,
   `ledgr_sweep()`, `ledgr_candidate()`, and `ledgr_promote()`.
5. Explain `execution_seed`, row-level `provenance`, promotion context, and why
   full sweep artifact persistence is deferred.
6. Document failure rows and `stop_on_error`.
7. Keep `ledgr_tune()` explicitly deferred.
8. Add/update documentation contract tests for the new public surface.

**Acceptance Criteria:**
- [ ] Docs teach sweep as exploration and promoted runs as committed artifacts.
- [ ] Train/test promotion uses `ledgr_candidate()` and `ledgr_promote()`.
- [ ] Same-snapshot replay is shown as secondary and in-sample.
- [ ] Docs mention warning threshold for large grids without precompute.
- [ ] Docs do not imply ledgr ranks candidates automatically.
- [ ] Docs do not advertise parallel sweep, walk-forward, PBO/CSCV,
      risk-layer, cost-model, paper/live, intraday, or full sweep persistence.

**Verification:**
```text
documentation contract tests
targeted vignette/render checks
manual docs review
```

**Source Reference:** v0.1.8 spec section 10.

**Classification:**
```yaml
risk_level: high
implementation_tier: M
review_tier: H
classification_reason: >
  Sweep makes overfitting easy. Documentation must teach the epistemic boundary
  clearly and avoid presenting exploratory sweep winners as validated results.
invariants_at_risk:
  - evaluation discipline
  - promotion UX correctness
  - non-goal clarity
  - public API documentation
required_context:
  - inst/design/architecture/ledgr_sweep_mode_ux.md
  - inst/design/contracts.md
  - vignettes
  - README.md
tests_required:
  - documentation contract tests
  - targeted render checks
escalation_triggers:
  - docs require APIs not implemented by prior tickets
  - examples imply ledgr-owned ranking/objective semantics
  - train/test discipline cannot be explained without a split helper
forbidden_actions:
  - adding ledgr_snapshot_split()
  - adding ledgr_tune()
  - implying sweep results are out-of-sample by default
  - documenting full sweep artifact persistence as shipped
```

---

## LDG-2114: v0.1.8 Release Gate

**Priority:** P0
**Effort:** 1 day
**Dependencies:** LDG-2112, LDG-2113
**Status:** Todo

**Description:**
Close the v0.1.8 release. Verify tickets and YAML status, update release docs,
sync design/admin pointers, run required checks, monitor CI, and tag only after
the release playbook gates pass.

**Tasks:**
1. Confirm all tickets and `tickets.yml` statuses are synchronized.
2. Update `NEWS.md`, `DESCRIPTION`, and any required release metadata.
3. Sync `inst/design/README.md`, `AGENTS.md`, and `docs/AGENTS.md` active-cycle
   pointers.
4. Confirm `contracts.md` and `ledgr_roadmap.md` reflect final v0.1.8 status.
5. Run targeted tests, full tests, package build/check, coverage, and pkgdown
   checks per the release playbook.
6. Push, monitor CI, and tag only after CI succeeds.

**Acceptance Criteria:**
- [ ] All v0.1.8 tickets are done or explicitly deferred with maintainer
      approval.
- [ ] `tickets.yml` matches `v0_1_8_tickets.md`.
- [ ] Release metadata and `NEWS.md` are updated.
- [ ] Design index and AGENTS files point to the current released/next cycle.
- [ ] Full test suite, package check, coverage, pkgdown checks, and CI pass.
- [ ] No generated local artifacts are committed.

**Verification:**
```text
testthat full suite
R CMD build
R CMD check --no-manual --no-build-vignettes
tools/check-coverage.R
pkgdown build/check
CI status
```

**Source Reference:** v0.1.8 spec section 13 and release playbook.

**Classification:**
```yaml
risk_level: release-critical
implementation_tier: M
review_tier: H
classification_reason: >
  This is the release gate for a runtime API milestone. It must catch status
  drift, generated artifacts, failing checks, stale docs, and CI failures before
  tagging.
invariants_at_risk:
  - release integrity
  - ticket/status consistency
  - package check health
  - documentation/admin pointer accuracy
required_context:
  - inst/design/ledgr_v0_1_8_spec_packet/v0_1_8_spec.md
  - inst/design/ledgr_v0_1_8_spec_packet/v0_1_8_tickets.md
  - inst/design/ledgr_v0_1_8_spec_packet/tickets.yml
  - inst/design/release_ci_playbook.md
  - NEWS.md
  - DESCRIPTION
tests_required:
  - full testthat
  - R CMD check
  - coverage check
  - pkgdown check
  - CI
escalation_triggers:
  - parity suite fails
  - CI differs from local checks
  - release metadata conflicts with active branch/version
  - docs/admin pointers cannot be reconciled
forbidden_actions:
  - tagging with failing CI
  - committing generated local artifacts
  - leaving AGENTS/docs AGENTS stale
  - silently deferring failed P0/P1 tickets
```
