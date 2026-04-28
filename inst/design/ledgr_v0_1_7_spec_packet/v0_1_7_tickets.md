# ledgr v0.1.7 Core UX Overhaul Tickets

**Version:** 0.1.0  
**Date:** April 28, 2026  
**Total Tickets:** 11  
**Estimated Duration:** 5-8 weeks

---

## Ticket Organization

v0.1.7 is an intentional public API reset. The ticket range starts at
`LDG-1001` to avoid collisions with earlier cycles.

Under `inst/design/model_routing.md`, most v0.1.7 tickets are Tier H because
they touch breaking public API behavior, canonical execution entry points,
persistence lifecycle, strategy contracts, or run identity. Documentation-only
work remains Tier M implementation with Tier H review because it teaches the
new public workflow.

### Dependency DAG

```text
LDG-1001 -> LDG-1002 -> LDG-1003 -> LDG-1010 -> LDG-1011
LDG-1002 -> LDG-1004 -------------> LDG-1010 -> LDG-1011
LDG-1002 -> LDG-1005 -> LDG-1007 -> LDG-1010 -> LDG-1011
LDG-1001 -> LDG-1006 -------------> LDG-1010 -> LDG-1011
LDG-1003 -> LDG-1008 -------------> LDG-1010 -> LDG-1011
LDG-1001 -> LDG-1009 -------------> LDG-1010 -> LDG-1011
LDG-1001 --------------------------------------> LDG-1011
```

`LDG-1011` is the v0.1.7 release gate.

### Priority Levels

- **P0 (Blocker):** Required for correctness or release coherence.
- **P1 (Critical):** Required for the user story to work.
- **P2 (Important):** Required for discoverability or documentation quality.
- **P3 (Optional):** Useful, but not a release blocker.

---

## LDG-1001: API Reset Contract And Migration Policy

**Priority:** P0  
**Effort:** 1-2 days  
**Dependencies:** None  
**Status:** Done

**Description:**
Make the v0.1.7 breaking-change policy explicit before implementation begins.
This ticket updates the design contracts and migration posture so implementers
do not accidentally preserve old public workflow signatures while building the
new experiment-first API.

**Tasks:**
1. Update `inst/design/contracts.md` with the v0.1.7 public workflow contract.
2. Add or update the compatibility policy to state that v0.1.7 intentionally
   hard-breaks old public workflow signatures.
3. Define what counts as public workflow API versus low-level/internal helper.
4. Define the migration rule for removed signatures:
   - `function(ctx)`;
   - `ctx$targets()`;
   - `ctx$current_targets()`;
   - `db_path`-first store operations;
   - user-facing `ledgr_backtest()` examples.
5. Create a migration-note skeleton for v0.1.6 to v0.1.7.
6. Add `NEWS.md` draft bullets under a v0.1.7 breaking-changes subsection.
7. Confirm that v0.1.8 sweep docs reference `ledgr_run()`, not
   `ledgr_backtest()`, where they describe future public workflows.

**Acceptance Criteria:**
- [x] Contracts say v0.1.7 is a hard public API reset.
- [x] Removed public workflow signatures are named explicitly.
- [x] Low-level/internal escape hatches are clearly separated from the
      recommended workflow.
- [x] NEWS has a breaking-changes subsection.
- [x] A migration-note skeleton exists before implementation tickets start.
- [x] No compatibility shim is implied without an explicit ticket.

**Test Requirements:**
- Documentation consistency scan.
- Export/API inventory review.

**Source Reference:** v0.1.7 spec sections 0, 2.1, 4.

**Classification:**
```yaml
risk_level: release-critical
implementation_tier: H
review_tier: H
classification_reason: >
  Version scoping, compatibility policy, contract modification, and public API
  breaking-change definition are Tier H by rule. This ticket sets boundaries
  for all later implementation work.
invariants_at_risk:
  - public API compatibility policy
  - release scope
  - migration semantics
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_spec_packet/v0_1_7_spec.md
  - inst/design/ledgr_ux_decisions.md
  - inst/design/ledgr_sweep_mode_ux.md
  - inst/design/contracts.md
  - NEWS.md
tests_required:
  - documentation consistency scan
  - export/API inventory review
escalation_triggers:
  - a compatibility shim seems necessary
  - existing contracts conflict with the hard reset
  - sweep/tune scope leaks into v0.1.7
forbidden_actions:
  - silently preserving old public workflow signatures
  - adding v0.1.8 sweep APIs
  - changing execution semantics while editing contracts
```

