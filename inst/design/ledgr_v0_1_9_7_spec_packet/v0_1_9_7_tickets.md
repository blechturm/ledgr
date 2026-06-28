# ledgr v0.1.9.7 Tickets

Version: v0.1.9.7
Date: 2026-06-26
Total Tickets: 11

## Ticket Organization

v0.1.9.7 is a business-objective eligibility and validation-polish release.
It consumes the validation-toolkit synthesis as maintainer-amended on
2026-06-26, the v0.1.9.6 business-objective deferral, the stable-region
research input, and the v0.1.9.6 intraday-readiness audit M-1 finding.

Ticket IDs start at LDG-2659 after the v0.1.9.6 packet.

The release spine is:

```text
packet alignment
  -> stable_region spike
  -> closed-trade retention
  -> teaching and intraday/K-Ratio side work
  -> business-objective internal contract and criteria
  -> all-candidates sweep filter
  -> release surfaces
  -> release gate
```

Ticket-cut decisions from spec review:

- `positive_trajectory` is self-contained. It regresses cumulative log-equity
  on the zero-based retained-row index after structural first-row handling;
  `slope_min` is in log-equity units per retained observation. K-Ratio is
  compatible but not required.
- `ledgr_sweep_filter_result` must define a rejecting
  `ledgr_candidate.ledgr_sweep_filter_result()` method. Absence of a method is
  insufficient because `ledgr_candidate.default()` accepts sweep-like tibbles.
- Closed-trade retention persists `candidate_row`, `trade_seq`,
  `close_ts_utc`, `realized_pnl`, and `win_loss`; `trade_seq` is the stable
  order key for same-pulse co-closes.
- Closed-trade persistence updates saved-sweep parent/artifact schema versions
  and per-table validators, not only `ledgr_sweep_retention_schema_version`.
- `stable_region` v1 is strict ordered-only. Plain factors fail closed; broader
  hold-fixed or mixed-topology detectors are deferred.
- The intraday M-1 guardrail is warning-only in v0.1.9.7. Hard-fail policy is
  deferred unless a ticket review finds a concrete unsafe surface.
- K-Ratio is conditional. LDG-2664 must bind one named published variant and
  reference/known-direction verification before implementation; otherwise it
  records a clean deferral.
- Diagnostic-threshold criteria v1 are candidate-level evidence thresholds over
  named v0.1.9.6 diagnostic columns. Initial admissible columns are MinTRL
  `min_TRL` / `status` and DSR `dsr_probability` / `status`. PBO/CSCV is not a
  v1 per-candidate threshold criterion.

## Dependency DAG

```text
LDG-2659
  -> LDG-2660
  -> LDG-2661
  -> LDG-2662
  -> LDG-2663
  -> LDG-2664
  -> LDG-2665
LDG-2660 + LDG-2661 + LDG-2665 -> LDG-2666
LDG-2665 + LDG-2666 -> LDG-2667
LDG-2660 + LDG-2661 + LDG-2662 + LDG-2663 + LDG-2664 + LDG-2667 -> LDG-2668
LDG-2659..LDG-2668 -> LDG-2669
```

Batch order is authoritative even where tickets could be implemented in
parallel.

## Priority Levels

- P0: Release-blocking contract, persistence, identity, or selection-boundary
  work.
- P1: Required release scope with user-facing or maintainer-facing impact.
- P2: Documentation closeout, release-surface polish, and release gates.

## LDG-2659 - Packet Alignment And Ticket Cut

Priority: P0
Effort: S
Dependencies: None
Status: Complete After Review

### Description

Create the v0.1.9.7 packet execution artifacts from the reviewed spec and bind
the ticket-cut decisions needed before implementation starts.

### Tasks

- Patch the stale synthesis wording so `ledgr_sweep_filter()` is described as
  all-candidates evidence with eligibility flags.
- Bind `positive_trajectory` slope units in the spec.
- Create `v0_1_9_7_tickets.md`, `tickets.yml`, `batch_plan.md`, and packet
  `README.md`.
- Record cut-line decisions for K-Ratio, diagnostic thresholds, `stable_region`,
  closed-trade retention, M-1 disposition, and the anti-selection boundary.

### Acceptance Criteria

- Every spec scope item is ticketed or explicitly deferred.
- Every ticket has priority, effort, dependencies, status, tasks, acceptance
  criteria, verification, source reference, and classification.
- Batch plan groups tickets into reviewable batches and preserves the
  stop-for-review discipline.
- No implementation work is mixed into ticket cut.

### Verification

