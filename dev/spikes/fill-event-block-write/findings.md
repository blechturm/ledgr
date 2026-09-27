# Per-pulse block write of fill events: findings and inventory

**Outcome: green on the charter.** Staging a pulse's fill events and writing them with one
`collapse::setv()` per column saves:

- warm `ledgr_run`: about 10% (6.5 s);
- warm `ledgr_sweep`: about 21% (8.7 s).

Both are at 500 × 1,260 with SMA 5/10 and 68,201 fills. Every parity surface is byte-identical in
all cases. Both workflows clear the RFC's 5% gate, so neither stop condition fired. Findings bind no
design.

**Question.** Does per-pulse block writing cut warm `ledgr_run` and `ledgr_sweep` wall time by more
than 5%, with byte-identical ledger events, fills and equity? The arms are production per-event
writes ("base") and the in-memory block seam ("block").

**Baseline.** A detached worktree at `b14579f`, the local tip of `codex/ws16-v0.2.1.0`. The
environment is R 4.6.1 (Windows), collapse 2.1.8 and duckdb 1.5.5. The blob ids of the three seamed
files are in `evidence/environment.csv`.

## What ran

`probe.R` came first: a 6-instrument run and sweep, identical under both arms, with the gut
detected. `seam.R` changes three loaded functions and nothing on disk:

- `ledgr_execute_fold()` gets one `flush_pulse_events()` call right after the per-fill loop. Nothing
  between that loop and the next reader (the checkpoint flush, the next pulse) touches the buffer.
- The run writer (`ledgr_persistent_output_handler`) stages rows. Its flush replaces 11 scalar
  writes per event with 11 vector writes per pulse.
- The sweep writer (`ledgr_memory_output_handler`) stages each row. `record_accounting_fact` patches
  the staged row and stages its close/open legs. The flush replaces 16 scalar event writes plus
  9 scalar leg writes per leg with one vector write per column.

Live event mode never reaches `buffer_event()`, so it is untouched.

## Parity (`parity.csv`: 39 rows, all identical)

Surfaces compared:

- **Runs:** ledger events (full table, by `event_seq`), fills, equity and trades.
- **Sweeps:** atomic non-timing columns, retained returns and trades, and object attributes.

The sweep comparison drops only the per-call random `sweep_id`; a base-versus-base row shows nothing
else varies.

Cases:

- p1: SMA crossover with zero cost.
- p2: a reversal pattern with a 10 bps fee (2,936 events, 4,106 fill legs, 1,854 trades).
- p3: availability path, uneven history, stale(2).
- p4: `db_live` mode.
- p5: `ledgr_backtest` with `checkpoint_every = 2`, so the pending buffer flushes mid-run.
- s1: the release shape, run and sweep.

## Measurements

Warm clocks start from a reused sealed snapshot and time experiment, execution and result surface.
Each timed run gets a fresh copy of the pristine store, made outside the timer. 7 alternating
repetitions after warm-up; `timing_summary.csv` has the full statistics.

| Workflow | base s | block s | paired saving s (IQR) | saving | GC base → block |
|---|---|---|---|---|---|
| `ledgr_run` | 64.66 | 58.39 | 6.54 (6.06–6.66) | 9.8% | 9.1 → 8.5 s |
| `ledgr_sweep` (1 candidate) | 42.15 | 33.59 | 8.74 (8.51–8.88) | 20.8% | 6.1 → 4.8 s |

Relative IQR is at most 0.019. An earlier full recording, rerun only to fix an attribution label,
gave 6.80 s (10.0%) and 8.81 s (21.1%).

**Attribution** (`attribution.csv`, one 10 ms `Rprof` per arm; sampled time is about 66% of wall):

| Workflow | Per-event writes, base | Same work, block | Flush, block |
|---|---|---|---|
| `ledgr_run` | `buffer_event` 4.69 s | 0.36 s | 0.35 s |
| `ledgr_sweep` | `buffer_event` + `record_accounting_fact`: 7.13 s | 1.15 s | 0.77 s |

The untouched costs stay flat:

| Unchanged cost | `ledgr_run` | `ledgr_sweep` |
|---|---|---|
| Row construction (`ledgr_fill_event_payload`) | 6.0 → 5.5 s | 2.0 → 1.8 s |
| `ctx$features` | about 8–9 s | about 8–9 s |
| Lot accounting | about 6.2 s | about 2.4 s |

The cost removed was per-call overhead: scalar type dispatch and index validation on every value,
not data movement.

## Follow-up probes (`followup_probe.R`, supplementary)

**Hotspots** (`hotspots.csv`, one sampled profile each at release shape; shares are percent of
sampled time):

| Function | Canonical run | Canonical sweep | Compiled `spot_fifo` sweep |
|---|---|---|---|
| strategy callback | 25% | 37% | 58% |
| `ctx$features` | 20% | 29% | 46% |
| alias-map lookup and normalization (inside `ctx$features`) | about 5% | about 6% | about 12% |
| fill-event writing | 24% | 25% | 5% (compiled batch append) |
| lot accounting | 15% | 9% | 15% (compiled batch) |
| finalization | 14% | n/a | n/a |
| snapshot hash guard | 7% | n/a | n/a |

The compiled accountant exists only for sweeps; durable runs refuse it. It already appends each
pulse's fills as one batch, so this spike does not apply to it. Its `ledgr_fill_row_buffer_add_many()`
copies take about 3%.

**Width scaling** (`width_scaling.csv`, 3 alternating repetitions, same strategy, 1,260 sessions):

| Instruments | Fills per pulse | `ledgr_run` saving | `ledgr_sweep` saving |
|---|---|---|---|
| 10 | 1.1 | 1.9% (noise level) | 0.6% (noise level) |
| 50 | 5.5 | 9.7% | 10.6% |
| 150 | 16.5 | 12.4% | 18.9% |
| 500 (main record) | 54 | 9.8% | 20.8% |

The saving follows how many fills share a pulse, not the number of bars. It is negligible when about
one fill lands per pulse and reaches its full share by roughly 150 instruments trading together.
Nothing got slower at small widths.

## Detector sensitivity

`spike_checker.R --gut misorder` writes every staged column except `event_seq` in reverse order
within a pulse. `parity.csv` then fails: for example, `p1_sma_zero_cost` run fills, trades and
ledger events flip from `TRUE` to `FALSE`. `fixture.csv` and every measured-evidence check still
pass, as they should. The ungutted checker passes 12 of 12 checks, including the package-scope
guard.

## Learned, demoted, deleted

- **Learned:**
  - The fold already treats the pulse as the emission unit: "Event emission and state mutation
    happen only after the private pulse plan is complete". A flush after the fill loop fits that
    shape. The only mid-loop reader of a just-written row is the sweep writer's
    `record_accounting_fact`.
  - Production `ledgr_fill_row_buffer_add_many()` writes through env-held base subassignment (style
    shape 7, a full column copy per call). The compiled-path caller is `R/sweep.R:1795`; the
    prototype does not use the helper.
  - Row construction, the per-fill JSON payload (about 5.5 s of the run), is now the largest
    remaining writer-side cost. It is out of scope here.
- **Demoted:** the first full recording, kept only as a reproduction figure above.
- **Deleted:** an attribution label (`handler$flush_pulse_events`) that could never match the fold's
  call site.

## Limitations

- One Windows machine; 7 repetitions per arm; one `Rprof` sample per arm.
- The single-candidate sweep is the peer-benchmark shape. Multi-candidate sweeps should scale per
  candidate but were not timed.
- Not exercised:
  - an exception raised inside a pulse's fill loop, where staged rows never reach the buffer;
  - the compiled spot-FIFO path;
  - walk-forward.
- The p4 `db_live` case only shows the seam is inert there.

## Recommendation

This evidence supports taking the block write forward. It is the only collapse-assisted change the
current profile showed above the 5% gate. A production version would make `flush_pulse_events()`
part of the output-handler contract in the shared fold, used by both handlers, and would need a
decision on failure semantics for rows staged mid-pulse. The maintainer owns that decision and any
ticket.

Rerun from the worktree root:
- `Rscript dev/spikes/fill-event-block-write/spike_runner.R --phase all`
- `spike_checker.R` (add `--gut misorder` to see it fail)