---

## LDG-1002: Experiment And Opening State Objects

**Priority:** P0  
**Effort:** 3-5 days  
**Dependencies:** LDG-1001  
**Status:** Done

**Description:**
Add the classed `ledgr_experiment` and `ledgr_opening` objects that define the
new public workflow. This is the central shape that `ledgr_run()`,
snapshot-first store operations, documentation, and future sweep mode depend
on.

**Tasks:**
1. Implement `ledgr_opening(cash, date = NULL, positions = NULL,
   cost_basis = NULL)`.
2. Validate cash, positions, cost basis, date format, names, finiteness, and
   long-only constraints.
3. Implement concise `print.ledgr_opening()`.
4. Implement `ledgr_experiment(snapshot, strategy, features = list(),
   opening = ledgr_opening(cash = 100000), universe = NULL, fill_model = ...,
   persist_features = TRUE, execution_mode = ...)`.
5. Validate that `snapshot` is a sealed snapshot or supported snapshot handle.
6. Validate that `features` is either a list of indicators or
   `function(params) list(...)`.
7. Validate `universe`: `NULL` means all snapshot instruments; supplied values
   must be a non-empty subset of the snapshot instruments.
8. Validate that `strategy` satisfies the v0.1.7 strategy contract boundary
   enough to fail unsupported signatures early.
9. Store enough snapshot/store metadata on the experiment object for later
   `ledgr_run()` and store operations to avoid `db_path`.
10. Implement concise `print.ledgr_experiment()`.
11. Add `ledgr_opening_from_broker(x, ...)` only as a structural adapter hook
    with no built-in broker integrations and no network calls. Unsupported
    objects fail with a classed not-supported error.
12. Document all three constructors.

**Acceptance Criteria:**
- [x] `ledgr_experiment()` returns a classed object with snapshot, strategy,
      feature, opening, fill-model, persistence, and execution-mode metadata.
- [x] `ledgr_opening()` rejects invalid cash, unnamed positions, negative
      positions, and inconsistent cost basis.
- [x] Opening state can represent cash-only and existing long portfolios.
- [x] `universe = NULL` selects all snapshot instruments.
- [x] Supplied universes are validated as non-empty snapshot-instrument subsets.
- [x] `ledgr_opening_from_broker()` does not imply broker support in v0.1.7.
- [x] Print methods are concise and useful.
- [x] No execution occurs in constructors.
- [x] No DuckDB writes occur in constructors except any existing snapshot
      validation that is already read-only.

**Test Requirements:**
- Constructor validation tests.
- Snapshot compatibility tests.
- Universe validation tests.
- Feature-list and feature-function tests.
- Opening-state validation tests.
- Print method tests.
- No-write tests for constructors where practical.

**Source Reference:** v0.1.7 spec sections 2.2, 2.7, 3.1, 3.2, 3.3.

**Classification:**
```yaml
risk_level: high
implementation_tier: H
review_tier: H
classification_reason: >
  Introduces central public API objects that carry snapshot, strategy, feature,
  opening, and execution metadata. It touches public API, strategy validation,
  execution configuration, and future run identity.
invariants_at_risk:
  - public API object model
  - strategy contract validation
  - opening-state semantics
  - future run config identity
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_spec_packet/v0_1_7_spec.md
  - inst/design/ledgr_ux_decisions.md
  - inst/design/contracts.md (Strategy Contract, Snapshot Contract, Run Identity Contract)
  - R/backtest.R
  - R/config-validate.R
  - R/snapshots-load.R
tests_required:
  - constructor validation tests
  - opening-state tests
  - experiment object tests
  - print method tests
escalation_triggers:
  - experiment object requires schema changes
  - opening state changes ledger semantics
  - broker integration becomes more than a structural hook
forbidden_actions:
  - running backtests from constructors
  - adding broker network integrations
  - allowing short positions
  - adding sweep or tune execution
```

---

## LDG-1003: `ledgr_run()` Public Execution API

**Priority:** P0  
**Effort:** 3-5 days  
**Dependencies:** LDG-1002  
**Status:** Done

**Description:**
Add `ledgr_run()` as the public single-run API on a `ledgr_experiment` object.
The implementation must reuse the canonical execution path and preserve result
semantics for equivalent valid runs.

