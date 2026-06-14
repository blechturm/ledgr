# ledgr v0.1.9.6 Tickets

Version: v0.1.9.6
Date: 2026-06-14
Total Tickets: 14

## Ticket Organization

v0.1.9.6 is a validation-substrate and gated-diagnostics release. It consumes
the accepted validation-toolkit synthesis as maintainer-amended on 2026-06-14,
the Methodological Diagnostics styleguide rule, and the roadmap/horizon entries
for canonical returns, retained-return panels, the PBO spike gate,
intraday-readiness audit, and current-surface peer-benchmark redo.

Ticket IDs start at LDG-2645 after the v0.1.9.5 packet.

The release spine is:

```text
packet alignment
  -> packet-open verification and method-teaching gate
  -> canonical run returns
  -> retained-return panel and projection substrate
  -> PBO spike decision gate
  -> native PBO/CSCV diagnostic
  -> self-contained diagnostics and selection-integrity docs
  -> audit / measurement closeout
  -> release surfaces
  -> release gate
```

Ticket-cut decisions from the spec open questions:

- PBO/CSCV implementation is now cut as LDG-2658 by maintainer amendment after
  LDG-2650 returned green for a native implementation ticket and was accepted.
  The public runtime route is native; CRAN `pbo` remains an optional reference
  and cross-check only.
- `ledgr_business_objective()` and `ledgr_sweep_filter()` remain deferred even
  though native PBO/CSCV is now ticketed. No narrowed objective override is cut
  for v0.1.9.6.
- MinTRL is the first self-contained diagnostic in scope.
- DSR may ship independently of PBO because its deflation depends on
  effective-trial clustering, not on the PBO algorithm. It remains gated by
  reference verification and deterministic clustering evidence.
- K-Ratio and Triple Penance are deferred out of v0.1.9.6.
- RPESE and `pbo` are not added to `Suggests` until their packet-open/spike
  verification says they are required. PerformanceAnalytics/xts projection work
  may use optional `Suggests` only if the implementation needs package-backed
  objects rather than base matrix/data-frame projections.
- The intraday-readiness audit runs after the return-panel substrate lands so
  it can audit the actual v0.1.9.6 validation evidence path.
- The peer benchmark redo is internal measurement only, not public benchmark
  marketing language.

## Dependency DAG

```text
LDG-2645
  -> LDG-2646
       -> LDG-2647
            -> LDG-2648
                 -> LDG-2649
                 -> LDG-2650 -> LDG-2658
                  -> LDG-2651
                  -> LDG-2652
                  -> LDG-2654
                  -> LDG-2655
LDG-2651 + LDG-2652 + LDG-2658 -> LDG-2653
LDG-2650 + LDG-2653 + LDG-2654 + LDG-2655 + LDG-2658 -> LDG-2656
LDG-2645..LDG-2656 + LDG-2658 -> LDG-2657
```

LDG-2658 was added by explicit maintainer amendment after LDG-2650 spike
acceptance. It does not authorize business-objective filtering, promotion,
walk-forward identity changes, or per-fold train-sweep PBO.

Batch order is authoritative even where tickets could be implemented in
smaller parallel patches.

## Priority Levels

- P0: Release-blocking contract, evidence-substrate, or gate work.
- P1: Required release scope with user-facing or maintainer-facing impact.
- P2: Documentation closeout, audit, measurement, and release-surface polish.

## LDG-2645 - Packet Alignment And Ticket Cut

Priority: P0
Effort: S
Dependencies: None
Status: Complete after Claude review (ticket-cut artifacts written; dependency
patches applied)

### Description

Create the v0.1.9.6 packet execution artifacts from the reviewed spec and bind
the cut-line decisions needed before implementation starts.

### Tasks

- Create `v0_1_9_6_tickets.md`, `tickets.yml`, `batch_plan.md`, and update
  the packet `README.md`.
- Record the ticket-cut decisions for PBO implementation, business objective,
  MinTRL, DSR, K-Ratio, Triple Penance, optional adapter packages,
  intraday-audit timing, and peer-benchmark language.
