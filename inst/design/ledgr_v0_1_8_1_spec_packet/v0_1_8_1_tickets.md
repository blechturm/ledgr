# ledgr v0.1.8.1 Tickets

Version: v0.1.8.1  
Date: 2026-05-16  
Total Tickets: 11

## Ticket Organization

This ticket packet implements the scoped v0.1.8.1 plan from
`v0_1_8_1_spec.md`: auditr-driven stabilization, documentation and diagnostic
polish, and the accepted multi-output indicator bundle authoring UX.

Roadmap work explicitly deferred by the spec is not part of this packet:
metric context/risk-free-rate storage, sweep optimization, parameter-grid QoL,
parallel sweep, target-risk policy layers, execution-policy/OMS work,
walk-forward validation, and random-slice validation.

Track 1 is a gate. LDG-2202 through LDG-2210 are cut here as draft
implementation tracks, but LDG-2201 must complete before implementation work
begins on them.

## Dependency DAG

```
LDG-2201 Scope routing gate
  |-- LDG-2202 Feature lifecycle and warmup guide
  |-- LDG-2203 Runnable examples and first-run workflows
  |-- LDG-2204 Result inspection and metrics schemas
  |-- LDG-2205 Strategy helper pipeline documentation
  |-- LDG-2206 Sweep documentation polish
  |-- LDG-2207 Snapshot metadata and CSV walkthrough
  |-- LDG-2208 Warning and error message polish
  |-- LDG-2209 Discoverability and version labels
  `-- LDG-2210 Multi-output indicator bundle authoring UX