**Tasks:**
1. Implement `ledgr_run(exp, params = list(), run_id = NULL, seed = NULL)`.
2. Validate that `exp` is a `ledgr_experiment`.
3. Validate that `params` is a list; empty list is valid.
4. If experiment features are a function, evaluate them with `params` and
   validate the returned indicators.
5. Map experiment/opening/params metadata into the existing backtest config.
6. Record opening cash and positions as opening ledger events if this is not
   already represented by the existing runner path.
7. Preserve feature cache behavior, telemetry behavior, provenance behavior,
   and run-store behavior from v0.1.6.
8. Always write a `seed` field into `config_json` before config hashing,
   including explicit `seed = NULL` for default runs.
9. Decide the v0.1.7 behavior for non-NULL `seed`:
   - implement it fully and include it in config identity; or
   - reject it with a classed "reserved for v0.1.8" error.
10. Demote `ledgr_backtest()` in docs and examples; do not remove internals that
   `ledgr_run()` needs.
11. Add parity tests between equivalent `ledgr_run()` and current valid
    execution paths where possible.

**Acceptance Criteria:**
- [x] `ledgr_run()` is the documented public single-run entry point.
- [x] Equivalent valid runs preserve equity, trades, fills, positions, ledger
      semantics, feature values, telemetry, and provenance.
- [x] Feature functions of params are evaluated exactly once per run.
- [x] `params = list()` works.
- [x] `run_id` generation and validation match existing durable run rules.
- [x] `seed = NULL` appears in `config_json` and participates in config hash.
- [x] non-NULL `seed` behavior is explicit and tested.
- [x] `ledgr_backtest()` is no longer recommended in user-facing docs.

**Test Requirements:**
- `ledgr_run()` smoke test with fixed features.
- `ledgr_run()` test with `features = function(params)`.
- `params = list()` test.
- durable run store test.
- result parity tests.
- provenance and telemetry tests.
- seed field/config-hash test.
- non-NULL seed behavior test.

**Source Reference:** v0.1.7 spec sections 2.3, 3.4, 5.

**Classification:**
```yaml
risk_level: high
implementation_tier: H
review_tier: H
classification_reason: >
  Adds the new canonical public execution API and maps it to the existing
  runner. It touches execution, persistence, run identity, strategy params,
  feature computation, telemetry, and public API contracts.
invariants_at_risk:
  - canonical execution path
  - event ledger semantics
  - run identity and config hash
  - strategy params provenance
  - feature cache behavior
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_spec_packet/v0_1_7_spec.md
  - inst/design/contracts.md (Execution Contract, Strategy Contract, Run Identity Contract, Persistence Contract)
  - R/backtest.R
  - R/backtest-runner.R
  - R/strategy-contracts.R
  - R/strategy-provenance.R
  - R/features-engine.R
tests_required:
  - ledgr_run execution tests
  - parity tests
  - durable store tests
  - provenance tests
  - telemetry tests
escalation_triggers:
  - parity with existing valid runs fails
  - opening state requires changing fill/ledger semantics
  - seed identity cannot be specified cleanly
forbidden_actions:
  - forking the runner
  - changing pulse order or fill semantics
  - adding sweep/tune execution
  - dropping telemetry or provenance
```

---

## LDG-1004: Strategy Signature And Context Helper Reset

**Priority:** P0  
**Effort:** 2-4 days  
**Dependencies:** LDG-1002  
**Status:** Done

**Description:**
Hard-reset the strategy contract to `function(ctx, params)` and replace target
helper names with `ctx$flat()` and `ctx$hold()`.

**Tasks:**
1. Update strategy signature detection so only `function(ctx, params)` is
   valid.
2. Ensure strategies with no params receive `params = list()`.
3. Reject `function(ctx)` with a classed migration error.
4. Reject unsupported signatures such as `function(ctx, params, extra)`.
5. Do not add `ctx$params`.
6. Add `ctx$flat()` and `ctx$hold()` to runtime contexts.
7. Add `ctx$flat()` and `ctx$hold()` to `ledgr_pulse_snapshot()` contexts.
8. Make `ctx$targets()` and `ctx$current_targets()` fail loudly with migration
   guidance.
9. Update tests that used the old helpers.
10. Update contracts for the new context names.

