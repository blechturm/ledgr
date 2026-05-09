# auditr v0.1.7.5 Follow-Up Plan

Sources:

- `cycle_retrospective.md`
- `ledgr_triage_report.md`

These reports summarize a v0.1.7.5 auditr run with 33 episodes and 64
feedback rows. They are maintainer-review inputs, not direct tickets. This
document records how ledgr routes the findings before cutting v0.1.7.6 work.

## Posture

The reports are dominated by documentation and discoverability findings:

- 52 documentation gaps
- 9 UX friction rows
- 3 unclear-error rows

There is no new confirmed runtime defect in these reports. The high-severity
theme, `THEME-010`, is explicitly classified as auditr runner/environment
friction rather than ledgr package behavior.

v0.1.7.6 should therefore not become a broad documentation rewrite. The current
release remains focused on DuckDB persistence architecture. The auditr findings
are handled by routing them into the right existing or future milestone.

## Excluded From ledgr Handoff

### THEME-010 - Episode Environment And Windows Friction

Excluded from ledgr implementation scope.

The evidence concerns UTF-8 BOM script failure, PowerShell `rg` glob syntax, and
network availability for Yahoo-dependent tasks. These belong to the auditr
harness and task environment, not ledgr runtime behavior.

The only ledgr-facing residue is the documentation point about ledgr-controlled
Yahoo arguments, which belongs with snapshot adapter documentation when that
surface is next touched.

## Current v0.1.7.6 Scope

v0.1.7.6 may use these reports only for work that reinforces the DuckDB
persistence architecture review:

- low-level CSV snapshot create/import/seal/load workflows;
- sealed snapshot metadata inspection;
- fresh-connection result visibility;
- installed documentation paths for persistence workflows if they affect
  headless release-gate verification.

Do not fold the full documentation backlog into v0.1.7.6.

## Theme Routing

| Theme | Routing | Rationale |
| --- | --- | --- |
| THEME-003 - Summary, metrics, ledger, and result inspection clarity | Split between v0.1.7.7 and docs backlog | Risk-metric semantics belong in the v0.1.7.7 metric contract. Result-table and ledger teaching was substantially improved in v0.1.7.5; any residual examples should be verified before creating new work. |
| THEME-002 - Strategy and feature-map authoring docs | v0.1.7.8 / docs backlog | Strategy reproducibility and dependency boundaries belong in v0.1.7.8. Feature-map examples can be strengthened when those contracts are documented. |
| THEME-004 - Warmup, final-bar, zero-trade, and short-sample diagnostics | Mostly completed in v0.1.7.5; residuals route to v0.1.7.8 or docs backlog | v0.1.7.5 added warmup diagnostics and the three-way warmup-adjacent distinction. Remaining strategy-execution mental-model gaps should align with the reproducibility preflight docs. |
| THEME-005 - Snapshot import, sealing, and metadata contracts | v0.1.7.6 if persistence-adjacent; otherwise docs backlog | This is the closest match to the current release because it touches low-level CSV, sealing, metadata, and fresh-connection workflows. Only persistence-contract gaps should be pulled into v0.1.7.6. |
| THEME-006 - Experiment store, run IDs, and comparison workflow | v0.1.7.7 / v0.1.8 backlog | Metric readability and comparison surfaces should follow the v0.1.7.7 risk metric contract. Parameter-grid and candidate-promotion guidance belongs with v0.1.8 sweep mode. |
| THEME-007 - Helper pipeline examples and errors | v0.1.7.8 / docs backlog | Helper examples interact with strategy dependency and reproducibility tiering. Do not expand this before the preflight contract is fixed. |
| THEME-009 - Public documentation boundaries and installed paths | Verify against current docs before ticketing | v0.1.7.5 added installed vignette path parity checks. Any remaining stale source-tree paths should be verified from current source before promotion. |
| THEME-001 - Runnable first examples and onboarding paths | Docs backlog unless still reproducible | v0.1.7.5 improved first-path documentation. Reproduce before creating new onboarding work. |
| THEME-008 - Feature registration and parameter safety | v0.1.7.8 / v0.1.8 | Pre-registering parameterized features and finite params are sweep-adjacent constraints. They should be handled with reproducibility preflight and sweep-mode docs. |

## Current-Version Action Items

1. Keep the v0.1.7.6 implementation scope focused on DuckDB persistence.
2. Use this document as the curated routing artifact for the auditr reports.
3. Pull only `THEME-005` findings into v0.1.7.6 if they directly affect the
   persistence architecture review or the local WSL/Ubuntu parity gate.
4. Do not promote broad documentation themes until they are checked against the
   already-merged v0.1.7.5 documentation work.

## Definition Of Done For This Follow-Up

- `THEME-010` remains excluded from ledgr handoff unless reframed as auditr
  harness work.
- Every ledgr-facing theme has a routing decision.
- v0.1.7.6 does not absorb unrelated documentation cleanup.
- Future ticket authors can use this routing table when cutting v0.1.7.7,
  v0.1.7.8, and v0.1.8 tickets.
