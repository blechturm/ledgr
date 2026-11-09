# Diagnostic records: probe findings

Probe: `probe.R` on the pinned build `d5b3a151`, 2026-11-09, one committed
run and one one-candidate sweep (`workers = 1`) per workload. Evidence:
`evidence/probe_rows.csv`, `probe_writes.csv`, `probe_cost.csv`. Wall times
are single runs on a working machine, not a timing record.

## 1. What the trace holds

Clean holds (one implicit row per held instrument per decided pulse) are most
of the logical trace on every run with more than a handful of instruments:

| workload | decided pulses | logical rows | clean holds | clean fills (2 rows each) | explicit |
| --- | --- | --- | --- | --- | --- |
| crossover 10 x 7,200 | 7,200 | 87,173 | 73.4% | 18.3% | 8.3% (7,200 reconciliation rows, one per pulse) |
| crossover 500 x 1,260 | 1,260 | 699,040 | 80.4% | 19.4% | 0.2% |
| momentum 500 x 1,260 | 1,260 | 32,759 | 84.3% | 5.4% | 10.3% (sizing, reconciliation, scheduled skips) |
| momentum 40 x 504 | 504 | 2,500 | 25.0% | 23.7% | 51.4% |
| cross-edge fixture, trading | 47 | 507 | 32.7% | 28.0% | 39.3% |
| A0 dense risk | 8 | 33 | 24.2% | 36.4% | 39.4% |

Rows a user would ask about (no fill, risk, stops, stale marks) are a few
dozen per run. Explicit rows that are not exceptions: one
`reconciliation/reconciled` row per decided pulse, one `sizing/recorded` row
per helper-sized decision, and one `decision/skipped` row per scheduled skip.

In R, the decoded trace of crossover 500 x 1,260 is 110 MB; its physical
implicit rows are 67 MB (630k rows, about 112 bytes each).

## 2. DuckDB writes inside the fold

Every store write happens before the first pulse (run initialization: two
summary rows, opening ledger rows) or after the last pulse, except one: the
implicit-diagnostic writer flushes a 65,536-row chunk whenever its buffer
fills. Crossover 10 x 7,200: 1 flush; crossover 500 x 1,260: 9 flushes,
590k rows, 0.30 s of an 8.2 s run. Ledger events, equity and explicit
diagnostics are written once at the end on these workloads.

## 3. What building diagnostics costs

Time inside the diagnostic builders (segment, staging, pulse block, clean-pair
checks, implicit blocks; outermost calls only):

| workload | committed run | sweep candidate | sweep rows built | sweep rows kept |
| --- | --- | --- | --- | --- |
| crossover 10 x 7,200 | 4.0 s of 21.5 (19%) | 4.8 s of 22.0 (22%) | 87,173 | 2 |
| crossover 500 x 1,260 | 0.9 s of 8.2 (11%) | 1.2 s of 7.1 (16%) | 699,040 | 108 |
| momentum 500 x 1,260 | 0.7 s of 3.4 (21%) | 0.7 s of 3.0 (23%) | 32,759 | 0 |
| momentum 40 x 504 | 0.3 s of 1.3 (25%) | 0.3 s of 0.9 (29%) | 2,500 | 0 |

A sweep candidate's memory sink cannot encode clean rows, so P3 expands every
decision row into the staging; P5's filter (`ledgr_memory_diagnostic_keep`,
`R/output-handler.R:15`) then keeps stale or frozen held marks, terminal
dispositions, final-pulse no-execution rows and stops: 0 to 108 rows here.
The figures exclude P2's own sizing and decision bookkeeping, so they are a
lower bound.

## 4. What this means for the spike

- The prize is the building, not the writing: 11-25% of a committed run and
  16-29% of a sweep candidate on the four larger workloads, against 4% for
  the in-loop flushes.
- A fold that builds only rows some reader needs removes most of both, and
  leaves nothing large enough to need an in-loop flush.
- Not probed yet: private H1 (counts only), and whether every clean-hold
  field and sequence position rebuilds from ledger, bars and facts.