**Acceptance Criteria:**
- [x] `function(ctx, params)` is the only accepted strategy signature.
- [x] `function(ctx)` fails before execution with a migration message.
- [x] `params = list()` is valid and passed as the second argument.
- [x] `ctx$flat()` returns a zero target vector over the universe.
- [x] `ctx$hold()` returns current positions as targets.
- [x] old helper names fail, not alias.
- [x] runtime and pulse-snapshot contexts behave consistently.

**Test Requirements:**
- Strategy signature validation tests.
- Runtime context helper tests.
- Pulse-snapshot context helper tests.
- Migration-error tests for old helpers and old signature.
- Existing strategy-provenance tests updated for the new signature.

**Source Reference:** v0.1.7 spec sections 2.4, 2.5, 3.6.

**Classification:**
```yaml
risk_level: high
implementation_tier: H
review_tier: H
classification_reason: >
  Hard-removes an existing strategy signature and existing context helpers,
  touching execution callbacks, strategy dispatch, target-vector semantics, and
  public API behavior.
invariants_at_risk:
  - strategy dispatch
  - target vector semantics
  - pulse context contract
  - reproducibility tier classification
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_spec_packet/v0_1_7_spec.md
  - inst/design/contracts.md (Strategy Contract, Context Contract)
  - R/strategy-contracts.R
  - R/pulse-context.R
  - R/backtest-runner.R
  - tests/testthat/test-strategy-provenance.R
tests_required:
  - strategy signature tests
  - context helper tests
  - migration-error tests
  - existing runner tests
escalation_triggers:
  - old helpers are needed internally
  - target semantics differ between runtime and pulse snapshot
  - provenance classifier assumes function(ctx) remains valid
forbidden_actions:
  - adding ctx$params
  - keeping old helpers as aliases
  - silently accepting function(ctx)
  - changing target vector shape
```

---

## LDG-1005: Snapshot-First Store Operations

**Priority:** P0  
**Effort:** 3-5 days  
**Dependencies:** LDG-1002  
**Status:** Done

**Description:**
Convert the public experiment-store workflow from `db_path`-first calls to
snapshot-first calls while preserving v0.1.5/v0.1.6 storage behavior.
This includes a first-class new-session resumption path from a durable DuckDB
file back to a snapshot handle.

**Tasks:**
1. Confirm or refine the public resumption API:
   `ledgr_snapshot_load(db_path, snapshot_id)` or an explicitly equivalent
   `ledgr_snapshot_open(db_path, snapshot_id)`.
2. Ensure the resumption API returns a snapshot object carrying enough store
   metadata for every snapshot-first run-management API.
3. Ensure missing `snapshot_id` in a multi-snapshot store fails with a classed
   error pointing to `ledgr_snapshot_list(db_path)`.
4. Update docs to show new sessions resuming by loading the snapshot first.
5. Update public signatures for run list, info, open, label, archive, tag,
   untag, compare, and strategy extraction to accept snapshot first.
6. Ensure mutation functions return the snapshot for pipe/reassign workflows.
7. Ensure read functions keep their existing classed return objects.
8. Preserve v0.1.6 behavior for archived, failed, incomplete, legacy, and
   tagged runs.
9. Decide how old `db_path`-first calls fail or are marked low-level.
10. Update roxygen docs and examples.
11. Add migration errors for old signatures where practical.
12. Add tests proving no unintended store mutation from read operations.

**Acceptance Criteria:**
- [x] New-session workflow can resume from an existing DuckDB file by loading a
      snapshot handle first.
- [x] `ledgr_snapshot_load()` or its replacement is documented as the
      canonical resumption path.
- [x] Snapshot-first calls cover all store workflows from v0.1.6.
- [x] Mutation calls return snapshot.
- [x] Read calls preserve classed returns.
- [x] Old `db_path`-first public examples are gone.
- [x] Old signatures fail clearly or are documented as low-level/internal.
- [x] Comparison and extraction remain no-recompute/no-mutation reads.
- [x] Run identity hashes are unchanged by metadata mutations.

**Test Requirements:**
- Snapshot resumption tests against an existing durable store.
- Snapshot-first run list/info/open tests.
- Snapshot-first label/archive/tag/untag tests.
- Snapshot-first compare/extract tests.
- Old-signature migration-error tests.
- No-mutation tests for read operations.
- Identity-preservation tests for metadata mutations.