- Manual packet-artifact review.
- `rg "LDG-2659|LDG-2669" inst/design/ledgr_v0_1_9_7_spec_packet`
- Manual check that the prior eligible-only filter wording no longer appears in
  the synthesis prose.
- `rg "[^\x00-\x7F]" inst/design/ledgr_v0_1_9_7_spec_packet`

### Implementation Notes

- Ticket cut artifacts written and the two spec-review nits patched.
- Awaiting Claude review before Batch 1.

### Source Reference

- `inst/design/ledgr_v0_1_9_7_spec_packet/v0_1_9_7_spec.md`
- `inst/design/rfc/rfc_validation_toolkit_v0_1_9_x_synthesis.md`

### Classification

```yaml
type: planning
surface: design-packet
scope: packet-alignment
```

## LDG-2660 - stable_region Detector Spike

Priority: P0
Effort: M
Dependencies: LDG-2659
Status: Complete After Review

### Description

Run the in-packet `stable_region` methodology spike and produce the reviewed
design note that either greenlights the strict-lattice detector or records a
clean deferral.

### Tasks

- Write a `stable_region` spike synthesis in the v0.1.9.7 packet.
- Verify the strict ordered-only lattice design against
  `Stable-Parameter-Region-Detection.md`.
- Specify neighbor rule, `tau`, stability statistic, fail-closed conditions,
  diagnostics, and attribution language.
- Build known-direction fixtures: broad plateau passes, isolated spike fails,
  non-factorial/sparse/unordered grids fail closed.
- Record maintainer acceptance or deferral before dependent criteria begin.

### Acceptance Criteria

- The spike authorizes no public API by itself.
- The accepted design is deterministic and consumes only candidate grid plus one
  per-candidate metric.
- Plain factors and unordered/sparse/non-factorial grids fail closed.
- The synthesis states the detector is ledgr's operationalization of Pardo's
  plateau idea, not a Pardo formula.
- If red/yellow, `stable_region` defers without blocking the other criteria.

### Verification

- Manual spike-synthesis review.
- Known-direction fixture script or documented calculations.
- Source spot-checks against the research input.

### Implementation Notes

- Added `stable_region_spike_synthesis.md` with a green, narrow verdict for
  the strict ordered-only lattice detector, pending Claude review and
  maintainer acceptance.
- Added and ran `stable_region_spike_reference.R`.
- The reference fixture verifies broad plateau pass, isolated spike fail, and
  sparse / unordered / duplicate / collapsed grid fail-closed behavior.
- The spike authorizes no public API, package dependency, criterion
  implementation, or selection behavior by itself.

### Source Reference

- `inst/design/ledgr_v0_1_9_7_spec_packet/v0_1_9_7_spec.md` Sections 2.4 and
  6.4
- `inst/design/research/Stable-Parameter-Region-Detection.md`

### Classification

```yaml
type: spike
surface: validation-methods
scope: stable-region-detector
```

## LDG-2661 - Closed-Trade Retention Extension

Priority: P0
Effort: L
Dependencies: LDG-2659
Status: Review Pending

### Description

Extend sweep retention with opt-in retained closed-trade evidence for completed
candidates, preserving no-retention byte stability and saved-sweep reopen
compatibility.

### Tasks

- Extend `ledgr_sweep_retention()` with an opt-in closed-trade evidence level.
- Persist retained closed trades with `candidate_row`, `trade_seq`,
  `close_ts_utc`, `realized_pnl`, and `win_loss`.
- Use `trade_seq` as the deterministic per-candidate order key.
- Update saved-sweep parent/artifact schema versions and
  `R/sweep-persistence-schema.R` table validators.
- Add retained-trade write/read/reopen paths.
- Add storage smoke evidence with a retained-trade ratio threshold.
- Update contracts, docs, conditions, and tests.

### Acceptance Criteria

- Default retention remains unchanged and no-retention sweep artifacts are
  byte-identical to the pre-ticket fixture.
- Reopened pre-extension sweeps remain valid and report trade evidence as
  unretained.
- Retained closed-trade evidence is available from saved and in-memory sweeps
  without recomputing from fills during filtering.
- Missing retained trade evidence fails closed for trade-distribution criteria.
- No run, fold, config, candidate, or walk-forward identity changes for sweeps
  that do not opt in.

### Verification

- Targeted retention and sweep-persistence tests.
- Schema compatibility tests for old and new saved sweeps.
- Storage smoke ratio check.
- Byte-identical no-trade-retention fixture.
- `tools::checkRd()` for touched retained-evidence docs.

### Implementation Notes

- Extended `ledgr_sweep_retention()` with `trades = c("none", "closed")`;
  default retention remains scalar-only / no-trade-evidence.