- Keep the spec status and packet README aligned with the ticket-cut state.
- Keep packet files ASCII-clean.

### Acceptance Criteria

- The packet contains a human ticket file, machine-readable YAML, batch plan,
  README, and spec.
- Every spec scope item is either ticketed or explicitly deferred.
- Every ticket has priority, effort, dependencies, status, tasks, acceptance
  criteria, verification, source reference, and classification.
- The batch plan groups tickets into reviewable batches and preserves the
  stop-for-review discipline.
- No implementation work is mixed into ticket cut.

### Verification

- Manual packet-artifact review.
- `rg "LDG-2645|LDG-2657" inst/design/ledgr_v0_1_9_6_spec_packet`
- `rg "[^\x00-\x7F]" inst/design/ledgr_v0_1_9_6_spec_packet`

### Source Reference

- `inst/design/ledgr_v0_1_9_6_spec_packet/v0_1_9_6_spec.md`

### Classification

```yaml
type: planning
surface: design-packet
scope: packet-alignment
```

## LDG-2646 - Packet-Open Verification And Method Teaching Gate

Priority: P0
Effort: S
Dependencies: LDG-2645
Status: Complete after Claude review

### Description

Close the packet-open gates before validation implementation starts: verify
external package facts and lock the Methodological Diagnostics teaching rule.

### Tasks

- Re-verify package/API/license/activity facts for PerformanceAnalytics, xts,
  RPESE, `pbo`, and any other candidate adapter package used by tickets.
- Confirm whether any optional adapter packages must enter `Suggests`; do not
  add optional packages to `Imports`.
- Ensure `inst/design/vignette_styleguide.md` contains the Methodological
  Diagnostics rule.
- Ensure `tests/testthat/test-documentation-contracts.R` locks the styleguide
  rule without vacuous tests for future articles.
- Record packet-open verification notes in the ticket implementation notes.

### Acceptance Criteria

- External package facts are current as of implementation day and cite package
  version/source.
- No validation-method implementation ticket starts before the styleguide gate
  is present and tested.
- Optional dependency posture is explicit: `Suggests` only, clean skips when
  absent, no `NAMESPACE` imports unless a later ticket records an approved
  exception.
- The doc-contract test verifies the rule itself and does not assert on planned
  articles that do not exist yet.

### Verification

- Targeted documentation-contract test for the styleguide lock.
- Manual verification notes for external packages.
- `rg "Methodological Diagnostics" inst/design/vignette_styleguide.md tests/testthat/test-documentation-contracts.R`

### Implementation Notes

- Added `packet_open_verification.md` with CRAN-verified package facts for
  PerformanceAnalytics, xts, RPESE, and `pbo` as of 2026-06-14.
- Confirmed current ledgr dependency posture: PerformanceAnalytics and xts are
  already in `Suggests`; RPESE and `pbo` are not; no optional adapter package
  is imported in `NAMESPACE`.
- Recorded the Batch 1 decision that no optional package moves to `Imports`,
  no optional `NAMESPACE` import is added, and RPESE/`pbo` remain unlisted
  until a later adapter or spike ticket justifies them.
- Confirmed the Methodological Diagnostics styleguide rule and non-vacuous
  documentation-contract lock are already present from Batch 0.

### Source Reference

- `inst/design/ledgr_v0_1_9_6_spec_packet/v0_1_9_6_spec.md` Sections 0, 3,
  and 6.5
- `inst/design/rfc/rfc_validation_toolkit_v0_1_9_x_synthesis.md`

### Classification

```yaml
type: planning
surface: validation-gates
scope: packet-open-verification
```

## LDG-2647 - Canonical Single-Run Returns Result View

Priority: P0
Effort: M
Dependencies: LDG-2646
Status: Complete after Claude review

### Description

Add the canonical single-run return evidence view through the existing
result-table contract.

### Tasks

- Add `tibble::as_tibble(bt, what = "returns")` with columns `ts_utc`,
  `equity`, and `period_return`.
- Add `ledgr_results(bt, what = "returns")` as a delegating view over the same
  `as_tibble()` result-table path.
