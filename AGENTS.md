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
- Spikes, prototypes, and comparative experiments follow
  `inst/design/spike_protocol.md`: probe the package by execution before
  writing design prose, build the smallest runnable core before any expected
  table, keep provenance in the product rather than the harness, and deliver
  a runner, a diff-based checker, and a gut demonstration. Size budgets in
  that document are stop signals, not targets.
- Code on ingest, seal, fold, hydration, finalisation, or result-reader paths
  follows the optimization coding style in
  `inst/design/manual/optimization_coding_style.qmd` (reviewable draft):
  no R-level iteration over collections that grow with bars, fact rows,
  instruments x pulses, events, diagnostics, or candidates; prepare and index
  once, read primitives by index, manifest data frames only at boundaries,
  write by index into typed buffers, and replace pairwise validators with
  grouped sweeps. Its seven named shapes are review criteria for any change on
  those paths; a new loop over such a collection needs a stated reason.
- This file stays operational and under 150 lines: rules, current state,
  entry points for open work, verification, and ticket workflow. Release
  history and packet narratives belong in `inst/design/ledgr_roadmap.md` and
  `inst/design/README.md`; when a packet closes, replace its bullet here with
  a pointer rather than appending its story.

## Design Documents

Read before implementing any non-trivial change:

- Design index: `inst/design/README.md`
- Execution contracts (authoritative): `inst/design/contracts.md`
- Milestone roadmap: `inst/design/ledgr_roadmap.md`
- RFC cycle process reference: `inst/design/rfc_cycle.md`
- Spike protocol (binding for spikes and prototypes): `inst/design/spike_protocol.md`
- Optimization coding style (maintainer manual; review criteria for hot-path,
  ingest, seal, and reader code): `inst/design/manual/optimization_coding_style.qmd`
- ADRs: `inst/design/adr/`

## Current State

Current planning context (2026-09-20):

- v0.2.0.1 is published. Its packet, closeout and measurements are historical
  evidence; do not reopen that release or rewrite its measured results.
- Next scheduled release and planning branch: v0.2.0.2, equity accounting and
  research-workflow improvements. Read the roadmap's v0.2.0.2 section and
  `inst/design/research/Sharadar-Workflow-Improvement-Evidence.md` plus its
  corporate-event companion. No v0.2.0.2 implementation packet is open yet.
- The existing governance/test review precedes the next implementation packet;
  production accounting consolidation precedes new settlement semantics.
  Exact-behavior reader work and validation fixes do not require new RFC cycles.
- Reuse public capabilities and production semantics. Design only the missing
  behavior; do not add research-specific manifests or a parallel provenance
  system. Prefer small detecting examples and concrete workflow improvements.
- Spot-crypto, compiled-default promotion and tax work remain separate from the
  scheduled equity/workflow scope. Older release narratives are linked from
  `inst/design/README.md` and `inst/design/planning_context_history.md`.

## Active Design Entry Points

Read these before working in the listed areas. They are accepted design decisions
binding for their stated release scope unless marked otherwise. Completed spec
packets are records, not authorization for new work.

