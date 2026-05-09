# ledgr v0.1.7.6 Tickets

**Version:** 0.1.7.6
**Date:** May 9, 2026
**Total Tickets:** 6

---

## Ticket Organization

v0.1.7.6 is a persistence-architecture stabilization cycle. The release should
turn the v0.1.7.5 Ubuntu CI lessons into durable contracts, tests, and release
gates without expanding into unrelated documentation or feature work.

Tracks:

1. **Scope and evidence:** classify the post-release DuckDB findings and route
   v0.1.7.5 auditr feedback without turning it into broad docs work.
2. **DuckDB architecture review:** map connections, checkpoints, transactions,
   shutdown ownership, and metadata dependencies.
3. **Persistence contract tests:** keep schema validation metadata-only, prove
   constraint enforcement in isolated databases, and verify fresh-connection
   read-back.
4. **Ubuntu parity gate:** add a small WSL/Ubuntu gate and stop-rule workflow to
   the release playbook.
5. **Release alignment:** update contracts, NEWS, docs, and ticket state.

### Dependency DAG

```text
LDG-1601 -> LDG-1602 -> LDG-1603 -> LDG-1605 -> LDG-1606
LDG-1601 -> LDG-1604 -------------> LDG-1605
LDG-1602 -> LDG-1604
```

`LDG-1606` is the v0.1.7.6 release gate.

### Priority Levels

- **P0 (Blocker):** Required for release correctness or scope coherence.
- **P1 (Critical):** Required for the v0.1.7.6 architecture story to hold.
- **P2 (Important):** Required for release hygiene and future maintainability.
- **P3 (Optional):** Useful, but not a release blocker.

---

## LDG-1601: Scope, Evidence, And auditr Routing Baseline

**Priority:** P0
**Effort:** 0.5-1 day
**Dependencies:** None
**Status:** Done

**Description:**
Finalize the v0.1.7.6 release boundary before implementation. Confirm that the
release is DuckDB persistence architecture work, not a broad documentation
cleanup cycle, and route the v0.1.7.5 auditr findings into the correct later
milestones.

**Tasks:**
1. Review `v0_1_7_6_spec.md`, `duckdb_architecture_review.md`,
   `cycle_retrospective.md`, `ledgr_triage_report.md`, and
   `auditr_v0_1_7_5_followup_plan.md`.
2. Confirm `THEME-010` remains excluded from ledgr handoff unless reframed as
   auditr harness work.
3. Confirm only persistence-adjacent `THEME-005` findings may enter v0.1.7.6.
4. Confirm risk metrics, reproducibility preflight, sweep mode, risk-free-rate
   adapters, and `{talib}` are out of v0.1.7.6 implementation scope.
5. Verify ticket markdown and YAML agree on IDs, dependencies, classifications,
   and forbidden actions.

**Acceptance Criteria:**
- [x] v0.1.7.6 scope is documented as DuckDB persistence architecture work.
- [x] Every auditr theme has a routing decision or explicit exclusion.
- [x] `THEME-010` is excluded from ledgr implementation scope.
- [x] `{talib}` remains issue-draft/contributor context, not release scope.
- [x] Ticket markdown and YAML classifications agree.

**Implementation Notes:**
- Reviewed the v0.1.7.6 spec, DuckDB architecture seed review, auditr
  retrospective, triage report, and follow-up plan.
- Confirmed the current release boundary is DuckDB persistence architecture,
  not broad documentation cleanup.
- Confirmed `THEME-010` is auditr runner/environment scope and excluded from
  ledgr implementation.
- Confirmed `THEME-005` may enter v0.1.7.6 only when directly
  persistence-adjacent: low-level CSV, sealing, sealed metadata, or
  fresh-connection workflows.
- Confirmed risk metrics, reproducibility preflight, sweep mode,
  risk-free-rate adapters, and `{talib}` are excluded from v0.1.7.6
  implementation scope.
- Ran scope and ticket/YAML consistency greps; no production code changed.

**Test Requirements:**
- Documentation consistency scan.
- Spec/ticket filename scan.
- Scope grep for excluded feature work.

**Source Reference:** v0.1.7.6 spec sections 1, 1.1, 2, 3, 7, 8.

