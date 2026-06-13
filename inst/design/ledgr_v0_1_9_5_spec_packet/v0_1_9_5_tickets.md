# ledgr v0.1.9.5 Tickets

Version: v0.1.9.5
Date: 2026-06-12
Total Tickets: 15

## Ticket Organization

v0.1.9.5 is a naming and teaching consolidation release. It consumes the
accepted API naming-consistency synthesis, the v0.1.9.4 deep code-review audit,
and the v0.1.9.4 vignette-screening audit.

Ticket IDs start at LDG-2627 after the v0.1.9.4 packet.

The release spine is:

```text
packet alignment
  -> release-blocking audit fixes
  -> rename/unexport/generic implementation
  -> contracts and identity reference
  -> vignette splits and teaching surfaces
  -> maintainer/manual and release surfaces
  -> release gate
```

Ticket-cut decisions from the spec's open cut lines:

- Split E from the vignette-screening audit is deferred out of v0.1.9.5.
  Splits A-D are in scope.
- The standalone debugging article is deferred out of v0.1.9.5. Batch 8 keeps
  the quickstart, risk/cost policy article, and walk-forward research-arc
  article.
- N-1 and N-2 remain optional ride-along cleanups for Batch 2 only if touched
  naturally. They are not release gates.
- N-3, N-5, and N-6 remain recorded-not-scheduled dispositions.
- N-4 is conditional on the M-4 implementation route.
- The pkgdown third-group label is `Going Deeper` unless implementation review
  finds that an existing site convention should be preserved.

## Dependency DAG

```text
LDG-2627
  -> LDG-2628
  -> LDG-2629
  -> LDG-2630 -> LDG-2631
  -> LDG-2632
       -> LDG-2633
            -> LDG-2634 -> LDG-2635
            -> LDG-2642
       -> LDG-2636
            -> LDG-2637
            -> LDG-2644 (also depends on LDG-2642)
  -> LDG-2638 -> LDG-2639
  -> LDG-2643
  -> LDG-2640 (also depends on LDG-2642, LDG-2643, LDG-2644)
  -> LDG-2641
```

Batch order is authoritative even where tickets can be implemented in smaller
parallel patches.

## Priority Levels

- P0: Release-blocking correctness, contract, or rename gates.
- P1: Required release scope with user-facing or maintainer-facing impact.
- P2: Documentation closeout and release-surface polish.

## LDG-2627 - Packet Alignment And Ticket Cut

Priority: P0
Effort: S
Dependencies: None
Status: Review Pending (ticket-cut review complete 2026-06-12; patches H-1,
M-1..M-4, L-1..L-3 applied; pointer-flip tasks implemented)

### Description

Create the v0.1.9.5 packet execution artifacts from the patched spec and bind
the cut-line decisions that must be concrete before implementation begins.

### Tasks

- Create `v0_1_9_5_tickets.md`, `tickets.yml`, `batch_plan.md`, and
  `README.md`.
- Reconcile the ticket list with the spec Section 2 batch structure and the
  spec Section 3 / Batch 12 release-gate expectations.
- Flip active-packet pointers (roadmap header, `inst/design/README.md`,
  AGENTS.md planning context) from v0.1.9.4 to v0.1.9.5 and update the
  doc-contract pointer-string locks (review-patch M-1: spec Batch 0 scope).
- Record the cut-line decisions for Split E, the debugging article, Batch 2
  optional nits, and the pkgdown third-group label.
- Keep all generated packet artifacts ASCII-clean.

### Acceptance Criteria

- The packet contains a human ticket file, machine-readable YAML, batch plan,
  and README.
- Every spec batch has at least one ticket.
- Every ticket has a priority, effort, dependency list, status, tasks,
  acceptance criteria, verification, and source reference.
- The batch plan tells future implementers to stop for Claude review after each
  batch and not commit before review unless the user explicitly directs it.
- Active-packet pointers and their doc-contract locks reflect v0.1.9.5.

### Verification

- Manual review of the packet artifact set.
- Targeted documentation-contract tests after the pointer flips.
- `rg "LDG-2627|LDG-2641" inst/design/ledgr_v0_1_9_5_spec_packet`
- `rg "[^\x00-\x7F]" inst/design/ledgr_v0_1_9_5_spec_packet`

### Source Reference

- `inst/design/ledgr_v0_1_9_5_spec_packet/v0_1_9_5_spec.md` (its status block
  carries the spec-review record; the standalone review artifact was
  deliberately not retained)

### Classification

```yaml
type: planning
surface: design-packet
scope: packet-alignment
```

## LDG-2628 - Batch 1A Release-Blocking Stale Vignette Fixes

Priority: P0
Effort: S
Dependencies: LDG-2627
Status: Review Pending (implementation complete; awaiting Claude review)

### Description

Fix the carried stale vignette items before the broader rename and teaching
rewrites make their locations harder to audit.

### Tasks

- Fix the stale cost-API framing in `vignettes/execution-semantics.qmd`.
- Fix delivered-versus-planned scope language in
  `vignettes/research-to-production.qmd`.
- Fix walk-forward pointers in `vignettes/sweeps.qmd` and
  `vignettes/research-workflow.qmd`.
- Update pointer-string locks in `tests/testthat/test-documentation-contracts.R`
  when exact text changes.

### Acceptance Criteria

- The three stale screening-audit items no longer appear in their old form.
- Replacement language reflects v0.1.9.1-v0.1.9.4 shipped scope without
  implying deferred validation-toolkit or production features.
