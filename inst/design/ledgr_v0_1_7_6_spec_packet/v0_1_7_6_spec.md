# ledgr v0.1.7.6 Spec

**Status:** Draft
**Target Version:** v0.1.7.6
**Scope:** DuckDB persistence architecture review, Ubuntu parity gate, and
curated routing of the v0.1.7.5 auditr reports
**Inputs:**

- `inst/design/ledgr_v0_1_7_6_spec_packet/duckdb_architecture_review.md`
- `inst/design/ledgr_v0_1_7_6_spec_packet/cycle_retrospective.md`
- `inst/design/ledgr_v0_1_7_6_spec_packet/ledgr_triage_report.md`
- `inst/design/ledgr_v0_1_7_6_spec_packet/auditr_v0_1_7_5_followup_plan.md`
- `inst/design/contracts.md`
- `inst/design/release_ci_playbook.md`
- `inst/design/ledgr_v0_1_7_5_spec_packet/v0_1_7_5_spec.md`
- `inst/design/ledgr_roadmap.md`

---

## 1. Purpose

v0.1.7.6 is an architecture-stabilization release.

v0.1.7.5 fixed and hardened a large amount of user-facing surface: TTR warmup,
warmup diagnostics, result inspection, low-level CSV documentation, feature-map
discovery, and adapter positioning. During the release gate, Ubuntu CI again
exposed DuckDB behavior that Windows did not surface early enough.

The lesson is not that Ubuntu is noisy. The lesson is that Ubuntu CI caught real
persistence design pressure. v0.1.7.6 turns that release-gate experience into a
deliberate architecture review so future releases do not require broad,
last-minute edits to schema, persistence, runner, or snapshot code.

The release should make DuckDB persistence boring before v0.1.8 adds sweep-mode
pressure around the execution core.

---

## 1.1 Evidence Baseline

The main evidence is the post-v0.1.7.5 DuckDB architecture review and release
CI post-mortem.

The v0.1.7.5 auditr retrospective and triage report are also included in this
spec packet. They are dominated by documentation and discoverability findings,
not confirmed runtime defects. They must be routed, not automatically promoted
into v0.1.7.6 implementation scope.

| Evidence | Baseline classification | v0.1.7.6 handling |
| --- | --- | --- |
| DuckDB cross-connection write visibility | Resolved issue class; needs durable contract and tests | Review checkpoint ownership and fresh-connection read-back coverage. |
| Mutating runtime constraint probes | Resolved design defect; runtime validation must be metadata-only | Preserve read-only validation contract and keep DML enforcement tests isolated. |
| Complex DuckDB metadata SQL under Ubuntu | Resolved issue class; prefer simple reads plus R-side enrichment | Preserve and document query-shape rule for metadata reads. |
| Runner checkpoint strictness | Residual architecture decision | Decide whether non-strict runner cleanup checkpointing is the final contract or should become strict. |
| Shutdown ownership | Residual architecture decision | Decide whether double-shutdown cleanup remains defensive or should be simplified. |
| DuckDB constraint expression parsing | Residual dependency risk | Record DuckDB-upgrade verification for `duckdb_constraints()` output format. |
| v0.1.7.5 auditr `THEME-010` | Auditr runner/environment friction | Excluded from ledgr handoff unless reframed as auditr harness work. |
| v0.1.7.5 auditr documentation themes | Mostly docs/discoverability backlog | Route to v0.1.7.7, v0.1.7.8, v0.1.8, or docs backlog; pull into v0.1.7.6 only when persistence-adjacent. |
| `{talib}` adapter opportunity | External PR opportunity, not release driver | Keep as an issue draft; do not make it a blocker for v0.1.7.6. |

---

## 2. Release Shape

v0.1.7.6 has four coordinated tracks.

### Track A - DuckDB Persistence Architecture Review

Map connection ownership, transaction boundaries, checkpoint behavior,
fresh-connection read-back, and schema-validation responsibilities across the
current package.

The output is a written architecture decision record, not an exploratory patch
set. Broad persistence changes require a ticket, a problem statement, and a
definition of done.

### Track B - Persistence Contract And Tests

Update contracts and tests to lock the final decisions from Track A.

Tests should prove the package contract without reintroducing runtime mutation
probes. Constraint enforcement belongs in isolated disposable databases.
Runtime schema validation remains metadata-only.

### Track C - Local Ubuntu/WSL Parity Gate

Define a small local Linux gate that exercises historically fragile paths before
remote CI:

- schema creation and validation;
- low-level CSV snapshot create/import/seal/load;
- completed run read-back from a fresh connection;
- pkgdown-sensitive executable documentation paths when docs changed.

This gate is not a replacement for remote CI, but it should catch likely
cross-platform issues before release-gate debugging starts.

### Track D - auditr Report Routing

Curate the v0.1.7.5 auditr retrospective and triage report. Keep v0.1.7.6
focused on persistence architecture. Route the rest to later milestones.

Only persistence-adjacent items, especially parts of `THEME-005` around
low-level CSV, sealing, sealed metadata, and fresh-connection workflows, may be
pulled into current-version implementation.