**Classification:**
```yaml
risk_level: release-critical
implementation_tier: H
review_tier: H
classification_reason: >
  Version scoping, evidence classification, persistence architecture routing,
  and release-boundary decisions are Tier H by model_routing.md.
invariants_at_risk:
  - release scope
  - evidence quality
  - persistence architecture boundary
  - documentation backlog routing
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_6_spec_packet/v0_1_7_6_spec.md
  - inst/design/ledgr_v0_1_7_6_spec_packet/duckdb_architecture_review.md
  - inst/design/ledgr_v0_1_7_6_spec_packet/cycle_retrospective.md
  - inst/design/ledgr_v0_1_7_6_spec_packet/ledgr_triage_report.md
  - inst/design/ledgr_v0_1_7_6_spec_packet/auditr_v0_1_7_5_followup_plan.md
  - inst/design/contracts.md
  - inst/design/release_ci_playbook.md
tests_required:
  - documentation consistency scan
  - spec/ticket filename scan
  - scope grep for excluded feature work
escalation_triggers:
  - auditr evidence reveals a new runtime defect
  - persistence-adjacent findings require broad docs or API work
  - talib adapter is promoted into current release scope
forbidden_actions:
  - implementing feature work
  - changing execution behavior
  - adding talib adapter APIs
  - adding risk metrics or sweep APIs
  - weakening release gates
```

---

## LDG-1602: DuckDB Connection, Checkpoint, And Transaction Review

**Priority:** P0
**Effort:** 1-2 days
**Dependencies:** LDG-1601
**Status:** Done

**Description:**
Produce the architecture review artifact that maps ledgr's DuckDB connection
ownership, checkpoint behavior, transaction boundaries, shutdown ownership, and
DuckDB metadata-format dependencies.

**Tasks:**
1. Map all public DuckDB entry points: snapshot creation/loading, CSV import,
   sealing, experiments, `ledgr_run()`, result access, run discovery, metadata
   mutation, and executable docs.
2. Build a mutating-API checkpoint matrix with strict vs best-effort behavior.
3. Audit all direct `DBI::dbConnect()`, `dbDisconnect()`, `CHECKPOINT`,
   transaction, temporary view, and `duckdb_register()` paths.
4. Record final decisions for runner checkpoint strictness, shutdown ownership,
   and `duckdb_constraints()` expression parsing.
5. Update `duckdb_architecture_review.md` from seed notes into the final
   decision artifact.

**Acceptance Criteria:**
- [x] Connection-lifecycle map covers all public DuckDB entry points.
- [x] Every durable public write path appears in the checkpoint matrix.
- [x] Every direct connection exception is documented with a reason.
- [x] Multi-statement durable writes have explicit transaction ownership.
- [x] Runner checkpoint strictness decision is recorded.
- [x] Shutdown ownership decision is recorded.
- [x] DuckDB metadata-format dependency and upgrade check are recorded.

**Implementation Notes:**
- Replaced the seed `duckdb_architecture_review.md` with the final LDG-1602
  architecture review artifact.
- Added a connection-lifecycle map for low-level DB init, snapshot creation,
  snapshot load/open/close, runner execution, backtest result reads,
  run-store discovery, mutable run metadata, migration, and executable docs.
- Added a checkpoint matrix that distinguishes best-effort cleanup checkpoints
  from strict user-facing mutation checkpoints.
- Recorded final decisions:
  - keep runner cleanup checkpointing best-effort;
  - keep defensive double-shutdown cleanup;
  - keep `duckdb_constraints()` expression parsing as a
    DuckDB-version-sensitive metadata contract protected by loud failures and
    upgrade checks.
- Audited transaction boundaries by static scan. No production code changes
  were made.
- Follow-up implementation remains in LDG-1603 and LDG-1604.

**Test Requirements:**
- Static scan for DuckDB connection/checkpoint/transaction calls.
- Documentation consistency scan.

**Source Reference:** v0.1.7.6 spec sections 4, A1-A4.

**Classification:**
```yaml
risk_level: release-critical
implementation_tier: H
review_tier: H
classification_reason: >
  DuckDB connection ownership, checkpoints, transactions, and metadata
  dependencies are core persistence architecture and require Tier H review.
invariants_at_risk:
  - DuckDB connection ownership
  - durable write visibility
  - transaction atomicity
  - snapshot and run-store persistence
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_6_spec_packet/v0_1_7_6_spec.md
  - inst/design/ledgr_v0_1_7_6_spec_packet/duckdb_architecture_review.md
  - inst/design/contracts.md
  - R/
tests_required:
  - static DuckDB call scan
  - documentation consistency scan
escalation_triggers:
  - review reveals missing checkpoint on public write path
  - review reveals transaction boundary bug
  - resolving a finding requires touching more than three production files
forbidden_actions:
  - speculative broad persistence edits
  - changing runner execution semantics
  - changing snapshot hash semantics
  - weakening tests to match current behavior
```