- Documentation-contract tests are updated for the new intended strings.
- No rename work is mixed into this batch.

### Verification

- `rg` checks for the stale phrases named in the screening audit.
- Targeted documentation-contract tests.
- Render affected vignettes if local rendering prerequisites are available.

### Source Reference

- `inst/design/audits/v0_1_9_4_vignette_screening_audit.md`
- `inst/design/ledgr_v0_1_9_5_spec_packet/v0_1_9_5_spec.md`

### Classification

```yaml
type: documentation
surface: vignettes
scope: stale-fixes
```

## LDG-2629 - Batch 1B Runner And Results Hardening

Priority: P0
Effort: M
Dependencies: LDG-2627
Status: Review Pending (implementation complete; awaiting Claude review)

### Description

Fix the release-blocking runner/results audit findings before the public rename
batch makes the same surfaces harder to reason about.

### Tasks

- Fix M-8 dead-cursor behavior before or with any rename implementation.
- Add a fail-closed run/window guard for H-1: execution windows must contain at
  least two pulses where next-bar fill semantics require a next pulse.
- Fix H-3 elapsed-time reporting so user-facing elapsed seconds are coherent.
- Add focused regression tests for all three fixes.

### Acceptance Criteria

- `ledgr_results(bt, "fills")` returns an eager result table even above
  `stream_threshold`; borrowed connections are never captured into returned
  cursors. A regression test forces the above-threshold borrowed-connection
  path through the internal impl seam (small threshold) and asserts no
  `ledgr_fills_cursor` is returned (review-patch M-3; synthesis gate 7.4).
- Single-pulse execution windows fail with a named, documented classed
  condition instead of producing misleading output.
- Elapsed-time helpers return seconds by construction; the magnitude
  heuristic is deleted; a regression test covers deltas above 1000 seconds
  (the former /1e9 range) and asserts correct `elapsed_sec` (review-patch
  L-2).
- The M-8 fix lands before LDG-2632 starts.

### Verification

- Targeted result-reader, run-window, and elapsed-time tests.
- `pkgload::load_all('.', quiet = TRUE)` before targeted tests.

### Source Reference

- `inst/design/audits/v0_1_9_4_deep_code_review_audit.md`
- `inst/design/rfc/rfc_api_naming_consistency_v0_1_9_5_synthesis.md`

### Classification

```yaml
type: bugfix
surface: runner-results
scope: release-blocking
```

## LDG-2630 - Batch 1C Kernel And Accounting Hardening

Priority: P0
Effort: M
Dependencies: LDG-2627
Status: Review Pending (implementation complete; awaiting Claude review)

### Description

Fix the release-blocking compiled-accounting and lot-application audit findings
before later documentation treats the contracts as stable.

### Tasks

- Fix B-1 `spot_fifo` protection discipline in compiled accounting code.
- Fix H-2 lot-application behavior so invalid accounting state fails closed.
- Add focused C++/R regression tests at the smallest practical fixture size.
- Keep the implementation limited to the audited code paths.

### Acceptance Criteria

- The compiled path is protected against the B-1 GC-safety failure mode.
- Lot-application invalid states fail with a named classed condition.
- Existing event-stream and accounting parity tests remain green.
- No public API or fold-core feature work is introduced.

### Verification

- Targeted compiled-accounting and lot-accounting tests.
- Relevant existing parity tests.

### Implementation Notes

- Implemented with LDG-2631 in one kernel/accounting/cost review batch.

### Source Reference

- `inst/design/audits/v0_1_9_4_deep_code_review_audit.md`

### Classification

```yaml
type: bugfix
surface: accounting-kernel
scope: release-blocking
```

## LDG-2631 - Batch 2 Kernel And Cost-Model Hygiene

Priority: P1
Effort: M
Dependencies: LDG-2630
Status: Review Pending (implementation complete; awaiting Claude review)

### Description

Clean up scheduled kernel and cost-model audit findings that are small enough
to land in this consolidation release without reopening execution semantics.

### Tasks

- Remove the legacy full-spread internal cost resolver and port tests to the
  public cost-model surface.
- Add `TYPEOF` validation for the five scalar compiled-accounting arguments
  named by M-2.
- Replace the scheduled compiled error paths with `cpp11::stop` per M-3.
- Clarify the fee-versus-rounding order from M-7 in code comments or docs where
  users can inspect it.
- Treat N-1 and N-2 as optional ride-alongs only if their files are already
  being touched.
- Record N-3, N-5, and N-6 as not scheduled; apply N-4 only if the M-4 route
  changes the tolerance story.
- Keep M-5 deferred with the spec's stated reason.

### Acceptance Criteria

- No tests depend on the removed legacy full-spread internal resolver.
- Compiled scalar argument failures are classed or otherwise testable at the R
  boundary.
- Compiled error messages use `cpp11::stop` on the scheduled paths.
- Cost-model behavior and identity bytes do not change except where the public
  cost-model surface already defines the behavior.
- Batch notes record the final N-item disposition choices.

### Verification

- Targeted cost-model tests.
- Targeted compiled-accounting tests.
- `rg` for removed legacy resolver references outside design history.

### Implementation Notes

- N-2 was applied as a natural ride-along in the compiled spot-FIFO lot-packing
  bridge.
- N-1 was not touched.
- N-3, N-5, and N-6 remain recorded-not-scheduled.
- N-4 did not apply because this batch did not change the M-4 tolerance route.

### Source Reference

