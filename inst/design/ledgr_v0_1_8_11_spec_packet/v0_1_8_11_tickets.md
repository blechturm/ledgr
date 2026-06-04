# ledgr v0.1.8.11 Tickets

Version: v0.1.8.11
Date: 2026-06-03
Total Tickets: 20

## Ticket Organization

This packet implements the scoped v0.1.8.11 documentation, structure, and
cleanup plan from `v0_1_8_11_spec.md`. It cuts no execution, API, target-risk,
OMS, walk-forward, cost/liquidity, durable compiled, non-spot compiled
accounting, or public benchmark-claim work.

The release spine is:

```text
packet alignment
  -> contracts audit
     -> design housekeeping
        -> RFC / decision index and ADR routing
           -> contracts structure pass
              -> maintainer manual foundation
                 -> user-facing documentation refresh
                    -> performance-arc narrative
                       -> disclaimer surface
                          -> generated-doc audit
                             -> generated-doc cleanup
                                -> inst/ subdir audit
                                   -> manual remainder (observability, snapshots, sweep, features)
                                      -> ADR-0004 split and adr/ wind-down
                                         -> benchmark methodology residual
                                            -> existing-article depth retrofit and maintainer_review/ wind-down
                                               -> release gate
```

Ticket IDs start at `LDG-2527` because `LDG-2517` through `LDG-2526` were used
by the v0.1.8.10 packet. `LDG-2538` was inserted after the initial ticket cut
to scope the `inst/` subdirectory cleanup; it runs in parallel with `LDG-2536`
before the release gate. `LDG-2539` was inserted after Batch 9 review to
consume the generated-doc audit findings without reopening the audit ticket.
`LDG-2540` through `LDG-2545` were added on 2026-06-04 to absorb the LDG-2532
manual remainder and complete the `adr/` and `architecture/` directory
wind-downs in this release rather than cutting a separate doc-only follow-on;
the CI cost of that version cut did not justify it.

The new tickets are grouped into batches in `batch_plan.md` for joint review:

- Batch 11 (deterministic substrate): `LDG-2540` + `LDG-2541`.
- Batch 12 (research surface): `LDG-2542` + `LDG-2543`.
- Batch 13 (small wind-down): `LDG-2544` + `LDG-2545`.
- Batch 14 (depth retrofit and `maintainer_review/` wind-down): `LDG-2546`.

Joint batching restores the original `batch_plan.md` purpose: tickets that can
be tackled and reviewed together because they share themes, terminology, or
wind-down obligations.

A 2026-06-04 review of the first manual articles (`execution_fold_core`,
`performance_arc`) found them too synthesis-heavy: they restated contracts and
horizon entries without adding implementation depth beyond what the public
vignettes already cover. Every manual article now ships in two layers —
Synthesis (orientation, contracts, scope guards) and Implementation Trace
(data structures, file:line code anchors, lookup/dispatch mechanisms, edge
cases, hot/cold path distinction). The standard is pinned in Section 3.7 of
the spec. `LDG-2546` was added to retrofit the existing
`execution_fold_core` and `performance_arc` articles to the new standard and
to wind down `inst/design/maintainer_review/` (its workbooks are the depth
source for the retrofit).

## Dependency DAG

```text
LDG-2527 Packet Alignment And v0.1.8.11 Ticket Cut
  |-- LDG-2528 contracts.md Audit Report
  |     `-- LDG-2531 contracts.md Structure Pass
  |-- LDG-2529 Roadmap Horizon And Design Index Housekeeping
  |-- LDG-2530 RFC Decision Index And ADR Routing
  |-- LDG-2532 Maintainer Manual Foundation
  |-- LDG-2533 User-Facing Documentation Refresh
  |-- LDG-2534 Performance Arc Narrative
  |-- LDG-2535 Research Software Disclaimer Surface
  |-- LDG-2536 Generated Docs And Man-Page Audit
  |     `-- LDG-2539 Generated Docs Stale-Language Cleanup
  |-- LDG-2538 inst/ Subdirectory Audit And Cleanup
  |-- LDG-2540 Observability/Determinism Manual Article
  |-- LDG-2541 Snapshots/Data Manual Article
  |     `-- LDG-2542 Sweep Manual Article
  |-- LDG-2543 Features Manual Article
  |-- LDG-2544 ADR-0004 Rationale Split And Directory Wind-Down
  |     (depends on LDG-2540 + LDG-2541)
  |-- LDG-2545 Benchmark Methodology Residual Article
  |-- LDG-2546 Existing-Article Depth Retrofit And maintainer_review/ Wind-Down
  `-- LDG-2537 v0.1.8.11 Release Gate
```

## Priority Levels

- P0: packet alignment, contract audit, release gate, or work needed to avoid
  stale design authority.
- P1: primary documentation synthesis, manual, user-facing docs, and contract
  structure work.
- P2: bounded follow-on cleanup that may defer if the docs cycle gets too
  large.

## Split Trigger

The original split trigger reserved a follow-on release for the manual /
vignette / narrative / disclaimer remainder. On 2026-06-04 the maintainer
rescoped: the manual remainder is absorbed into v0.1.8.11 via `LDG-2540`
through `LDG-2545`, because a separate doc-only release would consume hours of
tag-CI for no execution surface change. The current discipline is: if any
single new ticket blows its budget, route that ticket's residual to v0.1.9.x
follow-on documentation, not a new v0.1.8.x version. The release should
reduce entropy, close the legacy directory wind-downs, and not create a new
long-running docs backlog.

---

## LDG-2527: Packet Alignment And v0.1.8.11 Ticket Cut

Priority: P0
Effort: S
Dependencies: none
Status: Completed

### Description

Finalize the v0.1.8.11 planning packet after Claude / maintainer review and
align the spec, ticket markdown, machine-readable metadata, batch plan, design
index, roadmap, horizon, and agent notes before implementation starts.

### Tasks

- Keep `v0_1_8_11_spec.md`, `v0_1_8_11_tickets.md`, `tickets.yml`, and
  `batch_plan.md` synchronized.
- Confirm the packet remains documentation, structure, and cleanup only.
- Confirm no tickets authorize execution semantics, public API, target risk,
  OMS, walk-forward, cost/liquidity, durable compiled integration, non-spot
  compiled accounting, or public benchmark claims.
- Confirm the split trigger is explicit.
- Submit the ticket cut for review and patch caveats before Batch 1 starts.

### Acceptance Criteria

- Spec, tickets, YAML, and batch plan agree on IDs, dependencies, priorities,
  statuses, and scope.
- Active design index and AGENTS.md point to v0.1.8.11.
- Horizon promotion index has v0.1.8.11 as the active documentation/cleanup
  home and no closed v0.1.8.10 active-planning line.
- Review feedback is patched or explicitly accepted.

### Verification

Manual packet review, stale-scope `rg` checks, YAML review, and peer-review
response.

### Completion Note

