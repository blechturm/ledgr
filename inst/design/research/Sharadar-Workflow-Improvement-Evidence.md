# Sharadar Workflow Improvement Evidence

Date: 2026-09-20.
Status: empirical input to maintainer-scheduled v0.2.0.2 planning.
Authority: evidence and proposed outcomes; the roadmap owns scheduling.
This note does not select API signatures or replace an implementation spec.

## Evidence boundary

Source: the private ledgr-research repository at
`a7b24b3b694a3ee754c61537339ec24679e9d3a0`, particularly its
[feedback register](https://github.com/blechturm/ledgr-research/blob/a7b24b3b694a3ee754c61537339ec24679e9d3a0/docs/governance/ledgr-feedback.md).
Measurements below are reported executions against ledgr 0.2.0.1 at
`4350e655095fb708a1b3c5e990095bc7ac5617cc`, not new executions for this note.
No private identifiers or licensed rows are reproduced.

The companion [corporate-event evidence](Sharadar-Corporate-Event-Evidence.md)
covers LFB-001 and LFB-011. It explains why reconciled price accounting is not
yet economically complete equity accounting. This note covers workflow costs
and usability exposed by the same research.

## LFB-008: availability result reconstruction

Reported real workload: 563 configured instruments, 757 sessions. The fold
took 12.61 seconds; `ledgr_results(run, "availability")` took 799.56 seconds
for 382,288 rows. Fills, equity and diagnostics reads together took 0.55 seconds.
The surrounding phase took 858.69 seconds; that is not backtest execution time.

The source-based 2026-09-19 horizon entry identifies repeated price-history and
ledger-prefix reconstruction, catalogued as OPT-L14. The research-side public
synthetic reproducer measured 2,500 rows at 2.88 seconds and 10,000 at 11.62
seconds. Those two timings alone do not prove quadratic horizon scaling; the
separate source analysis identifies that mechanism.

Outcome: prepare history once and reconstruct forward, retaining current
schema, order, causal semantics and reopen behavior. Compare outputs on flat
and non-flat synthetic cases including stale and terminal states, and measure
growth with horizon and fills. No promised speed factor or new persistent
availability table is selected here. OPT-L14 already permits exact read-side
maintenance without a new RFC.

## LFB-009: progress during long operations

The same phase remained silent, making a slow result read look like a slow
fold. Post-run telemetry eventually separated them.

Outcome: optional, throttled progress identifies the active preparation,
execution, finalization or result-materialization stage. Report counts only
where meaningful; do not invent completion estimates. Progress must not change
strategy calls, RNG, accounting, identities or persisted economic output.
Callback/error behavior and the minimal public interface remain design choices.
No dashboard, background service or general observability framework is needed.

## LFB-010: opening-cash validation

`ledgr_opening(cash = 0)` reportedly constructs an object that `ledgr_run()`
later rejects because initial cash must be positive. The setup workaround uses
`.Machine$double.eps` and verifies no fills.

Outcome: construction and execution enforce the same supported input domain.
Unless an existing supported opening requires zero cash, prefer an early clear
rejection over expanding financing semantics for a diagnostic workaround.
Verify the boundary through public constructors and execution. This is a small
validation correction, not a new financing design.

## LFB-006: first-cutoff inspection

The production strategy context already exposes causal membership, prices and
restrictions. There is no demonstrated causality defect in deriving A0 there.
The recurring friction is using that derived basket to configure a separate
fixed-universe experiment. The reported public workaround encodes selection
as unfunded targets, reads diagnostics, and verifies zero fills. The real setup
took 13.47 seconds, returning 505 members and 504 initially allocatable members.

Outcome: inspect membership and current sizing eligibility at one decision
cutoff using a sealed snapshot and declared policies, without run registration
or a throwaway strategy. Reuse production resolution; separate membership,
sizing eligibility, portfolio-dependent restrictions and future execution.
Verify parity with the real first callback and absence of persistent writes.
Choose the smallest existing-surface extension or read-only query in focused
API design. Whole-history analytics and strategy-state export are not required.

## Explaining unsupported economics

This is a proposed usability outcome from the corporate-event findings, not a
newly proven absence of every existing warning surface. First inspect current
run summaries, diagnostics and explanations. Extend them only where supplied
event evidence leaves an unsupported economic effect unclear to the user.
Keep computational completion distinct from economic coverage; identify the
event and limitation without claiming total-return completeness for events
never supplied. Do not add a parallel certification or provenance system.

## Disposition and feedback to research

- LFB-001/011: scheduled equity-accounting design, using the companion note.
- LFB-008/009/010/006: scheduled v0.2.0.2 improvements described above.
- LFB-002: general external-lineage metadata remains parked.
- LFB-004: distinct source membership clocks remain parked; current translation
  preserves decision-time membership. Corporate-event timing still needs its
  own explicit contract.
- LFB-003: availability runtime already resolved upstream.
- LFB-005: membership-resolution performance already adopted as fixed.
- LFB-007: obsolete; explicit targets and `ctx$hold()` express the intentions.
- Terminal-only lifetime translation: corrected in the adapter, not new ledgr work.

Use the existing synthetic reproducer and the smallest detecting examples.
Keep source terms and research assumptions in adapters; retain one production
implementation of ledgr semantics. After release, ledgr-research pins the
release, checks the same workload and removes the corresponding workaround.
Adoption means that practical loop closes, not merely that a new API exists.
