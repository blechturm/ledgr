# R-floor spike, 2026-11-03

**Question.** What does a minimal plain-R fold cost per pulse when it
reproduces ledgr's fills, equity and cash exactly for the published SMA5/10
transition rule on a fixed basket? Kill condition: if the fold cannot match
ledgr bit for bit, stop as inconclusive; a fast fold that computes something
else measures nothing.

**Outcome: green.** Both variants match ledgr exactly (fills, equity, cash)
on every shape, and the floor is measured.

## What ran

- `floor.R`: prepared open/close/SMA matrices, then one loop over pulses with
  preallocated typed fill buffers. Variant `inline` writes the rule into the
  loop; variant `strategy` calls the unchanged strategy function from
  `fixture.R` through a reused context environment (`ctx$fast`, `ctx$slow`,
  `ctx$state`, `ctx$hold()`) with named vectors, as a ledgr strategy sees it.
- `run.R` runs the ledgr oracle (durable `ledgr_run()` on `lib` built from
  `0d6c0b11`) and both folds on the same fixture and writes
  `evidence/parity.csv` and `evidence/timings.csv`.
- `check.R` reruns into a scratch directory, diffs parity against the
  recorded evidence, checks the timing table's rows and guards package scope.

Windows 11, R 4.6.1, collapse 2.1.8, P-core affinity, High performance plan.

## Result (microseconds per pulse, warm loop)

| shape | fills | floor inline | floor + strategy call | ledgr run | ledgr / floor | PMwR, published |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 10 x 7,200 | 7,971 | 7 | 11 | 2,790 | about 250x | 19 |
| 20 x 23,400 | 51,242 | 8 | 13 | 3,135 | about 240x | 24 |
| 500 x 1,260 | 67,725 | 40 | 48 | 8,320 | about 175x | 214 |

Preparing the matrices and SMAs takes 0.00 to 0.09 s per run. The ledgr
column is the durable run without result reads; PMwR is from the 2026-10-31
peer benchmark (another build, not this host), shown only for scale.
`system.time()` resolves about 10 ms on this host and the loops take 0.05 to
0.31 s, so small-shape floor values carry about 10 to 20 percent noise. A
second run by the checker reproduced them within that noise.

## What was learned about the package

- ledgr's semantics for this rule fit in one loop of about 30 lines of R and
  run at about 10 us per pulse on narrow books and about 50 us on 500
  instruments, including the strategy call. That is below PMwR.
- ledgr today spends about 175 to 250 times its floor. The WS14 stretch
  objective (100 to 200 us per no-fill pulse) is still about ten times the
  floor, which leaves room for ledgr's guarantees.
- Cash is booked fill by fill; bit-exact parity depends on that order.
- A plain environment with a `hold()` closure and a state list serves the
  strategy unchanged; only `ledgr_strategy_result()` was stubbed.

## What the floor leaves out

Durable writes, result reads, run registration and other fixed per-run cost,
the decision trace, availability semantics (declared sessions, restrictions,
stale and frozen marks, terminals), validation, schedules, corporate
actions, sizing helpers, costs, risk and RNG. The floor prices the economics
and the strategy call for a fixed basket on clean daily bars, nothing else.

## Gutted path

`run.R <lib> <out> 3x40,10x300 same_bar_fill` fills the inline variant at
the decision bar instead of the next open. Its parity rows turn
`fills_identical = FALSE` and `equity_identical = FALSE` while the intact
variant stays identical, and `check.R` would fail on them.

Nothing in the package was changed, demoted or deleted.

## Stage 2: the price of each guarantee

**Question.** What does each of ledgr's per-pulse guarantees cost when it is
added back to the floor in lean form? Kill condition as in stage 1: a layer
counts only if fills, equity and cash stay bit-identical to ledgr, and a
trace layer only if its trace equals `ledgr_results(bt, "diagnostics")`.

**Outcome: green.** Every layer on every shape is bit-identical
(`evidence/parity_layers.csv`).

`layers.R` adds, cumulatively: boundary validation of the strategy's targets;
a rich context (ISO timestamp, cash, equity, positions, OHLCV); fixed-basket
availability (eligibility mask, mark source and age, restricted targets
held); then either ledgr's full logical decision trace built every pulse, or
the WS15 design, which keeps only requests that did not end in the requested
position and rebuilds the full trace after the run from the fills, the
prepared planes and that residual, with no strategy call.

| layer (cumulative), us per pulse | 10 x 7,200 | 20 x 23,400 | 500 x 1,260 |
| --- | ---: | ---: | ---: |
| base (stage 1 floor in this harness) | 15 | 18 | 48 |
| + target validation | 17 | 18 | 48 |
| + rich context | 19 | 21 | 64 |
| + fixed-basket availability | 26 | 29 | 103 |
| + full trace, built every pulse | 64 | 68 | 222 |
| or + trace difference only (WS15) | 26 | 29 | 103 |
| ledgr at `0d6c0b11` | 2,790 | 3,135 | 8,320 |

After the run (seconds): the WS15 rebuild of the full trace takes 0.18,
0.71 and 0.28, most of it one canonical JSON encode per pulse for the
reconciliation detail; one batched DuckDB write of fills and equity takes
0.08 to 0.10, and 0.20 to 0.69 with the full trace. The ledgr reference
writes and reads the same trace inside its 2.8 to 8.3 ms pulse.