Completed on 2026-06-03 as the packet-alignment closeout. The spec, ticket
markdown, ticket YAML, batch plan, design index, roadmap, horizon, and
AGENTS.md agree on v0.1.8.11 as the active documentation, structure, and cleanup
packet. Claude review approved the packet seed; review caveats were patched
into the spec before tickets were cut. Tickets `LDG-2527` through `LDG-2537`
plus inserted ticket `LDG-2538` are cut, `LDG-2527` is complete, and all
non-Batch-0 tickets remain planned.
The packet keeps `DESCRIPTION` at `0.1.8.10`, preserves the no execution / API /
target-risk / OMS / walk-forward / cost-liquidity / compiled-promotion
boundary, and makes `LDG-2528` the next substantive batch.

Verification used stale-scope `rg` checks, YAML parse checks, `git diff
--check`, and a trailing-whitespace check over the packet files.

### Source Reference

- `v0_1_8_11_spec.md`
- `inst/design/horizon.md`
- `inst/design/ledgr_roadmap.md`

### Classification

```yaml
type: governance
surface: design_packet
scope: v0.1.8.11
```

---

## LDG-2528: contracts.md Audit Report

Priority: P0
Effort: M
Dependencies: LDG-2527
Status: Completed

### Description

Audit `inst/design/contracts.md` before editing it. The report identifies stale,
missing, duplicated, weak, or poorly organized contract language after
v0.1.8.10.

### Tasks

- Create `contracts_audit.md` in this packet.
- Check whether every current public execution, sweep, context, persistence,
  feature, accounting, documentation, and release-gate surface has a contract
  entry.
- Identify removed or retired concepts still described as current behavior.
- Check canonical event evidence versus derived output language.
- Check B2 scope language: `compiled_accounting_model = NULL | "spot_fifo"`,
  memory-backed sweep opt-in, durable compiled integration deferred, non-spot
  accounting unsupported.
- Check one-fold-core language for `ledgr_run()` and `ledgr_sweep()`.
- Classify each finding as fix-now, defer-with-reason, no-action, or later RFC.

### Acceptance Criteria

- `contracts_audit.md` exists and is reviewable before `contracts.md` edits.
- Findings are routed without silently changing contract semantics.
- The report names the exact sections or line anchors it reviewed.
- Any contract bug is routed to a ticket or later RFC rather than fixed
  incidentally.

### Verification

Manual audit review, stale-term `rg` checks, and source-to-finding traceability
review.

### Completion Note

Completed on 2026-06-03 after Claude review. The audit artifact exists at
`contracts_audit.md`, classifies findings without editing `contracts.md`, and
routes fix-now contract cleanup to `LDG-2531`. Review-approved patches added a
structural recommendation, an explicit NAMESPACE export cross-check, a
generated-docs cross-route for `ttr-indicators` policy language, and a direct
LDG-2531 route for historical CI wording.

### Source Reference

- `inst/design/contracts.md`
- `v0_1_8_11_spec.md`
- `contracts_audit.md`

### Classification

```yaml
type: audit
surface: contracts
scope: stale_contract_review
```

---

## LDG-2529: Roadmap Horizon And Design Index Housekeeping

Priority: P0
Effort: S
Dependencies: LDG-2527
Status: Completed

### Description

Finish cross-cycle planning-doc housekeeping so the active and completed packet
state is internally consistent after v0.1.8.10 and before v0.1.8.11 work.

### Tasks

- Confirm `inst/design/README.md` marks v0.1.8.11 as active.
- Confirm `inst/design/ledgr_roadmap.md` points to the packet path and narrows
  v0.1.9.x follow-on documentation.
- Confirm `inst/design/horizon.md` has no stale in-flight v0.1.8.10 language.
- Confirm `AGENTS.md` points agents at v0.1.8.11 and preserves the no
  execution/API/feature-implementation boundary.
- Keep the resolved v0.1.8.10 horizon closeout visible.

### Acceptance Criteria

- Stale planning-language scans show no old "future packet",
  "v0.1.8.11 planning next", or "in-flight v0.1.8.10" active-state language
  outside historical context.
- No implementation files change.
- Packet docs, roadmap, horizon, README, and AGENTS.md agree on active state.

### Verification

`rg` stale-language checks and manual design-index review.

Completion note: completed on 2026-06-03. The design index, AGENTS.md, roadmap,
horizon, packet spec, tickets, YAML, and batch plan agree that v0.1.8.11 is the
active packet and v0.1.8.10 is closed. The resolved v0.1.8.10 horizon closeout
remains visible, stale LDG-2528-next and pending-B2 active-state wording was
removed, and no implementation files changed. Verification used stale-language
`rg` checks, YAML parse review, and `git diff --check`.

### Source Reference

- `inst/design/README.md`
- `inst/design/ledgr_roadmap.md`
- `inst/design/horizon.md`
- `AGENTS.md`

### Classification

```yaml
type: governance
surface: design_index_and_horizon
scope: active_packet_housekeeping
```

---

## LDG-2530: RFC Decision Index And ADR Routing

Priority: P1
Effort: M
Dependencies: LDG-2527
Status: Completed

### Description

Create a reader-oriented map from topic to binding RFC / ADR / packet and route
stable architectural decisions that deserve ADR extraction.

### Tasks

- Decide the RFC index home before writing: evergreen `inst/design/rfc/README.md`
  or packet-local `rfc_decision_index.md`.
- Add a topic-oriented decision index for load-bearing accepted RFCs.
- Mark scaffolding / historical RFC documents clearly.
- Review ADR candidates:
  - B2 spot-FIFO scope guard;
  - canonical R as default execution;
  - matrix-canonical strategy accessor contract;
  - fold-owned FIFO accounting boundary.
- Route each candidate as ADR-now, keep-as-RFC, or defer-with-reason.

### Acceptance Criteria

- Decision index exists at the chosen path.
- ADR routing decision is recorded for each candidate.
- No accepted RFC text is rewritten as replacement authority.
- Links point to source RFCs, final reviews, ADRs, and packet records.

### Verification

Manual link review, topic-to-source traceability review, and ADR candidate
review.

Completion note: completed after Claude review on 2026-06-03. The chosen index
home is evergreen `inst/design/rfc/README.md`. It adds a topic-oriented
decision map, distinguishes historical/scaffolding RFC artifacts from binding
syntheses/final reviews, and records ADR routing for B2 spot-FIFO scope guard,
canonical R default execution, matrix-canonical strategy accessor contract, and
fold-owned FIFO accounting. Claude review patches re-attributed the parallel
dispatch row to the sweep architecture note, added the B2 maintainer-decisions
authority, clarified non-synthesis binding artifacts, added the snapshot
trust-boundary row, and promoted the B2 spot-FIFO scope guard to ADR-0005. No
source RFC text was rewritten as replacement authority. Verification used
manual link/topic traceability review, ADR candidate review, stale-status
scans, YAML parse review, referenced-path checks, and `git diff --check`.