- `inst/design/audits/v0_1_9_4_deep_code_review_audit.md`
- `inst/design/ledgr_v0_1_9_5_spec_packet/v0_1_9_5_spec.md`

### Classification

```yaml
type: cleanup
surface: cost-and-kernel
scope: audit-consumption
```

## LDG-2632 - Batch 3 Rename And Unexport Batch

Priority: P0
Effort: L
Dependencies: LDG-2629
Status: Review Pending (implementation complete; awaiting Claude review)

### Description

Implement the accepted API naming-consistency synthesis rename and unexport
plan as one coherent surface change.

### Tasks

- Implement every public rename from synthesis Section 2.1, including the six
  DSL prefixes, the eight verb-first renames, `ledgr_snapshot_load()` to
  `ledgr_snapshot_open()`, and `ledgr_ttr_warmup_rules()` to
  `ledgr_ind_ttr_warmup_rules()`.
- Rename the internal helper `ledgr_snapshot_open` to
  `ledgr_snapshot_connection` in the same commit that creates the public
  `ledgr_snapshot_open()`.
- Unexport the four Bucket A functions from the synthesis.
- Update NAMESPACE, roxygen, Rd, examples, README, pkgdown config, UX decisions,
  documentation-contract tests, and the export lock.
- Add the consolidated rename table to NEWS.md.
- Do not keep compatibility aliases unless the synthesis explicitly allows one.

### Acceptance Criteria

- `tests/testthat/test-api-exports.R` reconciles exactly with the new export
  surface.
- The verb-first allowlist includes `ledgr_promote()` and all other final-review
  allowlist names.
- `ledgr_ind_*` names are indicator constructors and `ledgr_indicator_*` names
  are indicator infrastructure.
- The old-name `rg` sweep is zero outside NEWS and design history.
- The internal-definition collision criterion from the synthesis is satisfied.
- `ledgr_run_fills()` preserves the `lazy` / `stream_threshold` /
  `ledgr_fills_cursor` contract byte-for-byte (synthesis gate 7.6 made
  explicit here, where a regression would originate; review note L-3).
- Bucket A functions are no longer exported but remain internally reachable
  where needed.

### Verification

- Export-lock tests.
- Documentation-contract tests.
- `devtools::document()` or equivalent roxygen generation path.
- `rg` old-name sweep using the synthesis exclusion set.
- `tools::checkRd()` after generated docs update.

### Implementation Notes

- Implemented the accepted rename and unexport table across R source, tests,
  examples, README, pkgdown config, generated Rd files, UX decisions, NEWS, and
  active contract references.
- Kept `ledgr_walk_forward_extract_candidate()` exported for Batch 4; only the
  walk-forward result opener moved to `ledgr_walk_forward_open()` in this
  batch.
- Renamed the internal snapshot connection helper to
  `ledgr_snapshot_connection()` in the same change that creates public
  `ledgr_snapshot_open()`.
- Unexported Bucket A functions from NAMESPACE and public docs while leaving
  their internal definitions available to package code.
- Applied name-only `contracts.md` updates needed to keep active contract text
  aligned; the full R1-R7 contracts rework remains LDG-2634.

### Source Reference

- `inst/design/rfc/rfc_api_naming_consistency_v0_1_9_5_synthesis.md`
- `inst/design/ledgr_v0_1_9_5_spec_packet/v0_1_9_5_spec.md`

### Classification

```yaml
type: api-change
surface: public-exports
scope: naming-consistency
```

## LDG-2633 - Batch 4 Candidate Generic And Walk-Forward Locator

Priority: P0
Effort: L
Dependencies: LDG-2632
Status: Review Pending (implementation complete; awaiting Claude review)

### Description

Replace the walk-forward-specific candidate extractor with the accepted
`ledgr_candidate()` generic and add locator attributes to live and reopened
walk-forward result objects.

### Tasks

- Implement `ledgr_candidate()` as the public S3 generic.
- Remove or unexport `ledgr_walk_forward_extract_candidate()` per the naming
  synthesis disposition.
- Add durable string locator attributes to live and reopened walk-forward result
  objects without placing live DB handles on the object.
- Resolve snapshots at call time and verify `snapshot_id` and `snapshot_hash`.
- Implement override semantics where `snapshot_id` and `snapshot_hash` must
  match and `db_path` may differ.
- Reuse `LEDGR_SNAPSHOT_DB_NOT_FOUND` for missing or moved snapshot database
  paths.
- Add `ledgr_walk_forward_snapshot_override_mismatch` for override mismatch.
- Carry over Amendment 2 discipline and supersede the v0.1.9.4 Section 4
  candidate extraction text where it conflicts.

### Acceptance Criteria

- `ledgr_candidate()` works for sweep candidates and walk-forward result
  candidates through one generic surface.
- Reopened walk-forward results can extract promotion-ready candidates when
  locator verification succeeds.
- Missing database paths fail closed with `LEDGR_SNAPSHOT_DB_NOT_FOUND`.
- Snapshot override mismatch fails with
  `ledgr_walk_forward_snapshot_override_mismatch`.
- Candidate extraction does not store or reuse stale live handles.
- Tests cover live, reopened, override-success, override-failure, and
  missing-database paths.

### Implementation Notes

- Converted `ledgr_candidate()` into an S3 generic while preserving the sweep
  extraction behavior in `ledgr_candidate.default()`.
- Added `ledgr_candidate.ledgr_walk_forward_results()` with resolve-at-call
  locator verification, `"latest"` rationale discipline, and optional snapshot
  override support.