- Reuse the existing adjacent-equity return formula source of truth.
- Keep first `period_return` as `NA_real_`.
- Update `inst/design/contracts.md` to include `returns` in the closed
  result-set enumeration and preserve the `ledgr_results()` delegation rule.
- Update reference docs, examples, and export/result tests as needed.

### Acceptance Criteria

- `as_tibble(bt, what = "returns")` and `ledgr_results(bt, what = "returns")`
  return identical evidence tables.
- Columns are exactly `ts_utc`, `equity`, and `period_return` unless
  implementation review records a stronger result-table convention.
- Returns match the same adjacent-equity formula used by retained sweep returns
  and ledgr-owned metric computation.
- `what = "metrics"` remains unsupported.
- The view creates no new persisted evidence and changes no identity hash,
  run id, config id, snapshot id, or walk-forward session id.
- `contracts.md` and tests reflect the new result-set value.

### Verification

- Targeted result-table tests for `as_tibble()` and `ledgr_results()`.
- Regression test comparing the return formula to retained sweep returns on a
  small equivalent fixture.
- Documentation-contract or contract-text checks for the closed enumeration.
- `pkgload::load_all('.', quiet = TRUE)` before targeted tests.

### Implementation Notes

- Added `as_tibble(bt, what = "returns")` through the existing backtest
  result-table switch, returning exactly `ts_utc`, `equity`, and
  `period_return`.
- Added `ledgr_results(bt, what = "returns")` by extending the closed result
  matcher; the wrapper still delegates to `tibble::as_tibble()`.
- Reused `compute_period_returns()` so single-run returns match ledgr-owned
  metric computation and retained sweep returns, with the first row set to
  `NA_real_`.
- Updated `contracts.md`, the result-table Rd pages, and targeted tests for the
  new closed result-set member. No persisted schema or identity fields changed.
- Verification passed:
  `pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-backtest-s3.R', reporter='summary'); testthat::test_file('tests/testthat/test-documentation-contracts.R', reporter='summary')`
  and `tools::checkRd()` on the two touched Rd pages.

### Source Reference

- `inst/design/ledgr_v0_1_9_6_spec_packet/v0_1_9_6_spec.md` Sections 2.1 and
  6.1
- `inst/design/contracts.md`

### Classification

```yaml
type: feature
surface: results
scope: canonical-return-stream
```

## LDG-2648 - Retained-Sweep Return Panel Hygiene

Priority: P0
Effort: M
Dependencies: LDG-2647
Status: Complete after Claude review

### Description

Build the validation substrate over retained sweep returns without recomputing
evidence from fills or positions.

### Tasks

- Add or harden a retained-return panel normalization helper over
  `ledgr_sweep_returns()`.
- Enforce UTC timestamp ordering and deterministic candidate-column ordering.
- Preserve explicit first-row `NA` handling.
- Fail closed for diagnostics that require a complete common timestamp grid.
- Report completed-candidate universe and excluded candidate ids.
- Reuse `ledgr_sweep_returns_unretained` for missing retained-return evidence.

### Acceptance Criteria

- Equal-grid retained returns produce a deterministic `T x N` return matrix or
  table substrate.
- Ragged panels fail closed with a named classed condition when a diagnostic
  requires complete panels.
- Completed candidates and excluded candidates are visible to callers.
- No strategy evidence is reconstructed from raw fills or positions.
- The substrate is identity-neutral: it does not change candidate ids,
  candidate rows, sweep ids, config hashes, or retained-return bytes.

### Verification

- Targeted retained-sweep return tests.
- Equal-grid, ragged-grid, unretained-sweep, first-row-NA, and candidate-order
  fixtures.
- Reopened-sweep parity test where retained returns are available.

### Implementation Notes

- Added `ledgr_sweep_returns_panel()` as the normalized retained-return panel
  substrate over `ledgr_sweep_returns()`.
- The panel records normalized long evidence, a deterministic `T x N` matrix,
  UTC timestamps, used candidate ids, completed candidate ids, excluded
  candidate ids, and structural first-row handling metadata.