### Source Reference

- `inst/design/rfc/`
- `inst/design/adr/`
- `v0_1_8_11_spec.md`

### Classification

```yaml
type: documentation_synthesis
surface: rfc_and_adr_index
scope: decision_discoverability
```

---

## LDG-2531: contracts.md Structure Pass

Priority: P1
Effort: M
Dependencies: LDG-2528
Status: Completed

### Description

Consume `contracts_audit.md` and edit `contracts.md` only where the audit
routes a fix-now contract cleanup or structure pass.

### Tasks

- Apply only findings classified as fix-now in `contracts_audit.md`.
- Organize contract language by surface where this preserves or clarifies
  semantics.
- Preserve or strengthen existing contracts; do not weaken them silently.
- Keep public execution, sweep, output-handler, event-evidence, accounting,
  strategy-context, feature, persistence, documentation, and release-gate
  surfaces distinguishable.
- Route semantic contract bugs to later tickets or RFCs.

### Acceptance Criteria

- Every `contracts.md` edit is traceable to `contracts_audit.md`.
- No execution semantics or public API changes land.
- The B2 scope guard and durable compiled deferral are clear if edited.
- `ledgr_run()` / `ledgr_sweep()` shared fold-core language remains clear.

### Verification

Diff-to-audit traceability review, stale-term `rg` checks, and manual contract
review.

Completion note: completed after Claude review on 2026-06-03. `contracts.md`
edits are limited to the five fix-now findings in `contracts_audit.md`:
C-001 active packet pointer, C-002 fold-entry guard tense, C-003 R6 / legacy
strategy wording, C-004 removed context helper tense, and C-005 historical CI
wording. No execution semantics or public APIs changed, and the B2 scope guard,
durable compiled deferral, one-fold-core rule, and non-scope feature
boundaries remain intact. Claude review patches restored the committed-run
recompute/compare and sweep-hash-provenance guard mechanisms, kept R6 in the
static-analysis caveat, and tightened the lead paragraph's README/spec-packet
authority wording. Verification used diff-to-audit traceability review,
stale-term `rg` checks, YAML parse review, and `git diff --check`.

### Source Reference

- `contracts_audit.md`
- `inst/design/contracts.md`

### Classification

```yaml
type: contract_cleanup
surface: contracts
scope: structure_and_stale_language
```

---

## LDG-2532: Maintainer Manual Foundation

Priority: P1
Effort: L
Dependencies: LDG-2527
Status: Completed

### Description

Grow the internal maintainer manual from the v0.1.8.8 skeleton into coherent
prose, reviewed in batches. Partial completion is acceptable if bounded
remainder is routed to v0.1.9.x follow-on documentation.

### Tasks

- Confirm existing `inst/design/manual/` skeleton and article homes.
- Prioritize articles in this order:
  execution / fold core;
  observability / determinism;
  sweep;
  snapshots/data;
  features;
  benchmark methodology.
- Author or revise the highest-priority articles that fit the v0.1.8.11 budget.
- Keep governance records authoritative; manual articles synthesize and link.
- Record any bounded remainder explicitly.

### Acceptance Criteria

- At least the first prioritized article batch is reviewable.
- Manual prose points to binding RFCs, ADRs, contracts, and packet records.
- Any incomplete article family has a bounded follow-on disposition.
- No execution or API changes land through manual work.

### Verification

Manual article review, link review, and remainder-disposition review.

Completion note: completed after Claude review on 2026-06-03. The manual
foundation now lives under `inst/design/manual/` with `README.qmd` and the first
priority article, `execution_fold_core.qmd`; both render to sibling
GitHub-flavored Markdown for repository browsing. The manual follows the local
vignette styleguide shape where applicable, points to binding contracts, RFCs,
ADRs, architecture notes, workbooks, and packet records, and records bounded
remainder for observability/determinism, sweep, snapshots/data, features, and
benchmark methodology. Claude review patches tightened exact target matching,
callout rendering, strategy-state vocabulary, GitHub Markdown output, and
release-gate routing of the five deferred families. No execution or API changes
landed.
Verification used manual source-link review, remainder-disposition review,
stale next-batch scans, YAML parse review, and `git diff --check`.

### Source Reference

- `inst/design/manual/`
- `inst/design/manual/execution_fold_core.qmd`
- `inst/design/maintainer_review/feature_value_path_workbook.qmd`

### Classification

```yaml
type: documentation
surface: maintainer_manual
scope: architecture_synthesis
```

---

## LDG-2533: User-Facing Documentation Refresh

Priority: P1
Effort: L
Dependencies: LDG-2527
Status: Completed

### Description

Refresh first-pass user-facing documentation for the post-v0.1.8.10 reality:
strategy accessors, memory-backed sweep economics, B2 opt-in boundaries, and
why R remains credible for ledgr's target workload.

### Tasks

- Refresh strategy development documentation for `ctx$vec`, `ctx$idx()`, and
  `ctx$vec$feature(feature_id)`.
- Refresh research workflow documentation for memory-backed sweep as a real
  mode at serious-research scale.
- Refresh who-ledgr-is-for / why-r surfaces for the v0.1.8.x performance arc
  without public speed-claim marketing.
- Refresh sweep / B2 opt-in wording if user-facing docs mention it.
- Keep Pass 2 helper extensions deferred.

### Acceptance Criteria

- Required first-pass surfaces are reviewed: strategy development, research
  workflow, who-ledgr-is-for, and why R.
- Documentation does not imply B2 default execution, durable compiled
  integration, non-spot accounting support, or general compiled fold-core
  support.
- Documentation does not introduce new public helper APIs.
- Installed-doc build semantics remain intact.

### Verification

Doc render or targeted vignette checks as appropriate, link review, and
scope-language review.

Completion note: completed after Claude review on 2026-06-03. Refreshed the required
first-pass surfaces: `README.md`, strategy development, research workflow,
sweeps, who-ledgr-is-for, and why R. The strategy article now demonstrates
`ctx$idx()`, `ctx$vec`, and `ctx$vec$feature(feature_id)`; workflow and sweeps
now describe memory-backed sweep as compact candidate evidence with durable
materialization at promotion; sweeps and README name B2 only as explicit
`compiled_accounting_model = "spot_fifo"` memory-backed spot-FIFO opt-in with
canonical R as the default; audience / why-R surfaces explain the performance
arc without public speed-claim marketing. Pass 2 helper extensions remain
deferred. Claude's blocker on rendered GFM callout drift was resolved with
`tools/render-vignettes-gfm.R`, which keeps pkgdown-safe source callouts and
normalizes rendered Markdown callouts to GitHub admonitions. Verification used
targeted Quarto GFM renders with explicit R library paths, stale-version and
scope-language scans, rendered-output inspection, and `git diff --check`.

### Source Reference

