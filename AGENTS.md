# ledgr Agent Notes

This repository is an R package for deterministic, snapshot-backed,
event-sourced backtesting. Keep changes scoped to the active ticket and preserve
the execution contracts in `inst/design/contracts.md`.

## Core Rules

- Do not add a second execution engine. `ledgr_run()` is the committed-run
  execution entry point. `ledgr_sweep()` must share the same internal fold core and
  must not introduce a second execution path.
- Do not bypass snapshot creation, sealing, hash verification, or no-lookahead
  pulse execution.
- Interactive tools must remain read-only against persistent ledgr tables.
- Functional strategies must return full named numeric target vectors, or use an
  explicit wrapper such as `ledgr_signal_strategy()` that maps to those targets.
- Do not silently treat missing strategy targets as zero.
- Do not commit generated local artifacts: `*.tar.gz`, `*.Rcheck/`,
  `coverage.html`, `tests/testthat/Rplots.pdf`.
- Use UTF-8 or ASCII encoding only. Do not introduce other encodings in R
  source, test, or design files.

## Design Documents

Read before implementing any non-trivial change:

- Design index: `inst/design/README.md`
- Execution contracts (authoritative): `inst/design/contracts.md`
- Milestone roadmap: `inst/design/ledgr_roadmap.md`
- RFC cycle process reference: `inst/design/rfc_cycle.md`
- ADRs: `inst/design/adr/`

Current planning context (active v0.1.9.3 target-risk packet):

- The completed v0.1.8.2 packet is an archival release record.
- The completed v0.1.8.3 packet is an archival release record:
  `inst/design/ledgr_v0_1_8_3_spec_packet/v0_1_8_3_spec.md`,
  `inst/design/ledgr_v0_1_8_3_spec_packet/ledgr_triage_report.md`,
  `inst/design/ledgr_v0_1_8_3_spec_packet/categorized_feedback.yml`,
  `inst/design/ledgr_v0_1_8_3_spec_packet/cycle_retrospective.md`,
  `inst/design/ledgr_v0_1_8_3_spec_packet/v0_1_8_3_tickets.md`, and
  `inst/design/ledgr_v0_1_8_3_spec_packet/tickets.yml`.
- The completed v0.1.8.4 packet is an archival release record:
  `inst/design/ledgr_v0_1_8_4_spec_packet/v0_1_8_4_spec.md`,
  `inst/design/ledgr_v0_1_8_4_spec_packet/auditr_intake_synthesis.md`,
  `inst/design/ledgr_v0_1_8_4_spec_packet/v0_1_8_4_tickets.md`, and
  `inst/design/ledgr_v0_1_8_4_spec_packet/tickets.yml`.
- v0.1.8.4 combined active parameterized feature aliases with pulled-forward
  feature-grid and strategy-grid construction helpers plus routed v0.1.8.3
  auditr findings.
- The completed v0.1.8.5 packet is an archival release record:
  `inst/design/ledgr_v0_1_8_5_spec_packet/v0_1_8_5_spec.md`,
  `inst/design/ledgr_v0_1_8_5_spec_packet/v0_1_8_5_tickets.md`,
  `inst/design/ledgr_v0_1_8_5_spec_packet/tickets.yml`, and
  `inst/design/ledgr_v0_1_8_5_spec_packet/cycle_retrospective.md`.
- The completed v0.1.8.6 packet is an archival release record:
  `inst/design/ledgr_v0_1_8_6_spec_packet/v0_1_8_6_spec.md`,
  `inst/design/ledgr_v0_1_8_6_spec_packet/v0_1_8_6_tickets.md`,
  `inst/design/ledgr_v0_1_8_6_spec_packet/tickets.yml`, and
  `inst/design/ledgr_v0_1_8_6_spec_packet/cycle_retrospective.md`.
- The completed v0.1.8.7 packet is an archival release record:
  `inst/design/ledgr_v0_1_8_7_spec_packet/v0_1_8_7_spec.md`,
  `inst/design/ledgr_v0_1_8_7_spec_packet/v0_1_8_7_tickets.md`,
  `inst/design/ledgr_v0_1_8_7_spec_packet/tickets.yml`,
  `inst/design/ledgr_v0_1_8_7_spec_packet/benchmark_attribution_closeout.md`,
  and `inst/design/ledgr_v0_1_8_7_spec_packet/cycle_retrospective.md`.
- v0.1.8.7 shipped Optimization Round 2: modern execution is snapshot-backed
  and function-strategy based; raw `bars` execution, R6 strategy execution, and
  run-time `data_hash` identity were removed from modern execution or now fail
  clearly before fold entry.