**Source Reference:** v0.1.7 spec sections 2.6, 3.7, 3.8, 5.

**Classification:**
```yaml
risk_level: high
implementation_tier: H
review_tier: H
classification_reason: >
  Changes public signatures for experiment-store operations, including DuckDB
  reads/writes, metadata mutation, comparison, strategy extraction, and run
  identity surfaces.
invariants_at_risk:
  - experiment-store persistence
  - run identity immutability
  - archived/tagged metadata semantics
  - comparison no-mutation guarantee
  - strategy extraction trust boundary
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_spec_packet/v0_1_7_spec.md
  - inst/design/ledgr_v0_1_6_spec_packet/v0_1_6_spec.md
  - inst/design/contracts.md (Persistence Contract, Run Identity Contract, Result Contract)
  - R/run-store.R
  - R/run-tags.R
  - R/strategy-extract.R
tests_required:
  - snapshot-first store API tests
  - old-signature failure tests
  - no-mutation tests
  - identity-preservation tests
escalation_triggers:
  - snapshot object lacks enough store metadata
  - old db_path signature compatibility seems necessary
  - comparison/extraction behavior changes unintentionally
forbidden_actions:
  - changing run identity hashes during metadata mutation
  - mutating stores from read APIs
  - evaluating strategy source from comparison
  - adding hard delete
```

---

## LDG-1006: Typed Parameter Grid

**Priority:** P1  
**Effort:** 1-2 days  
**Dependencies:** LDG-1001  
**Status:** Pending

**Description:**
Add `ledgr_param_grid()` as a typed, non-executing parameter-grid object. This
locks the naming and validation contract needed by v0.1.8 sweep mode without
shipping sweep or tune execution in v0.1.7.

**Tasks:**
1. Implement `ledgr_param_grid(...)`.
2. Require every entry to be a list.
3. Preserve user-supplied names as labels.
4. Generate stable labels for unnamed entries using canonical JSON params hash.
5. Reject duplicate labels.
6. Add a concise print method.
7. Add accessors or documented structure for labels and params.
8. Document that grid labels are not run IDs.
9. Document that the object is not executed in v0.1.7.

**Acceptance Criteria:**
- [ ] Named grids preserve labels.
- [ ] Unnamed grids receive stable generated labels.
- [ ] Duplicate labels fail with a classed error.
- [ ] All entries are params lists.
- [ ] Return object is classed and printable.
- [ ] No sweep or tune execution API is added.
- [ ] Canonical params hashing is deterministic.

**Test Requirements:**
- Named-grid tests.
- Unnamed stable-label tests.
- Duplicate-label tests.
- Invalid-entry tests.
- Print method tests.
- Export scan confirming no `ledgr_sweep()` or `ledgr_tune()` export.

**Source Reference:** v0.1.7 spec sections 2.11, 3.5.

**Classification:**
```yaml
risk_level: high
implementation_tier: H
review_tier: H
classification_reason: >
  Adds a public API that uses canonical JSON-derived labels and will become
  part of future sweep identity. Although bounded, it touches public API and
  identity-adjacent hashing.
invariants_at_risk:
  - parameter identity
  - canonical JSON expectations
  - future sweep label semantics
  - public API boundary
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_spec_packet/v0_1_7_spec.md
  - inst/design/ledgr_sweep_mode_ux.md
  - inst/design/contracts.md (Canonical JSON Contract, Run Identity Contract)
  - R/config-canonical-json.R
tests_required:
  - param grid validation tests
  - stable label tests
  - duplicate label tests
  - export scan for sweep/tune APIs
escalation_triggers:
  - label hashing conflicts with existing canonical JSON behavior
  - users need grid expansion syntax not covered by the spec
  - implementation starts executing grids
forbidden_actions:
  - exporting ledgr_sweep
  - exporting ledgr_tune
  - treating grid labels as run IDs
  - using non-canonical serialization for generated labels
```

---

## LDG-1007: Curated Run List And Comparison Prints

**Priority:** P1  
**Effort:** 1-2 days  
**Dependencies:** LDG-1005  
**Status:** Pending

**Description:**
Make `ledgr_run_list` and `ledgr_comparison` print as curated research objects
while remaining ordinary tibble-like data underneath.