- `vignettes/`
- `inst/doc/`
- `README.md`
- `v0_1_8_11_spec.md`

### Classification

```yaml
type: documentation
surface: user_facing_docs
scope: post_b2_refresh
```

---

## LDG-2534: Performance Arc Narrative

Priority: P1
Effort: M
Dependencies: LDG-2527
Status: Completed

### Description

Create an internal teaching narrative for the v0.1.8.7-v0.1.8.10 performance
arc. The narrative lives under `inst/design/manual/`; raw evidence remains
under `dev/bench/`.

### Tasks

- Create `inst/design/manual/performance_arc_v0_1_8_x.qmd` or confirm a better
  manual path.
- Cover v0.1.8.7 Optimization Round 2, v0.1.8.8 diagnostics/parallel setup,
  v0.1.8.9 single-core optimization, and v0.1.8.10 substrate / B2 closeout.
- Link to benchmark evidence under `dev/bench/` and packet closeouts instead of
  copying every number.
- Explain local/current-source/machine-specific caveats.
- Explain what claims are intentionally not public marketing.

### Acceptance Criteria

- Narrative has a clear scope window: v0.1.8.7-v0.1.8.10.
- Evidence links are traceable to packet and benchmark artifacts.
- Public-speed-claim language is absent.
- Relationship to peers is apples-to-apples and caveated.

### Verification

Manual narrative review, benchmark-link review, and claim-language review.

Completion note: completed after Claude review on 2026-06-03. Added
`inst/design/manual/performance_arc_v0_1_8_x.qmd` and rendered
`performance_arc_v0_1_8_x.md`. The narrative covers the v0.1.8.7 to v0.1.8.10
window, links to `dev/bench/` and packet closeout artifacts, separates
canonical R, memory-backed, durable, peer, and B2 spot-FIFO opt-in surfaces,
and makes local/current-source/machine-specific caveats explicit. Public
speed-ranking language is intentionally absent. The manual README now includes
the article and narrows the remaining benchmark-methodology family to future
record-generation and release-gate details.

### Source Reference

- `dev/bench/`
- `inst/design/ledgr_v0_1_8_7_spec_packet/`
- `inst/design/ledgr_v0_1_8_8_spec_packet/`
- `inst/design/ledgr_v0_1_8_9_spec_packet/`
- `inst/design/ledgr_v0_1_8_10_spec_packet/`

### Classification

```yaml
type: documentation_synthesis
surface: performance_narrative
scope: v0.1.8.7_to_v0.1.8.10
```

---

## LDG-2535: Research Software Disclaimer Surface

Priority: P1
Effort: S
Dependencies: LDG-2527
Status: Completed

### Description

Add a plain-English financial research-software disclaimer surface and modest
links from user-facing entry points.

### Tasks

- Add `DISCLAIMER.md` at the repository root.
- State that ledgr is research software, not investment advice.
- State that backtests do not predict future performance.
- State that audit/replay features are research tools, not compliance or
  regulatory guarantees.
- Add modest links from README and relevant introductory docs if approved.

### Acceptance Criteria

- Disclaimer language is plain, concise, and not fake-lawyer prose.
- Links are discoverable but not alarmist.
- No DESCRIPTION metadata change lands unless review explicitly asks for it.

### Verification

Manual disclaimer review and link review.

Completion note: Batch 8 completed after Claude review on 2026-06-04. Added root
`DISCLAIMER.md` and modest links from `README.md`,
`vignettes/articles/who-ledgr-is-for.qmd`, and `vignettes/research-workflow.qmd`
plus rendered `research-workflow.md`. The surface covers research-software,
investment-advice, future-performance, and compliance/regulatory boundaries
without DESCRIPTION metadata changes. Claude's only required patch was
reverting incidental live-output drift in `vignettes/research-workflow.md`; the
recurring render-drift issue is routed to LDG-2536.

### Source Reference

- `inst/design/horizon.md` entry
  `2026-06-01 [documentation] User-facing research-software disclaimer for
  financial backtesting`

### Classification

```yaml
type: documentation
surface: disclaimer
scope: financial_research_software
```

---

## LDG-2536: Generated Docs And Man-Page Audit

Priority: P2
Effort: M
Dependencies: LDG-2527
Status: Completed

### Description

Audit generated docs and man pages for stale help-page language introduced or
left behind during the v0.1.8.x arc.

### Tasks

- Create `generated_docs_audit.md` in this packet.
- Review man pages and generated installed docs for stale execution, sweep,
  strategy, B2, benchmark, and contract language.
- Include Claude's Batch 8 finding that rendered vignette Markdown can pick up
  incidental live-output drift unrelated to the source-doc edit.
- Classify findings as fix-now, defer-with-reason, no-action, or later RFC.
- Route any fix-now docs changes through the appropriate documentation ticket.

### Acceptance Criteria

- `generated_docs_audit.md` exists and includes routed findings.
- The audit names affected files and proposed consuming tickets.
- No generated artifact churn lands without a source-doc reason.

### Verification

Manual audit review, stale-term `rg` checks, and source/generated-doc
traceability review.

Completion note: Batch 9 completed after Claude review on 2026-06-04. Added
`generated_docs_audit.md`, covering `man/`, absent `inst/doc/`, and
`vignettes/`. Findings route stale version-pinned vignette/Roxygen language,
the rendered-vignette live-output drift process issue, and source/generated
traceability expectations. No generated documentation artifacts were changed.
Claude approved the routing artifact and recommended a separate consuming
ticket; LDG-2539 now consumes GD-001 through GD-008.

### Source Reference

- `man/`
- `inst/doc/`
- `vignettes/`

### Classification

```yaml
type: audit
surface: generated_docs
scope: stale_help_language
```

---

## LDG-2539: Generated Docs Stale-Language Cleanup

Priority: P2
Effort: M
Dependencies: LDG-2536
Status: Completed

### Description

Consume the source-doc cleanup and render-drift process findings from
`generated_docs_audit.md` without reopening the audit ticket.

### Tasks

- Fix GD-001 through GD-003 in vignette `.qmd` sources and render the matching
  tracked `.md` siblings.
- Fix GD-004 through GD-007 in Roxygen source and regenerate the affected
  `man/*.Rd` files.
- Consume GD-008 with a documented render-drift discipline, or explicitly route
  it forward with rationale if the process fix should wait.
- Re-run stale-term `rg` checks from `generated_docs_audit.md`.
- Confirm generated artifact diffs match source intent and revert unrelated
  live-output drift.

### Acceptance Criteria

- GD-001 through GD-007 no longer appear in stale-term scans except where
  intentionally retained as runtime migration diagnostics.
- GD-008 is consumed or explicitly routed forward.
- `.Rd` changes trace to Roxygen source changes.
- Rendered `.md` changes trace to `.qmd` source changes.
- No execution semantics, API, target-risk, OMS, walk-forward, cost/liquidity,
  durable compiled, non-spot compiled, or public benchmark-claim work lands.