- Added durable string locator attributes (`db_path`, `snapshot_id`,
  `snapshot_hash`) to live and reopened walk-forward result objects. No live
  snapshot, DBI connection, cursor, or backtest handle is stored in those
  attributes.
- Removed the public `ledgr_walk_forward_extract_candidate()` export and help
  page; its extraction body is now internal implementation behind the generic.
- Added `ledgr_walk_forward_snapshot_override_mismatch` for explicit override
  mismatches and reused `LEDGR_SNAPSHOT_DB_NOT_FOUND` for missing locator
  database paths.

### Verification

- Targeted walk-forward candidate tests.
- Reopened-walk-forward tests.
- Export-lock and documentation tests after removing the old extractor name.

### Source Reference

- `inst/design/rfc/rfc_api_naming_consistency_v0_1_9_5_synthesis.md`
- `inst/design/ledgr_v0_1_9_4_spec_packet/v0_1_9_4_spec.md`

### Classification

```yaml
type: api-change
surface: candidate-extraction
scope: generic-and-locator
```

## LDG-2634 - Batch 5 Contracts Rework And M-4/M-6 Hardening

Priority: P0
Effort: L
Dependencies: LDG-2632, LDG-2633
Status: Review Pending (implementation complete; awaiting Claude review)

### Description

Rework `contracts.md` for the renamed API surface and land the scheduled M-4
and M-6 hardening work as contract-backed fixes.

### Tasks

- Re-verify `contracts.md` clause by clause against the post-rename export
  surface.
- Bind naming rules R1-R7 and the D2 indicator naming distinction into
  `contracts.md`.
- Update contract language for target-risk identity, walk-forward identity,
  sweep persistence, and cost API identity without changing identity bytes.
- Resolve M-4 through either the whole-ish quantity contract or the epsilon-pop
  route named in the spec.
- Resolve M-6 by making snapshot-hash input POSIXct-only with classed failure
  and a source-level regression test.
- If M-4 uses the epsilon-pop route, recheck N-4 tolerance consequences.

### Acceptance Criteria

- `contracts.md` is consistent with the post-rename public API.
- R1-R7 and the D2 indicator naming rule are explicit contract language.
- M-4 has an implementation and tests, not only prose.
- M-6 has an implementation and tests, not only prose.
- No new identity component is added and no existing durable identity hash
  recipe changes.

### Implementation Notes

- Added a public naming contract section to `contracts.md` that binds R1-R7,
  including the closed verb-first allowlist and the D2 `ledgr_ind_*` versus
  `ledgr_indicator_*` distinction.
- Refreshed cost, risk, sweep, and walk-forward identity contract language
  without adding identity components or changing hash recipes.
- Resolved M-4 with the epsilon-pop route in both the canonical R lot replay
  path and the compiled spot-FIFO path. The tolerance only removes
  machine-epsilon-scale fractional dust after matched close operations.
- Resolved M-6 by making snapshot-hash timestamp formatting POSIXct-only with
  classed failure before canonical hash bytes are produced.

### Verification

- Contract-review checklist in the ticket closeout.
- Targeted M-4 and M-6 tests.
- `rg` sweep for old public names in `contracts.md`.

### Source Reference

- `inst/design/rfc/rfc_api_naming_consistency_v0_1_9_5_synthesis.md`
- `inst/design/audits/v0_1_9_4_deep_code_review_audit.md`
- `inst/design/contracts.md`

### Classification

```yaml
type: contract
surface: contracts-and-hardening
scope: naming-and-audit
```

## LDG-2635 - Batch 6 Identity Contract Reference v2

Priority: P1
Effort: M
Dependencies: LDG-2633, LDG-2634
Status: Review Pending (implementation complete; awaiting Claude review)

### Description

Refresh the identity contract reference for the completed v0.1.9.1-v0.1.9.4
feature arc and the v0.1.9.5 naming/generic changes.

### Tasks

- Update `?ledgr_identity_fields` for risk-chain identity, walk-forward
  candidate/session identity, locator attributes, and naming supersessions.
- Update `inst/design/manual/identity_contract.qmd` with the same concepts.
- Preserve cost-API forward obligations and walk-forward Section 17 gate rows.
- Fix the Implementation Trace pointer to `R/walk-forward-identity.R`.
- Regenerate Rd output if roxygen source changes.

### Acceptance Criteria

- Identity docs describe the post-v0.1.9.4 identity surface accurately.
- Locator attributes are described as recovery/verification metadata, not
  identity bytes.
- Naming supersessions are visible enough that users can map old docs to the
  new API.
- Cost, sweep, risk, and walk-forward identity language remains mutually
  consistent.

### Implementation Notes

- Updated `ledgr_identity_fields` to cover risk-chain identity, walk-forward
  `candidate_key` / `session_id`, locator attributes, and the
  `ledgr_candidate()` generic supersession.
- Updated `inst/design/manual/identity_contract.qmd` with the same locator and
  naming language. Locator attributes are described as recovery and
  resolve-at-call verification metadata, not identity bytes.
- Kept the Implementation Trace pointer to `R/walk-forward-identity.R` and
  added the locator-resolution trace in `R/walk-forward-inspection.R`.

### Verification

- Targeted documentation tests where applicable.
- `tools::checkRd()` after generated docs update.
- Manual read-through of identity docs against the synthesis and active spec.

### Source Reference

