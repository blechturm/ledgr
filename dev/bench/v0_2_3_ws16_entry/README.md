# WS16 cut-entry record, 2026-11-05

This is the measure step before the first lean-core cut (macro WS16, first
checkpoint: stage recorder, complete R FIFO family, memory preparation). It
records how the pinned reference core behaves at the three boundaries that
cut will replace. It changes nothing in `R/` and sets no budget; the cut does
that.

## Pin and builds

| Name | Commit | Use |
| --- | --- | --- |
| reference pin | `d5b3a151` (Cut 11 close) | every public probe |
| private library | `cad309f4` | private H1 memory shape |

`d5b3a151` and `cad309f4` have identical product code: the diff between them
touches only `inst/design/` and `dev/`. The public library is `git archive
d5b3a151` installed with `R CMD INSTALL`; probes that need internals load the
same archive with `pkgload::load_all()`.

The host is an i9-12900K running Windows 11 and R 4.6.1. The FIFO clocks ran
alone under the High performance plan with P-core affinity `0xFFFF`. Memory
runs ran under Balanced; their clocks are descriptive only.

## Reproduce

`run.sh <lib> <source tree> <evidence dir> <scratch dir>` runs every public
probe. The private H1 memory shape runs `memory_probe.R --state=<build-state.json>`
against the private library and writes aggregates only; they live in
ledgr-research `experiments/v0_2_2-reference/data/ws16_entry/`.

| Script | Question | Evidence |
| --- | --- | --- |
| `stage_inventory.R` | What does each fold stage take, change, return and publish? | `stage_*.csv` |
| `fifo_census.R` | Which FIFO row kinds and refusals reach the one lot kernel, from which caller? | `fifo_rows_*`, `fifo_blocks_*`, `fifo_refusals_*` |
| `fifo_cost.R` | What does the kernel cost per block and per row? | `fifo_cost_*.csv` |
| `memory_probe.R`, `summarize.R` | Which step sets the process peak, and how large is each resident component? | `memory_*.csv` |

## 1. Stage boundaries

The probe wraps each stage function on the eight A0 workloads (committed runs
and in-process sweeps) and one 40 x 504 monthly momentum run. Dynamic rows
are what happened; `stage_fields_static.csv` lists the carrier fields each
stage body and its direct callees name.

| Stage | Fold-state slots it changed | Handler calls | Other exits |
| --- | --- | --- | --- |
| P1 observe/settle | `equity_facts`, `last_fully_valued` every pulse; `cash`, `lot_state`, `positions`, `event_seq`, `frozen_set` on corporate-action pulses | `append_event_rows` | the only stage that returned a stop result (INCOMPLETE `valuation_horizon_exhausted`, 4) |
| P2 decide | `pending_segments`, `current_stage` | none | raised `ledgr_strategy_error` 3 times, as a condition, not a stop result |
| P3 plan | `pending_segments`, `current_stage` | none | |
| P4 apply | `cash`, `lot_state`, `positions`, `event_seq`, `position_facts`, `current_stage` | `write_fill_events`, `record_accounting_fact`, `append_compiled_spot_batch` | |
| P5 commit | `diagnostic_seq`, `pending_segments`, `processed`, `last_executed`, `strategy_state`, `telemetry_idx` | `flush_pulse_events` | returns `continue` |
| scheduled skip | P2/P3 replaced by the skip pair on 481 of the momentum run's 504 pulses | | |

Stage inputs are wide. P1 reads 13 fields of the `services` list, P2 reads
22, P3 8, P4 8 and P5 11 (static). `current_stage` changes on every P2-P4
call, so a whole-state comparison must name it. Envelope-level handler calls
(`init_buffers`, `run_transaction`, `write_run_evidence`,
`write_run_diagnostics`, the diagnostic summary/coverage/implicit writers and
`write_exception_diagnostic`) happen outside the five stages.

## 2. FIFO row kinds and refusals

Every lot operation goes through `ledgr_lot_apply(book, input)`. The census
classifies each row by operation, side, position before and after, lots
consumed, dust snap, fee split, zero price and replay witness.

| Source | Kernel rows | What it covers |
| --- | ---: | --- |
| A0 workloads | 256 | long books only: from-flat buys, adds, partial and full closes, fees, zero-price and witnessed dispositions, positive-basis openings |
| fill-heavy 500 x 1,260 | 135,450 | from-flat buys and full-close sells only, 67,725 in the fold and 67,725 in the fills read |
| pinned test suite | 159,635 | every A0 kind plus shorts, reversals with fee splits, multi-lot closes, dust snaps, signed openings and refusals (231 files, 1,352 tests, no failure or error with the kernel wrapped) |