### Verification

Stale-term `rg` checks, source/generated traceability review, targeted doc
render/regeneration checks, and git diff review for unrelated live-output drift.

Completion note (2026-06-04): Closed after review. The consuming cleanup
handled GD-001 through GD-008 from `generated_docs_audit.md` through
source-owned documentation updates, source/generated traceability review, and
render-drift discipline checks. No execution semantics, public API,
target-risk, OMS, walk-forward, cost/liquidity, durable compiled,
non-spot compiled, or public benchmark-claim work landed.

### Source Reference

- `generated_docs_audit.md`
- `R/backtest.R`
- `R/experiment.R`
- `R/param-grid.R`
- `R/sweep.R`
- `vignettes/research-to-production.qmd`
- `vignettes/reproducibility.qmd`
- `vignettes/experiment-store.qmd`
- `tools/render-vignettes-gfm.R`

### Classification

```yaml
type: documentation_cleanup
surface: generated_docs_and_vignettes
scope: stale_language_and_render_drift
```

---

## LDG-2538: inst/ Subdirectory Audit And Cleanup

Priority: P2
Effort: M
Dependencies: LDG-2527
Status: Completed

### Description

Audit `inst/design/architecture/`, `inst/design/maintainer_review/`,
`inst/diagrams/`, `inst/examples/`, `inst/schemas/`, and `inst/testdata/` for
stale or unreferenced files. Route findings to deletion, gitignore, migration
into the maintainer manual, or retention as load-bearing source. Produce the
audit report first; apply deletions and migrations only after the audit is
reviewed.

Runs after or in parallel with `LDG-2539` by convenience; both must close before
the release gate.

### Tasks

- Create `inst_audit.md` in this packet.
- Inventory each in-scope directory and list every file with reference count,
  current purpose, and proposed disposition.
- Classify each file as: keep (load-bearing), gitignore (build artifact),
  delete (stale or fully superseded), or migrate-to-manual (useful prose that
  belongs in a manual article).
- Reference-check every "delete" candidate by grepping `R/`, `tests/`,
  `vignettes/`, `inst/design/`, `dev/`, and `.github/` before recommending
  removal.
- Review `.Rbuildignore` against the audit outcome: confirm development-only
  subdirectories are excluded from the package build and runtime-required
  content is included.
- After audit review, apply approved deletions, gitignores, and manual
  migrations.
- Re-run the full test suite, `R CMD check`, and the manual render to
  confirm no installed-doc, vignette, or runtime reference broke.

### Acceptance Criteria

- `inst_audit.md` exists and routes every audited file with a disposition.
- No file is deleted, moved, or migrated before the audit is reviewed.
- Load-bearing architecture notes are not renamed or relocated by this ticket.
  Any relocation requires a separate ticket with an explicit
  rg-sweep-and-patch acceptance criterion.
- Full test suite and `R CMD check` pass after cleanup.
- Tarball size and tracked scoped-file size before/after cleanup are recorded
  in the completion note.
- No execution semantics, API, target-risk, OMS, walk-forward, cost/liquidity,
  durable compiled, non-spot compiled, or public benchmark-claim work landed.

### Verification

Manual audit-report review, stale-reference `rg` checks, `.Rbuildignore`
review, full tests, package check after cleanup, and tarball-size delta
record.

Completion note: Batch 10 completed on 2026-06-04 after review. Added
`inst_audit.md`, covering all 19 tracked scoped files plus ignored local Quarto
render artifacts under `inst/design/maintainer_review/`. The audit preserves
the binding architecture paths, keeps the maintainer-review workbooks excluded
from package builds, and keeps `inst/testdata/yahoo_mock.csv` as a load-bearing
installed test fixture. The reviewed cleanup deleted `INST-011` through
`INST-018`: six stale unreferenced Mermaid diagrams, the empty schemas
placeholder, and the stale installed examples README. No files were moved,
migrated, or newly gitignored. Tracked scoped-file size before cleanup was
167,999 bytes. Package tarball size was 3,153,183 bytes before cleanup and
3,151,436 bytes after cleanup, a 1,747-byte reduction. Verification:
`git diff --check` passed; `tickets.yml` status graph passed;
`R CMD build --no-build-vignettes` succeeded before and after cleanup;
`R CMD check --no-manual --no-build-vignettes` completed with the existing
2 warnings / 2 notes state; manual render passed via RStudio's bundled Quarto;
full local tests failed only in `test-documentation-contracts.R` on stale
generated-doc/manual assertions already routed to LDG-2539.

### Source Reference

- `inst/design/architecture/`
- `inst/design/maintainer_review/`
- `inst/diagrams/`
- `inst/examples/`
- `inst/schemas/`
- `inst/testdata/`
- `.Rbuildignore`
- `v0_1_8_11_spec.md`

### Classification

```yaml
type: audit
surface: installed_subdirectories
scope: stale_file_cleanup_and_migration
```

---

## LDG-2540: Observability/Determinism Manual Article

Priority: P1
Effort: M
Dependencies: LDG-2532
Status: Completed

### Description

Author the `inst/design/manual/observability_determinism.qmd` article. Absorb
the ADR-0002 registry-fingerprint and ADR-0003 closure-fingerprinting rationale
into the article body. Delete those two ADR files and re-point active citation
sites at the new article.

### Tasks

- Author `observability_determinism.qmd` using the established manual shape:
  outcome first, one article job, Quarto-native callouts, source links, "Where
  Next" close.
- Cover error wrapping and telemetry, replay invariants, `ctx$pulse_seed`,
  parallel/resume determinism, collapse determinism gate, ambient-RNG
  classification, strategy preflight tiers.
- Migrate ADR-0002 (registry fingerprint policy) rationale into the article.
- Migrate ADR-0003 (closure fingerprinting) rationale into the article.
- Re-point active ADR-0002 and ADR-0003 citation sites to the new article.
  Update `adr/README.md` existing-records table to mark both files deleted.
- Delete the migrated ADR-0002 and ADR-0003 source files.
- Render the GFM sibling `observability_determinism.md` and confirm `git
  status` shows no unexpected drift outside the article's source changes.

### Acceptance Criteria

- Article is reviewable and points to binding contracts, RFCs, packet records.
- Article carries both layers per Section 3.7 of the spec: Synthesis layer
  (orientation, contracts restated, scope guards, maintainer checklist) AND
  Implementation Trace layer (data structures for telemetry/preflight registries
  and config_hash/closure_hash; file:line code anchors for the determinism
  surfaces; closure-hash and preflight tier classification mechanisms; ambient
  RNG detection mechanism; `ctx$pulse_seed` derivation; parallel-equivalence
  enforcement points; edge cases; hot/cold path distinction).
- No execution semantics, public API, or new contract authorship.
- ADR-0002 and ADR-0003 rationale is present in the article without weakening
  the existing contract bindings.