- v0.1.8.7 also shipped the event-buffer/emission lane, representation/setup
  cleanup, fills reconstruction/read-back cleanup, deterministic `collapse`
  wrapper, ADR 0004 dependency moves (`cli`/`R6` dropped, `collapse` added,
  `tibble` retained), and the sweep fast path / promotion materialization
  boundary.
- The completed v0.1.8.8 packet is an archival release record:
  `inst/design/ledgr_v0_1_8_8_spec_packet/v0_1_8_8_spec.md`,
  `inst/design/ledgr_v0_1_8_8_spec_packet/v0_1_8_8_tickets.md`,
  `inst/design/ledgr_v0_1_8_8_spec_packet/tickets.yml`, and
  `inst/design/ledgr_v0_1_8_8_spec_packet/release_closeout.md`.
- v0.1.8.8 shipped parallel sweep dispatch and determinism, fold-core
  diagnostics / containment, repo-local peer benchmark reporting under
  `dev/bench/`, and a self-profiling workload grid extension for v0.1.8.9
  optimization scoping. The maintainer-manual skeleton and stale-doc cleanup
  ticket was explicitly deferred.
- Sequential `ledgr_sweep()` remains the reference implementation. Parallelism
  is candidate dispatch over the same fold core, not a second execution engine.
- v0.1.8.8 binds deterministic-only resume/parallel RNG semantics with
  `ctx$pulse_seed`, `mirai` as a suggested parallel backend with fail-loud
  missing-backend behavior, hybrid worker dependency handling, an internal
  typed execution-spec constructor, and a mechanical fold-core split paired
  with documentation if behavior-neutral.
- The completed v0.1.8.9 packet is an archival release record:
  `inst/design/ledgr_v0_1_8_9_spec_packet/v0_1_8_9_spec.md`,
  `inst/design/ledgr_v0_1_8_9_spec_packet/v0_1_8_9_tickets.md`,
  `inst/design/ledgr_v0_1_8_9_spec_packet/tickets.yml`,
  `inst/design/ledgr_v0_1_8_9_spec_packet/per_lane_attribution.md`,
  `inst/design/ledgr_v0_1_8_9_spec_packet/v0_1_8_9_release_closeout.md`,
  and `inst/design/ledgr_v0_1_8_9_spec_packet/batch_plan.md`.
- v0.1.8.9 shipped the single-core optimization round: scale-growing buffer
  write fixes, per-pulse vectorization, yyjsonr canonical JSON byte-format v2
  migration, per-lane attribution, and workload-grid / peer-benchmark closeout.
- The completed v0.1.8.10 packet is an archival release record:
  `inst/design/ledgr_v0_1_8_10_spec_packet/v0_1_8_10_spec.md`,
  `inst/design/ledgr_v0_1_8_10_spec_packet/v0_1_8_10_tickets.md`,
  `inst/design/ledgr_v0_1_8_10_spec_packet/tickets.yml`,
  `inst/design/ledgr_v0_1_8_10_spec_packet/per_lane_attribution.md`,
  `inst/design/ledgr_v0_1_8_10_spec_packet/batch_plan.md`, and
  `inst/design/ledgr_v0_1_8_10_spec_packet/v0_1_8_10_release_closeout.md`.
- v0.1.8.10 closed the v0.1.8.x single-core arc with ephemeral subphase
  telemetry, matrix-canonical fold substrate and accepted strategy accessors,
  event-preserving fold-owned FIFO accounting, yyjsonr options hoisting, a
  compiled hot-frame B2 measurement gate, parked-spike disposition, and
  measurement closeout. It also shipped the scoped public memory-backed sweep
  B2 spot-FIFO opt-in. Events remain canonical evidence.
- Default compiled execution, durable compiled integration, non-spot compiled
  accounting, target risk, walk-forward, cost/liquidity, OMS, split stores,
  live data logs, point-in-time regressors, scaffold generation,
  external-provider work, broad collapse adoption, and package-vignette
  benchmark claims remain deferred unless the next packet explicitly scopes a
  bounded subset.
