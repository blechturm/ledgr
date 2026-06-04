# ledgr v0.1.8.11 Batch Plan

**Status:** Active; Batch 11 deterministic substrate manual articles complete
after Claude review. Rescoped 2026-06-04 to
absorb the manual remainder and complete the `adr/` + `architecture/` +
`maintainer_review/` wind-downs in this release (Batches 11-14 grouped for
joint review; release gate becomes Batch 15). Section 3.7 of the spec
introduces the two-layer manual article standard binding for every Batch
11-14 article.

v0.1.8.11 is a documentation, structure, and cleanup cycle. It is deliberately
not a feature cycle. The core risk is scope bloat: documentation synthesis can
become as large as implementation if every useful article is treated as required
for release. This plan keeps audit and authority cleanup first, then batches
manual/user-facing work with an explicit split trigger.

## Split Trigger

The original split trigger reserved a follow-on release for the manual /
vignette / narrative / disclaimer remainder. On 2026-06-04 the maintainer
rescoped: the manual remainder is absorbed into v0.1.8.11 via Batches 11-13,
because a separate doc-only release would consume hours of tag-CI for no
execution surface change. The current discipline: if any single new manual
ticket blows its budget, route that ticket's residual to v0.1.9.x follow-on
documentation, not a new v0.1.8.x version. The v0.1.9 feature arc should
start only after the codified architecture is discoverable enough for safe
feature planning, and the `adr/` and `architecture/` directories are wound
down.

## Batch 0 - Packet Review And Ticket Alignment

Ticket: `LDG-2527`
Status: Completed

Goal: finalize the spec, tickets, YAML, batch plan, design index, roadmap,
horizon, agent notes, and review-loop caveats before implementation starts.

Exit criteria:

- Ticket cut is reviewed and caveats are patched or accepted.
- Spec, tickets, YAML, and batch plan agree.
- Active design index points to v0.1.8.11.
- No ticket authorizes execution, API, target-risk, OMS, walk-forward,
  cost/liquidity, durable compiled, non-spot compiled, or public benchmark-claim
  work.
- Split trigger is explicit.

Completion note:

Batch 0 completed on 2026-06-03. The packet seed was reviewed, caveats were
patched into the spec, tickets were cut, packet metadata was validated, and
the active design index / roadmap / horizon / AGENTS.md context points at
v0.1.8.11. Substantive work now starts with Batch 1 / `LDG-2528`.

## Batch 1 - contracts.md Audit Report

Ticket: `LDG-2528`
Status: Completed

Goal: audit `contracts.md` before editing it.

Exit criteria:

- `contracts_audit.md` exists in the packet.
- Findings are classified as fix-now, defer-with-reason, no-action, or later
  RFC.
- B2 scope guard, durable compiled deferral, one-fold-core language, canonical
  event evidence, and documentation-discovery contracts are reviewed.
- No contract edits land in this batch.

Completion note:

`contracts_audit.md` was completed on 2026-06-03 after Claude review. It routes
five fix-now contract-cleanup findings to `LDG-2531`, records no-action and
later-RFC boundaries, and leaves `contracts.md` unchanged.

## Batch 2 - Roadmap Horizon And Design Index Housekeeping

Ticket: `LDG-2529`
Status: Completed

Goal: finish active/completed packet housekeeping after v0.1.8.10 and before
substantive v0.1.8.11 documentation work.

Exit criteria:

- Roadmap, horizon, design index, and AGENTS.md agree on active v0.1.8.11.
- Closed v0.1.8.10 work is no longer shown as active planning.
- Future v0.1.9/v0.1.9.x work remains parked with correct boundaries.
- No implementation files change.

Completion note:

Batch 2 completed on 2026-06-03. The design index, AGENTS.md, roadmap, horizon,
packet spec, tickets, YAML, and batch plan agree that v0.1.8.11 is active and
that v0.1.8.10 is closed. Stale active-state wording was removed, the
post-K1/B2 horizon promotion line now acknowledges the completed scoped B2 gate
while keeping compiled fold-core commitment deferred, and no implementation
files changed. Substantive work now moves to Batch 3 / `LDG-2530`.