- For `value = "returns"`, the structural first timestamp is dropped after
  verifying each candidate's first `period_return` is `NA_real_`.
- Complete panels fail closed with `ledgr_sweep_returns_incomplete_panel` and
  the future PBO-compatible alias `ledgr_validation_pbo_incomplete_panel`; the
  condition carries offending candidate ids plus missing/extra timestamp data.
- Missing retained evidence still routes through the existing
  `ledgr_sweep_returns_unretained` class. No fills or positions are
  reconstructed and no identity or retained-return bytes change.

### Source Reference

- `inst/design/ledgr_v0_1_9_6_spec_packet/v0_1_9_6_spec.md` Sections 2.2 and
  6.2
- `inst/design/rfc/rfc_validation_toolkit_v0_1_9_x_synthesis.md`

### Classification

```yaml
type: feature
surface: sweep-returns
scope: panel-hygiene
```

## LDG-2649 - Adapter-Shaped Return Projections

Priority: P1
Effort: M
Dependencies: LDG-2648
Status: Complete after Claude review

### Description

Expose adapter-shaped return projections for downstream consumers while
keeping optional packages optional and ledgr metrics authoritative.

### Tasks

- Add matrix/data-frame projection helpers over the normalized retained-return
  panel.
- Add `xts` projection only if packet-open verification and implementation
  review confirm that package-backed output is worth the dependency surface.
- Preserve deterministic row and column ordering.
- Label adapter-derived outputs as external evidence where package-specific
  functions are used.
- Add clean skip behavior when optional packages are absent.

### Acceptance Criteria

- Projection output is deterministic and derived only from retained returns.
- Optional adapter packages remain in `Suggests`, not `Imports`.
- Tests pass when optional packages are absent and exercise package-backed
  paths when present.
- Adapter conventions do not redefine ledgr-owned metrics or mutate evidence.

### Verification

- Targeted panel-projection tests.
- Optional-package skip tests.
- `NAMESPACE` review for accidental optional-package imports.
- `DESCRIPTION` review if `Suggests` changes.

### Implementation Notes

- Added deterministic projection helpers over the normalized panel:
  `ledgr_sweep_returns_matrix()`, `ledgr_sweep_returns_data_frame()`, and
  `ledgr_sweep_returns_xts()`.
- Matrix and data-frame projections use candidate ids as columns and UTC ISO
  row names. Projection metadata records retained-return source, value,
  candidate ids, completed/excluded candidates, first-row handling, and the
  complete-panel flag.
- `ledgr_sweep_returns_xts()` is optional-package backed, fails with
  `ledgr_missing_package` when `xts` is absent, and labels the output as
  external evidence with package/version metadata when present.
- `xts` remains in `Suggests`, not `Imports`; no `NAMESPACE` import was added.
- Verification passed:
  `pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-sweep-retention.R', reporter='summary'); testthat::test_file('tests/testthat/test-sweep-persistence-roundtrip.R', reporter='summary'); testthat::test_file('tests/testthat/test-api-exports.R', reporter='summary'); testthat::test_file('tests/testthat/test-documentation-contracts.R', reporter='summary')`
  and `tools::checkRd()` on the touched Rd pages.

### Source Reference

- `inst/design/ledgr_v0_1_9_6_spec_packet/v0_1_9_6_spec.md` Sections 2.2,
  2.3, and 6.2

### Classification

```yaml
type: feature
surface: adapters
scope: return-projections
```

## LDG-2650 - PBO Spike And Decision Synthesis

Priority: P0
Effort: M
Dependencies: LDG-2648
Status: Complete after Claude review

### Description

Run the PBO/CSCV spike and produce a reviewed synthesis before any public PBO
implementation is considered.

### Tasks

- Study PBO/CSCV method shape, assumptions, outputs, and failure modes.
- Audit the `pbo` package: current version, license, activity, dependencies,
  API, metric-hook shape, output shape, determinism with
  `allow_parallel = FALSE`, and known issues.
- Build or identify known-answer / reference-value fixtures.
- Test ledgr retained-return panels against the package/native expected input
  shape.
