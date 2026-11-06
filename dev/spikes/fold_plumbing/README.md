# Fold plumbing spike, 2026-11-06

**Question.** With the stages doing no work, what does the fold's data
movement cost per pulse at the real sizes of the two workloads in
`inst/design/ledgr_v0_2_3_spec_packet/lean_core_interface.md`, and does every
write land on the right pulse? The data movement is `services` reads, stage
outputs handed on, per-pulse checks, fill publication, diagnostic staging and
the equity row. A preallocated alternative is measured alongside. **Kill
condition:** if the skeleton fold cannot reproduce the real run's events,
diagnostic blocks and equity record exactly, it simulates something else, and
the spike stops as inconclusive.

**Outcome: green.** Both skeleton variants reproduce all three outputs
exactly on both workloads. Plumbing alone costs 1.2 to 2.0 ms per pulse
today, which is 32 to 62 percent of the real loop. The cost is fixed
per-call R overhead (checks, diagnostic staging, the fill block path), not
data volume or allocation.

## What ran

- `tape.R` wraps the pinned stages and write helpers from outside and records
  one real fold per workload pulse by pulse. It keeps each stage's result,
  every diagnostic staging call, every fill publication and the equity
  append, plus the outputs to reproduce: the published fill blocks, the
  diagnostic blocks given to the writer, and the equity prefix.
- `sim.R` is the skeleton: E's loop with stub stages. Each stub reads the
  `services` fields its real stage read (the mean count per call, through
  generated code), hands on that pulse's real objects, and writes through the
  real paths. It has two variants:
  - `today`: fresh objects each pulse, checked by the pinned carrier
    constructors; fills go block, then hold, then copy at P5 through the
    pinned output handler.
  - `prealloc`: E allocates each stage output once at its largest size and
    the stubs overwrite it in place; P4 writes fills straight into reserved
    event rows and P5 commits the count, with no append check and no failure
    protocol; fields are bound once as locals. The stage outputs and fills
    are not checked per pulse; diagnostic staging keeps its pinned checks.

  Both variants use the pinned diagnostic staging and equity append, which
  already preallocate. Fill legs (`record_accounting_fact`) are left out of
  both.
- `run.R` writes `evidence/`. Timings are interleaved, five repetitions,
  with the High performance plan and P-core affinity. The real loop is
  ledgr's `t_loop` telemetry on the same host. Each component is measured
  by removing it alone (`today-validate` is `today` without checks, and so
  on).
- `check.R` reruns into a scratch directory, diffs the structural CSVs,
  checks the timing rows, requires the gutted path to fail and guards
  package scope.

Pinned tree `d5b3a151` (`R/` unchanged at HEAD), Windows 11, R 4.6.1.

## Result

Microseconds per pulse, median of 5. The clock ticks every 15.6 ms, which is
about 31 us per pulse on momentum and 12 us on fill-heavy, so smaller
differences are noise.

| | momentum 40 x 504 | fill-heavy 500 x 1,260 |
| --- | ---: | ---: |
| real ledgr loop | 1,925 | 6,087 |
| skeleton, today's plumbing | 1,190 | 1,976 |
| skeleton, preallocated | 913 | 833 |
| loop and stub calls only | 0 | 16 |

What removing one component saves, in us per pulse (today / preallocated):

| component | momentum | fill-heavy |
| --- | --- | --- |
| per-pulse carrier and append checks | 476 / - | 825 / - |
| diagnostic staging and pulse flush | 714 / 675 | 445 / 437 |
| stage outputs (fresh copy / overwrite) | 198 / 258 | 286 / 333 |
| fill publication | 60 / 20 | 929 / 119 |
| `services` reads (list `$` / locals) | 20 / 20 | 16 / 0 |
| equity row | 40 / 20 | 0 / 16 |

The checks overlap the fill path (the publication block is checked), so the
rows do not add up to the total. Each row removes a whole component: the
check row turns off every carrier check and the append check together, and
the diagnostic row removes staging and the pulse drain with their checks.
They are ablations, not the saving of any particular design, and set no
budgets. Allocation per pulse, including E's setup:
momentum 75 KB today and 94 KB preallocated; fill-heavy 616 KB and 229 KB.

## What was learned about the package

- Every write lands on its pulse. The skeleton reproduces 296 and 67,725
  events, 1,284 and 1,369 diagnostic rows, and 504 and 1,260 equity rows bit
  for bit, in both variants. Dropping P4's reservation advance makes the
  event stream differ at once (`event_id`). The guarantee comes from the
  single loop and the sequence counters.
- Handing objects between stages is free. The loop with five stub calls costs
  0 to 16 us per pulse, and `services` reads cost about 20 us, which is at the
  clock's resolution.
- Preallocating and overwriting stage outputs is slower in R than building
  them fresh: 258 against 198 us on momentum, and 333 against 286 on
  fill-heavy. Allocating 500-element vectors is cheap. The cost is per-field
  interpreted work (a `get`, a `setv` and an `assign` per field), which
  both shapes pay.
- The expensive plumbing is fixed per-call R overhead:
  - per-pulse carrier checks: about 9 checks per pulse in the skeleton,
    about 10 in the real fill-heavy fold, which also checks P3's execution
    view (`evidence/check_census.csv`), each looping over its group's 6 to
    33 fields;
  - diagnostic staging: roughly 275 us per staging call, an estimate from
    an Rprof share (`ledgr_fold_staging_add`, about 46 percent, over 2
    calls) that is not part of the recorded evidence, because
    `ledgr_fold_diagnostic_segment`, `_rows` and `_staging_write` each loop
    over about 30 columns. On momentum, 2 staging calls per pulse cost more
    than everything else together;
  - the fill block path: build a block, check it, hold it, then copy it into
    the buffer. Writing fills straight into reserved rows is 8x cheaper on
    fill-heavy.
- A recorder that keeps references to preallocated outputs records the last
  pulse's values: 500 of 504 and 1,259 of 1,260 recorded decisions are wrong.
  With in-place buffers, LDG-3212's recorder must copy at the stage boundary.
- `Rprof()` on Windows reports about one seventh of the wall time at a 2 ms
  interval (pitfall 8 in the measurement notes). Its shares were used, its
  seconds were not.

## What the lean core may take from this

Keep fresh stage outputs, because allocation is not the cost. Write fills
straight into reserved event rows. Stage diagnostics as direct typed writes,
not segment, then rows, then write. Check carrier groups at fold boundaries
or under a debug switch, not on every pulse. These are inputs for the
P1-P5 family decisions; this spike binds nothing.

## What the skeleton leaves out

Stage computation (economics, the strategy, history reads, lot kernel),
P3's internal execution view (built and checked inside P3, never handed on),
fill legs, telemetry samples, the durable DuckDB writes, and stop pulses
(neither workload stops). The momentum workload is mostly scheduled skips
(481 of 504 pulses).