## Batch 3 - RFC Decision Index And ADR Routing

Ticket: `LDG-2530`
Status: Completed

Goal: make accepted decisions discoverable and route stable decisions into ADRs
where useful.

Exit criteria:

- RFC decision index home is chosen.
- Topic-oriented index links to binding RFCs, final reviews, ADRs, packets, and
  contracts.
- ADR routing is recorded for B2 spot-FIFO scope guard, canonical R default,
  matrix-canonical strategy accessor contract, and fold-owned FIFO accounting.
- RFCs remain authoritative; synthesis does not replace them.

Completion note:

Batch 3 completed after Claude review on 2026-06-03. The evergreen RFC decision
index lives at `inst/design/rfc/README.md`, links topic decisions back to RFC
syntheses, final reviews, ADRs, packet records, and contracts, marks
historical/scaffolding artifact classes, and records ADR routing for the four
named candidates. Claude review patches re-attributed the parallel-dispatch row
to the sweep architecture note, added the B2 maintainer-decisions authority,
clarified non-synthesis binding artifacts, added the snapshot trust-boundary
row, and promoted the B2 spot-FIFO scope guard to ADR-0005. No accepted RFC text
was rewritten as replacement authority. Substantive work moves to Batch 4 /
`LDG-2531`.

## Batch 4 - contracts.md Structure Pass

Ticket: `LDG-2531`
Status: Completed

Goal: consume `contracts_audit.md` and clean / structure `contracts.md` only
where the audit routes fix-now work.

Exit criteria:

- Every `contracts.md` edit traces to `contracts_audit.md`.
- No existing contract is weakened silently.
- Semantic bugs are routed to later tickets/RFCs, not fixed incidentally.
- Post-v0.1.8.10 surfaces remain clearly separated.

Completion note:

Batch 4 completed after Claude review on 2026-06-03. `contracts.md` edits trace
only to C-001 through C-005 in `contracts_audit.md`: active packet pointer,
fold-entry guard tense, R6 / legacy strategy wording, removed context helper
tense, and historical CI wording. Claude review patches restored the
committed-run recompute/compare and sweep-hash-provenance guard mechanisms,
kept R6 in the static-analysis caveat, and tightened the lead paragraph's
README/spec-packet authority wording. No execution semantics, public API,
compiled-accounting scope, target-risk, OMS, walk-forward, or cost/liquidity
contracts were broadened. Substantive work moves to Batch 5 / `LDG-2532`.

## Batch 5 - Maintainer Manual Foundation

Ticket: `LDG-2532`
Status: Completed

Goal: author the first reviewed batches of internal maintainer manual prose.

Exit criteria:

- Article priority order is followed: execution/fold core, observability /
  determinism, sweep, snapshots/data, features, benchmark methodology.
- At least the first prioritized article batch is reviewable.
- Governance records remain authoritative and are linked.
- Any incomplete article family has bounded follow-on disposition.

Completion note:

Batch 5 completed after Claude review on 2026-06-03. The `inst/design/manual/`
foundation now contains `README.qmd` with article order, source map, and
bounded remainder, plus `execution_fold_core.qmd` as the first priority
execution/fold core article. The sources render to sibling GitHub-flavored
Markdown for repository browsing. The article follows the local vignette
styleguide shape where applicable: outcome first, one article job,
scan-critical Quarto callouts, Mermaid diagram, shape-only illustrative strategy
snippet, and a short "Where Next" close. It synthesizes the shared fold core,
pulse lifecycle, output handlers, sealed-snapshot trust boundary, exact strategy
target contract, determinism surfaces, and B2 scope guard while linking to
binding contracts, RFCs, ADRs, architecture notes, workbooks, and packet
records. Claude review patches tightened exact target matching, callout
rendering, strategy-state vocabulary, GitHub Markdown output, and release-gate
routing of the five deferred families. No execution or API changes landed.
Substantive work moves to Batch 6 / `LDG-2533`.

## Batch 6 - User-Facing Documentation Refresh