- Bind adapter-vs-native verdict and fallback conditions.
- Write the "what PBO cannot prove" teaching surface.
- Produce a reviewed spike synthesis with green/yellow/red verdict and
  maintainer acceptance point.

### Acceptance Criteria

- No public PBO/CSCV implementation lands in this ticket.
- The spike synthesis covers package facts, method assumptions, deterministic
  behavior, known-answer or reference-value evidence, panel contract, and
  adapter-vs-native recommendation.
- The synthesis explicitly says whether v0.1.9.6 may add PBO implementation
  tickets or must defer PBO to v0.1.9.7+.
- The teaching surface distinguishes selection-integrity evidence from proof
  of future profitability.

### Verification

- Manual review of the spike synthesis.
- Reproducible known-answer or known-direction scripts where available.
- Optional-package installation status recorded but not assumed.

### Implementation Notes

- Added `pbo_spike_synthesis.md` with a green/yellow/red decision: green for a
  native v0.1.9.6 PBO/CSCV implementation ticket after review and maintainer
  acceptance; yellow for using CRAN `pbo` as the public runtime foundation.
- Verified CRAN `pbo` 1.3.5 package facts from the official manual and local
  package metadata: MIT, no compilation, imports `utils`, `lattice`,
  `latticeExtra`, and `foreach`, published 2022-05-26.
- Installed `pbo` locally for spike verification only; no package dependency or
  NAMESPACE import was added to ledgr.
- Added `pbo_spike_reference.R`, a fixed `12 x 4` return-panel reference check
  that compares `pbo::pbo(..., allow_parallel = FALSE)` against an independent
  manual CSCV calculation and verifies deterministic repeated output.
- Bound the ledgr panel contract, native-vs-adapter decision, fallback
  conditions, and "what PBO cannot prove" teaching surface. No public PBO/CSCV
  implementation landed in this ticket.

### Source Reference

- `inst/design/ledgr_v0_1_9_6_spec_packet/v0_1_9_6_spec.md` Sections 2.5
  and 6.3
- `inst/design/rfc/rfc_validation_toolkit_v0_1_9_x_synthesis.md`

### Classification

```yaml
type: spike
surface: validation-methods
scope: pbo-decision-gate
```

## LDG-2658 - Native PBO/CSCV Diagnostic

Priority: P0
Effort: M
Dependencies: LDG-2648, LDG-2649, LDG-2650
Status: Not Started

### Description

Implement the public ledgr PBO/CSCV diagnostic natively over retained-return
panels after the LDG-2650 spike returned green for a native implementation
ticket. CRAN `pbo` remains optional reference evidence only, not a runtime
foundation.

### Tasks

- Define the public function name, output shape, condition classes, and
  `as_tibble()` / print behavior under the v0.1.9.5 naming synthesis.
- Implement native CSCV/PBO over the LDG-2648 retained-return panel and
  LDG-2649 projection shape.
- Prevalidate `S`: even, positive, and dividing the post-first-row return count.
- Drop the structural first `NA` return row only after verifying it is
  structurally `NA_real_` for every selected candidate.
- Require complete grids and completed-candidate retained return evidence;
  reuse the panel failure classes and PBO alias.
- Carry evidence metadata: used candidate ids, completed candidate ids,
  excluded candidate ids, value, first-row handling, complete-panel proof,
  `S`, metric identity, schema/version, and optional reference-check metadata.
- Add reference-value tests from `pbo_spike_reference.R`.
- Add a hard known-direction fixture: an obviously overfit candidate family must
  produce high PBO, and a robust/less-overfit family must produce lower PBO.
- Add Methodological Diagnostics documentation under the Selection Integrity
  family surface.

### Acceptance Criteria

- No dependency on CRAN `pbo` is added to `Imports` or required for runtime.
- The public result has stable named fields for PBO, CSCV cases, rank/logit
  evidence, degradation/probability surfaces where shipped, and input metadata.
- Invalid `S`, too few candidates, too few observations, non-finite metric
  output, ragged panels, and missing retained returns fail closed with classed
  conditions.