**Tasks:**
1. Add or update `print.ledgr_run_list()`.
2. Add or update `print.ledgr_comparison()`.
3. Keep underlying numeric columns numeric.
4. Format return, drawdown, and win-rate values as percentages in print only.
5. Limit default print columns to the 7-8 fields most useful at a glance.
6. Add footers pointing to detail APIs.
7. Omit noisy `NA` footer fields where practical.
8. Add examples in docs and vignettes.

**Acceptance Criteria:**
- [ ] `ledgr_run_list()` prints a curated view with useful footer.
- [ ] `ledgr_compare_runs()` prints a curated view with useful footer.
- [ ] Underlying objects remain dplyr/tibble compatible.
- [ ] Numeric metric columns remain numeric.
- [ ] Print output does not hide access to identity and telemetry columns.

**Test Requirements:**
- Print snapshot tests or robust text tests.
- Underlying column type tests.
- dplyr/tibble compatibility tests if dplyr is available.

**Source Reference:** v0.1.7 spec sections 2.9, 3.9.

**Classification:**
```yaml
risk_level: medium
implementation_tier: M
review_tier: H
classification_reason: >
  Bounded S3 print work over existing return objects. It is user-visible and
  central to the UX reset but should not change persistence, identity, or
  execution semantics.
invariants_at_risk:
  - user-facing result presentation
  - tibble composability
  - metric type stability
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_spec_packet/v0_1_7_spec.md
  - inst/design/ledgr_ux_decisions.md
  - R/run-store.R
tests_required:
  - print method tests
  - type stability tests
  - docs examples
escalation_triggers:
  - print method requires changing returned columns
  - formatting changes underlying values
  - comparison object class is ambiguous
forbidden_actions:
  - changing stored metric definitions
  - dropping columns from underlying tibbles
  - formatting numeric columns in data rather than print
```

---

## LDG-1008: Safe Close Lifecycle

**Priority:** P1  
**Effort:** 2-4 days  
**Dependencies:** LDG-1003  
**Status:** Pending

**Description:**
Make forgotten `close(bt)` safe for durable runs. Explicit close remains
preferred, but users should not lose a completed run because they forgot to
close a handle.

**Tasks:**
1. Audit current close/checkpoint lifecycle for durable and in-memory runs.
2. Add finalizer-based auto-checkpoint for durable run handles where possible.
3. Emit a one-time informational message when GC checkpoints a run.
4. Ensure explicit `close(bt)` remains idempotent and immediate.
5. Ensure in-memory runs do not require close.
6. Add tests proving durable completed runs survive when explicit close is
   omitted.
7. Add tests for explicit close idempotency.
8. Update docs to keep showing explicit close as the preferred pattern.

**Acceptance Criteria:**
- [ ] Explicit close still works and is idempotent.
- [ ] Forgetting close does not silently lose completed durable run artifacts.
- [ ] GC checkpoint emits an informative one-time message.
- [ ] In-memory runs require no close.
- [ ] The lifecycle behavior is documented.

**Test Requirements:**
- Durable no-explicit-close persistence test.
- Explicit close idempotency test.
- In-memory no-close test.
- Message test for GC checkpoint if deterministic enough.

**Source Reference:** v0.1.7 spec sections 2.8, 8.

**Classification:**
```yaml
risk_level: high
implementation_tier: H
review_tier: H
classification_reason: >
  Touches DuckDB connection lifecycle, checkpoint behavior, persistence safety,
  and restart durability. These are persistence hard-escalation areas.
invariants_at_risk:
  - durable run persistence
  - checkpoint safety
  - connection lifecycle
  - restart safety
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_spec_packet/v0_1_7_spec.md
  - inst/design/contracts.md (Persistence Contract)
  - R/backtest.R
  - R/backtest-runner.R
  - R/db-connect.R
tests_required:
  - no-close durability tests
  - close idempotency tests
  - in-memory lifecycle tests
escalation_triggers:
  - finalizer behavior is unreliable on CI
  - checkpoint requires schema or connection architecture changes
  - close lifecycle conflicts with DuckDB locking on Windows
forbidden_actions:
  - relying on GC as the only persistence path
  - hiding checkpoint failures
  - weakening explicit close behavior
```

---

## LDG-1009: Demo Dataset And Simulation Helper

**Priority:** P1  
**Effort:** 2-4 days  
**Dependencies:** LDG-1001  
**Status:** Pending

**Description:**
Ship a deterministic synthetic demo dataset and a public simulator so examples
can stop hand-constructing tiny bars inline.