- Added `ledgr_sweep_trades()` as a read-only retained-evidence accessor over
  `sweep_trades`, with unretained / unknown / failed / missing-retained
  condition classes.
- Retained closed-trade rows are captured at sweep time from closed trade rows
  and persist only `candidate_row`, `trade_seq`, `close_ts_utc`,
  `realized_pnl`, and `win_loss` plus sweep/candidate identifiers.
- Saved-sweep schema v3 adds `sweep_trades`; write-time schema validation
  requires the table and read-time compatibility accepts pre-extension stores
  without it.
- `closed_trade_retention_storage_smoke.md` records the deterministic storage
  smoke ratio (`4 / 12 = 0.3334`, threshold `0.50`).

### Source Reference

- `inst/design/ledgr_v0_1_9_7_spec_packet/v0_1_9_7_spec.md` Sections 2.3,
  3, and 6.3
- `inst/design/ledgr_v0_1_9_2_spec_packet/sweep_retention_storage_smoke.md`

### Classification

```yaml
type: feature
surface: sweep-retention
scope: closed-trade-evidence
```

## LDG-2662 - Selection Integrity Teaching Refit

Priority: P1
Effort: M
Dependencies: LDG-2659
Status: Pending

### Description

Refit the already-shipped Selection Integrity article's worked examples and
relax brittle doc-contract header assertions without weakening anti-overclaim
coverage.

### Tasks

- Add the worked-example craft clause to `inst/design/vignette_styleguide.md`.
- Rework PBO/CSCV, MinTRL, and DSR examples into recognizable executed
  scenarios with calibrating high/low contrasts.
- Re-render the vignette mirror through Quarto.
- Relax rigid section-header doc-contract assertions while retaining
  non-vacuous content checks and anti-overclaim guards.

### Acceptance Criteria

- No new article is created.
- Worked examples execute; rendered `.md` output matches pinned values.
- The article still states diagnostics do not prove future profitability,
  select candidates, rank-to-pick, or promote.
- Doc-contract tests remain non-vacuous and resilient to narrative structure.
- No diagnostic behavior, API, or identity changes.

### Verification

- Quarto render of `vignettes/selection-integrity.qmd`.
- Targeted documentation-contract tests.
- `rg` sweep for forbidden overclaims.

### Source Reference

- `inst/design/ledgr_v0_1_9_7_spec_packet/v0_1_9_7_spec.md` Sections 2.7
  and 4
- `inst/design/vignette_styleguide.md`

### Classification

```yaml
type: documentation
surface: validation-teaching
scope: selection-integrity-refit
```

## LDG-2663 - Intraday Metric-Context Guardrail

Priority: P1
Effort: M
Dependencies: LDG-2659
Status: Pending

### Description

Close audit finding M-1 by warning when daily metric-context defaults are
applied to observed sub-daily evidence cadence.

### Tasks

- Wire the cadence-consistency guardrail into metrics, sweep metrics, and
  walk-forward degradation reading where metric contexts are applied.
- Use a classed warning for v0.1.9.7.
- Keep metric recipes and values unchanged.
- Update tests and docs for the warning behavior.
- Record M-2 and L-1 as still deferred.

### Acceptance Criteria

- Sub-daily evidence with daily annualization defaults emits a classed warning.
- Daily evidence remains quiet.
- The guardrail is identity-neutral and changes no metric values, hashes, run
  IDs, sweep IDs, session IDs, or walk-forward IDs.
- No first-class intraday runtime behavior is implemented.

### Verification

- Targeted metric-context tests.
- Targeted sweep and walk-forward degradation tests where applicable.
- Documentation-contract checks for deferred M-2/L-1 language.

### Source Reference

- `inst/design/ledgr_v0_1_9_7_spec_packet/v0_1_9_7_spec.md` Sections 2.6
  and 6
- `inst/design/audits/v0_1_9_6_intraday_readiness_audit.md`

### Classification

```yaml
type: feature
surface: metric-context
scope: intraday-honesty-guardrail
```

## LDG-2664 - Native K-Ratio Diagnostic

Priority: P1
Effort: M
Dependencies: LDG-2659
Status: Pending

### Description

Conditionally add a native K-Ratio diagnostic if a named published variant can
be pinned and verified with a reference value or known-direction fixture.

### Tasks

- Re-verify K-Ratio references and choose one named canonical variant.
- Record citation and formula boundary in `inst/design/methodology_references.md`.
- Implement the native diagnostic only if verification is green and scope stays
  small.