---

## LDG-1603: Schema Validation And Constraint Enforcement Tests

**Priority:** P0
**Effort:** 1-2 days
**Dependencies:** LDG-1602
**Status:** Done

**Description:**
Lock the separation between runtime schema validation and constraint
enforcement testing. Runtime validators inspect metadata only; live DML
constraint checks happen only in isolated disposable databases.

**Tasks:**
1. Verify runtime schema validation is read-only with respect to ledgr data
   rows.
2. Extend side-effect tests so repeated schema validation leaves core table row
   counts unchanged.
3. Ensure invalid `runs.status` values are rejected in isolated tests.
4. Add the missing isolated live DML test for invalid `snapshots.status`
   values.
5. Confirm valid status values needed by normal workflows remain accepted.
6. Harden or document any create-side DuckDB metadata fallback that could
   silently trigger destructive table recreation if `duckdb_constraints()`
   changes shape.

**Acceptance Criteria:**
- [x] Runtime schema validation performs no invalid-row DML probes.
- [x] Schema validation can run repeatedly on one connection without dirtying
      connection state.
- [x] Core ledgr table row counts are unchanged before and after validation.
- [x] Invalid `runs.status` values are rejected by DuckDB in an isolated test.
- [x] Invalid `snapshots.status` values are rejected by DuckDB in an isolated
      test.
- [x] DuckDB constraint metadata lookup failures fail loudly or are explicitly
      documented as safe.

**Implementation Notes:**
- Hardened the create-side `runs.status` metadata parser in
  `R/db-schema-create.R`: if `duckdb_constraints()` returns a status-related
  CHECK expression that is not the expected `status IN (...)` shape, schema
  creation now fails loudly instead of silently recreating `runs`.
- Kept no-constraint and old-enum migration behavior intact. Existing
  `COMPLETED`-to-`DONE` migration still uses the interpretable `IN (...)`
  expression path.
- Strengthened `runs.status` and `snapshots.status` DML tests to assert all
  valid status values and to issue safe `ROLLBACK` calls after expected
  constraint violations so later assertions do not inherit dirty DuckDB
  transaction state under Linux/covr.
- Added create-side coverage proving an unexpected status CHECK expression
  fails loudly and preserves the existing `runs` row.
- Confirmed the side-effect validator test already covers repeated validation
  without row mutations across `runs`, `snapshots`, `features`, and
  `ledger_events`.

**Test Requirements:**
- `tests/testthat/test-schema-validator-side-effects.R`
- `tests/testthat/test-schema.R`
- `tests/testthat/test-schema-snapshots.R`
- Targeted schema tests under local Windows and WSL/Ubuntu where available.

**Verification:**
```text
pkgload::load_all('.', quiet=TRUE);
testthat::test_file('tests/testthat/test-schema-validator-side-effects.R');
testthat::test_file('tests/testthat/test-schema-snapshots.R');
testthat::test_file('tests/testthat/test-schema.R')
```

Result: all targeted schema tests passed on Windows.

**Source Reference:** v0.1.7.6 spec sections R2, R5, B1-B3.

**Classification:**
```yaml
risk_level: release-critical
implementation_tier: H
review_tier: H
classification_reason: >
  Schema creation, validation, and DuckDB constraint checks affect package
  persistence safety and caused prior Ubuntu release-gate failures.
invariants_at_risk:
  - schema validation read-only contract
  - constraint enforcement
  - DuckDB connection state
  - migration safety
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_6_spec_packet/v0_1_7_6_spec.md
  - inst/design/contracts.md (Persistence Contract)
  - R/db-schema-create.R
  - R/db-schema-validate.R
  - tests/testthat/test-schema.R
  - tests/testthat/test-schema-snapshots.R
  - tests/testthat/test-schema-validator-side-effects.R
tests_required:
  - tests/testthat/test-schema-validator-side-effects.R
  - tests/testthat/test-schema.R
  - tests/testthat/test-schema-snapshots.R
escalation_triggers:
  - schema validation requires writing probe rows
  - DuckDB metadata APIs cannot identify constraints reliably
  - fixing the test requires broad schema migration changes
forbidden_actions:
  - invalid-row probes in runtime validators
  - silent destructive table recreation on metadata lookup failure
  - weakening constraint tests
  - changing public snapshot or run status values without a spec update
```

---