**Tasks:**
1. Implement `ledgr_sim_bars(n_instruments, n_days, seed, ...)` using a
   documented deterministic synthetic data process.
2. Add `data-raw/make_demo_bars.R` as the single source of truth for the
   committed dataset.
3. Generate and commit `data/ledgr_demo_bars.rda`.
4. Document `ledgr_demo_bars`.
5. Document `ledgr_sim_bars()`.
6. Ensure no runtime network access and no heavy optional dependencies.
7. Add tests for schema, determinism, row counts, and basic price invariants.
8. Do not replace internal test helper data unless a test explicitly benefits.

**Acceptance Criteria:**
- [ ] `ledgr_demo_bars` has at least 10 instruments and at least 5 years of
      daily bars.
- [ ] Dataset columns match `ledgr_snapshot_from_df()` input requirements.
- [ ] `ledgr_sim_bars()` is deterministic for the same seed.
- [ ] The DGP is documented and readable.
- [ ] No generation code runs at install, check, or package load time.
- [ ] README/vignettes can use the dataset offline.

**Test Requirements:**
- Dataset schema tests.
- Simulator determinism tests.
- Price high/low/open/close invariant tests.
- No-network assurance through code review.

**Source Reference:** v0.1.7 spec sections 2.10, 3.10.

**Classification:**
```yaml
risk_level: medium
implementation_tier: M
review_tier: H
classification_reason: >
  Adds package data, an exported simulator, and documentation. It does not
  touch execution semantics, but it is public API and becomes the canonical
  documentation dataset.
invariants_at_risk:
  - example reproducibility
  - package data stability
  - snapshot input schema assumptions
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_spec_packet/v0_1_7_spec.md
  - inst/design/ledgr_roadmap.md (Synthetic Demo Dataset)
  - R/snapshot-from-df.R
tests_required:
  - dataset schema tests
  - simulator determinism tests
  - documentation examples
escalation_triggers:
  - simulator requires non-base dependencies
  - dataset size causes check or install problems
  - DGP creates invalid OHLC bars
forbidden_actions:
  - using network data
  - regenerating data at install or check time
  - changing test helper datasets unnecessarily
```

---

## LDG-1010: Documentation Rewrite, Migration Guide, And NEWS

**Priority:** P1  
**Effort:** 3-5 days  
**Dependencies:** LDG-1003, LDG-1004, LDG-1006, LDG-1007, LDG-1008, LDG-1009  
**Status:** Pending

**Description:**
Rewrite user-facing documentation around the experiment-first v0.1.7 API and
the built-in demo dataset.

**Tasks:**
1. Update README quickstart to use `ledgr_demo_bars`, `ledgr_experiment()`,
   `ledgr_opening()`, and `ledgr_run()`.
2. Update `vignettes/getting-started.Rmd`.
3. Update `vignettes/research-to-production.Rmd`.
4. Update `vignettes/strategy-development.Rmd`.
5. Update `vignettes/experiment-store.Rmd`.
6. Update `vignettes/ttr-indicators.Rmd`.
7. Update relevant Rd examples to use the new API and demo data.
8. Add a v0.1.6 to v0.1.7 migration guide.
9. Update `_pkgdown.yml`.
10. Update `NEWS.md`.
11. Ensure docs do not present `ledgr_sweep()`, `ledgr_precompute_features()`,
    `ledgr_tune()`, live trading, broker adapters, or shorting as available.
12. Render changed Rmd files and generated markdown where the repo convention
    requires it.

**Acceptance Criteria:**
- [ ] User-facing docs teach `ledgr_experiment()` and `ledgr_run()`.
- [ ] No vignette or README workflow uses `function(ctx)` strategies.
- [ ] No vignette or README workflow uses old context helper names.
- [ ] No user-facing workflow passes `db_path` after snapshot creation.
- [ ] Inline ad-hoc bar construction is removed from README and vignettes.
- [ ] Migration guide names each breaking change and replacement.
- [ ] pkgdown navigation includes new APIs and articles.
- [ ] NEWS captures the breaking changes and new features.

**Test Requirements:**
- Roxygen generation.
- README render/check.
- Vignette renders for changed articles.
- pkgdown build.
- Documentation scans for removed public workflow names.

**Source Reference:** v0.1.7 spec sections 4, 6.