- `inst/design/manual/identity_contract.qmd`
- `inst/design/rfc/rfc_api_naming_consistency_v0_1_9_5_synthesis.md`
- `inst/design/ledgr_v0_1_9_4_spec_packet/v0_1_9_4_spec.md`

### Classification

```yaml
type: documentation
surface: identity-reference
scope: post-feature-arc-refresh
```

## LDG-2636 - Batch 7 Vignette Splits

Priority: P1
Effort: L
Dependencies: LDG-2628, LDG-2632
Status: Complete after Claude review

### Description

Implement the v0.1.9.4 vignette-screening audit splits A-D and update the site
structure around the split articles.

### Tasks

- Implement Split A: strategy-development -> "Strategy Basics" plus
  "Strategy Authoring Tools".
- Implement Split B: indicators -> "Indicators And Features" plus
  "TTR And Adapter Indicators".
- Implement Split C: metrics-and-accounting -> "The Accounting Model" plus
  "Metric Contexts And Conventions".
- Implement Split D: experiment-store -> "Data Input And Snapshots" plus the
  refocused "Experiment Store" (which receives the Recovery section).
- Keep Split E deferred out of v0.1.9.5 and record the reason in closeout.
- Update doc-contract pointer locks and pkgdown navigation.
- Add the `Going Deeper` pkgdown group unless an existing convention is better
  during implementation review.
- Apply post-rename public names throughout the split articles.

### Acceptance Criteria

- The split source articles are exactly strategy-development, indicators,
  metrics-and-accounting, and experiment-store per the screening audit;
  sweeps is NOT split (review-patch H-1: the original cut misassigned the
  split letters to the wrong articles).
- Splits A-D produce focused user-facing articles that follow
  `inst/design/vignette_styleguide.md`.
- Recovery docs land in the Split-D successor surface accepted by the naming
  synthesis final review.
- Split E is not partially implemented.
- Existing vignettes do not retain stale cross-links to pre-split anchors.
- Vignette rendering remains green for the affected files.

### Verification

- Render affected vignettes.
- Documentation-contract tests.
- `pkgdown::build_site()` during the release-gate window or earlier if local
  dependencies are available.

### Implementation Notes

- Split A-D landed as:
  `strategy-development` / `strategy-authoring-tools`,
  `indicators` / `ttr-and-adapter-indicators`,
  `metrics-and-accounting` / `metric-contexts-and-conventions`, and
  `data-input-and-snapshots` / `experiment-store`.
- Split E remains deferred; `sweeps` was not split.
- `_pkgdown.yml` now keeps the shorter workflow articles under `Core Workflow`
  and moves companion articles under `Going Deeper`.
- `inst/design/vignette_styleguide.md`, package help, generated Rd, and
  documentation-contract tests were updated for the split article set.
- Affected `.qmd` files were rendered to tracked `.md` mirrors with
  `knitr::knit()`. The render completed with existing mermaid engine warnings
  from knitr, and documentation-contract tests passed afterward.

### Source Reference

- `inst/design/audits/v0_1_9_4_vignette_screening_audit.md`
- `inst/design/vignette_styleguide.md`

### Classification

```yaml
type: documentation
surface: vignettes
scope: split-and-restructure
```

## LDG-2637 - Batch 8 New Teaching Surfaces

Priority: P1
Effort: L
Dependencies: LDG-2633, LDG-2636
Status: Review Pending

Implementation status: Review Pending. Batch 8 articles are implemented and
rendered; awaiting Claude review.

### Description

Add the new teaching surfaces needed for the post-walk-forward public workflow
without implementing validation-toolkit features.

### Tasks

- Add a risk-and-cost execution policy vignette.
- Add a walk-forward research-arc executable article.
- Add a quickstart article that reflects the renamed API and current workflow.
- Verify demo-data date span before writing walk-forward examples.
- Defer the standalone debugging article out of v0.1.9.5 and record the
  disposition.
- Keep all examples within shipped public API and available demo data.

### Acceptance Criteria

- The new articles teach existing behavior only.
- Walk-forward examples do not imply validation toolkit, PBO/CSCV/CPCV, DSR,
  production deployment, or benchmark-relative metrics.
- Quickstart examples are runnable in a clean package session.
- The risk/cost article preserves the cost, risk, liquidity, and OMS boundary.
- Articles follow the vignette styleguide reading-flow standard.

### Verification

- Render new articles.
- Run executable chunks where local dependencies allow.
- Documentation-contract tests for stable teaching pointers.

Implementation notes:

- Added `vignettes/quickstart.qmd` / `.md` for the short demo-data ->
  snapshot -> run -> sweep -> candidate path.
- Added `vignettes/risk-and-cost.qmd` / `.md` for target-risk, timing, cost,
  liquidity, and OMS boundaries.
- Replaced the design-only `walk-forward.qmd` sketch with an executable
  demo-data walk-forward example using compact rolling folds.
- Demo-data span was verified locally as 2018-01-01 through 2022-10-28, with
  10 instruments and 1260 bars per instrument.
- The standalone debugging article remains deferred out of v0.1.9.5.
- Rendered the new/changed articles and ran the documentation-contract tests.

### Source Reference

- `inst/design/audits/v0_1_9_4_vignette_screening_audit.md`
- `inst/design/ledgr_v0_1_9_5_spec_packet/v0_1_9_5_spec.md`
- `inst/design/vignette_styleguide.md`

### Classification

```yaml
type: documentation
surface: teaching
scope: new-articles
```

## LDG-2638 - Batch 9 Maintainer Manual Articles