## LDG-1604: Fresh-Connection Persistence And Local Ubuntu Gate

**Priority:** P1
**Effort:** 1-2 days
**Dependencies:** LDG-1601, LDG-1602
**Status:** Done

**Description:**
Prove the persistence paths that historically diverged between Windows and
Ubuntu: completed run read-back from a fresh connection, low-level CSV
snapshot create/import/seal/load, and pkgdown-sensitive executable workflows.
Document the local WSL/Ubuntu gate in the release playbook.

**Tasks:**
1. Add or confirm fresh-connection read-back tests for completed run artifacts.
2. Add or confirm fresh-connection read-back tests for public run metadata
   mutations that promise immediate durability.
3. Add or confirm low-level CSV create/import/seal/load tests after closing and
   reopening the database.
4. Define the narrow local WSL/Ubuntu DuckDB gate in `release_ci_playbook.md`.
5. Ensure the playbook states that local WSL evidence does not replace remote
   branch, main, or tag CI.

**Acceptance Criteria:**
- [x] Completed run artifacts are visible from a fresh connection after
      `ledgr_run()` returns.
- [x] Durable run metadata mutations are visible from a fresh connection.
- [x] Low-level CSV snapshot create/import/seal/load works after reopen.
- [x] The local WSL/Ubuntu gate lists targeted tests or command classes.
- [x] The playbook says when the local Linux gate is required.
- [x] The playbook preserves remote branch, main, and tag CI as separate gates.

**Implementation Notes:**
- Added `tests/testthat/test-persistence-fresh-connection.R`.
- The new run-artifact test opens a fresh DuckDB connection after
  `ledgr_run()` returns and verifies the completed run row, identity hashes,
  ledger events, and equity curve are visible.
- The new metadata test verifies `ledgr_run_label()`, `ledgr_run_archive()`,
  `ledgr_run_tag()`, and `ledgr_run_untag()` are visible through a fresh
  connection after the public mutation APIs return.
- The new low-level CSV test exercises create -> import -> seal -> disconnect
  -> `ledgr_snapshot_load(verify = TRUE)` -> `ledgr_run()` -> fresh-connection
  read-back.
- Updated `release_ci_playbook.md` with a local WSL/Ubuntu DuckDB gate, the
  ticket classes that require it, and the rule that local Linux evidence does
  not replace branch, `main`, or tag CI.

**Test Requirements:**
- Fresh-connection run artifact tests.
- Snapshot CSV create/import/seal/load tests.
- Targeted local WSL/Ubuntu command when available.

**Verification:**
```text
pkgload::load_all('.', quiet=TRUE);
testthat::test_file('tests/testthat/test-persistence-fresh-connection.R')
```

Result: passed on Windows.

```text
pkgload::load_all('.', quiet=TRUE);
testthat::test_file('tests/testthat/test-schema-validator-side-effects.R');
testthat::test_file('tests/testthat/test-schema-snapshots.R');
testthat::test_file('tests/testthat/test-schema.R');
testthat::test_file('tests/testthat/test-snapshot-adapters.R');
testthat::test_file('tests/testthat/test-run-store.R');
testthat::test_file('tests/testthat/test-run-metadata.R');
testthat::test_file('tests/testthat/test-run-tags.R')
```

Result: passed on Windows. One expected optional-package-path skip occurred in
`test-snapshot-adapters.R`. Local WSL execution was not available in this
session: `wsl.exe -l -v` returned `E_ACCESSDENIED`.

**Source Reference:** v0.1.7.6 spec sections R3, 6, B4, C1-C3.

**Classification:**
```yaml
risk_level: high
implementation_tier: H
review_tier: H
classification_reason: >
  Fresh-connection read-back, CSV snapshot workflows, and Ubuntu parity gates
  are persistence-sensitive and release-gate-sensitive.
invariants_at_risk:
  - completed run durability
  - snapshot seal/load durability
  - cross-connection visibility
  - release CI discipline
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_6_spec_packet/v0_1_7_6_spec.md
  - inst/design/release_ci_playbook.md
  - inst/design/contracts.md (Persistence Contract, Snapshot Contract)
  - R/backtest-runner.R
  - R/run-store.R
  - R/snapshot*.R
  - tests/testthat/
tests_required:
  - fresh-connection run artifact tests
  - snapshot CSV create/import/seal/load tests
  - targeted local WSL/Ubuntu gate when available
escalation_triggers:
  - fresh connections miss committed writes
  - checkpoint placement requires runner or snapshot redesign
  - WSL reproduces a different failure than remote CI
forbidden_actions:
  - broad release-gate surgery
  - weakening Ubuntu gates
  - changing snapshot hashes for visibility convenience
  - treating local WSL as a replacement for remote CI
```