- Citation grep `rg "adr/0002|adr/0003"` returns only historical packet
  completion notes and the `adr/README.md` table entry.

### Verification

Manual article review, ADR-0002/0003 migration citation review, manual render
check, stale-reference `rg` check.

### Review State

- `inst/design/manual/`
- ADR-0002 and ADR-0003 migrated and deleted.
- `inst/design/manual/observability_determinism.qmd`
- `inst/design/adr/README.md`
- `inst/design/contracts.md`
- Claude review approved the Section 3.7 Synthesis + Implementation Trace
  correction on 2026-06-04. Anchor freshness was spot-checked across config
  hashing, closure fingerprinting, strategy preflight, ambient-RNG handling,
  `ctx$pulse_seed`, and parallel/resume enforcement.

### Classification

```yaml
type: documentation
surface: maintainer_manual
scope: observability_determinism_with_adr_migration
```

---

## LDG-2541: Snapshots/Data Manual Article

Priority: P1
Effort: M
Dependencies: LDG-2532
Status: Completed

### Description

Author the `inst/design/manual/snapshots_data.qmd` article. Absorb the
ADR-0001 split-store rationale and the migrated fold trust-boundary
architecture content into the article body. Delete both source files and
re-point active citation sites at the new article.

### Tasks

- Author `snapshots_data.qmd` covering snapshot sealing, hash verification,
  snapshot/run database split, low-level snapshot adapter boundaries, and the
  fold-entry sealed-snapshot trust boundary.
- Migrate ADR-0001 (split-db semantics) rationale into the article.
- Migrate the fold trust-boundary architecture content into the article.
- Re-point active ADR-0001 and fold trust-boundary citation sites to the new
  article. Update `adr/README.md` and `architecture/README.md`
  existing-records tables.
- Delete the migrated ADR-0001 and fold trust-boundary source files.
- Render the GFM sibling and confirm no unexpected drift.

### Acceptance Criteria

- Article is reviewable.
- Article carries both layers per Section 3.7: Synthesis (orientation,
  contracts, scope guards) AND Implementation Trace (snapshot DB schema, run
  DB schema, `snapshot_hash` computation algorithm and byte-format v2 details,
  `ledgr_snapshot_load(verify = TRUE)` code path, fold-entry guard mechanisms
  for committed runs vs sweeps with file:line anchors, snapshot adapter
  boundaries, edge cases, hot/cold path distinction).
- The fold trust-boundary migration preserves the binding language about
  production-run vs sweep guard mechanisms (recompute vs
  validate-handle-and-carry-hash); no weakening.
- No execution semantics or public API changes.
- Citation grep returns only historical packet completion notes and the
  README tables.

### Verification

Manual article review, ADR-0001 + fold trust-boundary migration citation
review, manual render check, stale-reference `rg` check.

### Review State

- `inst/design/manual/`
- ADR-0001 and the fold trust-boundary note migrated and deleted.
- `inst/design/manual/snapshots_data.qmd`
- `inst/design/adr/README.md`
- `inst/design/architecture/README.md`
- `inst/design/contracts.md`
- Claude review approved the Section 3.7 Synthesis + Implementation Trace
  correction on 2026-06-04. Anchor freshness was spot-checked across snapshot
  schema, snapshot hash byte layout, `verify = TRUE` load checks, committed-run
  recompute-and-compare guards, sweep hash carry, and same-snapshot promotion.

### Classification

```yaml
type: documentation
surface: maintainer_manual
scope: snapshots_data_with_adr_and_architecture_migration
```

---

## LDG-2542: Sweep Manual Article

Priority: P1
Effort: L
Dependencies: LDG-2532, LDG-2541
Status: In Review

### Description

Author the `inst/design/manual/sweep.qmd` article. Absorb the binding
architecture content in `inst/design/architecture/ledgr_v0_1_8_sweep_architecture.md`
(which serves as the synthesis-equivalent for the parallel-sweep dispatch
decision) and the UX rationale in
`inst/design/architecture/ledgr_sweep_mode_ux.md`. Optionally absorb
`inst/design/architecture/sweep_mode_code_review.md` as appendix or defer to a
v0.1.9.x cycle. Delete the migrated files and re-point all citation sites
(~50+ across packets, contracts, RFC index, manual, ledgr_ux_decisions, audits).

### Tasks

- Author `sweep.qmd` covering sweep architecture, candidate promotion,
  parallel candidate dispatch, memory output handler, B2 memory-backed opt-in
  boundaries.
- Migrate `architecture/ledgr_v0_1_8_sweep_architecture.md` content into the
  article. This is the largest migration in the cycle; preserve the
  parallel-sweep dispatch synthesis-equivalent language.
- Migrate `architecture/ledgr_sweep_mode_ux.md` content into the article.
- Decide disposition of `architecture/sweep_mode_code_review.md`: absorb as
  appendix, route to `rfc/` as a response-equivalent, or delete with a
  reference in the architecture README.
- Re-point all citation sites. Update `rfc/README.md` Parallel Sweep Dispatch
  row's Primary authority from
  `../architecture/ledgr_v0_1_8_sweep_architecture.md` to the new manual
  article. Update `architecture/README.md` existing-records table.
- Delete the migrated source files.
- Render the GFM sibling and confirm no unexpected drift.

### Acceptance Criteria

- Article is reviewable.
- Article carries both layers per Section 3.7: Synthesis (orientation,
  contracts, scope guards) AND Implementation Trace (candidate_id derivation,
  worker dispatch mechanism with file:line anchors, discard-all interrupt
  code path, memory output handler shape, B2 dispatch in candidate execution,
  `ledgr_promote()` code flow, parallel/sequential parity surfaces, edge
  cases, hot/cold path distinction).
- The Parallel Sweep Dispatch synthesis-equivalent language is preserved in
  the article (no weakening of the "candidate dispatch, not a second engine"
  invariant).
- B2 scope language is consistent with the horizon entry +
  maintainer-decisions doc + contracts.md trio.
- No execution semantics or public API changes.
- Citation grep returns only historical packet completion notes and the
  README tables for the migrated files.

### Verification

Manual article review, architecture migration citation review, RFC index
Primary authority update review, manual render check, stale-reference `rg`
check.

### Source Reference

- `inst/design/manual/`
- `inst/design/architecture/ledgr_v0_1_8_sweep_architecture.md`
- `inst/design/architecture/ledgr_sweep_mode_ux.md`
- `inst/design/architecture/sweep_mode_code_review.md`
- `inst/design/architecture/README.md`
- `inst/design/rfc/README.md`
- `inst/design/contracts.md`

### Classification

```yaml
type: documentation
surface: maintainer_manual
scope: sweep_with_architecture_migration
```

---

## LDG-2543: Features Manual Article

Priority: P1
Effort: M
Dependencies: LDG-2532
Status: Completed

### Description