- Add output class, `as_tibble()`, print, failure classes, docs, and tests.
- If verification is not green, record a clean deferral with reasons.

### Acceptance Criteria

- One named K-Ratio variant is pinned; other variants are explicitly non-scope.
- Implementation matches a reference value or known-direction fixture.
- Diagnostic is evidence-only and independent of `positive_trajectory`.
- No optional package enters `Imports`; any reference package is test-only or
  `Suggests` with clean skips.
- If deferred, release surfaces and tickets record the deferral without
  blocking the objective layer.

### Verification

- Targeted K-Ratio tests or deferral artifact review.
- Optional reference-package cross-check where available.
- `tools::checkRd()` if docs are generated.
- `NAMESPACE`/`DESCRIPTION` import review.

### Source Reference

- `inst/design/ledgr_v0_1_9_7_spec_packet/v0_1_9_7_spec.md` Sections 2.5
  and 6.6

### Classification

```yaml
type: feature
surface: validation-diagnostics
scope: k-ratio
```

## LDG-2665 - Business-Objective Internal Contract

Priority: P0
Effort: M
Dependencies: LDG-2659
Status: Pending

### Description

Implement the classed, serializable, hashed internal criterion-step contract
and `ledgr_business_objective()` constructor without evaluation/filtering.

### Tasks

- Add the internal criterion-step representation with stable criterion id,
  serializable params, declared evidence key, and pure evaluate closure.
- Add `ledgr_business_objective()` all-pass composition.
- Add deterministic `business_objective_hash` over ordered criterion steps.
- Add validation, printing, serialization, round-trip, and failure classes.
- Update contracts, docs, exports, and tests.

### Acceptance Criteria

- Bare functions, arbitrary lists, unclassed criteria, duplicate IDs where
  disallowed, and non-serializable params fail closed.
- Changing threshold parameters changes `business_objective_hash`.
- Constructing an objective changes no run, sweep, candidate, session, or
  walk-forward identity.
- The internal contract is not exposed as a public third-party extension API.

### Verification

- Targeted business-objective constructor/hash tests.
- Serialization round-trip tests.
- Documentation-contract tests for no public extension contract.
- `tools::checkRd()` for new docs.

### Source Reference

- `inst/design/ledgr_v0_1_9_7_spec_packet/v0_1_9_7_spec.md` Sections 2.1,
  3, and 6.1
- `inst/design/rfc/rfc_validation_toolkit_v0_1_9_x_synthesis.md`

### Classification

```yaml
type: feature
surface: business-objective
scope: internal-step-contract
```

## LDG-2666 - Business-Objective Criteria

Priority: P0
Effort: L
Dependencies: LDG-2660, LDG-2661, LDG-2665
Status: Pending

### Description

Implement the v1 D2 criterion set and diagnostic-threshold criteria over
already-computed ledgr-owned evidence.

### Tasks

- Implement `max_drawdown`, `min_trades`, and self-contained
  `positive_trajectory` criteria.
- Implement `even_trades`, `even_profit`, and `stable_runs` criteria over
  retained closed-trade evidence.
- Implement `stable_region` if LDG-2660 returns green; otherwise record its
  clean deferral.
- Implement diagnostic-threshold criteria for candidate-level MinTRL and DSR
  outputs.
- Add classed fail-closed missing/non-finite evidence conditions.
- Update contracts, docs, examples, and tests.

### Acceptance Criteria

- Criteria threshold only already-computed evidence; no raw fills/positions
  recomputation.
- `positive_trajectory` uses retained equity, zero-based retained-row index,
  and `slope_min` in log-equity units per retained observation.
- Trade-distribution criteria require retained closed-trade evidence and use
  `trade_seq` for run ordering.
- Diagnostic-threshold criteria record source diagnostic metadata and hash and
  make no profitability endorsement.
- All criteria use the internal step contract from LDG-2665.

### Verification

- Targeted criterion tests.
- Missing-evidence and non-finite-evidence tests.
- Known-direction tests for `positive_trajectory`, trade distribution, and
  diagnostic thresholds.
- Documentation-contract tests for evidence-only language.

### Source Reference

- `inst/design/ledgr_v0_1_9_7_spec_packet/v0_1_9_7_spec.md` Sections 2.1,
  2.3, 2.4, and 6.1

### Classification

```yaml
type: feature
surface: business-objective
scope: objective-criteria
```

## LDG-2667 - Sweep Eligibility Filter

Priority: P0
Effort: M
Dependencies: LDG-2665, LDG-2666
Status: Pending

### Description

Implement `ledgr_sweep_filter()` as an all-candidates evidence surface over a
business objective, with explicit anti-selection and anti-promotion guards.