- Reference-value tests compare the native calculation to the spike fixture.
- Known-direction tests exercise at least one overfit and one less-overfit
  candidate family and lock the expected direction.
- The method docs teach what PBO asks, what evidence it consumes, how to
  interpret it, and what it cannot prove.
- The implementation performs no selection, promotion, business-objective
  filtering, walk-forward identity changes, or per-fold train-sweep PBO.

### Verification

- Targeted native PBO/CSCV tests.
- Optional `pbo` cross-check only when `pbo` is installed; tests must remain
  green without `pbo`.
- Documentation-contract tests for the Selection Integrity method surface.
- `tools::checkRd()` for new reference pages.
- `rg` sweep confirming no runtime dependency import and no business-objective
  or promotion scope.

### Source Reference

- `inst/design/ledgr_v0_1_9_6_spec_packet/pbo_spike_synthesis.md`
- `inst/design/ledgr_v0_1_9_6_spec_packet/pbo_spike_reference.R`
- `inst/design/ledgr_v0_1_9_6_spec_packet/v0_1_9_6_spec.md` Sections 2.5,
  3, 6.3, and 6.4
- `inst/design/rfc/rfc_validation_toolkit_v0_1_9_x_synthesis.md`

### Classification

```yaml
type: feature
surface: validation-diagnostics
scope: native-pbo-cscv
```

## LDG-2651 - Minimum Track Record Length Diagnostic

Priority: P1
Effort: M
Dependencies: LDG-2648
Status: Not Started

### Description

Ship the first self-contained selection-integrity diagnostic: minimum track
record length, with reference verification and teachable interpretation.

### Tasks

- Define public function name, output shape, condition classes, and input
  evidence contract under the v0.1.9.5 naming synthesis.
- Implement MinTRL over canonical return evidence.
- Add reference-value or known-direction tests.
- Carry input identity and schema/version metadata in the returned object.
- Fail closed for missing, ragged, or invalid evidence.
- Add method documentation under the Selection Integrity family surface.

### Acceptance Criteria

- MinTRL accepts canonical ledgr return evidence and rejects invalid inputs with
  classed conditions.
- Output fields are named, typed, documented, and stable.
- Reference-value or known-direction tests are present and explain their source.
- The method docs include question, evidence, method shape, interpretation,
  limits, failure modes, references, and an executed worked example.
- The implementation does not perform selection or promotion.

### Verification

- Targeted diagnostic tests.
- Documentation-contract tests for the method section.
- `tools::checkRd()` for new reference pages.

### Source Reference

- `inst/design/ledgr_v0_1_9_6_spec_packet/v0_1_9_6_spec.md` Sections 2.4,
  3, and 6.4

### Classification

```yaml
type: feature
surface: validation-diagnostics
scope: min-track-record-length
```

## LDG-2652 - DSR And Effective-Trial Clustering Diagnostic

Priority: P1
Effort: L
Dependencies: LDG-2648, LDG-2649
Status: Not Started

### Description

Implement DSR only if effective-trial clustering can be reference-verified and
kept deterministic. This ticket is independent of the PBO spike but shares the
same return-panel substrate.

### Tasks

- Verify DSR formula/reference behavior and the effective-trial-count input
  expected by ledgr.
- Design deterministic candidate clustering or effective-trial-count support.
- Implement DSR over canonical return evidence only if verification is green.
- Add named classed failures for missing, insufficient, or invalid evidence.
- Add reference-value or known-direction tests for DSR and clustering.
- Document DSR and clustering in the Selection Integrity family.

### Acceptance Criteria

- DSR does not depend on PBO implementation.
- If clustering/effective-trial verification is not green, this ticket records
  deferral rather than shipping a weak diagnostic.
- Any shipped implementation is deterministic and carries input identity and
  schema/version metadata.
- Documentation explains what DSR can and cannot prove.
- The implementation does not perform selection or promotion.

### Verification

- Targeted DSR tests.
- Determinism tests for clustering/effective-trial behavior.
- Documentation-contract tests for the DSR section if shipped.
- Deferral note if the verification gate does not pass.

