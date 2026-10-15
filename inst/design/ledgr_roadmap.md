# ledgr Roadmap

**Role:** living; release-scope front door.
**Status:** working
**Authority:** Release scope only. The active packet's `tickets.yml` is the
sole within-release sequencing authority.

This page answers which releases exist, what each release delivered or owns,
and where its packet lives. It does not duplicate ticket order, RFC
obligations, or parked ideas. Historical planning prose is preserved in
[roadmap history](roadmap_history.md).

## Release sequence

| Release | State | Release outcome | Authoritative packet |
| --- | --- | --- | --- |
| v0.1.0 | Released | Deterministic backtest MVP. | [packet](ledgr_v0_1_0_spec_packet/) |
| v0.1.1 | Released | Data ingestion and snapshotting. | [packet](ledgr_v0_1_1_spec_packet/) |
| v0.1.2 | Released | Snapshot correctness and research UX. | [packet](ledgr_v0_1_2_spec_packet/) |
| v0.1.3 | Released | Onboarding release. | [packet](ledgr_v0_1_3_spec_packet/) |
| v0.1.4 | Released | Research workflow stabilisation. | [packet](ledgr_v0_1_4_spec_packet/) |
| v0.1.5 | Released | Experiment-store core. | [packet](ledgr_v0_1_5_spec_packet/) |
| v0.1.6 | Released | Experiment comparison and strategy recovery. | [packet](ledgr_v0_1_6_spec_packet/) |
| v0.1.7 | Released | Core UX overhaul. | [packet](ledgr_v0_1_7_0_spec_packet/) |
| v0.1.7.1 | Released | Installed UX stabilisation. | [packet](ledgr_v0_1_7_1_spec_packet/) |
| v0.1.7.2 | Released | Auditr UX and strategy helpers. | [packet](ledgr_v0_1_7_2_spec_packet/) |
| v0.1.7.3 | Released | Accounting correctness and indicator documentation. | [packet](ledgr_v0_1_7_3_spec_packet/) |
| v0.1.7.4 | Released | External documentation review and auditr report. | [packet](ledgr_v0_1_7_4_spec_packet/) |
| v0.1.7.5 | Released | Indicator, diagnostic, and documentation hardening. | [packet](ledgr_v0_1_7_5_spec_packet/) |
| v0.1.7.6 | Released | DuckDB persistence architecture review. | [packet](ledgr_v0_1_7_6_spec_packet/) |
| v0.1.7.7 | Released | Risk-metrics contract. | [packet](ledgr_v0_1_7_7_spec_packet/) |
| v0.1.7.8 | Released | Strategy reproducibility preflight. | [packet](ledgr_v0_1_7_8_spec_packet/) |
| v0.1.7.9 | Released | Strategy ergonomics and execution stabilisation. | [packet](ledgr_v0_1_7_9_spec_packet/) |
| v0.1.8.00 | Released | Design-document governance and v0.1.8 readiness. | [packet](ledgr_v0_1_8_00_spec_packet/) |
| v0.1.8 | Released | Lightweight sweeps and the first fold-core split. | [packet](ledgr_v0_1_8_0_spec_packet/) |
| v0.1.8.1 | Released | Multi-output indicator authoring. | [packet](ledgr_v0_1_8_1_spec_packet/) |
| v0.1.8.2 | Released | Metric context, risk-free rate, and indicator cleanup. | [packet](ledgr_v0_1_8_2_spec_packet/) |
| v0.1.8.3 | Released | Single-core fold/runtime optimisation. | [packet](ledgr_v0_1_8_3_spec_packet/) |
| v0.1.8.4 | Released | Active feature aliases and parameter-grid helpers. | [packet](ledgr_v0_1_8_4_spec_packet/) |
| v0.1.8.5 | Released | Canonical research workflow and teachability. | [packet](ledgr_v0_1_8_5_spec_packet/) |
| v0.1.8.6 | Released | Feature projection, storage evidence, and performance attribution. | [packet](ledgr_v0_1_8_6_spec_packet/) |
| v0.1.8.7 | Released | Optimisation round two and legacy cleanup. | [packet](ledgr_v0_1_8_7_spec_packet/) |
| v0.1.8.8 | Released | Parallel sweeps and typed execution evidence. | [packet](ledgr_v0_1_8_8_spec_packet/) |
| v0.1.8.9 | Released | Single-core buffer and reconstruction optimisation. | [packet](ledgr_v0_1_8_9_spec_packet/) |
| v0.1.8.10 | Released | Matrix substrate and compiled spot-FIFO opt-in. | [packet](ledgr_v0_1_8_10_spec_packet/) |
| v0.1.8.11 | Released | Documentation, structure, and cleanup. | [packet](ledgr_v0_1_8_11_spec_packet/) |
| v0.1.9.1 | Released | Public transaction-cost API and cost identity. | [packet](ledgr_v0_1_9_1_spec_packet/) |
| v0.1.9.2 | Released | Durable sweep artifacts and retained returns. | [packet](ledgr_v0_1_9_2_spec_packet/) |
| v0.1.9.3 | Released | Target-risk and chainable risk identity. | [packet](ledgr_v0_1_9_3_spec_packet/) |
| v0.1.9.4 | Released | Walk-forward evaluation. | [packet](ledgr_v0_1_9_4_spec_packet/) |
| v0.1.9.5 | Released | Teaching, contract, and naming cleanup. | [packet](ledgr_v0_1_9_5_spec_packet/) |
| v0.1.9.6 | Released | Validation-toolkit substrate and selection diagnostics. | [packet](ledgr_v0_1_9_6_spec_packet/) |
| v0.1.9.7 | Released | Business-objective eligibility and robustness diagnostics. | [packet](ledgr_v0_1_9_7_spec_packet/) |
| v0.2.0.0 | Released | API hardening and point-in-time asset availability. | [packet](ledgr_v0_2_0_0_spec_packet/) |
| v0.2.0.1 | Released | Availability performance, resume repair, and benchmark closeout. | [packet](ledgr_v0_2_0_1_spec_packet/) |
| v0.2.1.0 | Released | Accounting consolidation, equity events, strategy context, and release hardening. | [packet](ledgr_v0_2_0_2_spec_packet/) |
| v0.2.2 | Active | Long-window point-in-time research, pre-history foundations, historical projection, recursive-indicator semantics, and release evidence. | [packet](ledgr_v0_2_2_spec_packet/); [tickets](ledgr_v0_2_2_spec_packet/tickets.yml) |

## Next release

After v0.2.2 closes, choose a bounded packet from measured evidence rather
than treating this list as a sequence:

- finish the phase-level memory and parallel-worker budget work;
- consolidate output handling, then reconsider one execution mode using the
  RED probe and the history implementation as inputs;
- simplify the ordinary conceptual surface only where the stable contracts
  show a real teaching or usage cost.

Each item requires its own accepted owner before implementation. The
[horizon](horizon.md) retains the full non-binding questions and the
[RFC pipeline](rfc/README.md) retains accepted obligations.

## Later direction

Later releases may take exact equity quantity settlement, opt-in factor or
prediction evidence (LFB-028), fitted-transform and ML lifecycle work,
portfolio construction, external point-in-time regressors, liquidity and
capacity, OMS/paper trading, and production observability. These are
directions, not promises. Promotion starts in the RFC pipeline or an accepted
packet; until then the horizon remains non-binding.

## Boundary

The design tree stays under `inst/design` as source-checkout evidence and is
excluded from built packages by `.Rbuildignore`. Cut 14 established and tests
that build boundary. Cut 15 deliberately performs no path rewrite, mirror,
redirect tree, or compatibility shim.