- The completed v0.1.8.11 packet is an archival release record:
  `inst/design/ledgr_v0_1_8_11_spec_packet/v0_1_8_11_spec.md`.
  It was a documentation, structure, and cleanup release before v0.1.9
  features. Scope was RFC / decision synthesis, ADR population,
  `contracts.md` audit and structural pass, maintainer manual, post-B2
  vignette refresh, user-facing research-software disclaimer, performance-arc
  narrative, and horizon/roadmap/design-index housekeeping. Tickets are cut;
  Batch 0 packet alignment, Batch 1 `contracts.md` audit, Batch 2 planning-doc
  housekeeping, and Batch 3 RFC decision-index work are complete after Claude
  review. Batch 4 `contracts.md` structure work is complete after Claude
  review. Batch 5 maintainer-manual foundation work is complete after Claude
  review. Batch 6 user-facing documentation refresh work is complete after
  Claude review. Batch 7 performance arc narrative work is complete after
  Claude review. Batch 8 research software disclaimer surface work is complete
  after Claude review. Batch 9 generated docs and man-page audit work is
  complete after Claude review. LDG-2539 was added to consume the generated-doc
  audit findings and is complete after review. Batch 10 `inst/` subdirectory
  audit and reviewed cleanup work is complete. Rescoped 2026-06-04:
  LDG-2540 through LDG-2546 added to absorb the manual remainder and complete
  the `adr/` + `architecture/` +
  `maintainer_review/` wind-downs in v0.1.8.11 (no v0.1.8.12 follow-on).
  ADR-0005 deleted; ADR-0001 through ADR-0003 and the fold trust-boundary
  note migrated into manual articles. Spec Section 3.7 introduces the
  two-layer manual article standard (Synthesis + Implementation Trace) after
  a 2026-06-04 review found the first articles too synthesis-heavy; LDG-2546
  retrofits `execution_fold_core` and `performance_arc` with Implementation
  Trace sections and winds down `maintainer_review/`. Batch 11 / LDG-2540 +
  LDG-2541 is complete after Claude review: both new deterministic substrate
  manual articles now carry Synthesis and Implementation Trace layers. Batch
  12 / LDG-2542 + LDG-2543 is complete after Claude review: sweep and features
  manual articles now carry both layers, the architecture notes were migrated,
  and `architecture/` is wound down to its README. Batch 14 / LDG-2546 is
  complete after Claude review: existing manual articles now carry
  Implementation Trace layers and `maintainer_review/` is wound down. Batch
  13 / LDG-2544 + LDG-2545 is complete after Claude review: ADR-0004 rationale
  is split into the manual, `adr/` is wound down to its README, and the
  benchmark methodology article is in place. Batch 15 / LDG-2537 closed the
  packet on 2026-06-04 and prepared the branch for merge/tag.
  Preserve the packet's no execution/API, target-risk, OMS, walk-forward,
  cost/liquidity, durable compiled, non-spot compiled, and public
  benchmark-claim implementation boundary.
- The completed v0.1.9.1 packet is an archival release record:
  `inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md`,
  `inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_tickets.md`,
  `inst/design/ledgr_v0_1_9_1_spec_packet/tickets.yml`,
  `inst/design/ledgr_v0_1_9_1_spec_packet/batch_plan.md`, and
  `inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_release_closeout.md`.
  It shipped the first public transaction-cost API, explicit
  `timing_model`, required `cost_model`, cost model inspection helpers,
  legacy-shape rejection, cost identity (`cost_model_hash` and
  `cost_plan_json`), and bounded auditr identity / disclaimer fixes.
- The completed v0.1.9.2 packet is an archival release record:
  `inst/design/ledgr_v0_1_9_2_spec_packet/v0_1_9_2_spec.md`,
  `inst/design/ledgr_v0_1_9_2_spec_packet/v0_1_9_2_tickets.md`,
  `inst/design/ledgr_v0_1_9_2_spec_packet/tickets.yml`,
  `inst/design/ledgr_v0_1_9_2_spec_packet/batch_plan.md`, and
  `inst/design/ledgr_v0_1_9_2_spec_packet/v0_1_9_2_release_closeout.md`.
  It shipped durable saved-sweep artifacts, optional retained net
  equity/return series for completed candidates, reopened-sweep compatibility,
  `candidate_id` / `candidate_row` sweep identity, and compact retention
  infrastructure for later walk-forward. Ranking helpers, named selection
  views, benchmark diagnostics, signal decay, implementation/cost decay,
  gross-vs-net attribution, and walk-forward integration remain non-scope.