### Source Reference

- `inst/design/ledgr_v0_1_9_6_spec_packet/v0_1_9_6_spec.md` Sections 2.4,
  3, 6.4, and 7

### Classification

```yaml
type: feature
surface: validation-diagnostics
scope: dsr-effective-trials
```

## LDG-2653 - Selection Integrity Teaching Surface

Priority: P1
Effort: M
Dependencies: LDG-2651, LDG-2652, LDG-2658
Status: Not Started

### Description

Create or update the Selection Integrity teaching surface for the diagnostics
that actually ship in v0.1.9.6.

### Tasks

- Organize shipped diagnostics by method family, not one article per function.
- Include MinTRL and any shipped DSR/effective-trial content.
- Add cautionary or disconfirming worked examples for high-risk diagnostics.
- Keep examples executable unless they satisfy the styleguide exceptions.
- Add doc-contract assertions for the actual article sections.
- Avoid generic statistics-textbook derivations; defer to references.

### Acceptance Criteria

- The article teaches question, evidence, method shape, interpretation, limits,
  failure modes, references, and worked examples for shipped diagnostics.
- The docs make clear that diagnostics do not prove future profitability.
- Documentation tests assert real article structure and do not pass vacuously.
- No docs imply automatic promotion, winner-picking, or business-objective
  filtering.

### Verification

- Render affected vignettes/articles where local tooling allows.
- Documentation-contract tests.
- `rg` checks for forbidden overclaims named in the ticket review.

### Source Reference

- `inst/design/vignette_styleguide.md`
- `inst/design/ledgr_v0_1_9_6_spec_packet/v0_1_9_6_spec.md` Sections 3 and
  6.5

### Classification

```yaml
type: documentation
surface: validation-teaching
scope: selection-integrity
```

## LDG-2654 - Intraday-Readiness Audit

Priority: P2
Effort: M
Dependencies: LDG-2648
Status: Not Started

### Description

Audit whether ledgr remains EOD-first but intraday-tolerant after the
v0.1.9.x feature arc, and estimate refactor size for any footguns found.

### Tasks

- Audit snapshot sealing and timestamp precision.
- Audit pulse calendars, fold windows, metrics annualization, feature warmup,
  timing/cost contexts, target-risk boundaries, retained panels, sweep/walk
  identity, and generated examples.
- Classify every finding by severity, affected surface, intraday impact,
  refactor size, and recommended disposition.
- Do not implement intraday runtime behavior in this ticket.

### Acceptance Criteria

- The audit writes a versioned artifact under `inst/design/audits/`.
- Every finding follows the spec output shape:
  finding -> affected surface -> why it matters for intraday -> current
  severity -> refactor size -> recommended disposition.
- The audit distinguishes documentation fixes, small guardrails, medium
  refactors, and architecture/RFC work.
- No runtime implementation or behavior change is mixed in.

### Verification

- Manual review of audit artifact.
- Spot-check `rg` / source references for every high or medium finding.

### Source Reference

- `inst/design/ledgr_v0_1_9_6_spec_packet/v0_1_9_6_spec.md` Sections 4.1
  and 6.6
- `inst/design/horizon.md` intraday-readiness audit entry

### Classification

```yaml
type: audit
surface: intraday-readiness
scope: architecture-footguns
```

## LDG-2655 - Current-Surface Peer Benchmark Redo

Priority: P2
Effort: M
Dependencies: LDG-2648
Status: Not Started

### Description

Rerun the internal peer parity/performance benchmark on the current v0.1.9.5+
surface with cost and risk chains represented explicitly.

### Tasks

- Add or verify benchmark rows for zero cost/risk and a representative real
  cost/risk-chain row on the same fixture and seed.
- Preserve canonical ledgr parity checks.
- Keep B2 spot-FIFO rows opt-in and clearly labeled.
- Update internal benchmark report artifacts only after the record bundle is
  accepted.
- Avoid public benchmark marketing language.

### Acceptance Criteria