Ticket: `LDG-2533`
Status: Completed

Goal: refresh first-pass user-facing docs for post-v0.1.8.10 strategy accessors,
sweep economics, and B2 boundaries.

Exit criteria:

- Strategy development, research workflow, who-ledgr-is-for, and why R are
  reviewed or explicitly deferred.
- Documentation teaches `ctx$vec`, `ctx$idx()`, and
  `ctx$vec$feature(feature_id)` where appropriate.
- Pass 2 strategy helpers remain deferred.
- B2 is not described as default, durable, non-spot, or general compiled
  execution.

Completion note:

Batch 6 completed after Claude review on 2026-06-03. Refreshed `README.md`,
`vignettes/strategy-development.qmd`, `vignettes/research-workflow.qmd`,
`vignettes/sweeps.qmd`, `vignettes/articles/who-ledgr-is-for.qmd`, and
`vignettes/articles/why-r.qmd`. Rendered tracked GFM siblings for
`strategy-development`, `research-workflow`, and `sweeps`; article-subdirectory
renders were used as verification only because those Markdown outputs are not
tracked. Claude's blocker on GFM callout drift was resolved by adding
`tools/render-vignettes-gfm.R`, which preserves pkgdown-safe source callouts
and normalizes rendered Markdown callouts back to GitHub admonitions. The
refresh teaches `ctx$idx()`, `ctx$vec`, and
`ctx$vec$feature(feature_id)`, describes memory-backed sweep economics, removes
stale sweep-helper/version wording, and names B2 only as explicit
`ledgr_sweep(..., compiled_accounting_model = "spot_fifo")` memory-backed
spot-FIFO opt-in. No public helper API, execution semantics, durable compiled,
non-spot compiled, or general compiled fold-core scope landed. Substantive work
moves to Batch 7 / `LDG-2534`.

## Batch 7 - Performance Arc Narrative

Ticket: `LDG-2534`
Status: Completed

Goal: write an internal teaching narrative for the v0.1.8.7-v0.1.8.10
performance arc.

Exit criteria:

- Narrative lives under `inst/design/manual/`.
- Raw evidence remains under `dev/bench/`.
- The article links to packet and benchmark artifacts.
- Local/current-source/machine-specific caveats are explicit.
- No public speed-claim marketing language appears.

Completion note:

Batch 7 completed after Claude review on 2026-06-03. Added
`inst/design/manual/performance_arc_v0_1_8_x.qmd` and rendered sibling
Markdown. The article explains the v0.1.8.7 to v0.1.8.10 performance arc as an
internal maintainer synthesis, links to benchmark and packet closeout artifacts
instead of copying raw local records, separates canonical R, memory-backed,
durable, peer, and B2 spot-FIFO opt-in surfaces, and preserves
same-host/current-source/machine-specific caveats. The manual index now includes
the article and routes remaining benchmark-methodology work to future
record-generation/release-gate details. No public speed-claim marketing or
execution/API change landed. Substantive work moves to Batch 8 / `LDG-2535`
after Claude review.

## Batch 8 - Research Software Disclaimer Surface

Ticket: `LDG-2535`
Status: Completed

Goal: add a modest, plain-English disclaimer surface for financial research
software.

Exit criteria:

- `DISCLAIMER.md` exists if approved by review.
- README and relevant introductory docs link to it modestly.
- No DESCRIPTION metadata change lands unless explicitly requested.
- Language is plain, concise, and not commercial legal prose.

Completion note:

Batch 8 completed after Claude review on 2026-06-04. Added root
`DISCLAIMER.md` with plain-English financial research-software boundaries;
linked it modestly from `README.md`,
`vignettes/articles/who-ledgr-is-for.qmd`, and `vignettes/research-workflow.qmd`
plus rendered `research-workflow.md`. The disclaimer states ledgr is research
software, not investment advice; backtests do not predict future performance;
and audit/replay/provenance features are research tools, not compliance or
regulatory guarantees. No DESCRIPTION metadata change landed. Claude's only
required patch was reverting incidental live-output drift in
`vignettes/research-workflow.md`; the recurring render-drift issue is routed to
Batch 9 / `LDG-2536`.