- The active v0.1.9.3 packet is the target-risk packet:
  `inst/design/ledgr_v0_1_9_3_spec_packet/v0_1_9_3_spec.md`,
  `inst/design/ledgr_v0_1_9_3_spec_packet/v0_1_9_3_tickets.md`,
  `inst/design/ledgr_v0_1_9_3_spec_packet/tickets.yml`,
  `inst/design/ledgr_v0_1_9_3_spec_packet/batch_plan.md`, and
  `inst/design/ledgr_v0_1_9_3_spec_packet/README.md`.
  It implements classed target-risk steps, risk-chain identity, a
  behavior-preserving phased-pulse substrate, bounded risk application, and
  integration with sweep/promotion/reopen identity. Batch 0 packet alignment,
  Batch 1 public risk constructors and identity, Batch 2 config/run identity,
  Batch 3 phased-pulse substrate, Batch 4 fold risk application, Batch 5
  built-in risk steps, Batch 6 sweep row identity, Batch 7 saved-sweep and
  promotion identity, and Batch 8 parallel / compiled sweep safety are complete
  after Claude review. Batch 9 documentation and release surfaces are review
  pending. Arbitrary risk callbacks, affordability enforcement,
  liquidity/capacity policy, OMS behavior, walk-forward implementation,
  failure-schema columns, target-helper expansion, and compiled-core
  architecture work remain non-scope.

## Active Design Entry Points

Read these before working in the listed areas. They are accepted design decisions
binding for their stated release scope unless marked otherwise. Completed spec
packets are records, not authorization for new work.