| Area | Read |
| --- | --- |
| v0.2.0.2 equity and workflow planning | `inst/design/ledgr_roadmap.md` v0.2.0.2 section; `inst/design/research/Sharadar-Corporate-Event-Evidence.md`; `inst/design/research/Sharadar-Workflow-Improvement-Evidence.md`; relevant horizon and RFC pipeline entries |
| v0.2.0.1 released availability performance | `inst/design/ledgr_v0_2_0_1_spec_packet/v0_2_0_1_spec.md`, accepted hot-path and timestamp/benchmark amendments in that packet, `inst/design/ledgr_v0_2_0_1_spec_packet/tickets.yml`, Markdown tickets, and batch plan; accepted RFC artifacts; `dev/spikes/v0_2_0_1_hot_path_complexity_audit/`; `dev/spikes/v0_2_0_1_availability_timestamp_prerequisite/`; optimization and benchmark manuals; spike protocol section 10; earlier spike inventories and `dev/spikes/snapshot-sealing/` |
| Post-v0.2.0.1 spot-crypto planning | `inst/design/ledgr_roadmap.md` (spot-crypto section), `inst/design/horizon.md` (2026-09-14 research entry), `inst/design/rfc/README.md` (pipeline row), `inst/design/spike_protocol.md`, `inst/design/research/Transaction-Cost-Models.md`, `inst/design/research/Cross-Asset-Accounting-Critical-Events.md` |
| v0.2.0.0 release record | `inst/design/ledgr_v0_2_0_0_spec_packet/v0_2_0_0_spec.md`, `inst/design/ledgr_v0_2_0_0_spec_packet/v0_2_0_0_tickets.md`, `inst/design/ledgr_v0_2_0_0_spec_packet/tickets.yml`, `inst/design/ledgr_v0_2_0_0_spec_packet/batch_plan.md`, `inst/design/ledgr_v0_2_0_0_spec_packet/v0_2_0_0_release_closeout.md`, `inst/design/rfc/rfc_api_representation_hardening_v0_2_0_synthesis.md`, `inst/design/rfc/rfc_asset_availability_point_in_time_universes_v0_1_9_8_synthesis.md`, `inst/design/audits/v0_2_0_test_suite_audit.md`, `inst/design/spike_protocol.md`, `inst/design/vignette_styleguide.md`, `inst/design/release_ci_playbook.md`, `inst/design/contracts.md`, `inst/design/ledgr_roadmap.md`, `inst/design/horizon.md` |
| Release records v0.1.8.2 to v0.1.9.7 | `inst/design/README.md` (release-record list) and `inst/design/ledgr_roadmap.md`; the per-packet reading lists that previously sat in this table are preserved in `inst/design/planning_context_history.md` |
| v0.1.8.9 optimization inputs | `inst/design/spikes/ledgr_v0_1_8_9_optimization_round_spike/architecture_synthesis.md`, `dev/bench/notes/single_core_optimization_inventory.md`, `dev/bench/notes/per_pulse_complexity_findings.md`, `dev/bench/peer_benchmark/peer_benchmark.md` |
| v0.1.8.8 parallel dispatch | `inst/design/spikes/ledgr_parallelism_spike/summary_report.md`, `inst/design/spikes/ledgr_parallelism_spike/architecture_synthesis.md`, `inst/design/manual/sweep.qmd`, `inst/design/rfc/rfc_parallelism_spike_architecture_consequences_response.md` |
| Fold-core and feature-path documentation | `inst/design/manual/execution_fold_core.qmd`, `inst/design/manual/performance_arc_v0_1_8_x.qmd`, `inst/design/manual/features.qmd`, `inst/design/horizon.md` |
| v0.1.8.8 peer benchmark report | `dev/bench/README.md`, `dev/bench/peer_three_way.R`, `dev/bench/peer_three_way_backtrader.py`, `inst/design/ledgr_v0_1_8_7_spec_packet/benchmark_attribution_closeout.md` |
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

Current Windows R path used here; it does not change the `DESCRIPTION` floor.

```powershell
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" -e "pkgload::load_all('.', quiet=TRUE); testthat::test_local('.', reporter='summary')"
& "C:\Program Files\R\R-4.6.1\bin\x64\R.exe" CMD build .
& "C:\Program Files\R\R-4.6.1\bin\x64\R.exe" CMD check --no-manual --no-build-vignettes ledgr_<version>.tar.gz
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" tools/check-coverage.R
```

Prefer targeted checks while editing, then full tests and package check.

Local pkgdown builds use `dev/build-site.R`. It sets Quarto/Pandoc and the user
library fallback, cleans stale compiled `src/` artifacts, then runs pkgdown.

```powershell
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" dev/build-site.R --check  # verify toolchain only
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" dev/build-site.R          # full build into docs/
```

The live site redeploys from the `pkgdown` workflow on push to `main`.

## Ticket Workflow

1. Read the ticket, its dependencies, and the relevant contract section.
2. Add or update tests for the acceptance criteria.
3. Implement the smallest change that satisfies the ticket.
4. Run targeted tests, then full tests/package checks when the change affects
   public API, runner behavior, snapshots, CI, or release gates.
5. Update the active `tickets.md` checkboxes and `tickets.yml` status together.