LDG-2211 Release gate depends on LDG-2202 through LDG-2210.
```

## Priority Levels

- P0: Release gate or scope gate.
- P1: User-facing correctness, teachability, or new accepted public surface.
- P2: Documentation polish and discoverability improvements.

---

## LDG-2201: Scope Routing And Ticket Synchronization

Priority: P0  
Effort: S  
Dependencies: none  
Status: Not Started

### Description

Close the v0.1.8.1 routing gate before any implementation tickets begin. This
ticket converts the auditr triage, current spec, accepted syntheses, and roadmap
constraints into a synchronized active packet and records decisions for all
missing-api rows.

### Tasks

- Review `v0_1_8_1_spec.md`, `ledgr_triage_report.md`,
  `categorized_feedback.yml`, `inst/design/README.md`, and
  `inst/design/ledgr_roadmap.md`.
- Confirm that every auditr theme is routed to a v0.1.8.1 ticket, deferred to a
  named future milestone, or explicitly rejected as out of scope.
- Record maintainer decisions for missing-api rows, especially
  `ledgr_results(bt, what = "features")`, final-equity shortcuts, annualization
  constants, and public causal validators.
- Confirm that no v0.1.8.2+ roadmap feature has been pulled into this packet.
- Keep `v0_1_8_1_tickets.md` and `tickets.yml` synchronized.

### Acceptance Criteria

- Track 1 decisions are recorded in this packet or the spec packet notes before
  LDG-2202 through LDG-2210 begin.
- Every auditr theme has an explicit disposition.
- Missing-api rows have an explicit maintainer disposition: implement now,
  defer to a named future milestone, or reject.
- No runtime source files are changed by this ticket.
- `v0_1_8_1_tickets.md` and `tickets.yml` agree on ticket IDs, titles,
  dependencies, priorities, and statuses.

### Verification

- Manual cross-check against the triage report and spec.
- `git diff --check`.

### Source Reference

- `inst/design/ledgr_v0_1_8_1_spec_packet/v0_1_8_1_spec.md`
- `inst/design/ledgr_v0_1_8_1_spec_packet/ledgr_triage_report.md`
- `inst/design/ledgr_v0_1_8_1_spec_packet/categorized_feedback.yml`

### Classification

```yaml
type: governance
surface: design_packet
scope: v0.1.8.1
```

---

## LDG-2202: Feature Lifecycle And Warmup Guide

Priority: P1  
Effort: M  
Dependencies: LDG-2201  
Status: Not Started

### Description

Create installed, user-facing guidance for feature lifecycle, indicator
contracts, feature IDs, aliases, warmup behavior, current-bar semantics, and
feature inspection. Coordinate the guide with LDG-2210 so multi-output bundles
are taught as ordinary feature declarations rather than a second runtime feature
system.

### Tasks

- Add or update an installed article/vignette section that explains the feature
  lifecycle from declaration to precompute to strategy lookup.
- Document accepted feature declaration shapes, including map/list shapes,
  built-in adapters, custom indicator signatures, and factory strategies.
- Explain generated feature IDs, aliases, duplicate replacement behavior, and
  output-specific fingerprints.
- Document warmup behavior, current-bar semantics, and what a strategy can
  observe through `ctx$feature()`.
- Document feature inspection and diagnosis paths.
- Coordinate with LDG-2210 so bundle flattening, bundle-derived feature IDs, and
  when to use bundle helpers versus single-output adapters are covered once in
  the right place.

### Acceptance Criteria

- Users can understand how a declared feature becomes a strategy-visible
  feature value without reading design files.
- The guide covers warmup, current-bar semantics, aliases, feature IDs,
  fingerprints, custom indicator signatures, and factory materialization.
- The guide either includes the LDG-2210 bundle UX or clearly links to the
  bundle help pages once that ticket lands.
- Relevant help pages link to the guide using installed vignette paths.
- Documentation contract tests cover the important user-facing claims.

### Verification

- Targeted documentation contract tests.
- `R CMD build` or documentation generation checks as appropriate.

### Source Reference

- THEME-002
- THEME-009
- `rfc/rfc_multi_output_indicator_ux_synthesis.md`

### Classification

```yaml
type: documentation
surface: features
scope: installed_docs
```

---

## LDG-2203: Runnable Examples And First-Run Workflows

Priority: P1  
Effort: M  
Dependencies: LDG-2201  
Status: Not Started

### Description

Make advertised first-run and tutorial examples runnable, current, and useful as
copyable workflows. This includes stale scripts, incomplete examples, and
examples that end before the user can inspect what happened.

### Tasks

- Audit advertised example scripts and vignette examples for runtime
  completeness.
- Fix or unadvertise stale scripts, including the `sweeps.R` script if it is
  empty or misleading.
- Ensure first-run examples cover `ledgr_run()`, closed-trade/result
  inspection, indicator use, strategy-helper recovery, custom indicators, and
  sweep basics where advertised.
- Ensure examples use the package's current filtering and setup conventions.
- Add smoke coverage for runnable scripts where practical.

### Acceptance Criteria

- Advertised scripts are either runnable or no longer advertised.
- Tutorial examples show a complete arc from data setup to run/sweep execution
  to result inspection.
- No tutorial depends on source-tree design files for user-facing explanation.
- First-run examples avoid stale version labels and obsolete APIs.

### Verification

- Targeted script smoke tests or equivalent documentation tests.
- Manual run-through of changed first-run examples.

### Source Reference

- THEME-001
- THEME-006
- THEME-007

### Classification

```yaml
type: documentation
surface: examples
scope: installed_docs
```

---

## LDG-2204: Result Inspection And Metrics Schema Documentation

Priority: P1  
Effort: M  
Dependencies: LDG-2201  
Status: Not Started

### Description

Clarify how users inspect run and sweep outputs today, including fills versus
trades, ledger/events, raw table shapes, print methods, summary return values,
comparison rows, sweep rows, and promotion context. Explicitly document current
metric assumptions without implementing metric context.

### Tasks

- Document the result inspection surfaces for backtests, run stores, sweeps,
  comparisons, metrics, and promotion context.
- Explain fills versus closed trades and ledger/event semantics.
- Document which helpers print, which helpers return structured objects, and
  which columns are stable enough for programmatic use.
- Document current Sharpe/risk-free-rate behavior and cadence-based
  annualization behavior without promising a specific future version.
- Record missing-api decisions from LDG-2201 in the relevant docs or packet.

### Acceptance Criteria

- Users can find the supported way to inspect metrics, fills, trades, final
  equity, comparison rows, sweep rows, and promotion context.
- Current risk-free-rate and annualization assumptions are visible.
- No partial metric-context storage, `metric_kernel`, or second annualization
  source is introduced.
- Missing-api decisions are discoverable from the packet or user-facing docs as
  appropriate.

### Verification

- Targeted documentation contract tests.
- Manual review of metric and comparison examples.

### Source Reference

- THEME-004
- Missing-API rows from auditr findings
- `rfc/rfc_risk_free_rate_metric_context_v0_1_8_1_synthesis.md` as deferred v0.1.8.2 context only

### Classification

```yaml
type: documentation
surface: metrics
scope: installed_docs
```

---

## LDG-2205: Strategy Helper Pipeline Documentation

Priority: P2  
Effort: S  
Dependencies: LDG-2201  
Status: Not Started

### Description

Improve the strategy-helper documentation so users can debug common setup,
validation, zero-trade, and helper-pipeline failures without reading tests or
internal code.

### Tasks

- Add a strategy-helper troubleshooting section or article.
- Explain the path from signal helpers to full target vectors.
- Document common validation failures, including missing target names,
  non-numeric outputs, unsupported return shapes, and zero-trade causes.
- Include or link a complete multi-asset example.
- Cross-link strategy preflight tier behavior where relevant.

### Acceptance Criteria

- Users can identify why a strategy helper produced no trades, invalid targets,
  or failed preflight.
- Documentation reinforces that functional strategies must return full named
  numeric target vectors unless using an explicit wrapper.
- Examples remain runnable and current.

### Verification

- Documentation contract tests for key claims.
- Targeted example smoke checks where applicable.

### Source Reference

- THEME-003
- `inst/design/contracts.md`

### Classification

```yaml
type: documentation
surface: strategy_helpers
scope: installed_docs
```

---

## LDG-2206: Sweep Documentation Polish And Runnable Sweep Script

Priority: P1  
Effort: M  
Dependencies: LDG-2201  
Status: Not Started

### Description

Polish sweep, precompute, promotion, seed, and failure-row documentation so the
v0.1.8 sweep surface is teachable and diagnostics are clear. This ticket also
fixes the high-priority empty or stale `sweeps.R` example if present.

### Tasks

- Review sweep vignette, sweep help pages, README sweep snippets, and advertised
  sweep scripts.
- Explain `ledgr_sweep()` as exploratory, `ledgr_candidate()` as selection, and
  `ledgr_promote()` as committed replay.
- Document failure rows, failed candidate inspection, preflight failures,
  invalid grids, invalid precomputed features, and feature-factory failures.
- Document seed chain behavior, `execution_seed`, and stochastic replay.
- Document `feature_set_hash`, candidate-level feature identity, and precompute
  validation payloads where missing.
- Ensure promotion context and same-snapshot promotion behavior are discoverable.

### Acceptance Criteria

- Sweep documentation presents a complete exploration-to-promotion workflow.
- The empty or stale `sweeps.R` script is fixed or removed from advertised paths.
- Failure rows and failed-candidate promotion rejection are documented.
- `feature_set_hash` and seed provenance are discoverable.
- No objective-function ownership, `ledgr_tune()`, or workflow-template API is
  introduced.

### Verification

- Documentation contract tests.
- Runnable sweep example smoke test where feasible.

### Source Reference

- THEME-006
- THEME-001
- v0.1.8 sweep implementation and docs

### Classification

```yaml
type: documentation
surface: sweeps
scope: installed_docs
```

---

## LDG-2207: Snapshot Metadata And CSV Walkthrough

Priority: P2  
Effort: S  
Dependencies: LDG-2201  
Status: Not Started

### Description

Improve snapshot, sealing, and metadata documentation for users working from CSV
or local data. The goal is a practical walkthrough of what ledgr stores, checks,
and reports, without changing snapshot semantics.

### Tasks

- Add or update CSV-to-snapshot walkthrough content.
- Explain snapshot sealing, snapshot hash, bar counts, instrument counts, and
  metadata fields.
- Document `snapshot_info` forms and field names such as `bar_count`,
  `instrument_count`, and `meta_json`.
- Clarify validation locality for CSV/OHLC failures.

### Acceptance Criteria

- Users can create and inspect a snapshot from CSV/local bars using installed
  docs.
- Snapshot metadata names match the actual public surfaces.
- No bypass of sealing, hash verification, or no-lookahead execution is
  introduced.

### Verification

- Documentation contract tests.
- Targeted example smoke check where feasible.

### Source Reference

- THEME-005
- THEME-009
- `inst/design/contracts.md`

### Classification

```yaml
type: documentation
surface: snapshots
scope: installed_docs
```

---

## LDG-2208: Warning And Error Message Polish

Priority: P1  
Effort: M  
Dependencies: LDG-2201  
Status: Not Started

### Description

Polish terse or ambiguous warnings/errors that auditr flagged, and verify that
runtime contracts are enforced where the finding could indicate behavior rather
than prose. This is a narrow diagnostic ticket, not a new public validator
surface.

### Tasks

- Review findings for `LEDGR_LAST_BAR_NO_FILL`, causal feature guidance,
  OHLC/CSV validation locality, Tier 3 preflight wording, same-ID indicator
  replacement, and `stop_on_error` duplicate condition classes.
- For each finding, classify it as prose-only, diagnostic-message polish, or
  runtime contract bug.
- Verify Tier 3/preflight runtime paths; Tier 3 strategies must not be silently
  accepted or downgraded to warning-only behavior.
- Fix duplicate generic condition classes if confirmed.
- Add focused tests for changed messages, classes, and runtime guards.

### Acceptance Criteria

- Changed diagnostics include enough origin, consequence, and next-action
  detail to be actionable.
- Tier 3 runtime behavior is verified by tests, not only documentation.
- Condition class vectors do not contain duplicate generic classes in the
  audited paths.
- No broad public causal validator or runtime feature is introduced.

### Verification

- Targeted tests for changed conditions and messages.
- Existing preflight and sweep failure tests.

### Source Reference

- THEME-009
- `inst/design/contracts.md`

### Classification

```yaml
type: diagnostics
surface: conditions
scope: runtime_and_docs
```

---

## LDG-2209: Discoverability And Version Labels

Priority: P2  
Effort: S  
Dependencies: LDG-2201  
Status: Not Started

### Description

Clean up stale version labels, scattered discoverability cues, and missing
cross-links so users can find the current workflows from installed docs and
pkgdown pages.

### Tasks

- Audit installed docs, README snippets, pkgdown navigation, and help-page links
  for stale v0.1.7/v0.1.8 labels.
- Update links to current articles and installed vignette paths.
- Ensure core workflow pages are discoverable from the package index.
- Avoid user-facing instructions that point at source-tree design files.

### Acceptance Criteria

- Public docs do not present stale release labels as current.
- Important workflow pages are reachable from package-level help and pkgdown
  navigation.
- Installed help links target installed vignettes or help pages, not private
  design files.

### Verification

- Documentation contract tests.
- Manual pkgdown/reference navigation review if docs are rebuilt.

### Source Reference

- THEME-007
- THEME-001

### Classification

```yaml
type: documentation
surface: discoverability
scope: installed_docs
```

---

## LDG-2210: Multi-Output Indicator Bundle Authoring UX

Priority: P1  
Effort: M  
Dependencies: LDG-2201  
Status: Not Started

### Description

Implement the accepted multi-output indicator authoring bundle UX. Bundles are
authoring-time conveniences that flatten into ordinary single-output feature
definitions at feature declaration boundaries. They are not runtime multi-output
features.

### Tasks

- Implement the accepted bundle object/helper surface from
  `rfc_multi_output_indicator_ux_synthesis.md`.
- Flatten bundle outputs into ordinary single-output indicator definitions
  before runtime feature computation.
- Use a derived default prefix from the normalized function name; normalize by
  lowercasing, stripping non-alphanumeric boundaries, and collapsing separators.
- Apply the prefix to selected outputs as well as full-output bundles.
- Preserve explicit `prefix = NULL` as the raw-output-name opt-in.
- Add help pages and examples that link to the feature lifecycle guide.
- Add tests required by the synthesis: ordinary indicator materialization,
  unique feature IDs, output-specific fingerprints, output filters with prefix
  applied, and unchanged existing single-output IDs/fingerprints.

### Acceptance Criteria

- Bundle entries materialize as ordinary indicators with unique feature IDs.
- Output-specific fingerprints differ when output semantics differ.
- Existing single-output adapter IDs and fingerprints are unchanged.
- The selected-outputs path still applies the derived or explicit prefix.
- `prefix = NULL` is the only raw-name opt-in.
- No grouped precompute, `multi_series_fn`, runtime multi-output feature object,
  discovery helper, or sweep provenance change is introduced.

### Verification

- Targeted unit tests for bundle flattening, IDs, fingerprints, and raw-name
  opt-in.
- Existing feature, precompute, and sweep tests.
- Documentation contract tests for new public help pages.

### Source Reference

- `inst/design/rfc/rfc_multi_output_indicator_ux_synthesis.md`
- THEME-002

### Classification

```yaml
type: feature
surface: indicator_authoring
scope: public_api
```

---

## LDG-2211: v0.1.8.1 Release Gate And Closeout

Priority: P0  
Effort: S  
Dependencies: LDG-2202, LDG-2203, LDG-2204, LDG-2205, LDG-2206, LDG-2207, LDG-2208, LDG-2209, LDG-2210  
Status: Not Started

### Description

Close the v0.1.8.1 packet after all implementation and documentation tickets
land. This ticket verifies the release boundary, documentation, tests, site,
NEWS, and ticket metadata.

### Tasks

- Confirm all v0.1.8.1 tickets are complete and statuses are synchronized in
  `v0_1_8_1_tickets.md` and `tickets.yml`.
- Update `NEWS.md` for new public API, behavioral changes, notable
  documentation/example additions, warning/error message changes, and runtime
  bug fixes.
- Verify no deferred roadmap feature was implemented accidentally.
- Run targeted tests for changed surfaces.
- Run full local tests and package checks appropriate for a release gate.
- Rebuild or validate documentation/site artifacts as required by the release
  playbook.

### Acceptance Criteria

- All ticket statuses and machine-readable metadata are synchronized.
- `NEWS.md` includes the relevant v0.1.8.1 changes.
- Full test suite passes locally.
- Package check passes with the agreed release flags.
- Documentation contract tests pass.
- No generated local artifacts are committed.
- Deferred v0.1.8.2+ roadmap features remain out of scope.

### Verification

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" -e "pkgload::load_all('.', quiet=TRUE); testthat::test_local('.', reporter='summary')"
& "C:\Program Files\R\R-4.5.2\bin\x64\R.exe" CMD build .
& "C:\Program Files\R\R-4.5.2\bin\x64\R.exe" CMD check --no-manual --no-build-vignettes ledgr_<version>.tar.gz
```

### Source Reference

- `v0_1_8_1_spec.md`
- Release playbook

### Classification

```yaml
type: release_gate
surface: package
scope: v0.1.8.1
```