Kinds the census did not see anywhere: a long opening with negative basis and
a short opening with zero basis. Every disposition closes its position fully,
as the contract requires.

Refusals reached the kernel only in tests: `ledgr_invalid_lot_fill`,
`ledgr_lot_state_invariant` and `ledgr_invalid_accounting_event`, 38 kernel
refusals in all, six of them through the fold path. There the fold applies a pulse's fills as one block
(10-49 rows in 361 pulses, 50 or more in 888 on the fill-heavy run) and, when
the block fails, `ledgr_fold_fill_candidate` finds the earliest failing row by
re-running the kernel on prefixes (bisection). That is how today's
earliest-row refusal precedence is produced.

## 3. Kernel cost

`fifo_cost.R` captures the 2,499 kernel calls of one fill-heavy run and its
fills read, then replays each group in timed passes.

| Caller | Block rows | Kernel us/call | Kernel us/row | Input validation us/call |
| --- | --- | ---: | ---: | ---: |
| fold (`ledgr_fold_fill_candidate`) | 10-49 | 222 | 5.0 | 24 |
| fold | 50+ | 242 | 4.2 | 26 |
| replay (`ledgr_replay_accounting_events`) | 10-49 | 220 | 5.0 | 24 |
| replay | 50+ | 242 | 4.2 | 26 |

The run takes 8.94 s and the fills read 0.69 s (67,725 fills, final equity
10728506.707646). Kernel work is about 0.30 s of each: 3 percent of the run,
but 43 percent of the fills read, because the read replays every fill.

## 4. Memory

Monthly top-20 momentum on one 252-session returns feature, fresh process per
run, two repetitions per portable shape. The repetitions agree within 2
percent.

| Shape | Peak private commit | Peak working set | Bar planes | Feature payload |
| --- | ---: | ---: | ---: | ---: |
| 500 x 1,260 | 564 MiB | 425-429 MiB | 26 MB | 5 MB |
| 500 x 2,520 | 807-822 MiB | 619-622 MiB | 53 MB | 10 MB |
| 500 x 5,040 | 1,147-1,183 MiB | 874-877 MiB | 106 MB | 21 MB |
| private H1 | 4,677-4,707 MiB | 2,469-2,487 MiB | 353 MB | 66 MB |

Step marks show where the lifetime peak private commit rises:

| Step | Peak rise, 500 x 5,040 | Peak rise, private H1 |
| --- | ---: | ---: |
| snapshot load (at open with `verify = TRUE`, else at experiment build) | +525-529 MiB | +1,307-1,360 MiB |
| bar hydration query, before the substrate is built | +142-160 MiB | +1,009-1,081 MiB |
| two store-wide validations at registration and restart (empty trace) | +140-161 MiB | none |
| substrate build, feature series, projection, provider, the pulse loop | none | none |
| store-wide validation at publication (full trace) | +168-203 MiB | +2,156-2,167 MiB |

The ranges cover both repetitions and the `verify = FALSE` run.

The pulse loop sets no new peak. The data resident for it (bar planes,
features, facts) is about 128 MB on the largest portable shape and 455 MB on
the private one. The process peak comes from loading the snapshot, hydrating
bars as one long frame, and validating the store. The last is the accepted
LDG-3209 exception, routed to LDG-3210 in WS9b. The `verify` switch moves the
snapshot-load cost between steps but does not change the peak.

## What this hands the cut

- The recorder's boundary list and what each stage changes are in section 1;
  `services` is a wide shared bag, so the interface table has to name the
  fields each stage really reads.
- Section 5.2 witnesses exist for every row kind but two opening sign
  combinations. Earliest-row refusal is a bisection over block prefixes.
- Tiles bound the prepared planes, not today's process peak. Moving the peak
  needs hydration by tile in place of the long bars query; the validation
  cost belongs to WS9b.
- Kernel baselines for the A2 budget: about 4-5 us per fill row and 25 us of
  input validation per block.

## Limits

Sizes are `utils::object.size`, so memory shared between components is
counted in each; stack objects are listed apart because they alias the named
components. Worker processes of sweeps were not observed. The private shape
has one history length; history-length variation is portable only. The
static field lists come from source text and miss fields reached through
helpers two calls deep.