## Batch 9 - Generated Docs And Man-Page Audit

Ticket: `LDG-2536`
Status: Completed

Goal: audit generated docs and man pages for stale language and route fixes.

Exit criteria:

- `generated_docs_audit.md` exists in the packet.
- Findings name files, classifications, and consuming tickets.
- The audit includes the Batch 8 finding that rendered vignette Markdown can
  pick up incidental live-output drift unrelated to the source-doc edit.
- Generated artifact churn only follows source-doc changes.
- Any required doc-render checks are identified.

Completion note:

Batch 9 completed after Claude review on 2026-06-04. Added
`generated_docs_audit.md`, covering `man/`, absent `inst/doc/`, and
`vignettes/`. The audit routes stale version-pinned vignette/Roxygen language,
Claude's rendered-vignette live-output drift finding, and source/generated
traceability expectations without changing generated artifacts. Claude approved
the routing artifact and recommended a separate consuming ticket; LDG-2539 now
consumes GD-001 through GD-008.

## Batch 9.5 - Generated Docs Stale-Language Cleanup

Ticket: `LDG-2539`
Status: Completed

Goal: consume the source-doc cleanup and render-drift process findings from
`generated_docs_audit.md`.

Exit criteria:

- GD-001 through GD-007 are fixed through source docs, not direct generated
  artifact edits.
- GD-008 is consumed by a documented render-drift discipline or explicitly
  routed forward with rationale.
- Affected `.Rd` and `.md` artifacts are regenerated/rendered only from changed
  sources.
- `rg` checks show the stale version-pinned language no longer appears except
  where intentionally retained as runtime migration diagnostics.
- Generated artifact diffs match source intent; unrelated live-output drift is
  reverted or separately routed.

Completion note:

LDG-2539 closed after review on 2026-06-04. The consuming cleanup handled
GD-001 through GD-008 from `generated_docs_audit.md` through source-owned
documentation updates, source/generated traceability review, and render-drift
discipline checks. No execution semantics, public API, target-risk, OMS,
walk-forward, cost/liquidity, durable compiled, non-spot compiled, or public
benchmark-claim work landed under this ticket.

## Batch 10 - inst/ Subdirectory Audit And Cleanup

Ticket: `LDG-2538`
Status: Completed

Goal: inventory `inst/design/architecture/`,
`inst/design/maintainer_review/`, `inst/diagrams/`, `inst/examples/`,
`inst/schemas/`, and `inst/testdata/`, and route stale or unreferenced files to
deletion, gitignore, manual migration, or retention. Runs after or in parallel
with Batch 9.5 / `LDG-2539` by convenience; both must close before the release
gate.

Exit criteria:

- `inst_audit.md` exists in the packet and routes every audited file with a
  disposition.
- Load-bearing architecture notes remain in place during the audit batch. Any
  relocation requires a separate migration ticket.
- `.Rbuildignore` reflects the audit outcome.
- Approved deletions, gitignores, and migrations are applied after audit
  review.
- Full test suite, `R CMD check`, and manual render pass after cleanup.
- Tarball size before/after cleanup is recorded in the completion note.

Completion note:

Batch 10 completed on 2026-06-04 after review. Added `inst_audit.md`, covering
all 19 tracked scoped files plus ignored local Quarto render artifacts under
`inst/design/maintainer_review/`. The audit preserves the binding architecture
paths, keeps the maintainer-review workbooks excluded from package builds, and
keeps `inst/testdata/yahoo_mock.csv` as a load-bearing installed test fixture.
The reviewed cleanup deleted `INST-011` through `INST-018`: six stale
unreferenced Mermaid diagrams, the empty schemas placeholder, and the stale
installed examples README. No files were moved, migrated, or newly gitignored.
Tracked scoped-file size before cleanup was 167,999 bytes. Package tarball size
was 3,153,183 bytes before cleanup and 3,151,436 bytes after cleanup, a
1,747-byte reduction. Verification: `git diff --check` passed; `tickets.yml`
status graph passed; `R CMD build --no-build-vignettes` succeeded before and
after cleanup; `R CMD check --no-manual --no-build-vignettes` completed with
the existing 2 warnings / 2 notes state; manual render passed via RStudio's
bundled Quarto; full local tests failed only in
`test-documentation-contracts.R` on stale generated-doc/manual assertions
already routed to LDG-2539.