- The benchmark report states fixture, seed, engine boundary, cost/risk chain,
  and opt-in compiled status.
- Parity checks pass or divergence is attributed before timing claims are
  interpreted.
- Internal benchmark language is measurement evidence, not public ranking.
- The ticket does not flip compiled defaults or optimize runtime code.

### Verification

- Benchmark smoke run where local tooling allows.
- Record-run artifact review when the full peer environment is available.
- Manual report review for public-claim guardrails.

### Source Reference

- `inst/design/ledgr_v0_1_9_6_spec_packet/v0_1_9_6_spec.md` Sections 4.2
  and 6.6
- `inst/design/horizon.md` peer benchmark redo entry

### Classification

```yaml
type: measurement
surface: peer-benchmark
scope: current-surface-redo
```

## LDG-2656 - Release Surfaces And Deferral Ledger

Priority: P2
Effort: S
Dependencies: LDG-2650, LDG-2653, LDG-2654, LDG-2655, LDG-2658
Status: Not Started

### Description

Update release surfaces and planning ledgers so v0.1.9.6 accurately describes
what shipped, what the PBO spike decided, and what remains deferred.

### Tasks

- Update `NEWS.md`, README/pkgdown surfaces, roadmap, horizon, AGENTS.md, and
  design indexes as appropriate.
- Record PBO spike verdict, native PBO shipped/deferred state, and any v0.1.9.7
  deferrals.
- Record business-objective deferral unless a later accepted amendment changes
  the cut.
- Record K-Ratio, Triple Penance, purging/embargo/CPCV, intraday runtime, and
  compiled-default deferrals.
- Ensure docs do not overclaim validation methods or benchmark results.

### Acceptance Criteria

- Release surfaces mention canonical returns, panel substrate, shipped
  diagnostics, PBO spike result, audits, and benchmark redo accurately.
- Deferred items appear in horizon or roadmap with a concrete reason.
- No release surface says PBO/CSCV shipped unless LDG-2658 is completed.
- No public benchmark ranking claim is introduced.

### Verification

- Documentation-contract tests where pointer strings changed.
- `rg` sweep for stale PBO/business-objective/benchmark overclaims.
- Manual release-surface review.

### Source Reference

- `inst/design/ledgr_v0_1_9_6_spec_packet/v0_1_9_6_spec.md` Sections 8 and
  9

### Classification

```yaml
type: documentation
surface: release-surfaces
scope: closeout-ledger
```

## LDG-2657 - v0.1.9.6 Release Gate

Priority: P0
Effort: M
Dependencies: LDG-2645, LDG-2646, LDG-2647, LDG-2648, LDG-2649, LDG-2650,
  LDG-2651, LDG-2652, LDG-2653, LDG-2654, LDG-2655, LDG-2656, LDG-2658
Status: Not Started

### Description

Run the release gate for v0.1.9.6 after all scoped tickets and review stops
are complete.

### Tasks

- Read `inst/design/release_ci_playbook.md` into context before starting.
- Run targeted verification for changed surfaces.
- Run full local tests and package checks required by the playbook.
- Run documentation/pkgdown checks required by the packet.
- Confirm native PBO/CSCV was added only through LDG-2658 after the spike gate.
- Confirm release surfaces and deferrals are current.
- Prepare branch for remote CI, merge, and tag only after local gates pass.

### Acceptance Criteria

- All tickets are complete or explicitly deferred with maintainer acceptance.
- Full local release gate passes or any failures are documented and accepted.
- Old/stale validation claims are absent from release surfaces.
- No generated local artifacts are committed.
- The packet has a release closeout artifact.

### Verification

- Release playbook command transcript or summary.
- Full local test suite.
- R CMD build/check per playbook.
- Coverage gate per current CI policy when applicable.
- pkgdown/documentation gate where changed.

### Source Reference

- `inst/design/release_ci_playbook.md`
- `inst/design/ledgr_v0_1_9_6_spec_packet/v0_1_9_6_spec.md`

### Classification

```yaml
type: release
surface: release-gate
scope: v0.1.9.6-closeout
```