What the layers taught about ledgr, all found by failed parity first:

- a decision row's `quantity` is the current holding, not zero;
- a final-pulse request that differs from the holding writes an
  `execution / no_fill / final_pulse_no_execution` row with the request in
  `target` and the holding in `quantity`;
- the reconciliation detail books recorded cash fill by fill in event order,
  and expected (virtual) cash fill by fill with sells before buys, so the
  two can differ in the last digit on busy pulses;
- `cumsum()` accumulates in long double and differs from that booking in the
  last digit; exact rebuilds need plain double additions.

The WS15 residual on these shapes is the unmet final-pulse requests only
(1, 3 and 54 rows). Everything else rebuilt exactly.

## Fixed cost per run

`fixed_cost.R` profiles 20 warm 12 x 90 runs (`evidence/fixed_cost*.csv`).
ledgr takes 625 ms per run including fills and equity reads and `close()`;
the floor does the same run with a batched DuckDB write in 84 ms, most of it
DuckDB connect and shutdown. Of ledgr's 625 ms, the fold loop is 283 ms (90
pulses at about 3 ms), so the per-pulse premium is half of the "fixed" cost
of a small run. The rest: run setup and finalisation outside the loop
138 ms, result reads 80 ms, close 28 ms, snapshot metadata 27 ms, snapshot
connection 26 ms, provider data 10 ms, strategy spec 9 ms.

## Stage 3: the strategy-context boundary on a changing axis

**Question** (the bounded prerequisite from the lean-fold-core Type 2
response, finding 7): can ledgr's real strategy-context boundary run lean
over a changing axis, with retained views frozen and cutoff-bound history,
at materially lower matched cost? Kill condition: the lean boundary must
hand the strategy exactly what ledgr hands it on every pulse.

**Outcome: green for the boundary.** `probe_axes.R` recorded the behaviour
first (`probe_findings.md`). `seam_p2.R` builds each pulse's context as a
fresh list from prepared planes; `run3.R` records, inside a real ledgr run,
everything the strategy reads on every pulse (axis, membership, holdings,
`buyable`, OHLCV, both SMAs, `hold()`, a ten-session `ledgr_history_matrix()`)
and its targets, and requires the lean side to reproduce all of it.
Holdings come from ledgr's own fills; P3 to P5 are not this seam.

| changing axis (`axes_fixture.R`) | lean P2 | ledgr decide stage | parity |
| --- | ---: | ---: | --- |
| 30 x 250 | 14 us | 675 us | 13 of 13 fields, every pulse |
| 30 x 250, history read every pulse | 26 us | 965 us | 14 of 14 |
| 200 x 250 | 30 us | 664 us | 13 of 13 |
| 200 x 250, history read every pulse | 50 us | 1,479 us | 14 of 14 |

A retained lean view stays unchanged in every run. ledgr's decide stage is
measured from profile samples scaled to its wall time, with the same rule
and no recording; another R process was running on the host, so read the
ratios (about 22 to 48 times) as approximate.

Rules parity taught, all first wrong in the seam:

- the decision axis is the members in stable order, then held former
  members, not one sorted list;
- `buyable` follows membership, not whether the instrument has a bar today;
- `ledgr_history_matrix()` admits an instrument only with a complete
  lookback window, and returns no columns before one exists;
- missing price inputs are carried for up to five sessions for features and
  history (history projection v11), while `ctx$close` stays `NA`; TTR's
  running sum passes through the carried value, so a per-segment SMA
  differs in the last digit;
- stored prices are rounded to eight decimals;
- a fill at the next session's open belongs to the first decision after it.

**Memory.** The prepared planes take about 80 bytes per instrument-session
(0.6 MB at 30 x 250, 3.9 MB at 200 x 250). That is about 50 MB at
500 x 1,260 but several GB for a Sharadar-scale 5,000 x 7,000 run, so a lean
core needs chunked preparation by time window; this seam does not bound
memory.

**Not in this seam.** P3 to P5 with ledgr's own FIFO lot accounting reused,
restrictions and terminals, schedules, corporate actions, sizing helpers,
costs, risk and RNG.

## What the spec may consume, and what is open

The spec may cite the floor and the layer prices as lower bounds for this
workload shape: with every guarantee priced here, a lean ledgr pulse costs
about 30 us on narrow books and about 100 us on 500 instruments, against
2.8 to 8.3 ms today. The WS15 design rebuilds ledgr's full trace exactly on
these shapes. Not priced here: declared sessions with real gaps,
restrictions and terminals, schedules, corporate actions, sizing helpers,
costs, risk and RNG. Those layers need fixtures that exercise them.

Reproduce: `Rscript dev/spikes/r_floor/run.R <lib> <out dir>
10x7200,20x23400,500x1260`, `Rscript dev/spikes/r_floor/run2.R <lib> <out
dir> 10x7200,20x23400,500x1260`, `Rscript dev/spikes/r_floor/fixed_cost.R
<lib> <out dir> 20`, then `Rscript dev/spikes/r_floor/check.R <lib> <scratch
dir>`.