Priority: P1
Effort: M
Dependencies: LDG-2631, LDG-2634, LDG-2635
Status: Review Pending

### Description

Add maintainer-manual coverage for the post-v0.1.9.x cost, risk, and
walk-forward machinery.

### Tasks

- Add or update the cost-resolver maintainer article.
- Add or update the target-risk layer maintainer article.
- Add or update the walk-forward fold-machinery maintainer article.
- Use the two-layer manual pattern: Synthesis plus Implementation Trace.
- Keep manual text tied to actual code files and accepted RFC/spec decisions.

### Acceptance Criteria

- Each article explains the why and points to the implementation files that
  future maintainers need.
- The articles do not authorize new feature work.
- Naming and identity language matches the post-rename surface.
- Manual links are discoverable through `inst/design/README.md` or the relevant
  manual index.

### Verification

- Manual link check through `rg` and design-index review.
- Render or inspect qmd/md outputs according to local manual conventions.

### Source Reference

- `inst/design/ledgr_v0_1_8_11_spec_packet/v0_1_8_11_spec.md`
- `inst/design/ledgr_v0_1_9_5_spec_packet/v0_1_9_5_spec.md`

### Classification

```yaml
type: documentation
surface: maintainer-manual
scope: implementation-trace
```

## LDG-2639 - Batch 10 Internal Performance And Decisions Narrative

Priority: P2
Effort: M
Dependencies: LDG-2638
Status: Review Pending

### Description

Update internal narrative documents so the cost/risk/sweep/walk-forward arc is
discoverable after the four-tick v0.1.9.x feature sequence.

### Tasks

- Add or update internal performance-arc notes for the v0.1.9.x sequence where
  they clarify current tradeoffs.
- Update decision-index or RFC index references for the naming synthesis and
  validation-toolkit response state.
- Keep narrative text separate from public benchmark claims.
- Avoid broad historical rewrites.

### Acceptance Criteria

- The decision trail from cost API to walk-forward is discoverable.
- The naming-consistency synthesis acceptance is visible in the appropriate RFC
  index or decision surface.
- No new benchmark marketing claim is added.
- No implementation code changes are included.

### Verification

- Manual design-index and RFC-index review.
- `rg` for stale packet-status references introduced by this work.

### Source Reference

- `inst/design/README.md`
- `inst/design/rfc/README.md`
- `inst/design/ledgr_v0_1_9_5_spec_packet/v0_1_9_5_spec.md`

### Classification

```yaml
type: documentation
surface: internal-narrative
scope: decision-discoverability
```

## LDG-2640 - Batch 11 Release Surfaces And Roadmap Audit

Priority: P1
Effort: M
Dependencies: LDG-2636, LDG-2637, LDG-2638, LDG-2639, LDG-2642, LDG-2643, LDG-2644
Status: Review Pending

### Description

Update release-facing surfaces after the rename, split, teaching, and manual
work has landed.

### Tasks

- Update NEWS.md with the final rename table, the
  `ledgr_sweep_review()` / `ledgr_temp_store()` helpers, the walk-forward
  inspection print methods, and the release summary.
- Update README and pkgdown entry points for renamed functions and new teaching
  surfaces.
- Update roadmap, horizon, design index, RFC index, and AGENTS active-packet
  references as appropriate.
- Record deferred Split E, deferred debugging article, N-item dispositions, and
  deferred vignette-audit items (Section 6 splits, lower-value helpers, trades
  entry/exit pairing, and any residual strategy-development trim).
- Audit public docs for old names using the synthesis exclusion rules.

### Acceptance Criteria

- Release surfaces point to the new v0.1.9.5 user workflow.
- NEWS carries the consolidated rename table required by the synthesis.
- Roadmap/horizon/design-index state is coherent with v0.1.9.5 completion and
  v0.1.9.6 validation-toolkit planning.
- Horizon no longer frames `ledgr_sweep_review()` as deferred future work; that
  entry is resolved or narrowed to the still-deferred promotion-recovery summary.
- No stale old-name references remain outside NEWS and design history.

### Verification

- Naming `rg` sweep.
- Documentation-contract tests.
- Manual review of README, NEWS, roadmap, horizon, and design index.

### Source Reference

- `inst/design/rfc/rfc_api_naming_consistency_v0_1_9_5_synthesis.md`
- `inst/design/ledgr_roadmap.md`
- `inst/design/horizon.md`

### Classification

```yaml
type: documentation
surface: release-surfaces
scope: closeout-prep
```

## LDG-2641 - Batch 12 v0.1.9.5 Release Gate

Priority: P0
Effort: M
Dependencies: LDG-2627, LDG-2628, LDG-2629, LDG-2630, LDG-2631, LDG-2632, LDG-2633, LDG-2634, LDG-2635, LDG-2636, LDG-2637, LDG-2638, LDG-2639, LDG-2640, LDG-2642, LDG-2643, LDG-2644
Status: Review Pending

### Description

Run the v0.1.9.5 release gate following the release CI playbook. Stop if a
required gate would force broad or unrelated diffs.

### Tasks

- Read `inst/design/release_ci_playbook.md` before starting the gate.
- Bump DESCRIPTION Version to 0.1.9.5 before the gate runs (review-patch
  M-2; spec Batch 0 routes the bump to the release-gate batch).
