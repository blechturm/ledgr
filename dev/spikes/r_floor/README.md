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

## What the spec may consume, and what is open

The spec may cite the floor as a lower bound for this workload shape. Open,
as a second stage: add ledgr's guarantees back one layer at a time (durable
batched write, the decision-trace difference, declared-session availability,
boundary validation) and price each, so WS14a and WS14 can separate the cost
of a guarantee from waste.

Reproduce: `Rscript dev/spikes/r_floor/run.R <lib> <out dir>
10x7200,20x23400,500x1260`, then `Rscript dev/spikes/r_floor/check.R <lib>
<scratch dir>`.