---

## 3. Hard Requirements

### R1 - No Release-Gate Surgery

If Ubuntu CI exposes a problem that appears to require broad edits to schema
creation, schema validation, snapshots, persistence, runner behavior, or other
core infrastructure, stop and create a blocker ticket.

The blocker ticket must include:

- failed CI run ID and first package stack frame;
- exact failing command or narrow local reproduction;
- smallest evidence for the suspected root cause;
- owning files;
- definition of done;
- rollback or containment plan.

Getting CI green is not more important than preserving architectural clarity.
The release gate did its job when it exposed a design issue.

### R2 - Runtime Schema Validation Is Metadata-Only

Runtime schema creation and validation may inspect DuckDB metadata. They must
not write invalid rows into persistent ledgr tables to prove constraints.

Constraint enforcement tests belong in isolated disposable DuckDB databases.
Those tests may intentionally trigger DML failures, but they must not share
their dirty connection state with runtime validators or later probes.

### R3 - Fresh-Connection Visibility Is A Persistence Contract

When a public write API returns and the user can reasonably inspect the result
through a new handle, the data must be visible from a fresh connection.

This applies to completed run artifacts and user-facing metadata mutations such
as labels, archive state, tags, or similar durable store updates.

The release must define where checkpointing is required, where best-effort
cleanup is sufficient, and which tests prove the contract.

### R4 - Transaction Boundaries Are Explicit

Multi-statement durable writes must use explicit transaction boundaries unless
there is a documented reason not to.

Migration and seal-style transitions must preserve all-or-nothing behavior.
Version or status markers should be written only after the data shape they
describe is in place.

### R5 - DuckDB Metadata Dependencies Are Versioned Assumptions

DuckDB metadata table functions such as `duckdb_constraints()` are acceptable
dependencies because ledgr is a DuckDB-backed package. But any parsing of
textual metadata, especially constraint expression text, must be documented as a
DuckDB-version-sensitive assumption.

The release must define how that assumption is checked during DuckDB upgrades.

### R6 - auditr Reports Are Routed Before Promotion

The v0.1.7.5 auditr reports are inputs, not tickets. Every theme promoted to
implementation must be classified as:

- confirmed ledgr bug;
- persistence-contract gap;
- documentation mismatch;
- expected user error with weak messaging;
- auditr harness or task-environment issue;
- no longer reproducible.

`THEME-010` is excluded from ledgr scope unless explicitly reframed as auditr
harness work.

### R7 - No Scope Expansion Into v0.1.7.7 Or v0.1.8 Work

v0.1.7.6 must not implement risk metrics, strategy reproducibility preflight,
sweep mode, risk-free-rate adapters, or the `{talib}` adapter.

It may document how those later milestones depend on the persistence contract.

---

## 4. Track A Scope - DuckDB Architecture Review

### A1 - Connection-Lifecycle Map

Produce a map of public entry points that open, close, or reuse DuckDB
connections.

At minimum, cover:

- snapshot creation;
- snapshot loading;
- low-level CSV import;
- snapshot sealing;
- experiment creation;
- `ledgr_run()`;
- result access;
- run discovery;
- run metadata mutation;
- pkgdown/vignette workflows that execute DuckDB-backed examples.

Acceptance points:

- each entry states who owns the connection;
- each entry states whether the connection is long-lived or operation-scoped;
- each entry states whether `dbDisconnect(..., shutdown = TRUE)` is used;
- direct `DBI::dbConnect()` exceptions are documented with a reason.

### A2 - Checkpoint Matrix

Produce a mutating-API checkpoint matrix.

Acceptance points:

- every public durable write path is listed;
- the matrix states whether it checkpoints before returning;
- the matrix states whether checkpointing is strict or best-effort;
- every best-effort checkpoint has a reason;
- every strict checkpoint has a test or contract explaining why failure should
  be loud.

### A3 - Transaction Audit

Audit multi-statement durable writes.

Acceptance points:

- multi-statement writes use `DBI::dbWithTransaction()` or an equivalent
  explicit transaction;
- migration version markers are written last;
- snapshot seal transitions remain atomic;
- no transaction is left dirty after expected validation failures.

### A4 - Residual Architecture Decisions

Record final decisions for:

- runner checkpoint strictness;
- shutdown ownership and redundant shutdown calls;
- DuckDB constraint expression parsing and upgrade checks.

Acceptance points:

- each decision names the chosen behavior;
- each decision names the alternative considered;
- each decision states what test, contract, or playbook rule protects it.

---

## 5. Track B Scope - Contracts And Tests

### B1 - Persistence Contract Update

Update `inst/design/contracts.md` after Track A decisions.

Acceptance points:

- runtime schema validation remains read-only with respect to data rows;
- fresh-connection visibility is explicit;
- checkpoint ownership is explicit;
- constraint enforcement testing remains isolated from runtime validation.

### B2 - Schema Validation Side-Effect Tests

Ensure schema validation does not mutate user ledgr rows.

Acceptance points:

- validation can be run repeatedly on the same connection;
- row counts in core ledgr tables remain unchanged;
- tests cover all tables previously touched by validator probes;
- tests fail if runtime validation reintroduces invalid-row DML probes.

### B3 - Constraint Enforcement Tests

Keep live DML constraint tests in isolated disposable databases.

Acceptance points:

- `runs.status` invalid values are rejected;
- `snapshots.status` invalid values are rejected;
- valid status values needed by normal workflows are accepted;
- failed DML probes do not contaminate later assertions on the same connection,
  or each probe owns its own disposable connection.

### B4 - Fresh-Connection Read-Back Tests

Add or confirm tests proving durable state is visible from a fresh connection.

Acceptance points:

- completed run artifacts are visible from a fresh connection;
- run metadata mutations that promise immediate visibility are visible from a
  fresh connection;
- low-level CSV create/import/seal/load works after closing and reopening;
- tests cover the code paths used by pkgdown or installed examples when those
  examples exercise persistence.

---

## 6. Track C Scope - Local Ubuntu/WSL Parity Gate

### C1 - Gate Definition

Define the local Linux gate in `release_ci_playbook.md`.

Acceptance points:

- the gate lists exact commands or command classes;
- the gate distinguishes targeted tests from full release checks;
- the gate states when it is required before push;
- the gate does not pretend to replace remote branch, main, or tag CI.

### C2 - Narrow DuckDB Gate

The local Linux gate must include a narrow DuckDB-sensitive subset.

Acceptance points:

- schema validation side-effect test;
- snapshot schema constraint tests;
- low-level CSV snapshot workflow;
- fresh-connection completed-run visibility;
- any pkgdown executable example that historically failed under Ubuntu.

### C3 - Stop Rule Reinforcement

The playbook must preserve the Ubuntu CI surgery stop rule.

Acceptance points:

- broad core edits during release-gate debugging require a blocker ticket;
- release tag is not valid until blocker is resolved and required gates are
  green;
- remote failed logs define initial scope;
- a one-sentence hypothesis is written before editing.

---

## 7. Track D Scope - auditr Routing

### D1 - Follow-Up Plan

Create a routing artifact for the v0.1.7.5 auditr reports.

Acceptance points:

- every ledgr-facing theme has a routing decision;
- `THEME-010` is excluded from ledgr implementation scope;
- broad documentation themes are deferred to the appropriate later milestone;
- only persistence-adjacent findings are eligible for v0.1.7.6 work.

### D2 - Persistence-Adjacent Pull-In

Review `THEME-005` only for current-version persistence relevance.

Acceptance points:

- low-level CSV workflow findings are checked against the current v0.1.7.5
  docs and tests before new work is created;
- sealed metadata inspection findings are checked against current
  `ledgr_snapshot_info()` behavior;
- any new implementation work has a narrow ticket and test target.

### D3 - Future Milestone Routing

Do not lose the rest of the auditr report.

Acceptance points:

- metrics and comparison findings route to v0.1.7.7 or later docs backlog;
- strategy/feature-map dependency findings route to v0.1.7.8;
- parameter-grid and candidate-promotion findings route to v0.1.8;
- first-path and help-page discovery findings remain backlog unless still
  reproducible after v0.1.7.5.

---

## 8. Non-Goals

v0.1.7.6 must stay focused:

- no risk metric implementation;
- no Sharpe ratio implementation;
- no risk-free-rate adapters;
- no sweep/tune implementation;
- no strategy reproducibility preflight implementation;
- no `{talib}` adapter implementation;
- no broad documentation rewrite;
- no visualization layer;
- no changes to fill timing, ledger accounting, target validation, or strategy
  execution semantics unless a narrow confirmed persistence bug requires it;
- no weakening of Ubuntu, coverage, pkgdown, or release-gate tests to pass CI.

The `{talib}` adapter issue draft may exist in this spec packet as contributor
coordination context. It is not part of the v0.1.7.6 release gate.

---

## 9. Release Gate

The release is not ready until:

- the DuckDB architecture review is finalized under `inst/design/`;
- connection ownership, checkpoint behavior, transaction boundaries, and schema
  validation responsibilities are documented;
- residual decisions on runner checkpoint strictness, shutdown ownership, and
  DuckDB metadata-format assumptions are recorded;
- `contracts.md` matches the final persistence decisions;
- `release_ci_playbook.md` includes the local WSL/Ubuntu parity gate and the
  Ubuntu CI surgery stop rule;
- schema validation has no row side effects;
- constraint enforcement is tested only through isolated disposable DML tests;
- `snapshots.status` and `runs.status` invalid-value enforcement are tested;
- completed run artifacts are visible from a fresh connection;
- low-level CSV create/import/seal/load works from a fresh connection;
- the v0.1.7.5 auditr reports are routed and `THEME-010` remains excluded from
  ledgr handoff;
- broad documentation themes are deferred rather than absorbed into v0.1.7.6;
- full Windows checks pass;
- local WSL/Ubuntu checks pass for DuckDB-sensitive changes;
- remote branch CI is green before merge;
- `main` CI and tag-triggered CI are green before the release is considered
  valid.