## Batch 11 - Deterministic Substrate Manual Articles

Tickets: `LDG-2540`, `LDG-2541`
Status: Completed

Grouped because both articles cover the deterministic-identity substrate
(observability/determinism + snapshots/data) and absorb the three v0.1.2-era
identity ADRs (0001/0002/0003) plus the fold trust-boundary note. Joint
review confirms consistent terminology across the pair and complete ADR
wind-down for 0001/0002/0003.

Goal: author `observability_determinism.qmd` and `snapshots_data.qmd`; migrate
ADR-0001 + ADR-0002 + ADR-0003 rationale into the respective articles;
migrate the fold trust-boundary note into the snapshots article;
delete the migrated source files and re-point active citation sites.

Exit criteria:

- Both articles reviewable per the Section 3.7 two-layer standard:
  - Synthesis layer (outcome first, Quarto-native callouts, source links,
    "Where Next" close).
  - Implementation Trace layer with data structures, file:line code anchors,
    lookup/dispatch mechanisms, edge cases, hot/cold path distinction. For
    observability/determinism: telemetry/preflight registry shapes,
    config_hash/closure_hash algorithms, ambient-RNG detection,
    `ctx$pulse_seed` derivation, parallel-equivalence enforcement. For
    snapshots/data: snapshot/run DB schemas, snapshot_hash algorithm,
    verify-true code path, fold-entry guard mechanisms for committed runs
    vs sweeps.
- ADR-0001 (split-db), ADR-0002 (registry fingerprint), and ADR-0003 (closure
  fingerprinting) rationale migrated without weakening contract bindings.
- Fold trust-boundary content migrated into snapshots/data with the
  binding recompute-and-compare + validate-handle-and-carry-hash mechanism
  language preserved.
- ADR-0001, ADR-0002, ADR-0003, and the fold trust-boundary architecture note
  deleted; active citations re-pointed;
  `adr/README.md` and `architecture/README.md` existing-records tables
  updated.
- Both manual GFM siblings render cleanly with no unexpected drift.
- Terminology is consistent across the two articles (no contradictions on
  determinism vs trust boundary).
- No execution semantics, API, or new contract authorship.

Completion note:

Batch 11 is complete after Claude review. Added
`observability_determinism.qmd` and `snapshots_data.qmd`, migrated the
ADR-0001/0002/0003 rationale plus the fold trust-boundary rationale into those
articles, deleted the migrated source files, re-pointed active design indexes,
and updated the installed-file metadata test to expect rendered manual
rationale pages instead of deleted ADRs. After the 2026-06-04 Section 3.7
rescope, both articles were expanded from synthesis-only orientation into the
required two-layer standard with Implementation Trace sections covering data
structures, file:line anchors, lookup/dispatch mechanisms, edge cases,
hot/cold path distinctions, and concrete examples. Claude approved the updated
sections and spot-checked anchor freshness across both articles.

## Batch 12 - Research-Surface Manual Articles

Tickets: `LDG-2542`, `LDG-2543`
Status: In Review

Grouped because both articles cover user-facing analytical surfaces built on
the deterministic substrate (sweep + features), and absorb the three
architecture/ UX-or-architecture notes. Joint review confirms architecture/
migration completeness for the heavy citation set and consistent
sweep/features cross-references.

Goal: author `sweep.qmd` and `features.qmd`; migrate
`architecture/ledgr_v0_1_8_sweep_architecture.md`,
`architecture/ledgr_sweep_mode_ux.md`, and
`architecture/ledgr_feature_map_ux.md` into the respective articles; decide
`architecture/sweep_mode_code_review.md` disposition; delete the migrated
source files and re-point all citation sites (~80+ across the repo).