---

## LDG-1605: Contracts, NEWS, Roadmap, And Release-Hygiene Alignment

**Priority:** P2
**Effort:** 0.5-1 day
**Dependencies:** LDG-1603, LDG-1604
**Status:** Done

**Description:**
Align the written package contracts and release-facing documentation with the
final v0.1.7.6 persistence decisions.

**Tasks:**
1. Update `contracts.md` with the final persistence invariants.
2. Update `release_ci_playbook.md` with the WSL/Ubuntu gate and stop-rule
   details from the implemented tickets.
3. Add or update the `NEWS.md` v0.1.7.6 section.
4. Confirm `ledgr_roadmap.md` reflects v0.1.7.6, v0.1.7.7, v0.1.7.8,
   v0.1.8, and v0.1.8.1 sequencing.
5. Update `v0_1_7_6_tickets.md` and `tickets.yml` statuses together.

**Acceptance Criteria:**
- [x] `contracts.md` matches final persistence behavior.
- [x] `release_ci_playbook.md` names the local WSL/Ubuntu gate and stop rule.
- [x] `NEWS.md` summarizes delivered v0.1.7.6 scope.
- [x] Roadmap sequencing is coherent and does not make `{talib}` a release
      blocker.
- [x] Ticket markdown and YAML statuses agree.

**Implementation Notes:**
- Added the v0.1.7.6 `NEWS.md` section covering the DuckDB architecture review,
  read-only schema validation boundary, isolated status constraint tests,
  fresh-connection persistence tests, local WSL/Ubuntu gate, and auditr routing.
- Updated `contracts.md` with the final v0.1.7.6 persistence invariants:
  read-only runtime validation, loud DuckDB metadata failures,
  fresh-connection visibility, strict public metadata-write durability,
  best-effort cleanup checkpoint limits, and low-level CSV reopen behavior.
- Confirmed `release_ci_playbook.md` names the local WSL/Ubuntu DuckDB gate,
  stop rule, and separate branch/`main`/tag CI gates.
- Confirmed `ledgr_roadmap.md` keeps v0.1.7.6, v0.1.7.7, v0.1.7.8, v0.1.8,
  and v0.1.8.1 sequencing coherent and does not make `{talib}` a release
  blocker.
- Added documentation-contract tests for the v0.1.7.6 NEWS, contracts,
  playbook, and roadmap invariants.

**Test Requirements:**
- Documentation contract scans if tests exist.
- NEWS section scan.
- Ticket/YAML consistency scan.

**Verification:**
```text
pkgload::load_all('.', quiet=TRUE);
testthat::test_file('tests/testthat/test-documentation-contracts.R')
```

Result: passed on Windows.

**Source Reference:** v0.1.7.6 spec sections 8, 9.

**Classification:**
```yaml
risk_level: medium
implementation_tier: M
review_tier: H
classification_reason: >
  Documentation and release-hygiene work, but it records persistence contracts
  and release gates. Tier H review is required.
invariants_at_risk:
  - persistence contract documentation
  - release gate documentation
  - roadmap sequencing
  - ticket state accuracy
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_6_spec_packet/v0_1_7_6_spec.md
  - inst/design/contracts.md
  - inst/design/release_ci_playbook.md
  - inst/design/ledgr_roadmap.md
  - NEWS.md
tests_required:
  - documentation contract scans if applicable
  - NEWS section scan
  - ticket/YAML consistency scan
escalation_triggers:
  - docs imply unimplemented persistence behavior
  - NEWS claims a shipped feature not implemented
  - talib or sweep work becomes release-critical
forbidden_actions:
  - implementing non-persistence features
  - making talib a release blocker
  - weakening release gates
```

---

## LDG-1606: v0.1.7.6 Release Gate

**Priority:** P0
**Effort:** 1 day
**Dependencies:** LDG-1605
**Status:** Todo

**Description:**
Run the v0.1.7.6 release gate according to the release CI playbook. Do not
perform broad release-gate surgery. If a gate exposes a new core design issue,
stop and create a blocker ticket.

