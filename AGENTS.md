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

Current planning context (v0.1.8.8 parallel dispatch and fold-core
maintainability cycle; update this block when the release closes or scope
changes materially):

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
- The v0.1.8.8 packet is the active implementation-planning packet:
  `inst/design/ledgr_v0_1_8_8_spec_packet/v0_1_8_8_spec.md`,
  `inst/design/ledgr_v0_1_8_8_spec_packet/v0_1_8_8_tickets.md`,
  `inst/design/ledgr_v0_1_8_8_spec_packet/tickets.yml`, and
  `inst/design/ledgr_v0_1_8_8_spec_packet/batch_plan.md`.
- v0.1.8.8 scopes parallel sweep dispatch and determinism, fold-core
  maintainer documentation / containment, and a repo-local reproducible peer
  benchmark report under `dev/bench/`.
- Sequential `ledgr_sweep()` remains the reference implementation. Parallelism
  is candidate dispatch over the same fold core, not a second execution engine.
- v0.1.8.8 binds deterministic-only resume/parallel RNG semantics with
  `ctx$pulse_seed`, `mirai` as a suggested parallel backend with fail-loud
  missing-backend behavior, hybrid worker dependency handling, an internal
  typed execution-spec constructor, and a mechanical fold-core split paired
  with documentation if behavior-neutral.
- Keep target risk, walk-forward, cost/liquidity, OMS, split stores, live data
  logs, point-in-time regressors, scaffold generation, companion-repository
  implementation, external-provider work, broad collapse adoption, compiled
  fold core, and package-vignette benchmark claims deferred unless the active
  packet explicitly scopes a bounded subset.

## Active Design Entry Points

Read these before working in the listed areas. They are accepted design decisions
binding for their stated release scope unless marked otherwise. Completed spec
packets are records, not authorization for new work.

| Area | Read |
| --- | --- |
| Active v0.1.8.8 packet | `inst/design/ledgr_v0_1_8_8_spec_packet/v0_1_8_8_spec.md`, `inst/design/ledgr_v0_1_8_8_spec_packet/v0_1_8_8_tickets.md`, `inst/design/ledgr_v0_1_8_8_spec_packet/batch_plan.md` |
| v0.1.8.8 parallel dispatch | `inst/design/spikes/ledgr_parallelism_spike/summary_report.md`, `inst/design/spikes/ledgr_parallelism_spike/architecture_synthesis.md`, `inst/design/architecture/ledgr_v0_1_8_sweep_architecture.md`, `inst/design/rfc/rfc_parallelism_spike_architecture_consequences_response.md` |
| v0.1.8.8 fold-core documentation | `inst/design/maintainer_review/fold_core_workbook.qmd`, `inst/design/maintainer_review/feature_value_path_workbook.qmd`, `inst/design/horizon.md` |
| v0.1.8.8 peer benchmark report | `dev/bench/README.md`, `dev/bench/peer_three_way.R`, `dev/bench/peer_three_way_backtrader.py`, `inst/design/ledgr_v0_1_8_7_spec_packet/benchmark_attribution_closeout.md` |
| v0.1.8.7 release record | `inst/design/ledgr_v0_1_8_7_spec_packet/v0_1_8_7_spec.md` |
| Sweep performance / optimization | `inst/design/rfc/rfc_sweep_single_core_optimization_routes_v0_1_8_synthesis.md`, `inst/design/rfc/rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x_synthesis.md`, `inst/design/rfc/rfc_pulse_context_data_model_consolidation_v0_1_8_3_synthesis.md`, `inst/design/rfc/rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md` |
| Feature projection / materialization | `inst/design/rfc/rfc_feature_projection_shape_and_lookback_v0_1_8_x_synthesis.md`, `inst/design/rfc/rfc_grid_level_feature_artifacts_wide_runtime_views_v0_1_8_x_synthesis.md`, `inst/design/rfc/rfc_pulse_context_data_model_consolidation_v0_1_8_3_synthesis.md` |
| v0.1.8.7 optimization inputs | `inst/design/audits/fold_path_hotpath_audit.md`, `inst/design/architecture/fold_core_trust_boundary.md`, `inst/design/collapse_optimization_map.md`, `inst/design/spikes/ledgr_optimization_round_spike/README.md`, `inst/design/adr/0004-dependency-footprint-and-strategy-interface.md` |
| Multi-output indicator authoring | `inst/design/rfc/rfc_multi_output_indicator_ux_synthesis.md` |
| Indicator determinism / fingerprinting | `inst/design/rfc/rfc_indicator_codebase_simplification_v0_1_8_x_synthesis.md` |
| Metric context / risk metrics | `inst/design/rfc/rfc_risk_free_rate_metric_context_v0_1_8_1_synthesis.md` (accepted for v0.1.8.2) |
| Active parameterized feature aliases | `inst/design/rfc/rfc_active_parameterized_feature_aliases_v0_1_8_x_synthesis.md` (accepted for v0.1.8.4) |
| Research workflow / artifact topology | `inst/design/rfc/rfc_research_workflow_artifact_topology_v0_1_8_x_synthesis.md` (accepted for v0.1.8.5 planning) |
| v0.1.9 risk layer / tiered output | `inst/design/rfc/rfc_chainable_risk_oms_policy_boundary_synthesis.md` (accepted for v0.1.9 planning) |
| Primitive internals / collapse acceleration | `inst/design/rfc/rfc_collapse_primitive_internals_v0_1_9_synthesis.md` (accepted for v0.1.9 planning) |

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