Exit criteria:

- Both articles reviewable per the Section 3.7 two-layer standard:
  - Synthesis + Implementation Trace layers, both present.
  - Sweep article Implementation Trace: candidate_id derivation, worker
    dispatch mechanism with file:line anchors, discard-all interrupt code
    path, memory output handler shape, B2 dispatch in candidate execution,
    `ledgr_promote()` code flow.
  - Features article Implementation Trace: absorbs
    `maintainer_review/feature_value_path_workbook.qmd` depth content;
    covers `ctx$feature()` resolution chain, feature cache key shape,
    features-engine.R structure, TTR adapter mechanism, alias map
    resolution.
- Parallel-sweep dispatch synthesis-equivalent language preserved without
  weakening the "candidate dispatch, not a second engine" invariant.
- `rfc/README.md` Parallel Sweep Dispatch row's Primary authority updated
  from `architecture/ledgr_v0_1_8_sweep_architecture.md` to the new sweep
  manual article.
- B2 scope language in the sweep article consistent with the horizon entry +
  maintainer-decisions doc + contracts.md trio.
- Feature-map UX rationale migrated without introducing new public API.
- `architecture/sweep_mode_code_review.md` disposition recorded (absorbed,
  routed to rfc/, or deleted with explicit reasoning).
- All four architecture/ source files deleted (or the code-review file is
  routed elsewhere); citations re-pointed; `architecture/README.md` existing-
  records table updated.
- Both manual GFM siblings render cleanly.

Status note:

Batch 12 is partially complete. LDG-2543 is completed after review. LDG-2542
remains in review: `inst/design/manual/sweep.qmd` and its rendered sibling are
not present yet, and the sweep architecture/UX source files remain active until
the sweep article absorbs them and records `sweep_mode_code_review.md`
disposition.

## Batch 13 - Wind-Down Completion

Tickets: `LDG-2544`, `LDG-2545`
Status: Planned

Grouped because both are small cleanup work that closes out the v0.1.8.11
discoverability arc: LDG-2544 finishes the `adr/` wind-down; LDG-2545
finishes the benchmark methodology family. Joint review confirms both legacy
directories (`adr/` and `architecture/`) are in their final wound-down state
(`README.md` only or deleted) and the manual surface is complete.

Goal: split ADR-0004 rationale across `execution_fold_core.qmd` (function-only
strategy interface) and `performance_arc_v0_1_8_x.qmd` (dependency posture);
delete `adr/0004`; author the benchmark methodology residual article (or fold
into a performance_arc section if maintainer prefers).

Exit criteria:

- Both target articles (`execution_fold_core`, `performance_arc`) carry
  ADR-0004 rationale without weakening contract language. Note: the
  Implementation Trace retrofit for these two articles is Batch 14's
  responsibility (LDG-2546), not this batch — Batch 13 only adds the
  ADR-0004 rationale Synthesis-layer content; Batch 14 does the depth pass.
- `adr/0004-...` deleted; citations re-pointed; `adr/README.md` reflects the
  wound-down state.
- `adr/` directory contains only `README.md` or is deleted entirely
  (maintainer call at close-out time).