**Tasks:**
1. Confirm every v0.1.7.6 ticket is done and status matches in markdown/YAML.
2. Run targeted schema, snapshot, and fresh-connection persistence tests.
3. Run full local Windows package tests.
4. Run `R CMD check --no-manual --no-build-vignettes`.
5. Run coverage gate if executable code changed in a way that affects coverage.
6. Run pkgdown build if documentation or executable vignettes changed.
7. Run the local WSL/Ubuntu gate when available.
8. Push branch and wait for branch CI.
9. Merge only after branch CI is green.
10. Wait for main CI and tag-triggered CI before considering the release valid.

**Acceptance Criteria:**
- [ ] All v0.1.7.6 ticket statuses are complete and synchronized.
- [x] Targeted persistence tests pass.
- [x] Full local Windows tests pass.
- [x] `R CMD check --no-manual --no-build-vignettes` passes.
- [x] Coverage and pkgdown gates pass when required.
- [x] Local WSL/Ubuntu gate passes when required and available.
- [ ] Remote branch CI is green.
- [ ] Main CI is green after merge.
- [ ] Tag-triggered CI is green before release is declared valid.

**Implementation Notes:**
- Bumped `DESCRIPTION` to `0.1.7.6`.
- Updated README source and rendered README to point to the current v0.1.7.6
  design packet.
- Local WSL was not available in this session: `wsl.exe -l -v` returned
  `E_ACCESSDENIED`. Per the playbook, this is recorded as unavailable local
  evidence, not as a replacement for remote CI.

**Verification:**
```text
pkgload::load_all('.', quiet=TRUE);
testthat::test_file('tests/testthat/test-schema-validator-side-effects.R');
testthat::test_file('tests/testthat/test-schema-snapshots.R');
testthat::test_file('tests/testthat/test-schema.R');
testthat::test_file('tests/testthat/test-persistence-fresh-connection.R');
testthat::test_file('tests/testthat/test-documentation-contracts.R')
```

Result: passed on Windows.

```text
pkgload::load_all('.', quiet=TRUE);
testthat::test_local('.', reporter='summary')
```

Result: passed on Windows. One expected optional-package-path skip occurred in
`test-snapshot-adapters.R`.

```text
R CMD build .
R CMD check --no-manual --no-build-vignettes ledgr_0.1.7.6.tar.gz
```

Result: passed on Windows with `Status: OK`. The first build attempt failed
because Pandoc was not on R's path; rerunning with the local `RSTUDIO_PANDOC`
path succeeded. `R CMD check` emitted repository-index warnings from offline
package index access and a Windows `du` warning, but returned `Status: OK`.

```text
Rscript tools/check-coverage.R
```

Result: passed on Windows with `ledgr coverage: 84.47%`.

```text
pkgdown::build_site(new_process = FALSE)
```

Result: passed on Windows in normal install mode. The sandboxed
`install = FALSE` shortcut failed while rendering `experiment-store.Rmd`, and
the sandboxed normal install-mode run failed with `EPERM` while statting the
user directory. The same normal install-mode pkgdown gate passed outside the
sandbox.

**Test Requirements:**
- Targeted schema/persistence tests.
- Full local test suite.
- R CMD check.
- Coverage if needed.
- pkgdown if docs changed.
- Local WSL/Ubuntu gate when applicable.
- Remote branch/main/tag CI.

**Source Reference:** v0.1.7.6 spec section 9.

**Classification:**
```yaml
risk_level: release-critical
implementation_tier: H
review_tier: H
classification_reason: >
  Release gates, CI interpretation, tag movement, and persistence-sensitive
  validation are Tier H and must follow the release CI playbook.
invariants_at_risk:
  - release validity
  - CI discipline
  - persistence parity
  - tag correctness
required_context:
  - inst/design/model_routing.md
  - inst/design/ledgr_v0_1_7_6_spec_packet/v0_1_7_6_spec.md
  - inst/design/ledgr_v0_1_7_6_spec_packet/v0_1_7_6_tickets.md
  - inst/design/ledgr_v0_1_7_6_spec_packet/tickets.yml
  - inst/design/release_ci_playbook.md
tests_required:
  - targeted schema/persistence tests
  - full local test suite
  - R CMD check
  - coverage if required
  - pkgdown if required
  - local WSL/Ubuntu gate when applicable
  - remote CI
escalation_triggers:
  - Ubuntu failure points to broad core infrastructure
  - CI failure cannot be reproduced narrowly
  - fix expands outside initially failing subsystem
  - main and tag CI disagree
forbidden_actions:
  - broad release-gate surgery
  - moving a release tag before main CI is green
  - declaring release valid before tag CI is green
  - weakening tests to pass CI
```
