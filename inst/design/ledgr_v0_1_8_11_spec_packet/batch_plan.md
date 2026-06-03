# ledgr v0.1.8.11 Batch Plan

**Status:** Active; Batch 8 completed after Claude review.

v0.1.8.11 is a documentation, structure, and cleanup cycle. It is deliberately
not a feature cycle. The core risk is scope bloat: documentation synthesis can
become as large as implementation if every useful article is treated as required
for release. This plan keeps audit and authority cleanup first, then batches
manual/user-facing work with an explicit split trigger.

## Split Trigger

If the release grows beyond a bounded cleanup cycle, keep the audit,
housekeeping, contract, and index work in v0.1.8.11 and defer manual/vignette /
narrative / disclaimer remainder to v0.1.8.12. The v0.1.9 feature arc should
start only after the codified architecture is discoverable enough for safe
feature planning.

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
Status: Planned

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

## Batch 10 - inst/ Subdirectory Audit And Cleanup

Ticket: `LDG-2538`
Status: Planned

Goal: inventory `inst/design/architecture/`,
`inst/design/maintainer_review/`, `inst/diagrams/`, `inst/examples/`,
`inst/schemas/`, and `inst/testdata/`, and route stale or unreferenced files to
deletion, gitignore, manual migration, or retention. Runs after or in parallel
with Batch 9.5 / `LDG-2539` by convenience; both must close before the release
gate.

Exit criteria:

- `inst_audit.md` exists in the packet and routes every audited file with a
  disposition.
- `architecture/fold_core_trust_boundary.md` and
  `architecture/ledgr_v0_1_8_sweep_architecture.md` remain in place. They are
  cited as binding authority in 15+ files; any relocation requires a separate
  ticket.
- `.Rbuildignore` reflects the audit outcome.
- Approved deletions, gitignores, and migrations are applied after audit
  review.
- Full test suite, `R CMD check`, and manual render pass after cleanup.
- Tarball size before/after cleanup is recorded in the completion note.

## Batch 11 - Release Gate

Ticket: `LDG-2537`
Status: Planned

Goal: close the documentation/cleanup cycle and prepare merge/tag.

Exit criteria:

- Completed tickets have artifacts and verification notes.
- Bounded remainder is routed to v0.1.8.12 or v0.1.9.x follow-on documentation
  if needed.
- The five deferred manual article families from LDG-2532 are explicitly
  routed: observability/determinism, sweep, snapshots/data, features, and
  benchmark methodology.
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