**Classification:**
```yaml
risk_level: medium
implementation_tier: M
review_tier: H
classification_reason: >
  Documentation-heavy, but it defines and teaches the new breaking public API.
  Tier H review is required for contract accuracy and to prevent old workflow
  leakage.
invariants_at_risk:
  - public workflow documentation
  - migration accuracy
  - API discoverability
  - scope clarity for sweep/live/broker non-goals
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_spec_packet/v0_1_7_spec.md
  - inst/design/contracts.md
  - NEWS.md
  - README.Rmd
  - vignettes/
  - _pkgdown.yml
tests_required:
  - roxygen generation
  - README render/check
  - vignette render
  - pkgdown build
  - documentation scans
escalation_triggers:
  - docs require behavior not implemented
  - old and new public workflows conflict
  - examples need network access
forbidden_actions:
  - documenting sweep/tune as available
  - using ctx$params
  - using function(ctx)
  - using old context helper names
  - recommending ledgr_backtest as public entry point
```

---

## LDG-1011: v0.1.7 Release Gate

**Priority:** P0  
**Effort:** 1 day  
**Dependencies:** LDG-1001, LDG-1002, LDG-1003, LDG-1004, LDG-1005, LDG-1006, LDG-1007, LDG-1008, LDG-1009, LDG-1010  
**Status:** Pending

**Description:**
Final validation gate for the v0.1.7 API reset.

**Tasks:**
1. Verify v0.1.7 spec, tickets, contracts, roadmap, UX decisions, and NEWS
   agree.
2. Run all targeted v0.1.7 tests.
3. Run earlier v0.1.x regression tests.
4. Run coverage gate.
5. Render README and vignettes.
6. Run package check.
7. Build pkgdown.
8. Confirm Ubuntu and Windows CI are green.
9. Confirm removed public workflow signatures fail clearly.
10. Confirm no v0.1.8 sweep/tune APIs are exported.
11. Confirm no open P0/P1 review findings remain.

**Acceptance Criteria:**
- [ ] `devtools::test()` passes.
- [ ] Coverage remains at or above the project gate.
- [ ] `R CMD check --no-manual --no-build-vignettes` passes with 0 errors and
      0 warnings.
- [ ] pkgdown builds.
- [ ] Ubuntu and Windows CI are green.
- [ ] README and vignettes are offline-safe.
- [ ] Contracts and NEWS match the implemented v0.1.7 scope.
- [ ] No old public workflow is taught in user-facing docs.
- [ ] No accidental v0.1.8 API exposure exists.
- [ ] No open P0/P1 review findings remain.

**Test Requirements:**
- Full package tests.
- Coverage gate.
- README/vignette renders.
- R CMD check.
- pkgdown build.
- CI green.
- Export scan.

**Source Reference:** v0.1.7 spec section 8.

**Classification:**
```yaml
risk_level: release-critical
implementation_tier: H
review_tier: H
classification_reason: >
  Release gate and final Tier H review for a breaking public API reset.
  Validates all contracts, tests, docs, CI, and API surface boundaries.
invariants_at_risk:
  - all v0.1.7 contracts
  - public API reset correctness
  - execution parity
  - persistence safety
  - documentation accuracy
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_spec_packet/v0_1_7_spec.md
  - inst/design/ledgr_v0_1_7_spec_packet/v0_1_7_tickets.md
  - inst/design/contracts.md
  - inst/design/ledgr_ux_decisions.md
  - NEWS.md
  - tools/check-coverage.R
  - tools/check-readme-example.R
  - .github/workflows/R-CMD-check.yaml
tests_required:
  - all targeted v0.1.7 tests pass
  - earlier v0.1.x regression tests pass
  - R CMD check passes with 0 errors and 0 warnings
  - coverage gate passes
  - pkgdown builds
  - Ubuntu and Windows CI are green
escalation_triggers: []
forbidden_actions:
  - accepting the gate with open P0 or P1 issues
  - bypassing R CMD check or coverage
  - releasing without green CI
  - accepting accidental v0.1.8 API scope
```

---

## Out Of Scope

Do not implement these in v0.1.7:

- `ledgr_sweep()`;
- `ledgr_precompute_features()`;
- `ledgr_tune()`;
- persistent feature-cache storage;
- walk-forward validation;
- short selling;
- portfolio sizing helpers;
- live trading;
- paper trading;
- broker integrations;
- hard delete;
- vectorized strategy execution.