- Run full local tests.
- Run README cold-start verification.
- Build and check the package.
- Run coverage when applicable to the active CI matrix.
- Build pkgdown.
- Run the local WSL/Ubuntu gate required by the playbook.
- Push the branch, monitor branch CI, merge to main, monitor main CI, and tag
  only after the playbook gates pass.
- Write the v0.1.9.5 release closeout note.

### Acceptance Criteria

- DESCRIPTION carries Version 0.1.9.5 at tag time.
- The release playbook was read into context before commands were run.
- The gate includes the release-playbook diff-size guard: stop and ask the
  maintainer before making broad generated-doc, pkgdown, or unrelated cleanup
  diffs.
- Full tests, package check, pkgdown, and local Ubuntu gate have recorded
  outcomes.
- Naming synthesis gates are satisfied, including old-name sweep, internal
  collision check, NEWS table, and M-8 completion.
- Vignette-screening audit scheduled items are closed or explicitly deferred
  with rationale.
- Vignette audit (2026-06-13) scheduled items are closed or explicitly deferred
  with rationale: the four stale facts and the two helpers are in scope; the
  `sweeps` / `metric-contexts` splits, lower-value helpers, trades entry/exit
  pairing, and residual strategy-development trim are deferred to horizon if not
  fixed.
- Branch CI, main CI, merge, and tag are completed before closeout is marked
  done.

### Verification

- Commands and outputs recorded in the release closeout.
- CI checks linked or summarized.
- `git status --short` clean before tag.

### Source Reference

- `inst/design/release_ci_playbook.md`
- `inst/design/ledgr_v0_1_9_5_spec_packet/v0_1_9_5_spec.md`

### Classification

```yaml
type: release
surface: release-gate
scope: v0.1.9.5
```

## LDG-2642 - Batch 8A Walk-Forward, Sweep, And Store UX Helpers

Priority: P1
Effort: M
Dependencies: LDG-2632, LDG-2633
Status: Review Pending (implementation complete; awaiting Claude review; walk-forward print methods already landed 2026-06-13, Codex-reviewed)

### Description

Implement the additive, identity-neutral UX-gap helpers from the v0.1.9.5
vignette audit Section 3, and record the walk-forward inspection print methods
already implemented this cycle. These helpers retire boilerplate duplicated
across multiple vignettes and resolve standing in-article design notes.

### Tasks

- Record (done 2026-06-13, Codex-reviewed): `print.ledgr_walk_forward_degradation`
  curated print and `print.ledgr_fold_list` per-fold window print.
- Implement `ledgr_sweep_review()`: returns review tables (rank, top-N,
  issue/flag columns) for a sweep result. Scope boundary: returns tables only;
  it must NOT choose or promote a winner (selection/promotion stay with
  `ledgr_candidate()` / `ledgr_promote()`).
- Implement `ledgr_temp_store()`: returns a disposable `.duckdb` path and removes
  any stale file already at that path. Scope boundary: path plus stale-file
  removal only; no store init/open/seal/lifecycle. Confirm the name against the
  naming synthesis utility-helper convention.
- Add targeted tests for each helper.
- Update NAMESPACE, generated docs, and NEWS.

### Acceptance Criteria

- `ledgr_sweep_review()` returns a review table and performs no selection or
  promotion.
- `ledgr_temp_store()` returns a fresh disposable path and clears any stale file;
  performs no store lifecycle.
- The walk-forward print methods are tested and recorded.
- Export-lock updated, `tools::checkRd()` clean, NEWS carries the helpers.

### Implementation Notes

- Added `ledgr_sweep_review()` as a no-selection review helper returning
  `ranked`, `top`, and `issues` tables. Ranking uses an explicit `rank_by`
  expression so the rule stays visible at the call site.
- Added `ledgr_temp_store()` as a path-and-clear helper for disposable
  `.duckdb` files. It does not open, initialize, seal, or manage stores.
- Exported both helpers, registered `print.ledgr_sweep_review`, updated
  generated docs, pkgdown references, NEWS, and the export lock.
- Verification passed:
  `testthat::test_file('tests/testthat/test-sweep-review.R')`,
  `testthat::test_file('tests/testthat/test-api-exports.R')`, and
  `tools::checkRd()` for the two new Rd pages.

### Tests

- Targeted helper tests, export-lock test, `tools::checkRd()`.

### Source Reference

- `inst/design/audits/v0_1_9_5_vignette_audit.md` Section 3.

### Classification

```yaml
type: feature
surface: public-api
scope: ux-helpers
```

## LDG-2643 - Batch 8B Vignette Stale-Fact Fixes

Priority: P1
Effort: S
Dependencies: LDG-2627
Status: Review Pending (implementation complete; awaiting Claude review)

### Description

Fix the four verified stale facts from the v0.1.9.5 vignette audit Section 2.

### Tasks

- `why-r.qmd`: correct the Imports list (`jsonlite` -> `yyjsonr`) and reconcile
  the full list against `DESCRIPTION`.
- `research-to-production.qmd`: add sweep persistence (v0.1.9.2) and the public
  target-risk API (v0.1.9.3) to the delivered list; re-anchor the validation
  toolkit to v0.1.9.6 and paper/observability/live to v0.3.0/v0.4.0/v1.0.0;
  de-version delivered behavior (e.g. "In v0.1.9.1...").
- `execution-semantics.qmd`: replace the trades `any_of()` nonexistent-column
  list with the real schema (`ts_utc`, `qty`, `realized_pnl`); note that trades
  are close-action fill rows.
- `experiment-store.qmd`: replace the stale "out of v0.1.8.5" boundary with the
  current planned cycle.