Author the `inst/design/manual/features.qmd` article. Absorb the UX rationale
in `inst/design/architecture/ledgr_feature_map_ux.md` into the article body.
Delete the source file and re-point all citation sites.

### Tasks

- Author `features.qmd` covering feature value path, cache/projection,
  indicator contract, `series_fn`, TTR adapter semantics, feature-map/alias
  contracts.
- Migrate `architecture/ledgr_feature_map_ux.md` content into the article.
- Re-point every citation. Update `architecture/README.md` existing-records
  table.
- Delete `architecture/ledgr_feature_map_ux.md`.
- Render the GFM sibling and confirm no unexpected drift.

### Acceptance Criteria

- Article is reviewable.
- Article carries both layers per Section 3.7: Synthesis AND Implementation
  Trace (the depth source is
  `inst/design/maintainer_review/feature_value_path_workbook.qmd` —
  absorb its content). Implementation Trace must include: `ctx$feature()`
  resolution chain with file:line anchors, feature cache key shape
  (snapshot_hash + instrument_id + indicator_fingerprint + fingerprint_key),
  features-engine.R structure, TTR adapter mechanism, alias map resolution,
  edge cases, hot/cold path distinction.
- `feature_value_path_workbook.qmd` content is absorbed into the article
  Implementation Trace section.
- Feature-map UX rationale is present without introducing new public API.
- No execution semantics or contract changes.
- Citation grep returns only historical packet completion notes and the
  README table entry.

### Verification

Manual article review, feature_map_ux migration citation review, manual render
check, stale-reference `rg` check.

### Source Reference

- `inst/design/manual/`
- `inst/design/architecture/ledgr_feature_map_ux.md`
- `inst/design/architecture/README.md`
- `inst/design/contracts.md`

### Classification

```yaml
type: documentation
surface: maintainer_manual
scope: features_with_architecture_migration
```

---

## LDG-2544: ADR-0004 Rationale Split And Directory Wind-Down

Priority: P2
Effort: S
Dependencies: LDG-2532, LDG-2534, LDG-2540, LDG-2541
Status: Planned

### Description

Split ADR-0004 (lean dependency footprint and function-only strategy
interface) rationale across the two existing manual articles that already
carry the surrounding context: `execution_fold_core.qmd` for the function-only
strategy interface, and `performance_arc_v0_1_8_x.qmd` for the cli/R6/tibble/
collapse dependency posture. Delete `adr/0004-dependency-footprint-and-strategy-interface.md`
and complete the `adr/` directory wind-down.

### Tasks

- Add a "Function-Only Strategy Interface" section (or expand the existing
  Strategy Contract section) in `execution_fold_core.qmd` that captures
  ADR-0004's rationale for the function-only interface.
- Add a "Dependency Posture" section in `performance_arc_v0_1_8_x.qmd` that
  captures ADR-0004's rationale for dropping `cli` and `R6`, keeping `tibble`,
  and adopting `collapse` behind the determinism wrapper.
- Re-point every citation of `adr/0004-...` to the appropriate split target.
- Update `adr/README.md` existing-records table to mark ADR-0004 deleted.
- Delete `adr/0004-dependency-footprint-and-strategy-interface.md`.
- Verify `adr/` contains only `README.md` (or is empty if the maintainer
  chooses to delete the directory entirely).
- Render the GFM siblings for both target articles.

### Acceptance Criteria

- Both target articles carry ADR-0004 rationale without weakening any
  existing contract language.
- `adr/` directory contains only `README.md` or is deleted; `adr/README.md`
  reflects the wound-down state.
- Citation grep returns only historical packet completion notes and the
  README table entry.

### Verification

execution_fold_core function-only section review, performance_arc dependency
posture section review, ADR directory empty-or-readme-only check,
stale-reference `rg` check.

Completion note (2026-06-04): Claude review approved the retrofit and
recommended close. The reviewer spot-checked roughly 50 anchors across both
retrofitted articles and found the line anchors fresh; the review also confirmed
`maintainer_review/` contains only `README.md` and
`feature_value_path_workbook.qmd`, live citation hygiene is clean, no contracts
or execution semantics changed, and the three minor polish notes are non-gating.

### Source Reference

- `inst/design/manual/execution_fold_core.qmd`
- `inst/design/manual/performance_arc_v0_1_8_x.qmd`
- `inst/design/adr/0004-dependency-footprint-and-strategy-interface.md`
- `inst/design/adr/README.md`

### Classification

```yaml
type: documentation
surface: adr_winddown
scope: adr_0004_split_and_directory_completion
```

---

## LDG-2545: Benchmark Methodology Residual Article

Priority: P2
Effort: S
Dependencies: LDG-2534
Status: Planned

### Description

Author the small benchmark-methodology residual article covering the
future-record-generation workflow, repeatability expectations, and
release-gate benchmark checks that `performance_arc_v0_1_8_x.qmd` does not
already cover. This is the smallest of the deferred article families.

### Tasks

- Author `benchmark_methodology.qmd` (or fold into an extended performance_arc
  section if the maintainer prefers).
- Cover: how to generate new records, what reproducibility expectations the
  records must meet, how release-gate benchmark checks are organized, where
  raw records live vs tracked artifacts.
- Render the GFM sibling and confirm no unexpected drift.

### Acceptance Criteria

- Article is reviewable.
- Article carries both layers per Section 3.7. Implementation Trace covers:
  how new records are generated (record harness shape, dev/bench/results
  layout), per-lane attribution mechanism, phase decomposition (ingestion,
  engine, results) with file:line anchors, reproducibility expectations,
  release-gate benchmark check mechanism.
- Public-speed-claim language is absent.
- Article links to `dev/bench/README.md` and the performance_arc article.

### Verification

Manual article review, manual render check.

### Source Reference

- `inst/design/manual/`
- `inst/design/manual/performance_arc_v0_1_8_x.qmd`
- `dev/bench/README.md`

### Classification

```yaml
type: documentation
surface: maintainer_manual
scope: benchmark_methodology_residual
```

---

## LDG-2546: Existing-Article Depth Retrofit And maintainer_review/ Wind-Down

Priority: P1
Effort: M
Dependencies: LDG-2532, LDG-2534
Status: Completed

### Description

Retrofit the two existing manual articles (`execution_fold_core.qmd` and
`performance_arc_v0_1_8_x.qmd`) with an Implementation Trace section that
brings them to the two-layer standard introduced in Section 3.7 of the spec.
Absorb the depth content from the retired fold-core workbook into
`execution_fold_core.qmd` and the retired v0.1.8.7 optimization workbook into
`performance_arc_v0_1_8_x.qmd`. Wind down the `maintainer_review/` directory
following the same pattern as `adr/` and `architecture/`: author a
`maintainer_review/README.md` codifying the wind-down, delete absorbed
workbook source files, and update status lines on any retained file to point
at its migration target.

### Tasks

