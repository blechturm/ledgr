# Diagnostic Records Amendment: Seed v1

- Author: Claude, 2026-11-09, at the maintainer's request.
- Status: seed. The maintainer names the review mode.
- Amends: the [per-pulse durable records synthesis](rfc_per_pulse_durable_records_v0_2_3_synthesis.md)
  (accepted 2026-11-03, implemented in Cut 11) Sections 2-3, and the
  [lean core pulse plumbing synthesis](rfc_lean_core_pulse_plumbing_v0_2_3_synthesis.md)
  clause that the fold writes "per chunk or at the end".
- Evidence: the [diagnostic-records spike](../../../dev/spikes/diagnostic_records/closeout.md)
  (pin `d5b3a151`, lean P3 at `724d522c`; probe, stage 1 rebuild, stage 2
  fork, checker).
- Already ticketed, not decided here: the sweep keep rule (LDG-3219,
  proposed Cut 13), which needs no format or contract change.

## 1. The problem

The maintainer's position (2026-11-09): ledgr should not do expensive work by
default, should not write to DuckDB inside the pulse loop, and a sweep should
spend nothing on analytics it throws away.

What a committed run does today, measured on the pin:

- It builds one decision row per instrument on the decision axis per decided
  pulse. Clean holds (target equals position, current close, nothing
  happened) are 73-84% of all rows on runs with more than a handful of
  instruments: 562,221 of 699,040 rows on crossover 500 x 1,260.
- Building diagnostics costs 11-25% of a committed run on the four larger
  probe workloads; P2's decision segment, P3's clean checks and implicit
  block, and P5's reconciliation row and pulse flush run on every pulse.
- The implicit codec stores one compact row per clean hold. Its 65,536-row
  buffer flushes to DuckDB inside the loop: 9 flushes, 0.3 s of an 8.2 s
  run on 500 x 1,260. It is the only in-loop DuckDB write.
- One explicit reconciliation row per decided pulse records that cash
  reconciled: 8% of the trace on crossover 10 x 7,200.

What users read from it (shipped surfaces): why a trade did not fill, what
the strategy knew (stale or frozen marks, membership), what risk changed,
stops and dispositions, and `ledgr_run_explain()`'s per-instrument timeline.
Only the timeline uses the clean-hold rows, and it adds no new fact: the
position comes from the ledger, the price from the bars, the date from the
schedule.

## 2. What the spike showed

1. Clean holds rebuild exactly from what remains stored: the explicit rows,
   the implicit fill rows, the logical row count, the ledger, the bar closes
   and the decision axis (the configured order, or the `availability` view
   for a membership universe). Every pulse ends with a stored row, so a
   missing sequence number belongs to the pulse of the next stored row; the
   decision block is contiguous in context order, so each gap's instrument
   follows. One certified hold count per decided pulse lets the reader refuse
   a store whose gaps do not match (`ledgr_diagnostic_corrupt`). Identical
   decoded trace on six workloads, including membership exits, relisting and
   missing bars.
2. A committed run that stores the counts instead of hold rows, holds all
   diagnostics in memory and writes once after the last pulse returns
   identical results, explain rows, summaries and tables on five workloads;
   stored implicit rows fall 89%; nothing is written inside the loop.
3. Its pulse loop is only 1-6% faster than lean P3, because the fold still
   builds the hold rows before dropping them; in R the diagnostic cost is
   per call, not per row.
4. The read side becomes the cost if the holds are rebuilt in R and queried
   as a registered data frame: the end-of-run summary and a full trace read
   became 2-10 x slower in the spike.

## 3. Proposed decisions

**D1. Clean holds are stored as counts.** A durable run stores, per decided
pulse, the number of certified clean holds instead of their rows. The
logical trace, sequence positions and every public read stay exactly as
today (synthesis Section 2 unchanged). The codec rule version and store
format version bump; older stores refuse with a classed condition.

**D2. The fold never builds a clean-hold row.** P2 and P3 decide cleanliness
from the decision vectors (target, post-risk target, position, mark source
and age, restriction and sizing reasons) and build rows only for the
residuals. Clean fills keep their implicit rows until the fills-reader
circularity (synthesis Section 4) is broken; that is a later step.

**D3. No DuckDB write inside the pulse loop.** Diagnostics, events and equity
are held in memory and written once after the last pulse, in the run's
transaction. With D1 the diagnostic memory is the residual and fill rows
only (crossover 500 x 1,260: 67,725 implicit rows instead of 629,946). This
replaces the pulse-plumbing "per chunk or at the end" clause with "at the
end"; a memory bound for long runs is stated as a measured figure, not a
chunk size.

**D4. The summary is written from the fold's own counts.** The end-of-run
summary and coverage need no read of the stored trace: decisions = residual
decision rows + hold counts; decision times include every pulse with a hold.

**D5. The reader rebuilds holds in SQL, and explain rebuilds only its
window.** One logical view adds the rebuilt holds through a join of the
count table, the decision axis, the ledger positions and the bar closes.
`ledgr_run_explain(bt, id, ts)` rebuilds only that instrument's window. The
integrity checks keep their refusals.

**D6. The reconciliation row.** One explicit row per pulse records a
successful reconciliation. The synthesis (Section 3) allows it to become
implicit only if its exact floating-point tuple rebuilds; this seed proposes
storing it only when reconciliation is not exact, and asks the response to
test whether the tuple is exactly derivable from stored cash and events.

**D7. Per-stage telemetry.** `contracts.md` (Telemetry And Recovery) keeps
detailed per-component telemetry session-scoped through
`ledgr_backtest_bench()`. The pin samples each stage every 100th pulse with
`proc.time()`, which ticks in about 10-16 ms on Windows against a 3 ms
pulse: every stage median is 0 on crossover 10 x 7,200. The samples are
never stored. The lean loop drops per-stage sampling (interface Section
19.1, maintainer 2026-11-09); this decides what `ledgr_backtest_bench()`
reports after the switch: whole-run times only, or stage times from a
fine-grained clock.

## 4. Open question for the maintainer: opt-in diagnostics

The maintainer asked whether the full trace should be opt-in. The accepted
synthesis decided "full reconstructed trace by default" (Q1) with no
retention tier. With D1-D5 the default costs one count per pulse in the
fold, and the price moves to the rare read. Options:

- **Keep the trace on by default (D1-D5).** No contract change; explain
  works on every run.
- **Make the full trace opt-in.** Runs record exceptions only unless asked;
  `ledgr_run_explain()` refuses on a run recorded without the trace. A
  contract change, and it gives up explain-by-default.

The seed recommends the first: with D1-D5 the default is no longer
expensive. The response should challenge that with measurements of D5's read
cost.

## 5. Out of scope

Clean-fill rows (fills-reader circularity), sizing rows (irreducible,
synthesis Section 3), scheduled-skip rows (synthesis Q3), sweeps (LDG-3219),
rerun-based explanation (rejected by the synthesis; asset-availability 9.4,
history-wave E9), and teaching the workflow in an article (a documentation
ticket once the design settles).

## 6. Questions for the response

1. Does D2 hold for every path that builds decision rows today (stop paths,
   scheduled skips, sizing-skipped instruments, risk-reduced targets)?
2. Is D3's memory acceptable on private H1 with D1 in place? (Measure the
   residual and fill rows per run.)
3. Can D5's SQL rebuild meet today's read cost for a full trace and for one
   explain window?
4. Is the reconciliation tuple (D6) exactly derivable?
5. Does any consumer read physical diagnostic rows rather than the logical
   view (sweep promotion, run comparison, recovery)?