- Re-render affected `.md`.

### Acceptance Criteria

- `why-r` Imports list matches `DESCRIPTION`.
- `research-to-production` delivered/planned sections match the roadmap and NEWS;
  the styleguide Section 12 release-gate roadmap check passes.
- `execution-semantics` trades example selects only existing columns.
- No current/past-version stamping of shipped behavior remains in these four
  articles.
- Documentation-contract tests pass; rendered `.md` regenerated.

### Tests

- Documentation-contract tests; render affected vignettes.

### Implementation Notes

- Corrected `vignettes/articles/why-r.qmd` to match the current
  `DESCRIPTION` Imports list (`collapse`, `codetools`, `DBI`, `digest`,
  `duckdb`, `rlang`, `tibble`, `yyjsonr`).
- Updated `research-to-production` so current cost, sweep persistence,
  target-risk identity, and walk-forward behavior are described as shipped
  behavior without current-version stamping; planned validation-toolkit,
  paper, observability, and live work now uses the roadmap anchors
  v0.1.9.6, v0.3.0, v0.4.0, and v1.0.0.
- Updated `execution-semantics` to select real trades columns
  (`ts_utc`, `qty`, `realized_pnl`) and to state that trades are close-action
  fill rows rather than paired entry/exit rows.
- Updated `experiment-store` to route external point-in-time regressors to the
  v0.2.x point-in-time data line instead of a stale v0.1.8.5 boundary.
- Affected `.md` mirrors were kept hand-synced. Quarto render was attempted
  with the RStudio-bundled executable but the subprocess could not resolve
  required Imports (`collapse`, `yyjsonr`) in this local shell.

### Source Reference

- `inst/design/audits/v0_1_9_5_vignette_audit.md` Section 2.

### Classification

```yaml
type: documentation
surface: vignettes
scope: stale-fixes
```

## LDG-2644 - Batch 8C Vignette Editorial Cleanups And Helper Adoption

Priority: P2
Effort: L
Dependencies: LDG-2642, LDG-2636

### Status

Review Pending (implementation complete; awaiting Claude review)

### Description

Apply the cross-cutting editorial fixes from the v0.1.9.5 vignette audit
Section 1, the Section 5 visualization gap where data already exists, and adopt
the two new helpers in the consuming articles.

### Tasks

- Convert decorative "Definition" note callouts to inline prose in `indicators`
  (5), `sweeps` (4), `strategy-development` (3), `metrics-and-accounting` (3),
  and `custom-indicators` (1); reserve callouts for scan-critical guidance.
- Rewrite topic-list openings to user-outcome inverted-pyramid in
  `strategy-authoring-tools`, `indicators`, `metric-contexts-and-conventions`,
  and `sweeps`.
- Add "Where Next" closings to `custom-indicators`, `leakage`, and
  `research-to-production`; rename `experiment-store` "What's Next?" to
  "Where Next" and add the reproducibility link.
- De-duplicate the `strategy-development` / `strategy-authoring-tools` shared
  boilerplate opening and snapshot setup (one canonical home plus cross-link);
  fix the snapshot cross-link to `data-input-and-snapshots` in both.
- Fix the `eval: false`-hides-the-lesson chunks (`metric-contexts`
  `metric-context-provenance` executes; review `strategy-authoring-tools`
  debug-checklist, `custom-indicators` `adapter-r`, `ttr` `ttr-pulse-snapshot`).
- Drop `dplyr::` qualifiers in the `ttr-and-adapter-indicators` attached-package
  chunk.
- Adopt `ledgr_sweep_review()` in `sweeps` and `research-workflow`; adopt
  `ledgr_temp_store()` in `data-input-and-snapshots` and `experiment-store`;
  remove the standing future-helper design notes.
- Add the missing equity-curve plot where the data already exists
  (`metrics-and-accounting`; the `research-workflow` report outline).
- Re-render all affected `.md`.

### Acceptance Criteria

- Decorative Definition callouts removed; callout hierarchy restored.
- Named openings replace topic lists in the four flagged articles.
- All core vignettes have a "Where Next" closing.
- Strategy-article duplication removed; snapshot cross-link points to
  `data-input-and-snapshots`.
- Flagged `eval: false` chunks execute or carry a justified label.
- `sweeps`/`research-workflow` use `ledgr_sweep_review()`;
  `data-input`/`experiment-store` use `ledgr_temp_store()`; design notes removed.
- Documentation-contract tests updated and passing; rendered `.md` regenerated.

### Tests

- Documentation-contract tests; render affected vignettes; `rg` for removed
  boilerplate and design notes.

### Implementation Notes

- Adopted `ledgr_sweep_review()` in `sweeps` and `research-workflow`, and
  `ledgr_temp_store()` in `data-input-and-snapshots` and `experiment-store`.
- Converted the targeted decorative Definition callouts to inline prose,
  refreshed flagged article openings, added "Where Next" closings, and removed
  standing future-helper design notes.
- Added equity-curve plots where existing run evidence already exists.
- Re-rendered affected `.md` mirrors with Quarto after installing the missing
  render-time R 4.6 dependencies; generated files were not hand-synced.
- The independently reviewed `execution-semantics` teachability rewrite was
  handled in a separate commit from LDG-2644.

### Source Reference

- `inst/design/audits/v0_1_9_5_vignette_audit.md` Sections 1 and 5.

### Classification

```yaml
type: documentation
surface: vignettes
scope: editorial-and-adoption
```