- Author Implementation Trace section in `execution_fold_core.qmd` absorbing
  the retired fold-core workbook depth content: per-pulse context env shape,
  strategy-state env shape, fold-entry sealed-snapshot guard code path
  (file:line), `compiled_accounting_model` dispatch (R/sweep.R,
  R/compiled-spot-fifo.R lines), event emission boundaries, telemetry
  checkpoint mechanism, hot/cold path distinction.
- Author Implementation Trace section in `performance_arc_v0_1_8_x.qmd`
  covering the lane-attribution mechanism, per-fill cost decomposition,
  phase-decomposition harness shape, dev/bench/results record layout, and the
  per-package optimization mechanisms that landed across v0.1.8.7-v0.1.8.10.
- Author `inst/design/maintainer_review/README.md` codifying the wind-down
  (parallel to `adr/README.md` and `architecture/README.md`): why the
  directory is wound down, what each workbook absorbed where, the three-or-no
  condition bar for any future workbook authoring (the answer is: don't -
  depth goes in `manual/`).
- Delete the retired fold-core workbook and, if fully absorbed, the retired
  v0.1.8.7 optimization workbook.
- Re-point every citation of the deleted workbook(s) to the relevant
  Implementation Trace section in the corresponding manual article.
- Confirm `maintainer_review/` contains only `README.md` and the temporarily
  retained `feature_value_path_workbook.qmd`.
- Render the GFM siblings for both retrofitted articles; confirm no
  unexpected drift.

### Acceptance Criteria

- Both retrofitted articles have an `## Implementation Trace` section meeting
  the Section 3.7 spec standard: data structures, file:line code anchors,
  lookup/dispatch mechanisms, edge cases, hot/cold path distinction.
- Code anchors cite specific source files with line numbers; the reviewer
  spot-checks a sample for freshness.
- No new contracts authored; no existing contract weakened.
- `maintainer_review/README.md` codifies the wind-down with per-file
  migration disposition.
- Retired fold-core workbook deleted; relevant citations re-pointed.
- Retired v0.1.8.7 optimization workbook deleted.
- `maintainer_review/` directory contains only `README.md` and
  `feature_value_path_workbook.qmd`.
- Manual GFM siblings render cleanly.

### Verification

execution_fold_core Implementation Trace review, performance_arc
Implementation Trace review, maintainer_review wind-down policy review,
retired fold-core workbook migration review, retired optimization workbook
migration review, maintainer_review directory retained-file check,
stale-reference `rg` check.

### Source Reference

- `inst/design/manual/execution_fold_core.qmd`
- `inst/design/manual/performance_arc_v0_1_8_x.qmd`
- `inst/design/maintainer_review/README.md`
- `inst/design/contracts.md`
- `v0_1_8_11_spec.md` Section 3.7

### Classification

```yaml
type: documentation
surface: maintainer_manual
scope: depth_retrofit_and_maintainer_review_winddown
```

---

## LDG-2537: v0.1.8.11 Release Gate

Priority: P0
Effort: M
Dependencies: LDG-2527, LDG-2528, LDG-2529, LDG-2530, LDG-2531, LDG-2532, LDG-2533, LDG-2534, LDG-2535, LDG-2536, LDG-2538, LDG-2539, LDG-2540, LDG-2541, LDG-2542, LDG-2543, LDG-2544, LDG-2545, LDG-2546
Status: Planned

### Description

Run the final documentation-cycle release gate, close or defer bounded
remainder, and prepare the v0.1.8.11 merge/tag.

### Tasks

- Confirm all completed tickets have artifacts and verification notes.
- Confirm deferred manual/doc remainder is bounded and routed.
- Confirm no non-scope implementation work landed.
- Update NEWS, design index, roadmap, horizon, AGENTS.md, and release notes as
  needed.
- Run relevant targeted checks, doc renders, full tests, package build/check,
  and release CI playbook steps appropriate to changed surfaces.

### Acceptance Criteria

- Packet is internally consistent and closed.
- Release closeout exists if ticket execution warrants it.
- No generated local artifacts are committed.
- `Rscript tools/render-maintainer-manual.R` completes, and committed manual
  Markdown siblings match the `.qmd` sources with no unexpected post-render
  diff.
- The five LDG-2532 deferred manual article families are authored in this
  release (LDG-2540 observability/determinism, LDG-2541 snapshots/data,
  LDG-2542 sweep, LDG-2543 features, LDG-2545 benchmark methodology). Any
  unfinished article residual is explicitly routed to v0.1.9.x follow-on with
  scope language; no v0.1.8.12 follow-on is cut.
- Every manual article carries a Synthesis layer AND an Implementation Trace
  layer per Section 3.7 of the spec. The release gate verifies each of the
  seven articles (`execution_fold_core`, `performance_arc_v0_1_8_x`,
  `observability_determinism`, `snapshots_data`, `sweep`, `features`,
  `benchmark_methodology`) has both layers present and that the
  Implementation Trace sections cite valid file:line anchors.
- The `inst/design/maintainer_review/` directory is wound down: workbook
  content absorbed into the corresponding manual article Implementation
  Trace sections (LDG-2546), source workbooks deleted, directory contains
  only `README.md` or is removed entirely.
- The `inst/design/adr/` directory is wound down: ADR-0005 deleted (LDG-2530
  reversal); ADR-0001 absorbed into snapshots/data article (LDG-2541); ADR-0002
  and ADR-0003 absorbed into observability/determinism article (LDG-2540);
  ADR-0004 rationale split into execution_fold_core and performance_arc
  (LDG-2544). The directory contains only `README.md` or is deleted.
- The `inst/design/architecture/` directory is wound down:
  the fold trust-boundary note absorbed into snapshots/data article
  (LDG-2541); `ledgr_v0_1_8_sweep_architecture.md` and `ledgr_sweep_mode_ux.md`
  absorbed into sweep article (LDG-2542); `ledgr_feature_map_ux.md` absorbed
  into features article (LDG-2543); `sweep_mode_code_review.md` disposition
  recorded in LDG-2542. The directory contains only `README.md` or is deleted.
- The LDG-2539 generated-doc cleanup findings are consumed, or the unfinished
  remainder is explicitly routed to v0.1.9.x with source/generated traceability
  preserved.
- The LDG-2538 `inst_audit.md` findings are consumed: approved deletions,
  gitignores, and migrations have landed, or the unfinished remainder is
  explicitly routed to v0.1.9.x with the binding-path constraint preserved.
- CI/release checks pass or accepted caveats are documented.

### Verification

Targeted checks, full tests/package checks as appropriate, doc render checks as
appropriate, release playbook, and git status review.

### Source Reference

- `inst/design/release_ci_playbook.md`
- `v0_1_8_11_spec.md`
- `v0_1_8_11_tickets.md`
- `tickets.yml`
- `batch_plan.md`

### Classification

```yaml
type: release_gate
surface: release_process
scope: v0.1.8.11
```