### Tasks

- Evaluate objectives over completed-candidate retained evidence.
- Return a classed long tear-down table containing every evaluated candidate
  and criterion row, including failures.
- Make `as_tibble()` and print default to the full table.
- Add explicit eligible-only extraction only if needed, never as default.
- Add rejecting `ledgr_candidate.ledgr_sweep_filter_result()` behavior.
- Ensure `ledgr_promote()` and walk-forward selection reject filter results.
- Add docs, conditions, exports, and tests.

### Acceptance Criteria

- The result contains candidate-level `eligible` flags but no chosen candidate.
- Ineligible candidates are not dropped from default output.
- Candidate order is not rewritten into a pick.
- `ledgr_candidate()`, `ledgr_promote()`, and walk-forward selection reject
  filter results with classed conditions.
- Filtering writes no persisted artifact and mutates no identity.

### Verification

- Targeted `ledgr_sweep_filter()` tests.
- Anti-selection regression tests for candidate/promote/walk-forward rejection.
- Reopened-sweep evidence tests.
- Documentation-contract tests for all-candidates evidence wording.
- `tools::checkRd()` for new docs.

### Source Reference

- `inst/design/ledgr_v0_1_9_7_spec_packet/v0_1_9_7_spec.md` Sections 2.2,
  3, and 6.2

### Classification

```yaml
type: feature
surface: business-objective
scope: sweep-filter
```

## LDG-2668 - Release Surfaces And Deferral Ledger

Priority: P2
Effort: M
Dependencies: LDG-2660, LDG-2661, LDG-2662, LDG-2663, LDG-2664, LDG-2667
Status: Pending

### Description

Update release surfaces, deferral ledgers, reference indexes, roadmap, and
NEWS for the implemented v0.1.9.7 scope.

### Tasks

- Bump `DESCRIPTION` to `0.1.9.7`.
- Update NEWS, README/pkgdown references, design index, roadmap, AGENTS, and
  horizon current-packet notes.
- Record any conditional deferrals from `stable_region` or K-Ratio.
- Preserve explicit deferrals for D4 walk-forward identity, broader robustness,
  scored composition, public extension contract, Triple Penance, M-2/L-1, and
  larger v0.2.x work.
- Add doc-contract locks for release-surface claims and anti-overclaims.

### Acceptance Criteria

- Release surfaces accurately describe shipped work and conditional deferrals.
- No surface says the objective layer selects, promotes, proves future
  profitability, or enters walk-forward identity.
- The horizon entry remains synchronized with the packet deferrals.
- `_pkgdown.yml`/reference index include new public surfaces where applicable.

### Verification

- Documentation-contract tests.
- `rg` sweeps for stale overclaims and old version status.
- Manual release-surface review.

### Source Reference

- `inst/design/ledgr_v0_1_9_7_spec_packet/v0_1_9_7_spec.md` Sections 2.8
  and 8
- `inst/design/horizon.md`
- `inst/design/ledgr_roadmap.md`

### Classification

```yaml
type: documentation
surface: release-surfaces
scope: release-ledger
```

## LDG-2669 - v0.1.9.7 Release Gate

Priority: P0
Effort: M
Dependencies: LDG-2659, LDG-2660, LDG-2661, LDG-2662, LDG-2663, LDG-2664, LDG-2665, LDG-2666, LDG-2667, LDG-2668
Status: Pending

### Description

Run the release playbook, close the packet, and prepare the branch for remote
CI, merge, and tag.

### Tasks

- Read `inst/design/release_ci_playbook.md` before starting.
- Run full local tests and package checks required by the playbook.
- Run pkgdown/documentation gates where changed.
- Update ticket statuses, batch plan, README, and release closeout.
- Confirm no generated local artifacts are committed.

### Acceptance Criteria

- All tickets are complete after review or explicitly deferred with maintainer
  acceptance.
- Full release verification passes or any exception is documented and accepted.
- `DESCRIPTION`, NEWS, docs, contracts, and packet records are internally
  consistent.
- Branch is ready for remote CI, merge, and tag.

### Verification

- Release playbook.
- Full local test suite.
- `R CMD build` and `R CMD check --no-manual --no-build-vignettes`.
- pkgdown/documentation gate where changed.
- Git status review for generated artifacts.

### Source Reference

- `inst/design/release_ci_playbook.md`
- `inst/design/ledgr_v0_1_9_7_spec_packet/v0_1_9_7_spec.md`

### Classification

```yaml
type: release
surface: release-gate
scope: v0.1.9.7-closeout
```