| Area | Read |
| --- | --- |
| active v0.1.9.3 target-risk packet | `inst/design/ledgr_v0_1_9_3_spec_packet/v0_1_9_3_spec.md`, `inst/design/ledgr_v0_1_9_3_spec_packet/v0_1_9_3_tickets.md`, `inst/design/ledgr_v0_1_9_3_spec_packet/tickets.yml`, `inst/design/ledgr_v0_1_9_3_spec_packet/batch_plan.md`, `inst/design/rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md`, `inst/design/contracts.md`, `inst/design/ledgr_roadmap.md`, `inst/design/horizon.md` |
| v0.1.9.2 release record | `inst/design/ledgr_v0_1_9_2_spec_packet/v0_1_9_2_spec.md`, `inst/design/ledgr_v0_1_9_2_spec_packet/v0_1_9_2_tickets.md`, `inst/design/ledgr_v0_1_9_2_spec_packet/tickets.yml`, `inst/design/ledgr_v0_1_9_2_spec_packet/batch_plan.md`, `inst/design/ledgr_v0_1_9_2_spec_packet/v0_1_9_2_release_closeout.md`, `inst/design/rfc/rfc_sweep_artifact_persistence_v0_1_9_x_synthesis.md` |
| v0.1.9.1 release record | `inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_spec.md`, `inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_tickets.md`, `inst/design/ledgr_v0_1_9_1_spec_packet/tickets.yml`, `inst/design/ledgr_v0_1_9_1_spec_packet/batch_plan.md`, `inst/design/ledgr_v0_1_9_1_spec_packet/v0_1_9_1_release_closeout.md`, `inst/design/rfc/rfc_public_transaction_cost_model_api_v0_1_9_x_synthesis.md`, `inst/design/manual/identity_contract.qmd` |
| v0.1.8.11 release record | `inst/design/ledgr_v0_1_8_11_spec_packet/v0_1_8_11_spec.md`, `inst/design/ledgr_v0_1_8_11_spec_packet/v0_1_8_11_tickets.md`, `inst/design/ledgr_v0_1_8_11_spec_packet/tickets.yml`, `inst/design/ledgr_v0_1_8_11_spec_packet/batch_plan.md`, `inst/design/ledgr_v0_1_8_11_spec_packet/v0_1_8_11_release_closeout.md`, `inst/design/ledgr_roadmap.md`, `inst/design/horizon.md`, `inst/design/contracts.md` |
| v0.1.8.10 release record | `inst/design/ledgr_v0_1_8_10_spec_packet/v0_1_8_10_spec.md`, `inst/design/ledgr_v0_1_8_10_spec_packet/v0_1_8_10_tickets.md`, `inst/design/ledgr_v0_1_8_10_spec_packet/tickets.yml`, `inst/design/ledgr_v0_1_8_10_spec_packet/batch_plan.md`, `inst/design/ledgr_v0_1_8_10_spec_packet/per_lane_attribution.md`, `inst/design/ledgr_v0_1_8_10_spec_packet/v0_1_8_10_release_closeout.md` |
| v0.1.8.9 release record | `inst/design/ledgr_v0_1_8_9_spec_packet/v0_1_8_9_spec.md`, `inst/design/ledgr_v0_1_8_9_spec_packet/v0_1_8_9_tickets.md`, `inst/design/ledgr_v0_1_8_9_spec_packet/batch_plan.md`, `inst/design/ledgr_v0_1_8_9_spec_packet/v0_1_8_9_release_closeout.md` |
| v0.1.8.9 optimization inputs | `inst/design/spikes/ledgr_v0_1_8_9_optimization_round_spike/architecture_synthesis.md`, `dev/bench/notes/single_core_optimization_inventory.md`, `dev/bench/notes/per_pulse_complexity_findings.md`, `dev/bench/peer_benchmark/peer_benchmark.md` |
| v0.1.8.8 parallel dispatch | `inst/design/spikes/ledgr_parallelism_spike/summary_report.md`, `inst/design/spikes/ledgr_parallelism_spike/architecture_synthesis.md`, `inst/design/manual/sweep.qmd`, `inst/design/rfc/rfc_parallelism_spike_architecture_consequences_response.md` |
| Fold-core and feature-path documentation | `inst/design/manual/execution_fold_core.qmd`, `inst/design/manual/performance_arc_v0_1_8_x.qmd`, `inst/design/manual/features.qmd`, `inst/design/horizon.md` |
| v0.1.8.8 peer benchmark report | `dev/bench/README.md`, `dev/bench/peer_three_way.R`, `dev/bench/peer_three_way_backtrader.py`, `inst/design/ledgr_v0_1_8_7_spec_packet/benchmark_attribution_closeout.md` |
| v0.1.8.7 release record | `inst/design/ledgr_v0_1_8_7_spec_packet/v0_1_8_7_spec.md` |
| Sweep performance / optimization | `inst/design/rfc/rfc_sweep_single_core_optimization_routes_v0_1_8_synthesis.md`, `inst/design/rfc/rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x_synthesis.md`, `inst/design/rfc/rfc_pulse_context_data_model_consolidation_v0_1_8_3_synthesis.md`, `inst/design/rfc/rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md` |
| Feature projection / materialization | `inst/design/rfc/rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md`, `inst/design/rfc/rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x_synthesis.md`, `inst/design/rfc/rfc_pulse_context_data_model_consolidation_v0_1_8_3_synthesis.md` |
| v0.1.8.7 optimization inputs | `inst/design/audits/fold_path_hotpath_audit.md`, `inst/design/manual/snapshots_data.qmd`, `inst/design/collapse_optimization_map.md`, `inst/design/spikes/ledgr_optimization_round_spike/README.md`, `inst/design/manual/execution_fold_core.qmd`, `inst/design/manual/performance_arc_v0_1_8_x.qmd` |
| Multi-output indicator authoring | `inst/design/rfc/rfc_multi_output_indicator_ux_synthesis.md` |
| Indicator determinism / fingerprinting | `inst/design/rfc/rfc_indicator_codebase_simplification_v0_1_8_x_synthesis.md` |
| Metric context / risk metrics | `inst/design/rfc/rfc_risk_free_rate_metric_context_v0_1_8_1_synthesis.md` (accepted for v0.1.8.2) |
| Active parameterized feature aliases | `inst/design/rfc/rfc_active_parameterized_feature_aliases_v0_1_8_x_synthesis.md` (accepted for v0.1.8.4) |
| Research workflow / artifact topology | `inst/design/rfc/rfc_research_workflow_artifact_topology_v0_1_8_x_synthesis.md` (accepted for v0.1.8.5 planning) |
| v0.1.9 risk layer / tiered output | `inst/design/rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md` (accepted for v0.1.9 planning) |
| Primitive internals / collapse acceleration | `inst/design/rfc/rfc_collapse_primitive_internals_v0_1_9_synthesis.md` (accepted for v0.1.9 planning) |
| v0.1.9 performance scoping | `inst/design/ledgr_v0_1_8_9_spec_packet/v0_1_8_9_release_closeout.md`, `dev/bench/notes/single_core_optimization_inventory.md`, `dev/bench/notes/per_pulse_complexity_findings.md`, `inst/design/horizon.md` |

## Local Verification

Windows R path used in this workspace:

```powershell
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" -e "pkgload::load_all('.', quiet=TRUE); testthat::test_local('.', reporter='summary')"
& "C:\Program Files\R\R-4.5.2\bin\x64\R.exe" CMD build .
& "C:\Program Files\R\R-4.5.2\bin\x64\R.exe" CMD check --no-manual --no-build-vignettes ledgr_<version>.tar.gz
& "C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe" tools/check-coverage.R
```

Targeted checks are preferred while editing, followed by full tests and package
check before committing release-ticket work.

## Ticket Workflow

1. Read the ticket, its dependencies, and the relevant contract section.
2. Add or update tests for the acceptance criteria.
3. Implement the smallest change that satisfies the ticket.
4. Run targeted tests, then full tests/package checks when the change affects
   public API, runner behavior, snapshots, CI, or release gates.
5. Update the active `tickets.md` checkboxes and `tickets.yml` status together.
