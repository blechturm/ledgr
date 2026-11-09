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
- Not probed yet: private H1 (counts only).

## 5. Prerequisite result (charter stage 1): green

`rebuild.R`, evidence `rebuild.csv` and `rebuild_gut.csv`. On all six
workloads, with the clean-hold rows treated as not stored, the rebuild from
the explicit rows, the implicit fill rows, the coverage count, the ledger,
the bar closes, the run config and the `availability` view gives a decoded
trace `identical()` to the pin's: 64,028 holds on crossover 10 x 7,200,
562,221 on 500 x 1,260, and the cross-edge fixture's membership exits,
relisting and missing bars. The only new stored value is one certified hold
count per decided pulse, used as a check.

How each hold is placed:

- Pulse: each pulse ends with a stored row (its reconciliation row), so a
  missing sequence number belongs to the pulse of the next stored row; no
  position was unplaced.
- Context ordinal: the decision block is contiguous in context order, so
  `base = seq - k` from any stored decision row of the pulse; a pulse whose
  decisions are all holds starts its block at the first gap (2,289 of 7,200
  pulses on crossover 10 x 7,200). No pulse gave two bases.
- Fields: position from the ledger's position deltas up to the decision time
  (sequential sums); price from the bar close; the rest are the clean-hold
  constants.

With one stored decision row deleted (`--gut`), all six stores are refused
before decoding: the gaps no longer match the certified counts.

Open for stage 2: positions are summed from ledger deltas, which is exact
here because quantities are whole; the fold sets positions from the lot
book's net, so fractional quantities need that rule or the stored position.
The full-trace rebuild is plain R (6.4 s for 562k holds); a filtered explain
read touches one instrument.

## 6. Stage 2a result (sweep path builds only kept rows): green

`fork.R`, evidence `fork_sweeps.csv`, `fork_a0.csv`, `fork_sweeps_gut.csv`.
One rule in the staging functions: before rows are built, the sink's keep
rule picks them; the others only reserve their logical positions. A durable
store keeps every row, so committed runs are unchanged. One-candidate sweep,
three alternating rounds, median wall (not a timing record):

| workload | pin | lean P3 | lean P3 + keep rule | vs pin |
| --- | --- | --- | --- | --- |
| crossover 10 x 7,200 | 28.5 s | 25.1 s | 21.3 s | -25% |
| crossover 500 x 1,260 | 9.0 s | 8.8 s | 8.1 s | -10% |
| momentum 500 x 1,260 | 3.0 s | 2.9 s | 2.3 s | -24% |
| momentum 40 x 504 | 0.97 s | 0.97 s | 0.72 s | -26% |

Sweep tables and kept memory diagnostics are identical to the pin on all six
workloads; the eight A0 workloads are identical on every path (run, one-worker
sweep, compiled FIFO, restart, abort, walk-forward). With the keep rule gutted
(keep nothing), parity fails on all three workloads that keep rows. P2 still
builds its full decision segment; the rule skips staging, validation, the
pulse block and the filter.
