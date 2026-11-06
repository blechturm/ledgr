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
- `checks.R` times per-pulse checks and `lean.R` the lean floor (sections below).
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

## Check-cost probe (`checks.R`), after the Type 2 response

The response
(`inst/design/rfc/rfc_lean_core_pulse_plumbing_v0_2_3_response.md`,
finding 2) splits each per-pulse carrier check into conditions that can
fail on data and conditions that hold by construction. `checks.R` times,
on the same recorded pulses, today's full carrier checks against only the
data conditions it keeps. Both variants also run the append check, which
the typed accounting synthesis binds. P3's execution view is in neither.

Microseconds per pulse, median of 5, High performance plan, P-core
affinity (`evidence/checks_timing.csv`):

| | momentum 40 x 504 | fill-heavy 500 x 1,260 |
| --- | ---: | ---: |
| today: full carrier checks + append check | 252 | 729 |
| targeted: data checks only + append check | 18 | 307 |
| full carrier checks alone | 238 | 389 |
| data checks alone | 10 | 25 |
| append check alone | 10 | 274 |

The data checks cost about 4 to 6 percent of the full carrier checks. What
remains is the append check: about 250 us for each published fill block on
both workloads (momentum publishes on 21 of 504 pulses), largely
independent of the block's 1 to 86 rows. That is a fixed cost of the
validator's R implementation, not of its rules.

Planted faults on one fill-heavy pulse (`evidence/checks_faults.csv`): both
variants refuse a negative fill price, a missing cash effect and an
infinite mark. Only the full checks refuse a `priced` flag that disagrees
with its mark, a duplicated context position and fills out of decision
order. Those three can only come from a ledgr defect; they are the
detectors the debug switch would hold.

## Lean floor probe (`lean.R`)

The fold in the proposed lean shape, with stages that emit their data and do
no work, on the same recorded pulses. Each stage builds its outputs fresh
with one `list()` call per group; P4 writes fills into reserved event rows,
P5 commits the count and writes the pulse's diagnostic rows straight into
typed columns; fixed `services` fields are locals. The only per-pulse check
is the strategy target check on decided pulses (response review D1-D4),
either the pinned one or the restructured one from
`dev/spikes/strategy_check/`. The availability target check, which needs
P2's provider view, is not in the probe.

Microseconds per pulse, median of 5 measurements of ten folds each,
including each fold's E setup, High performance plan, P-core affinity
(`evidence/lean_timing.csv`):

| | momentum 40 x 504 | fill-heavy 500 x 1,260 |
| --- | ---: | ---: |
| real loop today (edge-checks spike) | 1,954 | 5,988 |
| skeleton, today's plumbing | 1,244 | 2,028 |
| lean, pinned strategy check | 79 | 346 |
| lean, restructured strategy check | 77 | 225 |
| lean, restructured check, references instead of copies | 46 | 149 |
| compact lean, loop only | 6 | 33 |
| compact lean, with the output boundary | 22 | 71 |
| loop and five stage calls only | 6 | 4 |

What removing one part saves from the restructured lean fold (us per
pulse). The clock resolves about 3 us on momentum and 1 us on fill-heavy;
an earlier run of the same arms put the restructured lean fold at 207 on
fill-heavy, so differences under about 20 us are not resolved:

| part | momentum | fill-heavy |
| --- | ---: | ---: |
| fill event writes (54 fills per pulse on fill-heavy) | 2 | 104 |
| of which event ID and run ID text | 0 | 33 |
| copying stage outputs (vs passing references) | 32 | 76 |
| diagnostic row writes | 32 | 43 |
| equity row | 12 | 24 |
| strategy check, restructured, with building its named vector | 0 | 35 |
| `services` field reads | 2 | 2 |

The compact lean fold (`fp_compact_fold()`) removes those costs together:
stages pass references (the bound for reading prepared data by index), the
strategy check is the restructured one, each fill is a compact typed record
of seven values (sequence, instrument position, side, quantity, price, fee,
execution time), each pulse's diagnostic rows stay its typed block, and
equity goes into local vectors. The output boundary, once per run, builds
the 31-column ledger with event IDs, run IDs, side text and the cash and
position effects (`ledgr_fill_publication_deltas()`), and binds the
diagnostic blocks: 39 us per fill-heavy pulse when spread over the run,
about 49 ms per run.

Every lean variant reproduces every event, diagnostic row and equity row
exactly; dropping the reservation advance breaks the events
(`evidence/lean_parity.csv`). Checking six 500 x 1,260 bar planes once at
preparation takes 16 ms per run.

The first lean shape, 207 to 225 us per fill-heavy pulse, about equals
PMwR's published whole backtest of the same shape (214 us, 2026-10-31 peer
benchmark, another build). The compact shape costs 71 us including its
output boundary. Adding the R floor spike's work for the same 500 x 1,260
crossover (`dev/spikes/r_floor/`: 48 us per pulse with the strategy call,
about 103 with fixed-basket availability) gives roughly 175 us per
fill-heavy pulse for a lean core that keeps ledgr's full ledger and
diagnostics, against 6 ms today. That is a sum of two separate
measurements, not a run.

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
