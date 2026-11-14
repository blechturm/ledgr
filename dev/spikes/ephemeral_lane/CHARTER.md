# Spike ephemeral_lane: what an in-memory lean run costs

**Status.** Charter, approved by the maintainer on 2026-11-14 ("proceed").
Spike protocol (`inst/design/spike_protocol.md`) applies; this charter binds
nothing outside `dev/spikes/ephemeral_lane/`.

## Question

What does one sweep candidate cost per pulse on the lean loop when results
stay in memory (`ledgr_sweep()`, one worker, `ledgr_output_sink_memory`),
against the same workload as a durable `ledgr_run()`, with both runs' phase
clocks reconciled to their wall time?

The macro plan's WS14 asks for ephemeral and durable ledgr to be reported
separately. Today the lean cost map measures only `ledgr_run()`; the
ephemeral figures quoted so far (about 440 and 250 us per pulse) are
estimates, and this spike replaces them with measurements.

## Prerequisite (answered)

The lean loop already serves one-worker sweeps (slice-1 and slice-2 gates
include sweep witnesses: `witness_sweep`, `s2_sizing_sweep`). The memory sink
keeps no hold rows and no clean fill rows (dev/lean_core/loop.R, the sink's
keep rule).

## Method

- Workloads: `10x7200` and `slice2_10x7200` from `descriptors.R`, unchanged.
- Arms: the lean loop on the pin library, durable (`ledgr_run()`) and
  ephemeral (`ledgr_sweep()` with one candidate, one worker), alternating
  fresh processes, 7 rounds, High performance, P-core affinity.
- Clocks: whole call; fold (`ledgr_fold_envelope`); the output handler's
  flush and write; result materialization for the sweep's summary. The
  phases must sum to within 5 percent of the whole-call clock; the residual
  is reported.
- Results: the candidate's metrics must equal those computed from the
  durable run's results (economic parity); otherwise the comparison is void.

## Kill

Inconclusive if the phase clocks do not reconcile within 5 percent on either
workload, or if the ephemeral and durable runs disagree on any metric.

## Deliverables

Runner and raw/summary CSVs, a checker that reruns and diffs the
non-timing outputs and guards package scope, and a one-page closeout: per
workload, us per pulse for each phase in both lanes and the difference the
durable output costs.

## Not in scope

Multi-worker sweeps (slice 5), compiled kernels (measured separately in
`dev/spikes/lean_fifo_cpp` and `lean_plan_cpp`), any change in `R/` or
`dev/lean_core/`.