- `architecture/` directory contains only `README.md` or is deleted entirely
  (confirmed at this batch's close since Batches 11+12 land all migrations).
- Benchmark methodology residual article (or section) is reviewable;
  Synthesis + Implementation Trace layers both present per Section 3.7;
  public-speed-claim language is absent; links to `dev/bench/README.md` and
  performance_arc.
- All affected manual GFM siblings render cleanly.

## Batch 14 - Existing-Article Depth Retrofit And maintainer_review/ Wind-Down

Ticket: `LDG-2546`
Status: Completed

This batch executes the corrective for the 2026-06-04 review finding: the
two existing manual articles (`execution_fold_core`, `performance_arc`) need
Implementation Trace sections to meet the Section 3.7 standard, and the
`maintainer_review/` directory (which holds the depth source) winds down.

Goal: add Implementation Trace sections to `execution_fold_core.qmd` and
`performance_arc_v0_1_8_x.qmd` by absorbing depth from the retired fold-core
and v0.1.8.7 optimization workbooks; author
`maintainer_review/README.md` codifying the wind-down; delete absorbed
workbooks; verify `maintainer_review/` contains only `README.md` and the
temporarily retained `feature_value_path_workbook.qmd`.

Exit criteria:

- `execution_fold_core.qmd` has an `## Implementation Trace` section meeting
  the Section 3.7 standard: per-pulse `ctx` env shape, strategy-state env
  shape, fold-entry sealed-snapshot guard code path with file:line anchors,
  `compiled_accounting_model` dispatch (R/sweep.R, R/compiled-spot-fifo.R
  lines), event emission boundaries, telemetry checkpoint mechanism,
  hot/cold path distinction.
- `performance_arc_v0_1_8_x.qmd` has an `## Implementation Trace` section
  covering lane-attribution mechanism, per-fill cost decomposition,
  phase-decomposition harness shape, dev/bench/results record layout, and
  the per-package optimization mechanisms that landed across
  v0.1.8.7-v0.1.8.10.
- Code anchors cite specific source files with line numbers; spot-check
  freshness during review.
- `maintainer_review/README.md` codifies the wind-down with per-file
  migration disposition (parallel to `adr/README.md` and
  `architecture/README.md`).
- Retired fold-core workbook deleted; relevant citations re-pointed.
- Retired v0.1.8.7 optimization workbook deleted.
- `maintainer_review/` contains only `README.md` and
  `feature_value_path_workbook.qmd`.
- Both retrofitted manual GFM siblings render cleanly with no unexpected
  drift.
- No new contracts authored; no existing contract weakened.

Completion state:

- Added `## Implementation Trace` to `execution_fold_core.qmd` with source-line
  anchors for the execution spec, pulse context, strategy-state persistence,
  sealed-snapshot guard, output handlers, telemetry, and B2 dispatch.
- Added `## Implementation Trace` to `performance_arc_v0_1_8_x.qmd` with
  source-line anchors for benchmark phase decomposition, record layouts,
  per-fill costs, event buffers, fill reconstruction, yyjsonr canonical JSON,
  collapse determinism, and B2 dispatch.
- Rewrote `maintainer_review/README.md` as a wind-down policy, deleted the
  absorbed workbooks and local render artifacts, and retained only the feature
  workbook pending LDG-2543.
- Repointed live manual source links to the new implementation traces.
- Claude review approved the Batch 14 retrofit and recommended close after
  spot-checking approximately 50 source anchors across both retrofitted
  articles.

## Batch 15 - Release Gate

Ticket: `LDG-2537`
Status: Planned

Goal: close the documentation/cleanup cycle and prepare merge/tag.

Exit criteria:

- Completed tickets have artifacts and verification notes.
- Any unfinished manual article residual is routed to v0.1.9.x follow-on
  documentation (no v0.1.8.12 follow-on is cut).
- The five deferred manual article families from LDG-2532 are authored:
  observability/determinism (LDG-2540), snapshots/data (LDG-2541), sweep
  (LDG-2542), features (LDG-2543), benchmark methodology (LDG-2545).
- The `adr/` directory contains only `README.md` or is deleted (LDG-2530 +
  LDG-2540 + LDG-2541 + LDG-2544 wind-down complete).
- The `architecture/` directory contains only `README.md` or is deleted
  (LDG-2541 + LDG-2542 + LDG-2543 migrations complete).
- LDG-2539 generated-doc cleanup findings are consumed or explicitly routed
  forward with source/generated traceability preserved.
- LDG-2538 `inst_audit.md` findings are consumed or routed forward with the
  binding-path constraint preserved.
- `Rscript tools/render-maintainer-manual.R` completes and the committed
  Markdown siblings have no unexpected drift from the Quarto sources.
- NEWS, design index, roadmap, horizon, AGENTS.md, and release notes are updated
  as needed.
- Relevant doc renders, targeted tests, full tests/package checks, and release
  playbook steps pass or accepted caveats are documented.
- No generated local artifacts are committed.
