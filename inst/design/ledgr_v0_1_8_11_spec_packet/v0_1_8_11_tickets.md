# ledgr v0.1.8.11 Tickets

Version: v0.1.8.11
Date: 2026-06-03
Total Tickets: 11

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
                          -> generated docs / man-page audit
                             -> release gate
```

Ticket IDs start at `LDG-2527` because `LDG-2517` through `LDG-2526` were used
by the v0.1.8.10 packet.

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

If the manual, vignette, performance-narrative, or disclaimer work threatens to
turn this into a broad documentation marathon, keep `LDG-2528` through
`LDG-2531` in v0.1.8.11 and defer bounded remainder to a v0.1.8.12 follow-on.
The release should reduce entropy, not create a new long-running docs backlog.

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
are cut, `LDG-2527` is complete, and all non-Batch-0 tickets remain planned.
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
Status: Planned

### Description

Finish cross-cycle planning-doc housekeeping so the active and completed packet
state is internally consistent after v0.1.8.10 and before v0.1.8.11 work.

### Tasks

- Confirm `inst/design/README.md` marks v0.1.8.11 as active.
- Confirm `inst/design/ledgr_roadmap.md` points to the packet path and narrows
  v0.1.9.x follow-on documentation.
- Confirm `inst/design/horizon.md` has no stale in-flight v0.1.8.10 language.
- Confirm `AGENTS.md` points agents at v0.1.8.11 and preserves the no-ticket /
  no-implementation boundary.
- Keep the resolved v0.1.8.10 horizon closeout visible.

### Acceptance Criteria

- Stale planning-language scans show no old "future packet",
  "v0.1.8.11 planning next", or "in-flight v0.1.8.10" active-state language
  outside historical context.
- No implementation files change.
- Packet docs, roadmap, horizon, README, and AGENTS.md agree on active state.

### Verification

`rg` stale-language checks and manual design-index review.

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
Status: Planned

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
Status: Planned

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
Status: Planned

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

### Source Reference

- `inst/design/manual/`
- `inst/design/maintainer_review/fold_core_workbook.qmd`
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
Status: Planned

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
Status: Planned

### Description

Create an internal teaching narrative for the v0.1.8.7-v0.1.8.10 performance
arc. The narrative lives under `inst/design/manual/`; raw evidence remains
under `dev/bench/`.

### Tasks

- Create `inst/design/manual/performance_arc_v0_1_8_x.md` or confirm a better
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
Status: Planned

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
Status: Planned

### Description

Audit generated docs and man pages for stale help-page language introduced or
left behind during the v0.1.8.x arc.

### Tasks

- Create `generated_docs_audit.md` in this packet.
- Review man pages and generated installed docs for stale execution, sweep,
  strategy, B2, benchmark, and contract language.
- Classify findings as fix-now, defer-with-reason, no-action, or later RFC.
- Route any fix-now docs changes through the appropriate documentation ticket.

### Acceptance Criteria

- `generated_docs_audit.md` exists and includes routed findings.
- The audit names affected files and proposed consuming tickets.
- No generated artifact churn lands without a source-doc reason.

### Verification

Manual audit review, stale-term `rg` checks, and source/generated-doc
traceability review.

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

## LDG-2537: v0.1.8.11 Release Gate

Priority: P0
Effort: M
Dependencies: LDG-2527, LDG-2528, LDG-2529, LDG-2530, LDG-2531, LDG-2532, LDG-2533, LDG-2534, LDG-2535, LDG-2536
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
